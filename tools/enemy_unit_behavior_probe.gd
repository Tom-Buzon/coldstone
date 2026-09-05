extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")
const CombatantRegistry = preload("res://scripts/enemy/combatant_registry.gd")

class CombatTarget:
	extends Node3D

	var faction: StringName = &"spartan"
	var health := 100000.0

	func receive_enemy_hit(damage: float, _source: Node, _direction: Vector3) -> void:
		health -= damage

	func receive_ai_hit(damage: float, _source: Node, _direction: Vector3) -> void:
		health -= damage

	func is_dead_for_combat() -> bool:
		return health <= 0.0

var archetype: StringName = &"captain"
var failures: Array[String] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			archetype = StringName(argument.trim_prefix("--id="))
	call_deferred("_run")

func _run() -> void:
	if not Archetypes.all_ids().has(archetype):
		failures.append("unknown archetype %s" % archetype)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var director := CrowdDirector.new()
	world.add_child(director)
	var registry := CombatantRegistry.new()
	world.add_child(registry)
	var target := CombatTarget.new()
	target.add_to_group("player")
	world.add_child(target)
	var enemy := EnemyFactory.spawn(world, archetype, Vector3.ZERO, target, {
		"ai_enabled": true,
		"mass_battle_mode": false,
	})
	await process_frame
	await physics_frame
	_expect(enemy != null, "%s factory behavior fixture failed" % archetype)
	if enemy != null:
		enemy.set_process(false)
		enemy.set_physics_process(false)
		_expect(enemy.ai_enabled and enemy.is_in_group("combatant_ai"), "%s did not enter active AI participation" % archetype)
		_expect(not String(enemy.ai_state).is_empty(), "%s has no initial explicit state" % archetype)

		# Far/close decisions must both return a bounded goal and explicit state.
		target.position = Vector3(0.0, 0.0, -minf(enemy.ai_aggro_distance - 0.5, maxf(enemy.ai_attack_range + 3.5, 4.0)))
		var far_goal: Dictionary = enemy._ai_goal()
		_expect(far_goal.has("active") and far_goal.has("target") and far_goal.has("attack_player"), "%s far decision returned an incomplete goal" % archetype)
		_expect(not String(enemy.ai_state).is_empty(), "%s far decision has no explicit state" % archetype)
		target.position = Vector3(0.0, 0.0, -maxf(0.65, enemy.ai_attack_range * 0.45))
		var close_goal: Dictionary = enemy._ai_goal()
		_expect(close_goal.has("active") and close_goal.has("target") and close_goal.has("attack_player"), "%s close decision returned an incomplete goal" % archetype)
		_expect(not String(enemy.ai_state).is_empty(), "%s close decision has no explicit state" % archetype)

		# Exercise every declarative attack step (or the static fallback) through
		# the real scheduler/windup/resolve path.
		var attempts := maxi(1, enemy.combat_pattern.size())
		var started := 0
		var resolved := 0
		var observed_steps: Dictionary = {}
		for _attack: int in range(attempts):
			enemy.ai_attack_pending = false
			enemy.ai_attack_cooldown_timer = 0.0
			enemy.ai_attack_recovery_timer = 0.0
			enemy.sword_dropped = false
			enemy._release_attack_permission()
			enemy._set_combat_target(target)
			enemy.look_at(target.global_position, Vector3.UP)
			enemy._begin_ai_attack()
			if enemy.ai_attack_pending:
				started += 1
				var step_id := StringName(enemy.active_attack_step.get("id", &"static"))
				observed_steps[step_id] = true
				enemy._resolve_ai_attack()
				if not enemy.ai_attack_pending:
					resolved += 1
			enemy._release_attack_permission()
		_expect(started == attempts and resolved == attempts, "%s did not start/resolve every attack step (%d/%d, %d/%d)" % [archetype, started, attempts, resolved, attempts])
		if not enemy.combat_pattern.is_empty():
			_expect(observed_steps.size() == enemy.combat_pattern.size(), "%s did not traverse every distinct combat-pattern step" % archetype)

		# A disarmed attack is interrupted before damage delivery.
		enemy.ai_attack_pending = false
		enemy.ai_attack_cooldown_timer = 0.0
		enemy.ai_attack_recovery_timer = 0.0
		enemy.sword_dropped = false
		enemy._release_attack_permission()
		enemy._set_combat_target(target)
		enemy._begin_ai_attack()
		var health_before_interrupt := target.health
		if enemy.weapon_kind != &"unarmed":
			enemy.sword_dropped = true
			enemy._resolve_ai_attack()
			_expect(not enemy.ai_attack_pending and enemy.ai_state == &"disarmed", "%s did not exit windup when disarmed" % archetype)
			_expect(is_equal_approx(target.health, health_before_interrupt), "%s delivered damage after disarm interruption" % archetype)
		else:
			enemy._release_attack_permission()

		# Losing the target and sleep/wake cannot leave leases or group divergence.
		target.remove_from_group("player")
		target.queue_free()
		await process_frame
		enemy._set_combat_target(null)
		var lost_goal: Dictionary = enemy._ai_goal()
		_expect(not bool(lost_goal.get("attack_player", true)), "%s kept attack authority after target loss" % archetype)
		_expect(not enemy.attack_permission_claimed, "%s retained a lease after target loss" % archetype)
		enemy.set_ai_participation(false)
		_expect(not enemy.is_in_group("combatant_ai") and not enemy.ai_enabled, "%s sleep retained active crowd membership" % archetype)
		enemy.set_ai_participation(true)
		_expect(enemy.is_in_group("combatant_ai") and enemy.ai_enabled, "%s wake did not restore crowd membership" % archetype)

	world.queue_free()
	await process_frame
	await process_frame
	_expect(get_nodes_in_group("combatant_ai").is_empty(), "%s behavior teardown retained AI members" % archetype)
	if failures.is_empty():
		print("ENEMY_UNIT_BEHAVIOR_PROBE PASS id=%s far/close, attacks, interruption, target-loss, sleep/wake, cleanup" % archetype)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
