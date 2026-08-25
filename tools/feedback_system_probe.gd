extends SceneTree

const CombatAudioScript = preload("res://scripts/audio/combat_audio.gd")
const GoreHUDScript = preload("res://scripts/ui/gore_hud.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node.new()
	get_root().add_child(scene)
	current_scene = scene

	var audio := CombatAudioScript.new() as HopliteCombatAudio
	audio.name = "CombatAudioProbe"
	scene.add_child(audio)
	var hud := GoreHUDScript.new() as HopliteGoreHUD
	hud.name = "GoreHUDProbe"
	scene.add_child(hud)
	var settings := AudioSettingsScript.new() as HopliteAudioSettings
	settings.combat_audio = audio
	settings.gore_hud = hud
	scene.add_child(settings)
	await process_frame

	var failures: int = 0
	hud.set_enabled(false, false)
	var first_contact: int = hud.register_contact(&"torso", 24.0, false)
	var second_contact: int = hud.register_contact(&"head", 40.0, false)
	var independent_marker: bool = hud.feedback_root != null and hud.feedback_root.visible and not hud.root.visible
	var multi_target_ok: bool = first_contact == 1 and second_contact == 2 and hud.hit_value_label.text == "2 TARGETS"

	hud.set_enabled(true, false)
	hud.register_cinematic(&"decapitation", 1.0)
	hud._update_cinematic_overlay(0.16)
	var cinematic_hud_ok: bool = hud.root.visible and hud.cinematic_duration > 0.0 and hud.cinematic_top_bar.offset_bottom > 0.0
	var setting_sync_ok: bool = bool(settings.visual_settings.get(&"gore", false)) == hud.is_enabled()

	var confirm_bank: Array = audio.sfx_banks.get(&"hit_confirm", [])
	var confirm_stream: AudioStream = confirm_bank[0] as AudioStream if not confirm_bank.is_empty() else null
	var audio_fallback_ok: bool = confirm_stream != null
	audio.play_hit_confirm(&"head", 2, false)
	var contextual_banks_ok: bool = (
		audio.sfx_banks.get(&"sword_light_1", []).size() == 1
		and audio.sfx_banks.get(&"sword_light_air", []).size() == 1
		and audio.sfx_banks.get(&"sword_heavy", []).size() == 2
		and audio.sfx_banks.get(&"sword_spiral_ground", []).size() == 1
		and audio.sfx_banks.get(&"sword_slide", []).size() == 2
		and audio.sfx_banks.get(&"sword_shield_impact", []).size() == 3
		and audio.sfx_banks.get(&"sword_armor_impact", []).size() == 1
		and audio.sfx_banks.get(&"sever_head", []).size() == 2
		and audio.sfx_banks.get(&"sever_limb", []).size() == 3
	)
	var first_shield_stream: AudioStream = audio.call("_pick_bank_stream", &"sword_shield_impact") as AudioStream
	var second_shield_stream: AudioStream = audio.call("_pick_bank_stream", &"sword_shield_impact") as AudioStream
	var no_immediate_repeat: bool = first_shield_stream != null and second_shield_stream != null and first_shield_stream != second_shield_stream

	print("[FEEDBACK PROBE] gore_setting=", setting_sync_ok, " independent_marker=", independent_marker, " multi_target=", multi_target_ok, " cinematic_hud=", cinematic_hud_ok, " audio_fallback=", audio_fallback_ok, " contextual_banks=", contextual_banks_ok, " no_repeat=", no_immediate_repeat)
	if not setting_sync_ok or not independent_marker or not multi_target_ok or not cinematic_hud_ok or not audio_fallback_ok or not contextual_banks_ok or not no_immediate_repeat:
		failures += 1

	for player: AudioStreamPlayer in audio.sfx_players:
		player.stop()
		player.stream = null
	if audio.music_player != null:
		audio.music_player.stop()
		audio.music_player.stream = null
	confirm_stream = null
	confirm_bank.clear()
	audio.sfx_banks.clear()
	scene.free()
	quit(1 if failures > 0 else 0)
