extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
var failures: Array[String] = []

func _initialize() -> void:
	# Exercise locomotion without loading skins, audio or a gameplay scene.
	var player := PlayerScript.new()
	Input.action_press(&"move_forward", 0.60)
	var strength := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length()
	for tick: int in 120:
		player._update_free_movement(Vector3.FORWARD, 1.0, 1.0 / 60.0)
	_require(is_equal_approx(player.velocity.length(), player.max_speed * strength), "partial stick did not produce proportional speed")
	Input.action_press(&"move_forward", 1.0)
	for tick: int in 120:
		player._update_free_movement(Vector3.FORWARD, 1.0, 1.0 / 60.0)
	_require(is_equal_approx(player.velocity.length(), player.max_speed), "full input lost maximum speed")
	Input.action_release(&"move_forward")
	for tick: int in 120:
		player._update_free_movement(Vector3.ZERO, 1.0, 1.0 / 60.0)
	_require(player.velocity.is_zero_approx(), "releasing input did not stop movement")
	var angles: Array[float] = []
	for hz: int in [30, 60, 144]:
		player.rotation.y = 0.0
		for tick: int in hz / 6:
			player._face_direction(Vector3.RIGHT, 1.0 / float(hz))
		angles.append(player.rotation.y)
	_require(absf(angles[0] - angles[1]) < 0.0001 and absf(angles[1] - angles[2]) < 0.0001, "facing response depends on frame rate")
	player.free()
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: proportional movement and frame-independent facing")
	quit(0 if failures.is_empty() else 1)

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
