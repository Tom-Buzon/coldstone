extends "res://scripts/enemy_v2/enemy_v2_combat_core.gd"


const RECOVERY_SECONDS := 0.28
const ATTACK_START_RANGE := 3.65
const FORMATION_ATTACK_APPROACH_RANGE := 5.35
const ATTACK_FACING_DOT := 0.72
const APPROACH_MOVE_FACING_DOT := 0.35
const FORMATION_APPROACH_SPEED_FACTOR := 0.78
const ENGAGE_RANGE := 22.0
const BAYONET_REUSE_SECONDS := 4.2

## Timing follows the actual baked clips. The third entry is the supplied
## two-handed Mixamo bayonet step, not an alias of another action.
const SPEAR_PATTERNS: Array[Dictionary] = [
	{
		"id": &"torso_thrust", "semantic": &"spear_thrust",
		"clip_length": 1.458, "speed": 1.25, "hit_time": 0.68,
		"hit_range": 2.95, "damage_mult": 1.65, "move_factor": 0.55,
		"minimum_distance": 1.05, "uses_shield": true,
	},
	{
		"id": &"low_thrust", "semantic": &"spear_thrust_low",
		"clip_length": 1.458, "speed": 1.32, "hit_time": 0.72,
		"hit_range": 2.55, "damage_mult": 1.75, "move_factor": 0.22,
		"minimum_distance": 0.80, "uses_shield": true,
	},
	{
		"id": &"bayonet_step", "semantic": &"spear_bayonet_step",
		"clip_length": 3.267, "speed": 2.25, "hit_time": 1.70,
		"hit_range": 3.35, "damage_mult": 2.10, "move_factor": 0.95,
		"minimum_distance": 1.10, "uses_shield": false,
	},
]

var bayonet_cooldown: float = 0.0

func formation_decision_tick(delta: float, attack_authorized: bool, moving_to_slot: bool) -> void:
	if not externally_controlled or state == State.DEAD or actor == null or actor.dead:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	bayonet_cooldown = maxf(0.0, bayonet_cooldown - delta)
	if guard_impact_time > 0.0:
		guard_impact_time = maxf(0.0, guard_impact_time - delta)
		if guard_impact_time <= 0.0 and state in [State.GUARD, State.APPROACH, State.RECOVERY]:
			_play_state_animation()
	if state not in [State.GUARD, State.APPROACH]:
		return
	if attack_authorized and can_accept_formation_attack():
		formation_attack_committed = true
		attack_entry_distance = _planar_target_distance()
		if attack_entry_distance <= ATTACK_START_RANGE and _target_facing_dot() >= ATTACK_FACING_DOT:
			_transition(State.ATTACK)
		elif state != State.APPROACH:
			_transition(State.APPROACH)
		return
	formation_attack_committed = false
	var wanted := State.APPROACH if moving_to_slot else State.GUARD
	if state != wanted:
		_transition(wanted)


func formation_action_tick(delta: float) -> void:
	external_motion_velocity = Vector3.ZERO
	if not externally_controlled or actor == null or actor.dead:
		return
	match state:
		State.APPROACH:
			if formation_attack_committed:
				external_motion_velocity = _formation_attack_approach_velocity()
		State.ATTACK:
			state_time += delta
			external_motion_velocity = _attack_motion_velocity()
			if not hit_delivered and state_time >= current_hit_time:
				hit_delivered = true
				actor.clear_attack_telegraph()
				_try_deliver_hit()
			if state_time >= current_attack_duration:
				_transition(State.RECOVERY)
		State.RECOVERY:
			state_time += delta
			if state_time >= RECOVERY_SECONDS:
				attack_cooldown = 0.58 + float(actor.get_instance_id() % 17) / 100.0
				_transition(State.GUARD)
		State.STUNNED:
			state_time += delta
			external_motion_velocity = _guard_break_velocity()
			if state_time >= stun_duration:
				attack_cooldown = maxf(attack_cooldown, 0.42)
				_transition(State.GUARD)


func can_accept_formation_attack() -> bool:
	return (
		externally_controlled
		and state in [State.GUARD, State.APPROACH]
		and attack_cooldown <= 0.0
		and target != null
		and is_instance_valid(target)
		and _planar_target_distance() <= FORMATION_ATTACK_APPROACH_RANGE
	)


func is_formation_engaged() -> bool:
	return externally_controlled and state in [State.ATTACK, State.RECOVERY, State.STUNNED]


func formation_overrides_movement() -> bool:
	return externally_controlled and (state in [State.ATTACK, State.STUNNED] or (state == State.APPROACH and formation_attack_committed))


func formation_motion_velocity() -> Vector3:
	return external_motion_velocity


func formation_facing_direction(fallback: Vector3) -> Vector3:
	if not externally_controlled or target == null or not is_instance_valid(target):
		return fallback
	if state == State.ATTACK or formation_attack_committed:
		var direction := target.global_position - actor.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	return fallback


func _physics_process(delta: float) -> void:
	if actor == null or actor.dead:
		shutdown()
		return
	if target == null or not is_instance_valid(target):
		_stop_horizontal_motion()
		_apply_gravity_and_move(delta)
		return
	state_time += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	bayonet_cooldown = maxf(0.0, bayonet_cooldown - delta)
	if guard_impact_time > 0.0:
		guard_impact_time = maxf(0.0, guard_impact_time - delta)
		if guard_impact_time <= 0.0 and state in [State.GUARD, State.APPROACH, State.RECOVERY]:
			_play_state_animation()
	_face_target(delta)
	var offset := target.global_position - actor.global_position
	var planar := Vector3(offset.x, 0.0, offset.z)
	var distance := planar.length()
	match state:
		State.GUARD:
			_stop_horizontal_motion()
			if distance <= ENGAGE_RANGE:
				if distance > ATTACK_START_RANGE:
					_transition(State.APPROACH)
				elif attack_cooldown <= 0.0:
					attack_entry_distance = distance
					_transition(State.ATTACK)
		State.APPROACH:
			if distance > ENGAGE_RANGE:
				_transition(State.GUARD)
			elif distance <= ATTACK_START_RANGE:
				attack_entry_distance = distance
				_transition(State.ATTACK if attack_cooldown <= 0.0 else State.GUARD)
			else:
				var direction := planar.normalized()
				actor.velocity.x = direction.x * actor.effective_move_speed()
				actor.velocity.z = direction.z * actor.effective_move_speed()
		State.ATTACK:
			_apply_attack_motion(planar, distance)
			if not hit_delivered and state_time >= current_hit_time:
				hit_delivered = true
				actor.clear_attack_telegraph()
				_try_deliver_hit()
			if state_time >= current_attack_duration:
				_transition(State.RECOVERY)
		State.RECOVERY:
			_stop_horizontal_motion()
			if state_time >= RECOVERY_SECONDS:
				# A readable guard beat between short attacks gives the aspis enough
				# real interception time without stretching the attack clips themselves.
				attack_cooldown = 0.58 + float(actor.get_instance_id() % 17) / 100.0
				_transition(State.GUARD)
		State.STUNNED:
			_apply_guard_break_step()
			if state_time >= stun_duration:
				attack_cooldown = maxf(attack_cooldown, 0.42)
				_transition(State.GUARD)
		State.DEAD:
			_stop_horizontal_motion()
	_apply_gravity_and_move(delta)


func _begin_attack_pattern() -> void:
	hit_delivered = false
	current_pattern = _select_attack_pattern(attack_entry_distance).duplicate()
	if StringName(current_pattern["id"]) == &"bayonet_step":
		bayonet_cooldown = BAYONET_REUSE_SECONDS
	var speed := float(current_pattern["speed"])
	current_attack_duration = float(current_pattern["clip_length"]) / speed
	current_hit_time = float(current_pattern["hit_time"]) / speed
	if actor.equipment != null:
		actor.equipment.set_weapon_grip(&"bayonet" if StringName(current_pattern["id"]) == &"bayonet_step" else &"standard")
		actor.equipment.set_guard_active(bool(current_pattern.get("uses_shield", false)))
	actor.play_semantic_animation(StringName(current_pattern["semantic"]), 0.10, speed)
	actor.begin_attack_telegraph(StringName(current_pattern["id"]), current_hit_time)


func _select_attack_pattern(distance: float) -> Dictionary:
	# Every animation owns a readable tactical use instead of participating in a
	# blind cycle: low thrust controls a crowded close range, torso thrust advances
	# behind the shield, and Bayonet is the exposed gap closer from the range edge.
	if distance <= 1.62:
		return SPEAR_PATTERNS[1]
	if distance >= 2.72 and bayonet_cooldown <= 0.0:
		return SPEAR_PATTERNS[2]
	return SPEAR_PATTERNS[0]


func _apply_attack_motion(planar_to_target: Vector3, distance: float) -> void:
	if current_pattern.is_empty() or planar_to_target.length_squared() < 0.0001:
		_stop_horizontal_motion()
		return
	var minimum_distance := float(current_pattern.get("minimum_distance", 1.0))
	if distance <= minimum_distance:
		_stop_horizontal_motion()
		return
	var direction := planar_to_target.normalized()
	var move_factor := float(current_pattern.get("move_factor", 0.0))
	# Continue through the strike, then decelerate during the authored follow-through.
	if hit_delivered:
		move_factor *= 0.35
	var attack_speed: float = float(actor.effective_move_speed()) * move_factor
	actor.velocity.x = direction.x * attack_speed
	actor.velocity.z = direction.z * attack_speed


func _attack_motion_velocity() -> Vector3:
	if current_pattern.is_empty() or target == null or not is_instance_valid(target):
		return Vector3.ZERO
	var planar_to_target := target.global_position - actor.global_position
	planar_to_target.y = 0.0
	var distance := planar_to_target.length()
	if planar_to_target.length_squared() < 0.0001 or distance <= float(current_pattern.get("minimum_distance", 1.0)):
		return Vector3.ZERO
	var move_factor := float(current_pattern.get("move_factor", 0.0))
	if hit_delivered:
		move_factor *= 0.35
	return planar_to_target.normalized() * float(actor.effective_move_speed()) * move_factor


func _formation_attack_approach_velocity() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	var planar_to_target := target.global_position - actor.global_position
	planar_to_target.y = 0.0
	var distance := planar_to_target.length()
	if distance <= ATTACK_START_RANGE or planar_to_target.length_squared() < 0.0001:
		return Vector3.ZERO
	# Turn first, then close the short spear gap. Translation never begins while
	# the authored +Z forward axis still points away from the target.
	if _target_facing_dot() < APPROACH_MOVE_FACING_DOT:
		return Vector3.ZERO
	return planar_to_target.normalized() * float(actor.effective_move_speed()) * FORMATION_APPROACH_SPEED_FACTOR


func _try_deliver_hit() -> void:
	if target == null or not is_instance_valid(target) or current_pattern.is_empty():
		return
	var to_target := target.global_position - actor.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	var forward := actor.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var direction := to_target.normalized() if distance > 0.01 else forward
	var hit_range := float(current_pattern["hit_range"])
	var damage: float = float(actor.effective_attack_damage()) * float(current_pattern["damage_mult"])
	if distance <= hit_range and forward.dot(direction) >= 0.35:
		if target.has_method("receive_enemy_hit"):
			target.call("receive_enemy_hit", damage, actor, direction)
		elif target.has_method("receive_ai_hit"):
			target.call("receive_ai_hit", damage, actor, direction)
	elif target.has_method("register_enemy_near_miss") and distance <= hit_range + 1.0:
		target.call("register_enemy_near_miss", actor)



func is_attack_committed() -> bool:
	return state in [State.ATTACK, State.RECOVERY]
