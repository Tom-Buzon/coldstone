extends SceneTree

const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")
const CrowdSettings = preload("res://scripts/ai/crowd_management_settings.gd")

class Soldier extends Node3D:
	var faction: StringName = &"athenian"
	var behavior_mode: StringName = &"phalanx"
	var ai_player: Node3D
	var dead: bool = false

	func is_dead_for_combat() -> bool:
		return dead

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _probe_live_settings_contract()
	await _probe_stable_target_and_vacancy()
	await _probe_column_identity_survives_state_recreation()
	await _probe_degraded_assembly()
	if failures.is_empty():
		print("HOPLITE_COHORT_RECOVERY_PROBE PASS: stable target, vacancy, immutable columns and degraded assembly")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _probe_live_settings_contract() -> void:
	var director := CrowdDirector.new()
	root.add_child(director)
	var tuned := CrowdSettings.defaults()
	tuned[&"phalanx_columns"] = 5.0
	tuned[&"phalanx_column_spacing"] = 1.35
	tuned[&"phalanx_rank_spacing"] = 1.55
	tuned[&"phalanx_move_speed_multiplier"] = 1.75
	tuned[&"phalanx_arrival_slowdown_distance"] = 0.45
	tuned[&"phalanx_arrival_min_speed_scale"] = 0.95
	director.crowd_settings = CrowdSettings.sanitize(tuned)
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -12.0)
	root.add_child(target)
	var soldiers := _make_soldiers(target, &"settings_contract", 10)
	var assignments := _assign_all(director, soldiers, target)
	var columns_before_resize: Dictionary = {}
	for soldier: Soldier in soldiers:
		var assignment: Dictionary = assignments[soldier.get_instance_id()]
		columns_before_resize[soldier.get_instance_id()] = int(assignment.get("column", 0))
		_expect(int(assignment.get("formation_columns", 0)) == 5, "visible columns setting did not reach the assignment contract")
		_expect(is_equal_approx(float(assignment.get("formation_spacing", 0.0)), 1.35), "visible column spacing did not reach the assignment contract")
		_expect(is_equal_approx(float(assignment.get("formation_rank_spacing", 0.0)), 1.55), "visible rank spacing did not reach the assignment contract")
		_expect(is_equal_approx(float(assignment.get("move_speed_multiplier", 0.0)), 1.75), "visible hoplite catch-up speed did not reach the assignment contract")
		_expect(is_equal_approx(float(assignment.get("arrival_slowdown_distance", 0.0)), 0.45), "visible braking distance did not reach the assignment contract")
		_expect(is_equal_approx(float(assignment.get("arrival_min_speed_scale", 0.0)), 0.95), "visible braking speed did not reach the assignment contract")
	# A live width change is allowed to compact edge files, never to send them to
	# the opposite side of the centre line.
	director.crowd_settings[&"phalanx_columns"] = 3.0
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	var resized := _assign_all(director, soldiers, target)
	for soldier: Soldier in soldiers:
		var member_id := soldier.get_instance_id()
		var previous_column := int(columns_before_resize[member_id])
		var current_column := int(resized[member_id].get("column", 0))
		_expect(int(resized[member_id].get("formation_columns", 0)) == 3, "live columns setting did not rebuild the formation width")
		_expect(previous_column == 0 or current_column == 0 or signi(previous_column) == signi(current_column), "live columns setting moved a file across the formation centre")
	for soldier: Soldier in soldiers:
		soldier.free()
	target.free()
	director.free()

func _probe_stable_target_and_vacancy() -> void:
	var director := CrowdDirector.new()
	root.add_child(director)
	var target_a := Node3D.new()
	var target_b := Node3D.new()
	target_a.position = Vector3(0.0, 0.0, -12.0)
	target_b.position = Vector3(6.0, 0.0, -12.0)
	root.add_child(target_a)
	root.add_child(target_b)
	var soldiers := _make_soldiers(target_a, &"stable_cohort", 6)
	var first_assignments := _assign_all(director, soldiers, target_a)
	for soldier: Soldier in soldiers:
		soldier.global_position = first_assignments[soldier.get_instance_id()].get("position", soldier.global_position)
	director.phalanx_cache_frame = -1
	await physics_frame
	first_assignments = _assign_all(director, soldiers, target_a)
	_expect(bool(first_assignments[soldiers[0].get_instance_id()].get("cohort_formed", false)), "cohort did not form before target-change test")
	var slots_before: Dictionary = {}
	for soldier: Soldier in soldiers:
		slots_before[soldier.get_instance_id()] = int(first_assignments[soldier.get_instance_id()].get("slot", -1))
	var state_count_before := director.phalanx_cohort_states.size()
	for soldier: Soldier in soldiers:
		soldier.ai_player = target_b
	await physics_frame
	var changed_assignments := _assign_all(director, soldiers, target_b)
	_expect(director.phalanx_cohort_states.size() == state_count_before, "explicit cohort created a second state after target change")
	_expect(bool(changed_assignments[soldiers[0].get_instance_id()].get("cohort_formed", false)), "target change discarded formed cohort state")
	for soldier: Soldier in soldiers:
		_expect(int(changed_assignments[soldier.get_instance_id()].get("slot", -1)) == int(slots_before[soldier.get_instance_id()]), "target change reassigned a survivor slot")

	var removed := soldiers[2]
	var vacancy_slot := int(slots_before[removed.get_instance_id()])
	removed.dead = true
	director.phalanx_cache_frame = -1
	var replacement_started_at := Time.get_ticks_msec() * 0.001
	await physics_frame
	var promoted_assignments := _assign_all(director, soldiers, target_b)
	var promoted: Soldier
	var released_support_slot := -1
	for soldier: Soldier in soldiers:
		if soldier.dead:
			continue
		if int(promoted_assignments[soldier.get_instance_id()].get("slot", -1)) == vacancy_slot:
			promoted = soldier
			released_support_slot = int(slots_before.get(soldier.get_instance_id(), -1))
			break
	_expect(promoted != null, "front-rank death did not promote a living support soldier")
	_expect(Time.get_ticks_msec() * 0.001 - replacement_started_at < 0.2, "front-rank replacement was not published within 0.2 seconds")
	if promoted != null:
		var promoted_target: Vector3 = promoted_assignments[promoted.get_instance_id()].get("position", promoted.global_position)
		promoted.global_position = promoted_target
		_expect(promoted.global_position.distance_to(promoted_target) <= 0.01, "promoted survivor did not fill the front vacancy within 2 seconds")

	var reinforcement := Soldier.new()
	reinforcement.ai_player = target_b
	reinforcement.set_meta("formation_group", &"stable_cohort")
	reinforcement.position = Vector3(8.0, 0.0, 4.0)
	root.add_child(reinforcement)
	reinforcement.add_to_group("phalanx_unit")
	soldiers.append(reinforcement)
	director.phalanx_cache_frame = -1
	await physics_frame
	var vacancy_assignments := _assign_all(director, soldiers, target_b)
	for soldier: Soldier in soldiers:
		if soldier == removed or soldier == reinforcement or soldier == promoted:
			continue
		_expect(int(vacancy_assignments[soldier.get_instance_id()].get("slot", -1)) == int(promoted_assignments[soldier.get_instance_id()].get("slot", -1)), "unrelated survivor moved while filling the support vacancy")
	_expect(int(vacancy_assignments[reinforcement.get_instance_id()].get("slot", -1)) == released_support_slot, "reinforcement did not take the promoted soldier's support vacancy")

	for soldier: Soldier in soldiers:
		soldier.free()
	target_a.free()
	target_b.free()
	director.free()

func _probe_column_identity_survives_state_recreation() -> void:
	var director := CrowdDirector.new()
	root.add_child(director)
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -12.0)
	root.add_child(target)
	var soldiers := _make_soldiers(target, &"column_identity", 10)
	var assignments := _assign_all(director, soldiers, target)
	for soldier: Soldier in soldiers:
		soldier.global_position = assignments[soldier.get_instance_id()].get("position", soldier.global_position)
	director.phalanx_cache_frame = -1
	await physics_frame
	assignments = _assign_all(director, soldiers, target)
	var columns_before: Dictionary = {}
	var state_key: Variant = director.phalanx_cohort_states.keys()[0]
	var state_before: Dictionary = director.phalanx_cohort_states[state_key]
	var lateral_before: Vector3 = state_before.get("line_right", Vector3.RIGHT)
	for soldier: Soldier in soldiers:
		var member_id := soldier.get_instance_id()
		columns_before[member_id] = int(assignments[member_id].get("column", 0))
		_expect(director.phalanx_slot_history.get(member_id) is Vector3i, "column identity history is not stored in its packed descriptor")

	# Reproduce the rare runtime path: tactical state expires while member history
	# remains, and the next target direction is on the opposite side of the wall.
	director.phalanx_cohort_states.clear()
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	target.position = Vector3(0.0, 0.0, 12.0)
	await physics_frame
	var rebuilt := _assign_all(director, soldiers, target)
	var rebuilt_key: Variant = director.phalanx_cohort_states.keys()[0]
	var rebuilt_state: Dictionary = director.phalanx_cohort_states[rebuilt_key]
	var lateral_after: Vector3 = rebuilt_state.get("line_right", Vector3.LEFT)
	_expect(lateral_after.dot(lateral_before) > 0.99, "recreated cohort mirrored its world-space lateral axis")
	for soldier: Soldier in soldiers:
		var member_id := soldier.get_instance_id()
		_expect(int(rebuilt[member_id].get("column", 0)) == int(columns_before[member_id]), "recreated cohort exchanged a soldier's left/right column")

	# A deliberate about-face may exchange front and rear ranks, but it must keep
	# every lateral file and occupied world position intact.
	for soldier: Soldier in soldiers:
		soldier.global_position = rebuilt[soldier.get_instance_id()].get("position", soldier.global_position)
	director.phalanx_cache_frame = -1
	await physics_frame
	rebuilt = _assign_all(director, soldiers, target)
	_expect(bool(rebuilt[soldiers[0].get_instance_id()].get("cohort_formed", false)), "recreated cohort did not form before about-face regression")
	var positions_before_turn: Dictionary = {}
	for soldier: Soldier in soldiers:
		positions_before_turn[soldier.get_instance_id()] = rebuilt[soldier.get_instance_id()].get("position", soldier.global_position)
	target.position = Vector3(0.0, 0.0, -12.0)
	director.phalanx_cache_frame = -1
	await physics_frame
	var turned := _assign_all(director, soldiers, target)
	var turned_state: Dictionary = director.phalanx_cohort_states[rebuilt_key]
	var turned_lateral: Vector3 = turned_state.get("line_right", Vector3.LEFT)
	_expect(turned_lateral.dot(lateral_after) > 0.99, "about-face mirrored the lateral axis")
	for soldier: Soldier in soldiers:
		var member_id := soldier.get_instance_id()
		_expect(int(turned[member_id].get("column", 0)) == int(columns_before[member_id]), "about-face exchanged a soldier's left/right column")
		var position_before: Vector3 = positions_before_turn[member_id]
		var position_after: Vector3 = turned[member_id].get("position", soldier.global_position)
		_expect(position_after.distance_to(position_before) < 0.01, "about-face moved an occupied slot instead of rotating soldiers in place")

	for soldier: Soldier in soldiers:
		soldier.free()
	target.free()
	director.free()

func _probe_degraded_assembly() -> void:
	var director := CrowdDirector.new()
	root.add_child(director)
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -14.0)
	root.add_child(target)
	var soldiers := _make_soldiers(target, &"degraded_cohort", 4)
	var assignments := _assign_all(director, soldiers, target)
	for index: int in range(2):
		soldiers[index].global_position = assignments[soldiers[index].get_instance_id()].get("position", soldiers[index].global_position)
	for index: int in range(2, 4):
		soldiers[index].global_position = Vector3(20.0 + float(index) * 3.0, 0.0, 20.0)
	director.phalanx_cache_frame = -1
	await physics_frame
	_assign_all(director, soldiers, target)
	var state_key: Variant = director.phalanx_cohort_states.keys()[0]
	var state: Dictionary = director.phalanx_cohort_states[state_key]
	state["assembly_started_at"] = Time.get_ticks_msec() * 0.001 - 4.0
	director.phalanx_cohort_states[state_key] = state
	director.phalanx_cache_frame = -1
	await physics_frame
	assignments = _assign_all(director, soldiers, target)
	var ready_count := 0
	for soldier: Soldier in soldiers:
		if bool(assignments[soldier.get_instance_id()].get("member_ready", false)):
			ready_count += 1
	_expect(bool(assignments[soldiers[0].get_instance_id()].get("cohort_formed", false)), "two ready soldiers with two blocked reserves did not exit assembly after timeout")
	_expect(bool(assignments[soldiers[0].get_instance_id()].get("degraded", false)), "timed-out cohort was not marked degraded")
	_expect(ready_count == 2, "degraded cohort did not distinguish two ready members from two blocked reserves")
	for soldier: Soldier in soldiers:
		soldier.free()
	target.free()
	director.free()

func _make_soldiers(target: Node3D, group_name: StringName, count: int) -> Array[Soldier]:
	var soldiers: Array[Soldier] = []
	for index: int in range(count):
		var soldier := Soldier.new()
		soldier.ai_player = target
		soldier.position = Vector3((float(index) - float(count - 1) * 0.5) * 2.4, 0.0, 4.0 + float(index % 2))
		soldier.set_meta("formation_group", group_name)
		root.add_child(soldier)
		soldier.add_to_group("phalanx_unit")
		soldiers.append(soldier)
	return soldiers

func _assign_all(director: Node, soldiers: Array[Soldier], target: Node3D) -> Dictionary:
	var assignments: Dictionary = {}
	for soldier: Soldier in soldiers:
		if soldier.dead:
			continue
		assignments[soldier.get_instance_id()] = director.phalanx_assignment(soldier, target)
	return assignments

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
