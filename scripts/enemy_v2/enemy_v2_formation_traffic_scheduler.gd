extends RefCounted
class_name EnemyV2FormationTrafficScheduler

const OccupancyRuntime = preload("res://scripts/enemy_v2/enemy_v2_tactical_occupancy_runtime.gd")
const FormationNavigation = preload("res://scripts/enemy_v2/enemy_v2_formation_navigation.gd")

const MAX_ACTIVE_CORRIDORS := 32
const MAX_LOCAL_CORRIDORS := 8
const LOCAL_TRAFFIC_RADIUS := 30.0
const MIN_FAIR_LEASE_MSEC := 4000
const FAIR_WAIT_MSEC := 1800
const MAX_SOLVES_PER_FRAME := 2
const FRAME_SOLVE_BUDGET_USEC := 2000
const OUTER_CLEARANCE := 7.0
const ARC_STEP_RADIANS := PI / 8.0
const MAX_ROUTE_CANDIDATES := 6
const RETRY_BASE_MSEC := 400
const RETRY_MAX_MSEC := 2200

var occupancy: RefCounted
var navigation: RefCounted = FormationNavigation.new()
var _retry_after: Dictionary = {}
var _failures: Dictionary = {}
var _retry_goals: Dictionary = {}
var _wait_started: Dictionary = {}
var _capacity_yield: Array[StringName] = []
var diagnostics: Dictionary = {}
var rejection_counts: Dictionary = {}
var _request_started_usec: int = 0
var _solve_frame: int = -1
var _solves_this_frame: int = 0
var _frame_spent_usec: int = 0


func _init(occupancy_value: RefCounted = null) -> void:
	occupancy = occupancy_value if occupancy_value != null else OccupancyRuntime.new()


func configure_world(world: Node3D) -> void:
	navigation.call("configure_world", world)


func request_route(group_id: StringName, start: Vector3, goal: Vector3, focus: Vector3, formation_width: float, priority: int = 0, formation_depth: float = -1.0, forward: Vector3 = Vector3.ZERO, formation_height: float = 2.0, now_msec: int = -1) -> PackedVector3Array:
	var now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	if _planar_distance(start, goal) <= 0.75:
		release(group_id)
		return PackedVector3Array([goal])
	var has_existing: bool = occupancy.call("has_corridor", group_id, now)
	if has_existing:
		var existing: Variant = occupancy.get("reservations")[group_id]
		if _planar_distance(existing.final_goal, goal) <= 1.0:
			return existing.path if existing.status == &"moving" else PackedVector3Array()
	var same_goal := _retry_goals.has(group_id) and _planar_distance(_retry_goals[group_id], goal) <= 2.0
	if same_goal and now < int(_retry_after.get(group_id, 0)):
		return PackedVector3Array()
	var frame := Engine.get_physics_frames() if now_msec < 0 else now_msec
	if frame != _solve_frame:
		_solve_frame = frame
		_solves_this_frame = 0
		_frame_spent_usec = 0
	if _solves_this_frame >= MAX_SOLVES_PER_FRAME or _frame_spent_usec >= FRAME_SOLVE_BUDGET_USEC:
		return PackedVector3Array()
	var depth := formation_depth
	if depth < 0.0:
		var footprints: Dictionary = occupancy.get("footprints")
		depth = float(footprints[group_id].depth) if footprints.has(group_id) else 2.0
	if diagnostics.size() >= 128 and not diagnostics.has(group_id):
		diagnostics.erase(diagnostics.keys()[0])
	_solves_this_frame += 1
	_request_started_usec = Time.get_ticks_usec()
	diagnostics[group_id] = {"start": str(start), "goal": str(goal), "rejections": []}
	navigation.call("begin_request")
	if not _wait_started.has(group_id):
		_wait_started[group_id] = now
	_capacity_yield.clear()
	if not has_existing and not _capacity_available(group_id, start, priority, now):
		_note_failure(group_id, goal, now)
		return PackedVector3Array()
	var candidates: Array[PackedVector3Array] = []
	# Routes are world-space manoeuvres. The tactical director controls whether
	# to intercept; there is no mandatory orbit around the player's position.
	var direct := PackedVector3Array([start, goal])
	if _try_candidate(group_id, direct, formation_width, depth, forward, formation_height, priority, now):
		return direct
	# Make safe progress toward contact before reserving a large lateral detour.
	# Every prefix still passes occupancy and terrain checks.
	if _planar_distance(start,goal)>3.0:
		var prefix := PackedVector3Array([start,start.move_toward(goal,minf(4.0,_planar_distance(start,goal)*0.5))])
		if _try_candidate(group_id,prefix,formation_width,depth,forward,formation_height,priority,now): return prefix
	var nav_path: PackedVector3Array = navigation.call("navigation_path", start, goal)
	if nav_path.size() > 2:
		candidates.append(nav_path)
	var segment := goal - start
	segment.y = 0.0
	var side := Vector3.UP.cross(segment.normalized())
	var clearance := formation_width * 0.5 + OUTER_CLEARANCE
	for sign_value: float in [1.0, -1.0]:
		# Parallel local lanes are much shorter than orbiting the entire army.
		candidates.append(PackedVector3Array([start, start + side * clearance * sign_value, goal + side * clearance * sign_value, goal]))
	# Keep exterior detours as last-resort options for a genuinely occupied
	# front, subject to terrain clearance and the same exclusive horizon.
	candidates.append(_outer_route(start, goal, focus, formation_width, 1.0))
	candidates.append(_outer_route(start, goal, focus, formation_width, -1.0))
	candidates.sort_custom(func(a: PackedVector3Array, b: PackedVector3Array) -> bool:
		return _path_length(a) < _path_length(b)
	)
	for index: int in range(mini(MAX_ROUTE_CANDIDATES, candidates.size())):
		var path := candidates[index]
		if _try_candidate(group_id, path, formation_width, depth, forward, formation_height, priority, now):
			return path
	_note_failure(group_id, goal, now)
	return PackedVector3Array()


func _try_candidate(group_id: StringName, path: PackedVector3Array, width: float, depth: float, forward: Vector3, height: float, priority: int, now: int) -> bool:
	# Reject occupied corridors before spending any terrain queries. An open
	# direct route also avoids a navmesh query entirely.
	var yield_owners: Array[StringName] = _capacity_yield.duplicate()
	var available: bool = occupancy.call("corridor_is_available", group_id, path, width, depth, yield_owners)
	if not available and StringName(occupancy.get("last_block_reason")) == &"corridor" and now - int(_wait_started.get(group_id, now)) >= FAIR_WAIT_MSEC:
		var blockers: Array[StringName] = occupancy.call("corridor_blocking_owners", group_id, path, width, depth)
		var previous_count := yield_owners.size()
		for blocker: StringName in blockers:
			if not yield_owners.has(blocker) and _lease_can_yield(group_id, blocker, priority, now) and yield_owners.size() < 2:
				yield_owners.append(blocker)
		if yield_owners.size() > previous_count:
			available = occupancy.call("corridor_is_available", group_id, path, width, depth, yield_owners)
	if not available:
		_record_rejection(group_id, StringName(occupancy.get("last_block_reason")), String(occupancy.get("last_block_owner")))
		return false
	if not bool(navigation.call("path_is_clear", path, width, depth, forward, height)):
		_record_rejection(group_id, StringName(navigation.get("last_failure")), str(navigation.get("last_failure_position")))
		return false
	if occupancy.call("try_reserve_corridor", group_id, path, width, priority, now, depth, yield_owners) == null:
		return false
	_retry_after.erase(group_id)
	_failures.erase(group_id)
	_retry_goals.erase(group_id)
	_wait_started.erase(group_id)
	diagnostics[group_id]["yielded_owners"] = yield_owners
	diagnostics[group_id]["accepted"] = true
	diagnostics[group_id]["cost_usec"] = Time.get_ticks_usec() - _request_started_usec
	diagnostics[group_id]["queries"] = navigation.get("query_count")
	_frame_spent_usec += Time.get_ticks_usec() - _request_started_usec
	return true

func _capacity_available(group_id: StringName, start: Vector3, priority: int, now: int) -> bool:
	var total: int = occupancy.call("active_corridor_count", now)
	var leases: Dictionary = occupancy.get("reservations")
	var local: Array[StringName] = []
	for raw_owner: Variant in leases:
		var lease: Variant = leases[raw_owner]
		if _planar_distance(lease.last_progress_position, start) <= LOCAL_TRAFFIC_RADIUS:
			local.append(StringName(raw_owner))
	if total < MAX_ACTIVE_CORRIDORS and local.size() < MAX_LOCAL_CORRIDORS:
		return true
	var candidates: Array[StringName] = local
	if total >= MAX_ACTIVE_CORRIDORS and local.size() < MAX_LOCAL_CORRIDORS:
		candidates = []
		for raw_owner: Variant in leases:
			candidates.append(StringName(raw_owner))
	var oldest := &""
	var oldest_time := now
	for owner: StringName in candidates:
		if _lease_can_yield(group_id, owner, priority, now) and int(leases[owner].issued_at_msec) < oldest_time:
			oldest = owner
			oldest_time = int(leases[owner].issued_at_msec)
	if not oldest.is_empty():
		_capacity_yield.append(oldest)
		return true
	_record_rejection(group_id, &"capacity_local" if local.size() >= MAX_LOCAL_CORRIDORS else &"capacity_global", "local=%d total=%d" % [local.size(),total])
	return false


func _lease_can_yield(waiter: StringName, owner: StringName, priority: int, now: int) -> bool:
	var waited := now - int(_wait_started.get(waiter, now))
	if waited < FAIR_WAIT_MSEC:
		return false
	var leases: Dictionary = occupancy.get("reservations")
	if not leases.has(owner):
		return false
	var lease: Variant = leases[owner]
	if now - int(lease.issued_at_msec) < MIN_FAIR_LEASE_MSEC:
		return false
	# Age eventually outweighs role priority. A progressing but very long route
	# cannot monopolize a local gate forever; current bodies are never evicted.
	return priority + mini(1000, int(waited / 40)) >= int(lease.priority)

func _record_rejection(group_id: StringName, reason: StringName, detail: String) -> void:
	rejection_counts[reason] = int(rejection_counts.get(reason, 0)) + 1
	(diagnostics[group_id]["rejections"] as Array).append({"reason": reason, "detail": detail})
	diagnostics[group_id]["accepted"] = false
	diagnostics[group_id]["cost_usec"] = Time.get_ticks_usec() - _request_started_usec
	diagnostics[group_id]["queries"] = navigation.get("query_count")

func release(group_id: StringName) -> void:
	_wait_started.erase(group_id)
	occupancy.call("release_corridor", group_id)
	_retry_after.erase(group_id)
	_failures.erase(group_id)
	_retry_goals.erase(group_id)


func touch(group_id: StringName) -> void:
	occupancy.call("touch_corridor", group_id)


func get_route_status(group_id: StringName) -> StringName:
	return StringName(occupancy.call("get_route_status", group_id))


func can_follow_route(group_id: StringName) -> bool:
	return get_route_status(group_id) == &"moving"


func _note_failure(group_id: StringName, goal: Vector3, now: int) -> void:
	_frame_spent_usec += Time.get_ticks_usec() - _request_started_usec
	var attempts := mini(6, int(_failures.get(group_id, 0)) + 1)
	_failures[group_id] = attempts
	_retry_goals[group_id] = goal
	_retry_after[group_id] = now + mini(RETRY_MAX_MSEC, RETRY_BASE_MSEC * attempts) + absi(hash(group_id)) % 180


func _outer_route(start: Vector3, goal: Vector3, focus: Vector3, formation_width: float, direction_sign: float) -> PackedVector3Array:
	var start_offset := start - focus
	var goal_offset := goal - focus
	start_offset.y = 0.0
	goal_offset.y = 0.0
	var start_angle := atan2(start_offset.z, start_offset.x)
	var goal_angle := atan2(goal_offset.z, goal_offset.x)
	var safe_radius := maxf(start_offset.length(), goal_offset.length()) + OUTER_CLEARANCE + formation_width * 0.5
	var signed_delta := wrapf(goal_angle - start_angle, -PI, PI)
	if direction_sign > 0.0 and signed_delta < 0.0:
		signed_delta += TAU
	elif direction_sign < 0.0 and signed_delta > 0.0:
		signed_delta -= TAU
	var arc_steps := maxi(1, ceili(absf(signed_delta) / ARC_STEP_RADIANS))
	var result := PackedVector3Array([start])
	for step: int in range(arc_steps + 1):
		var angle := start_angle + signed_delta * float(step) / float(arc_steps)
		var point := focus + Vector3(cos(angle), 0.0, sin(angle)) * safe_radius
		point.y = start.y
		result.append(point)
	result.append(goal)
	return result


static func _path_length(path: PackedVector3Array) -> float:
	var result := 0.0
	for index: int in range(path.size() - 1):
		result += _planar_distance(path[index], path[index + 1])
	return result


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
