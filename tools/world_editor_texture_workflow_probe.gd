extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var error := change_scene_to_file("res://world_editor.tscn")
	if error != OK:
		_fail("scene=%d" % error)
		return
	await process_frame
	await process_frame
	var editor := current_scene
	if editor == null:
		_fail("editor unavailable")
		return
	var document: HopliteWorldDocument = editor.get("document") as HopliteWorldDocument
	var terrain: Dictionary = {}
	for raw: Variant in document.entities():
		var candidate := raw as Dictionary
		if String(candidate.get("type", "")) == "terrain":
			terrain = candidate
			break
	if terrain.is_empty():
		editor.call("_create_terrain_preset", "flat", "Texture probe", "mediterranean_grass", 0.0)
		await process_frame
		terrain = document.find_entity(String(editor.get("selected_id")))
	if terrain.is_empty():
		_fail("terrain unavailable")
		return
	var properties := terrain.get("properties", {}) as Dictionary
	var weights_before_base := (properties.get("material_weights", []) as Array).duplicate()
	editor.call("_set_terrain_base_material", terrain, "sandstone_floor")
	await process_frame
	if String(properties.get("material", "")) != "sandstone_floor" or properties.get("material_weights", []) != weights_before_base:
		_fail("global base texture modified local paint")
		return
	var category := editor.get("library_category") as OptionButton
	category.select(2)
	editor.call("_refresh_library")
	var painted_styles := ["mediterranean_grass", "rough_stone", "fortress", "poly_mud_leaves", "cool_marble_floor"]
	for style: String in painted_styles:
		editor.call("_select_material", style)
		editor.call("_apply_terrain_stamp", terrain, Vector3.ZERO)
		await process_frame
		if category.selected != 2 or String(editor.get("tool_mode")) != "terrain" or String(editor.get("terrain_tool")) != "paint":
			_fail("texture tab did not retain its active terrain brush for %s" % style)
			return
	var palette := properties.get("material_palette", []) as Array
	var weights := properties.get("material_weights", []) as Array
	var resolution := int(properties.get("resolution", 0))
	var center_coordinate := floori(float(resolution) * 0.5)
	var center_index := center_coordinate * resolution + center_coordinate
	for style: String in painted_styles:
		var channel := palette.find(style)
		if channel < 0 or float(weights[center_index * palette.size() + channel]) <= 0.0:
			_fail("additional texture erased or failed to preserve %s" % style)
			return
	category.select(0)
	editor.call("_refresh_library")
	editor.call("_set_terrain_tool", "raise")
	if category.selected != 0 or String(editor.get("tool_mode")) != "terrain" or String(editor.get("terrain_tool")) != "raise":
		_fail("terrain modeling brush is unavailable")
		return
	print("WORLD_EDITOR_TEXTURE_WORKFLOW_OK styles=%d palette=%d" % [painted_styles.size(), palette.size()])
	quit(0)

func _fail(message: String) -> void:
	push_error("WORLD_EDITOR_TEXTURE_WORKFLOW_FAILED: " + message)
	quit(1)
