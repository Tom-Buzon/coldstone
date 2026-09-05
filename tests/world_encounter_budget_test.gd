extends SceneTree

const BudgetScript = preload("res://scripts/world_editor/world_encounter_budget.gd")
const SpawnRequestScript = preload("res://scripts/enemy/enemy_spawn_request.gd")
const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const ArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_four_simultaneous_phalanxes()
	_test_late_simultaneous_reinforcement()
	_test_non_overlapping_reinforcement()
	_test_explicit_profiles_and_priority_units()
	_test_factory_resolves_before_ready()
	_test_legacy_document_migration()
	if failures.is_empty():
		print("PASS: world encounter budget (6 scenarios)")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _test_four_simultaneous_phalanxes() -> void:
	var groups: Array[Dictionary] = [_group("a", 15), _group("b", 15), _group("c", 15), _group("d", 15)]
	var budget := BudgetScript.new()
	budget.configure(groups)
	_assert_equal(budget.planned_population_for(groups[0]), 60, "four 15-soldier phalanxes must plan a 60-soldier peak")
	_assert_true(_auto_request(60).resolved_mass_battle_mode(false), "60 simultaneous troops must resolve crowd mode before spawn")


func _test_late_simultaneous_reinforcement() -> void:
	var groups: Array[Dictionary] = [_group("initial", 25), _group("reinforcement", 10, "timer")]
	var budget := BudgetScript.new()
	budget.configure(groups)
	_assert_equal(budget.planned_population_for(groups[0]), 35, "a timed reinforcement can coexist with the initial group")
	_assert_true(_auto_request(35).resolved_mass_battle_mode(false), "25 + 10 simultaneous troops must enter crowd mode")


func _test_non_overlapping_reinforcement() -> void:
	var groups: Array[Dictionary] = [_group("first", 25), _group("second", 10, "group_dead", "first")]
	var budget := BudgetScript.new()
	budget.configure(groups)
	_assert_equal(budget.planned_population_for(groups[0]), 25, "a dead-group successor must not overlap its predecessor")
	_assert_equal(budget.planned_population_for(groups[1]), 10, "the successor peak must exclude its dead predecessor")
	_assert_true(not _auto_request(25).resolved_mass_battle_mode(false), "a non-overlapping 25-soldier encounter remains detailed")


func _test_explicit_profiles_and_priority_units() -> void:
	var detailed := SpawnRequestScript.new()
	detailed.has_performance_profile = true
	detailed.performance_profile = SpawnRequestScript.PerformanceProfile.DETAILED
	detailed.planned_simultaneous_population = 100
	_assert_true(not detailed.resolved_mass_battle_mode(false), "detailed profile must override a large encounter")
	var crowd := SpawnRequestScript.new()
	crowd.has_performance_profile = true
	crowd.performance_profile = SpawnRequestScript.PerformanceProfile.CROWD
	_assert_true(crowd.resolved_mass_battle_mode(true), "forced crowd profile must override detail priority")
	_assert_true(not _auto_request(27).resolved_mass_battle_mode(false), "automatic mode must remain detailed below the threshold")
	_assert_true(_auto_request(28).resolved_mass_battle_mode(false), "automatic mode must enter crowd mode at the unchanged threshold of 28")
	_assert_true(not _auto_request(100).resolved_mass_battle_mode(true), "automatic profile must keep elite and boss units detailed")


func _test_factory_resolves_before_ready() -> void:
	var parent := Node3D.new()
	var troop_request := _auto_request(60)
	troop_request.archetype = &"nsbire1"
	var troop := EnemyFactoryScript.spawn_request(parent, troop_request)
	_assert_true(troop != null and troop.mass_battle_mode, "the factory must assign crowd mode to a troop before it enters the tree")
	var elite_request := _auto_request(60)
	elite_request.archetype = &"ngeneral_veteran"
	var elite := EnemyFactoryScript.spawn_request(parent, elite_request)
	_assert_true(elite != null and elite.mass_battle_mode, "the veteran hoplite must use the regular crowd resolution in a large formation")
	var veteran_data := ArchetypesScript.data(&"ngeneral_veteran")
	_assert_true(is_equal_approx(veteran_data.scale, 1.20), "crowd resolution must not alter the veteran's authored scale")
	_assert_true(veteran_data.behavior == &"phalanx_veteran", "crowd resolution must not alter the veteran's behavior")
	_assert_true(veteran_data.package_path == "res://assets/characters/3dgen_demo/hopliteClean1.glb", "the veteran must keep its dedicated clean hoplite model")
	var captain_request := _auto_request(60)
	captain_request.archetype = &"captain"
	var captain := EnemyFactoryScript.spawn_request(parent, captain_request)
	_assert_true(captain != null and not captain.mass_battle_mode, "other priority elites must remain detailed in automatic mode")
	var legacy_request := SpawnRequestScript.new()
	legacy_request.archetype = &"nsbire1"
	legacy_request.mass_battle_mode = true
	var legacy_troop := EnemyFactoryScript.spawn_request(parent, legacy_request)
	_assert_true(legacy_troop != null and legacy_troop.mass_battle_mode, "legacy campaign and Lab requests must keep their direct mass-mode behavior")
	parent.free()


func _test_legacy_document_migration() -> void:
	var legacy := WorldDocumentScript.create_default()
	legacy["version"] = 5
	(legacy["entities"] as Array).append(_group("legacy", 12))
	var document := WorldDocumentScript.new(legacy)
	var properties := (document.entities()[0] as Dictionary).get("properties", {}) as Dictionary
	_assert_equal(properties.get("performance_profile", ""), "auto", "legacy Forge groups must migrate to the automatic profile")
	_assert_equal(int(document.data.get("version", 0)), WorldDocumentScript.CURRENT_VERSION, "the Forge document schema must migrate to the current version")


func _auto_request(population: int) -> RefCounted:
	var request := SpawnRequestScript.new()
	request.has_performance_profile = true
	request.performance_profile = SpawnRequestScript.PerformanceProfile.AUTOMATIC
	request.planned_simultaneous_population = population
	return request


func _group(id: String, count: int, condition: String = "start", predecessor: String = "") -> Dictionary:
	return {
		"id": id,
		"name": id,
		"type": "enemy_group",
		"enabled": true,
		"properties": {
			"group_id": id,
			"count": count,
			"spawn_condition": condition,
			"spawn_dead_group": predecessor,
			"deployment_mode": "all",
		},
	}


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
