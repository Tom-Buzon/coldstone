extends SceneTree

const WorldDocument = preload("res://scripts/world_editor/world_document.gd")

const SOURCE_PATH := "user://hoplite_worlds/champsdebataille.hoplite.json"
const OUTPUT_PATH := "user://hoplite_worlds/champsdebataille_v2_150.hoplite.json"
const OUTPUT_NAME := "champsDeBataille_V2_150"
const V2_ARCHETYPE := "enemy_v2_hoplite"
const V2_VETERAN_ARCHETYPE := "enemy_v2_hoplite_veteran"

const FORMATIONS: Array[Dictionary] = [
	{
		"name": "Phalange V2 — proche gauche — 24",
		"group_id": "stress_v2_near_left_24",
		"position": Vector3(91.0, 0.0, -181.0),
		"rotation_y": 0.0,
	},
	{
		"name": "Phalange V2 — proche droite — 24",
		"group_id": "stress_v2_near_right_24",
		"position": Vector3(102.0, 0.0, -181.0),
		"rotation_y": 0.0,
	},
	{
		"name": "Phalange V2 — moyenne gauche — 24",
		"group_id": "stress_v2_mid_left_24",
		"position": Vector3(75.0, 0.0, -155.0),
		"rotation_y": 0.0,
	},
	{
		"name": "Phalange V2 — moyenne droite — 24",
		"group_id": "stress_v2_mid_right_24",
		"position": Vector3(86.0, 0.0, -155.0),
		"rotation_y": 0.0,
	},
	{
		"name": "Phalange V2 — lointaine gauche — 24",
		"group_id": "stress_v2_far_left_24",
		"position": Vector3(63.0, 0.0, -151.0),
		"rotation_y": 0.0,
	},
	{
		"name": "Phalange V2 — lointaine droite — 24",
		"group_id": "stress_v2_far_right_24",
		"position": Vector3(75.0, 0.0, -139.0),
		"rotation_y": 0.0,
	},
	{
		"name": "Garde V2 — vétérans — 6",
		"group_id": "stress_v2_veteran_guard_6",
		"position": Vector3(96.5, 0.0, -168.0),
		"rotation_y": 0.0,
		"guard": true,
	},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var source := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	if source == null:
		_fail("source world is missing: %s" % SOURCE_PATH)
		return
	var source_document := WorldDocument.from_json(source.get_as_text())
	source.close()
	if source_document == null:
		_fail("source world is not valid JSON")
		return

	var result_data: Dictionary = source_document.data.duplicate(true)
	result_data["name"] = OUTPUT_NAME
	var removed_enemy_count := 0
	var removed_route_ids: Dictionary = {}
	var kept_entities: Array = []
	for raw: Variant in result_data.get("entities", []):
		if not raw is Dictionary:
			continue
		var entity := raw as Dictionary
		if String(entity.get("type", "")) == "enemy_group":
			removed_enemy_count += 1
			var properties := entity.get("properties", {}) as Dictionary
			var route_id := String(properties.get("route_id", ""))
			if not route_id.is_empty():
				removed_route_ids[route_id] = true
			continue
		kept_entities.append(entity)

	# Patrol points dedicated to removed troops are part of those troop setups;
	# keeping them would leave misleading orphan markers in the duplicate.
	var cleaned_entities: Array = []
	var removed_patrol_points := 0
	for raw: Variant in kept_entities:
		var entity := raw as Dictionary
		var properties := entity.get("properties", {}) as Dictionary
		if String(entity.get("type", "")) == "patrol_point" and removed_route_ids.has(String(properties.get("route_id", ""))):
			removed_patrol_points += 1
			continue
		cleaned_entities.append(entity)

	for formation: Dictionary in FORMATIONS:
		var is_guard := bool(formation.get("guard", false))
		var unit_count := 6 if is_guard else 24
		var composition: Array = (
			[{"archetype": V2_VETERAN_ARCHETYPE, "count": 6}]
			if is_guard
			else [
				{"archetype": V2_ARCHETYPE, "count": 18},
				{"archetype": V2_VETERAN_ARCHETYPE, "count": 6},
			]
		)
		var group := WorldDocument.entity("enemy_group", String(formation["name"]), formation["position"] as Vector3, {
			"group_id": String(formation["group_id"]),
			"archetype": V2_VETERAN_ARCHETYPE if is_guard else V2_ARCHETYPE,
			"count": unit_count,
			"composition": composition,
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
			"formation": "line" if is_guard else "phalanx",
			"formation_columns": 8,
			"formation_spacing": 1.20,
			"formation_rank_spacing": 1.05,
			"performance_profile": "auto",
			"v2_animation": "block_idle",
			"v2_combat_lab": true,
			"v2_troop_mode": "" if is_guard else "hoplite_phalanx",
		})
		group["chapter"] = "chapter_1"
		group["rotation"] = [0.0, float(formation["rotation_y"]), 0.0]
		cleaned_entities.append(group)
	result_data["entities"] = cleaned_entities

	# The source currently has no editor groups, but sanitize this data anyway so
	# rerunning the author remains safe if the source acquires groups later.
	var known_entity_ids: Dictionary = {}
	for raw: Variant in cleaned_entities:
		known_entity_ids[String((raw as Dictionary).get("id", ""))] = true
	var cleaned_editor_groups: Array = []
	for raw: Variant in result_data.get("editor_groups", []):
		if not raw is Dictionary:
			continue
		var editor_group := (raw as Dictionary).duplicate(true)
		var member_ids: Array = []
		for raw_id: Variant in editor_group.get("entity_ids", []):
			var entity_id := String(raw_id)
			if known_entity_ids.has(entity_id):
				member_ids.append(entity_id)
		if member_ids.is_empty():
			continue
		editor_group["entity_ids"] = member_ids
		cleaned_editor_groups.append(editor_group)
	result_data["editor_groups"] = cleaned_editor_groups

	var output_document := WorldDocument.new(result_data)
	var report := output_document.validation_report()
	if not bool(report.get("valid", false)):
		_fail("generated world validation failed: %s" % ", ".join(report.get("errors", [])))
		return
	if int(report.get("mob_count", 0)) != 150:
		_fail("generated world has %d soldiers instead of 150" % int(report.get("mob_count", 0)))
		return
	if not _write_atomic(output_document.to_json()):
		return
	print("CHAMPSDEBATAILLE_V2_150_SAVED path=%s removed_groups=%d removed_patrol_points=%d soldiers=%d warnings=%d" % [
		ProjectSettings.globalize_path(OUTPUT_PATH),
		removed_enemy_count,
		removed_patrol_points,
		int(report.get("mob_count", 0)),
		(report.get("warnings", []) as Array).size(),
	])
	quit(0)


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
	push_error("CHAMPSDEBATAILLE_V2_150_FAILED " + message)
	quit(1)
