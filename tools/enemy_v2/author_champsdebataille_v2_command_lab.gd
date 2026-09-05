extends SceneTree

const WorldDocument = preload("res://scripts/world_editor/world_document.gd")

const SOURCE_PATH := "user://hoplite_worlds/champsdebataille_v2_150.hoplite.json"
const OUTPUT_PATH := "user://hoplite_worlds/champsdebataille_v2_commandement_414.hoplite.json"
const OUTPUT_NAME := "champsDeBataille_V2_Commandement_414"
const V2_ARCHETYPE := "enemy_v2_hoplite"
const V2_VETERAN_ARCHETYPE := "enemy_v2_hoplite_veteran"
const PLAYER_CENTER := Vector3(29.0, 0.0, -101.0)
const PHALANX_COUNT := 17
const SOLDIERS_PER_PHALANX := 24
const SKIRMISH_COUNT := 6


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Historical authoring tool must not overwrite the mixed-arms successor.
	if FileAccess.file_exists(OUTPUT_PATH):
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT_PATH))
		if existing is Dictionary and bool(existing.get("settings", {}).get("enemy_v2_combined_arms", false)):
			_fail("Combined-arms map already installed. Use tools/enemy_v2/author_combined_arms_world.py to regenerate it.")
			return
	var source := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	if source == null:
		_fail("source world is missing: %s" % SOURCE_PATH)
		return
	var source_document := WorldDocument.from_json(source.get_as_text())
	source.close()
	if source_document == null:
		_fail("source world is invalid")
		return
	var result_data: Dictionary = source_document.data.duplicate(true)
	result_data["name"] = OUTPUT_NAME
	var settings := result_data.get("settings", {}) as Dictionary
	settings["map_half_extent"] = 110.0
	settings["test_radius"] = 105.0
	settings["mob_warning_limit"] = 500
	settings["enemy_v2_command_lab"] = true
	settings["enemy_v2_expected_population"] = PHALANX_COUNT * SOLDIERS_PER_PHALANX + SKIRMISH_COUNT
	settings["enemy_lod_override"] = {
		"enabled": true,
		"near_distance": 10.0,
		"far_distance": 26.0,
		"cull_distance": 65.0,
		"full_rate_distance": 3.0,
		"medium_animation_hz": 24.0,
		"far_animation_hz": 10.0,
		"shadow_distance": 5.5,
	}
	result_data["settings"] = settings

	var cleaned_entities: Array = []
	for raw: Variant in result_data.get("entities", []):
		if not raw is Dictionary:
			continue
		var entity := raw as Dictionary
		var type := String(entity.get("type", ""))
		if type == "enemy_group":
			continue
		if type == "player_spawn":
			entity["position"] = [PLAYER_CENTER.x, PLAYER_CENTER.y, PLAYER_CENTER.z]
		cleaned_entities.append(entity)

	for index: int in range(PHALANX_COUNT):
		var position := _formation_position(index)
		var group := WorldDocument.entity(
			"enemy_group",
			"Phalange commandement V2 %02d — 24" % (index + 1),
			position,
			_group_properties(index)
		)
		group["chapter"] = "chapter_1"
		group["rotation"] = [0.0, 0.0, 0.0]
		cleaned_entities.append(group)

	var skirmish := WorldDocument.entity(
		"enemy_group",
		"Pression V2 — 6 veterans",
		PLAYER_CENTER + Vector3(0.0, 0.0, 12.0),
		{
			"group_id": "command_lab_pressure_06",
			"archetype": V2_VETERAN_ARCHETYPE,
			"count": SKIRMISH_COUNT,
			"composition": [{"archetype": V2_VETERAN_ARCHETYPE, "count": SKIRMISH_COUNT}],
			"rank": "normal",
			"size_multiplier": 1.0,
			"match_perfect_hitbox": false,
			"behavior": "normal",
			"route_id": "",
			"protect_target": "",
			"spawn_condition": "start",
			"spawn_trigger": "",
			"spawn_dead_group": "",
			"spawn_delay": 0.0,
			"deployment_mode": "all",
			"formation": "line",
			"formation_columns": 3,
			"formation_spacing": 1.25,
			"formation_rank_spacing": 1.10,
			"performance_profile": "auto",
			"v2_animation": "block_idle",
			"v2_combat_lab": true,
			"v2_troop_mode": "hoplite_skirmish",
			"v2_battle_role": "pressure",
			"v2_command_lab": true,
		}
	)
	skirmish["chapter"] = "chapter_1"
	cleaned_entities.append(skirmish)
	result_data["entities"] = cleaned_entities
	result_data["editor_groups"] = []

	var output_document := WorldDocument.new(result_data)
	var report := output_document.validation_report()
	var expected_population := PHALANX_COUNT * SOLDIERS_PER_PHALANX + SKIRMISH_COUNT
	if not bool(report.get("valid", false)):
		_fail("generated world validation failed: %s" % ", ".join(report.get("errors", [])))
		return
	if int(report.get("mob_count", 0)) != expected_population:
		_fail("generated world has %d soldiers instead of %d" % [int(report.get("mob_count", 0)), expected_population])
		return
	if not _write_atomic(output_document.to_json()):
		return
	print("CHAMPSDEBATAILLE_V2_COMMAND_LAB_SAVED path=%s soldiers=%d phalanxes=%d skirmish=%d" % [
		ProjectSettings.globalize_path(OUTPUT_PATH),
		expected_population,
		PHALANX_COUNT,
		SKIRMISH_COUNT,
	])
	quit(0)


func _formation_position(index: int) -> Vector3:
	if index < 4:
		var contact_angle := float(index) * TAU / 4.0
		return PLAYER_CENTER + Vector3(cos(contact_angle), 0.0, sin(contact_angle)) * 18.0
	if index < 8:
		var support_index := index - 4
		var support_angle := float(support_index) * TAU / 4.0
		return PLAYER_CENTER + Vector3(cos(support_angle), 0.0, sin(support_angle)) * 30.0
	var reserve_index := index - 8
	var front_index := reserve_index % 4
	var depth_rank := int(reserve_index / 8)
	var radius := 74.0 + float(depth_rank) * 18.0
	var angle := float(front_index) * TAU / 4.0
	var outward := Vector3(cos(angle), 0.0, sin(angle))
	var tangent := Vector3.UP.cross(outward).normalized()
	var side_band := int(reserve_index / 4) % 2
	var lateral := -7.0 if side_band == 0 else 7.0
	return PLAYER_CENTER + outward * radius + tangent * lateral


func _group_properties(index: int) -> Dictionary:
	return {
		"group_id": "command_lab_phalanx_%02d" % (index + 1),
		"archetype": V2_ARCHETYPE,
		"count": SOLDIERS_PER_PHALANX,
		"composition": [
			{"archetype": V2_ARCHETYPE, "count": 18},
			{"archetype": V2_VETERAN_ARCHETYPE, "count": 6},
		],
		"rank": "normal",
		"size_multiplier": 1.0,
		"match_perfect_hitbox": false,
		"behavior": "normal",
		"route_id": "",
		"protect_target": "",
		"spawn_condition": "start",
		"spawn_trigger": "",
		"spawn_dead_group": "",
		"spawn_delay": 0.0,
		"deployment_mode": "all",
		"formation": "phalanx",
		"formation_columns": 8,
		"formation_spacing": 1.20,
		"formation_rank_spacing": 1.05,
		"performance_profile": "auto",
		"v2_animation": "block_idle",
		"v2_combat_lab": true,
		"v2_troop_mode": "hoplite_phalanx",
		"v2_battle_role": "frontline",
		"v2_command_lab": true,
	}


func _write_atomic(contents: String) -> bool:
	var directory := OUTPUT_PATH.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK:
		_fail("could not create output directory: %s" % error_string(directory_error))
		return false
	var temporary_path := OUTPUT_PATH + ".tmp"
	var backup_path := OUTPUT_PATH + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_fail("could not open temporary output")
		return false
	file.store_string(contents)
	file.flush()
	file.close()
	var global_target := ProjectSettings.globalize_path(OUTPUT_PATH)
	var global_temporary := ProjectSettings.globalize_path(temporary_path)
	var global_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(OUTPUT_PATH):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(global_backup)
		DirAccess.copy_absolute(global_target, global_backup)
		DirAccess.remove_absolute(global_target)
	var rename_error := DirAccess.rename_absolute(global_temporary, global_target)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(global_backup, global_target)
		_fail("atomic rename failed: %s" % error_string(rename_error))
		return false
	return true


func _fail(message: String) -> void:
	push_error("CHAMPSDEBATAILLE_V2_COMMAND_LAB_FAILED " + message)
	quit(1)
