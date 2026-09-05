extends SceneTree

const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var ids := Archetypes.all_ids()
	for archetype: StringName in ids:
		var first: Resource = Archetypes.data(archetype)
		var second: Resource = Archetypes.data(archetype)
		_expect(first == second, "%s rebuilt its typed archetype Resource" % archetype)
		_expect(String(first.get("archetype_id")) == String(archetype), "%s lost its typed identity" % archetype)
		_expect(String(first.get("package_path")) == Archetypes.package_path(archetype), "%s package path cache diverged" % archetype)

	var mutable_copy: Dictionary = Archetypes.profile(&"ngeneral")
	mutable_copy["health"] = -1.0
	var pattern: Array = mutable_copy.get("combat_pattern", [])
	if not pattern.is_empty():
		(pattern[0] as Dictionary)["damage_mult"] = -1.0
	var fresh_copy: Dictionary = Archetypes.profile(&"ngeneral")
	_expect(float(fresh_copy.get("health", -1.0)) > 0.0, "legacy profile mutation escaped into the template cache")
	var fresh_pattern: Array = fresh_copy.get("combat_pattern", [])
	_expect(not fresh_pattern.is_empty() and float((fresh_pattern[0] as Dictionary).get("damage_mult", -1.0)) > 0.0, "nested profile mutation escaped into the template cache")

	if failures.is_empty():
		print("ENEMY_ARCHETYPE_CACHE_PROBE PASS: 22 immutable typed resources cached; legacy profiles isolated")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
