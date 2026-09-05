extends SceneTree

const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")

class ProbeTarget extends CharacterBody3D:
	var health := 1000.0
	var hits := 0
	var maximum_damage := 0.0

	func receive_enemy_hit(damage: float, _attacker: Node = null, _direction: Vector3 = Vector3.ZERO) -> bool:
		health -= damage
		hits += 1
		maximum_damage = maxf(maximum_damage, damage)
		return true

	func register_enemy_near_miss(_attacker: Node = null) -> bool:
		return false


var failures: Array[String] = []
var attack_started_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.1
	floor.add_child(floor_shape)
	world.add_child(floor)
	var target := ProbeTarget.new()
	target.position = Vector3(0.0, 0.0, -4.0)
	world.add_child(target)
	var actor := Factory.create(&"ngeneral") as HopliteEnemyActorV2
	actor.combat_lab_enabled = true
	actor.combat_target = target
	actor.lod_reference = target
	var telegraphed_patterns: Array[StringName] = []
	actor.attack_started.connect(func(_enemy: Node, weapon_kind: StringName) -> void:
		attack_started_count += 1
		_expect(weapon_kind == &"spear", "common attack signal reported the wrong weapon kind")
	)
	actor.attack_telegraphed.connect(func(_enemy: Node, pattern_id: StringName, windup_seconds: float) -> void:
		if not telegraphed_patterns.has(pattern_id):
			telegraphed_patterns.append(pattern_id)
		_expect(windup_seconds > 0.25, "attack telegraph has no readable windup")
	)
	world.add_child(actor)
	for _frame: int in range(8):
		await physics_frame

	# Defense is physical and modifies the ordinary combat HitEvent contract.
	var shield_event := HitEventScript.new()
	shield_event.source = target
	shield_event.attack_slot = &"light1"
	shield_event.damage = 18.0
	shield_event.guard_damage = 12.0
	var blocked := actor.receive_shield_hit(shield_event)
	_expect(blocked, "front-facing attack did not hit the active V2 shield")
	_expect(shield_event.contact_type in [&"shield", &"guard_break"], "shield defense did not mark its shared contact result")
	_expect(shield_event.hit_material == &"metal", "shield defense did not mark the hit as metal")
	_expect(actor.animation.current_semantic == &"block_impact", "shield defense did not play its impact reaction")
	if actor.guard.broken:
		actor.guard.force_recover()
	for _frame: int in range(30):
		await physics_frame

	# Each spear animation now has one explicit tactical trigger instead of being
	# selected by a blind cycle. Exercise the range edge, normal advance and crush.
	var bayonet_result := await _exercise_pattern(actor, target, &"bayonet_step", 3.25)
	var torso_result := await _exercise_pattern(actor, target, &"torso_thrust", 2.25)
	var low_result := await _exercise_pattern(actor, target, &"low_thrust", 1.30)
	var toward_target := (target.global_position - actor.global_position).normalized()
	_expect(actor.global_basis.z.dot(toward_target) > 0.90, "authored +Z visual does not face the combat target")
	_expect(actor.health_component != null and actor.health_component.anatomy != null, "combat actor has no anatomy receiver")
	_expect(actor.attack_telegraph != null, "combat actor has no shared attack telegraph component")
	_expect(target.hits >= 3, "combat actor did not complete its three tactical spear patterns")
	_expect(attack_started_count >= 3, "common attack_started signal was not emitted for every pattern")
	for expected: StringName in [&"torso_thrust", &"low_thrust", &"bayonet_step"]:
		_expect(telegraphed_patterns.has(expected), "missing spear pattern: %s" % expected)
	_expect(bool(bayonet_result.get("hit", false)), "Bayonet gap closer did not deliver a hit")
	_expect(bool(torso_result.get("hit", false)), "moving torso thrust did not deliver a hit")
	_expect(bool(low_result.get("hit", false)), "close low thrust did not deliver a hit")
	_expect(not bool(bayonet_result.get("shield_active_during_attack", true)), "exposed two-handed Bayonet unexpectedly kept the physical guard")
	_expect(bool(torso_result.get("shield_active_during_attack", false)), "torso thrust dropped the physical guard during its attack")
	_expect(bool(low_result.get("shield_active_during_attack", false)), "low thrust dropped the physical guard during its attack")
	_expect(float(torso_result.get("movement", 0.0)) > 0.20, "normal thrust still forces the hoplite to stop before striking")
	_expect(target.maximum_damage >= actor.definition.attack_damage * 2.1, "Bayonet gap closer did not apply its increased damage")

	# A fully charged heavy always breaks this class-configured guard, stuns the
	# defender and asks its combat controller for the configured backward step.
	actor.guard.force_recover()
	actor.combat.attack_cooldown = 1.0
	actor.combat._transition(HopliteV2CombatComponent.State.GUARD)
	target.global_position = actor.global_position + actor.global_basis.z.normalized() * 2.0
	await physics_frame
	var break_origin := actor.global_position
	var break_event := HitEventScript.new()
	break_event.source = target
	break_event.attack_slot = &"heavy"
	break_event.attack_charge_ratio = 1.0
	break_event.damage = 36.0
	break_event.guard_damage = 132.0
	var health_before_break := actor.health
	_expect(actor.receive_shield_hit(break_event), "fully charged heavy did not reach the raised V2 guard")
	_expect(break_event.guard_broken and break_event.guard_bypassed and break_event.contact_type == &"guard_break", "fully charged heavy did not bypass and break the shared guard")
	_expect(actor.health < health_before_break, "fully charged heavy was still swallowed by the broken shield")
	_expect(actor.combat.state == HopliteV2CombatComponent.State.STUNNED, "guard break did not enter the stunned combat state")
	var expected_step := (break_origin - target.global_position).normalized()
	target.global_position += Vector3(0.0, 0.0, 30.0)
	for _frame: int in range(65):
		await physics_frame
	var actual_step := actor.global_position - break_origin
	_expect(actual_step.dot(expected_step) > 0.20, "guard break did not move the defender backward")
	_expect(not actor.guard.broken and actor.combat.state != HopliteV2CombatComponent.State.STUNNED, "guard break stun did not recover")

	var death_ground_y := actor.global_position.y
	var event := HitEventScript.new()
	event.source = target
	event.damage = actor.definition.max_health + 10.0
	event.position = actor.global_position + Vector3.UP
	actor.receive_anatomy_hit(event, &"torso")
	_expect(actor.dead, "lethal anatomy damage did not kill the actor")
	_expect(actor.animation.current_semantic == &"death", "death animation was not selected")
	_expect(actor.collision_layer == 0, "dead actor kept its locomotion collision layer")
	for _frame: int in range(170):
		await physics_frame
	var lowest: float = actor.health_component.anatomy.estimate_lowest_surface_y()
	_expect(absf(lowest - (death_ground_y + 0.015)) <= 0.08, "death pose was not grounded (lowest=%.3f ground=%.3f)" % [lowest, death_ground_y])
	var delivered_hits := target.hits
	actor.free()
	target.free()
	world.free()
	if failures.is_empty():
		print("HOPLITE_V2_COMBAT_PROBE PASS hits=", delivered_hits, " patterns=", telegraphed_patterns, " defense=true death_grounded=true")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 COMBAT] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _exercise_pattern(
	actor: HopliteEnemyActorV2,
	target: ProbeTarget,
	expected_pattern: StringName,
	distance: float
) -> Dictionary:
	actor.guard.force_recover()
	actor.combat.attack_cooldown = 0.0
	if expected_pattern == &"bayonet_step":
		actor.combat.bayonet_cooldown = 0.0
	elif expected_pattern == &"torso_thrust":
		actor.combat.bayonet_cooldown = 2.0
	actor.combat._transition(HopliteV2CombatComponent.State.GUARD)
	var forward := actor.global_basis.z.normalized()
	target.global_position = actor.global_position + forward * distance
	var observed := false
	var start_position := actor.global_position
	var hits_before := target.hits
	var shield_active_during_attack := false
	for _frame: int in range(180):
		await physics_frame
		if actor.combat.state == HopliteV2CombatComponent.State.ATTACK and StringName(actor.combat.current_pattern.get("id", &"")) == expected_pattern:
			shield_active_during_attack = actor.equipment.shield_hitbox != null and actor.equipment.shield_hitbox.active
			if not observed:
				observed = true
				start_position = actor.global_position
		if observed and target.hits > hits_before:
			break
	_expect(observed, "distance %.2f did not select %s" % [distance, expected_pattern])
	return {
		"observed": observed,
		"hit": target.hits > hits_before,
		"movement": actor.global_position.distance_to(start_position),
		"shield_active_during_attack": shield_active_during_attack,
	}
