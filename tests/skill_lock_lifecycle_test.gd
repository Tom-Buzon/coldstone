extends SceneTree
const Player = preload("res://scripts/player.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30,1,30)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.5
	world.add_child(floor)
	var player := Player.new()
	world.add_child(player)
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.skills.profile.reset(true)
	var skills: Node = player.skills
	var driver: Node = player.animation_driver
	var controls: Node = skills.controls
	# Pause/focus/escape cancel a preparation exactly once, with its unused cost.
	for id: StringName in [&"thunder", &"flame"]:
		for reason: int in [Node.NOTIFICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
			skills.select_ultimate(id)
			skills.add_charge(100)
			check(skills.activate_ultimate(), "Preparation did not start")
			skills._notification(reason)
			controls._notification(reason)
			check(skills.ultimate == &"" and skills.ultimate_charge == 100, "Interrupted cast locked skills or refunded twice")
			check(not driver.is_heavy_charging() and skills.attack_allowed(&"light", &"air"), "Cast interruption retained charge or attack gate")
	# Choosing another ultimate releases the armed javelin without spending it.
	skills.select_ultimate(&"thunder")
	skills.activate_ultimate()
	skills.select_ultimate(&"ares")
	check(skills.ultimate == &"" and skills.ultimate_charge == 100, "Selection trapped old thunder")
	check(skills.activate_ultimate(), "Replacement ultimate stayed unavailable")
	skills.end_ultimate()
	player.primary_attack_held = true
	skills.end_ultimate()
	check(player.primary_attack_held, "Repeated ultimate cleanup erased unrelated primary input")
	player._reset_primary_attack_input()
	# Wheel opening during LMB hold must not schedule a shot on its release.
	skills.select_ultimate(&"thunder")
	skills.add_charge(100)
	skills.activate_ultimate()
	skills.thunder_button(true)
	controls.ultimate_button(true)
	controls.advance(0.3)
	skills.thunder_button(false)
	controls.ultimate_button(false)
	check(not skills.thunder_held and not skills.thunder_release_pending, "Wheel queued an accidental thunder release")
	controls.cancel()
	# Counter animation takes ownership without leaving X/cast locks behind.
	player.global_position.y = 5
	skills.begin_plunge()
	driver.play_external_attack(&"heavy_fast", &"heavy", &"counter_dash", true, 2)
	check(not skills.plunge_active and driver.current_attack_context_name() == &"counter_dash", "Counter left X active or lost its animation")
	driver._finish_attack()
	skills.select_ultimate(&"thunder")
	skills.activate_ultimate()
	driver.play_external_attack(&"heavy_fast", &"heavy", &"counter_dash", true, 2)
	check(skills.ultimate == &"" and skills.ultimate_charge == 100, "Counter left a charge preparation active")
	driver._finish_attack()
	# Expiry is independent of whether the previous Aura target still exists.
	skills.select_ultimate(&"aura")
	skills.activate_ultimate()
	var target := Node3D.new()
	world.add_child(target)
	skills.aura_target = target
	skills.aura_previous_target = target
	target.free()
	skills.remaining = 0.001
	skills.tick(0.016)
	check(skills.ultimate == &"" and skills.attack_allowed(&"heavy", &"air"), "Expired Aura retained a combat gate")
	# Landing already registered by physics (no new false->true callback).
	player.global_position = Vector3.ZERO
	await physics_frame
	player.velocity = Vector3.DOWN * 2
	player.move_and_slide()
	check(player.is_on_floor(), "Fixture did not establish floor contact")
	skills.begin_plunge()
	skills.tick(0.016)
	check(not skills.plunge_active and skills.attack_allowed(&"light", &"idle"), "Missed landing edge left X active")
	# An expired/orphaned cast timer must not block normal attacks forever.
	skills.cast_remaining = 2
	skills.tick(0.016)
	check(skills.cast_remaining == 0, "Orphaned cast timer was retained")
	player._do_light_attack()
	check(String(driver.current_attack_slot_name()).begins_with("light"), "Normal attack unavailable after lifecycle recovery")
	driver._finish_attack()
	skills.save_dirty = false
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("PASS: pause/focus, cast selection, wheel release, counter interruption, expired Aura and missed X landing")
	quit(0 if failures.is_empty() else 1)
