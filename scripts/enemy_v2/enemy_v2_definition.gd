extends Resource
class_name HopliteEnemyV2Definition

## Immutable shared definition. Never store health, cooldowns or current state
## here: the same resource is shared by every actor of this archetype.

@export var archetype_id: StringName
@export var unit_role: StringName = &"phalanx"
@export var display_name: String
@export var legacy_archetype_id: StringName
@export var package_manifest_path: String
@export var body_scene_path: String
@export var body_lod_scene_paths: PackedStringArray = []
@export var body_lod_distances: PackedFloat32Array = []
@export_range(0.0, 20.0, 0.25) var body_lod_fade_margin: float = 2.0
@export var animation_library_path: String
@export var animation_pack_paths: PackedStringArray = []
@export var weapon_script: Script
@export var special_ability_script: Script
@export var equipment_profile: StringName = &"hoplite_spear_shield"
@export var guard_profile: CombatGuardProfile
@export_range(0.1, 3.0, 0.01) var visual_scale: float = 1.0
@export_range(0.1, 3.0, 0.01) var weapon_scale: float = 1.0
@export_range(0.1, 3.0, 0.01) var shield_scale: float = 1.0
@export var semantic_animations: Dictionary = {}
@export var max_health: float = 100.0
@export var move_speed: float = 4.0
@export var attack_damage: float = 10.0


func validate() -> Array[String]:
	var errors: Array[String] = []
	if archetype_id.is_empty():
		errors.append("archetype_id is empty")
	if package_manifest_path.is_empty() or not FileAccess.file_exists(package_manifest_path):
		errors.append("package manifest is missing")
	if body_scene_path.is_empty() or not ResourceLoader.exists(body_scene_path):
		errors.append("body scene is missing")
	if body_lod_scene_paths.size() != body_lod_distances.size():
		errors.append("body LOD paths and distances have different sizes")
	var previous_distance := 0.0
	for index: int in range(body_lod_scene_paths.size()):
		if body_lod_scene_paths[index].is_empty() or not ResourceLoader.exists(body_lod_scene_paths[index]):
			errors.append("body LOD scene is missing: %s" % body_lod_scene_paths[index])
		if body_lod_distances[index] <= previous_distance:
			errors.append("body LOD distances must be strictly increasing")
		previous_distance = body_lod_distances[index]
	if animation_pack_paths.is_empty() and (animation_library_path.is_empty() or not ResourceLoader.exists(animation_library_path)):
		errors.append("animation library is missing")
	for path: String in animation_pack_paths:
		if not ResourceLoader.exists(path): errors.append("animation pack is missing: " + path)
	if guard_profile == null:
		errors.append("guard profile is missing")
	var required: Array[StringName] = [&"idle", &"move", &"sprint", &"death"]
	match unit_role:
		&"phalanx":
			required.append_array([&"spear_thrust", &"spear_thrust_low", &"spear_bayonet_step", &"shield_bash", &"block_idle", &"block_impact"])
		&"archer":
			required.append(&"bow_draw")
		&"infantry":
			required.append_array([&"sword_cut", &"sword_heavy", &"block_idle", &"block_impact"])
		&"giant":
			required.append_array([&"giant_punch", &"giant_swipe", &"giant_slam"])
		_:
			errors.append("unknown unit_role")
	for semantic: StringName in required:
		if not semantic_animations.has(semantic):
			errors.append("semantic animation is missing: %s" % semantic)
	return errors
