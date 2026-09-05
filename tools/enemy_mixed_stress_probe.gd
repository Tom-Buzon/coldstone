extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")
const CombatantRegistry = preload("res://scripts/enemy/combatant_registry.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

const STRESS_COUNT := 36
const PRESERVED_MASS_THRESHOLD := 28

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "EnemyMixedStress"
	root.add_child(world)
	current_scene = world
	_add_floor_and_chokepoint(world)

	var target_a := Node3D.new()
	target_a.name = "MovingTargetA"
	target_a.position = Vector3(0.0, 0.0, -7.0)
	target_a.add_to_group("player")
	world.add_child(target_a)
	var target_b := Node3D.new()
	target_b.name = "ReplacementTargetB"
	target_b.position = Vector3(8.0, 0.0, -3.0)
	target_b.add_to_group("player")
	world.add_child(target_b)

	var director := CrowdDirector.new()
	world.add_child(director)
	var registry := CombatantRegistry.new()
	world.add_child(registry)

	var roster: Array[StringName] = Archetypes.all_ids()
	_expect(roster.size() == 22, "canonical stress roster changed from 22 entries")
	var spawn_ids := roster.duplicate()
	while spawn_ids.size() < STRESS_COUNT:
		spawn_ids.append(&"ngeneral" if spawn_ids.size() % 2 == 0 else &"ngeneral_veteran")
	var enemies: Array[HopliteAthenianEnemy] = []
	var refs: Array[WeakRef] = []
	for index: int in range(STRESS_COUNT):
		var request := SpawnRequest.new()
		request.archetype = spawn_ids[index]
		request.position = Vector3(float(index % 9) * 1.35 - 5.4, 0.05, float(index / 9) * 1.55 + 3.0)
		request.target = target_a
		request.ai_enabled = true
		request.mass_battle_mode = STRESS_COUNT >= PRESERVED_MASS_THRESHOLD
		request.guard_index = index
		request.combatant_registry = registry
		var enemy := EnemyFactory.spawn_request(world, request)
		if enemy == null:
			failures.append("factory failed mixed stress spawn %d (%s)" % [index, spawn_ids[index]])
			continue
		if enemy.archetype_id in [&"ngeneral", &"ngeneral_veteran"]:
			enemy.set_meta("formation_group", &"stress_alpha" if index % 2 == 0 else &"stress_beta")
		enemies.append(enemy)
		refs.append(weakref(enemy))

	await process_frame
	await physics_frame
	_expect(enemies.size() == STRESS_COUNT, "mixed stress did not create 36 enemies")
	_expect(registry.registered_count() == STRESS_COUNT, "registry did not contain all stress enemies")
	_expect(get_nodes_in_group("combatant_ai").size() == STRESS_COUNT, "crowd group did not contain all stress enemies")
	for archetype: StringName in roster:
		var found := false
		for enemy: HopliteAthenianEnemy in enemies:
			if enemy.archetype_id == archetype:
				found = true
				break
		_expect(found, "mixed stress omitted archetype %s" % archetype)
	for enemy: HopliteAthenianEnemy in enemies:
		_expect(enemy.mass_battle_mode, "36-unit stress failed to retain the threshold-28 mass mode")

	# Exercise two stable phalanx cohorts in the same scene.
	var cohort_keys: Dictionary = {}
	for enemy: HopliteAthenianEnemy in enemies:
		if enemy.archetype_id not in [&"ngeneral", &"ngeneral_veteran"]:
			continue
		var assignment: Dictionary = director.phalanx_assignment(enemy, target_a)
		_expect(not assignment.is_empty(), "%s received no multi-cohort assignment" % enemy.name)
		cohort_keys[StringName(enemy.get_meta("formation_group", StringName()))] = true
	_expect(cohort_keys.has(&"stress_alpha") and cohort_keys.has(&"stress_beta"), "two independent stress cohorts were not built")

	# Moving target, explicit target switch, and atomic sleep/wake parity.
	target_a.position = Vector3(-6.0, 0.0, -1.0)
	for _frame: int in range(12):
		await physics_frame
	enemies[0]._set_combat_target(target_b)
	_expect(enemies[0].ai_player == target_b, "explicit target switch was not authoritative")
	enemies[1].set_ai_participation(false)
	await physics_frame
	_expect(not enemies[1].is_in_group("combatant_ai") and registry.living_count(StringName(), true) == STRESS_COUNT - 1, "sleep did not atomically leave active registry/crowd views")
	enemies[1].set_ai_participation(true)
	await physics_frame
	_expect(enemies[1].is_in_group("combatant_ai") and enemies[1].is_physics_processing() and registry.living_count(StringName(), true) == STRESS_COUNT, "wake did not atomically restore physics, active registry, and crowd views")

	# Successive dismemberments in one live crowd must release equipment without
	# destabilizing the remaining combatants.
	for index: int in range(4):
		var victim := enemies[2 + index]
		victim.max_health = 100000.0
		victim.health = victim.max_health
		victim.defense_mode = &"none"
		victim.armor_sever_multiplier = 1.0
		var hit := HitEvent.new()
		hit.damage = 1.0
		hit.sever_damage = 100000.0
		hit.position = victim.anatomy.get_zone_world_center(&"forearm_r")
		hit.direction = Vector3.RIGHT
		victim.receive_anatomy_hit(hit, &"forearm_r")
		await process_frame
		_expect(victim.is_combat_zone_severed(&"forearm_r"), "%s failed successive crowd dismemberment" % victim.archetype_id)
		if victim.weapon_kind != &"unarmed":
			_expect(victim.sword_dropped, "%s retained right-hand equipment after section (kind=%s root=%s current_scene=%s)" % [victim.archetype_id, victim.weapon_kind, victim.sword_root != null, current_scene != null])

	# Successive deaths must remove all AI/navigation/scheduler participation while
	# the rest of the 36-unit crowd remains live.
	for index: int in range(4):
		enemies[8 + index]._die(false)
	await process_frame
	await physics_frame
	_expect(registry.living_count() == STRESS_COUNT - 4, "registry retained dead stress units as living")
	_expect(get_nodes_in_group("combatant_ai").size() == STRESS_COUNT - 4, "crowd group retained dead stress units")
	for index: int in range(4):
		var dead_enemy := enemies[8 + index]
		_expect(dead_enemy.dead and not dead_enemy.ai_enabled, "%s death did not disable AI" % dead_enemy.archetype_id)
		_expect(dead_enemy.navigation_component == null or not dead_enemy.navigation_component.has_destination, "%s death retained a navigation destination" % dead_enemy.archetype_id)

	for _frame: int in range(45):
		await physics_frame
	_expect(director.spatial_rebuild_count < 25, "20 Hz crowd grid regressed toward per-frame rebuilding")

	world.queue_free()
	await process_frame
	await process_frame
	var live_refs := 0
	for ref: WeakRef in refs:
		if is_instance_valid(ref.get_ref()):
			live_refs += 1
	_expect(live_refs == 0, "mixed stress teardown retained %d enemy instances" % live_refs)
	_expect(get_nodes_in_group("combatant_ai").is_empty(), "mixed stress teardown retained combatant_ai members")

	if failures.is_empty():
		print("ENEMY_MIXED_STRESS_PROBE PASS: 22 families/36 units, threshold 28, two cohorts, moving/changed target, wake, 4 sections, 4 deaths, cleanup")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _add_floor_and_chokepoint(parent: Node3D) -> void:
	var floor := StaticBody3D.new()
	parent.add_child(floor)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.5
	floor.add_child(floor_shape)
	for x_position: float in [-2.2, 2.2]:
		var wall := StaticBody3D.new()
		wall.position = Vector3(x_position, 1.0, 0.0)
		parent.add_child(wall)
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(1.2, 2.0, 8.0)
		wall_shape.shape = wall_box
		wall.add_child(wall_shape)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
