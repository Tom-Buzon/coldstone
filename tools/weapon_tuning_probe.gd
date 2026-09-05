extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const WeaponTuningScript = preload("res://scripts/equipment/weapon_tuning.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	scene.name = "WeaponTuningProbe"
	root.add_child(scene)
	current_scene = scene
	var player := PlayerScript.new() as HopliteUALNativePlayer
	scene.add_child(player)
	await process_frame
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE))
	await process_frame

	var settings := player.player_presentation.audio_settings as HopliteAudioSettings
	assert(settings != null, "Settings UI is missing")
	assert(settings.tabs.get_node_or_null("ARMES") != null, "ARMES settings tab is missing")
	assert(settings.weapon_option.item_count == EquipmentCatalogScript.ALL_WEAPONS.size(), "Every weapon must be tunable")
	assert(settings.weapon_tuning_sliders.size() == WeaponTuningScript.DEFINITIONS.size(), "Weapon tuning controls are incomplete")

	var item := EquipmentCatalogScript.XIPHOS
	WeaponTuningScript.reset(item)
	settings.selected_weapon_id = item.item_id
	settings._sync_from_weapons()
	settings._on_weapon_tuning_changed(0.55, &"scale")
	settings._on_weapon_tuning_changed(0.18, &"blade_base")
	settings._on_weapon_tuning_changed(0.92, &"blade_tip")
	settings._on_weapon_tuning_changed(0.08, &"hit_radius")
	settings._on_weapon_tuning_changed(1.70, &"damage_multiplier")
	settings._flush_weapon_tuning_saves()

	assert(is_equal_approx(player.sword_root.scale.x, 0.55), "Weapon scale was not applied live")
	assert(is_equal_approx(player.sword_base.position.y, 0.18), "Blade base was not applied live")
	assert(is_equal_approx(player.sword_tip.position.y, 0.92), "Blade tip was not applied live")
	assert(is_equal_approx(player.weapon_hit_radius, 0.08), "Hit radius was not applied live")
	assert(is_equal_approx(player.weapon_damage_multiplier, 1.70), "Damage progression was not applied live")
	var hit: Variant = player._make_weapon_hit_event(&"light1", &"ground", Vector3.ZERO, Vector3.FORWARD, 0.0)
	assert(is_equal_approx(float(hit.damage), 18.0 * 0.90 * 1.70), "Weapon power did not multiply real combat damage")

	var config := ConfigFile.new()
	assert(config.load(WeaponTuningScript.CONFIG_PATH) == OK, "Weapon tuning settings were not persisted")
	assert(is_equal_approx(float(config.get_value("weapon_xiphos", "scale", 0.0)), 0.55), "Persisted weapon scale is wrong")

	WeaponTuningScript.reset(item)
	player.refresh_weapon_tuning(item.item_id)
	print("[WEAPON TUNING PROBE] PASS — per-weapon UI, persistence and live combat geometry")
	quit(0)
