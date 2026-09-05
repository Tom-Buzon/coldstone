extends SceneTree

const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const OUTPUT_DIR := "res://assets/environment/stylized_nature/thumbnails"
const MODEL_ROOT := "res://assets/environment/stylized_nature"

var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	root.size = Vector2i(320, 320)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_stage()
	call_deferred("_capture_all")

func _build_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171b20")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c7d6")
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46.0, -32.0, 0.0)
	key.light_color = Color("ffd7a3")
	key.light_energy = 1.45
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, 142.0, 0.0)
	fill.light_color = Color("789fd6")
	fill.light_energy = 0.55
	stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(10.0, 10.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("2c302d")
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	ground.mesh = ground_mesh
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.8
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(5.8, 4.0, 7.2), Vector3(0.0, 1.8, 0.0), Vector3.UP)

func _capture_all() -> void:
	await process_frame
	var paths: Array[String] = []
	_collect_models(MODEL_ROOT, paths)
	paths.sort()
	var captured := 0
	for path: String in paths:
		var packed := RuntimeGLTFCacheScript.scene(path)
		var content := packed.instantiate() as Node3D if packed != null else null
		if content == null:
			continue
		stage.add_child(content)
		_disable_activity(content)
		var bounds := _node_bounds(content)
		if bounds.size.length_squared() <= 0.0001:
			content.free()
			continue
		var fit_scale := 4.0 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		content.scale = Vector3.ONE * fit_scale
		content.position = Vector3(
			-(bounds.position.x + bounds.size.x * 0.5) * fit_scale,
			-bounds.position.y * fit_scale,
			-(bounds.position.z + bounds.size.z * 0.5) * fit_scale
		)
		content.rotation.y = deg_to_rad(24.0)
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var output_path := OUTPUT_DIR.path_join(path.get_file().get_basename() + ".png")
		if image.save_png(ProjectSettings.globalize_path(output_path)) == OK:
			captured += 1
		content.free()
	print("NATURE_THUMBNAILS_OK count=%d" % captured)
	stage.free()
	quit(0)

func _collect_models(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		var path := directory_path.path_join(filename)
		if directory.current_is_dir():
			if filename != "thumbnails":
				_collect_models(path, output)
		elif filename.get_extension().to_lower() == "gltf":
			output.append(path)
		filename = directory.get_next()
	directory.list_dir_end()

func _disable_activity(root_node: Node) -> void:
	root_node.process_mode = Node.PROCESS_MODE_DISABLED
	for raw: Node in root_node.find_children("*", "AnimationPlayer", true, false):
		(raw as AnimationPlayer).stop()
	for raw: Node in root_node.find_children("*", "AnimationTree", true, false):
		(raw as AnimationTree).active = false

func _node_bounds(root_node: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for raw: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var to_root := root_node.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var point := to_root * mesh_bounds.get_endpoint(corner_index)
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds
