extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := preload("res://scripts/player.gd").new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(45, 45)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.11, 0.13, 0.16)
	ground.material_override = ground_material
	world.add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.7
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(9, 7, 9)
	camera.look_at(Vector3(0, 0.7, -5))
	camera.make_current()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.07, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.78, 0.9)
	environment.ambient_light_energy = 0.6
	camera.environment = environment
	var flame := preload("res://scripts/abilities/flame_wall.gd").new()
	flame.source = player
	world.add_child(flame)
	flame.position = Vector3(0, 0, -1.5)
	flame.flames.preprocess = 0.7
	for index: int in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/skill_flame_preview.png")
	print("PASS: flame effect rendered in Compatibility")
	current_scene = null
	world.queue_free()
	await process_frame
	quit()
