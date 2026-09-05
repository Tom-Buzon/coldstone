extends Node
class_name HopliteTransientRigidDebrisLifecycle

# One timer drives both phases: a short physical phase, then a cheap visual-only
# phase before final release. This avoids a per-frame callback on every dropped
# weapon, shield or detached limb.

var body: RigidBody3D
var collision_shape: CollisionShape3D
var retired: bool = false

var _timer: Timer
var _remaining_visual_lifetime: float = 0.0
var _waiting_for_retirement: bool = false
var _release_callback: Callable
var _externally_scheduled: bool = false


func setup(
	 target_body: RigidBody3D,
	 target_collision: CollisionShape3D,
	 lifetime_seconds: float,
	 active_physics_seconds: float,
	 release_callback: Callable = Callable(),
	 externally_scheduled: bool = false
) -> void:
	body = target_body
	collision_shape = target_collision
	name = "TransientDebrisLifecycle"
	retired = false
	_release_callback = release_callback
	_externally_scheduled = externally_scheduled

	var safe_lifetime := maxf(lifetime_seconds, 0.01)
	var safe_active_time := clampf(active_physics_seconds, 0.0, safe_lifetime)
	_remaining_visual_lifetime = safe_lifetime - safe_active_time
	_waiting_for_retirement = safe_active_time > 0.0 and _remaining_visual_lifetime > 0.0

	if _externally_scheduled:
		if _timer != null:
			_timer.stop()
		return
	if _timer == null:
		_timer = Timer.new()
		_timer.name = "LifecycleTimer"
		_timer.one_shot = true
		_timer.timeout.connect(_on_timer_timeout)
		add_child(_timer)
	_timer.start(safe_active_time if _waiting_for_retirement else safe_lifetime)


func retire_now() -> void:
	if retired:
		return
	retired = true
	if body != null and is_instance_valid(body):
		body.collision_layer = 0
		body.collision_mask = 0
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = true
		body.freeze = true
		for candidate: Node in body.find_children("*", "GeometryInstance3D", true, false):
			var geometry := candidate as GeometryInstance3D
			if geometry != null:
				geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collision_shape != null and is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)

	if _waiting_for_retirement and not _externally_scheduled:
		_waiting_for_retirement = false
		if _timer != null and _remaining_visual_lifetime > 0.0:
			_timer.start(_remaining_visual_lifetime)


func expire_now() -> void:
	if not _release_callback.is_null() and _release_callback.is_valid():
		_release_callback.call(body)
		return
	if body != null and is_instance_valid(body):
		body.queue_free()


func _on_timer_timeout() -> void:
	if _waiting_for_retirement:
		retire_now()
	else:
		expire_now()
