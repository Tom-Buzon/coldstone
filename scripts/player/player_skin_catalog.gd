extends RefCounted
class_name HoplitePlayerSkinCatalog

const PLAYABLE_PLAYERS_DIRECTORY := "res://assets/characters/player_skins"
const BASE_SKIN_ID: StringName = &"base"
const BASE_SKIN_PATH := "res://assets/runtime/ual1/UAL1_Standard.glb"
const BASE_SKIN_LABEL := "HOPLITE D'ORIGINE"
const SUPPORTED_EXTENSIONS := ["glb", "gltf"]
const EXPECTED_BONE_COUNT := 53
const MINIMUM_ANIMATION_COUNT := 46


static func scan() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = [{
		"id": BASE_SKIN_ID,
		"label": BASE_SKIN_LABEL,
		"path": BASE_SKIN_PATH,
		"warnings": [],
	}]
	var canonical_bones := _canonical_bone_names()
	var discovered_paths: Array[String] = []
	_collect_model_paths(PLAYABLE_PLAYERS_DIRECTORY, discovered_paths)
	discovered_paths.sort()
	var known_ids := {BASE_SKIN_ID: true}
	for path: String in discovered_paths:
		var result := _validate_model(path, canonical_bones)
		if not bool(result.get("compatible", false)):
			push_warning("[PLAYER SKIN SCAN] Rejected %s: %s" % [path, String(result.get("reason", "incompatible"))])
			continue
		var skin_id := _skin_id_from_path(path)
		if skin_id == StringName() or known_ids.has(skin_id):
			push_warning("[PLAYER SKIN SCAN] Rejected duplicate/empty id for: " + path)
			continue
		known_ids[skin_id] = true
		for warning: String in result.get("warnings", []):
			push_warning("[PLAYER SKIN SCAN] %s: %s" % [path, warning])
		definitions.append({
			"id": skin_id,
			"label": _skin_label_from_path(path),
			"path": path,
			"warnings": result.get("warnings", []),
		})
	print("[PLAYER SKIN SCAN] %d compatible playable player(s) found in %s" % [definitions.size() - 1, PLAYABLE_PLAYERS_DIRECTORY])
	return definitions


static func _skin_id_from_path(path: String) -> StringName:
	var normalized := path.get_file().get_basename().to_snake_case()
	# Keep model/version suffixes compact (`noonT1` -> `noon_t1`) so adding
	# automatic discovery does not invalidate ids saved by the former fixed list.
	for digit: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		normalized = normalized.replace("_" + digit, digit)
	return StringName(normalized)


static func _skin_label_from_path(path: String) -> String:
	var label := String(_skin_id_from_path(path)).replace("_", " ").to_upper()
	return label


static func _collect_model_paths(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_warning("[PLAYER SKIN SCAN] Missing playable-player directory: " + directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_model_paths(path, output)
			elif entry.get_extension().to_lower() in SUPPORTED_EXTENSIONS:
				output.append(path)
			elif entry.ends_with(".remap"):
				# Exported PCKs expose imported resources as `<source>.remap` in
				# directory listings, while ResourceLoader still expects the source
				# path. Strip only that export suffix before testing the extension.
				var source_entry := entry.trim_suffix(".remap")
				if source_entry.get_extension().to_lower() in SUPPORTED_EXTENSIONS:
					output.append(directory_path.path_join(source_entry))
		entry = directory.get_next()
	directory.list_dir_end()


static func _canonical_bone_names() -> Dictionary:
	var result: Dictionary = {}
	var packed := load(BASE_SKIN_PATH) as PackedScene
	if packed == null:
		return result
	var instance := packed.instantiate()
	var skeleton := _find_skeleton(instance)
	if skeleton != null:
		for bone_index: int in range(skeleton.get_bone_count()):
			result[String(skeleton.get_bone_name(bone_index))] = true
	instance.free()
	return result


static func _validate_model(path: String, canonical_bones: Dictionary) -> Dictionary:
	var packed := load(path) as PackedScene
	if packed == null:
		return {"compatible": false, "reason": "le fichier n'est pas importable comme PackedScene"}
	var instance := packed.instantiate()
	var skeletons: Array[Skeleton3D] = []
	var animation_players: Array[AnimationPlayer] = []
	var meshes: Array[MeshInstance3D] = []
	_collect_components(instance, skeletons, animation_players, meshes)
	if skeletons.size() != 1:
		instance.free()
		return {"compatible": false, "reason": "il faut exactement un Skeleton3D (trouvé: %d)" % skeletons.size()}
	var skeleton := skeletons[0]
	if skeleton.get_bone_count() != EXPECTED_BONE_COUNT:
		instance.free()
		return {"compatible": false, "reason": "le rig doit avoir %d os (trouvé: %d)" % [EXPECTED_BONE_COUNT, skeleton.get_bone_count()]}
	for raw_name: Variant in canonical_bones.keys():
		var bone_name := String(raw_name)
		if bone_name == "root":
			continue
		if skeleton.find_bone(bone_name) < 0:
			instance.free()
			return {"compatible": false, "reason": "os UAL manquant: " + bone_name}
	var root_index := _unique_root_bone(skeleton)
	if root_index < 0:
		instance.free()
		return {"compatible": false, "reason": "le rig doit avoir un unique os racine"}
	var best_animation_count := 0
	for animation_player: AnimationPlayer in animation_players:
		best_animation_count = maxi(best_animation_count, animation_player.get_animation_list().size())
	if best_animation_count < MINIMUM_ANIMATION_COUNT:
		instance.free()
		return {"compatible": false, "reason": "banque UAL incomplète (%d/%d animations)" % [best_animation_count, MINIMUM_ANIMATION_COUNT]}
	if meshes.is_empty():
		instance.free()
		return {"compatible": false, "reason": "aucun MeshInstance3D"}
	var warnings: Array[String] = []
	var root_name := String(skeleton.get_bone_name(root_index))
	if root_name != "root":
		warnings.append("l'os racine '%s' est accepté comme alias de 'root'" % root_name)
	instance.free()
	return {"compatible": true, "warnings": warnings}


static func _collect_components(node: Node, skeletons: Array[Skeleton3D], animation_players: Array[AnimationPlayer], meshes: Array[MeshInstance3D]) -> void:
	if node is Skeleton3D:
		skeletons.append(node as Skeleton3D)
	elif node is AnimationPlayer:
		animation_players.append(node as AnimationPlayer)
	elif node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_components(child, skeletons, animation_players, meshes)


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var skeleton := _find_skeleton(child)
		if skeleton != null:
			return skeleton
	return null


static func _unique_root_bone(skeleton: Skeleton3D) -> int:
	var result := -1
	for bone_index: int in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(bone_index) >= 0:
			continue
		if result >= 0:
			return -1
		result = bone_index
	return result
