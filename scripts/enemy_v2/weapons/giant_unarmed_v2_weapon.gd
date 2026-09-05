extends "res://scripts/enemy_v2/enemy_v2_combat_core.gd"

## A committed miniboss strike locks its aim before impact. Recovery is a real
## player damage window, and every attack consumes the army danger budget.
const PATTERNS: Array[Dictionary] = [
	{"id": &"giant_punch", "windup": 1.05, "recovery": 1.55, "radius": 1.75, "dot": 0.62, "damage": 1.0},
	{"id": &"giant_swipe", "windup": 1.35, "recovery": 1.7, "radius": 2.0, "dot": -0.05, "damage": 0.85},
]
var pattern_index: int = 0
var special_ability: RefCounted
var locked_direction := Vector3.FORWARD
var locked_origin := Vector3.ZERO
var impact_center := Vector3.ZERO
var warning_mesh: MeshInstance3D
var warning_material: StandardMaterial3D

func install(value: CharacterBody3D, target_value: Node3D, _guard: CombatGuardComponent, external: bool = false) -> bool:
	actor = value
	if actor.definition.special_ability_script != null:
		special_ability = actor.definition.special_ability_script.new()
	target = target_value
	externally_controlled = external
	actor.ai_enabled = true
	actor.collision_layer = 4 | 256
	actor.collision_mask = 1 | 2
	actor.add_to_group("allied_combatants" if actor.faction == &"spartan" else "enemy")
	actor.add_to_group("spartan_allies" if actor.faction == &"spartan" else "athenian_enemies")
	actor.add_to_group("giant_enemy")
	locomotion_collision = CollisionShape3D.new()
	locomotion_collision.name = "GiantV2LocomotionCapsule"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43 * actor.size_multiplier
	shape.height = 1.72 * actor.size_multiplier
	locomotion_collision.shape = shape
	locomotion_collision.position.y = shape.height * 0.5
	actor.add_child(locomotion_collision)
	set_physics_process(not external)
	actor.play_semantic_animation(&"idle")
	return true

func formation_decision_tick(delta: float, authorized: bool, moving: bool) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if state not in [State.GUARD, State.APPROACH]:
		return
	if authorized and can_accept_formation_attack():
		_begin_attack()
		return
	var desired := State.APPROACH if moving else State.GUARD
	if state != desired:
		state = desired
		actor.play_semantic_animation(&"move" if moving else &"idle", 0.2, 0.72)

func formation_action_tick(delta: float) -> void:
	if state == State.DEAD:
		return
	state_time += delta
	if state == State.WINDUP:
		if not is_instance_valid(target):
			_enter_recovery()
			return
		if state_time >= float(current_pattern.windup):
			_deliver_impact()
			_enter_recovery()
	elif state == State.RECOVERY and state_time >= float(current_pattern.get("recovery", 1.5)):
		state = State.GUARD
		attack_cooldown = 0.8
		actor.play_semantic_animation(&"idle", 0.25)
	elif state == State.STUNNED and state_time >= stun_duration:
		state = State.GUARD
		attack_cooldown = 0.7
		actor.play_semantic_animation(&"idle", 0.25)

func can_accept_formation_attack() -> bool:
	return state in [State.GUARD, State.APPROACH] and attack_cooldown <= 0.0 and _distance() <= actor.size_multiplier * 1.7 and _target_facing_dot() > 0.48

func is_attack_committed() -> bool:
	return state in [State.WINDUP, State.RECOVERY]

func attack_budget_seconds() -> float:
	return 1.95

func is_formation_engaged() -> bool:
	return state in [State.WINDUP, State.RECOVERY, State.STUNNED] or actor.locomotion_factor == 0.0

func formation_overrides_movement() -> bool:
	return is_formation_engaged()

func formation_motion_velocity() -> Vector3:
	return Vector3.ZERO

func formation_facing_direction(fallback: Vector3) -> Vector3:
	return locked_direction if state in [State.WINDUP, State.RECOVERY] else fallback

func is_vulnerable() -> bool:
	return state in [State.RECOVERY, State.STUNNED]

func can_block_source(_source: Node3D) -> bool:
	return false

func on_shield_blocked(_seconds: float = 0.2) -> void:
	pass

func on_guard_broken(seconds: float, _distance: float, _direction: Vector3) -> void:
	state = State.STUNNED
	state_time = 0.0
	stun_duration = maxf(0.8, seconds)
	_clear_warning()
	actor.clear_attack_telegraph()

func set_simulation_lod(level: int) -> void:
	simulation_lod_level = level

func set_physical_locomotion_enabled(enabled: bool) -> void:
	if locomotion_collision != null:
		locomotion_collision.set_deferred("disabled", not enabled or state == State.DEAD)
	actor.collision_layer = 4 | 256 if enabled and state != State.DEAD else 0
	actor.collision_mask = 3 if enabled and state != State.DEAD else 0

func set_external_controlled(enabled: bool) -> void:
	externally_controlled = enabled
	set_physics_process(not enabled and state != State.DEAD)

func shutdown() -> void:
	state = State.DEAD
	_clear_warning()
	set_physics_process(false)
	set_physical_locomotion_enabled(false)
	actor.remove_from_group("enemy")
	actor.remove_from_group("athenian_enemies")
	actor.remove_from_group("giant_enemy")

func _begin_attack() -> void:
	var choices: Array[Dictionary] = PATTERNS.duplicate()
	if special_ability != null and special_ability.available(actor):
		choices.append(special_ability.pattern())
	current_pattern = choices[pattern_index % choices.size()]
	pattern_index += 1
	state = State.WINDUP
	state_time = 0.0
	locked_direction = _target_direction()
	locked_origin = actor.global_position
	impact_center = locked_origin
	impact_center += locked_direction * actor.size_multiplier * float(current_pattern.get("offset",0.0))
	var semantic: StringName = current_pattern.id
	var length := float(current_pattern.get("clip_length",1.1 if semantic == &"giant_punch" else 2.667))
	# Clip impact at about 60%; all movement and damage stay on the committed clock.
	actor.play_semantic_animation(semantic, 0.18, length * 0.6 / float(current_pattern.windup))
	actor.begin_attack_telegraph(semantic, float(current_pattern.windup))
	_show_warning()

func _enter_recovery() -> void:
	state = State.RECOVERY
	state_time = 0.0
	actor.clear_attack_telegraph()
	_clear_warning()

func _deliver_impact() -> void:
	if not is_instance_valid(target):
		return
	var offset := target.global_position - impact_center
	var vertical := offset.y
	offset.y = 0.0
	var radius: float = float(current_pattern.radius) * actor.size_multiplier
	var direction := offset.normalized() if offset.length_squared() > 0.001 else locked_direction
	if offset.length() > radius or direction.dot(locked_direction) < float(current_pattern.dot):
		if target.has_method("register_enemy_near_miss"):
			target.call("register_enemy_near_miss", actor)
		return
	# Jumping clears the ground slam; the other swings have a bounded height.
	if vertical > float(current_pattern.get("max_height",actor.size_multiplier * 1.3)) or vertical < -1.0:
		return
	var query := PhysicsRayQueryParameters3D.create(locked_origin + Vector3.UP * 1.2, target.global_position + Vector3.UP * 0.8, 1)
	if not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	var damage: float = actor.effective_attack_damage() * float(current_pattern.damage)
	if target.has_method("receive_enemy_hit"):
		target.call("receive_enemy_hit", damage, actor, direction)
	elif target.has_method("receive_ai_hit"):
		target.call("receive_ai_hit", damage, actor, direction)

func _show_warning() -> void:
	_clear_warning()
	warning_mesh = MeshInstance3D.new()
	warning_mesh.name = "GiantV2CommittedAttackZone"
	var mesh := ImmediateMesh.new()
	warning_material = StandardMaterial3D.new()
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_material.albedo_color = Color(1.0, 0.36, 0.04, 0.65)
	warning_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, warning_material)
	var radius: float = float(current_pattern.radius) * actor.size_multiplier
	var arc := acos(float(current_pattern.dot))
	var heading := atan2(locked_direction.x, locked_direction.z)
	for index: int in range(48):
		var a := heading - arc + 2.0 * arc * float(index) / 48.0
		var b := heading - arc + 2.0 * arc * float(index + 1) / 48.0
		var pa := Vector3(sin(a), 0, cos(a))
		var pb := Vector3(sin(b), 0, cos(b))
		for point: Vector3 in [pa * (radius - 0.14), pa * radius, pb * radius, pa * (radius - 0.14), pb * radius, pb * (radius - 0.14)]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	warning_mesh.mesh = mesh
	warning_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor.get_parent().add_child(warning_mesh)
	warning_mesh.global_position = impact_center + Vector3.UP * 0.055

func _clear_warning() -> void:
	if is_instance_valid(warning_mesh):
		warning_mesh.queue_free()
	warning_mesh = null

func _exit_tree() -> void:
	_clear_warning()

func _distance() -> float:
	if not is_instance_valid(target):
		return INF
	return Vector2(target.global_position.x - actor.global_position.x, target.global_position.z - actor.global_position.z).length()

func _target_direction() -> Vector3:
	var direction := target.global_position - actor.global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else actor.global_basis.z.normalized()

func _target_facing_dot() -> float:
	return actor.global_basis.z.normalized().dot(_target_direction()) if is_instance_valid(target) else -1.0

func _physics_process(delta: float) -> void:
	if actor.dead:
		shutdown()
		return
	formation_decision_tick(delta, true, _distance() > actor.size_multiplier * 1.4)
	formation_action_tick(delta)
	var moving := state == State.APPROACH and is_instance_valid(target) and _distance() < 65.0
	var direction := _target_direction() if is_instance_valid(target) else actor.global_basis.z
	if not formation_overrides_movement():
		actor.basis = actor.basis.slerp(Basis.looking_at(-direction), minf(1.4 * delta, 1.0)).orthonormalized()
	actor.velocity.x = direction.x * actor.effective_move_speed() * actor.locomotion_factor if moving else 0.0
	actor.velocity.z = direction.z * actor.effective_move_speed() * actor.locomotion_factor if moving else 0.0
	actor.velocity.y = -0.5 if actor.is_on_floor() else actor.velocity.y - 9.8 * delta
	actor.move_and_slide()
