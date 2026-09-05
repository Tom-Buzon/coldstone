extends SceneTree

const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")

class Fighter:
	extends Node3D

	var faction: StringName = &"athenian"
	var behavior_mode: StringName = &"aggressive"
	var ai_player: Node3D
	var dead := false

	func is_dead_for_combat() -> bool:
		return dead

	func is_ai_participating_for_combat() -> bool:
		return not dead

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_probe_proximity_handoff_and_opposed_rotation()
	_probe_static_inner_boss()
	_probe_phalanx_registration_safety()
	_probe_independent_phalanx_arcs()
	_probe_line_arc_lateral_continuity()
	_probe_expulsion_arc_reversal_lateral_continuity()
	_probe_phalanx_about_face_in_place()
	_probe_locked_phalanx_still_advances()
	_probe_slow_flank_preserves_lateral_files()
	_probe_three_cohort_enclosure()
	_probe_multi_phalanx_sortie()
	if failures.is_empty():
		print("CROWD_ENGAGEMENT_COORDINATION_PROBE PASS: independent melee contact, lateral slot continuity, fixed phalanx arcs, coordinated sorties and no ghost slots")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _probe_proximity_handoff_and_opposed_rotation() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var fighters: Array[Fighter] = []
	for index: int in range(12):
		var fighter := Fighter.new()
		var radius := 1.78 if index < 6 else 5.0
		var angle := float(index % 6) * TAU / 6.0
		fighter.position = Vector3(cos(angle), 0.0, sin(angle)) * radius
		root.add_child(fighter)
		fighters.append(fighter)
		director.engagement_assignment(fighter, target, 2.0)
	# Populate every live distance before forcing a deterministic rebalance.
	for fighter: Fighter in fighters:
		director.engagement_assignment(fighter, target, 2.0)
	director.engagement_coordinator.rebalance_after[target.get_instance_id()] = 0.0
	var initial_assignments: Dictionary = {}
	for fighter: Fighter in fighters:
		initial_assignments[fighter.get_instance_id()] = director.engagement_assignment(fighter, target, 2.0)
	var initial_contact_ids: Array[int] = []
	for fighter: Fighter in fighters:
		var assignment := initial_assignments[fighter.get_instance_id()] as Dictionary
		if bool(assignment.get("contact_assigned", false)):
			initial_contact_ids.append(fighter.get_instance_id())
		else:
			_expect(not bool(assignment.get("attack_ready", false)), "reserve soldier received attack permission outside the contact circle")
	_expect(initial_contact_ids.size() == 6, "proximity layout did not select six nearest contact fighters")

	# Move the player beside a former reserve. Proximity, not registration history,
	# must hand the contact role to him and revoke it from a now-distant incumbent.
	var promoted := fighters[6]
	target.position = Vector3(6.0, 0.0, 0.0)
	for fighter: Fighter in fighters:
		director.engagement_assignment(fighter, target, 2.0)
	director.engagement_coordinator.rebalance_after[target.get_instance_id()] = 0.0
	var promoted_assignment: Dictionary = director.engagement_assignment(promoted, target, 2.0)
	var demoted_assignment: Dictionary = director.engagement_assignment(fighters[3], target, 2.0)
	_expect(bool(promoted_assignment.get("contact_assigned", false)), "closest former reserve did not replace the old contact line after the player moved")
	_expect(bool(promoted_assignment.get("attack_ready", false)), "closest replacement could not attack after reaching his new contact post")
	_expect(not bool(demoted_assignment.get("attack_ready", false)), "distant former contact retained attack permission after handoff")

	# Freeze membership only for this phase check. Even and odd individual rings
	# still rotate oppositely; phalanges are tested separately and never use it.
	director.engagement_coordinator.rebalance_after[target.get_instance_id()] = INF
	var before_zero: Dictionary = promoted_assignment
	var ring_one_actor: Fighter
	var before_one: Dictionary = {}
	for fighter: Fighter in fighters:
		var candidate: Dictionary = director.engagement_assignment(fighter, target, 2.0)
		if int(candidate.get("ring", -1)) == 1:
			ring_one_actor = fighter
			before_one = candidate
			break
	var frame: Dictionary = director.engagement_frames[target.get_instance_id()]
	frame["started_at"] = float(frame.get("started_at", 0.0)) - 2.0
	director.engagement_frames[target.get_instance_id()] = frame
	var after_zero: Dictionary = director.engagement_assignment(promoted, target, 2.0)
	var after_one: Dictionary = director.engagement_assignment(ring_one_actor, target, 2.0) if ring_one_actor != null else {}
	var delta_zero := _position_angle_delta(before_zero, after_zero, target)
	var delta_one := _position_angle_delta(before_one, after_one, target)
	_expect(ring_one_actor != null, "twelve fighters produced no reserve ring")
	_expect(delta_zero * delta_one < 0.0, "adjacent crowd rings did not rotate in opposite directions")
	_free_nodes(fighters)
	target.free()
	director.free()


func _probe_static_inner_boss() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var boss := Fighter.new()
	boss.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(boss)
	var descriptor := {"formation_kind": &"individual", "crowd_role": &"boss"}
	var before: Dictionary = director.engagement_assignment(boss, target, 2.0, descriptor)
	var frame: Dictionary = director.engagement_frames[target.get_instance_id()]
	frame["started_at"] = float(frame.get("started_at", 0.0)) - 8.0
	director.engagement_frames[target.get_instance_id()] = frame
	var after: Dictionary = director.engagement_assignment(boss, target, 2.0, descriptor)
	var before_position: Vector3 = before.get("position", Vector3.ZERO)
	var after_position: Vector3 = after.get("position", Vector3.ZERO)
	_expect(StringName(before.get("role", &"")) == &"inner_boss", "boss was not assigned to the inner pocket")
	_expect(before_position.distance_to(target.position) < float(director.crowd_settings[&"contact_radius"]), "boss pocket is not inside the rotating contact circle")
	_expect(before_position.distance_to(after_position) <= 0.001, "boss pocket rotated with ordinary crowd rings")
	boss.free()
	target.free()
	director.free()


func _probe_phalanx_registration_safety() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var hoplite := Fighter.new()
	hoplite.behavior_mode = &"phalanx"
	hoplite.ai_player = target
	hoplite.position = Vector3(0.0, 0.0, 5.0)
	hoplite.set_meta("formation_group", &"ghost_safety")
	root.add_child(hoplite)
	hoplite.add_to_group("phalanx_unit")
	var descriptor := {"formation_kind": &"phalanx", "crowd_role": &"melee"}
	var assignment: Dictionary = director.engagement_assignment(hoplite, target, 2.0, descriptor)
	_expect(StringName(assignment.get("role", &"")) == &"formation_external", "phalanx participant was accepted as an individual")
	_expect(not director.engagement_slots.has(target.get_instance_id()), "phalanx left a ghost reservation in the individual rings")
	hoplite.free()
	target.free()
	director.free()


func _probe_independent_phalanx_arcs() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var first_cohort: Array[Fighter] = []
	var incoming_cohort: Array[Fighter] = []
	for member_index: int in range(5):
		var first := Fighter.new()
		first.behavior_mode = &"phalanx"
		first.ai_player = target
		first.position = Vector3(float(member_index - 2) * 0.35, 0.0, 4.5)
		first.set_meta("formation_group", &"independent_ready")
		root.add_child(first)
		first.add_to_group("phalanx_unit")
		first_cohort.append(first)

		var incoming := Fighter.new()
		incoming.behavior_mode = &"phalanx"
		incoming.ai_player = target
		# This cohort is inside the coordination perimeter but deliberately not
		# arranged in its eventual sector.
		incoming.position = Vector3(3.2 + float(member_index % 2) * 0.9, 0.0, 2.4 + float(member_index) * 0.28)
		incoming.set_meta("formation_group", &"independent_incoming")
		root.add_child(incoming)
		incoming.add_to_group("phalanx_unit")
		incoming_cohort.append(incoming)

	var first_assignment: Dictionary = director.phalanx_assignment(first_cohort[0], target)
	var incoming_assignment: Dictionary = director.phalanx_assignment(incoming_cohort[0], target)
	var first_key := String(first_assignment.get("cohort_key", ""))
	var incoming_key := String(incoming_assignment.get("cohort_key", ""))
	_expect(bool(first_assignment.get("breach", false)), "first phalanx waited for straight-line assembly before entering its multi-cohort arc")
	_expect(bool(incoming_assignment.get("breach", false)), "incoming phalanx did not target its own arc immediately")
	_expect(first_key != incoming_key, "two explicit phalanxes were merged into one internal cohort")
	_expect(int(first_assignment.get("unit_count", 0)) == 5, "first phalanx assignment included soldiers from the incoming cohort")
	_expect(int(incoming_assignment.get("unit_count", 0)) == 5, "incoming phalanx assignment included soldiers from the first cohort")

	# Complete only the first cohort's transition, obtain its final independent
	# slots, then place its soldiers there. The incoming cohort remains scattered
	# and unformed throughout this check.
	var first_state: Dictionary = director.phalanx_cohort_states.get(first_key, {})
	first_state["battle_arc_blend"] = 1.0
	first_state["last_update"] = Time.get_ticks_msec() * 0.001
	director.phalanx_cohort_states[first_key] = first_state
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	for first: Fighter in first_cohort:
		var destination: Dictionary = director.phalanx_assignment(first, target)
		first.position = destination.get("position", first.position)
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	first_assignment = director.phalanx_assignment(first_cohort[0], target)
	var incoming_state: Dictionary = director.phalanx_cohort_states.get(incoming_key, {})
	_expect(bool(first_assignment.get("member_ready", false)), "ready cohort member was coupled to the incoming cohort's readiness")
	_expect(not bool(first_assignment.get("breach_can_attack", false)), "distant coordinated wall attacked without using the sortie doctrine")
	_expect(not bool(incoming_state.get("formed", false)), "incoming cohort became formed through the neighbouring cohort's state")

	_free_nodes(first_cohort)
	_free_nodes(incoming_cohort)
	target.free()
	director.free()


func _probe_line_arc_lateral_continuity() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var layout := {
		"center_angle": PI * 0.5,
		"segment_span": PI * 0.5,
		"arc_radius": 4.84,
		"support_level": 0,
	}
	var facing := Vector3(0.0, 0.0, -1.0)
	var line_right := facing.cross(Vector3.UP).normalized()
	var arc_center := target.position + Vector3(0.0, 0.0, 1.0) * 4.84
	var positions: Array[Vector3] = []
	for column: int in range(-2, 3):
		var line_position := Vector3.ZERO + line_right * float(column) * 1.08
		var assignment: Dictionary = director._phalanx_coordinated_arc_assignment(
			target, 0, column, column + 2, 5, 1.18, 2.42, layout, line_position, 1.0
		)
		var position: Vector3 = assignment.get("position", Vector3.ZERO)
		positions.append(position)
		if column != 0:
			_expect((position - arc_center).dot(line_right) * float(column) > 0.0, "line/arc transition inverted a soldier's lateral side")
	for index: int in range(positions.size() - 1):
		_expect(positions[index].distance_to(positions[index + 1]) > 0.65, "coordinated arc collapsed neighbouring columns into a ball")
	target.free()
	director.free()


func _probe_expulsion_arc_reversal_lateral_continuity() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var origin_facing := Vector3(0.0, 0.0, -1.0)
	var stable_right := origin_facing.cross(Vector3.UP).normalized()
	for target_direction: Vector3 in [origin_facing, -origin_facing]:
		var negative := director._phalanx_expulsion_arc_assignment(
			null, target, target_direction, 0, -2, 0, 1.08, 1.18, 2.42, 5,
			Vector3(0.0, 0.0, 4.0), origin_facing, stable_right, 1.0
		)
		var positive := director._phalanx_expulsion_arc_assignment(
			null, target, target_direction, 0, 2, 4, 1.08, 1.18, 2.42, 5,
			Vector3(0.0, 0.0, 4.0), origin_facing, stable_right, 1.0
		)
		var negative_position: Vector3 = negative.get("position", Vector3.ZERO)
		var positive_position: Vector3 = positive.get("position", Vector3.ZERO)
		_expect((positive_position - negative_position).dot(stable_right) > 0.5, "solo expulsion arc exchanged left/right files when the target crossed the wall")
	target.free()
	director.free()


func _probe_phalanx_about_face_in_place() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var hoplites: Array[Fighter] = []
	for index: int in range(10):
		var hoplite := Fighter.new()
		hoplite.behavior_mode = &"phalanx"
		hoplite.ai_player = target
		hoplite.position = Vector3(float(index % 5 - 2) * 1.08, 0.0, 4.5 + float(index / 5) * 1.18)
		hoplite.set_meta("formation_group", &"about_face_in_place")
		root.add_child(hoplite)
		hoplite.add_to_group("phalanx_unit")
		hoplites.append(hoplite)

	var before: Dictionary = {}
	for hoplite: Fighter in hoplites:
		var assignment: Dictionary = director.phalanx_assignment(hoplite, target)
		before[hoplite.get_instance_id()] = assignment.duplicate(true)
		hoplite.position = assignment.get("position", hoplite.position)
	target.position = Vector3(0.0, 0.0, 9.0)
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	var after: Dictionary = {}
	for hoplite: Fighter in hoplites:
		after[hoplite.get_instance_id()] = director.phalanx_assignment(hoplite, target).duplicate(true)

	for hoplite: Fighter in hoplites:
		var member_id := hoplite.get_instance_id()
		var previous := before[member_id] as Dictionary
		var current := after[member_id] as Dictionary
		var previous_position: Vector3 = previous.get("position", Vector3.ZERO)
		var current_position: Vector3 = current.get("position", Vector3.INF)
		var previous_facing: Vector3 = previous.get("facing", Vector3.ZERO)
		var current_facing: Vector3 = current.get("facing", Vector3.ZERO)
		_expect(previous_position.distance_to(current_position) <= 0.001, "phalanx about-face moved an occupied slot instead of turning its soldier in place")
		_expect(previous_facing.dot(current_facing) <= -0.999, "phalanx about-face did not reverse each soldier's facing")
		_expect(int(previous.get("row", -1)) + int(current.get("row", -1)) == 1, "phalanx about-face did not exchange front and rear rank roles")
	_free_nodes(hoplites)
	target.free()
	director.free()


func _probe_slow_flank_preserves_lateral_files() -> void:
	var director := _director()
	# Isolate orientation from the separate forward-anchor translation doctrine.
	director.crowd_settings[&"phalanx_advance_speed"] = 0.0
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -8.0)
	root.add_child(target)
	var hoplites: Array[Fighter] = []
	for index: int in range(5):
		var hoplite := Fighter.new()
		hoplite.behavior_mode = &"phalanx"
		hoplite.ai_player = target
		hoplite.position = Vector3(float(index - 2) * 1.08, 0.0, 0.0)
		hoplite.set_meta("formation_group", &"slow_flank_lateral_lock")
		root.add_child(hoplite)
		hoplite.add_to_group("phalanx_unit")
		hoplites.append(hoplite)

	var initial_assignments: Dictionary = {}
	for hoplite: Fighter in hoplites:
		initial_assignments[hoplite.get_instance_id()] = director.phalanx_assignment(hoplite, target).duplicate(true)
	var cohort_key := String((initial_assignments[hoplites[0].get_instance_id()] as Dictionary).get("cohort_key", ""))
	var state: Dictionary = director.phalanx_cohort_states.get(cohort_key, {})
	state["formed"] = true
	state["degraded"] = false
	director.phalanx_cohort_states[cohort_key] = state
	var positive_id := -1
	var negative_id := -1
	var greatest_column := -999
	var smallest_column := 999
	for raw_member_id: Variant in initial_assignments.keys():
		var assignment := initial_assignments[raw_member_id] as Dictionary
		var column := int(assignment.get("column", 0))
		if column > greatest_column:
			greatest_column = column
			positive_id = int(raw_member_id)
		if column < smallest_column:
			smallest_column = column
			negative_id = int(raw_member_id)
	var initial_facing: Vector3 = (initial_assignments[positive_id] as Dictionary).get("facing", Vector3.FORWARD)
	var stable_right := initial_facing.cross(Vector3.UP).normalized()

	# One degree per simulated update is deliberately slower than the configured
	# turn rate. The previous implementation followed this orbit continuously and
	# exchanged the two edge soldiers without ever reaching its 120-degree test.
	var last_facing := initial_facing
	for reverse: bool in [false, true]:
		for sample_index: int in range(181):
			var degrees := float(180 - sample_index if reverse else sample_index)
			var angle := deg_to_rad(degrees)
			target.position = Vector3(sin(angle) * 8.0, 0.0, -cos(angle) * 8.0)
			state = director.phalanx_cohort_states.get(cohort_key, {})
			state["last_update"] = Time.get_ticks_msec() * 0.001 - 0.05
			director.phalanx_cohort_states[cohort_key] = state
			director.phalanx_assignment_cache.clear()
			director.phalanx_cache_frame = -1
			var positive := director.phalanx_assignment(_fighter_by_id(hoplites, positive_id), target)
			var negative := director.phalanx_assignment(_fighter_by_id(hoplites, negative_id), target)
			var positive_position: Vector3 = positive.get("position", Vector3.ZERO)
			var negative_position: Vector3 = negative.get("position", Vector3.ZERO)
			var lateral_separation := (positive_position - negative_position).dot(stable_right)
			_expect(lateral_separation > 3.5, "slow player flank exchanged the phalanx's left and right edge soldiers at %d degrees" % int(degrees))
			var facing: Vector3 = positive.get("facing", Vector3.ZERO)
			last_facing = facing
			_expect(absf(facing.dot(initial_facing)) >= 0.999, "formed phalanx rotated its complete line during a slow flank")
		if reverse:
			_expect(last_facing.dot(initial_facing) >= 0.999, "slow return flank did not turn every hoplite back in place")
		else:
			_expect(last_facing.dot(initial_facing) <= -0.999, "slow flank reached the rear but the hoplites did not turn in place")

	_free_nodes(hoplites)
	target.free()
	director.free()


func _probe_locked_phalanx_still_advances() -> void:
	var director := _director()
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -8.0)
	root.add_child(target)
	var hoplites: Array[Fighter] = []
	for index: int in range(5):
		var hoplite := Fighter.new()
		hoplite.behavior_mode = &"phalanx"
		hoplite.ai_player = target
		hoplite.position = Vector3(float(index - 2) * 1.08, 0.0, 0.0)
		hoplite.set_meta("formation_group", &"locked_axis_advance")
		root.add_child(hoplite)
		hoplite.add_to_group("phalanx_unit")
		hoplites.append(hoplite)
	var assignment := director.phalanx_assignment(hoplites[0], target)
	var cohort_key := String(assignment.get("cohort_key", ""))
	var state: Dictionary = director.phalanx_cohort_states.get(cohort_key, {})
	var before: Vector3 = state.get("front_center", Vector3.ZERO)
	state["formed"] = true
	state["last_update"] = Time.get_ticks_msec() * 0.001 - 0.05
	director.phalanx_cohort_states[cohort_key] = state
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	director.phalanx_assignment(hoplites[0], target)
	state = director.phalanx_cohort_states.get(cohort_key, {})
	var after: Vector3 = state.get("front_center", before)
	_expect(after.distance_to(before) > 0.05, "locking the phalanx lateral axis also froze its forward advance")
	_free_nodes(hoplites)
	target.free()
	director.free()


func _probe_three_cohort_enclosure() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var hoplites: Array[Fighter] = []
	for cohort_index: int in range(3):
		var angle := float(cohort_index) * TAU / 3.0
		var center := Vector3(cos(angle), 0.0, sin(angle)) * 5.0
		for member_index: int in range(5):
			var hoplite := Fighter.new()
			hoplite.behavior_mode = &"phalanx"
			hoplite.ai_player = target
			hoplite.position = center + Vector3(float(member_index - 2) * 0.3, 0.0, 0.0)
			hoplite.set_meta("formation_group", StringName("enclosure_%d" % cohort_index))
			root.add_child(hoplite)
			hoplite.add_to_group("phalanx_unit")
			hoplites.append(hoplite)
	var layouts: Dictionary = director._phalanx_battle_layouts_for_target(target)
	var primary_angles: Array[float] = []
	var total_coverage := 0.0
	var fixed_angles: Dictionary = {}
	for raw_layout: Variant in layouts.values():
		var layout := raw_layout as Dictionary
		if bool(layout.get("primary", false)):
			primary_angles.append(float(layout.get("center_angle", 0.0)))
			total_coverage += float(layout.get("segment_span", 0.0))
			fixed_angles[String(layout.get("cohort_key", ""))] = float(layout.get("center_angle", 0.0))
			_expect(float(layout.get("arc_radius", 0.0)) >= 4.80, "multi-phalanx arc did not use the doubled stand-off radius")
	_expect(primary_angles.size() == 3, "three arrived phalanxes did not receive three primary sectors")
	_expect(absf(total_coverage - deg_to_rad(280.0)) <= 0.02, "three phalanxes did not use the configured 280-degree coverage")
	if primary_angles.size() == 3:
		primary_angles.sort()
		var gaps: Array[float] = []
		for index: int in range(primary_angles.size()):
			gaps.append(wrapf(primary_angles[(index + 1) % primary_angles.size()] - primary_angles[index], 0.0, TAU))
		gaps.sort()
		_expect(absf(gaps[0] - deg_to_rad(280.0 / 3.0)) <= 0.03, "three-phalanx band did not preserve contiguous 93-degree sectors")
		_expect(gaps[2] >= deg_to_rad(170.0), "three-phalanx band did not leave its intended 80-degree opening")

	# Tangential movement of the members must not rotate the already established
	# phalanx sectors around the player.
	for hoplite: Fighter in hoplites:
		var radial := hoplite.position.normalized()
		hoplite.position += Vector3(-radial.z, 0.0, radial.x) * 0.65
	director.phalanx_battle_layout_cache.clear()
	director.phalanx_battle_layout_refresh_at.clear()
	var stable_layouts: Dictionary = director._phalanx_battle_layouts_for_target(target)
	for raw_key: Variant in fixed_angles.keys():
		var stable_layout := stable_layouts.get(raw_key, {}) as Dictionary
		_expect(absf(wrapf(float(stable_layout.get("center_angle", INF)) - float(fixed_angles[raw_key]), -PI, PI)) <= 0.001, "established phalanx sector rotated after member movement")
	var regulars: Array[Fighter] = []
	for index: int in range(6):
		var regular := Fighter.new()
		var angle := float(index) * TAU / 6.0
		regular.position = Vector3(cos(angle), 0.0, sin(angle)) * 1.78
		root.add_child(regular)
		regulars.append(regular)
		director.engagement_assignment(regular, target, 2.0)
	director.engagement_coordinator.rebalance_after[target.get_instance_id()] = 0.0
	for regular: Fighter in regulars:
		var regular_assignment: Dictionary = director.engagement_assignment(regular, target, 2.0)
		regular.position = regular_assignment.get("position", regular.position)
	for regular: Fighter in regulars:
		var regular_assignment: Dictionary = director.engagement_assignment(regular, target, 2.0)
		_expect(int(regular_assignment.get("ring", -1)) == 0, "a phalanx sector displaced ordinary melee from its independent contact circle")
		_expect(bool(regular_assignment.get("attack_ready", false)), "ordinary melee reached contact but phalanx count still blocked its attack eligibility")

	# A fourth primary cohort closes the circle and removes that opening.
	var fourth_cohort: Array[Fighter] = []
	var fourth_center := Vector3(cos(deg_to_rad(300.0)), 0.0, sin(deg_to_rad(300.0))) * 5.0
	for member_index: int in range(5):
		var hoplite := Fighter.new()
		hoplite.behavior_mode = &"phalanx"
		hoplite.ai_player = target
		hoplite.position = fourth_center + Vector3(float(member_index - 2) * 0.25, 0.0, 0.0)
		hoplite.set_meta("formation_group", &"enclosure_fourth")
		root.add_child(hoplite)
		hoplite.add_to_group("phalanx_unit")
		fourth_cohort.append(hoplite)
	director.phalanx_battle_layout_cache.clear()
	director.phalanx_battle_layout_refresh_at.clear()
	var four_layouts: Dictionary = director._phalanx_battle_layouts_for_target(target)
	var four_primary := 0
	for raw_layout: Variant in four_layouts.values():
		var layout := raw_layout as Dictionary
		if bool(layout.get("primary", false)):
			four_primary += 1
			_expect(absf(float(layout.get("segment_span", 0.0)) - TAU / 4.0) <= 0.02, "four-phalanx circle did not use fixed 90-degree sectors")
	_expect(four_primary == 4, "four nearby phalanxes did not close the primary circle")
	director.engagement_coordinator.rebalance_after[target.get_instance_id()] = 0.0
	for regular: Fighter in regulars:
		var regular_assignment: Dictionary = director.engagement_assignment(regular, target, 2.0)
		_expect(int(regular_assignment.get("ring", -1)) == 0, "four phalanxes trapped an ordinary soldier outside the independent contact circle")
	_free_nodes(regulars)
	_free_nodes(fourth_cohort)
	_free_nodes(hoplites)
	target.free()
	director.free()


func _probe_multi_phalanx_sortie() -> void:
	var director := _director()
	var target := Node3D.new()
	root.add_child(target)
	var hoplites: Array[Fighter] = []
	for cohort_index: int in range(2):
		var center := Vector3(-2.4 if cohort_index == 0 else 2.4, 0.0, 4.4)
		for member_index: int in range(5):
			var hoplite := Fighter.new()
			hoplite.behavior_mode = &"phalanx"
			hoplite.ai_player = target
			hoplite.position = center + Vector3(float(member_index - 2) * 0.25, 0.0, 0.0)
			hoplite.set_meta("formation_group", StringName("sortie_%d" % cohort_index))
			root.add_child(hoplite)
			hoplite.add_to_group("phalanx_unit")
			hoplites.append(hoplite)
	for hoplite: Fighter in hoplites:
		director.phalanx_assignment(hoplite, target)
	_expect(director.phalanx_sortie_states.size() == 1, "two phalanxes did not create one shared sortie state")
	if director.phalanx_sortie_states.is_empty():
		_free_nodes(hoplites)
		target.free()
		director.free()
		return
	var sortie_key: Variant = director.phalanx_sortie_states.keys()[0]
	var sortie_state: Dictionary = director.phalanx_sortie_states[sortie_key]
	_expect((sortie_state.get("selected_ids", []) as Array).size() == 3, "coordinated sortie did not select exactly three hoplites")
	sortie_state["phase_started_at"] = Time.get_ticks_msec() * 0.001 - float(director.crowd_settings.get(&"phalanx_sortie_advance_duration", 0.9)) - 0.05
	director.phalanx_sortie_states[sortie_key] = sortie_state
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	var strike_ids: Array[int] = []
	for hoplite: Fighter in hoplites:
		var assignment: Dictionary = director.phalanx_assignment(hoplite, target)
		if StringName(assignment.get("breach_tactic", &"")) == &"coordinated_sortie":
			strike_ids.append(hoplite.get_instance_id())
			hoplite.position = assignment.get("position", hoplite.position)
		else:
			_expect(not bool(assignment.get("breach_can_attack", false)), "wall member attacked instead of holding during a sortie")
	_expect(strike_ids.size() == 3, "sortie strike phase did not publish exactly three advancing members")
	director.phalanx_assignment_cache.clear()
	director.phalanx_cache_frame = -1
	var ready_strikers := 0
	for hoplite: Fighter in hoplites:
		var assignment: Dictionary = director.phalanx_assignment(hoplite, target)
		if hoplite.get_instance_id() in strike_ids and bool(assignment.get("breach_can_attack", false)):
			ready_strikers += 1
	_expect(ready_strikers == 3, "three sortie members reached attack radius but were not all eligible to strike")
	_free_nodes(hoplites)
	target.free()
	director.free()


func _director() -> HopliteBattleCrowdDirector:
	var director := CrowdDirector.new() as HopliteBattleCrowdDirector
	root.add_child(director)
	return director


func _position_angle_delta(before: Dictionary, after: Dictionary, target: Node3D) -> float:
	var before_delta: Vector3 = before.get("position", target.position) - target.position
	var after_delta: Vector3 = after.get("position", target.position) - target.position
	return wrapf(atan2(after_delta.z, after_delta.x) - atan2(before_delta.z, before_delta.x), -PI, PI)


func _free_nodes(nodes: Array[Fighter]) -> void:
	for node: Fighter in nodes:
		if is_instance_valid(node):
			node.free()


func _fighter_by_id(nodes: Array[Fighter], instance_id: int) -> Fighter:
	for node: Fighter in nodes:
		if node.get_instance_id() == instance_id:
			return node
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
