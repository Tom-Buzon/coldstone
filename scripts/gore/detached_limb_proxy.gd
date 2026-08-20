extends RigidBody3D
class_name HopliteDetachedLimbProxy

func setup(zone: StringName, world_transform: Transform3D, radius: float, length: float, body_color: Color, impulse: Vector3) -> void:
    name = "Detached_%s" % String(zone)
    global_transform = world_transform
    collision_layer = 16
    collision_mask = 1
    mass = 0.85 if zone != &"head" else 1.15
    linear_damp = 0.18
    angular_damp = 0.12

    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = body_color
    body_material.roughness = 0.60

    var blood_material := StandardMaterial3D.new()
    blood_material.albedo_color = Color(0.34, 0.005, 0.008)
    blood_material.roughness = 0.72

    var collision := CollisionShape3D.new()
    add_child(collision)

    if zone == &"head":
        var mesh_instance := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = maxf(radius, 0.18)
        mesh.height = maxf(radius * 2.0, 0.36)
        mesh_instance.mesh = mesh
        mesh_instance.material_override = body_material
        add_child(mesh_instance)

        var sphere := SphereShape3D.new()
        sphere.radius = maxf(radius, 0.18)
        collision.shape = sphere

        var cap := MeshInstance3D.new()
        var cap_mesh := CylinderMesh.new()
        cap_mesh.height = 0.025
        cap_mesh.top_radius = radius * 0.58
        cap_mesh.bottom_radius = radius * 0.62
        cap.mesh = cap_mesh
        cap.position.y = -radius * 0.82
        cap.material_override = blood_material
        add_child(cap)
    else:
        var safe_length: float = maxf(length, radius * 2.15)
        var mesh_instance := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = radius
        mesh.height = safe_length
        mesh_instance.mesh = mesh
        mesh_instance.material_override = body_material
        add_child(mesh_instance)

        var capsule := CapsuleShape3D.new()
        capsule.radius = radius
        capsule.height = safe_length
        collision.shape = capsule

        var cap := MeshInstance3D.new()
        var cap_mesh := CylinderMesh.new()
        cap_mesh.height = 0.028
        cap_mesh.top_radius = radius * 0.86
        cap_mesh.bottom_radius = radius * 0.92
        cap.mesh = cap_mesh
        cap.position.y = -safe_length * 0.48
        cap.material_override = blood_material
        add_child(cap)

    angular_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-6.0, 6.0), randf_range(-7.0, 7.0))
    apply_central_impulse(impulse + Vector3.UP * 2.4)

    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 14.0
    timer.timeout.connect(queue_free)
    add_child(timer)
    timer.start()
