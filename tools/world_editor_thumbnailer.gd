extends SceneTree

const EditorScene = preload("res://world_editor.tscn")
const OUTPUT_PATH := "res://docs/world_editor/world_forge.png"
const OBJECT_OUTPUT_PATH := "res://docs/world_editor/world_forge_objects.png"
const GHOST_OUTPUT_PATH := "res://docs/world_editor/world_forge_ghost.png"
const SNAP_OUTPUT_PATH := "res://docs/world_editor/world_forge_ground_snap.png"
const CLEAN_OUTPUT_PATH := "res://docs/world_editor/world_forge_panels_closed.png"
const ROTATION_OUTPUT_PATH := "res://docs/world_editor/world_forge_rotation.png"
const TROOP_OUTPUT_PATH := "res://docs/world_editor/world_forge_troop_patrol.png"
const RESERVE_OUTPUT_PATH := "res://docs/world_editor/world_forge_troop_reserve.png"
const DOOR_OUTPUT_PATH := "res://docs/world_editor/world_forge_door.png"
const CHAPTER_OUTPUT_PATH := "res://docs/world_editor/world_forge_chapter.png"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	_capture.call_deferred()

func _capture() -> void:
	change_scene_to_packed(EditorScene)
	await scene_changed
	await process_frame
	await process_frame
	await process_frame
	var texture := root.get_texture()
	if texture == null:
		push_error("WORLD_EDITOR_CAPTURE_FAILED viewport unavailable")
		quit(2)
		return
	var image := texture.get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [OUTPUT_PATH, error_string(error)])
	var category := current_scene.get("library_category") as OptionButton
	var document: HopliteWorldDocument = current_scene.get("document") as HopliteWorldDocument
	category.select(5)
	current_scene.call("_refresh_library")
	var gate := document.find_by_name("Porte nord de l'agora")
	current_scene.set("selected_id", String(gate.get("id", "")))
	current_scene.call("_rebuild_inspector")
	current_scene.call("_focus_selected")
	await process_frame
	await process_frame
	var door_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(DOOR_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [DOOR_OUTPUT_PATH, error_string(door_error)])
	var chapter_picker := current_scene.get("chapter_picker") as OptionButton
	if chapter_picker.item_count > 1:
		chapter_picker.select(1)
		current_scene.call("_on_chapter_selected", 1)
		await process_frame
		await process_frame
	var chapter_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CHAPTER_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [CHAPTER_OUTPUT_PATH, error_string(chapter_error)])
	chapter_picker.select(0)
	current_scene.call("_on_chapter_selected", 0)
	await process_frame
	var center := root.get_visible_rect().size * 0.5
	current_scene.set("last_mouse_position", center)
	current_scene.call("_begin_rotation", 1)
	current_scene.call("_update_rotation", center + Vector2(80.0, 0.0))
	await process_frame
	var rotation_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(ROTATION_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [ROTATION_OUTPUT_PATH, error_string(rotation_error)])
	current_scene.call("_finish_rotation", false)
	await process_frame
	category.select(3)
	current_scene.call("_refresh_library")
	var support_floor: Dictionary = {}
	for raw: Variant in document.entities():
		var entity := raw as Dictionary
		var properties := entity.get("properties", {}) as Dictionary
		if support_floor.is_empty() and String(entity.get("type", "")) == "surface" and String(properties.get("shape", "")) == "floor":
			support_floor = entity
		if String(entity.get("type", "")) == "prop":
			current_scene.set("selected_id", String(entity.get("id", "")))
	current_scene.call("_set_tool_mode", "select")
	current_scene.call("_rebuild_inspector")
	current_scene.call("_update_selection_marker")
	await process_frame
	await process_frame
	var object_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OBJECT_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [OBJECT_OUTPUT_PATH, error_string(object_error)])
	current_scene.call("_update_ground_snap_marker", support_floor)
	await process_frame
	var snap_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SNAP_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [SNAP_OUTPUT_PATH, error_string(snap_error)])
	current_scene.call("_update_ground_snap_marker", {})
	var guard := document.find_by_name("Garde de l'agora")
	if not guard.is_empty():
		current_scene.set("selected_id", String(guard.get("id", "")))
		current_scene.call("_rebuild_inspector")
		current_scene.call("_focus_selected")
		current_scene.call("_begin_patrol_mapping", guard)
		await process_frame
		await process_frame
		var inspector_content := current_scene.get("inspector_content") as VBoxContainer
		var inspector_scroll := inspector_content.get_parent() as ScrollContainer
		inspector_scroll.scroll_vertical = 395
		await process_frame
	var troop_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(TROOP_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [TROOP_OUTPUT_PATH, error_string(troop_error)])
	current_scene.call("_finish_capture_mode")
	var reserve := HopliteWorldDocument.entity("enemy_group", "Reserve des remparts", Vector3(4.0, 0.1, 3.0), {"group_id": "reserve_remparts", "archetype": "ngeneral", "count": 30, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "phalanx", "spawn_condition": "start", "deployment_mode": "reserve", "initial_active": 10, "reinforce_threshold": 7, "reinforce_amount": 3})
	var reserve_id := document.add_entity(reserve)
	current_scene.set("selected_id", reserve_id)
	current_scene.call("_rebuild_preview")
	current_scene.call("_focus_selected")
	await process_frame
	await process_frame
	var reserve_inspector_content := current_scene.get("inspector_content") as VBoxContainer
	var reserve_inspector_scroll := reserve_inspector_content.get_parent() as ScrollContainer
	reserve_inspector_scroll.scroll_vertical = 430
	await process_frame
	var reserve_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(RESERVE_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [RESERVE_OUTPUT_PATH, error_string(reserve_error)])
	current_scene.call("_set_ghost_mode", true)
	current_scene.call("_focus_selected")
	await process_frame
	await process_frame
	var ghost_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(GHOST_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [GHOST_OUTPUT_PATH, error_string(ghost_error)])
	current_scene.call("_toggle_left_panel")
	current_scene.call("_toggle_right_panel")
	await process_frame
	var clean_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CLEAN_OUTPUT_PATH))
	print("WORLD_EDITOR_CAPTURE %s (%s)" % [CLEAN_OUTPUT_PATH, error_string(clean_error)])
	quit(0 if error == OK and door_error == OK and chapter_error == OK and rotation_error == OK and object_error == OK and snap_error == OK and troop_error == OK and reserve_error == OK and ghost_error == OK and clean_error == OK else 2)
