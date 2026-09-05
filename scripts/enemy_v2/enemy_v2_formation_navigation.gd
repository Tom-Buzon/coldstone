extends RefCounted
class_name EnemyV2FormationNavigation

## One collective query per manoeuvre, using the world's existing navigation
## map. Clearance is checked for the formation, never inferred from the point
## path alone. World geometry lives on collision layer 1 in Forge.
const MAX_QUERIES_PER_REQUEST := 320
const SAMPLE_DISTANCE := 1.5
const MAX_SLOPE_COS := 0.72
const MAX_HEIGHT_STEP := 1.35
const MAX_PATH_LENGTH := 240.0

var _world_ref: WeakRef
var query_count: int = 0
var last_failure: StringName = &""
var last_failure_position := Vector3.ZERO
var _shape := BoxShape3D.new()
var _shape_query := PhysicsShapeQueryParameters3D.new()
var _ground_cache: Dictionary = {}
var _terrain_rids: Array[RID] = []
var _terrain_checked: Dictionary = {}
var _cache_until_msec: int = 0


func configure_world(world: Node3D) -> void:
	if world != null and is_instance_valid(world):
		if _world_ref != null and _world_ref.get_ref() != world:
			_ground_cache.clear()
			_terrain_rids.clear()
			_terrain_checked.clear()
		_world_ref = weakref(world)


func begin_request() -> void:
	query_count = 0
	if Time.get_ticks_msec() >= _cache_until_msec:
		_ground_cache.clear()
		_cache_until_msec = Time.get_ticks_msec() + 800


func navigation_path(start: Vector3, goal: Vector3) -> PackedVector3Array:
	var world := _world()
	if world == null:
		return PackedVector3Array()
	var map := world.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return PackedVector3Array()
	query_count += 1
	var result := NavigationServer3D.map_get_path(map, start, goal, true, 1)
	if result.size() < 2 or _flat(result[result.size() - 1] - goal).length() > 1.5:
		return PackedVector3Array()
	# The exact start and goal preserve the formation order's arrival contract.
	result[0] = start
	result[result.size() - 1] = goal
	return result


func path_is_clear(path: PackedVector3Array, width: float, depth: float, initial_forward: Vector3 = Vector3.ZERO, formation_height: float = 2.0) -> bool:
	last_failure = &"clear"
	var world := _world()
	if world == null:
		return true # Pure-data probes and maps without a configured world.
	if path.size() < 2:
		return false
	var space := world.get_world_3d().direct_space_state
	var total_distance := 0.0
	var previous_forward := initial_forward
	for index: int in range(path.size() - 1):
		var start := path[index]
		var finish := path[index + 1]
		var segment := _flat(finish - start)
		var length := segment.length()
		total_distance += length
		if total_distance > MAX_PATH_LENGTH:
			return _reject(&"path_too_long", start)
		if length <= 0.01:
			continue
		var forward := segment / length
		var right := Vector3.UP.cross(forward)
		var steps := maxi(1, ceili(length / SAMPLE_DISTANCE))
		var previous_ground := Vector3.ZERO
		for step: int in range(steps + 1):
			if query_count >= MAX_QUERIES_PER_REQUEST:
				return _reject(&"query_budget", start)
			var point := start.lerp(finish, float(step) / float(steps))
			var center_sample := _ground(space, point)
			if center_sample.is_empty():
				return _reject(&"ground", point)
			var grounded: Vector3 = center_sample["position"]
			if step == 0 and previous_forward.length_squared() > 0.001:
				if not _rotation_clear(space, grounded, previous_forward, forward, width, depth, formation_height):
					return _reject(&"rotation_obstacle", grounded)
			for side: float in [-0.5, 0.5]:
				var edge_sample := _ground(space, point + right * width * side)
				if edge_sample.is_empty() or absf(float((edge_sample["position"] as Vector3).y) - grounded.y) > maxf(MAX_HEIGHT_STEP, width * 0.5 * 0.7):
					return _reject(&"edge_support", point + right * width * side)
			if step > 0:
				var horizontal := _flat(grounded - previous_ground).length()
				if absf(grounded.y - previous_ground.y) > maxf(MAX_HEIGHT_STEP, horizontal * 0.7):
					return _reject(&"slope", grounded)
				if query_count + 2 > MAX_QUERIES_PER_REQUEST:
					return _reject(&"query_budget", grounded)
				_shape.size = Vector3(maxf(width, 0.5), maxf(0.5, formation_height - 0.45), maxf(depth, 0.5))
				_shape_query.shape = _shape
				_shape_query.exclude = _terrain_rids
				_shape_query.collision_mask = 1
				_shape_query.collide_with_areas = false
				_shape_query.transform = Transform3D(Basis.looking_at(forward), previous_ground + Vector3.UP * (formation_height + 0.45) * 0.5)
				_shape_query.motion = grounded - previous_ground
				query_count += 1
				# cast_motion ignores shapes overlapping at the start; test that
				# explicitly, otherwise a formation could leave through a wall.
				if not space.intersect_shape(_shape_query, 1).is_empty():
					return _reject(&"obstacle_start", previous_ground)
				query_count += 1
				var motion := space.cast_motion(_shape_query)
				if motion.size() >= 1 and motion[0] < 0.99:
					return _reject(&"obstacle_sweep", previous_ground)
			previous_ground = grounded
		previous_forward = forward
	return true


func _rotation_clear(space: PhysicsDirectSpaceState3D, ground: Vector3, old_forward: Vector3, new_forward: Vector3, width: float, depth: float, formation_height: float) -> bool:
	var first_angle := atan2(old_forward.x, old_forward.z)
	var delta_angle := wrapf(atan2(new_forward.x, new_forward.z) - first_angle, -PI, PI)
	if absf(delta_angle) < 0.02:
		return true
	var steps := maxi(1, ceili(absf(delta_angle) / (PI / 18.0)))
	var margin := Vector2(width, depth).length() * 0.5 * sin(absf(delta_angle) / float(steps) * 0.5)
	_shape.size = Vector3(maxf(width, 0.5) + margin * 2.0, maxf(0.5, formation_height - 0.45), maxf(depth, 0.5) + margin * 2.0)
	_shape_query.shape = _shape
	_shape_query.exclude = _terrain_rids
	_shape_query.collision_mask = 1
	_shape_query.collide_with_areas = false
	_shape_query.motion = Vector3.ZERO
	for index: int in range(steps + 1):
		if query_count >= MAX_QUERIES_PER_REQUEST:
			return false
		var angle := first_angle + delta_angle * float(index) / float(steps)
		var forward := Vector3(sin(angle), 0.0, cos(angle))
		_shape_query.transform = Transform3D(Basis.looking_at(forward), ground + Vector3.UP * (formation_height + 0.45) * 0.5)
		query_count += 1
		if not space.intersect_shape(_shape_query, 1).is_empty():
			return false
	return true

func _reject(reason: StringName, point: Vector3) -> bool:
	last_failure = reason
	last_failure_position = point
	return false

func _ground(space: PhysicsDirectSpaceState3D, point: Vector3) -> Dictionary:
	var key := Vector3i(roundi(point.x * 2.0), roundi(point.y), roundi(point.z * 2.0))
	if _ground_cache.has(key):
		return _ground_cache[key]
	if query_count >= MAX_QUERIES_PER_REQUEST:
		return {}
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point - Vector3.UP * 6.0, 1)
	ray.collide_with_areas = false
	query_count += 1
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		_register_sampled_terrain(hit)
	if not hit.is_empty() and (hit.get("normal", Vector3.UP) as Vector3).dot(Vector3.UP) < MAX_SLOPE_COS:
		hit = {}
	if _ground_cache.size() < 2048:
		_ground_cache[key] = hit
	return hit


func _register_sampled_terrain(hit: Dictionary) -> void:
	var collider := hit.get("collider") as CollisionObject3D
	if collider == null or _terrain_checked.has(collider.get_instance_id()):
		return
	_terrain_checked[collider.get_instance_id()] = true
	var owner_id := collider.shape_find_owner(int(hit.get("shape", 0)))
	var owner := collider.shape_owner_get_owner(owner_id) as CollisionShape3D
	if owner != null and owner.shape is HeightMapShape3D:
		# A formation follows the sampled relief with individual feet. Its flat
		# collective box must not interpret its own uphill wing as a wall. Keep
		# heightmaps in all support/slope rays, and exclude only those maps from
		# volume sweeps. Other geometry, including ceilings, stays solid.
		_terrain_rids.append(collider.get_rid())

func _world() -> Node3D:
	if _world_ref == null:
		return null
	var world := _world_ref.get_ref() as Node3D
	return world if world != null and world.is_inside_tree() else null


static func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)
