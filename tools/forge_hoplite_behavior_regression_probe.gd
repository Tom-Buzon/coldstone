extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const NavigationComponentScript = preload("res://scripts/ai/enemy_navigation_component.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var runtime := _build_forge_runtime()
	var spawn_wait_frames: int = 0
	while not runtime.pending_enemy_spawns.is_empty() and spawn_wait_frames < 120:
		await process_frame
		await physics_frame
		spawn_wait_frames += 1
	_expect(runtime.pending_enemy_spawns.is_empty(), "Forge staged enemy spawn queue did not drain within 120 frames")
	for _frame: int in range(4):
		await physics_frame

	var line := runtime.enemies_by_group.get("forge_behavior_line", []) as Array
	var degraded := runtime.enemies_by_group.get("forge_behavior_degraded", []) as Array
	var combat := runtime.enemies_by_group.get("forge_behavior_combat", []) as Array
	_expect(line.size() == 6, "Forge did not spawn the six-unit hoplite line")
	_expect(degraded.size() == 4, "Forge did not spawn the four-unit degraded cohort")
	_expect(combat.size() == 8, "Forge did not spawn the eight-unit combat cohort")
	if line.size() == 6 and degraded.size() == 4 and combat.size() == 8:
		_probe_forge_navigation(runtime, line)
		await _probe_combat_liveness(runtime, combat)
		_probe_controller_fifo(runtime, line)
		await _probe_live_replacement(runtime, line)
		await _probe_degraded_member_recovery(runtime, degraded)
		_probe_multi_cohort_sortie(runtime, line, degraded)

	if failures.is_empty():
		print("FORGE_HOPLITE_BEHAVIOR_REGRESSION_PROBE PASS: Forge NavMesh, controller FIFO, live replacement, degraded recovery, multi-cohort sortie")
		runtime.queue_free()
		await process_frame
		quit(0)
		return
	for failure: String in failures:
		push_error("[FORGE HOPLITE BEHAVIOR] " + failure)
	runtime.queue_free()
	await process_frame
	quit(1)


func _build_forge_runtime() -> HopliteWorldRuntime:
	var data := WorldDocumentScript.create_default()
	var spawn := WorldDocumentScript.entity("player_spawn", "Behavior Spawn", Vector3(0.0, 0.05, 3.2), {"spawn_id": "behavior"})
	var floor := WorldDocumentScript.entity("surface", "Behavior Floor", Vector3(0.0, -0.10, 0.0), {
		"shape": "floor", "size": [30.0, 0.2, 30.0], "material": "pavers"
	})
	var obstacle := WorldDocumentScript.entity("surface", "Navigation Obstacle", Vector3(0.0, 1.0, 1.3), {
		"shape": "box", "size": [2.4, 2.0, 0.7], "material": "fortress"
	})
	var line := WorldDocumentScript.entity("enemy_group", "Behavior Line", Vector3(0.0, 0.05, -1.5), {
		"group_id": "forge_behavior_line", "archetype": "ngeneral", "count": 6,
		"composition": [{"archetype": "ngeneral", "count": 5}, {"archetype": "ngeneral_veteran", "count": 1}],
		"rank": "normal", "formation": "phalanx", "spawn_condition": "start", "deployment_mode": "all"
	})
	var degraded := WorldDocumentScript.entity("enemy_group", "Degraded Line", Vector3(9.0, 0.05, -1.5), {
		"group_id": "forge_behavior_degraded", "archetype": "ngeneral", "count": 4,
		"rank": "normal", "formation": "phalanx", "spawn_condition": "start", "deployment_mode": "all"
	})
	var combat := WorldDocumentScript.entity("enemy_group", "Combat Line", Vector3(-8.0, 0.05, -1.5), {
		"group_id": "forge_behavior_combat", "archetype": "ngeneral", "count": 8,
		"composition": [{"archetype": "ngeneral", "count": 6}, {"archetype": "ngeneral_veteran", "count": 2}],
		"rank": "normal", "formation": "phalanx", "spawn_condition": "start", "deployment_mode": "all"
	})
	for entity: Dictionary in [spawn, floor, obstacle, line, degraded, combat]:
		entity["chapter"] = "chapter_1"
	data["entities"] = [spawn, floor, obstacle, line, degraded, combat]
	var document := WorldDocumentScript.new(data) as HopliteWorldDocument
	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	runtime.name = "ForgeHopliteBehaviorRegression"
	root.add_child(runtime)
	current_scene = runtime
	runtime.build(document, false)
	runtime.player.set_physics_process(false)
	runtime.player.set_process(false)
	runtime.player.health = 100000.0
	runtime.player.max_health = 100000.0
	return runtime


func _probe_forge_navigation(runtime: HopliteWorldRuntime, soldiers: Array) -> void:
	var region := runtime.world_root.get_node_or_null("WorldNavigationRegion") as NavigationRegion3D
	_expect(region != null, "playable Forge runtime owns no NavigationRegion3D")
	if region != null:
		_expect(region.navigation_mesh != null and region.navigation_mesh.get_polygon_count() > 0, "Forge runtime navigation bake produced no walkable polygons")
		var path := NavigationServer3D.map_get_path(
			region.get_navigation_map(), Vector3(0.0, 0.0, -1.5), Vector3(0.0, 0.0, 3.2), true
		)
		var saw_detour := false
		for point: Vector3 in path:
			if absf(point.x) > 1.25:
				saw_detour = true
		_expect(path.size() >= 3 and saw_detour, "Forge NavMesh path did not detour around the authored blocking surface")
		print("FORGE_HOPLITE_NAV polygons=", region.navigation_mesh.get_polygon_count(), " path_points=", path.size(), " detour=", saw_detour)
	for raw: Variant in soldiers:
		var soldier := raw as Node
		var navigation: Variant = soldier.get("navigation_component")
		_expect(navigation != null and int(navigation.mode) == NavigationComponentScript.Mode.NAVMESH_GROUND, "%s did not select NAVMESH_GROUND in Forge" % soldier.name)
		_expect(soldier.get_node_or_null("NavigationAgent") is NavigationAgent3D, "%s owns no NavigationAgent3D in Forge" % soldier.name)


func _probe_combat_liveness(runtime: HopliteWorldRuntime, soldiers: Array) -> void:
	for group_name: String in ["forge_behavior_line", "forge_behavior_degraded"]:
		for raw: Variant in runtime.enemies_by_group.get(group_name, []):
			(raw as Node).set_physics_process(false)
	runtime.player.global_position = Vector3(-8.0, 0.05, 1.8)
	var director := runtime.crowd_director
	for raw: Variant in soldiers:
		(raw as Node).set_physics_process(false)
		director.cancel_attack_requests(raw as Node3D)
	var assignments := _assign_all(director, soldiers, runtime.player)
	for raw: Variant in soldiers:
		var soldier := raw as Node3D
		soldier.global_position = assignments[soldier.get_instance_id()].get("position", soldier.global_position)
	director.phalanx_cache_frame = -1
	await physics_frame
	assignments = _assign_all(director, soldiers, runtime.player)
	_expect(bool(assignments[(soldiers[0] as Node).get_instance_id()].get("cohort_formed", false)), "combat cohort did not form in the Forge")
	var attack_count: Array[int] = [0]
	var distinct_attackers: Dictionary = {}
	for raw: Variant in soldiers:
		var soldier := raw as Node
		soldier.attack_started.connect(func(attacker: Node, _weapon: StringName) -> void:
			attack_count[0] += 1
			distinct_attackers[attacker.get_instance_id()] = true
		)
		soldier.set("ai_think_timer", 0.0)
		(soldier.get("cached_ai_goal") as Dictionary).clear()
		soldier.set_physics_process(true)
	for _frame: int in range(300):
		await physics_frame
	var states: Array[String] = []
	for raw: Variant in soldiers:
		var soldier := raw as Node
		states.append("%s:%s:r%d:dist=%.2f:cd=%.2f:def=%.2f:formed=%s:lease=%s" % [soldier.name, String(soldier.get("ai_state")), int(soldier.get("formation_row")), (soldier as Node3D).global_position.distance_to(runtime.player.global_position), float(soldier.get("ai_attack_cooldown_timer")), float(soldier.get("defense_timer")), str(soldier.get("formation_cohort_formed")), str(soldier.get("attack_permission_claimed"))])
	print("FORGE_HOPLITE_COMBAT attacks=", attack_count[0], " distinct=", distinct_attackers.size(), " queue=", director.attack_wait_queues.get(runtime.player.get_instance_id(), []), " permissions=", director.attack_permissions.get(runtime.player.get_instance_id(), {}), " states=", states)
	_expect(attack_count[0] >= 4, "formed Forge phalanx stared at the player instead of sustaining combat (attacks=%d)" % attack_count[0])
	_expect(distinct_attackers.size() >= 2, "Forge combat did not use both simultaneous hoplite attack lanes (distinct=%d)" % distinct_attackers.size())
	for raw: Variant in soldiers:
		var soldier := raw as Node
		soldier.set_physics_process(false)
		director.cancel_attack_requests(soldier)
	runtime.player.global_position = Vector3(0.0, 0.05, 3.2)


func _probe_controller_fifo(runtime: HopliteWorldRuntime, soldiers: Array) -> void:
	for raw: Variant in soldiers:
		(raw as Node).set_physics_process(false)
	var first := soldiers[0] as Node
	var second := soldiers[1] as Node
	var third := soldiers[2] as Node
	var fourth := soldiers[3] as Node
	_expect(bool(first.call("_claim_attack_permission", runtime.player)), "first hoplite did not receive a lease")
	_expect(bool(second.call("_claim_attack_permission", runtime.player)), "second hoplite did not receive a lease")
	_expect(not bool(third.call("_claim_attack_permission", runtime.player)), "third hoplite bypassed the two-lease capacity")
	_expect(not bool(fourth.call("_claim_attack_permission", runtime.player)), "fourth hoplite bypassed the two-lease capacity")
	var target_id := runtime.player.get_instance_id()
	var queue_before: Array = (runtime.crowd_director.attack_wait_queues.get(target_id, []) as Array).duplicate()
	_expect(queue_before == [third.get_instance_id(), fourth.get_instance_id()], "real controller did not publish FIFO order")
	_expect(not bool(third.call("_claim_attack_permission", runtime.player)), "waiting hoplite unexpectedly received a full-capacity lease")
	var queue_after: Array = (runtime.crowd_director.attack_wait_queues.get(target_id, []) as Array).duplicate()
	_expect(queue_after == queue_before, "retrying through the real controller lost the oldest FIFO position")
	runtime.crowd_director.cancel_attack_requests(first)
	runtime.crowd_director.cancel_attack_requests(second)
	runtime.crowd_director.cancel_attack_requests(third)
	runtime.crowd_director.cancel_attack_requests(fourth)


func _probe_live_replacement(runtime: HopliteWorldRuntime, soldiers: Array) -> void:
	var director := runtime.crowd_director
	var assignments := _assign_all(director, soldiers, runtime.player)
	for raw: Variant in soldiers:
		var soldier := raw as Node3D
		soldier.global_position = assignments[soldier.get_instance_id()].get("position", soldier.global_position)
	director.phalanx_cache_frame = -1
	await physics_frame
	assignments = _assign_all(director, soldiers, runtime.player)
	_expect(bool(assignments[(soldiers[0] as Node).get_instance_id()].get("cohort_formed", false)), "real Forge cohort did not form at its published slots")
	var victim: Node
	for raw: Variant in soldiers:
		var candidate := raw as Node
		if int(assignments[candidate.get_instance_id()].get("row", -1)) == 0:
			victim = candidate
			break
	if victim == null:
		_expect(false, "real Forge cohort published no front-rank victim")
		return
	var vacancy_slot := int(assignments[victim.get_instance_id()].get("slot", -1))
	victim.call("set_ai_participation", false)
	await physics_frame
	var survivors: Array = []
	for raw: Variant in soldiers:
		if raw != victim:
			survivors.append(raw)
	var promoted_assignments := _assign_all(director, survivors, runtime.player)
	var promoted: Node
	for raw: Variant in survivors:
		var survivor := raw as Node
		if int(promoted_assignments[survivor.get_instance_id()].get("slot", -1)) == vacancy_slot:
			promoted = survivor
			break
	_expect(promoted != null, "front-rank vacancy did not promote a living Forge hoplite")
	if promoted == null:
		return
	promoted.set_physics_process(true)
	promoted.set("ai_think_timer", 0.0)
	(promoted.get("cached_ai_goal") as Dictionary).clear()
	for _frame: int in range(120):
		await physics_frame
	var final_assignment: Dictionary = director.phalanx_assignment(promoted, runtime.player)
	var target: Vector3 = final_assignment.get("position", (promoted as Node3D).global_position)
	var distance := (promoted as Node3D).global_position.distance_to(target)
	_expect(distance <= 0.92, "promoted Forge hoplite did not physically fill the vacancy within two simulated seconds (%.3f m)" % distance)
	promoted.set_physics_process(false)


func _probe_degraded_member_recovery(runtime: HopliteWorldRuntime, soldiers: Array) -> void:
	var director := runtime.crowd_director
	for raw: Variant in soldiers:
		(raw as Node).set_physics_process(false)
	var assignments := _assign_all(director, soldiers, runtime.player)
	for index: int in range(soldiers.size()):
		var soldier := soldiers[index] as Node3D
		if index < 2:
			soldier.global_position = assignments[soldier.get_instance_id()].get("position", soldier.global_position)
		else:
			soldier.global_position += Vector3(12.0 + float(index), 0.0, 12.0)
	director.phalanx_cache_frame = -1
	await physics_frame
	_assign_all(director, soldiers, runtime.player)
	var state_key := "athenian:forge_behavior_degraded"
	var state: Dictionary = director.phalanx_cohort_states.get(state_key, {})
	_expect(not state.is_empty(), "degraded Forge cohort has no persistent state")
	if state.is_empty():
		return
	state["formed"] = false
	state["degraded"] = false
	state["assembly_started_at"] = Time.get_ticks_msec() * 0.001 - 4.0
	director.phalanx_cohort_states[state_key] = state
	director.phalanx_cache_frame = -1
	await physics_frame
	assignments = _assign_all(director, soldiers, runtime.player)
	_expect(bool(assignments[(soldiers[0] as Node).get_instance_id()].get("degraded", false)), "two ready Forge hoplites did not enter bounded degraded mode")
	var returning := soldiers[2] as Node3D
	returning.global_position = assignments[returning.get_instance_id()].get("position", returning.global_position)
	director.phalanx_cache_frame = -1
	await physics_frame
	assignments = _assign_all(director, soldiers, runtime.player)
	_expect(bool(assignments[returning.get_instance_id()].get("member_ready", false)), "a recovered degraded member remained permanently ineligible after reaching its slot")


func _probe_multi_cohort_sortie(runtime: HopliteWorldRuntime, first_cohort: Array, second_cohort: Array) -> void:
	var director := runtime.crowd_director
	var cohorts := [first_cohort, second_cohort]
	for cohort_index: int in range(cohorts.size()):
		var members: Array = cohorts[cohort_index]
		var center := runtime.player.global_position + Vector3(-2.0 if cohort_index == 0 else 2.0, 0.0, 4.0)
		for member_index: int in range(members.size()):
			var soldier := members[member_index] as Node3D
			soldier.call("set_ai_participation", true)
			soldier.set_physics_process(false)
			soldier.global_position = center + Vector3(float(member_index - 2) * 0.24, 0.0, 0.0)
	director.phalanx_cohort_states.clear()
	director.phalanx_sortie_states.clear()
	director.phalanx_battle_layout_cache.clear()
	director.phalanx_battle_layout_refresh_at.clear()
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	var combined: Array = first_cohort + second_cohort
	_assign_all(director, combined, runtime.player)
	_expect(director.phalanx_sortie_states.size() == 1, "real Forge phalanxes did not share one sortie controller")
	if director.phalanx_sortie_states.is_empty():
		return
	var state_key: Variant = director.phalanx_sortie_states.keys()[0]
	var state: Dictionary = director.phalanx_sortie_states[state_key]
	state["phase_started_at"] = Time.get_ticks_msec() * 0.001 - float(director.crowd_settings.get(&"phalanx_sortie_advance_duration", 0.9)) - 0.05
	director.phalanx_sortie_states[state_key] = state
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	var expected_sortie_size := maxi(1, int(director.crowd_settings.get(&"phalanx_sortie_size", 3.0)))
	var strike_ids: Array[int] = []
	var assignments := _assign_all(director, combined, runtime.player)
	for raw: Variant in combined:
		var soldier := raw as Node3D
		var assignment := assignments.get(soldier.get_instance_id(), {}) as Dictionary
		if StringName(assignment.get("breach_tactic", &"")) == &"coordinated_sortie":
			strike_ids.append(soldier.get_instance_id())
			soldier.global_position = assignment.get("position", soldier.global_position)
	_expect(strike_ids.size() == expected_sortie_size, "real Forge sortie did not advance the configured number of hoplites (%d)" % expected_sortie_size)
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	assignments = _assign_all(director, combined, runtime.player)
	var threatening := 0
	for raw: Variant in combined:
		var soldier := raw as Node3D
		var assignment := assignments.get(soldier.get_instance_id(), {}) as Dictionary
		if soldier.get_instance_id() in strike_ids and bool(assignment.get("breach_can_attack", false)):
			var goal := soldier.call("_phalanx_combat_goal", soldier.global_position.distance_to(runtime.player.global_position)) as Dictionary
			if bool(goal.get("attack_player", false)):
				threatening += 1
	_expect(threatening == expected_sortie_size, "real Forge sortie reached spear range but did not publish the configured number of valid attack goals (%d)" % expected_sortie_size)


func _assign_all(director: Node, soldiers: Array, target: Node3D) -> Dictionary:
	var assignments: Dictionary = {}
	for raw: Variant in soldiers:
		var soldier := raw as Node3D
		if soldier == null or not soldier.is_in_group("phalanx_unit"):
			continue
		assignments[soldier.get_instance_id()] = director.call("phalanx_assignment", soldier, target)
	return assignments


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
