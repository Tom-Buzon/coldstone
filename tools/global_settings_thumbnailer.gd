extends SceneTree

const LabScene = preload("res://combat_lab.tscn")
const OUTPUT_DIR := "res://docs/global_settings"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_packed(LabScene)
	await scene_changed
	await process_frame
	await process_frame
	var settings := current_scene.get_node_or_null("Settings") as HopliteAudioSettings
	if settings == null:
		push_error("[GLOBAL SETTINGS CAPTURE] Settings node unavailable")
		quit(2)
		return
	settings.set_open(true)
	settings.tabs.current_tab = 7
	await process_frame
	await process_frame
	_save_viewport("01_gameplay_remapping")
	settings.tabs.current_tab = 4
	await process_frame
	await process_frame
	_save_viewport("02_atmosphere_templates")
	settings.tabs.current_tab = 2
	settings.lod_enabled_toggle.grab_focus()
	await process_frame
	await process_frame
	_save_viewport("03_enemy_lod")
	settings.tabs.current_tab = 3
	await process_frame
	await process_frame
	_save_viewport("05_weapon_workbench")
	settings.tabs.current_tab = 1
	settings.call("_toggle_sfx_detail")
	await process_frame
	await process_frame
	_save_viewport("04_detailed_sfx")
	settings.set_open(false)
	quit(0)

func _save_viewport(file_name: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		push_error("[GLOBAL SETTINGS CAPTURE] Viewport image unavailable")
		return
	var image := texture.get_image()
	if image == null:
		push_error("[GLOBAL SETTINGS CAPTURE] Renderer returned no viewport image")
		return
	var output_path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	print("[GLOBAL SETTINGS CAPTURE] %s (%s)" % [output_path, error_string(error)])
