extends RefCounted
class_name EnemyV2TacticalFocusTracker

const FOCUS_DEAD_ZONE := 5.5
const FOCUS_HARD_LIMIT := 14.0
const HANDOFF_DWELL_MSEC := 450

var states: Dictionary = {}


func register_target(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_id := target.get_instance_id()
	if states.has(target_id):
		return
	states[target_id] = {
		"focus": target.global_position,
		"candidate_since_msec": 0,
		"revision": 1,
	}


func unregister_target_id(target_id: int) -> void:
	states.erase(target_id)


func update_target(target: Node3D, now_msec: int = -1) -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	register_target(target)
	var target_id := target.get_instance_id()
	var state := states[target_id] as Dictionary
	var raw := target.global_position
	var focus := state["focus"] as Vector3
	var planar_distance := Vector2(raw.x - focus.x, raw.z - focus.z).length()
	var grounded := true
	if target.has_method("is_on_floor"):
		grounded = bool(target.call("is_on_floor"))
	var resolved_now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	if planar_distance >= FOCUS_HARD_LIMIT and grounded:
		focus = raw
		state["focus"] = focus
		state["candidate_since_msec"] = 0
		state["revision"] = int(state.get("revision", 0)) + 1
	elif planar_distance <= FOCUS_DEAD_ZONE:
		state["candidate_since_msec"] = 0
	elif grounded:
		var candidate_since := int(state.get("candidate_since_msec", 0))
		if candidate_since <= 0:
			state["candidate_since_msec"] = resolved_now
		elif resolved_now - candidate_since >= HANDOFF_DWELL_MSEC:
			focus = raw
			state["focus"] = focus
			state["candidate_since_msec"] = 0
			state["revision"] = int(state.get("revision", 0)) + 1
	return focus


func focus_for_id(target_id: int) -> Vector3:
	if not states.has(target_id):
		return Vector3.ZERO
	return (states[target_id] as Dictionary).get("focus", Vector3.ZERO) as Vector3


func revision_for_id(target_id: int) -> int:
	if not states.has(target_id):
		return 0
	return int((states[target_id] as Dictionary).get("revision", 0))


func force_focus(target: Node3D, position: Vector3) -> void:
	if target == null or not is_instance_valid(target):
		return
	register_target(target)
	var state := states[target.get_instance_id()] as Dictionary
	state["focus"] = position
	state["candidate_since_msec"] = 0
	state["revision"] = int(state.get("revision", 0)) + 1
