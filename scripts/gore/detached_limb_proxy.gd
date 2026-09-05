extends RigidBody3D
class_name HopliteDetachedLimbProxy

const DebrisLifecycleScript = preload("res://scripts/gore/transient_rigid_debris_lifecycle.gd")

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

func setup(zone: StringName, world_transform: Transform3D, radius: float, length: float, body_color: Color, impulse: Vector3) -> void:
    name = "Detached_%s" % String(zone)
    global_transform = world_transform
    collision_layer = 16
    collision_mask = 1
    mass = 0.85 if zone != &"head" else 1.15
    linear_damp = 0.18
    angular_damp = 0.12
    can_sleep = true

    var body_material := _body_material(body_color)
    var blood_material := _blood_material()

    var collision := CollisionShape3D.new()
    add_child(collision)

    if zone == &"head":
        var mesh_instance := MeshInstance3D.new()
        mesh_instance.name = "DetachedBody"
        var mesh := _head_mesh(radius)
        mesh_instance.mesh = mesh
        mesh_instance.material_override = body_material
        add_child(mesh_instance)

        var sphere := SphereShape3D.new()
        sphere.radius = maxf(radius, 0.18)
        collision.shape = sphere

        var cap := MeshInstance3D.new()
        cap.name = "SeverCap"
        var cap_mesh := _cap_mesh(radius, 0.025, 0.58, 0.62)
        cap.mesh = cap_mesh
        cap.position.y = -radius * 0.82
        cap.material_override = blood_material
        add_child(cap)
    else:
        var safe_length: float = maxf(length, radius * 2.15)
        var mesh_instance := MeshInstance3D.new()
        mesh_instance.name = "DetachedBody"
        var mesh := _limb_mesh(radius, safe_length)
        mesh_instance.mesh = mesh
        mesh_instance.material_override = body_material
        add_child(mesh_instance)

        var capsule := CapsuleShape3D.new()
        capsule.radius = radius
        capsule.height = safe_length
        collision.shape = capsule

        var cap := MeshInstance3D.new()
        cap.name = "SeverCap"
        var cap_mesh := _cap_mesh(radius, 0.028, 0.86, 0.92)
        cap.mesh = cap_mesh
        cap.position.y = -safe_length * 0.48
        cap.material_override = blood_material
        add_child(cap)

    angular_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-6.0, 6.0), randf_range(-7.0, 7.0))
    apply_central_impulse(impulse + Vector3.UP * 2.4)

    var lifecycle = DebrisLifecycleScript.new()
    add_child(lifecycle)
    lifecycle.setup(self, collision, 14.0, 4.0)

func _body_material(color: Color) -> StandardMaterial3D:
    var key := "body:%s" % color.to_html()
    if not _material_cache.has(key):
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.roughness = 0.60
        _material_cache[key] = material
    return _material_cache[key] as StandardMaterial3D

func _blood_material() -> StandardMaterial3D:
    const KEY := "blood"
    if not _material_cache.has(KEY):
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.34, 0.005, 0.008)
        material.roughness = 0.72
        _material_cache[KEY] = material
    return _material_cache[KEY] as StandardMaterial3D

func _head_mesh(radius: float) -> SphereMesh:
    var safe_radius := maxf(radius, 0.18)
    var key := "head:%.4f" % safe_radius
    if not _mesh_cache.has(key):
        var mesh := SphereMesh.new()
        mesh.radius = safe_radius
        mesh.height = maxf(radius * 2.0, 0.36)
        _mesh_cache[key] = mesh
    return _mesh_cache[key] as SphereMesh

func _limb_mesh(radius: float, length: float) -> CapsuleMesh:
    var key := "limb:%.4f:%.4f" % [radius, length]
    if not _mesh_cache.has(key):
        var mesh := CapsuleMesh.new()
        mesh.radius = radius
        mesh.height = length
        _mesh_cache[key] = mesh
    return _mesh_cache[key] as CapsuleMesh

func _cap_mesh(radius: float, height: float, top_scale: float, bottom_scale: float) -> CylinderMesh:
    var key := "cap:%.4f:%.4f:%.4f:%.4f" % [radius, height, top_scale, bottom_scale]
    if not _mesh_cache.has(key):
        var mesh := CylinderMesh.new()
        mesh.height = height
        mesh.top_radius = radius * top_scale
        mesh.bottom_radius = radius * bottom_scale
        _mesh_cache[key] = mesh
    return _mesh_cache[key] as CylinderMesh
