extends CharacterBody3D
class_name HopliteUALNativePlayer

signal slide_slash_contact(target: Node)

const DriverScript = preload("res://scripts/animation/native_animation_driver.gd")
const TrailScript = preload("res://scripts/animation/sword_trail.gd")
const UAL1_PATH := "res://assets/runtime/ual1/UAL1_Standard.glb"

# Fast, momentum-preserving locomotion. Steering changes direction without
# shrinking the horizontal velocity vector, so turning does not cost speed.
var max_speed: float = 7.2
var acceleration: float = 9.2
var deceleration: float = 13.5
var air_acceleration: float = 4.8
var movement_turn_response: float = 22.0
var air_turn_response: float = 10.0
var turn_speed: float = 14.0
var jump_velocity: float = 8.8
var gravity: float = 24.0
var max_jumps: int = 2
var jumps_used: int = 0

# No authored landing recovery: touching the floor returns immediately to
# locomotion, unless a slide was armed in the air.
var dash_speed: float = 19.0
var dash_end_speed: float = 12.0
var dash_duration: float = 0.27
var dash_time: float = 0.0
var dash_cooldown: float = 0.38
var dash_cooldown_timer: float = 0.0
var dash_variant_grace: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

# CTRL slide: 70% of dash top speed, 60% of the implemented dash distance.
var slide_speed_ratio: float = 0.70
var slide_distance_ratio: float = 0.60
var slide_time: float = 0.0
var slide_armed: bool = false
var slide_direction: Vector3 = Vector3.ZERO
var slide_turn_response: float = 8.0
# UAL2 Slide is authored around the donor hips/root height. The CharacterBody
# origin is at the feet, so lower only the visible mannequin while sliding.
# This does NOT move the collider or add root motion.
var slide_visual_drop: float = 0.62
var slide_visual_vertical_speed: float = 14.0
var slide_slash_active_time: float = 0.0
var slide_slash_radius: float = 1.05
var slide_slash_contacts: Dictionary = {}

var parkour_active: bool = false
var parkour_kind: StringName = StringName()
var parkour_elapsed: float = 0.0
var parkour_duration: float = 0.0
var parkour_start: Vector3 = Vector3.ZERO
var parkour_end: Vector3 = Vector3.ZERO
var parkour_arc: float = 0.0
var parkour_exit_direction: Vector3 = Vector3.ZERO
# CTRL pressed during vault/mantle is buffered and converted into a slide on exit.
var parkour_slide_queued: bool = false
var parkour_debug_reason: String = "ready"
var parkour_probe_distance: float = 1.65
var parkour_min_height: float = 0.30
var parkour_vault_max_height: float = 1.20
var parkour_max_height: float = 2.75
# If CTRL was buffered during a mantle, trim the last ~20% of the authored
# climb and hand control straight to the slide. At this point the body is
# already essentially on top of the ledge, so the tiny snap to parkour_end is
# preferable to a visible pause between mantle and slide.
var parkour_slide_early_exit_progress: float = 0.80

var visual_root: Node3D
var visual_flipped: bool = true
var mannequin_scene: Node
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_driver: HopliteNativeAnimationDriver

var camera_yaw: Node3D
var camera_pitch: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var camera_pitch_value: float = -0.18
var camera_distance: float = 5.2
var mouse_sensitivity: float = 0.00105

var right_hand_bone: String = ""
var left_hand_bone: String = ""
var sword_attachment: BoneAttachment3D
var shield_attachment: BoneAttachment3D
var sword_root: Node3D
var sword_tip: Marker3D
var sword_trail: HopliteNativeSwordTrail
var sword_blade_material: StandardMaterial3D
var sword_base_color: Color = Color(0.72, 0.76, 0.78)
var sword_preset: int = 0
var shield_visible: bool = true

var light_step: int = 0
var combo_timer: float = 0.0
var combo_light_count: int = 0
var heavy_charging: bool = false
var heavy_charge_pose_started: bool = false
var heavy_charge: float = 0.0
var heavy_charge_max: float = 1.55
var heavy_charge_context: StringName = &"idle"
var fast_heavy_candidate: bool = false
var spin_active_time: float = 0.0
var spin_total_time: float = 0.0
var spin_rotation_total: float = 0.0

var resource_error: String = ""
var debug_text: String = ""

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_ensure_slide_input_action()
	_build_collider()
	_build_camera()
	_load_ual1_mannequin()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_collider() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.82
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.91, 0.0)
	add_child(collision)

func _build_camera() -> void:
	camera_yaw = Node3D.new()
	camera_yaw.name = "CameraYaw"
	camera_yaw.top_level = true
	get_tree().current_scene.add_child(camera_yaw)
	camera_yaw.global_position = global_position + Vector3(0.0, 1.55, 0.0)
	camera_pitch = Node3D.new()
	camera_yaw.add_child(camera_pitch)
	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = camera_distance
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.12
	camera_pitch.add_child(spring_arm)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 72.0
	spring_arm.add_child(camera)

func _load_ual1_mannequin() -> void:
	visual_root = Node3D.new()
	visual_root.name = "UAL1VisibleMannequin"
	add_child(visual_root)
	visual_root.rotation.y = PI if visual_flipped else 0.0
	var packed: PackedScene = load(UAL1_PATH) as PackedScene
	if packed == null:
		resource_error = "UAL1_Standard.glb missing. Run SETUP_ASSETS.bat with Godot closed."
		_missing_marker()
		return
	mannequin_scene = packed.instantiate()
	visual_root.add_child(mannequin_scene)
	_disable_animation_trees(mannequin_scene)
	animation_player = _find_best_animation_player(mannequin_scene)
	skeleton = _find_skeleton(mannequin_scene)
	if skeleton == null or animation_player == null:
		resource_error = "UAL1 mannequin Skeleton3D/AnimationPlayer not found."
		return
	animation_player.stop()
	_tint_mannequin()
	right_hand_bone = _find_hand_bone(true)
	left_hand_bone = _find_hand_bone(false)
	_build_weapons()
	animation_driver = DriverScript.new() as HopliteNativeAnimationDriver
	animation_driver.name = "NativeUALDriver"
	add_child(animation_driver)
	if not animation_driver.configure(mannequin_scene, skeleton, animation_player):
		resource_error = "Native UAL animation setup failed. Check Output."
	else:
		print("[HOPLITE LAB V2.12] persistent heavy charge across mobility ACTIVE")
		print("[HOPLITE LAB V2.12] right hand=", right_hand_bone, " left hand=", left_hand_bone)

func _missing_marker() -> void:
	var label: Label3D = Label3D.new()
	label.text = "RUN SETUP_ASSETS.bat"
	label.font_size = 48
	label.modulate = Color(1.0, 0.15, 0.05)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.5, 0)
	visual_root.add_child(label)

func _physics_process(delta: float) -> void:
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	dash_variant_grace = maxf(0.0, dash_variant_grace - delta)
	slide_slash_active_time = maxf(0.0, slide_slash_active_time - delta)

	if parkour_active:
		# Parkour owns movement while active, but CTRL is still accepted as a
		# buffered combo input. The slide starts on the exact frame the mantle/
		# vault finishes instead of being lost by this early return.
		if Input.is_action_just_pressed("slide"):
			_queue_slide_after_parkour()
		_update_parkour(delta)
		if animation_driver != null:
			animation_driver.set_locomotion(0.0)
		return

	var was_on_floor: bool = is_on_floor()

	if not is_on_floor():
		var gravity_scale: float = 1.0
		if animation_driver != null:
			var active_slot: StringName = animation_driver.current_attack_slot_name()
			var attack_context: StringName = animation_driver.current_attack_context_name()
			if active_slot == &"heavy" and attack_context == &"air":
				gravity_scale = 1.65
			elif active_slot == &"spin360" and attack_context == &"air" and animation_driver.current_attack_progress() < 0.60:
				gravity_scale = 0.34
				velocity.y = maxf(velocity.y, -2.3)
		velocity.y -= gravity * gravity_scale * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		jumps_used = 0

	# CTRL on the ground starts the slide immediately. In the air it arms the
	# slide; the slide begins on the exact landing frame, with no landing recovery.
	if Input.is_action_just_pressed("slide"):
		_request_slide()

	if Input.is_action_just_pressed("jump"):
		if _try_start_parkour():
			return
		if jumps_used < max_jumps:
			_stop_slide(true, false)
			# Heavy charge is intentionally preserved through jumps.
			var is_second_jump: bool = jumps_used == 1
			velocity.y = jump_velocity if not is_second_jump else jump_velocity * 0.92
			jumps_used += 1
			if animation_driver != null:
				# Both jumps now use the exact UAL2 NinjaJump_Start clip.
				# The second jump is slightly faster so it reads as a sharper combo beat.
				var ninja_speed: float = 1.12 if is_second_jump else 1.0
				if animation_driver.play_ninja_jump(ninja_speed) <= 0.0:
					animation_driver.play_full_body(&"jump")

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_stop_slide(false, false)
		# Heavy charge is intentionally preserved through dash.
		dash_time = dash_duration
		dash_cooldown_timer = dash_cooldown
		dash_variant_grace = 0.20
		dash_direction = _desired_move_direction()
		if dash_direction.length() < 0.05:
			var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
			dash_direction = flat_velocity.normalized() if flat_velocity.length() > 0.2 else _camera_forward_flat()
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		if animation_driver != null:
			animation_driver.stop_movement_action()
			animation_driver.play_full_body(&"dash")

	var move_dir: Vector3 = _desired_move_direction()
	var move_multiplier: float = 0.55 if heavy_charging else 1.0

	if slide_time > 0.0:
		_update_slide_motion(move_dir, delta)
	elif dash_time > 0.0:
		dash_time = maxf(0.0, dash_time - delta)
		var dash_ratio: float = dash_time / maxf(dash_duration, 0.001)
		var current_dash_speed: float = lerpf(dash_end_speed, dash_speed, dash_ratio)
		velocity.x = dash_direction.x * current_dash_speed
		velocity.z = dash_direction.z * current_dash_speed
	else:
		_update_free_movement(move_dir, move_multiplier, delta)

	if slide_time > 0.0 and slide_direction.length() > 0.05:
		_face_direction(slide_direction, delta * 1.7)
	elif _should_face_camera_for_attack():
		_face_direction(_camera_forward_flat(), delta * 2.0)
	elif dash_time > 0.0 and dash_direction.length() > 0.05:
		_face_direction(dash_direction, delta * 1.8)
	elif move_dir.length() > 0.10:
		_face_direction(move_dir, delta)

	move_and_slide()

	if not was_on_floor and is_on_floor():
		if slide_armed:
			# Exact contact-frame conversion: no Jump_Land/NinjaJump_Land is ever
			# played and horizontal momentum is immediately converted into slide.
			_start_slide(true)
		elif animation_driver != null:
			# Direct landing: kill only jump/movement overlays and let locomotion
			# pick Idle/Jog/Sprint immediately from the actual horizontal speed.
			animation_driver.stop_movement_action()
			if dash_time <= 0.0:
				animation_driver.stop_full_body()

	if slide_time > 0.0 and slide_slash_active_time > 0.0:
		_scan_slide_slash_contacts()

	if animation_driver != null:
		var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
		animation_driver.set_locomotion(clampf(horizontal_speed / max_speed, 0.0, 1.0))

func _process(delta: float) -> void:
	_update_slide_visual_height(delta)
	_update_camera(delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0 and not Input.is_action_pressed("attack_light"):
		light_step = 0
		combo_light_count = 0

	if heavy_charging:
		heavy_charge = minf(heavy_charge_max, heavy_charge + delta)
		var ratio: float = clampf(heavy_charge / heavy_charge_max, 0.0, 1.0)
		if not heavy_charge_pose_started and (not fast_heavy_candidate or heavy_charge >= 0.12):
			if animation_driver != null:
				heavy_charge_pose_started = animation_driver.begin_heavy_charge(heavy_charge_context)
		if heavy_charge_pose_started and animation_driver != null:
			animation_driver.update_heavy_charge(ratio)
		_set_sword_charge_visual(ratio)

	if spin_active_time > 0.0:
		var step: float = minf(delta, spin_active_time)
		spin_active_time -= step
		if spin_total_time > 0.001:
			rotate_y((spin_rotation_total / spin_total_time) * step)

	if animation_driver != null:
		animation_driver.tick(delta)
		if animation_driver.is_attack_active() and not animation_driver.is_heavy_charging() and sword_tip != null and sword_trail != null:
			sword_trail.push_point(sword_tip.global_position, animation_driver.current_attack_is_heavy())
	_update_debug_text()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		camera_yaw.rotation.y -= motion.relative.x * mouse_sensitivity
		camera_pitch_value = clampf(camera_pitch_value - motion.relative.y * mouse_sensitivity, -1.05, 0.50)
		camera_pitch.rotation.x = camera_pitch_value
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(2.8, camera_distance - 0.35)
			spring_arm.spring_length = camera_distance
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(7.5, camera_distance + 0.35)
			spring_arm.spring_length = camera_distance

	if parkour_active:
		return

	if event.is_action_pressed("attack_light"):
		_do_light_attack()
	if event.is_action_pressed("spin_attack"):
		_do_spin_attack()
	if event.is_action_pressed("attack_heavy"):
		_begin_heavy_input()
	if event.is_action_released("attack_heavy") and heavy_charging:
		_release_heavy_attack()

	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_F2:
				visual_flipped = not visual_flipped
				if visual_root != null:
					visual_root.rotation.y = PI if visual_flipped else 0.0
			KEY_F3:
				_cycle_sword_preset()
			KEY_F4:
				shield_visible = not shield_visible
				if shield_attachment != null:
					shield_attachment.visible = shield_visible
			KEY_PAGEUP:
				if animation_driver != null:
					animation_driver.preview_next()
			KEY_PAGEDOWN:
				if animation_driver != null:
					animation_driver.preview_prev()
			KEY_ENTER, KEY_KP_ENTER:
				if animation_driver != null:
					animation_driver.preview_play()
			KEY_1:
				if animation_driver != null: animation_driver.assign_preview_to_slot(&"light1")
			KEY_2:
				if animation_driver != null: animation_driver.assign_preview_to_slot(&"light2")
			KEY_3:
				if animation_driver != null: animation_driver.assign_preview_to_slot(&"light3")
			KEY_4:
				if animation_driver != null: animation_driver.assign_preview_to_slot(&"heavy")
			KEY_5:
				if animation_driver != null: animation_driver.assign_preview_to_slot(&"spin360")

func _do_light_attack() -> void:
	if animation_driver == null or heavy_charging:
		return

	var context: StringName = _combat_context()
	if context != &"slide":
		_face_direction(_camera_forward_flat(), 0.08)

	if combo_timer <= 0.0:
		light_step = 0
		combo_light_count = 0
	var next_step: int = (light_step % 3) + 1
	var slot: StringName = StringName("light%d" % next_step)

	# Slide attacks deliberately stay upper-body weighted: the legs keep the slide
	# pose while the sword gets its own low/wide contextual slash variant.
	var full_body: bool = context == &"air" or context == &"dash"
	var custom_speed: float = 1.22 if context == &"slide" else -1.0
	var custom_blend: float = 0.035 if context == &"slide" else -1.0
	var hips_weight: float = 0.42 if context == &"slide" else -1.0

	if animation_driver.request_attack_variant(slot, context, full_body, custom_speed, custom_blend, hips_weight):
		light_step = next_step
		combo_light_count = mini(3, combo_light_count + 1)
		combo_timer = 1.05
		if context == &"dash":
			var forward: Vector3 = _camera_forward_flat()
			_add_horizontal_impulse(forward, 2.2, dash_speed)
		elif context == &"slide":
			slide_slash_active_time = maxf(slide_slash_active_time, minf(maxf(slide_time, 0.10), 0.28))
			slide_slash_contacts.clear()

func _begin_heavy_input() -> void:
	if animation_driver == null or heavy_charging:
		return
	# Heavy can begin while running, airborne, dashing or sliding. Movement owns
	# the lower body while the held charge remains an upper-body combat layer.
	heavy_charging = true
	heavy_charge = 0.0
	heavy_charge_context = _combat_context()
	fast_heavy_candidate = combo_timer > 0.0 and combo_light_count >= 2
	heavy_charge_pose_started = false
	if not fast_heavy_candidate:
		heavy_charge_pose_started = animation_driver.begin_heavy_charge(heavy_charge_context)

func _release_heavy_attack() -> void:
	if animation_driver == null:
		_cancel_heavy_charge()
		return
	_face_direction(_camera_forward_flat(), 0.09)
	var ratio: float = clampf(heavy_charge / heavy_charge_max, 0.0, 1.0)
	var context: StringName = _combat_context()
	var fast_combo: bool = fast_heavy_candidate and heavy_charge <= 0.28
	var played: bool = false
	if heavy_charge_pose_started:
		played = animation_driver.release_heavy_charge(context, ratio, fast_combo)
	else:
		played = animation_driver.play_attack_variant(&"heavy", context, context == &"air" or context == &"dash", 1.48 if fast_combo else -1.0, 0.04 if fast_combo else -1.0, -1.0, fast_combo)

	if played:
		var forward: Vector3 = _camera_forward_flat()
		var impulse: float = (4.7 if fast_combo else lerpf(3.0, 7.4, ratio))
		var heavy_speed_cap: float = dash_speed if context == &"dash" else max_speed + (2.6 if fast_combo else lerpf(2.0, 4.0, ratio))
		_add_horizontal_impulse(forward, impulse, heavy_speed_cap)
		if context == &"air":
			velocity.y = minf(velocity.y, -4.0 - ratio * 4.8)
		_spawn_heavy_shockwave(ratio, fast_combo)

	heavy_charging = false
	heavy_charge_pose_started = false
	heavy_charge = 0.0
	fast_heavy_candidate = false
	combo_timer = 0.0
	combo_light_count = 0
	_set_sword_charge_visual(0.0)

func _cancel_heavy_charge() -> void:
	if not heavy_charging:
		return
	heavy_charging = false
	heavy_charge_pose_started = false
	heavy_charge = 0.0
	fast_heavy_candidate = false
	if animation_driver != null:
		animation_driver.cancel_heavy_charge()
	_set_sword_charge_visual(0.0)

func _do_spin_attack() -> void:
	if animation_driver == null or heavy_charging:
		return
	_face_direction(_camera_forward_flat(), 0.06)
	var context: StringName = _combat_context()
	var combo_fast: bool = combo_timer > 0.0 and combo_light_count > 0
	var speed: float = 1.24 if combo_fast else -1.0
	if animation_driver.play_attack_variant(&"spin360", context, true, speed, 0.045 if combo_fast else -1.0, 1.0, combo_fast):
		spin_total_time = maxf(0.38, animation_driver.current_attack_length() * 0.88)
		spin_active_time = spin_total_time
		spin_rotation_total = TAU * (1.20 if context == &"air" else 1.0)
		if context == &"air":
			velocity.y = maxf(velocity.y, 0.9)
		elif context == &"dash":
			var forward: Vector3 = _camera_forward_flat()
			_add_horizontal_impulse(forward, 2.4, dash_speed)
	combo_timer = 0.0
	combo_light_count = 0

func _combat_context() -> StringName:
	if slide_time > 0.0:
		return &"slide"
	if dash_time > 0.0 or dash_variant_grace > 0.0:
		return &"dash"
	if not is_on_floor():
		return &"air"
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 2.8:
		return &"run"
	return &"idle"

func _should_face_camera_for_attack() -> bool:
	if slide_time > 0.0:
		return false
	return heavy_charging or (animation_driver != null and animation_driver.is_attack_active())

func _ensure_slide_input_action() -> void:
	if not InputMap.has_action("slide"):
		InputMap.add_action("slide")
	for existing: InputEvent in InputMap.action_get_events("slide"):
		if existing is InputEventKey:
			var key_event: InputEventKey = existing as InputEventKey
			if key_event.keycode == KEY_CTRL:
				return
	var ctrl_event: InputEventKey = InputEventKey.new()
	ctrl_event.keycode = KEY_CTRL
	InputMap.action_add_event("slide", ctrl_event)

func _dash_nominal_distance() -> float:
	return ((dash_speed + dash_end_speed) * 0.5) * dash_duration

func _slide_speed() -> float:
	return dash_speed * slide_speed_ratio

func _slide_duration() -> float:
	return (_dash_nominal_distance() * slide_distance_ratio) / maxf(_slide_speed(), 0.001)

func _request_slide() -> void:
	if parkour_active or slide_time > 0.0 or slide_armed:
		return

	# Entering/arming a slide does not cancel an already-held heavy charge.
	dash_time = 0.0
	dash_variant_grace = 0.0

	var wanted: Vector3 = _desired_move_direction()
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if wanted.length() > 0.05:
		slide_direction = wanted
	elif flat_velocity.length() > 0.20:
		slide_direction = flat_velocity.normalized()
	else:
		slide_direction = _camera_forward_flat()

	if is_on_floor():
		_start_slide(false)
	else:
		slide_armed = true

func _start_slide(from_air: bool) -> void:
	slide_armed = false
	slide_time = _slide_duration()

	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if from_air and flat_velocity.length() > 0.20:
		slide_direction = flat_velocity.normalized()
	elif slide_direction.length() < 0.05:
		slide_direction = _desired_move_direction()
		if slide_direction.length() < 0.05:
			slide_direction = _camera_forward_flat()
	slide_direction.y = 0.0
	slide_direction = slide_direction.normalized()

	var speed: float = _slide_speed()
	velocity.x = slide_direction.x * speed
	velocity.z = slide_direction.z * speed

	if animation_driver != null:
		animation_driver.start_slide_visual(_slide_duration())

func _stop_slide(_preserve_momentum: bool = true, play_exit: bool = true) -> void:
	# Always notify the animation driver. Previously _update_slide_motion() could
	# reduce slide_time to zero first, making this function think no slide was
	# active and leaving the UAL2 Slide loop stuck forever.
	slide_time = 0.0
	slide_armed = false
	slide_slash_active_time = 0.0
	slide_slash_contacts.clear()
	if animation_driver != null:
		if play_exit:
			animation_driver.finish_slide_visual()
		else:
			animation_driver.cancel_slide_visual()

func _update_slide_motion(move_dir: Vector3, delta: float) -> void:
	slide_time = maxf(0.0, slide_time - delta)
	if move_dir.length() > 0.05:
		slide_direction = _steer_flat_direction(slide_direction, move_dir, slide_turn_response, delta)

	var speed: float = _slide_speed()
	velocity.x = slide_direction.x * speed
	velocity.z = slide_direction.z * speed

	if slide_time <= 0.0:
		_stop_slide(true, true)

func _update_slide_visual_height(delta: float) -> void:
	if visual_root == null:
		return
	var target_y: float = -slide_visual_drop if slide_time > 0.0 else 0.0
	visual_root.position.y = move_toward(
		visual_root.position.y,
		target_y,
		slide_visual_vertical_speed * delta
	)

func _update_free_movement(move_dir: Vector3, move_multiplier: float, delta: float) -> void:
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = flat_velocity.length()

	if move_dir.length() > 0.05:
		var target_speed: float = max_speed * move_multiplier
		var speed_rate: float = acceleration if is_on_floor() else air_acceleration
		var next_speed: float = current_speed

		if current_speed < target_speed:
			next_speed = move_toward(current_speed, target_speed, speed_rate * delta)
		elif current_speed > target_speed:
			# Overspeed from attacks/dash bleeds off, but steering itself never
			# reduces magnitude. This keeps movement-combo momentum readable.
			var overspeed_rate: float = deceleration if is_on_floor() else air_acceleration
			next_speed = move_toward(current_speed, target_speed, overspeed_rate * delta)

		var current_dir: Vector3 = move_dir
		if current_speed > 0.05:
			current_dir = flat_velocity / current_speed
		var response: float = movement_turn_response if is_on_floor() else air_turn_response
		var steered: Vector3 = _steer_flat_direction(current_dir, move_dir, response, delta)
		velocity.x = steered.x * next_speed
		velocity.z = steered.z * next_speed
	else:
		var next_speed: float = move_toward(current_speed, 0.0, deceleration * delta)
		if current_speed > 0.001:
			var coast_dir: Vector3 = flat_velocity / current_speed
			velocity.x = coast_dir.x * next_speed
			velocity.z = coast_dir.z * next_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0

func _steer_flat_direction(from_dir: Vector3, to_dir: Vector3, response: float, delta: float) -> Vector3:
	var a: Vector3 = from_dir
	var b: Vector3 = to_dir
	a.y = 0.0
	b.y = 0.0
	if b.length() < 0.001:
		return a.normalized() if a.length() > 0.001 else Vector3.ZERO
	if a.length() < 0.001:
		return b.normalized()
	a = a.normalized()
	b = b.normalized()
	var weight: float = clampf(1.0 - exp(-response * delta), 0.0, 1.0)
	var from_angle: float = atan2(a.x, a.z)
	var to_angle: float = atan2(b.x, b.z)
	var angle: float = lerp_angle(from_angle, to_angle, weight)
	return Vector3(sin(angle), 0.0, cos(angle)).normalized()

func _scan_slide_slash_contacts() -> void:
	if get_world_3d() == null:
		return

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = slide_slash_radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.82 + slide_direction * 0.36)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var excluded: Array[RID] = []
	excluded.append(get_rid())
	query.exclude = excluded

	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 32)
	for hit: Dictionary in hits:
		var collider: Node = hit.get("collider") as Node
		var target: Node = _resolve_slide_slash_target(collider)
		if target == null or target == self:
			continue
		var id: int = target.get_instance_id()
		if slide_slash_contacts.has(id):
			continue
		slide_slash_contacts[id] = true
		slide_slash_contact.emit(target)
		if target.has_method("on_slide_slash"):
			target.call("on_slide_slash", self)

func _resolve_slide_slash_target(collider: Node) -> Node:
	var current: Node = collider
	var depth: int = 0
	while current != null and depth < 5:
		if current.is_in_group("damageable") or current.has_method("on_slide_slash"):
			return current
		current = current.get_parent()
		depth += 1
	return null

func _add_horizontal_impulse(direction: Vector3, impulse: float, speed_cap: float) -> void:
	var flat_direction: Vector3 = direction
	flat_direction.y = 0.0
	if flat_direction.length() < 0.001:
		return
	flat_direction = flat_direction.normalized()

	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	flat_velocity += flat_direction * impulse

	var cap: float = maxf(0.0, speed_cap)
	if cap > 0.0 and flat_velocity.length() > cap:
		flat_velocity = flat_velocity.normalized() * cap

	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z

func _try_start_parkour() -> bool:
	if get_world_3d() == null:
		parkour_debug_reason = "no world"
		return false

	var direction: Vector3 = _desired_move_direction()
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if direction.length() < 0.05 and flat_velocity.length() > 0.20:
		direction = flat_velocity.normalized()
	if direction.length() < 0.05:
		direction = _camera_forward_flat()
	direction.y = 0.0
	direction = direction.normalized()

	var wall_hit: Dictionary = _find_parkour_wall(direction)
	if wall_hit.is_empty():
		parkour_debug_reason = "no wall in probe"
		return false

	var wall_normal: Vector3 = wall_hit.get("normal", Vector3.ZERO)
	if absf(wall_normal.dot(Vector3.UP)) > 0.55:
		parkour_debug_reason = "surface is not a wall"
		return false

	var wall_point: Vector3 = wall_hit.get("position", global_position + direction * parkour_probe_distance)
	var top_info: Dictionary = _find_parkour_top(wall_point, direction)
	if top_info.is_empty():
		parkour_debug_reason = "top surface not found"
		return false

	var top_point: Vector3 = top_info.get("point", Vector3.ZERO)
	var top_depth: float = float(top_info.get("depth", 0.25))
	var obstacle_height: float = top_point.y - global_position.y
	if obstacle_height < parkour_min_height or obstacle_height > parkour_max_height:
		parkour_debug_reason = "height %.2f outside %.2f..%.2f" % [obstacle_height, parkour_min_height, parkour_max_height]
		return false

	var extent: Dictionary = _find_parkour_top_extent(wall_point, direction, top_point.y, top_depth)
	var last_top_depth: float = float(extent.get("last_depth", top_depth))
	var edge_depth: float = float(extent.get("edge_depth", last_top_depth + 0.25))

	if obstacle_height <= parkour_vault_max_height:
		var landing: Vector3 = _find_vault_landing(wall_point, direction, edge_depth, top_point.y)
		if landing == Vector3.ZERO:
			parkour_debug_reason = "no safe landing behind vault"
			return false
		var travel_distance: float = Vector2(landing.x - global_position.x, landing.z - global_position.z).length()
		var vault_duration: float = clampf(travel_distance / maxf(max_speed * 1.25, 0.1), 0.34, 0.58)
		var vault_arc: float = maxf(0.58, obstacle_height + 0.30)
		_begin_parkour(&"vault", landing, vault_duration, vault_arc, direction)
		parkour_debug_reason = "vault %.2fm" % obstacle_height
	else:
		var usable_depth: float = maxf(top_depth, last_top_depth - 0.18)
		var mantle_depth: float = minf(top_depth + 0.55, usable_depth)
		var climb_end: Vector3 = wall_point + direction * mantle_depth
		climb_end.y = top_point.y + 0.055
		if not _parkour_has_headroom(climb_end):
			parkour_debug_reason = "mantle blocked above"
			return false
		var climb_duration: float = remap(clampf(obstacle_height, parkour_vault_max_height, parkour_max_height), parkour_vault_max_height, parkour_max_height, 0.52, 0.88)
		_begin_parkour(&"climb", climb_end, climb_duration, 0.18, direction)
		parkour_debug_reason = "mantle %.2fm" % obstacle_height
	return true

func _find_parkour_wall(direction: Vector3) -> Dictionary:
	var best_hit: Dictionary = {}
	var best_distance: float = INF
	var probe_heights: Array[float] = [0.32, 0.58, 0.86, 1.12]
	for height: float in probe_heights:
		var from_point: Vector3 = global_position + Vector3.UP * height
		var hit: Dictionary = _raycast_world(from_point, from_point + direction * parkour_probe_distance)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if absf(normal.dot(Vector3.UP)) > 0.62:
			continue
		var hit_point: Vector3 = hit.get("position", from_point + direction * parkour_probe_distance)
		var distance: float = global_position.distance_to(hit_point)
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit

func _find_parkour_top(wall_point: Vector3, direction: Vector3) -> Dictionary:
	var depths: Array[float] = [0.10, 0.22, 0.36, 0.52, 0.72, 0.96, 1.24]
	for depth: float in depths:
		var sample: Vector3 = wall_point + direction * depth
		var from_point: Vector3 = Vector3(sample.x, global_position.y + parkour_max_height + 0.70, sample.z)
		var to_point: Vector3 = Vector3(sample.x, global_position.y + parkour_min_height - 0.10, sample.z)
		var hit: Dictionary = _raycast_world(from_point, to_point)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if normal.dot(Vector3.UP) < 0.68:
			continue
		var point: Vector3 = hit.get("position", Vector3.ZERO)
		var height: float = point.y - global_position.y
		if height >= parkour_min_height and height <= parkour_max_height:
			return {"point": point, "depth": depth}
	return {}

func _find_parkour_top_extent(wall_point: Vector3, direction: Vector3, top_y: float, start_depth: float) -> Dictionary:
	var last_depth: float = start_depth
	var edge_depth: float = start_depth + 0.30
	var step: float = 0.20
	var max_depth: float = 3.20
	var depth: float = start_depth + step

	while depth <= max_depth:
		var sample: Vector3 = wall_point + direction * depth
		var from_point: Vector3 = Vector3(sample.x, top_y + 0.42, sample.z)
		var to_point: Vector3 = Vector3(sample.x, top_y - 0.34, sample.z)
		var hit: Dictionary = _raycast_world(from_point, to_point)
		var same_top: bool = false
		if not hit.is_empty():
			var normal: Vector3 = hit.get("normal", Vector3.ZERO)
			var point: Vector3 = hit.get("position", Vector3.ZERO)
			same_top = normal.dot(Vector3.UP) >= 0.68 and absf(point.y - top_y) <= 0.22
		if not same_top:
			edge_depth = depth
			break
		last_depth = depth
		edge_depth = depth + step
		depth += step

	return {"last_depth": last_depth, "edge_depth": edge_depth}

func _find_vault_landing(wall_point: Vector3, direction: Vector3, edge_depth: float, top_y: float) -> Vector3:
	var extras: Array[float] = [0.42, 0.68, 0.94, 1.20]
	for extra: float in extras:
		var sample: Vector3 = wall_point + direction * (edge_depth + extra)
		var from_point: Vector3 = Vector3(sample.x, top_y + 1.35, sample.z)
		var to_point: Vector3 = Vector3(sample.x, global_position.y - 1.60, sample.z)
		var hit: Dictionary = _raycast_world(from_point, to_point)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var point: Vector3 = hit.get("position", Vector3.ZERO)
		if normal.dot(Vector3.UP) >= 0.68 and point.y <= top_y - 0.18:
			return point + Vector3.UP * 0.055
	return Vector3.ZERO

func _parkour_has_headroom(end_position: Vector3) -> bool:
	var from_point: Vector3 = end_position + Vector3.UP * 0.18
	var to_point: Vector3 = end_position + Vector3.UP * 1.90
	return _raycast_world(from_point, to_point).is_empty()

func _queue_slide_after_parkour() -> void:
	if not parkour_active or parkour_slide_queued:
		return

	parkour_slide_queued = true

	var requested_direction: Vector3 = _desired_move_direction()
	if requested_direction.length() > 0.05:
		slide_direction = requested_direction
	elif parkour_exit_direction.length() > 0.05:
		slide_direction = parkour_exit_direction
	else:
		slide_direction = _camera_forward_flat()

	parkour_debug_reason = "slide buffered"

func _begin_parkour(kind: StringName, end_position: Vector3, duration: float, arc: float, direction: Vector3) -> void:
	# Parkour is the one movement state that intentionally breaks a heavy charge.
	# Do it only after a valid vault/mantle has actually been accepted.
	_cancel_heavy_charge()
	_stop_slide(false, false)
	dash_time = 0.0
	dash_variant_grace = 0.0
	parkour_active = true
	parkour_kind = kind
	parkour_elapsed = 0.0
	parkour_duration = maxf(duration, 0.2)
	parkour_start = global_position
	parkour_end = end_position
	parkour_arc = arc
	parkour_exit_direction = direction.normalized()
	parkour_slide_queued = false
	velocity = Vector3.ZERO
	if animation_driver != null:
		animation_driver.stop_full_body()
		if not animation_driver.play_donor_action(kind, 1.08):
			animation_driver.play_full_body(&"jump")

func _update_parkour(delta: float) -> void:
	parkour_elapsed += delta
	var t: float = clampf(parkour_elapsed / parkour_duration, 0.0, 1.0)

	if parkour_kind == &"climb":
		# Mantle rises early and translates over the lip later. This reads like a
		# pull-up instead of interpolating straight through the obstacle.
		var lift_t: float = smoothstep(0.0, 0.70, t)
		var forward_t: float = smoothstep(0.12, 1.0, t)
		var p: Vector3 = parkour_start
		p.x = lerpf(parkour_start.x, parkour_end.x, forward_t)
		p.z = lerpf(parkour_start.z, parkour_end.z, forward_t)
		p.y = lerpf(parkour_start.y, parkour_end.y, lift_t) + sin(t * PI) * parkour_arc
		global_position = p
	else:
		var eased: float = smoothstep(0.0, 1.0, t)
		var base: Vector3 = parkour_start.lerp(parkour_end, eased)
		global_position = base + Vector3.UP * (sin(t * PI) * parkour_arc)

	if parkour_exit_direction.length() > 0.05:
		_face_direction(parkour_exit_direction, delta * 2.8)

	# A buffered slide should feel like a direct movement combo, not mantle ->
	# pause -> slide. For climbs, once ~80% of the mantle is complete the body is
	# already over the lip, so finish the last few centimetres immediately and
	# give control to the slide. Vaults keep almost their complete authored arc.
	var slide_exit_progress: float = parkour_slide_early_exit_progress if parkour_kind == &"climb" else 0.96
	if parkour_slide_queued and t >= slide_exit_progress:
		global_position = parkour_end
		parkour_debug_reason = "early exit -> buffered slide"
		_finish_parkour()
		return

	if t >= 1.0:
		_finish_parkour()

func _finish_parkour() -> void:
	# End parkour with NO inherited forward impulse. No input after a climb means
	# the player stays exactly on the ledge.
	parkour_active = false
	parkour_kind = StringName()
	jumps_used = 0
	velocity = Vector3.ZERO

	# Stop the retargeted parkour donor immediately as well. Otherwise the
	# authored clip can visually keep taking a final step after mechanics stop.
	if animation_driver != null:
		animation_driver.stop_movement_action()

	var queued_slide: bool = parkour_slide_queued
	parkour_slide_queued = false

	if queued_slide:
		# CTRL during the climb is a combo buffer. Prefer the direction currently
		# held by the player; otherwise continue over the climbed lip.
		var requested_direction: Vector3 = _desired_move_direction()
		if requested_direction.length() > 0.05:
			slide_direction = requested_direction
		elif parkour_exit_direction.length() > 0.05:
			slide_direction = parkour_exit_direction
		else:
			slide_direction = _camera_forward_flat()
		parkour_debug_reason = "exit -> buffered slide"
		_start_slide(false)
	else:
		# Normal exit deliberately remains still. On the next physics frame the
		# regular locomotion code reads live input; no input means no movement.
		parkour_debug_reason = "exit -> player control"

func _raycast_world(from_point: Vector3, to_point: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = from_point
	query.to = to_point
	query.collision_mask = 1
	var excluded: Array[RID] = []
	excluded.append(get_rid())
	query.exclude = excluded
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)

func _spawn_heavy_shockwave(charge: float, fast_combo: bool) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var forward: Vector3 = _camera_forward_flat()
	var root: Node3D = Node3D.new()
	root.name = "HeavyShockwave"
	scene.add_child(root)
	root.global_position = global_position + Vector3.UP * 0.08 + forward * 1.05
	root.rotation.y = rotation.y

	var wave: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = 0.035
	mesh.top_radius = 0.85
	mesh.bottom_radius = 0.85
	wave.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.12, 0.02, 0.58)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.025, 0.005) * (0.55 + charge * 1.6)
	mat.roughness = 0.2
	wave.material_override = mat
	root.add_child(wave)
	root.scale = Vector3(0.28, 0.24, 0.12)

	var distance: float = 3.8 if fast_combo else lerpf(4.5, 8.0, charge)
	var width: float = 1.55 if fast_combo else lerpf(1.8, 4.6, charge)
	var length_scale: float = 0.85 if fast_combo else lerpf(1.0, 2.1, charge)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "global_position", root.global_position + forward * distance, 0.34)
	tween.tween_property(root, "scale", Vector3(width, 0.22, length_scale), 0.34)
	tween.tween_property(mat, "albedo_color", Color(1.0, 0.04, 0.01, 0.0), 0.34)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)

func _set_sword_charge_visual(ratio: float) -> void:
	if sword_blade_material == null:
		return
	var t: float = clampf(ratio, 0.0, 1.0)
	sword_blade_material.albedo_color = sword_base_color.lerp(Color(1.0, 0.015, 0.005), t)
	sword_blade_material.emission_enabled = t > 0.01
	sword_blade_material.emission = Color(1.0, 0.01, 0.002) * (t * 1.65)

func _desired_move_direction() -> Vector3:
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward: Vector3 = _camera_forward_flat()
	var right: Vector3 = _camera_right_flat()
	var result: Vector3 = right * input_vec.x + forward * -input_vec.y
	return result.normalized() if result.length() > 0.001 else Vector3.ZERO

func _camera_forward_flat() -> Vector3:
	if camera_yaw == null:
		return -global_basis.z.normalized()
	var forward: Vector3 = -camera_yaw.global_basis.z
	forward.y = 0.0
	return forward.normalized()

func _camera_right_flat() -> Vector3:
	if camera_yaw == null:
		return global_basis.x.normalized()
	var right: Vector3 = camera_yaw.global_basis.x
	right.y = 0.0
	return right.normalized()

func _face_direction(direction: Vector3, delta_or_amount: float) -> void:
	var flat: Vector3 = direction
	flat.y = 0.0
	if flat.length() < 0.001:
		return
	var target_yaw: float = atan2(-flat.x, -flat.z)
	var amount: float = clampf(turn_speed * delta_or_amount, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, amount)

func _update_camera(delta: float) -> void:
	if camera_yaw == null:
		return
	var target: Vector3 = global_position + Vector3(0.0, 1.55, 0.0)

	# Horizontal lag made dash/attack speed spikes look like the character was
	# shooting away from the screen centre and then snapping back afterward.
	camera_yaw.global_position.x = target.x
	camera_yaw.global_position.z = target.z
	camera_yaw.global_position.y = lerpf(
		camera_yaw.global_position.y,
		target.y,
		1.0 - exp(-14.0 * delta)
	)

func _build_weapons() -> void:
	if right_hand_bone != "":
		sword_attachment = BoneAttachment3D.new()
		sword_attachment.name = "SwordAttachment"
		sword_attachment.bone_name = right_hand_bone
		skeleton.add_child(sword_attachment)
		sword_root = _make_sword()
		sword_attachment.add_child(sword_root)
		sword_trail = TrailScript.new() as HopliteNativeSwordTrail
		sword_trail.name = "SwordTrail"
		get_tree().current_scene.add_child(sword_trail)
	if left_hand_bone != "":
		shield_attachment = BoneAttachment3D.new()
		shield_attachment.name = "ShieldAttachment"
		shield_attachment.bone_name = left_hand_bone
		skeleton.add_child(shield_attachment)
		shield_attachment.add_child(_make_shield())

func _make_sword() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Xiphos"
	var bronze: StandardMaterial3D = StandardMaterial3D.new()
	bronze.albedo_color = Color(0.33, 0.16, 0.05)
	bronze.metallic = 0.5
	bronze.roughness = 0.35
	sword_blade_material = StandardMaterial3D.new()
	sword_blade_material.albedo_color = sword_base_color
	sword_blade_material.metallic = 0.82
	sword_blade_material.roughness = 0.22
	var blade: MeshInstance3D = MeshInstance3D.new()
	var blade_mesh: BoxMesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.065, 0.92, 0.025)
	blade.mesh = blade_mesh
	blade.position.y = 0.55
	blade.material_override = sword_blade_material
	root.add_child(blade)
	var guard: MeshInstance3D = MeshInstance3D.new()
	var guard_mesh: BoxMesh = BoxMesh.new()
	guard_mesh.size = Vector3(0.30, 0.055, 0.06)
	guard.mesh = guard_mesh
	guard.position.y = 0.07
	guard.material_override = bronze
	root.add_child(guard)
	var grip: MeshInstance3D = MeshInstance3D.new()
	var grip_mesh: CylinderMesh = CylinderMesh.new()
	grip_mesh.height = 0.28
	grip_mesh.top_radius = 0.04
	grip_mesh.bottom_radius = 0.05
	grip.mesh = grip_mesh
	grip.position.y = -0.10
	grip.material_override = bronze
	root.add_child(grip)
	sword_tip = Marker3D.new()
	sword_tip.position = Vector3(0.0, 1.03, 0.0)
	root.add_child(sword_tip)
	_apply_sword_preset(root)
	return root

func _make_shield() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Aspis"
	var shield: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = 0.09
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.48
	shield.mesh = mesh
	shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.025, 0.018)
	material.metallic = 0.48
	material.roughness = 0.38
	shield.material_override = material
	root.add_child(shield)
	root.position = Vector3(0.0, 0.0, 0.04)
	return root

func _cycle_sword_preset() -> void:
	sword_preset = (sword_preset + 1) % 6
	if sword_root != null:
		_apply_sword_preset(sword_root)

func _apply_sword_preset(root: Node3D) -> void:
	var rotations: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(0, 0, -90),
		Vector3(90, 0, 0),
		Vector3(-90, 0, 0),
		Vector3(0, 90, 0),
		Vector3(0, -90, 90)
	]
	root.rotation_degrees = rotations[sword_preset]
	root.position = Vector3.ZERO

func _find_hand_bone(right: bool) -> String:
	var desired_side: String = "r" if right else "l"
	var best_name: String = ""
	var best_score: int = -999
	for i: int in range(skeleton.get_bone_count()):
		var bone: String = skeleton.get_bone_name(i)
		var low: String = bone.to_lower()
		var compact: String = low.replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
		var score: int = 0
		if "hand" in compact:
			score += 30
		if "wrist" in compact:
			score += 12
		if "finger" in compact or "thumb" in compact:
			score -= 30
		var side: String = _bone_side(bone)
		if side == desired_side:
			score += 45
		elif side != "":
			score -= 60
		if score > best_score:
			best_score = score
			best_name = bone
	return best_name if best_score >= 25 else ""

func _bone_side(raw: String) -> String:
	var s: String = raw.to_lower()
	if ".r" in s or "_r" in s or "-r" in s or "right" in s:
		return "r"
	if ".l" in s or "_l" in s or "-l" in s or "left" in s:
		return "l"
	var compact: String = s.replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
	if compact.ends_with("r"):
		return "r"
	if compact.ends_with("l"):
		return "l"
	return ""

func _tint_mannequin() -> void:
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.48, 0.025, 0.018)
	red.roughness = 0.62
	red.metallic = 0.05
	_override_mesh_materials(mannequin_scene, red)

func _override_mesh_materials(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child: Node in node.get_children():
		_override_mesh_materials(child, material)

func _disable_animation_trees(node: Node) -> void:
	if node is AnimationTree:
		(node as AnimationTree).active = false
	for child: Node in node.get_children():
		_disable_animation_trees(child)

func _find_best_animation_player(root: Node) -> AnimationPlayer:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	var best: AnimationPlayer = null
	var count_best: int = -1
	for p: AnimationPlayer in players:
		var count: int = p.get_animation_list().size()
		if count > count_best:
			count_best = count
			best = p
	return best

func _collect_animation_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for child: Node in node.get_children():
		_collect_animation_players(child, out)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var result: Skeleton3D = _find_skeleton(child)
		if result != null:
			return result
	return null

func _update_debug_text() -> void:
	var status: String = animation_driver.debug_summary() if animation_driver != null else "UAL NATIVE=OFF"
	var charge_pct: int = int(clampf(heavy_charge / heavy_charge_max, 0.0, 1.0) * 100.0)
	var movement_state: String = "PARKOUR:" + String(parkour_kind) + ("+SLIDE" if parkour_slide_queued else "") if parkour_active else ("SLIDE_ARMED" if slide_armed else String(_combat_context()).to_upper())
	var slide_y: float = visual_root.position.y if visual_root != null else 0.0
	debug_text = "V2.12  STATE=%s  speed=%.2f  slideY=%.2f  comboLights=%d  charge=%d%%\n%s\nSPACE x2=NinjaJump_Start • landing=direct locomotion • air+CTRL=slide on contact\nHeavy charge survives jump/dash/slide • parkour cancels charge • CTRL parkour=early slide • parkourProbe=%s" % [movement_state, Vector2(velocity.x, velocity.z).length(), slide_y, combo_light_count, charge_pct, status, parkour_debug_reason]
	if resource_error != "":
		debug_text += "\nERROR: " + resource_error
