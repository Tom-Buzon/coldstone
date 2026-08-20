extends Area3D
class_name HopliteAnatomyHitbox

var enemy_owner: Node = null
var skeleton: Skeleton3D = null
var zone_defs: Dictionary = {}
var zone_runtime: Dictionary = {}
var debug_missing_bones: Array[String] = []
var debug_visible: bool = false

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

func _physics_process(_delta: float) -> void:
    if skeleton == null:
        return
    for raw_zone: Variant in zone_runtime.keys():
        _update_zone_shape(StringName(raw_zone))

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

    var debug_mesh := MeshInstance3D.new()
    debug_mesh.name = "Debug_%s" % String(zone)
    debug_mesh.visible = debug_visible
    debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(debug_mesh)

    zone_runtime[zone] = {
        "collision": collision,
        "debug_mesh": debug_mesh,
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
    _rebuild_debug_mesh(zone)

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

    var a_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(bone_a).origin)
    var shape_kind: StringName = StringName(runtime.get("shape", &"sphere"))

    if shape_kind == &"capsule" and bone_b >= 0:
        var b_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(bone_b).origin)
        var segment: Vector3 = b_world - a_world
        var length: float = segment.length()
        if length < 0.05:
            collision.global_position = a_world
            if debug_mesh != null:
                debug_mesh.global_position = a_world
            return

        var radius: float = float(runtime.get("radius", 0.16))
        var capsule := collision.shape as CapsuleShape3D
        if capsule != null:
            capsule.radius = radius
            # CapsuleShape3D.height includes both hemispheres. Add the diameters
            # so the hit volume truly spans from bone A all the way to bone B.
            capsule.height = maxf(length + radius * 2.0, radius * 2.05)
        var transform := Transform3D(_basis_y_along(segment), a_world.lerp(b_world, 0.5))
        collision.global_transform = transform
        if debug_mesh != null:
            debug_mesh.global_transform = transform
        runtime["length"] = length
    else:
        collision.global_transform = Transform3D(Basis.IDENTITY, a_world)
        if debug_mesh != null:
            debug_mesh.global_transform = collision.global_transform
        runtime["length"] = float(runtime.get("radius", 0.16)) * 2.0

    zone_runtime[zone] = runtime
    _rebuild_debug_mesh(zone)

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
    if enemy_owner != null and enemy_owner.has_method("receive_anatomy_hit"):
        enemy_owner.call("receive_anatomy_hit", hit, zone)
        return true
    return false

func zone_from_shape_index(shape_index: int) -> StringName:
    if shape_index < 0:
        return StringName()
    var owner_id: int = shape_find_owner(shape_index)
    if owner_id < 0:
        return StringName()
    var owner_node: Object = shape_owner_get_owner(owner_id)
    if owner_node is CollisionShape3D:
        var collision := owner_node as CollisionShape3D
        return StringName(collision.get_meta("damage_zone", StringName()))
    return StringName()

func zone_world_center_from_shape_index(shape_index: int) -> Vector3:
    return get_zone_world_center(zone_from_shape_index(shape_index))

func zone_radius_from_shape_index(shape_index: int) -> float:
    return get_zone_radius(zone_from_shape_index(shape_index))

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

func get_zone_length(zone: StringName) -> float:
    if not zone_runtime.has(zone):
        return 0.32
    return float((zone_runtime[zone] as Dictionary).get("length", 0.32))

func set_debug_visible(enabled: bool) -> void:
    debug_visible = enabled
    for raw_zone: Variant in zone_runtime.keys():
        var runtime: Dictionary = zone_runtime[raw_zone]
        var debug_mesh: MeshInstance3D = runtime.get("debug_mesh") as MeshInstance3D
        if debug_mesh != null:
            debug_mesh.visible = enabled and not bool(runtime.get("disabled", false))

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

func _rebuild_debug_mesh(zone: StringName) -> void:
    if not zone_runtime.has(zone):
        return
    var runtime: Dictionary = zone_runtime[zone]
    var debug_mesh: MeshInstance3D = runtime.get("debug_mesh") as MeshInstance3D
    if debug_mesh == null:
        return

    var radius: float = float(runtime.get("radius", 0.16))
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
