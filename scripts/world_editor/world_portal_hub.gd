extends Node3D
class_name HopliteWorldPortalHub

const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")

const SAVE_DIR := "user://hoplite_worlds"
const LOBBY_FILENAME := "lobbyy.hoplite.json"
const LOBBY_SCENE := "res://lobby.tscn"
const LAB_SCENE := "res://combat_lab.tscn"
const FORGE_SCENE := "res://world_editor.tscn"
const CAMPAIGN_SCENE := "res://procedural_campaign.tscn"
const WORLD_PLAY_SCENE := "res://world_play.tscn"
const MAX_WORLD_PORTALS := 16
const PORTAL_COLUMN_SPACING := 7.0
const PORTAL_ROW_SPACING := 7.5
const FORGE_PORTAL_VISUAL := "res://assets/blenderAseet/07_portes/portal_world_forge/portal_world_forge_LOD0.glb"
const SAVED_WORLD_PORTAL_VISUAL := "res://assets/blenderAseet/07_portes/portal_saved_world/portal_saved_world_LOD0.glb"
const CAMPAIGN_DESTINATIONS := {
	"grand_siege": "res://battle_02.tscn",
	"procedural_campaign": "res://procedural_campaign.tscn",
	"last_flame": "res://battle_03_narrative.tscn",
}
const CAMPAIGN_LABELS := {
	"grand_siege": "GRAND SIEGE",
	"procedural_campaign": "CAMPAGNE PROCEDURALE",
	"last_flame": "LA DERNIERE FLAMME",
}

enum HubMode {
	LEGACY_LAB_CATALOG,
	LOBBY,
	LAB_RETURN,
}

var mode: HubMode = HubMode.LEGACY_LAB_CATALOG
var transitioning: bool = false
var lobby_runtime: HopliteWorldRuntime
var lobby_document: HopliteWorldDocument
var lobby_world_path: String = SAVE_DIR.path_join(LOBBY_FILENAME)
var externally_attached_nodes: Array[Node] = []


func configure_lobby(runtime: HopliteWorldRuntime, document: HopliteWorldDocument, world_path: String = "") -> void:
	mode = HubMode.LOBBY
	lobby_runtime = runtime
	lobby_document = document
	if not world_path.is_empty():
		lobby_world_path = world_path


func configure_lab_return() -> void:
	mode = HubMode.LAB_RETURN


func _ready() -> void:
	name = "WorldPortalDistrict"
	match mode:
		HubMode.LOBBY:
			_build_lobby_portals()
		HubMode.LAB_RETURN:
			_build_legacy_lab_catalog()
			_build_lab_return_portal()
		_:
			_build_legacy_lab_catalog()


func _exit_tree() -> void:
	for node: Node in externally_attached_nodes:
		if is_instance_valid(node):
			node.queue_free()
	externally_attached_nodes.clear()


func _build_lobby_portals() -> void:
	if lobby_runtime == null or lobby_document == null:
		push_error("[LOBBY PORTALS] Runtime or document missing.")
		return
	_bind_authored_portal(
		&"world_editor",
		"FORGE DE MONDES\nCREER & EDITER",
		Color(0.18, 0.86, 0.66),
		FORGE_SCENE
	)
	_bind_campaign_portals()
	_build_saved_world_district()


func _build_lab_return_portal() -> void:
	_add_scene_portal(
		Vector3(10.5, 0.0, -50.5),
		Vector3.ZERO,
		"RETOUR AU LOBBY",
		Color(0.32, 0.68, 1.0),
		SAVED_WORLD_PORTAL_VISUAL,
		LOBBY_SCENE
	)


func _build_legacy_lab_catalog() -> void:
	_add_scene_portal(
		Vector3(10.5, 0.0, -58.0),
		Vector3.ZERO,
		"FORGE DE MONDES\nCREER & EDITER",
		Color(0.18, 0.86, 0.66),
		FORGE_PORTAL_VISUAL,
		FORGE_SCENE
	)
	var world_files := _saved_world_files(true)
	for index: int in range(mini(world_files.size(), MAX_WORLD_PORTALS)):
		var filename: String = world_files[index]
		var column := index % 4
		var row := index / 4
		var position_value := Vector3(17.5 + float(column) * PORTAL_COLUMN_SPACING, 0.0, -58.0 + float(row) * PORTAL_ROW_SPACING)
		var color := Color.from_hsv(fmod(0.57 + float(index) * 0.083, 1.0), 0.64, 0.95)
		_add_world_portal(position_value, Vector3.ZERO, filename, color)
	if world_files.size() > MAX_WORLD_PORTALS:
		_add_label(Vector3(28.0, 3.4, -34.0), "+ %d MONDES\n(les 16 plus recents sont exposes)" % (world_files.size() - MAX_WORLD_PORTALS), Color("f0c56a"))


func _bind_authored_portal(role: StringName, title: String, color: Color, target_scene: String) -> void:
	var entity := _entity_with_portal_role(role)
	var anchor := _runtime_node_for_entity(entity)
	if anchor == null:
		push_warning("[LOBBY PORTALS] Missing authored '%s' portal in lobbyy." % String(role))
		return
	var properties := entity.get("properties", {}) as Dictionary
	var authored_title := String(properties.get("portal_label", title)).strip_edges()
	_add_anchor_interaction(anchor, authored_title if not authored_title.is_empty() else title, color, target_scene)


func _bind_campaign_portals() -> void:
	var entities := _entities_with_portal_role(&"official_campaign")
	if entities.is_empty():
		push_warning("[LOBBY PORTALS] Missing authored campaign portals in lobbyy.")
		return
	for entity: Dictionary in entities:
		var anchor := _runtime_node_for_entity(entity)
		if anchor == null:
			continue
		var properties := entity.get("properties", {}) as Dictionary
		var campaign_id := String(properties.get("campaign_id", "procedural_campaign"))
		var target_scene := String(CAMPAIGN_DESTINATIONS.get(campaign_id, CAMPAIGN_SCENE))
		var fallback_label := String(CAMPAIGN_LABELS.get(campaign_id, "CAMPAGNE OFFICIELLE"))
		var title := String(properties.get("portal_label", fallback_label)).strip_edges()
		_add_anchor_interaction(anchor, title if not title.is_empty() else fallback_label, Color(0.92, 0.20, 0.34), target_scene)


func _build_saved_world_district() -> void:
	var entity := _entity_with_portal_role(&"saved_worlds_anchor")
	var anchor := _runtime_node_for_entity(entity)
	if anchor == null:
		push_warning("[LOBBY PORTALS] Missing saved-world district anchor in lobbyy.")
		return
	var properties := entity.get("properties", {}) as Dictionary
	var columns := clampi(int(properties.get("portal_columns", 9)), 1, MAX_WORLD_PORTALS + 1)
	var column_spacing := maxf(5.0, float(properties.get("portal_column_spacing", 7.25)))
	var row_spacing := maxf(5.0, float(properties.get("portal_row_spacing", 8.0)))

	# The authored anchor itself is the shooting-range portal. Every generated
	# world is offset from this transform, so moving or rotating the prop in the
	# Forge moves the complete district on the next lobby load.
	_add_anchor_interaction(anchor, "STAND DE TIR", Color(0.36, 0.74, 1.0), LAB_SCENE)
	var world_files := _saved_world_files(true)
	for index: int in range(mini(world_files.size(), MAX_WORLD_PORTALS)):
		var slot := index + 1
		var column := slot % columns
		var row := slot / columns
		var local_offset := Vector3(float(column) * column_spacing, 0.0, -float(row) * row_spacing)
		var portal_root := Node3D.new()
		portal_root.name = "SavedWorldPortal_%02d" % slot
		add_child(portal_root)
		portal_root.global_transform = anchor.global_transform * Transform3D(Basis.IDENTITY, local_offset)
		var color := Color.from_hsv(fmod(0.57 + float(index) * 0.083, 1.0), 0.64, 0.95)
		_add_authored_portal_visual(portal_root, SAVED_WORLD_PORTAL_VISUAL)
		_add_local_interaction(
			portal_root,
			"MONDE CREE\n%s" % _world_display_name(world_files[index]).to_upper(),
			color,
			WORLD_PLAY_SCENE,
			SAVE_DIR.path_join(world_files[index])
		)
	if world_files.size() > MAX_WORLD_PORTALS:
		var overflow := Label3D.new()
		overflow.name = "WorldPortalOverflow"
		overflow.text = "+ %d MONDES\n(les 16 plus recents sont exposes)" % (world_files.size() - MAX_WORLD_PORTALS)
		overflow.position = Vector3(float(columns - 1) * column_spacing * 0.5, 6.2, -float((MAX_WORLD_PORTALS / columns) + 1) * row_spacing)
		overflow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		overflow.font_size = 28
		overflow.outline_size = 8
		overflow.modulate = Color("f0c56a")
		anchor.add_child(overflow)
		externally_attached_nodes.append(overflow)


func _entity_with_portal_role(role: StringName) -> Dictionary:
	var matches := _entities_with_portal_role(role)
	return matches[0] if not matches.is_empty() else {}


func _entities_with_portal_role(role: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if lobby_document == null:
		return result
	var chapter_id := lobby_runtime.active_chapter_id if lobby_runtime != null else lobby_document.start_chapter()
	for entity: Dictionary in lobby_document.entities_for_chapter(chapter_id):
		var properties := entity.get("properties", {}) as Dictionary
		if StringName(properties.get("portal_role", &"")) == role:
			result.append(entity)
	return result


func _runtime_node_for_entity(entity: Dictionary) -> Node3D:
	if entity.is_empty() or lobby_runtime == null:
		return null
	return lobby_runtime.nodes_by_id.get(String(entity.get("id", ""))) as Node3D


func _saved_world_files(exclude_lobby: bool) -> Array[String]:
	var result: Array[String] = []
	for filename: String in DirAccess.get_files_at(SAVE_DIR):
		if not filename.ends_with(".hoplite.json"):
			continue
		if exclude_lobby and filename.naturalnocasecmp_to(lobby_world_path.get_file()) == 0:
			continue
		result.append(filename)
	result.sort_custom(func(a: String, b: String) -> bool:
		var modified_a := FileAccess.get_modified_time(SAVE_DIR.path_join(a))
		var modified_b := FileAccess.get_modified_time(SAVE_DIR.path_join(b))
		if modified_a == modified_b:
			return a.naturalnocasecmp_to(b) < 0
		return modified_a > modified_b
	)
	return result


func _world_display_name(filename: String) -> String:
	var fallback := filename.trim_suffix(".hoplite.json").replace("_", " ").capitalize()
	var file := FileAccess.open(SAVE_DIR.path_join(filename), FileAccess.READ)
	if file == null:
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return String((parsed as Dictionary).get("name", fallback))
	return fallback


func _add_world_portal(position_value: Vector3, rotation_value: Vector3, filename: String, color: Color) -> void:
	_add_scene_portal(
		position_value,
		rotation_value,
		"MONDE SAUVE\n%s" % _world_display_name(filename).to_upper(),
		color,
		SAVED_WORLD_PORTAL_VISUAL,
		WORLD_PLAY_SCENE,
		SAVE_DIR.path_join(filename)
	)


func _add_scene_portal(
	position_value: Vector3,
	rotation_value: Vector3,
	title: String,
	color: Color,
	visual_path: String,
	target_scene: String,
	world_path: String = ""
) -> void:
	var root := Node3D.new()
	root.position = position_value
	root.rotation_degrees = rotation_value
	add_child(root)
	if not _add_authored_portal_visual(root, visual_path):
		_add_fallback_portal_visual(root, color)
	_add_local_interaction(root, title, color, target_scene, world_path)


func _add_anchor_interaction(anchor: Node3D, title: String, color: Color, target_scene: String, world_path: String = "") -> void:
	var nodes := _add_local_interaction(anchor, title, color, target_scene, world_path)
	for node: Node in nodes:
		externally_attached_nodes.append(node)


func _add_local_interaction(root: Node3D, title: String, color: Color, target_scene: String, world_path: String = "") -> Array[Node]:
	var label := Label3D.new()
	label.name = "PortalLabel"
	label.text = title
	label.position = Vector3(0.0, 6.45, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.modulate = color.lightened(0.18)
	root.add_child(label)
	var area := Area3D.new()
	area.name = "PortalInteraction"
	area.collision_layer = 0
	area.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 3.4, 2.6)
	collision.shape = shape
	collision.position.y = 1.7
	area.add_child(collision)
	area.body_entered.connect(_on_destination_portal_entered.bind(target_scene, world_path))
	root.add_child(area)
	return [label, area]


func _add_authored_portal_visual(root: Node3D, visual_path: String) -> bool:
	var packed := RuntimeGLTFCacheScript.scene(visual_path)
	if packed == null:
		push_warning("[WORLD PORTALS] Missing authored portal visual: %s" % visual_path)
		return false
	var visual := packed.instantiate() as Node3D
	if visual == null:
		push_warning("[WORLD PORTALS] Invalid authored portal visual: %s" % visual_path)
		return false
	visual.name = "AuthoredPortalFrame"
	root.add_child(visual)
	return true


func _add_fallback_portal_visual(root: Node3D, color: Color) -> void:
	var glow := StandardMaterial3D.new()
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(color.r, color.g, color.b, 0.30)
	glow.emission_enabled = true
	glow.emission = color * 1.7
	var portal := MeshInstance3D.new()
	var portal_mesh := BoxMesh.new()
	portal_mesh.size = Vector3(3.35, 2.7, 0.10)
	portal.mesh = portal_mesh
	portal.position = Vector3(0, 1.55, 0)
	portal.material_override = glow
	root.add_child(portal)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.15, 0.17, 0.22)
	stone.metallic = 0.55
	stone.roughness = 0.34
	for x: float in [-1.95, 1.95]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.height = 3.65
		pillar_mesh.top_radius = 0.19
		pillar_mesh.bottom_radius = 0.28
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x, 1.82, 0)
		pillar.material_override = stone
		root.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(4.45, 0.35, 0.42)
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0, 3.55, 0)
	lintel.material_override = stone
	root.add_child(lintel)


func _add_label(global_position_value: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = global_position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.modulate = color
	add_child(label)


func _on_destination_portal_entered(body: Node3D, target_scene: String, world_path: String) -> void:
	if transitioning or not body.is_in_group("player"):
		return
	transitioning = true
	if not world_path.is_empty():
		get_tree().set_meta("hoplite_world_path", world_path)
	var scene_error := get_tree().change_scene_to_file(target_scene)
	if scene_error != OK:
		transitioning = false
		push_error("[WORLD PORTALS] Scene transition failed: %s (%s)" % [target_scene, error_string(scene_error)])
