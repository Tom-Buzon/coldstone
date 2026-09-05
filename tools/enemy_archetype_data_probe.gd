extends SceneTree

const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")

const EXPECTED_IDS: Array[StringName] = [
	&"swordsman", &"guardian", &"spearman", &"flanker", &"brute",
	&"captain", &"warlord", &"boss_colossus", &"boss_bronze",
	&"nathenian1", &"nsbire1", &"nsbire2", &"nathenian2",
	&"nathenian2_soldier", &"bronze_colossus", &"ncenturion",
	&"ngeneral", &"ngeneral_veteran", &"giant_novice",
	&"giant_standard", &"giant_veteran", &"nfull_armor",
	&"the_wolf_mid", &"the_wolf_veteran",
	&"velociraptor", &"tyrannosaurus",
]

var failures: Array[String] = []


func _initialize() -> void:
	var ids := Archetypes.all_ids()
	_expect(ids == EXPECTED_IDS, "canonical archetype id set/order changed")
	var unique_ids: Dictionary = {}
	for id: StringName in ids:
		unique_ids[id] = true
		_validate_archetype(id)
	_expect(unique_ids.size() == EXPECTED_IDS.size(), "canonical archetype ids are not unique")
	_validate_alias_and_fallback()
	_validate_nested_copy_isolation()

	if failures.is_empty():
		print("ENEMY_ARCHETYPE_DATA_PROBE PASS: 26 typed views match the normalized profile source")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY ARCHETYPE DATA] " + failure)
	quit(1)


func _validate_archetype(id: StringName) -> void:
	var profile := Archetypes.profile(id)
	var data := Archetypes.data(id)
	var label := String(id)
	_expect(data.archetype_id == id, "%s id mismatch" % label)
	_expect(data.asset_origin == Archetypes.asset_origin(id), "%s asset origin mismatch" % label)
	_expect(data.display_name == String(profile.get("display_name", "SWORDSMAN")), "%s display name mismatch" % label)
	_expect(data.role == StringName(profile.get("role", &"standard")), "%s role mismatch" % label)
	_expect(data.rank == StringName(profile.get("rank", &"troop")), "%s rank mismatch" % label)
	_expect(data.weapon == StringName(profile.get("weapon", &"sword")), "%s weapon mismatch" % label)
	_expect(data.defense == StringName(profile.get("defense", &"none")), "%s defense mismatch" % label)
	_expect(data.behavior == StringName(profile.get("behavior", &"aggressive")), "%s behavior mismatch" % label)
	_expect(data.package_path == Archetypes.package_path(id), "%s package mismatch" % label)
	_expect(data.is_giant == Archetypes.is_giant(id), "%s giant flag mismatch" % label)
	_expect(is_equal_approx(data.scale, float(profile.get("scale", 1.0))), "%s scale mismatch" % label)
	_expect(is_equal_approx(data.health, float(profile.get("health", 100.0))), "%s health mismatch" % label)
	_expect(is_equal_approx(data.move_speed, float(profile.get("move_speed", 4.0))), "%s move speed mismatch" % label)
	_expect(is_equal_approx(data.attack_damage, float(profile.get("attack_damage", 14.0))), "%s damage mismatch" % label)
	_expect(is_equal_approx(data.attack_range, float(profile.get("attack_range", 1.7))), "%s attack range mismatch" % label)
	_expect(is_equal_approx(data.aggro_distance, float(profile.get("aggro_distance", 20.0))), "%s aggro mismatch" % label)
	_expect(is_equal_approx(data.procedural_cost, float(profile.get("procedural_cost", 1.0))), "%s cost mismatch" % label)
	_expect(is_equal_approx(data.procedural_weight, float(profile.get("procedural_weight", 1.0))), "%s weight mismatch" % label)
	_expect(data.first_wave == int(profile.get("first_wave", 0)), "%s first wave mismatch" % label)
	_expect(data.is_miniboss_or_boss() == (data.rank == &"miniboss" or data.rank == &"boss"), "%s rank helper mismatch" % label)
	_expect(data.legacy_profile() == profile, "%s legacy snapshot mismatch" % label)

	var mutable_copy := data.legacy_profile()
	mutable_copy["health"] = -999.0
	_expect(data.health >= 0.0, "%s typed snapshot leaked mutable legacy data" % label)
	_expect(data.legacy_profile() != mutable_copy, "%s legacy profile copy is not isolated" % label)


func _validate_alias_and_fallback() -> void:
	var alias_data := Archetypes.data(&"nathenian2_soldier")
	_expect(alias_data.archetype_id == &"nathenian2_soldier", "heavy infantry alias id changed")
	_expect(alias_data.rank == &"troop", "heavy infantry alias rank changed")
	_expect(alias_data.role == &"heavy_infantry", "heavy infantry alias role changed")
	_expect(alias_data.display_name == "FANTASSIN LOURD ATHENIEN", "heavy infantry alias name changed")
	_expect(alias_data.package_path.get_file().begins_with("nathenian2-"), "heavy infantry alias package changed")

	var fallback := Archetypes.data(&"unknown_probe_archetype")
	_expect(fallback.archetype_id == &"unknown_probe_archetype", "unknown fallback lost requested id")
	_expect(fallback.asset_origin == Archetypes.ASSET_ORIGIN_UNCLASSIFIED,
		"unknown fallback inherited a real asset origin")
	var fallback_profile := fallback.legacy_profile()
	var swordsman_profile := Archetypes.profile(&"swordsman")
	fallback_profile.erase("asset_origin")
	swordsman_profile.erase("asset_origin")
	_expect(fallback_profile == swordsman_profile, "unknown fallback no longer uses swordsman gameplay data")
	_expect(fallback.package_path == Archetypes.package_path(&"unknown_probe_archetype"), "unknown fallback package changed")
	_expect(Archetypes.data(&"nathenian1").package_path.get_file().begins_with("nathenian1-"), "nathenian1 package prefix changed")
	_expect(Archetypes.data(&"giant_veteran").package_path.get_file().begins_with("geant1-"), "giant package prefix changed")


func _validate_nested_copy_isolation() -> void:
	var captain := Archetypes.data(&"captain")
	var mutable_copy := captain.legacy_profile()
	var pattern: Array = mutable_copy.get("combat_pattern", [])
	pattern.append(&"probe_mutation")
	mutable_copy["combat_pattern"] = pattern
	_expect(not Array(captain.legacy_profile().get("combat_pattern", [])).has(&"probe_mutation"),
		"nested legacy array mutation leaked into typed snapshot")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
