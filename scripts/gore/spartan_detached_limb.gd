extends RigidBody3D
class_name HopliteSpartanDetachedLimb

const PackageAdapterScript = preload("res://scripts/enemy/spartan_character_package.gd")
const DebrisLifecycleScript = preload("res://scripts/gore/transient_rigid_debris_lifecycle.gd")

var active: bool = false
var fragment_adapter: HopliteSpartanCharacterPackage
var fragment_scene: Node3D
var detached_collision: CollisionShape3D
var lifecycle: HopliteTransientRigidDebrisLifecycle
var fragment_geometries: Array[GeometryInstance3D] = []
var fragment_shadow_modes := PackedInt32Array()
var _sphere_shape := SphereShape3D.new()
var _capsule_shape := CapsuleShape3D.new()
var _managed_release: Callable


func prepare(package_scene: PackedScene, release_callback: Callable = Callable()) -> bool:
	if package_scene == null:
		return false
	_managed_release = release_callback
	collision_layer = 0
	collision_mask = 0
	can_sleep = true
	freeze = true
	visible = false
	fragment_scene = package_scene.instantiate() as Node3D
	if fragment_scene == null:
		return false
	fragment_scene.name = "DetachedCharacterParts"
	add_child(fragment_scene)
	fragment_adapter = PackageAdapterScript.new() as HopliteSpartanCharacterPackage
	if not fragment_adapter.bind(fragment_scene):
		return false
	if not fragment_adapter.optimize_body_meshes():
		return false
	for candidate: Node in fragment_scene.find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		if geometry != null:
			fragment_geometries.append(geometry)
			fragment_shadow_modes.append(geometry.cast_shadow)

	detached_collision = CollisionShape3D.new()
	detached_collision.name = "DetachedCollision"
	detached_collision.disabled = true
	add_child(detached_collision)
	lifecycle = DebrisLifecycleScript.new() as HopliteTransientRigidDebrisLifecycle
	add_child(lifecycle)
	lifecycle.setup(self, detached_collision, 14.0, 4.0, _managed_release, not _managed_release.is_null())
	return true


func activate(
	source_adapter: RefCounted,
	cut_zone: StringName,
	zone_world_transform: Transform3D,
	radius: float,
	length: float,
	impulse: Vector3
) -> bool:
	if source_adapter == null or fragment_adapter == null:
		return false
	var source_root := source_adapter.get("package_root") as Node3D
	var source_skeleton := source_adapter.get("skeleton") as Skeleton3D
	if source_root == null or source_skeleton == null:
		return false

	name = "SpartanDetached_%s" % String(cut_zone)
	global_transform = source_root.global_transform
	mass = 1.15 if cut_zone == &"head" else 0.90
	linear_damp = 0.18
	angular_damp = 0.12
	if not fragment_adapter.copy_pose_from(source_skeleton):
		return false
	if not fragment_adapter.show_detached_branch(cut_zone):
		return false

	detached_collision.transform = global_transform.affine_inverse() * zone_world_transform
	if cut_zone == &"head":
		_sphere_shape.radius = maxf(radius, 0.14)
		detached_collision.shape = _sphere_shape
	else:
		_capsule_shape.radius = maxf(radius, 0.08)
		_capsule_shape.height = maxf(length + _capsule_shape.radius * 2.0, _capsule_shape.radius * 2.05)
		detached_collision.shape = _capsule_shape
	detached_collision.disabled = false
	collision_layer = 16
	collision_mask = 1
	freeze = false
	sleeping = false
	visible = true
	active = true
	for index: int in range(fragment_geometries.size()):
		fragment_geometries[index].cast_shadow = fragment_shadow_modes[index]
	lifecycle.setup(self, detached_collision, 14.0, 4.0, _managed_release, not _managed_release.is_null())
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-6.0, 6.0), randf_range(-7.0, 7.0))
	apply_central_impulse(impulse + Vector3.UP * 2.4)
	return true


func setup(
	package_scene: PackedScene,
	source_adapter: RefCounted,
	cut_zone: StringName,
	zone_world_transform: Transform3D,
	radius: float,
	length: float,
	impulse: Vector3
) -> bool:
	if not prepare(package_scene):
		return false
	if not activate(source_adapter, cut_zone, zone_world_transform, radius, length, impulse):
		return false
	# Compatibility path for probes/scenes not using the director.
	lifecycle.setup(self, detached_collision, 14.0, 4.0)
	return true


func retire_now() -> void:
	if lifecycle != null:
		lifecycle.retire_now()


func deactivate_to_pool() -> void:
	active = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	freeze = true
	if detached_collision != null:
		detached_collision.disabled = true
