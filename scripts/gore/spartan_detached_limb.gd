extends RigidBody3D
class_name HopliteSpartanDetachedLimb

const PackageAdapterScript = preload("res://scripts/enemy/spartan_character_package.gd")

func setup(
    package_scene: PackedScene,
    source_adapter: RefCounted,
    cut_zone: StringName,
    zone_world_transform: Transform3D,
    radius: float,
    length: float,
    impulse: Vector3
) -> bool:
    if package_scene == null or source_adapter == null:
        return false
    var source_root: Node3D = source_adapter.get("package_root") as Node3D
    var source_skeleton: Skeleton3D = source_adapter.get("skeleton") as Skeleton3D
    if source_root == null or source_skeleton == null:
        return false

    name = "SpartanDetached_%s" % String(cut_zone)
    global_transform = source_root.global_transform
    collision_layer = 16
    collision_mask = 1
    mass = 1.15 if cut_zone == &"head" else 0.90
    linear_damp = 0.18
    angular_damp = 0.12

    var fragment_scene := package_scene.instantiate() as Node3D
    if fragment_scene == null:
        return false
    fragment_scene.name = "DetachedCharacterParts"
    add_child(fragment_scene)

    var fragment_adapter = PackageAdapterScript.new()
    if not fragment_adapter.bind(fragment_scene):
        fragment_scene.queue_free()
        return false
    if not fragment_adapter.copy_pose_from(source_skeleton):
        fragment_scene.queue_free()
        return false
    if not fragment_adapter.show_detached_branch(cut_zone):
        fragment_scene.queue_free()
        return false

    var collision := CollisionShape3D.new()
    collision.name = "DetachedCollision"
    collision.transform = global_transform.affine_inverse() * zone_world_transform
    if cut_zone == &"head":
        var sphere := SphereShape3D.new()
        sphere.radius = maxf(radius, 0.14)
        collision.shape = sphere
    else:
        var capsule := CapsuleShape3D.new()
        capsule.radius = maxf(radius, 0.08)
        capsule.height = maxf(length + capsule.radius * 2.0, capsule.radius * 2.05)
        collision.shape = capsule
    add_child(collision)

    angular_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-6.0, 6.0), randf_range(-7.0, 7.0))
    apply_central_impulse(impulse + Vector3.UP * 2.4)

    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 14.0
    timer.timeout.connect(queue_free)
    add_child(timer)
    timer.start()
    return true
