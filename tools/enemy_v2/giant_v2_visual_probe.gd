extends SceneTree
const Definition = preload("res://scripts/enemy_v2/giant_v2_definition.gd")
const Presentation = preload("res://scripts/enemy_v2/giant_v2_presentation_component.gd")
const AnimationComponent = preload("res://scripts/enemy_v2/hoplite_v2_animation_component.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1300, 800)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("192333")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = 0.8
	env.environment = settings
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 4.5, 15), Vector3(0, 2.6, 0))
	camera.current = true
	var clips: Array[StringName] = [&"idle", &"giant_punch", &"giant_swipe", &"giant_slam"]
	for index: int in range(4):
		var visual := Presentation.new()
		visual.position.x = float(index) * 4.1 - 6.15
		world.add_child(visual)
		visual.install(Definition.create())
		var anim := AnimationComponent.new()
		world.add_child(anim)
		anim.install(visual.skeleton, Definition.create())
		anim.play_semantic(clips[index], 0.0)
		anim.set_manual_sampling(true)
		anim.sample(0.05 if index == 0 else (0.65 if index == 1 else (1.6 if index == 2 else 2.28)))
		var label := Label3D.new()
		label.text = String(clips[index]) + " x3"
		label.position = Vector3(visual.position.x, 5.8, 0)
		label.font_size = 30
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		print("GIANT_POSE ", clips[index], " head=", visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("DEF-head")))
	for i: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tmp_tools/giant_v2_visual.png"))
	world.queue_free()
	await process_frame
	quit()
