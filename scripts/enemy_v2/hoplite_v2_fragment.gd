extends RigidBody3D
class_name HopliteV2Fragment

@export_range(0.5, 30.0, 0.1) var lifetime_seconds := 8.0
@export_range(0.05, 2.0, 0.05) var maximum_contact_seconds := 0.70

var zone: StringName
var contact_seconds: float = 0.0
var settled: bool = false
var authored_center := Vector3.ZERO
var authored_axis := Vector3.UP
var visual_container: Node3D
var collision_shape: CollisionShape3D
var ground_reference_y := NAN
var settle_finalize_scheduled := false
static var _scene_cache: Dictionary = {}


static func preload_fragment(fragment: Dictionary) -> bool:
	var runtime_path := String(fragment.get("runtime_path", ""))
	if runtime_path.is_empty():
		return false
	if _scene_cache.has(runtime_path):
		return true
	var packed := load(runtime_path) as PackedScene
	if packed == null:
		return false
	_scene_cache[runtime_path] = packed
	return true


func configure(fragment: Dictionary) -> bool:
	if is_inside_tree() or fragment.is_empty():
		return false
	zone = StringName(fragment.get("zone", fragment.get("name", &"")))
	set_meta("fragment_zone", zone)
	var runtime_path := String(fragment.get("runtime_path", ""))
	if not preload_fragment(fragment):
		return false
	var packed := _scene_cache.get(runtime_path) as PackedScene
	if packed == null:
		return false
	var visual := packed.instantiate() as Node3D
	if visual == null:
		return false
	visual_container = Node3D.new()
	visual_container.name = "CenteredVisual"
	add_child(visual_container)
	visual_container.add_child(visual)
	var collision_data: Dictionary = fragment.get("collision", {})
	var authored_length := maxf(0.02, float(collision_data.get("length", 0.2)))
	var pivot_data := fragment.get("pivot", {}) as Dictionary
	var authored_pivot := _source_vector_to_godot(pivot_data.get("position", []))
	authored_axis = _source_vector_to_godot(pivot_data.get("normal", [])).normalized()
	if authored_axis.is_zero_approx():
		authored_axis = Vector3.UP
	# AABB data on skinned glTF fragments can cover the complete source rig.
	# 3DGen's cut pivot + outward normal + collider length is the authoritative
	# fragment contract and gives a stable centre for static and two-bone pieces.
	authored_center = authored_pivot + authored_axis * authored_length * 0.5
	# 3DGen stores each fragment in full-body coordinates around its cut pivot.
	# Recenter the rendered geometry around the RigidBody centre of mass so its
	# primitive collider can rest on the floor instead of stopping while the mesh
	# still appears suspended above it.
	visual_container.position = -authored_center
	mass = maxf(0.1, float(fragment.get("mass_kg", 1.0)))
	collision_layer = 16
	collision_mask = 1
	continuous_cd = true
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 6
	linear_damp = 4.5
	angular_damp = 8.0
	gravity_scale = 1.15
	var material := PhysicsMaterial.new()
	material.friction = 1.0
	material.rough = true
	material.bounce = 0.0
	material.absorbent = true
	physics_material_override = material
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CenteredFragmentCollision"
	var radius := maxf(0.01, float(collision_data.get("radius", 0.1)))
	if String(collision_data.get("shape", "sphere")) == "capsule":
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(radius * 2.0, float(collision_data.get("length", radius * 2.0)))
		collision_shape.shape = capsule
		collision_shape.basis = Basis(Quaternion(Vector3.UP, authored_axis))
	else:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		collision_shape.shape = sphere
	add_child(collision_shape)
	return true


func _ready() -> void:
	var timer := get_tree().create_timer(lifetime_seconds)
	timer.timeout.connect(queue_free)
	# Broad Forge helper colliders can catch debris well above the visible floor.
	# This bounded watchdog is independent from contact callbacks, so even a body
	# sleeping on such a plane is brought back to the severing unit's foot level.
	var ground_watchdog := get_tree().create_timer(1.60)
	ground_watchdog.timeout.connect(_force_ground_if_floating)


func launch(
	linear_impulse: Vector3,
	impact_offset: Vector3 = Vector3.ZERO,
	torque_impulse: Vector3 = Vector3.ZERO
) -> void:
	settled = false
	contact_seconds = 0.0
	sleeping = false
	# The small, clamped off-centre application preserves the blade direction
	# while producing one natural tumble without destabilising the debris.
	var safe_offset := impact_offset.limit_length(0.18)
	apply_impulse(linear_impulse, safe_offset)
	apply_torque_impulse(torque_impulse)


func set_ground_reference(height: float) -> void:
	ground_reference_y = height


func centered_point(authored_point: Vector3) -> Vector3:
	return authored_point - authored_center


func estimate_lowest_collision_y() -> float:
	if collision_shape == null or collision_shape.shape == null:
		return global_position.y
	if collision_shape.shape is SphereShape3D:
		return collision_shape.global_position.y - (collision_shape.shape as SphereShape3D).radius
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		var world_axis := (collision_shape.global_basis * Vector3.UP).normalized()
		var cylinder_half := maxf(0.0, capsule.height * 0.5 - capsule.radius)
		var vertical_extent := capsule.radius + absf(world_axis.y) * cylinder_half
		return collision_shape.global_position.y - vertical_extent
	return collision_shape.global_position.y


func estimate_lowest_visual_y() -> float:
	var lowest := INF
	for visual: MeshInstance3D in _mesh_instances(visual_container):
		var bounds := visual.get_aabb()
		if bounds.size.length_squared() <= 0.000001:
			continue
		lowest = minf(lowest, (visual.global_transform * bounds).position.y)
	return global_position.y if not is_finite(lowest) else lowest


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	if node != null:
		for child: Node in node.get_children():
			result.append_array(_mesh_instances(child))
	return result


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if settled:
		return
	if state.get_contact_count() <= 0:
		contact_seconds = 0.0
		return
	contact_seconds += state.step
	# Contact is intentionally deadened. Fragments may tumble once after the
	# cut, then become cheap sleeping debris instead of rebounding indefinitely.
	state.linear_velocity = state.linear_velocity.lerp(Vector3.ZERO, clampf(state.step * 6.0, 0.0, 1.0))
	state.angular_velocity = state.angular_velocity.lerp(Vector3.ZERO, clampf(state.step * 9.0, 0.0, 1.0))
	var naturally_slow := state.linear_velocity.length() <= 0.42 and state.angular_velocity.length() <= 0.75
	if (naturally_slow and contact_seconds >= 0.22) or contact_seconds >= maximum_contact_seconds:
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		state.sleeping = true
		settled = true
		if not settle_finalize_scheduled:
			settle_finalize_scheduled = true
			_finalize_settle.call_deferred()


func _finalize_settle() -> void:
	if not is_inside_tree():
		return
	# Forge maps can contain broad helper collision surfaces above their rendered
	# terrain. A fragment that contacts one must not remain visibly suspended.
	# The severing actor supplies the local foot-height as a conservative ground
	# reference; only obviously floating debris is corrected.
	if is_finite(ground_reference_y):
		var collision_low := estimate_lowest_collision_y()
		if collision_low > ground_reference_y + 0.25:
			global_position.y -= collision_low - (ground_reference_y + 0.015)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.disabled = true


func _force_ground_if_floating() -> void:
	if not is_inside_tree() or not is_finite(ground_reference_y):
		return
	var collision_low := estimate_lowest_collision_y()
	if collision_low > ground_reference_y + 0.25:
		global_position.y -= collision_low - (ground_reference_y + 0.015)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	settled = true
	_finalize_settle()


func _source_vector_to_godot(raw: Variant) -> Vector3:
	var values := raw as Array
	if values == null or values.size() < 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[2]), -float(values[1]))
