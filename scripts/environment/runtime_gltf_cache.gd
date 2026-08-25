extends RefCounted
class_name HopliteRuntimeGLTFCache

# Shared by the training range, character packages and automatic library. A raw
# GLB below a .gdignore folder is parsed once, packed in memory, then instantiated
# as many times as needed without touching Godot's editor importer.
static var scene_cache: Dictionary = {}

static func scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	if scene_cache.has(path):
		return scene_cache[path] as PackedScene
	if not FileAccess.file_exists(path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if error != OK:
		push_warning("[RUNTIME GLTF] Parse failed for %s (error %d)." % [path, error])
		return null
	var generated := document.generate_scene(state) as Node3D
	if generated == null:
		push_warning("[RUNTIME GLTF] No scene generated for %s." % path)
		return null
	_rebuild_meshes_with_missing_normals(generated, path)
	var packed := PackedScene.new()
	error = packed.pack(generated)
	generated.free()
	if error != OK:
		push_warning("[RUNTIME GLTF] Packing failed for %s (error %d)." % [path, error])
		return null
	scene_cache[path] = packed
	return packed

static func _rebuild_meshes_with_missing_normals(root: Node3D, source_path: String) -> void:
	var mesh_instances: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		mesh_instances.append(root as MeshInstance3D)
	for candidate: Node in root.find_children("*", "MeshInstance3D", true, false):
		mesh_instances.append(candidate as MeshInstance3D)
	var repaired_surface_count := 0
	for mesh_instance: MeshInstance3D in mesh_instances:
		var source_mesh := mesh_instance.mesh
		if source_mesh == null or not _mesh_has_missing_triangle_normals(source_mesh):
			continue
		var rebuilt_mesh := ArrayMesh.new()
		rebuilt_mesh.resource_name = source_mesh.resource_name
		for surface_index: int in range(source_mesh.get_surface_count()):
			var surface_tool := SurfaceTool.new()
			surface_tool.create_from(source_mesh, surface_index)
			surface_tool.set_material(source_mesh.surface_get_material(surface_index))
			var arrays := source_mesh.surface_get_arrays(surface_index)
			var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
			var normals_missing: bool = normals == null or (normals is PackedVector3Array and normals.is_empty())
			if normals_missing and source_mesh.surface_get_primitive_type(surface_index) == Mesh.PRIMITIVE_TRIANGLES:
				surface_tool.generate_normals()
				repaired_surface_count += 1
			surface_tool.commit(rebuilt_mesh)
			var rebuilt_index := rebuilt_mesh.get_surface_count() - 1
			rebuilt_mesh.surface_set_name(rebuilt_index, source_mesh.surface_get_name(surface_index))
		mesh_instance.mesh = rebuilt_mesh
	if repaired_surface_count > 0:
		print("[RUNTIME GLTF] Generated missing normals on %d surface(s): %s" % [repaired_surface_count, source_path])

static func _mesh_has_missing_triangle_normals(mesh: Mesh) -> bool:
	for surface_index: int in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
		if normals == null or (normals is PackedVector3Array and normals.is_empty()):
			return true
	return false

static func clear() -> void:
	scene_cache.clear()
