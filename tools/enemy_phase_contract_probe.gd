extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")

var archetype: StringName = &"warlord"
var failures: Array[String] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			archetype = StringName(argument.trim_prefix("--id="))
	call_deferred("_run")


func _run() -> void:
	var profile: Dictionary = Archetypes.profile(archetype)
	var phase_two: Array = Array(profile.get("phase_two_pattern", []))
	var phase_three: Array = Array(profile.get("phase_three_pattern", []))
	_expect(float(profile.get("phase_threshold", 0.0)) > 0.0 and not phase_two.is_empty(), "%s has no declared phase-two contract" % archetype)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var target := Node3D.new()
	target.add_to_group("player")
	target.position = Vector3(0.0, 0.0, -1.0)
	world.add_child(target)
	var enemy = EnemyFactory.spawn(world, archetype, Vector3.ZERO, target, {"ai_enabled": true})
	await process_frame
	await physics_frame
	_expect(enemy != null, "%s factory phase fixture failed" % archetype)
	if enemy != null and not phase_two.is_empty():
		enemy.set_process(false)
		enemy.set_physics_process(false)
		var transitions: Array[int] = []
		enemy.combat_phase_changed.connect(func(_source: Node, phase: int) -> void: transitions.append(phase))
		var speed_one: float = enemy.ai_move_speed
		var damage_one: float = enemy.ai_attack_damage
		var cooldown_one: float = enemy.ai_attack_cooldown_min
		enemy.ai_attack_pending = true
		enemy.ai_attack_windup_timer = 1.0
		enemy.active_attack_step = {"id": &"stale_phase_one"}
		enemy.health = maxf(1.0, enemy.max_health * float(profile.get("phase_threshold", 0.0)) - 0.5)
		enemy.call("_try_activate_combat_phase")
		_expect(enemy.combat_phase == 2 and transitions == [2], "%s did not emit exactly one phase-two transition" % archetype)
		_expect(not enemy.ai_attack_pending and enemy.active_attack_step.is_empty(), "%s phase transition did not cancel the old windup atomically" % archetype)
		_expect(is_equal_approx(enemy.ai_move_speed, speed_one * float(profile.get("phase_speed_multiplier", 1.0))), "%s phase-two speed multiplier was not applied once" % archetype)
		_expect(is_equal_approx(enemy.ai_attack_damage, damage_one * float(profile.get("phase_damage_multiplier", 1.0))), "%s phase-two damage multiplier was not applied once" % archetype)
		_expect(is_equal_approx(enemy.ai_attack_cooldown_min, cooldown_one / float(profile.get("phase_speed_multiplier", 1.0))), "%s phase-two cooldown scaling is inconsistent" % archetype)
		_expect(_collect_runtime_pattern_ids(enemy, phase_two.size()) == _pattern_ids(phase_two), "%s phase-two runtime pattern differs from its declaration" % archetype)

		if not phase_three.is_empty():
			var speed_two: float = enemy.ai_move_speed
			var damage_two: float = enemy.ai_attack_damage
			enemy.health = maxf(1.0, enemy.max_health * float(profile.get("phase_three_threshold", 0.0)) - 0.5)
			enemy.call("_try_activate_combat_phase")
			_expect(enemy.combat_phase == 3 and transitions == [2, 3], "%s did not emit its declared phase-three transition" % archetype)
			_expect(is_equal_approx(enemy.ai_move_speed, speed_two * float(profile.get("phase_three_speed_multiplier", 1.0))), "%s phase-three speed multiplier was not applied once" % archetype)
			_expect(is_equal_approx(enemy.ai_attack_damage, damage_two * float(profile.get("phase_three_damage_multiplier", 1.0))), "%s phase-three damage multiplier was not applied once" % archetype)
			_expect(_collect_runtime_pattern_ids(enemy, phase_three.size()) == _pattern_ids(phase_three), "%s phase-three runtime pattern differs from its declaration" % archetype)

	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("ENEMY_PHASE_CONTRACT_PROBE PASS id=%s transitions=%s phase2_actions=%d phase3_actions=%d cleanup=true" % [archetype, [2, 3] if not phase_three.is_empty() else [2], phase_two.size(), phase_three.size()])
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _collect_runtime_pattern_ids(enemy: Node, count: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for _index: int in range(count):
		ids.append(StringName(enemy.call("_next_combat_pattern_step").get("id", StringName())))
	return ids


func _pattern_ids(pattern: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for raw_step: Variant in pattern:
		ids.append(StringName((raw_step as Dictionary).get("id", StringName())))
	return ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
