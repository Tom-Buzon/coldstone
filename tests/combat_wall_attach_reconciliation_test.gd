extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "CombatWallAttachReconciliationWorld"
	root.add_child(world)
	current_scene = world
	_add_static_box(world, Vector3(0.0, -0.10, 0.0), Vector3(12.0, 0.20, 12.0))

	var player := PlayerScript.new() as HopliteUALNativePlayer
	player.position = Vector3(0.0, 0.05, 1.0)
	world.add_child(player)
	for _frame: int in 4:
		await physics_frame
		await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED

	_require(player.animation_driver != null, "animation driver was not created")
	if player.animation_driver == null:
		_finish(world)
		return
	var original_layer := player.collision_layer
	var original_mask := player.collision_mask
	player.spiral_stamina = player.max_spiral_stamina
	for _charge: int in 4:
		player.spin_input_cooldown_timer = 0.0
		player._do_spin_attack(-1)
	_require(player.animation_driver.attack_queue.size() == 3, "four spiral inputs did not produce one active plus three buffered attacks")
	_require(player.animation_driver.current_action_blocks(&"wall_attach"), "active low spiral did not explicitly block wall attachment")

	player._begin_heavy_input(0.24)
	_require(player.animation_driver.attack_queue.is_empty(), "heavy charge did not cancel the authoritative attack queue")
	_require(player.spin_vertical_direction == 0, "cancelled spiral left a stale vertical direction")
	_require(not player.spiral_down_air_impact_pending, "cancelled spiral left an impact pending")
	_require(not player.spiral_down_enemy_passthrough, "cancelled spiral left enemy pass-through enabled")
	_require(player.collision_layer == original_layer and player.collision_mask == original_mask, "cancelled spiral did not restore player collision state")
	_require(not player.animation_driver.current_action_blocks(&"wall_attach"), "heavy charge inherited the cancelled spiral wall-attach block")
	player._cancel_heavy_charge()
	_require(not player.animation_driver.is_attack_active(), "heavy-charge cancellation left combat active")

	player.global_position = Vector3(0.0, 1.2, 1.0)
	player.velocity = Vector3(0.0, 1.0, 0.0)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	for _frame: int in 2:
		await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.wall_run_attach_available = true
	player.wall_run_attach_cooldown = 0.0
	player.wall_run_runs_used = 0
	Input.action_press(&"move_forward")
	var desired: Vector3 = player._desired_move_direction()
	var wall_position := player.global_position + desired.normalized() * 1.0
	wall_position.y = 2.5
	var wall := _add_static_box(world, wall_position, Vector3(4.0, 5.0, 0.50))
	wall.rotation.y = atan2(desired.x, desired.z)
	await physics_frame
	var attached := player._try_start_wall_run()
	Input.action_release(&"move_forward")
	_require(attached and player.wall_run_active, "wall attachment remained blocked after combat cancellation: %s" % player.wall_run_debug_reason)

	_finish(world)


func _add_static_box(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(world: Node3D) -> void:
	current_scene = null
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: combat action cancellation restores wall attachment")
		quit(0)
		return
	for failure: String in failures:
		push_error("[COMBAT WALL ATTACH] " + failure)
	quit(1)
