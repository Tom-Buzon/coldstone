extends RefCounted
class_name EnemyV2CorridorReservation

var owner_id: StringName = &""
var path := PackedVector3Array()
var cells: Array[Vector2i] = []
var final_goal := Vector3.ZERO
var priority: int = 0
var expires_at_msec: int = 0
var issued_at_msec: int = 0
var last_progress_at_msec: int = 0
var last_progress_position := Vector3.ZERO
var segment_index: int = 0
var formation_width: float = 1.0
var formation_depth: float = 1.0
var status: StringName = &"moving"
var last_refresh_at_msec: int = 0


func is_active(now_msec: int = -1) -> bool:
	var resolved_now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	return not owner_id.is_empty() and resolved_now < expires_at_msec
