extends SceneTree

const ASSET_ROOT: String = "res://assets/blenderAseet"
const EXPECTED_GLB_COUNT: int = 477
const EXPECTED_LOD0_COUNT: int = 112


func _initialize() -> void:
	var glb_paths: Array[String] = []
	var failures: Array[String] = []
	_collect_glb_paths(ASSET_ROOT, glb_paths, failures)
	glb_paths.sort()

	var lod0_count: int = 0
	var scene_count: int = 0
	var mesh_instance_count: int = 0

	for path: String in glb_paths:
		var resource: Resource = ResourceLoader.load(
			path,
			"PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE
		)
		if resource == null or not (resource is PackedScene):
			failures.append("Unable to load PackedScene: %s" % path)
			continue

		var instance: Node = (resource as PackedScene).instantiate()
		if instance == null or not (instance is Node3D):
			failures.append("Unable to instantiate Node3D: %s" % path)
			if instance != null:
				instance.free()
			continue

		var scene_mesh_count: int = _count_mesh_instances(instance)
		if scene_mesh_count == 0:
			failures.append("Scene contains no MeshInstance3D: %s" % path)
		else:
			mesh_instance_count += scene_mesh_count
		scene_count += 1
		if path.ends_with("_LOD0.glb"):
			lod0_count += 1
		instance.free()

	if glb_paths.size() != EXPECTED_GLB_COUNT:
		failures.append(
			"Expected %d GLBs, found %d" % [EXPECTED_GLB_COUNT, glb_paths.size()]
		)
	if lod0_count != EXPECTED_LOD0_COUNT:
		failures.append(
			"Expected %d LOD0 scenes, loaded %d" % [EXPECTED_LOD0_COUNT, lod0_count]
		)

	if failures.is_empty():
		print(
			"[BLENDER ASSET IMPORT PROBE] PASS glb=%d scenes=%d lod0=%d meshes=%d"
			% [glb_paths.size(), scene_count, lod0_count, mesh_instance_count]
		)
		quit(0)
		return

	printerr("[BLENDER ASSET IMPORT PROBE] FAIL count=%d" % failures.size())
	for failure: String in failures:
		printerr(failure)
	quit(1)


func _collect_glb_paths(
	directory_path: String,
	paths: Array[String],
	failures: Array[String]
) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		failures.append("Unable to open directory: %s" % directory_path)
		return

	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "glb":
			paths.append(directory_path.path_join(file_name))
	for directory_name: String in directory.get_directories():
		_collect_glb_paths(directory_path.path_join(directory_name), paths, failures)


func _count_mesh_instances(root: Node) -> int:
	var count: int = 1 if root is MeshInstance3D else 0
	count += root.find_children("*", "MeshInstance3D", true, false).size()
	return count
