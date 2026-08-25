extends RefCounted
class_name HopliteSpartanCharacterPackage

# Runtime adapter for the stable package emitted by 3DGen Studio. Gameplay only
# relies on the schema metadata and these names; it never depends on glTF indices.
const EXPECTED_SCHEMA: int = 1
const EXPECTED_RIG: String = "spartan_ual1_v1"
const EXPECTED_BONE_COUNT: int = 53

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
var validation_error: String = ""

func bind(root: Node) -> bool:
    validation_error = ""
    body_parts.clear()
    body_caps.clear()
    limb_caps.clear()
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

func normalize_cut_zone(zone: StringName) -> StringName:
    return &"head" if zone == &"neck" else zone

func sever_body(zone: StringName) -> bool:
    zone = normalize_cut_zone(zone)
    if not body_parts.has(zone) or not body_caps.has(zone):
        return false
    for branch_zone: StringName in branch_for(zone):
        var part := body_parts.get(branch_zone) as MeshInstance3D
        if part != null:
            part.visible = false
    _show_cap(body_caps.get(zone) as MeshInstance3D)
    return true

func show_detached_branch(zone: StringName) -> bool:
    zone = normalize_cut_zone(zone)
    if not body_parts.has(zone) or not limb_caps.has(zone):
        return false
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
    var copied: int = 0
    for source_index: int in range(source.get_bone_count()):
        var target_index: int = skeleton.find_bone(source.get_bone_name(source_index))
        if target_index < 0:
            continue
        skeleton.set_bone_pose_position(target_index, source.get_bone_pose_position(source_index))
        skeleton.set_bone_pose_rotation(target_index, source.get_bone_pose_rotation(source_index))
        skeleton.set_bone_pose_scale(target_index, source.get_bone_pose_scale(source_index))
        copied += 1
    skeleton.force_update_all_bone_transforms()
    return copied == EXPECTED_BONE_COUNT

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

func _fail(message: String) -> bool:
    validation_error = message
    return false
