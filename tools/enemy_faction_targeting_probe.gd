extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "EnemyFactionTargetingProbeStage"
	root.add_child(stage)
	var director: HopliteBattleCrowdDirector = CrowdDirector.new()
	director.name = "TargetSnapshotCrowdDirector"
	stage.add_child(director)
	director.set_physics_process(false)

	var player := Node3D.new()
	player.name = "ProbePlayer"
	player.position = Vector3.ZERO
	stage.add_child(player)
	player.add_to_group("player")
	var alternate_target := Node3D.new()
	alternate_target.name = "AlternateImmediateTarget"
	stage.add_child(alternate_target)
	var stable_reference := Node3D.new()
	stable_reference.name = "StableBattleReference"
	stage.add_child(stable_reference)

	var hostile_primary := _spawn_combatant(
		stage, "HostilePrimary", &"athenian", Vector3(0.0, 0.0, 4.0), player
	)
	var hostile_secondary := _spawn_combatant(
		stage, "HostileSecondary", &"athenian", Vector3(0.0, 0.0, 9.0), null
	)
	var spartan_near := _spawn_spartan(stage, "SpartanNear", Vector3(1.0, 0.0, 6.0), player)
	var spartan_far := _spawn_spartan(stage, "SpartanFar", Vector3(8.0, 0.0, 6.0), player)
	var override_probe := _spawn_distinct_overrides(stage, player, alternate_target, stable_reference)
	var passive_probe := _spawn_combatant(
		stage, "PassiveAthenian", &"athenian", Vector3(60.0, 0.0, 60.0), null, false
	)
	var combatants: Array[HopliteAthenianEnemy] = [
		hostile_primary, hostile_secondary, spartan_near, spartan_far, override_probe, passive_probe,
	]
	for combatant: HopliteAthenianEnemy in combatants:
		if combatant == null:
			_finish(stage, [])
			return
	director._physics_process(0.001)

	_characterize_groups(hostile_primary, spartan_near)
	_characterize_spawn_target_semantics(
		hostile_primary, spartan_near, override_probe, passive_probe,
		player, alternate_target, stable_reference
	)
	_characterize_target_selection(hostile_primary, hostile_secondary, spartan_near, spartan_far, player, director)
	_characterize_retaliation_and_friendly_fire(hostile_primary, hostile_secondary, spartan_near, player)
	_characterize_hold_position_release(spartan_far, hostile_primary)
	_characterize_claim_release_on_death(hostile_secondary, spartan_near)
	await _characterize_claim_release_on_live_free(stage, spartan_near)

	# Release all remaining claims explicitly so teardown checks the probe rather
	# than depending on an uncharacterized live-queue-free lifecycle path.
	for combatant: HopliteAthenianEnemy in combatants:
		if combatant != null and is_instance_valid(combatant):
			combatant.call("_set_combat_target", null)
			combatant.retaliation_target = null
	spartan_near.set_meta("hoplite_ai_claims", 0)
	spartan_far.set_meta("hoplite_ai_claims", 0)
	player.set_meta("hoplite_ai_claims", 0)

	var weak_refs: Array[WeakRef] = []
	for combatant: HopliteAthenianEnemy in combatants:
		weak_refs.append(weakref(combatant))
	_finish(stage, weak_refs)


func _spawn_combatant(
	stage: Node3D,
	combatant_name: String,
	combatant_faction: StringName,
	combatant_position: Vector3,
	target: Node3D,
	ai_enabled: bool = true
) -> HopliteAthenianEnemy:
	var request: SpawnRequest = SpawnRequest.new()
	request.archetype = &"swordsman"
	request.position = combatant_position
	request.target = target
	request.ai_enabled = ai_enabled
	request.faction = combatant_faction
	request.mass_battle_mode = true
	request.has_name_override = true
	request.name_override = combatant_name
	var enemy := EnemyFactory.spawn_request(stage, request)
	if enemy == null:
		_expect(false, "%s failed to spawn" % combatant_name)
		return null
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _spawn_spartan(
	stage: Node3D,
	combatant_name: String,
	combatant_position: Vector3,
	player: Node3D
) -> HopliteAthenianEnemy:
	var request: SpawnRequest = SpawnRequest.new()
	request.archetype = &"swordsman"
	request.position = combatant_position
	request.target = player
	request.ai_enabled = true
	request.faction = &"spartan"
	request.mass_battle_mode = true
	request.has_name_override = true
	request.name_override = combatant_name
	request.has_ai_target_override = true
	request.ai_target_override = null
	request.has_battle_player_override = true
	request.battle_player_override = player
	var ally := EnemyFactory.spawn_request(stage, request)
	if ally == null:
		_expect(false, "%s failed to spawn" % combatant_name)
		return null
	ally.set_process(false)
	ally.set_physics_process(false)
	return ally


func _spawn_distinct_overrides(
	stage: Node3D,
	default_target: Node3D,
	immediate_target: Node3D,
	stable_reference: Node3D
) -> HopliteAthenianEnemy:
	var request: SpawnRequest = SpawnRequest.new()
	request.archetype = &"swordsman"
	request.position = Vector3(50.0, 0.0, 50.0)
	request.target = default_target
	request.ai_enabled = false
	request.has_name_override = true
	request.name_override = "DistinctOverrideAthenian"
	request.has_ai_target_override = true
	request.ai_target_override = immediate_target
	request.has_battle_player_override = true
	request.battle_player_override = stable_reference
	var enemy := EnemyFactory.spawn_request(stage, request)
	if enemy == null:
		_expect(false, "distinct override combatant failed to spawn")
		return null
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _characterize_groups(hostile: HopliteAthenianEnemy, ally: HopliteAthenianEnemy) -> void:
	for group_name: StringName in [&"enemy", &"athenian", &"damageable", &"combatant", &"combatant_ai", &"enemy_ai"]:
		_expect(hostile.is_in_group(group_name), "Athenian missing %s group" % String(group_name))
	for group_name: StringName in [&"ally", &"spartan_ally", &"damageable", &"combatant", &"combatant_ai", &"ally_ai"]:
		_expect(ally.is_in_group(group_name), "Spartan missing %s group" % String(group_name))
	_expect(not hostile.is_in_group("spartan_ally"), "Athenian entered Spartan group")
	_expect(not ally.is_in_group("enemy"), "Spartan entered enemy group")


func _characterize_spawn_target_semantics(
	hostile: HopliteAthenianEnemy,
	ally: HopliteAthenianEnemy,
	override_probe: HopliteAthenianEnemy,
	passive_probe: HopliteAthenianEnemy,
	player: Node3D,
	alternate_target: Node3D,
	stable_reference: Node3D
) -> void:
	_expect(hostile.ai_player == player, "default hostile target did not wire ai_player")
	_expect(hostile.battle_player == player, "default hostile target did not wire battle_player")
	_expect(ally.ai_player == null, "explicit-null Spartan AI target inherited the player")
	_expect(ally.battle_player == player, "Spartan stable battle-player override changed")
	_expect(override_probe.ai_player == alternate_target, "non-null immediate-target override changed")
	_expect(override_probe.battle_player == stable_reference, "non-null stable-reference override changed")
	_expect(override_probe.ai_player != player and override_probe.battle_player != player, "distinct overrides fell back to target")
	_expect(passive_probe.is_in_group("enemy"), "AI-disabled Athenian lost faction group")
	_expect(passive_probe.is_in_group("combatant"), "AI-disabled Athenian lost combatant group")
	_expect(not passive_probe.is_in_group("combatant_ai"), "AI-disabled Athenian entered combatant_ai")
	_expect(not passive_probe.is_in_group("enemy_ai"), "AI-disabled Athenian entered enemy_ai")


func _characterize_target_selection(
	hostile_primary: HopliteAthenianEnemy,
	hostile_secondary: HopliteAthenianEnemy,
	spartan_near: HopliteAthenianEnemy,
	spartan_far: HopliteAthenianEnemy,
	player: Node3D,
	director: HopliteBattleCrowdDirector
) -> void:
	var snapshot_builds_before := director.group_snapshot_build_count
	# A local human target has priority over enemy-group scanning.
	hostile_primary.call("_refresh_combat_target")
	_expect(hostile_primary.ai_player == player, "local player priority changed")
	_expect(int(player.get_meta("hoplite_ai_claims", 0)) == 1, "player claim was not registered")
	hostile_primary.call("_set_combat_target", null)
	_expect(int(player.get_meta("hoplite_ai_claims", 0)) == 0, "player claim was not released")

	# With the player outside aggro, hostiles scan Spartans. Existing claims can
	# outweigh pure distance, while the chosen target gains exactly one claim.
	player.position = Vector3(0.0, 0.0, 100.0)
	spartan_near.set_meta("hoplite_ai_claims", 5)
	spartan_far.set_meta("hoplite_ai_claims", 0)
	hostile_primary.call("_refresh_combat_target")
	_expect(hostile_primary.ai_player == spartan_far, "claim-aware hostile selection changed")
	_expect(int(spartan_far.get_meta("hoplite_ai_claims", 0)) == 1, "selected Spartan claim was not incremented")
	hostile_primary.call("_set_combat_target", null)
	_expect(int(spartan_far.get_meta("hoplite_ai_claims", 0)) == 0, "selected Spartan claim was not released")
	spartan_near.set_meta("hoplite_ai_claims", 0)

	# Spartans scan the enemy group. Dead combatants remain in the group but must
	# be excluded by is_dead_for_combat().
	spartan_near.call("_refresh_combat_target")
	_expect(spartan_near.ai_player == hostile_primary, "Spartan did not select the nearest living Athenian")
	spartan_near.call("_set_combat_target", null)
	hostile_primary.dead = true
	spartan_near.call("_refresh_combat_target")
	_expect(spartan_near.ai_player == hostile_secondary, "dead Athenian remained a valid Spartan target")
	spartan_near.call("_set_combat_target", null)
	hostile_primary.dead = false
	_expect(director.group_snapshot_build_count == snapshot_builds_before, "stable target refreshes rebuilt SceneTree faction snapshots")


func _characterize_retaliation_and_friendly_fire(
	hostile_primary: HopliteAthenianEnemy,
	hostile_secondary: HopliteAthenianEnemy,
	spartan: HopliteAthenianEnemy,
	player: Node3D
) -> void:
	hostile_primary.retaliation_target = null
	hostile_primary.retaliation_timer = 0.0
	hostile_primary.call("_register_retaliation", hostile_secondary)
	_expect(hostile_primary.retaliation_target == null, "same-faction retaliation was accepted")
	hostile_primary.call("_register_retaliation", spartan)
	_expect(hostile_primary.retaliation_target == spartan, "opposing-faction retaliation was not accepted")

	spartan.retaliation_target = null
	spartan.retaliation_timer = 0.0
	spartan.call("_register_retaliation", player)
	_expect(spartan.retaliation_target == null, "Spartan treated the player as a retaliation target")
	spartan.call("_register_retaliation", hostile_primary)
	_expect(spartan.retaliation_target == hostile_primary, "Spartan ignored hostile retaliation")

	var health_before := hostile_primary.health
	var accepted := hostile_primary.receive_ai_hit(10.0, hostile_secondary, Vector3.FORWARD)
	_expect(not accepted, "same-faction AI hit was accepted")
	_expect(is_equal_approx(hostile_primary.health, health_before), "same-faction AI hit changed health")
	var opposing_hit_accepted := spartan.receive_ai_hit(1.0, hostile_primary, Vector3.FORWARD)
	_expect(opposing_hit_accepted, "opposing-faction AI hit was rejected")
	_expect(not spartan.can_receive_hit_from(player), "Spartan no longer rejects player friendly fire")
	_expect(hostile_primary.can_receive_hit_from(player), "Athenian incorrectly rejects player hits")


func _characterize_hold_position_release(
	ally: HopliteAthenianEnemy,
	target: HopliteAthenianEnemy
) -> void:
	ally.call("_set_combat_target", target)
	_expect(int(target.get_meta("hoplite_ai_claims", 0)) == 1, "hold-position test claim was not registered")
	ally.hold_battlefield_position()
	_expect(ally.ai_player == null and ally.claimed_ai_target == null, "hold position retained combat target")
	_expect(int(target.get_meta("hoplite_ai_claims", 0)) == 0, "hold position did not release target claim")


func _characterize_claim_release_on_death(
	hostile: HopliteAthenianEnemy,
	target: HopliteAthenianEnemy
) -> void:
	hostile.call("_set_combat_target", target)
	_expect(int(target.get_meta("hoplite_ai_claims", 0)) == 1, "death test claim was not registered")
	hostile.call("_die", false)
	_expect(hostile.dead, "death lifecycle did not mark the combatant dead")
	_expect(hostile.ai_player == null, "death lifecycle retained ai_player")
	_expect(hostile.claimed_ai_target == null, "death lifecycle retained claimed target")
	_expect(int(target.get_meta("hoplite_ai_claims", 0)) == 0, "death lifecycle did not release target claim")


func _characterize_claim_release_on_live_free(stage: Node3D, target: HopliteAthenianEnemy) -> void:
	var director: HopliteBattleCrowdDirector = CrowdDirector.new()
	director.name = "LiveFreeCrowdDirector"
	stage.add_child(director)
	var claimant := _spawn_combatant(
		stage, "LiveFreedClaimant", &"athenian", Vector3(70.0, 0.0, 70.0), null
	)
	if claimant == null:
		return
	claimant.call("_set_combat_target", target)
	_expect(int(target.get_meta("hoplite_ai_claims", 0)) == 1, "live-free test claim was not registered")
	claimant.crowd_director = director
	var permission_granted := bool(claimant.call("_claim_attack_permission", target))
	var target_id := target.get_instance_id()
	var claimant_id := claimant.get_instance_id()
	var permissions_before: Dictionary = director.attack_permissions.get(target_id, {})
	_expect(permission_granted and permissions_before.has(claimant_id), "live-free attack permission was not registered")
	var claimant_ref: WeakRef = weakref(claimant)
	claimant.queue_free()
	await process_frame
	_expect(claimant_ref.get_ref() == null, "live claimant survived queue_free")
	_expect(int(target.get_meta("hoplite_ai_claims", 0)) == 0, "live queue_free leaked target claim")
	var permissions_after: Dictionary = director.attack_permissions.get(target_id, {})
	_expect(not permissions_after.has(claimant_id), "live queue_free leaked attack permission")


func _finish(stage: Node, weak_refs: Array[WeakRef]) -> void:
	stage.queue_free()
	await process_frame
	await process_frame
	for reference: WeakRef in weak_refs:
		_expect(reference.get_ref() == null, "combatant survived stage teardown")
	if failures.is_empty():
		print("ENEMY_FACTION_TARGETING_PROBE PASS: groups, target precedence, claims, retaliation and friendly fire preserved")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY FACTION TARGETING] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
