extends RefCounted
class_name HopliteEnemyNavigationComponent

signal destination_reached
signal navigation_failed(reason: StringName)
signal stuck_detected(attempt: int)
signal recovery_started(attempt: int)
signal recovery_finished(success: bool)

enum Mode {
	NAVMESH_GROUND,
	FORMATION_LOCAL,
	DIRECT_STEERING,
	STATIC,
	FLYING,
	LARGE_BODY,
	RECOVERY_ONLY,
}

class NavigationIntent extends RefCounted:
	var direction: Vector3 = Vector3.ZERO
	var facing_direction: Vector3 = Vector3.ZERO
	var speed_scale: float = 0.0
	var valid: bool = false
	var status: StringName = &"unconfigured"
	var recovery_attempt: int = 0

var owner_body: CharacterBody3D
var mode: Mode = Mode.DIRECT_STEERING
var settings: Dictionary = {}
var destination: Vector3 = Vector3.ZERO
var has_destination: bool = false
var formation_forward: Vector3 = Vector3.FORWARD
var formation_slot: int = -1
var cohort_revision: int = -1

var _destination_revision: int = 0
var _failed_revision: int = -1
var _arrival_emitted_revision: int = -1
var _stationary_time: float = 0.0
var _recovery_time: float = 0.0
var _recovery_direction: Vector3 = Vector3.ZERO
var _recovery_attempt: int = 0
var _last_requested_direction: Vector3 = Vector3.ZERO
var _navigation_agent: NavigationAgent3D
var _intent := NavigationIntent.new()
var _recovery_made_progress: bool = false
var _path_pending_time: float = 0.0
var navigation_map_query_count: int = 0
var _cached_navigation_map: RID
var _cached_navigation_layers: int = 0
var _cached_navigation_map_status: StringName = &"navmesh_unavailable"
var _navigation_map_status_ttl: float = 0.0

func configure(body: CharacterBody3D, navigation_mode: Mode, navigation_settings: Dictionary = {}) -> void:
	owner_body = body
	mode = navigation_mode
	settings = navigation_settings.duplicate(true)
	_stationary_time = 0.0
	_recovery_time = 0.0
	_recovery_attempt = 0
	_path_pending_time = 0.0
	_cached_navigation_map = RID()
	_cached_navigation_layers = 0
	_cached_navigation_map_status = &"navmesh_unavailable"
	_navigation_map_status_ttl = 0.0
	_ensure_navigation_agent()

func set_destination(world_position: Vector3) -> void:
	var semantic_change := not has_destination
	if has_destination:
		var reset_distance := float(settings.get("destination_reset_distance", 3.0))
		semantic_change = destination.distance_squared_to(world_position) >= reset_distance * reset_distance
	_update_destination(world_position, semantic_change)

func set_arrival_profile(slowdown_distance: float, minimum_speed_scale: float) -> void:
	settings["arrival_slowdown_distance"] = maxf(float(settings.get("arrival_distance", 0.28)) + 0.01, slowdown_distance)
	settings["arrival_min_speed_scale"] = clampf(minimum_speed_scale, 0.05, 1.0)

func set_formation_anchor(world_position: Vector3, forward: Vector3, slot_index: int, revision: int) -> void:
	var semantic_change := slot_index != formation_slot or revision != cohort_revision
	formation_forward = _flatten(forward).normalized() if _flatten(forward).length_squared() > 0.0001 else Vector3.FORWARD
	formation_slot = slot_index
	cohort_revision = revision
	_update_destination(world_position, semantic_change or not has_destination)

func clear_destination() -> void:
	if not has_destination:
		return
	has_destination = false
	_stationary_time = 0.0
	_recovery_time = 0.0
	_last_requested_direction = Vector3.ZERO
	_destination_revision += 1
	if _navigation_agent != null:
		_navigation_agent.target_position = owner_body.global_position if owner_body != null else Vector3.ZERO

func sample_intent(delta: float) -> NavigationIntent:
	var intent := _reset_intent()
	_navigation_map_status_ttl = maxf(0.0, _navigation_map_status_ttl - maxf(delta, 0.0))
	if owner_body == null or not is_instance_valid(owner_body):
		intent.status = &"unconfigured"
		return intent
	if _recovery_time > 0.0:
		_recovery_time = maxf(0.0, _recovery_time - maxf(delta, 0.0))
		intent.direction = _recovery_direction
		intent.facing_direction = _recovery_direction
		intent.speed_scale = float(settings.get("recovery_speed_scale", 0.72))
		intent.valid = true
		intent.status = &"recovering"
		intent.recovery_attempt = _recovery_attempt
		_last_requested_direction = intent.direction
		if _recovery_time <= 0.0:
			var success := _recovery_made_progress
			recovery_finished.emit(success)
			if not success and _recovery_attempt >= int(settings.get("max_recovery_attempts", 3)):
				_emit_navigation_failure_once(&"recovery_exhausted")
		return intent
	if not has_destination:
		intent.status = &"idle"
		return intent
	if mode == Mode.STATIC:
		intent.status = &"static"
		return intent

	var to_destination := destination - owner_body.global_position
	if mode != Mode.FLYING:
		to_destination.y = 0.0
	var destination_distance := to_destination.length()
	var arrival_distance := float(settings.get("arrival_distance", 0.28))
	if to_destination.length_squared() <= arrival_distance * arrival_distance:
		intent.status = &"arrived"
		if _arrival_emitted_revision != _destination_revision:
			_arrival_emitted_revision = _destination_revision
			destination_reached.emit()
		_last_requested_direction = Vector3.ZERO
		return intent

	var resolved_mode := mode
	if mode == Mode.NAVMESH_GROUND:
		var map_status := _navigation_map_status()
		if map_status != &"ready":
			_emit_navigation_failure_once(map_status)
			resolved_mode = int(settings.get("fallback_mode", Mode.DIRECT_STEERING)) as Mode
			intent.status = &"fallback_direct"
		else:
			var next_path_position := _navigation_agent.get_next_path_position()
			to_destination = next_path_position - owner_body.global_position
			to_destination.y = 0.0
			if to_destination.length_squared() <= 0.0001 and not _navigation_agent.is_target_reachable():
				_path_pending_time += maxf(delta, 0.0)
				if _path_pending_time < float(settings.get("path_pending_timeout", 0.35)):
					intent.status = &"path_pending"
					return intent
				_emit_navigation_failure_once(&"target_unreachable")
				resolved_mode = int(settings.get("fallback_mode", Mode.DIRECT_STEERING)) as Mode
				to_destination = destination - owner_body.global_position
				to_destination.y = 0.0
				intent.status = &"fallback_direct"
			else:
				_path_pending_time = 0.0
				intent.status = &"moving_navmesh"

	if resolved_mode == Mode.RECOVERY_ONLY:
		intent.status = &"monitoring"
		return intent
	if to_destination.length_squared() <= 0.0001:
		intent.status = &"path_pending"
		return intent

	intent.direction = to_destination.normalized()
	intent.facing_direction = formation_forward if resolved_mode == Mode.FORMATION_LOCAL or bool(settings.get("formation_facing", false)) else intent.direction
	intent.speed_scale = 0.78 if resolved_mode == Mode.LARGE_BODY else 1.0
	if resolved_mode == Mode.FORMATION_LOCAL or bool(settings.get("formation_facing", false)):
		# A formation slot is an arrival target, not a point to cross at full speed.
		# Damping only the existing speed scale avoids another steering query and
		# prevents the accelerate/overshoot/reverse loop around tightly packed posts.
		var slowdown_distance := maxf(arrival_distance + 0.01, float(settings.get("arrival_slowdown_distance", 0.55)))
		var minimum_scale := clampf(float(settings.get("arrival_min_speed_scale", 0.80)), 0.05, 1.0)
		var arrival_ratio := clampf((destination_distance - arrival_distance) / (slowdown_distance - arrival_distance), 0.0, 1.0)
		intent.speed_scale *= lerpf(minimum_scale, 1.0, smoothstep(0.0, 1.0, arrival_ratio))
	intent.valid = true
	if intent.status == &"unconfigured":
		intent.status = &"moving"
	_last_requested_direction = intent.direction
	return intent

func notify_motion_applied(previous_position: Vector3, current_position: Vector3, delta: float, applied_direction: Vector3 = Vector3.ZERO) -> void:
	if not has_destination or _last_requested_direction.length_squared() <= 0.0001:
		_stationary_time = 0.0
		return
	var progress := current_position - previous_position
	if mode != Mode.FLYING:
		progress.y = 0.0
	var measured_direction := applied_direction.normalized() if applied_direction.length_squared() > 0.0001 else _last_requested_direction
	var progress_speed := progress.dot(measured_direction) / maxf(delta, 0.0001)
	var minimum_progress_speed := float(settings.get("minimum_progress_speed", 0.12))
	if _recovery_time > 0.0:
		_recovery_made_progress = _recovery_made_progress or progress_speed >= minimum_progress_speed
		return
	if progress_speed < minimum_progress_speed:
		_stationary_time += maxf(delta, 0.0)
	else:
		_stationary_time = 0.0
	var stuck_timeout := float(settings.get("stuck_timeout", 0.75))
	if _stationary_time + 0.0001 < stuck_timeout:
		return
	_stationary_time = 0.0
	_recovery_attempt += 1
	var side_sign := -1.0 if _recovery_attempt % 2 == 0 else 1.0
	_recovery_direction = Vector3(-_last_requested_direction.z, 0.0, _last_requested_direction.x) * side_sign
	if _recovery_direction.length_squared() <= 0.0001:
		_recovery_direction = Vector3.RIGHT * side_sign
	else:
		_recovery_direction = _recovery_direction.normalized()
	_recovery_time = float(settings.get("recovery_duration", 0.46))
	_recovery_made_progress = false
	stuck_detected.emit(_recovery_attempt)
	recovery_started.emit(_recovery_attempt)

func _ensure_navigation_agent() -> void:
	if owner_body == null or mode != Mode.NAVMESH_GROUND:
		return
	if _navigation_agent == null:
		_navigation_agent = NavigationAgent3D.new()
		_navigation_agent.name = "NavigationAgent"
		_navigation_agent.path_height_offset = 0.0
		# RVO remains disabled until the owner consumes velocity_computed. Enabling
		# it without that loop would advertise avoidance while applying raw intent.
		_navigation_agent.avoidance_enabled = false
		_navigation_agent.radius = float(settings.get("agent_radius", 0.45))
		_navigation_agent.height = float(settings.get("agent_height", 1.8))
		_navigation_agent.navigation_layers = maxi(1, int(settings.get("navigation_layers", 1)))
		owner_body.add_child(_navigation_agent)

func _has_usable_navigation_map() -> bool:
	return _navigation_map_status() == &"ready"

func _navigation_map_status() -> StringName:
	if _navigation_agent == null or owner_body == null or not owner_body.is_inside_tree() or not _navigation_agent.is_inside_tree():
		return &"navmesh_unavailable"
	var map_rid := _navigation_agent.get_navigation_map()
	if not map_rid.is_valid():
		return &"navmesh_unavailable"
	var navigation_layers := _navigation_agent.navigation_layers
	if (
		map_rid == _cached_navigation_map
		and navigation_layers == _cached_navigation_layers
		and _navigation_map_status_ttl > 0.0
	):
		return _cached_navigation_map_status

	_cached_navigation_map = map_rid
	_cached_navigation_layers = navigation_layers
	navigation_map_query_count += 1
	var regions := NavigationServer3D.map_get_regions(map_rid)
	if regions.is_empty():
		_cached_navigation_map_status = &"navmesh_unavailable"
		_navigation_map_status_ttl = float(settings.get("navigation_map_retry_interval", 0.12))
		return _cached_navigation_map_status
	for region_rid: RID in regions:
		if NavigationServer3D.region_get_navigation_layers(region_rid) & navigation_layers:
			_cached_navigation_map_status = &"ready"
			_navigation_map_status_ttl = float(settings.get("navigation_map_refresh_interval", 0.50))
			return _cached_navigation_map_status
	_cached_navigation_map_status = &"navigation_layers_mismatch"
	_navigation_map_status_ttl = float(settings.get("navigation_map_retry_interval", 0.12))
	return _cached_navigation_map_status

func _emit_navigation_failure_once(reason: StringName) -> void:
	if _failed_revision == _destination_revision:
		return
	_failed_revision = _destination_revision
	navigation_failed.emit(reason)

func _update_destination(world_position: Vector3, semantic_change: bool) -> void:
	destination = world_position
	has_destination = true
	if semantic_change:
		_destination_revision += 1
		_stationary_time = 0.0
		_recovery_time = 0.0
		_recovery_attempt = 0
		_recovery_made_progress = false
	if _navigation_agent != null:
		var retarget_distance := float(settings.get("path_retarget_distance", 0.35))
		if semantic_change or _navigation_agent.target_position.distance_squared_to(destination) >= retarget_distance * retarget_distance:
			_navigation_agent.target_position = destination

func _reset_intent() -> NavigationIntent:
	_intent.direction = Vector3.ZERO
	_intent.facing_direction = Vector3.ZERO
	_intent.speed_scale = 0.0
	_intent.valid = false
	_intent.status = &"unconfigured"
	_intent.recovery_attempt = 0
	return _intent

func _flatten(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)
