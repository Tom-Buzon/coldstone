extends HopliteAthenianEnemy
class_name HopliteWolfBoss

const MODEL_PATH := "res://assets/fauna/quaternius_ultimate_animated_animals/models/Wolf.gltf"
const WolfRuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const WolfBossHitboxScript = preload("res://scripts/bosses/wolf_boss_hitbox.gd")
const ArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")

enum BossState { INTRO, HUNT, TELEGRAPH, ATTACK, RECOVERY, TRANSITION, DEAD }

const GRAVITY := 24.0
const TURN_RESPONSE := 10.0
const TELEGRAPH_HEIGHT := 0.055

var boss_state: BossState = BossState.INTRO
var state_time_left := 0.0
var attack_id: StringName = StringName()
var attack_target := Vector3.ZERO
var attack_direction := Vector3.FORWARD
var attack_hit_done := false
var dash_links_remaining := 0
var wave_pulses_remaining := 0
var pounce_was_airborne := false
var invulnerable := false
var veteran_mode := false
var target_height := 2.70
var phase_color := Color("b91f2f")
var mobility_break := 0.0
var mobility_break_max := 100.0
var ground_damage_multiplier := 0.42
var exposed_duration := 3.8
var exposed_damage_multiplier := 1.90
var moon_heart_exposed := false

var wolf_visual: Node3D
var wolf_hitbox: HopliteWolfBossHitbox
var wolf_animation_players: Array[AnimationPlayer] = []
var current_animation_kind: StringName = StringName()
var aura_ring: MeshInstance3D
var aura_material: StandardMaterial3D
var phase_light: OmniLight3D
var readout: Label3D
var health_bar_fill: MeshInstance3D
var health_bar_material: StandardMaterial3D
var visual_overlay: StandardMaterial3D
var telegraph_root: Node3D


func _ready() -> void:
	_apply_wolf_profile()
	_build_wolf_physics()
	_build_wolf_visual()
	_build_boss_identity()
	if faction == &"spartan":
		add_to_group("ally")
		add_to_group("spartan_ally")
	else:
		add_to_group("enemy")
		add_to_group("athenian")
	add_to_group("damageable")
	add_to_group("combatant")
	add_to_group("enemy_miniboss")
	add_to_group("enemy_epic")
	add_to_group("the_wolf_boss")
	if ai_enabled:
		add_to_group("combatant_ai")
		add_to_group("enemy_ai")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	reset_physics_interpolation()
	_play_animation(&"idle")
	_enter_state(BossState.INTRO, 1.35 if ai_enabled else INF)
	set_physics_process(ai_enabled)
	set_process(false)


func _exit_tree() -> void:
	_clear_telegraph()
	_set_attack_outline_active(false)


func _process(_delta: float) -> void:
	# The humanoid parent owns a large presentation loop. THE WOLF builds and
	# drives its imported quadruped presentation explicitly instead.
	pass


func _physics_process(delta: float) -> void:
	if dead or not ai_enabled:
		return
	if ai_player == null or not is_instance_valid(ai_player):
		velocity = velocity.move_toward(Vector3.ZERO, delta * 10.0)
		move_and_slide()
		return
	state_time_left -= delta
	match boss_state:
		BossState.INTRO:
			_update_intro()
		BossState.HUNT:
			_update_hunt(delta)
		BossState.TELEGRAPH:
			_update_telegraph()
		BossState.ATTACK:
			_update_attack(delta)
		BossState.RECOVERY:
			_update_recovery(delta)
		BossState.TRANSITION:
			_update_transition()


func _apply_wolf_profile() -> void:
	var profile := ArchetypesScript.profile(archetype_id)
	archetype_name = String(profile.get("display_name", "THE WOLF"))
	combat_rank = &"boss"
	behavior_mode = &"boss"
	weapon_kind = &"fangs"
	max_health = float(profile.get("health", 1200.0))
	health = max_health
	ai_move_speed = float(profile.get("move_speed", 7.4))
	ai_attack_damage = float(profile.get("attack_damage", 38.0))
	ai_attack_range = float(profile.get("attack_range", 2.5))
	ai_aggro_distance = float(profile.get("aggro_distance", 36.0))
	ai_attack_cooldown_min = float(profile.get("cooldown_min", 0.82))
	ai_attack_cooldown_max = float(profile.get("cooldown_max", 1.08))
	phase_threshold = float(profile.get("phase_threshold", 0.52))
	phase_speed_multiplier = float(profile.get("phase_speed_multiplier", 1.16))
	phase_damage_multiplier = float(profile.get("phase_damage_multiplier", 1.12))
	phase_three_threshold = float(profile.get("phase_three_threshold", 0.0))
	phase_three_speed_multiplier = float(profile.get("phase_three_speed_multiplier", 1.0))
	phase_three_damage_multiplier = float(profile.get("phase_three_damage_multiplier", 1.0))
	combat_pattern = Array(profile.get("combat_pattern", [])).duplicate(true)
	phase_two_pattern = Array(profile.get("phase_two_pattern", [])).duplicate(true)
	phase_three_pattern = Array(profile.get("phase_three_pattern", [])).duplicate(true)
	mobility_break_max = float(profile.get("mobility_break_max", 100.0))
	ground_damage_multiplier = float(profile.get("ground_damage_multiplier", 0.42))
	exposed_duration = float(profile.get("exposed_duration", 3.8))
	exposed_damage_multiplier = float(profile.get("exposed_damage_multiplier", 1.90))
	combat_pattern_cursor = 0
	combat_phase = 1
	veteran_mode = archetype_id == &"the_wolf_veteran"
	target_height = float(profile.get("wolf_target_height", 2.70)) * external_scale_multiplier
	base_color = Color(profile.get("color", Color("b91f2f")))
	phase_color = base_color
	corpse_lifetime = 18.0


func _build_wolf_physics() -> void:
	collision_layer = 4
	collision_mask = (1 | 2) if ai_enabled else 1
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(52.0)
	var size_factor := target_height / 2.70
	body_collider = CollisionShape3D.new()
	body_collider.name = "BodyCollider"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.82 * size_factor
	capsule.height = 2.25 * size_factor
	body_collider.shape = capsule
	body_collider.position.y = capsule.height * 0.5
	add_child(body_collider)
	wolf_hitbox = WolfBossHitboxScript.new() as HopliteWolfBossHitbox
	wolf_hitbox.name = "WolfBossHitbox"
	add_child(wolf_hitbox)
	wolf_hitbox.configure(self, 3.25 * size_factor)


func _build_wolf_visual() -> void:
	var packed := WolfRuntimeGLTFCacheScript.scene(MODEL_PATH)
	if packed == null:
		push_error("[THE WOLF] Modèle introuvable : %s" % MODEL_PATH)
		return
	wolf_visual = packed.instantiate() as Node3D
	if wolf_visual == null:
		return
	wolf_visual.name = "AnimatedVisual"
	add_child(wolf_visual)
	_fit_visual_to_height(wolf_visual, target_height)
	# Ultimate Animated Animals faces +Z; Godot gameplay forward is -Z.
	wolf_visual.rotation.y = PI
	for candidate: Node in wolf_visual.find_children("*", "AnimationPlayer", true, false):
		wolf_animation_players.append(candidate as AnimationPlayer)
	visual_overlay = StandardMaterial3D.new()
	visual_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual_overlay.albedo_color = Color(phase_color, 0.10)
	visual_overlay.emission_enabled = true
	visual_overlay.emission = phase_color
	visual_overlay.emission_energy_multiplier = 0.75
	for candidate: Node in wolf_visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		mesh.material_overlay = visual_overlay
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_boss_identity() -> void:
	aura_ring = MeshInstance3D.new()
	aura_ring.name = "PredatorAura"
	var ring := TorusMesh.new()
	ring.inner_radius = 1.72
	ring.outer_radius = 1.86
	ring.rings = 24
	ring.ring_segments = 12
	aura_ring.mesh = ring
	aura_ring.position.y = 0.07
	aura_material = _emissive_material(phase_color, 0.72)
	aura_ring.material_override = aura_material
	aura_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aura_ring)

	phase_light = OmniLight3D.new()
	phase_light.name = "PhaseLight"
	phase_light.position = Vector3(0.0, target_height * 0.72, 0.0)
	phase_light.omni_range = 8.0
	phase_light.light_energy = 2.2
	phase_light.shadow_enabled = false
	phase_light.light_color = phase_color
	add_child(phase_light)

	_add_boss_ornaments()
	_build_readout()


func _add_boss_ornaments() -> void:
	var ornament_root := Node3D.new()
	ornament_root.name = "BossOrnaments"
	add_child(ornament_root)
	var size_factor := target_height / 2.70
	for side: float in [-1.0, 1.0]:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.14 * size_factor
		cone.height = 0.72 * size_factor
		cone.radial_segments = 8
		spike.mesh = cone
		spike.position = Vector3(side * 0.48, target_height * 0.82, -target_height * 0.34)
		spike.rotation_degrees = Vector3(18.0, 0.0, -side * 28.0)
		spike.material_override = _emissive_material(Color("d9b45c"), 1.0)
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ornament_root.add_child(spike)


func _build_readout() -> void:
	readout = Label3D.new()
	readout.name = "BossReadout"
	readout.position = Vector3(0.0, target_height + 1.05, 0.0)
	readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	readout.no_depth_test = true
	readout.font_size = 34
	readout.outline_size = 9
	readout.modulate = Color.WHITE
	readout.text = "THE WOLF"
	add_child(readout)
	var bar_back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(3.4, 0.13, 0.05)
	bar_back.mesh = back_mesh
	bar_back.position = Vector3(0.0, target_height + 0.72, 0.0)
	bar_back.material_override = _flat_material(Color("180d12"))
	add_child(bar_back)
	health_bar_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(3.32, 0.09, 0.065)
	health_bar_fill.mesh = fill_mesh
	health_bar_fill.position = Vector3(0.0, target_height + 0.72, -0.035)
	health_bar_material = _flat_material(phase_color)
	health_bar_fill.material_override = health_bar_material
	add_child(health_bar_fill)
	_update_readout()


func _enter_state(next_state: BossState, duration: float) -> void:
	boss_state = next_state
	_set_attack_outline_active(next_state == BossState.TELEGRAPH)
	state_time_left = duration
	match boss_state:
		BossState.INTRO:
			velocity = Vector3.ZERO
			_play_animation(&"idle_2")
		BossState.HUNT:
			invulnerable = false
			ai_attack_pending = false
			active_attack_step.clear()
			_play_animation(&"gallop")
		BossState.TELEGRAPH:
			velocity = Vector3.ZERO
			ai_attack_pending = true
			_play_animation(&"idle_2")
		BossState.RECOVERY:
			velocity.x = 0.0
			velocity.z = 0.0
			ai_attack_pending = false
			active_attack_step.clear()
			_play_animation(&"idle")
		BossState.TRANSITION:
			velocity = Vector3.ZERO
			invulnerable = true
			ai_attack_pending = false
			active_attack_step.clear()
			_clear_telegraph()
			_play_animation(&"attack")
		BossState.DEAD:
			velocity = Vector3.ZERO
			_play_animation(&"death")


func _update_intro() -> void:
	_face_target(0.08)
	if state_time_left <= 0.0:
		_enter_state(BossState.HUNT, 0.0)


func _update_hunt(delta: float) -> void:
	var to_target := ai_player.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > ai_aggro_distance * 1.45:
		velocity.x = move_toward(velocity.x, 0.0, ai_acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, ai_acceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		_play_animation(&"idle")
		return
	var direction := to_target.normalized() if distance > 0.01 else -global_basis.z
	var tangent := Vector3(-direction.z, 0.0, direction.x) * (-1.0 if (get_instance_id() & 1) == 0 else 1.0)
	var desired := direction
	if distance < 4.6:
		desired = tangent * 0.82 - direction * 0.24
	elif distance < 8.0:
		desired = (direction * 0.52 + tangent * 0.48).normalized()
	var desired_velocity := desired * ai_move_speed
	velocity.x = move_toward(velocity.x, desired_velocity.x, ai_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, ai_acceleration * delta)
	_apply_gravity(delta)
	move_and_slide()
	_face_direction(Vector3(velocity.x, 0.0, velocity.z), delta * TURN_RESPONSE)
	_play_animation(&"gallop")
	ai_attack_cooldown_timer -= delta
	if ai_attack_cooldown_timer <= 0.0 and distance <= 14.0:
		_begin_next_attack()


func _begin_next_attack() -> void:
	active_attack_step = _next_combat_pattern_step()
	attack_id = StringName(active_attack_step.get("id", &"fang_dash"))
	attack_target = ai_player.global_position
	attack_direction = _flat_direction_to(attack_target)
	attack_hit_done = false
	var telegraph_time := float(active_attack_step.get("telegraph", 0.42))
	if veteran_mode:
		telegraph_time *= 0.88
	_show_attack_telegraph(attack_id)
	_enter_state(BossState.TELEGRAPH, telegraph_time)


func _update_telegraph() -> void:
	_face_direction(attack_direction, 0.18)
	if state_time_left <= 0.0:
		_start_attack()


func _start_attack() -> void:
	_clear_telegraph()
	boss_state = BossState.ATTACK
	_set_attack_outline_active(false)
	attack_hit_done = false
	match attack_id:
		&"blood_dash_chain":
			dash_links_remaining = 2
			_start_dash_link()
		&"fenrir_rush":
			dash_links_remaining = 3
			_start_dash_link()
		&"sky_pounce":
			state_time_left = 1.55
			pounce_was_airborne = false
			var pounce_direction := _flat_direction_to(attack_target)
			velocity = pounce_direction * (8.4 if veteran_mode else 7.6)
			velocity.y = 10.8 if combat_phase >= 2 else 9.6
			_play_animation(&"jump")
		&"moon_wave", &"twin_moon_wave":
			wave_pulses_remaining = 2 if attack_id == &"twin_moon_wave" else 1
			state_time_left = 0.18
			velocity = Vector3.ZERO
			_play_animation(&"attack")
		_:
			dash_links_remaining = 1
			_start_dash_link()


func _start_dash_link() -> void:
	attack_direction = _flat_direction_to(ai_player.global_position)
	state_time_left = 0.34 if combat_phase == 1 else (0.29 if combat_phase == 2 else 0.25)
	attack_hit_done = false
	_play_animation(&"attack" if dash_links_remaining <= 1 else &"gallop")


func _update_attack(delta: float) -> void:
	match attack_id:
		&"sky_pounce":
			_update_pounce(delta)
		&"moon_wave", &"twin_moon_wave":
			_update_moon_wave(delta)
		_:
			_update_dash(delta)


func _update_dash(delta: float) -> void:
	var dash_speed := (14.8 if combat_phase == 1 else (17.2 if combat_phase == 2 else 20.0))
	velocity.x = attack_direction.x * dash_speed
	velocity.z = attack_direction.z * dash_speed
	_apply_gravity(delta)
	move_and_slide()
	_face_direction(attack_direction, delta * 22.0)
	if not attack_hit_done and _target_flat_distance() <= 2.35:
		attack_hit_done = _damage_player(ai_attack_damage * float(active_attack_step.get("damage_mult", 1.0)), 2.6, 9.0)
	if state_time_left > 0.0:
		return
	dash_links_remaining -= 1
	if dash_links_remaining > 0:
		_start_dash_link()
		return
	_finish_attack(0.42 if combat_phase == 1 else 0.28)


func _update_pounce(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	_face_direction(Vector3(velocity.x, 0.0, velocity.z), delta * 12.0)
	if not is_on_floor():
		pounce_was_airborne = true
	if (pounce_was_airborne and is_on_floor() and velocity.y <= 0.1) or state_time_left <= 0.0:
		_spawn_ground_pulse(global_position, 4.3 if combat_phase == 1 else 5.1, phase_color)
		_damage_grounded_player(ai_attack_damage * 1.18, 4.3 if combat_phase == 1 else 5.1, 11.5)
		_finish_attack(0.52 if combat_phase == 1 else 0.32)


func _update_moon_wave(_delta: float) -> void:
	if state_time_left > 0.0:
		return
	var pulse_index := (2 if attack_id == &"twin_moon_wave" else 1) - wave_pulses_remaining
	var radius := (5.4 + float(pulse_index) * 2.0) * (1.08 if veteran_mode else 1.0)
	_spawn_ground_pulse(global_position, radius, phase_color)
	_damage_grounded_player(ai_attack_damage * (0.82 + float(pulse_index) * 0.10), radius, 8.5)
	wave_pulses_remaining -= 1
	if wave_pulses_remaining > 0:
		state_time_left = 0.38
		return
	_finish_attack(0.46 if combat_phase == 2 else 0.28)


func _finish_attack(recovery: float) -> void:
	ai_attack_cooldown_timer = randf_range(ai_attack_cooldown_min, ai_attack_cooldown_max)
	_enter_state(BossState.RECOVERY, recovery)


func _update_recovery(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 22.0 * delta)
	_apply_gravity(delta)
	move_and_slide()
	if not moon_heart_exposed:
		_face_target(delta * 7.0)
	if state_time_left <= 0.0:
		if moon_heart_exposed:
			_close_moon_heart()
		_enter_state(BossState.HUNT, 0.0)


func _update_transition() -> void:
	_face_target(0.12)
	if state_time_left <= 0.0:
		_spawn_ground_pulse(global_position, 6.2 + float(combat_phase), phase_color)
		_enter_state(BossState.HUNT, 0.0)
		ai_attack_cooldown_timer = 0.25


func _try_activate_combat_phase() -> void:
	if dead or max_health <= 0.0:
		return
	var health_ratio := health / max_health
	if combat_phase == 1 and phase_threshold > 0.0 and health_ratio <= phase_threshold and not phase_two_pattern.is_empty():
		_activate_wolf_phase(2, phase_speed_multiplier, phase_damage_multiplier)
		# A single oversized hit must not skip the entire authored second phase.
		return
	if combat_phase == 2 and phase_three_threshold > 0.0 and health_ratio <= phase_three_threshold and not phase_three_pattern.is_empty():
		_activate_wolf_phase(3, phase_three_speed_multiplier, phase_three_damage_multiplier)


func _activate_wolf_phase(next_phase: int, speed_multiplier: float, damage_multiplier: float) -> void:
	if moon_heart_exposed:
		_close_moon_heart()
	combat_phase = next_phase
	ai_move_speed *= maxf(speed_multiplier, 0.1)
	ai_attack_damage *= maxf(damage_multiplier, 0.1)
	ai_attack_cooldown_min /= maxf(speed_multiplier, 0.1)
	ai_attack_cooldown_max /= maxf(speed_multiplier, 0.1)
	combat_pattern = (phase_two_pattern if next_phase == 2 else phase_three_pattern).duplicate(true)
	combat_pattern_cursor = 0
	ai_attack_pending = false
	ai_attack_windup_timer = 0.0
	active_attack_step.clear()
	forced_attack_step.clear()
	attack_id = StringName()
	phase_color = Color("e23a2e") if next_phase == 2 else Color("b88cff")
	_apply_phase_identity()
	_enter_state(BossState.TRANSITION, 1.15 if next_phase == 2 else 1.35)
	combat_phase_changed.emit(self, combat_phase)


func _next_combat_pattern_step() -> Dictionary:
	if combat_pattern.is_empty():
		return {"id": &"fang_dash", "telegraph": 0.42, "damage_mult": 1.0}
	var step := (combat_pattern[combat_pattern_cursor % combat_pattern.size()] as Dictionary).duplicate(true)
	combat_pattern_cursor = (combat_pattern_cursor + 1) % combat_pattern.size()
	return step


func can_receive_hit_from(source: Node) -> bool:
	return not invulnerable and not dead and not (faction == &"spartan" and source != null and source.is_in_group("player"))


func receive_anatomy_hit(hit: Variant, zone: StringName) -> void:
	if hit == null or not can_receive_hit_from(hit.source):
		return
	var zone_multiplier := 1.28 if zone == &"head" else (0.88 if zone == &"flanks" else 1.0)
	var break_gain := _mobility_break_gain(hit)
	var damage_factor := exposed_damage_multiplier if moon_heart_exposed else (0.88 if break_gain > 0.0 else ground_damage_multiplier)
	var damage := maxf(0.0, float(hit.damage) * zone_multiplier * damage_factor)
	health = maxf(0.0, health - damage)
	if not moon_heart_exposed and break_gain > 0.0:
		mobility_break = minf(mobility_break_max, mobility_break + break_gain)
	last_hit_zone = zone
	last_hit_damage = damage
	last_hit_sever = 0.0
	localized_hit.emit(self, zone, damage, 0.0)
	_flash_wolf()
	_update_readout()
	_try_activate_combat_phase()
	if not dead and not moon_heart_exposed and mobility_break >= mobility_break_max and boss_state != BossState.TRANSITION:
		_open_moon_heart()
	if health <= 0.0:
		_die(false)


func _mobility_break_gain(hit: Variant) -> float:
	var context := StringName(hit.attack_context)
	var source := hit.source as Node
	var gain := 0.0
	match context:
		&"wall": gain = 42.0
		&"counter_dash", &"dash": gain = 34.0
		&"slide": gain = 27.0
		&"air": gain = 22.0
		&"run": gain = 10.0
		_: gain = 0.0
	# Only the player owns these mobility properties. This guard also keeps AI
	# damage and test fixtures from querying properties that do not exist.
	if source != null and source.is_in_group("player"):
		var jumps_used_value: Variant = source.get("jumps_used")
		if context == &"air" and jumps_used_value != null and int(jumps_used_value) >= 2:
			gain += 24.0
		var wall_active_value: Variant = source.get("wall_run_active")
		var wall_release_value: Variant = source.get("wall_run_repulsion_control_lock")
		if bool(wall_active_value) or (wall_release_value != null and float(wall_release_value) > 0.0):
			gain = maxf(gain, 44.0)
	if context == &"air" and StringName(hit.attack_slot) == &"spin360":
		gain += 12.0
	return gain


func _open_moon_heart() -> void:
	moon_heart_exposed = true
	mobility_break = 0.0
	invulnerable = false
	_clear_telegraph()
	_enter_state(BossState.RECOVERY, exposed_duration)
	_play_animation(&"idle_2")
	if aura_material != null:
		aura_material.albedo_color = Color(0.82, 0.94, 1.0, 0.92)
		aura_material.emission = Color(0.82, 0.94, 1.0)
	if phase_light != null:
		phase_light.light_color = Color(0.74, 0.88, 1.0)
		phase_light.light_energy = 5.2
	_spawn_ground_pulse(global_position, 4.8, Color(0.68, 0.88, 1.0))
	_update_readout()


func _close_moon_heart() -> void:
	moon_heart_exposed = false
	_apply_phase_identity()


func receive_ai_hit(damage: float, attacker: Node3D, hit_direction: Vector3) -> bool:
	if dead or attacker == null:
		return false
	if attacker is HopliteAthenianEnemy and (attacker as HopliteAthenianEnemy).faction == faction:
		return false
	var event := HopliteHitEvent.new()
	event.source = attacker
	event.damage = damage
	event.sever_damage = 0.0
	event.direction = hit_direction
	event.position = global_position + Vector3.UP * 1.3
	receive_anatomy_hit(event, &"torso")
	return true


func receive_spiral_smash(hit: Variant) -> bool:
	if hit == null or not can_receive_hit_from(hit.source):
		return false
	receive_anatomy_hit(hit, &"flanks")
	if not dead and boss_state not in [BossState.TRANSITION, BossState.DEAD]:
		_enter_state(BossState.RECOVERY, 0.38)
	return true


func alert_ai(duration: float = 8.0) -> void:
	ai_alert_timer = maxf(ai_alert_timer, duration)


func set_ai_participation(enabled: bool) -> void:
	ai_enabled = enabled and not dead
	set_physics_process(ai_enabled)


func is_dead_for_combat() -> bool:
	return dead


func _die(_from_sever: bool) -> void:
	if dead:
		return
	dead = true
	health = 0.0
	invulnerable = true
	collision_layer = 0
	collision_mask = 0
	if body_collider != null:
		body_collider.set_deferred("disabled", true)
	if wolf_hitbox != null:
		wolf_hitbox.shutdown()
	_clear_telegraph()
	_enter_state(BossState.DEAD, INF)
	set_physics_process(false)
	_update_readout()
	died.emit(self)
	if get_tree() != null:
		get_tree().create_timer(corpse_lifetime).timeout.connect(_release_wolf_corpse)


func _release_wolf_corpse() -> void:
	if dead and is_inside_tree():
		queue_free()


func _play_animation(kind: StringName) -> void:
	if kind == current_animation_kind:
		return
	current_animation_kind = kind
	var candidates: Array[StringName] = []
	var looped := false
	var speed := 1.0
	match kind:
		&"gallop":
			candidates = [&"Gallop", &"Walk"]
			looped = true
			speed = clampf(ai_move_speed / 7.4, 0.90, 1.45)
		&"jump": candidates = [&"Gallop_Jump", &"Jump_ToIdle", &"Gallop"]
		&"attack": candidates = [&"Attack", &"Idle_HitReact2"]
		&"death": candidates = [&"Death"]
		&"idle_2":
			candidates = [&"Idle_2", &"Idle_2_HeadLow", &"Idle"]
			looped = true
		&"hit": candidates = [&"Idle_HitReact1", &"Idle_HitReact2"]
		_:
			candidates = [&"Idle", &"Idle_2"]
			looped = true
	for player_node: AnimationPlayer in wolf_animation_players:
		var animation_name := _find_animation(player_node, candidates)
		if animation_name.is_empty():
			continue
		var animation := player_node.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
		var blend := 0.0 if player_node.current_animation.is_empty() else 0.14
		player_node.play(animation_name, blend, speed)


func _find_animation(player_node: AnimationPlayer, candidates: Array[StringName]) -> StringName:
	for wanted_name: StringName in candidates:
		var wanted := String(wanted_name).to_lower()
		for available: StringName in player_node.get_animation_list():
			var normalized := String(available).to_lower()
			if normalized == wanted or normalized.ends_with("|" + wanted) or normalized.ends_with("/" + wanted):
				return available
	return StringName()


func _show_attack_telegraph(kind: StringName) -> void:
	_clear_telegraph()
	telegraph_root = Node3D.new()
	telegraph_root.name = "WolfAttackTelegraph"
	get_tree().current_scene.add_child(telegraph_root)
	if kind in [&"sky_pounce"]:
		_add_telegraph_disk(telegraph_root, attack_target, 4.3 if combat_phase == 1 else 5.1, Color(phase_color, 0.34))
	elif kind in [&"moon_wave", &"twin_moon_wave"]:
		_add_telegraph_disk(telegraph_root, global_position, 5.4, Color(phase_color, 0.28))
	else:
		var distance := clampf(global_position.distance_to(attack_target), 4.0, 14.0)
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.35, TELEGRAPH_HEIGHT, distance)
		line.mesh = box
		line.material_override = _transparent_material(Color(phase_color, 0.38))
		telegraph_root.add_child(line)
		line.global_position = global_position.lerp(attack_target, 0.5) + Vector3.UP * TELEGRAPH_HEIGHT
		line.look_at(Vector3(attack_target.x, line.global_position.y, attack_target.z), Vector3.UP)


func _add_telegraph_disk(parent: Node3D, center: Vector3, radius: float, color: Color) -> void:
	var disk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = TELEGRAPH_HEIGHT
	cylinder.radial_segments = 48
	disk.mesh = cylinder
	disk.material_override = _transparent_material(color)
	parent.add_child(disk)
	disk.global_position = Vector3(center.x, maxf(global_position.y, center.y) + TELEGRAPH_HEIGHT, center.z)
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _spawn_ground_pulse(center: Vector3, radius: float, color: Color) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var pulse := MeshInstance3D.new()
	pulse.name = "WolfGroundPulse"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.45
	cylinder.bottom_radius = 0.45
	cylinder.height = 0.075
	cylinder.radial_segments = 40
	pulse.mesh = cylinder
	pulse.material_override = _transparent_material(Color(color, 0.62))
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(pulse)
	pulse.global_position = center + Vector3.UP * 0.08
	var tween := pulse.create_tween().set_parallel(true)
	tween.tween_property(pulse, "scale", Vector3(radius * 2.0, 0.25, radius * 2.0), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "transparency", 1.0, 0.42)
	tween.chain().tween_callback(pulse.queue_free)


func _clear_telegraph() -> void:
	if telegraph_root != null and is_instance_valid(telegraph_root):
		telegraph_root.queue_free()
	telegraph_root = null


func _damage_player(amount: float, radius: float, knockback: float) -> bool:
	if ai_player == null or not is_instance_valid(ai_player) or _target_flat_distance() > radius:
		return false
	var direction := _flat_direction_to(ai_player.global_position)
	if ai_player.has_method("receive_enemy_hit"):
		return bool(ai_player.call("receive_enemy_hit", amount, self, direction * knockback))
	return false


func _damage_grounded_player(amount: float, radius: float, knockback: float) -> bool:
	if ai_player == null or not is_instance_valid(ai_player):
		return false
	var height_above_floor := ai_player.global_position.y - global_position.y
	var wall_running := bool(ai_player.get("wall_run_active"))
	if height_above_floor > 1.45 or wall_running:
		return false
	return _damage_player(amount, radius, knockback)


func _target_flat_distance() -> float:
	if ai_player == null or not is_instance_valid(ai_player):
		return INF
	var offset := ai_player.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _flat_direction_to(world_point: Vector3) -> Vector3:
	var direction := world_point - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else -global_basis.z


func _face_target(weight: float) -> void:
	if ai_player != null and is_instance_valid(ai_player):
		_face_direction(_flat_direction_to(ai_player.global_position), weight)


func _face_direction(direction: Vector3, weight: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	var target_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	basis = basis.slerp(target_basis, clampf(weight, 0.0, 1.0)).orthonormalized()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2


func _apply_phase_identity() -> void:
	if aura_material != null:
		aura_material.albedo_color = Color(phase_color, 0.78)
		aura_material.emission = phase_color
	if health_bar_material != null:
		health_bar_material.albedo_color = phase_color
		health_bar_material.emission = phase_color
	if phase_light != null:
		phase_light.light_color = phase_color
		phase_light.light_energy = 2.8 + float(combat_phase) * 0.65
	if visual_overlay != null:
		visual_overlay.albedo_color = Color(phase_color, 0.12 + float(combat_phase) * 0.03)
		visual_overlay.emission = phase_color
	_update_readout()


func _update_readout() -> void:
	if readout != null:
		var mode := "VETERAN" if veteran_mode else "MID"
		if moon_heart_exposed:
			readout.text = "THE WOLF • %s\nCOEUR LUNAIRE EXPOSE" % mode
		else:
			var break_ratio := roundi(mobility_break / maxf(mobility_break_max, 1.0) * 100.0)
			readout.text = "THE WOLF • %s — PHASE %d\nRUPTURE MOBILITE %d%%" % [mode, combat_phase, break_ratio]
		readout.modulate = phase_color.lightened(0.35) if not dead else Color("625760")
	if health_bar_fill != null:
		var ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
		health_bar_fill.scale.x = ratio
		health_bar_fill.position.x = -(1.0 - ratio) * 1.66


func _flash_wolf() -> void:
	if visual_overlay == null:
		return
	visual_overlay.albedo_color = Color.WHITE
	visual_overlay.emission = Color.WHITE
	visual_overlay.emission_energy_multiplier = 2.4
	var tween := create_tween()
	tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.16)


func _set_flash_amount(amount: float) -> void:
	if visual_overlay == null:
		return
	visual_overlay.albedo_color = Color(phase_color.lerp(Color.WHITE, amount), 0.10 + amount * 0.42)
	visual_overlay.emission = phase_color.lerp(Color.WHITE, amount)
	visual_overlay.emission_energy_multiplier = 0.75 + amount * 1.65


func _fit_visual_to_height(content: Node3D, wanted_height: float) -> void:
	var bounds := _node_bounds(content)
	if bounds.size.y <= 0.001:
		return
	var scale_value := wanted_height / bounds.size.y
	content.scale = Vector3.ONE * scale_value
	content.position = Vector3(
		-(bounds.position.x + bounds.size.x * 0.5) * scale_value,
		-bounds.position.y * scale_value,
		-(bounds.position.z + bounds.size.z * 0.5) * scale_value
	)


func _node_bounds(content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if mesh.mesh == null:
			continue
		var to_content := content.global_transform.affine_inverse() * mesh.global_transform
		var mesh_bounds := to_content * mesh.get_aabb()
		bounds = mesh_bounds if not initialized else bounds.merge(mesh_bounds)
		initialized = true
	return bounds


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, color.a)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _transparent_material(color: Color) -> StandardMaterial3D:
	var material := _emissive_material(color, 1.4)
	material.no_depth_test = false
	return material


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
