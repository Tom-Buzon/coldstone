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
const MAX_POOLED_PER_KIND := 32

static var _shared_meshes: Dictionary = {}
static var _shared_materials: Dictionary = {}
static var _pools: Dictionary = {}

var _ray_query: PhysicsRayQueryParameters3D
var _configured: bool = false
var _runtime_initialized: bool = false

static func acquire(parent: Node, kind: StringName) -> HopliteEnemyProjectile:
    var pool: Array = _pools.get(kind, [])
    while not pool.is_empty():
        var reference := pool.pop_back() as WeakRef
        var candidate := reference.get_ref() as HopliteEnemyProjectile if reference != null else null
        if candidate == null or not is_instance_valid(candidate):
            continue
        _pools[kind] = pool
        if candidate.get_parent() != parent:
            candidate.reparent(parent, true)
        return candidate
    _pools[kind] = pool
    var projectile := HopliteEnemyProjectile.new()
    parent.add_child(projectile)
    return projectile

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
    lifetime = 4.0
    _configured = true
    visible = true
    set_physics_process(true)
    if is_inside_tree():
        _initialize_runtime()
        _configure_ray_query()
        _face_velocity()

func _ready() -> void:
    if _configured:
        _initialize_runtime()

func _initialize_runtime() -> void:
    if _runtime_initialized:
        return
    _runtime_initialized = true
    _build_visual()
    _face_velocity()

func _configure_ray_query() -> void:
    var excludes: Array[RID] = []
    if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject3D:
        excludes.append((shooter as CollisionObject3D).get_rid())
    _ray_query = PhysicsRayQueryParameters3D.create(global_position, global_position, collision_mask, excludes)
    _ray_query.collide_with_areas = false
    _ray_query.collide_with_bodies = true

func _physics_process(delta: float) -> void:
    if not _configured:
        return
    lifetime -= delta
    if lifetime <= 0.0:
        _release_to_pool()
        return

    var from := global_position
    velocity.y -= gravity * delta
    var to := from + velocity * delta
    if _ray_query == null:
        _ray_query = PhysicsRayQueryParameters3D.create(from, to, collision_mask)
        _ray_query.collide_with_areas = false
        _ray_query.collide_with_bodies = true
    _ray_query.from = from
    _ray_query.to = to
    _ray_query.collision_mask = collision_mask
    var hit := get_world_3d().direct_space_state.intersect_ray(_ray_query)
    if not hit.is_empty():
        global_position = hit.get("position", to)
        _deliver_hit(hit)
        _release_to_pool()
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
        var stone := _visual(&"Stone", &"stone", &"stone")
        add_child(stone)
        return

    var is_arrow := projectile_kind == &"arrow"
    var shaft := _visual(&"Shaft", &"arrow_shaft" if is_arrow else &"javelin_shaft", &"wood")
    shaft.position.z = 0.15 if is_arrow else 0.18
    add_child(shaft)

    var tip := _visual(&"Tip", &"arrow_tip" if is_arrow else &"javelin_tip", &"bronze")
    tip.rotation_degrees.x = 90.0
    tip.position.z = -0.255 if is_arrow else -0.52
    add_child(tip)

    if is_arrow:
        for crossed: bool in [false, true]:
            var feather := _visual(&"FeatherCross" if crossed else &"FeatherFlat", &"feather_cross" if crossed else &"feather_flat", &"feather")
            feather.position.z = 0.44
            add_child(feather)

func expire_now() -> void:
    _release_to_pool()

func _release_to_pool() -> void:
    if not _configured:
        return
    _configured = false
    visible = false
    set_physics_process(false)
    velocity = Vector3.ZERO
    shooter = null
    var pool: Array = _pools.get(projectile_kind, [])
    if pool.size() >= MAX_POOLED_PER_KIND:
        queue_free()
        return
    pool.append(weakref(self))
    _pools[projectile_kind] = pool

func _visual(node_name: StringName, mesh_key: StringName, material_key: StringName) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    visual.name = String(node_name)
    visual.mesh = _shared_mesh(mesh_key)
    visual.material_override = _shared_material(material_key)
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return visual

func _shared_mesh(key: StringName) -> PrimitiveMesh:
    if _shared_meshes.has(key):
        return _shared_meshes[key] as PrimitiveMesh
    var mesh: PrimitiveMesh
    match key:
        &"stone":
            var sphere := SphereMesh.new()
            sphere.radius = 0.055
            sphere.height = 0.10
            mesh = sphere
        &"arrow_shaft", &"javelin_shaft":
            var box := BoxMesh.new()
            var is_arrow := key == &"arrow_shaft"
            box.size = Vector3(0.012 if is_arrow else 0.024, 0.012 if is_arrow else 0.024, 0.72 if is_arrow else 1.25)
            mesh = box
        &"arrow_tip", &"javelin_tip":
            var tip := CylinderMesh.new()
            var is_arrow := key == &"arrow_tip"
            tip.height = 0.11 if is_arrow else 0.18
            tip.top_radius = 0.0
            tip.bottom_radius = 0.026 if is_arrow else 0.052
            mesh = tip
        &"feather_cross", &"feather_flat":
            var feather := BoxMesh.new()
            feather.size = Vector3(0.006, 0.058, 0.15) if key == &"feather_cross" else Vector3(0.058, 0.006, 0.15)
            mesh = feather
    _shared_meshes[key] = mesh
    return mesh

func _shared_material(key: StringName) -> StandardMaterial3D:
    if _shared_materials.has(key):
        return _shared_materials[key] as StandardMaterial3D
    var material := StandardMaterial3D.new()
    match key:
        &"stone":
            material.albedo_color = Color(0.24, 0.20, 0.15)
            material.roughness = 0.9
        &"wood":
            material.albedo_color = Color(0.24, 0.09, 0.025)
            material.roughness = 0.78
        &"bronze":
            material.albedo_color = Color(0.55, 0.32, 0.09)
            material.roughness = 0.28
            material.metallic = 0.72
        &"feather":
            material.albedo_color = Color(0.82, 0.18, 0.08)
            material.roughness = 0.92
    _shared_materials[key] = material
    return material
