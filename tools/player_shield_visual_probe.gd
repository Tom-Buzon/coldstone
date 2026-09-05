extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const FRONT_OUTPUT := "res://docs/player_shield_front_probe.png"
const SIDE_OUTPUT := "res://docs/player_shield_side_probe.png"


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(720, 720)
	var world := Node3D.new()
	world.name = "PlayerShieldVisualProbe"
	root.add_child(world)
	current_scene = world

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.82)
	env.ambient_light_energy = 1.0
	environment.environment = env
	world.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	light.light_energy = 1.45
	world.add_child(light)

	var player := PlayerScript.new() as HopliteUALNativePlayer
	world.add_child(player)
	for _frame: int in range(12):
		await process_frame
		await physics_frame
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE), "Could not load the base player skin")
	for _frame: int in range(8):
		await process_frame
		await physics_frame
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3.ZERO
	player.sword_root.visible = false
	for node: Node in player.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	for node: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var belongs_to_character := player.mannequin_scene == mesh or player.mannequin_scene.is_ancestor_of(mesh)
		var belongs_to_shield := player.shield_root == mesh or player.shield_root.is_ancestor_of(mesh)
		mesh.visible = belongs_to_character or belongs_to_shield
	if player.animation_driver != null:
		player.animation_driver.set_locomotion(0.0)
	for _frame: int in range(6):
		await process_frame

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 42.0
	await _capture(camera, Vector3(0.0, 1.2, -2.35), FRONT_OUTPUT)
	await _capture(camera, Vector3(-2.35, 1.2, 0.0), SIDE_OUTPUT)
	print("[PLAYER SHIELD VISUAL PROBE] rest_transform=", player.shield_rest_transform)
	print("[PLAYER SHIELD VISUAL PROBE] local_position=", player.shield_root.position, " local_rotation_degrees=", player.shield_root.rotation_degrees)
	print("[PLAYER SHIELD VISUAL PROBE] hand=", player.left_hand_bone, " attachment=", player.shield_attachment.global_transform, " shield=", player.shield_root.global_transform)
	for bone_name: String in ["DEF-hips", "DEF-spine.002", "DEF-hand.L", "DEF-forearm.L"]:
		var bone_index := player.skeleton.find_bone(bone_name)
		if bone_index >= 0:
			print("[PLAYER SHIELD VISUAL PROBE] bone=", bone_name, " pose=", player.skeleton.get_bone_global_pose(bone_index))
	quit(0)


func _capture(camera: Camera3D, position: Vector3, output_path: String) -> void:
	camera.look_at_from_position(position, Vector3(0.0, 1.05, 0.0), Vector3.UP)
	for _frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save player shield probe: %s" % error_string(error))
		quit(1)
