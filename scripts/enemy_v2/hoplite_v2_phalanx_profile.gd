extends Resource
class_name HopliteV2PhalanxProfile

@export_range(2, 16, 1) var columns: int = 8
@export_range(0.70, 2.50, 0.05) var column_spacing: float = 1.20
@export_range(0.70, 2.50, 0.05) var rank_spacing: float = 1.05
@export_range(1.0, 20.0, 0.5) var near_decision_hz: float = 8.0
@export_range(0.5, 10.0, 0.5) var far_decision_hz: float = 2.0
@export_range(5.0, 150.0, 1.0) var far_decision_distance: float = 35.0
@export_range(0.5, 8.0, 0.05) var advance_speed: float = 2.80
@export_range(0.5, 3.0, 0.05) var member_speed_multiplier: float = 1.30
@export_range(0.10, 2.0, 0.05) var arrival_slowdown_distance: float = 0.65
@export_range(0.05, 0.8, 0.05) var arrival_tolerance: float = 0.16
@export_range(2.5, 10.0, 0.1) var desired_target_distance: float = 4.20
@export_range(0.1, 3.0, 0.05) var target_distance_hysteresis: float = 0.65
@export_range(0.3, 3.0, 0.05) var cohesion_tolerance: float = 1.15
@export_range(0.25, 1.0, 0.05) var minimum_cohesion_ratio: float = 0.65
@export_range(1, 8, 1) var max_concurrent_attacks: int = 3
@export_range(0.1, 3.0, 0.05) var attack_permission_seconds: float = 1.85


static func from_properties(properties: Dictionary) -> HopliteV2PhalanxProfile:
	var result := HopliteV2PhalanxProfile.new()
	result.columns = clampi(int(properties.get("formation_columns", result.columns)), 2, 16)
	result.column_spacing = maxf(0.70, float(properties.get("formation_spacing", result.column_spacing)))
	result.rank_spacing = maxf(0.70, float(properties.get("formation_rank_spacing", result.rank_spacing)))
	result.near_decision_hz = clampf(float(properties.get("v2_near_decision_hz", result.near_decision_hz)), 1.0, 20.0)
	result.far_decision_hz = clampf(float(properties.get("v2_far_decision_hz", result.far_decision_hz)), 0.5, result.near_decision_hz)
	result.far_decision_distance = maxf(5.0, float(properties.get("v2_far_decision_distance", result.far_decision_distance)))
	result.advance_speed = maxf(0.5, float(properties.get("v2_phalanx_advance_speed", result.advance_speed)))
	result.max_concurrent_attacks = clampi(int(properties.get("v2_max_concurrent_attacks", result.max_concurrent_attacks)), 1, 8)
	return result
