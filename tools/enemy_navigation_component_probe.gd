extends SceneTree

const NavigationComponent = preload("res://scripts/ai/enemy_navigation_component.gd")
const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe_direct_steering_and_arrival()
	_probe_formation_anchor_metadata()
	_probe_stuck_recovery()
	_probe_moving_goal_still_recovers()
	_probe_slow_progress_is_not_stuck()
	_probe_navmesh_fallback()
	_probe_enemy_facade_integration()
	if failures.is_empty():
		print("ENEMY_NAVIGATION_COMPONENT_PROBE PASS: intent, formation, fallback and recovery")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _probe_direct_steering_and_arrival() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var navigation := NavigationComponent.new()
	navigation.configure(body, NavigationComponent.Mode.DIRECT_STEERING, {"arrival_distance": 0.25})
	navigation.set_destination(Vector3(4.0, 3.0, 0.0))
	var intent = navigation.sample_intent(0.1)
	_expect(intent.valid, "direct steering returned no valid intent")
	_expect(intent.status == &"moving", "direct steering did not report moving")
	_expect(intent.direction.is_equal_approx(Vector3.RIGHT), "ground steering did not flatten and normalize its direction")
	_expect(is_equal_approx(intent.speed_scale, 1.0), "direct steering changed full-speed intent")
	body.position = Vector3(3.9, 0.0, 0.0)
	intent = navigation.sample_intent(0.1)
	_expect(intent.status == &"arrived" and not intent.valid, "arrival tolerance did not stop locomotion")
	body.queue_free()

func _probe_formation_anchor_metadata() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var navigation := NavigationComponent.new()
	navigation.configure(body, NavigationComponent.Mode.FORMATION_LOCAL)
	navigation.set_formation_anchor(Vector3(0.0, 0.0, -5.0), Vector3.FORWARD, 7, 3)
	var intent = navigation.sample_intent(0.1)
	_expect(intent.valid and intent.direction.is_equal_approx(Vector3.FORWARD), "formation mode did not steer toward its slot")
	body.position = Vector3(0.0, 0.0, -4.4)
	intent = navigation.sample_intent(0.1)
	_expect(intent.valid and is_equal_approx(intent.speed_scale, 1.0), "formation arrival ramp still slows an approaching cohort before the final brake")
	body.position = Vector3(0.0, 0.0, -4.6)
	intent = navigation.sample_intent(0.1)
	_expect(intent.valid and intent.speed_scale > 0.85 and intent.speed_scale < 0.92, "formation final brake is not using the fast default profile")
	body.position = Vector3(0.0, 0.0, -4.68)
	intent = navigation.sample_intent(0.1)
	_expect(intent.valid and intent.speed_scale >= 0.80 and intent.speed_scale < 0.84, "formation arrival did not retain the configured minimum speed immediately before its slot")
	navigation.set_arrival_profile(1.10, 0.40)
	intent = navigation.sample_intent(0.1)
	_expect(intent.valid and intent.speed_scale >= 0.40 and intent.speed_scale < 0.42, "live formation arrival profile did not reach the navigation component")
	_expect(navigation.formation_slot == 7 and navigation.cohort_revision == 3, "formation metadata was not retained")
	body.queue_free()

func _probe_stuck_recovery() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var navigation := NavigationComponent.new()
	navigation.configure(body, NavigationComponent.Mode.DIRECT_STEERING, {
		"stuck_timeout": 0.20,
		"recovery_duration": 0.30,
		"minimum_progress_speed": 0.05,
	})
	navigation.set_destination(Vector3(6.0, 0.0, 0.0))
	navigation.sample_intent(0.1)
	for _step: int in range(4):
		navigation.notify_motion_applied(body.global_position, body.global_position, 0.1)
	var intent = navigation.sample_intent(0.1)
	_expect(intent.status == &"recovering", "blocked movement did not enter bounded recovery")
	_expect(intent.recovery_attempt == 1, "first stuck event did not produce attempt 1")
	_expect(absf(intent.direction.z) > 0.5, "recovery did not create a lateral escape direction")
	body.queue_free()

func _probe_moving_goal_still_recovers() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var navigation := NavigationComponent.new()
	navigation.configure(body, NavigationComponent.Mode.DIRECT_STEERING, {"stuck_timeout": 0.20})
	for step: int in range(5):
		navigation.set_destination(Vector3(5.0 + float(step) * 0.08, 0.0, 0.0))
		navigation.sample_intent(0.05)
		navigation.notify_motion_applied(body.global_position, body.global_position, 0.05, Vector3.RIGHT)
	var intent = navigation.sample_intent(0.05)
	_expect(intent.status == &"recovering", "small target drift continuously reset stuck recovery")
	body.queue_free()

func _probe_slow_progress_is_not_stuck() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var navigation := NavigationComponent.new()
	navigation.configure(body, NavigationComponent.Mode.DIRECT_STEERING, {
		"stuck_timeout": 0.20,
		"minimum_progress_speed": 0.20,
	})
	navigation.set_destination(Vector3(5.0, 0.0, 0.0))
	for _step: int in range(20):
		var previous := body.global_position
		body.global_position += Vector3.RIGHT * 0.012
		navigation.sample_intent(1.0 / 60.0)
		navigation.notify_motion_applied(previous, body.global_position, 1.0 / 60.0, Vector3.RIGHT)
	var intent = navigation.sample_intent(1.0 / 60.0)
	_expect(intent.status != &"recovering", "valid crawl-speed progress was classified as stuck")
	body.queue_free()

func _probe_navmesh_fallback() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var navigation := NavigationComponent.new()
	var failures_seen: Array[StringName] = []
	navigation.navigation_failed.connect(func(reason: StringName) -> void: failures_seen.append(reason))
	navigation.configure(body, NavigationComponent.Mode.NAVMESH_GROUND, {"fallback_mode": NavigationComponent.Mode.DIRECT_STEERING})
	navigation.set_destination(Vector3(0.0, 0.0, 3.0))
	var first = navigation.sample_intent(0.1)
	var second = navigation.sample_intent(0.1)
	_expect(first.valid and first.status == &"fallback_direct", "missing navmesh did not use controlled direct fallback")
	_expect(second.valid and failures_seen == [&"navmesh_unavailable"], "navmesh failure was not emitted exactly once per destination revision")
	_expect(navigation is RefCounted, "navigation component is not a lightweight RefCounted service")
	var agent := body.get_node_or_null("NavigationAgent") as NavigationAgent3D
	_expect(agent != null and agent.get_parent() is Node3D, "NavigationAgent3D has an invalid non-3D parent")
	body.queue_free()

func _probe_enemy_facade_integration() -> void:
	var enemy := Enemy.new()
	enemy.ai_enabled = true
	enemy.archetype_id = &"swordsman"
	root.add_child(enemy)
	var navigation: Variant = enemy.navigation_component
	_expect(navigation != null, "enemy facade did not create its navigation component")
	if navigation != null:
		_expect(navigation.owner_body == enemy, "enemy facade did not configure itself as the single motion owner")
	enemy.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
