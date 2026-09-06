extends Node
class_name HopliteCombatFeedback

signal audio_cue_requested(cue: StringName, zone: StringName, intensity: float)
signal vfx_cue_requested(cue: StringName, position: Vector3, direction: Vector3, intensity: float)
signal cinematic_started(kind: StringName, intensity: float)

const BASE_FOV: float = 72.0
const EPIC_RUN_MIN_PRESENTATION: float = 0.20
const GIANT_RUN_ACCENT: Color = Color(1.0, 0.42, 0.10, 1.0)
const SHIELD_RUN_ACCENT: Color = Color(0.28, 0.80, 1.0, 1.0)

var feedback_camera: Camera3D
var owner_body: Node3D
var camera_rest_h_offset: float = 0.0
var camera_rest_v_offset: float = 0.0
var camera_kick: Vector3 = Vector3.ZERO
var fov_offset: float = 0.0
var cinematic_active: bool = false
var cinematic_elapsed: float = 0.0
var cinematic_duration: float = 0.46
var cinematic_side: float = 1.0
var cinematic_cooldown_until_ms: int = 0
var perfect_response_active: bool = false
var perfect_response_consumed: bool = false
var perfect_response_elapsed: float = 0.0
var perfect_response_duration: float = 0.92
var perfect_response_side: float = 1.0
var skill_time_scale := 1.0
var skill_fov := 0.0
var skill_rotation := Vector3.ZERO
var time_effect_owned: bool = false
var previous_ticks_usec: int = 0
var transient_nodes: Array[Dictionary] = []
var wall_run_contact_active: bool = false
var wall_run_surface_kind: StringName = &"world"
var wall_run_mode: StringName = StringName()
var wall_run_side: float = 0.0
var wall_run_side_target: float = 0.0
var wall_run_envelope: float = 0.0
var wall_run_phase: float = 0.0
var wall_run_orientation_blend: Vector3 = Vector3.RIGHT
var epic_run_kind: StringName = StringName()
var epic_run_contact_active: bool = false
var epic_run_elapsed: float = 0.0
var epic_run_envelope: float = 0.0
var shield_camera_height: float = 0.10
var shield_camera_distance: float = 3.0
var shield_camera_pitch: float = 6.5
var shield_fov_zoom: float = 6.0
var shield_time_scale: float = 0.90
var shield_transition_duration: float = 0.30
var giant_camera_height: float = 0.10
var giant_camera_distance: float = 3.0
var giant_camera_pitch: float = 22.0
var giant_fov_zoom: float = 4.0
var giant_time_scale: float = 0.70
var giant_transition_duration: float = 0.40
var epic_run_hud: CanvasLayer
var epic_run_hud_root: Control
var epic_run_tint: ColorRect
var epic_run_left_edge: ColorRect
var epic_run_right_edge: ColorRect
var epic_run_panel: PanelContainer
var epic_run_panel_style: StyleBoxFlat
var epic_run_label: Label
var epic_run_subtitle: Label
var epic_run_accent: Color = GIANT_RUN_ACCENT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_ticks_usec = Time.get_ticks_usec()
	_build_epic_run_hud()

func configure(camera_node: Camera3D, body: Node3D) -> void:
	feedback_camera = camera_node
	owner_body = body
	if feedback_camera != null:
		# Camera3D is a direct child of SpringArm3D. The spring arm owns its local
		# position, so cinematic framing must use camera offsets; writing position
		# here would collapse the arm every frame and turn the TPS view into an FPS.
		camera_rest_h_offset = feedback_camera.h_offset
		camera_rest_v_offset = feedback_camera.v_offset
		feedback_camera.fov = BASE_FOV

func configure_epic_wall_run_settings(settings: Dictionary) -> void:
	shield_camera_height = clampf(float(settings.get(&"shield_camera_height", shield_camera_height)), -0.4, 1.4)
	shield_camera_distance = clampf(float(settings.get(&"shield_camera_distance", shield_camera_distance)), 3.0, 9.0)
	shield_camera_pitch = clampf(float(settings.get(&"shield_camera_pitch", shield_camera_pitch)), 0.0, 28.0)
	shield_fov_zoom = clampf(float(settings.get(&"shield_fov_zoom", shield_fov_zoom)), 0.0, 12.0)
	shield_time_scale = clampf(float(settings.get(&"shield_time_scale", shield_time_scale)), 0.45, 1.0)
	shield_transition_duration = clampf(float(settings.get(&"shield_transition_duration", shield_transition_duration)), 0.12, 1.0)
	giant_camera_height = clampf(float(settings.get(&"giant_camera_height", giant_camera_height)), -1.2, 0.8)
	giant_camera_distance = clampf(float(settings.get(&"giant_camera_distance", giant_camera_distance)), 3.0, 10.0)
	giant_camera_pitch = clampf(float(settings.get(&"giant_camera_pitch", giant_camera_pitch)), 5.0, 42.0)
	giant_fov_zoom = clampf(float(settings.get(&"giant_fov_zoom", giant_fov_zoom)), 0.0, 12.0)
	giant_time_scale = clampf(float(settings.get(&"giant_time_scale", giant_time_scale)), 0.45, 1.0)
	giant_transition_duration = clampf(float(settings.get(&"giant_transition_duration", giant_transition_duration)), 0.12, 1.0)

func set_wall_run_state(active: bool, surface_kind: StringName, mode: StringName, side: float) -> void:
	var normalized_kind: StringName = surface_kind if surface_kind != StringName() else &"world"
	var is_special_surface: bool = active and (normalized_kind == &"giant_enemy" or normalized_kind == &"phalanx_shields")
	var special_kind: StringName = normalized_kind if is_special_surface else StringName()
	var starts_epic_run: bool = special_kind != StringName() and (not epic_run_contact_active or special_kind != epic_run_kind)
	var cold_epic_start: bool = epic_run_kind == StringName() or epic_run_envelope <= 0.15

	wall_run_contact_active = active
	if active:
		wall_run_surface_kind = normalized_kind
		wall_run_mode = mode
		wall_run_side_target = clampf(side, -1.0, 1.0)

	if starts_epic_run:
		if cold_epic_start:
			# The cinematic envelope is still near zero, so selecting the correct
			# initial direction here is invisible. Later mode changes remain blended.
			wall_run_orientation_blend = _wall_run_orientation_target(mode)
			wall_run_side = wall_run_side_target
		epic_run_kind = special_kind
		epic_run_elapsed = 0.0
		# The presentation tail survives a contact ending before the next frame, so
		# the envelope may start at zero and ease in without an initial camera snap.
		if cold_epic_start:
			epic_run_envelope = 0.0
		_configure_epic_run_hud(special_kind)
		for device: int in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.18, 0.34 if special_kind == &"giant_enemy" else 0.48, 0.075)
	epic_run_contact_active = special_kind != StringName()

func is_epic_wall_run_active() -> bool:
	return epic_run_kind != StringName() and (epic_run_contact_active or epic_run_envelope > 0.01)

func _wall_run_orientation_target(mode: StringName) -> Vector3:
	if mode == &"diagonal":
		return Vector3.UP
	if mode == &"vertical":
		return Vector3.BACK
	return Vector3.RIGHT

func epic_camera_focus_height(base_height: float) -> float:
	if epic_run_kind == StringName():
		return base_height
	var orientation_drop: float = wall_run_orientation_blend.dot(Vector3(0.0, -0.12, -0.26))
	var profile_height: float = giant_camera_height if epic_run_kind == &"giant_enemy" else shield_camera_height
	return lerpf(base_height, profile_height + orientation_drop, _epic_run_eased_envelope())

func epic_camera_distance(base_distance: float) -> float:
	if epic_run_kind == StringName():
		return base_distance
	var orientation_distance: float = wall_run_orientation_blend.dot(Vector3(0.0, -0.20, -0.40))
	var profile_distance: float = giant_camera_distance if epic_run_kind == &"giant_enemy" else shield_camera_distance
	# A close normal-camera preference must never be pushed farther away by the
	# cinematic preset; this setting only controls how far the run may zoom in.
	var cinematic_distance: float = minf(base_distance, maxf(2.5, profile_distance + orientation_distance))
	return lerpf(base_distance, cinematic_distance, _epic_run_eased_envelope())

func epic_camera_follow_response() -> float:
	# Three exponential time constants put the rig very close to its target within
	# the same designer-facing duration used by the ease-in/out envelope.
	return clampf(3.0 / maxf(_epic_run_transition_duration(), 0.01), 3.0, 20.0)

func epic_camera_blend_strength() -> float:
	return _epic_run_eased_envelope()

func _epic_run_transition_duration() -> float:
	return giant_transition_duration if epic_run_kind == &"giant_enemy" else shield_transition_duration

func _epic_run_eased_envelope() -> float:
	return smoothstep(0.0, 1.0, clampf(epic_run_envelope, 0.0, 1.0))

func attack_started(slot: StringName, power: float) -> void:
	match slot:
		&"heavy":
			# A subtle inhale before release. Impact adds the opposite FOV pulse.
			fov_offset = minf(fov_offset, lerpf(-1.15, -2.0, clampf(power, 0.0, 1.0)))
		&"spin360":
			fov_offset = minf(fov_offset, -0.65)

func blade_whoosh(slot: StringName, blade_speed: float, context: StringName = StringName()) -> void:
	var intensity: float = clampf(inverse_lerp(1.1, 15.0, blade_speed), 0.0, 1.0)
	var cue: StringName = &"whoosh_light1" if slot == &"light1" else &"whoosh_light"
	if slot == &"heavy":
		cue = &"whoosh_heavy"
	elif slot == &"spin360":
		cue = &"whoosh_spiral"
	audio_cue_requested.emit(cue, context, intensity)

func charge_max_reached(position: Vector3) -> void:
	fov_offset = minf(fov_offset, -1.25)
	audio_cue_requested.emit(&"charge_max", StringName(), 1.0)
	vfx_cue_requested.emit(&"charge_max", position, Vector3.UP, 1.0)
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, 0.12, 0.20, 0.055)

func weapon_hit(hit: Variant, zone: StringName, target: Node = null) -> void:
	if hit == null:
		return
	var slot: StringName = StringName(hit.attack_slot)
	var intensity: float = clampf(float(hit.damage) / 76.0, 0.20, 1.0)
	var hit_direction: Vector3 = hit.direction
	var material: StringName = StringName(hit.hit_material)
	var contact: StringName = StringName(hit.contact_type)
	if contact in [&"shield", &"parry", &"armor", &"guard_break"]:
		var defended_intensity: float = maxf(intensity, 0.55 if contact == &"armor" else 0.72)
		_apply_directional_camera_kick(hit_direction, &"shield", defended_intensity)
		_rumble_for(&"shield", defended_intensity, true)
		var cue: StringName = &"parry" if contact == &"parry" else (&"guard_break" if contact == &"guard_break" else (&"impact_shield" if contact == &"shield" else &"impact_metal"))
		audio_cue_requested.emit(cue, zone, defended_intensity)
		_spawn_shield_sparks(hit.position, -hit_direction, defended_intensity)
		vfx_cue_requested.emit(cue, hit.position, hit_direction, defended_intensity)
		return

	_apply_directional_camera_kick(hit_direction, slot, intensity)
	_rumble_for(slot, intensity, false)
	audio_cue_requested.emit(StringName("impact_%s" % String(material)), zone, intensity)
	vfx_cue_requested.emit(StringName("impact_%s" % String(material)), hit.position, hit_direction, intensity)
	_try_start_rare_cinematic(hit, zone, target)

func shield_blocked(blocked_damage: float, attacker: Node) -> void:
	var direction: Vector3 = Vector3.ZERO
	if owner_body != null and attacker is Node3D:
		direction = owner_body.global_position - (attacker as Node3D).global_position
	if direction.length() < 0.01 and owner_body != null:
		direction = -owner_body.global_basis.z
	direction = direction.normalized()
	var intensity: float = clampf(blocked_damage / 55.0, 0.35, 1.0)
	_apply_directional_camera_kick(direction, &"shield", intensity)
	_rumble_for(&"shield", intensity, true)
	audio_cue_requested.emit(&"impact_shield", &"shield", intensity)

	var spark_position: Vector3 = Vector3.ZERO
	if owner_body != null:
		spark_position = owner_body.global_position + Vector3.UP * 1.18 - owner_body.global_basis.z * 0.48
	_spawn_shield_sparks(spark_position, -direction, intensity)
	vfx_cue_requested.emit(&"impact_shield", spark_position, -direction, intensity)

func spiral_smash(position: Vector3, radius: float) -> void:
	_apply_directional_camera_kick(Vector3.ZERO, &"heavy", 0.92)
	fov_offset = maxf(fov_offset, 1.65)
	_rumble_for(&"heavy", 0.90, false)
	audio_cue_requested.emit(&"impact_stone", &"ground", 1.0)
	vfx_cue_requested.emit(&"spiral_smash", position, Vector3.UP, 1.0)
	_spawn_spiral_smash_wave(position, radius)

func start_perfect_response(kind: StringName, attacker: Node3D = null) -> void:
	perfect_response_active = true
	perfect_response_consumed = false
	perfect_response_elapsed = 0.0
	perfect_response_duration = 0.92
	perfect_response_side = 1.0
	if owner_body != null and attacker != null and feedback_camera != null:
		var threat_direction: Vector3 = attacker.global_position - owner_body.global_position
		threat_direction.y = 0.0
		perfect_response_side = 1.0 if threat_direction.dot(feedback_camera.global_basis.x) >= 0.0 else -1.0
	fov_offset = minf(fov_offset, -2.4)
	audio_cue_requested.emit(&"parry", kind, 0.92)
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, 0.24, 0.42, 0.065)

func is_perfect_response_active() -> bool:
	return perfect_response_active and not perfect_response_consumed

func consume_perfect_response() -> void:
	if not perfect_response_active:
		return
	perfect_response_consumed = true
	# Keep a short tail after the choice so the attack launches through the visual
	# transition instead of snapping the world back to full speed on input.
	perfect_response_elapsed = maxf(perfect_response_elapsed, perfect_response_duration - 0.26)

func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	var real_delta: float = clampf(float(now_usec - previous_ticks_usec) / 1000000.0, 0.0, 0.05)
	previous_ticks_usec = now_usec
	_tick_feedback(real_delta)

func _tick_feedback(real_delta: float) -> void:
	real_delta = clampf(real_delta, 0.0, 0.05)

	camera_kick = camera_kick.lerp(Vector3.ZERO, 1.0 - exp(-24.0 * real_delta))
	fov_offset = lerpf(fov_offset, 0.0, 1.0 - exp(-13.0 * real_delta))
	var wall_run_target: float = 1.0 if wall_run_contact_active else 0.0
	var wall_run_response: float = 12.0 if wall_run_contact_active else 7.5
	wall_run_envelope = lerpf(wall_run_envelope, wall_run_target, 1.0 - exp(-wall_run_response * real_delta))
	if wall_run_contact_active:
		var orientation_target: Vector3 = _wall_run_orientation_target(wall_run_mode)
		wall_run_orientation_blend = wall_run_orientation_blend.lerp(orientation_target, 1.0 - exp(-8.5 * real_delta))
	wall_run_side = lerpf(wall_run_side, wall_run_side_target, 1.0 - exp(-9.0 * real_delta))
	if wall_run_contact_active or wall_run_envelope > 0.002:
		var phase_speed: float = 11.0 if wall_run_mode == &"vertical" else 15.0
		wall_run_phase = fmod(wall_run_phase + real_delta * phase_speed, TAU)

	if epic_run_kind != StringName():
		epic_run_elapsed += real_delta
	var epic_run_should_hold: bool = epic_run_contact_active or (epic_run_kind != StringName() and epic_run_elapsed < EPIC_RUN_MIN_PRESENTATION)
	var epic_run_target: float = 1.0 if epic_run_should_hold else 0.0
	var epic_transition_duration: float = _epic_run_transition_duration()
	epic_run_envelope = move_toward(epic_run_envelope, epic_run_target, real_delta / maxf(epic_transition_duration, 0.01))
	if not epic_run_should_hold and epic_run_envelope < 0.002:
		epic_run_envelope = 0.0
		epic_run_kind = StringName()
		epic_run_elapsed = 0.0
	var epic_visual_envelope: float = _epic_run_eased_envelope()

	var owned_before: bool = time_effect_owned
	var desired_time_scale: float = 1.0
	var perfect_envelope: float = 0.0
	if perfect_response_active:
		perfect_response_elapsed += real_delta
		var perfect_progress: float = clampf(perfect_response_elapsed / maxf(perfect_response_duration, 0.001), 0.0, 1.0)
		if perfect_progress < 0.10:
			perfect_envelope = smoothstep(0.0, 0.10, perfect_progress)
		elif perfect_progress < 0.72:
			perfect_envelope = 1.0
		else:
			perfect_envelope = 1.0 - smoothstep(0.72, 1.0, perfect_progress)
		desired_time_scale = minf(desired_time_scale, lerpf(1.0, 0.30, perfect_envelope))
		if perfect_progress >= 1.0:
			perfect_response_active = false
			perfect_envelope = 0.0

	var cinematic_envelope: float = 0.0
	if cinematic_active:
		cinematic_elapsed += real_delta
		var cinematic_progress: float = clampf(cinematic_elapsed / maxf(cinematic_duration, 0.001), 0.0, 1.0)
		cinematic_envelope = sin(PI * cinematic_progress)
		desired_time_scale = minf(desired_time_scale, 0.28)
		if cinematic_progress >= 1.0:
			cinematic_active = false
			cinematic_envelope = 0.0

	if epic_run_kind != StringName():
		var epic_time_scale: float = shield_time_scale if epic_run_kind == &"phalanx_shields" else giant_time_scale
		desired_time_scale = minf(desired_time_scale, lerpf(1.0, epic_time_scale, epic_visual_envelope))

	desired_time_scale = minf(desired_time_scale, skill_time_scale if not get_tree().paused else 1.0)
	time_effect_owned = perfect_response_active or cinematic_active or epic_run_kind != StringName() or desired_time_scale < 0.999
	if time_effect_owned:
		Engine.time_scale = desired_time_scale
	elif owned_before:
		Engine.time_scale = 1.0

	if feedback_camera != null and is_instance_valid(feedback_camera):
		var wall_pulse: float = sin(wall_run_phase) * wall_run_envelope
		var horizontal_weight: float = wall_run_orientation_blend.x
		var diagonal_weight: float = wall_run_orientation_blend.y
		var vertical_weight: float = wall_run_orientation_blend.z
		var lateral_weight: float = horizontal_weight + diagonal_weight * 0.72 + vertical_weight * 0.10
		var upward_weight: float = diagonal_weight * 0.58 + vertical_weight
		var traversal_rotation := Vector3.ZERO
		traversal_rotation.x = deg_to_rad(1.05) * upward_weight * wall_run_envelope
		traversal_rotation.z = deg_to_rad(3.2) * wall_run_side * lateral_weight * wall_run_envelope
		traversal_rotation.z += deg_to_rad(0.22) * wall_pulse
		var traversal_h_offset: float = 0.11 * wall_run_side * lateral_weight * wall_run_envelope
		var traversal_v_offset: float = 0.025 * wall_pulse
		var traversal_fov: float = 4.0 * wall_run_envelope

		var epic_rotation := Vector3.ZERO
		var epic_h_offset: float = 0.0
		var epic_v_offset: float = 0.0
		var epic_fov: float = 0.0
		var profile_pitch: float = giant_camera_pitch if epic_run_kind == &"giant_enemy" else shield_camera_pitch
		var epic_pitch_degrees: float = profile_pitch + wall_run_orientation_blend.dot(Vector3(0.0, 2.0, 5.0))
		var epic_yaw_degrees: float = wall_run_side * (horizontal_weight * 2.0 + diagonal_weight * 1.35 + vertical_weight * 0.30)
		var profile_zoom: float = giant_fov_zoom if epic_run_kind == &"giant_enemy" else shield_fov_zoom
		var epic_zoom_degrees: float = profile_zoom + wall_run_orientation_blend.dot(Vector3(0.0, 0.5, 1.0))
		if epic_run_kind == &"giant_enemy":
			epic_rotation = Vector3(deg_to_rad(epic_pitch_degrees), deg_to_rad(epic_yaw_degrees), deg_to_rad(1.55 * wall_run_side * lateral_weight)) * epic_visual_envelope
			epic_h_offset = 0.12 * wall_run_side * lateral_weight * epic_visual_envelope
			epic_v_offset = (0.025 + sin(wall_run_phase * 0.48) * 0.012) * epic_visual_envelope
			epic_fov = -epic_zoom_degrees * epic_visual_envelope
		elif epic_run_kind == &"phalanx_shields":
			epic_rotation = Vector3(deg_to_rad(epic_pitch_degrees), deg_to_rad(epic_yaw_degrees * 1.12), deg_to_rad(2.45 * wall_run_side * lateral_weight)) * epic_visual_envelope
			epic_h_offset = 0.22 * wall_run_side * lateral_weight * epic_visual_envelope
			epic_v_offset = (0.018 + sin(wall_run_phase * 1.35) * 0.010) * epic_visual_envelope
			epic_fov = -epic_zoom_degrees * epic_visual_envelope

		var cinematic_rotation := Vector3(deg_to_rad(-1.8), deg_to_rad(7.4 * cinematic_side), deg_to_rad(-1.5 * cinematic_side)) * cinematic_envelope
		var perfect_rotation := Vector3(deg_to_rad(-0.35), 0.0, deg_to_rad(-0.55 * perfect_response_side)) * perfect_envelope
		feedback_camera.h_offset = camera_rest_h_offset + traversal_h_offset + epic_h_offset + 0.42 * cinematic_side * cinematic_envelope + 0.07 * perfect_response_side * perfect_envelope
		feedback_camera.v_offset = camera_rest_v_offset + traversal_v_offset + epic_v_offset + 0.075 * cinematic_envelope + 0.025 * perfect_envelope
		feedback_camera.rotation = camera_kick + traversal_rotation + epic_rotation + cinematic_rotation + perfect_rotation + skill_rotation
		feedback_camera.fov = BASE_FOV + skill_fov + fov_offset + traversal_fov + epic_fov - 4.6 * cinematic_envelope - 2.8 * perfect_envelope

	_update_epic_run_hud()

	for index: int in range(transient_nodes.size() - 1, -1, -1):
		var entry: Dictionary = transient_nodes[index]
		entry["ttl"] = float(entry.get("ttl", 0.0)) - real_delta
		if float(entry["ttl"]) <= 0.0:
			var node: Node = entry.get("node") as Node
			if node != null and is_instance_valid(node):
				node.queue_free()
			transient_nodes.remove_at(index)
		else:
			transient_nodes[index] = entry

func _build_epic_run_hud() -> void:
	epic_run_hud = CanvasLayer.new()
	epic_run_hud.name = "EpicTraversalHUD"
	epic_run_hud.layer = 24
	epic_run_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(epic_run_hud)

	epic_run_hud_root = Control.new()
	epic_run_hud_root.name = "EpicTraversalRoot"
	epic_run_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	epic_run_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epic_run_hud_root.visible = false
	epic_run_hud.add_child(epic_run_hud_root)

	epic_run_tint = ColorRect.new()
	epic_run_tint.name = "TraversalTint"
	epic_run_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	epic_run_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epic_run_hud_root.add_child(epic_run_tint)

	epic_run_left_edge = ColorRect.new()
	epic_run_left_edge.name = "LeftAdrenalineEdge"
	epic_run_left_edge.anchor_bottom = 1.0
	epic_run_left_edge.offset_right = 9.0
	epic_run_left_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epic_run_hud_root.add_child(epic_run_left_edge)

	epic_run_right_edge = ColorRect.new()
	epic_run_right_edge.name = "RightAdrenalineEdge"
	epic_run_right_edge.anchor_left = 1.0
	epic_run_right_edge.anchor_right = 1.0
	epic_run_right_edge.anchor_bottom = 1.0
	epic_run_right_edge.offset_left = -9.0
	epic_run_right_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epic_run_hud_root.add_child(epic_run_right_edge)

	epic_run_panel = PanelContainer.new()
	epic_run_panel.name = "EpicTraversalCallout"
	epic_run_panel.anchor_left = 0.5
	epic_run_panel.anchor_right = 0.5
	epic_run_panel.offset_left = -220.0
	epic_run_panel.offset_right = 220.0
	epic_run_panel.offset_top = 46.0
	epic_run_panel.offset_bottom = 132.0
	epic_run_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epic_run_panel_style = StyleBoxFlat.new()
	epic_run_panel_style.bg_color = Color(0.025, 0.018, 0.014, 0.92)
	epic_run_panel_style.border_color = GIANT_RUN_ACCENT
	epic_run_panel_style.set_border_width_all(2)
	epic_run_panel_style.set_corner_radius_all(12)
	epic_run_panel.add_theme_stylebox_override("panel", epic_run_panel_style)
	epic_run_hud_root.add_child(epic_run_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	epic_run_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -1)
	margin.add_child(column)

	epic_run_label = Label.new()
	epic_run_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epic_run_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epic_run_label.add_theme_font_size_override("font_size", 26)
	epic_run_label.add_theme_constant_override("outline_size", 7)
	epic_run_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	column.add_child(epic_run_label)

	epic_run_subtitle = Label.new()
	epic_run_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	epic_run_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epic_run_subtitle.add_theme_font_size_override("font_size", 11)
	epic_run_subtitle.add_theme_constant_override("outline_size", 4)
	epic_run_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	column.add_child(epic_run_subtitle)

func _configure_epic_run_hud(kind: StringName) -> void:
	if epic_run_hud_root == null:
		return
	epic_run_accent = SHIELD_RUN_ACCENT if kind == &"phalanx_shields" else GIANT_RUN_ACCENT
	if epic_run_label != null:
		epic_run_label.text = "SHIELD RUN" if kind == &"phalanx_shields" else "GIANT RUN"
		epic_run_label.add_theme_color_override("font_color", epic_run_accent.lightened(0.18))
	if epic_run_subtitle != null:
		epic_run_subtitle.text = "COURSE SUR LA PHALANGE  •  ASPIDES LEVÉS" if kind == &"phalanx_shields" else "COURSE SUR GÉANT  •  PRENEZ DE LA HAUTEUR"
		epic_run_subtitle.add_theme_color_override("font_color", epic_run_accent.lightened(0.38))
	if epic_run_panel_style != null:
		epic_run_panel_style.bg_color = Color(epic_run_accent.r * 0.075, epic_run_accent.g * 0.055, epic_run_accent.b * 0.045, 0.94)
		epic_run_panel_style.border_color = Color(epic_run_accent.r, epic_run_accent.g, epic_run_accent.b, 0.90)
	epic_run_hud_root.visible = true

func _update_epic_run_hud() -> void:
	if epic_run_hud_root == null:
		return
	if epic_run_kind == StringName() and epic_run_envelope <= 0.001:
		epic_run_hud_root.visible = false
		return
	epic_run_hud_root.visible = true
	var epic_visual_envelope: float = _epic_run_eased_envelope()
	var pulse: float = 0.82 + 0.18 * sin(wall_run_phase * 0.72)
	if epic_run_tint != null:
		epic_run_tint.color = Color(epic_run_accent.r * 0.20, epic_run_accent.g * 0.14, epic_run_accent.b * 0.12, 0.055 * epic_visual_envelope)
	var edge_color := Color(epic_run_accent.r, epic_run_accent.g, epic_run_accent.b, 0.34 * epic_visual_envelope * pulse)
	if epic_run_left_edge != null:
		epic_run_left_edge.color = edge_color
	if epic_run_right_edge != null:
		epic_run_right_edge.color = edge_color
	if epic_run_panel != null:
		epic_run_panel.modulate = Color(1.0, 1.0, 1.0, epic_visual_envelope)
		epic_run_panel.pivot_offset = epic_run_panel.size * 0.5
		epic_run_panel.scale = Vector2.ONE * lerpf(0.93, 1.0 + 0.012 * pulse, epic_visual_envelope)

func _apply_directional_camera_kick(direction: Vector3, slot: StringName, intensity: float) -> void:
	if feedback_camera == null:
		return
	var flat: Vector3 = direction
	flat.y = 0.0
	if flat.length() < 0.01:
		flat = -feedback_camera.global_basis.z
	flat = flat.normalized()
	var side: float = clampf(flat.dot(feedback_camera.global_basis.x), -1.0, 1.0)
	var degrees: float = 0.42
	if slot == &"heavy":
		degrees = lerpf(0.85, 1.45, intensity)
	elif slot == &"spin360":
		degrees = 0.72
	elif slot == &"shield":
		degrees = lerpf(1.15, 1.90, intensity)
	var radians: float = deg_to_rad(degrees)
	camera_kick.x += radians * 0.34
	camera_kick.y += radians * side * 0.45
	camera_kick.z += radians * (-side if absf(side) > 0.12 else 0.45)
	fov_offset = maxf(fov_offset, lerpf(0.45, 1.45, intensity))

func _try_start_rare_cinematic(hit: Variant, zone: StringName, target: Node) -> void:
	if cinematic_active or Time.get_ticks_msec() < cinematic_cooldown_until_ms:
		return
	var confirmed_head_sever: bool = false
	var confirmed_zone_sever: bool = false
	if target != null and target.has_method("is_combat_zone_severed"):
		confirmed_head_sever = bool(target.call("is_combat_zone_severed", &"head"))
		confirmed_zone_sever = bool(target.call("is_combat_zone_severed", zone))
	var violent_death: bool = false
	if target != null and target.has_method("is_dead_for_combat"):
		violent_death = bool(target.call("is_dead_for_combat")) and float(hit.sever_damage) >= 115.0
	var is_head_contact: bool = zone == &"head" or zone == &"neck"
	var finisher_slot: bool = StringName(hit.attack_slot) == &"heavy" or StringName(hit.attack_slot) == &"spin360" or StringName(hit.attack_slot) == &"light3"
	var violent_limb_sever: bool = confirmed_zone_sever and finisher_slot and float(hit.sever_damage) >= 75.0
	if not (is_head_contact and confirmed_head_sever) and not violent_death and not violent_limb_sever:
		return
	cinematic_active = true
	cinematic_elapsed = 0.0
	cinematic_duration = 0.58
	var side_value: float = hit.direction.dot(feedback_camera.global_basis.x) if feedback_camera != null else 0.0
	cinematic_side = 1.0 if side_value >= 0.0 else -1.0
	cinematic_cooldown_until_ms = Time.get_ticks_msec() + 5500
	Engine.time_scale = 0.28
	fov_offset = maxf(fov_offset, 1.2)
	var cinematic_kind: StringName = &"execution"
	if is_head_contact and confirmed_head_sever:
		cinematic_kind = &"decapitation"
	elif violent_limb_sever:
		cinematic_kind = &"dismemberment"
	var cinematic_intensity: float = clampf(float(hit.sever_damage) / 150.0, 0.65, 1.0)
	cinematic_started.emit(cinematic_kind, cinematic_intensity)

func _rumble_for(slot: StringName, intensity: float, blocked: bool) -> void:
	var weak: float = 0.18
	var strong: float = 0.28
	var duration: float = 0.055
	if slot == &"heavy":
		weak = lerpf(0.30, 0.62, intensity)
		strong = lerpf(0.45, 0.90, intensity)
		duration = 0.095
	elif slot == &"spin360":
		weak = 0.30
		strong = 0.48
		duration = 0.070
	if blocked:
		weak = lerpf(0.35, 0.62, intensity)
		strong = lerpf(0.58, 0.95, intensity)
		duration = 0.080
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)

func _spawn_shield_sparks(position: Vector3, direction: Vector3, intensity: float) -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	var particles := CPUParticles3D.new()
	particles.name = "ShieldImpactSparks"
	particles.top_level = true
	particles.amount = clampi(int(lerpf(12.0, 18.0, intensity)), 10, 18)
	particles.lifetime = 0.24
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = direction.normalized() if direction.length() > 0.01 else Vector3.UP
	particles.spread = 52.0
	particles.gravity = Vector3(0.0, -7.0, 0.0)
	particles.initial_velocity_min = 2.8
	particles.initial_velocity_max = 5.8
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.065
	particles.color = Color(1.0, 0.67, 0.16, 1.0)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.025, 0.025, 0.16)
	particles.mesh = spark_mesh
	scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	transient_nodes.append({"node": particles, "ttl": 0.42})

	var flash := OmniLight3D.new()
	flash.name = "ShieldImpactFlash"
	flash.top_level = true
	flash.light_color = Color(1.0, 0.58, 0.18)
	flash.light_energy = lerpf(0.55, 1.15, intensity)
	flash.omni_range = 1.25
	flash.shadow_enabled = false
	scene.add_child(flash)
	flash.global_position = position
	transient_nodes.append({"node": flash, "ttl": 0.055})

	var impact_disc := MeshInstance3D.new()
	impact_disc.name = "ShieldImpactDisc"
	impact_disc.top_level = true
	var disc_mesh := QuadMesh.new()
	disc_mesh.size = Vector2.ONE * lerpf(0.42, 0.68, intensity)
	var disc_material := StandardMaterial3D.new()
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	disc_material.albedo_color = Color(1.0, 0.63, 0.16, 0.72)
	disc_material.emission_enabled = true
	disc_material.emission = Color(1.0, 0.38, 0.04) * 2.2
	disc_mesh.material = disc_material
	impact_disc.mesh = disc_mesh
	scene.add_child(impact_disc)
	impact_disc.global_position = position
	transient_nodes.append({"node": impact_disc, "ttl": 0.085})

func _spawn_spiral_smash_wave(position: Vector3, radius: float) -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	var safe_radius: float = maxf(radius, 0.6)
	var ring := MeshInstance3D.new()
	ring.name = "SpiralSmashWave"
	ring.top_level = true
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(0.05, safe_radius - 0.15)
	ring_mesh.outer_radius = safe_radius
	ring_mesh.rings = 64
	ring_mesh.ring_segments = 8
	var ring_material := StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.34, 0.06, 0.74)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.11, 0.015) * 2.4
	ring_mesh.material = ring_material
	ring.mesh = ring_mesh
	scene.add_child(ring)
	ring.global_position = position + Vector3.UP * 0.055
	transient_nodes.append({"node": ring, "ttl": 0.18})

	var dust := CPUParticles3D.new()
	dust.name = "SpiralSmashDust"
	dust.top_level = true
	dust.amount = 42
	dust.lifetime = 0.48
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.direction = Vector3.UP
	dust.spread = 86.0
	dust.gravity = Vector3(0.0, -5.5, 0.0)
	dust.initial_velocity_min = 2.2
	dust.initial_velocity_max = 5.0
	dust.scale_amount_min = 0.05
	dust.scale_amount_max = 0.16
	dust.color = Color(0.72, 0.42, 0.20, 0.76)
	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(0.10, 0.10)
	dust.mesh = dust_mesh
	scene.add_child(dust)
	dust.global_position = position + Vector3.UP * 0.04
	dust.emitting = true
	transient_nodes.append({"node": dust, "ttl": 0.62})

func _exit_tree() -> void:
	if cinematic_active or perfect_response_active or time_effect_owned:
		Engine.time_scale = 1.0
