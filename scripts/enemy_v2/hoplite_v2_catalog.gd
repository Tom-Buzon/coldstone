extends RefCounted
class_name HopliteEnemyV2Catalog

const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const Definition = preload("res://scripts/enemy_v2/enemy_v2_definition.gd")

const SUPPORTED_ARCHETYPES: Array[StringName] = [&"ngeneral", &"ngeneral_veteran", &"archer_v2", &"infantry_v2", &"giant_v2"]
## Forge-only IDs deliberately differ from production archetype IDs. A saved
## laboratory scene therefore cannot silently change generation when the
## production rollout flag eventually moves from CONTRACT_READY to MIGRATED.
const FORGE_HOPLITE_ID: StringName = &"enemy_v2_hoplite"
const FORGE_VETERAN_ID: StringName = &"enemy_v2_hoplite_veteran"
const FORGE_ARCHER_ID: StringName = &"enemy_v2_archer"
const FORGE_INFANTRY_ID: StringName = &"enemy_v2_infantry"
const FORGE_GIANT_ID: StringName = &"enemy_v2_giant"
const FORGE_ARCHETYPES: Dictionary = {
	FORGE_HOPLITE_ID: &"ngeneral",
	FORGE_VETERAN_ID: &"ngeneral_veteran",
	FORGE_ARCHER_ID: &"archer_v2",
	FORGE_INFANTRY_ID: &"infantry_v2",
	FORGE_GIANT_ID: &"giant_v2",
}
const PACKAGE_MANIFEST := "res://assets/characters/enemy_v2/hoplite/hoplite_v2.package.json"
const BODY_SCENE := "res://assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod0_22k_atlas.gltf"
const BODY_LOD_SCENES: Array[String] = [
	"res://assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod1_8k_atlas.gltf",
	"res://assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod2_2k_atlas.gltf",
]
const BODY_LOD_DISTANCES: Array[float] = [20.0, 55.0]
const ANIMATION_LIBRARY := "res://assets/animations/enemy_v2/hoplite/hoplite_v2_animation_library.res"
const STANDARD_GUARD_PROFILE := preload("res://data/combat/guard_profiles/hoplite_v2_standard.tres")
const VETERAN_GUARD_PROFILE := preload("res://data/combat/guard_profiles/hoplite_v2_veteran.tres")

const SEMANTIC_ANIMATIONS: Dictionary = {
	&"idle": &"Idle",
	&"move": &"Jog_Fwd",
	&"sprint": &"Sprint",
	&"death": &"Death01",
	&"spear_thrust": &"spear_thrust",
	&"spear_thrust_low": &"spear_thrust_low",
	&"spear_bayonet_step": &"spear_bayonet_step",
	&"shield_bash": &"shield_bash",
	&"block_idle": &"block_idle",
	&"block_impact": &"block_impact",
}

static var _definitions: Dictionary = {}


static func forge_archetype_ids() -> Array[StringName]:
	return [FORGE_HOPLITE_ID, FORGE_VETERAN_ID, FORGE_ARCHER_ID, FORGE_INFANTRY_ID, FORGE_GIANT_ID]


static func is_forge_archetype(archetype_id: StringName) -> bool:
	return FORGE_ARCHETYPES.has(archetype_id)


static func source_archetype_for(archetype_id: StringName) -> StringName:
	return StringName(FORGE_ARCHETYPES.get(archetype_id, archetype_id))


static func forge_display_name(archetype_id: StringName) -> String:
	var source_id := source_archetype_for(archetype_id)
	if source_id in [&"archer_v2", &"infantry_v2", &"giant_v2"]:
		return "%s — ENEMY V2 (LAB)" % {&"archer_v2": "Archer", &"infantry_v2": "Fantassin", &"giant_v2": "Géant"}[source_id]
	if not supports(source_id):
		return String(archetype_id)
	return "%s — ENEMY V2 (LAB)" % String(Archetypes.profile(source_id).get("display_name", source_id))


static func supports(archetype_id: StringName) -> bool:
	return SUPPORTED_ARCHETYPES.has(archetype_id)


static func definition(archetype_id: StringName) -> HopliteEnemyV2Definition:
	archetype_id = source_archetype_for(archetype_id)
	if not supports(archetype_id):
		return null
	if _definitions.has(archetype_id):
		return _definitions[archetype_id] as HopliteEnemyV2Definition
	if archetype_id == &"giant_v2":
		var giant_definition: HopliteEnemyV2Definition = load("res://scripts/enemy_v2/giant_v2_definition.gd").create()
		_definitions[archetype_id] = giant_definition
		return giant_definition
	if archetype_id in [&"archer_v2", &"infantry_v2"]:
		var result := Definition.new() as HopliteEnemyV2Definition
		result.package_manifest_path = PACKAGE_MANIFEST
		result.body_scene_path = BODY_SCENE
		result.body_lod_scene_paths = PackedStringArray(BODY_LOD_SCENES)
		result.body_lod_distances = PackedFloat32Array(BODY_LOD_DISTANCES)
		result.body_lod_fade_margin = 2.0
		result.guard_profile = STANDARD_GUARD_PROFILE.duplicate(true)
		for key: StringName in [&"idle", &"move", &"sprint", &"death", &"block_idle", &"block_impact"]:
			result.semantic_animations[key] = SEMANTIC_ANIMATIONS[key]
		result.archetype_id = archetype_id
		result.legacy_archetype_id = &""
		result.unit_role = &"archer" if archetype_id == &"archer_v2" else &"infantry"
		result.display_name = "Archer V2" if result.unit_role == &"archer" else "Fantassin V2"
		result.equipment_profile = &"bow" if result.unit_role == &"archer" else &"sword_buckler"
		result.animation_library_path = "res://assets/animations/enemy_v2/hoplite/enemy_v2_roles.res"
		var weapon := "bow" if result.unit_role == &"archer" else "sword"
		result.weapon_script = load("res://scripts/enemy_v2/weapons/%s_v2_weapon.gd" % weapon)
		result.animation_pack_paths = PackedStringArray(["res://assets/animations/enemy_v2/packs/hoplite_common.res", "res://assets/animations/enemy_v2/packs/hoplite_%s.res" % weapon])
		for clip: StringName in ([&"bow_draw"] if weapon == "bow" else [&"sword_cut", &"sword_heavy"]):
			result.semantic_animations[clip] = clip
		result.shield_scale = 0.62
		result.max_health = 65.0 if result.unit_role == &"archer" else 85.0
		result.move_speed = 4.2 if result.unit_role == &"archer" else 5.1
		result.attack_damage = 11.0 if result.unit_role == &"archer" else 14.0
		result.guard_profile.break_resistance = 0.7
		_definitions[archetype_id] = result
		return result
	var legacy_profile := Archetypes.profile(archetype_id)
	var result := Definition.new() as HopliteEnemyV2Definition
	result.archetype_id = archetype_id
	result.legacy_archetype_id = archetype_id
	result.display_name = String(legacy_profile.get("display_name", String(archetype_id)))
	result.package_manifest_path = PACKAGE_MANIFEST
	result.body_scene_path = BODY_SCENE
	result.body_lod_scene_paths = PackedStringArray(BODY_LOD_SCENES)
	result.body_lod_distances = PackedFloat32Array(BODY_LOD_DISTANCES)
	result.body_lod_fade_margin = 2.0
	result.animation_library_path = ANIMATION_LIBRARY
	result.weapon_script = preload("res://scripts/enemy_v2/weapons/spear_v2_weapon.gd")
	result.animation_pack_paths = PackedStringArray(["res://assets/animations/enemy_v2/packs/hoplite_common.res", "res://assets/animations/enemy_v2/packs/hoplite_spear.res"])
	result.equipment_profile = &"hoplite_spear_shield_veteran" if archetype_id == &"ngeneral_veteran" else &"hoplite_spear_shield"
	result.guard_profile = VETERAN_GUARD_PROFILE if archetype_id == &"ngeneral_veteran" else STANDARD_GUARD_PROFILE
	result.semantic_animations = SEMANTIC_ANIMATIONS.duplicate()
	result.visual_scale = float(legacy_profile.get("scale", 1.0))
	result.weapon_scale = float(legacy_profile.get("weapon_scale", 1.0))
	result.shield_scale = float(legacy_profile.get("shield_scale", 1.0))
	result.max_health = float(legacy_profile.get("health", 100.0))
	result.move_speed = float(legacy_profile.get("move_speed", 4.0))
	result.attack_damage = float(legacy_profile.get("attack_damage", 10.0))
	_definitions[archetype_id] = result
	return result
