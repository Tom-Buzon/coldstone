extends "res://scripts/enemy_v2/enemy_v2_role_combat.gd"

## Short sword sorties from a loose formation. A committed cut retains its
## direction, so a dodge exposes the soldier throughout the recovery beat.
const ATTACK_REACH := 2.1
const SORTIE_REACH := 5.5
const MAX_SORTIE_SECONDS := 1.4
var sortie_time := 0.0
var heavy_cut := false

func can_accept_formation_attack() -> bool:
	return weapon_available and _has_target() and state in [State.GUARD, State.APPROACH] and attack_cooldown <= 0.0 and _planar_target_distance() <= SORTIE_REACH

func formation_decision_tick(delta: float, attack_authorized: bool, moving_to_slot: bool) -> void:
	if not _decision_clock(delta) or state not in [State.GUARD, State.APPROACH]:
		return
	local_override = false
	if attack_authorized and can_accept_formation_attack():
		sortie_time += delta
		if sortie_time <= MAX_SORTIE_SECONDS and actor.global_position.distance_to(_local_home()) < SORTIE_REACH:
			local_override = true
			if _planar_target_distance() <= ATTACK_REACH and _target_facing_dot() >= 0.75:
				_transition(State.ATTACK)
			elif state != State.APPROACH:
				_transition(State.APPROACH)
			return
		attack_cooldown = 0.9
	sortie_time = 0.0
	var wanted := State.APPROACH if moving_to_slot else State.GUARD
	if state != wanted:
		_transition(wanted)

func formation_action_tick(delta: float) -> void:
	if actor == null or actor.dead:
		return
	_advance_role_action(delta, 0.65, 0.8)
	if state == State.APPROACH and local_override and _has_target() and _planar_target_distance() > 1.7 and _target_facing_dot() > 0.45:
		local_motion = (target.global_position - actor.global_position).normalized() * actor.definition.move_speed
		local_motion.y = 0.0
	elif state == State.ATTACK and state_time < current_hit_time:
		local_motion = locked_direction * 0.85

func _begin_attack_pattern() -> void:
	_lock_attack_direction()
	heavy_cut = actor.get_instance_id() % 3 == 0 and _planar_target_distance() < 1.65
	current_pattern = {"uses_shield": false}
	current_hit_time = 0.55 if heavy_cut else 0.52
	current_attack_duration = 1.0 if heavy_cut else 1.14
	hit_delivered = false
	sortie_time = 0.0
	actor.play_semantic_animation(&"sword_heavy" if heavy_cut else &"sword_cut", 0.09, 1.0 if heavy_cut else 1.2)
	actor.begin_attack_telegraph(&"sword_heavy" if heavy_cut else &"sword_cut", current_hit_time)

func _try_deliver_hit() -> void:
	if not _has_target():
		return
	var offset := target.global_position - actor.global_position
	if absf(offset.y) > 1.55:
		return
	offset.y = 0.0
	if offset.length() <= ATTACK_REACH and locked_direction.dot(offset.normalized()) >= 0.25:
		var method := &"receive_enemy_hit" if target.has_method("receive_enemy_hit") else &"receive_ai_hit"
		if target.has_method(method):
			target.call(method, actor.definition.attack_damage * (1.35 if heavy_cut else 1.0), actor, locked_direction)
	elif offset.length() < ATTACK_REACH + 1.0 and target.has_method("register_enemy_near_miss"):
		target.call("register_enemy_near_miss", actor)
