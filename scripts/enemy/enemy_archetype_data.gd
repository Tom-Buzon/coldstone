extends Resource
class_name HopliteEnemyArchetypeData

# Read-only typed view over one normalized legacy profile snapshot. During the
# incremental migration, HopliteEnemyArchetypes.profile() remains the sole
# authored source. Callers receive copies for legacy access, never this snapshot.
var _archetype_id: StringName
var _asset_origin: StringName
var _display_name: String
var _role: StringName
var _rank: StringName
var _weapon: StringName
var _defense: StringName
var _behavior: StringName
var _package_path: String
var _is_giant: bool
var _scale: float
var _health: float
var _move_speed: float
var _attack_damage: float
var _attack_range: float
var _aggro_distance: float
var _procedural_cost: float
var _procedural_weight: float
var _first_wave: int
var _auto_crowd_scalable: bool
var _profile_snapshot: Dictionary
var _configured: bool = false

var archetype_id: StringName:
	get:
		return _archetype_id
var asset_origin: StringName:
	get:
		return _asset_origin
var display_name: String:
	get:
		return _display_name
var role: StringName:
	get:
		return _role
var rank: StringName:
	get:
		return _rank
var weapon: StringName:
	get:
		return _weapon
var defense: StringName:
	get:
		return _defense
var behavior: StringName:
	get:
		return _behavior
var package_path: String:
	get:
		return _package_path
var is_giant: bool:
	get:
		return _is_giant
var scale: float:
	get:
		return _scale
var health: float:
	get:
		return _health
var move_speed: float:
	get:
		return _move_speed
var attack_damage: float:
	get:
		return _attack_damage
var attack_range: float:
	get:
		return _attack_range
var aggro_distance: float:
	get:
		return _aggro_distance
var procedural_cost: float:
	get:
		return _procedural_cost
var procedural_weight: float:
	get:
		return _procedural_weight
var first_wave: int:
	get:
		return _first_wave
var auto_crowd_scalable: bool:
	get:
		return _auto_crowd_scalable


func _configure(
	id: StringName,
	profile: Dictionary,
	resolved_package_path: String,
	giant: bool
) -> void:
	if _configured:
		push_error("HopliteEnemyArchetypeData can only be configured once")
		return
	_archetype_id = id
	_asset_origin = StringName(profile.get("asset_origin", &"unclassified"))
	_display_name = String(profile.get("display_name", "SWORDSMAN"))
	_role = StringName(profile.get("role", &"standard"))
	_rank = StringName(profile.get("rank", &"troop"))
	_weapon = StringName(profile.get("weapon", &"sword"))
	_defense = StringName(profile.get("defense", &"none"))
	_behavior = StringName(profile.get("behavior", &"aggressive"))
	_package_path = resolved_package_path
	_is_giant = giant
	_scale = float(profile.get("scale", 1.0))
	_health = float(profile.get("health", 100.0))
	_move_speed = float(profile.get("move_speed", 4.0))
	_attack_damage = float(profile.get("attack_damage", 14.0))
	_attack_range = float(profile.get("attack_range", 1.7))
	_aggro_distance = float(profile.get("aggro_distance", 20.0))
	_procedural_cost = float(profile.get("procedural_cost", 1.0))
	_procedural_weight = float(profile.get("procedural_weight", 1.0))
	_first_wave = int(profile.get("first_wave", 0))
	_auto_crowd_scalable = bool(profile.get("auto_crowd_scalable", false))
	_profile_snapshot = profile.duplicate(true)
	_configured = true


func is_miniboss_or_boss() -> bool:
	return _rank == &"miniboss" or _rank == &"boss"


func legacy_profile() -> Dictionary:
	return _profile_snapshot.duplicate(true)
