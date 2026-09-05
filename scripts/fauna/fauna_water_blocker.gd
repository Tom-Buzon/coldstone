extends Node3D
class_name HopliteFaunaWaterBlocker

## Lightweight rectangular water footprint used only by the fauna system.
## It deliberately owns no physics body, collision shape or per-frame process.
@export var footprint_size := Vector2(12.0, 12.0)
@export_range(0.0, 3.0, 0.05) var allowed_height_above_surface := 0.75


func _ready() -> void:
	add_to_group("fauna_water_blocker")


func configure(size: Vector2, height_clearance: float = 0.75) -> void:
	footprint_size = Vector2(maxf(0.05, size.x), maxf(0.05, size.y))
	allowed_height_above_surface = maxf(0.0, height_clearance)
	add_to_group("fauna_water_blocker")


func blocks_world_point(world_point: Vector3, footprint_margin: float = 0.0) -> bool:
	var local_point := to_local(world_point)
	var half_size := footprint_size * 0.5 + Vector2.ONE * maxf(0.0, footprint_margin)
	if absf(local_point.x) > half_size.x or absf(local_point.z) > half_size.y:
		return false
	# A bridge or high platform may safely cross above a water plane.
	return local_point.y <= allowed_height_above_surface
