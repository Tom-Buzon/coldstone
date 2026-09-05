extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const EnemySpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const CombatAudioScript = preload("res://scripts/audio/combat_audio.gd")
const GoreHUDScript = preload("res://scripts/ui/gore_hud.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")

const HEALTH_BAR_WIDTH: float = 286.0
const TUTORIAL_SCENE: String = "res://combat_lab.tscn"

var player: HopliteUALNativePlayer
var debug_overlay_visible: bool = false
var debug_world_labels: Array[Label3D] = []
var debug_panel: ColorRect
var debug_title: Label
var debug_help: Label
var debug_label: Label
var health_bar_fill: ColorRect
var health_bar_label: Label
var combat_audio: HopliteCombatAudio
var gore_hud: HopliteGoreHUD
var audio_settings: HopliteAudioSettings

var outer_gate: AnimatableBody3D
var city_gate_a: AnimatableBody3D
var city_gate_b: AnimatableBody3D
var inner_gate: AnimatableBody3D
var opened_gates: Dictionary = {}

var outer_alive: int = 0
var encounter_alive: Dictionary = {}
var triggered_encounters: Dictionary = {}
var final_alive: int = 0
var battle_complete: bool = false
var final_boss: HopliteAthenianEnemy = null
var return_portal_created: bool = false

func _ready() -> void:
    _build_environment()
    _build_ui()
    _build_feedback_systems()
    _build_battlefield()

    player = PlayerScript.new() as HopliteUALNativePlayer
    player.name = "SpartanBattle01"
    player.position = Vector3(0.0, 0.05, 79.0)
    add_child(player)
    if audio_settings != null:
        audio_settings.player = player
    _wire_player_feedback()

    _build_return_to_training_portal()
    _spawn_outer_battle()
    _spawn_spartan_allies()

func _process(_delta: float) -> void:
    if player == null:
        return
    _update_player_health_bar()
    if debug_overlay_visible and debug_label != null:
        var phase_text: String = "FPS=%d  OUTER=%d" % [int(Engine.get_frames_per_second()), outer_alive]
        if triggered_encounters.has(&"city_a"):
            phase_text += "  A=%d" % int(encounter_alive.get(&"city_a", 0))
        if triggered_encounters.has(&"city_b"):
            phase_text += "  B=%d" % int(encounter_alive.get(&"city_b", 0))
        if triggered_encounters.has(&"city_c"):
            phase_text += "  C=%d" % int(encounter_alive.get(&"city_c", 0))
        if triggered_encounters.has(&"final"):
            phase_text += "  FINAL=%d" % final_alive
        debug_label.text = "BATTLE 01  %s\n%s" % [phase_text, player.debug_text]

func _input(event: InputEvent) -> void:
    if event.is_action_pressed(&"toggle_settings") and audio_settings != null and not audio_settings.is_open():
        audio_settings.set_open(true)
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo:
        var key: InputEventKey = event as InputEventKey
        if _is_settings_key(key):
            if audio_settings != null and not audio_settings.is_open():
                audio_settings.set_open(true)
            get_viewport().set_input_as_handled()
        elif key.keycode == KEY_I:
            _set_debug_overlay_visible(not debug_overlay_visible)
            get_viewport().set_input_as_handled()
        elif key.keycode == KEY_G:
            if gore_hud != null:
                gore_hud.set_enabled(not gore_hud.is_enabled())
            get_viewport().set_input_as_handled()

func _is_settings_key(key: InputEventKey) -> bool:
    return key.unicode == 0x00B2 or key.keycode == KEY_QUOTELEFT or key.physical_keycode == KEY_QUOTELEFT

func _set_debug_overlay_visible(enabled: bool) -> void:
    debug_overlay_visible = enabled
    for control: Control in [debug_panel, debug_title, debug_help, debug_label]:
        if control != null:
            control.visible = enabled
    for label: Label3D in debug_world_labels:
        if is_instance_valid(label):
            label.visible = enabled
    if player != null:
        player.set_combat_debug_visible(enabled)
    for enemy: Node in get_tree().get_nodes_in_group("enemy"):
        if enemy.has_method("set_combat_debug_visible"):
            enemy.call("set_combat_debug_visible", enabled)
    for ally: Node in get_tree().get_nodes_in_group("spartan_ally"):
        if ally.has_method("set_combat_debug_visible"):
            ally.call("set_combat_debug_visible", enabled)

func _build_feedback_systems() -> void:
    combat_audio = CombatAudioScript.new() as HopliteCombatAudio
    combat_audio.name = "CombatAudio"
    add_child(combat_audio)

    gore_hud = GoreHUDScript.new() as HopliteGoreHUD
    gore_hud.name = "GoreHUD"
    add_child(gore_hud)

    audio_settings = AudioSettingsScript.new() as HopliteAudioSettings
    audio_settings.name = "AudioSettings"
    audio_settings.combat_audio = combat_audio
    audio_settings.gore_hud = gore_hud
    add_child(audio_settings)

func _wire_player_feedback() -> void:
    if player == null:
        return
    if not player.damage_received.is_connected(_on_player_damage_received):
        player.damage_received.connect(_on_player_damage_received)
    if not player.movement_sfx_requested.is_connected(_on_player_movement_sfx_requested):
        player.movement_sfx_requested.connect(_on_player_movement_sfx_requested)
    if not player.combat_hit.is_connected(_on_player_combat_hit):
        player.combat_hit.connect(_on_player_combat_hit)
    if not player.perfect_response_started.is_connected(_on_player_perfect_response):
        player.perfect_response_started.connect(_on_player_perfect_response)
    if not player.perfect_response_consumed.is_connected(_on_player_perfect_response_consumed):
        player.perfect_response_consumed.connect(_on_player_perfect_response_consumed)
    var feedback: HopliteCombatFeedback = player.get_combat_feedback()
    if feedback != null and not feedback.audio_cue_requested.is_connected(_on_combat_audio_cue):
        feedback.audio_cue_requested.connect(_on_combat_audio_cue)
    if feedback != null and not feedback.cinematic_started.is_connected(_on_combat_cinematic_started):
        feedback.cinematic_started.connect(_on_combat_cinematic_started)

func _wire_enemy_feedback(enemy: HopliteAthenianEnemy) -> void:
    if enemy == null:
        return
    if not enemy.localized_hit.is_connected(_on_enemy_localized_hit):
        enemy.localized_hit.connect(_on_enemy_localized_hit)
    if not enemy.attack_started.is_connected(_on_enemy_attack_started):
        enemy.attack_started.connect(_on_enemy_attack_started)
    if not enemy.zone_severed.is_connected(_on_enemy_zone_severed):
        enemy.zone_severed.connect(_on_enemy_zone_severed)
    if not enemy.died.is_connected(_on_enemy_died_feedback):
        enemy.died.connect(_on_enemy_died_feedback)

func _on_combat_audio_cue(cue: StringName, zone: StringName, intensity: float) -> void:
    if combat_audio != null:
        combat_audio.play_feedback_cue(cue, zone, intensity)

func _on_player_combat_hit(_target: Node, zone: StringName, hit: Variant) -> void:
    if hit == null:
        return
    var contact: StringName = StringName(hit.contact_type)
    var defended: bool = contact in [&"shield", &"parry", &"armor", &"guard_break"]
    var contact_count: int = 1
    if gore_hud != null:
        contact_count = gore_hud.register_contact(zone, float(hit.damage), defended)
    if combat_audio != null:
        combat_audio.play_hit_confirm(zone, contact_count, defended)

func _on_combat_cinematic_started(kind: StringName, intensity: float) -> void:
    if gore_hud != null:
        gore_hud.register_cinematic(kind, intensity)

func _on_player_perfect_response(kind: StringName) -> void:
    if gore_hud != null:
        gore_hud.register_perfect_response(kind)

func _on_player_perfect_response_consumed() -> void:
    if gore_hud != null:
        gore_hud.consume_perfect_response()

func _on_player_movement_sfx_requested(kind: StringName) -> void:
    if combat_audio != null:
        combat_audio.play_movement_sfx(kind)

func _on_player_damage_received(damage: float, _attacker: Node) -> void:
    if combat_audio != null:
        combat_audio.play_player_hurt(damage)
    if gore_hud != null:
        gore_hud.register_player_hurt(damage)

func _on_enemy_attack_started(enemy: Node, weapon_kind: StringName) -> void:
    if combat_audio == null or player == null or not (enemy is Node3D):
        return
    var distance_to_player: float = (enemy as Node3D).global_position.distance_to(player.global_position)
    if distance_to_player <= 10.5:
        combat_audio.play_enemy_swing(weapon_kind, distance_to_player)

func _on_enemy_localized_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float) -> void:
    if gore_hud != null:
        var combo_count: int = gore_hud.register_hit(enemy, zone, damage, sever_damage)
        if combat_audio != null:
            combat_audio.play_combo_tick(combo_count)

func _on_enemy_zone_severed(enemy: Node, zone: StringName) -> void:
    if combat_audio != null:
        combat_audio.play_sever(zone)
    if gore_hud != null:
        gore_hud.register_sever(enemy, zone)

func _on_enemy_died_feedback(enemy: Node) -> void:
    var archetype_id: StringName = &"swordsman"
    if enemy is HopliteAthenianEnemy:
        var typed_enemy := enemy as HopliteAthenianEnemy
        archetype_id = typed_enemy.archetype_id
    if combat_audio != null:
        combat_audio.play_kill(archetype_id)
    if gore_hud != null:
        gore_hud.register_kill(enemy)

func _build_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.18, 0.24, 0.38)
    sky_mat.sky_horizon_color = Color(0.88, 0.50, 0.24)
    sky_mat.ground_bottom_color = Color(0.055, 0.025, 0.018)
    sky_mat.ground_horizon_color = Color(0.34, 0.16, 0.08)
    sky.sky_material = sky_mat
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.62
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    world_environment.environment = environment
    add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
    sun.light_color = Color(1.0, 0.70, 0.49)
    sun.light_energy = 1.28
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 150.0
    add_child(sun)

func _build_battlefield() -> void:
    var earth := Color(0.20, 0.095, 0.055)
    var road := Color(0.28, 0.19, 0.12)
    var stone := Color(0.48, 0.39, 0.28)
    var dark_stone := Color(0.31, 0.25, 0.21)
    var house := Color(0.57, 0.37, 0.22)
    var wood := Color(0.20, 0.095, 0.035)

    # One continuous collision floor keeps combat/parkour deterministic while the
    # visible zoning comes from thinner road/courtyard overlays.
    _add_box("BattleGround", Vector3(92.0, 0.35, 270.0), Vector3(0.0, -0.18, -41.0), earth, true)
    _add_box("OuterRoad", Vector3(20.0, 0.045, 78.0), Vector3(0.0, 0.025, 43.0), road, false)
    _add_box("CityRoad", Vector3(16.0, 0.045, 112.0), Vector3(0.0, 0.025, -53.0), road, false)
    _add_box("CitadelFloor", Vector3(50.0, 0.05, 37.0), Vector3(0.0, 0.03, -132.0), dark_stone, false)

    # OUTER WALL / CITY ENTRANCE.
    _add_box("OuterWall_L", Vector3(34.0, 6.0, 2.2), Vector3(-21.0, 3.0, 3.0), stone, true)
    _add_box("OuterWall_R", Vector3(34.0, 6.0, 2.2), Vector3(21.0, 3.0, 3.0), stone, true)
    _add_tower(Vector3(-36.0, 0.0, 3.0), stone)
    _add_tower(Vector3(36.0, 0.0, 3.0), stone)
    outer_gate = _create_lift_gate("OuterGate", Vector3(0.0, 2.65, 3.0), Vector3(8.0, 5.3, 0.75), wood)
    _add_debug_world_label("PHASE 1 — OUTER ASSAULT", Vector3(0.0, 7.2, 7.0))

    # Tall city perimeter. The player cannot simply mantle around phase gates.
    _add_box("CityBoundary_L", Vector3(2.2, 7.0, 116.0), Vector3(-38.0, 3.5, -54.0), stone, true)
    _add_box("CityBoundary_R", Vector3(2.2, 7.0, 116.0), Vector3(38.0, 3.5, -54.0), stone, true)

    # CITY A: broad entrance plaza, a climbable terrace and a false side route.
    _add_box("HouseA_L1", Vector3(13.0, 4.5, 13.0), Vector3(-28.0, 2.25, -15.0), house, true)
    _add_box("HouseA_R1", Vector3(14.0, 5.4, 11.0), Vector3(27.0, 2.7, -17.0), house.darkened(0.05), true)
    _add_box("TerraceA", Vector3(7.0, 1.45, 5.0), Vector3(-8.0, 0.725, -23.0), stone, true)
    _add_box("TerraceAHigh", Vector3(5.0, 2.25, 4.0), Vector3(-15.0, 1.125, -27.0), dark_stone, true)
    _add_box("DeadEndA_Wall", Vector3(1.1, 3.0, 11.0), Vector3(17.0, 1.5, -24.0), stone, true)
    _add_box("DeadEndA_Back", Vector3(10.0, 3.0, 1.0), Vector3(21.5, 1.5, -29.0), stone, true)
    city_gate_a = _add_cross_wall_with_gate("CityGateA", -37.0, 10.0, 8.0, 4.6, stone, wood)
    _create_encounter_trigger(&"city_a", Vector3(0.0, 1.0, -11.5), Vector3(25.0, 2.2, 4.0))
    _add_debug_world_label("AMBUSH A", Vector3(0.0, 5.0, -18.0))

    # CITY B: offset route; the central low wall is a deliberate parkour shortcut.
    _add_box("HouseB_L1", Vector3(16.0, 5.6, 10.0), Vector3(-27.0, 2.8, -46.0), house.darkened(0.08), true)
    _add_box("HouseB_R1", Vector3(11.0, 4.2, 14.0), Vector3(29.0, 2.1, -50.0), house, true)
    _add_box("ClimbShortcutB", Vector3(8.0, 2.05, 1.2), Vector3(1.0, 1.025, -51.0), stone, true)
    _add_box("AlleyB_Left", Vector3(1.0, 3.1, 14.0), Vector3(-15.0, 1.55, -55.0), stone, true)
    _add_box("AlleyB_Right", Vector3(1.0, 3.1, 9.0), Vector3(14.5, 1.55, -51.0), stone, true)
    _add_box("CrateB1", Vector3(2.0, 1.2, 2.0), Vector3(8.5, 0.6, -59.0), wood, true)
    _add_box("CrateB2", Vector3(2.6, 1.8, 2.2), Vector3(11.0, 0.9, -61.0), wood, true)
    city_gate_b = _add_cross_wall_with_gate("CityGateB", -70.0, -11.0, 8.0, 4.6, stone, wood)
    _create_encounter_trigger(&"city_b", Vector3(5.0, 1.0, -43.0), Vector3(25.0, 2.2, 4.0))
    _add_debug_world_label("AMBUSH B — PARKOUR OPTIONS", Vector3(0.0, 5.0, -52.0))

    # CITY C: denser final urban arena, several cul-de-sacs and climbable pockets.
    _add_box("HouseC_L1", Vector3(12.0, 5.0, 13.0), Vector3(-29.0, 2.5, -80.0), house, true)
    _add_box("HouseC_R1", Vector3(13.0, 5.7, 11.0), Vector3(28.0, 2.85, -82.0), house.darkened(0.07), true)
    _add_box("HouseC_L2", Vector3(9.0, 4.2, 10.0), Vector3(-20.0, 2.1, -98.0), house.darkened(0.12), true)
    _add_box("HouseC_R2", Vector3(9.0, 4.8, 12.0), Vector3(22.0, 2.4, -96.0), house, true)
    _add_box("MazeC_1", Vector3(1.0, 2.2, 12.0), Vector3(-8.0, 1.1, -84.0), stone, true)
    _add_box("MazeC_2", Vector3(13.0, 1.55, 1.0), Vector3(-1.5, 0.775, -90.0), stone, true)
    _add_box("MazeC_3", Vector3(1.0, 2.45, 11.0), Vector3(9.0, 1.225, -94.0), stone, true)
    _add_box("DeadEndC_Back", Vector3(8.0, 2.8, 1.0), Vector3(-13.0, 1.4, -101.0), stone, true)
    inner_gate = _add_cross_wall_with_gate("InnerCitadelGate", -109.0, 0.0, 8.0, 6.0, dark_stone, wood.darkened(0.18))
    _create_encounter_trigger(&"city_c", Vector3(-4.0, 1.0, -76.0), Vector3(25.0, 2.2, 4.0))
    _add_debug_world_label("AMBUSH C — INNER CITY", Vector3(0.0, 5.0, -86.0))

    # FINAL CITADEL: deliberately clean arena. Only the final commander and his
    # close guard spawn here after all urban skirmishes are cleared.
    _add_box("CitadelWall_L", Vector3(2.2, 7.0, 43.0), Vector3(-27.0, 3.5, -132.0), dark_stone, true)
    _add_box("CitadelWall_R", Vector3(2.2, 7.0, 43.0), Vector3(27.0, 3.5, -132.0), dark_stone, true)
    _add_box("CitadelBack", Vector3(56.0, 7.0, 2.2), Vector3(0.0, 3.5, -153.0), dark_stone, true)
    _add_column(Vector3(-17.0, 0.0, -128.0), stone)
    _add_column(Vector3(17.0, 0.0, -128.0), stone)
    _add_column(Vector3(-17.0, 0.0, -145.0), stone)
    _add_column(Vector3(17.0, 0.0, -145.0), stone)
    _create_encounter_trigger(&"final", Vector3(0.0, 1.0, -116.0), Vector3(16.0, 2.2, 3.5))
    _add_debug_world_label("FINAL COURTYARD", Vector3(0.0, 6.0, -128.0))

func _spawn_outer_battle() -> void:
    # Three captain-centered groups plus a loose front line = 24 combatants at once.
    # Regular soldiers use mass_battle_mode so the stress test stays practical:
    # anatomy/gore/AI remain exact, while only captains instantiate full UAL2 donors.
    var captain_x: Array[float] = [-18.0, 0.0, 18.0]
    var guard_types: Array[StringName] = [&"guardian", &"spearman", &"swordsman", &"flanker", &"brute"]
    for squad: int in range(3):
        var captain: HopliteAthenianEnemy = _spawn_enemy(Vector3(captain_x[squad], 0.05, 13.0 + absf(captain_x[squad]) * 0.08), &"captain", null, squad * 5, true, false)
        _register_outer_enemy(captain)
        for i: int in range(guard_types.size()):
            var angle: float = (TAU / float(guard_types.size())) * float(i) + float(squad) * 0.35
            var radius: float = 3.0 + float(i % 2) * 0.7
            var pos := Vector3(captain_x[squad] + cos(angle) * radius, 0.05, 15.5 + sin(angle) * radius)
            var guard: HopliteAthenianEnemy = _spawn_enemy(pos, guard_types[i], captain, i, false, true)
            _register_outer_enemy(guard)

    var front_positions: Array[Vector3] = [
        Vector3(-16.0, 0.05, 43.0), Vector3(-9.0, 0.05, 48.0),
        Vector3(-2.0, 0.05, 39.0), Vector3(6.0, 0.05, 46.0),
        Vector3(13.0, 0.05, 40.0), Vector3(20.0, 0.05, 50.0)
    ]
    var front_types: Array[StringName] = [&"flanker", &"swordsman", &"spearman", &"swordsman", &"guardian", &"flanker"]
    for i: int in range(front_positions.size()):
        var soldier: HopliteAthenianEnemy = _spawn_enemy(front_positions[i], front_types[i], null, i, false, true)
        _register_outer_enemy(soldier)

func _spawn_spartan_allies() -> void:
    # Two loose Spartan files enter the already-active outer battle from the
    # player's flanks. They select Athenians independently; only Athenian deaths
    # advance the encounter counter, regardless of who lands the finishing blow.
    var positions: Array[Vector3] = [
        Vector3(-17.0, 0.05, 61.0), Vector3(-12.0, 0.05, 66.0),
        Vector3(-7.0, 0.05, 58.0), Vector3(-2.5, 0.05, 64.0),
        Vector3(3.5, 0.05, 59.0), Vector3(8.5, 0.05, 66.0),
        Vector3(13.5, 0.05, 60.0), Vector3(18.0, 0.05, 65.0),
        Vector3(-21.0, 0.05, 69.0), Vector3(21.0, 0.05, 70.0)
    ]
    var types: Array[StringName] = [
        &"guardian", &"spearman", &"swordsman", &"spearman", &"guardian",
        &"swordsman", &"spearman", &"guardian", &"swordsman", &"spearman"
    ]
    for index: int in range(positions.size()):
        _spawn_spartan(positions[index], types[index], index)

func _spawn_spartan(position_value: Vector3, archetype: StringName, formation_index: int) -> HopliteAthenianEnemy:
    var request: EnemySpawnRequest = EnemySpawnRequest.new()
    request.archetype = archetype
    request.position = position_value
    request.has_name_override = true
    request.name_override = "Battle01_Spartan_%s_%02d" % [String(archetype), formation_index]
    request.ai_enabled = true
    request.has_battle_player_override = true
    request.battle_player_override = player
    request.faction = &"spartan"
    request.guard_index = formation_index
    request.has_is_miniboss_override = true
    request.is_miniboss_override = false
    request.mass_battle_mode = true
    var ally := EnemyFactoryScript.spawn_request(self, request)
    if not ally.attack_started.is_connected(_on_enemy_attack_started):
        ally.attack_started.connect(_on_enemy_attack_started)
    ally.set_combat_debug_visible(debug_overlay_visible)
    return ally

func _register_outer_enemy(enemy: Node) -> void:
    if enemy == null:
        return
    outer_alive += 1
    if enemy.has_signal("died"):
        enemy.died.connect(_on_outer_enemy_died)

func _on_outer_enemy_died(_enemy: Node) -> void:
    outer_alive = maxi(0, outer_alive - 1)
    if outer_alive == 0:
        _open_gate(outer_gate, 6.2)

func _spawn_city_encounter(encounter_id: StringName) -> void:
    if encounter_alive.has(encounter_id):
        return

    var captain_position := Vector3.ZERO
    var positions: Array[Vector3] = []
    var types: Array[StringName] = []

    match encounter_id:
        &"city_a":
            captain_position = Vector3(8.5, 0.05, -31.0)
            positions = [
                Vector3(-8.0, 0.05, -14.0), Vector3(8.0, 0.05, -14.0),
                Vector3(-13.0, 0.05, -25.0), Vector3(13.0, 0.05, -24.0),
                Vector3(1.0, 0.05, -27.0), Vector3(18.0, 0.05, -29.0)
            ]
            types = [&"flanker", &"swordsman", &"spearman", &"guardian", &"swordsman", &"brute"]
        &"city_b":
            captain_position = Vector3(-10.0, 0.05, -64.0)
            positions = [
                Vector3(10.0, 0.05, -45.0), Vector3(-5.0, 0.05, -47.0),
                Vector3(17.0, 0.05, -55.0), Vector3(-20.0, 0.05, -54.0),
                Vector3(4.0, 0.05, -59.0), Vector3(-10.0, 0.05, -58.0),
                Vector3(20.0, 0.05, -64.0)
            ]
            types = [&"spearman", &"flanker", &"guardian", &"flanker", &"brute", &"swordsman", &"spearman"]
        &"city_c":
            captain_position = Vector3(0.0, 0.05, -103.0)
            positions = [
                Vector3(-16.0, 0.05, -78.0), Vector3(15.0, 0.05, -79.0),
                Vector3(-3.0, 0.05, -82.0), Vector3(5.0, 0.05, -88.0),
                Vector3(-18.0, 0.05, -92.0), Vector3(18.0, 0.05, -93.0),
                Vector3(-3.0, 0.05, -99.0), Vector3(11.0, 0.05, -101.0)
            ]
            types = [&"flanker", &"spearman", &"guardian", &"brute", &"swordsman", &"flanker", &"spearman", &"guardian"]
        _:
            return

    var count: int = 1 + positions.size()
    encounter_alive[encounter_id] = count
    var captain: HopliteAthenianEnemy = _spawn_enemy(captain_position, &"captain", null, 0, true, false)
    # Urban minibosses are deliberately one tier above the three wall captains.
    # Uniform node scale keeps skeleton, anatomy and collider aligned.
    captain.max_health *= 1.18
    captain.health = captain.max_health
    captain.ai_attack_damage *= 1.12
    captain.scale = captain.scale * 1.05
    captain.died.connect(_on_city_enemy_died.bind(encounter_id))

    for i: int in range(positions.size()):
        var enemy: HopliteAthenianEnemy = _spawn_enemy(positions[i], types[i], captain, i, false, false)
        enemy.died.connect(_on_city_enemy_died.bind(encounter_id))

func _on_city_enemy_died(_enemy: Node, encounter_id: StringName) -> void:
    var remaining: int = maxi(0, int(encounter_alive.get(encounter_id, 0)) - 1)
    encounter_alive[encounter_id] = remaining
    if remaining > 0:
        return
    match encounter_id:
        &"city_a": _open_gate(city_gate_a, 5.4)
        &"city_b": _open_gate(city_gate_b, 5.4)
        &"city_c": _open_gate(inner_gate, 6.5)

func _spawn_final_encounter() -> void:
    if final_alive > 0 or battle_complete:
        return

    final_boss = _spawn_enemy(Vector3(0.0, 0.05, -143.0), &"warlord", null, 0, true, false)
    final_alive = 1
    final_boss.died.connect(_on_final_enemy_died)

    var guard_positions: Array[Vector3] = [
        Vector3(-8.0, 0.05, -137.0), Vector3(8.0, 0.05, -137.0),
        Vector3(-12.0, 0.05, -145.0), Vector3(12.0, 0.05, -145.0),
        Vector3(-5.0, 0.05, -149.0), Vector3(5.0, 0.05, -149.0)
    ]
    var guard_types: Array[StringName] = [&"guardian", &"guardian", &"spearman", &"spearman", &"brute", &"flanker"]
    for i: int in range(guard_positions.size()):
        var guard: HopliteAthenianEnemy = _spawn_enemy(guard_positions[i], guard_types[i], final_boss, i, false, false)
        final_alive += 1
        guard.died.connect(_on_final_enemy_died)

func _on_final_enemy_died(_enemy: Node) -> void:
    final_alive = maxi(0, final_alive - 1)
    if final_alive == 0:
        battle_complete = true
        _spawn_victory_portal()

func _create_encounter_trigger(encounter_id: StringName, position_value: Vector3, size: Vector3) -> void:
    var area := Area3D.new()
    area.name = "Trigger_%s" % String(encounter_id)
    area.position = position_value
    area.collision_layer = 0
    area.collision_mask = 2
    area.monitoring = true
    add_child(area)
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    area.add_child(shape_node)
    area.body_entered.connect(_on_encounter_trigger_entered.bind(encounter_id, area))

func _on_encounter_trigger_entered(body: Node3D, encounter_id: StringName, area: Area3D) -> void:
    if body != player or triggered_encounters.has(encounter_id):
        return
    triggered_encounters[encounter_id] = true
    area.set_deferred("monitoring", false)
    if encounter_id == &"final":
        _spawn_final_encounter()
    else:
        _spawn_city_encounter(encounter_id)

func _spawn_enemy(position_value: Vector3, archetype: StringName, boss_ref: Node3D = null, guard_index: int = 0, elite: bool = false, mass_mode: bool = false) -> HopliteAthenianEnemy:
    var request: EnemySpawnRequest = EnemySpawnRequest.new()
    request.archetype = archetype
    request.position = position_value
    request.target = player
    request.has_name_override = true
    request.name_override = "Battle01_%s_%03d" % [String(archetype), get_tree().get_nodes_in_group("enemy").size()]
    request.ai_enabled = true
    request.commander = boss_ref
    request.guard_index = guard_index
    request.has_is_miniboss_override = true
    request.is_miniboss_override = elite
    request.mass_battle_mode = mass_mode
    var enemy := EnemyFactoryScript.spawn_request(self, request)
    _wire_enemy_feedback(enemy)
    enemy.set_combat_debug_visible(debug_overlay_visible)
    return enemy

func _add_cross_wall_with_gate(node_name: String, z_value: float, gate_x: float, gate_width: float, height: float, wall_color: Color, gate_color: Color) -> AnimatableBody3D:
    var half_width: float = 38.0
    var gate_left: float = gate_x - gate_width * 0.5
    var gate_right: float = gate_x + gate_width * 0.5
    var left_width: float = gate_left + half_width
    var right_width: float = half_width - gate_right
    if left_width > 0.1:
        _add_box(node_name + "_L", Vector3(left_width, height, 1.4), Vector3(-half_width + left_width * 0.5, height * 0.5, z_value), wall_color, true)
    if right_width > 0.1:
        _add_box(node_name + "_R", Vector3(right_width, height, 1.4), Vector3(gate_right + right_width * 0.5, height * 0.5, z_value), wall_color, true)
    return _create_lift_gate(node_name + "_Gate", Vector3(gate_x, height * 0.5, z_value), Vector3(gate_width, height, 0.72), gate_color)

func _create_lift_gate(node_name: String, position_value: Vector3, size: Vector3, color: Color) -> AnimatableBody3D:
    var gate := AnimatableBody3D.new()
    gate.name = node_name
    gate.position = position_value
    gate.collision_layer = 1
    gate.collision_mask = 0
    add_child(gate)

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _make_material(color, 0.74)
    gate.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    gate.add_child(collision)

    # Vertical bronze/wood bars make it read as a gate instead of a solid wall.
    for x: float in [-size.x * 0.32, -size.x * 0.11, size.x * 0.11, size.x * 0.32]:
        var bar := MeshInstance3D.new()
        var bar_mesh := BoxMesh.new()
        bar_mesh.size = Vector3(0.13, size.y * 1.03, size.z * 1.18)
        bar.mesh = bar_mesh
        bar.position.x = x
        bar.material_override = _make_material(color.lightened(0.16), 0.55)
        gate.add_child(bar)
    return gate

func _open_gate(gate: AnimatableBody3D, lift: float) -> void:
    if gate == null or opened_gates.has(gate.get_instance_id()):
        return
    opened_gates[gate.get_instance_id()] = true
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(gate, "position:y", gate.position.y + lift, 0.85)

func _add_box(node_name: String, size: Vector3, position_value: Vector3, color: Color, collision_enabled: bool) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = position_value
    add_child(body)
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = _make_material(color, 0.82)
    body.add_child(mi)
    if collision_enabled:
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        cs.shape = shape
        body.add_child(cs)
        body.collision_layer = 1
    else:
        body.collision_layer = 0
    return body

func _add_tower(position_value: Vector3, color: Color) -> void:
    _add_box("Tower_%d" % get_child_count(), Vector3(5.2, 8.0, 5.2), position_value + Vector3.UP * 4.0, color.darkened(0.04), true)
    _add_box("TowerTop_%d" % get_child_count(), Vector3(6.0, 0.65, 6.0), position_value + Vector3.UP * 8.15, color.lightened(0.08), true)

func _add_column(position_value: Vector3, color: Color) -> void:
    var root := Node3D.new()
    root.position = position_value
    add_child(root)
    var shaft := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.height = 4.8
    cylinder.top_radius = 0.30
    cylinder.bottom_radius = 0.40
    shaft.mesh = cylinder
    shaft.position.y = 2.4
    shaft.material_override = _make_material(color, 0.72)
    root.add_child(shaft)
    var top := MeshInstance3D.new()
    var top_mesh := BoxMesh.new()
    top_mesh.size = Vector3(1.20, 0.24, 0.90)
    top.mesh = top_mesh
    top.position.y = 4.84
    top.material_override = _make_material(color.lightened(0.08), 0.72)
    root.add_child(top)

func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat

func _add_debug_world_label(text_value: String, position_value: Vector3) -> void:
    var label := Label3D.new()
    label.text = text_value
    label.position = position_value
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 34
    label.modulate = Color(1.0, 0.85, 0.48)
    label.visible = debug_overlay_visible
    add_child(label)
    debug_world_labels.append(label)

func _build_return_to_training_portal() -> void:
    _add_scene_portal("ReturnPortal", Vector3(0.0, 0.0, 89.0), "RETURN TO TRAINING", TUTORIAL_SCENE, Color(0.18, 0.55, 0.95))

func _spawn_victory_portal() -> void:
    if return_portal_created:
        return
    return_portal_created = true
    _add_scene_portal("VictoryPortal", Vector3(0.0, 0.0, -149.0), "BATTLE COMPLETE", TUTORIAL_SCENE, Color(0.95, 0.64, 0.12))

func _add_scene_portal(node_name: String, position_value: Vector3, label_text: String, destination: String, color: Color) -> void:
    var root := Node3D.new()
    root.name = node_name
    root.position = position_value
    add_child(root)

    for x: float in [-2.0, 2.0]:
        var pillar := MeshInstance3D.new()
        var pillar_mesh := BoxMesh.new()
        pillar_mesh.size = Vector3(0.65, 3.4, 0.65)
        pillar.mesh = pillar_mesh
        pillar.position = Vector3(x, 1.7, 0.0)
        var pillar_mat := _make_material(color.darkened(0.48), 0.62)
        pillar.material_override = pillar_mat
        root.add_child(pillar)
    var lintel := MeshInstance3D.new()
    var lintel_mesh := BoxMesh.new()
    lintel_mesh.size = Vector3(4.65, 0.55, 0.65)
    lintel.mesh = lintel_mesh
    lintel.position = Vector3(0.0, 3.25, 0.0)
    lintel.material_override = _make_material(color.darkened(0.35), 0.62)
    root.add_child(lintel)

    var portal_visual := MeshInstance3D.new()
    var portal_mesh := BoxMesh.new()
    portal_mesh.size = Vector3(3.25, 2.45, 0.08)
    portal_visual.mesh = portal_mesh
    portal_visual.position = Vector3(0.0, 1.45, 0.0)
    var portal_mat := StandardMaterial3D.new()
    portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    portal_mat.albedo_color = Color(color.r, color.g, color.b, 0.28)
    portal_mat.emission_enabled = true
    portal_mat.emission = color * 1.6
    portal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    portal_visual.material_override = portal_mat
    root.add_child(portal_visual)

    var label := Label3D.new()
    label.text = label_text
    label.position = Vector3(0.0, 3.95, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 38
    label.modulate = color.lightened(0.24)
    root.add_child(label)

    var area := Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 2
    root.add_child(area)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(3.4, 2.9, 1.6)
    collision.shape = shape
    collision.position.y = 1.45
    area.add_child(collision)
    area.body_entered.connect(_on_scene_portal_entered.bind(destination))

func _on_scene_portal_entered(body: Node3D, destination: String) -> void:
    if body != player:
        return
    call_deferred("_change_scene", destination)

func _change_scene(destination: String) -> void:
    get_tree().change_scene_to_file(destination)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var health_background := ColorRect.new()
    health_background.visible = false
    health_background.position = Vector2(18, 18)
    health_background.size = Vector2(302, 34)
    health_background.color = Color(0.025, 0.02, 0.025, 0.90)
    layer.add_child(health_background)

    var health_track := ColorRect.new()
    health_track.position = Vector2(8, 8)
    health_track.size = Vector2(HEALTH_BAR_WIDTH, 18)
    health_track.color = Color(0.16, 0.045, 0.045, 0.96)
    health_background.add_child(health_track)

    health_bar_fill = ColorRect.new()
    health_bar_fill.position = Vector2(8, 8)
    health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, 18)
    health_bar_fill.color = Color(0.72, 0.055, 0.035, 1.0)
    health_background.add_child(health_bar_fill)

    health_bar_label = Label.new()
    health_bar_label.position = Vector2(12, 5)
    health_bar_label.size = Vector2(278, 24)
    health_bar_label.text = "SPARTAN"
    health_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    health_bar_label.add_theme_font_size_override("font_size", 12)
    health_background.add_child(health_bar_label)

    debug_panel = ColorRect.new()
    debug_panel.position = Vector2(14, 64)
    debug_panel.size = Vector2(1235, 232)
    debug_panel.color = Color(0.025, 0.025, 0.035, 0.86)
    debug_panel.visible = false
    layer.add_child(debug_panel)

    debug_title = Label.new()
    debug_title.position = Vector2(28, 74)
    debug_title.text = "PROJECT HOPLITE — V0.0.15 SUNO SFX"
    debug_title.add_theme_font_size_override("font_size", 23)
    debug_title.visible = false
    layer.add_child(debug_title)

    debug_help = Label.new()
    debug_help.position = Vector2(28, 106)
    debug_help.text = "LMB court = rapide • LMB maintenu = lourde + aim assist fort • RMB = bouclier • molette haut/A = spirale decapitation • molette bas = plongeon tournoyant\nSpirales = aim assist fort • Aerien = gros bonus de degats • I = diagnostics • G = gore/combo HUD • ² = réglages caméra/audio"
    debug_help.add_theme_font_size_override("font_size", 14)
    debug_help.visible = false
    layer.add_child(debug_help)

    debug_label = Label.new()
    debug_label.position = Vector2(28, 164)
    debug_label.text = "Battle initializing..."
    debug_label.add_theme_font_size_override("font_size", 13)
    debug_label.visible = false
    layer.add_child(debug_label)

func _update_player_health_bar() -> void:
    if player == null or health_bar_fill == null or health_bar_label == null:
        return
    var maximum: float = maxf(player.max_health, 1.0)
    var ratio: float = clampf(player.health / maximum, 0.0, 1.0)
    health_bar_fill.size.x = HEALTH_BAR_WIDTH * ratio
    var defense_text: String = "   BOUCLIER" if player.shield_blocking else ""
    health_bar_label.text = "SPARTAN   %.0f / %.0f%s" % [player.health, player.max_health, defense_text]
