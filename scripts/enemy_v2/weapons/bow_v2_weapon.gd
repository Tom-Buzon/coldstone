extends "res://scripts/enemy_v2/enemy_v2_role_combat.gd"

const Projectile = preload("res://scripts/enemy_v2/archer_v2_projectile.gd")
const MIN_RANGE := 9.0
const MAX_RANGE := 34.0
const RETREAT_DISTANCE := 4.0
const RETREAT_SECONDS := 1.2
var locked_aim := Vector3.ZERO
var retreat_origin := Vector3.ZERO
var retreat_remaining := 0.0
var retreat_cooldown := 0.0
var retreat_direction := Vector3.ZERO
var projectile: Node3D
var line_clear := false
var sight_timer := 0.0
var lane_frame := -1
var lane_origin := Vector3.ZERO
var lane_aim := Vector3.ZERO
var lane_clear := false

func can_accept_formation_attack() -> bool:
	var distance := _planar_target_distance()
	return weapon_available and _has_target() and state in [State.GUARD, State.APPROACH] and retreat_remaining <= 0.0 and attack_cooldown <= 0.0 and distance >= MIN_RANGE and distance <= MAX_RANGE and line_clear and Projectile.can_spawn(get_tree()) and _army_lane_clear(target.global_position)

func formation_decision_tick(delta: float, attack_authorized: bool, moving_to_slot: bool) -> void:
	if not _decision_clock(delta):
		return
	retreat_cooldown = maxf(0.0, retreat_cooldown - delta)
	sight_timer -= delta
	if sight_timer <= 0.0 and state in [State.GUARD, State.APPROACH]:
		sight_timer = 0.45 + float(actor.get_instance_id() % 7) * 0.035
		line_clear = _has_clear_shot()
	if state not in [State.GUARD, State.APPROACH]:
		return
	local_override = retreat_remaining > 0.0
	if _planar_target_distance() < MIN_RANGE and retreat_cooldown <= 0.0:
		retreat_origin = actor.global_position
		retreat_direction = actor.global_position - target.global_position
		retreat_direction.y = 0.0
		retreat_direction = retreat_direction.normalized()
		# One short withdrawal, then the archer remains catchable for six seconds.
		retreat_remaining = RETREAT_SECONDS
		retreat_cooldown = 6.0
		local_override = true
	if attack_authorized and can_accept_formation_attack() and not moving_to_slot and _target_facing_dot() >= 0.75:
		_transition(State.ATTACK)
		return
	var wanted := State.APPROACH if moving_to_slot or retreat_remaining > 0.0 else State.GUARD
	if state != wanted:
		_transition(wanted)

func formation_action_tick(delta: float) -> void:
	if actor == null or actor.dead:
		return
	_advance_role_action(delta, 0.7, 1.65)
	if state == State.APPROACH and retreat_remaining > 0.0:
		retreat_remaining = maxf(0.0, retreat_remaining - delta)
		if actor.global_position.distance_to(retreat_origin) < RETREAT_DISTANCE and actor.global_position.distance_to(_local_home()) < RETREAT_DISTANCE + 1.0:
			local_motion = retreat_direction * actor.effective_move_speed() * 0.65
		else:
			retreat_remaining = 0.0
		local_override = retreat_remaining > 0.0

func _begin_attack_pattern() -> void:
	_lock_attack_direction()
	locked_aim = target.global_position + Vector3.UP * 1.0
	current_pattern = {"uses_shield": false}
	current_hit_time = 1.0
	current_attack_duration = 1.47
	hit_delivered = false
	actor.play_semantic_animation(&"bow_draw", 0.1, 1.0)
	actor.begin_attack_telegraph(&"archer_draw_release", current_hit_time)

func _try_deliver_hit() -> void:
	if not _has_target() or not weapon_available or not _army_lane_clear(locked_aim - Vector3.UP) or not Projectile.can_spawn(get_tree()):
		return
	# Do not fire through cover appearing during the committed draw.
	var origin: Vector3 = actor.equipment.projectile_origin()
	var query := PhysicsRayQueryParameters3D.create(origin, locked_aim, 1)
	if not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	projectile = Projectile.new()
	actor.get_parent().add_child(projectile)
	projectile.launch(origin, locked_aim, actor, target, actor.effective_attack_damage())

func _army_lane_clear(aim: Vector3) -> bool:
	var runtime: Node = actor.phalanx_runtime
	if runtime == null or not is_instance_valid(runtime) or not runtime.has_method("is_fire_lane_clear"):
		return true
	var frame := Engine.get_process_frames()
	if frame != lane_frame or not lane_aim.is_equal_approx(aim) or not lane_origin.is_equal_approx(actor.global_position):
		lane_frame = frame
		lane_origin = actor.global_position
		lane_aim = aim
		lane_clear = bool(runtime.call("is_fire_lane_clear",actor.phalanx_group_id,lane_origin,aim))
	return lane_clear

func _has_clear_shot() -> bool:
	if not _has_target() or _planar_target_distance() > MAX_RANGE:
		return false
	var origin := actor.global_position + Vector3.UP * 1.4
	var aim := target.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, aim, 1 | 4)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func can_block_source(_source_node: Node3D) -> bool:
	return false

func on_equipment_lost(slot: StringName) -> void:
	# Drawing a bow needs both arms; left-arm severing uses the shield slot in
	# the shared anatomy contract and must disable the bow as well.
	super.on_equipment_lost(&"weapon" if slot == &"shield" else slot)
	if actor.equipment != null:
		actor.equipment.set_weapon_visible(false)

func is_attack_committed() -> bool:
	return state == State.ATTACK or (projectile != null and is_instance_valid(projectile) and not projectile.is_queued_for_deletion())

func attack_budget_seconds() -> float:
	return 4.0

func _idle_semantic() -> StringName:
	return &"idle"
