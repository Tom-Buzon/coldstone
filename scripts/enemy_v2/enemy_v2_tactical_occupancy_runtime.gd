extends RefCounted
class_name EnemyV2TacticalOccupancyRuntime

const Footprint = preload("res://scripts/enemy_v2/enemy_v2_formation_footprint.gd")
const CorridorReservation = preload("res://scripts/enemy_v2/enemy_v2_corridor_reservation.gd")

const CELL_SIZE := 3.0
const CORRIDOR_TTL_MSEC := 12000
const CORRIDOR_HORIZON := 18.0
const STALLED_MSEC := 3600
const REFRESH_MSEC := 220
const PROGRESS_DISTANCE := 0.25
const YIELD_MSEC := 700

var footprints: Dictionary = {}
var footprint_cells: Dictionary = {}
var footprint_owners: Dictionary = {}
var reservations: Dictionary = {}
var corridor_owners: Dictionary = {}
var route_states: Dictionary = {}
var yield_until: Dictionary = {}
var last_block_reason: StringName = &""
var last_block_owner: StringName = &""


func update_footprint(group_id: StringName, center: Vector3, forward: Vector3, width: float, depth: float) -> void:
	if footprints.has(group_id):
		var old: RefCounted = footprints[group_id]
		if (old.center as Vector3).is_equal_approx(center) and (old.forward as Vector3).is_equal_approx(forward) and is_equal_approx(old.width,width) and is_equal_approx(old.depth,depth):
			update_progress(group_id,center)
			return
	_release_footprint_cells(group_id)
	var footprint: RefCounted = Footprint.new().configure(group_id, center, forward, width, depth)
	var cells: Array[Vector2i] = footprint.call("covered_cells", CELL_SIZE, 0.20)
	footprints[group_id] = footprint
	footprint_cells[group_id] = cells
	for cell: Vector2i in cells:
		var owners := footprint_owners.get(cell, []) as Array
		if not owners.has(group_id):
			owners.append(group_id)
		footprint_owners[cell] = owners
	update_progress(group_id, center)


func remove_group(group_id: StringName) -> void:
	release_corridor(group_id)
	_release_footprint_cells(group_id)
	footprints.erase(group_id)
	route_states.erase(group_id)
	yield_until.erase(group_id)


## Only the next horizon is exclusive. Ownership is replaced AFTER all checks,
## so a failed replan leaves the old route and its ownership intact.
func try_reserve_corridor(group_id: StringName, path: PackedVector3Array, formation_width: float, priority: int = 0, now_msec: int = -1, formation_depth: float = -1.0, yield_owners: Array[StringName] = []) -> RefCounted:
	if path.size() < 2:
		return null
	var now := _now(now_msec)
	_prune_expired(now)
	if now < int(yield_until.get(group_id, 0)):
		return null
	var depth := formation_depth
	if depth < 0.0:
		depth = float(footprints[group_id].depth) if footprints.has(group_id) else 2.0
	var horizon := _horizon_path(path, path[0], 0)
	var cells := _corridor_cells(horizon, formation_width, depth, _group_forward(group_id))
	if not _cells_available(group_id, cells, horizon, formation_width, depth, yield_owners):
		if not reservations.has(group_id):
			route_states[group_id] = &"waiting_corridor"
		return null
	for owner: StringName in yield_owners:
		if owner != group_id and reservations.has(owner):
			release_corridor(owner)
			route_states[owner] = &"yielding"
			yield_until[owner] = now + YIELD_MSEC + absi(hash(owner)) % 350
	var reservation: RefCounted = CorridorReservation.new()
	reservation.owner_id = group_id
	reservation.issued_at_msec = now
	reservation.path = path
	reservation.final_goal = path[path.size() - 1]
	reservation.priority = priority
	reservation.formation_width = formation_width
	reservation.formation_depth = depth
	reservation.expires_at_msec = now + CORRIDOR_TTL_MSEC
	reservation.last_progress_at_msec = now
	reservation.last_refresh_at_msec = now
	reservation.last_progress_position = path[0]
	_replace_cells(group_id, reservation, cells)
	reservations[group_id] = reservation
	route_states[group_id] = &"moving"
	return reservation


## A heartbeat alone is not progress. Live but stuck groups yield their future
## corridor; their actual footprint always remains occupied.
func update_progress(group_id: StringName, position: Vector3, now_msec: int = -1) -> void:
	if not reservations.has(group_id):
		return
	var now := _now(now_msec)
	var reservation: Variant = reservations[group_id]
	if now - int(reservation.last_refresh_at_msec) < REFRESH_MSEC:
		return
	reservation.last_refresh_at_msec = now
	var path: PackedVector3Array = reservation.path
	var index: int = reservation.segment_index
	while index < path.size() - 2:
		var segment := _flat(path[index + 1] - path[index])
		var offset := _flat(position - path[index + 1])
		if _flat(position - path[index + 1]).length() > 1.0 and offset.dot(segment) < 0.0:
			break
		index += 1
	reservation.segment_index = index
	var moved := _flat(position - (reservation.last_progress_position as Vector3))
	var remaining := _flat(path[mini(index + 1, path.size() - 1)] - position)
	var old_remaining := _flat(path[mini(index + 1, path.size() - 1)] - (reservation.last_progress_position as Vector3))
	if moved.length() >= PROGRESS_DISTANCE and remaining.length() < old_remaining.length() - PROGRESS_DISTANCE * 0.25:
		reservation.last_progress_position = position
		reservation.last_progress_at_msec = now
		reservation.expires_at_msec = now + CORRIDOR_TTL_MSEC
	if now - int(reservation.last_progress_at_msec) >= STALLED_MSEC:
		release_corridor(group_id)
		route_states[group_id] = &"yielding"
		yield_until[group_id] = now + YIELD_MSEC + absi(hash(group_id)) % 350
		return
	if _flat(position - reservation.final_goal).length() <= 0.75:
		release_corridor(group_id)
		route_states[group_id] = &"arrived"
		return
	var horizon := _horizon_path(path, position, index)
	var cells := _corridor_cells(horizon, float(reservation.formation_width), float(reservation.formation_depth), _group_forward(group_id))
	if _cells_available(group_id, cells, horizon, float(reservation.formation_width), float(reservation.formation_depth)):
		_replace_cells(group_id, reservation, cells)
		reservation.status = &"moving"
		route_states[group_id] = &"moving"
	else:
		# Free passed segments even when the next segment cannot yet be booked.
		# Retain only already-owned cells within the new horizon, then wait.
		var retained: Array[Vector2i] = []
		for cell: Vector2i in cells:
			if StringName(corridor_owners.get(cell, &"")) == group_id:
				retained.append(cell)
		_replace_cells(group_id, reservation, retained)
		reservation.status = &"waiting_corridor"
		route_states[group_id] = &"waiting_corridor"


func corridor_is_available(group_id: StringName, path: PackedVector3Array, width: float, depth: float, ignored_owners: Array[StringName] = []) -> bool:
	if path.size() < 2:
		return false
	var horizon := _horizon_path(path, path[0], 0)
	return _cells_available(group_id, _corridor_cells(horizon, width, depth, _group_forward(group_id)), horizon, width, depth, ignored_owners)

## Read-only conflict discovery for age-based scheduling. Footprints are never
## yieldable; only future leases can be atomically handed to another group.
func corridor_blocking_owners(group_id: StringName, path: PackedVector3Array, width: float, depth: float) -> Array[StringName]:
	var result: Array[StringName] = []
	if path.size() < 2:
		return result
	var horizon := _horizon_path(path, path[0], 0)
	for cell: Vector2i in _corridor_cells(horizon, width, depth, _group_forward(group_id)):
		var owner := StringName(corridor_owners.get(cell, &""))
		if not owner.is_empty() and owner != group_id and not result.has(owner):
			result.append(owner)
	return result

func release_corridor(group_id: StringName) -> void:
	if reservations.has(group_id):
		var reservation: Variant = reservations[group_id]
		for cell: Vector2i in reservation.cells:
			if StringName(corridor_owners.get(cell, &"")) == group_id:
				corridor_owners.erase(cell)
		reservations.erase(group_id)
	route_states[group_id] = &"idle"


func active_corridor_count(now_msec: int = -1) -> int:
	_prune_expired(now_msec)
	return reservations.size()


func has_corridor(group_id: StringName, now_msec: int = -1) -> bool:
	_prune_expired(now_msec)
	return reservations.has(group_id)


func get_route_status(group_id: StringName, now_msec: int = -1) -> StringName:
	_prune_expired(now_msec)
	return StringName(route_states.get(group_id, &"idle"))


func touch_corridor(group_id: StringName, now_msec: int = -1) -> void:
	if footprints.has(group_id):
		update_progress(group_id, footprints[group_id].center, now_msec)
	_prune_expired(now_msec)


## Spatial hash bounds the neighborhood by physical extent; safety checks never
## truncate a crowded cell's owners. No all-army scan in the movement loop.
func groups_along_segment(start: Vector3, finish: Vector3) -> Array[StringName]:
	# Footprints already index every covered cell. Visit a narrow ray strip,
	# rather than a disc whose area grows with the square of shooting range.
	var found: Dictionary = {}
	var visited: Dictionary = {}
	var steps := maxi(1,ceili(_flat(finish-start).length()/CELL_SIZE))
	for step in range(steps+1):
		var point := start.lerp(finish,float(step)/float(steps))
		var cell := Vector2i(floori(point.x/CELL_SIZE),floori(point.z/CELL_SIZE))
		for x in range(-1,2):
			for z in range(-1,2):
				var key := cell+Vector2i(x,z)
				if visited.has(key): continue
				visited[key] = true
				for id: StringName in footprint_owners.get(key,[]): found[id] = true
	var result: Array[StringName] = []
	for id: StringName in found: result.append(id)
	return result


func nearby_group_ids(center: Vector3, radius: float) -> Array[StringName]:
	var unique: Dictionary = {}
	var minimum := Vector2i(floori((center.x - radius) / CELL_SIZE), floori((center.z - radius) / CELL_SIZE))
	var maximum := Vector2i(floori((center.x + radius) / CELL_SIZE), floori((center.z + radius) / CELL_SIZE))
	for x: int in range(minimum.x, maximum.x + 1):
		for z: int in range(minimum.y, maximum.y + 1):
			for raw_owner: Variant in footprint_owners.get(Vector2i(x, z), []):
				unique[StringName(raw_owner)] = true
	var result: Array[StringName] = []
	for raw_owner: Variant in unique:
		result.append(StringName(raw_owner))
	return result


func constrain_motion(group_id: StringName, current: Vector3, proposed: Vector3, from_forward: Vector3, to_forward: Vector3) -> Vector3:
	if not footprints.has(group_id):
		return proposed
	return proposed if _motion_is_clear(group_id, current, proposed, from_forward, to_forward) else current


func rotation_is_clear(group_id: StringName, center: Vector3, from_forward: Vector3, to_forward: Vector3) -> bool:
	return not footprints.has(group_id) or _motion_is_clear(group_id, center, center, from_forward, to_forward)


## Minimal separating-axis correction, bounded by the caller's movement budget.
## Existing overlap may decrease, but recovery cannot enter a new neighbor.
func resolve_overlap(group_id: StringName, current: Vector3, max_step: float) -> Vector3:
	if not footprints.has(group_id) or max_step <= 0.0:
		return current
	var original: Variant = footprints[group_id]
	var self_shape: RefCounted = Footprint.new().configure(group_id, current, original.forward, original.width, original.depth)
	var radius := Vector2(original.width, original.depth).length() * 0.5
	var correction := Vector3.ZERO
	for other_id: StringName in nearby_group_ids(current, radius):
		if other_id == group_id:
			continue
		var other: Variant = footprints[other_id]
		if not self_shape.overlaps(other):
			continue
		var self_forward: Vector3 = original.forward
		var other_forward: Vector3 = other.forward
		var self_right := Vector3.UP.cross(self_forward)
		var other_right := Vector3.UP.cross(other_forward)
		var offset: Vector3 = current - other.center
		var smallest := INF
		var escape := Vector3.ZERO
		for axis: Vector3 in [self_right, self_forward, other_right, other_forward]:
			var self_radius := absf(axis.dot(self_right)) * float(original.width) * 0.5 + absf(axis.dot(self_forward)) * float(original.depth) * 0.5
			var other_radius := absf(axis.dot(other_right)) * float(other.width) * 0.5 + absf(axis.dot(other_forward)) * float(other.depth) * 0.5
			var separation := self_radius + other_radius - absf(offset.dot(axis))
			if separation < smallest:
				smallest = separation
				var side := signf(offset.dot(axis))
				if is_zero_approx(side):
					side = 1.0 if String(group_id) < String(other_id) else -1.0
				escape = axis * side * (separation + 0.15)
		correction += escape
	if correction.length_squared() < 0.000001:
		return current
	var proposed := current + correction.limit_length(minf(max_step, 2.0))
	return constrain_motion(group_id, current, proposed, original.forward, original.forward)

func overlap_count() -> int:
	var count := 0
	for raw_id: Variant in footprints:
		var group_id := StringName(raw_id)
		var footprint: Variant = footprints[group_id]
		var radius := Vector2(footprint.width, footprint.depth).length() * 0.5
		for other_id: StringName in nearby_group_ids(footprint.center, radius):
			if String(group_id) < String(other_id) and footprint.overlaps(footprints[other_id]):
				count += 1
	return count


func _motion_is_clear(group_id: StringName, current: Vector3, proposed: Vector3, from_forward: Vector3, to_forward: Vector3) -> bool:
	var original: Variant = footprints[group_id]
	var width: float = original.width
	var depth: float = original.depth
	var radius := Vector2(width, depth).length() * 0.5
	var distance := _flat(proposed - current).length()
	# Excessive one-tick moves are rejected rather than doing unbounded sampling.
	if distance > 12.0:
		return false
	var first_angle := atan2(from_forward.x, from_forward.z)
	var angle_delta := wrapf(atan2(to_forward.x, to_forward.z) - first_angle, -PI, PI)
	var steps := maxi(1, maxi(ceili(distance / 0.75), ceili(absf(angle_delta) / (PI / 24.0))))
	var sweep_margin := radius * sin(absf(angle_delta) / float(steps) * 0.5)
	var neighbors := nearby_group_ids((current + proposed) * 0.5, radius + distance * 0.5 + 0.5)
	var before: RefCounted = Footprint.new().configure(group_id, current, from_forward, width, depth)
	var sample: RefCounted = Footprint.new()
	for other_id: StringName in neighbors:
		if other_id == group_id:
			continue
		var other: RefCounted = footprints[other_id]
		var old_depth: float = before.call("overlap_depth", other)
		for step: int in range(1, steps + 1):
			var ratio := float(step) / float(steps)
			var angle := first_angle + angle_delta * ratio
			sample.call("configure", group_id, current.lerp(proposed, ratio), Vector3(sin(angle), 0.0, cos(angle)), width, depth)
			var penetration: float = sample.call("overlap_depth", other, sweep_margin)
			var separating := _flat(current.lerp(proposed, ratio) - (other.get("center") as Vector3)).length_squared() > _flat(current - (other.get("center") as Vector3)).length_squared() + 0.000001
			if penetration > 0.0 and (old_depth <= 0.0 or penetration > old_depth + 0.0001 or (not separating and penetration >= old_depth - 0.0001)):
				return false
	return true


func _cells_available(group_id: StringName, cells: Array[Vector2i], path: PackedVector3Array, width: float, depth: float, ignored_owners: Array[StringName] = []) -> bool:
	last_block_reason = &""
	last_block_owner = &""
	var neighbors: Dictionary = {}
	for cell: Vector2i in cells:
		for raw_owner: Variant in footprint_owners.get(cell, []):
			if StringName(raw_owner) != group_id:
				neighbors[StringName(raw_owner)] = true
		var corridor_owner := StringName(corridor_owners.get(cell, &""))
		if not corridor_owner.is_empty() and corridor_owner != group_id and not ignored_owners.has(corridor_owner):
			last_block_reason = &"corridor"
			last_block_owner = corridor_owner
			return false
	# Cells are only a broad phase for occupied formations. Parallel wings with
	# real clearance must not be rejected just because they share a grid cell.
	for raw_owner: Variant in neighbors:
		if _path_overlaps_footprint(group_id, path, width, depth, footprints[raw_owner]):
			last_block_reason = &"footprint"
			last_block_owner = StringName(raw_owner)
			return false
	return true


func _path_overlaps_footprint(group_id: StringName, path: PackedVector3Array, width: float, depth: float, other: RefCounted) -> bool:
	var previous_forward: Vector3 = footprints[group_id].forward if footprints.has(group_id) else Vector3.ZERO
	var sample: RefCounted = Footprint.new()
	for index: int in range(path.size() - 1):
		var segment := _flat(path[index + 1] - path[index])
		if segment.length_squared() < 0.0001:
			continue
		var forward := segment.normalized()
		# Sweeping an oriented box along its forward axis is exactly one longer
		# box; no per-metre allocation or collision sampling is necessary.
		sample.call("configure", group_id, (path[index] + path[index + 1]) * 0.5, forward, width, depth + segment.length())
		if sample.call("overlaps", other, 0.15):
			return true
		if previous_forward.length_squared() > 0.001:
			var first_angle := atan2(previous_forward.x, previous_forward.z)
			var angle_delta := wrapf(atan2(forward.x, forward.z) - first_angle, -PI, PI)
			var steps := maxi(1, ceili(absf(angle_delta) / (PI / 24.0)))
			var margin := Vector2(width, depth).length() * 0.5 * sin(absf(angle_delta) / float(steps) * 0.5)
			for step: int in range(steps + 1):
				var angle := first_angle + angle_delta * float(step) / float(steps)
				sample.call("configure", group_id, path[index], Vector3(sin(angle), 0.0, cos(angle)), width, depth)
				if sample.call("overlaps", other, margin + 0.15):
					return true
		previous_forward = forward
	return false

func _replace_cells(group_id: StringName, reservation: RefCounted, cells: Array[Vector2i]) -> void:
	if reservations.has(group_id):
		for cell: Vector2i in reservations[group_id].cells:
			if StringName(corridor_owners.get(cell, &"")) == group_id:
				corridor_owners.erase(cell)
	reservation.set("cells", cells)
	for cell: Vector2i in cells:
		corridor_owners[cell] = group_id


func _release_footprint_cells(group_id: StringName) -> void:
	for cell: Vector2i in footprint_cells.get(group_id, []):
		var owners := footprint_owners.get(cell, []) as Array
		owners.erase(group_id)
		if owners.is_empty():
			footprint_owners.erase(cell)
		else:
			footprint_owners[cell] = owners
	footprint_cells.erase(group_id)


func _prune_expired(now_msec: int = -1) -> void:
	var now := _now(now_msec)
	for raw_id: Variant in reservations.keys():
		var group_id := StringName(raw_id)
		var reservation: Variant = reservations[group_id]
		if not reservation.is_active(now) or now - int(reservation.last_progress_at_msec) >= STALLED_MSEC:
			release_corridor(group_id)
			route_states[group_id] = &"yielding"
			yield_until[group_id] = now + YIELD_MSEC + absi(hash(group_id)) % 350


func _horizon_path(path: PackedVector3Array, position: Vector3, segment_index: int) -> PackedVector3Array:
	var result := PackedVector3Array([position])
	var available := CORRIDOR_HORIZON
	var previous := position
	for index: int in range(segment_index + 1, path.size()):
		var distance := _flat(path[index] - previous).length()
		if distance > available:
			result.append(previous.lerp(path[index], available / maxf(distance, 0.001)))
			break
		result.append(path[index])
		available -= distance
		previous = path[index]
	return result


func _corridor_cells(path: PackedVector3Array, formation_width: float, formation_depth: float = 2.0, initial_forward: Vector3 = Vector3.ZERO) -> Array[Vector2i]:
	var unique: Dictionary = {}
	var sample: RefCounted = Footprint.new()
	var previous_forward := initial_forward
	for index: int in range(path.size() - 1):
		var start := path[index]
		var finish := path[index + 1]
		var segment := _flat(finish - start)
		if segment.length_squared() < 0.0001:
			continue
		var forward := segment.normalized()
		sample.call("configure", &"", (start + finish) * 0.5, forward, formation_width, formation_depth + segment.length())
		for cell: Vector2i in sample.call("covered_cells", CELL_SIZE, 0.15):
			unique[cell] = true
		if previous_forward.length_squared() > 0.001:
			var first_angle := atan2(previous_forward.x, previous_forward.z)
			var angle_delta := wrapf(atan2(forward.x, forward.z) - first_angle, -PI, PI)
			var steps := maxi(1, ceili(absf(angle_delta) / (PI / 12.0)))
			var margin := Vector2(formation_width, formation_depth).length() * 0.5 * sin(absf(angle_delta) / float(steps) * 0.5)
			for step: int in range(steps + 1):
				var angle := first_angle + angle_delta * float(step) / float(steps)
				sample.call("configure", &"", start, Vector3(sin(angle), 0.0, cos(angle)), formation_width, formation_depth)
				for cell: Vector2i in sample.call("covered_cells", CELL_SIZE, margin + 0.15):
					unique[cell] = true
		previous_forward = forward
	var result: Array[Vector2i] = []
	for raw_cell: Variant in unique:
		result.append(Vector2i(raw_cell))
	return result


func _group_forward(group_id: StringName) -> Vector3:
	return footprints[group_id].forward if footprints.has(group_id) else Vector3.ZERO

static func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


static func _now(value: int) -> int:
	return Time.get_ticks_msec() if value < 0 else value
