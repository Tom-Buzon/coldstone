extends Node
class_name HopliteCombatFeedback

signal audio_cue_requested(cue: StringName, zone: StringName, intensity: float)
signal vfx_cue_requested(cue: StringName, position: Vector3, direction: Vector3, intensity: float)
signal cinematic_started(kind: StringName, intensity: float)

const BASE_FOV: float = 72.0

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
var time_effect_owned: bool = false
var previous_ticks_usec: int = 0
var transient_nodes: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_ticks_usec = Time.get_ticks_usec()

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

	camera_kick = camera_kick.lerp(Vector3.ZERO, 1.0 - exp(-24.0 * real_delta))
	fov_offset = lerpf(fov_offset, 0.0, 1.0 - exp(-13.0 * real_delta))
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

	time_effect_owned = perfect_response_active or cinematic_active
	if time_effect_owned:
		Engine.time_scale = desired_time_scale
	elif owned_before:
		Engine.time_scale = 1.0

	if feedback_camera != null and is_instance_valid(feedback_camera):
		var cinematic_rotation := Vector3(deg_to_rad(-1.8), deg_to_rad(7.4 * cinematic_side), deg_to_rad(-1.5 * cinematic_side)) * cinematic_envelope
		var perfect_rotation := Vector3(deg_to_rad(-0.35), 0.0, deg_to_rad(-0.55 * perfect_response_side)) * perfect_envelope
		feedback_camera.h_offset = camera_rest_h_offset + 0.42 * cinematic_side * cinematic_envelope + 0.07 * perfect_response_side * perfect_envelope
		feedback_camera.v_offset = camera_rest_v_offset + 0.075 * cinematic_envelope + 0.025 * perfect_envelope
		feedback_camera.rotation = camera_kick + cinematic_rotation + perfect_rotation
		feedback_camera.fov = BASE_FOV + fov_offset - 4.6 * cinematic_envelope - 2.8 * perfect_envelope

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
