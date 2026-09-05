extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var error := change_scene_to_file("res://world_editor.tscn")
	_expect(error == OK, "World Forge scene failed to load")
	if error != OK:
		_finish()
		return
	await process_frame
	await process_frame
	var editor := current_scene
	_expect(editor != null, "World Forge root is unavailable")
	if editor == null:
		_finish()
		return

	var library_category := editor.get("library_category") as OptionButton
	_expect(library_category != null, "character library category selector is unavailable")
	if library_category == null:
		_finish()
		return
	library_category.select(4)
	editor.call("_refresh_library")
	await process_frame

	var section_texts: Array[String] = []
	var library_items := editor.get("library_items") as VBoxContainer
	for child: Node in library_items.get_children():
		if child is Label:
			section_texts.append((child as Label).text)
	_expect(section_texts.has("ENEMY V2 — FORMAT OPTIMISÉ"), "Enemy V2 section is missing")
	_expect(section_texts.has("3DGEN — ROSTER DU JEU / CANDIDATS V2"), "3DGen section is missing")
	_expect(section_texts.has("MIXAMO — ANCIENS MODÈLES DE TEST"), "Mixamo test section is missing")
	_expect(section_texts.has("AUTRES — CRÉATURES / IMPORTS SPÉCIAUX"), "external creature section is missing")

	var options := editor.call("_enemy_archetype_option_data") as Dictionary
	var labels := options.get("labels", []) as Array
	var values := options.get("values", []) as Array
	_expect(values.size() == 28, "Forge character selector must expose 26 production archetypes plus two explicit V2 laboratory entries")
	_expect(_prefix_count(labels, "ENEMY V2 LAB —") == 2, "Forge selector must expose the standard and veteran Hoplite V2 laboratory entries")
	_expect(_prefix_count(labels, "3DGEN —") == 15, "Forge selector must expose thirteen roster entries plus two historical 3DGen-backed IDs")
	_expect(_prefix_count(labels, "MIXAMO —") == 7, "Forge selector must expose the seven actual Mixamo test entries")
	_expect(_prefix_count(labels, "AUTRES —") == 4, "Forge selector must expose four external entries")
	var unique_values: Dictionary = {}
	for value: Variant in values:
		unique_values[String(value)] = true
	_expect(unique_values.size() == values.size(), "Forge character selector contains duplicated archetypes")
	_expect(unique_values.has("enemy_v2_hoplite") and unique_values.has("enemy_v2_hoplite_veteran"), "Forge V2 IDs must stay distinct from V1 production IDs")
	_finish()


func _prefix_count(labels: Array, prefix: String) -> int:
	var count := 0
	for label: Variant in labels:
		if String(label).begins_with(prefix):
			count += 1
	return count


func _finish() -> void:
	if failures.is_empty():
		print("FORGE_ENEMY_ASSET_SECTIONS_PROBE PASS: Enemy V2, 3DGen, Mixamo and external sections are explicit")
		quit(0)
		return
	for failure: String in failures:
		push_error("[FORGE ENEMY ASSET SECTIONS] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
