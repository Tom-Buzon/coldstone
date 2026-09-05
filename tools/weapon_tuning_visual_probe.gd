extends SceneTree

const LabScene = preload("res://combat_lab.tscn")
const OUTPUT := "res://docs/weapon_tuning_settings_probe.png"


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_capture")


func _capture() -> void:
	change_scene_to_packed(LabScene)
	await scene_changed
	await process_frame
	await process_frame
	var settings := current_scene.get_node_or_null("Settings") as HopliteAudioSettings
	assert(settings != null, "Settings node unavailable")
	settings.set_open(true)
	for index: int in range(settings.tabs.get_tab_count()):
		if settings.tabs.get_tab_control(index).name == "ARMES":
			settings.tabs.current_tab = index
			break
	settings.weapon_option.select(3)
	settings.call("_on_weapon_selected", 3)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	assert(error == OK, "Could not save weapon settings preview")
	print("[WEAPON TUNING VISUAL PROBE] PASS — ", OUTPUT)
	quit(0)
