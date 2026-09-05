extends RefCounted
class_name HopliteV2Package

const PACKAGE_PATH := "res://assets/characters/enemy_v2/hoplite/hoplite_v2.package.json"
const SOURCE_MANIFEST_PATH := "res://assets/characters/enemy_v2/hoplite/source_3dgen_manifest.json"

var contract: Dictionary = {}
var source_manifest: Dictionary = {}
static var _default_cache: HopliteV2Package


static func load_default() -> HopliteV2Package:
	if _default_cache != null:
		return _default_cache
	var result := HopliteV2Package.new()
	result.contract = result._read_json(PACKAGE_PATH)
	result.source_manifest = result._read_json(SOURCE_MANIFEST_PATH)
	_default_cache = result
	return result


func validate(require_migration_ready: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if int(contract.get("schema_version", 0)) != 2:
		errors.append("package schema must be 2")
	if String(contract.get("source_kind", "")) != "3dgen":
		errors.append("package source must be 3dgen")
	var body: Dictionary = contract.get("body", {})
	if not ResourceLoader.exists(String(body.get("path", ""))):
		errors.append("body scene is missing")
	var lod_contract: Dictionary = contract.get("lods", {})
	var lod_levels: Array = lod_contract.get("levels", [])
	if lod_levels.size() != 3:
		errors.append("package must expose exactly three body LOD levels")
	for raw_level: Variant in lod_levels:
		var level := raw_level as Dictionary
		if level == null or not ResourceLoader.exists(String(level.get("path", ""))):
			errors.append("body LOD scene is missing")
	var animations: Dictionary = contract.get("animations", {})
	if not ResourceLoader.exists(String(animations.get("library", ""))):
		errors.append("animation library is missing")
	var fragment_contract: Dictionary = contract.get("fragments", {})
	var runtime_paths: Dictionary = fragment_contract.get("runtime_paths", {})
	for raw_zone: Variant in fragment_contract.get("required", []):
		var zone := String(raw_zone)
		var path := String(runtime_paths.get(zone, ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			errors.append("fragment is missing: %s" % zone)
	if require_migration_ready and not bool(contract.get("migration_ready", false)):
		errors.append("package is not approved for production migration")
	return errors


func fragment_definition(zone: StringName) -> Dictionary:
	var source_fragments: Dictionary = source_manifest.get("fragments", {})
	if not source_fragments.has(String(zone)):
		return {}
	var result: Dictionary = (source_fragments[String(zone)] as Dictionary).duplicate(true)
	result["zone"] = zone
	var runtime_paths: Dictionary = (contract.get("fragments", {}) as Dictionary).get("runtime_paths", {})
	result["runtime_path"] = String(runtime_paths.get(String(zone), ""))
	return result


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
