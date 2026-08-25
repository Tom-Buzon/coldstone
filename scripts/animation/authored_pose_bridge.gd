extends SkeletonModifier3D
class_name HopliteAuthoredPoseBridge

var source_skeleton: Skeleton3D
var bone_pairs: Array[Vector2i] = [] # x = target bone, y = source bone
var pair_roles: Array[String] = []
var mirrored_source_indices: Array[int] = []
var blend_weight: float = 0.0
var full_body: bool = false
var hips_influence: float = 0.0
var configured: bool = false
var attack_aim_pitch: float = 0.0
var rest_space_retarget: bool = false
var ignore_source_root_rotation: bool = false
var scale_full_body_hips: bool = false
var include_finger_bones: bool = false
var pose_mirrored: bool = false

# This bridge intentionally copies rotations only. Positional/root tracks are
# excluded so donor animations can never move the visible character away from
# the CharacterBody. Visual grounding for Slide is handled in player.gd.
const UPPER_ROLES := {
    "spine": true,
    "chest": true,
    "neck": true,
    "head": true,
    "shoulder": true,
    "upper_arm": true,
    "forearm": true,
    "hand": true,
    "finger": true,
}

func configure(source: Skeleton3D, include_fingers: bool = false) -> bool:
    source_skeleton = source
    include_finger_bones = include_fingers
    var target: Skeleton3D = get_skeleton()
    if source_skeleton == null or target == null:
        push_error("[UAL BRIDGE] source/target skeleton missing")
        return false
    bone_pairs.clear()
    pair_roles.clear()
    mirrored_source_indices.clear()

    var target_norm: Dictionary = {}
    var target_semantic: Dictionary = {}
    for i: int in range(target.get_bone_count()):
        var t_name: String = target.get_bone_name(i)
        target_norm[_normalize_bone_name(t_name)] = i
        var key: String = _semantic_key(t_name)
        if key != "":
            if not target_semantic.has(key):
                target_semantic[key] = []
            var semantic_targets: Array = target_semantic[key]
            semantic_targets.append(i)

    var exact_count: int = 0
    var normalized_count: int = 0
    var semantic_count: int = 0
    var semantic_cursor: Dictionary = {}
    var used_target_bones: Dictionary = {}
    for s_idx: int in range(source_skeleton.get_bone_count()):
        var s_name: String = source_skeleton.get_bone_name(s_idx)
        var t_idx: int = target.find_bone(s_name)
        if t_idx >= 0 and not used_target_bones.has(t_idx):
            exact_count += 1
        else:
            t_idx = -1
            var norm: String = _normalize_bone_name(s_name)
            if target_norm.has(norm) and not used_target_bones.has(int(target_norm[norm])):
                t_idx = int(target_norm[norm])
                normalized_count += 1
            else:
                var key: String = _semantic_key(s_name)
                if key != "" and target_semantic.has(key):
                    var semantic_targets: Array = target_semantic[key]
                    var cursor: int = int(semantic_cursor.get(key, 0))
                    while cursor < semantic_targets.size() and used_target_bones.has(int(semantic_targets[cursor])):
                        cursor += 1
                    if cursor < semantic_targets.size():
                        t_idx = int(semantic_targets[cursor])
                        semantic_cursor[key] = cursor + 1
                        semantic_count += 1
        if t_idx >= 0:
            var role: String = _bone_role(s_name)
            bone_pairs.append(Vector2i(t_idx, s_idx))
            pair_roles.append(role)
            used_target_bones[t_idx] = true

    _build_mirrored_source_indices()

    configured = not bone_pairs.is_empty()
    active = configured
    influence = 1.0
    print("[UAL BRIDGE] mapped bones=", bone_pairs.size(), " exact=", exact_count, " normalized=", normalized_count, " semantic=", semantic_count)
    if bone_pairs.size() < 12:
        print("[UAL BRIDGE] WARNING: low mapping count. SOURCE BONES:")
        for i: int in range(source_skeleton.get_bone_count()):
            print("  SRC ", i, " ", source_skeleton.get_bone_name(i))
        print("[UAL BRIDGE] TARGET BONES:")
        for i: int in range(target.get_bone_count()):
            print("  DST ", i, " ", target.get_bone_name(i))
    return configured

func set_attack_weight(value: float, use_full_body: bool = false, hips_weight: float = 0.0) -> void:
    blend_weight = clampf(value, 0.0, 1.0)
    full_body = use_full_body
    hips_influence = clampf(hips_weight, 0.0, 1.0)

func set_attack_aim_pitch(value: float) -> void:
    attack_aim_pitch = clampf(value, -0.90, 0.65)

func set_rest_space_retarget(enabled: bool) -> void:
    # Exact-name rigs can still encode their glTF axis conversion in different
    # local rest bones. Converting through rest space avoids applying that axis
    # correction twice (most visibly on root/hips).
    rest_space_retarget = enabled

func set_mixamo_runtime_guards(ignore_root: bool, weighted_hips: bool) -> void:
    # These guards are opt-in. UAL/player and enemy bridges historically rely
    # on their complete authored full-body pose and must not be changed by a
    # Mixamo-specific workaround.
    ignore_source_root_rotation = ignore_root
    scale_full_body_hips = weighted_hips

func set_pose_mirrored(enabled: bool) -> void:
    pose_mirrored = enabled

func _aim_pitch_factor(role: String) -> float:
    # Distribute camera pitch instead of rotating the whole mannequin. Several
    # spine bones may map to the same semantic role, so each receives only a
    # fraction; chest/neck finish the arc and the feet stay planted.
    match role:
        "spine": return 0.18
        "chest": return 0.30
        "neck": return 0.08
        "shoulder": return 0.04
        _: return 0.0

func _process_modification_with_delta(_delta: float) -> void:
    if not configured or source_skeleton == null or blend_weight <= 0.0001:
        return
    var target: Skeleton3D = get_skeleton()
    if target == null:
        return
    for idx: int in range(bone_pairs.size()):
        var pair: Vector2i = bone_pairs[idx]
        var role: String = pair_roles[idx]
        # Root rotation from imported FBX files commonly contains the package's
        # axis conversion. CharacterBody3D owns world orientation and movement.
        if role == "root" and ignore_source_root_rotation:
            continue
        var role_weight: float = blend_weight
        if full_body:
            if role == "hips" and scale_full_body_hips:
                role_weight = blend_weight * hips_influence
        else:
            if UPPER_ROLES.has(role):
                role_weight = blend_weight
            elif role == "hips" and hips_influence > 0.0:
                role_weight = blend_weight * hips_influence
            else:
                continue
        var target_idx: int = pair.x
        var source_idx: int = mirrored_source_indices[idx] if pose_mirrored and idx < mirrored_source_indices.size() else pair.y
        if target_idx < 0 or source_idx < 0:
            continue
        var base_q: Quaternion = target.get_bone_pose_rotation(target_idx)
        var source_q: Quaternion = source_skeleton.get_bone_pose_rotation(source_idx)
        if rest_space_retarget:
            var target_rest_q: Quaternion = target.get_bone_rest(target_idx).basis.get_rotation_quaternion()
            var source_rest_q: Quaternion = source_skeleton.get_bone_rest(source_idx).basis.get_rotation_quaternion()
            # Godot 4 Bone Pose includes Bone Rest (unlike Godot 3). Remove the
            # donor rest orientation from its absolute local pose, then apply
            # the resulting motion on top of the target rest orientation.
            source_q = target_rest_q * source_rest_q.inverse() * source_q
        if pose_mirrored:
            # Reflection across the character's local X axis. Side-specific
            # bones are read from their opposite counterpart first, then the
            # local rotation is reflected so hands, feet and torso lean all
            # remain coherent instead of merely swapping limb tracks.
            source_q = Quaternion(source_q.x, -source_q.y, -source_q.z, source_q.w).normalized()
        var result_q: Quaternion = base_q.slerp(source_q, role_weight)
        var pitch_factor: float = _aim_pitch_factor(role)
        if pitch_factor > 0.0 and absf(attack_aim_pitch) > 0.0001:
            var aim_q := Quaternion(Vector3.RIGHT, attack_aim_pitch * pitch_factor * blend_weight)
            result_q = result_q * aim_q
        target.set_bone_pose_rotation(target_idx, result_q)

func _build_mirrored_source_indices() -> void:
    var sources_by_role_side: Dictionary = {}
    for source_idx: int in range(source_skeleton.get_bone_count()):
        var source_name: String = source_skeleton.get_bone_name(source_idx)
        var role: String = _bone_role(source_name)
        var side: String = _bone_side(source_name)
        if role == "" or not side in ["l", "r"]:
            continue
        var key: String = role + ":" + side
        if not sources_by_role_side.has(key):
            sources_by_role_side[key] = []
        var side_sources: Array = sources_by_role_side[key]
        side_sources.append(source_idx)

    for pair: Vector2i in bone_pairs:
        var source_idx: int = pair.y
        var source_name: String = source_skeleton.get_bone_name(source_idx)
        var role: String = _bone_role(source_name)
        var side: String = _bone_side(source_name)
        if role == "" or not side in ["l", "r"]:
            mirrored_source_indices.append(source_idx)
            continue
        var same_key: String = role + ":" + side
        var opposite_key: String = role + ":" + ("r" if side == "l" else "l")
        var same_sources: Array = sources_by_role_side.get(same_key, [])
        var opposite_sources: Array = sources_by_role_side.get(opposite_key, [])
        var ordinal: int = same_sources.find(source_idx)
        if ordinal >= 0 and ordinal < opposite_sources.size():
            mirrored_source_indices.append(int(opposite_sources[ordinal]))
        else:
            mirrored_source_indices.append(source_idx)

func _normalize_bone_name(raw: String) -> String:
    var s: String = raw.to_lower().strip_edges()
    for prefix: String in ["def-", "org-", "mch-", "def_", "org_", "mch_", "mixamorig_", "mixamorig:", "mixamorig"]:
        if s.begins_with(prefix):
            s = s.substr(prefix.length())
            break
    s = s.replace("left", "l").replace("right", "r")
    for ch: String in [".", "_", "-", " ", ":"]:
        s = s.replace(ch, "")
    return s

func _semantic_key(raw: String) -> String:
    if include_finger_bones:
        var finger_key := _finger_semantic_key(raw)
        if finger_key != "":
            return finger_key
        var torso_key := _torso_semantic_key(raw)
        if torso_key != "":
            return torso_key
    var role: String = _bone_role(raw)
    if role == "":
        return ""
    var side: String = _bone_side(raw)
    if role in ["spine", "chest", "neck", "head", "hips", "root"]:
        return role
    return role + ":" + side

func _bone_side(raw: String) -> String:
    var s: String = raw.to_lower()
    if s.ends_with(".r") or s.ends_with("_r") or s.ends_with("-r") or "right" in s or s.ends_with(" r"):
        return "r"
    if s.ends_with(".l") or s.ends_with("_l") or s.ends_with("-l") or "left" in s or s.ends_with(" l"):
        return "l"
    var n: String = _normalize_bone_name(raw)
    if n.ends_with("r"):
        return "r"
    if n.ends_with("l"):
        return "l"
    return ""

func _bone_role(raw: String) -> String:
    var n: String = _normalize_bone_name(raw)
    if include_finger_bones and _is_finger_bone(n):
        return "finger"
    if "hand" in n and not _is_finger_bone(n):
        return "hand"
    if "forearm" in n or "lowerarm" in n:
        return "forearm"
    if "upperarm" in n or ("arm" in n and not "forearm" in n and not "lowerarm" in n):
        return "upper_arm"
    if "shoulder" in n or "clavicle" in n:
        return "shoulder"
    if "head" in n:
        return "head"
    if "neck" in n:
        return "neck"
    if "chest" in n or "upperchest" in n:
        return "chest"
    if "spine" in n:
        return "spine"
    if "hips" in n or "pelvis" in n:
        return "hips"
    if "thigh" in n or "upperleg" in n or "upleg" in n:
        return "thigh"
    if "shin" in n or "calf" in n or "lowerleg" in n or ("leg" in n and not "upleg" in n):
        return "shin"
    if "foot" in n and not "toe" in n:
        return "foot"
    if "toe" in n:
        return "toe"
    if n == "root" or n.ends_with("root"):
        return "root"
    return ""

func _is_finger_bone(normalized_name: String) -> bool:
    for token: String in ["finger", "thumb", "index", "middle", "ring", "little", "pinky"]:
        if token in normalized_name:
            return true
    return false

func _torso_semantic_key(raw: String) -> String:
    var n := _normalize_bone_name(raw)
    if n == "spine" or n.ends_with("spine001"):
        return "spine:1"
    if n == "chest" or n.ends_with("spine002"):
        return "spine:2"
    if n == "upperchest" or n.ends_with("spine003"):
        return "spine:3"
    return ""

func _finger_semantic_key(raw: String) -> String:
    var n := _normalize_bone_name(raw)
    if not _is_finger_bone(n):
        return ""
    var digit := ""
    for candidate: String in ["thumb", "index", "middle", "ring", "little", "pinky"]:
        if candidate in n:
            digit = "little" if candidate == "pinky" else candidate
            break
    if digit == "":
        return ""
    var segment := 0
    if "metacarpal" in n:
        segment = 1
    elif "proximal" in n:
        segment = 2 if digit == "thumb" else 1
    elif "intermediate" in n:
        segment = 2
    elif "distal" in n:
        segment = 3
    else:
        for candidate_segment: int in [1, 2, 3]:
            if str(candidate_segment) in n:
                segment = candidate_segment
                break
    if segment == 0:
        return ""
    return "finger:%s:%s:%d" % [digit, _bone_side(raw), segment]
