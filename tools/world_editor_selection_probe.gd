extends SceneTree

const SAVE_DIR := "user://hoplite_worlds"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene_error := change_scene_to_file("res://world_editor.tscn")
	_assert(scene_error == OK, "Forge scene must load")
	await process_frame
	await process_frame
	var editor := current_scene
	_assert(editor != null, "Forge editor must be available")
	var document := editor.get("document") as HopliteWorldDocument
	var chapter_id := String(editor.get("active_chapter_id"))
	var first := HopliteWorldDocument.entity("prop", "Multi A", Vector3(2.0, 1.0, 2.0), {"asset_id": "crates", "collision_enabled": true, "collision_shape": "box"})
	var second := HopliteWorldDocument.entity("prop", "Multi B", Vector3(6.0, 1.0, 2.0), {"asset_id": "crates", "collision_enabled": true, "collision_shape": "box"})
	first["chapter"] = chapter_id
	second["chapter"] = chapter_id
	var first_id := document.add_entity(first)
	var second_id := document.add_entity(second)
	editor.call("_rebuild_preview")
	await process_frame
	editor.call("_set_selection", [first_id, second_id], second_id)
	editor.call("_refresh_selection_ui")
	_assert((editor.get("selected_ids") as Array).size() == 2, "multi-selection must preserve both entity IDs")

	editor.call("_translate_selection", Vector3(3.0, 0.0, -1.0))
	await process_frame
	_assert(HopliteWorldDocument.vector3(document.find_entity(first_id).get("position", [])).is_equal_approx(Vector3(5.0, 1.0, 1.0)), "group translation must move first prop")
	_assert(HopliteWorldDocument.vector3(document.find_entity(second_id).get("position", [])).is_equal_approx(Vector3(9.0, 1.0, 1.0)), "group translation must move second prop")

	editor.set("last_mouse_position", Vector2.ZERO)
	editor.call("_begin_rotation", 1)
	editor.call("_update_rotation", Vector2(100.0, 0.0))
	editor.call("_finish_rotation", true)
	await process_frame
	var rotated_a := HopliteWorldDocument.vector3(document.find_entity(first_id).get("position", []))
	var rotated_b := HopliteWorldDocument.vector3(document.find_entity(second_id).get("position", []))
	_assert(rotated_a.is_equal_approx(Vector3(5.0, 1.0, 1.0)) and rotated_b.is_equal_approx(Vector3(9.0, 1.0, 1.0)), "group rotation must preserve every member position")
	_assert(is_equal_approx(HopliteWorldDocument.vector3(document.find_entity(first_id).get("rotation", [])).y, 45.0), "group rotation must rotate each orientation")

	editor.call("_scale_selection", 2.0)
	await process_frame
	var scaled_a := HopliteWorldDocument.vector3(document.find_entity(first_id).get("position", []))
	var scaled_b := HopliteWorldDocument.vector3(document.find_entity(second_id).get("position", []))
	_assert(scaled_a.is_equal_approx(rotated_a) and scaled_b.is_equal_approx(rotated_b), "group scale must preserve every member position")
	_assert(is_equal_approx(scaled_a.distance_to(scaled_b), 4.0), "group scale must preserve spacing between members")
	_assert(HopliteWorldDocument.vector3(document.find_entity(first_id).get("scale", []), Vector3.ONE).is_equal_approx(Vector3.ONE * 2.0), "group scale must scale each prop")

	editor.call("_set_multi_prop_property", "collision_enabled", false)
	await process_frame
	_assert(not bool((document.find_entity(first_id).get("properties", {}) as Dictionary).get("collision_enabled", true)), "multi-property edit must disable first collider")
	_assert(not bool((document.find_entity(second_id).get("properties", {}) as Dictionary).get("collision_enabled", true)), "multi-property edit must disable second collider")

	var selection_ids: Array[String] = [first_id, second_id]
	editor.call("_request_save_selection_as_group")
	await process_frame
	var create_dialog := editor.get("create_group_dialog") as ConfirmationDialog
	var create_name := editor.get("create_group_name_edit") as LineEdit
	var create_kind := editor.get("create_group_kind_label") as Label
	_assert(create_dialog != null and create_dialog.visible, "creating a group must open the naming dialog immediately")
	_assert(create_kind != null and create_kind.text.contains("GROUPE D'OBJETS"), "group creation dialog must identify the object group kind")
	_assert(create_name.size.x >= 300.0 and create_name.size.y >= 24.0, "group naming field must be clearly laid out in the dialog")
	create_name.text = "Remparts"
	editor.call("_save_selection_as_group")
	create_dialog.hide()
	var group_id := String(editor.get("active_editor_group_id"))
	_assert(not group_id.is_empty(), "selection group must be created")
	_assert(String(document.find_editor_group(group_id).get("name", "")) == "Remparts", "the requested group name must be stored directly")
	_assert(String(document.find_editor_group(group_id).get("kind", "")) == "object", "prop selections must create an object group")
	editor.call("_set_single_selection", first_id)
	editor.call("_rebuild_inspector")
	await process_frame
	var membership_button := _find_button_with_text(editor.get("inspector_content") as Node, "Remparts")
	_assert(membership_button != null, "a single member inspector must show its named group at the top")
	_assert(membership_button.size.x >= 250.0, "group membership must be presented as a prominent full-width inspector action")
	membership_button.pressed.emit()
	await process_frame
	_assert((editor.get("selected_ids") as Array).size() == 2, "clicking the inspector group membership must select the whole group")
	var update_button := _find_button_with_text(editor, "METTRE À JOUR")
	_assert(update_button != null, "the scene panel must expose an explicit group update action")
	var third := HopliteWorldDocument.entity("prop", "Multi C", Vector3(12.0, 1.0, 2.0), {"asset_id": "crates"})
	third["chapter"] = chapter_id
	var third_id := document.add_entity(third)
	editor.call("_set_selection", [first_id, third_id], third_id)
	editor.call("_update_active_editor_group_from_selection")
	var updated_members := document.find_editor_group(group_id).get("entity_ids", []) as Array
	_assert(updated_members.size() == 2 and updated_members.has(first_id) and updated_members.has(third_id) and not updated_members.has(second_id), "updating a group must replace its composition with the current selection")
	editor.call("_select_active_editor_group")
	_assert((editor.get("selected_ids") as Array).has(third_id) and not (editor.get("selected_ids") as Array).has(second_id), "reopening an updated group must recall its new composition")
	editor.call("_set_selection", [first_id, second_id], second_id)
	editor.call("_update_active_editor_group_from_selection")
	var decoded := HopliteWorldDocument.from_json(document.to_json())
	_assert(decoded != null and int(decoded.data.get("version", 0)) == HopliteWorldDocument.CURRENT_VERSION, "selection group document must migrate to the current version")
	_assert((decoded.find_editor_group(group_id).get("entity_ids", []) as Array).size() == 2 and String(decoded.find_editor_group(group_id).get("kind", "")) == "object", "typed selection group must survive JSON round-trip")
	document.remove_entity(first_id)
	_assert((document.find_editor_group(group_id).get("entity_ids", []) as Array).size() == 1, "deleting an entity must clean its group membership")
	document.remove_entity(second_id)
	_assert(document.find_editor_group(group_id).is_empty(), "empty selection groups must be removed")

	var enemy_a := HopliteWorldDocument.entity("enemy_group", "Escouade A", Vector3.ZERO, {"group_id": "squad_a", "count": 1, "spawn_condition": "trigger"})
	var enemy_b := HopliteWorldDocument.entity("enemy_group", "Escouade B", Vector3.ZERO, {"group_id": "squad_b", "count": 1, "spawn_condition": "trigger"})
	var reference_source := HopliteWorldDocument.entity("trigger", "Source des références", Vector3.ZERO, {})
	enemy_a["chapter"] = chapter_id
	enemy_b["chapter"] = chapter_id
	reference_source["chapter"] = chapter_id
	var enemy_a_id := document.add_entity(enemy_a)
	var enemy_b_id := document.add_entity(enemy_b)
	var source_id := document.add_entity(reference_source)
	var enemy_editor_group_id := document.create_editor_group("Défense coordonnée", [enemy_a_id, enemy_b_id], "enemy")
	_assert(not enemy_editor_group_id.is_empty(), "enemy selections must create a distinct enemy group")
	editor.call("_refresh_group_picker")
	var enemy_picker_label := ""
	for index in range((editor.get("group_picker") as OptionButton).item_count):
		var editor_group_picker := editor.get("group_picker") as OptionButton
		if String(editor_group_picker.get_item_metadata(index)) == enemy_editor_group_id:
			enemy_picker_label = editor_group_picker.get_item_text(index)
			break
	_assert(enemy_picker_label.contains("ENNEMIS"), "enemy groups must be visually distinguished in the scene picker")
	var captured_keys := {
		"protect": "protect_target",
		"spawn_dead": "spawn_dead_group",
		"trigger_condition_dead": "condition_group",
		"action_group": "action_target",
		"deployment_stop_death": "deployment_stop_group",
	}
	for capture_mode: String in captured_keys:
		editor.set("capture_source_id", source_id)
		editor.set("capture_mode", capture_mode)
		_assert(bool(editor.call("_assign_captured_reference", document.find_entity(enemy_a_id))), "capture mode %s must accept an enemy group member" % capture_mode)
		var source_properties := document.find_entity(source_id).get("properties", {}) as Dictionary
		_assert(String(source_properties.get(String(captured_keys[capture_mode]), "")) == enemy_editor_group_id, "capture mode %s must store the composite enemy group reference" % capture_mode)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var filename := "__forge_delete_probe_%d.hoplite.json" % Time.get_ticks_usec()
	var save_path := SAVE_DIR.path_join(filename)
	for path: String in [save_path, save_path + ".bak", save_path + ".tmp"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		_assert(file != null, "probe save file must be writable")
		file.store_string(document.to_json())
		file.close()
	editor.call("_refresh_save_picker")
	var picker := editor.get("save_picker") as OptionButton
	for index in range(picker.item_count):
		if String(picker.get_item_metadata(index)) == filename:
			picker.select(index)
			break
	_assert(picker.selected >= 0 and String(picker.get_item_metadata(picker.selected)) == filename, "probe save must appear in picker")
	editor.set("current_save_filename", filename)
	editor.call("_delete_selected_world_save")
	_assert(not FileAccess.file_exists(save_path), "save deletion must remove the main world file")
	_assert(not FileAccess.file_exists(save_path + ".bak") and not FileAccess.file_exists(save_path + ".tmp"), "save deletion must clean backup and temporary files")
	_assert(String(editor.get("current_save_filename")).is_empty(), "deleting the open save must detach the in-memory document")
	print("WORLD_EDITOR_SELECTION_OK")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("WORLD_EDITOR_SELECTION_FAILED: " + message)
	quit(1)

func _find_button_with_text(root: Node, needle: String) -> Button:
	if root is Button and (root as Button).text.contains(needle):
		return root as Button
	for child: Node in root.get_children():
		var found := _find_button_with_text(child, needle)
		if found != null:
			return found
	return null
