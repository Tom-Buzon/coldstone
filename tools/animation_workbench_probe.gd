extends SceneTree

const Bindings = preload("res://scripts/animation/animation_workbench_bindings.gd")
const MANIFEST_PATH := "res://tools/animation_workbench/data/animation_workbench_manifest.json"
const RUNTIME_PATH := "res://assets/animations/generated/runtime_bindings.json"


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var failures := PackedStringArray()
	var manifest := _read_json(MANIFEST_PATH)
	var runtime := _read_json(RUNTIME_PATH)
	_expect(int(manifest.get("schema_version", 0)) == 1, "manifest schema", failures)
	var profiles: Array = manifest.get("archetypes", [])
	var summary: Dictionary = manifest.get("summary", {})
	_expect(int(summary.get("archetype_count", 0)) == 15, "15 current 3DGen archetypes", failures)
	_expect(profiles.size() == 24 and int(summary.get("virtual_profile_count", 0)) == 9, "one common rig and eight weapon profiles", failures)
	var common_profile := _profile_by_id(profiles, "__rig_common__")
	var spear_profile := _profile_by_id(profiles, "__weapon__spear")
	_expect(String(common_profile.get("assignment_scope", "")) == "rig_common" and Array(common_profile.get("target_archetypes", [])).size() == 15, "common rig profile scope", failures)
	_expect(String(spear_profile.get("assignment_scope", "")) == "weapon_pack" and Array(spear_profile.get("actions", [])).size() >= 12, "weapon profile includes common and weapon actions", failures)
	_expect(Array(manifest.get("sources", [])).size() >= 100, "all installed animation sources", failures)
	_expect(int(summary.get("clip_count", 0)) >= 187, "all installed clips", failures)
	_expect(int(summary.get("asset_origin_mismatches", -1)) == 0, "3DGen asset origins are consistent", failures)
	var monitoring: Dictionary = manifest.get("monitoring", {})
	var monitor_rows: Array = monitoring.get("rows", [])
	var monitor_weapons: Array = monitoring.get("weapons", [])
	_expect(monitor_rows.size() == 247, "247 real runtime monitoring rows", failures)
	_expect(monitor_weapons.size() == 8, "eight monitored weapon families", failures)
	for raw_weapon: Variant in monitor_weapons:
		if raw_weapon is Dictionary:
			_expect(not Array((raw_weapon as Dictionary).get("character_ids", [])).is_empty(), "weapon monitoring keeps its character owners", failures)
	var hoplite_thrust := _monitor_row(monitor_rows, "ngeneral", "hoplite_high_thrust")
	_expect(String(hoplite_thrust.get("runtime_truth", "")) == "runtime_layered", "hoplite thrust is reported as a composed runtime action", failures)
	_expect(String(hoplite_thrust.get("runtime_source_path", "")).ends_with("hoplite_animation_library_v4.res"), "hoplite runtime reports the shared baked library", failures)
	_expect(String(hoplite_thrust.get("preview_fidelity", "")) == "approximate_raw_donor_instead_of_shared_bake", "raw hoplite donor is explicitly marked approximate", failures)
	var legacy_signature := _monitor_row(monitor_rows, "nsbire1", "signature_farm_harvest")
	_expect(String(legacy_signature.get("runtime_truth", "")) == "runtime_unreachable", "unreachable legacy signatures are not presented as gameplay actions", failures)
	var roots: Array = manifest.get("source_roots", [])
	_expect(not roots.is_empty() and String((roots[0] as Dictionary).get("path", "")) == "res://assets/animations/source_packs", "new source folder has priority", failures)
	_expect(String(manifest.get("default_new_source_compatibility", "")) == "mixamo", "new packs default to Mixamo", failures)
	_expect(int(runtime.get("schema_version", 0)) == 1, "runtime schema", failures)
	Bindings.reset_cache_for_tests()
	var fallback := Bindings.binding_for(&"nathenian1", &"unknown_probe_key", "res://project.godot")
	_expect(String(fallback.get("source_path", "")) == "res://project.godot", "fallback survives an absent override", failures)
	if failures.is_empty():
		print("[ANIMATION WORKBENCH PROBE] PASS enemies=", summary.get("archetype_count", 0), " profiles=", profiles.size(), " sources=", Array(manifest.get("sources", [])).size(), " clips=", summary.get("clip_count", 0))
		quit(0)
		return
	for failure: String in failures:
		push_error("[ANIMATION WORKBENCH PROBE] " + failure)
	quit(1)


func _expect(condition: bool, label: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(label)


func _profile_by_id(profiles: Array, profile_id: String) -> Dictionary:
	for raw_profile: Variant in profiles:
		if raw_profile is Dictionary and String((raw_profile as Dictionary).get("archetype_id", "")) == profile_id:
			return raw_profile as Dictionary
	return {}


func _monitor_row(rows: Array, archetype_id: String, action_id: String) -> Dictionary:
	for raw_row: Variant in rows:
		if raw_row is Dictionary:
			var row: Dictionary = raw_row
			if String(row.get("archetype_id", "")) == archetype_id and String(row.get("action_id", "")) == action_id:
				return row
	return {}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
