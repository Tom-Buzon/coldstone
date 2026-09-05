extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")

class ConfirmedDecapTarget extends Node:
	var severed_zone: StringName = &"head"
	func is_combat_zone_severed(zone: StringName) -> bool:
		return zone == severed_zone
	func is_dead_for_combat() -> bool:
		return severed_zone == &"head"

class CombatOwnerProxy extends Node:
	var combat_owner: Node
	func get_combat_owner() -> Node:
		return combat_owner

class SpiralSmashTarget extends CharacterBody3D:
	var received_hit: Variant
	func receive_spiral_smash(hit: Variant) -> bool:
		received_hit = hit
		velocity = hit.impulse
		return true
	func _physics_process(delta: float) -> void:
		if received_hit == null:
			return
		velocity.y -= 24.0 * delta
		move_and_slide()

var world: Node3D
var player: HopliteUALNativePlayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = Node3D.new()
	world.name = "CombatAttackProbeWorld"
	get_root().add_child(world)
	current_scene = world
	_add_floor()

	player = PlayerScript.new() as HopliteUALNativePlayer
	world.add_child(player)
	for _frame: int in range(4):
		await physics_frame
		await process_frame

	if player.animation_driver == null or player.sword_tip == null:
		push_error("[COMBAT ATTACK PROBE] player animation setup unavailable")
		quit(1)
		return

	var failures: int = 0
	var camera_arm_distance: float = player.camera.position.length() if player.camera != null else 0.0
	var camera_tps_ok: bool = player.spring_arm != null and player.camera != null and player.spring_arm.spring_length >= 1.0 and camera_arm_distance >= 0.8
	print("[COMBAT ATTACK PROBE] camera_tps | mode=", player.get_camera_mode(), " target_distance=", snappedf(player.get_camera_distance(), 0.1), " actual_offset=", snappedf(camera_arm_distance, 0.01), " valid=", camera_tps_ok)
	if not camera_tps_ok:
		failures += 1
	if player.get_camera_mode_labels() != ["TPS GLOBAL"]:
		failures += 1
	var saved_camera_distance: float = player.get_camera_distance()
	player.set_camera_distance(0.1, false)
	if not is_equal_approx(player.get_camera_distance(), 1.0):
		failures += 1
	player.set_camera_distance(saved_camera_distance, false)
	player.camera_yaw.rotation.y = 0.82
	player.rotation.y = -0.35
	player._update_camera(0.5)
	if absf(player.camera_yaw.rotation.y - 0.82) > 0.001:
		failures += 1
	player.camera_yaw.rotation.y = 0.0
	player.rotation.y = PI
	Input.action_press("move_back")
	var backward_facing: Vector3 = player._attack_input_facing_direction()
	Input.action_release("move_back")
	if backward_facing.dot(-player.global_basis.z) < 0.98:
		failures += 1
	player.rotation.y = 0.0
	for light_index: int in range(1, 4):
		var light_key := StringName("light%d" % light_index)
		var light_started: bool = player.animation_driver.play_external_attack(light_key, light_key, &"idle", false, 2.35 if light_index == 1 else (2.45 if light_index == 2 else 1.85), 0.045, 0.42, false, 0.10)
		var light_result: Dictionary = await _sample_current_attack("light%d_idle" % light_index)
		if not light_started or StringName(light_result.get("clip", StringName())) != StringName("external:light%d" % light_index):
			failures += 1
	player.velocity = Vector3(5.0, 0.0, 0.0)
	player._begin_heavy_input(player.heavy_charge_max * 0.80)
	var charged: bool = player.heavy_charging
	var charge_clip: StringName = player.animation_driver.current_attack_clip
	player._release_heavy_attack()
	var released: bool = player.animation_driver.is_attack_active()
	var heavy_result: Dictionary = await _sample_current_attack("heavy_run")
	if not charged or not released or charge_clip != &"Sword_Regular_C" or StringName(heavy_result.get("clip", StringName())) != &"external:heavy_release":
		failures += 1

	player.velocity = Vector3.ZERO
	player.spiral_stamina = player.max_spiral_stamina
	player._do_spin_attack(1)
	var high_result: Dictionary = await _sample_current_attack("spiral_high")
	if StringName(high_result.get("clip", StringName())) != &"external:spin_high":
		failures += 1

	# Wait out the input guard as well as the animation lifecycle.
	for _frame: int in range(18):
		await physics_frame
		await process_frame
	player._do_spin_attack(-1)
	var low_result: Dictionary = await _sample_current_attack("spiral_low")
	if StringName(low_result.get("clip", StringName())) != &"external:spin_low":
		failures += 1
	if float(low_result.get("azimuth_coverage", 0.0)) < 270.0:
		failures += 1
	if not is_equal_approx(player.spiral_stamina, player.max_spiral_stamina - player.spiral_stamina_cost * 2.0):
		failures += 1
	player.spiral_stamina = 0.0
	player.spin_input_cooldown_timer = 0.0
	player._do_spin_attack(1)
	if player.spin_active_time > 0.0:
		failures += 1
	player._register_combat_hit_stamina()
	if not is_equal_approx(player.spiral_stamina, 1.0):
		failures += 1

	player.animation_driver.play_external_attack(&"spin_low_alt", &"spin360", &"idle", true, 3.20, 0.045, 0.72, false, 0.10)
	var old_low_result: Dictionary = await _sample_current_attack("spiral_low_alternative")
	if float(low_result.get("azimuth_coverage", 0.0)) <= float(old_low_result.get("azimuth_coverage", 0.0)):
		failures += 1

	# All grounded locomotion states keep the circular low/high silhouettes. Only
	# aerial Spiral Down switches to the authored plunge used by the landing smash.
	for context: StringName in [&"idle", &"run", &"dash", &"slide"]:
		if player._spiral_external_key(-1, context) != &"spin_low" or player._spiral_external_key(1, context) != &"spin_high":
			failures += 1
	if player._spiral_external_key(-1, &"air") != &"air_down" or player._spiral_external_key(1, &"air") != &"spin_high":
		failures += 1
	player.slide_time = 0.0
	player.dash_time = 0.0
	player.dash_variant_grace = 0.0
	player.velocity = Vector3.ZERO
	if player._combat_context() != &"idle":
		failures += 1
	player.velocity = Vector3(4.0, 0.0, 0.0)
	if player._combat_context() != &"run":
		failures += 1
	player.dash_time = 0.15
	if player._combat_context() != &"dash":
		failures += 1
	player.slide_time = 0.15
	if player._combat_context() != &"slide":
		failures += 1
	player.slide_time = 0.0
	player.dash_time = 0.0
	player.velocity = Vector3.ZERO

	# Ordinary aerial light/heavy attacks must preserve their current trajectory
	# and must never borrow the Spiral Down plunge animation.
	player.global_position = Vector3(0.0, 2.6, 0.0)
	for _frame: int in range(2):
		await physics_frame
		await process_frame
	player.velocity = Vector3(1.25, 3.4, -0.75)
	var light_air_velocity: Vector3 = player.velocity
	player._do_light_attack()
	var light_air_ok: bool = player.animation_driver.current_attack_context_name() == &"air" and player.animation_driver.current_attack_clip != &"external:air_down" and player.velocity.is_equal_approx(light_air_velocity)
	player.animation_driver.call("_finish_attack")
	player.call("_clear_attack_assist")
	player.velocity = Vector3(-0.8, 2.7, 1.1)
	player._begin_heavy_input(player.heavy_charge_max * 0.62)
	var heavy_air_velocity: Vector3 = player.velocity
	player._release_heavy_attack()
	var heavy_air_ok: bool = player.animation_driver.current_attack_context_name() == &"air" and player.animation_driver.current_attack_clip != &"external:air_down" and player.velocity.is_equal_approx(heavy_air_velocity)
	player.animation_driver.call("_finish_attack")
	player.call("_clear_attack_assist")
	player.spiral_stamina = player.spiral_stamina_cost
	player.spin_input_cooldown_timer = 0.0
	player.spin_up_air_used = false
	player.velocity = Vector3(0.4, -1.2, -0.3)
	player._do_spin_attack(1)
	var spiral_up_ok: bool = player.animation_driver.current_attack_clip == &"external:spin_high" and is_equal_approx(player.velocity.y, player.jump_velocity * 0.72)
	print("[COMBAT ATTACK PROBE] aerial_trajectory | light=", light_air_ok, " heavy=", heavy_air_ok, " spiral_up=", spiral_up_ok)
	if not light_air_ok or not heavy_air_ok or not spiral_up_ok:
		failures += 1
	player.animation_driver.call("_finish_attack")
	player.spin_active_time = 0.0
	player.spin_vertical_direction = 0
	player.global_position = Vector3(0.0, 0.12, 0.0)
	player.velocity = Vector3.ZERO
	for _frame: int in range(60):
		await physics_frame
		await process_frame
		if player.is_on_floor():
			break

	# Four charges produce four complete buffered executions instead of four
	# restarts of frame zero.
	player.spiral_stamina = player.max_spiral_stamina
	var executed_spirals: Array[StringName] = []
	var execution_tracker := func(slot: StringName, context: StringName, _power: float) -> void:
		if slot == &"spin360":
			executed_spirals.append(context)
	player.combat_attack_started.connect(execution_tracker)
	for _charge: int in range(4):
		player.spin_input_cooldown_timer = 0.0
		player._do_spin_attack(-1)
	if not is_zero_approx(player.spiral_stamina) or player.animation_driver.attack_queue.size() != 3:
		failures += 1
	for _frame: int in range(280):
		await physics_frame
		await process_frame
		if not player.animation_driver.is_attack_active() and player.animation_driver.attack_queue.is_empty():
			break
	player.combat_attack_started.disconnect(execution_tracker)
	if executed_spirals.size() != 4:
		failures += 1

	var smash_target := SpiralSmashTarget.new()
	smash_target.name = "SpiralSmashFullTarget"
	smash_target.collision_layer = 4
	smash_target.collision_mask = 1 | 2
	var smash_body_collision := CollisionShape3D.new()
	var smash_body_shape := CapsuleShape3D.new()
	smash_body_shape.radius = 0.39
	smash_body_shape.height = 1.82
	smash_body_collision.shape = smash_body_shape
	smash_body_collision.position.y = 0.91
	smash_target.add_child(smash_body_collision)
	smash_target.add_to_group("enemy")
	world.add_child(smash_target)
	player.global_position = Vector3(0.0, 2.6, 0.0)
	player.velocity = Vector3.ZERO
	smash_target.global_position = Vector3.ZERO
	for _frame: int in range(2):
		await physics_frame
		await process_frame
	player.spiral_stamina = player.spiral_stamina_cost
	player.spin_input_cooldown_timer = 0.0
	player._do_spin_attack(-1)
	var aerial_clip_ok: bool = player.animation_driver.current_attack_clip == &"external:air_down" and player.animation_driver.current_attack_context_name() == &"air" and player.spiral_down_air_impact_pending
	for _frame: int in range(180):
		await physics_frame
		await process_frame
		if player.is_on_floor() and not player.spiral_down_air_impact_pending:
			break
	var smash_hit: Variant = smash_target.received_hit
	# The descending blade can legitimately cross this full-body fixture before
	# floor impact. In that branch the radial follow-up is intentionally reduced
	# to 38% (see `_trigger_spiral_down_impact`); both outcomes still prove the
	# radial event, guard damage and bounded knockback contract.
	var smash_damage: float = float(smash_hit.damage) if smash_hit != null else -1.0
	var expected_smash_damage: bool = is_equal_approx(smash_damage, player.spiral_down_impact_damage) or is_equal_approx(smash_damage, player.spiral_down_impact_damage * 0.38)
	var smash_ok: bool = smash_hit != null and expected_smash_damage and is_equal_approx(float(smash_hit.guard_damage), player.spiral_down_impact_guard_damage) and absf(smash_hit.impulse.length() - player.spiral_down_impact_knockback) <= 0.001
	var smash_vfx_ok: bool = world.get_node_or_null("SpiralSmashWave") != null and world.get_node_or_null("SpiralSmashDust") != null
	var passed_through_enemy_body: bool = player.global_position.y < 0.45 and player.spiral_down_enemy_passthrough
	print("[COMBAT ATTACK PROBE] spiral_smash | aerial_clip=", aerial_clip_ok, " radial_hit=", smash_ok, " radial_damage=", smash_damage, "/", player.spiral_down_impact_damage, " guard=", float(smash_hit.guard_damage) if smash_hit != null else -1.0, "/", player.spiral_down_impact_guard_damage, " impulse=", smash_hit.impulse.length() if smash_hit != null else -1.0, "/", player.spiral_down_impact_knockback, " vfx=", smash_vfx_ok, " enemy_passthrough=", passed_through_enemy_body, " player_y=", snappedf(player.global_position.y, 0.01), " target_y=", snappedf(smash_target.global_position.y, 0.01), " pending=", player.spiral_down_air_impact_pending, " passthrough_active=", player.spiral_down_enemy_passthrough, " executions=", executed_spirals.size())
	if not aerial_clip_ok or not smash_ok or not smash_vfx_ok or not passed_through_enemy_body:
		failures += 1
	for _frame: int in range(120):
		await physics_frame
		await process_frame
		if not player.animation_driver.is_attack_active() and not player.spiral_down_enemy_passthrough:
			break
	if player.spiral_down_enemy_passthrough:
		failures += 1
	smash_target.remove_from_group("enemy")
	smash_target.queue_free()

	player.slide_time = 0.90
	player.light_step = 0
	player._do_light_attack()
	var slide_left_result: Dictionary = await _sample_current_attack("slide_left")
	if StringName(slide_left_result.get("clip", StringName())) != &"external:slide_left":
		failures += 1
	player.slide_time = 0.90
	player.light_step = 1
	player._do_light_attack()
	var slide_right_result: Dictionary = await _sample_current_attack("slide_right")
	if StringName(slide_right_result.get("clip", StringName())) != &"external:slide_right":
		failures += 1
	player.slide_time = 0.0

	var mock_target := Node3D.new()
	mock_target.name = "AssistProbeTarget"
	mock_target.add_to_group("enemy")
	var preferred: Vector3 = player._camera_forward_flat()
	var target_direction: Vector3 = Basis(Vector3.UP, deg_to_rad(20.0)) * preferred
	world.add_child(mock_target)
	mock_target.global_position = player.global_position + target_direction * 2.18
	var start_position: Vector3 = player.global_position
	var start_yaw: float = player.rotation.y
	player._do_light_attack()
	for _frame: int in range(12):
		await physics_frame
		await process_frame
	var yaw_change: float = absf(wrapf(player.rotation.y - start_yaw, -PI, PI))
	var lunge_distance: float = Vector2(player.global_position.x - start_position.x, player.global_position.z - start_position.z).length()
	var acquired: bool = player.attack_assist_target == mock_target
	print("[COMBAT ATTACK PROBE] assist | acquired=", acquired, " yaw_change_deg=", snappedf(rad_to_deg(yaw_change), 0.01), " movement=", snappedf(lunge_distance, 0.001))
	if not acquired or yaw_change < deg_to_rad(3.0) or lunge_distance < 0.05:
		failures += 1
	mock_target.global_position.y = player.global_position.y + 4.0
	player.attack_assist_context = &"air"
	player.attack_assist_lock_remaining = 0.5
	player.velocity.y = -4.0
	player._update_attack_assist(0.10)
	if player.velocity.y <= -3.5:
		failures += 1
	mock_target.remove_from_group("enemy")
	mock_target.queue_free()
	var recoil_target := Node3D.new()
	world.add_child(recoil_target)
	recoil_target.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)
	var shield_contact = HitEventScript.new()
	shield_contact.contact_type = &"shield"
	player.velocity = Vector3(0.0, 0.0, -7.0)
	player._apply_attacker_contact_response(shield_contact, recoil_target)
	var shield_recoil_ok: bool = player.velocity.z > 0.0
	print("[COMBAT ATTACK PROBE] shield_recoil | stopped_and_repelled=", shield_recoil_ok, " velocity_z=", snappedf(player.velocity.z, 0.01))
	if not shield_recoil_ok:
		failures += 1
	player.velocity = Vector3.ZERO
	recoil_target.queue_free()

	player.combat_feedback.shield_blocked(42.0, null)
	await process_frame
	var shield_vfx_ok: bool = world.get_node_or_null("ShieldImpactSparks") != null and world.get_node_or_null("ShieldImpactFlash") != null and world.get_node_or_null("ShieldImpactDisc") != null
	print("[COMBAT ATTACK PROBE] shield_feedback | vfx=", shield_vfx_ok, " time_scale=", Engine.time_scale)
	if not shield_vfx_ok or not is_equal_approx(Engine.time_scale, 1.0):
		failures += 1
	player._set_shield_blocking(true)
	var shield_animation_ok: bool = player.animation_driver.play_block_impact() and player.animation_driver.block_impact_timer > 0.0
	print("[COMBAT ATTACK PROBE] shield_animation | impact_clip=", shield_animation_ok)
	if not shield_animation_ok:
		failures += 1
	player._set_shield_blocking(false)

	var ordinary_hit = HitEventScript.new()
	ordinary_hit.attack_slot = &"light1"
	ordinary_hit.damage = 18.0
	ordinary_hit.sever_damage = 12.0
	ordinary_hit.direction = Vector3.RIGHT
	ordinary_hit.position = player.global_position + Vector3.UP
	ordinary_hit.hit_material = &"flesh"
	ordinary_hit.contact_type = &"flesh"
	player.combat_feedback.weapon_hit(ordinary_hit, &"torso", null)
	var ordinary_scale_ok: bool = is_equal_approx(Engine.time_scale, 1.0) and not player.combat_feedback.cinematic_active

	var cinematic_target := ConfirmedDecapTarget.new()
	world.add_child(cinematic_target)
	var anatomy_proxy := CombatOwnerProxy.new()
	anatomy_proxy.combat_owner = cinematic_target
	world.add_child(anatomy_proxy)
	var decap_hit = HitEventScript.new()
	decap_hit.attack_slot = &"heavy"
	decap_hit.damage = 90.0
	decap_hit.sever_damage = 145.0
	decap_hit.direction = Vector3.RIGHT
	decap_hit.position = player.global_position + Vector3.UP * 1.7
	decap_hit.hit_material = &"flesh"
	decap_hit.contact_type = &"flesh"
	var resolved_owner: Node = player._combat_feedback_target(anatomy_proxy)
	player.combat_feedback.weapon_hit(decap_hit, &"head", resolved_owner)
	var rare_cinematic_ok: bool = player.combat_feedback.cinematic_active and is_equal_approx(Engine.time_scale, 0.28)
	player.combat_feedback.cinematic_active = false
	player.combat_feedback.cinematic_cooldown_until_ms = 0
	Engine.time_scale = 1.0
	var limb_target := ConfirmedDecapTarget.new()
	limb_target.severed_zone = &"forearm_r"
	world.add_child(limb_target)
	var limb_hit = HitEventScript.new()
	limb_hit.attack_slot = &"heavy"
	limb_hit.damage = 70.0
	limb_hit.sever_damage = 90.0
	limb_hit.direction = Vector3.LEFT
	limb_hit.position = player.global_position + Vector3(0.4, 1.0, 0.0)
	limb_hit.hit_material = &"flesh"
	limb_hit.contact_type = &"flesh"
	player.combat_feedback.weapon_hit(limb_hit, &"forearm_r", limb_target)
	var rare_limb_ok: bool = player.combat_feedback.cinematic_active and is_equal_approx(Engine.time_scale, 0.28)
	print("[COMBAT ATTACK PROBE] cinematic | ordinary_no_slow=", ordinary_scale_ok, " resolved_owner=", resolved_owner == cinematic_target, " confirmed_decap=", rare_cinematic_ok, " violent_limb=", rare_limb_ok)
	if not ordinary_scale_ok or resolved_owner != cinematic_target or not rare_cinematic_ok or not rare_limb_ok:
		failures += 1

	print("[COMBAT ATTACK PROBE] failures=", failures)
	world.free()
	quit(1 if failures > 0 else 0)

func _sample_current_attack(label: String) -> Dictionary:
	var driver: HopliteNativeAnimationDriver = player.animation_driver
	var clip: StringName = driver.current_attack_clip
	var slot: StringName = driver.current_attack_slot_name()
	var context: StringName = driver.current_attack_context_name()
	var path_length: float = 0.0
	var horizontal_span: float = 0.0
	var vertical_min: float = INF
	var vertical_max: float = -INF
	var previous: Vector3 = player.to_local(player.sword_tip.global_position)
	var origin: Vector3 = previous
	var attack_origin_global: Vector3 = player.global_position
	var samples: int = 0
	var blade_elevation_min: float = INF
	var blade_elevation_max: float = -INF
	var blade_elevation_sum: float = 0.0
	var upward_samples: int = 0
	var peak_step: float = 0.0
	var peak_progress: float = 0.0
	var peak_motion: Vector3 = Vector3.ZERO
	var azimuth_bins: Dictionary = {}
	for _frame: int in range(120):
		await physics_frame
		await process_frame
		var point: Vector3 = player.to_local(player.sword_tip.global_position)
		# World-space coverage includes the mechanical root revolution used to
		# restore yaw removed by Mixamo retargeting.
		var world_point: Vector3 = player.sword_tip.global_position - attack_origin_global
		var radial_point := Vector2(world_point.x, world_point.z)
		if radial_point.length() > 0.18:
			var azimuth: float = wrapf(atan2(radial_point.y, radial_point.x), 0.0, TAU)
			azimuth_bins[int(floor(azimuth / TAU * 24.0)) % 24] = true
		var step_motion: Vector3 = point - previous
		var step_length: float = step_motion.length()
		path_length += step_length
		if step_length > peak_step:
			peak_step = step_length
			peak_motion = step_motion.normalized() if step_length > 0.0001 else Vector3.ZERO
			peak_progress = driver.current_attack_progress()
		horizontal_span = maxf(horizontal_span, Vector2(point.x - origin.x, point.z - origin.z).length())
		vertical_min = minf(vertical_min, point.y)
		vertical_max = maxf(vertical_max, point.y)
		previous = point
		var blade_direction: Vector3 = player.sword_tip.global_position - player.sword_base.global_position
		if blade_direction.length_squared() > 0.0001:
			var elevation: float = rad_to_deg(asin(clampf(blade_direction.normalized().y, -1.0, 1.0)))
			blade_elevation_min = minf(blade_elevation_min, elevation)
			blade_elevation_max = maxf(blade_elevation_max, elevation)
			blade_elevation_sum += elevation
			if elevation > 50.0:
				upward_samples += 1
		samples += 1
		if not driver.is_attack_active():
			break
	var vertical_span: float = maxf(0.0, vertical_max - vertical_min)
	var average_elevation: float = blade_elevation_sum / maxf(float(samples), 1.0)
	var upward_ratio: float = float(upward_samples) / maxf(float(samples), 1.0)
	var azimuth_coverage: float = float(azimuth_bins.size()) / 24.0 * 360.0
	print(
		"[COMBAT ATTACK PROBE] ", label,
		" | slot=", slot,
		" context=", context,
		" clip=", clip,
		" samples=", samples,
		" tip_path=", snappedf(path_length, 0.001),
		" horizontal_span=", snappedf(horizontal_span, 0.001),
		" vertical_span=", snappedf(vertical_span, 0.001),
		" blade_elevation=", snappedf(blade_elevation_min, 0.1), "..", snappedf(blade_elevation_max, 0.1),
		" avg=", snappedf(average_elevation, 0.1),
		" upward_ratio=", snappedf(upward_ratio, 0.01),
		" peak_progress=", snappedf(peak_progress, 0.01),
		" peak_motion_y=", snappedf(peak_motion.y, 0.01),
		" azimuth_coverage=", snappedf(azimuth_coverage, 1.0)
	)
	return {
		"clip": clip,
		"slot": slot,
		"context": context,
		"tip_path": path_length,
		"horizontal_span": horizontal_span,
		"vertical_span": vertical_span,
		"blade_elevation_average": average_elevation,
		"upward_ratio": upward_ratio,
		"azimuth_coverage": azimuth_coverage
	}

func _add_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12.0, 0.2, 12.0)
	collision.shape = shape
	collision.position.y = -0.1
	floor.add_child(collision)
	world.add_child(floor)
