extends "res://scripts/enemy_v2/enemy_actor_v2.gd"

const GiantPresentation = preload("res://scripts/enemy_v2/giant_v2_presentation_component.gd")
const GiantCombat = preload("res://scripts/enemy_v2/giant_v2_combat_component.gd")
const GiantHealth = preload("res://scripts/enemy_v2/giant_v2_health_component.gd")
const GiantDismemberment = preload("res://scripts/enemy_v2/giant_v2_dismemberment_component.gd")
var size_multiplier: float = 3.0
var locomotion_factor: float = 1.0

func set_visual_scale(value: float) -> void:
	if not is_inside_tree():
		size_multiplier = clampf(value, 0.5, 8.0)
		scale = Vector3.ONE

func _ready() -> void:
	if not configured:
		set_physics_process(false)
		return
	presentation = GiantPresentation.new()
	presentation.size_multiplier = size_multiplier
	presentation.name = "Presentation"
	add_child(presentation)
	if not presentation.install(definition):
		return
	animation = AnimationComponent.new()
	animation.name = "Animation"
	add_child(animation)
	if not animation.install(presentation.skeleton, definition):
		return
	if combat_lab_enabled:
		health_component = GiantHealth.new()
		health_component.name = "Health"
		add_child(health_component)
		if not health_component.install(self, presentation.skeleton, runtime_state):
			return
		health_component.health_changed.connect(_on_health_changed)
		health_component.depleted.connect(_on_health_depleted)
		dismemberment = GiantDismemberment.new()
		dismemberment.name = "Dismemberment"
		add_child(dismemberment)
		dismemberment.install(self, presentation.skeleton, health_component.anatomy, definition)
		health_component.sever_requested.connect(_on_sever_requested)
		attack_telegraph = AttackTelegraph.new()
		add_child(attack_telegraph)
		attack_telegraph.configure(size_multiplier * 1.85)
		combat = GiantCombat.new()
		combat.name = "Combat"
		add_child(combat)
		combat.install(self, combat_target, null, troop_controlled)
	performance_lod = LodComponent.new()
	performance_lod.name = "PerformanceLOD"
	add_child(performance_lod)
	performance_lod.install(self, lod_reference, presentation, animation, null)
	add_to_group("enemy_v2_lod_participant")
	add_to_group("camera_occlusion_dynamic_actor")
	set_meta("enemy_runtime_generation", &"modular_v2_shadow")
	set_meta("enemy_migration_family", &"giant")
	set_meta("enemy_asset_origin", &"3dgen")
	set_meta("enemy_v2_unit_role", &"giant")
	set_meta("enemy_v2_movement_mode", &"individual_physics")
	set_meta("enemy_v2_footprint_radius", size_multiplier * 0.9)
	_refresh_simulation_mode()

func set_far_impostor_batch(_batch: Node) -> void:
	# No hoplite billboard may stand in for the giant silhouette.
	pass

func on_v2_lod_sample(_level: int, distance: float) -> void:
	if health_component != null:
		health_component.apply_runtime_lod(_level, distance)
	mass_transform_mode = false
	_refresh_simulation_mode()

func _refresh_simulation_mode() -> void:
	set_physics_process(troop_controlled and combat != null and not dead)
	if combat != null:
		combat.set_physical_locomotion_enabled(not dead)

func _advance_formation(delta: float, _use_physics: bool) -> void:
	combat.formation_action_tick(delta)
	var desired_velocity := Vector3.ZERO
	if not combat.formation_overrides_movement():
		var offset := phalanx_target_position - global_position
		offset.y = 0.0
		if offset.length() > 0.35:
			desired_velocity = offset.normalized() * minf(definition.move_speed * locomotion_factor, offset.length() / maxf(delta, 0.001))
	var facing: Vector3 = combat.formation_facing_direction(phalanx_facing)
	if facing.length_squared() > 0.001:
		basis = basis.slerp(Basis.looking_at(-facing), minf(1.4 * delta, 1.0)).orthonormalized()
	velocity.x = move_toward(velocity.x, desired_velocity.x, delta * 5.5)
	velocity.z = move_toward(velocity.z, desired_velocity.z, delta * 5.5)
	velocity.y = -0.5 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()

func set_phalanx_intent(target_position: Vector3, facing_direction: Vector3, moving_to_slot: bool, attack_authorized: bool, decision_delta: float) -> void:
	# Giants remain physical even while animation is sleeping at distance.
	phalanx_target_position = target_position
	phalanx_facing = facing_direction.normalized() if facing_direction.length_squared() > 0.001 else phalanx_facing
	phalanx_moving = moving_to_slot
	if combat != null:
		combat.formation_decision_tick(decision_delta, attack_authorized, moving_to_slot)

func begin_attack_telegraph(pattern_id: StringName, seconds: float) -> void:
	if attack_telegraph != null and not dead:
		attack_telegraph.begin(seconds)
	attack_started.emit(self, &"unarmed")
	attack_telegraphed.emit(self, pattern_id, seconds)

func _on_health_depleted(hit: Variant, zone: StringName) -> void:
	super._on_health_depleted(hit, zone)
	# Bounded corpse lifecycle, without timers retaining this actor after unload.
	var timer := Timer.new()
	timer.wait_time = 18.0
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(queue_free)
	timer.start()

func is_wall_run_giant() -> bool:
	return not dead

func refresh_leg_injury() -> void:
	var left: bool = dismemberment.is_severed(&"thigh_l") or dismemberment.is_severed(&"shin_l")
	var right: bool = dismemberment.is_severed(&"thigh_r") or dismemberment.is_severed(&"shin_r")
	locomotion_factor = 0.0 if left and right else (0.55 if left or right else 1.0)
	if left and right:
		presentation.position.y = -0.48 * size_multiplier
		presentation.rotation.x = deg_to_rad(-18.0)
		var capsule := combat.locomotion_collision.shape as CapsuleShape3D
		capsule.height = 0.95 * size_multiplier
		capsule.radius = 0.38 * size_multiplier
		combat.locomotion_collision.position.y = capsule.height * 0.5
		phalanx_target_position = global_position
