extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const NavigationComponent = preload("res://scripts/ai/enemy_navigation_component.gd")

const EXPECTED_IDS: Array[StringName] = [
	&"swordsman", &"guardian", &"spearman", &"flanker", &"brute", &"captain", &"warlord", &"boss_colossus", &"boss_bronze",
	&"nathenian1", &"nsbire1", &"nsbire2", &"nathenian2", &"nathenian2_soldier", &"bronze_colossus", &"ncenturion",
	&"ngeneral", &"ngeneral_veteran", &"giant_novice", &"giant_standard", &"giant_veteran", &"nfull_armor",
]

const REQUIRED_ANATOMY_ZONES: Array[StringName] = [
	&"head", &"neck", &"torso", &"pelvis",
	&"upper_arm_l", &"forearm_l", &"upper_arm_r", &"forearm_r",
	&"thigh_l", &"shin_l", &"thigh_r", &"shin_r",
]

const FAMILY_BY_ID: Dictionary = {
	&"swordsman": "legacy_standard",
	&"guardian": "legacy_standard_shield",
	&"spearman": "legacy_phalanx",
	&"flanker": "legacy_standard",
	&"brute": "legacy_heavy",
	&"captain": "legacy_elite",
	&"warlord": "legacy_boss",
	&"boss_colossus": "legacy_boss",
	&"boss_bronze": "legacy_elite",
	&"nathenian1": "nathenian",
	&"nsbire1": "nsbire",
	&"nsbire2": "nsbire_archer",
	&"nathenian2": "nathenian_heavy",
	&"nathenian2_soldier": "nathenian_heavy",
	&"bronze_colossus": "bronze_colossus",
	&"ncenturion": "ncenturion",
	&"ngeneral": "hoplite_ngeneral",
	&"ngeneral_veteran": "hoplite_clean1",
	&"giant_novice": "giant_geant1",
	&"giant_standard": "giant_geant1",
	&"giant_veteran": "giant_geant1",
	&"nfull_armor": "nfull_armor",
}

class ProbeTarget extends CharacterBody3D:
	signal combat_attack_started(slot: StringName, context: StringName, power: float)

	func receive_enemy_hit(_damage: float, _attacker: Node = null, _direction: Vector3 = Vector3.ZERO) -> bool:
		return true

	func get_combat_aim_point() -> Vector3:
		return global_position + Vector3.UP


var failures: Array[String] = []
var validated_ids: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "EnemyFullRosterValidationStage"
	root.add_child(stage)
	current_scene = stage

	var target := ProbeTarget.new()
	target.name = "EnemyFullRosterValidationTarget"
	target.position = Vector3(0.0, 0.0, -12.0)
	stage.add_child(target)

	_expect_global(Archetypes.all_ids() == EXPECTED_IDS, "canonical 22-ID set or order changed")
	for archetype: StringName in EXPECTED_IDS:
		await _validate_archetype(stage, target, archetype)

	_expect_global(validated_ids == EXPECTED_IDS, "probe did not validate every ID in canonical order")
	target.queue_free()
	await process_frame
	await physics_frame
	_expect_global(stage.get_child_count() == 0, "probe stage retained children after roster teardown")
	stage.queue_free()
	await process_frame

	if failures.is_empty():
		print("ENEMY_FULL_ROSTER_VALIDATION_PROBE PASS: 22/22 identities, rigs, anatomy, equipment, actions, navigation modes and teardown")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("ENEMY_FULL_ROSTER_VALIDATION_PROBE FAIL: %d issue(s), %d/22 IDs traversed" % [failures.size(), validated_ids.size()])
	quit(1)


func _validate_archetype(stage: Node3D, target: Node3D, archetype: StringName) -> void:
	var profile := Archetypes.profile(archetype)
	var enemy := EnemyFactory.spawn(stage, archetype, Vector3.ZERO, target, {
		"name": "FullRoster_%s" % String(archetype),
		"ai_enabled": true,
	})
	if enemy == null:
		_expect(archetype, false, "factory returned null")
		return

	# Imported package setup, skeleton evaluation and navigation registration are
	# synchronous/deferred across a few frames depending on the source asset.
	for _frame: int in range(3):
		await process_frame
		await physics_frame
	enemy.set_process(false)
	enemy.set_physics_process(false)

	_validate_identity(archetype, profile, enemy)
	_validate_visual_and_rig(archetype, enemy)
	_validate_anatomy(archetype, enemy)
	_validate_equipment(archetype, profile, enemy)
	var action_result := _validate_action(archetype, profile, enemy)
	var navigation_label := _validate_navigation(archetype, profile, enemy)

	print("ROSTER_VALIDATE id=%-22s family=%-20s rig=%-16s anatomy=%02d/%02d equipment=%-12s action=%-12s navigation=%s" % [
		String(archetype),
		_family_for(archetype),
		_rig_label(enemy),
		enemy.anatomy.zone_runtime.size() if enemy.anatomy != null else 0,
		REQUIRED_ANATOMY_ZONES.size(),
		String(profile.get("weapon", &"none")) + ("+shield" if bool(profile.get("shield", false)) else ""),
		action_result,
		navigation_label,
	])
	validated_ids.append(archetype)

	var enemy_ref: WeakRef = weakref(enemy)
	enemy.queue_free()
	await process_frame
	await physics_frame
	_expect(archetype, enemy_ref.get_ref() == null, "instance survived queue_free")
	_expect(archetype, stage.get_child_count() == 1, "stage retained nodes after sequential teardown")


func _validate_identity(archetype: StringName, profile: Dictionary, enemy: Node) -> void:
	_expect(archetype, enemy.archetype_id == archetype, "runtime identity changed to %s" % enemy.archetype_id)
	_expect(archetype, String(enemy.archetype_name) == String(profile.get("display_name", "")), "display identity does not match profile")
	_expect(archetype, enemy.get_meta("procedural_archetype", StringName()) == archetype, "factory metadata identity missing")
	_expect(archetype, enemy.is_in_group("combatant") and enemy.is_in_group("enemy"), "canonical combatant/enemy groups missing")
	_expect(archetype, enemy.max_health > 0.0 and enemy.health == enemy.max_health, "initial health contract invalid")


func _validate_visual_and_rig(archetype: StringName, enemy: Node) -> void:
	_expect(archetype, enemy.visual_root != null and enemy.visual_root.is_inside_tree(), "visual root missing")
	_expect(archetype, enemy.mannequin_scene != null and enemy.mannequin_scene.is_inside_tree(), "character visual missing")
	_expect(archetype, enemy.skeleton != null and enemy.skeleton.get_bone_count() > 0, "skeleton missing or empty")
	_expect(archetype, enemy.animation_player != null and not enemy.animation_player.get_animation_list().is_empty(), "AnimationPlayer missing or empty")
	_expect(archetype, enemy.right_hand_bone != "" and enemy.skeleton.find_bone(enemy.right_hand_bone) >= 0, "right-hand bone unresolved")
	_expect(archetype, enemy.left_hand_bone != "" and enemy.skeleton.find_bone(enemy.left_hand_bone) >= 0, "left-hand bone unresolved")


func _validate_anatomy(archetype: StringName, enemy: Node) -> void:
	_expect(archetype, enemy.anatomy != null and enemy.anatomy.is_inside_tree(), "anatomy component missing")
	_expect(archetype, enemy.anatomy_defs.size() == REQUIRED_ANATOMY_ZONES.size(), "anatomy definition count changed")
	_expect(archetype, enemy.zone_state.size() == REQUIRED_ANATOMY_ZONES.size(), "anatomy state count changed")
	if enemy.anatomy == null:
		return
	for zone: StringName in REQUIRED_ANATOMY_ZONES:
		_expect(archetype, enemy.anatomy_defs.has(zone), "anatomy definition missing zone %s" % zone)
		_expect(archetype, enemy.zone_state.has(zone), "anatomy state missing zone %s" % zone)
		_expect(archetype, enemy.anatomy.zone_runtime.has(zone), "skeleton did not map anatomy zone %s" % zone)
	_expect(archetype, enemy.anatomy.debug_missing_bones.is_empty(), "unmapped anatomy bones: %s" % [enemy.anatomy.debug_missing_bones])


func _validate_equipment(archetype: StringName, profile: Dictionary, enemy: Node) -> void:
	var expected_weapon := StringName(profile.get("weapon", &"sword"))
	var expected_shield := bool(profile.get("shield", false))
	var expected_defense := StringName(profile.get("defense", &"none"))
	_expect(archetype, enemy.weapon_kind == expected_weapon, "weapon kind %s does not match %s" % [enemy.weapon_kind, expected_weapon])
	_expect(archetype, enemy.shield_enabled == expected_shield, "shield flag does not match profile")
	_expect(archetype, enemy.defense_mode == expected_defense, "defense mode does not match profile")
	if expected_weapon == &"unarmed":
		_expect(archetype, enemy.sword_root == null and enemy.sword_attachment == null, "unarmed profile received a procedural weapon")
	else:
		_expect(archetype, enemy.sword_root != null, "armed profile has no visible weapon or detachable authored anchor")
		if enemy.sword_attachment != null:
			var expected_hand: String = enemy.left_hand_bone if expected_weapon == &"bow" else enemy.right_hand_bone
			_expect(archetype, enemy.sword_attachment.bone_name == expected_hand, "weapon attached to the wrong hand")
	if expected_shield:
		_expect(archetype, expected_defense == &"shield", "visible shield lacks shield defense")
		_expect(archetype, enemy.shield_root != null and enemy.shield_attachment != null, "shield visual/attachment missing")
		_expect(archetype, enemy.shield_attachment == null or enemy.shield_attachment.bone_name == enemy.left_hand_bone, "shield attached to the wrong hand")
		_expect(archetype, enemy.shield_hitbox != null, "shield combat hitbox missing")
	else:
		_expect(archetype, expected_defense != &"shield", "shield defense exists without a shield")
		_expect(archetype, enemy.shield_hitbox == null, "unshielded profile received a shield hitbox")


func _validate_action(archetype: StringName, profile: Dictionary, enemy: Node) -> String:
	var pattern: Array = Array(profile.get("combat_pattern", []))
	if pattern.is_empty():
		var static_action_ok := float(profile.get("attack_damage", 0.0)) > 0.0 and StringName(profile.get("attack_delivery", &"melee")) in [&"melee", &"projectile"]
		_expect(archetype, static_action_ok, "no combat pattern and no valid static attack justification")
		return "static"
	enemy.call("_begin_ai_attack")
	var step_id := StringName(enemy.active_attack_step.get("id", StringName()))
	_expect(archetype, enemy.ai_attack_pending and step_id != StringName(), "combat pattern could not start an action")
	_expect(archetype, enemy.active_attack_windup_total >= 0.10, "started action has no readable windup")
	return String(step_id) if step_id != StringName() else "failed"


func _validate_navigation(archetype: StringName, profile: Dictionary, enemy: Node) -> String:
	var navigation: Variant = enemy.navigation_component
	_expect(archetype, navigation != null, "navigation component missing")
	if navigation == null:
		return "missing"
	_expect(archetype, navigation.owner_body == enemy, "navigation owner is not the enemy body")
	var expected_mode := NavigationComponent.Mode.DIRECT_STEERING
	var behavior := StringName(profile.get("behavior", &"aggressive"))
	if behavior in [&"phalanx", &"phalanx_veteran"]:
		expected_mode = NavigationComponent.Mode.FORMATION_LOCAL
	elif float(profile.get("scale", 1.0)) >= 1.75 or archetype in [&"boss_colossus", &"bronze_colossus", &"giant_novice", &"giant_standard", &"giant_veteran"]:
		expected_mode = NavigationComponent.Mode.LARGE_BODY
	_expect(archetype, navigation.mode == expected_mode, "navigation mode %s does not match expected %s" % [navigation.mode, expected_mode])
	return NavigationComponent.Mode.keys()[expected_mode]


func _family_for(archetype: StringName) -> String:
	return String(FAMILY_BY_ID.get(archetype, "unknown"))


func _rig_label(enemy: Node) -> String:
	if enemy.archetype_id in [&"ngeneral", &"ngeneral_veteran"]:
		return "shared_library"
	if enemy.uses_mixamo_visual:
		return "direct_mixamo"
	if enemy.uses_spartan_package_visual:
		return "package_retarget"
	return "legacy_ual1"


func _expect(archetype: StringName, condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [archetype, message])


func _expect_global(condition: bool, message: String) -> void:
	if not condition:
		failures.append("roster: " + message)
