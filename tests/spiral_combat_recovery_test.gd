extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := preload("res://scripts/player.gd").new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.skills.profile.reset(true)
	var driver: Node = player.animation_driver
	for direction: int in [1, -1]:
		player.spiral_stamina = 12
		for index: int in 4:
			player.spin_input_cooldown_timer = 0
			player._do_spin_attack(direction)
		for step: int in 480: driver.tick(1.0 / 60)
		check(not driver.is_attack_active(), "Four buffered spirals never finished")
		check(player.spiral_active_request_id == 0, "Spiral request remained active")
		player._do_light_attack()
		check(String(driver.current_attack_slot_name()).begins_with("light"), "Normal light blocked after spiral")
		driver._finish_attack()
		player._finish_spiral_action(true)
		check(not player.spiral_down_enemy_passthrough, "Interrupted spiral kept ghost collision")
	# Replacing a persistent charge must never leave the finite attack frozen.
	driver.begin_heavy_charge(&"idle")
	driver.play_external_attack(&"spin_high", &"spin360", &"idle", true, 2.65)
	for step: int in 240: driver.tick(1.0 / 60)
	check(not driver.is_attack_active() and not driver.is_heavy_charging(), "Replaced charge froze spiral timer")
	player._begin_heavy_input()
	player._reset_primary_attack_input()
	player.reconcile_combat_holds()
	check(not player.heavy_charging and not driver.is_heavy_charging(), "Lost heavy release locked all combat")
	player.skills.swap_weapon()
	check(player.skills.ranged_active, "Weapon switch remained locked")
	player.skills.ranged_active = false
	player._do_light_attack()
	check(driver.is_attack_active(), "Normal attack unavailable after recovery")
	player.skills.save_dirty = false
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("PASS: four queued up/down spirals, normal attacks, interrupted charge and collision recovery")
	quit(0 if failures.is_empty() else 1)
