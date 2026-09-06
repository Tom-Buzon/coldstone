extends SceneTree

var failures: Array[String] = []
var player: Node3D
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(640, 300)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func motion() -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(2, 0)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _run() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	player = preload("res://scripts/player.gd").new()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.skills.set_process(false)
	player.skills.profile.reset(true)
	await process_frame
	for scenario: Vector2i in [Vector2i(Input.MOUSE_MODE_CAPTURED, 300), Vector2i(Input.MOUSE_MODE_VISIBLE, 300), Vector2i(Input.MOUSE_MODE_CONFINED, 300), Vector2i(Input.MOUSE_MODE_CAPTURED, 0)]:
		var mode := scenario.x
		player.health = scenario.y
		Input.mouse_mode = mode
		mouse(true)
		player._update_primary_attack_input(0.016)
		await process_frame
		motion()
		player.skills.tick(0.016)
		mouse(false)
		player._update_primary_attack_input(0.016)
		check(String(player.animation_driver.current_attack_slot_name()).begins_with("light"), "Light lost with mouse mode " + str(mode) + " HP=" + str(scenario.y))
		player.animation_driver._finish_attack()
		await process_frame
		mouse(true)
		player._update_primary_attack_input(0.016)
		await process_frame
		motion()
		player.skills.tick(0.016)
		player._update_primary_attack_input(0.3)
		check(player.heavy_charging, "Heavy lost with mouse mode " + str(mode) + " HP=" + str(scenario.y))
		mouse(false)
		player._update_primary_attack_input(0.016)
		player._cancel_heavy_charge()
		player.animation_driver._finish_attack()
		await process_frame
		player.skills.select_ultimate(&"ares")
		player.skills.add_charge(100)
		key(KEY_Q, true)
		key(KEY_Q, false)
		player.skills._process(0.016)
		check(player.skills.ultimate == &"ares", "Ultimate lost with mouse mode " + str(mode) + " HP=" + str(scenario.y))
		player.skills.end_ultimate()
		key(KEY_X, true)
		key(KEY_X, false)
		player.skills.tick(0.016)
		check(player.skills.plunge_active, "X lost with mouse mode " + str(mode) + " HP=" + str(scenario.y))
		player.skills.on_landed()
		player.animation_driver._finish_attack()
		player.spiral_stamina = 12
		player.spin_input_cooldown_timer = 0
		player._do_spin_attack(1)
		check(player.animation_driver.current_attack_slot_name() == &"spin360", "Spiral failed in reference scenario")
		player.animation_driver._finish_attack()
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.skills.save_dirty = false
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("PASS: light, heavy, ultimate, X and spiral across captured, visible and confined cursor, including zero HP")
	quit(0 if failures.is_empty() else 1)
