extends RefCounted
class_name HopliteAnimationWorkbenchBindings

const GENERATED_PATH := "res://assets/animations/generated/runtime_bindings.json"

static var _loaded: bool = false
static var _catalog: Dictionary = {}


static func binding_for(archetype_id: StringName, runtime_key: StringName, default_path: String) -> Dictionary:
	_ensure_loaded()
	var result := {
		"source_path": default_path,
		"source_clip": StringName(),
		"origin": &"default",
	}
	var global_bindings: Dictionary = _catalog.get("global", {})
	if global_bindings.has(String(runtime_key)):
		_apply_candidate(result, global_bindings[String(runtime_key)], &"workbench_global")
	var archetype_bindings: Dictionary = _catalog.get("archetypes", {})
	var per_archetype: Dictionary = archetype_bindings.get(String(archetype_id), {})
	if per_archetype.has(String(runtime_key)):
		_apply_candidate(result, per_archetype[String(runtime_key)], &"workbench_archetype")
	return result


static func reset_cache_for_tests() -> void:
	_loaded = false
	_catalog.clear()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_catalog = {"global": {}, "archetypes": {}}
	if not FileAccess.file_exists(GENERATED_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GENERATED_PATH))
	if not parsed is Dictionary:
		push_warning("[ANIMATION WORKBENCH] Generated runtime bindings are not valid JSON")
		return
	var data: Dictionary = parsed
	if int(data.get("schema_version", 0)) != 1:
		push_warning("[ANIMATION WORKBENCH] Unsupported runtime binding schema")
		return
	_catalog = data


static func _apply_candidate(result: Dictionary, raw_candidate: Variant, origin: StringName) -> void:
	if not raw_candidate is Dictionary:
		return
	var candidate: Dictionary = raw_candidate
	var source_path := String(candidate.get("source_path", ""))
	if source_path.is_empty():
		return
	if not ResourceLoader.exists(source_path) and not FileAccess.file_exists(source_path):
		push_warning("[ANIMATION WORKBENCH] Ignoring missing override source: " + source_path)
		return
	result["source_path"] = source_path
	result["source_clip"] = StringName(candidate.get("source_clip", ""))
	result["origin"] = origin
