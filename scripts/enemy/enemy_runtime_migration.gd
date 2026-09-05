extends RefCounted
class_name HopliteEnemyRuntimeMigration

const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")

## Central rollout catalog for the progressive Enemy V1 -> Enemy V2 migration.
##
## This file only decides which runtime generation owns an archetype. It does
## not contain combat, AI, animation, presentation or simulation logic. Keeping
## the switch here makes every family migration explicit and reversible.

enum RuntimeGeneration {
	LEGACY_V1,
	MODULAR_V2,
}

enum MigrationStage {
	LEGACY_ONLY,
	CONTRACT_READY,
	SHADOW_VALIDATED,
	MIGRATED,
}

const FAMILY_UNCLASSIFIED: StringName = &"unclassified"
const FAMILY_NOT_ELIGIBLE: StringName = &"not_eligible"
const FAMILY_LIGHT_MELEE: StringName = &"light_melee"
const FAMILY_SPEAR_FORMATION: StringName = &"spear_formation"
const FAMILY_RANGED: StringName = &"ranged"
const FAMILY_HEAVY_MELEE: StringName = &"heavy_melee"
const FAMILY_COMMAND: StringName = &"command"
const FAMILY_BOSS_HUMANOID: StringName = &"boss_humanoid"
const FAMILY_GIANT_HUMANOID: StringName = &"giant_humanoid"

const FAMILY_ORDER: Array[StringName] = [
	FAMILY_LIGHT_MELEE,
	FAMILY_SPEAR_FORMATION,
	FAMILY_RANGED,
	FAMILY_HEAVY_MELEE,
	FAMILY_COMMAND,
	FAMILY_BOSS_HUMANOID,
	FAMILY_GIANT_HUMANOID,
]

# Explicit membership is intentional. A newly-authored archetype must be
# classified before it can enter the V2 rollout; unknown IDs always stay V1.
const ARCHETYPE_FAMILIES: Dictionary = {
	&"nathenian1": FAMILY_LIGHT_MELEE,
	&"nsbire1": FAMILY_LIGHT_MELEE,

	&"ngeneral": FAMILY_SPEAR_FORMATION,
	&"ngeneral_veteran": FAMILY_SPEAR_FORMATION,

	&"nsbire2": FAMILY_RANGED,

	&"nathenian2": FAMILY_HEAVY_MELEE,
	&"nathenian2_soldier": FAMILY_HEAVY_MELEE,
	&"bronze_colossus": FAMILY_HEAVY_MELEE,
	&"boss_colossus": FAMILY_HEAVY_MELEE,
	&"boss_bronze": FAMILY_HEAVY_MELEE,

	&"ncenturion": FAMILY_COMMAND,

	&"nfull_armor": FAMILY_BOSS_HUMANOID,

	&"giant_novice": FAMILY_GIANT_HUMANOID,
	&"giant_standard": FAMILY_GIANT_HUMANOID,
	&"giant_veteran": FAMILY_GIANT_HUMANOID,
}

# Rollout authority. Changing a family to MIGRATED is deliberately not enough
# on its own: the factory also rejects V2 until a V2 constructor is installed.
# That two-key gate prevents an accidental production switch while assets and
# behavior are still being validated in the lab.
const FAMILY_STAGES: Dictionary = {
	FAMILY_LIGHT_MELEE: MigrationStage.LEGACY_ONLY,
	# Assets and component contracts exist, but production still resolves to V1
	# until the shadow, gameplay-parity and performance gates all pass.
	FAMILY_SPEAR_FORMATION: MigrationStage.CONTRACT_READY,
	FAMILY_RANGED: MigrationStage.LEGACY_ONLY,
	FAMILY_HEAVY_MELEE: MigrationStage.LEGACY_ONLY,
	FAMILY_COMMAND: MigrationStage.LEGACY_ONLY,
	FAMILY_BOSS_HUMANOID: MigrationStage.LEGACY_ONLY,
	FAMILY_GIANT_HUMANOID: MigrationStage.LEGACY_ONLY,
}


static func has_explicit_family(archetype: StringName) -> bool:
	return ARCHETYPE_FAMILIES.has(archetype)


static func is_migration_eligible(archetype: StringName) -> bool:
	return Archetypes.asset_origin(archetype) == Archetypes.ASSET_ORIGIN_3DGEN


static func family_for(archetype: StringName) -> StringName:
	if ARCHETYPE_FAMILIES.has(archetype):
		return StringName(ARCHETYPE_FAMILIES[archetype])
	if not is_migration_eligible(archetype):
		return FAMILY_NOT_ELIGIBLE
	return FAMILY_UNCLASSIFIED


static func stage_for_family(family: StringName) -> MigrationStage:
	return int(FAMILY_STAGES.get(family, MigrationStage.LEGACY_ONLY))


static func stage_for(archetype: StringName) -> MigrationStage:
	return stage_for_family(family_for(archetype))


static func resolved_generation_for(archetype: StringName) -> RuntimeGeneration:
	if stage_for(archetype) == MigrationStage.MIGRATED:
		return RuntimeGeneration.MODULAR_V2
	return RuntimeGeneration.LEGACY_V1


static func route_for(archetype: StringName) -> Dictionary:
	var asset_origin := Archetypes.asset_origin(archetype)
	var family := family_for(archetype)
	var stage := stage_for_family(family)
	var generation := resolved_generation_for(archetype)
	return {
		"archetype": archetype,
		"asset_origin": asset_origin,
		"migration_eligible": is_migration_eligible(archetype),
		"family": family,
		"stage": stage,
		"stage_id": migration_stage_id(stage),
		"generation": generation,
		"generation_id": runtime_generation_id(generation),
	}


static func known_families() -> Array[StringName]:
	return FAMILY_ORDER.duplicate()


static func runtime_generation_id(generation: RuntimeGeneration) -> StringName:
	match generation:
		RuntimeGeneration.MODULAR_V2:
			return &"modular_v2"
		_:
			return &"legacy_v1"


static func migration_stage_id(stage: MigrationStage) -> StringName:
	match stage:
		MigrationStage.CONTRACT_READY:
			return &"contract_ready"
		MigrationStage.SHADOW_VALIDATED:
			return &"shadow_validated"
		MigrationStage.MIGRATED:
			return &"migrated"
		_:
			return &"legacy_only"
