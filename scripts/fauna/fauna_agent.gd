extends Node3D
class_name HopliteFaunaAgent

const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const GROUND_PROBE_INTERVAL := 0.10
const ANIMATION_BLEND_TIME := 0.16
const MAX_GROUND_RISE := 1.25
const MAX_GROUND_DROP := 2.50

var species_id: StringName = &""
var definition: Dictionary = {}
var behavior_id: StringName = &"passive"
var player: Node3D
var fauna_manager: Node
var home_position := Vector3.ZERO
var movement_target := Vector3.ZERO
var airborne := false

var _rng := RandomNumberGenerator.new()
var _animation_players: Array[AnimationPlayer] = []
var _current_animation_kind: StringName = &""
var _logic_interval := 0.25
var _logic_time_left := 0.0
var _rest_time_left := 0.0
var _moving_fast := false
var _simulation_active := true
var _walk_speed := 1.0
var _run_speed := 4.0
var _wander_radius := 15.0
var _flee_distance := 10.0
var _ground_probe_time_left := 0.0
var _ground_height := 0.0
var _physics_divisor := 1
var _physics_phase := 0
var _deferred_delta := 0.0


func configure(
	species_definition: Dictionary,
	behavior_index: int,
	owner_player: Node3D,
	owner_manager: Node,
	random_seed: int,
	spawn_position: Vector3,
	logic_hz: float
) -> bool:
	definition = species_definition.duplicate(true)
	species_id = StringName(definition.get("id", &"unknown"))
	behavior_id = HopliteFaunaSettings.behavior_id(behavior_index)
	player = owner_player
	fauna_manager = owner_manager
	_rng.seed = random_seed
	airborne = bool(definition.get("airborne", false))
	_walk_speed = float(definition.get("walk_speed", 1.0))
	_run_speed = float(definition.get("run_speed", 4.0))
	_wander_radius = float(definition.get("wander_radius", 15.0))
	_flee_distance = float(definition.get("flee_distance", 10.0))
	_logic_interval = 1.0 / maxf(1.0, logic_hz)
	_logic_time_left = _rng.randf_range(0.02, _logic_interval)
	_ground_probe_time_left = _rng.randf_range(0.0, GROUND_PROBE_INTERVAL)
	global_position = spawn_position
	_ground_height = spawn_position.y
	home_position = spawn_position
	movement_target = spawn_position
	rotation.y = _rng.randf_range(-PI, PI)
	if not _build_visual():
		return false
	set_physics_process(true)
	_request_wander_target(false)
	return true


func _physics_process(delta: float) -> void:
	if not _simulation_active or player == null or not is_instance_valid(player):
		return
	_physics_phase = (_physics_phase + 1) % _physics_divisor
	if _physics_phase != 0:
		_deferred_delta += delta
		return
	delta += _deferred_delta
	_deferred_delta = 0.0
	_logic_time_left -= delta
	if _logic_time_left <= 0.0:
		_logic_time_left += _logic_interval
		_update_behavior()
	if _rest_time_left > 0.0:
		_rest_time_left -= delta
		_play_animation(&"idle")
		if _rest_time_left <= 0.0:
			_request_wander_target(false)
		return
	var offset := movement_target - global_position
	var movement_offset := offset if airborne else Vector3(offset.x, 0.0, offset.z)
	var distance := movement_offset.length()
	if distance <= 0.22:
		if airborne:
			global_position = movement_target
		else:
			global_position.y = move_toward(global_position.y, movement_target.y, maxf(3.0, _walk_speed * 1.8) * delta)
			if not is_equal_approx(global_position.y, movement_target.y):
				_play_animation(&"idle")
				return
		_rest_time_left = _rng.randf_range(1.0, 3.6) if not airborne else _rng.randf_range(0.05, 0.3)
		_play_animation(&"idle")
		return
	var direction := movement_offset / distance
	var speed := _run_speed if _moving_fast else _walk_speed
	var next_position := global_position + direction * minf(distance, speed * delta)
	if not airborne:
		next_position.y = global_position.y
		if not _resolve_ground_step(next_position, delta):
			return
	else:
		global_position = next_position
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() > 0.0001:
		var target_basis := Basis.looking_at(flat_direction.normalized(), Vector3.UP)
		basis = basis.slerp(target_basis, clampf(delta * 5.0, 0.0, 1.0)).orthonormalized()
	_play_animation(&"run" if _moving_fast else &"walk")


func _resolve_ground_step(next_position: Vector3, delta: float) -> bool:
	if fauna_manager == null or not is_instance_valid(fauna_manager):
		return false
	var margin := water_clearance_radius()
	if fauna_manager.has_method("is_water_blocked") and bool(fauna_manager.call("is_water_blocked", next_position, margin)):
		_reject_ground_target()
		return false
	_ground_probe_time_left -= delta
	if _ground_probe_time_left <= 0.0:
		_ground_probe_time_left += GROUND_PROBE_INTERVAL
		var projected: Variant = fauna_manager.call("project_ground_position", next_position, margin)
		if not projected is Vector3:
			_reject_ground_target()
			return false
		var projected_position := projected as Vector3
		var height_delta := projected_position.y - global_position.y
		if height_delta > MAX_GROUND_RISE or height_delta < -MAX_GROUND_DROP:
			_reject_ground_target()
			return false
		_ground_height = projected_position.y
	next_position.y = move_toward(global_position.y, _ground_height, maxf(3.0, (_run_speed if _moving_fast else _walk_speed) * 1.8) * delta)
	global_position = next_position
	return true


func _reject_ground_target() -> void:
	movement_target = global_position
	_moving_fast = false
	_rest_time_left = 0.15
	_request_wander_target(false)


func _update_behavior() -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var player_distance := to_player.length()
	match behavior_id:
		&"wary", &"skittish":
			var detection := _flee_distance * (1.45 if behavior_id == &"skittish" else 1.0)
			if player_distance < detection and player_distance > 0.01:
				var flee_distance := _wander_radius * (1.25 if behavior_id == &"skittish" else 0.85)
				_request_specific_target(global_position - to_player.normalized() * flee_distance, true)
		&"territorial":
			if player_distance < _flee_distance and player_distance > 4.0:
				_request_specific_target(player.global_position - to_player.normalized() * 3.5, true)
			elif player_distance <= 4.0:
				movement_target = global_position
				_moving_fast = false
				_rest_time_left = maxf(_rest_time_left, 0.6)
		_:
			pass


func set_behavior(behavior_index: int, logic_hz: float) -> void:
	behavior_id = HopliteFaunaSettings.behavior_id(behavior_index)
	_logic_interval = 1.0 / maxf(1.0, logic_hz)
	_logic_time_left = minf(_logic_time_left, _logic_interval)


func set_wander_target(target: Vector3, fast: bool = false) -> void:
	movement_target = target
	_moving_fast = fast
	_rest_time_left = 0.0


func hold_position(duration: float = 0.8) -> void:
	movement_target = global_position
	_moving_fast = false
	_rest_time_left = maxf(0.05, duration)
	_play_animation(&"idle")


func water_clearance_radius() -> float:
	return clampf(float(definition.get("target_height", 1.0)) * 0.25, 0.28, 0.70)


func relocate(spawn_position: Vector3) -> void:
	global_position = spawn_position
	home_position = spawn_position
	movement_target = spawn_position
	_ground_height = spawn_position.y
	_ground_probe_time_left = 0.0
	_rest_time_left = 0.0
	_request_wander_target(false)


func set_simulation_active(active: bool) -> void:
	if active == _simulation_active:
		return
	_simulation_active = active
	set_physics_process(active)
	for animation_player: AnimationPlayer in _animation_players:
		animation_player.speed_scale = 1.0 if active else 0.0


func set_physics_divisor(divisor: int) -> void:
	var next_divisor := clampi(divisor, 1, 8)
	if next_divisor == _physics_divisor:
		return
	_physics_divisor = next_divisor
	_physics_phase = posmod(get_instance_id(), _physics_divisor)
	_deferred_delta = 0.0


func _request_wander_target(fast: bool) -> void:
	if fauna_manager != null and is_instance_valid(fauna_manager) and fauna_manager.has_method("assign_wander_target"):
		fauna_manager.call("assign_wander_target", self, fast)


func _request_specific_target(desired: Vector3, fast: bool) -> void:
	if fauna_manager != null and is_instance_valid(fauna_manager) and fauna_manager.has_method("assign_specific_target"):
		fauna_manager.call("assign_specific_target", self, desired, fast)


func _build_visual() -> bool:
	var model_path := String(definition.get("model_path", ""))
	var packed := RuntimeGLTFCacheScript.scene(model_path)
	if packed == null:
		push_warning("[FAUNA] Modèle indisponible pour %s : %s" % [String(species_id), model_path])
		return false
	var visual := packed.instantiate() as Node3D
	if visual == null:
		return false
	visual.name = "AnimatedVisual"
	add_child(visual)
	_fit_visual_to_height(visual, float(definition.get("target_height", 1.0)))
	# The Ultimate pack faces +Z, while the standalone eagle already faces -Z.
	visual.rotation.y = deg_to_rad(float(definition.get("visual_yaw_degrees", 180.0)))
	_collect_animation_players(visual)
	_configure_rendering(visual)
	_play_animation(&"idle")
	return true


func _collect_animation_players(root: Node) -> void:
	_animation_players.clear()
	if root is AnimationPlayer:
		_animation_players.append(root as AnimationPlayer)
	for candidate: Node in root.find_children("*", "AnimationPlayer", true, false):
		var animation_player := candidate as AnimationPlayer
		if animation_player != null:
			_animation_players.append(animation_player)


func _configure_rendering(root: Node) -> void:
	for candidate: Node in root.find_children("*", "CollisionObject3D", true, false):
		var collision_object := candidate as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for candidate: Node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh: MeshInstance3D in meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 150.0
		mesh.visibility_range_end_margin = 10.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _play_animation(kind: StringName) -> void:
	var effective_kind := &"fly" if airborne else kind
	if effective_kind == _current_animation_kind:
		return
	_current_animation_kind = effective_kind
	var candidates: Array[StringName]
	match effective_kind:
		&"fly": candidates = [&"Flying", &"Fly", &"Animation", &"Gallop", &"Walk", &"Idle"]
		&"run": candidates = [&"Gallop", &"Run", &"Walk"]
		&"walk": candidates = [&"Walk", &"Gallop", &"Idle"]
		_: candidates = [&"Idle", &"Idle_2", &"Eating"]
	for animation_player: AnimationPlayer in _animation_players:
		var animation_name := _find_animation(animation_player, candidates)
		if not animation_name.is_empty():
			var animation := animation_player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			var blend_time := 0.0 if animation_player.current_animation.is_empty() else ANIMATION_BLEND_TIME
			animation_player.play(animation_name, blend_time, _animation_speed(effective_kind))


func _animation_speed(kind: StringName) -> float:
	match kind:
		&"walk": return clampf(_walk_speed / 1.2, 0.75, 1.30)
		&"run": return clampf(_run_speed / 4.5, 0.85, 1.25)
		_: return 1.0


func _find_animation(animation_player: AnimationPlayer, candidates: Array[StringName]) -> StringName:
	var names := animation_player.get_animation_list()
	for candidate: StringName in candidates:
		var wanted := String(candidate).to_lower()
		for available: StringName in names:
			var normalized := String(available).to_lower()
			if normalized == wanted or normalized.ends_with("|" + wanted) or normalized.ends_with("/" + wanted):
				return available
	return StringName()


func _fit_visual_to_height(content: Node3D, target_height: float) -> void:
	var bounds := _node_bounds(content)
	if bounds.size.y <= 0.001:
		return
	var scale_value := target_height / bounds.size.y
	content.scale = Vector3.ONE * scale_value
	content.position = Vector3(
		-(bounds.position.x + bounds.size.x * 0.5) * scale_value,
		-bounds.position.y * scale_value,
		-(bounds.position.z + bounds.size.z * 0.5) * scale_value
	)


func _node_bounds(content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		var to_content := content.global_transform.affine_inverse() * mesh.global_transform
		var mesh_bounds := to_content * mesh.get_aabb()
		bounds = mesh_bounds if not initialized else bounds.merge(mesh_bounds)
		initialized = true
	return bounds
