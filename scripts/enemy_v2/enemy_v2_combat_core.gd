extends Node
class_name EnemyV2CombatCore

## Neutral lifecycle, guard and motion primitives. Weapon modules own tactics and attacks.
enum State { GUARD, APPROACH, ATTACK, WINDUP = ATTACK, RECOVERY, STUNNED, DEAD }
const TURN_SPEED := 9.0

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
	if actor == null or guard_component == null:
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
	actor.add_to_group("allied_combatants" if actor.faction == &"spartan" else "enemy")
	actor.add_to_group("spartan_allies" if actor.faction == &"spartan" else "athenian_enemies")
	_transition(State.GUARD)
	set_physics_process(not externally_controlled)
	return true


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

func _begin_attack_pattern() -> void:
	pass

func can_accept_formation_attack() -> bool:
	return false

func _try_deliver_hit() -> void:
	pass

func formation_decision_tick(_delta: float, _authorized: bool, _moving: bool) -> void:
	pass

func formation_action_tick(_delta: float) -> void:
	pass

func cancel_player_order() -> void:
	if state in [State.DEAD,State.STUNNED]: return
	hit_delivered = true
	formation_attack_committed = false
	external_motion_velocity = Vector3.ZERO
	actor.clear_attack_telegraph()
	_transition(State.GUARD)
