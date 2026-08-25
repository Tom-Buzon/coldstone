extends SceneTree

const MapGeneratorScript = preload("res://scripts/campaign/procedural_map_generator.gd")
const WaveDirectorScript = preload("res://scripts/campaign/procedural_wave_director.gd")
const EnemyScript = preload("res://scripts/enemy/athenian_enemy.gd")
const ArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const CatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(CatalogScript.ASSETS.size() == 13, "The environment asset registry is incomplete")
	assert(CatalogScript.TEXTURES.size() == 13, "The environment texture registry is incomplete")
	var world := Node3D.new()
	root.add_child(world)
	for index: int in range(3):
		var zone_id: StringName = [&"walls", &"city", &"dungeon"][index]
		var generator := MapGeneratorScript.new() as HopliteProceduralMapGenerator
		var layout := generator.generate(world, zone_id, 7103 + index * 97)
		assert(layout.has("zone_root"), "%s did not produce a root" % String(zone_id))
		assert((layout.get("spawn_points", []) as Array).size() >= 12, "%s has too few safe spawns" % String(zone_id))
		assert((layout.get("zone_root") as Node3D).get_child_count() >= 12, "%s generated too little geometry" % String(zone_id))
		assert(layout.has("safe_bounds") and (layout.get("safe_bounds") as Rect2).has_point(Vector2.ZERO), "%s has no valid safety bounds" % String(zone_id))
		assert((layout.get("player_spawn", Vector3.ZERO) as Vector3).y >= 1.0, "%s player spawn is too close to the floor" % String(zone_id))
		assert(int(layout.get("variant", -1)) in [0, 1, 2], "%s did not select a macro-layout variant" % String(zone_id))
		var generated_root := layout.get("zone_root") as Node3D
		assert(generated_root.find_children("*", "GPUParticles3D", true, false).size() > 0, "%s has no living brazier smoke" % String(zone_id))
		if zone_id == &"city":
			var road := generated_root.get_node("ProcessionalRoad") as StaticBody3D
			var agora := generated_root.get_node("Agora") as StaticBody3D
			var road_mesh := (road.get_child(0) as MeshInstance3D).mesh as BoxMesh
			var agora_mesh := (agora.get_child(0) as MeshInstance3D).mesh as BoxMesh
			var road_top := road.position.y + road_mesh.size.y * 0.5
			var agora_top := agora.position.y + agora_mesh.size.y * 0.5
			assert(not is_equal_approx(road_top, agora_top), "City road/agora still share a texture plane")
		if zone_id == &"dungeon":
			var dungeon_floor := generated_root.get_node("DungeonFloor") as StaticBody3D
			assert(dungeon_floor.get_child_count() >= 2 and dungeon_floor.get_child(1) is CollisionShape3D, "Dungeon spawn floor has no collision")
			assert(generated_root.find_children("WallTorch_*", "Node3D", false, false).size() == 12, "Dungeon wall torches are incomplete")
			var magistrates := generated_root.find_children("Prop_magistrate_statue_*", "Node3D", false, false)
			assert(magistrates.size() == 1 and is_zero_approx((magistrates[0] as Node3D).rotation.y), "Magistrate statue faces away from the player")
		(layout.get("zone_root") as Node3D).free()

	var nfull_profile := ArchetypesScript.profile(&"nfull_armor")
	assert(StringName(nfull_profile.get("rank", StringName())) == &"boss")
	assert(float(nfull_profile.get("phase_threshold", 0.0)) > float(nfull_profile.get("phase_three_threshold", 0.0)))
	assert((nfull_profile.get("phase_three_pattern", []) as Array).size() >= 3)

	var boss := EnemyScript.new() as HopliteAthenianEnemy
	boss.archetype_id = &"nfull_armor"
	boss.ai_enabled = false
	boss.call("_apply_archetype_profile")
	boss.health = boss.max_health * 0.67
	boss.call("_try_activate_combat_phase")
	assert(boss.combat_phase == 2, "NFullArmor did not enter phase 2")
	boss.health = boss.max_health * 0.31
	boss.call("_try_activate_combat_phase")
	assert(boss.combat_phase == 3, "NFullArmor did not enter phase 3")

	var wave_director := WaveDirectorScript.new() as HopliteProceduralWaveDirector
	world.add_child(wave_director)
	var walls_plan := wave_director.call("_plan_for_zone", &"walls") as Array
	var city_plan := wave_director.call("_plan_for_zone", &"city") as Array
	assert(walls_plan.size() == 1 and city_plan.size() == 1, "Outer zones are still split into overly long wave chains")
	for plan: Array in [walls_plan, city_plan]:
		var legions := (plan[0] as Dictionary).get("legions", []) as Array
		assert(legions.size() == 4, "A staged encounter does not define its four typed legions")
		for legion: Dictionary in legions:
			assert(int(legion.get("count", 0)) == 10, "A typed legion does not contain ten units")
	var dungeon_plan := wave_director.call("_plan_for_zone", &"dungeon") as Array
	assert(dungeon_plan.size() == 1 and StringName((dungeon_plan[0] as Dictionary).get("final_elite", StringName())) == &"nfull_armor")
	assert((dungeon_plan[0] as Dictionary).get("legions", []).size() == 4, "Dungeon staged legions are incomplete")
	assert(HopliteProceduralWaveDirector.DUNGEON_SURGE_TICKS == 10 and HopliteProceduralWaveDirector.DUNGEON_SURGE_PER_TICK == 2, "Dungeon entry surge no longer provides two minions per second for ten seconds")
	var archer_profile := ArchetypesScript.profile(&"nsbire2")
	assert(float(archer_profile.get("health", 999.0)) <= 48.0, "Archers still have excessive health")
	assert(float(archer_profile.get("preferred_min", 99.0)) < 4.0, "Archers still retreat before melee contact")
	assert(HopliteProceduralWaveDirector.SPAWN_BATCH == 2 and HopliteProceduralWaveDirector.MAX_CONCURRENT <= 32, "Progressive legion resource limits regressed")
	var target := Node3D.new()
	world.add_child(target)
	wave_director.player = target
	wave_director.spawn_points = [
		Vector3(-20.0, 0.05, -15.0), Vector3(20.0, 0.05, -15.0),
		Vector3(-20.0, 0.05, 15.0), Vector3(20.0, 0.05, 15.0)
	]
	wave_director.current_wave = 0
	wave_director.rng.seed = 8128
	wave_director.spawn_queue.clear()
	var wall_legions := (walls_plan[0] as Dictionary).get("legions", []) as Array
	wave_director.call("_queue_legion_set", wall_legions.slice(0, 2), 0)
	assert(wave_director.spawn_queue.size() == 20, "The map does not begin with two complete legions")
	var legion_counts := {}
	var legion_anchors := {}
	for spec: Dictionary in wave_director.spawn_queue:
		if not spec.has("legion_id"):
			continue
		var legion_id := int(spec.get("legion_id", -1))
		legion_counts[legion_id] = int(legion_counts.get(legion_id, 0)) + 1
		legion_anchors[legion_id] = spec.get("legion_anchor", Vector3.ZERO)
	assert(legion_counts.size() == 2 and legion_anchors.size() == 2, "The initial typed legions were merged into one spawn group")
	for count: Variant in legion_counts.values():
		assert(int(count) == 10, "A queued legion was split or oversized")
	var unique_anchors := {}
	for anchor: Variant in legion_anchors.values():
		unique_anchors[anchor] = true
	assert(unique_anchors.size() >= 2, "All typed legions still use the same spawn location")
	wave_director.zone_id = &"dungeon"
	wave_director.entry_reinforcement_points = [Vector3(-18.0, 0.05, 34.0), Vector3(18.0, 0.05, 34.0)]
	wave_director.call("_start_dungeon_entry_surge")
	for _second: int in range(10):
		wave_director.call("_update_dungeon_entry_surge", 1.0)
	assert(wave_director.dungeon_surge_spawned == 20, "Dungeon surge did not deploy exactly twenty minions")
	assert(not wave_director.dungeon_surge_active and wave_director.dungeon_surge_ticks_remaining == 0, "Dungeon surge did not stop after ten seconds")
	wave_director.zone_id = &"walls"
	wave_director.spawn_queue.clear()
	wave_director.call("_queue_legion_set", [wall_legions[2]], 2)
	assert(wave_director.spawn_queue.size() == 10, "The third legion is not queued as a progressive reinforcement")
	wave_director.spawn_queue.clear()
	wave_director.encounter_definition = walls_plan[0] as Dictionary
	wave_director.call("_queue_final_assault", wall_legions[3] as Dictionary)
	assert(wave_director.spawn_queue.size() == 11 and bool((wave_director.spawn_queue[0] as Dictionary).get("completion_elite", false)), "Final legion and elite are not deployed together")
	wave_director.spawn_queue.clear()
	# Stage triggers: no reinforcement while both opening legions have four or
	# more survivors; the third launches as soon as either one reaches three.
	var staged_enemies: Array[HopliteAthenianEnemy] = []
	for legion_index: int in range(2):
		for _unit: int in range(4):
			var staged_enemy := EnemyScript.new() as HopliteAthenianEnemy
			staged_enemy.set_meta("campaign_legion_id", legion_index)
			wave_director.active_enemies[staged_enemy.get_instance_id()] = staged_enemy
			staged_enemies.append(staged_enemy)
	wave_director.encounter_definition = walls_plan[0] as Dictionary
	wave_director.deployment_stage = 0
	wave_director.encounter_completed = false
	wave_director.call("_update_staged_deployment")
	assert(wave_director.spawn_queue.is_empty(), "Third legion launched before an opening legion was decimated")
	var removed_enemy := staged_enemies.pop_front() as HopliteAthenianEnemy
	wave_director.active_enemies.erase(removed_enemy.get_instance_id())
	removed_enemy.free()
	wave_director.call("_update_staged_deployment")
	assert(wave_director.deployment_stage == 1 and wave_director.spawn_queue.size() == 10, "Third legion did not launch at three survivors")
	wave_director.spawn_queue.clear()
	for _unit: int in range(3):
		var third_enemy := EnemyScript.new() as HopliteAthenianEnemy
		third_enemy.set_meta("campaign_legion_id", 2)
		wave_director.active_enemies[third_enemy.get_instance_id()] = third_enemy
		staged_enemies.append(third_enemy)
	wave_director.call("_update_staged_deployment")
	assert(wave_director.deployment_stage == 2 and wave_director.spawn_queue.size() == 11, "Final legion and elite did not launch after the third was decimated")
	wave_director.spawn_queue.clear()
	wave_director.active_enemies.clear()
	for staged_enemy: HopliteAthenianEnemy in staged_enemies:
		if is_instance_valid(staged_enemy):
			staged_enemy.free()
	var completion_state := [false]
	wave_director.zone_completed.connect(func() -> void: completion_state[0] = true)
	wave_director.running = true
	wave_director.completion_elite = boss
	wave_director.boss = boss
	wave_director.active_enemies[boss.get_instance_id()] = boss
	wave_director.call("_on_enemy_died", boss)
	assert(bool(completion_state[0]) and not wave_director.running, "Elite death did not immediately complete the zone")
	wave_director.active_enemies[123] = world
	wave_director.call("_on_enemy_tree_exited", 123)
	assert(not wave_director.active_enemies.has(123), "A freed enemy remained in the progression counter")

	print("[PROCEDURAL CAMPAIGN PROBE] PASS — staged legions, 20-unit dungeon entry surge, elite completion")
	boss.free()
	world.free()
	quit(0)
