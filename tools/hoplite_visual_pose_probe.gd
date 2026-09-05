extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const OUTPUT := "res://docs/enemy_refactor/hoplite_visual_pose_probe.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(720, 720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.35, -2.7)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.12, 0.0), Vector3.UP)
	world.add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_energy = 1.4
	world.add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.72)
	env.ambient_light_energy = 0.85
	environment.environment = env
	world.add_child(environment)

	var enemy := Enemy.new() as HopliteAthenianEnemy
	enemy.archetype_id = &"ngeneral"
	enemy.ai_enabled = false
	world.add_child(enemy)
	for _frame: int in range(12):
		await process_frame
		await physics_frame
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.stop_full_body()
		enemy.ai_animation_driver.set_locomotion(1.0)
		enemy.ai_animation_driver.begin_block()
		if enemy.shield_root != null:
			enemy.shield_root.visible = false
		if enemy.sword_root != null:
			enemy.sword_root.visible = false
		var merged := enemy.find_child("SPARTAN_body_merged", true, false) as MeshInstance3D
		print("HOPLITE_RENDER_SKIN show_rest_only=", enemy.skeleton.show_rest_only, " skeleton_path=", merged.skeleton if merged != null else NodePath(), " mesh_parent=", merged.get_parent().get_path() if merged != null else NodePath())
	for _frame: int in range(12):
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("HOPLITE_VISUAL_POSE_PROBE could not save screenshot: %s" % error_string(error))
		quit(1)
		return
	print("HOPLITE_VISUAL_POSE_PROBE saved=", OUTPUT)
	quit(0)
