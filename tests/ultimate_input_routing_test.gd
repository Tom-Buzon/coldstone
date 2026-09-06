extends SceneTree

var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")

func _key(physical: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := preload("res://scripts/player.gd").new()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.skills.profile.reset(true)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for index: int in 8:
		_key(KEY_Q, true)
		_key(KEY_Q, false)
		await process_frame
		await process_frame
		if player.skills.ultimate != &"" or player.skills.activation_buffer > 0:
			failures.append("Empty A left an ultimate or activation buffer")
		var previous: bool = player.skills.ranged_active
		_key(KEY_E, true)
		_key(KEY_E, false)
		await process_frame
		if player.skills.ranged_active == previous: failures.append("E failed after empty A")
	player.skills.select_ultimate(&"thunder")
	player.skills.add_charge(100)
	_key(KEY_Q, true)
	_key(KEY_Q, false)
	await process_frame
	await process_frame
	if player.skills.ultimate != &"thunder": failures.append("Ready A failed after repeated empty taps")
	_key(KEY_E, true)
	_key(KEY_E, false)
	await process_frame
	if player.skills.ultimate != &"" or player.skills.ultimate_charge != 100:
		failures.append("E did not cancel armed thunder and refund charge")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.skills.save_dirty = false
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("PASS: physical A/E input routing, repeated empty gauge taps, ready activation and cancellation")
	quit(0 if failures.is_empty() else 1)
