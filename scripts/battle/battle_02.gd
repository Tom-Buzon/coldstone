extends "res://scripts/battle/battle_01.gd"

const QuestSystemScript = preload("res://scripts/quests/battle_quest_system.gd")
const ObjectiveTargetScript = preload("res://scripts/battle/battle_objective_target.gd")
const CrowdDirectorScript = preload("res://scripts/ai/battle_crowd_director.gd")

const ALLY_RESPAWN_THRESHOLD: int = 18
const ALLY_RESPAWN_TARGET: int = 22
const ALLY_RESPAWN_MAX_WAVE: int = 6

var quest_system: HopliteBattleQuestSystem
var dungeon_seal_gate: AnimatableBody3D
var dungeon_sealed: bool = false
var spartan_allies_alive: int = 0
var reinforcement_serial: int = 0

func _process(delta: float) -> void:
    super._process(delta)
    if quest_system != null and quest_system.state_of(&"save_vanguard") == &"active" and spartan_allies_alive < 10:
        quest_system.fail(&"save_vanguard")

func _build_ui() -> void:
    super._build_ui()
    quest_system = QuestSystemScript.new() as HopliteBattleQuestSystem
    quest_system.name = "BattleQuestSystem"
    add_child(quest_system)
    quest_system.register_quest(&"breach_walls", "PRENDRE LES MURAILLES", "Brisez la ligne athénienne et ouvrez la porte.", 1, false, true)
    quest_system.register_quest(&"destroy_siege", "SABOTAGE", "Détruisez les trois machines de siège.", 3, true, true, &"field_medic")
    quest_system.register_quest(&"save_vanguard", "AUCUN HOMME ABANDONNE", "Gardez au moins dix Spartiates en vie jusqu'à la brèche.", 1, true, true, &"battle_fury")
    quest_system.register_quest(&"take_city", "PRENDRE LA VILLE", "Nettoyez les deux districts et poussez jusqu'à l'acropole.", 2, false)
    quest_system.register_quest(&"silence_signals", "COUPER LES RENFORTS", "Éteignez les trois feux de signalisation athéniens.", 3, true, false, &"weaken_guard")
    quest_system.register_quest(&"slay_warlord", "LE DONJON", "Entrez seul, abattez le seigneur de guerre et sa garde.", 1, false)
    quest_system.quest_completed.connect(_on_quest_reward)
    quest_system.set_phase("ACTE I — PRISE DES MURAILLES")

func _build_environment() -> void:
    var crowd_director_runtime = CrowdDirectorScript.new() as HopliteBattleCrowdDirector
    crowd_director_runtime.name = "BattleCrowdDirector"
    add_child(crowd_director_runtime)

    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.08, 0.15, 0.29)
    sky_material.sky_horizon_color = Color(0.92, 0.58, 0.30)
    sky_material.ground_bottom_color = Color(0.035, 0.025, 0.022)
    sky_material.ground_horizon_color = Color(0.29, 0.19, 0.12)
    sky_material.sun_angle_max = 10.0
    sky_material.sun_curve = 0.08
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.glow_enabled = true
    world_environment.environment = environment
    add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_color = Color(1.0, 0.78, 0.58)
    sun.light_energy = 1.42
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 240.0
    add_child(sun)

func _build_battlefield() -> void:
    var earth := Color(0.19, 0.105, 0.065)
    var dry_grass := Color(0.28, 0.25, 0.13)
    var road := Color(0.37, 0.28, 0.18)
    var limestone := Color(0.58, 0.50, 0.38)
    var pale_stone := Color(0.68, 0.59, 0.45)
    var dark_stone := Color(0.25, 0.23, 0.23)
    var plaster := Color(0.68, 0.49, 0.31)
    var roof_red := Color(0.43, 0.15, 0.07)
    var wood := Color(0.20, 0.095, 0.032)

    # A broad, continuous combat floor with layered roads and dry banks. The
    # central boulevard remains clear so dozens of agents do not fight navigation.
    _add_box("GrandBattleGround", Vector3(124.0, 0.42, 340.0), Vector3(0.0, -0.22, -58.0), earth, true)
    _add_box("OuterDryField", Vector3(116.0, 0.055, 93.0), Vector3(0.0, 0.02, 54.0), dry_grass, false)
    _add_box("AssaultRoad", Vector3(24.0, 0.07, 88.0), Vector3(0.0, 0.04, 48.0), road, false)
    _add_box("CityBoulevard", Vector3(20.0, 0.07, 133.0), Vector3(0.0, 0.04, -61.0), road.lightened(0.05), false)
    _add_box("DungeonFloor", Vector3(34.0, 0.08, 76.0), Vector3(0.0, 0.05, -169.0), dark_stone.lightened(0.04), false)
    _add_box("WestEscarpment", Vector3(5.0, 4.2, 320.0), Vector3(-62.0, 1.9, -48.0), earth.darkened(0.18), true)
    _add_box("EastEscarpment", Vector3(5.0, 4.2, 320.0), Vector3(62.0, 1.9, -48.0), earth.darkened(0.18), true)

    # ACT I — monumental wall, battlements, assault ramps and siege machinery.
    _add_box("GrandWallLeft", Vector3(53.0, 9.0, 3.2), Vector3(-31.5, 4.5, 5.0), limestone, true)
    _add_box("GrandWallRight", Vector3(53.0, 9.0, 3.2), Vector3(31.5, 4.5, 5.0), limestone, true)
    _add_tower(Vector3(-57.0, 0.0, 5.0), pale_stone)
    _add_tower(Vector3(57.0, 0.0, 5.0), pale_stone)
    outer_gate = _create_lift_gate("GrandOuterGate", Vector3(0.0, 4.15, 5.0), Vector3(10.0, 8.3, 0.9), wood)
    _add_battlements(5.0, 55.0, 9.6, limestone.lightened(0.08))
    _add_ramp("AssaultRampL", Vector3(-23.0, 1.65, 14.0), Vector3(7.0, 0.8, 18.0), -10.0, wood)
    _add_ramp("AssaultRampR", Vector3(23.0, 1.65, 14.0), Vector3(7.0, 0.8, 18.0), -10.0, wood)
    _add_banner(Vector3(-7.5, 8.7, 3.0), Color(0.04, 0.16, 0.62))
    _add_banner(Vector3(7.5, 8.7, 3.0), Color(0.04, 0.16, 0.62))
    _spawn_objective_target(Vector3(-31.0, 0.0, 47.0), &"siege_left", &"siege_engine", 145.0)
    _spawn_objective_target(Vector3(0.0, 0.0, 39.0), &"siege_center", &"siege_engine", 165.0)
    _spawn_objective_target(Vector3(31.0, 0.0, 49.0), &"siege_right", &"siege_engine", 145.0)
    for rubble_index: int in range(12):
        var side: float = -1.0 if rubble_index % 2 == 0 else 1.0
        _add_box("FieldRubble_%02d" % rubble_index, Vector3(1.1 + float(rubble_index % 3) * 0.35, 0.55, 0.8), Vector3(side * (14.0 + float(rubble_index) * 2.8), 0.25, 22.0 + float(rubble_index % 4) * 9.0), limestone.darkened(0.18), false)

    # ACT II — outer city: readable plazas with dense, non-blocking side detail.
    _add_box("CityBoundaryL", Vector3(3.0, 8.0, 137.0), Vector3(-58.0, 4.0, -62.0), limestone, true)
    _add_box("CityBoundaryR", Vector3(3.0, 8.0, 137.0), Vector3(58.0, 4.0, -62.0), limestone, true)
    _add_house("LowerHouseL1", Vector3(-45.0, 0.0, -13.0), Vector3(17.0, 5.5, 16.0), plaster, roof_red)
    _add_house("LowerHouseR1", Vector3(43.0, 0.0, -15.0), Vector3(19.0, 6.5, 14.0), plaster.lightened(0.05), roof_red.darkened(0.07))
    _add_house("LowerHouseL2", Vector3(-37.0, 0.0, -42.0), Vector3(22.0, 4.8, 15.0), plaster.darkened(0.06), roof_red)
    _add_house("LowerHouseR2", Vector3(42.0, 0.0, -45.0), Vector3(18.0, 5.7, 18.0), plaster, roof_red.darkened(0.10))
    _add_market_stall(Vector3(-16.0, 0.0, -27.0), Color(0.58, 0.08, 0.04))
    _add_market_stall(Vector3(16.0, 0.0, -31.0), Color(0.75, 0.52, 0.12))
    _add_market_stall(Vector3(21.0, 0.0, -48.0), Color(0.10, 0.25, 0.58))
    _spawn_objective_target(Vector3(-34.0, 0.0, -27.0), &"signal_lower", &"signal_fire", 105.0)
    _add_city_gate("MidCityWall", -62.0, limestone, wood, true)
    _add_column(Vector3(-19.0, 0.0, -54.0), pale_stone)
    _add_column(Vector3(19.0, 0.0, -54.0), pale_stone)
    _create_encounter_trigger(&"city_a", Vector3(0.0, 1.0, -7.5), Vector3(28.0, 2.4, 5.0))

    # Upper city: narrower lanes, temple terrace and the approach to the acropolis.
    _add_house("UpperHouseL1", Vector3(-44.0, 0.0, -77.0), Vector3(20.0, 6.2, 17.0), plaster.darkened(0.10), roof_red)
    _add_house("UpperHouseR1", Vector3(44.0, 0.0, -80.0), Vector3(20.0, 5.0, 18.0), plaster, roof_red.darkened(0.05))
    _add_house("UpperHouseL2", Vector3(-37.0, 0.0, -108.0), Vector3(24.0, 5.4, 17.0), plaster.lightened(0.03), roof_red)
    _add_house("UpperHouseR2", Vector3(41.0, 0.0, -110.0), Vector3(21.0, 6.8, 18.0), plaster.darkened(0.04), roof_red.darkened(0.08))
    _add_box("TempleTerrace", Vector3(30.0, 1.2, 15.0), Vector3(-24.0, 0.6, -94.0), pale_stone, true)
    for column_x: float in [-34.0, -27.0, -20.0, -13.0]:
        _add_column(Vector3(column_x, 1.2, -96.0), pale_stone)
    _spawn_objective_target(Vector3(34.0, 0.0, -84.0), &"signal_market", &"signal_fire", 105.0)
    _spawn_objective_target(Vector3(-28.0, 1.2, -103.0), &"signal_temple", &"signal_fire", 105.0)
    _add_market_stall(Vector3(17.0, 0.0, -96.0), Color(0.52, 0.06, 0.035))
    _add_market_stall(Vector3(23.0, 0.0, -105.0), Color(0.69, 0.48, 0.10))
    _add_city_gate("AcropolisWall", -128.0, dark_stone, wood.darkened(0.18), false)
    _create_encounter_trigger(&"city_b", Vector3(0.0, 1.0, -69.0), Vector3(28.0, 2.4, 5.0))

    # ACT III — an enclosed donjon. The army is locked outside at the second
    # portcullis, leaving a compact boss arena and close guard formation.
    _add_box("DungeonWallL", Vector3(3.2, 9.0, 77.0), Vector3(-18.0, 4.5, -168.0), dark_stone, true)
    _add_box("DungeonWallR", Vector3(3.2, 9.0, 77.0), Vector3(18.0, 4.5, -168.0), dark_stone, true)
    _add_box("DungeonBack", Vector3(39.0, 9.0, 3.2), Vector3(0.0, 4.5, -206.0), dark_stone, true)
    dungeon_seal_gate = _create_lift_gate("DungeonSeal", Vector3(0.0, 12.0, -141.0), Vector3(10.0, 7.2, 0.9), wood.darkened(0.25))
    _create_player_only_trigger(Vector3(0.0, 1.2, -146.0), Vector3(12.0, 2.6, 3.0), _on_player_entered_dungeon)
    _create_encounter_trigger(&"final", Vector3(0.0, 1.0, -151.0), Vector3(13.0, 2.4, 4.0))
    for torch_z: float in [-150.0, -166.0, -183.0, -199.0]:
        _add_torch(Vector3(-15.8, 2.7, torch_z))
        _add_torch(Vector3(15.8, 2.7, torch_z))
    _add_box("BossDais", Vector3(17.0, 1.1, 10.0), Vector3(0.0, 0.55, -195.0), dark_stone.lightened(0.13), true)
    _add_column(Vector3(-7.0, 1.1, -197.0), pale_stone.darkened(0.22))
    _add_column(Vector3(7.0, 1.1, -197.0), pale_stone.darkened(0.22))

    _add_debug_world_label("ACTE I — LES MURAILLES", Vector3(0.0, 11.0, 8.0))
    _add_debug_world_label("ACTE II — LA VILLE", Vector3(0.0, 8.0, -58.0))
    _add_debug_world_label("ACTE III — LE DONJON", Vector3(0.0, 8.0, -165.0))

func _spawn_outer_battle() -> void:
    # 56 Athenians form four independently commanded cohorts. Regular troops all
    # use mass_battle_mode; only the four captains pay for the full animation rig.
    var captain_x: Array[float] = [-45.0, -15.0, 15.0, 45.0]
    var guard_types: Array[StringName] = [&"guardian", &"spearman", &"swordsman", &"flanker", &"brute", &"spearman", &"swordsman", &"guardian"]
    for squad: int in range(captain_x.size()):
        var captain: HopliteAthenianEnemy = _spawn_enemy(Vector3(captain_x[squad], 0.05, 20.0 + float(squad % 2) * 8.0), &"captain", null, squad * 8, true, false)
        _register_outer_enemy(captain)
        for index: int in range(guard_types.size()):
            var angle: float = (TAU / float(guard_types.size())) * float(index)
            var position_value := Vector3(captain_x[squad] + cos(angle) * 4.5, 0.05, 24.0 + float(squad % 2) * 5.0 + sin(angle) * 3.8)
            _register_outer_enemy(_spawn_enemy(position_value, guard_types[index], captain, index, false, true))
    var front_types: Array[StringName] = [
        &"flanker", &"swordsman", &"spearman", &"guardian", &"swordsman", &"brute", &"spearman", &"flanker", &"guardian",
        &"swordsman", &"spearman", &"flanker", &"guardian", &"brute", &"swordsman", &"spearman", &"flanker", &"guardian", &"swordsman", &"spearman"
    ]
    for index: int in range(front_types.size()):
        var row: int = index / 10
        var column: int = index % 10
        var x: float = -49.5 + float(column) * 11.0
        _register_outer_enemy(_spawn_enemy(Vector3(x, 0.05, 47.0 + float(row) * 10.0), front_types[index], null, index, false, true))
    if quest_system != null:
        quest_system.set_target(&"breach_walls", outer_alive)

func _spawn_spartan_allies() -> void:
    # Four staggered files of seven Spartans create a second moving front rather
    # than a small escort following directly behind the player.
    var types: Array[StringName] = []
    var formation_pattern: Array[StringName] = [&"guardian", &"spearman", &"swordsman", &"spearman", &"guardian", &"swordsman", &"spearman"]
    for _row: int in range(4):
        types.append_array(formation_pattern)
    for index: int in range(types.size()):
        var row: int = index / 7
        var column: int = index % 7
        var position_value := Vector3(-39.0 + float(column) * 13.0 + float(row % 2) * 3.0, 0.05, 66.0 + float(row) * 8.0)
        var ally: HopliteAthenianEnemy = _spawn_spartan(position_value, types[index], index)
        ally.died.connect(_on_spartan_ally_died)
        spartan_allies_alive += 1

func _on_spartan_ally_died(_ally: Node) -> void:
    spartan_allies_alive = maxi(0, spartan_allies_alive - 1)

func _on_outer_enemy_died(_enemy: Node) -> void:
    outer_alive = maxi(0, outer_alive - 1)
    if quest_system != null:
        quest_system.increment(&"breach_walls")
    if outer_alive > 0:
        return
    _open_gate(outer_gate, 9.2)
    if quest_system != null:
        if quest_system.state_of(&"save_vanguard") == &"active":
            if spartan_allies_alive >= 10:
                quest_system.complete(&"save_vanguard")
            else:
                quest_system.fail(&"save_vanguard")
        quest_system.activate(&"take_city")
        quest_system.activate(&"silence_signals")
        quest_system.set_phase("ACTE II — PRISE DE LA VILLE")
    _maybe_respawn_allies(&"walls", Vector3(0.0, 0.05, 14.0))

func _spawn_city_encounter(encounter_id: StringName) -> void:
    if encounter_alive.has(encounter_id):
        return
    var captain_position: Vector3
    var positions: Array[Vector3] = []
    var types: Array[StringName] = []
    if encounter_id == &"city_a":
        captain_position = Vector3(0.0, 0.05, -46.0)
        positions = [Vector3(-23.0,0.05,-14.0),Vector3(22.0,0.05,-15.0),Vector3(-12.0,0.05,-25.0),Vector3(13.0,0.05,-28.0),Vector3(-25.0,0.05,-39.0),Vector3(25.0,0.05,-40.0),Vector3(-8.0,0.05,-49.0),Vector3(9.0,0.05,-51.0),Vector3(-18.0,0.05,-54.0),Vector3(19.0,0.05,-55.0)]
        types = [&"flanker",&"spearman",&"swordsman",&"guardian",&"brute",&"flanker",&"spearman",&"guardian",&"swordsman",&"spearman"]
    elif encounter_id == &"city_b":
        captain_position = Vector3(0.0, 0.05, -118.0)
        positions = [Vector3(-22.0,0.05,-74.0),Vector3(23.0,0.05,-76.0),Vector3(-10.0,0.05,-83.0),Vector3(11.0,0.05,-86.0),Vector3(-25.0,0.05,-92.0),Vector3(25.0,0.05,-95.0),Vector3(-12.0,0.05,-103.0),Vector3(13.0,0.05,-106.0),Vector3(-25.0,0.05,-115.0),Vector3(25.0,0.05,-116.0),Vector3(-8.0,0.05,-121.0),Vector3(8.0,0.05,-122.0)]
        types = [&"spearman",&"flanker",&"guardian",&"swordsman",&"brute",&"spearman",&"flanker",&"guardian",&"swordsman",&"brute",&"spearman",&"guardian"]
    else:
        return
    encounter_alive[encounter_id] = 1 + positions.size()
    var captain := _spawn_enemy(captain_position, &"captain", null, 0, true, false)
    captain.died.connect(_on_city_enemy_died.bind(encounter_id))
    for index: int in range(positions.size()):
        var enemy := _spawn_enemy(positions[index], types[index], captain, index, false, true)
        enemy.died.connect(_on_city_enemy_died.bind(encounter_id))

func _on_city_enemy_died(_enemy: Node, encounter_id: StringName) -> void:
    var remaining: int = maxi(0, int(encounter_alive.get(encounter_id, 0)) - 1)
    encounter_alive[encounter_id] = remaining
    if remaining > 0:
        return
    if quest_system != null:
        quest_system.increment(&"take_city")
    if encounter_id == &"city_a":
        _open_gate(city_gate_a, 6.3)
        _cleanup_dead_combatants_behind(0.0)
        _maybe_respawn_allies(&"lower_city", Vector3(0.0, 0.05, -55.0))
    elif encounter_id == &"city_b":
        _open_gate(inner_gate, 8.0)
        _cleanup_dead_combatants_behind(-62.0)
        _maybe_respawn_allies(&"acropolis", Vector3(0.0, 0.05, -121.0))
        if quest_system != null:
            quest_system.activate(&"slay_warlord")
            quest_system.set_phase("ACTE III — PRISE DU DONJON")

func _spawn_final_encounter() -> void:
    if final_alive > 0 or battle_complete:
        return
    final_boss = _spawn_enemy(Vector3(0.0, 1.15, -195.0), &"warlord", null, 0, true, false)
    final_alive = 1
    final_boss.died.connect(_on_final_enemy_died)
    var guard_count: int = 5 if quest_system != null and quest_system.state_of(&"silence_signals") == &"completed" else 8
    for index: int in range(guard_count):
        var angle: float = (TAU / float(guard_count)) * float(index)
        var guard_position := Vector3(cos(angle) * 8.0, 0.05, -187.0 + sin(angle) * 5.0)
        var guard_type: StringName = [&"guardian", &"spearman", &"brute"][index % 3]
        var guard := _spawn_enemy(guard_position, guard_type, final_boss, index, false, false)
        final_alive += 1
        guard.died.connect(_on_final_enemy_died)

func _on_final_enemy_died(_enemy: Node) -> void:
    final_alive = maxi(0, final_alive - 1)
    if final_alive > 0:
        return
    battle_complete = true
    if quest_system != null:
        quest_system.complete(&"slay_warlord")
        quest_system.set_phase("VICTOIRE — LA CITADELLE EST PRISE")
    _spawn_victory_portal()

func _on_player_entered_dungeon(body: Node3D) -> void:
    if body != player or dungeon_sealed:
        return
    dungeon_sealed = true
    if dungeon_seal_gate != null:
        var tween := create_tween()
        tween.set_trans(Tween.TRANS_QUAD)
        tween.set_ease(Tween.EASE_IN)
        tween.tween_property(dungeon_seal_gate, "position:y", 3.6, 0.78)
    for ally_node: Node in get_tree().get_nodes_in_group("spartan_ally"):
        if ally_node is HopliteAthenianEnemy:
            var ally := ally_node as HopliteAthenianEnemy
            ally.hold_battlefield_position()
    _cleanup_dead_combatants_behind(-128.0)
    if quest_system != null:
        for optional_id: StringName in [&"destroy_siege", &"silence_signals"]:
            if quest_system.state_of(optional_id) == &"active":
                quest_system.fail(optional_id)

func _on_objective_destroyed(_target: HopliteBattleObjectiveTarget, objective_id: StringName) -> void:
    if quest_system == null:
        return
    if String(objective_id).begins_with("siege_"):
        quest_system.increment(&"destroy_siege")
    elif String(objective_id).begins_with("signal_"):
        quest_system.increment(&"silence_signals")

func _on_quest_reward(_quest_id: StringName, reward_id: StringName) -> void:
    if player == null:
        return
    match reward_id:
        &"field_medic":
            player.health = minf(player.max_health, player.health + 70.0)
        &"battle_fury":
            player.max_health += 50.0
            player.health = minf(player.max_health, player.health + 80.0)

func _cleanup_dead_combatants_behind(minimum_z: float) -> void:
    # Corpses remain throughout the active arena, but once the player has crossed
    # the next gate they can no longer be seen. Releasing their skeletons, anatomy
    # Areas and procedural armour prevents each act from accumulating in RAM.
    for node: Node in get_tree().get_nodes_in_group("combatant"):
        if node is HopliteAthenianEnemy:
            var combatant := node as HopliteAthenianEnemy
            if combatant.dead and combatant.global_position.z > minimum_z:
                combatant.queue_free()

func _maybe_respawn_allies(stage_id: StringName, center: Vector3) -> void:
    if spartan_allies_alive >= ALLY_RESPAWN_THRESHOLD:
        return
    var missing_to_target: int = maxi(0, ALLY_RESPAWN_TARGET - spartan_allies_alive)
    var spawn_count: int = mini(ALLY_RESPAWN_MAX_WAVE, missing_to_target)
    if spawn_count <= 0:
        return
    var pattern: Array[StringName] = [&"guardian", &"spearman", &"swordsman", &"spearman", &"guardian", &"swordsman"]
    for index: int in range(spawn_count):
        var offset := Vector3((float(index) - float(spawn_count - 1) * 0.5) * 2.4, 0.0, float(index % 2) * 2.2)
        var formation_index: int = 1000 + reinforcement_serial
        reinforcement_serial += 1
        var ally: HopliteAthenianEnemy = _spawn_spartan(center + offset, pattern[index % pattern.size()], formation_index)
        ally.died.connect(_on_spartan_ally_died)
        spartan_allies_alive += 1
    if quest_system != null:
        quest_system.announce("RENFORTS SPARTIATES — %d HOMMES (%s)" % [spawn_count, String(stage_id).to_upper()], Color(0.92, 0.30, 0.20))

func _spawn_objective_target(position_value: Vector3, objective_id: StringName, kind: StringName, health_value: float) -> void:
    var target = ObjectiveTargetScript.new() as HopliteBattleObjectiveTarget
    target.name = "Objective_%s" % String(objective_id)
    target.position = position_value
    target.configure(objective_id, kind, health_value)
    add_child(target)
    target.destroyed.connect(_on_objective_destroyed)

func _add_city_gate(node_name: String, z_value: float, stone: Color, wood: Color, middle_gate: bool) -> void:
    _add_box(node_name + "_L", Vector3(53.0, 6.5, 2.2), Vector3(-31.5, 3.25, z_value), stone, true)
    _add_box(node_name + "_R", Vector3(53.0, 6.5, 2.2), Vector3(31.5, 3.25, z_value), stone, true)
    var gate := _create_lift_gate(node_name + "_Gate", Vector3(0.0, 3.0, z_value), Vector3(10.0, 6.0, 0.8), wood)
    if middle_gate:
        city_gate_a = gate
    else:
        inner_gate = gate
    _add_battlements(z_value, 55.0, 7.0, stone.lightened(0.06))

func _add_battlements(z_value: float, half_width: float, y_value: float, color: Color) -> void:
    var index: int = 0
    var x: float = -half_width
    while x <= half_width:
        if absf(x) > 6.0:
            _add_box("Merlon_%d_%d" % [int(z_value), index], Vector3(2.0, 1.25, 2.2), Vector3(x, y_value, z_value), color, true)
        x += 4.0
        index += 1

func _add_house(node_name: String, ground_position: Vector3, size: Vector3, wall_color: Color, roof_color: Color) -> void:
    _add_box(node_name, size, ground_position + Vector3.UP * size.y * 0.5, wall_color, true)
    _add_box(node_name + "_Roof", Vector3(size.x + 1.0, 0.55, size.z + 1.0), ground_position + Vector3.UP * (size.y + 0.28), roof_color, false)
    _add_box(node_name + "_Door", Vector3(1.4, 2.5, 0.22), ground_position + Vector3(0.0, 1.25, size.z * 0.51), Color(0.16, 0.07, 0.025), false)

func _add_market_stall(position_value: Vector3, cloth_color: Color) -> void:
    var wood := Color(0.20, 0.09, 0.025)
    for x: float in [-1.8, 1.8]:
        _add_box("StallPost_%d" % get_child_count(), Vector3(0.16, 2.5, 0.16), position_value + Vector3(x, 1.25, 0.0), wood, false)
    _add_box("StallTable_%d" % get_child_count(), Vector3(4.0, 0.18, 1.8), position_value + Vector3.UP * 1.0, wood, false)
    _add_box("StallCloth_%d" % get_child_count(), Vector3(4.4, 0.12, 2.2), position_value + Vector3.UP * 2.55, cloth_color, false)

func _add_banner(position_value: Vector3, color: Color) -> void:
    _add_box("BannerPole_%d" % get_child_count(), Vector3(0.14, 3.7, 0.14), position_value, Color(0.18, 0.08, 0.025), false)
    _add_box("BannerCloth_%d" % get_child_count(), Vector3(1.5, 1.8, 0.08), position_value + Vector3(0.78, 0.65, 0.0), color, false)

func _add_torch(position_value: Vector3) -> void:
    _add_box("Torch_%d" % get_child_count(), Vector3(0.13, 1.5, 0.13), position_value, Color(0.20, 0.08, 0.02), false)
    var light := OmniLight3D.new()
    light.position = position_value + Vector3.UP * 0.85
    light.light_color = Color(1.0, 0.36, 0.08)
    light.light_energy = 2.2
    light.omni_range = 8.0
    add_child(light)

func _add_ramp(node_name: String, position_value: Vector3, size: Vector3, rotation_x: float, color: Color) -> void:
    var ramp := _add_box(node_name, size, position_value, color, true)
    ramp.rotation_degrees.x = rotation_x

func _create_player_only_trigger(position_value: Vector3, size: Vector3, callback: Callable) -> void:
    var area := Area3D.new()
    area.position = position_value
    area.collision_layer = 0
    area.collision_mask = 2
    add_child(area)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    area.add_child(collision)
    area.body_entered.connect(callback)

func _build_return_to_training_portal() -> void:
    _add_scene_portal("ReturnPortal", Vector3(0.0, 0.0, 96.0), "RETOUR A L'ENTRAINEMENT", TUTORIAL_SCENE, Color(0.18, 0.55, 0.95))

func _spawn_victory_portal() -> void:
    if return_portal_created:
        return
    return_portal_created = true
    _add_scene_portal("VictoryPortal", Vector3(0.0, 1.1, -199.0), "CITADELLE CONQUISE", TUTORIAL_SCENE, Color(0.95, 0.64, 0.12))
