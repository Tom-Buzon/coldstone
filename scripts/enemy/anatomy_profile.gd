extends Resource
class_name HopliteAnatomyProfile

# Reusable humanoid anatomy profile.
# Bone candidate lists accept common UE / Mixamo / generic humanoid names so
# the same combat system can be reused on future human characters.
# target_priority is used only when several anatomy shapes overlap the sword in
# the same sweep: small intentional targets win over large torso volumes.

static func default_humanoid() -> Dictionary:
    return {
        &"head": {
            "bone_a": ["head"],
            "bone_b": [],
            "shape": &"sphere",
            "radius": 0.25,
            "damage_mult": 1.70,
            "sever_mult": 1.00,
            "sever_threshold": 64.0,
            "severable": true,
            "fatal_sever": true,
            "proxy_zone": &"head",
            "target_priority": 0.95
        },
        &"neck": {
            "bone_a": ["neck", "neck_01", "neck01"],
            "bone_b": ["head"],
            "shape": &"capsule",
            "radius": 0.15,
            "damage_mult": 1.85,
            "sever_mult": 1.35,
            "sever_threshold": 56.0,
            "severable": true,
            "fatal_sever": true,
            "sever_target": &"head",
            "proxy_zone": &"head",
            "target_priority": 1.10
        },
        &"torso": {
            "bone_a": ["spine_01", "spine01", "spine1", "spine"],
            "bone_b": ["spine_03", "spine03", "spine3", "chest", "upperchest", "neck"],
            "shape": &"capsule",
            "radius": 0.34,
            "damage_mult": 1.00,
            "sever_mult": 0.35,
            "sever_threshold": 9999.0,
            "severable": false,
            "fatal_sever": false,
            "proxy_zone": &"torso",
            "target_priority": 0.00
        },
        &"pelvis": {
            "bone_a": ["pelvis", "hips", "hip"],
            "bone_b": ["spine_01", "spine01", "spine1", "spine"],
            "shape": &"capsule",
            "radius": 0.30,
            "damage_mult": 0.95,
            "sever_mult": 0.30,
            "sever_threshold": 9999.0,
            "severable": false,
            "fatal_sever": false,
            "proxy_zone": &"pelvis",
            "target_priority": 0.02
        },
        &"upper_arm_l": _limb(["upperarm_l", "upper_arm_l", "leftupperarm", "arm_l"], ["lowerarm_l", "lower_arm_l", "leftforearm", "forearm_l"], 0.16, 0.78, 1.00, 78.0, 0.34),
        &"forearm_l": _limb(["lowerarm_l", "lower_arm_l", "leftforearm", "forearm_l"], ["hand_l", "lefthand", "wrist_l"], 0.14, 0.75, 1.10, 60.0, 0.46),
        &"upper_arm_r": _limb(["upperarm_r", "upper_arm_r", "rightupperarm", "arm_r"], ["lowerarm_r", "lower_arm_r", "rightforearm", "forearm_r"], 0.16, 0.78, 1.00, 78.0, 0.34),
        &"forearm_r": _limb(["lowerarm_r", "lower_arm_r", "rightforearm", "forearm_r"], ["hand_r", "righthand", "wrist_r"], 0.14, 0.75, 1.10, 60.0, 0.46),
        &"thigh_l": _limb(["thigh_l", "leftupleg", "upperleg_l", "upleg_l"], ["calf_l", "leftleg", "lowerleg_l", "shin_l"], 0.21, 0.88, 0.82, 94.0, 0.22),
        &"shin_l": _limb(["calf_l", "leftleg", "lowerleg_l", "shin_l"], ["foot_l", "leftfoot", "ankle_l"], 0.18, 0.84, 1.05, 72.0, 0.40),
        &"thigh_r": _limb(["thigh_r", "rightupleg", "upperleg_r", "upleg_r"], ["calf_r", "rightleg", "lowerleg_r", "shin_r"], 0.21, 0.88, 0.82, 94.0, 0.22),
        &"shin_r": _limb(["calf_r", "rightleg", "lowerleg_r", "shin_r"], ["foot_r", "rightfoot", "ankle_r"], 0.18, 0.84, 1.05, 72.0, 0.40)
    }

static func _limb(bone_a: Array, bone_b: Array, radius: float, damage_mult: float, sever_mult: float, threshold: float, target_priority: float) -> Dictionary:
    return {
        "bone_a": bone_a,
        "bone_b": bone_b,
        "shape": &"capsule",
        "radius": radius,
        "damage_mult": damage_mult,
        "sever_mult": sever_mult,
        "sever_threshold": threshold,
        "severable": true,
        "fatal_sever": false,
        "proxy_zone": StringName(),
        "target_priority": target_priority
    }
