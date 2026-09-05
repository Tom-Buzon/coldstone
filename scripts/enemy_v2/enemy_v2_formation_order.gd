extends RefCounted
class_name EnemyV2FormationOrder

var revision: int = 0
var role: StringName = &"hold"
var final_goal := Vector3.ZERO
var final_facing := Vector3.FORWARD
var path := PackedVector3Array()
var waypoint_index: int = 0
var movement_phase: StringName = &"hold"
var issued_at_msec: int = 0
var min_hold_until_msec: int = 0


func current_waypoint() -> Vector3:
	if waypoint_index < 0 or waypoint_index >= path.size():
		return final_goal
	return path[waypoint_index]


func advance_if_reached(position: Vector3, tolerance: float) -> bool:
	while waypoint_index < path.size() and _planar_distance(position, path[waypoint_index]) <= tolerance:
		waypoint_index += 1
	return waypoint_index >= path.size()


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
