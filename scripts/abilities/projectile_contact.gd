extends RefCounted

# Query animated anatomy directly, including when crowd LOD removes physics shapes.
# Bone reads do not re-enable distant actors in the physics broad phase.
static func anatomy_for(target: Node3D) -> Variant:
	var health: Variant = target.get("health_component")
	return health.get("anatomy") if health != null else target.get("anatomy")

static func anatomy_hit(target: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var anatomy: Variant = anatomy_for(target)
	if anatomy == null or not is_instance_valid(anatomy): return {}
	var nearest := from.distance_to(to) + 0.001
	var result := {}
	var priority := -1.0
	var ray := (to - from).normalized()
	for zone: StringName in anatomy.zone_runtime:
		var data: Dictionary = anatomy.zone_runtime[zone]
		if data.get("disabled", false): continue
		var a: Vector3 = anatomy._bone_world_position(int(data.bone_a))
		var b: Vector3 = anatomy._bone_world_position(int(data.bone_b)) if int(data.bone_b) >= 0 else a
		var radius: float = float(data.radius) * anatomy._world_radius_scale()
		var distance := _capsule(from, ray, a, b, radius)
		var rank: float = float(data.get("priority", 0.0))
		# Large torso capsules overlap neck/head on giants. Prefer the small
		# authored zone when their entry surfaces overlap, as melee contacts do.
		var overlap := absf(distance - nearest) <= radius * 0.75
		if distance >= 0.0 and distance <= from.distance_to(to) and ((distance < nearest and not (overlap and rank < priority)) or (overlap and rank > priority)):
			priority = rank
			nearest = distance
			result = {"position": from + ray * distance, "zone": zone, "distance": distance}
	return result

static func _sphere(origin: Vector3, ray: Vector3, center: Vector3, radius: float) -> float:
	var offset := origin - center
	var c := offset.length_squared() - radius * radius
	if c <= 0: return 0.0
	var b := offset.dot(ray)
	var h := b * b - c
	if h < 0: return INF
	var t := -b - sqrt(h)
	return t if t >= 0 else INF

static func _capsule(origin: Vector3, ray: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	if origin.distance_squared_to(Geometry3D.get_closest_point_to_segment(origin, a, b)) <= radius * radius: return 0.0
	var axis := b - a
	var offset := origin - a
	var length2 := axis.length_squared()
	if length2 < 0.0001: return _sphere(origin, ray, a, radius)
	var along := axis.dot(ray)
	var projected := axis.dot(offset)
	var qa := length2 - along * along
	var qb := length2 * ray.dot(offset) - projected * along
	var qc := length2 * offset.length_squared() - projected * projected - radius * radius * length2
	var h := qb * qb - qa * qc
	if absf(qa) > 0.00001 and h >= 0:
		var t := (-qb - sqrt(h)) / qa
		var y := projected + t * along
		if t >= 0 and y >= 0 and y <= length2: return t
	return minf(_sphere(origin, ray, a, radius), _sphere(origin, ray, b, radius))
