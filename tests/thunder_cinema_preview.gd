extends SceneTree
func _initialize() -> void: call_deferred("_run")
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/thunder_" + label + ".png")
func _run() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := preload("res://scripts/player.gd").new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.skills.profile.reset(true)
	player.skills.select_ultimate(&"thunder")
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150,150)
	mesh.mesh = plane
	world.add_child(mesh)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60,-25,0)
	world.add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07,0.10,0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5,0.6,0.8)
	env.ambient_light_energy = 0.7
	player.camera.environment = env
	player._update_camera(1)
	for i: int in 7:
		var enemy := preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd").create(&"infantry_v2")
		enemy.combat_lab_enabled = true
		world.add_child(enemy)
		enemy.add_to_group(&"enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.position = Vector3((i % 3 - 1) * 3, 0, -30 + (i / 3) * 3)
	await process_frame
	var shot := preload("res://scripts/abilities/skill_projectile.gd").new()
	shot.source = player
	shot.thunder = true
	shot.charge_ratio = 1
	shot.damage = 1300
	shot.position = Vector3(0,1.5,0)
	world.add_child(shot)
	shot.set_physics_process(false)
	player.skills.cinema.thunder_view.begin(shot)
	for i: int in 65:
		shot.position += Vector3.FORWARD * 0.45
		player.skills.cinema.advance(1.0 / 60)
		player.skills.cinema.vfx._process(Engine.time_scale / 60.0)
		await process_frame
		if i == 35: await capture("chase")
	shot.impact(null, &"torso", Vector3(0,0.1,-29))
	for i: int in 130:
		player.skills.cinema.advance(1.0 / 60)
		player.skills.cinema.vfx._process(Engine.time_scale / 60.0)
		await process_frame
		if i == 10: await capture("blast")
		if i == 38: await capture("overhead")
		if i == 129: await capture("return")
	player.skills.save_dirty = false
	print("PASS: thunder chase, explosion, overhead and return rendered")
	current_scene = null
	world.queue_free()
	await process_frame
	quit()
