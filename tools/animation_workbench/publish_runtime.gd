extends SceneTree

const SCHEMA_VERSION := 1
const MANIFEST_PATH := "res://tools/animation_workbench/data/animation_workbench_manifest.json"
const OVERRIDES_PATH := "res://tools/animation_workbench/data/workbench_overrides.json"
const RUNTIME_PATH := "res://assets/animations/generated/runtime_bindings.json"
const REPORT_PATH := "res://tools/animation_workbench/data/publish_report.json"


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var manifest := _read_json(MANIFEST_PATH)
	var overrides := _read_json(OVERRIDES_PATH)
	if manifest.is_empty() or overrides.is_empty():
		push_error("[ANIMATION WORKBENCH] Manifest or override file is missing/invalid")
		quit(1)
		return
	if int(manifest.get("schema_version", 0)) != SCHEMA_VERSION or int(overrides.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("[ANIMATION WORKBENCH] Unsupported manifest/override schema")
		quit(1)
		return

	var action_index := _build_action_index(Array(manifest.get("archetypes", [])))
	var archetype_index := _build_archetype_index(Array(manifest.get("archetypes", [])))
	var source_index := _build_source_index(Array(manifest.get("sources", [])))
	var runtime_global: Dictionary = {}
	var runtime_archetypes: Dictionary = {}
	var published: Array[Dictionary] = []
	var pending_bake: Array[Dictionary] = []
	var pending_effective: Dictionary = {}
	var pending_priorities: Dictionary = {}
	var superseded: Array[Dictionary] = []
	var warnings: PackedStringArray = PackedStringArray()
	var errors: PackedStringArray = PackedStringArray()
	var assigned_priorities: Dictionary = {}

	var sorted_bindings: Array = Array(overrides.get("bindings", [])).duplicate(true)
	sorted_bindings.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _scope_priority(String((a as Dictionary).get("scope", "archetype")) if a is Dictionary else "") < _scope_priority(String((b as Dictionary).get("scope", "archetype")) if b is Dictionary else "")
	)
	for raw_binding: Variant in sorted_bindings:
		if not raw_binding is Dictionary:
			errors.append("An override entry is not an object")
			continue
		var binding: Dictionary = raw_binding.duplicate(true)
		if not bool(binding.get("enabled", true)):
			continue
		var archetype_id := String(binding.get("archetype_id", ""))
		var action_id := String(binding.get("action_id", ""))
		var source_path := String(binding.get("source_path", ""))
		var source_clip := String(binding.get("source_clip", ""))
		var scope := String(binding.get("scope", "archetype"))
		var scope_id := String(binding.get("scope_id", ""))
		var action_key := "%s::%s" % [archetype_id, action_id]
		if not action_index.has(action_key):
			errors.append("Unknown action override: %s" % action_key)
			continue
		if not source_index.has(source_path):
			errors.append("Source is absent from the fresh manifest: %s" % source_path)
			continue
		var source: Dictionary = source_index[source_path]
		var clips: Array = source.get("clips", [])
		if source_clip.is_empty() and clips.size() == 1:
			source_clip = String(clips[0].get("name", ""))
		if not _source_has_clip(clips, source_clip):
			errors.append("Clip '%s' was not found in %s" % [source_clip, source_path])
			continue
		if scope not in ["rig_common", "rig_family", "weapon_pack", "archetype"]:
			errors.append("Invalid scope '%s' for %s" % [scope, action_key])
			continue

		var action: Dictionary = action_index[action_key]
		var runtime_key := String(action.get("runtime_key", ""))
		var target_archetypes := _scope_targets(archetype_id, scope, scope_id, archetype_index)
		if target_archetypes.is_empty():
			errors.append("No compatible target was found for %s with scope '%s'" % [action_key, scope])
			continue
		var normalized := {
			"source_path": source_path,
			"source_clip": source_clip,
			"scope": scope,
			"scope_id": scope_id,
			"action_id": action_id,
			"pack_id": String(source.get("pack_id", "")),
			"compatibility": String(source.get("compatibility", "mixamo")),
		}
		if runtime_key.is_empty() or not bool(action.get("runtime_binding_supported", false)):
			normalized["archetype_id"] = archetype_id
			normalized["target_archetypes"] = target_archetypes
			normalized["reason"] = "requires_baked_library_or_future_action_contract"
			var pending_priority := _scope_priority(scope)
			for target_id: String in target_archetypes:
				var pending_key := "%s::%s" % [target_id, action_id]
				var previous_pending_priority := int(pending_priorities.get(pending_key, -1))
				if pending_effective.has(pending_key) and previous_pending_priority == pending_priority and not _same_runtime_source(pending_effective[pending_key], normalized):
					errors.append("Conflicting pending bake override at the same priority for %s" % pending_key)
					continue
				var effective := normalized.duplicate(true)
				effective["target_archetype"] = target_id
				pending_effective[pending_key] = effective
				pending_priorities[pending_key] = pending_priority
			continue

		var priority := _scope_priority(scope)
		var runtime_targets := _runtime_supported_targets(target_archetypes, action_id, runtime_key, action_index)
		if runtime_targets.is_empty():
			errors.append("No target actually consumes runtime key '%s' for %s" % [runtime_key, action_key])
			continue
		for target_id: String in runtime_targets:
			var per_archetype: Dictionary = runtime_archetypes.get(target_id, {})
			var assignment_key := "%s::%s" % [target_id, runtime_key]
			var previous_priority := int(assigned_priorities.get(assignment_key, -1))
			if per_archetype.has(runtime_key) and previous_priority == priority and not _same_runtime_source(per_archetype[runtime_key], normalized):
				errors.append("Conflicting override at the same priority for %s" % assignment_key)
				continue
			if per_archetype.has(runtime_key) and previous_priority < priority:
				superseded.append({"target_archetype": target_id, "runtime_key": runtime_key, "replaced_scope_priority": previous_priority, "winning_scope": scope})
			per_archetype[runtime_key] = normalized
			runtime_archetypes[target_id] = per_archetype
			assigned_priorities[assignment_key] = priority
		normalized["archetype_id"] = archetype_id
		normalized["runtime_key"] = runtime_key
		normalized["target_archetypes"] = runtime_targets
		published.append(normalized)

	var pending_keys := PackedStringArray(pending_effective.keys())
	pending_keys.sort()
	for pending_key: String in pending_keys:
		pending_bake.append(pending_effective[pending_key])

	var report := {
		"schema_version": SCHEMA_VERSION,
		"generated_at_utc": Time.get_datetime_string_from_system(true, true),
		"published": published,
		"pending_bake": pending_bake,
		"superseded": superseded,
		"warnings": Array(warnings),
		"errors": Array(errors),
		"summary": {
			"published": published.size(),
			"pending_bake": pending_bake.size(),
			"superseded": superseded.size(),
			"warnings": warnings.size(),
			"errors": errors.size(),
		},
	}
	_write_json(REPORT_PATH, report)
	if not errors.is_empty():
		for message: String in errors:
			push_error("[ANIMATION WORKBENCH] " + message)
		print("[ANIMATION WORKBENCH] Publication cancelled; previous runtime bindings were preserved")
		quit(1)
		return

	var runtime := {
		"schema_version": SCHEMA_VERSION,
		"generated_at_utc": Time.get_datetime_string_from_system(true, true),
		"global": runtime_global,
		"archetypes": runtime_archetypes,
	}
	var save_error := _write_json(RUNTIME_PATH, runtime)
	if save_error != OK:
		push_error("[ANIMATION WORKBENCH] Runtime publication failed: %s" % error_string(save_error))
		quit(1)
		return
	print("[ANIMATION WORKBENCH] runtime=", RUNTIME_PATH, " published=", published.size(), " pending_bake=", pending_bake.size())
	quit(0)


func _build_action_index(archetypes: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_archetype: Variant in archetypes:
		if not raw_archetype is Dictionary:
			continue
		var archetype: Dictionary = raw_archetype
		var archetype_id := String(archetype.get("archetype_id", ""))
		for raw_action: Variant in Array(archetype.get("actions", [])):
			if raw_action is Dictionary:
				var action: Dictionary = raw_action
				result["%s::%s" % [archetype_id, String(action.get("action_id", ""))]] = action
	return result


func _build_archetype_index(archetypes: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_archetype: Variant in archetypes:
		if raw_archetype is Dictionary and not bool((raw_archetype as Dictionary).get("virtual", false)):
			var archetype: Dictionary = raw_archetype
			result[String(archetype.get("archetype_id", ""))] = archetype
	return result


func _runtime_supported_targets(targets: PackedStringArray, action_id: String, runtime_key: String, action_index: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for target_id: String in targets:
		var target_action_key := "%s::%s" % [target_id, action_id]
		if not action_index.has(target_action_key):
			continue
		var target_action: Dictionary = action_index[target_action_key]
		if bool(target_action.get("runtime_binding_supported", false)) and String(target_action.get("runtime_key", "")) == runtime_key:
			result.append(target_id)
	return result


func _scope_targets(source_archetype_id: String, scope: String, scope_id: String, archetype_index: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	if scope == "rig_common":
		for raw_id: Variant in archetype_index.keys():
			result.append(String(raw_id))
		result.sort()
		return result
	if scope == "archetype":
		var target_id := scope_id if not scope_id.is_empty() else source_archetype_id
		if archetype_index.has(target_id):
			result.append(target_id)
		return result
	var property := "rig_family" if scope == "rig_family" else "weapon_family"
	var expected := scope_id
	if expected.is_empty():
		if not archetype_index.has(source_archetype_id):
			return result
		var source: Dictionary = archetype_index[source_archetype_id]
		expected = String(source.get(property, ""))
	for raw_id: Variant in archetype_index.keys():
		var candidate_id := String(raw_id)
		var candidate: Dictionary = archetype_index[candidate_id]
		if String(candidate.get(property, "")) == expected:
			result.append(candidate_id)
	result.sort()
	return result


func _scope_priority(scope: String) -> int:
	match scope:
		"archetype":
			return 30
		"weapon_pack":
			return 20
		"rig_common", "rig_family":
			return 10
		_:
			return 0


func _build_source_index(sources: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_source: Variant in sources:
		if raw_source is Dictionary:
			var source: Dictionary = raw_source
			result[String(source.get("path", ""))] = source
	return result


func _source_has_clip(clips: Array, clip_name: String) -> bool:
	if clip_name.is_empty():
		return false
	for raw_clip: Variant in clips:
		if raw_clip is Dictionary and String((raw_clip as Dictionary).get("name", "")) == clip_name:
			return true
	return false


func _same_runtime_source(a: Variant, b: Dictionary) -> bool:
	if not a is Dictionary:
		return false
	var left: Dictionary = a
	return String(left.get("source_path", "")) == String(b.get("source_path", "")) and String(left.get("source_clip", "")) == String(b.get("source_clip", ""))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", true) + "\n")
	return OK
