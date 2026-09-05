extends SceneTree

const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const Factory = preload("res://scripts/enemy/enemy_factory.gd")
const Migration = preload("res://scripts/enemy/enemy_runtime_migration.gd")

const EXPECTED_FAMILIES: Array[StringName] = [
	&"light_melee",
	&"spear_formation",
	&"ranged",
	&"heavy_melee",
	&"command",
	&"boss_humanoid",
	&"giant_humanoid",
]

var failures: Array[String] = []


func _initialize() -> void:
	_validate_family_catalog()
	_validate_3dgen_migration_scope()
	_validate_non_3dgen_exclusion()
	_validate_fail_closed_fallback()

	if failures.is_empty():
		print("ENEMY_RUNTIME_MIGRATION_PROBE PASS: Hoplite contract is ready while every production route remains legacy V1")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY RUNTIME MIGRATION] " + failure)
	quit(1)


func _validate_family_catalog() -> void:
	_expect(Migration.known_families() == EXPECTED_FAMILIES, "family order or membership changed")
	for family: StringName in EXPECTED_FAMILIES:
		var expected_stage := Migration.MigrationStage.CONTRACT_READY if family == &"spear_formation" else Migration.MigrationStage.LEGACY_ONLY
		_expect(Migration.stage_for_family(family) == expected_stage,
			"family %s has an unexpected rollout stage" % family)


func _validate_3dgen_migration_scope() -> void:
	var ids := Archetypes.ids_for_asset_origin(Archetypes.ASSET_ORIGIN_3DGEN)
	_expect(ids.size() == 15, "3DGen migration scope must contain fifteen archetypes")
	for archetype: StringName in ids:
		_expect(Migration.has_explicit_family(archetype), "%s has no explicit migration family" % archetype)
		var route := Factory.migration_route_for(archetype)
		_expect(bool(route.get("migration_eligible", false)), "%s must be migration eligible" % archetype)
		_expect(StringName(route.get("asset_origin", &"")) == &"3dgen", "%s lost its 3DGen origin" % archetype)
		_expect(StringName(route.get("family", &"")) != Migration.FAMILY_UNCLASSIFIED,
			"%s resolves to the unclassified family" % archetype)
		var expected_stage := Migration.MigrationStage.CONTRACT_READY if archetype in [&"ngeneral", &"ngeneral_veteran"] else Migration.MigrationStage.LEGACY_ONLY
		_expect(int(route.get("stage", -1)) == expected_stage,
			"%s has an unexpected migration stage" % archetype)
		_expect(int(route.get("generation", -1)) == Migration.RuntimeGeneration.LEGACY_V1,
			"%s no longer resolves to legacy V1" % archetype)
		_expect(StringName(route.get("generation_id", &"")) == &"legacy_v1",
			"%s generation diagnostic id changed" % archetype)


func _validate_non_3dgen_exclusion() -> void:
	for archetype: StringName in Archetypes.all_ids():
		if Archetypes.asset_origin(archetype) == Archetypes.ASSET_ORIGIN_3DGEN:
			continue
		var route := Factory.migration_route_for(archetype)
		_expect(not Migration.has_explicit_family(archetype), "%s must not have a V2 migration family" % archetype)
		_expect(not bool(route.get("migration_eligible", true)), "%s must stay outside the V2 migration" % archetype)
		_expect(StringName(route.get("family", &"")) == Migration.FAMILY_NOT_ELIGIBLE,
			"%s must resolve to the not-eligible family" % archetype)
		_expect(int(route.get("generation", -1)) == Migration.RuntimeGeneration.LEGACY_V1,
			"%s external model must stay on legacy V1" % archetype)


func _validate_fail_closed_fallback() -> void:
	var unknown := &"future_unclassified_enemy"
	_expect(not Migration.has_explicit_family(unknown), "unknown archetype unexpectedly has an explicit family")
	var route := Factory.migration_route_for(unknown)
	_expect(StringName(route.get("asset_origin", &"")) == Archetypes.ASSET_ORIGIN_UNCLASSIFIED,
		"unknown archetype must keep an unclassified asset origin")
	_expect(StringName(route.get("family", &"")) == Migration.FAMILY_NOT_ELIGIBLE,
		"unknown archetype must stay outside the migration")
	_expect(int(route.get("generation", -1)) == Migration.RuntimeGeneration.LEGACY_V1,
		"unknown archetype must fail closed to legacy V1")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
