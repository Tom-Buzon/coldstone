extends Node3D
class_name HopliteV2PresentationComponent

var visual_root: Node3D
var skeleton: Skeleton3D
var lod_meshes: Array[MeshInstance3D] = []
var runtime_lod_enabled: bool = true
var runtime_cull_distance: float = 0.0
static var _body_scene_cache: Dictionary = {}


func install(definition: HopliteEnemyV2Definition) -> bool:
	clear_visual()
	var packed := _body_scene_cache.get(definition.body_scene_path) as PackedScene
	if packed == null:
		packed = load(definition.body_scene_path) as PackedScene
		if packed != null:
			_body_scene_cache[definition.body_scene_path] = packed
	if packed == null:
		push_error("HopliteV2 body scene is missing: %s" % definition.body_scene_path)
		return false
	visual_root = packed.instantiate() as Node3D
	if visual_root == null:
		push_error("HopliteV2 body root is not Node3D")
		return false
	add_child(visual_root)
	skeleton = _find_skeleton(visual_root)
	if skeleton == null or skeleton.get_bone_count() != 23:
		push_error("HopliteV2 presentation requires the canonical 23-bone skeleton")
		clear_visual()
		return false
	var body := visual_root.find_child("SPARTAN_character_body", true, false) as MeshInstance3D
	if body == null or body.mesh == null:
		push_error("HopliteV2 presentation requires the canonical body mesh")
		clear_visual()
		return false
	# 3DGen's prepared source also contains nine zero-scaled gore-cap meshes.
	# Dismemberment V2 spawns its shared fragment resources independently, so
	# retaining those helpers on every actor only creates render submissions and
	# scene nodes. Keep the one skinned body and discard all import-only geometry.
	_remove_import_helper_geometry(visual_root, body)
	lod_meshes.append(body)
	if not _install_lod_meshes(definition):
		clear_visual()
		return false
	_configure_visibility_ranges(definition)
	return true


func clear_visual() -> void:
	if visual_root != null:
		visual_root.queue_free()
	visual_root = null
	skeleton = null
	lod_meshes.clear()


func _install_lod_meshes(definition: HopliteEnemyV2Definition) -> bool:
	for index: int in range(definition.body_lod_scene_paths.size()):
		var path := definition.body_lod_scene_paths[index]
		var packed := _body_scene_cache.get(path) as PackedScene
		if packed == null:
			packed = load(path) as PackedScene
			if packed != null:
				_body_scene_cache[path] = packed
		if packed == null:
			push_error("HopliteV2 LOD scene is missing: %s" % path)
			return false
		var donor_root := packed.instantiate() as Node3D
		if donor_root == null:
			push_error("HopliteV2 LOD root is not Node3D: %s" % path)
			return false
		var donor_skeleton := _find_skeleton(donor_root)
		var donor_body := donor_root.find_child("SPARTAN_character_body", true, false) as MeshInstance3D
		if donor_skeleton == null or donor_body == null or donor_body.mesh == null:
			push_error("HopliteV2 LOD has no compatible skeleton/body: %s" % path)
			donor_root.free()
			return false
		if not _skeletons_are_compatible(skeleton, donor_skeleton):
			push_error("HopliteV2 LOD rest pose differs from LOD0: %s" % path)
			donor_root.free()
			return false
		var donor_parent := donor_body.get_parent()
		donor_parent.remove_child(donor_body)
		donor_body.owner = null
		donor_body.name = "SPARTAN_character_body_LOD%d" % (index + 1)
		skeleton.add_child(donor_body)
		donor_body.skeleton = NodePath("..")
		lod_meshes.append(donor_body)
		donor_root.free()
	return true


func _configure_visibility_ranges(definition: HopliteEnemyV2Definition) -> void:
	var near_distance := definition.body_lod_distances[0] if definition.body_lod_distances.size() > 0 else 20.0
	var far_distance := definition.body_lod_distances[1] if definition.body_lod_distances.size() > 1 else near_distance + 35.0
	apply_lod_policy(true, near_distance, far_distance, 0.0, definition.body_lod_fade_margin)


func apply_lod_policy(enabled: bool, near_distance: float, far_distance: float, cull_distance: float, fade_margin: float = 2.0) -> void:
	runtime_lod_enabled = enabled
	runtime_cull_distance = cull_distance
	near_distance = maxf(1.0, near_distance)
	far_distance = maxf(near_distance + 1.0, far_distance)
	cull_distance = 0.0 if cull_distance <= 0.0 else maxf(far_distance + 1.0, cull_distance)
	for index: int in range(lod_meshes.size()):
		var mesh := lod_meshes[index]
		mesh.visible = enabled or index == 0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if not enabled:
			mesh.visibility_range_begin = 0.0
			mesh.visibility_range_end = 0.0
			mesh.visibility_range_begin_margin = 0.0
			mesh.visibility_range_end_margin = 0.0
			continue
		mesh.visibility_range_begin = 0.0 if index == 0 else (near_distance if index == 1 else far_distance)
		mesh.visibility_range_end = near_distance if index == 0 else (far_distance if index == 1 else cull_distance)
		mesh.visibility_range_begin_margin = 0.0 if index == 0 else fade_margin
		mesh.visibility_range_end_margin = fade_margin if mesh.visibility_range_end > 0.0 else 0.0


func set_shadows_enabled(enabled: bool) -> void:
	for mesh: MeshInstance3D in lod_meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _skeletons_are_compatible(first: Skeleton3D, second: Skeleton3D) -> bool:
	if first.get_bone_count() != second.get_bone_count():
		return false
	for index: int in range(first.get_bone_count()):
		if first.get_bone_name(index) != second.get_bone_name(index):
			return false
		if not first.get_bone_rest(index).is_equal_approx(second.get_bone_rest(index)):
			return false
	return true


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _remove_import_helper_geometry(node: Node, body: MeshInstance3D) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D and child != body:
			child.queue_free()
			continue
		_remove_import_helper_geometry(child, body)
