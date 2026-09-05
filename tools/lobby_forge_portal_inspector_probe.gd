extends SceneTree

const LOBBY_FILENAME := "lobbyy.hoplite.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_error := change_scene_to_file("res://world_editor.tscn")
	if scene_error != OK:
		_fail("scene=%s" % error_string(scene_error))
		return
	await scene_changed
	await process_frame
	await process_frame
	var editor := current_scene
	if editor == null:
		_fail("editor unavailable")
		return
	var save_picker := editor.get("save_picker") as OptionButton
	var lobby_index := _find_save_index(save_picker, LOBBY_FILENAME)
	if lobby_index < 0:
		_fail("lobby save missing from picker")
		return
	save_picker.select(lobby_index)
	editor.call("_load_selected_world")
	await process_frame
	await process_frame
	var document: HopliteWorldDocument = editor.get("document") as HopliteWorldDocument
	if document == null:
		_fail("document unavailable")
		return
	var campaign_portals: Array[Dictionary] = []
	var saved_worlds_anchor: Dictionary = {}
	for raw: Variant in document.entities():
		var entity := raw as Dictionary
		var properties := entity.get("properties", {}) as Dictionary
		match String(properties.get("portal_role", "")):
			"official_campaign":
				campaign_portals.append(entity)
			"saved_worlds_anchor":
				saved_worlds_anchor = entity
	if campaign_portals.size() != 3 or saved_worlds_anchor.is_empty():
		_fail("expected 3 campaigns and one saved-world anchor")
		return
	var campaign := campaign_portals[0]
	editor.call("_set_single_selection", String(campaign.get("id", "")))
	editor.call("_rebuild_inspector")
	await process_frame
	var campaign_text := _inspector_text(editor.get("inspector_content") as Control)
	for required: String in ["PORTAIL DU LOBBY", "Position", "Rotation", "Campagne", "Libelle personnalise"]:
		if not campaign_text.contains(required):
			_fail("campaign inspector missing '%s'" % required)
			return
	var campaign_properties := campaign.get("properties", {}) as Dictionary
	var original_campaign := String(campaign_properties.get("campaign_id", ""))
	var replacement_campaign := "last_flame" if original_campaign != "last_flame" else "grand_siege"
	editor.call("_set_property", campaign, "campaign_id", replacement_campaign)
	if String(campaign_properties.get("campaign_id", "")) != replacement_campaign:
		_fail("campaign reassignment did not update the document")
		return
	editor.call("_set_single_selection", String(saved_worlds_anchor.get("id", "")))
	editor.call("_rebuild_inspector")
	await process_frame
	var anchor_text := _inspector_text(editor.get("inspector_content") as Control)
	for required: String in ["PORTAIL DU LOBBY", "Position", "Rotation", "Portails par rangee", "Espacement horizontal", "Espacement des rangees"]:
		if not anchor_text.contains(required):
			_fail("anchor inspector missing '%s'" % required)
			return
	var anchor_properties := saved_worlds_anchor.get("properties", {}) as Dictionary
	var original_columns := int(anchor_properties.get("portal_columns", 9))
	var replacement_columns := 7 if original_columns != 7 else 8
	editor.call("_set_property", saved_worlds_anchor, "portal_columns", replacement_columns)
	if int(anchor_properties.get("portal_columns", 0)) != replacement_columns:
		_fail("anchor layout setting did not update the document")
		return
	print("LOBBY_FORGE_PORTAL_INSPECTOR_PROBE_OK campaigns=%d campaign_reassigned=%s columns=%d" % [campaign_portals.size(), replacement_campaign, replacement_columns])
	quit(0)


func _find_save_index(picker: OptionButton, filename: String) -> int:
	if picker == null:
		return -1
	for index in picker.item_count:
		if String(picker.get_item_metadata(index)) == filename:
			return index
	return -1


func _inspector_text(root_control: Control) -> String:
	if root_control == null:
		return ""
	var labels: Array[String] = []
	for raw: Node in root_control.find_children("*", "Label", true, false):
		labels.append((raw as Label).text)
	return "\n".join(labels)


func _fail(reason: String) -> void:
	push_error("LOBBY_FORGE_PORTAL_INSPECTOR_PROBE_FAILED %s" % reason)
	quit(1)
