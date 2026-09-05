extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const ProbePlayer = preload("res://tools/battle_enemy_spawn_probe_player.gd")

const PACKAGE_OVERRIDE := "res://assets/characters/3dgen_demo/nathenian1-1787346222233.glb"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := ProbePlayer.new() as HopliteUALNativePlayer
	root.add_child(player)
	var commander := Node3D.new()
	root.add_child(commander)

	var enemy := EnemyFactory.spawn(stage, &"guardian", Vector3(1.0, 0.05, 2.0), player, {
		"name": "FactoryOptionsGuardian",
		"ai_enabled": false,
		"ai_target": null,
		"battle_player": player,
		"mass_battle_mode": true,
		"faction": &"spartan",
		"guard_index": 9,
		"scale_multiplier": 1.25,
		"match_perfect_hitbox": true,
		"giant_traversal_mode": &"matched",
		"giant_capsule_radius_multiplier": 1.30,
		"giant_capsule_height_multiplier": 1.40,
		"giant_walkable_tops": false,
		"commander": commander,
		"is_miniboss": true,
		"package_path": PACKAGE_OVERRIDE,
	})

	_expect(enemy != null, "factory returned null")
	if enemy != null:
		_expect(enemy.get_parent() == stage, "parent changed")
		_expect(enemy.name == "FactoryOptionsGuardian", "name option changed")
		_expect(enemy.archetype_id == &"guardian", "archetype changed")
		_expect(enemy.position.is_equal_approx(Vector3(1.0, 0.05, 2.0)), "position changed")
		_expect(not enemy.ai_enabled, "ai_enabled option changed")
		_expect(not enemy.is_physics_processing(), "factory-created inactive enemy kept its physics callback enabled")
		_expect(enemy.ai_player == null, "explicit null ai_target override changed")
		_expect(enemy.battle_player == player, "battle_player override changed")
		_expect(enemy.mass_battle_mode, "mass_battle_mode option changed")
		_expect(enemy.faction == &"spartan", "faction option changed")
		_expect(enemy.ai_guard_index == 9, "guard_index option changed")
		_expect(is_equal_approx(enemy.external_scale_multiplier, 1.25), "scale_multiplier option changed")
		_expect(enemy.match_perfect_hitbox, "match_perfect_hitbox option changed")
		_expect(enemy.giant_traversal_mode == &"matched", "giant_traversal_mode option changed")
		_expect(is_equal_approx(enemy.giant_capsule_radius_multiplier, 1.30), "giant radius option changed")
		_expect(is_equal_approx(enemy.giant_capsule_height_multiplier, 1.40), "giant height option changed")
		_expect(not enemy.giant_walkable_tops, "giant_walkable_tops option changed")
		_expect(enemy.ai_miniboss == commander, "commander option changed")
		_expect(enemy.is_miniboss, "is_miniboss promotion changed")
		_expect(enemy.character_package_path == PACKAGE_OVERRIDE, "package_path option changed")
		_expect(StringName(enemy.get_meta("procedural_archetype", StringName())) == &"guardian", "factory metadata changed")
		_expect(StringName(enemy.get_meta("enemy_asset_origin", StringName())) == &"mixamo",
			"factory asset origin metadata changed")
		_expect(not bool(enemy.get_meta("enemy_migration_eligible", true)),
			"Mixamo test model became migration eligible")
		_expect(StringName(enemy.get_meta("enemy_runtime_generation", StringName())) == &"legacy_v1",
			"factory runtime generation metadata changed")
		_expect(StringName(enemy.get_meta("enemy_migration_family", StringName())) == &"not_eligible",
			"factory migration family metadata changed")
		_expect(StringName(enemy.get_meta("enemy_migration_stage", StringName())) == &"legacy_only",
			"factory migration stage metadata changed")
		_expect(enemy.is_in_group("spartan_ally"), "pre-ready faction configuration changed groups")
		enemy.set_ai_participation(true)
		_expect(enemy.ai_enabled and enemy.is_physics_processing(), "inactive factory enemy did not restore physics when activated")
		enemy.set_ai_participation(false)
		_expect(not enemy.ai_enabled and not enemy.is_physics_processing(), "reactivated factory enemy did not suspend physics again")

	var defaults := EnemyFactory.spawn(stage, &"swordsman", Vector3.ZERO, player)
	_expect(defaults.name == "Swordsman", "absent name no longer uses archetype default")
	_expect(defaults.ai_player == player, "absent ai_target no longer inherits target")
	_expect(defaults.battle_player == player, "absent battle_player no longer inherits target")
	_expect(not defaults.is_miniboss, "absent is_miniboss unexpectedly promotes a troop")

	var explicit_nulls := EnemyFactory.spawn(stage, &"swordsman", Vector3.ZERO, player, {
		"ai_target": null,
		"battle_player": null,
		"is_miniboss": false,
	})
	_expect(explicit_nulls.ai_player == null, "present null ai_target incorrectly inherited target")
	_expect(explicit_nulls.battle_player == null, "present null battle_player incorrectly inherited target")
	_expect(not explicit_nulls.is_miniboss, "explicit false is_miniboss promoted a troop")

	var ranked_false := EnemyFactory.spawn(stage, &"captain", Vector3.ZERO, player, {"is_miniboss": false})
	_expect(ranked_false.is_miniboss, "explicit false demoted a profile-ranked miniboss")
	var troop_true := EnemyFactory.spawn(stage, &"swordsman", Vector3.ZERO, player, {"is_miniboss": true})
	_expect(troop_true.is_miniboss, "explicit true no longer promotes a troop")

	_expect(EnemyFactory.spawn(null, &"swordsman", Vector3.ZERO, player) == null,
		"null parent no longer returns early")

	stage.queue_free()
	commander.queue_free()
	player.queue_free()
	await process_frame

	if failures.is_empty():
		print("ENEMY_FACTORY_OPTIONS_PROBE PASS: legacy dictionary option contract preserved")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY FACTORY OPTIONS] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
