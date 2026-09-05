extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -4.0)
	stage.add_child(target)

	var request: SpawnRequest = SpawnRequest.new()
	request.archetype = &"swordsman"
	request.target = target
	request.ai_enabled = false
	request.has_name_override = true
	request.name_override = "ActionStateProbeEnemy"
	var enemy := EnemyFactory.spawn_request(stage, request)
	_expect(enemy != null, "factory returned null")
	if enemy == null:
		_finish(stage)
		return
	enemy.ai_enabled = true
	enemy.ai_player = target
	enemy.battle_player = target

	# Existing priority contract: guard break owns the tick before recovery and
	# attack wind-up. Its timer advances, but wind-up remains frozen.
	enemy.guard_break_timer = 0.50
	enemy.ai_attack_recovery_timer = 0.50
	enemy.ai_attack_pending = true
	enemy.ai_attack_windup_timer = 0.40
	enemy.call("_physics_process", 0.10)
	_expect(is_equal_approx(enemy.guard_break_timer, 0.40), "guard-break timer did not advance")
	_expect(is_equal_approx(enemy.ai_attack_recovery_timer, 0.40), "recovery timer did not advance before priority resolution")
	_expect(is_equal_approx(enemy.ai_attack_windup_timer, 0.40), "guard break no longer freezes attack wind-up")
	_expect(enemy.ai_attack_pending, "guard break unexpectedly cancelled an otherwise valid pending attack")

	# Recovery owns the next priority slot when no wind-up is pending.
	enemy.guard_break_timer = 0.0
	enemy.ai_attack_pending = false
	enemy.ai_attack_recovery_timer = 0.50
	enemy.cached_ai_goal = {"sentinel": true}
	enemy.call("_physics_process", 0.10)
	_expect(is_equal_approx(enemy.ai_attack_recovery_timer, 0.40), "recovery timer did not advance")
	_expect(bool(enemy.cached_ai_goal.get("sentinel", false)), "recovery unexpectedly entered tactical decision")

	# Wind-up advances only after guard/recovery gates and keeps ownership until
	# its timer expires.
	enemy.ai_attack_recovery_timer = 0.50
	enemy.ai_attack_pending = true
	enemy.ai_attack_windup_timer = 0.50
	enemy.call("_physics_process", 0.10)
	_expect(enemy.ai_attack_pending, "wind-up resolved too early")
	_expect(is_equal_approx(enemy.ai_attack_windup_timer, 0.40), "wind-up timer changed")
	_expect(is_equal_approx(enemy.ai_attack_recovery_timer, 0.40), "pending wind-up no longer outranks recovery")

	# A queued parry counter precedes ordinary tactical selection.
	enemy.ai_attack_pending = false
	enemy.ai_attack_recovery_timer = 0.0
	enemy.guard_break_timer = 0.0
	enemy.defense_timer = 0.0
	enemy.defense_reaction_timer = -1.0
	enemy.defense_mode = &"none"
	enemy.parry_counter_queued = true
	enemy.ai_attack_cooldown_timer = 0.0
	target.position = enemy.position + Vector3(0.0, 0.0, -1.0)
	enemy.call("_physics_process", 0.01)
	_expect(not enemy.parry_counter_queued, "parry counter was not consumed")
	_expect(enemy.ai_attack_pending, "parry counter did not enter attack wind-up")
	_expect(enemy.ai_state == &"attack_windup", "parry counter diagnostic state changed")

	# Tactical decision remains the final branch. ai_state is the observable
	# tactical/diagnostic label, while timers above are the real action state.
	enemy.ai_attack_pending = false
	enemy.ai_attack_recovery_timer = 0.0
	enemy.parry_counter_queued = false
	enemy.ai_attack_cooldown_timer = 1.0
	enemy.ai_think_timer = 0.0
	enemy.cached_ai_goal.clear()
	target.position = enemy.position + Vector3(0.0, 0.0, -4.0)
	enemy.call("_physics_process", 0.01)
	_expect(not enemy.cached_ai_goal.is_empty(), "tactical decision did not populate a goal")
	_expect(enemy.ai_state == &"attack", "standard swordsman tactical state changed")

	# defense_timer keeps a queued parry pending without creating a transition.
	enemy.parry_counter_queued = true
	enemy.defense_timer = 0.50
	enemy.ai_attack_cooldown_timer = 1.0
	enemy.call("_physics_process", 0.01)
	_expect(enemy.parry_counter_queued, "defense window no longer blocks queued parry")

	# An invalid/out-of-range counter is consumed, then truthfully falls through
	# to tactical work in the same tick.
	enemy.defense_timer = 0.0
	enemy.parry_counter_queued = true
	enemy.cached_ai_goal.clear()
	enemy.ai_think_timer = 0.0
	target.position = enemy.position + Vector3(0.0, 0.0, -4.0)
	enemy.call("_physics_process", 0.01)
	_expect(not enemy.parry_counter_queued, "invalid parry counter was not consumed")
	_expect(not enemy.cached_ai_goal.is_empty(), "invalid parry did not fall through to tactical decision")

	_finish(stage)


func _finish(stage: Node) -> void:
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_ACTION_STATE_PROBE PASS: guard, recovery, wind-up, parry and tactical priority preserved")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY ACTION STATE] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
