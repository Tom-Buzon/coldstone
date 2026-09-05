extends "res://scripts/enemy_v2/hoplite_v2_combat_component.gd"

## Shared lifecycle/capsule/guard/LOD contract. Role subclasses own decisions,
## attack timing and delivery. Neither imports nor invokes the V1 controller.
var weapon_available := true
var shield_available := true
var locked_direction := Vector3.FORWARD
var local_motion := Vector3.ZERO
var local_override := false
var standalone_origin := Vector3.ZERO

func install(actor_value: CharacterBody3D, target_value: Node3D, guard_value: CombatGuardComponent, external_control: bool = false) -> bool:
	var installed := super.install(actor_value, target_value, guard_value, external_control)
	if installed:
		standalone_origin = actor.global_position
		attack_cooldown = 0.25 + float(actor.get_instance_id() % 13) * 0.09
	return installed

func _physics_process(delta: float) -> void:
	if actor == null or actor.dead:
		shutdown()
		return
	# The standalone Forge preview runs the same role decisions as army members.
	formation_decision_tick(delta, true, false)
	formation_action_tick(delta)
	var facing := formation_facing_direction(actor.global_basis.z)
	if facing.length_squared() > 0.001:
		var desired := Basis.looking_at(-facing.normalized(), Vector3.UP)
		actor.basis = actor.basis.orthonormalized().slerp(desired, minf(8.0 * delta, 1.0)).scaled(actor.basis.get_scale())
	actor.velocity.x = local_motion.x
	actor.velocity.z = local_motion.z
	_apply_gravity_and_move(delta)

func formation_overrides_movement() -> bool:
	return local_override or state in [State.ATTACK, State.RECOVERY, State.STUNNED]

func formation_motion_velocity() -> Vector3:
	return local_motion

func formation_facing_direction(fallback: Vector3) -> Vector3:
	if state == State.ATTACK:
		return locked_direction
	if _has_target() and (local_override or can_accept_formation_attack()):
		var direction := target.global_position - actor.global_position
		direction.y = 0.0
		return direction.normalized() if direction.length_squared() > 0.001 else fallback
	return fallback

func is_attack_committed() -> bool:
	return state == State.ATTACK

func attack_budget_seconds() -> float:
	return 2.0

func on_equipment_lost(slot: StringName) -> void:
	if slot == &"shield":
		shield_available = false
	if slot == &"weapon":
		weapon_available = false
		if state == State.ATTACK:
			_transition(State.RECOVERY)

func can_block_source(source_node: Node3D) -> bool:
	return shield_available and super.can_block_source(source_node)

func _has_target() -> bool:
	return target != null and is_instance_valid(target)

func _local_home() -> Vector3:
	return actor.phalanx_target_position if externally_controlled else standalone_origin

func _decision_clock(delta: float) -> bool:
	if actor == null or actor.dead or state == State.DEAD:
		return false
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	return _has_target()

func _advance_role_action(delta: float, recovery: float, cooldown: float) -> void:
	local_motion = Vector3.ZERO
	state_time += delta
	match state:
		State.ATTACK:
			if not hit_delivered and state_time >= current_hit_time:
				hit_delivered = true
				actor.clear_attack_telegraph()
				if weapon_available:
					_try_deliver_hit()
			if state_time >= current_attack_duration:
				_transition(State.RECOVERY)
		State.RECOVERY:
			if state_time >= recovery:
				attack_cooldown = cooldown + float(actor.get_instance_id() % 11) * 0.045
				_transition(State.GUARD)
		State.STUNNED:
			local_motion = _guard_break_velocity()
			if state_time >= stun_duration:
				attack_cooldown = maxf(attack_cooldown, 0.6)
				_transition(State.GUARD)

func _lock_attack_direction() -> void:
	locked_direction = target.global_position - actor.global_position
	locked_direction.y = 0.0
	locked_direction = locked_direction.normalized() if locked_direction.length_squared() > 0.001 else actor.global_basis.z.normalized()

func _play_state_animation() -> void:
	actor.play_semantic_animation(&"move" if state == State.APPROACH else (&"idle" if actor.definition.unit_role == &"archer" else &"block_idle"))
