extends "res://scripts/battle/battle_01.gd"

const QuestSystemScript = preload("res://scripts/quests/battle_quest_system.gd")
const CrowdDirectorScript = preload("res://scripts/ai/battle_crowd_director.gd")
const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")
const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const BrazierLightScript = preload("res://scripts/campaign/campaign_brazier_light.gd")

const ZONE_ONE_PLANNED_TOTAL := 88
const ZONE_TWO_PLANNED_TOTAL := 46
const ZONE_THREE_PRE_BOSS_TOTAL := 51

var quest_system: HopliteBattleQuestSystem
var narrative_layer: CanvasLayer
var narrative_panel: PanelContainer
var narrative_title: Label
var narrative_text: Label
var narrative_tween: Tween
var story_environment: Environment
var moon: DirectionalLight3D
var first_gate: AnimatableBody3D
var sanctuary_gate: AnimatableBody3D
var story_triggered: Dictionary = {}
var story_encounter_alive: Dictionary = {}
var story_role_alive: Dictionary = {}
var story_rng := RandomNumberGenerator.new()
var zone_one_main_force_spawned := false
var zone_one_spawner_finished := false
var zone_one_second_battalion_spawned := false
var zone_one_first_miniboss_spawned := false
var zone_one_second_miniboss_spawned := false
var zone_one_completed := false
var zone_two_completed := false
var zone_three_army_spawned := false
var zone_three_centurions_alive := 0
var final_boss_enemy: HopliteAthenianEnemy
var boss_brazier_lights: Array[HopliteCampaignBrazierLight] = []
var final_started := false
var story_kill_count := 0

func _ready() -> void:
	story_rng.randomize()
	super._ready()
	player.position = Vector3(0.0, 0.05, 94.0)
	player.rotation.y = 0.0
	call_deferred("_begin_story")

func _process(delta: float) -> void:
	super._process(delta)
	if debug_overlay_visible and debug_label != null:
		debug_label.text = "LA DERNIERE FLAMME\n%s" % player.debug_text

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "LastFlameWorldEnvironment"
	story_environment = Environment.new()
	story_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.018, 0.040, 0.105)
	sky_material.sky_horizon_color = Color(0.16, 0.24, 0.42)
	sky_material.ground_bottom_color = Color(0.005, 0.004, 0.008)
	sky_material.ground_horizon_color = Color(0.10, 0.09, 0.14)
	sky_material.sun_angle_max = 4.0
	sky_material.sun_curve = 0.04
	sky.sky_material = sky_material
	story_environment.sky = sky
	story_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	story_environment.ambient_light_color = Color(0.42, 0.52, 0.74)
	story_environment.ambient_light_energy = 1.15
	story_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	story_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	story_environment.glow_enabled = true
	story_environment.fog_enabled = true
	story_environment.fog_light_color = Color(0.18, 0.23, 0.34)
	story_environment.fog_light_energy = 0.82
	story_environment.fog_density = 0.0025
	world_environment.environment = story_environment
	add_child(world_environment)

	moon = DirectionalLight3D.new()
	moon.name = "ColdMoon"
	moon.rotation_degrees = Vector3(-52.0, 28.0, -8.0)
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 1.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 190.0
	add_child(moon)

func _build_ui() -> void:
	super._build_ui()
	quest_system = QuestSystemScript.new() as HopliteBattleQuestSystem
	quest_system.name = "LastFlameQuestSystem"
	add_child(quest_system)
	quest_system.register_quest(&"follow_flame", "SUIVRE LA FLAMME BLEUE", "Remontez la voie sacrée et retrouvez Théron.", 1, false, true)
	quest_system.register_quest(&"break_agora", "BRISER LES DEUX MURS DE BRONZE", "Abattez les vingt-quatre lanciers qui encadrent la fontaine.", 24, false)
	quest_system.register_quest(&"face_theron", "LE PARJURE", "Montez au sanctuaire et affrontez Théron.", 1, false)
	quest_system.set_phase("PROLOGUE — LA DERNIERE FLAMME")
	_build_narrative_overlay()

func _build_narrative_overlay() -> void:
	narrative_layer = CanvasLayer.new()
	narrative_layer.layer = 24
	narrative_layer.name = "NarrativeOverlay"
	narrative_layer.add_to_group("global_hud_narration")
	add_child(narrative_layer)
	narrative_panel = PanelContainer.new()
	narrative_panel.anchor_left = 0.5
	narrative_panel.anchor_right = 0.5
	narrative_panel.anchor_top = 1.0
	narrative_panel.anchor_bottom = 1.0
	narrative_panel.offset_left = -470.0
	narrative_panel.offset_right = 470.0
	narrative_panel.offset_top = -176.0
	narrative_panel.offset_bottom = -32.0
	narrative_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrative_panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.009, 0.018, 0.91)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.72, 0.45, 0.12, 0.84)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	narrative_panel.add_theme_stylebox_override("panel", style)
	narrative_layer.add_child(narrative_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	narrative_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	narrative_title = Label.new()
	narrative_title.add_theme_font_size_override("font_size", 19)
	narrative_title.add_theme_color_override("font_color", Color(1.0, 0.68, 0.28))
	stack.add_child(narrative_title)
	narrative_text = Label.new()
	narrative_text.add_theme_font_size_override("font_size", 21)
	narrative_text.add_theme_color_override("font_color", Color(0.90, 0.92, 0.98))
	narrative_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_text.max_lines_visible = 3
	stack.add_child(narrative_text)

func _build_battlefield() -> void:
	var crowd_director := CrowdDirectorScript.new() as HopliteBattleCrowdDirector
	crowd_director.name = "LastFlameCrowdDirector"
	add_child(crowd_director)

	# One continuous sacred road lets the silhouettes of each act remain visible
	# from the previous one: siege wreckage, the agora, then the temple on the hill.
	_add_textured_box("WorldGround", Vector3(92.0, 0.40, 226.0), Vector3(0.0, -0.20, -8.0), &"dirt_path", true)
	_add_textured_box("ScorchedApproach", Vector3(88.0, 0.045, 72.0), Vector3(0.0, 0.024, 67.0), &"scorched_ground", false)
	_add_textured_box("SacredRoad", Vector3(15.0, 0.055, 176.0), Vector3(0.0, 0.035, 9.0), &"sandstone_floor", false)
	_add_textured_box("AgoraFloor", Vector3(76.0, 0.065, 58.0), Vector3(0.0, 0.047, 3.0), &"white_marble_floor", false)
	_add_textured_box("SanctuaryNave", Vector3(40.0, 0.075, 82.0), Vector3(0.0, 0.055, -72.0), &"bone_gravel", false)
	_add_textured_box("WestBoundary", Vector3(3.0, 7.0, 226.0), Vector3(-46.0, 3.5, -8.0), &"rough_stone", true)
	_add_textured_box("EastBoundary", Vector3(3.0, 7.0, 226.0), Vector3(46.0, 3.5, -8.0), &"rough_stone", true)
	_add_textured_box("NorthBoundary", Vector3(92.0, 7.0, 3.0), Vector3(0.0, 3.5, -121.0), &"rough_stone", true)
	_add_textured_box("SouthBoundary", Vector3(92.0, 4.0, 3.0), Vector3(0.0, 2.0, 105.0), &"fortress", true)

	_build_siege_approach()
	_build_greek_agora()
	_build_sanctuary()

	first_gate = _add_story_gate("GateOfNames", 31.0, &"fortress")
	sanctuary_gate = _add_story_gate("GateOfAsh", -30.0, &"ornate_stone_wall")
	_create_story_trigger(&"first_omen", Vector3(0.0, 1.2, 76.0), Vector3(18.0, 3.0, 5.0))
	_create_story_trigger(&"siege_remnants", Vector3(0.0, 1.2, 60.0), Vector3(24.0, 3.0, 5.0))
	_create_story_trigger(&"agora", Vector3(0.0, 1.2, 24.0), Vector3(30.0, 3.0, 5.0))
	_create_story_trigger(&"descent", Vector3(0.0, 1.2, -37.0), Vector3(20.0, 3.0, 5.0))
	_create_story_trigger(&"final", Vector3(0.0, 1.2, -73.0), Vector3(20.0, 3.0, 5.0))

func _build_siege_approach() -> void:
	_add_story_prop(&"catapult", Vector3(-25.0, 0.0, 76.0), 18.0, false)
	_add_story_prop(&"catapult", Vector3(26.0, 0.0, 66.0), -24.0, false)
	_add_story_prop(&"big_rock", Vector3(-38.0, 0.0, 52.0), -18.0, false, 5.0)
	_add_story_prop(&"big_rock", Vector3(38.0, 0.0, 87.0), 28.0, true, 4.0)
	for index: int in range(5):
		_add_story_prop(&"barricade", Vector3(-16.0 + float(index) * 4.0, 0.0, 49.0), 0.0, true)
	for cluster: Vector3 in [Vector3(-29.0, 0.0, 60.0), Vector3(29.0, 0.0, 84.0)]:
		_add_story_prop(&"crates", cluster, 12.0, true)
		_add_story_prop(&"jar", cluster + Vector3(1.8, 0.0, 0.6), -18.0, true)
		_add_story_prop(&"jar", cluster + Vector3(-1.4, 0.0, 1.1), 28.0, true, 1.05)
	for side: float in [-1.0, 1.0]:
		_add_story_prop(&"tomb", Vector3(side * 18.0, 0.0, 38.0), -12.0 * side, true)
		_add_story_brazier(Vector3(side * 7.0, 0.0, 79.0), Color(0.18, 0.42, 1.0), 2.7)
		_add_story_brazier(Vector3(side * 7.0, 0.0, 54.0), Color(1.0, 0.25, 0.035), 2.3)

func _build_greek_agora() -> void:
	# Blue banners, bronze-lit Athenae and a white processional floor establish an
	# unmistakably Athenian civic space before the phalanx closes it.
	for side: float in [-1.0, 1.0]:
		for z: float in [24.0, 8.0, -10.0]:
			_add_textured_box("AgoraHouse_%s_%s" % [side, z], Vector3(18.0, 5.8, 12.0), Vector3(side * 32.5, 2.9, z), &"limestone_brick", true)
			_add_textured_box("AgoraCornice_%s_%s" % [side, z], Vector3(18.8, 0.35, 12.8), Vector3(side * 32.5, 5.9, z), &"marble", false)
		_add_story_prop(&"athena_statue", Vector3(side * 15.5, 0.0, -18.0), 18.0 * side, false)
		_add_story_prop(&"cypress_tree", Vector3(side * 20.0, 0.0, 20.0), 0.0, true)
		_add_story_prop(&"cypress_tree", Vector3(side * 20.0, 0.0, -4.0), 0.0, true)
		_add_story_brazier(Vector3(side * 8.0, 0.0, 25.0), Color(0.20, 0.48, 1.0), 3.0)
		_add_story_brazier(Vector3(side * 8.0, 0.0, -20.0), Color(1.0, 0.34, 0.05), 3.2)
	_add_story_prop(&"fountain", Vector3(0.0, 0.0, 6.0), 17.0, false)
	_add_story_prop(&"temple", Vector3(0.0, 0.0, -34.0), 180.0, false, 12.5, false)
	_add_wall_panel(Vector3(-45.35, 3.4, 6.0), Vector2(11.0, 5.0), 90.0, &"mural")
	_add_wall_panel(Vector3(45.35, 3.4, 6.0), Vector2(11.0, 5.0), -90.0, &"mural")
	_add_hero_spotlight(Vector3(-19.0, 8.5, -10.0), Vector3(-15.5, 2.5, -18.0), Color(0.36, 0.52, 1.0), 4.2, 24.0)
	_add_hero_spotlight(Vector3(19.0, 8.5, -10.0), Vector3(15.5, 2.5, -18.0), Color(1.0, 0.49, 0.15), 4.0, 24.0)

func _build_sanctuary() -> void:
	_add_textured_box("CryptWestWall", Vector3(3.0, 8.5, 86.0), Vector3(-22.0, 4.25, -75.0), &"ornate_stone_wall", true)
	_add_textured_box("CryptEastWall", Vector3(3.0, 8.5, 86.0), Vector3(22.0, 4.25, -75.0), &"ornate_stone_wall", true)
	_add_textured_box("TheronDais", Vector3(22.0, 1.0, 15.0), Vector3(0.0, 0.50, -105.0), &"white_marble_floor", true)
	for side: float in [-1.0, 1.0]:
		for row: int in range(5):
			_add_story_prop(&"tomb", Vector3(side * 16.5, 0.0, -46.0 - float(row) * 12.0), -90.0 * side, true)
		_add_story_prop(&"lion_statue", Vector3(side * 7.5, 1.0, -91.0), -18.0 * side, true)
		for z: float in [-43.0, -61.0, -80.0, -99.0]:
			_add_story_brazier(Vector3(side * 18.0, 0.0, z), Color(0.95, 0.08, 0.025), 3.1)
	_add_story_prop(&"magistrate_statue", Vector3(0.0, 1.0, -110.0), 0.0, false)
	_add_story_prop(&"temple", Vector3(0.0, 0.0, -118.0), 180.0, true, 11.2, false)
	# These four flames are deliberately dormant. Killing the three taxiarchs
	# ignites the central altar and reveals Théron in a single readable beat.
	for altar_position: Vector3 in [
		Vector3(-5.3, 1.0, -100.0), Vector3(5.3, 1.0, -100.0),
		Vector3(-5.3, 1.0, -109.0), Vector3(5.3, 1.0, -109.0)
	]:
		boss_brazier_lights.append(_add_story_brazier(altar_position, Color(1.0, 0.24, 0.025), 5.2, false))
	_add_wall_panel(Vector3(-21.45, 4.0, -65.0), Vector2(8.5, 5.2), 90.0, &"mural")
	_add_wall_panel(Vector3(21.45, 4.0, -65.0), Vector2(8.5, 5.2), -90.0, &"mural")
	_add_hero_spotlight(Vector3(0.0, 10.0, -93.0), Vector3(0.0, 1.4, -104.0), Color(1.0, 0.12, 0.035), 6.5, 31.0)

func _spawn_outer_battle() -> void:
	# Eight soldiers are already holding the scorched road when the mission loads.
	# They belong to the first twenty-man battalion, so this removes the empty
	# opening without increasing the encounter's planned total.
	story_encounter_alive[&"zone_one"] = 0
	var vanguard_positions: Array[Vector3] = [
		Vector3(-10.0, 0.05, 82.0), Vector3(-4.0, 0.05, 79.0),
		Vector3(4.0, 0.05, 79.0), Vector3(10.0, 0.05, 82.0),
		Vector3(-14.0, 0.05, 74.0), Vector3(-6.0, 0.05, 72.0),
		Vector3(6.0, 0.05, 72.0), Vector3(14.0, 0.05, 74.0)
	]
	for index: int in range(vanguard_positions.size()):
		_spawn_story_soldier(&"zone_one", &"zone1_infantry_a", &"nathenian1", vanguard_positions[index], StringName(), index)

func _spawn_spartan_allies() -> void:
	# This is a one-warrior legend. The numerical disadvantage is intentional.
	pass

func _build_return_to_training_portal() -> void:
	_add_scene_portal("LastFlameReturn", Vector3(0.0, 0.0, 100.0), "RETOUR AU STAND", TUTORIAL_SCENE, Color(0.18, 0.55, 0.95))

func _begin_story() -> void:
	_play_named_track("Ripped Crown Run")
	_show_narration(
		"LA DERNIERE FLAMME",
		"Une nuit après la chute des murs, le capitaine spartiate Théron a disparu. Une flamme bleue remonte seule vers l'Acropole.",
		7.0
	)
	quest_system.announce("SEUL CONTRE ATHENES", Color(0.40, 0.67, 1.0))

func _create_story_trigger(trigger_id: StringName, position_value: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "StoryTrigger_%s" % String(trigger_id)
	area.position = position_value
	area.collision_layer = 0
	area.collision_mask = 2
	add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_story_trigger_entered.bind(trigger_id, area))

func _on_story_trigger_entered(body: Node3D, trigger_id: StringName, area: Area3D) -> void:
	if body != player or story_triggered.has(trigger_id):
		return
	story_triggered[trigger_id] = true
	area.set_deferred("monitoring", false)
	match trigger_id:
		&"first_omen":
			_show_narration("DORIEUS — ECLAIREUR", "Des catapultes tournées vers Athènes... et des tombeaux grecs. Quelqu'un a préparé cette route pour nous.", 5.6)
		&"siege_remnants":
			quest_system.set_phase("ACTE I — LA VOIE DES CENDRES")
			_spawn_story_encounter(&"zone_one")
			_show_narration("VOIX ATHENIENNE", "Le Spartiate est venu seul. Tous les quartiers à la voie sacrée ! Écrasez-le sous le nombre !", 4.8)
		&"agora":
			quest_system.complete(&"follow_flame")
			quest_system.activate(&"break_agora")
			quest_system.set_phase("ACTE II — LE MUR DE BRONZE")
			_play_named_track("Carnage Arena")
			_shift_atmosphere(2)
			_spawn_story_encounter(&"zone_two")
			_show_narration("LE CORYPHEE", "ATHENES ! Deux murs autour de la source. Archers, couvrez les lances. Que l'étranger se noie dans le bronze !", 5.8)
		&"descent":
			quest_system.set_phase("ACTE III — LA DERNIERE ARMEE")
			_spawn_story_encounter(&"zone_three")
			_show_narration("THERON", "Tu cherches un traître ? Traverse d'abord tout ce qu'Athènes possède encore.", 5.8)
			_shift_atmosphere(3)
		&"final":
			_show_narration("LES TAXIARQUES", "Trois commandants. Une dernière phalange. Théron ne paraîtra qu'après notre mort.", 5.5)

func _spawn_story_encounter(encounter_id: StringName) -> void:
	if final_started and encounter_id == &"final_boss":
		return
	# Zone one already contains its visible vanguard at load time. Its trigger is
	# still allowed to deploy the rest of the battalion and timed reinforcements.
	if encounter_id == &"zone_one":
		if zone_one_main_force_spawned:
			return
	elif story_encounter_alive.has(encounter_id):
		return
	match encounter_id:
		&"zone_one": _spawn_zone_one()
		&"zone_two": _spawn_zone_two()
		&"zone_three": _spawn_zone_three()
		&"final_boss": _spawn_final_boss()

func _spawn_zone_one() -> void:
	if zone_one_main_force_spawned:
		return
	zone_one_main_force_spawned = true
	if not story_encounter_alive.has(&"zone_one"):
		story_encounter_alive[&"zone_one"] = 0
	# The first eight infantry are the vanguard spawned with the battlefield.
	_spawn_rect_group(&"zone_one", &"zone1_infantry_a", &"nathenian1", 12, Vector3(-24.0, 0.05, 43.0), Vector3(24.0, 0.05, 56.0), 4)
	_spawn_rect_group(&"zone_one", &"zone1_archers", &"nsbire2", 10, Vector3(-33.0, 0.05, 35.0), Vector3(33.0, 0.05, 43.0), 5)
	for position_value: Vector3 in [Vector3(-22.0, 0.05, 61.0), Vector3(18.0, 0.05, 68.0), Vector3(27.0, 0.05, 49.0)]:
		_spawn_story_soldier(&"zone_one", &"zone1_heavy_soldiers", &"nathenian2_soldier", position_value)
	call_deferred("_run_zone_one_random_pressure")
	quest_system.announce("20 FANTASSINS • 10 ARCHERS • RENFORTS DANS TOUTES LES RUES", Color(1.0, 0.36, 0.08))

func _run_zone_one_random_pressure() -> void:
	for second: int in range(15):
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
		for spawn_index: int in range(2):
			var side := -1.0 if (second + spawn_index) % 2 == 0 else 1.0
			var spawn_position := Vector3(side * story_rng.randf_range(11.0, 39.0), 0.05, story_rng.randf_range(39.0, 82.0))
			_spawn_story_soldier(&"zone_one", &"zone1_random_levies", &"nsbire1", spawn_position)
		if second in [4, 9, 13]:
			var heavy_position := Vector3(story_rng.randf_range(-31.0, 31.0), 0.05, story_rng.randf_range(42.0, 76.0))
			_spawn_story_soldier(&"zone_one", &"zone1_heavy_soldiers", &"nathenian2_soldier", heavy_position)
	zone_one_spawner_finished = true
	_spawn_zone_one_first_miniboss()

func _spawn_zone_one_first_miniboss() -> void:
	if zone_one_first_miniboss_spawned or zone_one_completed:
		return
	zone_one_first_miniboss_spawned = true
	_spawn_story_soldier(&"zone_one", &"zone1_miniboss_a", &"bronze_colossus", Vector3(0.0, 0.05, 39.0))
	_show_narration("LE COLOSSE DE BRONZE", "Quinze secondes de massacre. Athènes envoie enfin quelqu'un digne de toi.", 4.4)

func _spawn_zone_one_second_battalion() -> void:
	if zone_one_second_battalion_spawned:
		return
	zone_one_second_battalion_spawned = true
	_spawn_rect_group(&"zone_one", &"zone1_infantry_b", &"nathenian1", 20, Vector3(-29.0, 0.05, 34.0), Vector3(29.0, 0.05, 48.0), 5)
	quest_system.announce("DEUXIEME BATAILLON — VINGT BOUCLIERS FRAIS", Color(1.0, 0.30, 0.07))

func _spawn_zone_one_second_miniboss() -> void:
	await get_tree().create_timer(2.6).timeout
	if not is_inside_tree() or zone_one_second_miniboss_spawned or zone_one_completed:
		return
	zone_one_second_miniboss_spawned = true
	_spawn_story_soldier(&"zone_one", &"zone1_miniboss_b", &"ncenturion", Vector3(0.0, 0.05, 42.0))
	_show_narration("LE TAXIARQUE", "Le colosse est tombé ? Alors je prendrai sa place. Reformez la ligne !", 4.4)

func _spawn_zone_two() -> void:
	story_encounter_alive[&"zone_two"] = 0
	_spawn_phalanx_cohort(&"zone_two", &"zone2_phalanx_left", Vector3(-13.0, 0.05, 7.0), 3, 4)
	_spawn_phalanx_cohort(&"zone_two", &"zone2_phalanx_right", Vector3(13.0, 0.05, 7.0), 3, 4)
	_spawn_zone_two_support(-1.0)
	_spawn_zone_two_support(1.0)
	_spawn_rect_group(&"zone_two", &"zone2_front_infantry", &"nathenian1", 6, Vector3(-11.0, 0.05, 19.0), Vector3(11.0, 0.05, 24.0), 3)
	_spawn_rect_group(&"zone_two", &"zone2_front_levies", &"nsbire1", 6, Vector3(-16.0, 0.05, 26.0), Vector3(16.0, 0.05, 31.0), 3)
	quest_system.announce("DEUX PHALANGES — ARCHERS ET TAXIARQUES SUR LES FLANCS", Color(1.0, 0.63, 0.18))

func _spawn_zone_two_support(side: float) -> void:
	var prefix := "zone2_left" if side < 0.0 else "zone2_right"
	_spawn_story_soldier(&"zone_two", StringName(prefix + "_centurion"), &"ncenturion", Vector3(side * 22.0, 0.05, 2.0))
	_spawn_story_soldier(&"zone_two", StringName(prefix + "_heavy"), &"nathenian2_soldier", Vector3(side * 19.0, 0.05, 10.0))
	for index: int in range(3):
		_spawn_story_soldier(&"zone_two", StringName(prefix + "_archers"), &"nsbire2", Vector3(side * (11.0 + float(index) * 4.6), 0.05, -4.0 - float(index % 2) * 2.2))

func _spawn_zone_three() -> void:
	story_encounter_alive[&"zone_three"] = 0
	call_deferred("_run_zone_three_pressure")

func _run_zone_three_pressure() -> void:
	# Only a brief levy screen remains here. The former infantry stream made the
	# reveal of the final phalanx noisy and needlessly expensive.
	for second: int in range(4):
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
		for spawn_index: int in range(2):
			var x := story_rng.randf_range(-17.5, 17.5)
			var z := story_rng.randf_range(-69.0, -49.0)
			_spawn_story_soldier(&"zone_three", &"zone3_pressure", &"nsbire1", Vector3(x, 0.05, z))
	if not zone_three_army_spawned:
		_spawn_zone_three_army()

func _spawn_zone_three_army() -> void:
	if zone_three_army_spawned:
		return
	zone_three_army_spawned = true
	_spawn_phalanx_cohort(&"zone_three", &"zone3_great_phalanx", Vector3(0.0, 0.05, -74.0), 4, 7)
	_spawn_rect_group(&"zone_three", &"zone3_archers", &"nsbire2", 8, Vector3(-16.0, 0.05, -86.0), Vector3(16.0, 0.05, -90.0), 4)
	for index: int in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		_spawn_story_soldier(&"zone_three", &"zone3_heavy_guard", &"nathenian2_soldier", Vector3(side * (11.0 + float(index / 2) * 2.7), 0.05, -80.0 - float(index % 3) * 3.0))
	zone_three_centurions_alive = 3
	for index: int in range(3):
		_spawn_story_soldier(&"zone_three", &"zone3_centurions", &"ncenturion", Vector3((float(index) - 1.0) * 7.5, 0.05, -96.0))
	_show_narration("LE DERNIER SERMENT D'ATHENES", "Vingt-huit lances. Huit archers. Quatre briseurs. Trois taxiarchs gardent la flamme de Théron.", 6.5)

func _spawn_final_boss() -> void:
	if final_started:
		return
	final_started = true
	quest_system.activate(&"face_theron")
	quest_system.set_phase("ACTE IV — THERON, LE PARJURE")
	for light: HopliteCampaignBrazierLight in boss_brazier_lights:
		if light == null:
			continue
		light.configure_atmosphere(1.0, 0.20)
		for child: Node in light.get_children():
			if child is MeshInstance3D:
				child.visible = true
	final_boss_enemy = _spawn_story_soldier(&"final_boss", &"final_boss", &"nfull_armor", Vector3(0.0, 1.05, -104.0))
	_add_boss_title()
	_show_narration("THERON", "Tu as traversé une armée entière. Maintenant viens prendre la vérité à un seul homme.", 6.2)

func _spawn_phalanx_cohort(encounter_id: StringName, role_tag: StringName, center: Vector3, rows: int, columns: int) -> void:
	var total := rows * columns
	for index: int in range(total):
		var row := index / columns
		var column := index % columns
		var veteran := row < 2 and (column == 0 or column == columns - 1)
		var archetype := &"ngeneral_veteran" if veteran else &"ngeneral"
		var position_value := center + Vector3((float(column) - float(columns - 1) * 0.5) * 1.28, 0.0, -float(row) * 1.32)
		var enemy := _spawn_story_soldier(encounter_id, role_tag, archetype, position_value, StringName("story_%s" % String(role_tag)), index)
		enemy.formation_columns = columns

func _spawn_rect_group(encounter_id: StringName, role_tag: StringName, archetype: StringName, count: int, corner_a: Vector3, corner_b: Vector3, columns: int) -> void:
	for index: int in range(count):
		var column := index % columns
		var row := index / columns
		var row_count := maxi(1, ceili(float(count) / float(columns)))
		var tx := float(column) / float(maxi(columns - 1, 1))
		var tz := float(row) / float(maxi(row_count - 1, 1))
		var position_value := Vector3(lerpf(corner_a.x, corner_b.x, tx), lerpf(corner_a.y, corner_b.y, tz), lerpf(corner_a.z, corner_b.z, tz))
		_spawn_story_soldier(encounter_id, role_tag, archetype, position_value, StringName(), index)

func _spawn_story_soldier(encounter_id: StringName, role_tag: StringName, archetype: StringName, position_value: Vector3, formation_group: StringName = StringName(), guard_index: int = 0) -> HopliteAthenianEnemy:
	var is_command_unit := archetype in [&"bronze_colossus", &"ncenturion", &"nfull_armor"]
	var enemy := _spawn_enemy(position_value, archetype, null, guard_index, false, not is_command_unit)
	if formation_group != StringName() and enemy.is_phalanx_unit():
		enemy.set_meta("formation_group", formation_group)
	story_encounter_alive[encounter_id] = int(story_encounter_alive.get(encounter_id, 0)) + 1
	story_role_alive[role_tag] = int(story_role_alive.get(role_tag, 0)) + 1
	enemy.died.connect(_on_story_enemy_died.bind(encounter_id, role_tag))
	return enemy

func _on_story_enemy_died(_enemy: Node, encounter_id: StringName, role_tag: StringName) -> void:
	story_encounter_alive[encounter_id] = maxi(0, int(story_encounter_alive.get(encounter_id, 0)) - 1)
	story_role_alive[role_tag] = maxi(0, int(story_role_alive.get(role_tag, 0)) - 1)
	if role_tag in [&"zone2_phalanx_left", &"zone2_phalanx_right"] and quest_system != null:
		quest_system.increment(&"break_agora")
		_try_open_sanctuary_after_phalanxes()
	if role_tag == &"zone1_infantry_a" and zone_one_main_force_spawned and int(story_role_alive[role_tag]) == 0:
		_spawn_zone_one_second_battalion()
	elif role_tag == &"zone1_miniboss_a" and int(story_role_alive[role_tag]) == 0:
		call_deferred("_spawn_zone_one_second_miniboss")
	elif role_tag == &"zone1_miniboss_b" and int(story_role_alive[role_tag]) == 0:
		_complete_zone_one_after_bosses()
	elif role_tag == &"zone3_centurions":
		zone_three_centurions_alive = maxi(0, zone_three_centurions_alive - 1)
		quest_system.announce("TAXIARQUES RESTANTS : %d" % zone_three_centurions_alive, Color(1.0, 0.38, 0.08))
		if zone_three_centurions_alive == 0:
			call_deferred("_spawn_story_encounter", &"final_boss")
	elif role_tag == &"final_boss":
		_complete_story()
	_check_story_encounter_completion(encounter_id)

func _complete_zone_one_after_bosses() -> void:
	if zone_one_completed:
		return
	zone_one_completed = true
	_open_gate(first_gate, 6.5)
	player.health = minf(player.max_health, player.health + 65.0)
	quest_system.announce("LES DEUX CHAMPIONS SONT MORTS — LA VOIE S'OUVRE", Color(1.0, 0.52, 0.20))
	_show_narration("DORIEUS", "Leurs champions sont tombés. Laisse les survivants derrière toi : Théron est au-delà de cette porte.", 5.2)

func _try_open_sanctuary_after_phalanxes() -> void:
	if zone_two_completed:
		return
	var left_alive := int(story_role_alive.get(&"zone2_phalanx_left", 0))
	var right_alive := int(story_role_alive.get(&"zone2_phalanx_right", 0))
	if left_alive > 0 or right_alive > 0:
		return
	zone_two_completed = true
	_open_gate(sanctuary_gate, 7.0)
	quest_system.activate(&"face_theron")
	player.health = minf(player.max_health, player.health + 85.0)
	quest_system.announce("LES DEUX PHALANGES SONT BRISEES — LA PORTE S'OUVRE", Color(1.0, 0.72, 0.24))
	_show_narration("DORIEUS", "Les deux murs sont à terre. Ignore leurs soutiens dispersés : la route du sanctuaire est ouverte.", 5.0)

func _check_story_encounter_completion(encounter_id: StringName) -> void:
	if int(story_encounter_alive.get(encounter_id, 0)) > 0:
		return
	match encounter_id:
		&"zone_one":
			# Zone one is objective-driven: surviving fodder does not keep the gate shut
			# after both champions have died.
			return
		&"zone_two":
			# Safety fallback for unusual cleanup orders. Normal progression opens the
			# gate as soon as the two local phalanxes are dead, with supports remaining.
			_try_open_sanctuary_after_phalanxes()

func _on_enemy_died_feedback(enemy: Node) -> void:
	super._on_enemy_died_feedback(enemy)
	story_kill_count += 1
	# Small, readable momentum rewards make the player feel like the terrifying
	# exception inside an otherwise disciplined Athenian army, without erasing risk.
	if player != null:
		player.health = minf(player.max_health, player.health + 3.0)
	if quest_system == null:
		return
	match story_kill_count:
		5:
			quest_system.announce("CINQ GRECS A TERRE — ILS RECULENT DEVANT UN SEUL HOMME", Color(1.0, 0.58, 0.16))
		10:
			quest_system.announce("DIX — LE MUR D'ATHENES TREMBLE", Color(1.0, 0.36, 0.08))
		20:
			quest_system.announce("VINGT — TON NOM COUVRE LEURS CRIS", Color(1.0, 0.18, 0.055))

func _complete_story() -> void:
	battle_complete = true
	quest_system.complete(&"face_theron")
	quest_system.set_phase("EPILOGUE — LE PRIX DE LA VICTOIRE")
	_show_narration("INSCRIPTION SUR LA TABLETTE", "« Les portes étaient ouvertes avant l'assaut. » Théron n'avait pas fui la bataille : il en gardait la preuve.", 8.0)
	_add_scene_portal("LastFlameVictory", Vector3(0.0, 1.0, -109.0), "LA LEGENDE CONTINUE", TUTORIAL_SCENE, Color(1.0, 0.58, 0.12))

func _show_narration(title: String, text_value: String, duration: float) -> void:
	if narrative_panel == null:
		return
	if narrative_tween != null and narrative_tween.is_valid():
		narrative_tween.kill()
	narrative_title.text = title
	narrative_text.text = text_value
	narrative_panel.modulate.a = 0.0
	narrative_tween = create_tween()
	narrative_tween.tween_property(narrative_panel, "modulate:a", 1.0, 0.28)
	narrative_tween.tween_interval(duration)
	narrative_tween.tween_property(narrative_panel, "modulate:a", 0.0, 0.55)

func _shift_atmosphere(act: int) -> void:
	if moon == null or story_environment == null:
		return
	var tween := create_tween().set_parallel(true)
	if act == 2:
		tween.tween_property(moon, "light_color", Color(0.70, 0.78, 1.0), 1.8)
		tween.tween_property(moon, "light_energy", 2.00, 1.8)
		tween.tween_property(story_environment, "ambient_light_energy", 1.18, 1.8)
	else:
		tween.tween_property(moon, "light_color", Color(0.92, 0.58, 0.48), 2.0)
		tween.tween_property(moon, "light_energy", 1.65, 2.0)
		tween.tween_property(story_environment, "ambient_light_energy", 1.00, 2.0)
		tween.tween_property(story_environment, "fog_density", 0.0030, 2.0)

func _play_named_track(fragment: String) -> void:
	if combat_audio == null:
		return
	var names := combat_audio.get_track_names()
	for index: int in range(names.size()):
		if fragment.to_lower() in names[index].to_lower():
			combat_audio.play_track(index)
			return

func _add_boss_title() -> void:
	var label := Label3D.new()
	label.text = "THERON, LE PARJURE\nDERNIER CAPITAINE DE SPARTE"
	label.position = Vector3(0.0, 5.8, -104.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.outline_size = 9
	label.modulate = Color(1.0, 0.32, 0.12)
	add_child(label)

func _add_story_gate(node_name: String, z_value: float, wall_style: StringName) -> AnimatableBody3D:
	_add_textured_box(node_name + "_L", Vector3(39.0, 6.5, 2.0), Vector3(-26.5, 3.25, z_value), wall_style, true)
	_add_textured_box(node_name + "_R", Vector3(39.0, 6.5, 2.0), Vector3(26.5, 3.25, z_value), wall_style, true)
	return _create_lift_gate(node_name + "_Gate", Vector3(0.0, 3.0, z_value), Vector3(13.5, 6.0, 0.75), Color(0.16, 0.07, 0.025))

func _add_textured_box(node_name: String, size: Vector3, position_value: Vector3, style: StringName, collision_enabled: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1 if collision_enabled else 0
	body.collision_mask = 1
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = MaterialLibraryScript.material(style)
	body.add_child(mesh_instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return body

func _add_story_prop(asset_id: StringName, position_value: Vector3, rotation_y_degrees: float, repeated: bool = false, height_override: float = 0.0, collision_enabled: bool = true) -> Node3D:
	var definition: Dictionary = AssetCatalogScript.definition(asset_id)
	var path := AssetCatalogScript.visual_path(asset_id, repeated)
	if path.is_empty():
		push_warning("[LAST FLAME] Missing story prop %s" % String(asset_id))
		return null
	var packed := RuntimeGLTFCacheScript.scene(path)
	if packed == null:
		return null
	var holder := Node3D.new()
	holder.name = "StoryProp_%s_%d" % [String(asset_id), get_child_count()]
	holder.position = position_value
	holder.rotation_degrees.y = rotation_y_degrees
	add_child(holder)
	var content := packed.instantiate() as Node3D
	if content == null:
		holder.queue_free()
		return null
	holder.add_child(content)
	_disable_prop_activity(content)
	var bounds := _story_node_bounds(holder, content)
	var target_height := height_override if height_override > 0.0 else AssetCatalogScript.target_height(asset_id)
	if bounds.size.length_squared() > 0.001:
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		content.scale = Vector3.ONE * scale_value
		content.position = Vector3(
			-(bounds.position.x + bounds.size.x * 0.5) * scale_value,
			-bounds.position.y * scale_value,
			-(bounds.position.z + bounds.size.z * 0.5) * scale_value
		)
	if collision_enabled:
		_add_story_prop_collision(holder, definition)
	return holder

func _add_story_prop_collision(holder: Node3D, definition: Dictionary) -> void:
	var kind := StringName(definition.get("collision", &"none"))
	if kind == &"none":
		return
	var body := StaticBody3D.new()
	body.name = "GameplayCollision"
	body.collision_layer = 1
	holder.add_child(body)
	var collision := CollisionShape3D.new()
	if kind == &"cylinder":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(definition.get("collision_radius", 0.5))
		cylinder.height = float(definition.get("collision_height", 1.0))
		collision.shape = cylinder
		collision.position.y = cylinder.height * 0.5
	else:
		var box := BoxShape3D.new()
		box.size = definition.get("collision_size", Vector3.ONE)
		collision.shape = box
		collision.position.y = box.size.y * 0.5
	body.add_child(collision)

func _add_story_brazier(position_value: Vector3, color: Color, energy: float, initially_lit: bool = true) -> HopliteCampaignBrazierLight:
	_add_story_prop(&"brazier", position_value, 0.0, true)
	var light := BrazierLightScript.new() as HopliteCampaignBrazierLight
	light.position = position_value + Vector3.UP * 2.18
	light.light_color = color
	light.light_energy = energy
	light.base_energy = energy
	light.intensity_multiplier = 1.0 if initially_lit else 0.0
	light.omni_range = 11.0
	light.shadow_enabled = false
	add_child(light)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.17
	flame_mesh.height = 0.42
	flame.mesh = flame_mesh
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.emission_enabled = true
	flame_material.emission = color * 4.2
	flame_material.albedo_color = color
	flame.material_override = flame_material
	flame.visible = initially_lit
	light.add_child(flame)
	return light

func _add_wall_panel(position_value: Vector3, size: Vector2, rotation_y_degrees: float, style: StringName) -> void:
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.10)
	panel.mesh = mesh
	panel.material_override = MaterialLibraryScript.uv_material(style)
	panel.position = position_value
	panel.rotation_degrees.y = rotation_y_degrees
	add_child(panel)

func _add_hero_spotlight(position_value: Vector3, target: Vector3, color: Color, energy: float, light_range: float) -> void:
	var spotlight := SpotLight3D.new()
	spotlight.position = position_value
	spotlight.light_color = color
	spotlight.light_energy = energy
	spotlight.spot_range = light_range
	spotlight.spot_angle = 32.0
	spotlight.shadow_enabled = true
	add_child(spotlight)
	spotlight.look_at(target, Vector3.UP)

func _disable_prop_activity(root_node: Node) -> void:
	root_node.process_mode = Node.PROCESS_MODE_DISABLED
	for candidate: Node in root_node.find_children("*", "AnimationPlayer", true, false):
		(candidate as AnimationPlayer).stop()
	for candidate: Node in root_node.find_children("*", "CollisionObject3D", true, false):
		(candidate as CollisionObject3D).collision_layer = 0
		(candidate as CollisionObject3D).collision_mask = 0

func _story_node_bounds(root_node: Node3D, content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		var mesh_to_root := _transform_to_story_ancestor(mesh_instance, root_node)
		for corner: int in range(8):
			var point := mesh_to_root * mesh_bounds.get_endpoint(corner)
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds

func _transform_to_story_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
