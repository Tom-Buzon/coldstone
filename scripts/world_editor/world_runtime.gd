extends Node3D
class_name HopliteWorldRuntime

signal enemy_spawned(enemy: Node, group_id: String)
signal enemy_died(enemy: Node, group_id: String)
signal player_entered_trigger(trigger_id: String)
signal player_entered_atmosphere(zone_id: String)
signal chapter_transition_requested(destination_chapter: String, destination_spawn: String)

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")
const WorldTerrainFoliageScript = preload("res://scripts/world_editor/world_terrain_foliage.gd")
const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")
const AtmosphereCatalogScript = preload("res://scripts/environment/world_atmosphere_catalog.gd")
const WATER_SHADER: Shader = preload("res://scripts/environment/water_surface.gdshader")
const FIRE_SHADER: Shader = preload("res://scripts/environment/fire_billboard.gdshader")
const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const EquipmentPickupScript = preload("res://scripts/equipment/equipment_pickup.gd")
const FaunaWaterBlockerScript = preload("res://scripts/fauna/fauna_water_blocker.gd")
const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const EnemyArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const HopliteV2CatalogScript = preload("res://scripts/enemy_v2/hoplite_v2_catalog.gd")
const HopliteV2ShadowFactoryScript = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const HopliteV2TroopRuntimeScript = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")
const HopliteV2LodComponentScript = preload("res://scripts/enemy_v2/hoplite_v2_lod_component.gd")
const EncounterBudgetScript = preload("res://scripts/world_editor/world_encounter_budget.gd")
const PlayerScript = preload("res://scripts/player.gd")
const CrowdDirectorScript = preload("res://scripts/ai/battle_crowd_director.gd")

const PREVIEW_FORMATION_LIMIT := 16
const PREVIEW_CHARACTER_LIMIT := 12

const MAX_AUTHORED_CONVEX_PARTS: int = 16
const WORLD_ENEMY_LOD_SETTING_KEYS := {
	"enabled": "hoplite/enemy_lod/enabled",
	"near_distance": "hoplite/enemy_lod/near_distance",
	"far_distance": "hoplite/enemy_lod/far_distance",
	"cull_distance": "hoplite/enemy_lod/cull_distance",
	"full_rate_distance": "hoplite/enemy_lod/full_rate_distance",
	"medium_animation_hz": "hoplite/enemy_lod/medium_animation_hz",
	"far_animation_hz": "hoplite/enemy_lod/far_animation_hz",
	"shadow_distance": "hoplite/enemy_lod/shadow_distance",
}

static var convex_collision_cache: Dictionary = {}
static var tree_trunk_bounds_cache: Dictionary = {}

var document: HopliteWorldDocument
var editing := true
var portion_center := Vector3.ZERO
var portion_radius := INF
var world_root: Node3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var player: HopliteUALNativePlayer
var crowd_director: HopliteBattleCrowdDirector
var enemy_v2_troop_runtime: HopliteV2TroopRuntime
var navigation_region: NavigationRegion3D
var navigation_mesh: NavigationMesh
var navigation_source_geometry: NavigationMeshSourceGeometryData3D
var navigation_bake_revision: int = 0
var nodes_by_id: Dictionary = {}
var enemies_by_group: Dictionary = {}
var initial_group_counts: Dictionary = {}
var v2_terrain_surfaces: Array[Dictionary] = []
var preview_character_count := 0
var active_chapter_id := ""
var requested_spawn_id := ""
var encounter_budget: RefCounted
var pending_enemy_spawns: Array[Dictionary] = []
var document_runtime_setting_restore: Dictionary = {}

func build(source: HopliteWorldDocument, edit_mode: bool = true, center: Vector3 = Vector3.ZERO, radius: float = INF, chapter_id: String = "", spawn_id: String = "") -> void:
	clear_world()
	document = source
	_apply_document_runtime_overrides()
	editing = edit_mode
	active_chapter_id = chapter_id if not chapter_id.is_empty() else document.start_chapter()
	requested_spawn_id = spawn_id
	encounter_budget = EncounterBudgetScript.new()
	encounter_budget.configure(_chapter_entities(), document.editor_groups())
	portion_center = center
	portion_radius = radius
	world_root = Node3D.new()
	world_root.name = "EditableWorld"
	add_child(world_root)
	if not editing:
		_build_runtime_navigation()
	_build_environment()
	if not editing:
		crowd_director = CrowdDirectorScript.new() as HopliteBattleCrowdDirector
		crowd_director.name = "WorldCrowdDirector"
		world_root.add_child(crowd_director)
		enemy_v2_troop_runtime = HopliteV2TroopRuntimeScript.new() as HopliteV2TroopRuntime
		enemy_v2_troop_runtime.name = "EnemyV2TroopRuntime"
		world_root.add_child(enemy_v2_troop_runtime)
		_build_test_player()
		# Player/UI startup may restore the user's global quality configuration.
		# Re-assert a map-owned laboratory profile immediately before enemies are
		# instantiated so every actor receives the documented thresholds.
		_apply_document_runtime_overrides()
		call_deferred("_apply_document_runtime_overrides")
	for raw: Variant in _chapter_entities():
		if not raw is Dictionary:
			continue
		var entity := raw as Dictionary
		if not bool(entity.get("enabled", true)) or not _inside_portion(entity):
			continue
		var type := String(entity.get("type", ""))
		if not editing and type == "enemy_group" and not _spawns_on_start(entity):
			continue
		var node := _build_entity(entity)
		if node != null:
			nodes_by_id[String(entity.get("id", ""))] = node
	if not editing:
		_resolve_protect_targets()
		_request_runtime_navigation_rebake()
	set_process(not pending_enemy_spawns.is_empty())


func _apply_document_runtime_overrides() -> void:
	if document == null:
		return
	var settings := document.data.get("settings", {}) as Dictionary
	var lod_override := settings.get("enemy_lod_override", {}) as Dictionary
	for raw_key: Variant in WORLD_ENEMY_LOD_SETTING_KEYS.keys():
		var key := String(raw_key)
		if lod_override.has(key):
			var project_key := String(WORLD_ENEMY_LOD_SETTING_KEYS[key])
			if not document_runtime_setting_restore.has(project_key):
				document_runtime_setting_restore[project_key] = ProjectSettings.get_setting(project_key)
			ProjectSettings.set_setting(project_key, lod_override[key])
	HopliteV2LodComponentScript.invalidate_settings_cache()


func _restore_document_runtime_overrides() -> void:
	if document_runtime_setting_restore.is_empty():
		return
	for raw_key: Variant in document_runtime_setting_restore.keys():
		var project_key := String(raw_key)
		ProjectSettings.set_setting(project_key, document_runtime_setting_restore[project_key])
	document_runtime_setting_restore.clear()
	HopliteV2LodComponentScript.invalidate_settings_cache()


func _exit_tree() -> void:
	_restore_document_runtime_overrides()

func _process(_delta: float) -> void:
	if editing or pending_enemy_spawns.is_empty():
		set_process(false)
		return
	var budget_usec := int(clampf(float(ProjectSettings.get_setting("hoplite/performance/spawn_budget_ms", 3.0)), 1.0, 12.0) * 1000.0)
	var max_per_frame := clampi(int(ProjectSettings.get_setting("hoplite/performance/spawn_per_frame", 2)), 1, 8)
	var started_usec := Time.get_ticks_usec()
	var spawned_this_frame := 0
	while not pending_enemy_spawns.is_empty() and spawned_this_frame < max_per_frame:
		var task := pending_enemy_spawns[0]
		var entity := task["entity"] as Dictionary
		var holder := task["holder"] as Node3D
		if holder == null or not is_instance_valid(holder):
			pending_enemy_spawns.pop_front()
			continue
		var next_index := int(task["next_index"])
		var total_count := int(task["total_count"])
		var spawned := spawn_enemy_group(entity, task["target"] as Node3D, holder, 1, next_index, false)
		var all_spawned: Array[Node] = task["spawned"]
		all_spawned.append_array(spawned)
		task["next_index"] = next_index + 1
		spawned_this_frame += 1
		if int(task["next_index"]) >= total_count:
			_configure_group_behavior(all_spawned, entity, task["target"] as Node3D)
			pending_enemy_spawns.pop_front()
		if spawned_this_frame > 0 and Time.get_ticks_usec() - started_usec >= budget_usec:
			break
	set_process(not pending_enemy_spawns.is_empty())

func clear_world() -> void:
	_restore_document_runtime_overrides()
	pending_enemy_spawns.clear()
	set_process(false)
	if player != null and is_instance_valid(player):
		# A chapter transition can leave one frame between queue_free() calls.
		# Stop the old pawn immediately so it never reads an already released camera.
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.set_process(false)
		player.set_physics_process(false)
		# The native player keeps these top-level helpers beside itself in the
		# current scene. They must follow the pawn when a chapter is unloaded.
		var external_player_nodes: Array[Node] = []
		for candidate: Node in [player.camera_yaw, player.sword_trail, player.debug_blade_mesh, player.debug_sweep_mesh_instance]:
			if candidate != null and is_instance_valid(candidate):
				external_player_nodes.append(candidate)
		for external_node: Node in external_player_nodes:
			external_node.queue_free()
	nodes_by_id.clear()
	enemies_by_group.clear()
	initial_group_counts.clear()
	preview_character_count = 0
	player = null
	crowd_director = null
	enemy_v2_troop_runtime = null
	v2_terrain_surfaces.clear()
	navigation_bake_revision += 1
	navigation_region = null
	navigation_mesh = null
	navigation_source_geometry = null
	encounter_budget = null
	world_environment = null
	sun = null
	if world_root != null and is_instance_valid(world_root):
		world_root.queue_free()
	world_root = null


func _build_runtime_navigation() -> void:
	# The Forge owns the level geometry, so it also owns the common ground map.
	# Creating the region before enemies are spawned lets every terrestrial unit
	# select NAVMESH_GROUND in _ready(); baking itself happens after all static
	# Forge collision shapes exist and never blocks the gameplay thread.
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.agent_radius = 0.50
	navigation_mesh.agent_height = 2.00
	navigation_mesh.agent_max_climb = 0.50
	navigation_mesh.agent_max_slope = 46.0
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_collision_mask = 1
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "WorldNavigationRegion"
	navigation_region.navigation_layers = 1
	navigation_region.navigation_mesh = navigation_mesh
	navigation_region.add_to_group("enemy_navigation_region")
	world_root.add_child(navigation_region)


func _request_runtime_navigation_rebake() -> void:
	if editing or navigation_region == null or not is_instance_valid(navigation_region) or world_root == null:
		return
	navigation_bake_revision += 1
	var revision := navigation_bake_revision
	call_deferred(&"_parse_runtime_navigation_geometry", revision)


func _parse_runtime_navigation_geometry(revision: int) -> void:
	if revision != navigation_bake_revision or navigation_region == null or not is_instance_valid(navigation_region) or world_root == null:
		return
	navigation_source_geometry = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		navigation_mesh,
		navigation_source_geometry,
		world_root,
		_on_runtime_navigation_geometry_parsed.bind(revision)
	)


func _on_runtime_navigation_geometry_parsed(revision: int) -> void:
	if revision != navigation_bake_revision or navigation_source_geometry == null or navigation_mesh == null:
		return
	NavigationServer3D.bake_from_source_geometry_data_async(
		navigation_mesh,
		navigation_source_geometry,
		_on_runtime_navigation_baked.bind(revision)
	)


func _on_runtime_navigation_baked(revision: int) -> void:
	if revision != navigation_bake_revision or navigation_region == null or not is_instance_valid(navigation_region) or navigation_mesh == null:
		return
	# Reassigning publishes the freshly baked polygons to the region RID even on
	# renderers/platforms that do not emit a resource-changed notification here.
	navigation_region.navigation_mesh = navigation_mesh

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_root.add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "WorldSun"
	sun.shadow_enabled = not editing
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	world_root.add_child(sun)
	apply_atmosphere(document.data.get("atmosphere", {}) as Dictionary)

func apply_atmosphere(values: Dictionary) -> void:
	if world_environment == null or sun == null:
		return
	values = AtmosphereCatalogScript.normalized(values)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var horizon_color := _color(values.get("sky_horizon", "#d8ad78"), Color("d8ad78"))
	var sky_path := AtmosphereCatalogScript.sky_path(String(values.get("sky_id", "procedural")))
	if not sky_path.is_empty() and ResourceLoader.exists(sky_path):
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(sky_path) as Texture2D
		sky.sky_material = panorama
	else:
		var procedural := ProceduralSkyMaterial.new()
		procedural.sky_top_color = _color(values.get("sky_top", "#263850"), Color("263850"))
		procedural.sky_horizon_color = horizon_color
		procedural.ground_bottom_color = Color(0.05, 0.045, 0.04)
		procedural.ground_horizon_color = horizon_color.darkened(0.46)
		procedural.sun_angle_max = 22.0
		sky.sky_material = procedural
	environment.sky = sky
	environment.sky_rotation = Vector3(0.0, deg_to_rad(float(values.get("sky_rotation", 0.0))), 0.0)
	environment.background_energy_multiplier = float(values.get("background_energy", 1.0))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if not sky_path.is_empty() else Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = horizon_color.lightened(0.12)
	environment.ambient_light_energy = float(values.get("ambient_energy", 0.72))
	environment.ambient_light_sky_contribution = float(values.get("sky_contribution", 0.72))
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = float(values.get("exposure", 1.08))
	environment.adjustment_enabled = true
	environment.adjustment_saturation = float(values.get("saturation", 1.0))
	environment.adjustment_contrast = float(values.get("contrast", 1.0))
	var fog := float(values.get("fog_density", 0.006))
	environment.fog_enabled = fog > 0.0001
	environment.fog_density = fog
	environment.fog_height = float(values.get("fog_height", 0.0))
	environment.fog_height_density = float(values.get("fog_height_density", 0.0))
	environment.fog_aerial_perspective = float(values.get("fog_aerial_perspective", 0.35))
	environment.fog_sky_affect = float(values.get("fog_sky_affect", 0.35))
	environment.fog_light_color = _color(values.get("fog_color", values.get("sky_horizon", "#d8ad78")), horizon_color)
	environment.fog_light_energy = float(values.get("fog_light_energy", 0.55))
	world_environment.environment = environment
	sun.rotation_degrees = Vector3(float(values.get("sun_rotation_x", -48.0)), float(values.get("sun_rotation_y", -28.0)), 0.0)
	sun.light_color = _color(values.get("sun_color", "#f9dfb2"), horizon_color.lightened(0.18))
	sun.light_energy = float(values.get("sun_energy", 1.15))

func _build_test_player() -> void:
	var spawn_position := portion_center + Vector3(0, 0.1, 6.0)
	var fallback_spawn := spawn_position
	var found_fallback := false
	var matched_requested := requested_spawn_id.is_empty()
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) == "player_spawn" and _inside_portion(entity):
			var candidate_position := WorldDocumentScript.vector3(entity.get("position", []))
			if not found_fallback:
				fallback_spawn = candidate_position
				found_fallback = true
			var properties := entity.get("properties", {}) as Dictionary
			if requested_spawn_id.is_empty() or requested_spawn_id in [String(properties.get("spawn_id", "")), String(entity.get("id", "")), String(entity.get("name", ""))]:
				spawn_position = candidate_position
				matched_requested = true
				break
	if not matched_requested and found_fallback:
		spawn_position = fallback_spawn
	player = PlayerScript.new() as HopliteUALNativePlayer
	player.name = "WorldTestPlayer"
	player.position = spawn_position
	world_root.add_child(player)

func _build_entity(entity: Dictionary) -> Node3D:
	match String(entity.get("type", "")):
		"terrain": return _build_terrain(entity)
		"surface": return _build_surface(entity)
		"prop": return _build_prop(entity)
		"water": return _build_water(entity)
		"fire": return _build_fire(entity)
		"light": return _build_light(entity)
		"enemy_group": return _build_enemy_group(entity)
		"patrol_point": return _build_patrol_point(entity)
		"trigger": return _build_trigger(entity)
		"door": return _build_door(entity)
		"chapter_portal": return _build_chapter_portal(entity)
		"narrative": return _build_narrative(entity)
		"atmosphere_zone": return _build_atmosphere_zone(entity)
		"player_spawn": return _build_player_spawn(entity) if editing else null
		_: return null

func _build_terrain(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var body := StaticBody3D.new()
	body.name = _safe_name(entity)
	_configure_entity_node(body, entity)
	WorldTerrainScript.rebuild_body(body, properties, MaterialLibraryScript.terrain_material(properties))
	WorldTerrainFoliageScript.rebuild(body, properties, editing)
	world_root.add_child(body)
	return body

func _build_surface(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var size := WorldDocumentScript.vector3(properties.get("size", [4, 1, 4]), Vector3(4, 1, 4))
	var body := StaticBody3D.new()
	body.name = _safe_name(entity)
	_configure_entity_node(body, entity)
	body.collision_layer = 1
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = MaterialLibraryScript.material(StringName(properties.get("material", "pavers")))
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world_root.add_child(body)
	return body

func _build_prop(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	# Scanned catalogue assets carry an explicit path but no legacy asset_id.
	# Keeping "crates" as an implicit id here made flowers inherit the crate
	# collider before their path-based vegetation defaults could be evaluated.
	var asset_id := StringName(properties.get("asset_id", ""))
	var path := AssetCatalogScript.migrate_asset_path(String(properties.get("asset_path", "")))
	if path.is_empty():
		if asset_id.is_empty():
			asset_id = &"crates"
		path = AssetCatalogScript.visual_path(asset_id, false)
	var pickup_item: HopliteEquipmentItemData = EquipmentCatalogScript.item_for_visual_path(path)
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	var entity_scale := holder.scale
	holder.scale = Vector3.ONE
	world_root.add_child(holder)
	var editor_visual_bounds := AABB(Vector3(-0.7, 0.0, -0.7), Vector3(1.4, maxf(1.0, float(properties.get("target_height", AssetCatalogScript.target_height(asset_id)))), 1.4))
	var collision_bounds := _scaled_aabb(editor_visual_bounds, entity_scale)
	var visual_transform := Transform3D(Basis.from_scale(entity_scale), Vector3.ZERO)
	var prop_visual: Node3D
	var packed := RuntimeGLTFCacheScript.scene(path)
	if packed != null:
		var visual := packed.instantiate() as Node3D
		if visual != null:
			prop_visual = visual
			holder.add_child(visual)
			_configure_prop_activity(visual, path)
			var use_support_percentile := path.contains("/stylized_nature/rocks/") or path.contains("/stylized_nature/stone_paths/")
			_fit_visual_to_height(visual, float(properties.get("target_height", AssetCatalogScript.target_height(asset_id))), use_support_percentile)
			visual.position.y += float(properties.get("ground_offset", 0.0))
			var measured_editor_bounds := _node_bounds_in_root(holder, visual)
			if measured_editor_bounds.size.length_squared() > 0.0001:
				editor_visual_bounds = measured_editor_bounds
			visual.transform = Transform3D(Basis.from_scale(entity_scale), Vector3.ZERO) * visual.transform
			visual_transform = visual.transform
			var measured_collision_bounds := _node_bounds_in_root(holder, visual)
			if measured_collision_bounds.size.length_squared() > 0.0001:
				collision_bounds = measured_collision_bounds
	var definition := AssetCatalogScript.definition(asset_id)
	var default_collision_enabled := AssetCatalogScript.default_collision_enabled_for_path(path, asset_id)
	# Forge equipment remains a regular editable prop in edit mode. In play mode,
	# keep the fitted visual but replace its blocking collider with a pickup area.
	var is_runtime_equipment_pickup := not editing and pickup_item != null
	if not is_runtime_equipment_pickup and bool(properties.get("collision_enabled", default_collision_enabled)):
		var fitted_definition := definition.duplicate(true)
		var has_explicit_shape := properties.has("collision_shape") or definition.is_empty()
		var collision_kind := String(properties.get("collision_shape", AssetCatalogScript.default_collision_shape_for_path(path, asset_id)))
		fitted_definition["collision"] = collision_kind
		var convex_cache_key := "%s|%.4f|%.4f|%.4f|%.4f|%.4f" % [path, float(properties.get("target_height", 2.0)), float(properties.get("ground_offset", 0.0)), entity_scale.x, entity_scale.y, entity_scale.z]
		var gameplay_collision_bounds := collision_bounds
		if collision_kind == "cylinder" and AssetCatalogScript.is_tree_asset(path, asset_id):
			var tree_definition := AssetCatalogScript.definition_for_path(path, asset_id)
			gameplay_collision_bounds = _tree_trunk_collision_bounds(
				holder,
				prop_visual,
				collision_bounds,
				tree_definition,
				float(properties.get("target_height", AssetCatalogScript.target_height(asset_id))),
				entity_scale,
				convex_cache_key
			)
			fitted_definition["collision_source"] = "tree_trunk"
			has_explicit_shape = true
		_add_catalog_collision(holder, fitted_definition, gameplay_collision_bounds, has_explicit_shape, convex_cache_key, path, visual_transform)
	if is_runtime_equipment_pickup:
		_add_equipment_pickup(holder, pickup_item)
	holder.set_meta("editor_local_bounds", editor_visual_bounds)
	holder.set_meta("editor_ground_anchor_offset", 0.0)
	_add_selection_collider(holder, collision_bounds.size, collision_bounds.get_center())
	return holder

func _add_equipment_pickup(holder: Node3D, item: HopliteEquipmentItemData) -> void:
	var pickup := EquipmentPickupScript.new() as HopliteEquipmentPickup
	pickup.name = "EquipmentPickup_%s" % String(item.item_id)
	pickup.equipment = item
	pickup.create_visual = false
	pickup.collect_target = holder
	holder.set_meta("equipment_item_id", item.item_id)
	holder.add_child(pickup)

func _build_water(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var size := WorldDocumentScript.vector3(properties.get("size", [12.0, 0.08, 12.0]), Vector3(12.0, 0.08, 12.0))
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WaterSurface"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size.x, size.z)
	mesh.subdivide_width = clampi(roundi(size.x * 0.5), 2, 32)
	mesh.subdivide_depth = clampi(roundi(size.z * 0.5), 2, 32)
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("shallow_color", _color(properties.get("shallow_color", "#167e93"), Color("167e93")))
	material.set_shader_parameter("deep_color", _color(properties.get("deep_color", "#062b4a"), Color("062b4a")))
	var water_texture_id := StringName(properties.get("texture", "none"))
	if water_texture_id != &"none":
		var water_texture := MaterialLibraryScript.albedo_texture(water_texture_id)
		if water_texture != null:
			material.set_shader_parameter("surface_texture", water_texture)
			material.set_shader_parameter("use_surface_texture", true)
	material.set_shader_parameter("texture_scale", float(properties.get("texture_scale", 4.0)))
	material.set_shader_parameter("texture_strength", float(properties.get("texture_strength", 0.18)))
	material.set_shader_parameter("opacity", float(properties.get("opacity", 0.68)))
	material.set_shader_parameter("wave_scale", float(properties.get("wave_scale", 0.55)))
	material.set_shader_parameter("wave_speed", float(properties.get("wave_speed", 0.7)))
	material.set_shader_parameter("wave_height", float(properties.get("wave_height", 0.08)))
	material.set_shader_parameter("roughness_value", float(properties.get("roughness", 0.18)))
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	holder.add_child(mesh_instance)
	holder.set_meta("editor_local_bounds", AABB(Vector3(-size.x * 0.5, -0.12, -size.z * 0.5), Vector3(size.x, 0.24, size.z)))
	var fauna_blocker := FaunaWaterBlockerScript.new() as HopliteFaunaWaterBlocker
	fauna_blocker.name = "FaunaWaterBlocker"
	holder.add_child(fauna_blocker)
	fauna_blocker.configure(Vector2(size.x, size.z), maxf(0.45, float(properties.get("wave_height", 0.08)) + 0.35))
	_add_selection_collider(holder, Vector3(size.x, maxf(0.16, size.y), size.z), Vector3.ZERO)
	return holder

func _build_fire(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var fire_size := float(properties.get("size", 1.0))
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	var particles := GPUParticles3D.new()
	particles.name = "OptimizedFire"
	particles.amount = clampi(int(properties.get("amount", 48)), 8, 128)
	particles.lifetime = float(properties.get("lifetime", 1.15))
	particles.fixed_fps = 30
	particles.preprocess = particles.lifetime
	particles.randomness = 0.45
	particles.visibility_aabb = AABB(Vector3(-fire_size, -0.2, -fire_size), Vector3(fire_size * 2.0, fire_size * 3.2, fire_size * 2.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = fire_size * 0.18
	process.direction = Vector3.UP
	process.spread = 18.0
	process.initial_velocity_min = fire_size * 0.9
	process.initial_velocity_max = fire_size * 1.7
	process.gravity = Vector3(0.0, fire_size * 0.35, 0.0)
	process.scale_min = fire_size * 0.35
	process.scale_max = fire_size * 0.72
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 1.35)
	var fire_material := ShaderMaterial.new()
	fire_material.shader = FIRE_SHADER
	fire_material.set_shader_parameter("core_color", _color(properties.get("core_color", "#ffdc52"), Color("ffdc52")))
	fire_material.set_shader_parameter("edge_color", _color(properties.get("edge_color", "#ff3608"), Color("ff3608")))
	quad.material = fire_material
	particles.draw_pass_1 = quad
	holder.add_child(particles)
	if bool(properties.get("light_enabled", false)):
		var light := OmniLight3D.new()
		light.name = "OptionalFireLight"
		light.light_color = _color(properties.get("edge_color", "#ff3608"), Color("ff6a20"))
		light.light_energy = float(properties.get("light_energy", 1.8))
		light.omni_range = float(properties.get("light_range", 7.0))
		light.shadow_enabled = false
		holder.add_child(light)
	holder.set_meta("editor_local_bounds", AABB(Vector3(-fire_size * 0.7, 0.0, -fire_size * 0.7), Vector3(fire_size * 1.4, fire_size * 2.4, fire_size * 1.4)))
	_add_selection_collider(holder, Vector3(fire_size * 1.4, fire_size * 2.4, fire_size * 1.4), Vector3(0.0, fire_size * 1.2, 0.0))
	return holder

func _build_light(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	var kind := String(properties.get("light_type", "omni"))
	var light: Light3D
	if kind == "spot":
		var spot := SpotLight3D.new()
		spot.spot_range = float(properties.get("range", 12.0))
		spot.spot_angle = float(properties.get("angle", 42.0))
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = float(properties.get("range", 12.0))
		light = omni
	light.light_color = _color(properties.get("color", "#ffb36b"), Color("ffb36b"))
	light.light_energy = float(properties.get("energy", 2.0))
	light.shadow_enabled = not editing and bool(properties.get("shadows", false))
	holder.add_child(light)
	if editing:
		_add_icon(holder, Color(1.0, 0.68, 0.2), "LUMIERE", 0.28)
		_add_selection_collider(holder, Vector3.ONE)
	return holder

func _build_enemy_group(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	var group_id := String(properties.get("group_id", entity.get("id", "group")))
	var count := clampi(int(properties.get("count", 1)), 0, 500)
	initial_group_counts[group_id] = int(initial_group_counts.get(group_id, 0)) + count
	if editing:
		_build_enemy_preview(holder, entity, count)
		return holder
	_queue_enemy_group_spawn(entity, player, holder, count)
	return holder

func _queue_enemy_group_spawn(entity: Dictionary, target: Node3D, holder: Node3D, count: int) -> void:
	if count <= 0:
		return
	var spawned: Array[Node] = []
	pending_enemy_spawns.append({
		"entity": entity,
		"target": target,
		"holder": holder,
		"next_index": 0,
		"total_count": count,
		"spawned": spawned,
	})
	set_process(true)

func spawn_enemy_group(entity: Dictionary, target: Node3D, existing_holder: Node3D = null, count_override: int = -1, start_index: int = 0, configure_behavior: bool = true) -> Array[Node]:
	var properties := entity.get("properties", {}) as Dictionary
	var holder := existing_holder
	if holder == null:
		holder = Node3D.new()
		holder.name = _safe_name(entity)
		_configure_entity_node(holder, entity)
		world_root.add_child(holder)
		nodes_by_id[String(entity.get("id", ""))] = holder
	var group_id := String(properties.get("group_id", entity.get("id", "group")))
	var total_count := clampi(int(properties.get("count", 1)), 0, 500)
	var effective_v2_troop_mode := _effective_v2_troop_mode(properties, total_count)
	var planned_population: int = int(encounter_budget.planned_population_for(entity)) if encounter_budget != null else total_count
	var count := total_count - start_index if count_override < 0 else mini(count_override, total_count - start_index)
	count = maxi(0, count)
	var formation_positions := _enemy_formation_positions(properties, maxi(total_count, count))
	var spawned: Array[Node] = []
	for index in range(count):
		var unit_index := start_index + index
		var archetype := _enemy_archetype_for_index(properties, unit_index)
		if not HopliteV2CatalogScript.is_forge_archetype(archetype) and String(properties.get("rank", "normal")) == "miniboss" and not EnemyArchetypesScript.is_miniboss(archetype) and not EnemyArchetypesScript.is_boss(archetype):
			archetype = &"captain"
		var unit_position := formation_positions[unit_index % formation_positions.size()] if not formation_positions.is_empty() else Vector3.ZERO
		var spawn_options := {
			"name": "%s_%02d" % [group_id, unit_index + 1], "ai_enabled": true,
			"performance_profile": String(properties.get("performance_profile", "auto")),
			"planned_simultaneous_population": planned_population, "guard_index": unit_index,
			"scale_multiplier": float(properties.get("size_multiplier", 1.0)),
			"v2_animation": StringName(properties.get("v2_animation", &"idle")),
			"v2_combat_lab": bool(properties.get("v2_combat_lab", false)),
			"v2_troop_mode": effective_v2_troop_mode,
			"formation_unit_index": unit_index,
			"match_perfect_hitbox": bool(properties.get("match_perfect_hitbox", false)),
			"giant_traversal_mode": StringName(properties.get("giant_traversal_mode", "assisted")),
			"giant_capsule_radius_multiplier": float(properties.get("giant_capsule_radius_multiplier", 0.90)),
			"giant_capsule_height_multiplier": float(properties.get("giant_capsule_height_multiplier", 1.0)),
			"giant_walkable_tops": bool(properties.get("giant_walkable_tops", true))
		}
		if String(properties.get("formation", "line")) == "phalanx":
			var columns := clampi(int(properties.get("formation_columns", 8)), 2, maxi(2, total_count))
			var spacing := maxf(0.5, float(properties.get("formation_spacing", _enemy_formation_spacing(properties))))
			var rank_spacing := maxf(0.55, float(properties.get("formation_rank_spacing", spacing * 0.72)))
			spawn_options["formation_column"] = roundi(unit_position.x / spacing + float(columns - 1) * 0.5)
			var rank_direction := -1.0 if not effective_v2_troop_mode.is_empty() else 1.0
			spawn_options["formation_row"] = roundi(unit_position.z / (rank_spacing * rank_direction))
		var enemy := _spawn_forge_enemy(holder, archetype, unit_position, target, spawn_options)
		if enemy == null:
			continue
		enemy.set_meta("world_entity_id", String(entity.get("id", "")))
		enemy.set_meta("world_group_id", group_id)
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died.bind(group_id))
		spawned.append(enemy)
		if not enemies_by_group.has(group_id):
			enemies_by_group[group_id] = []
		(enemies_by_group[group_id] as Array).append(enemy)
		enemy.set_meta("formation_group", StringName(group_id))
		enemy_spawned.emit(enemy, group_id)
	if configure_behavior:
		_configure_group_behavior(spawned, entity, target)
	return spawned

func remove_enemy_group(group_id: String) -> int:
	if enemy_v2_troop_runtime != null:
		enemy_v2_troop_runtime.remove_group(StringName(group_id))
	var removed := 0
	for raw: Variant in enemies_by_group.get(group_id, []):
		var enemy := raw as Node
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
			removed += 1
	enemies_by_group[group_id] = []
	return removed

func living_count(group_id: String) -> int:
	var result := 0
	var enemies := enemies_by_group.get(group_id, []) as Array
	for index in range(enemies.size() - 1, -1, -1):
		var raw: Variant = enemies[index]
		# A corpse can outlive gameplay and later free itself on its TTL. Validate
		# the Variant before casting it, because casting a freed Object raises
		# "Trying to cast a freed object" before a Node-level guard can run.
		if typeof(raw) != TYPE_OBJECT or not is_instance_valid(raw):
			enemies.remove_at(index)
			continue
		if not (raw is Node):
			enemies.remove_at(index)
			continue
		var enemy := raw as Node
		if not bool(enemy.get("dead")):
			result += 1
	return result

func _build_enemy_preview(holder: Node3D, entity: Dictionary, count: int) -> void:
	var properties := entity.get("properties", {}) as Dictionary
	var shown := mini(count, PREVIEW_FORMATION_LIMIT)
	var positions := _enemy_formation_positions(properties, shown)
	var rank := String(properties.get("rank", "normal"))
	for index in range(shown):
		var archetype := _enemy_archetype_for_index(properties, index)
		var profile := _enemy_profile(archetype)
		var is_veteran := StringName(profile.get("behavior", &"")) == &"phalanx_veteran"
		var color := Color(0.88, 0.24, 0.16) if rank == "miniboss" else (Color(0.92, 0.65, 0.18) if is_veteran else Color(0.20, 0.48, 0.88))
		if index == 0 and preview_character_count < PREVIEW_CHARACTER_LIMIT:
			if not HopliteV2CatalogScript.is_forge_archetype(archetype) and rank == "miniboss" and not EnemyArchetypesScript.is_miniboss(archetype) and not EnemyArchetypesScript.is_boss(archetype):
				archetype = &"captain"
			var preview_options := {
				"ai_enabled": false,
				"name": "Apercu",
				"scale_multiplier": float(properties.get("size_multiplier", 1.0)),
				"v2_animation": StringName(properties.get("v2_animation", &"idle")),
				"match_perfect_hitbox": bool(properties.get("match_perfect_hitbox", false)),
				"giant_traversal_mode": StringName(properties.get("giant_traversal_mode", "assisted")),
				"giant_capsule_radius_multiplier": float(properties.get("giant_capsule_radius_multiplier", 0.90)),
				"giant_capsule_height_multiplier": float(properties.get("giant_capsule_height_multiplier", 1.0)),
				"giant_walkable_tops": bool(properties.get("giant_walkable_tops", true))
			}
			var enemy := _spawn_forge_enemy(holder, archetype, positions[index], null, preview_options)
			if enemy != null:
				enemy.process_mode = Node.PROCESS_MODE_DISABLED
				enemy.set_meta("world_entity_id", String(entity.get("id", "")))
				preview_character_count += 1
				continue
		var marker := _capsule_marker(color, float(properties.get("size_multiplier", 1.0)))
		marker.position = positions[index]
		marker.set_meta("world_entity_id", String(entity.get("id", "")))
		holder.add_child(marker)
	var label := Label3D.new()
	label.text = "%s  x%d\n%s • %s" % [String(entity.get("name", "Groupe")), count, String(properties.get("behavior", "normal")).to_upper(), String(properties.get("archetype", ""))]
	label.position = Vector3(0, 3.1, 0)
	label.font_size = 34
	label.outline_size = 8
	label.modulate = Color.WHITE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holder.add_child(label)
	var formation_min := Vector3.ZERO
	var formation_max := Vector3.ZERO
	if not positions.is_empty():
		formation_min = positions[0]
		formation_max = positions[0]
		for formation_position in positions:
			formation_min.x = minf(formation_min.x, formation_position.x)
			formation_min.z = minf(formation_min.z, formation_position.z)
			formation_max.x = maxf(formation_max.x, formation_position.x)
			formation_max.z = maxf(formation_max.z, formation_position.z)
	var selection_size := Vector3(maxf(2.4, formation_max.x - formation_min.x + 1.8), 2.8, maxf(2.4, formation_max.z - formation_min.z + 1.8))
	var selection_center := Vector3((formation_min.x + formation_max.x) * 0.5, selection_size.y * 0.5, (formation_min.z + formation_max.z) * 0.5)
	holder.set_meta("editor_local_bounds", AABB(selection_center - selection_size * 0.5, selection_size))
	_add_selection_collider(holder, selection_size, selection_center)


func _spawn_forge_enemy(parent: Node, archetype: StringName, position_value: Vector3, target: Node3D, options: Dictionary) -> Node3D:
	if not HopliteV2CatalogScript.is_forge_archetype(archetype):
		return EnemyFactoryScript.spawn(parent, archetype, position_value, target, options)
	var source_archetype := HopliteV2CatalogScript.source_archetype_for(archetype)
	var actor := HopliteV2ShadowFactoryScript.create(source_archetype)
	if actor == null:
		push_error("Forge could not create Enemy V2 laboratory actor: %s" % archetype)
		return null
	actor.name = String(options.get("name", HopliteV2CatalogScript.forge_display_name(archetype)))
	actor.position = position_value
	if actor.has_method("set_visual_scale"):
		actor.call("set_visual_scale", maxf(0.35, float(options.get("scale_multiplier", 3.0))))
	else:
		actor.scale = Vector3.ONE * maxf(0.01, float(options.get("scale_multiplier", 1.0)) * actor.definition.visual_scale)
	actor.initial_semantic = StringName(options.get("v2_animation", &"idle"))
	actor.lod_reference = target
	actor.combat_lab_enabled = bool(options.get("v2_combat_lab", false)) and bool(options.get("ai_enabled", false))
	actor.combat_target = target if actor.combat_lab_enabled else null
	actor.troop_controlled = not StringName(options.get("v2_troop_mode", &"")).is_empty()
	actor.set_meta("forge_archetype", archetype)
	actor.set_meta("forge_source_archetype", source_archetype)
	actor.set_meta("formation_unit_index", int(options.get("formation_unit_index", 0)))
	actor.set_meta("formation_row", int(options.get("formation_row", 0)))
	actor.set_meta("formation_column", int(options.get("formation_column", 0)))
	# Equipment is installed during _ready(), so the shield must already know
	# whether this actor belongs to a true phalanx when its hitbox is configured.
	actor.set_meta("enemy_v2_troop_mode", StringName(options.get("v2_troop_mode", &"")))
	parent.add_child(actor)
	actor.set_meta("enemy_runtime_generation", &"modular_v2_forge_lab")
	actor.set_meta("forge_enemy_v2", true)
	return actor


func _enemy_profile(archetype: StringName) -> Dictionary:
	var source := HopliteV2CatalogScript.source_archetype_for(archetype)
	if source in [&"archer_v2", &"infantry_v2"]:
		return EnemyArchetypesScript.profile(&"ngeneral")
	if archetype == &"enemy_v2_giant":
		return {"scale": 1.0, "formation_spacing": 6.5}
	return EnemyArchetypesScript.profile(source)


func _effective_v2_troop_mode(properties: Dictionary, member_count: int) -> StringName:
	var authored_mode := StringName(properties.get("v2_troop_mode", &""))
	if not authored_mode.is_empty():
		return authored_mode
	var role_source := HopliteV2CatalogScript.source_archetype_for(StringName(properties.get("archetype", &"")))
	if bool(properties.get("v2_combat_lab", false)):
		if role_source == &"archer_v2": return &"archer"
		if role_source == &"infantry_v2": return &"infantry"
		if StringName(properties.get("archetype", &"")) == &"enemy_v2_giant": return &"giant"
	if member_count <= 1 or not bool(properties.get("v2_combat_lab", false)):
		return &""
	var composition := properties.get("composition", []) as Array
	if composition.is_empty():
		return &"hoplite_skirmish" if HopliteV2CatalogScript.is_forge_archetype(StringName(properties.get("archetype", &""))) else &""
	for raw_entry: Variant in composition:
		if not raw_entry is Dictionary:
			return &""
		var entry := raw_entry as Dictionary
		if not HopliteV2CatalogScript.is_forge_archetype(StringName(entry.get("archetype", &""))):
			return &""
	return &"hoplite_skirmish"

func _configure_group_behavior(enemies: Array[Node], entity: Dictionary, target_override: Node3D = null) -> void:
	var properties := entity.get("properties", {}) as Dictionary
	var effective_mode := _effective_v2_troop_mode(properties, enemies.size())
	if (
		enemy_v2_troop_runtime != null
		and not effective_mode.is_empty()
		and not enemies.is_empty()
	):
		var group_id := StringName(properties.get("group_id", entity.get("id", "group")))
		var troop_target := target_override if target_override != null else player
		var runtime_properties := properties.duplicate(true)
		if bool(properties.get("v2_persistent_fronts", false)):
			if v2_terrain_surfaces.is_empty() and document != null:
				for raw_surface: Variant in document.data.get("entities", []):
					if raw_surface is Dictionary and raw_surface.get("type") == "terrain" and bool(raw_surface.get("enabled", true)):
						var surface_properties: Dictionary = raw_surface.get("properties", {})
						if (surface_properties.get("heights", []) as Array).size() != int(surface_properties.get("resolution", 0)) ** 2:
							continue
						var surface_transform := Transform3D(Basis.from_euler(WorldDocumentScript.vector3(raw_surface.get("rotation", [])) * PI / 180.0).scaled(WorldDocumentScript.vector3(raw_surface.get("scale", [1,1,1]))), WorldDocumentScript.vector3(raw_surface.get("position", [])))
						v2_terrain_surfaces.append({"properties": surface_properties, "transform": surface_transform, "inverse": surface_transform.affine_inverse()})
			enemy_v2_troop_runtime.terrain_height_sampler = _sample_v2_terrain_height
		runtime_properties["v2_troop_mode"] = effective_mode
		enemy_v2_troop_runtime.register_group(group_id, enemies, troop_target, runtime_properties, effective_mode)
	var behavior := String(properties.get("behavior", "normal"))
	if behavior == "patrol":
		var route := _patrol_route(String(properties.get("route_id", "")))
		for index in range(enemies.size()):
			var enemy := enemies[index] as Node3D
			if enemy != null and enemy.has_method("configure_demo_patrol"):
				var personal_route := route.duplicate()
				if not personal_route.is_empty():
					var home := enemy.global_position
					if personal_route[-1].distance_squared_to(home) > 0.01:
						personal_route.append(home)
				var authored_phase := posmod(index, route.size()) if not route.is_empty() else 0
				enemy.call("configure_demo_patrol", personal_route, authored_phase, _enemy_engage_distance(properties), float(properties.get("patrol_speed", 2.0)))
	elif behavior == "wait":
		for enemy: Node in enemies:
			if bool(enemy.get_meta("forge_enemy_v2", false)):
				continue
			enemy.set("training_activation_pending", true)
			enemy.set("training_activation_center", (enemy as Node3D).global_position)
			enemy.set("training_activation_radius", _enemy_engage_distance(properties))

func _resolve_protect_targets() -> void:
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) != "enemy_group":
			continue
		var properties := entity.get("properties", {}) as Dictionary
		if String(properties.get("behavior", "")) != "protect":
			continue
		var target := _resolve_protect_target_node(String(properties.get("protect_target", "")))
		if target == null:
			continue
		var group_id := String(properties.get("group_id", ""))
		for index in range((enemies_by_group.get(group_id, []) as Array).size()):

			var enemy := (enemies_by_group[group_id] as Array)[index] as Node
			if bool(enemy.get_meta("forge_enemy_v2", false)):
				continue
			enemy.set("ai_miniboss", target)
			enemy.set("ai_guard_index", index)

func _resolve_protect_target_node(target_key: String) -> Node3D:
	if target_key.is_empty():
		return null
	var direct_entity := document.find_entity(target_key)
	if direct_entity.is_empty():
		direct_entity = document.find_by_name(target_key)
	if not direct_entity.is_empty() and String(direct_entity.get("type", "")) != "enemy_group":
		return nodes_by_id.get(String(direct_entity.get("id", ""))) as Node3D
	for enemy_entity: Dictionary in document.enemy_entities_for_reference(target_key, active_chapter_id):
		var target_properties := enemy_entity.get("properties", {}) as Dictionary
		var group_id := String(target_properties.get("group_id", ""))
		for raw_enemy: Variant in enemies_by_group.get(group_id, []):
			var enemy := raw_enemy as Node3D
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.has_method("is_dead_for_combat") and bool(enemy.call("is_dead_for_combat")):
				continue
			return enemy
		var holder := nodes_by_id.get(String(enemy_entity.get("id", ""))) as Node3D
		if holder != null:
			return holder
	if not direct_entity.is_empty():
		return nodes_by_id.get(String(direct_entity.get("id", ""))) as Node3D
	return null

func refresh_protect_targets() -> void:
	_resolve_protect_targets()

func _build_patrol_point(entity: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	if editing:
		var properties := entity.get("properties", {}) as Dictionary
		_add_icon(holder, Color(0.22, 0.86, 0.65), "%s  #%d" % [String(properties.get("route_id", "route")), int(properties.get("order", 0)) + 1], 0.34)
		_add_selection_collider(holder, Vector3.ONE)
	return holder

func _build_trigger(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var size := WorldDocumentScript.vector3(properties.get("size", [5, 3, 5]), Vector3(5, 3, 5))
	var area := Area3D.new()
	area.name = _safe_name(entity)
	_configure_entity_node(area, entity)
	area.collision_layer = 16 if editing else 0
	area.collision_mask = 2
	area.monitoring = not editing
	area.monitorable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	world_root.add_child(area)
	if String(properties.get("condition", "player_enter")) == "player_enter" and not editing:
		area.body_entered.connect(_on_trigger_body_entered.bind(String(entity.get("id", ""))))
	if editing:
		_add_zone_visual(area, size, Color(0.90, 0.30, 0.72, 0.25), "EVENT • %s" % String(properties.get("condition", "player_enter")).to_upper())
	return area

func _build_door(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var size := WorldDocumentScript.vector3(properties.get("size", [3.0, 4.0, 0.45]), Vector3(3.0, 4.0, 0.45))
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	var style := String(properties.get("door_style", "wood"))
	var motion := String(properties.get("open_motion", "pivot_left"))
	var leaf_pivot := Node3D.new()
	leaf_pivot.name = "DoorLeafPivot"
	holder.add_child(leaf_pivot)
	if motion in ["pivot_left", "pivot_right"]:
		leaf_pivot.position.x = -size.x * 0.5 if motion == "pivot_left" else size.x * 0.5
	var leaf_body := StaticBody3D.new()
	leaf_body.name = "DoorLeaf"
	leaf_body.collision_layer = 1
	leaf_body.position.x = size.x * 0.5 if motion == "pivot_left" else (-size.x * 0.5 if motion == "pivot_right" else 0.0)
	leaf_pivot.add_child(leaf_body)
	var leaf_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	leaf_mesh.mesh = box
	leaf_mesh.material_override = _door_material(style)
	leaf_body.add_child(leaf_mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	leaf_body.add_child(collision)
	_add_door_frame(holder, size, style)
	holder.set_meta("door_leaf_pivot", leaf_pivot)
	holder.set_meta("door_collision", collision)
	holder.set_meta("door_motion", motion)
	holder.set_meta("door_size", size)
	holder.set_meta("door_open", false)
	holder.set_meta("editor_local_bounds", AABB(Vector3(-size.x * 0.65, -size.y * 0.5, -size.z), Vector3(size.x * 1.3, size.y * 1.15, size.z * 2.0)))
	if editing:
		_add_selection_collider(holder, size, Vector3.ZERO)
	elif bool(properties.get("starts_open", false)):
		_apply_door_open_transform(holder, 1.0)
		collision.disabled = true
		holder.set_meta("door_open", true)
	return holder

func _add_door_frame(holder: Node3D, size: Vector3, style: String) -> void:
	var frame_material := _door_material("stone" if style == "stone" else "bronze")
	var thickness := maxf(0.18, minf(size.x, size.y) * 0.09)
	var frames: Array[Dictionary] = [
		{"position": Vector3(-size.x * 0.5 - thickness * 0.5, 0.0, 0.0), "size": Vector3(thickness, size.y + thickness, size.z * 1.6)},
		{"position": Vector3(size.x * 0.5 + thickness * 0.5, 0.0, 0.0), "size": Vector3(thickness, size.y + thickness, size.z * 1.6)},
		{"position": Vector3(0.0, size.y * 0.5 + thickness * 0.5, 0.0), "size": Vector3(size.x + thickness * 2.0, thickness, size.z * 1.6)}
	]
	for frame_data: Dictionary in frames:
		var frame := MeshInstance3D.new()
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = frame_data["size"]
		frame.mesh = frame_mesh
		frame.position = frame_data["position"]
		frame.material_override = frame_material
		holder.add_child(frame)

func _door_material(style: String) -> Material:
	if style == "stone":
		return MaterialLibraryScript.material(&"fortress")
	var material := StandardMaterial3D.new()
	match style:
		"iron":
			material.albedo_color = Color("303844")
			material.metallic = 0.82
			material.roughness = 0.34
		"bronze":
			material.albedo_color = Color("8f612c")
			material.metallic = 0.72
			material.roughness = 0.38
		_:
			material.albedo_color = Color("6f4124")
			material.metallic = 0.05
			material.roughness = 0.88
	return material

func open_door(reference: String) -> bool:
	var entity := document.find_entity(reference)
	if entity.is_empty():
		entity = document.find_by_name(reference)
	if entity.is_empty() or String(entity.get("type", "")) != "door" or String(entity.get("chapter", document.start_chapter())) != active_chapter_id:
		return false
	var holder := nodes_by_id.get(String(entity.get("id", ""))) as Node3D
	if holder == null or bool(holder.get_meta("door_open", false)):
		return holder != null
	holder.set_meta("door_open", true)
	var collision := holder.get_meta("door_collision") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	var properties := entity.get("properties", {}) as Dictionary
	var duration := maxf(0.05, float(properties.get("open_duration", 1.2)))
	var leaf_pivot := holder.get_meta("door_leaf_pivot") as Node3D
	if leaf_pivot == null:
		return false
	var motion := String(holder.get_meta("door_motion", "pivot_left"))
	var size := holder.get_meta("door_size") as Vector3
	var tween := holder.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Keep the RefCounted tween with its door until the animation completes.
	# This also makes it disappear automatically when a chapter is unloaded.
	holder.set_meta("door_tween", tween)
	var target_position := leaf_pivot.position
	var target_rotation := leaf_pivot.rotation
	match motion:
		"vertical":
			target_position.y += size.y + 0.25
			tween.tween_property(leaf_pivot, "position", target_position, duration)
		"slide_left":
			target_position.x -= size.x + 0.25
			tween.tween_property(leaf_pivot, "position", target_position, duration)
		"slide_right":
			target_position.x += size.x + 0.25
			tween.tween_property(leaf_pivot, "position", target_position, duration)
		"pivot_right":
			target_rotation.y = deg_to_rad(-95.0)
			tween.tween_property(leaf_pivot, "rotation", target_rotation, duration)
		_:
			target_rotation.y = deg_to_rad(95.0)
			tween.tween_property(leaf_pivot, "rotation", target_rotation, duration)
	return true

func _apply_door_open_transform(holder: Node3D, amount: float) -> void:
	var leaf_pivot := holder.get_meta("door_leaf_pivot") as Node3D
	if leaf_pivot == null:
		return
	var motion := String(holder.get_meta("door_motion", "pivot_left"))
	var size := holder.get_meta("door_size") as Vector3
	match motion:
		"vertical": leaf_pivot.position.y += (size.y + 0.25) * amount
		"slide_left": leaf_pivot.position.x -= (size.x + 0.25) * amount
		"slide_right": leaf_pivot.position.x += (size.x + 0.25) * amount
		"pivot_right": leaf_pivot.rotation.y = deg_to_rad(-95.0) * amount
		_: leaf_pivot.rotation.y = deg_to_rad(95.0) * amount

func _build_chapter_portal(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var size := WorldDocumentScript.vector3(properties.get("size", [3.0, 3.0, 1.5]), Vector3(3.0, 3.0, 1.5))
	var area := Area3D.new()
	area.name = _safe_name(entity)
	_configure_entity_node(area, entity)
	area.collision_layer = 16 if editing else 0
	area.collision_mask = 2
	area.monitoring = not editing
	area.monitorable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	world_root.add_child(area)
	if editing:
		_add_zone_visual(area, size, Color(0.20, 0.82, 0.95, 0.24), "CHAPITRE → %s" % String(properties.get("destination_chapter", "?")))
		# A dedicated body makes the whole cyan volume easy to select even when
		# another physics query is configured to ignore Area3D nodes.
		_add_selection_collider(area, size, Vector3.ZERO)
	else:
		var portal_mesh := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x, size.y, minf(0.12, size.z))
		portal_mesh.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.12, 0.70, 0.95, 0.48)
		material.emission_enabled = true
		material.emission = Color(0.08, 0.62, 1.0) * 1.8
		portal_mesh.material_override = material
		area.add_child(portal_mesh)
		area.body_entered.connect(_on_chapter_portal_entered.bind(String(properties.get("destination_chapter", "")), String(properties.get("destination_spawn", "")), area))
	return area

func _build_narrative(entity: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	if editing:
		var properties := entity.get("properties", {}) as Dictionary
		_add_icon(holder, Color(0.84, 0.45, 0.98), "NARRATION\n%s" % String(properties.get("speaker", "Narrateur")), 0.40)
		_add_selection_collider(holder, Vector3(1.2, 1.8, 1.2))
	return holder

func _build_atmosphere_zone(entity: Dictionary) -> Node3D:
	var properties := entity.get("properties", {}) as Dictionary
	var size := WorldDocumentScript.vector3(properties.get("size", [10, 5, 10]), Vector3(10, 5, 10))
	var area := Area3D.new()
	area.name = _safe_name(entity)
	_configure_entity_node(area, entity)
	area.collision_layer = 0
	area.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	world_root.add_child(area)
	if editing:
		_add_zone_visual(area, size, Color(0.18, 0.62, 0.90, 0.18), "ATMOSPHERE • %s" % String(properties.get("preset", "Zone")))
	else:
		area.body_entered.connect(_on_atmosphere_body_entered.bind(String(entity.get("id", ""))))
	return area

func _build_player_spawn(entity: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	_add_icon(holder, Color(0.18, 0.90, 0.40), "DEPART JOUEUR", 0.46)
	_add_selection_collider(holder, Vector3(1.2, 2.0, 1.2))
	return holder

func _configure_entity_node(node: Node3D, entity: Dictionary) -> void:
	node.position = WorldDocumentScript.vector3(entity.get("position", []))
	node.rotation_degrees = WorldDocumentScript.vector3(entity.get("rotation", []))
	node.scale = WorldDocumentScript.vector3(entity.get("scale", []), Vector3.ONE)
	node.set_meta("world_entity_id", String(entity.get("id", "")))

func _formation_positions(count: int, formation: String, spacing: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	spacing = maxf(0.5, spacing)
	for index in range(count):
		if formation == "circle":
			var radius := maxf(2.0, spacing * float(count) / TAU)
			var angle := TAU * float(index) / maxf(1.0, float(count))
			result.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
		elif formation == "line":
			result.append(Vector3((float(index) - float(count - 1) * 0.5) * spacing, 0, 0))
		elif formation == "column":
			result.append(Vector3(float(index % 2) * spacing - spacing * 0.5, 0, float(index / 2) * spacing))
		elif formation == "wedge":
			var rank := floori((sqrt(8.0 * float(index) + 1.0) - 1.0) * 0.5)
			var rank_start := rank * (rank + 1) / 2
			var slot := index - rank_start
			result.append(Vector3((float(slot) - float(rank) * 0.5) * spacing, 0, float(rank) * spacing))
		elif formation == "phalanx":
			var columns := mini(8, maxi(2, ceili(sqrt(float(count)) * 1.45)))
			result.append(Vector3((float(index % columns) - float(columns - 1) * 0.5) * spacing, 0, float(index / columns) * spacing * 0.72))
		elif formation == "arc":
			var arc_angle := lerpf(-PI * 0.62, PI * 0.62, float(index) / maxf(1.0, float(count - 1)))
			var arc_radius := maxf(2.0, spacing * float(count) / 2.8)
			result.append(Vector3(sin(arc_angle) * arc_radius, 0, (1.0 - cos(arc_angle)) * arc_radius))
		elif formation == "scattered":
			var scatter_angle := float(index) * 2.399963
			var scatter_radius := spacing * sqrt(float(index))
			result.append(Vector3(cos(scatter_angle) * scatter_radius, 0, sin(scatter_angle) * scatter_radius))
		else:
			var columns := mini(8, maxi(1, ceili(sqrt(float(count)))))
			result.append(Vector3((float(index % columns) - float(columns - 1) * 0.5) * spacing, 0, float(index / columns) * spacing))
	return result

func _spawns_on_start(entity: Dictionary) -> bool:
	var properties := entity.get("properties", {}) as Dictionary
	var fallback := "start" if bool(properties.get("active_on_start", true)) else "trigger"
	return String(properties.get("spawn_condition", fallback)) == "start" and String(properties.get("deployment_mode", "all")) == "all"

func _enemy_archetype_for_index(properties: Dictionary, index: int) -> StringName:
	var composition := properties.get("composition", []) as Array
	var cursor := 0
	for raw: Variant in composition:
		if not raw is Dictionary:
			continue
		var entry := raw as Dictionary
		var entry_count := maxi(0, int(entry.get("count", 0)))
		if index < cursor + entry_count:
			return StringName(entry.get("archetype", properties.get("archetype", "nathenian1")))
		cursor += entry_count
	return StringName(properties.get("archetype", "nathenian1"))

func _enemy_formation_positions(properties: Dictionary, count: int) -> Array[Vector3]:
	var formation := String(properties.get("formation", "line"))
	var spacing := float(properties.get("formation_spacing", _enemy_formation_spacing(properties)))
	var base_positions := _formation_positions(count, formation, spacing)
	if formation == "phalanx" and (properties.has("formation_columns") or properties.has("formation_rank_spacing")):
		base_positions.clear()
		var default_columns := mini(8, maxi(2, ceili(sqrt(float(count)) * 1.45)))
		var columns := clampi(int(properties.get("formation_columns", default_columns)), 2, maxi(2, count))
		var rank_spacing := maxf(0.55, float(properties.get("formation_rank_spacing", spacing * 0.72)))
		var rank_direction := -1.0 if StringName(properties.get("v2_troop_mode", &"")) == &"hoplite_phalanx" else 1.0
		for index: int in range(count):
			base_positions.append(Vector3(
				(float(index % columns) - float(columns - 1) * 0.5) * spacing,
				0.0,
				float(index / columns) * rank_spacing * rank_direction
			))
	if String(properties.get("formation", "line")) != "phalanx" or not properties.get("composition", []) is Array or (properties.get("composition", []) as Array).is_empty():
		return base_positions
	var columns := clampi(int(properties.get("formation_columns", mini(8, maxi(2, ceili(sqrt(float(count)) * 1.45))))), 2, maxi(2, count))
	var veteran_slots: Array[int] = []
	var row_start := 0
	while row_start < count:
		var row_size := mini(columns, count - row_start)
		if row_size >= 3:
			veteran_slots.append(row_start)
			if row_size > 1:
				veteran_slots.append(row_start + row_size - 1)
		row_start += row_size
	var veteran_count := 0
	for unit_index in range(count):
		var profile := _enemy_profile(_enemy_archetype_for_index(properties, unit_index))
		if StringName(profile.get("behavior", &"")) == &"phalanx_veteran":
			veteran_count += 1
	if veteran_slots.size() > veteran_count:
		veteran_slots.resize(veteran_count)
	var occupied_veteran_slots: Dictionary = {}
	for veteran_slot in veteran_slots:
		occupied_veteran_slots[veteran_slot] = true
	var regular_slots: Array[int] = []
	for slot_index in range(count):
		if not occupied_veteran_slots.has(slot_index):
			regular_slots.append(slot_index)
	var result: Array[Vector3] = []
	result.resize(count)
	var veteran_cursor := 0
	var regular_cursor := 0
	for unit_index in range(count):
		var profile := _enemy_profile(_enemy_archetype_for_index(properties, unit_index))
		var is_veteran := StringName(profile.get("behavior", &"")) == &"phalanx_veteran"
		var slot := unit_index
		if is_veteran and veteran_cursor < veteran_slots.size():
			slot = veteran_slots[veteran_cursor]
			veteran_cursor += 1
		elif regular_cursor < regular_slots.size():
			slot = regular_slots[regular_cursor]
			regular_cursor += 1
		result[unit_index] = base_positions[slot]
	return result

func _enemy_formation_spacing(properties: Dictionary) -> float:
	var profile := _enemy_profile(StringName(properties.get("archetype", "nathenian1")))
	var profile_spacing := float(profile.get("formation_spacing", 0.0))
	if profile_spacing > 0.0:
		return profile_spacing
	var scale_value := float(profile.get("scale", 1.0)) * float(properties.get("size_multiplier", 1.0))
	var role := StringName(profile.get("role", &"infantry"))
	var base := 2.15 if role in [&"ranged", &"archer"] else (1.35 if role in [&"phalanx", &"guardian"] else 1.65)
	return maxf(0.8, base * scale_value)

func _enemy_engage_distance(properties: Dictionary) -> float:
	var profile := _enemy_profile(StringName(properties.get("archetype", "nathenian1")))
	var tactical_radius := float(profile.get("tactical_radius", 2.4))
	var behavior := StringName(profile.get("behavior", &"aggressive"))
	return clampf(tactical_radius * (1.7 if behavior == &"ranged" else 2.6), 6.0, 24.0)

func _patrol_route(route_id: String) -> Array[Vector3]:
	var points: Array[Dictionary] = []
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		var properties := entity.get("properties", {}) as Dictionary
		if String(entity.get("type", "")) == "patrol_point" and String(properties.get("route_id", "")) == route_id:
			points.append(entity)
	points.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int((a.get("properties", {}) as Dictionary).get("order", 0)) < int((b.get("properties", {}) as Dictionary).get("order", 0)))
	var route: Array[Vector3] = []
	for point: Dictionary in points:
		route.append(WorldDocumentScript.vector3(point.get("position", [])))
	return route

func _inside_portion(entity: Dictionary) -> bool:
	if portion_radius == INF:
		return true
	if String(entity.get("type", "")) in ["terrain", "surface", "player_spawn"]:
		return true
	var position := WorldDocumentScript.vector3(entity.get("position", []))
	return Vector2(position.x - portion_center.x, position.z - portion_center.z).length() <= portion_radius

func _chapter_entities() -> Array[Dictionary]:
	return document.entities_for_chapter(active_chapter_id)

func _add_catalog_collision(holder: Node3D, definition: Dictionary, visual_bounds: AABB = AABB(), fit_to_visual: bool = false, convex_cache_key: String = "", visual_path: String = "", visual_transform: Transform3D = Transform3D.IDENTITY) -> void:
	var kind := String(definition.get("collision", "none"))
	if kind == "none":
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("world_entity_id", holder.get_meta("world_entity_id", ""))
	holder.add_child(body)
	if kind == "convex":
		var convex_shapes: Array[ConvexPolygonShape3D] = _cached_convex_shapes(convex_cache_key)
		var collision_source := "cache"
		if convex_shapes.is_empty():
			var authored_path := AssetCatalogScript.authored_collision_path_for_visual(visual_path)
			convex_shapes = _convex_shapes_from_authored_collision(holder, authored_path, visual_transform)
			collision_source = "authored" if not convex_shapes.is_empty() else "visual_hull"
			if convex_shapes.is_empty():
				var visual_shape := _convex_shape_from_visual(holder)
				if visual_shape != null:
					convex_shapes.append(visual_shape)
			if not convex_shapes.is_empty() and not convex_cache_key.is_empty():
				convex_collision_cache[convex_cache_key] = convex_shapes
		if not convex_shapes.is_empty():
			for shape_index: int in range(convex_shapes.size()):
				var convex_collision := CollisionShape3D.new()
				convex_collision.name = "ConvexPart_%02d" % shape_index
				convex_collision.shape = convex_shapes[shape_index]
				body.add_child(convex_collision)
			body.set_meta("gameplay_collision_shape", kind)
			body.set_meta("gameplay_collision_source", collision_source)
			body.set_meta("gameplay_collision_part_count", convex_shapes.size())
			return
		kind = "box"
	var collision := CollisionShape3D.new()
	if collision.shape == null and fit_to_visual and visual_bounds.size.length_squared() > 0.0001:
		var fitted_size := Vector3(maxf(visual_bounds.size.x, 0.05), maxf(visual_bounds.size.y, 0.05), maxf(visual_bounds.size.z, 0.05))
		body.position = visual_bounds.get_center()
		match kind:
			"cylinder":
				var cylinder := CylinderShape3D.new()
				cylinder.radius = maxf(fitted_size.x, fitted_size.z) * 0.5
				cylinder.height = fitted_size.y
				collision.shape = cylinder
			"capsule":
				var capsule := CapsuleShape3D.new()
				capsule.radius = minf(maxf(fitted_size.x, fitted_size.z) * 0.5, fitted_size.y * 0.5)
				capsule.height = maxf(fitted_size.y, capsule.radius * 2.0)
				collision.shape = capsule
			"sphere":
				var sphere := SphereShape3D.new()
				sphere.radius = maxf(fitted_size.x, maxf(fitted_size.y, fitted_size.z)) * 0.5
				collision.shape = sphere
			_:
				var box := BoxShape3D.new()
				box.size = fitted_size
				collision.shape = box
	elif collision.shape == null and kind == "cylinder":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(definition.get("collision_radius", 0.5))
		cylinder.height = float(definition.get("collision_height", 1.0))
		collision.shape = cylinder
		body.position.y = cylinder.height * 0.5
	elif collision.shape == null:
		var box := BoxShape3D.new()
		box.size = definition.get("collision_size", Vector3.ONE)
		collision.shape = box
		body.position.y = box.size.y * 0.5
	body.set_meta("gameplay_collision_shape", kind)
	body.set_meta("gameplay_collision_source", String(definition.get("collision_source", "primitive")))
	body.set_meta("gameplay_collision_part_count", 1)
	body.add_child(collision)

func _tree_trunk_collision_bounds(holder: Node3D, visual: Node3D, visual_bounds: AABB, definition: Dictionary, target_height: float, entity_scale: Vector3, cache_key: String) -> AABB:
	if not cache_key.is_empty() and tree_trunk_bounds_cache.has(cache_key):
		return tree_trunk_bounds_cache[cache_key] as AABB
	var result := _authored_tree_trunk_bounds(visual_bounds, definition, target_height, entity_scale)
	if result.size.length_squared() <= 0.0001:
		result = _measured_tree_trunk_bounds(holder, visual, visual_bounds)
	if not cache_key.is_empty():
		tree_trunk_bounds_cache[cache_key] = result
	return result

func _authored_tree_trunk_bounds(visual_bounds: AABB, definition: Dictionary, target_height: float, entity_scale: Vector3) -> AABB:
	var authored_radius := float(definition.get("collision_radius", 0.0))
	var authored_target_height := float(definition.get("target_height", 0.0))
	if authored_radius <= 0.0 or authored_target_height <= 0.0:
		return AABB()
	var target_scale := target_height / authored_target_height
	var radius := authored_radius * target_scale * maxf(absf(entity_scale.x), absf(entity_scale.z))
	var height := visual_bounds.size.y
	var center := visual_bounds.get_center()
	center.y = visual_bounds.position.y + height * 0.5
	return AABB(center - Vector3(radius, height * 0.5, radius), Vector3(radius * 2.0, height, radius * 2.0))

func _measured_tree_trunk_bounds(holder: Node3D, visual: Node3D, visual_bounds: AABB) -> AABB:
	var visual_height := maxf(visual_bounds.size.y, 0.05)
	var fallback_radius := clampf(visual_height * 0.075, 0.12, visual_height * 0.10)
	var collision_height := visual_height
	var fallback_center := visual_bounds.get_center()
	fallback_center.y = visual_bounds.position.y + collision_height * 0.5
	if visual == null:
		return AABB(fallback_center - Vector3(fallback_radius, collision_height * 0.5, fallback_radius), Vector3(fallback_radius * 2.0, collision_height, fallback_radius * 2.0))
	var bark_points := _tree_surface_points(holder, visual, true)
	if bark_points.is_empty():
		bark_points = _tree_surface_points(holder, visual, false)
	var lower_points: Array[Vector3] = []
	var sample_ceiling := visual_bounds.position.y + visual_height * 0.20
	for point: Vector3 in bark_points:
		if point.y <= sample_ceiling:
			lower_points.append(point)
	if lower_points.size() < 12:
		bark_points.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
		var fallback_count := mini(bark_points.size(), maxi(12, ceili(float(bark_points.size()) * 0.20)))
		lower_points.assign(bark_points.slice(0, fallback_count))
	if lower_points.is_empty():
		return AABB(fallback_center - Vector3(fallback_radius, collision_height * 0.5, fallback_radius), Vector3(fallback_radius * 2.0, collision_height, fallback_radius * 2.0))
	var x_samples: Array[float] = []
	var z_samples: Array[float] = []
	for point: Vector3 in lower_points:
		x_samples.append(point.x)
		z_samples.append(point.z)
	x_samples.sort()
	z_samples.sort()
	var center_x := x_samples[floori(float(x_samples.size()) * 0.5)]
	var center_z := z_samples[floori(float(z_samples.size()) * 0.5)]
	var radial_samples: Array[float] = []
	for point: Vector3 in lower_points:
		radial_samples.append(Vector2(point.x - center_x, point.z - center_z).length())
	radial_samples.sort()
	var percentile_index := clampi(floori(float(radial_samples.size() - 1) * 0.85), 0, radial_samples.size() - 1)
	var radius := radial_samples[percentile_index] * 1.08
	radius = clampf(radius, maxf(0.12, visual_height * 0.025), visual_height * 0.10)
	var center := Vector3(center_x, visual_bounds.position.y + collision_height * 0.5, center_z)
	return AABB(center - Vector3(radius, collision_height * 0.5, radius), Vector3(radius * 2.0, collision_height, radius * 2.0))

func _tree_surface_points(holder: Node3D, visual: Node3D, bark_only: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var meshes: Array[MeshInstance3D] = []
	if visual is MeshInstance3D:
		meshes.append(visual as MeshInstance3D)
	for candidate: Node in visual.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var to_holder := holder.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index)
			var material_name := material.resource_name.to_lower() if material != null else ""
			if bark_only and not (material_name.contains("bark") or material_name.contains("trunk") or material_name.contains("wood")):
				continue
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var sample_step := maxi(1, ceili(float(vertices.size()) / 2048.0))
			for vertex_index: int in range(0, vertices.size(), sample_step):
				result.append(to_holder * vertices[vertex_index])
	return result

func _cached_convex_shapes(cache_key: String) -> Array[ConvexPolygonShape3D]:
	var result: Array[ConvexPolygonShape3D] = []
	if cache_key.is_empty() or not convex_collision_cache.has(cache_key):
		return result
	var cached: Variant = convex_collision_cache[cache_key]
	if cached is ConvexPolygonShape3D:
		result.append(cached as ConvexPolygonShape3D)
	elif cached is Array:
		for value: Variant in cached as Array:
			if value is ConvexPolygonShape3D:
				result.append(value as ConvexPolygonShape3D)
	return result

func _convex_shapes_from_authored_collision(holder: Node3D, collision_path: String, source_transform: Transform3D) -> Array[ConvexPolygonShape3D]:
	var result: Array[ConvexPolygonShape3D] = []
	if collision_path.is_empty():
		return result
	var packed := RuntimeGLTFCacheScript.scene(collision_path)
	if packed == null:
		return result
	var source := packed.instantiate() as Node3D
	if source == null:
		return result
	source.name = "AuthoredCollisionSource"
	source.visible = false
	holder.add_child(source)
	source.transform = source_transform
	var meshes: Array[MeshInstance3D] = []
	if source is MeshInstance3D:
		meshes.append(source as MeshInstance3D)
	for candidate: Node in source.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	if meshes.size() > MAX_AUTHORED_CONVEX_PARTS:
		push_warning("[FORGE COLLISION] %s contains %d convex parts; only the first %d are used." % [collision_path, meshes.size(), MAX_AUTHORED_CONVEX_PARTS])
	for mesh_index: int in range(mini(meshes.size(), MAX_AUTHORED_CONVEX_PARTS)):
		var shape := _convex_shape_from_mesh_instance(holder, meshes[mesh_index])
		if shape != null:
			result.append(shape)
	holder.remove_child(source)
	source.free()
	return result

func _convex_shape_from_mesh_instance(holder: Node3D, mesh_instance: MeshInstance3D) -> ConvexPolygonShape3D:
	if mesh_instance.mesh == null:
		return null
	var points := PackedVector3Array()
	var to_holder := holder.global_transform.affine_inverse() * mesh_instance.global_transform
	for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for vertex: Vector3 in vertices:
			points.append(to_holder * vertex)
	if points.size() < 4:
		return null
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape

func _convex_shape_from_visual(holder: Node3D) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	for candidate: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var to_holder := holder.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var sample_step := maxi(1, ceili(float(vertices.size()) / 1024.0))
			for vertex_index in range(0, vertices.size(), sample_step):
				points.append(to_holder * vertices[vertex_index])
	if points.size() < 4:
		return null
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape

func _add_selection_collider(holder: Node3D, size: Vector3, center: Variant = null) -> void:
	if not editing:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	body.set_meta("world_entity_id", holder.get_meta("world_entity_id", ""))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center as Vector3 if center is Vector3 else Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(collision)
	holder.add_child(body)

func _node_bounds_in_root(root: Node3D, content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		for corner_index: int in range(8):
			var local_point := root.to_local(mesh_instance.to_global(mesh_bounds.get_endpoint(corner_index)))
			if not initialized:
				bounds = AABB(local_point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(local_point)
	return bounds

func _scaled_aabb(bounds: AABB, scale_value: Vector3) -> AABB:
	var result := AABB(bounds.position * scale_value, Vector3.ZERO)
	for corner_index: int in range(1, 8):
		result = result.expand(bounds.get_endpoint(corner_index) * scale_value)
	return result

func _add_icon(holder: Node3D, color: Color, text: String, radius: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 1.35
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.65
	holder.add_child(mesh_instance)
	var label := Label3D.new()
	label.text = text
	label.position.y = 1.45
	label.font_size = 30
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holder.add_child(label)

func _add_zone_visual(holder: Node3D, size: Vector3, color: Color, label_text: String) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	mesh_instance.mesh = mesh
	holder.add_child(mesh_instance)
	var label := Label3D.new()
	label.text = label_text
	label.position.y = size.y * 0.5 + 0.5
	label.font_size = 28
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holder.add_child(label)

func _capsule_marker(color: Color, scale_value: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32 * scale_value
	mesh.height = 1.75 * scale_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.15
	material.roughness = 0.6
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.88 * scale_value
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35 * scale_value
	shape.height = 1.8 * scale_value
	collision.shape = shape
	collision.position.y = 0.9 * scale_value
	body.add_child(collision)
	return body

func _fit_visual_to_height(content: Node3D, target_height: float, use_support_percentile: bool = false) -> void:
	var bounds := _node_bounds_in_root(content, content)
	if bounds.size.y > 0.001:
		var scale_value := target_height / bounds.size.y
		var support_y := _visual_support_floor(content) if use_support_percentile else bounds.position.y
		content.scale = Vector3.ONE * scale_value
		content.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * scale_value, -support_y * scale_value, -(bounds.position.z + bounds.size.z * 0.5) * scale_value)

func _visual_support_floor(content: Node3D) -> float:
	var samples: Array[float] = []
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var to_content := content.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var sample_step := maxi(1, ceili(float(vertices.size()) / 2048.0))
			for vertex_index in range(0, vertices.size(), sample_step):
				samples.append((to_content * vertices[vertex_index]).y)
	if samples.is_empty():
		return 0.0
	samples.sort()
	return samples[clampi(floori(float(samples.size() - 1) * 0.02), 0, samples.size() - 1)]

func _disable_activity(root: Node) -> void:
	for raw: Node in root.find_children("*", "", true, false):
		if raw is AnimationPlayer:
			(raw as AnimationPlayer).stop()
		elif raw is AnimationTree:
			(raw as AnimationTree).active = false

func _configure_prop_activity(root: Node, path: String) -> void:
	if not path.replace("\\", "/").to_lower().contains("/assets/fauna/"):
		_disable_activity(root)
		return
	root.process_mode = Node.PROCESS_MODE_INHERIT
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for raw_mesh: Node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw_mesh as MeshInstance3D)
	for mesh: MeshInstance3D in meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for raw_tree: Node in root.find_children("*", "AnimationTree", true, false):
		(raw_tree as AnimationTree).active = false
	var animation_players: Array[AnimationPlayer] = []
	if root is AnimationPlayer:
		animation_players.append(root as AnimationPlayer)
	for raw_player: Node in root.find_children("*", "AnimationPlayer", true, false):
		animation_players.append(raw_player as AnimationPlayer)
	var wanted := "flying" if path.to_lower().contains("eagle") else "idle"
	for animation_player: AnimationPlayer in animation_players:
		for animation_name: StringName in animation_player.get_animation_list():
			var normalized := String(animation_name).to_lower()
			if normalized == wanted or normalized.ends_with("|" + wanted) or normalized.ends_with("/" + wanted):
				var animation := animation_player.get_animation(animation_name)
				if animation != null:
					animation.loop_mode = Animation.LOOP_LINEAR
				animation_player.play(animation_name, 0.0, 1.0)
				break

func _on_enemy_died(enemy: Node, group_id: String) -> void:
	enemy_died.emit(enemy, group_id)

func _on_trigger_body_entered(body: Node3D, trigger_id: String) -> void:
	if body == player:
		player_entered_trigger.emit(trigger_id)

func _on_atmosphere_body_entered(body: Node3D, zone_id: String) -> void:
	if body == player:
		player_entered_atmosphere.emit(zone_id)

func _on_chapter_portal_entered(body: Node3D, destination_chapter: String, destination_spawn: String, portal: Area3D) -> void:
	if body == player and not destination_chapter.is_empty():
		if portal != null:
			portal.set_deferred("monitoring", false)
		chapter_transition_requested.emit(destination_chapter, destination_spawn)

func _safe_name(entity: Dictionary) -> String:
	return String(entity.get("name", entity.get("type", "Element"))).validate_node_name()

func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	var text := String(value)
	return Color(text) if Color.html_is_valid(text) else fallback


func _sample_v2_terrain_height(position_value: Vector3) -> float:
	for surface: Dictionary in v2_terrain_surfaces:
		var local: Vector3 = surface["inverse"] * position_value
		var properties: Dictionary = surface["properties"]
		if WorldTerrainScript.contains_local_point(properties, local.x, local.z):
			local.y = WorldTerrainScript.height_at_normalized(properties, local.x, local.z)
			return float((surface["transform"] * local).y)
	return position_value.y
