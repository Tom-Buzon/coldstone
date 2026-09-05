extends RefCounted
class_name HopliteEnemySpawnRequest

const CombatantRegistry = preload("res://scripts/enemy/combatant_registry.gd")
const AUTO_CROWD_THRESHOLD := 28

enum PerformanceProfile {
	AUTOMATIC,
	DETAILED,
	CROWD,
}

# Typed, ephemeral construction data. Runtime Node references make this a
# RefCounted request rather than an Inspector-authored Resource.
var archetype: StringName = &"swordsman"
var position: Vector3 = Vector3.ZERO
var target: Node3D
var combatant_registry: CombatantRegistry

var name_override: String = ""
var has_name_override: bool = false
var ai_enabled: bool = true
# Legacy callers can keep setting this bool directly. Forge encounters opt into
# the profile contract below so the final value is resolved before _ready().
var mass_battle_mode: bool = false
var has_performance_profile: bool = false
var performance_profile: PerformanceProfile = PerformanceProfile.AUTOMATIC
var planned_simultaneous_population: int = 1
var faction: StringName = &"athenian"
var navigation_mode_override: int = -1
var navigation_layers: int = 1

var ai_target_override: Node3D
var has_ai_target_override: bool = false
var battle_player_override: Node3D
var has_battle_player_override: bool = false

var guard_index: int = 0
var scale_multiplier: float = 1.0
var match_perfect_hitbox: bool = false
var has_match_perfect_hitbox_override: bool = false
var giant_traversal_mode: StringName = &"auto"
var giant_capsule_radius_multiplier: float = -1.0
var giant_capsule_height_multiplier: float = -1.0
var giant_walkable_tops: bool = true

var commander: Node3D
var is_miniboss_override: bool = false
var has_is_miniboss_override: bool = false
var package_path: String = ""
var mixamo_model_override: StringName = StringName()


func resolved_mass_battle_mode(detail_priority: bool = false) -> bool:
	if not has_performance_profile:
		return mass_battle_mode
	match performance_profile:
		PerformanceProfile.DETAILED:
			return false
		PerformanceProfile.CROWD:
			return true
		_:
			return planned_simultaneous_population >= AUTO_CROWD_THRESHOLD and not detail_priority


static func performance_profile_from_id(value: Variant) -> PerformanceProfile:
	match String(value):
		"detailed":
			return PerformanceProfile.DETAILED
		"crowd":
			return PerformanceProfile.CROWD
		_:
			return PerformanceProfile.AUTOMATIC


static func performance_profile_id(value: PerformanceProfile) -> String:
	match value:
		PerformanceProfile.DETAILED:
			return "detailed"
		PerformanceProfile.CROWD:
			return "crowd"
		_:
			return "auto"
