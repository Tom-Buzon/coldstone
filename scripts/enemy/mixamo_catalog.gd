extends RefCounted
class_name HopliteMixamoCatalog

const MODEL_ROOT := "res://assets/runtime/mixamo/models/"
const ANIMATION_ROOT := "res://assets/runtime/mixamo/animations/"
const GLOBAL_MODEL_SCALE := 1.18
const GLOBAL_GROUND_OFFSET := -0.055

const MODEL_POOLS: Dictionary = {
    &"swordsman": [&"smallsbir1", &"smallsbir3", &"smallsbir6"],
    &"guardian": [&"smallsbir5", &"smallsbir3"],
    &"spearman": [&"smallsbir2", &"sorcer1"],
    &"flanker": [&"smallsbir4", &"kamikaze1", &"smallsbir1"],
    &"brute": [&"bossmonster1", &"bossmonster2", &"bossmonster3"],
    &"captain": [&"knight1", &"knight2", &"knight3"],
    &"warlord": [&"bossmonster4", &"bossmonster3", &"bossmonster1", &"bossmonster2"],
    &"boss_colossus": [&"bossmonster2", &"bossmonster3", &"bossmonster1"],
    &"boss_bronze": [&"knight2", &"knight1", &"knight3"],
}

# Crowd waves intentionally use a smaller simultaneous texture set. The omitted
# high-resolution variants remain available for close encounters and future maps,
# but do not consume hundreds of MB just because fifty fodder units spawned.
const MASS_MODEL_POOLS: Dictionary = {
    &"swordsman": [&"smallsbir1"],
    &"guardian": [&"smallsbir5"],
    &"spearman": [&"smallsbir2", &"sorcer1"],
    &"flanker": [&"smallsbir4", &"kamikaze1"],
    &"brute": [&"bossmonster1"],
}

# Normalizes the very different source heights before the archetype's gameplay
# scale is applied to the CharacterBody. BossMonster stays intentionally imposing.
const MODEL_SCALES: Dictionary = {
    &"smallsbir1": 0.76,
    &"smallsbir2": 0.76,
    &"smallsbir3": 0.84,
    &"smallsbir4": 0.73,
    &"smallsbir5": 0.79,
    &"smallsbir6": 0.85,
    &"kamikaze1": 0.86,
    &"sorcer1": 0.76,
    &"knight1": 1.10,
    &"knight2": 0.94,
    &"knight3": 1.10,
    &"bossmonster1": 0.96,
    &"bossmonster2": 0.96,
    &"bossmonster3": 1.02,
    &"bossmonster4": 1.02,
}

const CLIP_FILES: Dictionary = {
    &"axe_block_idle": "Axe Standing Block Idle.fbx",
    &"axe_down": "Axe Standing Melee Attack Downward.fbx",
    &"axe_horizontal": "Axe Standing Melee Attack Horizontal.fbx",
    &"axe_kick": "Axe Standing Melee Attack Kick Ver. 1.fbx",
    &"axe_combo": "Axe Standing Melee Combo Attack Ver. 1.fbx",
    &"hit_react": "Axe Standing React Large From Left.fbx",
    &"battlecry": "Axe Standing Taunt Battlecry.fbx",
    &"bow_walk": "Bow Standing Aim Walk Back.fbx",
    &"flying_knee": "Flying Knee Punch Combo.fbx",
    &"greatsword_jump": "Great Sword Jump Attack.fbx",
    &"mutant_punch": "Mutant Punch.fbx",
    &"mutant_roar": "Mutant Roaring.fbx",
    &"mutant_swipe": "Mutant Swiping.fbx",
    &"run": "Running.fbx",
    &"running_turn": "Running To Turn.fbx",
    &"sword_slash": "Stable Sword Outward Slash.fbx",
    &"vertical_sword": "verticalSwordAttack.fbx",
    &"tired_idle": "Wiping Sweat.fbx",
    &"zombie_attack": "Zombie Attack.fbx",
}

const LOOPING_CLIPS: Array[StringName] = [&"axe_block_idle", &"bow_walk", &"run"]

const ATTACK_POOLS: Dictionary = {
    &"swordsman": [&"zombie_attack", &"mutant_punch", &"sword_slash"],
    &"guardian": [&"axe_horizontal", &"axe_down", &"sword_slash"],
    &"spearman": [&"vertical_sword", &"sword_slash", &"zombie_attack"],
    &"flanker": [&"flying_knee", &"axe_kick", &"mutant_swipe"],
    &"brute": [&"mutant_swipe", &"mutant_punch", &"axe_combo"],
    &"captain": [&"axe_kick", &"axe_down", &"axe_horizontal", &"axe_combo", &"sword_slash", &"vertical_sword"],
    &"warlord": [&"mutant_swipe", &"axe_down", &"greatsword_jump", &"axe_combo", &"vertical_sword"],
    &"boss_colossus": [&"axe_down", &"mutant_punch", &"mutant_swipe"],
    &"boss_bronze": [&"vertical_sword", &"sword_slash", &"axe_horizontal"],
}

static var _animation_cache: Dictionary = {}

static func appearance(archetype: StringName, guard_index: int, seed: int, mass_mode: bool = false) -> Dictionary:
    var source_pools: Dictionary = MASS_MODEL_POOLS if mass_mode and MASS_MODEL_POOLS.has(archetype) else MODEL_POOLS
    var pool: Array = source_pools.get(archetype, MODEL_POOLS[&"swordsman"])
    var index: int = absi(guard_index * 7 + seed * 3) % pool.size()
    var model_id: StringName = StringName(pool[index])
    return {
        "id": model_id,
        "path": MODEL_ROOT + String(model_id) + ".glb",
        "scale": float(MODEL_SCALES.get(model_id, 1.0)) * GLOBAL_MODEL_SCALE,
        "ground_offset": GLOBAL_GROUND_OFFSET,
    }

static func install_personality(player: AnimationPlayer, archetype: StringName) -> Dictionary:
    if player == null:
        return {}
    if player.has_animation_library(&"mixamo"):
        player.remove_animation_library(&"mixamo")
    var library := AnimationLibrary.new()
    var attack_ids: Array = ATTACK_POOLS.get(archetype, ATTACK_POOLS[&"swordsman"])
    var move_id: StringName = &"run"
    var taunt_id: StringName = &"mutant_roar" if archetype in [&"brute", &"warlord"] else &"battlecry"
    var requested: Array[StringName] = [&"axe_block_idle", move_id, &"hit_react", taunt_id]
    for raw_id: Variant in attack_ids:
        var attack_id := StringName(raw_id)
        if not requested.has(attack_id):
            requested.append(attack_id)
    for clip_id: StringName in requested:
        var animation := _load_animation(clip_id)
        if animation != null:
            library.add_animation(clip_id, animation)
    player.add_animation_library(&"mixamo", library)

    var qualified_attacks: Array[StringName] = []
    for raw_id: Variant in attack_ids:
        var clip_id := StringName(raw_id)
        if library.has_animation(clip_id):
            qualified_attacks.append(_qualified(clip_id))
    return {
        "idle": _qualified(&"axe_block_idle"),
        "move": _qualified(move_id),
        "reaction": _qualified(&"hit_react"),
        "taunt": _qualified(taunt_id),
        "attacks": qualified_attacks,
    }

static func _load_animation(clip_id: StringName) -> Animation:
    if _animation_cache.has(clip_id):
        return _animation_cache[clip_id] as Animation
    if not CLIP_FILES.has(clip_id):
        return null
    var path: String = ANIMATION_ROOT + String(CLIP_FILES[clip_id])
    var packed := load(path) as PackedScene
    if packed == null:
        push_warning("[MIXAMO] Missing animation scene: " + path)
        return null
    var root := packed.instantiate()
    var source_player := _find_animation_player(root)
    if source_player == null:
        root.free()
        push_warning("[MIXAMO] AnimationPlayer missing in: " + path)
        return null
    var source_animation: Animation = source_player.get_animation(&"mixamo_com")
    if source_animation == null:
        var best_length: float = -1.0
        for animation_name: StringName in source_player.get_animation_list():
            var candidate := source_player.get_animation(animation_name)
            if candidate != null and candidate.length > best_length:
                source_animation = candidate
                best_length = candidate.length
    if source_animation == null:
        root.free()
        return null
    var animation := source_animation.duplicate(true) as Animation
    root.free()
    animation.resource_name = String(clip_id)
    animation.loop_mode = Animation.LOOP_LINEAR if LOOPING_CLIPS.has(clip_id) else Animation.LOOP_NONE
    _remove_root_motion(animation)
    _animation_cache[clip_id] = animation
    return animation

static func _remove_root_motion(animation: Animation) -> void:
    # CharacterBody3D owns translation. Keeping Mixamo's hips translation would
    # make the mesh drift away from its collider or float during jump attacks.
    for track_index: int in range(animation.get_track_count() - 1, -1, -1):
        if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
            continue
        var path := animation.track_get_path(track_index)
        var target_text := String(path).to_lower()
        if "hips" in target_text:
            animation.remove_track(track_index)

static func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child: Node in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

static func _qualified(clip_id: StringName) -> StringName:
    return StringName("mixamo/" + String(clip_id))
