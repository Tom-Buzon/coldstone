extends SkeletonModifier3D
class_name HopliteAuthoredPoseBridge

var source_skeleton: Skeleton3D
var bone_pairs: Array[Vector2i] = [] # x = target bone, y = source bone
var pair_roles: Array[String] = []
var blend_weight: float = 0.0
var full_body: bool = false
var hips_influence: float = 0.0
var configured: bool = false
var attack_aim_pitch: float = 0.0

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
}

func configure(source: Skeleton3D) -> bool:
    source_skeleton = source
    var target: Skeleton3D = get_skeleton()
    if source_skeleton == null or target == null:
        push_error("[UAL BRIDGE] source/target skeleton missing")
        return false
    bone_pairs.clear()
    pair_roles.clear()

    var target_norm: Dictionary = {}
    var target_semantic: Dictionary = {}
    for i: int in range(target.get_bone_count()):
        var t_name: String = target.get_bone_name(i)
        target_norm[_normalize_bone_name(t_name)] = i
        var key: String = _semantic_key(t_name)
        if key != "" and not target_semantic.has(key):
            target_semantic[key] = i

    var exact_count: int = 0
    var normalized_count: int = 0
    var semantic_count: int = 0
    for s_idx: int in range(source_skeleton.get_bone_count()):
        var s_name: String = source_skeleton.get_bone_name(s_idx)
        var t_idx: int = target.find_bone(s_name)
        if t_idx >= 0:
            exact_count += 1
        else:
            var norm: String = _normalize_bone_name(s_name)
            if target_norm.has(norm):
                t_idx = int(target_norm[norm])
                normalized_count += 1
            else:
                var key: String = _semantic_key(s_name)
                if key != "" and target_semantic.has(key):
                    t_idx = int(target_semantic[key])
                    semantic_count += 1
        if t_idx >= 0:
            var role: String = _bone_role(s_name)
            bone_pairs.append(Vector2i(t_idx, s_idx))
            pair_roles.append(role)

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
        var role_weight: float = blend_weight
        if not full_body:
            if UPPER_ROLES.has(role):
                role_weight = blend_weight
            elif role == "hips" and hips_influence > 0.0:
                role_weight = blend_weight * hips_influence
            else:
                continue
        var target_idx: int = pair.x
        var source_idx: int = pair.y
        if target_idx < 0 or source_idx < 0:
            continue
        var base_q: Quaternion = target.get_bone_pose_rotation(target_idx)
        var source_q: Quaternion = source_skeleton.get_bone_pose_rotation(source_idx)
        var result_q: Quaternion = base_q.slerp(source_q, role_weight)
        var pitch_factor: float = _aim_pitch_factor(role)
        if pitch_factor > 0.0 and absf(attack_aim_pitch) > 0.0001:
            var aim_q := Quaternion(Vector3.RIGHT, attack_aim_pitch * pitch_factor * blend_weight)
            result_q = result_q * aim_q
        target.set_bone_pose_rotation(target_idx, result_q)

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
    var role: String = _bone_role(raw)
    if role == "":
        return ""
    var side: String = _bone_side(raw)
    if role in ["spine", "chest", "neck", "head", "hips", "root"]:
        return role
    return role + ":" + side

func _bone_side(raw: String) -> String:
    var s: String = raw.to_lower()
    if ".r" in s or "_r" in s or "-r" in s or "right" in s or s.ends_with(" r"):
        return "r"
    if ".l" in s or "_l" in s or "-l" in s or "left" in s or s.ends_with(" l"):
        return "l"
    var n: String = _normalize_bone_name(raw)
    if n.ends_with("r"):
        return "r"
    if n.ends_with("l"):
        return "l"
    return ""

func _bone_role(raw: String) -> String:
    var n: String = _normalize_bone_name(raw)
    if "hand" in n and not "finger" in n and not "thumb" in n:
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
    if "thigh" in n or "upperleg" in n:
        return "thigh"
    if "shin" in n or "calf" in n or "lowerleg" in n:
        return "shin"
    if "foot" in n and not "toe" in n:
        return "foot"
    if "toe" in n:
        return "toe"
    if n == "root" or n.ends_with("root"):
        return "root"
    return ""
