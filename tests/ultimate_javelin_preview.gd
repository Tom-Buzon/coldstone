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
	player.skills.profile.reset(true)
	player.skills.cinema.vfx.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.position = Vector3(5, 3.3, 6)
	camera.look_at(Vector3(0, 1, -1))
	player.skills.controls.wheel.open()
	for index: int in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/ultimate_authored_icons.png")
	player.skills.controls.cancel()
	player.skills.select_ultimate(&"thunder")
	player.skills.add_charge(100)
	player.skills.activate_ultimate()
	player.skills.thunder_button(true)
	player.skills.tick(0.25)
	for index: int in 12:
		player.skills.cinema.advance(0.016)
		player.skills.presentation()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/ultimate_javelin_low.png")
	player.skills.tick(2.0)
	for index: int in 12:
		player.skills.cinema.advance(0.016)
		player.skills.presentation()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/ultimate_javelin_full.png")
	player.skills.thunder_button(false)
	player.skills.tick(0.001)
	for child: Node in world.get_children():
		if child.get_script() == preload("res://scripts/abilities/skill_projectile.gd"):
			child.set_physics_process(false)
			child.global_position += child.direction * 3
	player.skills.presentation()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/ultimate_javelin_flight.png")
	print("PASS: authored HUD icons and charged electric javelin rendered")
	current_scene = null
	world.queue_free()
	await process_frame
	quit()
