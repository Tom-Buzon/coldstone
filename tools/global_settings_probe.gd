extends SceneTree

const LabScene = preload("res://combat_lab.tscn")
const BattleScene = preload("res://battle_01.tscn")
const CampaignScene = preload("res://procedural_campaign.tscn")
const NarrativeScene = preload("res://battle_03_narrative.tscn")

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
		_require(settings.tabs != null and settings.tabs.get_tab_count() == 5, "settings must expose camera, sound, display, atmosphere and gameplay tabs")
		_require(settings.remap_buttons.size() >= 26, "full MNK/gamepad remapping list is incomplete")
		_require(settings.sfx_detail_sliders.size() >= 20, "per-SFX detail controls are incomplete")
		_require(settings.atmosphere_sliders.size() == 8 and settings.atmosphere_preset_option.item_count >= 10, "atmosphere controls and templates are incomplete")
		_require(settings.lod_sliders.size() == 4 and settings.lod_enabled_toggle != null, "enemy LOD settings are incomplete")
		_require(settings.is_open() and paused, "opening settings must pause every scene")
		settings.call("_on_lod_profile_selected", 2)
		_require(is_equal_approx(root.mesh_lod_threshold, 4.0), "performance LOD profile did not reach the root viewport")
		_require(bool(ProjectSettings.get_setting("hoplite/enemy_lod/enabled", false)), "enemy LOD runtime policy is not enabled")
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
		print("GLOBAL_SETTINGS_PROBE PASS: 5 tabs, 10 atmosphere templates, configurable enemy LOD in lab/battle/campaign/narrative")
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
