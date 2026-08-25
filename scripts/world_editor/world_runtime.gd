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
const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const EnemyArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const PlayerScript = preload("res://scripts/player.gd")
const CrowdDirectorScript = preload("res://scripts/ai/battle_crowd_director.gd")

const PREVIEW_FORMATION_LIMIT := 16
const PREVIEW_CHARACTER_LIMIT := 12

var document: HopliteWorldDocument
var editing := true
var portion_center := Vector3.ZERO
var portion_radius := INF
var world_root: Node3D
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var player: HopliteUALNativePlayer
var crowd_director: HopliteBattleCrowdDirector
var nodes_by_id: Dictionary = {}
var enemies_by_group: Dictionary = {}
var initial_group_counts: Dictionary = {}
var preview_character_count := 0
var active_chapter_id := ""
var requested_spawn_id := ""

func build(source: HopliteWorldDocument, edit_mode: bool = true, center: Vector3 = Vector3.ZERO, radius: float = INF, chapter_id: String = "", spawn_id: String = "") -> void:
	clear_world()
	document = source
	editing = edit_mode
	active_chapter_id = chapter_id if not chapter_id.is_empty() else document.start_chapter()
	requested_spawn_id = spawn_id
	portion_center = center
	portion_radius = radius
	world_root = Node3D.new()
	world_root.name = "EditableWorld"
	add_child(world_root)
	_build_environment()
	if not editing:
		crowd_director = CrowdDirectorScript.new() as HopliteBattleCrowdDirector
		crowd_director.name = "WorldCrowdDirector"
		world_root.add_child(crowd_director)
		_build_test_player()
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

func clear_world() -> void:
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
	world_environment = null
	sun = null
	if world_root != null and is_instance_valid(world_root):
		world_root.queue_free()
	world_root = null

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
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = _color(values.get("sky_top", "#263850"), Color("263850"))
	sky_material.sky_horizon_color = _color(values.get("sky_horizon", "#d8ad78"), Color("d8ad78"))
	sky_material.ground_bottom_color = Color(0.05, 0.045, 0.04)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color.darkened(0.46)
	sky_material.sun_angle_max = 22.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = sky_material.sky_horizon_color.lightened(0.12)
	environment.ambient_light_energy = float(values.get("ambient_energy", 0.72))
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	var fog := float(values.get("fog_density", 0.006))
	environment.fog_enabled = fog > 0.0001
	environment.fog_density = fog
	environment.fog_light_color = sky_material.sky_horizon_color
	environment.fog_light_energy = 0.55
	world_environment.environment = environment
	sun.light_color = sky_material.sky_horizon_color.lightened(0.18)
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
	var asset_id := StringName(properties.get("asset_id", "crates"))
	var path := AssetCatalogScript.migrate_asset_path(String(properties.get("asset_path", "")))
	if path.is_empty():
		path = AssetCatalogScript.visual_path(asset_id, false)
	var holder := Node3D.new()
	holder.name = _safe_name(entity)
	_configure_entity_node(holder, entity)
	world_root.add_child(holder)
	var visual_bounds := AABB(Vector3(-0.7, 0.0, -0.7), Vector3(1.4, maxf(1.0, float(properties.get("target_height", AssetCatalogScript.target_height(asset_id)))), 1.4))
	var packed := RuntimeGLTFCacheScript.scene(path)
	if packed != null:
		var visual := packed.instantiate() as Node3D
		if visual != null:
			holder.add_child(visual)
			_disable_activity(visual)
			_fit_visual_to_height(visual, float(properties.get("target_height", AssetCatalogScript.target_height(asset_id))))
			var measured_bounds := _node_bounds_in_root(holder, visual)
			if measured_bounds.size.length_squared() > 0.0001:
				visual_bounds = measured_bounds
	var definition := AssetCatalogScript.definition(asset_id)
	if definition.is_empty() and not path.is_empty():
		definition = {"collision": "box", "collision_size": Vector3(1.4, float(properties.get("target_height", 2.0)), 1.4)}
	_add_catalog_collision(holder, definition)
	holder.set_meta("editor_local_bounds", visual_bounds)
	_add_selection_collider(holder, visual_bounds.size, visual_bounds.get_center())
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
	spawn_enemy_group(entity, player, holder)
	return holder

func spawn_enemy_group(entity: Dictionary, target: Node3D, existing_holder: Node3D = null, count_override: int = -1, start_index: int = 0) -> Array[Node]:
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
	var count := total_count - start_index if count_override < 0 else mini(count_override, total_count - start_index)
	count = maxi(0, count)
	var formation_positions := _enemy_formation_positions(properties, maxi(total_count, count))
	var spawned: Array[Node] = []
	for index in range(count):
		var unit_index := start_index + index
		var archetype := _enemy_archetype_for_index(properties, unit_index)
		if String(properties.get("rank", "normal")) == "miniboss" and not EnemyArchetypesScript.is_miniboss(archetype) and not EnemyArchetypesScript.is_boss(archetype):
			archetype = &"captain"
		var unit_position := formation_positions[unit_index % formation_positions.size()] if not formation_positions.is_empty() else Vector3.ZERO
		var enemy := EnemyFactoryScript.spawn(holder, archetype, unit_position, target, {
			"name": "%s_%02d" % [group_id, unit_index + 1], "ai_enabled": true,
			"mass_battle_mode": total_count >= 28, "guard_index": unit_index,
			"scale_multiplier": float(properties.get("size_multiplier", 1.0)),
			"match_perfect_hitbox": bool(properties.get("match_perfect_hitbox", false)),
			"giant_traversal_mode": StringName(properties.get("giant_traversal_mode", "assisted")),
			"giant_capsule_radius_multiplier": float(properties.get("giant_capsule_radius_multiplier", 0.90)),
			"giant_capsule_height_multiplier": float(properties.get("giant_capsule_height_multiplier", 1.0)),
			"giant_walkable_tops": bool(properties.get("giant_walkable_tops", true))
		})
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
	_configure_group_behavior(spawned, entity)
	return spawned

func remove_enemy_group(group_id: String) -> int:
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
	for raw: Variant in enemies_by_group.get(group_id, []):
		var enemy := raw as Node
		if enemy != null and is_instance_valid(enemy) and not bool(enemy.get("dead")):
			result += 1
	return result

func _build_enemy_preview(holder: Node3D, entity: Dictionary, count: int) -> void:
	var properties := entity.get("properties", {}) as Dictionary
	var shown := mini(count, PREVIEW_FORMATION_LIMIT)
	var positions := _enemy_formation_positions(properties, shown)
	var rank := String(properties.get("rank", "normal"))
	for index in range(shown):
		var archetype := _enemy_archetype_for_index(properties, index)
		var profile := EnemyArchetypesScript.profile(archetype)
		var is_veteran := StringName(profile.get("behavior", &"")) == &"phalanx_veteran"
		var color := Color(0.88, 0.24, 0.16) if rank == "miniboss" else (Color(0.92, 0.65, 0.18) if is_veteran else Color(0.20, 0.48, 0.88))
		if index == 0 and preview_character_count < PREVIEW_CHARACTER_LIMIT:
			if rank == "miniboss" and not EnemyArchetypesScript.is_miniboss(archetype) and not EnemyArchetypesScript.is_boss(archetype):
				archetype = &"captain"
			var enemy := EnemyFactoryScript.spawn(holder, archetype, positions[index], null, {
				"ai_enabled": false,
				"name": "Apercu",
				"scale_multiplier": float(properties.get("size_multiplier", 1.0)),
				"match_perfect_hitbox": bool(properties.get("match_perfect_hitbox", false)),
				"giant_traversal_mode": StringName(properties.get("giant_traversal_mode", "assisted")),
				"giant_capsule_radius_multiplier": float(properties.get("giant_capsule_radius_multiplier", 0.90)),
				"giant_capsule_height_multiplier": float(properties.get("giant_capsule_height_multiplier", 1.0)),
				"giant_walkable_tops": bool(properties.get("giant_walkable_tops", true))
			})
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

func _configure_group_behavior(enemies: Array[Node], entity: Dictionary) -> void:
	var properties := entity.get("properties", {}) as Dictionary
	var behavior := String(properties.get("behavior", "normal"))
	if behavior == "patrol":
		var route := _patrol_route(String(properties.get("route_id", "")))
		for index in range(enemies.size()):
			if enemies[index].has_method("configure_demo_patrol"):
				enemies[index].call("configure_demo_patrol", route, index, _enemy_engage_distance(properties), float(properties.get("patrol_speed", 2.0)))
	elif behavior == "wait":
		for enemy: Node in enemies:
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
		var target_key := String(properties.get("protect_target", ""))
		var target_entity := document.find_entity(target_key)
		if target_entity.is_empty():
			target_entity = document.find_by_name(target_key)
		var target := nodes_by_id.get(String(target_entity.get("id", ""))) as Node3D
		if target == null:
			continue
		var group_id := String(properties.get("group_id", ""))
		for index in range((enemies_by_group.get(group_id, []) as Array).size()):
			var enemy := (enemies_by_group[group_id] as Array)[index] as Node
			enemy.set("ai_miniboss", target)
			enemy.set("ai_guard_index", index)

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
	var base_positions := _formation_positions(count, String(properties.get("formation", "line")), _enemy_formation_spacing(properties))
	if String(properties.get("formation", "line")) != "phalanx" or not properties.get("composition", []) is Array or (properties.get("composition", []) as Array).is_empty():
		return base_positions
	var columns := mini(8, maxi(2, ceili(sqrt(float(count)) * 1.45)))
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
		var profile := EnemyArchetypesScript.profile(_enemy_archetype_for_index(properties, unit_index))
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
		var profile := EnemyArchetypesScript.profile(_enemy_archetype_for_index(properties, unit_index))
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
	var profile := EnemyArchetypesScript.profile(StringName(properties.get("archetype", "nathenian1")))
	var profile_spacing := float(profile.get("formation_spacing", 0.0))
	if profile_spacing > 0.0:
		return profile_spacing
	var scale_value := float(profile.get("scale", 1.0)) * float(properties.get("size_multiplier", 1.0))
	var role := StringName(profile.get("role", &"infantry"))
	var base := 2.15 if role in [&"ranged", &"archer"] else (1.35 if role in [&"phalanx", &"guardian"] else 1.65)
	return maxf(0.8, base * scale_value)

func _enemy_engage_distance(properties: Dictionary) -> float:
	var profile := EnemyArchetypesScript.profile(StringName(properties.get("archetype", "nathenian1")))
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

func _add_catalog_collision(holder: Node3D, definition: Dictionary) -> void:
	var kind := String(definition.get("collision", "none"))
	if kind == "none":
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("world_entity_id", holder.get_meta("world_entity_id", ""))
	holder.add_child(body)
	var collision := CollisionShape3D.new()
	if kind == "cylinder":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(definition.get("collision_radius", 0.5))
		cylinder.height = float(definition.get("collision_height", 1.0))
		collision.shape = cylinder
		collision.position.y = cylinder.height * 0.5
	else:
		var box := BoxShape3D.new()
		box.size = definition.get("collision_size", Vector3.ONE)
		collision.shape = box
		collision.position.y = box.size.y * 0.5
	body.add_child(collision)

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

func _fit_visual_to_height(content: Node3D, target_height: float) -> void:
	var bounds := _node_bounds_in_root(content, content)
	if bounds.size.y > 0.001:
		var scale_value := target_height / bounds.size.y
		content.scale = Vector3.ONE * scale_value
		content.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * scale_value, -bounds.position.y * scale_value, -(bounds.position.z + bounds.size.z * 0.5) * scale_value)

func _disable_activity(root: Node) -> void:
	for raw: Node in root.find_children("*", "", true, false):
		if raw is AnimationPlayer:
			(raw as AnimationPlayer).stop()
		elif raw is AnimationTree:
			(raw as AnimationTree).active = false

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
