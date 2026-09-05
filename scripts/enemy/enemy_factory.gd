extends RefCounted
class_name HopliteEnemyFactory

const EnemyScript = preload("res://scripts/enemy/athenian_enemy.gd")
const WolfBossScript = preload("res://scripts/bosses/wolf_boss.gd")
const DinosaurEnemyScript = preload("res://scripts/enemy/dinosaur_enemy.gd")
const ArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const ArchetypeData = preload("res://scripts/enemy/enemy_archetype_data.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const RuntimeMigration = preload("res://scripts/enemy/enemy_runtime_migration.gd")

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
    var request: SpawnRequest = SpawnRequest.new()
    request.archetype = archetype
    request.position = position_value
    request.target = target
    request.has_name_override = options.has("name")
    request.name_override = String(options.get("name", ""))
    request.ai_enabled = bool(options.get("ai_enabled", true))
    request.mass_battle_mode = bool(options.get("mass_battle_mode", false))
    request.has_performance_profile = options.has("performance_profile")
    request.performance_profile = SpawnRequest.performance_profile_from_id(options.get("performance_profile", "auto"))
    request.planned_simultaneous_population = maxi(1, int(options.get("planned_simultaneous_population", 1)))
    request.faction = StringName(options.get("faction", &"athenian"))
    request.navigation_mode_override = int(options.get("navigation_mode", -1))
    request.navigation_layers = maxi(1, int(options.get("navigation_layers", 1)))
    request.has_ai_target_override = options.has("ai_target")
    request.ai_target_override = options.get("ai_target") as Node3D
    request.has_battle_player_override = options.has("battle_player")
    request.battle_player_override = options.get("battle_player") as Node3D
    request.guard_index = int(options.get("guard_index", 0))
    request.scale_multiplier = maxf(0.01, float(options.get("scale_multiplier", 1.0)))
    request.has_match_perfect_hitbox_override = options.has("match_perfect_hitbox")
    request.match_perfect_hitbox = bool(options.get("match_perfect_hitbox", false))
    request.giant_traversal_mode = StringName(options.get("giant_traversal_mode", &"auto"))
    request.giant_capsule_radius_multiplier = float(options.get("giant_capsule_radius_multiplier", -1.0))
    request.giant_capsule_height_multiplier = float(options.get("giant_capsule_height_multiplier", -1.0))
    request.giant_walkable_tops = bool(options.get("giant_walkable_tops", true))
    request.commander = options.get("commander") as Node3D
    request.has_is_miniboss_override = options.has("is_miniboss")
    request.is_miniboss_override = bool(options.get("is_miniboss", false))
    request.package_path = String(options.get("package_path", ""))
    request.mixamo_model_override = StringName(options.get("mixamo_model_override", StringName()))
    return spawn_request(parent, request)


static func spawn_request(parent: Node, request: SpawnRequest) -> HopliteAthenianEnemy:
    if parent == null or request == null:
        return null
    var runtime_route := migration_route_for(request.archetype)
    # The current public factory returns HopliteAthenianEnemy. Until the generic
    # V2 construction API exists, fail closed instead of silently spawning the
    # wrong implementation after a rollout flag changes.
    if int(runtime_route.get("generation", RuntimeMigration.RuntimeGeneration.LEGACY_V1)) != RuntimeMigration.RuntimeGeneration.LEGACY_V1:
        push_error("Enemy V2 route requested for '%s', but no V2 constructor is installed" % request.archetype)
        return null
    if request.combatant_registry != null:
        if not is_instance_valid(request.combatant_registry) or not request.combatant_registry.is_inside_tree():
            return null
        if parent.get_tree() == null or request.combatant_registry.get_tree() != parent.get_tree():
            return null
    var enemy: HopliteAthenianEnemy
    if ArchetypesScript.is_dinosaur(request.archetype):
        enemy = DinosaurEnemyScript.new() as HopliteAthenianEnemy
    elif ArchetypesScript.is_wolf_boss(request.archetype):
        enemy = WolfBossScript.new() as HopliteAthenianEnemy
    else:
        enemy = EnemyScript.new() as HopliteAthenianEnemy
    var archetype_data: ArchetypeData = ArchetypesScript.data(request.archetype)
    var detail_priority := (
        archetype_data.rank in [&"elite", &"miniboss", &"boss"]
        and not archetype_data.auto_crowd_scalable
    )
    enemy.name = request.name_override if request.has_name_override else String(request.archetype).to_pascal_case()
    enemy.archetype_id = request.archetype
    enemy.position = request.position
    enemy.ai_enabled = request.ai_enabled
    enemy.mass_battle_mode = request.resolved_mass_battle_mode(detail_priority)
    enemy.faction = request.faction
    enemy.navigation_mode_override = request.navigation_mode_override
    enemy.navigation_layers = request.navigation_layers
    enemy.ai_player = request.ai_target_override if request.has_ai_target_override else request.target
    enemy.battle_player = request.battle_player_override if request.has_battle_player_override else request.target
    enemy.ai_guard_index = request.guard_index
    enemy.external_scale_multiplier = maxf(0.01, request.scale_multiplier)
    enemy.match_perfect_hitbox = request.match_perfect_hitbox
    if request.has_match_perfect_hitbox_override:
        enemy.set_meta("match_perfect_hitbox_override", request.match_perfect_hitbox)
    enemy.giant_traversal_mode = request.giant_traversal_mode
    enemy.giant_capsule_radius_multiplier = request.giant_capsule_radius_multiplier
    enemy.giant_capsule_height_multiplier = request.giant_capsule_height_multiplier
    enemy.giant_walkable_tops = request.giant_walkable_tops
    enemy.ai_miniboss = request.commander
    enemy.combatant_registry = request.combatant_registry
    # This can promote a troop for legacy authored encounters. Profile-ranked
    # minibosses/bosses remain promoted by the controller during _ready().
    enemy.is_miniboss = request.is_miniboss_override if request.has_is_miniboss_override else archetype_data.is_miniboss_or_boss()
    enemy.character_package_path = request.package_path if not request.package_path.is_empty() else archetype_data.package_path
    enemy.mixamo_model_override = request.mixamo_model_override
    enemy.set_meta("procedural_archetype", request.archetype)
    # Asset provenance and runtime generation are separate: a 3DGen source can
    # later use an optimized V2 representation without losing its origin.
    enemy.set_meta("enemy_asset_origin", runtime_route.get("asset_origin", &"unclassified"))
    enemy.set_meta("enemy_migration_eligible", bool(runtime_route.get("migration_eligible", false)))
    enemy.set_meta("enemy_runtime_generation", runtime_route.get("generation_id", &"legacy_v1"))
    enemy.set_meta("enemy_migration_family", runtime_route.get("family", RuntimeMigration.FAMILY_UNCLASSIFIED))
    enemy.set_meta("enemy_migration_stage", runtime_route.get("stage_id", &"legacy_only"))
    if request.has_performance_profile:
        enemy.set_meta("performance_profile", SpawnRequest.performance_profile_id(request.performance_profile))
        enemy.set_meta("planned_simultaneous_population", request.planned_simultaneous_population)
    parent.add_child(enemy)
    if request.combatant_registry != null and not request.combatant_registry.register_combatant(enemy):
        parent.remove_child(enemy)
        enemy.queue_free()
        return null
    return enemy


static func migration_route_for(archetype: StringName) -> Dictionary:
    return RuntimeMigration.route_for(archetype)

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
