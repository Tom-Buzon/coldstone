extends SceneTree

const EditorScene = preload("res://world_editor.tscn")
const OUTPUT_PATH := "res://docs/world_editor/asset_catalog_preview.png"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_capture.call_deferred()

func _capture() -> void:
	change_scene_to_packed(EditorScene)
	await scene_changed
	await process_frame
	await process_frame
	var editor := current_scene
	var category := editor.get("library_category") as OptionButton
	category.select(3)
	editor.call("_refresh_library")
	var entries := editor.get("automatic_assets") as Array[Dictionary]
	var chosen: Dictionary = {}
	for entry: Dictionary in entries:
		if String(entry.get("path", "")).ends_with("CommonTree_1.gltf"):
			chosen = entry
			break
	if chosen.is_empty():
		push_error("WORLD_EDITOR_ASSET_PREVIEW_FAILED asset missing")
		quit(2)
		return
	editor.call("_select_asset_brush", chosen)
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("WORLD_EDITOR_ASSET_PREVIEW_OK %s (%s)" % [OUTPUT_PATH, error_string(error)])
	quit(0 if error == OK else 2)
