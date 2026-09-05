extends RefCounted
class_name HopliteSpartanCharacterPackage

# Runtime adapter for the stable package emitted by 3DGen Studio. Gameplay only
# relies on the schema metadata and these names; it never depends on glTF indices.
const EXPECTED_SCHEMA: int = 1
const EXPECTED_RIG: String = "spartan_ual1_v1"
const EXPECTED_BONE_COUNT: int = 53
const BODY_ZONE_SHADER := preload("res://assets/shaders/hoplite_body_zones.gdshader")

const BODY_ZONE_ORDER: Array[StringName] = [
    &"torso", &"head", &"upper_arm_l", &"forearm_l", &"upper_arm_r",
    &"forearm_r", &"thigh_l", &"shin_l", &"thigh_r", &"shin_r",
]

const ZONE_PARTS := {
    &"torso": "SPARTAN_body_torso",
    &"head": "SPARTAN_body_head",
    &"upper_arm_l": "SPARTAN_body_upper_arm_l",
    &"forearm_l": "SPARTAN_body_forearm_l",
    &"upper_arm_r": "SPARTAN_body_upper_arm_r",
    &"forearm_r": "SPARTAN_body_forearm_r",
    &"thigh_l": "SPARTAN_body_thigh_l",
    &"shin_l": "SPARTAN_body_shin_l",
    &"thigh_r": "SPARTAN_body_thigh_r",
    &"shin_r": "SPARTAN_body_shin_r",
}

const ZONE_BONES := {
    &"head": "DEF-head",
    &"upper_arm_l": "DEF-upper_arm.L",
    &"forearm_l": "DEF-forearm.L",
    &"upper_arm_r": "DEF-upper_arm.R",
    &"forearm_r": "DEF-forearm.R",
    &"thigh_l": "DEF-thigh.L",
    &"shin_l": "DEF-shin.L",
    &"thigh_r": "DEF-thigh.R",
    &"shin_r": "DEF-shin.R",
}

const ZONE_DESCENDANTS := {
    &"head": [],
    &"upper_arm_l": [&"forearm_l"],
    &"forearm_l": [],
    &"upper_arm_r": [&"forearm_r"],
    &"forearm_r": [],
    &"thigh_l": [&"shin_l"],
    &"shin_l": [],
    &"thigh_r": [&"shin_r"],
    &"shin_r": [],
}

const ESSENTIAL_BONES: Array[String] = [
    "root", "DEF-hips", "DEF-spine.001", "DEF-spine.002",
    "DEF-spine.003", "DEF-neck", "DEF-head", "DEF-hand.L", "DEF-hand.R",
    "DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
    "DEF-thigh.L", "DEF-shin.L", "DEF-thigh.R", "DEF-shin.R",
]

var package_root: Node3D
var asset_root: Node3D
var skeleton: Skeleton3D
var body_parts: Dictionary = {}
var body_caps: Dictionary = {}
var limb_caps: Dictionary = {}
var merged_body: MeshInstance3D
var merged_body_material: ShaderMaterial
var body_zone_visibility: Dictionary = {}
var validation_error: String = ""
static var shared_merged_body_mesh: ArrayMesh
var pose_copy_source_indices := PackedInt32Array()

func bind(root: Node) -> bool:
    validation_error = ""
    body_parts.clear()
    body_caps.clear()
    limb_caps.clear()
    body_zone_visibility.clear()
    merged_body = null
    merged_body_material = null
    pose_copy_source_indices.clear()
    package_root = root as Node3D
    if package_root == null:
        return _fail("package root is not Node3D")

    asset_root = package_root.find_child("SPARTAN_ASSET", true, false) as Node3D
    skeleton = package_root.find_child("Skeleton3D", true, false) as Skeleton3D
    if asset_root == null:
        return _fail("SPARTAN_ASSET is missing")
    if skeleton == null:
        return _fail("Skeleton3D is missing")

    var extras: Dictionary = asset_root.get_meta("extras", {}) as Dictionary
    if int(extras.get("spartan_schema", -1)) != EXPECTED_SCHEMA:
        return _fail("unsupported spartan_schema")
    if String(extras.get("spartan_rig", "")) != EXPECTED_RIG:
        return _fail("unsupported spartan_rig")
    if skeleton.get_bone_count() != EXPECTED_BONE_COUNT:
        return _fail("expected %d bones, got %d" % [EXPECTED_BONE_COUNT, skeleton.get_bone_count()])
    for bone_name: String in ESSENTIAL_BONES:
        if skeleton.find_bone(bone_name) < 0:
            return _fail("essential bone missing: %s" % bone_name)

    for raw_zone: Variant in ZONE_PARTS.keys():
        var zone := StringName(raw_zone)
        var part := package_root.find_child(String(ZONE_PARTS[zone]), true, false) as MeshInstance3D
        if part == null:
            return _fail("body part missing for %s" % String(zone))
        body_parts[zone] = part

    for raw_zone: Variant in ZONE_BONES.keys():
        var zone := StringName(raw_zone)
        var body_cap_name := "SPARTAN_gore_cap_%s_body" % String(zone)
        var limb_cap_name := "SPARTAN_gore_cap_%s_limb" % String(zone)
        var body_cap := package_root.find_child(body_cap_name, true, false) as MeshInstance3D
        var limb_cap := package_root.find_child(limb_cap_name, true, false) as MeshInstance3D
        if body_cap == null or limb_cap == null:
            return _fail("gore caps missing for %s" % String(zone))
        body_caps[zone] = body_cap
        limb_caps[zone] = limb_cap

    _prepare_caps(body_caps, "BodyCapAttachment")
    _prepare_caps(limb_caps, "LimbCapAttachment")
    hide_all_caps()
    return true

func optimize_body_meshes() -> bool:
    if merged_body != null:
        return true
    if skeleton == null or body_parts.size() != BODY_ZONE_ORDER.size():
        return false
    var reference := body_parts.get(BODY_ZONE_ORDER[0]) as MeshInstance3D
    if reference == null or reference.mesh == null or reference.mesh.get_surface_count() != 1:
        return false
    var shared_skin: Skin = reference.skin
    if shared_merged_body_mesh == null:
        shared_merged_body_mesh = _build_shared_body_mesh(shared_skin)
    if shared_merged_body_mesh == null:
        return false
    merged_body_material = _make_merged_body_material(reference.get_active_material(0))
    merged_body = MeshInstance3D.new()
    merged_body.name = "SPARTAN_body_merged"
    merged_body.mesh = shared_merged_body_mesh
    merged_body.material_override = merged_body_material
    merged_body.skin = shared_skin
    merged_body.cast_shadow = reference.cast_shadow
    merged_body.layers = reference.layers
    merged_body.visibility_range_begin = reference.visibility_range_begin
    merged_body.visibility_range_end = reference.visibility_range_end
    merged_body.visibility_range_begin_margin = reference.visibility_range_begin_margin
    merged_body.visibility_range_end_margin = reference.visibility_range_end_margin
    merged_body.visibility_range_fade_mode = reference.visibility_range_fade_mode
    skeleton.add_child(merged_body)
    # Resolve the Skeleton3D path only after the merged mesh has entered the
    # same scene branch. Copying ".." before parenting can leave GLES3 with a
    # valid-looking NodePath but no live SkinReference, so attachments animate
    # while the body remains in bind pose.
    merged_body.skeleton = merged_body.get_path_to(skeleton)
    for zone: StringName in BODY_ZONE_ORDER:
        body_zone_visibility[zone] = true
    _sync_body_zone_visibility()
    for part_value: Variant in body_parts.values():
        var part := part_value as MeshInstance3D
        if part != null:
            part.free()
    body_parts.clear()
    return true

func _build_shared_body_mesh(shared_skin: Skin) -> ArrayMesh:
    var surface_tool := SurfaceTool.new()
    var lod_sources: Array[Dictionary] = []
    var lod_thresholds: Array[float] = []
    var vertex_offset := 0
    for zone_index: int in range(BODY_ZONE_ORDER.size()):
        var zone: StringName = BODY_ZONE_ORDER[zone_index]
        var part := body_parts.get(zone) as MeshInstance3D
        if part == null or part.mesh == null or part.mesh.get_surface_count() != 1 or part.skin != shared_skin:
            return null
        var arrays: Array = part.mesh.surface_get_arrays(0).duplicate(true)
        var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
        var base_indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
        if vertices.is_empty() or base_indices.is_empty():
            return null
        var colors := PackedColorArray()
        colors.resize(vertices.size())
        colors.fill(Color((float(zone_index) + 0.5) / 10.0, 0.0, 0.0, 1.0))
        arrays[Mesh.ARRAY_COLOR] = colors
        var zone_mesh := ArrayMesh.new()
        zone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        var relative_transform: Transform3D = skeleton.global_transform.affine_inverse() * part.global_transform
        surface_tool.append_from(zone_mesh, 0, relative_transform)
        lod_sources.append(_lod_source_for(part.mesh, vertex_offset, base_indices, lod_thresholds))
        vertex_offset += vertices.size()

    var combined := surface_tool.commit() as ArrayMesh
    if combined == null or combined.get_surface_count() != 1:
        return null
    var combined_arrays: Array = combined.surface_get_arrays(0)
    var combined_vertices := combined_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
    if combined_vertices.size() != vertex_offset:
        return null
    var with_lods := ArrayMesh.new()
    with_lods.add_surface_from_arrays(
        Mesh.PRIMITIVE_TRIANGLES,
        combined_arrays,
        [],
        _build_combined_lods(lod_sources, lod_thresholds)
    )
    with_lods.resource_name = "HopliteMergedBody"
    return with_lods

func _lod_source_for(mesh: Mesh, vertex_offset: int, base_indices: PackedInt32Array, thresholds: Array[float]) -> Dictionary:
    var result := {"offset": vertex_offset, "base": base_indices, "lods": []}
    var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
    var index_data := surface.get("index_data", PackedByteArray()) as PackedByteArray
    var index_count := int(surface.get("index_count", 0))
    var index_stride := index_data.size() / index_count if index_count > 0 else 4
    var decoded_lods: Array[Dictionary] = []
    for raw_lod: Variant in surface.get("lods", []):
        var lod := raw_lod as Dictionary
        var edge_length := float(lod.get("edge_length", 0.0))
        var lod_data := lod.get("index_data", PackedByteArray()) as PackedByteArray
        if edge_length <= 0.0 or lod_data.is_empty():
            continue
        decoded_lods.append({"edge": edge_length, "indices": _decode_lod_indices(lod_data, index_stride)})
        if not thresholds.has(edge_length):
            thresholds.append(edge_length)
    decoded_lods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["edge"]) < float(b["edge"]))
    result["lods"] = decoded_lods
    return result

func _build_combined_lods(sources: Array[Dictionary], thresholds: Array[float]) -> Dictionary:
    thresholds.sort()
    var result: Dictionary = {}
    for threshold: float in thresholds:
        var combined_indices := PackedInt32Array()
        for source: Dictionary in sources:
            var selected := source.get("base") as PackedInt32Array
            for lod: Dictionary in source.get("lods", []):
                if float(lod.get("edge", INF)) <= threshold + 0.000001:
                    selected = lod.get("indices") as PackedInt32Array
                else:
                    break
            var offset := int(source.get("offset", 0))
            for source_index: int in selected:
                combined_indices.append(source_index + offset)
        result[threshold] = combined_indices
    return result

func _decode_lod_indices(data: PackedByteArray, stride: int) -> PackedInt32Array:
    var safe_stride := 2 if stride == 2 else 4
    var result := PackedInt32Array()
    result.resize(data.size() / safe_stride)
    for index: int in range(result.size()):
        result[index] = data.decode_u16(index * safe_stride) if safe_stride == 2 else data.decode_u32(index * safe_stride)
    return result

func normalize_cut_zone(zone: StringName) -> StringName:
    return &"head" if zone == &"neck" else zone

func sever_body(zone: StringName) -> bool:
    zone = normalize_cut_zone(zone)
    if not ZONE_PARTS.has(zone) or not body_caps.has(zone):
        return false
    if merged_body != null:
        for branch_zone: StringName in branch_for(zone):
            body_zone_visibility[branch_zone] = false
        _sync_body_zone_visibility()
        _show_cap(body_caps.get(zone) as MeshInstance3D)
        return true
    for branch_zone: StringName in branch_for(zone):
        var part := body_parts.get(branch_zone) as MeshInstance3D
        if part != null:
            part.visible = false
    _show_cap(body_caps.get(zone) as MeshInstance3D)
    return true

func show_detached_branch(zone: StringName) -> bool:
    zone = normalize_cut_zone(zone)
    if not ZONE_PARTS.has(zone) or not limb_caps.has(zone):
        return false
    if merged_body != null:
        for body_zone: StringName in BODY_ZONE_ORDER:
            body_zone_visibility[body_zone] = false
        for branch_zone: StringName in branch_for(zone):
            body_zone_visibility[branch_zone] = true
        _sync_body_zone_visibility()
        hide_all_caps()
        _show_cap(limb_caps.get(zone) as MeshInstance3D)
        return true
    for part_value: Variant in body_parts.values():
        var part := part_value as MeshInstance3D
        if part != null:
            part.visible = false
    hide_all_caps()
    for branch_zone: StringName in branch_for(zone):
        var branch_part := body_parts.get(branch_zone) as MeshInstance3D
        if branch_part != null:
            branch_part.visible = true
    _show_cap(limb_caps.get(zone) as MeshInstance3D)
    return true

func branch_for(zone: StringName) -> Array[StringName]:
    zone = normalize_cut_zone(zone)
    var result: Array[StringName] = [zone]
    var descendants: Array = ZONE_DESCENDANTS.get(zone, []) as Array
    for descendant: Variant in descendants:
        result.append(StringName(descendant))
    return result

func hide_all_caps() -> void:
    for cap_value: Variant in body_caps.values():
        _hide_cap(cap_value as MeshInstance3D)
    for cap_value: Variant in limb_caps.values():
        _hide_cap(cap_value as MeshInstance3D)

func copy_pose_from(source: Skeleton3D) -> bool:
    if source == null or skeleton == null:
        return false
    if pose_copy_source_indices.size() != skeleton.get_bone_count():
        pose_copy_source_indices.resize(skeleton.get_bone_count())
        for target_index: int in range(skeleton.get_bone_count()):
            pose_copy_source_indices[target_index] = source.find_bone(skeleton.get_bone_name(target_index))
            if pose_copy_source_indices[target_index] < 0:
                pose_copy_source_indices.clear()
                return false
    for target_index: int in range(pose_copy_source_indices.size()):
        var source_index := pose_copy_source_indices[target_index]
        skeleton.set_bone_pose_position(target_index, source.get_bone_pose_position(source_index))
        skeleton.set_bone_pose_rotation(target_index, source.get_bone_pose_rotation(source_index))
        skeleton.set_bone_pose_scale(target_index, source.get_bone_pose_scale(source_index))
    skeleton.force_update_all_bone_transforms()
    return pose_copy_source_indices.size() == EXPECTED_BONE_COUNT

func _prepare_caps(caps: Dictionary, attachment_prefix: String) -> void:
    for raw_zone: Variant in caps.keys():
        var zone := StringName(raw_zone)
        var cap := caps[zone] as MeshInstance3D
        if cap == null:
            continue
        # Generated caps are rigid meshes. BoneAttachment3D preserves their authored
        # cut transform while making them follow the animated cut bone.
        var preserved_global: Transform3D = cap.global_transform
        var attachment := BoneAttachment3D.new()
        attachment.name = "%s_%s" % [attachment_prefix, String(zone)]
        attachment.bone_name = String(ZONE_BONES[zone])
        skeleton.add_child(attachment)
        cap.reparent(attachment, true)
        cap.global_transform = preserved_global

func _hide_cap(cap: MeshInstance3D) -> void:
    if cap == null:
        return
    cap.visible = false
    cap.scale = Vector3.ZERO

func _show_cap(cap: MeshInstance3D) -> void:
    if cap == null:
        return
    cap.scale = Vector3.ONE
    cap.visible = true

func _make_merged_body_material(source: Material) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = BODY_ZONE_SHADER
    var standard := source as StandardMaterial3D
    if standard != null:
        material.set_shader_parameter("albedo_texture", standard.albedo_texture)
        material.set_shader_parameter("albedo_color", standard.albedo_color)
        material.set_shader_parameter("roughness", standard.roughness)
        material.set_shader_parameter("metallic", standard.metallic)
    return material

func _sync_body_zone_visibility() -> void:
    if merged_body_material == null:
        return
    var values := PackedFloat32Array()
    values.resize(BODY_ZONE_ORDER.size())
    for index: int in range(BODY_ZONE_ORDER.size()):
        values[index] = 1.0 if bool(body_zone_visibility.get(BODY_ZONE_ORDER[index], true)) else 0.0
    merged_body_material.set_shader_parameter("zone_visibility_0", Vector4(values[0], values[1], values[2], values[3]))
    merged_body_material.set_shader_parameter("zone_visibility_1", Vector4(values[4], values[5], values[6], values[7]))
    merged_body_material.set_shader_parameter("zone_visibility_2", Vector2(values[8], values[9]))

func _fail(message: String) -> bool:
    validation_error = message
    return false
