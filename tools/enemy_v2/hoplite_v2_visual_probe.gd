extends SceneTree

const ShadowFactory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const OUTPUT := "res://docs/enemy_refactor/hoplite_v2_shared_skin_probe.png"


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1100, 720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111722")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c9d8f4")
	settings.ambient_light_energy = 0.9
	environment.environment = settings
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_energy = 1.6
	world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.2, 3.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.05, 0.0), Vector3.UP)
	camera.current = true
	world.add_child(camera)
	var archetypes: Array[StringName] = [&"ngeneral", &"ngeneral_veteran"]
	for index: int in range(archetypes.size()):
		var actor := ShadowFactory.create(archetypes[index]) as HopliteEnemyActorV2
		if actor == null:
			push_error("HOPLITE_V2_VISUAL_PROBE actor creation failed")
			quit(1)
			return
		actor.position = Vector3(-0.65 if index == 0 else 0.65, 0.0, 0.0)
		world.add_child(actor)
		actor.play_semantic_animation(&"block_idle" if index == 0 else &"spear_thrust")
		var label := Label3D.new()
		label.text = "STANDARD" if index == 0 else "VETERAN"
		label.position = actor.position + Vector3(0.0, 2.2, 0.0)
		label.font_size = 22
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	for _frame: int in range(18):
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if save_error != OK:
		push_error("HOPLITE_V2_VISUAL_PROBE save failed: %s" % error_string(save_error))
		quit(1)
		return
	print("HOPLITE_V2_VISUAL_PROBE saved=", OUTPUT)
	quit(0)
