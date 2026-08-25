extends "res://scripts/enemy/athenian_enemy.gd"

var terrain_mode: StringName = &"platform"

func _ready() -> void:
	pass

func _ranged_ground_sample(sample_position: Vector3, _scan_up: float, _scan_down: float) -> Dictionary:
	var floor_y := 0.0
	match terrain_mode:
		&"platform":
			floor_y = 2.0 if absf(sample_position.x) <= 2.0 and absf(sample_position.z) <= 2.0 else 0.0
		&"isolated_platform":
			if absf(sample_position.x) > 2.0 or absf(sample_position.z) > 2.0:
				return {}
			floor_y = 2.0
		&"slope":
			floor_y = clampf(sample_position.x * 0.30, 0.0, 1.50)
	return {"position": Vector3(sample_position.x, floor_y, sample_position.z), "normal": Vector3.UP}
