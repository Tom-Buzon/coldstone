extends CharacterBody3D
class_name HopliteEnemyActorV2

const RuntimeState = preload("res://scripts/enemy_v2/enemy_v2_runtime_state.gd")
const PresentationComponent = preload("res://scripts/enemy_v2/hoplite_v2_presentation_component.gd")
const AnimationComponent = preload("res://scripts/enemy_v2/hoplite_v2_animation_component.gd")
const EquipmentComponent = preload("res://scripts/enemy_v2/hoplite_v2_equipment_component.gd")
const LodComponent = preload("res://scripts/enemy_v2/hoplite_v2_lod_component.gd")
const HealthComponent = preload("res://scripts/enemy_v2/hoplite_v2_health_component.gd")
const CombatComponent = preload("res://scripts/enemy_v2/hoplite_v2_combat_component.gd")
const AttackTelegraph = preload("res://scripts/combat/enemy_attack_telegraph.gd")
const DismembermentComponent = preload("res://scripts/enemy_v2/hoplite_v2_dismemberment_component.gd")
const GuardComponent = preload("res://scripts/combat/guard_component.gd")

signal died(enemy: Node)
signal localized_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float)
signal attack_started(enemy: Node, weapon_kind: StringName)
signal attack_telegraphed(enemy: Node, pattern_id: StringName, windup_seconds: float)
signal zone_severed(enemy: Node, zone: StringName)

var definition: HopliteEnemyV2Definition
var runtime_state: HopliteEnemyV2RuntimeState
var presentation: HopliteV2PresentationComponent
var animation: HopliteV2AnimationComponent
var equipment: HopliteV2EquipmentComponent
var performance_lod: HopliteV2LodComponent
var health_component: Node
var combat: Node
var guard: CombatGuardComponent
var attack_telegraph: HopliteEnemyAttackTelegraph
var dismemberment: Node
var configured: bool = false
var archetype_id: StringName
var initial_semantic: StringName = &"idle"
var dead: bool = false
var ai_enabled: bool = false
var faction: StringName = &"athenian"
var lod_reference: Node3D
var combat_lab_enabled: bool = false
var combat_target: Node3D
var max_health: float = 0.0
var health: float = 0.0
var troop_controlled: bool = false
var phalanx_runtime: Node
var phalanx_group_id: StringName
var phalanx_row: int = -1
var phalanx_column: int = -1
var phalanx_profile: HopliteV2PhalanxProfile
var phalanx_target_position := Vector3.ZERO
var phalanx_facing := Vector3.FORWARD
var phalanx_moving: bool = false
var simulation_lod_level: int = 0
var simulation_accumulator: float = 0.0
var combat_modifiers := preload("res://scripts/enemy_v2/enemy_v2_combat_modifiers.gd").new()
var gravity: float = 9.8
var mass_transform_mode: bool = false
var mass_transform_accumulator: float = 0.0
var far_impostor_batch: Node


func configure(value: HopliteEnemyV2Definition) -> bool:
	if is_inside_tree() or value == null or not value.validate().is_empty():
		return false
	definition = value
	archetype_id = definition.archetype_id
	set_meta("enemy_v2_impostor_role", definition.unit_role)
	runtime_state = RuntimeState.new() as HopliteEnemyV2RuntimeState
	runtime_state.reset_from_definition(definition)
	max_health = definition.max_health
	health = runtime_state.health
	configured = true
	return true


func _ready() -> void:
	if not configured:
		push_error("EnemyActorV2 must be configured before entering the scene tree")
		set_process(false)
		set_physics_process(false)
		return
	presentation = PresentationComponent.new() as HopliteV2PresentationComponent
	presentation.name = "Presentation"
	add_child(presentation)
	if not presentation.install(definition):
		return
	animation = AnimationComponent.new() as HopliteV2AnimationComponent
	animation.name = "Animation"
	add_child(animation)
	if not animation.install(presentation.skeleton, definition):
		return
	equipment = EquipmentComponent.new() as HopliteV2EquipmentComponent
	equipment.name = "Equipment"
	add_child(equipment)
	if not equipment.install(presentation.skeleton, definition, self if combat_lab_enabled else null):
		return
	performance_lod = LodComponent.new() as HopliteV2LodComponent
	performance_lod.name = "PerformanceLOD"
	add_child(performance_lod)
	performance_lod.install(self, lod_reference, presentation, animation, equipment)
	if combat_lab_enabled:
		attack_telegraph = AttackTelegraph.new() as HopliteEnemyAttackTelegraph
		attack_telegraph.name = "AttackTelegraph"
		add_child(attack_telegraph)
		attack_telegraph.configure(2.35 * definition.visual_scale)
		health_component = HealthComponent.new()
		health_component.name = "Health"
		add_child(health_component)
		if not health_component.install(self, presentation.skeleton, runtime_state):
			push_error("EnemyActorV2 could not install its health component")
			return
		health_component.apply_runtime_lod(performance_lod.current_level, performance_lod.cached_distance)
		health_component.health_changed.connect(_on_health_changed)
		health_component.depleted.connect(_on_health_depleted)
		dismemberment = DismembermentComponent.new()
		dismemberment.name = "Dismemberment"
		add_child(dismemberment)
		if not dismemberment.install(self, presentation.skeleton, health_component.anatomy, definition):
			push_error("EnemyActorV2 could not install its dismemberment component")
			return
		health_component.sever_requested.connect(_on_sever_requested)
		dismemberment.equipment_lost.connect(_on_sever_equipment_lost)
		guard = GuardComponent.new() as CombatGuardComponent
		guard.name = "Guard"
		add_child(guard)
		if not guard.configure(self, definition.guard_profile):
			push_error("EnemyActorV2 could not install its shared guard component")
			return
		guard.guard_held.connect(_on_guard_held)
		guard.guard_broken.connect(_on_guard_broken)
		combat = _create_combat_component()
		combat.name = "Combat"
		add_child(combat)
		if not combat.install(self, combat_target, guard, troop_controlled):
			push_error("EnemyActorV2 could not install its combat laboratory component")
			return
		gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		_refresh_simulation_mode()
	else:
		animation.start_pattern(initial_semantic, get_instance_id())
	add_to_group("enemy_v2_lod_participant")
	# Mass-controlled V2 actors deliberately disable their CharacterBody collider.
	# The camera fader tracks this lightweight group geometrically so readability
	# does not depend on re-enabling 150 physics bodies.
	add_to_group("camera_occlusion_dynamic_actor")
	set_meta("enemy_runtime_generation", &"modular_v2_shadow")
	set_meta("enemy_asset_origin", &"3dgen")
	set_meta("enemy_migration_family", definition.unit_role)


	preload("res://scripts/enemy_v2/enemy_v2_team_palette.gd").apply(self,faction)

func _create_combat_component() -> Node:
	if definition.weapon_script != null:
		return definition.weapon_script.new()
	return CombatComponent.new()


func is_phalanx_unit() -> bool:
	# This is queried while the physical shield is installed in _ready(). The
	# Forge writes the effective mode before adding the actor to the scene tree.
	return StringName(get_meta("enemy_v2_troop_mode", &"")) == &"hoplite_phalanx"


func bind_phalanx_runtime(
	runtime_value: Node,
	group_id: StringName,
	row: int,
	column: int,
	profile: HopliteV2PhalanxProfile,
	troop_mode: StringName = &"hoplite_phalanx"
) -> void:
	phalanx_runtime = runtime_value
	phalanx_group_id = group_id
	phalanx_row = row
	phalanx_column = column
	phalanx_profile = profile
	troop_controlled = true
	if combat != null:
		combat.set_external_controlled(true)
	phalanx_target_position = global_position
	set_meta("enemy_v2_troop_mode", troop_mode)
	set_meta("enemy_v2_phalanx_row", row)
	set_meta("enemy_v2_phalanx_column", column)
	if performance_lod != null:
		on_v2_lod_sample(performance_lod.current_level, performance_lod.cached_distance)
	else:
		mass_transform_mode = true
		_refresh_simulation_mode()
	_sync_far_impostor()


func unbind_phalanx_runtime(runtime_value: Node) -> void:
	if phalanx_runtime != runtime_value:
		return
	phalanx_runtime = null
	phalanx_group_id = &""
	phalanx_profile = null
	phalanx_moving = false
	troop_controlled = false
	mass_transform_mode = false
	if combat != null:
		combat.set_external_controlled(false)
	if far_impostor_batch != null and is_instance_valid(far_impostor_batch):
		far_impostor_batch.call("remove_actor", self)
	far_impostor_batch = null
	_refresh_simulation_mode()


func set_far_impostor_batch(batch: Node) -> void:
	if far_impostor_batch == batch:
		_sync_far_impostor()
		return
	if far_impostor_batch != null and is_instance_valid(far_impostor_batch):
		far_impostor_batch.call("remove_actor", self)
	far_impostor_batch = batch
	_sync_far_impostor()


func impostor_visual_scale() -> float:
	return definition.visual_scale if definition != null else 1.0


func _sync_far_impostor() -> void:
	if far_impostor_batch == null or not is_instance_valid(far_impostor_batch):
		return
	var active := troop_controlled and simulation_lod_level >= 3 and not dead
	far_impostor_batch.call("set_actor_active", self, active)
	if performance_lod != null:
		# While represented by the batch, the shared 4 Hz loop owns distance
		# checks. This removes one per-frame _process callback per far soldier.
		performance_lod.set_process(not active)


func far_impostor_lod_tick() -> void:
	if performance_lod != null and troop_controlled and simulation_lod_level >= 3 and not dead:
		performance_lod.refresh(false)


func set_phalanx_intent(
	target_position: Vector3,
	facing_direction: Vector3,
	moving_to_slot: bool,
	attack_authorized: bool,
	decision_delta: float
) -> void:
	phalanx_target_position = target_position
	phalanx_facing = facing_direction.normalized() if facing_direction.length_squared() > 0.0001 else phalanx_facing
	phalanx_moving = moving_to_slot
	if simulation_lod_level >= 3:
		global_position = phalanx_target_position
	if combat != null:
		combat.formation_decision_tick(decision_delta, attack_authorized, moving_to_slot)


func can_accept_phalanx_attack() -> bool:
	return not dead and combat != null and bool(combat.can_accept_formation_attack())


func is_phalanx_combat_engaged() -> bool:
	return not dead and combat != null and bool(combat.is_formation_engaged())


func on_v2_lod_level_changed(level: int) -> void:
	simulation_lod_level = clampi(level, 0, 3)
	simulation_accumulator = 0.0
	if combat != null:
		combat.set_simulation_lod(simulation_lod_level)
	if animation != null and animation.player != null:
		animation.player.active = simulation_lod_level < 3
	_sync_far_impostor()
	_refresh_simulation_mode()


func on_v2_lod_sample(level: int, planar_distance: float) -> void:
	if health_component != null:
		health_component.apply_runtime_lod(level, planar_distance)
	var full_rate_distance := 3.8
	if performance_lod != null:
		full_rate_distance = float(performance_lod.current_settings.get("full_rate", full_rate_distance))
	# Visual LOD0 is deliberately broader than the physical interaction bubble.
	# Only the front rank needs an individual CharacterBody while it can directly
	# contact the player; the troop runtime keeps every other slot coherent.
	var physical_candidate := (
		troop_controlled
		and phalanx_row == 0
		and level == 0
		and planar_distance <= full_rate_distance
	)
	var next_mass_mode := troop_controlled and not physical_candidate
	if next_mass_mode != mass_transform_mode:
		mass_transform_mode = next_mass_mode
		mass_transform_accumulator = 0.0
		set_meta("enemy_v2_movement_mode", &"troop_transform" if mass_transform_mode else &"individual_physics")
		_refresh_simulation_mode()


func _refresh_simulation_mode() -> void:
	var use_individual_physics := troop_controlled and combat != null and not mass_transform_mode and simulation_lod_level < 3 and not dead
	set_physics_process(use_individual_physics)
	if combat != null:
		combat.set_physical_locomotion_enabled(use_individual_physics if troop_controlled else simulation_lod_level < 3 and not dead)


func _physics_process(delta: float) -> void:
	if not troop_controlled or phalanx_runtime == null or dead or phalanx_profile == null:
		return
	_advance_formation(delta, true)


func formation_mass_tick(delta: float) -> void:
	if not mass_transform_mode or not troop_controlled or phalanx_runtime == null or dead or phalanx_profile == null:
		return
	var update_interval := 0.0
	match simulation_lod_level:
		1: update_interval = 1.0 / 30.0
		2: update_interval = 1.0 / 12.0
		3: update_interval = 0.25
	if update_interval > 0.0:
		mass_transform_accumulator += delta
		if mass_transform_accumulator < update_interval:
			return
		delta = mass_transform_accumulator
		mass_transform_accumulator = 0.0
	_advance_formation(delta, false)


func _advance_formation(delta: float, use_physics: bool) -> void:
	combat.formation_action_tick(delta)
	var planar_velocity := Vector3.ZERO
	if combat.formation_overrides_movement():
		planar_velocity = combat.formation_motion_velocity()
	else:
		var offset := phalanx_target_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > phalanx_profile.arrival_tolerance:
			var speed := effective_move_speed() * phalanx_profile.member_speed_multiplier
			if distance < phalanx_profile.arrival_slowdown_distance:
				speed *= clampf(distance / phalanx_profile.arrival_slowdown_distance, 0.25, 1.0)
			planar_velocity = offset.normalized() * speed
	velocity.x = planar_velocity.x
	velocity.z = planar_velocity.z
	var desired_facing := phalanx_facing
	if combat != null:
		desired_facing = combat.formation_facing_direction(desired_facing)
	if desired_facing.length_squared() > 0.0001:
		var desired_basis := Basis.looking_at(-desired_facing, Vector3.UP)
		var actor_scale := global_basis.get_scale()
		var current_rotation := global_basis.orthonormalized()
		# Avoid dirtying the physics body, skeleton and renderer transform when an
		# already aligned formation member has nothing to rotate this frame.
		if current_rotation.z.dot(desired_basis.z) < 0.99995:
			var blended_rotation := current_rotation.slerp(desired_basis, clampf(8.0 * delta, 0.0, 1.0)).orthonormalized()
			global_basis = blended_rotation.scaled(actor_scale)
	if use_physics:
		if is_on_floor():
			velocity.y = -0.5
		else:
			velocity.y -= gravity * delta
		move_and_slide()
	else:
		velocity.y = 0.0
		var next_position := global_position
		if planar_velocity.length_squared() > 0.000001:
			next_position += Vector3(velocity.x, 0.0, velocity.z) * delta
		if not is_equal_approx(next_position.y, phalanx_target_position.y):
			next_position.y = move_toward(next_position.y, phalanx_target_position.y, maxf(1.0, effective_move_speed()) * delta)
		if not next_position.is_equal_approx(global_position):
			global_position = next_position


func play_semantic_animation(semantic: StringName, blend: float = 0.12, speed: float = 1.0) -> bool:
	if animation == null:
		return false
	runtime_state.current_action = semantic
	return animation.play_semantic(semantic, blend, speed)


func begin_attack_telegraph(pattern_id: StringName, windup_seconds: float) -> void:
	if dead:
		return
	if attack_telegraph != null:
		if combat_target is HopliteEnemyActorV2:
			attack_telegraph.clear()
		else:
			attack_telegraph.begin(windup_seconds)
	var weapon_kind: StringName = {&"archer": &"bow", &"infantry": &"sword", &"giant": &"fists"}.get(definition.unit_role, &"spear")
	attack_started.emit(self, weapon_kind)
	attack_telegraphed.emit(self, pattern_id, windup_seconds)


func clear_attack_telegraph() -> void:
	if attack_telegraph != null:
		attack_telegraph.clear()


func receive_shield_hit(hit: Variant) -> bool:
	if dead or combat == null or guard == null or equipment == null or equipment.shield_hitbox == null:
		return false
	var source_node := hit.source as Node3D if hit != null else null
	if source_node == null or not guard.can_guard() or not combat.can_block_source(source_node):
		return false
	hit.body_part = &"shield"
	hit.hit_material = &"metal"
	hit.position = equipment.shield_hitbox.global_position
	var intercepted := guard.resolve_guard(hit)
	if intercepted and bool(hit.guard_bypassed) and health_component != null:
		# Guaranteed bypasses still produce the common break/stun reaction, but
		# unlike a probabilistic break the fully charged blow also reaches the body.
		var penetrating_hit: Variant = hit.clone() if hit.has_method("clone") else hit
		penetrating_hit.body_part = &"torso"
		penetrating_hit.hit_material = &"flesh"
		penetrating_hit.contact_type = &"blade"
		receive_anatomy_hit(penetrating_hit, &"torso")
	return intercepted


func _on_guard_held(_hit: Variant, _attack_kind: StringName, _break_chance: float) -> void:
	if combat != null:
		combat.on_shield_blocked(definition.guard_profile.block_reaction_seconds)


func _on_guard_broken(
	_hit: Variant,
	_attack_kind: StringName,
	stun_seconds: float,
	step_back_distance: float,
	step_direction: Vector3
) -> void:
	if combat != null:
		combat.on_guard_broken(stun_seconds, step_back_distance, step_direction)


func is_dead_for_combat() -> bool:
	return dead


func can_receive_hit_from(source: Node) -> bool:
	return not dead and (source == null or preload("res://scripts/enemy_v2/enemy_v2_factions.gd").hostile(source, self))


func receive_anatomy_hit(hit: Variant, zone: StringName) -> void:
	if health_component == null or (hit != null and not can_receive_hit_from(hit.source)):
		return
	hit = combat_modifiers.incoming(hit)
	var previous_health := runtime_state.health
	health_component.receive_hit(hit, zone)
	var damage := maxf(0.0, previous_health - runtime_state.health)
	var sever_damage := maxf(0.0, float(hit.sever_damage)) if hit != null else 0.0
	localized_hit.emit(self, zone, damage, sever_damage)


func _on_health_changed(current: float, maximum: float) -> void:
	health = current
	max_health = maximum


func _on_sever_requested(zone: StringName, hit: Variant) -> void:
	if dismemberment != null and dismemberment.sever(zone, hit):
		zone_severed.emit(self, zone)


func _on_sever_equipment_lost(slot: StringName) -> void:
	if combat != null and combat.has_method("on_equipment_lost"):
		combat.call("on_equipment_lost", slot)
	if equipment == null:
		return
	if slot == &"weapon":
		equipment.set_weapon_visible(false)
	elif slot == &"shield":
		equipment.set_shield_visible(false)


func _on_health_depleted(_hit: Variant, _zone: StringName) -> void:
	if dead:
		return
	dead = true
	set_physics_process(false)
	if far_impostor_batch != null and is_instance_valid(far_impostor_batch):
		far_impostor_batch.call("remove_actor", self)
	if phalanx_runtime != null and phalanx_runtime.has_method("unregister_member"):
		phalanx_runtime.call("unregister_member", phalanx_group_id, self)
	var death_ground_y := global_position.y
	if combat != null:
		combat.shutdown()
	if equipment != null:
		equipment.shutdown_combat()
		equipment.drop_shield()
	if guard != null:
		guard.force_recover()
	if attack_telegraph != null:
		attack_telegraph.shutdown()
	play_semantic_animation(&"death")
	var ground_timer := get_tree().create_timer(2.45)
	ground_timer.timeout.connect(_ground_death_pose.bind(death_ground_y))
	died.emit(self)


func _ground_death_pose(ground_y: float) -> void:
	if not dead or presentation == null or health_component == null or health_component.anatomy == null:
		return
	var lowest: float = health_component.anatomy.estimate_lowest_surface_y()
	if not is_finite(lowest):
		return
	# Keep a tiny visual margin to prevent z-fighting with cobblestones/terrain.
	var correction: float = clampf(ground_y + 0.015 - lowest, -1.5, 1.5)
	presentation.position.y += correction


func _update_performance_lod() -> void:
	LodComponent.invalidate_settings_cache()
	if performance_lod != null:
		performance_lod.refresh(true)

func set_combat_target(value: Node3D) -> void:
	if combat_target == value: return
	if combat != null and combat.has_method("is_attack_committed") and combat.is_attack_committed(): return
	if is_instance_valid(phalanx_runtime): phalanx_runtime.invalidate_target_permission(self)
	combat_target = value
	if combat != null: combat.target = value

## Shared hit-receiver contract: callers (including the player's spiral) use
## the result to emit hit feedback only when damage was actually accepted.
func receive_ai_hit(amount: float, source: Node3D, direction: Vector3) -> bool:
	if not can_receive_hit_from(source) or health_component == null:
		return false
	var previous_health := health
	if combat != null and combat.can_block_source(source):
		amount *= 0.3
	var hit := preload("res://scripts/combat/hit_event.gd").new()
	hit.source = source
	hit.damage = amount
	hit.direction = direction
	hit.position = global_position + Vector3.UP
	receive_anatomy_hit(hit, &"torso")
	return health < previous_health

func effective_attack_damage() -> float:
	return definition.attack_damage * combat_modifiers.power

func effective_move_speed() -> float:
	return definition.move_speed * combat_modifiers.speed
