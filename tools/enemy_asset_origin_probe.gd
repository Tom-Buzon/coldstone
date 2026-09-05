extends SceneTree

const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const Migration = preload("res://scripts/enemy/enemy_runtime_migration.gd")

const EXPECTED_3DGEN: Array[StringName] = [
	&"nathenian1",
	&"nsbire1",
	&"nsbire2",
	&"nathenian2",
	&"nathenian2_soldier",
	&"bronze_colossus",
	&"ncenturion",
	&"ngeneral",
	&"ngeneral_veteran",
	&"giant_novice",
	&"giant_standard",
	&"giant_veteran",
	&"nfull_armor",
	&"boss_colossus",
	&"boss_bronze",
]

const EXPECTED_MIXAMO: Array[StringName] = [
	&"swordsman",
	&"guardian",
	&"spearman",
	&"flanker",
	&"brute",
	&"captain",
	&"warlord",
]

const EXPECTED_OTHER: Array[StringName] = [
	&"the_wolf_mid",
	&"the_wolf_veteran",
	&"velociraptor",
	&"tyrannosaurus",
]

var failures: Array[String] = []


func _initialize() -> void:
	_validate_origin(&"3dgen", EXPECTED_3DGEN, true)
	_validate_origin(&"mixamo", EXPECTED_MIXAMO, false)
	_validate_origin(&"other", EXPECTED_OTHER, false)
	_expect(Archetypes.ids_for_asset_origin(&"enemy_v2").is_empty(),
		"Enemy V2 must stay empty until an optimized runtime package is registered")
	_expect(EXPECTED_3DGEN.size() + EXPECTED_MIXAMO.size() + EXPECTED_OTHER.size() == Archetypes.all_ids().size(),
		"asset-origin groups do not cover the canonical archetype catalog exactly")

	if failures.is_empty():
		print("ENEMY_ASSET_ORIGIN_PROBE PASS: 15 3DGen, 7 Mixamo and 4 external archetypes are separated")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY ASSET ORIGIN] " + failure)
	quit(1)


func _validate_origin(origin: StringName, expected_ids: Array[StringName], migration_eligible: bool) -> void:
	_expect(Archetypes.ids_for_asset_origin(origin) == expected_ids,
		"%s archetype membership or order changed" % origin)
	for archetype: StringName in expected_ids:
		_expect(Archetypes.has_explicit_asset_origin(archetype), "%s has no explicit asset origin" % archetype)
		_expect(Archetypes.asset_origin(archetype) == origin, "%s origin mismatch" % archetype)
		_expect(StringName(Archetypes.profile(archetype).get("asset_origin", &"")) == origin,
			"%s legacy profile does not expose its origin" % archetype)
		_expect(Archetypes.data(archetype).asset_origin == origin,
			"%s typed profile does not expose its origin" % archetype)
		_expect(Migration.is_migration_eligible(archetype) == migration_eligible,
			"%s migration eligibility does not match its origin" % archetype)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
