extends SceneTree

const LayoutRuntime = preload("res://scripts/enemy_v2/enemy_v2_battle_layout_runtime.gd")
const TroopRuntime = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Node3D.new()
	target.position = Vector3(7.0, 0.0, -5.0)
	world.add_child(target)
	for contact_count: int in range(1, 5):
		var layout := LayoutRuntime.new() as EnemyV2BattleLayoutRuntime
		for index: int in range(contact_count):
			var angle := float(index) * TAU / float(contact_count)
			var anchor := target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 6.0
			layout.register_group(StringName("contact_%d_%d" % [contact_count, index]), target, anchor, {}, &"hoplite_phalanx", 24)
		var frontline_angles: Array[float] = []
		for index: int in range(contact_count):
			var assignment := layout.assignment(StringName("contact_%d_%d" % [contact_count, index]))
			_expect(StringName(assignment.get("role", &"")) == &"frontline", "%d nearby phalanxes did not all receive contact sectors" % contact_count)
			frontline_angles.append(atan2((assignment.get("anchor_goal", Vector3.ZERO) as Vector3).z - target.global_position.z, (assignment.get("anchor_goal", Vector3.ZERO) as Vector3).x - target.global_position.x))
		_expect(_minimum_angular_gap(frontline_angles) >= TAU / float(contact_count) - 0.04 if contact_count > 1 else true, "%d contact phalanxes do not form the expected opposite/triangle/square ring" % contact_count)

	var dynamic_layout := LayoutRuntime.new() as EnemyV2BattleLayoutRuntime
	for index: int in range(5):
		var radius := 20.0 if index == 4 else 5.0
		var angle := float(index) * TAU / 5.0
		dynamic_layout.register_group(StringName("dynamic_%d" % index), target, target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius, {}, &"hoplite_phalanx", 24)
	# Build the first reservation, then move one reserve beside the player and one
	# former contact group away. The newcomer must stage outside, orbit, assemble,
	# and only then replace the obsolete focus.
	dynamic_layout.assignment(&"dynamic_0")
	dynamic_layout.update_group(&"dynamic_0", target.global_position + Vector3.RIGHT * 30.0, 24, 1.0)
	dynamic_layout.update_group(&"dynamic_4", target.global_position + Vector3.RIGHT * 1.0, 24, 1.0)
	dynamic_layout.invalidate_target(target)
	var outer_order := dynamic_layout.assignment(&"dynamic_4")
	_expect(StringName(outer_order.get("role", &"")) == &"approach", "a newcomer entered the contact structure before staging")
	_expect(StringName(outer_order.get("movement_phase", &"")) == &"outer", "a newcomer did not begin by clearing the occupied contact ring")
	_expect(absf((outer_order.get("anchor_goal", Vector3.ZERO) as Vector3).distance_to(target.global_position) - LayoutRuntime.APPROACH_RADIUS) < 0.05, "the newcomer outer route is not on the safe circle")
	_expect(StringName(dynamic_layout.assignment(&"dynamic_0").get("role", &"")) == &"support", "a distant old-focus phalanx kept its contact priority")
	var newcomer_record := dynamic_layout.records[&"dynamic_4"] as Dictionary
	var reserved_angle := float(newcomer_record["reserved_angle"])
	dynamic_layout.update_group(&"dynamic_4", target.global_position + Vector3.RIGHT * LayoutRuntime.APPROACH_RADIUS, 24, 1.0)
	var orbit_order := dynamic_layout.assignment(&"dynamic_4")
	if StringName(orbit_order.get("movement_phase", &"")) == &"orbit":
		var orbit_goal := orbit_order.get("anchor_goal", Vector3.ZERO) as Vector3
		_expect(absf(orbit_goal.distance_to(target.global_position) - LayoutRuntime.APPROACH_RADIUS) < 0.05, "the lateral maneuver left the safe approach circle")
	dynamic_layout.update_group(
		&"dynamic_4",
		target.global_position + Vector3(cos(reserved_angle), 0.0, sin(reserved_angle)) * LayoutRuntime.APPROACH_RADIUS,
		24,
		1.0
	)
	var assemble_order := dynamic_layout.assignment(&"dynamic_4")
	_expect(StringName(assemble_order.get("movement_phase", &"")) == &"assemble", "an aligned newcomer did not receive the radial assembly order")
	dynamic_layout.update_group(
		&"dynamic_4",
		target.global_position + Vector3(cos(reserved_angle), 0.0, sin(reserved_angle)) * LayoutRuntime.ASSEMBLY_RADIUS,
		24,
		1.0
	)
	newcomer_record["ready_since_msec"] = Time.get_ticks_msec() - LayoutRuntime.ADMISSION_READY_MSEC - 1
	dynamic_layout.invalidate_target(target)
	_expect(StringName(dynamic_layout.assignment(&"dynamic_4").get("role", &"")) == &"frontline", "a staged and coherent newcomer was not admitted")

	var skirmish_layout := LayoutRuntime.new() as EnemyV2BattleLayoutRuntime
	skirmish_layout.register_group(&"veterans", target, target.global_position + Vector3.BACK * 8.0, {}, &"hoplite_skirmish", 6)
	var skirmish := skirmish_layout.assignment(&"veterans")
	_expect(StringName(skirmish.get("role", &"")) == &"skirmish" and bool(skirmish.get("engage", false)), "the six-veteran squad was folded into phalanx reservations")
	_expect((skirmish.get("anchor_goal", Vector3.ZERO) as Vector3).distance_to(target.global_position) <= LayoutRuntime.SKIRMISH_RADIUS + 0.05, "the six-veteran squad does not close to contact through the encirclement")

	var state := {"slots": {1: Vector3(-2.0, 0.0, 1.0), 2: Vector3(2.0, 0.0, -1.0)}}
	var old_forward := Vector3.FORWARD
	var old_right := Vector3.UP.cross(old_forward).normalized()
	var before: Dictionary = {}
	for member_id: Variant in (state["slots"] as Dictionary).keys():
		var slot := (state["slots"] as Dictionary)[member_id] as Vector3
		before[member_id] = old_right * slot.x + old_forward * slot.z
	TroopRuntime._preserve_world_slots_for_about_face(state, old_forward, -old_forward)
	var new_right := Vector3.UP.cross(-old_forward).normalized()
	for member_id: Variant in (state["slots"] as Dictionary).keys():
		var slot := (state["slots"] as Dictionary)[member_id] as Vector3
		var after := new_right * slot.x - old_forward * slot.z
		_expect(after.distance_to(before[member_id] as Vector3) < 0.001, "about-face exchanged formation slots instead of turning soldiers in place")

	var intrusion_members: Array[Node3D] = []
	for index: int in range(16):
		var member := Node3D.new()
		world.add_child(member)
		intrusion_members.append(member)
	var intrusion_profile := preload("res://scripts/enemy_v2/hoplite_v2_phalanx_profile.gd").new()
	var intrusion_slots: Dictionary = {}
	for index: int in range(intrusion_members.size()):
		var member := intrusion_members[index]
		var row := int(index / 8)
		var column := index % 8
		intrusion_slots[member.get_instance_id()] = Vector3((float(column) - 3.5) * intrusion_profile.column_spacing, 0.0, (0.5 - float(row)) * intrusion_profile.rank_spacing)
	var intrusion_state := {
		"profile": intrusion_profile,
		"members": intrusion_members,
		"slots": intrusion_slots,
		"active_columns": 8,
		"breach_state": TroopRuntime.BreachState.CLOSED,
		"breach_candidate_since_msec": 0,
		"breach_close_at_msec": 0,
		"breach_lateral": 0.0,
		"breach_column": -1,
	}
	var formation_anchor := Vector3.ZERO
	var formation_forward := Vector3.FORWARD
	var formation_right := Vector3.UP.cross(formation_forward).normalized()
	var front_depth := intrusion_profile.rank_spacing * 0.5
	target.global_position = formation_anchor + formation_forward * (front_depth + 0.15)
	_expect(not TroopRuntime._update_breach_state(intrusion_state, target, formation_anchor, formation_forward, formation_right, 1000), "frontal shield contact opened the phalanx")
	target.global_position = formation_anchor + formation_forward * (front_depth - TroopRuntime.BREACH_ENTER_DEPTH - 0.10)
	TroopRuntime._update_breach_state(intrusion_state, target, formation_anchor, formation_forward, formation_right, 1100)
	_expect(int(intrusion_state["breach_state"]) == TroopRuntime.BreachState.CANDIDATE, "crossing the first rank did not create a breach candidate")
	TroopRuntime._update_breach_state(intrusion_state, target, formation_anchor, formation_forward, formation_right, 1100 + TroopRuntime.BREACH_CONFIRM_MSEC + 1)
	_expect(int(intrusion_state["breach_state"]) == TroopRuntime.BreachState.CHANNEL, "a confirmed first-rank crossing did not open a channel")
	var outer_before := intrusion_slots[intrusion_members[0].get_instance_id()] as Vector3
	var outer_after := TroopRuntime._breach_slot_position(intrusion_state, 0, formation_anchor, formation_forward, formation_right)
	var center_after := TroopRuntime._breach_slot_position(intrusion_state, 2, formation_anchor, formation_forward, formation_right)
	_expect((outer_after - (formation_anchor + formation_right * outer_before.x + formation_forward * outer_before.z)).length() < 0.001, "a distant column moved during a local breach")
	_expect(absf((center_after - formation_anchor).dot(formation_right)) >= TroopRuntime.BREACH_CHANNEL_CLEARANCE - 0.01, "the breached column did not create a local passage")

	world.free()
	if failures.is_empty():
		print("HOPLITE_V2_BATTLE_LAYOUT_PROBE PASS: contact=1/2/3/4 staged_admission=yes skirmish=independent breach=first_rank_local about_face=in_place")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 BATTLE LAYOUT] " + failure)
	quit(1)


func _minimum_angular_gap(angles: Array[float]) -> float:
	if angles.size() <= 1:
		return TAU
	angles.sort()
	var result := TAU
	for index: int in range(angles.size()):
		var next_index := (index + 1) % angles.size()
		var next_angle := angles[next_index] + (TAU if next_index == 0 else 0.0)
		result = minf(result, next_angle - angles[index])
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
