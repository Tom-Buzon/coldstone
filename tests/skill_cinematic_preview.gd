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
	player.skills.profile.selected_ultimate = &"aura"
	player.skills.add_charge(100)
	player.skills.activate_ultimate()
	player.skills.cinema.vfx.process_mode = Node.PROCESS_MODE_ALWAYS
	player.animation_driver.tick(0.1)
	camera.position = Vector3(4, 3.3, 5)
	camera.look_at(Vector3(0, 1, 0))
	for index: int in 18:
		player.skills.cinema.advance(0.016)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/skill_aura_preview.png")
	player.skills.controls.ultimate_button(true)
	player.skills.controls.advance(0.3)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/skill_wheel_preview.png")
	player.skills.controls.cancel()
	player.skills.end_ultimate()
	player.skills.cinema.impact(player.global_position, 5.0)
	for index: int in 8:
		player.skills.cinema.advance(0.016)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/skill_impact_preview.png")
	for kind: StringName in [&"ares", &"flame", &"thunder"]:
		player.skills.profile.selected_ultimate = kind
		player.skills.add_charge(100)
		player.skills.activate_ultimate()
		for index: int in 12:
			player.skills.cinema.advance(0.016)
			await process_frame
		if kind == &"thunder": player.skills.cinema.vfx.thunder(Vector3(0, 1, 0), Vector3(0, 1, -6))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/skill_" + String(kind) + "_signature.png")
		player.skills.end_ultimate()
	print("PASS: four ultimate signatures, wheel and plunge impact rendered")
	current_scene = null
	world.queue_free()
	await process_frame
	quit()
