extends SceneTree

const LIBRARY_PATH := "res://assets/animations/enemy_v2/hoplite/hoplite_v2_animation_library.res"
const Catalog = preload("res://scripts/enemy_v2/hoplite_v2_catalog.gd")
const LIBRARY_NAME: StringName = &"hoplite_v2"
const CLIP: StringName = &"hoplite_v2/spear_thrust"
const BODY_NAME: StringName = &"SPARTAN_character_body"

var _failures: Array[String] = []


func _initialize() -> void:
	var library := load(LIBRARY_PATH) as AnimationLibrary
	_expect(library != null, "shared animation library must load")
	var definition := Catalog.definition(&"ngeneral") as HopliteEnemyV2Definition
	var lod_paths: Array[String] = [definition.body_scene_path]
	for path: String in definition.body_lod_scene_paths:
		lod_paths.append(path)
	var reference_names: PackedStringArray = []
	var reference_rests: Array[Transform3D] = []
	for path: String in lod_paths:
		var packed := load(path) as PackedScene
		_expect(packed != null, "LOD scene must load: %s" % path)
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		_expect(instance != null, "LOD root must be Node3D: %s" % path)
		if instance == null:
			continue
		root.add_child(instance)
		var skeleton := _find_skeleton(instance)
		var body := instance.find_child(String(BODY_NAME), true, false) as MeshInstance3D
		_expect(skeleton != null, "LOD must contain a skeleton: %s" % path)
		_expect(body != null and body.mesh != null, "LOD must contain the canonical body mesh: %s" % path)
		if skeleton != null:
			_expect(skeleton.get_bone_count() == 23, "LOD skeleton must have 23 bones: %s" % path)
			if reference_names.is_empty():
				for index: int in range(skeleton.get_bone_count()):
					reference_names.append(String(skeleton.get_bone_name(index)))
					reference_rests.append(skeleton.get_bone_rest(index))
			else:
				for index: int in range(skeleton.get_bone_count()):
					_expect(String(skeleton.get_bone_name(index)) == reference_names[index], "LOD bone order mismatch: %s" % path)
					_expect(skeleton.get_bone_rest(index).is_equal_approx(reference_rests[index]), "LOD rest pose mismatch: %s bone=%s" % [path, reference_names[index]])
			if library != null:
				var player := AnimationPlayer.new()
				skeleton.add_child(player)
				_expect(player.add_animation_library(LIBRARY_NAME, library) == OK, "LOD donor must bind: %s" % path)
				_expect(player.has_animation(CLIP), "LOD donor clip must exist: %s" % path)
				player.play(CLIP)
				player.advance(0.35)
		if body != null and body.mesh != null:
			_expect(body.mesh.get_surface_count() > 0, "LOD body must expose at least one material surface: %s" % path)
			_expect(not body.skeleton.is_empty(), "LOD body must target its skeleton: %s" % path)
			print("HOPLITE_V2_LOD_CONTRACT path=", path, " surfaces=", body.mesh.get_surface_count(), " skeleton=", body.skeleton)
		instance.free()
	if _failures.is_empty():
		print("HOPLITE_V2_LOD_CONTRACT_PROBE PASS lods=", lod_paths.size(), " bones=23 clip=", CLIP)
		quit(0)
	else:
		for failure: String in _failures:
			push_error("HOPLITE_V2_LOD_CONTRACT_PROBE " + failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
