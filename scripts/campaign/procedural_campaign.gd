extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CombatAudioScript = preload("res://scripts/audio/combat_audio.gd")
const GoreHUDScript = preload("res://scripts/ui/gore_hud.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")
const CrowdDirectorScript = preload("res://scripts/ai/battle_crowd_director.gd")
const MapGeneratorScript = preload("res://scripts/campaign/procedural_map_generator.gd")
const WaveDirectorScript = preload("res://scripts/campaign/procedural_wave_director.gd")
const LoadingScreenScript = preload("res://scripts/campaign/campaign_loading_screen.gd")
const AtmospherePanelScript = preload("res://scripts/campaign/atmosphere_control_panel.gd")

const TRAINING_SCENE := "res://lobby.tscn"
const ZONES: Array[StringName] = [&"walls", &"city", &"dungeon"]
const HEALTH_BAR_WIDTH := 310.0
const BOSS_BAR_WIDTH := 610.0
const TEST_IMMORTALITY := true

var campaign_seed: int
var zone_index := -1
var zone_root: Node3D
var current_layout: Dictionary = {}
var map_generator: HopliteProceduralMapGenerator
var wave_director: HopliteProceduralWaveDirector
var loading_screen: HopliteCampaignLoadingScreen
var atmosphere_panel
var player: HopliteUALNativePlayer
var combat_audio: HopliteCombatAudio
var gore_hud: HopliteGoreHUD
var audio_settings: HopliteAudioSettings
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var active_boss: HopliteAthenianEnemy
var campaign_state: StringName = &"boot"
var total_kills := 0
var wave_total := 0
var test_recovery_cooldown := 0.0
var player_safety_timer := 0.0
var safe_player_spawn := Vector3.ZERO

var act_label: Label
var objective_label: Label
var wave_label: Label
var counter_label: Label
var health_fill: ColorRect
var health_label: Label
var boss_panel: Control
var boss_fill: ColorRect
var boss_label: Label
var announcement: Label
var announcement_tween: Tween
var end_overlay: ColorRect
var end_title: Label
var end_subtitle: Label

func _ready() -> void:
	campaign_seed = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())
	_build_environment()
	_build_ui()
	_build_runtime_systems()
	call_deferred("_start_campaign")

func _process(delta: float) -> void:
	_update_hud()
	test_recovery_cooldown = maxf(0.0, test_recovery_cooldown - delta)
	player_safety_timer = maxf(0.0, player_safety_timer - delta)
	if campaign_state == &"combat" and player_safety_timer <= 0.0:
		player_safety_timer = 0.25
		_audit_player_position()
	if campaign_state == &"combat" and player != null and player.health <= 0.0:
		if TEST_IMMORTALITY:
			_recover_test_player()
		else:
			_defeat()

func _recover_test_player() -> void:
	if test_recovery_cooldown > 0.0:
		return
	test_recovery_cooldown = 2.5
	player.health = player.max_health
	player.enemy_hit_invulnerability_timer = 2.5
	player.velocity = Vector3.ZERO
	print("[PROCEDURAL CAMPAIGN] Test immortality restored the player.")
	if announcement != null and is_inside_tree():
		_announce("MODE TEST — IMMORTEL", "Vos PV ont ete restaures pour poursuivre la campagne.", Color(0.46, 0.92, 0.72))

func _audit_player_position() -> void:
	if player == null or current_layout.is_empty():
		return
	var bounds := current_layout.get("safe_bounds", Rect2(-100.0, -100.0, 200.0, 200.0)) as Rect2
	var horizontal := Vector2(player.global_position.x, player.global_position.z)
	if player.global_position.y < -2.0 or not bounds.has_point(horizontal):
		player.global_position = safe_player_spawn
		player.velocity = Vector3.ZERO
		player.enemy_hit_invulnerability_timer = maxf(player.enemy_hit_invulnerability_timer, 1.5)
		if announcement != null:
			_announce("REPLI SECURISE", "Retour sur la zone de combat.", Color(0.52, 0.78, 1.0))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_settings") and audio_settings != null and not audio_settings.is_open():
		audio_settings.set_open(true)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_O and atmosphere_panel != null and not atmosphere_panel.is_open() and campaign_state not in [&"defeat", &"victory"]:
		atmosphere_panel.set_open(true)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_P and player != null and (atmosphere_panel == null or not atmosphere_panel.is_open()) and campaign_state not in [&"loading", &"defeat", &"victory"]:
		player.cycle_player_skin()
		_announce("APPARENCE DU JOUEUR", player.get_player_skin_label(), Color(0.82, 0.70, 1.0))
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_R and campaign_state in [&"defeat", &"victory"]:
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and campaign_state in [&"defeat", &"victory"]:
		get_tree().change_scene_to_file(TRAINING_SCENE)
		get_viewport().set_input_as_handled()
	elif _is_settings_key(key) and audio_settings != null and not audio_settings.is_open():
		audio_settings.set_open(true)
		get_viewport().set_input_as_handled()

func _start_campaign() -> void:
	zone_index = 0
	total_kills = 0
	player.health = player.max_health
	await _load_zone(zone_index)

func _load_zone(index: int) -> void:
	campaign_state = &"loading"
	zone_index = index
	var zone_id := ZONES[zone_index]
	var titles := ["PRISE DES MURAILLES", "PRISE DE LA VILLE", "PRISE DU DONJON"]
	var tips := [
		"Les ennemis de masse attaquent par cercles : ouvrez une sortie avant d'etre encercle.",
		"Les places sont plus sures que les ruelles. Utilisez le parkour pour rompre la pression.",
		"Les cercles rouges annoncent les ondes de choc de NFullArmor. Gardez votre dash."
	]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await loading_screen.transition_in(zone_index + 1, titles[zone_index], tips[zone_index])
	wave_director.stop_and_clear()
	active_boss = null
	boss_panel.visible = false
	if zone_root != null and is_instance_valid(zone_root):
		zone_root.queue_free()
		zone_root = null
	await get_tree().process_frame
	loading_screen.set_progress(0.36, "ASSEMBLAGE DU TERRAIN")
	_configure_environment(zone_id)
	current_layout = map_generator.generate(self, zone_id, campaign_seed + zone_index * 104729)
	zone_root = current_layout.get("zone_root") as Node3D
	# Static bodies enter the physics space on the next physics tick. Waiting here
	# prevents the act-III character from integrating one frame over an absent floor.
	await get_tree().physics_frame
	loading_screen.set_progress(0.66, "DEPLOIEMENT DES LEGIONS")
	safe_player_spawn = current_layout.get("player_spawn", Vector3.ZERO)
	player.global_position = safe_player_spawn
	player.velocity = Vector3.ZERO
	player.health = minf(player.max_health, player.health + player.max_health * (0.46 if zone_index > 0 else 0.0))
	var entry_reinforcement_points: Array[Vector3] = []
	for raw_point: Variant in current_layout.get("entry_reinforcement_points", []):
		if raw_point is Vector3:
			entry_reinforcement_points.append(raw_point as Vector3)
	wave_director.configure(
		self,
		player,
		zone_id,
		current_layout.get("spawn_points", []) as Array[Vector3],
		current_layout.get("boss_spawn", Vector3.ZERO),
		campaign_seed + zone_index * 104729,
		current_layout.get("safe_bounds", Rect2(-100.0, -100.0, 200.0, 200.0)) as Rect2,
		entry_reinforcement_points
	)
	act_label.text = "%s   •   %s" % [String(current_layout.get("title", "")), String(current_layout.get("variant_name", "VARIANTE INCONNUE"))]
	objective_label.text = String(current_layout.get("objective", ""))
	if atmosphere_panel != null:
		atmosphere_panel.refresh_runtime_targets()
	await get_tree().process_frame
	loading_screen.set_progress(0.86, "ALLUMAGE DES BRASEROS")
	await get_tree().process_frame
	loading_screen.set_progress(0.94, "MISE EN PLACE DES DEUX LEGIONS")
	wave_director.prepare_initial_force()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	await loading_screen.transition_out()
	campaign_state = &"combat"
	wave_director.activate_prepared_force()
	_announce("ACTE %s" % ["I", "II", "III"][zone_index], String(current_layout.get("objective", "")), Color(0.91, 0.62, 0.24))

func _on_zone_completed() -> void:
	if campaign_state != &"combat":
		return
	campaign_state = &"transition"
	if zone_index + 1 < ZONES.size():
		_announce("ZONE CONQUISE", "Reprenez votre souffle. La route continue.", Color(0.78, 0.88, 0.62))
		await get_tree().create_timer(2.8).timeout
		await _load_zone(zone_index + 1)
	else:
		_victory()

func _on_wave_started(index: int, total: int, title: String, total_enemies: int) -> void:
	wave_total = total
	wave_label.text = "VAGUE %d / %d   %s" % [index, total, title]
	_announce("VAGUE %d" % index, "%s  •  %d ADVERSAIRES" % [title, total_enemies], Color(0.94, 0.42, 0.13))
	if index > 1:
		player.health = minf(player.max_health, player.health + player.max_health * 0.10)

func _on_wave_progress(alive: int, remaining: int, defeated: int) -> void:
	counter_label.text = "EN VIE  %02d    EN APPROCHE  %02d    TOMBES  %03d" % [alive, remaining, defeated]

func _on_enemy_spawned(enemy: HopliteAthenianEnemy) -> void:
	_wire_enemy_feedback(enemy)

func _on_miniboss_spawned(_enemy: HopliteAthenianEnemy, title: String) -> void:
	_announce("MINIBOSS", title, Color(1.0, 0.72, 0.20))

func _on_boss_spawned(enemy: HopliteAthenianEnemy) -> void:
	active_boss = enemy
	boss_panel.visible = true
	_announce("BOSS FINAL", "NFULLARMOR — LE ROI SOUS LE FER", Color(0.96, 0.16, 0.06))

func _on_boss_phase_started(phase: int, title: String) -> void:
	if phase >= 4:
		_announce("VICTOIRE", title, Color(0.94, 0.78, 0.35))
		return
	var subtitle := "L'armure se fissure. Des renforts entrent dans l'arene." if phase == 2 else "Plus de garde. Plus de retenue. Survivez a la frenesie."
	_announce("PHASE %s" % ["I", "II", "III"][clampi(phase - 1, 0, 2)], title + "\n" + subtitle, Color(1.0, 0.22, 0.055))

func _defeat() -> void:
	campaign_state = &"defeat"
	wave_director.running = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_show_end_screen("LA CITE VOUS A BRISE", "Graine %d  •  %d ennemis abattus\nR — recommencer    ECHAP — retour au lobby" % [campaign_seed, total_kills], Color(0.76, 0.08, 0.035))

func _victory() -> void:
	campaign_state = &"victory"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_show_end_screen("LA CITE EST A VOUS", "NFullArmor est tombe.  %d ennemis abattus.\nGraine %d\nR — nouvelle campagne    ECHAP — retour au lobby" % [total_kills, campaign_seed], Color(0.80, 0.55, 0.18))

func _show_end_screen(title: String, subtitle: String, color: Color) -> void:
	end_title.text = title
	end_title.add_theme_color_override("font_color", color)
	end_subtitle.text = subtitle
	end_overlay.visible = true
	end_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(end_overlay, "modulate:a", 1.0, 0.65)

func _build_runtime_systems() -> void:
	combat_audio = CombatAudioScript.new() as HopliteCombatAudio
	combat_audio.name = "CampaignAudio"
	add_child(combat_audio)
	gore_hud = GoreHUDScript.new() as HopliteGoreHUD
	gore_hud.name = "CampaignGoreHUD"
	add_child(gore_hud)
	var crowd_director := CrowdDirectorScript.new() as HopliteBattleCrowdDirector
	crowd_director.name = "CampaignCrowdDirector"
	add_child(crowd_director)
	wave_director = WaveDirectorScript.new() as HopliteProceduralWaveDirector
	wave_director.name = "ProceduralWaveDirector"
	add_child(wave_director)
	wave_director.wave_started.connect(_on_wave_started)
	wave_director.wave_progress.connect(_on_wave_progress)
	wave_director.enemy_spawned.connect(_on_enemy_spawned)
	wave_director.miniboss_spawned.connect(_on_miniboss_spawned)
	wave_director.boss_spawned.connect(_on_boss_spawned)
	wave_director.boss_phase_started.connect(_on_boss_phase_started)
	wave_director.zone_completed.connect(_on_zone_completed)
	map_generator = MapGeneratorScript.new() as HopliteProceduralMapGenerator
	player = PlayerScript.new() as HopliteUALNativePlayer
	player.name = "LoneHoplite"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	player.damage_received.connect(_on_player_damage_received)
	player.movement_sfx_requested.connect(_on_player_movement_sfx_requested)
	player.combat_hit.connect(_on_player_combat_hit)
	player.perfect_response_started.connect(_on_player_perfect_response)
	player.perfect_response_consumed.connect(_on_player_perfect_response_consumed)
	var feedback := player.get_combat_feedback()
	if feedback != null:
		feedback.audio_cue_requested.connect(_on_combat_audio_cue)
		feedback.cinematic_started.connect(_on_combat_cinematic_started)
	audio_settings = AudioSettingsScript.new() as HopliteAudioSettings
	audio_settings.name = "CampaignSettings"
	audio_settings.combat_audio = combat_audio
	audio_settings.gore_hud = gore_hud
	audio_settings.player = player
	add_child(audio_settings)
	loading_screen = LoadingScreenScript.new() as HopliteCampaignLoadingScreen
	loading_screen.name = "CampaignLoadingScreen"
	add_child(loading_screen)
	atmosphere_panel = AtmospherePanelScript.new()
	atmosphere_panel.name = "AtmosphereControlPanel"
	add_child(atmosphere_panel)
	atmosphere_panel.configure(world_environment, sun)

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "CampaignEnvironment"
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "CampaignSun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130.0
	add_child(sun)
	_configure_environment(&"walls")

func _configure_environment(zone_id: StringName) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	match zone_id:
		&"walls":
			sky_material.sky_top_color = Color("52647a").darkened(0.42)
			sky_material.sky_horizon_color = Color("ffb46a").lerp(Color.WHITE, 0.28)
			sky_material.ground_bottom_color = Color(0.035, 0.018, 0.014)
			sky_material.ground_horizon_color = Color(0.30, 0.12, 0.055)
			sun.rotation_degrees = Vector3(-24.0, -26.0, 0.0)
			sun.light_color = Color("ffb46a")
			sun.light_energy = 1.62
		&"city":
			sky_material.sky_top_color = Color("39465a").darkened(0.42)
			sky_material.sky_horizon_color = Color("d79557").lerp(Color.WHITE, 0.28)
			sky_material.ground_bottom_color = Color(0.07, 0.045, 0.035)
			sky_material.ground_horizon_color = Color(0.34, 0.23, 0.16)
			sun.rotation_degrees = Vector3(-31.0, 18.0, 0.0)
			sun.light_color = Color("d79557")
			sun.light_energy = 1.30
		_:
			sky_material.sky_top_color = Color("202737").darkened(0.52)
			sky_material.sky_horizon_color = Color("c94b32").darkened(0.18)
			sky_material.ground_bottom_color = Color(0.005, 0.004, 0.006)
			sky_material.ground_horizon_color = Color(0.055, 0.025, 0.018)
			sun.rotation_degrees = Vector3(-16.0, -12.0, 0.0)
			sun.light_color = Color("c94b32")
			sun.light_energy = 0.58
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("52647a") if zone_id == &"walls" else (Color("39465a") if zone_id == &"city" else Color("202737"))
	environment.ambient_light_energy = 0.48 if zone_id == &"walls" else (0.34 if zone_id == &"city" else 0.22)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.12 if zone_id == &"walls" else (1.16 if zone_id == &"city" else 1.24)
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("8a6340") if zone_id == &"walls" else (Color("69513d") if zone_id == &"city" else Color("3e1e1b"))
	environment.fog_light_energy = 0.72
	environment.fog_density = 0.009 if zone_id == &"walls" else (0.012 if zone_id == &"city" else 0.020)
	environment.fog_sky_affect = 0.35
	world_environment.environment = environment
	if atmosphere_panel != null:
		atmosphere_panel.sync_from_environment()

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 25
	add_child(canvas)
	var root := Control.new()
	root.add_to_group("global_hud_combat")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var top_back := ColorRect.new()
	top_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_back.offset_bottom = 88.0
	top_back.color = Color(0.018, 0.014, 0.016, 0.83)
	root.add_child(top_back)
	var accent := ColorRect.new()
	accent.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	accent.offset_top = -3.0
	accent.offset_bottom = 0.0
	accent.color = Color(0.74, 0.31, 0.075)
	top_back.add_child(accent)
	act_label = _make_label(top_back, 22, Color(0.94, 0.76, 0.46), HORIZONTAL_ALIGNMENT_LEFT)
	act_label.position = Vector2(28.0, 12.0)
	act_label.size = Vector2(590.0, 30.0)
	objective_label = _make_label(top_back, 16, Color(0.80, 0.79, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	objective_label.position = Vector2(28.0, 45.0)
	objective_label.size = Vector2(720.0, 26.0)
	wave_label = _make_label(top_back, 19, Color(0.94, 0.44, 0.18), HORIZONTAL_ALIGNMENT_RIGHT)
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wave_label.position = Vector2(-590.0, 13.0)
	wave_label.size = Vector2(560.0, 28.0)
	counter_label = _make_label(top_back, 15, Color(0.74, 0.71, 0.67), HORIZONTAL_ALIGNMENT_RIGHT)
	counter_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	counter_label.position = Vector2(-590.0, 46.0)
	counter_label.size = Vector2(560.0, 25.0)

	var health_back := ColorRect.new()
	health_back.visible = false
	health_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_back.position = Vector2(28.0, -53.0)
	health_back.size = Vector2(HEALTH_BAR_WIDTH, 11.0)
	health_back.color = Color(0.11, 0.08, 0.08, 0.92)
	root.add_child(health_back)
	health_fill = ColorRect.new()
	health_fill.size = Vector2(HEALTH_BAR_WIDTH, 11.0)
	health_fill.color = Color(0.73, 0.07, 0.035)
	health_back.add_child(health_fill)
	health_label = _make_label(root, 16, Color(0.94, 0.87, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	health_label.visible = false
	health_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_label.position = Vector2(28.0, -82.0)
	health_label.size = Vector2(420.0, 26.0)

	boss_panel = Control.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	boss_panel.offset_top = -104.0
	boss_panel.offset_bottom = -42.0
	boss_panel.visible = false
	root.add_child(boss_panel)
	boss_label = _make_label(boss_panel, 19, Color(0.96, 0.73, 0.50), HORIZONTAL_ALIGNMENT_CENTER)
	boss_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_label.position = Vector2(-360.0, 0.0)
	boss_label.size = Vector2(720.0, 28.0)
	var boss_back := ColorRect.new()
	boss_back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_back.position = Vector2(-BOSS_BAR_WIDTH * 0.5, 33.0)
	boss_back.size = Vector2(BOSS_BAR_WIDTH, 13.0)
	boss_back.color = Color(0.08, 0.055, 0.055, 0.94)
	boss_panel.add_child(boss_back)
	boss_fill = ColorRect.new()
	boss_fill.size = Vector2(BOSS_BAR_WIDTH, 13.0)
	boss_fill.color = Color(0.88, 0.12, 0.035)
	boss_back.add_child(boss_fill)

	announcement = _make_label(root, 35, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	announcement.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	announcement.position = Vector2(-510.0, 124.0)
	announcement.size = Vector2(1020.0, 110.0)
	announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement.add_theme_constant_override("outline_size", 12)
	announcement.add_theme_color_override("font_outline_color", Color(0.10, 0.008, 0.005, 0.92))
	announcement.modulate.a = 0.0

	var seed_label := _make_label(root, 13, Color(0.48, 0.45, 0.43), HORIZONTAL_ALIGNMENT_RIGHT)
	seed_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	seed_label.position = Vector2(-290.0, -34.0)
	seed_label.size = Vector2(264.0, 22.0)
	seed_label.text = "GENERATION  %d" % campaign_seed
	var controls_label := _make_label(root, 13, Color(0.61, 0.60, 0.63), HORIZONTAL_ALIGNMENT_RIGHT)
	controls_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls_label.position = Vector2(-420.0, -57.0)
	controls_label.size = Vector2(394.0, 22.0)
	controls_label.text = "O  ATMOSPHERE     •     P  APPARENCE"

	end_overlay = ColorRect.new()
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.color = Color(0.012, 0.008, 0.009, 0.94)
	end_overlay.visible = false
	root.add_child(end_overlay)
	end_title = _make_label(end_overlay, 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	end_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	end_title.position = Vector2(-500.0, -110.0)
	end_title.size = Vector2(1000.0, 80.0)
	end_title.add_theme_constant_override("outline_size", 12)
	end_subtitle = _make_label(end_overlay, 20, Color(0.78, 0.73, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	end_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	end_subtitle.position = Vector2(-500.0, -15.0)
	end_subtitle.size = Vector2(1000.0, 130.0)
	end_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _make_label(parent: Control, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	parent.add_child(label)
	return label

func _announce(title: String, subtitle: String, color: Color) -> void:
	announcement.text = "%s\n%s" % [title, subtitle]
	announcement.add_theme_color_override("font_color", color)
	if announcement_tween != null and announcement_tween.is_valid():
		announcement_tween.kill()
	announcement.modulate.a = 0.0
	announcement_tween = create_tween()
	announcement_tween.tween_property(announcement, "modulate:a", 1.0, 0.22)
	announcement_tween.tween_interval(2.2)
	announcement_tween.tween_property(announcement, "modulate:a", 0.0, 0.48)

func _update_hud() -> void:
	if player != null and health_fill != null:
		var health_ratio := clampf(player.health / maxf(player.max_health, 1.0), 0.0, 1.0)
		health_fill.size.x = HEALTH_BAR_WIDTH * health_ratio
		health_label.text = "HOPLITE SOLITAIRE   %.0f / %.0f%s%s" % [player.health, player.max_health, "   BOUCLIER" if player.shield_blocking else "", "   • MODE TEST IMMORTEL" if TEST_IMMORTALITY else ""]
	if active_boss != null and is_instance_valid(active_boss) and not active_boss.dead:
		var boss_ratio := clampf(active_boss.health / maxf(active_boss.max_health, 1.0), 0.0, 1.0)
		boss_fill.size.x = BOSS_BAR_WIDTH * boss_ratio
		boss_label.text = "NFULLARMOR   PHASE %s   %.0f / %.0f" % [["I", "II", "III"][clampi(active_boss.combat_phase - 1, 0, 2)], active_boss.health, active_boss.max_health]

func _wire_enemy_feedback(enemy: HopliteAthenianEnemy) -> void:
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
	var defended := StringName(hit.contact_type) in [&"shield", &"parry", &"armor", &"guard_break"]
	var count := gore_hud.register_contact(zone, float(hit.damage), defended) if gore_hud != null else 1
	if combat_audio != null:
		combat_audio.play_hit_confirm(zone, count, defended)

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
	if combat_audio != null and player != null and enemy is Node3D:
		var distance := (enemy as Node3D).global_position.distance_to(player.global_position)
		if distance <= 11.0:
			combat_audio.play_enemy_swing(weapon_kind, distance)

func _on_enemy_localized_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float) -> void:
	if gore_hud != null:
		var combo := gore_hud.register_hit(enemy, zone, damage, sever_damage)
		if combat_audio != null:
			combat_audio.play_combo_tick(combo)

func _on_enemy_zone_severed(enemy: Node, zone: StringName) -> void:
	if combat_audio != null:
		combat_audio.play_sever(zone)
	if gore_hud != null:
		gore_hud.register_sever(enemy, zone)

func _on_enemy_died_feedback(enemy: Node) -> void:
	total_kills += 1
	var archetype := StringName(enemy.get("archetype_id")) if enemy != null else &"nsbire1"
	if combat_audio != null:
		combat_audio.play_kill(archetype)
	if gore_hud != null:
		gore_hud.register_kill(enemy)

func _is_settings_key(key: InputEventKey) -> bool:
	return key.unicode == 0x00B2 or key.keycode == KEY_QUOTELEFT or key.physical_keycode == KEY_QUOTELEFT
