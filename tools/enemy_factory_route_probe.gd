extends SceneTree

const FACTORY_PATH := "res://scripts/enemy/enemy_factory.gd"
const RUNTIME_ROOT := "res://scripts"
const ENEMY_SCRIPT_REFERENCE := "res://scripts/enemy/athenian_enemy.gd"
const DIRECT_CONSTRUCTION_MARKERS: Array[String] = [
	"EnemyScript.new()",
	"HopliteAthenianEnemy.new()",
]

var failures: Array[String] = []


func _initialize() -> void:
	var runtime_files: Array[String] = []
	_collect_gdscript_files(RUNTIME_ROOT, runtime_files)
	for path: String in runtime_files:
		if path == FACTORY_PATH:
			continue
		var source := FileAccess.get_file_as_string(path)
		if source.contains(ENEMY_SCRIPT_REFERENCE):
			failures.append("runtime enemy script reference outside factory: %s" % path)
		for marker: String in DIRECT_CONSTRUCTION_MARKERS:
			if source.contains(marker):
				failures.append("runtime direct enemy construction '%s': %s" % [marker, path])

	var factory_source := FileAccess.get_file_as_string(FACTORY_PATH)
	_expect(_count_occurrences(factory_source, ENEMY_SCRIPT_REFERENCE) == 1,
		"factory must preload the canonical enemy script exactly once")
	_expect(_count_occurrences(factory_source, "enemy = EnemyScript.new()") == 1,
		"factory must contain exactly one canonical enemy construction point")

	if failures.is_empty():
		print("ENEMY_FACTORY_ROUTE_PROBE PASS: all runtime enemy construction routes through the canonical factory")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY FACTORY ROUTE] " + failure)
	quit(1)


func _collect_gdscript_files(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append("cannot inspect runtime directory: %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_gdscript_files(path, output)
		elif entry.ends_with(".gd"):
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _count_occurrences(source: String, needle: String) -> int:
	var count := 0
	var offset := 0
	while true:
		var found := source.find(needle, offset)
		if found < 0:
			return count
		count += 1
		offset = found + needle.length()
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
