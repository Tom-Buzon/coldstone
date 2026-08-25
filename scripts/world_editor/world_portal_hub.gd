extends Node3D
class_name HopliteWorldPortalHub

const SAVE_DIR := "user://hoplite_worlds"
const FORGE_SCENE := "res://world_editor.tscn"
const WORLD_PLAY_SCENE := "res://world_play.tscn"
const MAX_WORLD_PORTALS := 16

var transitioning := false

func _ready() -> void:
	name = "WorldPortalDistrict"
	_add_portal(Vector3(10.5, 0.0, -58.0), "FORGE DE MONDES\nCREER & EDITER", Color(0.18, 0.86, 0.66), "")
	var files := DirAccess.get_files_at(SAVE_DIR)
	files.sort()
	var world_files: Array[String] = []
	for filename: String in files:
		if filename.ends_with(".hoplite.json"):
			world_files.append(filename)
	for index in range(mini(world_files.size(), MAX_WORLD_PORTALS)):
		var filename := world_files[index]
		var display_name := filename.trim_suffix(".hoplite.json").replace("_", " ").capitalize()
		var file := FileAccess.open(SAVE_DIR.path_join(filename), FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				display_name = String((parsed as Dictionary).get("name", display_name))
		var column := index % 4
		var row := index / 4
		var position := Vector3(16.0 + float(column) * 5.5, 0.0, -58.0 + float(row) * 6.5)
		var color := Color.from_hsv(fmod(0.57 + float(index) * 0.083, 1.0), 0.64, 0.95)
		_add_portal(position, "MONDE SAUVE\n%s" % display_name.to_upper(), color, SAVE_DIR.path_join(filename))
	if world_files.size() > MAX_WORLD_PORTALS:
		_add_label(Vector3(24.0, 3.4, -39.0), "+ %d MONDES\n(les 16 plus recents sont exposes)" % (world_files.size() - MAX_WORLD_PORTALS), Color("f0c56a"))

func _add_portal(position_value: Vector3, title: String, color: Color, world_path: String) -> void:
	var root := Node3D.new()
	root.position = position_value
	add_child(root)
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
	for x in [-1.95, 1.95]:
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
	_add_label(position_value + Vector3(0, 4.15, 0), title, color.lightened(0.18))
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 3.4, 2.6)
	collision.shape = shape
	collision.position.y = 1.7
	area.add_child(collision)
	area.body_entered.connect(_on_portal_entered.bind(world_path))
	root.add_child(area)

func _add_label(global_position_value: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = global_position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.modulate = color
	add_child(label)

func _on_portal_entered(body: Node3D, world_path: String) -> void:
	if transitioning or not body.is_in_group("player"):
		return
	transitioning = true
	if world_path.is_empty():
		get_tree().change_scene_to_file(FORGE_SCENE)
	else:
		get_tree().set_meta("hoplite_world_path", world_path)
		get_tree().change_scene_to_file(WORLD_PLAY_SCENE)
