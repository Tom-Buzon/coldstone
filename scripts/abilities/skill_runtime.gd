extends Node

signal state_changed
const Profile = preload("res://scripts/abilities/skill_profile.gd")
const Damage = preload("res://scripts/abilities/skill_damage.gd")
const Projectile = preload("res://scripts/abilities/skill_projectile.gd")
const Flame = preload("res://scripts/abilities/flame_wall.gd")
var profile := Profile.new()
var player: Node3D
var ultimate_charge := 0.0
var ultimate: StringName = &""
var remaining := 0.0
var cast_remaining := 0.0
var ranged_active := false
var ranged_cooldown := 0.0
var ranged_pending := false
var ranged_power := 1.0
var edge_active := false
var edge_perfect := false
var edge_tick := 0.0
var mobility_elapsed := 100.0
var previous_mobility := false
var sword_saved_transform := Transform3D.IDENTITY
var sword_pose_owned := false
var posed_sword: Node3D
var plunge_active := false
var airborne_peak := 0.0
var wall_boost := false
var aura_tick := 0.0
var aura_target: Node3D
var enemy_refresh := 0.0
var observed: Dictionary = {}
var kill_waves: Array[Vector3] = []
var wave_generation := false
var hud_timer := 0.0
var save_dirty := false
var javelin_visual: MeshInstance3D
var controls: Node
var cinema: Node
var status_message := ""
var status_time := 0.0
var activation_buffer := 0.0
var aura_combo := 0
var aura_motion: StringName = &"dash"
var aura_velocity := Vector3.ZERO
var aura_search_timer := 0.0
var aura_attack_target: Node3D
var aura_strike_delay := 0.0
var aura_stuck := 0.0
var aura_last_position := Vector3.ZERO
var last_real_usec := 0
var thunder_charge := 0.0
var thunder_held := false
var thunder_release_pending := false
var aura_previous_target: Node3D
var aura_leg_target: Node3D
var aura_leg_elapsed := 0.0
var aura_leg_distance := 0.0
var aura_leg_origin := Vector3.ZERO

func configure(owner_player: Node3D) -> void:
	player = owner_player
	profile.load_settings()
	profile.changed.connect(_on_profile_changed)
	player.combat_hit.connect(_on_combat_hit)
	player.perfect_response_started.connect(_on_perfect)
	apply_profile()
	_ensure_actions()
	controls = preload("res://scripts/abilities/skill_input.gd").new()
	add_child(controls)
	controls.configure(self)
	cinema = preload("res://scripts/abilities/skill_cinematic.gd").new()
	add_child(cinema)
	cinema.configure(self)
	last_real_usec = Time.get_ticks_usec()
	var hud := preload("res://scripts/ui/skill_hud.gd").new()
	add_child(hud)
	hud.configure(self)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := minf((now - last_real_usec) / 1000000.0, 0.05)
	last_real_usec = now
	controls.reconcile_releases()
	controls.advance(real_delta)
	cinema.advance(real_delta)
	status_time = maxf(0.0, status_time - real_delta)
	if controls.activation_pending:
		controls.activation_pending = false
		if ultimate == &"" and active(profile.selected_ultimate) and ultimate_charge >= 99.99:
			activation_buffer = 0.65
		else:
			activation_buffer = 0.0
			notice(activation_reason())
	if activation_buffer > 0.0:
		activation_buffer -= real_delta
		if activate_ultimate(): activation_buffer = 0.0
		elif not player.parkour_active or activation_buffer <= 0.0:
			activation_buffer = 0.0
			notice(activation_reason())

func notice(message: String) -> void:
	status_message = message
	status_time = 2.4
	state_changed.emit()

func activation_reason() -> String:
	if ultimate != &"": return "Ultime déjà actif"
	if not active(profile.selected_ultimate): return "Ultime verrouillé · Paramètres → Compétences"
	if ultimate_charge < 99.99: return "Jauge insuffisante · %.0f / 100" % ultimate_charge
	if plunge_active: return "Terminer la frappe tellurique"
	return "Ultime indisponible pendant ce mouvement"

func select_ultimate(id: StringName) -> bool:
	if not id in Profile.ULTIMATES or not active(id):
		notice("Ultime verrouillé · Paramètres → Compétences")
		return false
	if ultimate == &"thunder" and id != ultimate: cancel_preparation()
	profile.selected_ultimate = id
	profile.emit_changed()
	notice("Ultime sélectionné · jauge %.0f / 100" % ultimate_charge)
	return true

func swap_weapon() -> void:
	if ultimate == &"thunder":
		cancel_preparation()
	if not active(&"ranged"):
		notice("Seconde arme verrouillée · Paramètres → Compétences")
		return
	player.reconcile_combat_holds()
	if player._equipment_swap_locked() or player.parkour_active or ultimate != &"" or plunge_active:
		notice("Changement d'arme après l'action en cours")
		return
	ranged_active = not ranged_active
	ranged_pending = false
	notice("JAVELOT" if ranged_active else "ÉPÉE")

func active(id: StringName) -> bool:
	return profile.active(id)

func value(id: StringName) -> float:
	return profile.value(id)

func _on_profile_changed() -> void:
	save_dirty = true
	apply_profile()
	state_changed.emit()

func flush_save() -> Error:
	if not save_dirty: return OK
	var result := profile.save_settings()
	if result == OK: save_dirty = false
	return result

func apply_profile() -> void:
	if player == null: return
	var health_ratio := clampf(player.health / maxf(player.max_health, 1.0), 0.0, 1.0)
	for id: StringName in [&"max_speed", &"acceleration", &"dash_duration", &"dash_max_charges", &"dash_recharge_duration", &"slide_turn_response", &"slide_max_charges", &"slide_recharge_duration", &"wall_run_max_distance", &"wall_run_max_chain_runs", &"wall_run_vertical_max_rise", &"wall_run_vertical_max_time", &"wall_jump_up_speed", &"max_health", &"health_regen_delay", &"perfect_regen_rate"]:
		player.set(id, int(value(id)) if id in [&"dash_max_charges", &"slide_max_charges", &"wall_run_max_chain_runs"] else value(id))
	player.health = health_ratio * player.max_health
	player.aim_assist_enabled = active(&"aim_assist")
	player._clear_attack_assist()
	if not active(&"block"): player._set_shield_blocking(false)
	if not active(&"perfect") and player.combat_feedback != null: player.combat_feedback.consume_perfect_response()
	player.health_regen_rate = value(&"health_regen_rate") if active(&"regen") else 0.0
	player.perfect_regen_rate = value(&"perfect_regen_rate") if active(&"regen") else 0.0
	player.max_jumps = int(value(&"max_jumps")) if active(&"air_jumps") else 1
	player.jump_velocity = jump_speed(0)
	player.dash_speed = value(&"dash_distance") / value(&"dash_duration") * 38.0 / 31.0
	player.dash_end_speed = player.dash_speed * 12.0 / 19.0
	player.slide_speed_ratio = value(&"slide_speed") / player.dash_speed
	player.slide_distance_ratio = value(&"slide_distance") / value(&"dash_distance")
	player.dash_charges = mini(player.dash_charges, player.dash_max_charges)
	player.slide_charges = mini(player.slide_charges, player.slide_max_charges)
	if not active(&"dash"): player.dash_time = 0.0
	if not active(&"slide"):
		player.slide_armed = false
		player._stop_slide()
	if player.wall_run_active and not wall_allowed(player.wall_run_surface_kind): player._detach_wall_run("skill disabled", false)
	if not active(&"ranged"): ranged_active = false
	if not active(&"edge"): edge_active = false
	if not active(&"plunge") and plunge_active:
		cancel_plunge()
	if ultimate != &"" and not active(ultimate): end_ultimate()
	if not active(&"flame"):
		for effect: Node in get_tree().get_nodes_in_group(&"player_skill_effect"):
			if effect.get_meta(&"skill", &"") == &"flame" and effect.get_meta(&"source", 0) == player.get_instance_id(): effect.queue_free()
	if player.heavy_charging and not attack_allowed(&"heavy", player._combat_context()): player._cancel_heavy_charge()
	if player.animation_driver != null and ultimate != &"aura":
		var slot: StringName = player.animation_driver.current_attack_slot_name()
		var context: StringName = player.animation_driver.current_attack_context_name()
		if (slot == &"spin360" and not active(&"spin_up" if player.spin_vertical_direction > 0 else &"spin_down")) or (String(slot).begins_with("light") and not attack_allowed(&"light", context)) or (slot == &"heavy" and not attack_allowed(&"heavy", context)):
			player.animation_driver._finish_attack(&"skill_disabled")

func jump_speed(index: int) -> float:
	return sqrt(2.0 * player.gravity * value(&"jump_1" if index == 0 else (&"jump_2" if index == 1 else &"jump_3")))

func wall_allowed(kind: StringName) -> bool:
	return active(&"wall") and (kind != &"giant_enemy" or active(&"giant_wall")) and (kind != &"phalanx_shields" or active(&"shield_wall"))

func attack_allowed(weight: StringName, context: StringName) -> bool:
	return active(StringName(String(weight) + "_" + String(context))) and cast_remaining <= 0.0 and not plunge_active and ultimate not in [&"aura", &"thunder"] and (controls == null or not controls.wheel.visible)

func on_wall_jump(kind: StringName) -> void:
	var prefix := "giant" if kind == &"giant_enemy" else ("shield" if kind == &"phalanx_shields" else "")
	if prefix.is_empty(): return
	if active(StringName(prefix + "_reset")):
		player.wall_run_runs_used = 0
		player.wall_run_attach_available = true
		player.wall_run_chain_armed_by_jump = true
		player.jumps_used = 0
	wall_boost = active(StringName(prefix + "_aim"))

func aim_multiplier(context: StringName) -> float:
	return value(StringName("aim_" + String(context))) * (value(&"wall_aim_bonus") if wall_boost else 1.0)

func tick(delta: float) -> void:
	# The current player has no death state: vitality can reach zero and recover.
	# Do not invent a separate skills-only death state that resets input every tick.
	# Landing can also arrive through floor snap, a teleport or a traversal exit,
	# without the false -> true edge observed by Player's movement callback.
	if plunge_active:
		if player.parkour_active or player.wall_run_active: cancel_plunge()
		elif player.is_on_floor(): on_landed()
	if ultimate == &"":
		cast_remaining = 0.0
		thunder_held = false
		thunder_release_pending = false
	ranged_cooldown = maxf(0.0, ranged_cooldown - delta)
	if player.is_on_floor():
		if not plunge_active: airborne_peak = player.global_position.y
		wall_boost = false
	else:
		airborne_peak = maxf(airborne_peak, player.global_position.y)
	if controls.plunge_pending:
		controls.plunge_pending = false
		if not plunge_active and active(&"plunge") and not player.is_on_floor() and not player.parkour_active and not player.wall_run_active and cast_remaining <= 0.0 and ultimate != &"thunder":
			begin_plunge()
		else: notice("Frappe tellurique : débloquer puis utiliser en l'air")
	if ranged_pending:
		ranged_pending = false
		if active(&"ranged") and ranged_active and ranged_cooldown <= 0.0:
			fire_projectile(false, value(&"ranged_damage") * ranged_power)
			ranged_cooldown = value(&"ranged_cooldown")
	var moving_attack: bool = player.dash_time > 0.0 or player.spin_active_time > 0.0
	mobility_elapsed = mobility_elapsed + delta if moving_attack and previous_mobility else (0.0 if moving_attack else 100.0)
	previous_mobility = moving_attack
	if controls.edge_pressed:
		controls.edge_pressed = false
		edge_perfect = mobility_elapsed <= value(&"edge_timing")
	edge_active = active(&"edge") and moving_attack and controls.edge_down and not ranged_active
	if edge_active:
		edge_tick -= delta
		if edge_tick <= 0.0:
			edge_tick = value(&"edge_interval")
			_edge_contacts()
	else: edge_tick = 0.0
	if ultimate != &"":
		if ultimate == &"thunder":
			if thunder_held:
				thunder_charge = minf(1.0, thunder_charge + delta / maxf(value(&"thunder_charge_time"), 0.1))
				if player.animation_driver != null: player.animation_driver.update_heavy_charge(thunder_charge)
			if thunder_release_pending:
				thunder_release_pending = false
				fire_projectile(true, value(&"thunder_damage") * lerpf(0.25, 1.0, pow(thunder_charge, 1.3)))
				cinema.accent(0.32, 0.35, 10.0)
				end_ultimate()
		elif cast_remaining > 0.0:
			cast_remaining = maxf(0.0, cast_remaining - delta)
			if cast_remaining <= 0.0:
				if ultimate == &"flame": _spawn_flame()
				elif ultimate == &"thunder": fire_projectile(true, value(&"thunder_damage"))
				end_ultimate()
		else:
			remaining = maxf(0.0, remaining - delta)
			# Expiry must not depend on target references or the next combat action.
			if remaining <= 0.0: end_ultimate()
			elif ultimate == &"aura": _tick_aura(delta)
	enemy_refresh -= delta
	if enemy_refresh <= 0.0:
		enemy_refresh = 0.5
		_observe_enemies()
	if not kill_waves.is_empty():
		var batch: Array[Vector3] = []
		for index: int in mini(8, kill_waves.size()): batch.append(kill_waves.pop_front())
		wave_generation = true
		for point: Vector3 in batch:
			Damage.radial(player, point, 2.8, value(&"ares_wave"), 6.0, &"ares_wave")
			_feedback(point, 2.8)
			cinema.vfx.burst(point, cinema.vfx.color_for(&"ares"), 2.8, true)
		wave_generation = false
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.10
		state_changed.emit()

func begin_plunge() -> void:
	if plunge_active: return
	plunge_active = true
	ranged_active = false
	player._cancel_heavy_charge()
	player._stop_slide()
	player.dash_time = 0.0
	cinema.begin_plunge()
	if player.animation_driver != null:
		player.animation_driver.play_external_attack(&"air_down", &"skill_plunge", &"air", true, 1.6, 0.04, 1.0, false, 0.08)

func on_landed() -> void:
	if not plunge_active: return
	plunge_active = false
	if player.animation_driver != null and player.animation_driver.current_attack_slot_name() == &"skill_plunge": player.animation_driver._finish_attack(&"landed")
	var height := clampf(airborne_peak - player.global_position.y, 0.0, value(&"plunge_cap"))
	var amount := value(&"plunge_base") + height * value(&"plunge_height")
	Damage.radial(player, player.global_position, value(&"plunge_radius"), amount, value(&"plunge_push") * (1.0 + height * 0.08), &"plunge")
	_feedback(player.global_position, value(&"plunge_radius"))
	cinema.impact(player.global_position, value(&"plunge_radius"))

func cancel_plunge() -> void:
	if not plunge_active: return
	plunge_active = false
	if cinema != null: cinema.cancel()
	if player.animation_driver != null and player.animation_driver.current_attack_slot_name() == &"skill_plunge": player.animation_driver._finish_attack(&"plunge_cancelled")

func cancel_preparation() -> void:
	# Only an uncommitted cast is refundable; running buffs and fired shots are not.
	if ultimate == &"thunder" or (ultimate == &"flame" and cast_remaining > 0.0):
		end_ultimate()
		add_charge(100.0)

func on_combat_action_started(action: Dictionary) -> void:
	var slot := StringName(action.get(&"slot", &""))
	if plunge_active and slot != &"skill_plunge": cancel_plunge()
	if slot not in [&"charge", &"javelin"]: cancel_preparation()

func steer_dash(delta: float) -> void:
	if player.perfect_counter_dash_active: return
	var desired: Vector3 = player._desired_move_direction()
	if ultimate == &"aura" and Damage.alive(aura_target): desired = (aura_target.global_position - player.global_position).normalized()
	if desired.length_squared() > 0.01:
		player.dash_direction = player._steer_flat_direction(player.dash_direction, desired, value(&"dash_turn"), delta)

func request_ranged(power: float = 1.0) -> bool:
	if not ranged_active: return false
	if active(&"ranged") and ranged_cooldown <= 0.0:
		ranged_power = power
		ranged_pending = true
	return true

func thunder_button(pressed: bool) -> void:
	if ultimate != &"thunder" or controls.wheel.visible: return
	if pressed:
		thunder_held = true
	elif thunder_held:
		thunder_held = false
		thunder_release_pending = true

func javelin_origin() -> Vector3:
	var view: Transform3D = player.camera.get_camera_transform()
	return player.global_position + Vector3.UP * 1.45 + view.basis.x * 0.65 - view.basis.z * 0.45

func fire_projectile(thunder: bool, amount: float) -> void:
	var shot := Projectile.new()
	shot.source = player
	shot.thunder = thunder
	shot.damage = amount
	shot.charge_ratio = thunder_charge if thunder else 0.0
	shot.speed = lerpf(180.0, 260.0, thunder_charge) if thunder else 48.0
	var origin: Vector3 = javelin_origin() if thunder else player.global_position + Vector3.UP * 1.25
	var aim: Vector3 = -player.camera.get_camera_transform().basis.z if player.camera != null else -player.global_basis.z
	var camera_origin: Vector3 = player.camera.get_camera_transform().origin if player.camera != null else origin
	var aim_point := camera_origin + aim * 150.0
	var sight := PhysicsRayQueryParameters3D.create(camera_origin, aim_point, (1 | 8) if thunder else (1 | 4 | 8 | 64 | 256))
	sight.collide_with_areas = true
	sight.exclude = [player.get_rid()]
	var sight_hit := player.get_world_3d().direct_space_state.intersect_ray(sight)
	if not sight_hit.is_empty(): aim_point = sight_hit.position
	shot.direction = (aim_point - origin).normalized()
	shot.position = origin
	get_tree().current_scene.add_child(shot)
	shot.global_position = origin
	if thunder:
		shot.lifetime = 1.1
		cinema.thunder_view.begin(shot)
	if player.animation_driver != null: player.animation_driver.play_external_attack(&"light1", &"javelin", player._combat_context(), false, 2.6, 0.035, 0.15, false, 0.10)
	if player.combat_feedback != null: player.combat_feedback.attack_started(&"heavy" if thunder else &"light1", 1.0 if thunder else 0.0)

func activate_ultimate() -> bool:
	var selected: StringName = profile.selected_ultimate
	if ultimate != &"" or ultimate_charge < 99.99 or not active(selected) or player.parkour_active or plunge_active: return false
	ultimate_charge = 0.0
	cast_remaining = 0.0
	remaining = 0.0
	ultimate = selected
	status_time = 0.0
	player._clear_attack_assist()
	player._reset_primary_attack_input()
	player._cancel_heavy_charge()
	player._set_shield_blocking(false)
	if player.animation_driver != null: player.animation_driver._finish_attack(&"ultimate")
	cinema.announce(selected, ["AURA MEURTRIÈRE", "FIRE WALL", "COUP DE TONNERRE", "WRATH OF ARES"][Profile.ULTIMATES.find(selected)])
	if selected != &"thunder": ranged_active = false
	remaining = value(StringName(String(selected) + "_duration"))
	if selected == &"flame":
		cast_remaining = value(&"flame_cast")
		if player.animation_driver != null: player.animation_driver.begin_heavy_charge(player._combat_context())
	elif selected == &"thunder":
		thunder_charge = 0.0
		thunder_held = Input.is_action_pressed(&"attack_primary")
		thunder_release_pending = false
		ranged_active = false
		notice("TONNERRE PRÊT · maintenir attaque puis relâcher")
		if player.animation_driver != null: player.animation_driver.begin_heavy_charge(player._combat_context())
	elif selected == &"aura":
		aura_tick = 0.0
		aura_combo = 0
		aura_previous_target = null
		aura_leg_target = null
		aura_search_timer = 0.0
		aura_last_position = player.global_position
		player._stop_slide()
		player.dash_time = 0.0
	if selected != &"flame": _feedback(player.global_position, 1.5)
	state_changed.emit()
	return true

func end_ultimate() -> void:
	var previous := ultimate
	ultimate = &""
	remaining = 0.0
	cast_remaining = 0.0
	status_time = 0.0
	thunder_held = false
	thunder_release_pending = false
	if previous != &"" and player != null: player._reset_primary_attack_input()
	if previous in [&"flame", &"thunder"] and player != null:
		player._set_sword_charge_visual(0.0)
		if player.animation_driver != null: player.animation_driver.cancel_heavy_charge()
	if previous == &"aura" and player != null:
		player.dash_time = 0.0
		player._stop_slide()
		aura_velocity = Vector3.ZERO
		aura_attack_target = null
		aura_strike_delay = 0.0
	aura_target = null
	aura_previous_target = null
	aura_leg_target = null
	state_changed.emit()

func cycle_ultimate() -> void:
	var start: int = Profile.ULTIMATES.find(profile.selected_ultimate)
	for offset: int in range(1, 5):
		var next: StringName = Profile.ULTIMATES[(start + offset) % 4]
		if active(next):
			select_ultimate(next)
			return

func _tick_aura(delta: float) -> void:
	aura_velocity = Vector3.ZERO
	if player.parkour_active or player.wall_run_active or plunge_active or controls.wheel.visible: return
	aura_tick = maxf(0.0, aura_tick - delta)
	if aura_strike_delay > 0.0:
		aura_strike_delay -= delta
		if aura_strike_delay > 0.0: return
		if Damage.alive(aura_attack_target):
			var offset: Vector3 = aura_attack_target.global_position - player.global_position
			if offset.length() <= 3.0 and player._attack_assist_has_line_of_sight(aura_attack_target.global_position + Vector3.UP):
				if Damage.deal(player, aura_attack_target, value(&"aura_damage") * 1.5, offset, 6.0, &"aura", 90.0):
					aura_previous_target = aura_attack_target
					cinema.vfx.burst(aura_attack_target.global_position, cinema.vfx.color_for(&"aura"), 1.6, false)
					cinema.aura_impact(aura_attack_target.global_position)
					player.combat_feedback.blade_whoosh(&"heavy", 20.0, &"aura")
		# Retarget on contact, not death. Never stay on the old target if another
		# reachable opponent exists; a single remaining opponent stays attackable.
		aura_target = _next_aura_target(aura_previous_target if is_instance_valid(aura_previous_target) else null)
		aura_leg_target = null
		aura_attack_target = null
		aura_tick = 0.0
	if not Damage.alive(aura_target): aura_target = _next_aura_target(aura_previous_target if is_instance_valid(aura_previous_target) else null)
	if aura_target == null: return
	if aura_leg_target != aura_target: _begin_aura_leg()
	aura_leg_elapsed += delta
	var to_target: Vector3 = aura_target.global_position - player.global_position
	var flat := Vector3(to_target.x, 0, to_target.z)
	if flat.length() > 1.35:
		aura_stuck = aura_stuck + delta if player.global_position.distance_to(aura_last_position) < 0.012 else 0.0
		aura_last_position = player.global_position
		if aura_stuck > 0.4:
			aura_target = _next_aura_target(aura_target)
			aura_leg_target = null
			return
		var forward := flat.normalized()
		var progress := clampf(1.0 - flat.length() / maxf(aura_leg_distance, 0.1), 0.0, 1.0)
		var curve := sin(progress * PI) * (0.28 if aura_motion == &"slide" else 0.10)
		var tangent := forward.cross(Vector3.UP) * (1.0 if aura_combo % 2 == 0 else -1.0)
		var speed := value(&"aura_speed") * (0.80 if aura_motion == &"slide" else (0.65 if aura_motion == &"jump" else 1.0))
		aura_velocity = (forward + tangent * curve).normalized() * minf(speed, maxf(0.0, flat.length() - 1.15) / maxf(delta, 0.001))
		player.slide_direction = forward
		player._face_direction(forward, 1.0)
	if flat.length() <= 1.6 and aura_leg_elapsed >= (0.12 if aura_motion == &"jump" else 0.07) and aura_tick <= 0.0:
		aura_tick = value(&"aura_interval")
		aura_combo += 1
		aura_attack_target = aura_target
		aura_strike_delay = 0.065
		player._face_direction(flat, 1.0)
		if player.animation_driver != null:
			player.animation_driver.play_attack_variant(&"heavy", player._combat_context(), aura_motion != &"slide", 2.8, 0.035, 0.9, true)

func _next_aura_target(excluded: Node3D) -> Node3D:
	var desired: Vector3 = player._desired_move_direction()
	if desired.length_squared() < 0.01: desired = player._camera_forward_flat()
	var reach := maxf(value(&"dash_distance"), value(&"slide_distance")) + 1.8
	var best := INF
	var chosen: Node3D
	var fallback: Node3D
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if not node is Node3D or not Damage.alive(node): continue
		if node.has_method("can_receive_hit_from") and not node.can_receive_hit_from(player): continue
		var offset: Vector3 = node.global_position - player.global_position
		if offset.length() > reach or absf(offset.y) > 3.0: continue
		if not player._attack_assist_has_line_of_sight(node.global_position + Vector3.UP): continue
		if node == excluded:
			fallback = node
			continue
		var score := offset.length() + (1.0 - desired.dot(offset.normalized())) * reach * 0.3
		if score < best:
			best = score
			chosen = node
	return chosen if chosen != null else fallback

func _begin_aura_leg() -> void:
	aura_leg_target = aura_target
	aura_leg_origin = player.global_position
	aura_leg_elapsed = 0.0
	aura_stuck = 0.0
	aura_last_position = player.global_position
	var offset: Vector3 = aura_target.global_position - player.global_position
	aura_leg_distance = Vector2(offset.x, offset.z).length()
	aura_motion = &"dash" if aura_leg_distance >= 3.2 else (&"slide" if aura_leg_distance >= 1.8 else &"jump")
	if aura_motion == &"slide" and not active(&"slide"): aura_motion = &"jump"
	player._stop_slide()
	if aura_motion == &"slide":
		player.slide_time = maxf(0.18, aura_leg_distance / maxf(value(&"aura_speed") * 0.8, 1.0))
		player.slide_direction = Vector3(offset.x, 0, offset.z).normalized()
		if player.animation_driver != null: player.animation_driver.start_slide_visual(player.slide_time)
	elif aura_motion == &"jump" and active(&"jump"):
		if player.is_on_floor() or offset.y > -0.5: player.velocity.y = 4.5
		if player.animation_driver != null: player.animation_driver.play_ninja_jump(2.0)
	cinema.aura_transfer(aura_target, aura_motion, aura_combo)

func owns_aura_movement() -> bool:
	return ultimate == &"aura" and not plunge_active and not player.wall_run_active and not player.parkour_active and not controls.wheel.visible

func _spawn_flame() -> void:
	var wall := Flame.new()
	wall.source = player
	wall.length = value(&"flame_length")
	wall.duration = value(&"flame_duration")
	wall.dps = value(&"flame_dps")
	wall.burn_duration = value(&"burn_duration")
	var forward: Vector3 = player._camera_forward_flat()
	var origin: Vector3 = player.global_position + forward * 1.5
	var sight := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, origin + forward * wall.length + Vector3.UP, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(sight)
	if not hit.is_empty(): wall.length = maxf(0.0, player.global_position.distance_to(hit.position - Vector3.UP) - 1.7)
	if wall.length < 0.5:
		wall.free()
		return
	wall.add_to_group(&"player_skill_effect")
	wall.set_meta(&"skill", &"flame")
	wall.set_meta(&"source", player.get_instance_id())
	get_tree().current_scene.add_child(wall)
	wall.global_position = origin
	wall.look_at(wall.global_position + forward, Vector3.UP)
	_feedback(origin, 1.0)
	cinema.accent(0.22, 0.3, 8.0)
	cinema.vfx.beam(origin + Vector3.UP * 0.1, origin + forward * wall.length + Vector3.UP * 0.1, cinema.vfx.color_for(&"flame"), 0.3, 0.6)

func _edge_contacts() -> void:
	var forward: Vector3 = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	if forward.length_squared() < 0.01: forward = player._camera_forward_flat()
	var right := forward.cross(Vector3.UP).normalized()
	var center: Vector3 = player.global_position + Vector3.UP * 1.1
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if not node is Node3D or not Damage.alive(node): continue
		var offset: Vector3 = node.global_position + Vector3.UP - center
		if absf(offset.dot(right)) <= 2.2 and absf(offset.dot(forward)) <= 0.8 and absf(offset.y) <= 1.0 and player._attack_assist_has_line_of_sight(node.global_position + Vector3.UP):
			Damage.deal(player, node, value(&"edge_damage") * (2.0 if edge_perfect else 1.0), forward, 1.0, &"edge", 8.0)

func presentation() -> void:
	if player.sword_root == null: return
	if sword_pose_owned and posed_sword != player.sword_root:
		if is_instance_valid(posed_sword): posed_sword.transform = sword_saved_transform
		sword_pose_owned = false
	if cast_remaining > 0.0: player._set_sword_charge_visual(1.0 - cast_remaining / maxf(value(&"flame_cast"), 0.001))
	if not is_instance_valid(javelin_visual) and player.sword_attachment != null:
		javelin_visual = MeshInstance3D.new()
		var shaft := CylinderMesh.new()
		shaft.height = 1.8
		shaft.top_radius = 0.0
		shaft.bottom_radius = 0.025
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.62, 0.40, 0.16)
		material.metallic = 0.6
		shaft.material = material
		javelin_visual.mesh = shaft
		javelin_visual.position.y = 0.55
		player.sword_attachment.add_child(javelin_visual)
	if is_instance_valid(javelin_visual): javelin_visual.visible = ranged_active
	if edge_active:
		if not sword_pose_owned:
			sword_saved_transform = player.sword_root.transform
			posed_sword = player.sword_root
			sword_pose_owned = true
		var forward: Vector3 = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
		if forward.length_squared() < 0.01: forward = player._camera_forward_flat()
		var blade := forward.cross(Vector3.UP).normalized()
		player.sword_root.global_basis = Basis(Vector3.UP, blade, Vector3.UP.cross(blade)).scaled(sword_saved_transform.basis.get_scale())
	elif sword_pose_owned:
		player.sword_root.transform = sword_saved_transform
		sword_pose_owned = false
	player.sword_root.visible = not ranged_active and ultimate != &"thunder"

func modify_hit(hit: Variant) -> void:
	if hit.has_meta(&"skill_modified"): return
	hit.set_meta(&"skill_modified", true)
	hit.damage *= value(&"damage")
	hit.sever_damage *= value(&"damage")
	if ultimate == &"ares":
		hit.impulse *= value(&"ares_push")
		hit.destroy_shield = true
		hit.attack_charge_ratio = 1.0

func prepare_hit(collider: Node) -> void:
	var owner_actor: Node = collider.get_combat_owner() if collider.has_method("get_combat_owner") else collider
	if is_instance_valid(owner_actor): owner_actor.set_meta(&"last_skill_source", player.get_instance_id())

func _on_combat_hit(target: Node, _zone: StringName, hit: Variant) -> void:
	prepare_hit(target)
	var owner_actor: Node = target.get_combat_owner() if target.has_method("get_combat_owner") else target
	if ultimate == &"ares" and is_instance_valid(owner_actor) and owner_actor.has_method("destroy_skill_shield"):
		owner_actor.destroy_skill_shield()
	if hit != null and ultimate == &"ares":
		cinema.vfx.burst(hit.position, cinema.vfx.color_for(&"ares"), 1.8, false)
		cinema.accent(0.10, 0.55, 4.0)
	if hit != null and ultimate == &"ares" and Damage.alive(owner_actor):
		var combat: Variant = owner_actor.get("combat")
		if combat is Node and combat.has_method("on_guard_broken"):
			combat.on_guard_broken(0.35, minf(hit.impulse.length() * 0.22, 7.0), hit.direction)

func _on_perfect(_kind: StringName) -> void:
	if active(&"perfect_charge"): add_charge(value(&"perfect_reward"))

func add_charge(amount: float) -> void:
	ultimate_charge = clampf(ultimate_charge + amount, 0.0, 100.0)
	state_changed.emit()

func _observe_enemies() -> void:
	for id: int in observed.keys():
		if not is_instance_id_valid(id): observed.erase(id)
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		observe_enemy(node)

func observe_enemy(node: Node) -> void:
	if observed.has(node.get_instance_id()): return
	observed[node.get_instance_id()] = true
	if node.has_signal("zone_severed"): node.connect("zone_severed", _on_sever)
	if node.has_signal("died"): node.connect("died", _on_death)

func _on_sever(enemy: Node, _zone: StringName) -> void:
	if active(&"sever_charge") and int(enemy.get_meta(&"last_skill_source", 0)) == player.get_instance_id(): add_charge(value(&"sever_reward"))

func _on_death(enemy: Node) -> void:
	if ultimate == &"ares" and int(enemy.get_meta(&"last_skill_source", 0)) == player.get_instance_id():
		kill_waves.append(enemy.global_position)

func _feedback(point: Vector3, radius: float) -> void:
	if player.combat_feedback != null: player.combat_feedback.spiral_smash(point, radius)

func _ensure_actions() -> void:
	var bindings := {&"skill_weapon_swap": KEY_E, &"skill_edge": KEY_F, &"skill_plunge": KEY_X, &"skill_ultimate": KEY_Q, &"skill_ultimate_next": KEY_T}
	for id: StringName in bindings:
		if InputMap.has_action(id): continue
		InputMap.add_action(id)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[id]
		InputMap.action_add_event(id, event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		activation_buffer = 0.0
		if controls != null: controls.cancel()

func _exit_tree() -> void:
	if sword_pose_owned and is_instance_valid(posed_sword): posed_sword.transform = sword_saved_transform
