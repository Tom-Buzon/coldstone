extends SceneTree
const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200, 700)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("172230")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	world.add_child(camera)
	camera.look_at_from_position(Vector3(3.3, 2.6, 6.3), Vector3(0, 1.1, 0), Vector3.UP)
	camera.current = true
	var roles: Array[StringName] = [&"archer_v2", &"infantry_v2", &"infantry_v2"]
	var poses: Array[StringName] = [&"bow_draw", &"block_idle", &"sword_cut"]
	var actors: Array[Node] = []
	for index: int in range(3):
		var actor := Factory.create(roles[index])
		actor.position.x = float(index - 1) * 1.8
		world.add_child(actor)
		actor.animation.set_manual_sampling(true)
		actor.play_semantic_animation(poses[index], 0.0)
		actor.animation.player.seek(0.55, true)
		actors.append(actor)
		var label := Label3D.new()
		label.text = ["ARCHER · AIM", "INFANTRY · GUARD", "INFANTRY · CUT"][index]
		label.position = actor.position + Vector3.UP * 2.3
		label.font_size = 24
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	for frame: int in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/enemy_refactor/enemy_v2_roles_visual_probe.png"))
	print("ROLE_VISUAL ", error_string(error))
	quit(int(error != OK))
