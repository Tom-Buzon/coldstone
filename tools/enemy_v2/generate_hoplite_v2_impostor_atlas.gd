extends SceneTree

const ShadowFactory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const OUTPUT := "res://assets/characters/enemy_v2/hoplite/impostor/hoplite_v2_guard_cycle.png"
const FRAME_SIZE := Vector2i(256, 320)
const FRAME_COUNT := 4
var role_id: StringName = &"ngeneral"
var role_body_rect := Rect2i()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role_id = StringName(argument.trim_prefix("--role="))
	root.size = FRAME_SIZE
	root.transparent_bg = true
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.0, 0.0, 0.0, 0.0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("dce5f2")
	settings.ambient_light_energy = 1.05
	environment.environment = settings
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color("ffe3c2")
	key.light_energy = 1.65
	key.shadow_enabled = false
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
	rim.light_color = Color("b7d2ff")
	rim.light_energy = 0.75
	rim.shadow_enabled = false
	world.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.85 if role_id == &"ngeneral" else 3.5
	camera.position = Vector3(0.0, 1.30, 4.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.18, 0.0), Vector3.UP)
	camera.current = true
	world.add_child(camera)
	var actor := ShadowFactory.create(role_id) as HopliteEnemyActorV2
	if actor == null:
		push_error("HOPLITE_V2_IMPOSTOR_GENERATOR actor creation failed")
		quit(1)
		return
	actor.lod_reference = camera
	world.add_child(actor)
	actor.play_semantic_animation(&"bow_draw" if role_id == &"archer_v2" else &"block_idle", 0.0)
	for _warmup: int in range(12):
		await process_frame
		await physics_frame
	var player := actor.animation.player if actor.animation != null else null
	if player == null:
		push_error("HOPLITE_V2_IMPOSTOR_GENERATOR animation player missing")
		quit(1)
		return
	var animation := player.get_animation(player.current_animation)
	var duration := animation.length if animation != null else 1.0
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if role_id != &"ngeneral":
		actor.equipment.set_weapon_visible(false)
		actor.equipment.set_shield_visible(false)
		await process_frame
		await RenderingServer.frame_post_draw
		role_body_rect = root.get_texture().get_image().get_used_rect()
		print("ROLE_BODY_FRAME ", role_id, " ", role_body_rect)
		actor.equipment.set_weapon_visible(true)
		actor.equipment.set_shield_visible(true)
	var atlas := Image.create(FRAME_SIZE.x * FRAME_COUNT, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))
	for frame: int in range(FRAME_COUNT):
		player.seek(duration * float(frame) / float(FRAME_COUNT), true)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image = _fit_subject(image)
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, FRAME_SIZE), Vector2i(frame * FRAME_SIZE.x, 0))
	var output_path := OUTPUT if role_id == &"ngeneral" else "res://assets/characters/enemy_v2/hoplite/impostor/%s_cycle.png" % role_id
	var absolute_output := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var save_error := atlas.save_png(absolute_output)
	if save_error != OK:
		push_error("HOPLITE_V2_IMPOSTOR_GENERATOR save failed: %s" % error_string(save_error))
		quit(1)
		return
	print("HOPLITE_V2_IMPOSTOR_GENERATOR PASS frames=", FRAME_COUNT, " size=", atlas.get_size(), " output=", output_path)
	quit(0)


func _fit_subject(source: Image) -> Image:
	var framed := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	framed.fill(Color(0.0, 0.0, 0.0, 0.0))
	var used := source.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return framed
	var subject := source.get_region(used)
	if role_body_rect.size.y > 0:
		# Match the existing hoplite atlas' body height and ground line. Framing
		# against the bow would shrink the archer body at the LOD hand-off.
		var body_height := 224.0 if role_id == &"archer_v2" else 256.0
		var body_scale := body_height / float(role_body_rect.size.y)
		subject.resize(maxi(1, roundi(subject.get_width() * body_scale)), maxi(1, roundi(subject.get_height() * body_scale)), Image.INTERPOLATE_LANCZOS)
		var body_center := float(role_body_rect.position.x) + float(role_body_rect.size.x) * 0.5
		var destination := Vector2i(roundi(FRAME_SIZE.x * 0.5 + (used.position.x - body_center) * body_scale), roundi(FRAME_SIZE.y - 5 - (role_body_rect.end.y - used.position.y) * body_scale))
		framed.blit_rect(subject, Rect2i(Vector2i.ZERO, subject.get_size()), destination)
		return framed
	var maximum := Vector2(float(FRAME_SIZE.x) * 0.88, float(FRAME_SIZE.y) * 0.90)
	var scale := minf(maximum.x / float(subject.get_width()), maximum.y / float(subject.get_height()))
	var fitted_size := Vector2i(
		maxi(1, roundi(float(subject.get_width()) * scale)),
		maxi(1, roundi(float(subject.get_height()) * scale))
	)
	subject.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)
	var destination := Vector2i(
		(FRAME_SIZE.x - fitted_size.x) / 2,
		FRAME_SIZE.y - fitted_size.y - 5
	)
	framed.blit_rect(subject, Rect2i(Vector2i.ZERO, fitted_size), destination)
	return framed
