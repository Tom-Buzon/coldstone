extends RefCounted
class_name EnemyV2BattleLayoutRuntime

const TacticalFocusTracker = preload("res://scripts/enemy_v2/enemy_v2_tactical_focus_tracker.gd")
const TacticalOccupancyRuntime = preload("res://scripts/enemy_v2/enemy_v2_tactical_occupancy_runtime.gd")
const TrafficScheduler = preload("res://scripts/enemy_v2/enemy_v2_formation_traffic_scheduler.gd")
const FrontDirector = preload("res://scripts/enemy_v2/enemy_v2_front_director.gd")
const Capabilities = preload("res://scripts/enemy_v2/enemy_v2_unit_capabilities.gd")
const FormationOrder = preload("res://scripts/enemy_v2/enemy_v2_formation_order.gd")

## Strategic placement shared by all Enemy V2 troops attacking one target.
##
## The service owns no soldiers. It gives each whole group a stable sector and
## stages newcomers on an outer circle before admitting them into the contact
## ring. Consequently an arriving phalanx never receives a straight route
## through the player or through formations already in contact.

const MAX_CONTACT_PHALANXES := 4
const PRIMARY_RADIUS := 6.00
# Kept as a compatibility constant for existing tools. Support formations no
# longer use one ring; they occupy depth ranks starting at SUPPORT_DEPTH.
const SUPPORT_RADIUS := 30.00
const SUPPORT_DEPTH := 30.00
const RESERVE_FIRST_DEPTH := 74.00
const RESERVE_DEPTH_STEP := 18.00
const RESERVE_LATERAL_OFFSET := 7.00
const APPROACH_RADIUS := 15.00
const ASSEMBLY_RADIUS := 7.35
const SKIRMISH_RADIUS := 3.35
const RANGED_RADIUS := 14.00
const REMNANT_MAX_MEMBERS := 4
const CONTACT_ELIGIBILITY_RADIUS := 13.25
const CONTACT_RELEASE_RADIUS := 24.00
const FRONTLINE_SWAP_HYSTERESIS := 1.50
const REBALANCE_INTERVAL_MSEC := 350
const ADMISSION_READY_MSEC := 300
const APPROACH_RADIAL_TOLERANCE := 0.55
const APPROACH_ANGULAR_TOLERANCE := 0.075
const APPROACH_ANGULAR_STEP := 0.22
const MINIMUM_ADMISSION_COHESION := 0.62
const ORDER_GOAL_TOLERANCE := 0.85
const ORDER_REPLAN_DISTANCE := 2.0
const ORDER_MIN_HOLD_MSEC := 900
const MIN_ANCHOR_SEPARATION := 3.6

var front_director: RefCounted = FrontDirector.new()
var records: Dictionary = {}
var target_frames: Dictionary = {}
var target_initialized: Dictionary = {}
var dirty_targets: Dictionary = {}
var next_rebalance_msec: Dictionary = {}
var target_focus_revisions: Dictionary = {}
var next_registration_order := 1
var focus_tracker: RefCounted = TacticalFocusTracker.new()
var occupancy: RefCounted = TacticalOccupancyRuntime.new()
var traffic: RefCounted = TrafficScheduler.new(occupancy)


func register_group(
	group_id: StringName,
	target: Node3D,
	initial_anchor: Vector3,
	properties: Dictionary,
	mode: StringName,
	member_count: int
) -> void:
	remove_group(group_id)
	var target_id := target.get_instance_id() if target != null and is_instance_valid(target) else 0
	if target_id != 0:
		focus_tracker.call("register_target", target)
	var from_target := initial_anchor - target.global_position if target_id != 0 else Vector3.FORWARD
	from_target.y = 0.0
	if from_target.length_squared() < 0.001:
		from_target = Vector3.FORWARD
	if not target_frames.has(target_id):
		target_frames[target_id] = atan2(from_target.z, from_target.x)
	var columns := clampi(int(properties.get("formation_columns", 8)), 1, 16)
	var column_spacing := maxf(0.70, float(properties.get("formation_spacing", 1.20)))
	var rank_spacing := maxf(0.70, float(properties.get("formation_rank_spacing", 1.05)))
	var rows := maxi(1, ceili(float(member_count) / float(columns)))
	var formation_width := float(columns - 1) * column_spacing + 1.80
	var formation_depth := float(rows - 1) * rank_spacing + 2.10
	var initial_forward := -from_target.normalized()
	var cap := Capabilities.from_properties(properties, mode)
	var persistent := bool(properties.get("v2_persistent_fronts", false))
	var front_id := int(properties.get("v2_front_id", posmod(roundi(atan2(from_target.z, from_target.x) / (PI * 0.5)), 4)))
	var front_origin := initial_anchor
	var raw_origin: Variant = properties.get("v2_front_origin")
	if raw_origin is Array and raw_origin.size() == 3:
		front_origin = Vector3(float(raw_origin[0]), float(raw_origin[1]), float(raw_origin[2]))
	var front_forward := initial_forward
	var raw_forward: Variant = properties.get("v2_front_forward")
	if raw_forward is Array and raw_forward.size() == 3:
		front_forward = Vector3(float(raw_forward[0]), 0.0, float(raw_forward[2])).normalized()
	if bool(properties.get("v2_persistent_fronts", false)) and front_forward.length_squared() > 0.001:
		initial_forward = front_forward
	if cap.role == &"giant":
		formation_width = cap.body_radius * 2.0
		formation_depth = formation_width
	if persistent and target != null and target.is_inside_tree() and traffic.has_method("configure_world"):
		traffic.call("configure_world", target)

	records[group_id] = {
		"persistent_fronts": persistent,
		"capabilities": cap,
		"front_id": front_id,
		"front_origin": front_origin,
		"front_forward": front_forward,
		"home_anchor": initial_anchor,
		"columns": columns,
		"column_spacing": column_spacing,
		"rank_spacing": rank_spacing,
		"disorganized_until": 0,
		"target": target,
		"target_id": target_id,
		"initial_angle": atan2(from_target.z, from_target.x),
		"current_anchor": initial_anchor,
		"mode": mode,
		"battle_role": StringName(properties.get("v2_battle_role", &"frontline")),
		"member_count": member_count,
		"original_count": member_count,
		"registration_order": next_registration_order,
		"assignment": {},
		"admitted": false,
		"approach_phase": &"none",
		"reserved_angle": atan2(from_target.z, from_target.x),
		"ready_since_msec": 0,
		"cohesion": 0.0,
		"engaged": false,
		"intrusion": false,
		"formation_width": formation_width,
		"formation_depth": formation_depth,
		"forward": initial_forward,
		"order": null,
		"order_revision": 0,
	}
	occupancy.call("update_footprint", group_id, initial_anchor, initial_forward, formation_width, formation_depth)
	next_registration_order += 1
	dirty_targets[target_id] = true


func update_group(
	group_id: StringName,
	current_anchor: Vector3,
	member_count: int,
	cohesion: float = 0.0,
	engaged: bool = false,
	intrusion: bool = false,
	forward: Vector3 = Vector3.FORWARD
) -> void:
	if not records.has(group_id):
		return
	var record := records[group_id] as Dictionary
	var was_remnant := _is_remnant(record)
	if bool(record.get("persistent_fronts", false)):
		var now := Time.get_ticks_msec()
		var lost := maxi(0, int(record["member_count"]) - member_count)
		if now >= int(record.get("loss_window_until", 0)):
			record["recent_losses"] = 0
		if lost > 0:
			record["shape_settle_until"] = now + 2400
			record["recent_losses"] = int(record.get("recent_losses", 0)) + lost
			record["loss_window_until"] = now + 1500
		if (intrusion and not bool(record.get("intrusion", false))) or int(record.get("recent_losses", 0)) >= maxi(2, ceili(float(record["original_count"]) * 0.15)):
			record["disorganized_until"] = now + 2400
			record["recent_losses"] = 0
		var cap: EnemyV2UnitCapabilities = record["capabilities"]
		if cap.role != &"giant" and now >= int(record.get("shape_settle_until", 0)):
			var columns := mini(int(record["columns"]), maxi(1, member_count))
			if member_count <= ceili(float(record["original_count"]) * 0.25):
				columns = mini(3, columns)
			record["formation_width"] = float(columns - 1) * float(record["column_spacing"]) + 1.8
			record["formation_depth"] = float(maxi(1, ceili(float(member_count) / columns)) - 1) * float(record["rank_spacing"]) + 2.1
	record["current_anchor"] = current_anchor
	record["member_count"] = member_count
	record["cohesion"] = cohesion
	record["engaged"] = engaged
	record["intrusion"] = intrusion
	if forward.length_squared() > 0.0001:
		record["forward"] = forward.normalized()
	# A wide formation can need more than the reservation TTL to complete an
	# outer march. Refresh its live corridor from the formation heartbeat; dead
	# or removed groups still release through remove_group / expiry.
	traffic.call("touch", group_id)
	occupancy.call(
		"update_footprint",
		group_id,
		current_anchor,
		record.get("forward", Vector3.FORWARD) as Vector3,
		float(record.get("formation_width", 10.0)),
		float(record.get("formation_depth", 4.0))
	)
	if was_remnant != _is_remnant(record):
		dirty_targets[int(record["target_id"])] = true


func assignment(group_id: StringName) -> Dictionary:
	if not records.has(group_id):
		return {}
	var record := records[group_id] as Dictionary
	var target_id := int(record["target_id"])
	var target := record.get("target") as Node3D
	if target != null and is_instance_valid(target):
		focus_tracker.call("update_target", target)
		var focus_revision: int = int(focus_tracker.call("revision_for_id", target_id))
		if focus_revision != int(target_focus_revisions.get(target_id, 0)):
			target_focus_revisions[target_id] = focus_revision
			dirty_targets[target_id] = true
	var now_msec := Time.get_ticks_msec()
	if bool(dirty_targets.get(target_id, false)) or now_msec >= int(next_rebalance_msec.get(target_id, 0)):
		_rebuild_target(target_id)
	var reserved := record.get("assignment", {}) as Dictionary
	if target == null or not is_instance_valid(target) or reserved.is_empty():
		return {}
	var tactical_focus: Vector3 = focus_tracker.call("focus_for_id", target_id) as Vector3
	var raw_target_position := target.global_position
	if bool(record.get("persistent_fronts", false)):
		return _front_route_assignment(group_id, record, reserved, raw_target_position)
	if StringName(record.get("approach_phase", &"none")) != &"none":
		return _approach_assignment(record, tactical_focus)
	return _resolved_assignment(group_id, record, reserved, tactical_focus, raw_target_position)


func remove_group(group_id: StringName) -> void:
	if not records.has(group_id):
		return
	var target_id := int((records[group_id] as Dictionary)["target_id"])
	traffic.call("release", group_id)
	occupancy.call("remove_group", group_id)
	records.erase(group_id)
	dirty_targets[target_id] = true


func invalidate_target(target: Node3D) -> void:
	var target_id := target.get_instance_id() if target != null and is_instance_valid(target) else 0
	dirty_targets[target_id] = true


func snapshot(group_id: StringName) -> Dictionary:
	if not records.has(group_id):
		return {}
	var record := records[group_id] as Dictionary
	var result := (record.get("assignment", {}) as Dictionary).duplicate(true)
	result["admitted"] = bool(record.get("admitted", false))
	result["approach_phase"] = StringName(record.get("approach_phase", &"none"))
	result["reserved_angle"] = float(record.get("reserved_angle", record.get("initial_angle", 0.0)))
	return result


func active_corridor_count() -> int:
	return int(occupancy.call("active_corridor_count"))


func active_anchor_conflict_count() -> int:
	for record: Dictionary in records.values():
		if bool(record.get("persistent_fronts", false)) and occupancy.has_method("overlap_count"):
			return int(occupancy.call("overlap_count"))
	var result := 0
	var ids := records.keys()
	for first_index: int in range(ids.size()):
		var first := records[ids[first_index]] as Dictionary
		for second_index: int in range(first_index + 1, ids.size()):
			var second := records[ids[second_index]] as Dictionary
			if int(first.get("target_id", -1)) != int(second.get("target_id", -2)):
				continue
			var required_separation := maxf(
				MIN_ANCHOR_SEPARATION,
				(float(first.get("formation_depth", MIN_ANCHOR_SEPARATION)) + float(second.get("formation_depth", MIN_ANCHOR_SEPARATION))) * 0.42
			)
			if _planar_distance(first.get("current_anchor", Vector3.ZERO) as Vector3, second.get("current_anchor", Vector3.ZERO) as Vector3) < required_separation:
				result += 1
	return result


func constrain_anchor_step(group_id: StringName, current: Vector3, proposed: Vector3) -> Vector3:
	if not records.has(group_id) or _planar_distance(current, proposed) <= 0.0001:
		return proposed
	var record := records[group_id] as Dictionary
	if bool(record.get("persistent_fronts", false)) and occupancy.has_method("constrain_motion"):
		var allowed: Vector3 = occupancy.call("constrain_motion", group_id, current, proposed, record["forward"], record["forward"])
		record["anchor_blocked"] = allowed.is_equal_approx(current)
		return allowed
	var self_depth := float(record.get("formation_depth", MIN_ANCHOR_SEPARATION))
	for raw_other_id: Variant in records.keys():
		var other_id := StringName(raw_other_id)
		if other_id == group_id:
			continue
		var other := records[other_id] as Dictionary
		if int(other.get("target_id", -1)) != int(record.get("target_id", -2)):
			continue
		var other_anchor := other.get("current_anchor", Vector3.ZERO) as Vector3
		var other_depth := float(other.get("formation_depth", MIN_ANCHOR_SEPARATION))
		var required_separation := maxf(MIN_ANCHOR_SEPARATION, (self_depth + other_depth) * 0.42)
		var current_distance := _planar_distance(current, other_anchor)
		var proposed_distance := _planar_distance(proposed, other_anchor)
		# Existing overlaps are allowed to separate. A new step may never reduce
		# the distance below the group-level exclusion radius.
		if proposed_distance < required_separation and proposed_distance <= current_distance + 0.001:
			record["anchor_blocked"] = true
			dirty_targets[int(record.get("target_id", 0))] = true
			return current
	record["anchor_blocked"] = false
	return proposed


func resolve_anchor_overlap(group_id: StringName, current: Vector3, maximum_step: float) -> Vector3:
	if not records.has(group_id) or maximum_step <= 0.0:
		return current
	var record := records[group_id] as Dictionary
	if bool(record.get("persistent_fronts", false)) and occupancy.has_method("resolve_overlap"):
		return occupancy.call("resolve_overlap", group_id, current, maximum_step)
	var self_depth := float(record.get("formation_depth", MIN_ANCHOR_SEPARATION))
	var correction := Vector3.ZERO
	for raw_other_id: Variant in records.keys():
		var other_id := StringName(raw_other_id)
		if other_id == group_id:
			continue
		var other := records[other_id] as Dictionary
		if int(other.get("target_id", -1)) != int(record.get("target_id", -2)):
			continue
		var other_anchor := other.get("current_anchor", Vector3.ZERO) as Vector3
		var required_separation := maxf(
			MIN_ANCHOR_SEPARATION,
			(self_depth + float(other.get("formation_depth", MIN_ANCHOR_SEPARATION))) * 0.42
		)
		var away := current - other_anchor
		away.y = 0.0
		var distance := away.length()
		if distance >= required_separation:
			continue
		if distance < 0.001:
			away = Vector3.RIGHT if String(group_id) < String(other_id) else Vector3.LEFT
		else:
			away /= distance
		correction += away * (required_separation - distance)
	if correction.length_squared() < 0.0001:
		return current
	record["anchor_blocked"] = true
	return current + correction.limit_length(maximum_step)


func _rebuild_target(target_id: int) -> void:
	for raw_id: Variant in records:
		var record: Dictionary = records[raw_id]
		if int(record["target_id"]) == target_id and bool(record.get("persistent_fronts", false)):
			front_director.call("update", records, target_id, record["target"])
			dirty_targets[target_id] = false
			next_rebalance_msec[target_id] = Time.get_ticks_msec() + REBALANCE_INTERVAL_MSEC
			break
	var phalanxes: Array[StringName] = []
	var skirmishers: Array[StringName] = []
	var ranged: Array[StringName] = []
	for raw_group_id: Variant in records.keys():
		var group_id := StringName(raw_group_id)
		var record := records[group_id] as Dictionary
		if int(record["target_id"]) != target_id or bool(record.get("persistent_fronts", false)):
			continue
		if StringName(record["battle_role"]) == &"ranged":
			ranged.append(group_id)
		elif StringName(record["mode"]) == &"hoplite_phalanx" and not _is_remnant(record):
			phalanxes.append(group_id)
		else:
			skirmishers.append(group_id)
	var target_position := _target_position(phalanxes + skirmishers + ranged)
	var distance_sorter := func(a: StringName, b: StringName) -> bool:
		var a_record := records[a] as Dictionary
		var b_record := records[b] as Dictionary
		var a_distance := _effective_frontline_distance(a_record, target_position)
		var b_distance := _effective_frontline_distance(b_record, target_position)
		if not is_equal_approx(a_distance, b_distance):
			return a_distance < b_distance
		return int(a_record["registration_order"]) < int(b_record["registration_order"])
	phalanxes.sort_custom(distance_sorter)
	skirmishers.sort_custom(distance_sorter)
	ranged.sort_custom(distance_sorter)
	var eligible: Array[StringName] = []
	var supports: Array[StringName] = []
	for phalanx_index: int in range(phalanxes.size()):
		var group_id := phalanxes[phalanx_index]
		var record := records[group_id] as Dictionary
		var distance := _planar_distance(record["current_anchor"] as Vector3, target_position)
		# The four closest intact formations are always candidates for the active
		# fronts. They can therefore march from an authored reserve instead of
		# waiting forever for an individual actor to enter a player-centric ring.
		if phalanx_index < MAX_CONTACT_PHALANXES or distance <= CONTACT_ELIGIBILITY_RADIUS or bool(record.get("admitted", false)):
			eligible.append(group_id)
		else:
			supports.append(group_id)

	# The map can register all initial formations before the first strategic tick.
	# Seed that starting encirclement once; only later arrivals use staging.
	if not bool(target_initialized.get(target_id, false)):
		var seed_count := mini(eligible.size(), MAX_CONTACT_PHALANXES)
		var seeded: Array[StringName] = eligible.slice(0, seed_count)
		for group_id: StringName in seeded:
			var record := records[group_id] as Dictionary
			record["admitted"] = true
			record["approach_phase"] = &"none"
		_commit_contact_layout(seeded, target_position, target_id)
		target_initialized[target_id] = true

	var admitted: Array[StringName] = []
	var pending: Array[StringName] = []
	for group_id: StringName in eligible:
		var record := records[group_id] as Dictionary
		var distance := _planar_distance(record["current_anchor"] as Vector3, target_position)
		if bool(record.get("admitted", false)):
			if distance > CONTACT_RELEASE_RADIUS and not bool(record.get("engaged", false)):
				record["admitted"] = false
				record["approach_phase"] = &"none"
				record["ready_since_msec"] = 0
			else:
				admitted.append(group_id)
		elif StringName(record.get("approach_phase", &"none")) != &"none":
			pending.append(group_id)

	# At most one newcomer maneuvers toward the contact ring. This freezes the
	# established structure until the entrant is actually ready to join it.
	if admitted.size() < MAX_CONTACT_PHALANXES:
		var newcomer := _select_pending_newcomer(eligible, admitted, pending)
		if not newcomer.is_empty():
			var newcomer_record := records[newcomer] as Dictionary
			if StringName(newcomer_record.get("approach_phase", &"none")) == &"none":
				newcomer_record["approach_phase"] = &"outer"
				newcomer_record["ready_since_msec"] = 0
				var projected := admitted.duplicate()
				projected.append(newcomer)
				var mapping := _best_contact_mapping(projected, target_position, target_id)
				var future := mapping.get(newcomer, {}) as Dictionary
				newcomer_record["reserved_angle"] = float(future.get("angle", newcomer_record["initial_angle"]))
				newcomer_record["assignment"] = {
					"angle": float(newcomer_record["reserved_angle"]),
					"radius": ASSEMBLY_RADIUS,
					"engage": false,
					"role": &"approach",
					"ring": 1,
					"slot": projected.size() - 1,
				}
			if _newcomer_ready(newcomer_record, target_position):
				var now_msec := Time.get_ticks_msec()
				if int(newcomer_record.get("ready_since_msec", 0)) <= 0:
					newcomer_record["ready_since_msec"] = now_msec
				elif now_msec - int(newcomer_record["ready_since_msec"]) >= ADMISSION_READY_MSEC:
					newcomer_record["admitted"] = true
					newcomer_record["approach_phase"] = &"none"
					newcomer_record["ready_since_msec"] = 0
					admitted.append(newcomer)
					_commit_contact_layout(admitted, target_position, target_id)
			else:
				newcomer_record["ready_since_msec"] = 0

	var base_angle := float(target_frames.get(target_id, 0.0))
	if not admitted.is_empty():
		base_angle = float(((records[admitted[0]] as Dictionary).get("assignment", {}) as Dictionary).get("angle", base_angle))
	for group_id: StringName in phalanxes:
		var record := records[group_id] as Dictionary
		if bool(record.get("admitted", false)) or StringName(record.get("approach_phase", &"none")) != &"none":
			continue
		if not supports.has(group_id):
			supports.append(group_id)
	_assign_nearest(supports, _depth_candidates(base_angle, supports.size(), target_position), target_position)
	_assign_nearest(skirmishers, _candidates(base_angle, maxi(6, skirmishers.size()), SKIRMISH_RADIUS, true, &"skirmish", 2, 0.5), target_position)
	_assign_nearest(ranged, _candidates(base_angle, maxi(6, ranged.size()), RANGED_RADIUS, true, &"ranged", 3, 0.0), target_position)
	dirty_targets[target_id] = false
	next_rebalance_msec[target_id] = Time.get_ticks_msec() + REBALANCE_INTERVAL_MSEC


func _select_pending_newcomer(eligible: Array[StringName], admitted: Array[StringName], pending: Array[StringName]) -> StringName:
	for group_id: StringName in pending:
		if eligible.has(group_id) and not admitted.has(group_id):
			return group_id
	for group_id: StringName in eligible:
		if not admitted.has(group_id):
			return group_id
	return &""


func _newcomer_ready(record: Dictionary, target_position: Vector3) -> bool:
	var current := record["current_anchor"] as Vector3
	var radius := _planar_distance(current, target_position)
	var angle_error := absf(wrapf(float(record["reserved_angle"]) - _current_angle(record, target_position), -PI, PI))
	return (
		absf(radius - ASSEMBLY_RADIUS) <= APPROACH_RADIAL_TOLERANCE
		and angle_error <= APPROACH_ANGULAR_TOLERANCE * 1.35
		and float(record.get("cohesion", 0.0)) >= MINIMUM_ADMISSION_COHESION
	)


func _approach_assignment(record: Dictionary, target_position: Vector3) -> Dictionary:
	var current := record["current_anchor"] as Vector3
	var current_radius := _planar_distance(current, target_position)
	var current_angle := _current_angle(record, target_position)
	var reserved_angle := float(record.get("reserved_angle", current_angle))
	var phase := StringName(record.get("approach_phase", &"outer"))
	var goal_angle := current_angle
	var goal_radius := APPROACH_RADIUS
	if phase == &"outer" and absf(current_radius - APPROACH_RADIUS) <= APPROACH_RADIAL_TOLERANCE:
		phase = &"orbit"
		record["approach_phase"] = phase
	if phase == &"orbit":
		var angle_delta := wrapf(reserved_angle - current_angle, -PI, PI)
		if absf(angle_delta) <= APPROACH_ANGULAR_TOLERANCE:
			phase = &"assemble"
			record["approach_phase"] = phase
		else:
			goal_angle = current_angle + clampf(angle_delta, -APPROACH_ANGULAR_STEP, APPROACH_ANGULAR_STEP)
	if phase == &"assemble":
		goal_angle = reserved_angle
		goal_radius = ASSEMBLY_RADIUS
	var outward := Vector3(cos(goal_angle), 0.0, sin(goal_angle))
	var goal := target_position + outward * goal_radius
	goal.y = current.y
	var route_direction := _planar_direction(current, goal, -outward)
	return {
		"anchor_goal": goal,
		"facing": -outward if phase == &"assemble" else route_direction,
		"engage": false,
		"role": &"approach",
		"ring": 1,
		"slot": int((record.get("assignment", {}) as Dictionary).get("slot", -1)),
		"movement_phase": phase,
		"admitted": false,
	}


func _resolved_assignment(
	group_id: StringName,
	record: Dictionary,
	reserved: Dictionary,
	target_position: Vector3,
	raw_target_position: Vector3
) -> Dictionary:
	var angle := float(reserved.get("angle", float(record["initial_angle"])))
	var radius := float(reserved.get("radius", PRIMARY_RADIUS))
	var outward := Vector3(cos(angle), 0.0, sin(angle))
	var final_goal := reserved.get("position", target_position + outward * radius) as Vector3
	var final_facing := reserved.get("facing", -outward) as Vector3
	var role := StringName(reserved.get("role", &"reserve"))
	var current := record["current_anchor"] as Vector3
	if bool(record.get("admitted", false)):
		var current_angle := _current_angle(record, target_position)
		var radial_lane_error := absf(wrapf(angle - current_angle, -PI, PI))
		if radial_lane_error <= 0.18 and not bool(record.get("anchor_blocked", false)):
			var arrived := _planar_distance(current, final_goal) <= ORDER_GOAL_TOLERANCE
			var contact_facing := _planar_direction(current, raw_target_position, final_facing)
			return {
				"anchor_goal": final_goal,
				"facing": contact_facing if arrived or bool(record.get("engaged", false)) or bool(record.get("intrusion", false)) else _planar_direction(current, final_goal, final_facing),
				"engage": bool(reserved.get("engage", false)) and arrived,
				"role": role,
				"ring": int(reserved.get("ring", -1)),
				"slot": int(reserved.get("slot", -1)),
				"movement_phase": &"contact" if arrived else &"advance_front",
				"admitted": true,
			}
	# Compact pressure squads and ranged supports use their own narrow-lane
	# steering. The phalanx traffic scheduler only reserves full-width military
	# corridors and must not send a six-man squad on a wide outer detour.
	if role in [&"skirmish", &"ranged"]:
		return {
			"anchor_goal": final_goal,
			"facing": final_facing,
			"engage": bool(reserved.get("engage", false)),
			"role": role,
			"ring": int(reserved.get("ring", -1)),
			"slot": int(reserved.get("slot", -1)),
			"movement_phase": &"pressure" if role == &"skirmish" else &"support_fire",
			"admitted": false,
		}
	var order: Variant = record.get("order")
	var now_msec := Time.get_ticks_msec()
	var needs_order := order == null or _planar_distance(order.final_goal, final_goal) > ORDER_REPLAN_DISTANCE
	if needs_order and (order == null or now_msec >= order.min_hold_until_msec or bool(record.get("intrusion", false))):
		var path: PackedVector3Array = traffic.call(
			"request_route",
			group_id,
			current,
			final_goal,
			target_position,
			float(record.get("formation_width", 10.0)),
			100 if bool(reserved.get("engage", false)) else 20
		)
		if path.size() > 0:
			order = FormationOrder.new()
			record["order_revision"] = int(record.get("order_revision", 0)) + 1
			order.revision = int(record["order_revision"])
			order.role = role
			order.final_goal = final_goal
			order.final_facing = final_facing
			order.path = path
			order.waypoint_index = 0
			order.movement_phase = &"march"
			order.issued_at_msec = now_msec
			order.min_hold_until_msec = now_msec + ORDER_MIN_HOLD_MSEC
			record["order"] = order
	if order == null:
		var waiting_facing := record.get("forward", final_facing) as Vector3
		if bool(record.get("engaged", false)) or bool(record.get("intrusion", false)):
			waiting_facing = _planar_direction(current, raw_target_position, waiting_facing)
		return {
			"anchor_goal": current,
			"facing": waiting_facing,
			"engage": false,
			"role": role,
			"ring": int(reserved.get("ring", -1)),
			"slot": int(reserved.get("slot", -1)),
			"movement_phase": &"waiting_corridor",
			"admitted": bool(record.get("admitted", false)),
		}
	var route_finished: bool = bool(order.call("advance_if_reached", current, ORDER_GOAL_TOLERANCE))
	if route_finished:
		traffic.call("release", group_id)
		order.movement_phase = &"contact" if bool(record.get("admitted", false)) else &"hold"
		var resolved_facing := _planar_direction(current, raw_target_position, final_facing) if bool(record.get("admitted", false)) else final_facing
		return {
			"anchor_goal": final_goal,
			"facing": resolved_facing,
			"engage": bool(reserved.get("engage", false)),
			"role": role,
			"ring": int(reserved.get("ring", -1)),
			"slot": int(reserved.get("slot", -1)),
			"movement_phase": order.movement_phase,
			"admitted": bool(record.get("admitted", false)),
		}
	var waypoint: Vector3 = order.call("current_waypoint") as Vector3
	var route_facing := _planar_direction(current, waypoint, record.get("forward", final_facing) as Vector3)
	if bool(record.get("engaged", false)) or bool(record.get("intrusion", false)):
		route_facing = _planar_direction(current, raw_target_position, route_facing)
	return {
		"anchor_goal": waypoint,
		"facing": route_facing,
		"engage": false,
		"role": role,
		"ring": int(reserved.get("ring", -1)),
		"slot": int(reserved.get("slot", -1)),
		"movement_phase": &"march",
		"admitted": bool(record.get("admitted", false)),
	}


func _commit_contact_layout(group_ids: Array[StringName], target_position: Vector3, target_id: int) -> void:
	var mapping := _best_contact_mapping(group_ids, target_position, target_id)
	for group_id: StringName in group_ids:
		var record := records[group_id] as Dictionary
		record["assignment"] = (mapping.get(group_id, {}) as Dictionary).duplicate(true)
		record["admitted"] = true
		record["approach_phase"] = &"none"


func _best_contact_mapping(group_ids: Array[StringName], target_position: Vector3, target_id: int) -> Dictionary:
	var best_mapping: Dictionary = {}
	var best_cost := INF
	var count := group_ids.size()
	if count <= 0:
		return best_mapping
	var base_candidates: Array[float] = [float(target_frames.get(target_id, 0.0))]
	for group_id: StringName in group_ids:
		var record := records[group_id] as Dictionary
		var reference_angle := _reference_angle(record, target_position)
		for slot: int in range(count):
			base_candidates.append(reference_angle - float(slot) * TAU / float(count))
	for base_angle: float in base_candidates:
		var candidates := _candidates(base_angle, count, PRIMARY_RADIUS, true, &"frontline", 0, 0.0)
		var available := candidates.duplicate(true)
		var mapping: Dictionary = {}
		var cost := 0.0
		for group_id: StringName in group_ids:
			var record := records[group_id] as Dictionary
			var reference_angle := _reference_angle(record, target_position)
			var best_index := 0
			var local_cost := INF
			for index: int in range(available.size()):
				var angular_cost := absf(wrapf(float(available[index]["angle"]) - reference_angle, -PI, PI))
				if angular_cost < local_cost:
					local_cost = angular_cost
					best_index = index
			mapping[group_id] = available.pop_at(best_index)
			cost += local_cost * local_cost
		if cost < best_cost:
			best_cost = cost
			best_mapping = mapping
	return best_mapping


func _reference_angle(record: Dictionary, target_position: Vector3) -> float:
	var assignment_value := record.get("assignment", {}) as Dictionary
	if bool(record.get("admitted", false)) and not assignment_value.is_empty():
		return float(assignment_value.get("angle", record["initial_angle"]))
	return _current_angle(record, target_position)


func _candidates(base_angle: float, count: int, radius: float, engage: bool, role: StringName, ring: int, stagger: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if count <= 0:
		return result
	for index: int in range(count):
		result.append({
			"angle": base_angle + (float(index) + stagger) * TAU / float(count),
			"radius": radius,
			"engage": engage,
			"role": role,
			"ring": ring,
			"slot": index,
		})
	return result


func _depth_candidates(base_angle: float, count: int, target_position: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if count <= 0:
		return result
	# Four parallel approach axes create genuine army depth. Additional groups
	# extend the columns away from combat instead of increasing a ring density.
	for index: int in range(count):
		var front_index := index % MAX_CONTACT_PHALANXES
		var angle := base_angle + float(front_index) * TAU / float(MAX_CONTACT_PHALANXES)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3.UP.cross(outward).normalized()
		var depth_rank := 0
		var depth := SUPPORT_DEPTH
		var lateral := 0.0
		var role := &"support"
		if index >= MAX_CONTACT_PHALANXES:
			var reserve_index := index - MAX_CONTACT_PHALANXES
			depth_rank = 1 + int(reserve_index / (MAX_CONTACT_PHALANXES * 2))
			depth = RESERVE_FIRST_DEPTH + float(depth_rank - 1) * RESERVE_DEPTH_STEP
			var side_band := int(reserve_index / MAX_CONTACT_PHALANXES) % 2
			lateral = -RESERVE_LATERAL_OFFSET if side_band == 0 else RESERVE_LATERAL_OFFSET
			role = &"reserve"
		var position := target_position + outward * depth + tangent * lateral
		result.append({
			"angle": angle,
			"radius": depth,
			"position": position,
			"facing": -outward,
			"engage": false,
			"role": role,
			"ring": depth_rank + 1,
			"slot": index,
		})
	return result


func _assign_nearest(group_ids: Array, candidates: Array[Dictionary], target_position: Vector3 = Vector3.ZERO) -> void:
	var available := candidates.duplicate(true)
	for raw_group_id: Variant in group_ids:
		var group_id := StringName(raw_group_id)
		var record := records[group_id] as Dictionary
		if available.is_empty():
			record["assignment"] = {}
			continue
		var best_index := 0
		var best_cost := INF
		var current_angle := _current_angle(record, target_position)
		var current_position := record["current_anchor"] as Vector3
		for index: int in range(available.size()):
			var candidate := available[index] as Dictionary
			var cost := absf(wrapf(float(candidate["angle"]) - current_angle, -PI, PI))
			if candidate.has("position"):
				cost = _planar_distance(current_position, candidate["position"] as Vector3)
			if cost < best_cost:
				best_cost = cost
				best_index = index
		record["assignment"] = available.pop_at(best_index)


func _effective_frontline_distance(record: Dictionary, target_position: Vector3) -> float:
	var distance := _planar_distance(record["current_anchor"] as Vector3, target_position)
	if bool(record.get("admitted", false)):
		distance = maxf(0.0, distance - FRONTLINE_SWAP_HYSTERESIS)
	return distance


func _target_position(group_ids: Array[StringName]) -> Vector3:
	if group_ids.is_empty():
		return Vector3.ZERO
	var record := records[group_ids[0]] as Dictionary
	var target := record.get("target") as Node3D
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	return focus_tracker.call("update_target", target) as Vector3


func _current_angle(record: Dictionary, target_position: Vector3) -> float:
	var from_target := (record["current_anchor"] as Vector3) - target_position
	from_target.y = 0.0
	if from_target.length_squared() < 0.001:
		return float(record["initial_angle"])
	return atan2(from_target.z, from_target.x)


static func _planar_direction(from: Vector3, to: Vector3, fallback: Vector3) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return fallback
	return direction.normalized()


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _is_remnant(record: Dictionary) -> bool:
	var member_count := int(record.get("member_count", 0))
	var original_count := maxi(1, int(record.get("original_count", member_count)))
	return member_count <= REMNANT_MAX_MEMBERS or member_count <= ceili(float(original_count) * 0.25)


func _front_route_assignment(group_id: StringName, record: Dictionary, mission: Dictionary, player: Vector3) -> Dictionary:
	var result := mission.duplicate()
	var current: Vector3 = record["current_anchor"]
	var goal: Vector3 = mission.get("position", current)
	var now := Time.get_ticks_msec()
	result["anchor_goal"] = current
	result["movement_phase"] = mission.get("mission", &"hold")
	if _planar_distance(current, goal) <= ORDER_GOAL_TOLERANCE:
		traffic.call("release", group_id)
		record["order"] = null
		return result
	var order: Variant = record.get("order")
	var permitted := not traffic.has_method("can_follow_route") or bool(traffic.call("can_follow_route", group_id))
	var needs_order := order == null or _planar_distance(order.final_goal, goal) > ORDER_REPLAN_DISTANCE or not permitted
	if needs_order and now >= int(record.get("retry_at", 0)):
		record["retry_at"] = now + 500 + int(record["registration_order"]) % 7 * 35
		var path: PackedVector3Array = traffic.call("request_route", group_id, current, goal, player,
			float(record["formation_width"]), 100 if bool(mission.get("engage", false)) else 30,
			float(record["formation_depth"]), record["forward"], record["capabilities"].body_height)
		if not path.is_empty():
			order = FormationOrder.new()
			order.final_goal = goal
			order.final_facing = mission.get("facing", record["forward"])
			order.path = path
			record["order"] = order
			record["order_revision"] = int(record["order_revision"]) + 1
			permitted = true
	if order == null or not permitted:
		result["movement_phase"] = &"waiting_corridor"
		return result
	if bool(order.call("advance_if_reached", current, ORDER_GOAL_TOLERANCE)):
		traffic.call("release", group_id)
		record["order"] = null
		return result
	var waypoint: Vector3 = order.call("current_waypoint")
	result["anchor_goal"] = waypoint
	result["movement_phase"] = &"march"
	if not bool(record.get("engaged", false)) and not bool(record.get("intrusion", false)):
		result["facing"] = _planar_direction(current, waypoint, record["forward"])
	return result

func constrain_front_rotation(group_id: StringName, current: Vector3, proposed: Vector3) -> Vector3:
	if not records.has(group_id) or not bool(records[group_id].get("persistent_fronts", false)):
		return proposed
	if occupancy.has_method("rotation_is_clear") and not bool(occupancy.call("rotation_is_clear", group_id, records[group_id]["current_anchor"], current, proposed)):
		return current
	return proposed
