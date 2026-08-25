extends Node3D
class_name HopliteEnemyProjectile

# Cheap kinematic projectile: one swept ray per physics tick, no RigidBody and no
# Area node. The same component can later represent arrows, javelins or sling
# stones by changing kind, speed and gravity in the enemy profile.

var shooter: Node3D
var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var gravity: float = 5.0
var projectile_kind: StringName = &"arrow"
var collision_mask: int = 3
var lifetime: float = 4.0

func setup(
    source: Node3D,
    origin: Vector3,
    initial_velocity: Vector3,
    damage_value: float,
    kind: StringName = &"arrow",
    gravity_value: float = 5.0,
    mask_value: int = 3
) -> void:
    shooter = source
    global_position = origin
    velocity = initial_velocity
    damage = damage_value
    projectile_kind = kind
    gravity = gravity_value
    collision_mask = mask_value

func _ready() -> void:
    _build_visual()
    _face_velocity()

func _physics_process(delta: float) -> void:
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()
        return

    var from := global_position
    velocity.y -= gravity * delta
    var to := from + velocity * delta
    var excludes: Array[RID] = []
    if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject3D:
        excludes.append((shooter as CollisionObject3D).get_rid())
    var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, excludes)
    query.collide_with_areas = false
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        global_position = hit.get("position", to)
        _deliver_hit(hit)
        queue_free()
        return

    global_position = to
    _face_velocity()

func _deliver_hit(hit: Dictionary) -> void:
    var receiver := hit.get("collider") as Node
    if receiver == null or receiver == shooter:
        return
    var direction := velocity.normalized()
    if receiver.has_method("receive_enemy_hit"):
        receiver.call("receive_enemy_hit", damage, shooter, direction)
    elif receiver.has_method("receive_ai_hit"):
        receiver.call("receive_ai_hit", damage, shooter, direction)

func _face_velocity() -> void:
    if velocity.length_squared() > 0.001:
        look_at(global_position + velocity.normalized(), Vector3.UP)

func _build_visual() -> void:
    if projectile_kind == &"stone":
        var stone := MeshInstance3D.new()
        var stone_mesh := SphereMesh.new()
        stone_mesh.radius = 0.055
        stone_mesh.height = 0.10
        stone.mesh = stone_mesh
        stone.material_override = _material(Color(0.24, 0.20, 0.15), 0.9, 0.0)
        add_child(stone)
        return

    var is_arrow := projectile_kind == &"arrow"
    var shaft := MeshInstance3D.new()
    var shaft_mesh := BoxMesh.new()
    shaft_mesh.size = Vector3(0.012 if is_arrow else 0.024, 0.012 if is_arrow else 0.024, 0.72 if is_arrow else 1.25)
    shaft.mesh = shaft_mesh
    shaft.position.z = 0.15 if is_arrow else 0.18
    shaft.material_override = _material(Color(0.24, 0.09, 0.025), 0.78, 0.0)
    add_child(shaft)

    var tip := MeshInstance3D.new()
    var tip_mesh := CylinderMesh.new()
    tip_mesh.height = 0.11 if is_arrow else 0.18
    tip_mesh.top_radius = 0.0
    tip_mesh.bottom_radius = 0.026 if is_arrow else 0.052
    tip.mesh = tip_mesh
    tip.rotation_degrees.x = 90.0
    tip.position.z = -0.255 if is_arrow else -0.52
    tip.material_override = _material(Color(0.55, 0.32, 0.09), 0.28, 0.72)
    add_child(tip)

    if is_arrow:
        var feather_material := _material(Color(0.82, 0.18, 0.08), 0.92, 0.0)
        for crossed: bool in [false, true]:
            var feather := MeshInstance3D.new()
            var feather_mesh := BoxMesh.new()
            feather_mesh.size = Vector3(0.058, 0.006, 0.15) if not crossed else Vector3(0.006, 0.058, 0.15)
            feather.mesh = feather_mesh
            feather.position.z = 0.44
            feather.material_override = feather_material
            add_child(feather)

func _material(color: Color, roughness_value: float, metallic_value: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness_value
    material.metallic = metallic_value
    return material
