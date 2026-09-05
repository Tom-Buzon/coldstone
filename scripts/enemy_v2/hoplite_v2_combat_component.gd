extends Node
class_name HopliteV2CombatComponent

enum State { GUARD, APPROACH, ATTACK, RECOVERY, STUNNED, DEAD }

const RECOVERY_SECONDS := 0.28
const ATTACK_START_RANGE := 3.65
const FORMATION_ATTACK_APPROACH_RANGE := 5.35
const ATTACK_FACING_DOT := 0.72
const APPROACH_MOVE_FACING_DOT := 0.35
const FORMATION_APPROACH_SPEED_FACTOR := 0.78
const ENGAGE_RANGE := 22.0
const TURN_SPEED := 9.0
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

var actor: CharacterBody3D
var target: Node3D
var guard_component: CombatGuardComponent
var state: State = State.GUARD
var state_time: float = 0.0
var attack_cooldown: float = 0.0
var hit_delivered: bool = false
var gravity: float = 9.8
var locomotion_collision: CollisionShape3D
var current_pattern: Dictionary = {}
var current_attack_duration: float = 0.0
var current_hit_time: float = 0.0
var guard_impact_time: float = 0.0
var attack_entry_distance: float = 0.0
var bayonet_cooldown: float = 0.0
var stun_duration: float = 0.0
var stun_step_distance: float = 0.0
var stun_step_direction := Vector3.ZERO
var externally_controlled: bool = false
var external_motion_velocity := Vector3.ZERO
var simulation_lod_level: int = 0
var physical_locomotion_enabled: bool = true
var formation_attack_committed: bool = false


func install(
	actor_value: CharacterBody3D,
	target_value: Node3D,
	guard_value: CombatGuardComponent,
	external_control: bool = false
) -> bool:
	actor = actor_value
	target = target_value
	guard_component = guard_value
	externally_controlled = external_control
	if actor == null or target == null or guard_component == null:
		return false
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	actor.collision_layer = 4
	actor.collision_mask = 1 | 2
	locomotion_collision = CollisionShape3D.new()
	locomotion_collision.name = "HopliteV2LocomotionCapsule"
	locomotion_collision.position = Vector3(0.0, 0.92, 0.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.84
	locomotion_collision.shape = capsule
	actor.add_child(locomotion_collision)
	actor.ai_enabled = true
	actor.add_to_group("enemy")
	actor.add_to_group("athenian_enemies")
	_transition(State.GUARD)
	set_physics_process(not externally_controlled)
	return true


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


func set_simulation_lod(level: int) -> void:
	simulation_lod_level = clampi(level, 0, 3)
	_refresh_locomotion_collision()


func set_physical_locomotion_enabled(enabled: bool) -> void:
	physical_locomotion_enabled = enabled
	if actor != null and state != State.DEAD:
		actor.collision_layer = 4 if enabled else 0
		actor.collision_mask = (1 | 2) if enabled else 0
	_refresh_locomotion_collision()


func set_external_controlled(enabled: bool) -> void:
	externally_controlled = enabled
	set_physics_process(not externally_controlled and state != State.DEAD)


func _refresh_locomotion_collision() -> void:
	if locomotion_collision != null:
		locomotion_collision.set_deferred(
			"disabled",
			not physical_locomotion_enabled or simulation_lod_level >= 3 or state == State.DEAD
		)


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
				actor.velocity.x = direction.x * actor.definition.move_speed
				actor.velocity.z = direction.z * actor.definition.move_speed
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


func shutdown() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	set_physics_process(false)
	if actor != null:
		actor.velocity = Vector3.ZERO
		actor.collision_layer = 0
		actor.collision_mask = 0
		actor.clear_attack_telegraph()
		if actor.equipment != null:
			actor.equipment.set_guard_active(false)
	if locomotion_collision != null:
		locomotion_collision.set_deferred("disabled", true)


func can_block_source(source_node: Node3D) -> bool:
	if guard_component == null or not guard_component.can_guard():
		return false
	var shield_window := state in [State.GUARD, State.APPROACH, State.RECOVERY]
	if state == State.ATTACK:
		shield_window = bool(current_pattern.get("uses_shield", false))
	if not shield_window or source_node == null:
		return false
	var incoming := source_node.global_position - actor.global_position
	incoming.y = 0.0
	if incoming.length_squared() < 0.0001:
		return true
	var forward := actor.global_basis.z
	forward.y = 0.0
	return forward.normalized().dot(incoming.normalized()) >= 0.15


func on_shield_blocked(reaction_seconds: float = 0.30) -> void:
	if state == State.ATTACK and bool(current_pattern.get("uses_shield", false)):
		return
	if state not in [State.GUARD, State.APPROACH, State.RECOVERY]:
		return
	guard_impact_time = maxf(reaction_seconds, 0.05)
	actor.play_semantic_animation(&"block_impact", 0.04)


func on_guard_broken(duration: float, step_distance: float, step_direction: Vector3) -> void:
	if state == State.DEAD:
		return
	stun_duration = maxf(duration, 0.05)
	stun_step_distance = maxf(step_distance, 0.0)
	stun_step_direction = step_direction.normalized() if step_direction.length_squared() > 0.0001 else -actor.global_basis.z
	formation_attack_committed = false
	_transition(State.STUNNED)


func _transition(next: State) -> void:
	state = next
	state_time = 0.0
	actor.clear_attack_telegraph()
	if actor.equipment != null:
		actor.equipment.set_weapon_grip(&"standard")
		actor.equipment.set_guard_active(state in [State.GUARD, State.APPROACH, State.RECOVERY])
	match state:
		State.GUARD, State.APPROACH, State.RECOVERY:
			_play_state_animation()
		State.ATTACK:
			_begin_attack_pattern()
		State.STUNNED:
			actor.play_semantic_animation(&"block_impact", 0.04, 1.15)
		State.DEAD:
			pass


func _play_state_animation() -> void:
	if guard_impact_time > 0.0:
		return
	actor.play_semantic_animation(&"move" if state == State.APPROACH else &"block_idle")


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
	var attack_speed: float = float(actor.definition.move_speed) * move_factor
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
	return planar_to_target.normalized() * float(actor.definition.move_speed) * move_factor


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
	return planar_to_target.normalized() * float(actor.definition.move_speed) * FORMATION_APPROACH_SPEED_FACTOR


func _apply_guard_break_step() -> void:
	if stun_step_distance <= 0.0:
		_stop_horizontal_motion()
		return
	var progress := clampf(state_time / maxf(stun_duration, 0.05), 0.0, 1.0)
	# Integral of 2*(1-progress) over the stun duration equals one full step.
	var speed := stun_step_distance / maxf(stun_duration, 0.05) * 2.0 * (1.0 - progress)
	actor.velocity.x = stun_step_direction.x * speed
	actor.velocity.z = stun_step_direction.z * speed


func _guard_break_velocity() -> Vector3:
	if stun_step_distance <= 0.0:
		return Vector3.ZERO
	var progress := clampf(state_time / maxf(stun_duration, 0.05), 0.0, 1.0)
	var speed := stun_step_distance / maxf(stun_duration, 0.05) * 2.0 * (1.0 - progress)
	return stun_step_direction * speed


func _planar_target_distance() -> float:
	if target == null or not is_instance_valid(target):
		return INF
	var offset := target.global_position - actor.global_position
	return Vector2(offset.x, offset.z).length()


func _target_facing_dot() -> float:
	if target == null or not is_instance_valid(target) or actor == null:
		return -1.0
	var direction := target.global_position - actor.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return 1.0
	var forward := actor.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return -1.0
	return forward.normalized().dot(direction.normalized())


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
	var damage: float = float(actor.definition.attack_damage) * float(current_pattern["damage_mult"])
	if distance <= hit_range and forward.dot(direction) >= 0.35:
		if target.has_method("receive_enemy_hit"):
			target.call("receive_enemy_hit", damage, actor, direction)
		elif target.has_method("receive_ai_hit"):
			target.call("receive_ai_hit", damage, actor, direction)
	elif target.has_method("register_enemy_near_miss") and distance <= hit_range + 1.0:
		target.call("register_enemy_near_miss", actor)


func _face_target(delta: float) -> void:
	var direction := target.global_position - actor.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var desired := Basis.looking_at(-direction.normalized(), Vector3.UP)
	var actor_scale := actor.basis.get_scale()
	var current_rotation := actor.basis.orthonormalized()
	var blended_rotation := current_rotation.slerp(desired, clampf(TURN_SPEED * delta, 0.0, 1.0)).orthonormalized()
	actor.basis = blended_rotation.scaled(actor_scale)


func _stop_horizontal_motion() -> void:
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, 12.0)
	actor.velocity.z = move_toward(actor.velocity.z, 0.0, 12.0)


func _apply_gravity_and_move(delta: float) -> void:
	if actor.is_on_floor():
		actor.velocity.y = -0.5
	else:
		actor.velocity.y -= gravity * delta
	actor.move_and_slide()
