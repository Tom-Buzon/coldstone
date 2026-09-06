extends Node3D

# One temporary camera: chase -> impact crane -> smooth return to the live rig.
var runtime: Node
var camera: Camera3D
var projectile: Node3D
var phase: StringName = &""
var elapsed := 0.0
var forward := Vector3.FORWARD
var focus := Vector3.ZERO
var start_transform := Transform3D.IDENTITY
var radius := 7.0
var slow := 1.0

func configure(value: Node) -> void:
	runtime = value
	camera = Camera3D.new()
	camera.top_level = true
	add_child(camera)
	camera.current = false

func begin(shot: Node3D) -> void:
	start_transform = camera.global_transform if phase != &"" else runtime.player.camera.get_camera_transform()
	projectile = shot
	forward = shot.direction
	phase = &"flight"
	elapsed = 0.0
	slow = 0.22
	camera.global_transform = start_transform
	camera.fov = runtime.player.camera.fov
	camera.environment = runtime.player.camera.environment
	camera.cull_mask = runtime.player.camera.cull_mask
	camera.make_current()

func impact(shot: Node3D, point: Vector3, blast_radius: float) -> void:
	if phase != &"flight" or projectile != shot: return
	focus = point
	radius = blast_radius
	projectile = null
	phase = &"impact"
	elapsed = 0.0
	start_transform = camera.global_transform

func advance(delta: float) -> void:
	if phase == &"":
		slow = 1.0
		return
	if not is_instance_valid(runtime.player):
		finish()
		return
	elapsed += delta
	if phase == &"flight":
		slow = 0.22
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion() or elapsed > 3.0:
			_return()
			return
		focus = projectile.global_position
		var position := focus - forward * 5.5 + Vector3.UP * 2.4 + forward.cross(Vector3.UP).normalized() * 1.3
		var desired := _framing(position, focus + forward * 2.0)
		camera.global_transform = start_transform.interpolate_with(desired, smoothstep(0.0, 0.22, elapsed))
		camera.fov = lerpf(camera.fov, 62.0, 1.0 - exp(-8.0 * delta))
	elif phase == &"impact":
		slow = lerpf(0.12, 0.38, smoothstep(0.0, 0.85, elapsed))
		var flat := Vector3(forward.x, 0, forward.z).normalized()
		if flat.length_squared() < 0.01: flat = Vector3.FORWARD
		var desired := _framing(focus - flat * (radius + 4.0) + Vector3.UP * (radius + 6.0), focus)
		camera.global_transform = start_transform.interpolate_with(desired, smoothstep(0.0, 0.8, elapsed))
		camera.fov = lerpf(camera.fov, 78.0, 1.0 - exp(-5.0 * delta))
		if elapsed >= 0.9: _return()
	elif phase == &"return":
		var weight := smoothstep(0.0, 1.1, elapsed)
		slow = lerpf(0.38, 1.0, weight)
		var player: Node3D = runtime.player
		player.camera_yaw.rotation.y = lerp_angle(player.camera_yaw.rotation.y, player.rotation.y, 1.0 - exp(-6.0 * delta))
		camera.global_transform = start_transform.interpolate_with(player.camera.get_camera_transform(), weight)
		camera.fov = lerpf(camera.fov, player.camera.fov, weight)
		if elapsed >= 1.1: finish()

func _framing(position: Vector3, target: Vector3) -> Transform3D:
	# Keep the cinematic lens on the visible side of solid scenery.
	var query := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 0.2, position, 1)
	var hit: Dictionary = runtime.player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): position = hit.position + hit.normal * 0.3
	if position.distance_squared_to(target) < 0.01: position += Vector3.UP
	var transform := Transform3D(Basis.IDENTITY, position)
	var up := Vector3.RIGHT if absf((target - position).normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	return transform.looking_at(target, up)

func _return() -> void:
	projectile = null
	phase = &"return"
	elapsed = 0.0
	start_transform = camera.global_transform

func finish() -> void:
	phase = &""
	projectile = null
	slow = 1.0
	if is_instance_valid(runtime) and is_instance_valid(runtime.player) and is_instance_valid(runtime.player.camera): runtime.player.camera.make_current()

func _exit_tree() -> void: finish()
