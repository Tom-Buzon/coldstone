extends RefCounted
class_name HopliteWorldEncounterBudget

const SpawnRequestScript = preload("res://scripts/enemy/enemy_spawn_request.gd")
const PROFILE_AUTO := "auto"
const PROFILE_DETAILED := "detailed"
const PROFILE_CROWD := "crowd"
const AUTO_CROWD_THRESHOLD := SpawnRequestScript.AUTO_CROWD_THRESHOLD

var _entities_by_key: Dictionary = {}
var _keys_by_reference: Dictionary = {}
var _capacities: Dictionary = {}
var _direct_dependencies: Dictionary = {}
var _ancestors: Dictionary = {}
var _planned_populations: Dictionary = {}
var _chapter_peak := 0


func configure(entities: Array[Dictionary], editor_groups: Array = []) -> void:
	_entities_by_key.clear()
	_keys_by_reference.clear()
	_capacities.clear()
	_direct_dependencies.clear()
	_ancestors.clear()
	_planned_populations.clear()
	_chapter_peak = 0
	for index in range(entities.size()):
		var entity := entities[index]
		if String(entity.get("type", "")) != "enemy_group" or not bool(entity.get("enabled", true)):
			continue
		var key := String(entity.get("id", ""))
		if key.is_empty() or _entities_by_key.has(key):
			key = "__enemy_%d" % index
		_entities_by_key[key] = entity
		_capacities[key] = active_capacity(entity)
		_register_reference(key, key)
		_register_reference(String(entity.get("name", "")), key)
		var properties := entity.get("properties", {}) as Dictionary
		_register_reference(String(properties.get("group_id", "")), key)
	for raw_group: Variant in editor_groups:
		if not raw_group is Dictionary:
			continue
		var editor_group := raw_group as Dictionary
		if String(editor_group.get("kind", "object")) != "enemy":
			continue
		var editor_group_id := String(editor_group.get("id", ""))
		var editor_group_name := String(editor_group.get("name", ""))
		for raw_member_id: Variant in editor_group.get("entity_ids", []):
			var member_key := String(raw_member_id)
			if not _entities_by_key.has(member_key):
				continue
			_register_reference(editor_group_id, member_key)
			_register_reference(editor_group_name, member_key)
	_build_dependencies()
	_build_ancestor_sets()
	_build_planned_populations()


func planned_population_for(entity: Dictionary) -> int:
	var key := String(entity.get("properties",{}).get("boss_budget_owner",entity.get("id", "")))
	if _planned_populations.has(key):
		return int(_planned_populations[key])
	var properties := entity.get("properties", {}) as Dictionary
	for reference: String in [String(properties.get("group_id", "")), String(entity.get("name", ""))]:
		var keys := _keys_by_reference.get(reference, []) as Array
		if keys.size() == 1:
			return int(_planned_populations.get(String(keys[0]), active_capacity(entity)))
	return active_capacity(entity)


func chapter_peak_population() -> int:
	return _chapter_peak


static func normalize_profile(value: Variant) -> String:
	return SpawnRequestScript.performance_profile_id(SpawnRequestScript.performance_profile_from_id(value))


static func active_capacity(entity: Dictionary) -> int:
	var properties := entity.get("properties", {}) as Dictionary
	var total := clampi(int(properties.get("count", 0)), 0, 500)
	if properties.get("battlefield_boss",false):
		for role: String in ["phalanx","infantry","archer"]: total += clampi(int(properties.get("boss_guard_"+role,0)),0,48)
	if String(properties.get("deployment_mode", "all")) != "reserve":
		return total
	var initial_active := maxi(1, int(properties.get("initial_active", mini(10, maxi(1, total)))))
	var threshold := maxi(0, int(properties.get("reinforce_threshold", 7)))
	var reinforce_amount := maxi(1, int(properties.get("reinforce_amount", 3)))
	var refill_peak := maxi(0, threshold - 1) + reinforce_amount
	return mini(total, maxi(initial_active, refill_peak))


func _register_reference(reference: String, key: String) -> void:
	if reference.is_empty():
		return
	var keys := _keys_by_reference.get(reference, []) as Array
	if not keys.has(key):
		keys.append(key)
	_keys_by_reference[reference] = keys


func _build_dependencies() -> void:
	for raw_key: Variant in _entities_by_key.keys():
		var key := String(raw_key)
		var entity := _entities_by_key[key] as Dictionary
		var properties := entity.get("properties", {}) as Dictionary
		var dependencies: Array[String] = []
		var fallback := "start" if bool(properties.get("active_on_start", true)) else "trigger"
		if String(properties.get("spawn_condition", fallback)) == "group_dead":
			var reference := String(properties.get("spawn_dead_group", ""))
			for dependency: Variant in _keys_by_reference.get(reference, []):
				var dependency_key := String(dependency)
				if dependency_key != key and not dependencies.has(dependency_key):
					dependencies.append(dependency_key)
		_direct_dependencies[key] = dependencies


func _build_ancestor_sets() -> void:
	for raw_key: Variant in _entities_by_key.keys():
		var key := String(raw_key)
		var result: Dictionary = {}
		var pending := (_direct_dependencies.get(key, []) as Array).duplicate()
		while not pending.is_empty():
			var dependency_key := String(pending.pop_back())
			if dependency_key == key or result.has(dependency_key):
				continue
			result[dependency_key] = true
			for ancestor: Variant in _direct_dependencies.get(dependency_key, []):
				if not result.has(String(ancestor)):
					pending.append(String(ancestor))
		_ancestors[key] = result


func _build_planned_populations() -> void:
	for raw_key: Variant in _entities_by_key.keys():
		var key := String(raw_key)
		var population := 0
		var own_ancestors := _ancestors.get(key, {}) as Dictionary
		for raw_candidate: Variant in _entities_by_key.keys():
			var candidate := String(raw_candidate)
			var candidate_ancestors := _ancestors.get(candidate, {}) as Dictionary
			# Direct and indirect predecessor/successor groups cannot coexist: the
			# runtime only releases the next link once the previous group is dead.
			if own_ancestors.has(candidate) or candidate_ancestors.has(key):
				continue
			population += int(_capacities.get(candidate, 0))
		_planned_populations[key] = population
		_chapter_peak = maxi(_chapter_peak, population)
