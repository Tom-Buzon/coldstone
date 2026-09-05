extends SceneTree

const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")

const DINOSAUR_COUNT := 20
const SAMPLE_FRAMES := 120

var _stage: Node3D
var _failed := false


func _initialize() -> void:
	_stage = Node3D.new()
	_stage.name = "DinosaurLODPerformanceProbe"
	root.add_child(_stage)
	call_deferred("_run")


func _run() -> void:
	_build_floor()
	_build_camera_and_light()
	var battle_reference := Node3D.new()
	battle_reference.name = "BattleReference"
	_stage.add_child(battle_reference)
	var ai_target := Node3D.new()
	ai_target.name = "DistantAITarget"
	ai_target.position = Vector3(80.0, 0.0, 0.0)
	_stage.add_child(ai_target)
	var dinosaurs: Array[HopliteDinosaurEnemy] = []
	for index: int in range(DINOSAUR_COUNT):
		var angle: float = TAU * float(index) / float(DINOSAUR_COUNT)
		var radius: float = 10.0 + float(index % 3) * 1.6
		var spawn_position := Vector3(cos(angle) * radius, 0.05, sin(angle) * radius)
		var dinosaur := EnemyFactoryScript.spawn(_stage, &"velociraptor", spawn_position, ai_target, {
			"ai_enabled": true,
			"performance_profile": "auto",
			"planned_simultaneous_population": DINOSAUR_COUNT,
			"battle_player": battle_reference,
			"match_perfect_hitbox": true,
			"giant_traversal_mode": &"exact",
		}) as HopliteDinosaurEnemy
		if dinosaur != null:
			dinosaur.ai_attack_cooldown_timer = 999.0
			dinosaur._update_performance_lod()
			dinosaurs.append(dinosaur)
	_check(dinosaurs.size() == DINOSAUR_COUNT, "20 velociraptors instantiated")
	await physics_frame
	for dinosaur: HopliteDinosaurEnemy in dinosaurs:
		dinosaur.dinosaur_full_physics_steps = 0
		dinosaur.dinosaur_deferred_physics_steps = 0
		dinosaur.dinosaur_anatomy_updates = 0

	var start_usec := Time.get_ticks_usec()
	for _frame: int in range(SAMPLE_FRAMES):
		await physics_frame
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var full_steps := 0
	var deferred_steps := 0
	var anatomy_updates := 0
	var manual_animation_count := 0
	var traversal_body_count := 0
	for dinosaur: HopliteDinosaurEnemy in dinosaurs:
		full_steps += dinosaur.dinosaur_full_physics_steps
		deferred_steps += dinosaur.dinosaur_deferred_physics_steps
		anatomy_updates += dinosaur.dinosaur_anatomy_updates
		manual_animation_count += 1 if dinosaur.dinosaur_animation_manual else 0
		traversal_body_count += dinosaur.traversal_by_zone.size()
	var total_steps := full_steps + deferred_steps
	var expected_steps := DINOSAUR_COUNT * SAMPLE_FRAMES
	var measured_fps: float = float(Performance.get_monitor(Performance.TIME_FPS))
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_check(manual_animation_count == DINOSAUR_COUNT, "20-raptor Forge pack samples animation at crowd cadence")
	_check(deferred_steps >= int(float(total_steps) * 0.40), "near crowd defers at least 40% of non-contact AI steps")
	_check(anatomy_updates <= full_steps + DINOSAUR_COUNT, "anatomy is sampled at most once per executed physics step")
	_check(abs(total_steps - expected_steps) <= DINOSAUR_COUNT * 2, "LOD accounts for every dinosaur physics tick")
	_check(traversal_body_count == DINOSAUR_COUNT * 15, "close LOD preserves exact raptor traversal")
	print(
		"[DINOSAUR LOD BENCH] dinosaurs=", DINOSAUR_COUNT,
		" frames=", SAMPLE_FRAMES,
		" elapsed_ms=", snappedf(float(elapsed_usec) / 1000.0, 0.01),
		" full_steps=", full_steps,
		" deferred_steps=", deferred_steps,
		" anatomy_updates=", anatomy_updates,
		" legacy_anatomy_updates=", expected_steps * 3,
		" traversal_bodies=", traversal_body_count,
		" fps=", snappedf(measured_fps, 0.1),
		" draw_calls=", draw_calls
	)
	print("[DINOSAUR LOD BENCH] RESULT=", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)


func _build_floor() -> void:
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	_stage.add_child(floor)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(220.0, 0.2, 220.0)
	collision.shape = shape
	collision.position.y = -0.1
	floor.add_child(collision)


func _build_camera_and_light() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 11.0, 24.0)
	camera.current = true
	_stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.5, 0.0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	light.shadow_enabled = true
	_stage.add_child(light)


func _check(condition: bool, label: String) -> void:
	print("[DINOSAUR LOD BENCH] ", "PASS " if condition else "FAIL ", label)
	_failed = _failed or not condition
