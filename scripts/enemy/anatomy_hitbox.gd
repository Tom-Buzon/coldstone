extends Area3D
class_name HopliteAnatomyHitbox

var enemy_owner: Node = null
var skeleton: Skeleton3D = null
var zone_defs: Dictionary = {}
var zone_runtime: Dictionary = {}
var debug_missing_bones: Array[String] = []
var debug_visible: bool = false
var bone_world_position_mapper := Callable()

# V0.0.12 performance LOD. Hitboxes close to the player can still track bones every
# physics frame; distant crowds update less often. Debug geometry is created lazily.
var tracking_enabled: bool = true
var query_enabled: bool = true
var update_interval: float = 0.0
var update_accumulator: float = 0.0

func configure(owner_node: Node, skeleton_node: Skeleton3D, definitions: Dictionary) -> bool:
	enemy_owner = owner_node
	skeleton = skeleton_node
	zone_defs = definitions
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	process_priority = 60
	add_to_group("damageable")

	if skeleton == null:
		return false

	for raw_zone: Variant in zone_defs.keys():
		var zone: StringName = StringName(raw_zone)
		var definition: Dictionary = zone_defs[raw_zone]
		_create_zone(zone, definition)

	return not zone_runtime.is_empty()

func set_bone_world_position_mapper(mapper: Callable) -> void:
	bone_world_position_mapper = mapper

func _physics_process(delta: float) -> void:
	if skeleton == null or not tracking_enabled:
		return
	if update_interval > 0.0001:
		update_accumulator += delta
		if update_accumulator < update_interval:
			return
		update_accumulator = 0.0
	_update_all_zones()

func _update_all_zones() -> void:
	for raw_zone: Variant in zone_runtime.keys():
		_update_zone_shape(StringName(raw_zone))

func set_update_interval(seconds: float) -> void:
	var next_interval: float = maxf(seconds, 0.0)
	if is_equal_approx(update_interval, next_interval):
		return
	update_interval = next_interval
	update_accumulator = update_interval

func set_tracking_enabled(enabled: bool) -> void:
	if tracking_enabled == enabled:
		return
	tracking_enabled = enabled
	set_physics_process(enabled)
	if enabled:
		force_update()

## Separates combat participation from bone tracking. Distant EnemyV2 actors
## must leave the physics broad phase entirely; merely stopping this callback
## keeps twelve stale query shapes registered for every soldier.
func set_runtime_query_enabled(enabled: bool) -> void:
	if query_enabled == enabled and tracking_enabled == enabled:
		return
	query_enabled = enabled
	if enabled:
		set_tracking_enabled(true)
		collision_layer = 8
	else:
		collision_layer = 0
		set_tracking_enabled(false)

func force_update() -> void:
	if skeleton == null:
		return
	update_accumulator = 0.0
	_update_all_zones()

func shutdown() -> void:
	tracking_enabled = false
	query_enabled = false
	collision_layer = 0
	set_physics_process(false)
	set_debug_visible(false)

func _create_zone(zone: StringName, definition: Dictionary) -> void:
	var bone_a: int = _find_bone(Array(definition.get("bone_a", [])))
	var bone_b: int = _find_bone(Array(definition.get("bone_b", [])))
	if bone_a < 0:
		debug_missing_bones.append(String(zone))
		return

	var collision := CollisionShape3D.new()
	collision.name = "Zone_%s" % String(zone)
	collision.set_meta("damage_zone", zone)
	add_child(collision)

	var radius: float = float(definition.get("radius", 0.16))
	var shape_kind: StringName = StringName(definition.get("shape", &"sphere"))
	if shape_kind == &"capsule" and bone_b >= 0:
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = radius * 2.05
		collision.shape = capsule
	else:
		shape_kind = &"sphere"
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		collision.shape = sphere

	# Debug meshes used to be allocated for every zone on every enemy at startup,
	# even when diagnostics were hidden. Keep only the collision shape here; the
	# visual mesh is created on demand the first time I diagnostics are enabled.
	zone_runtime[zone] = {
		"collision": collision,
		"debug_mesh": null,
		"bone_a": bone_a,
		"bone_b": bone_b,
		"bone_a_name": skeleton.get_bone_name(bone_a),
		"bone_b_name": skeleton.get_bone_name(bone_b) if bone_b >= 0 else "",
		"shape": shape_kind,
		"radius": radius,
		"priority": float(definition.get("target_priority", 0.0)),
		"disabled": false,
		"length": radius * 2.0
	}
	_update_zone_shape(zone)

func _update_zone_shape(zone: StringName) -> void:
	if not zone_runtime.has(zone):
		return
	var runtime: Dictionary = zone_runtime[zone]
	var collision: CollisionShape3D = runtime.get("collision") as CollisionShape3D
	var debug_mesh: MeshInstance3D = runtime.get("debug_mesh") as MeshInstance3D
	if collision == null:
		return

	var disabled: bool = bool(runtime.get("disabled", false))
	if disabled:
		if debug_mesh != null:
			debug_mesh.visible = false
		return

	var bone_a: int = int(runtime.get("bone_a", -1))
	var bone_b: int = int(runtime.get("bone_b", -1))
	if bone_a < 0:
		return

	var a_world: Vector3 = _bone_world_position(bone_a)
	var shape_kind: StringName = StringName(runtime.get("shape", &"sphere"))
	# CollisionShape3D transforms are written in world space below so that their
	# orientation stays clean while following animated bones. That deliberately
	# cancels the Area/enemy parent scale, therefore the Shape3D dimensions must
	# carry that scale themselves. Without this, a Forge giant at x3 kept human-
	# sized damage volumes even though its bones and traversal body were x3 apart.
	var local_radius: float = float(runtime.get("radius", 0.16))
	var world_radius: float = local_radius * _world_radius_scale()
	runtime["world_radius"] = world_radius

	if shape_kind == &"capsule" and bone_b >= 0:
		var b_world: Vector3 = _bone_world_position(bone_b)
		var segment: Vector3 = b_world - a_world
		var length: float = segment.length()
		var capsule := collision.shape as CapsuleShape3D
		if capsule != null:
			if absf(capsule.radius - world_radius) > 0.001:
				capsule.radius = world_radius
			# CapsuleShape3D.height includes both hemispheres. Add the diameters
			# so the hit volume truly spans from bone A all the way to bone B.
			var wanted_height := maxf(length + world_radius * 2.0, world_radius * 2.05)
			if absf(capsule.height - wanted_height) > 0.001:
				capsule.height = wanted_height
		if length < 0.05:
			collision.global_position = a_world
			if debug_mesh != null:
				debug_mesh.global_position = a_world
			runtime["length"] = length
			zone_runtime[zone] = runtime
			if debug_visible:
				_sync_debug_mesh_geometry(zone)
			return
		var transform := Transform3D(_basis_y_along(segment), a_world.lerp(b_world, 0.5))
		collision.global_transform = transform
		if debug_mesh != null:
			debug_mesh.global_transform = transform
		runtime["length"] = length
	else:
		var sphere := collision.shape as SphereShape3D
		if sphere != null and absf(sphere.radius - world_radius) > 0.001:
			sphere.radius = world_radius
		collision.global_transform = Transform3D(Basis.IDENTITY, a_world)
		if debug_mesh != null:
			debug_mesh.global_transform = collision.global_transform
		runtime["length"] = world_radius * 2.0

	zone_runtime[zone] = runtime
	if debug_visible:
		_sync_debug_mesh_geometry(zone)

func receive_weapon_hit(hit: Variant, shape_index: int) -> bool:
	var zone: StringName = zone_from_shape_index(shape_index)
	if zone == StringName():
		return false
	return receive_weapon_hit_zone(hit, zone)

func receive_weapon_hit_zone(hit: Variant, zone: StringName) -> bool:
	if zone == StringName() or not zone_runtime.has(zone):
		return false
	var runtime: Dictionary = zone_runtime[zone]
	if bool(runtime.get("disabled", false)):
		return false
	if enemy_owner != null and enemy_owner.has_method("can_receive_hit_from"):
		if not bool(enemy_owner.call("can_receive_hit_from", hit.source)):
			return false
	if enemy_owner != null and enemy_owner.has_method("receive_anatomy_hit"):
		enemy_owner.call("receive_anatomy_hit", hit, zone)
		return true
	return false

func get_combat_owner() -> Node:
	return enemy_owner

func zone_from_shape_index(shape_index: int) -> StringName:
	if shape_index < 0:
		return StringName()
	var owner_id: int = shape_find_owner(shape_index)
	if owner_id < 0:
		return StringName()
	var owner_node: Object = shape_owner_get_owner(owner_id)
	if owner_node is CollisionShape3D:
		var collision: CollisionShape3D = owner_node as CollisionShape3D
		return StringName(collision.get_meta("damage_zone", StringName()))
	return StringName()

func zone_world_center_from_shape_index(shape_index: int) -> Vector3:
	return get_zone_world_center(zone_from_shape_index(shape_index))

func zone_radius_from_shape_index(shape_index: int) -> float:
	return get_zone_world_radius(zone_from_shape_index(shape_index))

func zone_priority_from_shape_index(shape_index: int) -> float:
	return get_zone_priority(zone_from_shape_index(shape_index))

func get_zone_world_center(zone: StringName) -> Vector3:
	if not zone_runtime.has(zone):
		return global_position
	var collision: CollisionShape3D = (zone_runtime[zone] as Dictionary).get("collision") as CollisionShape3D
	return collision.global_position if collision != null else global_position

func get_zone_priority(zone: StringName) -> float:
	if not zone_runtime.has(zone):
		return 0.0
	return float((zone_runtime[zone] as Dictionary).get("priority", 0.0))

func disable_zone(zone: StringName) -> void:
	if not zone_runtime.has(zone):
		return
	var runtime: Dictionary = zone_runtime[zone]
	runtime["disabled"] = true
	var collision: CollisionShape3D = runtime.get("collision") as CollisionShape3D
	var debug_mesh: MeshInstance3D = runtime.get("debug_mesh") as MeshInstance3D
	if collision != null:
		collision.set_deferred("disabled", true)
	if debug_mesh != null:
		debug_mesh.visible = false
	zone_runtime[zone] = runtime

func get_zone_primary_bone(zone: StringName) -> int:
	if not zone_runtime.has(zone):
		return -1
	return int((zone_runtime[zone] as Dictionary).get("bone_a", -1))

func get_zone_world_transform(zone: StringName) -> Transform3D:
	if not zone_runtime.has(zone):
		return Transform3D.IDENTITY
	var collision: CollisionShape3D = (zone_runtime[zone] as Dictionary).get("collision") as CollisionShape3D
	return collision.global_transform if collision != null else Transform3D.IDENTITY

func get_zone_radius(zone: StringName) -> float:
	if not zone_runtime.has(zone):
		return 0.16
	return float((zone_runtime[zone] as Dictionary).get("radius", 0.16))

func get_zone_world_radius(zone: StringName) -> float:
	if not zone_runtime.has(zone):
		return 0.16 * _world_radius_scale()
	var runtime: Dictionary = zone_runtime[zone]
	return float(runtime.get("world_radius", float(runtime.get("radius", 0.16)) * _world_radius_scale()))

func get_zone_length(zone: StringName) -> float:
	if not zone_runtime.has(zone):
		return 0.32
	return float((zone_runtime[zone] as Dictionary).get("length", 0.32))

func estimate_lowest_surface_y() -> float:
	# Bone origins alone make a horizontal corpse hover by roughly a limb radius.
	# Estimate the skinned body's lower envelope from the same capsules/spheres used
	# by combat, even after shutdown() has disabled their live tracking.
	if skeleton == null or zone_runtime.is_empty():
		return INF
	var lowest: float = INF
	var anatomy_scale := global_basis.get_scale()
	var radius_scale := maxf(absf(anatomy_scale.x), maxf(absf(anatomy_scale.y), absf(anatomy_scale.z)))
	for raw_zone: Variant in zone_runtime.keys():
		var runtime: Dictionary = zone_runtime[raw_zone]
		var radius: float = float(runtime.get("radius", 0.16)) * radius_scale
		for key: String in ["bone_a", "bone_b"]:
			var bone_index: int = int(runtime.get(key, -1))
			if bone_index >= 0 and bone_index < skeleton.get_bone_count():
				var bone_world: Vector3 = _bone_world_position(bone_index)
				lowest = minf(lowest, bone_world.y - radius)
	return lowest

func set_debug_visible(enabled: bool) -> void:
	debug_visible = enabled
	for raw_zone: Variant in zone_runtime.keys():
		var zone: StringName = StringName(raw_zone)
		var runtime: Dictionary = zone_runtime[zone]
		if enabled:
			_ensure_debug_mesh(zone)
			_sync_debug_mesh_geometry(zone)
			runtime = zone_runtime[zone]
		var debug_mesh: MeshInstance3D = runtime.get("debug_mesh") as MeshInstance3D
		if debug_mesh != null:
			debug_mesh.visible = enabled and not bool(runtime.get("disabled", false))
	if enabled:
		force_update()

func debug_mapping_summary() -> String:
	var parts: Array[String] = []
	for raw_zone: Variant in zone_runtime.keys():
		var zone: StringName = StringName(raw_zone)
		var runtime: Dictionary = zone_runtime[raw_zone]
		var a_name: String = String(runtime.get("bone_a_name", "?"))
		var b_name: String = String(runtime.get("bone_b_name", ""))
		if b_name != "":
			parts.append("%s=%s->%s" % [String(zone), a_name, b_name])
		else:
			parts.append("%s=%s" % [String(zone), a_name])
	return " | ".join(parts)

func _ensure_debug_mesh(zone: StringName) -> void:
	if not zone_runtime.has(zone):
		return
	var runtime: Dictionary = zone_runtime[zone]
	var existing: MeshInstance3D = runtime.get("debug_mesh") as MeshInstance3D
	if existing != null:
		return

	var debug_mesh := MeshInstance3D.new()
	debug_mesh.name = "Debug_%s" % String(zone)
	debug_mesh.visible = debug_visible and not bool(runtime.get("disabled", false))
	debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(debug_mesh)

	var radius: float = float(runtime.get("world_radius", float(runtime.get("radius", 0.16)) * _world_radius_scale()))
	var shape_kind: StringName = StringName(runtime.get("shape", &"sphere"))
	if shape_kind == &"capsule":
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = maxf(float(runtime.get("length", radius * 2.0)) + radius * 2.0, radius * 2.05)
		mesh.radial_segments = 8
		mesh.rings = 3
		mesh.material = _debug_material_for_zone(zone)
		debug_mesh.mesh = mesh
	else:
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 10
		sphere.rings = 5
		sphere.material = _debug_material_for_zone(zone)
		debug_mesh.mesh = sphere

	runtime["debug_mesh"] = debug_mesh
	zone_runtime[zone] = runtime

func _sync_debug_mesh_geometry(zone: StringName) -> void:
	if not debug_visible or not zone_runtime.has(zone):
		return
	var runtime: Dictionary = zone_runtime[zone]
	var debug_mesh: MeshInstance3D = runtime.get("debug_mesh") as MeshInstance3D
	var collision: CollisionShape3D = runtime.get("collision") as CollisionShape3D
	if debug_mesh == null or collision == null:
		return
	debug_mesh.global_transform = collision.global_transform
	var radius: float = float(runtime.get("world_radius", float(runtime.get("radius", 0.16)) * _world_radius_scale()))
	if debug_mesh.mesh is CapsuleMesh:
		var capsule_mesh := debug_mesh.mesh as CapsuleMesh
		capsule_mesh.radius = radius
		capsule_mesh.height = maxf(float(runtime.get("length", radius * 2.0)) + radius * 2.0, radius * 2.05)
	elif debug_mesh.mesh is SphereMesh:
		var sphere_mesh := debug_mesh.mesh as SphereMesh
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2.0

func _world_radius_scale() -> float:
	var world_scale := global_basis.get_scale()
	return maxf(maxf(absf(world_scale.x), absf(world_scale.y)), maxf(absf(world_scale.z), 0.01))

func _bone_world_position(bone_index: int) -> Vector3:
	if bone_world_position_mapper.is_valid():
		var mapped: Variant = bone_world_position_mapper.call(bone_index)
		if mapped is Vector3:
			return mapped as Vector3
	return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)

func _debug_material_for_zone(zone: StringName) -> StandardMaterial3D:
	var color := Color(0.12, 0.48, 1.0, 0.22)
	match zone:
		&"head": color = Color(1.0, 0.78, 0.08, 0.30)
		&"neck": color = Color(1.0, 0.08, 0.08, 0.36)
		&"torso", &"pelvis": color = Color(0.12, 0.50, 1.0, 0.22)
		&"upper_arm_l", &"upper_arm_r", &"forearm_l", &"forearm_r": color = Color(0.15, 1.0, 0.34, 0.25)
		&"thigh_l", &"thigh_r", &"shin_l", &"shin_r": color = Color(0.72, 0.22, 1.0, 0.25)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = color
	return mat

func _find_bone(candidates: Array) -> int:
	if skeleton == null or candidates.is_empty():
		return -1

	var compact_candidates: Array[String] = []
	for value: Variant in candidates:
		compact_candidates.append(_compact(String(value)))

	for i: int in range(skeleton.get_bone_count()):
		var compact_name: String = _compact(skeleton.get_bone_name(i))
		if compact_candidates.has(compact_name):
			return i

	compact_candidates.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for candidate: String in compact_candidates:
		if candidate.length() < 4:
			continue
		for i: int in range(skeleton.get_bone_count()):
			var compact_name: String = _compact(skeleton.get_bone_name(i))
			if candidate in compact_name:
				return i
	return -1

func _compact(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace(".", "")

func _basis_y_along(segment: Vector3) -> Basis:
	var y_axis: Vector3 = segment.normalized()
	var helper: Vector3 = Vector3.RIGHT
	if absf(y_axis.dot(helper)) > 0.92:
		helper = Vector3.FORWARD
	var z_axis: Vector3 = helper.cross(y_axis).normalized()
	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)
