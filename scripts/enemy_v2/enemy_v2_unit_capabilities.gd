extends Resource
class_name EnemyV2UnitCapabilities

## Command contract; no mesh, animation or individual combat state lives here.
@export var role: StringName = &"phalanx"
@export var move_speed: float = 2.8
@export var turn_speed: float = 0.65
@export var preferred_range: float = 4.5
@export var pursuit_leash: float = 28.0
@export var threat_kind: StringName = &"melee"
@export var threat_cost: int = 1
@export var body_radius: float = 0.9
@export var body_height: float = 2.0

static func from_properties(properties: Dictionary, mode: StringName) -> EnemyV2UnitCapabilities:
	var result := EnemyV2UnitCapabilities.new()
	result.role = StringName(properties.get("v2_unit_role", mode))
	match result.role:
		&"archer", &"ranged":
			result.role = &"archer"
			result.move_speed = 3.0
			result.turn_speed = 1.8
			result.preferred_range = 22.0
			result.pursuit_leash = 12.0
			result.threat_kind = &"ranged"
			result.threat_cost = 2
		&"giant":
			result.move_speed = 2.5
			result.turn_speed = 0.5
			result.pursuit_leash = 48.0
			result.preferred_range = 1.35 * maxf(0.5, float(properties.get("size_multiplier", 3.0)))
			result.threat_kind = &"heavy"
			result.threat_cost = 3
			result.body_height = 2.0 * maxf(1.0, float(properties.get("size_multiplier", 3.0)))
			result.body_radius = 0.9 * maxf(1.0, float(properties.get("size_multiplier", 3.0)))
		&"infantry", &"hoplite_skirmish":
			result.role = &"infantry"
			result.move_speed = 4.0
			result.turn_speed = 1.8
			result.preferred_range = 2.7
		_:
			result.role = &"phalanx"
	result.move_speed = float(properties.get("v2_phalanx_advance_speed", result.move_speed))
	return result
