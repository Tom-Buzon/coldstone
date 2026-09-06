extends SceneTree

const Player = preload("res://scripts/player.gd")
const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	collision.shape = box
	ground.add_child(collision)
	ground.position.y = -0.5
	world.add_child(ground)
	var player := Player.new()
	world.add_child(player)
	player.skills.profile.reset(true)
	player.skills.profile.set_tuning(&"aura_duration", 3.0)
	await physics_frame
	await physics_frame
	var enemies: Array[Node3D] = []
	for point: Vector3 in [Vector3(3, 0, 0), Vector3(0, 0, -4), Vector3(-3, 0, 0)]:
		var enemy := Factory.create(&"infantry_v2")
		enemy.combat_lab_enabled = true
		enemy.combat_target = player
		world.add_child(enemy)
		enemy.global_position = point
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemies.append(enemy)
	player.skills.add_charge(100)
	player.skills.select_ultimate(&"aura")
	player.skills.activate_ultimate()
	var max_speed := 0.0
	var frames := 0
	while player.skills.ultimate != &"" and frames < 500:
		await physics_frame
		max_speed = maxf(max_speed, Vector2(player.velocity.x, player.velocity.z).length())
		frames += 1
	var damaged := 0
	for enemy: Node3D in enemies:
		if enemy.health < enemy.max_health: damaged += 1
	_require(max_speed >= 25.0, "Aura never reached burst speed")
	_require(damaged >= 2, "Aura did not chain multiple real enemies")
	_require(player.skills.ultimate == &"", "Aura failed to expire")
	# Actual airborne X -> real floor collision -> camera and time recover.
	player.global_position = Vector3(0, 9, 7)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	player.skills.begin_plunge()
	var started_y: float = player.skills.cinema.anchor_y
	var camera_error := 0.0
	frames = 0
	while player.skills.plunge_active and frames < 500:
		await physics_frame
		if player.skills.cinema.camera_weight >= 0.99:
			camera_error = maxf(camera_error, absf(player.camera.global_position.y - started_y))
		frames += 1
	_require(not player.skills.plunge_active and player.is_on_floor(), "X did not complete on real floor")
	_require(camera_error < 0.7, "camera height drifted during actual plunge")
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1300: await process_frame
	_require(player.skills.cinema.camera_weight == 0.0 and is_equal_approx(Engine.time_scale, 1.0), "real cinematic left camera or world slowed")
	print("LIVE FLOW: aura max_speed=", max_speed, " damaged=", damaged, " plunge_camera_error=", camera_error)
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error("[SKILL LIVE] " + failure)
	if failures.is_empty(): print("PASS: live Aura chain and cinematic plunge physics lifecycle")
	quit(0 if failures.is_empty() else 1)

func _require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
