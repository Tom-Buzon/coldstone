extends RefCounted
class_name HopliteEnemyFactory

const EnemyScript = preload("res://scripts/enemy/athenian_enemy.gd")
const ArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")

# Single construction point for handcrafted encounters and future procedural
# rooms. The caller chooses only an archetype, position and target; package path,
# rank, equipment and combat behavior come from the profile.
static func spawn(
    parent: Node,
    archetype: StringName,
    position_value: Vector3,
    target: Node3D = null,
    options: Dictionary = {}
) -> HopliteAthenianEnemy:
    if parent == null:
        return null
    var enemy := EnemyScript.new() as HopliteAthenianEnemy
    enemy.name = String(options.get("name", String(archetype).to_pascal_case()))
    enemy.archetype_id = archetype
    enemy.position = position_value
    enemy.ai_enabled = bool(options.get("ai_enabled", true))
    enemy.mass_battle_mode = bool(options.get("mass_battle_mode", false))
    enemy.faction = StringName(options.get("faction", &"athenian"))
    enemy.ai_player = target
    enemy.battle_player = target
    enemy.ai_guard_index = int(options.get("guard_index", 0))
    enemy.external_scale_multiplier = maxf(0.01, float(options.get("scale_multiplier", 1.0)))
    enemy.match_perfect_hitbox = bool(options.get("match_perfect_hitbox", false))
    enemy.giant_traversal_mode = StringName(options.get("giant_traversal_mode", &"auto"))
    enemy.giant_capsule_radius_multiplier = float(options.get("giant_capsule_radius_multiplier", -1.0))
    enemy.giant_capsule_height_multiplier = float(options.get("giant_capsule_height_multiplier", -1.0))
    enemy.giant_walkable_tops = bool(options.get("giant_walkable_tops", true))
    enemy.ai_miniboss = options.get("commander") as Node3D
    enemy.is_miniboss = ArchetypesScript.is_miniboss(archetype) or ArchetypesScript.is_boss(archetype)
    var package_override := String(options.get("package_path", ""))
    enemy.character_package_path = package_override if not package_override.is_empty() else ArchetypesScript.package_path(archetype)
    enemy.set_meta("procedural_archetype", archetype)
    parent.add_child(enemy)
    return enemy

static func catalog(max_cost: float = INF, wave: int = 0) -> Array[Dictionary]:
    return ArchetypesScript.procedural_catalog(max_cost, wave)

static func choose_for_budget(rng: RandomNumberGenerator, max_cost: float, wave: int = 0, include_bosses: bool = false) -> StringName:
    var candidates := catalog(max_cost, wave)
    var total_weight := 0.0
    var filtered: Array[Dictionary] = []
    for candidate: Dictionary in candidates:
        if not include_bosses and StringName(candidate.get("rank", &"troop")) == &"boss":
            continue
        var weight := maxf(0.0, float(candidate.get("weight", 0.0)))
        if weight <= 0.0:
            continue
        total_weight += weight
        filtered.append(candidate)
    if filtered.is_empty() or total_weight <= 0.0:
        return &"nsbire1"
    var roll := rng.randf_range(0.0, total_weight)
    for candidate: Dictionary in filtered:
        roll -= float(candidate.get("weight", 0.0))
        if roll <= 0.0:
            return StringName(candidate.get("id", &"nsbire1"))
    return StringName(filtered.back().get("id", &"nsbire1"))
