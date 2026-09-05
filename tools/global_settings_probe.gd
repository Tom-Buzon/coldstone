extends SceneTree

const LabScene = preload("res://combat_lab.tscn")
const BattleScene = preload("res://battle_01.tscn")
const CampaignScene = preload("res://procedural_campaign.tscn")
const NarrativeScene = preload("res://battle_03_narrative.tscn")
const CrowdSettingsScript = preload("res://scripts/ai/crowd_management_settings.gd")
const FaunaSettingsScript = preload("res://scripts/fauna/fauna_settings.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const WeaponTuningScript = preload("res://scripts/equipment/weapon_tuning.gd")

const EPIC_CAMERA_DEFAULTS := {
	&"shield_camera_height": 0.10,
	&"shield_camera_distance": 3.0,
	&"shield_camera_pitch": 6.5,
	&"shield_fov_zoom": 6.0,
	&"shield_time_scale": 0.90,
	&"shield_transition_duration": 0.30,
	&"giant_camera_height": 0.10,
	&"giant_camera_distance": 3.0,
	&"giant_camera_pitch": 22.0,
	&"giant_fov_zoom": 4.0,
	&"giant_time_scale": 0.70,
	&"giant_transition_duration": 0.40,
}

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_packed(LabScene)
	await scene_changed
	await process_frame
	await process_frame
	var settings := current_scene.get_node_or_null("Settings") as HopliteAudioSettings
	_require(settings != null, "global settings menu is missing from the combat lab")
	if settings != null:
		settings.set_open(true)
		await process_frame
		_require(settings.tabs != null and settings.tabs.get_tab_count() == 8, "settings must expose camera, sound, display, weapons, atmosphere, crowd management, fauna and gameplay tabs")
		_require(settings.weapon_option != null and settings.weapon_option.item_count == EquipmentCatalogScript.ALL_WEAPONS.size(), "weapon settings must expose every registered weapon")
		_require(settings.weapon_tuning_sliders.size() == WeaponTuningScript.DEFINITIONS.size(), "weapon settings are missing tuning controls")
		_require(settings.crowd_sliders.size() == CrowdSettingsScript.DEFINITIONS.size(), "crowd-management tab does not expose every shared tuning value")
		for required_phalanx_control: StringName in [
			&"phalanx_advance_speed", &"phalanx_move_speed_multiplier",
			&"phalanx_arrival_slowdown_distance", &"phalanx_arrival_min_speed_scale",
			&"phalanx_columns", &"phalanx_column_spacing", &"phalanx_rank_spacing",
		]:
			_require(settings.crowd_sliders.has(required_phalanx_control), "crowd-management tab is missing live phalanx control: %s" % String(required_phalanx_control))
		_require(settings.fauna_species_toggles.size() == FaunaSettingsScript.SPECIES.size(), "fauna tab does not expose every animal species")
		for definition: Dictionary in CrowdSettingsScript.DEFINITIONS:
			_require(not String(definition.get("description", "")).is_empty(), "crowd setting has no visible explanation: %s" % String(definition.get("id", "unknown")))
		_require(settings.remap_buttons.size() >= 26, "full MNK/gamepad remapping list is incomplete")
		_require(settings.sfx_detail_sliders.size() >= 20, "per-SFX detail controls are incomplete")
		_require(settings.atmosphere_sliders.size() == 8 and settings.atmosphere_preset_option.item_count >= 10, "atmosphere controls and templates are incomplete")
		_require(settings.lod_sliders.size() == 15 and settings.lod_enabled_toggle != null, "performance and enemy LOD settings are incomplete")
		_require(settings.player_skin_option != null and settings.player_skin_option.item_count == HopliteUALNativePlayer.PLAYER_SKINS.size(), "display settings must expose the three player skins")
		if settings.player != null and settings.player_skin_option != null:
			settings.call("_on_player_skin_selected", 1)
			_require(settings.player.get_player_skin_id() == HopliteUALNativePlayer.PLAYER_SKIN_NOON and settings.player_skin_option.selected == 1, "the display skin selector did not apply Noon T1 live")
			_require(settings.player_skin_parts_container != null and settings.player_skin_parts_container.get_child_count() == settings.player.get_player_skin_parts().size(), "the display menu did not expose every imported player mesh")
			settings.call("_on_player_skin_selected", 0)
			_require(settings.player.get_player_skin_id() == HopliteUALNativePlayer.PLAYER_SKIN_BASE, "the display skin selector did not restore the base Hoplite")
		_require(settings.visual_settings.has(&"camera_occlusion") and not settings.visual_settings.has(&"camera_occlusion_outline"), "camera readability must expose its enable toggle without the removed outline option")
		_require(settings.camera_occlusion_sliders.size() == 2, "camera readability opacity and protection radius controls are incomplete")
		var occlusion_fader := settings.player.camera_occlusion_fader if settings.player != null else null
		_require(occlusion_fader != null, "the player does not own the global camera occlusion fader")
		if occlusion_fader != null:
			settings.call("_on_camera_occlusion_slider_changed", 0.21, &"opacity")
			settings.call("_on_camera_occlusion_slider_changed", 0.66, &"radius")
			_require(is_equal_approx(occlusion_fader.occluder_opacity, 0.21) and is_equal_approx(occlusion_fader.probe_radius, 0.66), "live readability settings did not reach the camera fader")
		_require(settings.epic_run_camera_sliders.size() == HopliteUALNativePlayer.EPIC_RUN_CAMERA_SETTING_DEFINITIONS.size(), "camera tab does not expose every Giant/Shield Run tuning value")
		if settings.player != null:
			_require(is_equal_approx(settings.camera_distance_slider.min_value, 1.0), "normal camera slider does not reach the new 1 metre minimum")
			settings.player.set_camera_distance(0.1, false)
			_require(is_equal_approx(settings.player.get_camera_distance(), 1.0), "normal camera runtime did not clamp to the new 1 metre minimum")
			settings.player.reset_camera_tps()
			_require(is_equal_approx(settings.player.get_camera_distance(), 3.5), "normal camera reset did not preserve the promoted 3.5 metre default")
			for definition: Dictionary in HopliteUALNativePlayer.EPIC_RUN_CAMERA_SETTING_DEFINITIONS:
				var id := StringName(definition["id"])
				_require(EPIC_CAMERA_DEFAULTS.has(id), "unexpected epic camera setting definition: %s" % String(id))
				_require(is_equal_approx(float(definition["default"]), float(EPIC_CAMERA_DEFAULTS.get(id, -999.0))), "promoted default does not match the saved playtest value: %s" % String(id))
				_require(is_equal_approx(settings.player.get_epic_wall_run_camera_setting(id), float(EPIC_CAMERA_DEFAULTS.get(id, -999.0))), "player reset did not apply the promoted default: %s" % String(id))
			settings.call("_on_epic_run_camera_setting_changed", -0.75, &"giant_camera_height")
			settings.call("_on_epic_run_camera_setting_changed", 31.0, &"giant_camera_pitch")
			_require(is_equal_approx(settings.player.get_epic_wall_run_camera_setting(&"giant_camera_height"), -0.75), "live Giant Run camera height did not reach the player")
			_require(is_equal_approx(settings.player.combat_feedback.giant_camera_pitch, 31.0), "live Giant Run upward angle did not reach CombatFeedback")
			settings.player._reset_epic_wall_run_camera_settings()
			settings.player.combat_feedback.configure_epic_wall_run_settings(settings.player.epic_wall_run_camera_settings)
			settings.call("_sync_from_camera")
		_require(settings.is_open() and paused, "opening settings must pause every scene")
		settings.call("_on_lod_profile_selected", 2)
		_require(is_equal_approx(root.mesh_lod_threshold, 4.0), "performance LOD profile did not reach the root viewport")
		_require(bool(ProjectSettings.get_setting("hoplite/enemy_lod/enabled", false)), "enemy LOD runtime policy is not enabled")
		_require(int(ProjectSettings.get_setting("hoplite/enemy_lod/near_physics_divisor", 0)) == 3, "performance profile did not publish the near crowd cadence")
		_require(int(ProjectSettings.get_setting("hoplite/performance/spawn_per_frame", 0)) == 1, "performance profile did not publish the staged-spawn budget")
		settings.call("_on_atmosphere_preset_selected", 4)
		_require(settings.atmosphere_sun != null and settings.atmosphere_sun.light_energy > 1.5, "atmosphere template did not reach the scene light")
		var lod_enemy := get_first_node_in_group("enemy") as HopliteAthenianEnemy
		if lod_enemy != null and settings.player != null:
			lod_enemy.global_position = settings.player.global_position + Vector3(100.0, 0.0, 0.0)
			lod_enemy.call("_update_performance_lod")
			_require(int(lod_enemy.get("render_lod_level")) == 3, "far enemy did not enter culling LOD")
			var lod_meshes := lod_enemy.find_children("*", "MeshInstance3D", true, false)
			_require(not lod_meshes.is_empty(), "LOD enemy has no mesh to optimize")
			if not lod_meshes.is_empty():
				var lod_mesh := lod_meshes[0] as GeometryInstance3D
				_require(lod_mesh.lod_bias <= 0.23 and is_equal_approx(lod_mesh.visibility_range_end, 65.0), "far mesh did not receive Godot LOD bias and culling range")
				_require(lod_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "far mesh still casts expensive shadows")
			settings.call("_on_lod_enabled_toggled", false)
			_require(int(lod_enemy.get("render_lod_level")) == 0, "disabling LOD did not restore full quality")
			settings.call("_on_lod_enabled_toggled", true)
		settings.set_open(false)
	_require(_has_gamepad_event(&"jump"), "jump has no gamepad binding")
	_require(_has_gamepad_event(&"attack_primary"), "primary attack has no R2 binding")
	_require(InputMap.has_action(&"counter_close") and not InputMap.action_get_events(&"counter_close").is_empty(), "perfect close counter binding is missing")
	await _require_global_menu(BattleScene, "battle mission")
	await _require_global_menu(CampaignScene, "procedural campaign")
	await _require_global_menu(NarrativeScene, "narrative mission")
	if failures.is_empty():
		print("GLOBAL_SETTINGS_PROBE PASS: 8 tabs, per-weapon tuning, live Giant/Shield camera tuning, fauna, crowd tuning, atmosphere templates and enemy LOD in every world")
		quit(0)
		return
	for failure: String in failures:
		push_error("[GLOBAL SETTINGS] " + failure)
	quit(1)

func _has_gamepad_event(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false

func _require_global_menu(scene: PackedScene, scene_label: String) -> void:
	change_scene_to_packed(scene)
	await scene_changed
	await process_frame
	await process_frame
	var found := false
	for child: Node in current_scene.find_children("*", "HopliteAudioSettings", true, false):
		if child is HopliteAudioSettings:
			found = true
			break
	_require(found, "global settings menu is missing from %s" % scene_label)

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
