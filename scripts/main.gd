extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CombatAudioScript = preload("res://scripts/audio/combat_audio.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")
const GoreHUDScript = preload("res://scripts/ui/gore_hud.gd")
const AtmospherePanelScript = preload("res://scripts/campaign/atmosphere_control_panel.gd")
const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const CrowdDirectorScript = preload("res://scripts/ai/battle_crowd_director.gd")
const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const AssetLibraryRoomScript = preload("res://scripts/environment/asset_library_room.gd")
const WorldPortalHubScript = preload("res://scripts/world_editor/world_portal_hub.gd")
const BATTLE_02_SCENE: String = "res://battle_02.tscn"
const PROCEDURAL_CAMPAIGN_SCENE: String = "res://procedural_campaign.tscn"
const NARRATIVE_BATTLE_SCENE: String = "res://battle_03_narrative.tscn"
const TEMPLE_VISUAL: String = "res://assets/environment/temple1/temple1.glb"
const TEMPLE_COLLISION: String = "res://assets/environment/temple1/temple1_collision.glb"
const ATHENA_STATUE_VISUAL: String = "res://assets/environment/status_athena/status_athena.glb"
const ATHENA_STATUE_COLLISION: String = "res://assets/environment/status_athena/status_athena_collision.glb"
const RAW_ENVIRONMENT_ROOT: String = "res://_source/environment_props_raw"

var player: HopliteUALNativePlayer
var combat_audio: HopliteCombatAudio
var audio_settings: HopliteAudioSettings
var gore_hud: HopliteGoreHUD
var atmosphere_panel: HopliteAtmosphereControlPanel
var training_world_environment: WorldEnvironment
var training_sun: DirectionalLight3D
var debug_label: Label
var debug_panel: ColorRect
var debug_title: Label
var debug_help: Label
var debug_overlay_visible: bool = false
var debug_world_labels: Array[Label3D] = []

var health_bar_fill: ColorRect
var health_bar_label: Label
const HEALTH_BAR_WIDTH: float = 286.0

func _ready() -> void:
	_build_environment()
	_build_ui()
	_build_atmosphere_controls()
	combat_audio = CombatAudioScript.new() as HopliteCombatAudio
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)
	gore_hud = GoreHUDScript.new() as HopliteGoreHUD
	gore_hud.name = "GoreHUD"
	add_child(gore_hud)
	player = PlayerScript.new() as HopliteUALNativePlayer
	player.name = "SpartanUALNativeTest"
	player.position = Vector3(0.0, 0.05, 12.0)
	add_child(player)
	audio_settings = AudioSettingsScript.new() as HopliteAudioSettings
	audio_settings.name = "Settings"
	audio_settings.combat_audio = combat_audio
	audio_settings.player = player
	audio_settings.gore_hud = gore_hud
	add_child(audio_settings)
	_wire_player_audio()
	var crowd_director_runtime = CrowdDirectorScript.new()
	crowd_director_runtime.name = "TrainingCrowdDirector"
	add_child(crowd_director_runtime)
	_build_training_ground()
	var world_portals := WorldPortalHubScript.new() as HopliteWorldPortalHub
	add_child(world_portals)

func _wire_player_audio() -> void:
	if player == null or combat_audio == null:
		return
	if not player.movement_sfx_requested.is_connected(combat_audio.play_movement_sfx):
		player.movement_sfx_requested.connect(combat_audio.play_movement_sfx)
	if not player.damage_received.is_connected(_on_player_damage_audio):
		player.damage_received.connect(_on_player_damage_audio)
	if not player.combat_hit.is_connected(_on_player_combat_hit):
		player.combat_hit.connect(_on_player_combat_hit)
	if not player.perfect_response_started.is_connected(_on_player_perfect_response):
		player.perfect_response_started.connect(_on_player_perfect_response)
	if not player.perfect_response_consumed.is_connected(_on_player_perfect_response_consumed):
		player.perfect_response_consumed.connect(_on_player_perfect_response_consumed)
	var feedback: HopliteCombatFeedback = player.get_combat_feedback()
	if feedback != null and not feedback.audio_cue_requested.is_connected(combat_audio.play_feedback_cue):
		feedback.audio_cue_requested.connect(combat_audio.play_feedback_cue)
	if feedback != null and not feedback.cinematic_started.is_connected(_on_combat_cinematic_started):
		feedback.cinematic_started.connect(_on_combat_cinematic_started)

func _on_player_damage_audio(damage: float, _attacker: Node) -> void:
	if combat_audio != null:
		combat_audio.play_player_hurt(damage)
	if gore_hud != null:
		gore_hud.register_player_hurt(damage)

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

func _wire_enemy_feedback(enemy: Node3D) -> void:
	var typed_enemy := enemy as HopliteAthenianEnemy
	if typed_enemy == null:
		return
	if not typed_enemy.localized_hit.is_connected(_on_enemy_localized_hit):
		typed_enemy.localized_hit.connect(_on_enemy_localized_hit)
	if not typed_enemy.attack_started.is_connected(_on_enemy_attack_started):
		typed_enemy.attack_started.connect(_on_enemy_attack_started)
	if not typed_enemy.zone_severed.is_connected(_on_enemy_zone_severed):
		typed_enemy.zone_severed.connect(_on_enemy_zone_severed)
	if not typed_enemy.died.is_connected(_on_enemy_died_feedback):
		typed_enemy.died.connect(_on_enemy_died_feedback)

func _on_enemy_localized_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float) -> void:
	if gore_hud == null:
		return
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
	var archetype_value: Variant = enemy.get("archetype_id") if enemy != null else null
	if archetype_value != null:
		archetype_id = StringName(archetype_value)
	if combat_audio != null:
		combat_audio.play_kill(archetype_id)
	if gore_hud != null:
		gore_hud.register_kill(enemy)

func _on_enemy_attack_started(enemy: Node, weapon_kind: StringName) -> void:
	if combat_audio == null or player == null or not (enemy is Node3D):
		return
	var distance_to_player: float = (enemy as Node3D).global_position.distance_to(player.global_position)
	if distance_to_player <= 10.5:
		combat_audio.play_enemy_swing(weapon_kind, distance_to_player)

func _process(_delta: float) -> void:
	if player == null:
		return
	_update_player_health_bar()
	if debug_overlay_visible and debug_label != null:
		debug_label.text = player.debug_text

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
	if debug_panel != null:
		debug_panel.visible = enabled
	if debug_title != null:
		debug_title.visible = enabled
	if debug_help != null:
		debug_help.visible = enabled
	if debug_label != null:
		debug_label.visible = enabled
	for label: Label3D in debug_world_labels:
		if is_instance_valid(label):
			label.visible = enabled
	if player != null:
		player.set_combat_debug_visible(enabled)

func _update_player_health_bar() -> void:
	if player == null or health_bar_fill == null or health_bar_label == null:
		return
	var maximum: float = maxf(player.max_health, 1.0)
	var ratio: float = clampf(player.health / maximum, 0.0, 1.0)
	health_bar_fill.size.x = HEALTH_BAR_WIDTH * ratio
	var defense_text: String = "   BOUCLIER" if player.shield_blocking else ""
	health_bar_label.text = "SPARTAN   %.0f / %.0f%s" % [player.health, player.max_health, defense_text]

func _build_environment() -> void:
	training_world_environment = WorldEnvironment.new()
	training_world_environment.name = "TrainingWorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.31, 0.62)
	sky_mat.sky_horizon_color = Color(0.82, 0.67, 0.43)
	sky_mat.ground_bottom_color = Color(0.07, 0.045, 0.032)
	sky_mat.ground_horizon_color = Color(0.38, 0.24, 0.14)
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	training_world_environment.environment = environment
	add_child(training_world_environment)

	training_sun = DirectionalLight3D.new()
	training_sun.name = "TrainingSun"
	training_sun.rotation_degrees = Vector3(-50, -32, 0)
	training_sun.light_color = Color(1.0, 0.83, 0.66)
	training_sun.light_energy = 1.20
	training_sun.shadow_enabled = true
	training_sun.directional_shadow_max_distance = 240.0
	add_child(training_sun)

func _build_atmosphere_controls() -> void:
	atmosphere_panel = AtmospherePanelScript.new() as HopliteAtmosphereControlPanel
	atmosphere_panel.name = "AtmosphereControlPanel"
	add_child(atmosphere_panel)
	atmosphere_panel.configure(training_world_environment, training_sun)

func _build_training_ground() -> void:
	# One large PBR/triplanar ground replaces the former flat brown slab.
	_add_textured_box("PaverGround", Vector3(230.0, 0.35, 140.0), Vector3(50.0, -0.18, 0.0), &"pavers", true)
	_add_textured_box("RangeCourtyard", Vector3(58.0, 0.10, 42.0), Vector3(19.0, 0.02, 15.0), &"sandstone_floor", false)

	_add_environment_prop("TrainingTemple", TEMPLE_VISUAL, TEMPLE_COLLISION, Vector3(38.0, 0.0, -34.0), 28.0, Vector3(0.0, -90.0, 0.0), 0.0, 0.5)
	_add_environment_prop("AthenaStatue", ATHENA_STATUE_VISUAL, ATHENA_STATUE_COLLISION, Vector3(-38.0, 0.0, -34.0), 10.0, Vector3(0.0, 28.0, 0.0), 0.5, 0.5)

	# Fortification shell: simple meshes, world-space triplanar stone and a gate.
	# The west wall leaves a six-metre doorway into the automatic asset library.
	_add_textured_box("RangeWallWestSouth", Vector3(1.2, 3.6, 15.0), Vector3(-10.0, 1.8, 1.5), &"fortress", true)
	_add_textured_box("RangeWallWestNorth", Vector3(1.2, 3.6, 21.0), Vector3(-10.0, 1.8, 25.5), &"fortress", true)
	# The former solid east wall is split around a broad doorway into the new
	# legion-testing annex.
	_add_textured_box("RangeWallEastSouth", Vector3(1.2, 3.6, 18.0), Vector3(48.0, 1.8, 3.0), &"fortress", true)
	_add_textured_box("RangeWallEastNorth", Vector3(1.2, 3.6, 16.0), Vector3(48.0, 1.8, 28.0), &"fortress", true)
	_add_textured_box("LegionGateLintel", Vector3(1.4, 0.9, 9.0), Vector3(48.0, 3.25, 16.0), &"marble", true)
	_add_textured_box("RangeWallNorthLeft", Vector3(25.0, 3.6, 1.2), Vector3(2.5, 1.8, 35.4), &"fortress", true)
	_add_textured_box("RangeWallNorthRight", Vector3(27.0, 3.6, 1.2), Vector3(34.5, 1.8, 35.4), &"fortress", true)
	_add_textured_box("GateLintel", Vector3(7.0, 1.0, 1.4), Vector3(18.5, 3.1, 35.4), &"marble", true)
	var asset_library = AssetLibraryRoomScript.new()
	asset_library.name = "AutomaticAssetLibrary"
	asset_library.position = Vector3(-10.0, 0.0, 12.0)
	add_child(asset_library)
	for x: int in range(-8, 49, 4):
		if x > 14 and x < 23:
			continue
		_add_textured_box("NorthCrenel_%02d" % x, Vector3(2.1, 0.72, 1.45), Vector3(float(x), 3.96, 35.4), &"rough_stone", true)

	# Three firing lanes separated by low cover. Triplanar projection keeps the
	# same stone density on long walls, short blocks and vertical platform faces.
	for x: float in [3.0, 19.0, 35.0]:
		_add_textured_box("ArcherPlatform_%02d" % int(x), Vector3(7.0, 1.25, 5.0), Vector3(x, 0.625, 30.0), &"marble", true)
		_add_textured_box("ArcherParapet_%02d" % int(x), Vector3(7.4, 1.05, 0.65), Vector3(x, 1.77, 27.8), &"fortress", true)
	for x: float in [11.0, 27.0]:
		_add_textured_box("LaneDivider_%02d" % int(x), Vector3(0.75, 1.45, 14.0), Vector3(x, 0.725, 17.5), &"rough_stone", true)
	for cover: Dictionary in [
		{"name": "CoverA", "size": Vector3(5.5, 1.25, 0.8), "position": Vector3(2.0, 0.625, 20.0), "rotation": Vector3(0.0, 12.0, 0.0)},
		{"name": "CoverB", "size": Vector3(6.5, 1.65, 0.8), "position": Vector3(19.0, 0.825, 19.0), "rotation": Vector3(0.0, -10.0, 0.0)},
		{"name": "CoverC", "size": Vector3(5.5, 1.25, 0.8), "position": Vector3(36.0, 0.625, 20.5), "rotation": Vector3(0.0, 14.0, 0.0)}
	]:
		_add_textured_box(String(cover["name"]), cover["size"], cover["position"], &"rough_stone", true, cover["rotation"])

	# Props remain below _source/.gdignore and are decoded on demand, so merely
	# adding a raw GLB never launches a costly editor reimport.
	_add_raw_environment_prop("CrateBarricade", RAW_ENVIRONMENT_ROOT + "/caisse/caisses.glb", Vector3(-6.0, 0.0, 28.5), 1.65, Vector3(0.0, 18.0, 0.0))
	_add_raw_environment_prop("TrainingJar", RAW_ENVIRONMENT_ROOT + "/jare/jare.glb", Vector3(-3.5, 0.0, 25.5), 1.15, Vector3(0.0, -22.0, 0.0))
	_add_raw_environment_prop("SiegeCatapult", RAW_ENVIRONMENT_ROOT + "/catapulte/catapulte.glb", Vector3(42.0, 0.0, 29.5), 3.30, Vector3(0.0, -135.0, 0.0))

	# Static showroom: every target uses one of the replacement packages only.
	_spawn_enemy_group(
		&"new_roster_showcase",
		[&"nathenian1", &"nsbire1", &"nsbire2", &"nathenian2"],
		[Vector3(-32.0, 0.05, 7.0), Vector3(-27.5, 0.05, 7.0), Vector3(-23.0, 0.05, 7.0), Vector3(-18.0, 0.05, 7.0)],
		false,
		3
	)
	_add_world_label("NOUVEAU ROSTER — TEST ANATOMIE", Vector3(-25.0, 3.4, 4.5))

	# Dedicated ranged group. Nsbire2 owns the high ground, checks line of sight
	# around the parapets and falls back when the player reaches its platform.
	_spawn_enemy_group(
		&"archer_line",
		[&"nsbire2", &"nsbire2", &"nsbire2"],
		[Vector3(3.0, 1.30, 30.5), Vector3(19.0, 1.30, 30.5), Vector3(35.0, 1.30, 30.5)],
		true
	)
	_add_world_label("LIGNE D'ARCHERS NSBIRE2", Vector3(19.0, 4.5, 27.0))

	# A complete live formation: Nathenian2 commands shield infantry, farm-tool
	# skirmishers and a rear pair of archers. No legacy swordsman/captain remains.
	_spawn_enemy_group(
		&"new_combined_squad",
		[&"nathenian2", &"nathenian1", &"nathenian1", &"nsbire1", &"nsbire1", &"nsbire2", &"nsbire2"],
		[
			Vector3(41.0, 0.05, 10.0),
			Vector3(38.0, 0.05, 8.0), Vector3(44.0, 0.05, 8.0),
			Vector3(38.0, 0.05, 12.5), Vector3(44.0, 0.05, 12.5),
			Vector3(39.0, 0.05, 16.0), Vector3(43.0, 0.05, 16.0)
		],
		true,
		0
	)
	_add_world_label("GROUPE COMBINE — NATHENIAN2 COMMANDANT", Vector3(41.0, 3.6, 5.5))

	_build_legion_testing_annex()

	for i: int in range(10):
		_add_column(Vector3(-22.0 + i * 5.0, 0.0, -40.0))
	_add_battle_portal(Vector3(-5.5, 0.0, -49.0), "BATTLE 02 — GRAND SIEGE", BATTLE_02_SCENE, Color(0.78, 0.10, 0.035))
	_add_battle_portal(Vector3(5.5, 0.0, -49.0), "DERNIER HOPLITE — CAMPAGNE PROCEDURALE", PROCEDURAL_CAMPAIGN_SCENE, Color(0.92, 0.40, 0.055))
	_add_battle_portal(Vector3(0.0, 0.0, -58.0), "LA DERNIERE FLAMME — RECIT", NARRATIVE_BATTLE_SCENE, Color(0.20, 0.46, 1.0))
	_spawn_portal_phalanx_patrol()

func _add_world_label(text_value: String, position_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.modulate = Color(0.82, 0.90, 1.0)
	label.visible = debug_overlay_visible
	add_child(label)
	debug_world_labels.append(label)

func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color, collision_enabled: bool) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	add_child(body)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mi.material_override = mat
	body.add_child(mi)
	if collision_enabled:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.collision_layer = 1

func _add_textured_box(
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_style: StringName,
	collision_enabled: bool,
	rotation_value: Vector3 = Vector3.ZERO
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation_degrees = rotation_value
	body.collision_layer = 1 if collision_enabled else 0
	body.collision_mask = 1
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = MaterialLibraryScript.material(material_style)
	body.add_child(mesh_instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)

func _add_raw_environment_prop(
	node_name: String,
	path: String,
	position_value: Vector3,
	target_height: float,
	rotation_value: Vector3
) -> void:
	var packed := _runtime_environment_scene(path)
	if packed == null:
		push_warning("[ENVIRONMENT] Could not load raw prop: %s" % path)
		return
	var content := packed.instantiate() as Node3D
	if content == null:
		return
	var root := Node3D.new()
	root.name = node_name
	root.position = position_value
	root.rotation_degrees = rotation_value
	add_child(root)
	root.add_child(content)

	var bounds := _node_bounds_in_root(root, content)
	if bounds.size.y <= 0.001:
		push_warning("[ENVIRONMENT] Raw prop has no measurable mesh: %s" % path)
		root.queue_free()
		return
	var uniform_scale := target_height / bounds.size.y
	content.scale = Vector3.ONE * uniform_scale
	content.position.y = -bounds.position.y * uniform_scale

	# One conservative box proxy per decorative prop keeps collision cheap. The
	# authored collision GLBs stay available for a later production pass.
	var final_size := bounds.size * uniform_scale
	var collision_body := StaticBody3D.new()
	collision_body.name = "%sCollision" % node_name
	collision_body.collision_layer = 1
	collision_body.collision_mask = 1
	root.add_child(collision_body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(0.18, final_size.x * 0.86), maxf(0.18, final_size.y), maxf(0.18, final_size.z * 0.86))
	collision.shape = shape
	collision.position = Vector3(
		(bounds.position.x + bounds.size.x * 0.5) * uniform_scale,
		final_size.y * 0.5,
		(bounds.position.z + bounds.size.z * 0.5) * uniform_scale
	)
	collision_body.add_child(collision)

func _runtime_environment_scene(path: String) -> PackedScene:
	return RuntimeGLTFCacheScript.scene(path)

func _node_bounds_in_root(root: Node3D, content: Node3D) -> AABB:
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
		for corner_index: int in range(8):
			var local_point := root.to_local(mesh_instance.to_global(mesh_bounds.get_endpoint(corner_index)))
			if not initialized:
				bounds = AABB(local_point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(local_point)
	return bounds

func _build_legion_testing_annex() -> void:
	_add_textured_box("LegionAnnexFloor", Vector3(112.0, 0.12, 72.0), Vector3(104.0, 0.01, 2.0), &"sandstone_floor", false)
	_add_textured_box("LegionAnnexSouthWall", Vector3(112.0, 3.6, 1.2), Vector3(104.0, 1.8, -35.0), &"fortress", true)
	_add_textured_box("LegionAnnexNorthWall", Vector3(112.0, 3.6, 1.2), Vector3(104.0, 1.8, 39.0), &"fortress", true)
	_add_textured_box("LegionAnnexEastWall", Vector3(1.2, 3.6, 75.0), Vector3(160.0, 1.8, 2.0), &"fortress", true)

	var zones: Array[Dictionary] = [
		{"id": &"nathenian1", "label": "NATHENIAN I — INFANTERIE LEGERE", "center": Vector3(66.0, 0.0, -18.0)},
		{"id": &"nsbire1", "label": "NSBIRE I — LEVEE PAYSANNE", "center": Vector3(92.0, 0.0, -18.0)},
		{"id": &"nsbire2", "label": "NSBIRE II — ARCHERS", "center": Vector3(118.0, 0.0, -18.0)},
		{"id": &"nathenian2", "label": "NATHENIAN II — MARTEAUX", "center": Vector3(144.0, 0.0, -18.0)},
		{"id": &"bronze_colossus", "label": "BRONZE COLOSSUS — JUGGERNAUTS", "center": Vector3(66.0, 0.0, 22.0)},
		{"id": &"ncenturion", "label": "NCENTURION — COMMANDANTS", "center": Vector3(92.0, 0.0, 22.0)},
		{"id": &"ngeneral", "label": "NGENERAL — LANCIERS HOPLITES", "center": Vector3(118.0, 0.0, 22.0)},
		{"id": &"nfull_armor", "label": "NFULLARMOR — BOSS", "center": Vector3(144.0, 0.0, 22.0)}
	]
	for zone_index: int in range(zones.size()):
		var zone: Dictionary = zones[zone_index]
		_spawn_legion_test_zone(StringName(zone["id"]), String(zone["label"]), zone["center"] as Vector3, zone_index)
	_spawn_mixed_training_patrols()

func _spawn_legion_test_zone(archetype: StringName, label_text: String, center: Vector3, zone_index: int) -> void:
	var floor_style: StringName = &"marble" if (zone_index % 2) == 0 else &"sandstone_floor"
	_add_textured_box("LegionZoneFloor_%02d" % zone_index, Vector3(23.0, 0.10, 28.0), center + Vector3(0.0, 0.07, 0.0), floor_style, false)
	for corner: Vector3 in [Vector3(-10.8, 0.55, -12.8), Vector3(10.8, 0.55, -12.8), Vector3(-10.8, 0.55, 12.8), Vector3(10.8, 0.55, 12.8)]:
		_add_textured_box("LegionZone_%02d_Post_%s" % [zone_index, str(corner)], Vector3(0.65, 1.10, 0.65), center + corner, &"marble", true)
	_add_training_zone_label(label_text + "\n7 UNITES — ACTIVATION LOCALE", center + Vector3(0.0, 3.6, -11.8))

	var members: Array[StringName] = []
	var positions: Array[Vector3] = []
	var formation: Array[Vector3] = [
		Vector3(-4.8, 0.05, -3.0), Vector3(0.0, 0.05, -3.0), Vector3(4.8, 0.05, -3.0),
		Vector3(-7.0, 0.05, 2.8), Vector3(-2.4, 0.05, 2.8), Vector3(2.4, 0.05, 2.8), Vector3(7.0, 0.05, 2.8)
	]
	for offset: Vector3 in formation:
		members.append(archetype)
		positions.append(center + offset)
	var needs_detailed_weapon_animation := archetype in [&"nsbire2", &"ngeneral", &"ngeneral_veteran"]
	_spawn_enemy_group(
		StringName("legion_%s" % String(archetype)),
		members,
		positions,
		true,
		-1,
		not needs_detailed_weapon_animation,
		center,
		13.5
	)

func _spawn_mixed_training_patrols() -> void:
	var regular_members: Array[StringName] = [&"ncenturion", &"nathenian1", &"nathenian1", &"nsbire1", &"nsbire1", &"nsbire2", &"nsbire2"]
	var regular_positions: Array[Vector3] = []
	for index: int in range(regular_members.size()):
		regular_positions.append(Vector3(58.0 - float(index % 3) * 1.5, 0.05, -3.0 + float(index / 3) * 1.8))
	var regular := _spawn_enemy_group(&"mixed_regular_patrol", regular_members, regular_positions, true, 0, true, Vector3(105.0, 0.0, -3.0), 19.0)
	for index: int in range(regular.size()):
		var lane_offset := (float(index) - 3.0) * 0.62
		var regular_route: Array[Vector3] = [
			Vector3(58.0, 0.05, -3.0 + lane_offset),
			Vector3(105.0, 0.05, -3.0 + lane_offset),
			Vector3(151.0, 0.05, -3.0 + lane_offset)
		]
		regular[index].call("configure_demo_patrol", regular_route, index)
	_add_training_zone_label("PATROUILLE MIXTE REGULIERE\nCENTURION • BOUCLIERS • PAYSANS • ARCHERS", Vector3(84.0, 4.2, -3.0))

	var elite_members: Array[StringName] = [&"nfull_armor", &"nathenian2", &"bronze_colossus", &"ngeneral_veteran", &"ncenturion", &"nathenian1", &"nsbire2"]
	var elite_positions: Array[Vector3] = []
	for index: int in range(elite_members.size()):
		elite_positions.append(Vector3(151.0 + float(index % 3) * 1.4, 0.05, 3.0 + float(index / 3) * 1.8))
	var elite := _spawn_enemy_group(&"mixed_elite_patrol", elite_members, elite_positions, true, 0, true, Vector3(105.0, 0.0, 4.0), 19.0)
	for index: int in range(elite.size()):
		var lane_offset := (float(index) - 3.0) * 0.68
		var elite_route: Array[Vector3] = [
			Vector3(151.0, 0.05, 4.0 + lane_offset),
			Vector3(105.0, 0.05, 4.0 + lane_offset),
			Vector3(58.0, 0.05, 4.0 + lane_offset)
		]
		elite[index].call("configure_demo_patrol", elite_route, index)
	_add_training_zone_label("PATROUILLE MIXTE ELITE\nBOSS • MINIBOSS • SOUTIENS", Vector3(126.0, 4.2, 4.0))

func _spawn_portal_phalanx_patrol() -> void:
	# Fifteen soldiers produce three complete ranks of five. Veterans occupy the
	# two flanks of the first two ranks; the all-standard rear rank demonstrates
	# the high spear carry used while waiting for a breach.
	var members: Array[StringName] = [
		&"ngeneral_veteran", &"ngeneral", &"ngeneral", &"ngeneral", &"ngeneral_veteran",
		&"ngeneral_veteran", &"ngeneral", &"ngeneral", &"ngeneral", &"ngeneral_veteran",
		&"ngeneral", &"ngeneral", &"ngeneral", &"ngeneral", &"ngeneral"
	]
	var center := Vector3(0.0, 0.05, -37.0)
	var positions: Array[Vector3] = []
	var offsets: Array[Vector3] = []
	for row: int in range(3):
		for column: int in range(5):
			var offset := Vector3((float(column) - 2.0) * 1.28, 0.0, -float(row) * 1.32)
			offsets.append(offset)
			positions.append(center + offset)
	var patrol := _spawn_enemy_group(
		&"portal_phalanx_patrol",
		members,
		positions,
		true,
		-1,
		false,
		center,
		0.0
	)
	for index: int in range(patrol.size()):
		var route: Array[Vector3] = [
			Vector3(-4.0, 0.05, -37.0) + offsets[index],
			Vector3(4.0, 0.05, -37.0) + offsets[index]
		]
		patrol[index].call("configure_demo_patrol", route, 0, 31.0, 1.65)
	_add_training_zone_label(
		"PATROUILLE DE PHALANGE — 15 SOLDATS\n11 HOPLITES • 4 VETERANS AUX FLANCS • 3 RANGS",
		Vector3(0.0, 4.6, -33.0)
	)

func _add_training_zone_label(text_value: String, position_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(0.95, 0.78, 0.38)
	add_child(label)

func _spawn_enemy_group(
	group_id: StringName,
	members: Array[StringName],
	positions: Array[Vector3],
	ai_enabled: bool,
	commander_index: int = -1,
	mass_battle_mode: bool = false,
	activation_center: Vector3 = Vector3.ZERO,
	activation_radius: float = 0.0
) -> Array[Node3D]:
	var enemies: Array[Node3D] = []
	if members.size() != positions.size():
		push_warning("[TRAINING GROUP] %s has mismatched member/position counts." % String(group_id))
		return enemies
	enemies.resize(members.size())
	var commander: Node3D = null
	if commander_index >= 0 and commander_index < members.size():
		commander = EnemyFactoryScript.spawn(self, members[commander_index], positions[commander_index], player, {
			"ai_enabled": ai_enabled,
			"mass_battle_mode": mass_battle_mode,
			"guard_index": commander_index,
			"name": "%s_Commander" % String(group_id)
		})
		enemies[commander_index] = commander
	for i: int in range(members.size()):
		if i == commander_index:
			continue
		var enemy := EnemyFactoryScript.spawn(self, members[i], positions[i], player, {
			"ai_enabled": ai_enabled,
			"mass_battle_mode": mass_battle_mode,
			"guard_index": i,
			"commander": commander,
			"name": "%s_%02d_%s" % [String(group_id), i, String(members[i])]
		}) as Node3D
		enemies[i] = enemy
	for enemy: Node3D in enemies:
		if enemy != null:
			_wire_enemy_feedback(enemy)
			enemy.set_meta("training_group", group_id)
			enemy.set_meta("formation_group", group_id)
			if activation_radius > 0.0 and enemy.has_method("configure_training_activation"):
				enemy.call("configure_training_activation", activation_center, activation_radius)
	return enemies

func _add_marker(position: Vector3, radius: float) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = 0.025
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	marker.mesh = mesh
	marker.position = position
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.48, 0.19)
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.07, 0.01)
	marker.material_override = mat
	add_child(marker)

func _add_environment_prop(
	node_name: String,
	visual_path: String,
	collision_path: String,
	position_value: Vector3,
	uniform_scale: float,
	rotation_value: Vector3,
	visual_ground_offset: float,
	collision_ground_offset: float
) -> void:
	var visual_scene := load(visual_path) as PackedScene
	if visual_scene == null:
		push_warning("[ENVIRONMENT] Missing visual: %s" % visual_path)
		return

	var root := Node3D.new()
	root.name = node_name
	root.position = position_value
	root.rotation_degrees = rotation_value
	add_child(root)

	var visual := visual_scene.instantiate() as Node3D
	if visual != null:
		visual.name = "%sVisual" % node_name
		visual.scale = Vector3.ONE * uniform_scale
		visual.position.y = visual_ground_offset * uniform_scale
		root.add_child(visual)

	var collision_scene := load(collision_path) as PackedScene
	if collision_scene == null:
		push_warning("[ENVIRONMENT] Missing collision proxy: %s" % collision_path)
		return
	var collision_root := collision_scene.instantiate() as Node3D
	if collision_root == null:
		return
	collision_root.name = "%sCollisionProxy" % node_name
	collision_root.scale = Vector3.ONE * uniform_scale
	collision_root.position.y = collision_ground_offset * uniform_scale
	root.add_child(collision_root)

	var collision_meshes: Array[MeshInstance3D] = []
	if collision_root is MeshInstance3D:
		collision_meshes.append(collision_root as MeshInstance3D)
	for candidate: Node in collision_root.find_children("*", "MeshInstance3D", true, false):
		collision_meshes.append(candidate as MeshInstance3D)
	for collision_mesh: MeshInstance3D in collision_meshes:
		collision_mesh.visible = false
		if collision_mesh.mesh == null:
			continue
		var body := StaticBody3D.new()
		body.name = "%sStaticBody" % node_name
		body.collision_layer = 1
		body.collision_mask = 1
		collision_mesh.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = collision_mesh.mesh.create_trimesh_shape()
		body.add_child(shape)

func _add_column(position: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.position = position
	add_child(root)
	var mat: Material = MaterialLibraryScript.material(&"marble")
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.height = 4.6
	cylinder.top_radius = 0.30
	cylinder.bottom_radius = 0.38
	shaft.mesh = cylinder
	shaft.position.y = 2.3
	shaft.material_override = mat
	root.add_child(shaft)
	var top: MeshInstance3D = MeshInstance3D.new()
	var top_mesh: BoxMesh = BoxMesh.new()
	top_mesh.size = Vector3(1.15, 0.22, 0.8)
	top.mesh = top_mesh
	top.position.y = 4.62
	top.material_override = mat
	root.add_child(top)

func _add_athenian(position: Vector3, ai_enabled: bool = false, _miniboss: bool = false, boss_ref: Node3D = null, guard_index: int = 0, archetype: StringName = &"nsbire1", character_package_path: String = ""):
	var enemy := EnemyFactoryScript.spawn(self, archetype, position, player, {
		"ai_enabled": ai_enabled,
		"commander": boss_ref,
		"guard_index": guard_index,
		"package_path": character_package_path
	}) as Node3D
	if enemy != null:
		_wire_enemy_feedback(enemy)
	return enemy

func _add_battle_portal(position_value: Vector3, portal_title: String, target_scene: String, portal_color: Color) -> void:
	var root := Node3D.new()
	root.name = "Battle01Portal"
	root.position = position_value
	add_child(root)

	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.19, 0.16, 0.14)
	stone.roughness = 0.72
	var glow := StandardMaterial3D.new()
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.30)
	glow.emission_enabled = true
	glow.emission = portal_color * 1.55
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for x: float in [-2.0, 2.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.70, 3.6, 0.70)
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x, 1.8, 0.0)
		pillar.material_override = stone
		root.add_child(pillar)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(4.75, 0.62, 0.72)
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0.0, 3.42, 0.0)
	lintel.material_override = stone
	root.add_child(lintel)

	var portal := MeshInstance3D.new()
	var portal_mesh := BoxMesh.new()
	portal_mesh.size = Vector3(3.25, 2.55, 0.08)
	portal.mesh = portal_mesh
	portal.position = Vector3(0.0, 1.5, 0.0)
	portal.material_override = glow
	root.add_child(portal)

	var label := Label3D.new()
	label.text = portal_title
	label.position = Vector3(0.0, 4.08, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.modulate = portal_color.lightened(0.34)
	root.add_child(label)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	root.add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 3.0, 1.7)
	collision.shape = shape
	collision.position.y = 1.5
	area.add_child(collision)
	area.body_entered.connect(_on_battle_portal_entered.bind(target_scene))

func _on_battle_portal_entered(body: Node3D, target_scene: String) -> void:
	if body != player:
		return
	call_deferred("_load_battle_scene", target_scene)

func _load_battle_scene(target_scene: String) -> void:
	get_tree().change_scene_to_file(target_scene)

func _add_dummy(position: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.position = position
	add_child(root)
	var blue: StandardMaterial3D = StandardMaterial3D.new()
	blue.albedo_color = Color(0.035, 0.20, 0.68)
	blue.roughness = 0.58
	var torso: MeshInstance3D = MeshInstance3D.new()
	var torso_mesh: CylinderMesh = CylinderMesh.new()
	torso_mesh.height = 1.45
	torso_mesh.top_radius = 0.31
	torso_mesh.bottom_radius = 0.34
	torso.mesh = torso_mesh
	torso.position.y = 0.82
	torso.material_override = blue
	root.add_child(torso)
	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position.y = 1.72
	head.material_override = blue
	root.add_child(head)

	# Non-blocking combat sensor so slide slashes can be tested without turning
	# the training dummies into walls for the CharacterBody.
	var hit_area: Area3D = Area3D.new()
	hit_area.name = "SlideSlashTarget"
	hit_area.collision_layer = 4
	hit_area.collision_mask = 0
	root.add_child(hit_area)
	hit_area.add_to_group("damageable")
	var hit_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 1.95
	hit_shape.shape = capsule
	hit_shape.position.y = 0.98
	hit_area.add_child(hit_shape)

func _on_slide_slash_contact(target: Node) -> void:
	if target == null:
		return
	var dummy_root: Node3D = target.get_parent() as Node3D
	if dummy_root == null:
		return
	# Lab feedback only. Real enemies can implement on_slide_slash(attacker)
	# or connect to the player's slide_slash_contact signal for their damage logic.
	var tween: Tween = dummy_root.create_tween()
	tween.tween_property(dummy_root, "scale", Vector3(1.16, 0.82, 1.16), 0.045)
	tween.tween_property(dummy_root, "scale", Vector3.ONE, 0.13)

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	# Clean game HUD: this is the only UI visible by default.
	var health_background: ColorRect = ColorRect.new()
	health_background.visible = false
	health_background.position = Vector2(18, 18)
	health_background.size = Vector2(302, 34)
	health_background.color = Color(0.025, 0.02, 0.025, 0.90)
	layer.add_child(health_background)

	var health_track: ColorRect = ColorRect.new()
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

	# Laboratory diagnostics. Hidden by default; I reveals this entire layer AND
	# enables the former H anatomy/sword debug at the same time.
	debug_panel = ColorRect.new()
	debug_panel.position = Vector2(14, 64)
	debug_panel.size = Vector2(1235, 214)
	debug_panel.color = Color(0.025, 0.025, 0.035, 0.86)
	debug_panel.visible = debug_overlay_visible
	layer.add_child(debug_panel)

	debug_title = Label.new()
	debug_title.position = Vector2(28, 74)
	debug_title.text = "PROJECT HOPLITE — V0.0.11 TUTORIAL + BATTLE 01"
	debug_title.add_theme_font_size_override("font_size", 23)
	debug_title.visible = debug_overlay_visible
	layer.add_child(debug_title)

	debug_help = Label.new()
	debug_help.position = Vector2(28, 106)
	debug_help.text = "ZQSD/WASD = mouvement • SPACE x2 = NinjaJump • SPACE obstacle = vault/mantle • SHIFT = dash (3s) • CTRL = slide x2 (1,5s)\nLMB court/J = rapide • LMB maintenu/K = lourde + aim assist 3D • RMB = bouclier • molette haut/A = spirale decapitation • molette bas = spirale plongeante\nSpirale = 3 stamina • Hit = +1 • Perfect = +2 et recharge mobilité • Caméra libre • I = diagnostics"
	debug_help.add_theme_font_size_override("font_size", 14)
	debug_help.visible = debug_overlay_visible
	layer.add_child(debug_help)

	debug_label = Label.new()
	debug_label.position = Vector2(28, 186)
	debug_label.text = "Starting UAL motion/combat lab..."
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_label.visible = debug_overlay_visible
	layer.add_child(debug_label)
