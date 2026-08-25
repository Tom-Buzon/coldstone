extends Area3D
class_name HopliteBattleObjectiveTarget

signal destroyed(target: HopliteBattleObjectiveTarget, objective_id: StringName)

var objective_id: StringName
var visual_kind: StringName = &"siege_engine"
var max_health: float = 120.0
var health: float = 120.0
var is_destroyed: bool = false
var collision: CollisionShape3D
var hit_material: StandardMaterial3D
var flash_tween: Tween

func configure(id_value: StringName, kind: StringName, health_value: float = 120.0) -> void:
    objective_id = id_value
    visual_kind = kind
    max_health = health_value
    health = max_health

func _ready() -> void:
    collision_layer = 8
    collision_mask = 0
    monitoring = false
    monitorable = true
    add_to_group("damageable")
    add_to_group("battle_objective")
    _build_visual()
    _build_collision()

func receive_weapon_hit(hit: Variant, _shape_index: int) -> bool:
    return receive_weapon_hit_zone(hit, &"objective")

func receive_weapon_hit_zone(hit: Variant, zone: StringName) -> bool:
    if is_destroyed or zone != &"objective":
        return false
    health = maxf(0.0, health - float(hit.damage))
    _flash()
    if health <= 0.0:
        _destroy()
    return true

func zone_from_shape_index(_shape_index: int) -> StringName:
    return &"objective" if not is_destroyed else StringName()

func zone_world_center_from_shape_index(_shape_index: int) -> Vector3:
    return global_position + Vector3.UP * (1.2 if visual_kind == &"siege_engine" else 0.85)

func zone_radius_from_shape_index(_shape_index: int) -> float:
    return 1.1 if visual_kind == &"siege_engine" else 0.65

func zone_priority_from_shape_index(_shape_index: int) -> float:
    return 0.35

func _build_collision() -> void:
    collision = CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.4, 2.4, 2.2) if visual_kind == &"siege_engine" else Vector3(1.4, 1.8, 1.4)
    collision.shape = shape
    collision.position.y = shape.size.y * 0.5
    add_child(collision)

func _build_visual() -> void:
    var wood := _material(Color(0.24, 0.105, 0.032), 0.78)
    var iron := _material(Color(0.19, 0.21, 0.23), 0.32, 0.76)
    var stone := _material(Color(0.42, 0.36, 0.29), 0.88)
    hit_material = _material(Color(0.62, 0.26, 0.055), 0.70)
    match visual_kind:
        &"signal_fire":
            _box("Brazier", Vector3(1.15, 0.42, 1.15), Vector3(0.0, 0.65, 0.0), stone)
            _box("BrazierStem", Vector3(0.34, 0.76, 0.34), Vector3(0.0, 0.25, 0.0), iron)
            var flame := _material(Color(1.0, 0.20, 0.025), 0.35)
            flame.emission_enabled = true
            flame.emission = Color(1.0, 0.10, 0.01) * 3.2
            _cone("SignalFlame", 0.36, 1.15, Vector3(0.0, 1.42, 0.0), flame)
        _:
            _box("SiegeBase", Vector3(2.5, 0.35, 2.0), Vector3(0.0, 0.22, 0.0), wood)
            _box("FrameL", Vector3(0.24, 2.7, 0.24), Vector3(-0.82, 1.35, 0.0), wood, Vector3(0.0, 0.0, -12.0))
            _box("FrameR", Vector3(0.24, 2.7, 0.24), Vector3(0.82, 1.35, 0.0), wood, Vector3(0.0, 0.0, 12.0))
            _box("ThrowingArm", Vector3(0.22, 2.8, 0.22), Vector3(0.0, 1.65, 0.0), hit_material, Vector3(0.0, 0.0, 28.0))
            _cylinder("WheelL", 0.52, 0.18, Vector3(-1.18, 0.55, 0.0), wood, Vector3(0.0, 0.0, 90.0))
            _cylinder("WheelR", 0.52, 0.18, Vector3(1.18, 0.55, 0.0), wood, Vector3(0.0, 0.0, 90.0))

func _destroy() -> void:
    if is_destroyed:
        return
    is_destroyed = true
    collision_layer = 0
    if collision != null:
        collision.set_deferred("disabled", true)
    destroyed.emit(self, objective_id)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(self, "rotation:z", rotation.z + deg_to_rad(72.0), 0.52)
    tween.tween_property(self, "position:y", position.y - 0.48, 0.52)

func _flash() -> void:
    if hit_material == null:
        return
    if flash_tween != null and flash_tween.is_valid():
        flash_tween.kill()
    var base: Color = Color(0.62, 0.26, 0.055)
    hit_material.albedo_color = Color(1.0, 0.80, 0.30)
    flash_tween = create_tween()
    flash_tween.tween_property(hit_material, "albedo_color", base, 0.15)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _box(node_name: String, size: Vector3, position_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
    var piece := MeshInstance3D.new()
    piece.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    piece.mesh = mesh
    piece.position = position_value
    piece.rotation_degrees = rotation_value
    piece.material_override = material
    add_child(piece)

func _cylinder(node_name: String, radius: float, height: float, position_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
    var piece := MeshInstance3D.new()
    piece.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    piece.mesh = mesh
    piece.position = position_value
    piece.rotation_degrees = rotation_value
    piece.material_override = material
    add_child(piece)

func _cone(node_name: String, radius: float, height: float, position_value: Vector3, material: Material) -> void:
    var piece := MeshInstance3D.new()
    piece.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.0
    mesh.bottom_radius = radius
    mesh.height = height
    piece.mesh = mesh
    piece.position = position_value
    piece.material_override = material
    add_child(piece)
