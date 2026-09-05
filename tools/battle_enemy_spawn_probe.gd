extends SceneTree

const BattleHarness = preload("res://tools/battle_enemy_spawn_probe_actor.gd")
const ProbePlayer = preload("res://tools/battle_enemy_spawn_probe_player.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BattleHarness.new()
	root.add_child(battle)
	var player := ProbePlayer.new() as HopliteUALNativePlayer
	root.add_child(player)
	battle.player = player

	var commander := Node3D.new()
	root.add_child(commander)
	var hostile: HopliteAthenianEnemy = battle.call(
		"_spawn_enemy",
		Vector3(2.0, 0.05, -3.0),
		&"guardian",
		commander,
		7,
		true,
		true
	)
	_expect(hostile != null, "hostile helper returned null")
	if hostile != null:
		_expect(hostile.get_parent() == battle, "hostile parent changed")
		_expect(hostile.name.begins_with("Battle01_guardian_"), "hostile naming contract changed")
		_expect(hostile.archetype_id == &"guardian", "hostile archetype changed")
		_expect(hostile.position.is_equal_approx(Vector3(2.0, 0.05, -3.0)), "hostile position changed")
		_expect(hostile.ai_enabled, "hostile AI was not enabled")
		_expect(hostile.is_miniboss, "forced elite flag was lost")
		_expect(hostile.ai_player == player, "hostile immediate target changed")
		_expect(hostile.battle_player == player, "hostile stable player reference changed")
		_expect(hostile.ai_miniboss == commander, "hostile commander changed")
		_expect(hostile.ai_guard_index == 7, "hostile guard index changed")
		_expect(hostile.mass_battle_mode, "hostile mass-battle mode changed")
		_expect(hostile.is_in_group("enemy"), "hostile enemy group changed")
		_expect(hostile.is_in_group("enemy_miniboss"), "hostile miniboss group changed")
		_expect(hostile.is_in_group("combatant_ai"), "hostile combatant AI group changed")
		_expect(hostile.localized_hit.is_connected(Callable(battle, "_on_enemy_localized_hit")), "hostile localized-hit feedback was not wired")
		_expect(hostile.attack_started.is_connected(Callable(battle, "_on_enemy_attack_started")), "hostile attack feedback was not wired")
		_expect(hostile.zone_severed.is_connected(Callable(battle, "_on_enemy_zone_severed")), "hostile sever feedback was not wired")
		_expect(hostile.died.is_connected(Callable(battle, "_on_enemy_died_feedback")), "hostile death feedback was not wired")

	var profile_miniboss_without_forced_elite: HopliteAthenianEnemy = battle.call(
		"_spawn_enemy",
		Vector3(4.0, 0.05, -5.0),
		&"captain",
		null,
		8,
		false,
		false
	)
	_expect(profile_miniboss_without_forced_elite != null, "miniboss-profile helper returned null")
	if profile_miniboss_without_forced_elite != null:
		_expect(profile_miniboss_without_forced_elite.is_miniboss, "miniboss profile lost its rank-driven legacy flag")
		_expect(profile_miniboss_without_forced_elite.is_in_group("enemy_miniboss"), "miniboss profile lost its legacy group")
		_expect(profile_miniboss_without_forced_elite.is_in_group("enemy_epic"), "miniboss profile lost its rank-driven epic group")

	var ally: HopliteAthenianEnemy = battle.call(
		"_spawn_spartan",
		Vector3(-2.0, 0.05, 4.0),
		&"spearman",
		3
	)
	_expect(ally != null, "Spartan helper returned null")
	if ally != null:
		_expect(ally.get_parent() == battle, "Spartan parent changed")
		_expect(ally.name == "Battle01_Spartan_spearman_03", "Spartan naming contract changed")
		_expect(ally.archetype_id == &"spearman", "Spartan archetype changed")
		_expect(ally.position.is_equal_approx(Vector3(-2.0, 0.05, 4.0)), "Spartan position changed")
		_expect(ally.ai_enabled, "Spartan AI was not enabled")
		_expect(ally.faction == &"spartan", "Spartan faction changed")
		_expect(ally.ai_player == null, "Spartan acquired the human player as an immediate combat target")
		_expect(ally.battle_player == player, "Spartan stable player reference changed")
		_expect(ally.ai_guard_index == 3, "Spartan formation index changed")
		_expect(ally.mass_battle_mode, "Spartan mass-battle mode changed")
		_expect(ally.is_in_group("ally"), "Spartan ally group changed")
		_expect(ally.is_in_group("spartan_ally"), "Spartan faction group changed")
		_expect(ally.is_in_group("ally_ai"), "Spartan AI group changed")
		_expect(not ally.is_in_group("enemy"), "Spartan entered the hostile group")
		_expect(ally.attack_started.is_connected(Callable(battle, "_on_enemy_attack_started")), "Spartan attack feedback was not wired")

	battle.queue_free()
	commander.queue_free()
	player.queue_free()
	await process_frame

	if failures.is_empty():
		print("BATTLE_ENEMY_SPAWN_PROBE PASS: hostile and Spartan helper contracts preserved")
		quit(0)
		return
	for failure: String in failures:
		push_error("[BATTLE ENEMY SPAWN] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
