extends SceneTree

const CampaignScript = preload("res://scripts/campaign/procedural_campaign.gd")
const PanelScript = preload("res://scripts/campaign/atmosphere_control_panel.gd")
const TrainingRangeScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var training_range := TrainingRangeScript.new()
	training_range.call("_build_environment")
	training_range.call("_build_atmosphere_controls")
	var training_panel := training_range.atmosphere_panel as HopliteAtmosphereControlPanel
	assert(training_panel != null, "The shooting range does not install the O atmosphere menu")
	assert(training_panel.world_environment == training_range.training_world_environment, "The shooting range menu is not linked to its environment")
	assert(training_panel.sun == training_range.training_sun, "The shooting range menu is not linked to its sun")
	training_range.free()

	var campaign := CampaignScript.new()
	campaign.call("_build_environment")
	var expected := {
		&"walls": [Color("ffb46a"), Color("52647a"), 0.48, 24.0],
		&"city": [Color("d79557"), Color("39465a"), 0.34, 31.0],
		&"dungeon": [Color("c94b32"), Color("202737"), 0.22, 16.0]
	}
	for zone_id: StringName in expected:
		campaign.call("_configure_environment", zone_id)
		var environment := campaign.world_environment.environment as Environment
		var values: Array = expected[zone_id]
		assert(environment.tonemap_mode == Environment.TONE_MAPPER_ACES, "%s does not use ACES" % String(zone_id))
		assert(campaign.sun.light_color.is_equal_approx(values[0] as Color), "%s sun color is wrong" % String(zone_id))
		assert(environment.ambient_light_color.is_equal_approx(values[1] as Color), "%s ambient color is wrong" % String(zone_id))
		assert(is_equal_approx(environment.ambient_light_energy, float(values[2])), "%s ambient energy is wrong" % String(zone_id))
		assert(is_equal_approx(absf(campaign.sun.rotation_degrees.x), float(values[3])), "%s sun height is wrong" % String(zone_id))
	assert(campaign.world_environment.environment.fog_enabled, "Atmospheric fog is disabled")

	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var panel = PanelScript.new()
	scene.add_child(panel)
	panel.configure(campaign.world_environment, campaign.sun)
	panel.call("_on_preset_selected", 1)
	assert(campaign.sun.light_color.is_equal_approx(Color("ffb46a")), "Battlefield preset is incorrect")
	panel.call("_on_preset_selected", 2)
	assert(campaign.world_environment.environment.ambient_light_color.is_equal_approx(Color("39465a")), "Fortress preset is incorrect")
	panel.call("_on_preset_selected", 3)
	assert(campaign.sun.light_color.is_equal_approx(Color("c94b32")), "Boss dungeon preset is incorrect")
	panel.set_open(true)
	assert(paused and panel.is_open(), "O menu does not pause the game")
	panel.set_open(false)
	assert(not paused and not panel.is_open(), "Atmosphere menu does not resume the game")
	print("[ATMOSPHERE PANEL PROBE] PASS — shooting range O menu, ACES, presets and pause")
	campaign.free()
	quit(0)
