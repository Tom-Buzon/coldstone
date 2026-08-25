extends SceneTree

const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")

const ASSETS: Array[Dictionary] = [
	{"id": "big_rock", "path": "res://_source/environment_props_raw/bigRock/bigRock_LOD0.glb"},
	{"id": "brazier", "path": "res://_source/environment_props_raw/brazier/brazier_LOD0.glb"},
	{"id": "crates", "path": "res://_source/environment_props_raw/caisse/caisses.glb"},
	{"id": "catapult", "path": "res://_source/environment_props_raw/catapulte/catapulte.glb"},
	{"id": "cypress_tree", "path": "res://_source/environment_props_raw/cypressTree/cypressTree_LOD0.glb"},
	{"id": "fountain", "path": "res://_source/environment_props_raw/fontaine1/fontaine1_LOD0.glb"},
	{"id": "jar", "path": "res://_source/environment_props_raw/jare/jare.glb"},
	{"id": "barricade", "path": "res://_source/environment_props_raw/obstacle/obstacle.glb"},
	{"id": "athena_statue", "path": "res://_source/environment_props_raw/statusAthena/statusAthena_LOD0.glb"},
	{"id": "lion_statue", "path": "res://_source/environment_props_raw/statusLion/statusLion_LOD0.glb"},
	{"id": "magistrate_statue", "path": "res://_source/environment_props_raw/statusMagistrale/statusMagistrale_LOD0.glb"},
	{"id": "temple", "path": "res://_source/environment_props_raw/temple1/temple1_LOD0.glb"},
	{"id": "tomb", "path": "res://_source/environment_props_raw/tombe1/tombe1_LOD0.glb"}
]

const OUTPUT_DIR := "res://docs/environment_asset_catalog/images"

var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	root.size = Vector2i(720, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_stage()
	call_deferred("_capture_all")

func _build_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.065, 0.078)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.78)
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	key.light_color = Color(1.0, 0.82, 0.64)
	key.light_energy = 1.55
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22.0, 142.0, 0.0)
	fill.light_color = Color(0.40, 0.58, 1.0)
	fill.light_energy = 0.68
	stage.add_child(fill)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(20.0, 20.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.20, 0.19, 0.17)
	ground_material.roughness = 0.92
	ground_mesh.material = ground_material
	ground.mesh = ground_mesh
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 36.0
	stage.add_child(camera)

func _capture_all() -> void:
	await process_frame
	for definition: Dictionary in ASSETS:
		var packed := RuntimeGLTFCacheScript.scene(String(definition["path"]))
		if packed == null:
			continue
		var content := packed.instantiate() as Node3D
		if content == null:
			continue
		content.name = "Preview_%s" % String(definition["id"])
		stage.add_child(content)
		var bounds := _node_bounds(content)
		var target_height := 4.8
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		content.scale = Vector3.ONE * scale_value
		content.position = Vector3(
			-(bounds.position.x + bounds.size.x * 0.5) * scale_value,
			-bounds.position.y * scale_value,
			-(bounds.position.z + bounds.size.z * 0.5) * scale_value
		)
		var footprint := maxf(bounds.size.x, bounds.size.z) * scale_value
		var framing := maxf(5.0, maxf(footprint, target_height))
		camera.position = Vector3(framing * 1.15, target_height * 0.68, framing * 1.42)
		camera.look_at(Vector3(0.0, target_height * 0.43, 0.0), Vector3.UP)
		await process_frame
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var output_path := "%s/%s.png" % [OUTPUT_DIR, String(definition["id"])]
		var error := image.save_png(ProjectSettings.globalize_path(output_path))
		print("[ASSET THUMBNAIL] %s -> %s (%s)" % [definition["id"], output_path, error_string(error)])
		content.free()
	stage.free()
	quit(0)

func _node_bounds(root_node: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for child: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var transform := _transform_to_ancestor(mesh_instance, root_node)
		var mesh_bounds := mesh_instance.get_aabb()
		for corner: int in range(8):
			var point := transform * mesh_bounds.get_endpoint(corner)
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds

func _transform_to_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
