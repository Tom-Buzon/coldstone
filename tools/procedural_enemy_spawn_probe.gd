extends SceneTree

const WaveDirectorScript = preload("res://scripts/campaign/procedural_wave_director.gd")
const ProbePlayerScript = preload("res://tools/battle_enemy_spawn_probe_player.gd")

var failures: Array[String] = []
var spawned_enemies: Array[HopliteAthenianEnemy] = []
var miniboss_enemies: Array[HopliteAthenianEnemy] = []
var miniboss_titles: Array[String] = []
var boss_enemies: Array[HopliteAthenianEnemy] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "ProceduralEnemySpawnProbe"
	root.add_child(world)
	var enemy_parent := Node3D.new()
	enemy_parent.name = "Enemies"
	world.add_child(enemy_parent)
	var player := ProbePlayerScript.new() as HopliteUALNativePlayer
	player.name = "Player"
	world.add_child(player)
	player.position = Vector3(0.0, 0.05, 8.0)

	var director := WaveDirectorScript.new() as HopliteProceduralWaveDirector
	director.name = "WaveDirector"
	world.add_child(director)
	director.enemy_parent = enemy_parent
	director.player = player
	director.zone_id = &"walls"
	director.current_wave = 2
	director.rng.seed = 76021
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 76021
	var expected_soldier_name := "Nathenian1_W03_%04d" % expected_rng.randi_range(0, 9999)
	director.enemy_spawned.connect(_on_enemy_spawned)
	director.miniboss_spawned.connect(_on_miniboss_spawned)
	director.boss_spawned.connect(_on_boss_spawned)

	var legion_anchor := Vector3(12.0, 0.05, -6.0)
	var formation_index := 7
	var expected_position := director.call(
		"_legion_formation_position", legion_anchor, formation_index, &"nathenian1"
	) as Vector3
	director.call("_spawn_spec", {
		"archetype": &"nathenian1",
		"position": Vector3(99.0, 0.05, 99.0),
		"mass": false,
		"guard_index": 17,
		"formation_index": formation_index,
		"legion_id": 3,
		"legion_anchor": legion_anchor,
	})

	_expect(spawned_enemies.size() == 1, "ordinary spawn did not emit enemy_spawned exactly once")
	var soldier := spawned_enemies[0] if not spawned_enemies.is_empty() else null
	if soldier != null:
		_expect(soldier.get_parent() == enemy_parent, "ordinary spawn escaped enemy_parent")
		_expect(soldier.archetype_id == &"nathenian1", "ordinary archetype changed")
		_expect(soldier.position.is_equal_approx(expected_position), "legion formation position changed")
		_expect(soldier.ai_player == player and soldier.battle_player == player, "player target wiring changed")
		_expect(soldier.ai_enabled, "ordinary spawn did not enable AI")
		_expect(not soldier.mass_battle_mode, "ordinary mass mode option changed")
		_expect(soldier.ai_guard_index == 17, "ordinary guard index changed")
		_expect(String(soldier.name) == expected_soldier_name, "ordinary deterministic name or RNG order changed")
		_expect(soldier.is_in_group("campaign_legion_03"), "ordinary legion group missing")
		_expect(soldier.is_in_group("campaign_type_nathenian1"), "ordinary archetype group missing")
		_expect(int(soldier.get_meta("campaign_legion_id", -1)) == 3, "ordinary legion metadata changed")
		_expect((soldier.get_meta("campaign_legion_anchor", Vector3.ZERO) as Vector3).is_equal_approx(legion_anchor), "ordinary legion anchor metadata changed")
		_expect(director.active_enemies.get(soldier.get_instance_id()) == soldier, "ordinary spawn missing from active_enemies")

	director.deployment_locked = true
	director.call("_spawn_spec", {
		"archetype": &"ncenturion",
		"position": Vector3(-10.0, 0.05, -4.0),
		"mass": true,
		"guard_index": 23,
		"elite_title": "CENTURION TEST",
	})
	_expect(spawned_enemies.size() == 2, "miniboss spawn did not emit enemy_spawned")
	_expect(miniboss_enemies.size() == 1, "profile-ranked miniboss did not emit miniboss_spawned")
	_expect(miniboss_titles == ["CENTURION TEST"], "miniboss title changed")
	var miniboss := miniboss_enemies[0] if not miniboss_enemies.is_empty() else null
	if miniboss != null:
		_expect(miniboss == spawned_enemies[1], "miniboss signals referenced different enemies")
		_expect(miniboss.is_miniboss, "profile-ranked miniboss lost its rank")
		_expect(not miniboss.ai_enabled, "deployment lock did not disable miniboss AI")
		_expect(miniboss.ai_player == null and miniboss.battle_player == player, "miniboss suspension did not clear transient target while retaining its stable player")
		_expect(not miniboss.is_physics_processing(), "elite entrance did not suspend miniboss physics")
		_expect(miniboss.mass_battle_mode and miniboss.ai_guard_index == 23, "miniboss request options changed")

	director.deployment_locked = false
	director.call("_spawn_spec", {
		"archetype": &"nfull_armor",
		"position": Vector3(3.0, 0.05, -14.0),
		"mass": false,
		"guard_index": 31,
		"completion_elite": true,
	})
	_expect(spawned_enemies.size() == 3, "boss spawn did not emit enemy_spawned")
	_expect(boss_enemies.size() == 1, "boss spawn did not emit boss_spawned")
	var boss := boss_enemies[0] if not boss_enemies.is_empty() else null
	if boss != null:
		_expect(boss == spawned_enemies[2] and director.boss == boss, "boss references diverged")
		_expect(director.completion_elite == boss, "completion elite reference changed")
		_expect(not director.boss_defeated, "new boss started defeated")
		_expect(boss.archetype_id == &"nfull_armor" and boss.is_miniboss, "boss profile rank changed")
		_expect(boss.ai_player == null and boss.battle_player == player, "boss entrance did not clear transient target while retaining its stable player")
		_expect(not boss.ai_enabled and not boss.is_physics_processing(), "boss entrance did not suspend AI and physics")
		_expect(director.active_enemies.get(boss.get_instance_id()) == boss, "boss missing from active_enemies")

	_expect(enemy_parent.get_child_count() == 5, "unexpected procedural child count (three enemies plus two entrance sigils expected)")
	await create_timer(1.05).timeout
	_expect(enemy_parent.get_child_count() == 3, "elite entrance sigils did not finish and free themselves")
	if miniboss != null:
		_expect(miniboss.ai_enabled and miniboss.is_physics_processing(), "miniboss entrance did not restore AI and physics")
		_expect(miniboss.ai_player == player and miniboss.battle_player == player, "miniboss entrance did not restore target wiring")
	if boss != null:
		_expect(boss.ai_enabled and boss.is_physics_processing(), "boss entrance did not restore AI and physics")
		_expect(boss.ai_player == player and boss.battle_player == player, "boss entrance did not restore target wiring")
	var enemy_refs: Array[WeakRef] = []
	for enemy: HopliteAthenianEnemy in spawned_enemies:
		enemy_refs.append(weakref(enemy))
	world.queue_free()
	await process_frame
	await process_frame
	for enemy_ref: WeakRef in enemy_refs:
		_expect(enemy_ref.get_ref() == null, "procedural enemy survived world teardown")

	if failures.is_empty():
		print("PROCEDURAL_ENEMY_SPAWN_PROBE PASS: ordinary, miniboss and boss factory spawns preserve runtime contracts")
		quit(0)
		return
	for failure: String in failures:
		push_error("[PROCEDURAL ENEMY SPAWN] " + failure)
	quit(1)


func _on_enemy_spawned(enemy: HopliteAthenianEnemy) -> void:
	spawned_enemies.append(enemy)


func _on_miniboss_spawned(enemy: HopliteAthenianEnemy, title: String) -> void:
	miniboss_enemies.append(enemy)
	miniboss_titles.append(title)


func _on_boss_spawned(enemy: HopliteAthenianEnemy) -> void:
	boss_enemies.append(enemy)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
