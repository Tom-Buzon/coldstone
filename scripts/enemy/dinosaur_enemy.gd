extends HopliteAthenianEnemy
class_name HopliteDinosaurEnemy

const DinosaurRuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const DinosaurAnatomyScript = preload("res://scripts/enemy/anatomy_hitbox.gd")
const DinosaurArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const DinosaurNavigationScript = preload("res://scripts/ai/enemy_navigation_component.gd")
const DinosaurDetachedLimbScript = preload("res://scripts/gore/detached_limb_proxy.gd")

enum DinosaurState { IDLE, HUNT, CREATE_SPACE, ALIGN, WINDUP, ATTACK, RECOVERY, DEAD }

const GRAVITY := 24.0
const NAVIGATION_REFRESH := 0.18
const PACK_QUERY_INTERVAL := 0.35
const TRAVERSAL_LAYER := 256
const DINOSAUR_LOD_REFRESH_INTERVAL := 0.20
const DINOSAUR_AUTO_CROWD_THRESHOLD := 12
const CAMERA_OCCLUSION_COLLIDER_AUTHORITATIVE_META := &"camera_occlusion_collider_authoritative"
const RAPTOR_GROUND_BONES: Array[StringName] = [
	&"Velo_l_Toe_01_02SHJnt_042_end_076",
	&"Velo_l_Toe_02_02SHJnt_044_end_077",
	&"Velo_l_Toe_03_02SHJnt_046_end_078",
	&"Velo_r_Toe_01_02SHJnt_052_end_079",
	&"Velo_r_Toe_02_02SHJnt_054_end_080",
	&"Velo_r_Toe_03_02SHJnt_056_end_081",
]

var dinosaur_state: DinosaurState = DinosaurState.IDLE
var dinosaur_kind: StringName = &"raptor"
var pack_hunter := false
var dinosaur_auto_crowd_threshold: int = DINOSAUR_AUTO_CROWD_THRESHOLD
var target_height := 3.25
var state_time_left := 0.0
var attack_hit_done := false
var charge_direction := Vector3.ZERO
var trex_charge_trigger_range := 9.5
var trex_windup_duration := 0.72
var trex_charge_duration := 1.05
var trex_charge_speed := 13.5
var trex_recovery_duration := 1.45
var trex_min_charge_distance := 5.5
var trex_space_duration := 0.80
var trex_space_distance := 3.0
var trex_space_speed := 4.2
var trex_align_duration := 1.15
var trex_align_turn_speed := deg_to_rad(82.0)
var trex_align_tolerance := deg_to_rad(10.0)
var trex_space_start_position := Vector3.ZERO
var trex_space_direction := Vector3.ZERO
var head_severed := false
var severed_head_bone := -1

var dinosaur_visual: Node3D
var dinosaur_visual_pivot: Node3D
var dinosaur_animation_players: Array[AnimationPlayer] = []
var current_animation_kind: StringName = StringName()
var navigation_refresh_left := 0.0
var pack_query_left := 0.0
var cached_separation := Vector3.ZERO
var traversal_by_zone: Dictionary = {}
var raptor_ground_bone_indices := PackedInt32Array()
var dinosaur_meshes: Array[MeshInstance3D] = []
var dinosaur_mesh_defaults: Dictionary = {}
var dinosaur_animation_accumulator: float = 0.0
var dinosaur_animation_manual: bool = false
var dinosaur_crowd_mode_cached: bool = false
var dinosaur_physics_accumulator: float = 0.0
var dinosaur_physics_phase: int = 0
var dinosaur_full_physics_steps: int = 0
var dinosaur_deferred_physics_steps: int = 0
var dinosaur_anatomy_updates: int = 0
var traversal_lod_enabled: bool = true
var dinosaur_lod_enabled_cached: bool = false
var dinosaur_cull_distance_cached: float = -1.0


func _ready() -> void:
	_apply_dinosaur_profile()
	if dinosaur_kind == &"trex":
		# This imported skin has invalid authored bounds. Its existing physics
		# colliders are the reliable camera-occlusion source instead.
		set_meta(CAMERA_OCCLUSION_COLLIDER_AUTHORITATIVE_META, true)
	_build_dinosaur_physics()
	_build_dinosaur_visual()
	_build_dinosaur_anatomy()
	_configure_navigation()
	add_to_group("enemy")
	add_to_group("athenian")
	add_to_group("damageable")
	add_to_group("combatant")
	add_to_group("dinosaur_enemy")
	add_to_group("raptor_pack_hunter" if pack_hunter else "solitary_predator")
	if ai_enabled:
		add_to_group("combatant_ai")
		add_to_group("enemy_ai")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	reset_physics_interpolation()
	_enter_state(DinosaurState.IDLE, 0.0)
	performance_lod_timer = randf_range(0.0, DINOSAUR_LOD_REFRESH_INTERVAL) if ai_enabled else 0.0
	_update_performance_lod()
	set_process(false)
	set_physics_process(true)


func _process(_delta: float) -> void:
	# The humanoid parent presentation loop does not apply to imported dinosaurs.
	pass


func _physics_process(delta: float) -> void:
	if ai_enabled and not dead:
		performance_lod_timer -= delta
		if performance_lod_timer <= 0.0:
			_update_performance_lod()
			performance_lod_timer = DINOSAUR_LOD_REFRESH_INTERVAL
	_update_dinosaur_animation_sampling(delta)
	if severed_head_bone >= 0:
		skeleton.set_bone_pose_scale(severed_head_bone, Vector3.ZERO)
	if dead:
		return
	if ai_enabled and _defer_dinosaur_physics_step(delta):
		return
	delta += dinosaur_physics_accumulator
	dinosaur_physics_accumulator = 0.0
	dinosaur_full_physics_steps += 1
	if not ai_enabled:
		_update_dinosaur_contact_surfaces()
		return
	if ai_attack_cooldown_timer > 0.0:
		ai_attack_cooldown_timer = maxf(0.0, ai_attack_cooldown_timer - delta)
	state_time_left -= delta
	pack_query_left -= delta
	if pack_query_left <= 0.0:
		pack_query_left = PACK_QUERY_INTERVAL * (1.0 if render_lod_level <= 0 else (2.0 if render_lod_level == 1 else 4.0))
		cached_separation = _separation_steering()
		_share_pack_target()
	match dinosaur_state:
		DinosaurState.IDLE:
			_update_idle(delta)
		DinosaurState.HUNT:
			_update_hunt(delta)
		DinosaurState.CREATE_SPACE:
			_update_create_space(delta)
		DinosaurState.ALIGN:
			_update_align(delta)
		DinosaurState.WINDUP:
			_update_windup(delta)
		DinosaurState.ATTACK:
			_update_attack(delta)
		DinosaurState.RECOVERY:
			_update_recovery(delta)
	# One post-motion sample is the single authority for animated hitboxes and
	# traversal. Previously AnatomyHitbox also sampled itself while this controller
	# forced two more complete updates every tick.
	_update_dinosaur_contact_surfaces()


func _update_performance_lod() -> void:
	if not ai_enabled:
		dinosaur_crowd_mode_cached = false
		cached_player_distance = 0.0
		_apply_dinosaur_lod(0, false, INF)
		return
	var lod_reference: Node3D = battle_player if battle_player != null and is_instance_valid(battle_player) else ai_player
	if lod_reference == null or not is_instance_valid(lod_reference):
		cached_player_distance = INF
	else:
		var delta_to_player: Vector3 = lod_reference.global_position - global_position
		delta_to_player.y = 0.0
		cached_player_distance = delta_to_player.length()
	dinosaur_crowd_mode_cached = _resolve_dinosaur_auto_crowd_mode()
	var lod_settings: Dictionary = _runtime_lod_settings()
	var lod_enabled: bool = bool(lod_settings["enabled"])
	var near_distance: float = float(lod_settings["near_distance"])
	var far_distance: float = float(lod_settings["far_distance"])
	var cull_distance: float = float(lod_settings["cull_distance"])
	var next_level: int = 0
	if lod_enabled:
		if cached_player_distance > cull_distance:
			next_level = 3
		elif cached_player_distance > far_distance:
			next_level = 2
		elif cached_player_distance > near_distance:
			next_level = 1
	var manual_sampling_changed: bool = dinosaur_animation_manual != _dinosaur_should_sample_animation_manually(next_level, lod_settings)
	var settings_changed: bool = lod_enabled != dinosaur_lod_enabled_cached or not is_equal_approx(cull_distance, dinosaur_cull_distance_cached)
	if next_level != render_lod_level or manual_sampling_changed or settings_changed:
		_apply_dinosaur_lod(next_level, lod_enabled, cull_distance)


func _apply_dinosaur_lod(level: int, lod_enabled: bool, cull_distance: float) -> void:
	dinosaur_lod_enabled_cached = lod_enabled
	dinosaur_cull_distance_cached = cull_distance
	render_lod_level = level if lod_enabled else 0
	dinosaur_animation_accumulator = 0.0
	_configure_dinosaur_animation_sampling(lod_enabled)
	for mesh_instance: MeshInstance3D in dinosaur_meshes:
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue
		var instance_id: int = mesh_instance.get_instance_id()
		if not dinosaur_mesh_defaults.has(instance_id):
			dinosaur_mesh_defaults[instance_id] = {
				"lod_bias": mesh_instance.lod_bias,
				"range_end": mesh_instance.visibility_range_end,
				"range_margin": mesh_instance.visibility_range_end_margin,
				"fade_mode": mesh_instance.visibility_range_fade_mode,
				"cast_shadow": mesh_instance.cast_shadow,
				"visible": mesh_instance.visible,
			}
		var defaults: Dictionary = dinosaur_mesh_defaults[instance_id]
		if not lod_enabled:
			mesh_instance.lod_bias = float(defaults["lod_bias"])
			mesh_instance.visibility_range_end = float(defaults["range_end"])
			mesh_instance.visibility_range_end_margin = float(defaults["range_margin"])
			mesh_instance.visibility_range_fade_mode = int(defaults["fade_mode"])
			mesh_instance.cast_shadow = int(defaults["cast_shadow"])
			mesh_instance.visible = bool(defaults["visible"])
			continue
		mesh_instance.lod_bias = 1.0 if render_lod_level == 0 else (0.55 if render_lod_level == 1 else 0.22)
		# The Unity-authored T-Rex needs a huge custom AABB whose centre is hundreds
		# of metres from the animated surface. Godot's visibility range measures from
		# that false centre and would cull it at medium LOD. Its root-distance LOD
		# below already hides the mesh at level 3, so no second range cull is needed.
		mesh_instance.visibility_range_end = 0.0 if dinosaur_kind == &"trex" else cull_distance
		mesh_instance.visibility_range_end_margin = 3.0
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mesh_instance.cast_shadow = int(defaults["cast_shadow"]) if render_lod_level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.visible = render_lod_level < 3
	if anatomy != null:
		# DinosaurEnemy owns the only anatomy sampling loop. Layer 8 stays available
		# at medium range for ranged hits, but the expensive shapes stop tracking at
		# far LOD where melee and traversal are impossible.
		anatomy.set_tracking_enabled(false)
		anatomy.collision_layer = 8 if render_lod_level <= 1 else 0
	_set_traversal_lod_enabled(render_lod_level == 0)
	if render_lod_level <= 1:
		_update_dinosaur_contact_surfaces()


func _dinosaur_should_sample_animation_manually(level: int, lod_settings: Dictionary) -> bool:
	if level > 0:
		return true
	return dinosaur_crowd_mode_cached and cached_player_distance > float(lod_settings["full_rate_distance"])


func _configure_dinosaur_animation_sampling(lod_enabled: bool) -> void:
	var lod_settings: Dictionary = _runtime_lod_settings()
	dinosaur_animation_manual = lod_enabled and _dinosaur_should_sample_animation_manually(render_lod_level, lod_settings)
	for player_node: AnimationPlayer in dinosaur_animation_players:
		if player_node == null:
			continue
		player_node.callback_mode_process = (
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			if dinosaur_animation_manual
			else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		)
		player_node.advance(0.0)


func _update_dinosaur_animation_sampling(delta: float) -> void:
	if not dinosaur_animation_manual or render_lod_level >= 3:
		return
	var lod_settings: Dictionary = _runtime_lod_settings()
	var animation_hz: float = (
		float(lod_settings["far_animation_hz"])
		if render_lod_level >= 2
		else float(lod_settings["medium_animation_hz"])
	)
	var interval := 1.0 / maxf(animation_hz, 1.0)
	dinosaur_animation_accumulator += delta
	if dinosaur_animation_accumulator + 0.000001 < interval:
		return
	var remainder := fmod(dinosaur_animation_accumulator, interval)
	var sample_delta := dinosaur_animation_accumulator - remainder
	for player_node: AnimationPlayer in dinosaur_animation_players:
		if player_node != null:
			player_node.advance(sample_delta)
	dinosaur_animation_accumulator = remainder


func _defer_dinosaur_physics_step(delta: float) -> bool:
	if not ai_enabled or dead:
		dinosaur_physics_phase = 0
		return false
	var lod_settings: Dictionary = _runtime_lod_settings()
	if not bool(lod_settings["enabled"]):
		dinosaur_physics_phase = 0
		return false
	if render_lod_level >= 3:
		velocity = Vector3.ZERO
		dinosaur_physics_accumulator = 0.0
		dinosaur_deferred_physics_steps += 1
		return true
	if dinosaur_state in [DinosaurState.CREATE_SPACE, DinosaurState.ALIGN, DinosaurState.WINDUP, DinosaurState.ATTACK, DinosaurState.RECOVERY]:
		dinosaur_physics_phase = 0
		return false
	var target_in_contact := false
	if ai_player != null and is_instance_valid(ai_player):
		var target_delta: Vector3 = ai_player.global_position - global_position
		target_delta.y = 0.0
		var full_rate_distance: float = float(lod_settings["full_rate_distance"])
		target_in_contact = target_delta.length_squared() <= full_rate_distance * full_rate_distance
	if target_in_contact:
		dinosaur_physics_phase = 0
		return false
	var divisor := 1
	if render_lod_level == 1:
		divisor = int(lod_settings["medium_physics_divisor"])
	elif render_lod_level == 2:
		divisor = int(lod_settings["far_physics_divisor"])
	elif dinosaur_crowd_mode_cached:
		divisor = int(lod_settings["near_physics_divisor"])
	if divisor <= 1:
		dinosaur_physics_phase = 0
		return false
	dinosaur_physics_phase = (dinosaur_physics_phase + 1) % divisor
	if dinosaur_physics_phase == 0:
		return false
	dinosaur_physics_accumulator += delta
	dinosaur_deferred_physics_steps += 1
	return true


func _resolve_dinosaur_auto_crowd_mode() -> bool:
	if mass_battle_mode:
		return true
	if dinosaur_kind != &"raptor" or String(get_meta("performance_profile", "auto")) != "auto":
		return false
	return int(get_meta("planned_simultaneous_population", 1)) >= dinosaur_auto_crowd_threshold


func _update_dinosaur_contact_surfaces() -> void:
	if anatomy == null or render_lod_level > 1:
		return
	_ground_raptor_on_animated_feet()
	anatomy.force_update()
	dinosaur_anatomy_updates += 1
	if render_lod_level == 0 and traversal_lod_enabled:
		_sync_traversal_surfaces()


func _set_traversal_lod_enabled(enabled: bool) -> void:
	traversal_lod_enabled = enabled
	for raw_zone: Variant in traversal_by_zone.keys():
		var zone := StringName(raw_zone)
		var traversal: Dictionary = traversal_by_zone[zone]
		var body := traversal.get("body") as AnimatableBody3D
		var collision := traversal.get("collision") as CollisionShape3D
		if body == null:
			continue
		var severed: bool = bool((zone_state.get(zone, {}) as Dictionary).get("severed", false))
		body.collision_layer = TRAVERSAL_LAYER if enabled and not severed and collision != null and not collision.disabled else 0


func _apply_dinosaur_profile() -> void:
	var profile := DinosaurArchetypesScript.profile(archetype_id)
	archetype_name = String(profile.get("display_name", String(archetype_id).to_upper()))
	dinosaur_kind = StringName(profile.get("dinosaur_kind", &"raptor"))
	pack_hunter = bool(profile.get("pack_hunter", false))
	dinosaur_auto_crowd_threshold = maxi(1, int(profile.get("dinosaur_auto_crowd_threshold", DINOSAUR_AUTO_CROWD_THRESHOLD)))
	combat_rank = StringName(profile.get("rank", &"elite"))
	behavior_mode = &"pack_predator" if pack_hunter else &"solitary_predator"
	weapon_kind = &"jaws"
	max_health = float(profile.get("health", 260.0))
	health = max_health
	ai_move_speed = float(profile.get("move_speed", 8.0))
	ai_attack_damage = float(profile.get("attack_damage", 28.0))
	ai_attack_range = float(profile.get("attack_range", 2.0))
	ai_aggro_distance = float(profile.get("aggro_distance", 34.0))
	ai_attack_cooldown_min = float(profile.get("cooldown_min", 0.8))
	ai_attack_cooldown_max = float(profile.get("cooldown_max", 1.2))
	target_height = float(profile.get("dinosaur_target_height", 3.25)) * external_scale_multiplier
	trex_charge_trigger_range = float(profile.get("trex_charge_trigger_range", 9.5))
	trex_windup_duration = float(profile.get("trex_windup_duration", 0.72))
	trex_charge_duration = float(profile.get("trex_charge_duration", 1.05))
	trex_charge_speed = float(profile.get("trex_charge_speed", 13.5))
	trex_recovery_duration = float(profile.get("trex_recovery_duration", 1.45))
	trex_min_charge_distance = float(profile.get("trex_min_charge_distance", 5.5))
	trex_space_duration = float(profile.get("trex_space_duration", 0.80))
	trex_space_distance = float(profile.get("trex_space_distance", 3.0))
	trex_space_speed = float(profile.get("trex_space_speed", 4.2))
	trex_align_duration = float(profile.get("trex_align_duration", 1.15))
	trex_align_turn_speed = deg_to_rad(float(profile.get("trex_align_turn_speed_degrees", 82.0)))
	trex_align_tolerance = deg_to_rad(float(profile.get("trex_align_tolerance_degrees", 10.0)))
	base_color = Color(profile.get("color", Color("63834d")))
	character_package_path = String(profile.get("package_candidates", [character_package_path])[0]) if character_package_path.is_empty() else character_package_path
	match_perfect_hitbox = bool(get_meta("match_perfect_hitbox_override", profile.get("forge_default_match_perfect_hitbox", true)))
	giant_traversal_mode = &"exact"
	corpse_lifetime = 20.0


func _build_dinosaur_physics() -> void:
	collision_layer = 4
	collision_mask = (1 | 2) if ai_enabled else 1
	floor_snap_length = 0.42
	floor_max_angle = deg_to_rad(50.0)
	body_collider = CollisionShape3D.new()
	body_collider.name = "BodyCollider"
	var capsule := CapsuleShape3D.new()
	if dinosaur_kind == &"trex":
		capsule.radius = target_height * 0.19
		capsule.height = target_height * 0.78
	else:
		capsule.radius = target_height * 0.18
		capsule.height = target_height * 0.74
	body_collider.shape = capsule
	body_collider.position.y = capsule.height * 0.5
	add_child(body_collider)


func _build_dinosaur_visual() -> void:
	var packed := DinosaurRuntimeGLTFCacheScript.scene(character_package_path)
	if packed == null:
		push_error("[DINOSAUR] Modèle introuvable : %s" % character_package_path)
		return
	dinosaur_visual_pivot = Node3D.new()
	dinosaur_visual_pivot.name = "VisualPivot"
	dinosaur_visual_pivot.rotation.y = PI
	add_child(dinosaur_visual_pivot)
	dinosaur_visual = packed.instantiate() as Node3D
	if dinosaur_visual == null:
		return
	dinosaur_visual.name = "AnimatedVisual"
	dinosaur_visual_pivot.add_child(dinosaur_visual)
	# Center and scale the authored asset first, then rotate the centered pivot.
	# Rotating a strongly off-centre Unity export directly would orbit it around
	# its old origin and separate the rendered mesh from its animated colliders.
	_fit_visual_to_height(dinosaur_visual, target_height)
	_normalize_visual_pivot()
	visual_root = dinosaur_visual_pivot
	if dinosaur_visual is Skeleton3D:
		skeleton = dinosaur_visual as Skeleton3D
	else:
		for candidate: Node in dinosaur_visual.find_children("*", "Skeleton3D", true, false):
			skeleton = candidate as Skeleton3D
			break
	for candidate: Node in dinosaur_visual.find_children("*", "AnimationPlayer", true, false):
		var player_node := candidate as AnimationPlayer
		if player_node != null and not dinosaur_animation_players.has(player_node):
			dinosaur_animation_players.append(player_node)
	animation_player = dinosaur_animation_players[0] if not dinosaur_animation_players.is_empty() else null
	if dinosaur_kind == &"trex" and skeleton != null:
		# The Unity export's static vertex origin differs from its skinned origin.
		# Normalize a second time from the actual bind-pose surface once the
		# Skeleton3D and Skin resources are available.
		_normalize_visual_pivot()
	elif dinosaur_kind == &"raptor" and skeleton != null:
		_cache_raptor_ground_bones()
	for candidate: Node in dinosaur_visual.find_children("*", "MeshInstance3D", true, false):
		_configure_dinosaur_mesh(candidate as MeshInstance3D)


func _build_dinosaur_anatomy() -> void:
	if skeleton == null:
		push_error("[DINOSAUR] Skeleton3D absent pour %s" % String(archetype_id))
		return
	anatomy_defs = _trex_anatomy() if dinosaur_kind == &"trex" else _raptor_anatomy()
	zone_state.clear()
	for raw_zone: Variant in anatomy_defs.keys():
		zone_state[StringName(raw_zone)] = {"damage": 0.0, "sever": 0.0, "severed": false}
	anatomy = DinosaurAnatomyScript.new() as HopliteAnatomyHitbox
	anatomy.name = "DinosaurAnatomy"
	add_child(anatomy)
	if dinosaur_kind == &"trex":
		anatomy.set_bone_world_position_mapper(_trex_bone_world_position)
	if not anatomy.configure(self, skeleton, anatomy_defs):
		push_error("[DINOSAUR] Aucun os anatomique reconnu pour %s" % String(archetype_id))
		return
	anatomy.force_update()
	_build_traversal_surfaces()
	# This controller samples anatomy once after locomotion. Leaving the Area's
	# own physics callback active would duplicate the full bone/shape pass.
	anatomy.set_tracking_enabled(false)


func _configure_navigation() -> void:
	navigation_component = DinosaurNavigationScript.new()
	navigation_component.configure(self, DinosaurNavigationScript.Mode.NAVMESH_GROUND, {
		"agent_radius": target_height * (0.18 if dinosaur_kind == &"trex" else 0.15),
		"agent_height": target_height * 0.72,
		"navigation_layers": navigation_layers,
		"arrival_distance": ai_attack_range * 0.72,
		"fallback_mode": DinosaurNavigationScript.Mode.DIRECT_STEERING,
		"stuck_timeout": 0.85,
		"recovery_duration": 0.48,
	})


func _update_idle(delta: float) -> void:
	_apply_stopping_motion(delta)
	if ai_player != null and is_instance_valid(ai_player) and _target_flat_distance() <= ai_aggro_distance:
		_enter_state(DinosaurState.HUNT, 0.0)


func _update_hunt(delta: float) -> void:
	if ai_player == null or not is_instance_valid(ai_player):
		_enter_state(DinosaurState.IDLE, 0.0)
		return
	var distance := _target_flat_distance()
	var attack_trigger_range := trex_charge_trigger_range if dinosaur_kind == &"trex" else ai_attack_range
	if distance <= attack_trigger_range and ai_attack_cooldown_timer <= 0.0:
		_begin_attack()
		return
	navigation_refresh_left -= delta
	if navigation_refresh_left <= 0.0:
		navigation_refresh_left = NAVIGATION_REFRESH * (1.0 if render_lod_level <= 0 else (1.8 if render_lod_level == 1 else 3.0))
		navigation_component.set_destination(_hunt_destination())
	var intent = navigation_component.sample_intent(delta)
	var direction: Vector3 = intent.direction if intent.valid else _flat_direction_to(ai_player.global_position)
	direction = (direction + cached_separation).normalized() if (direction + cached_separation).length_squared() > 0.0001 else direction
	var previous_position := global_position
	velocity.x = move_toward(velocity.x, direction.x * ai_move_speed * maxf(0.35, float(intent.speed_scale)), ai_move_speed * 4.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * ai_move_speed * maxf(0.35, float(intent.speed_scale)), ai_move_speed * 4.0 * delta)
	_apply_gravity(delta)
	move_and_slide()
	navigation_component.notify_motion_applied(previous_position, global_position, delta, direction)
	_face_direction(direction, delta * (9.5 if pack_hunter else 5.5))
	_play_animation(&"run")


func _begin_attack() -> void:
	attack_hit_done = false
	if dinosaur_kind == &"trex":
		if _target_flat_distance() < trex_min_charge_distance:
			_begin_trex_create_space()
		else:
			_begin_trex_alignment()
		return
	attack_started.emit(self, &"jaws")
	_enter_state(DinosaurState.ATTACK, 0.58 if pack_hunter else 0.92)
	_play_animation(&"attack")


func _begin_trex_create_space() -> void:
	trex_space_start_position = global_position
	trex_space_direction = global_basis.z
	trex_space_direction.y = 0.0
	if trex_space_direction.length_squared() <= 0.0001:
		trex_space_direction = Vector3.BACK
	else:
		trex_space_direction = trex_space_direction.normalized()
	_enter_state(DinosaurState.CREATE_SPACE, trex_space_duration)


func _update_create_space(delta: float) -> void:
	if ai_player == null or not is_instance_valid(ai_player):
		_enter_state(DinosaurState.IDLE, 0.0)
		return
	var travelled := global_position - trex_space_start_position
	travelled.y = 0.0
	if state_time_left <= 0.0 or travelled.length() >= trex_space_distance or _target_flat_distance() >= trex_min_charge_distance:
		_begin_trex_alignment()
		return
	velocity.x = move_toward(velocity.x, trex_space_direction.x * trex_space_speed, trex_space_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, trex_space_direction.z * trex_space_speed, trex_space_speed * 6.0 * delta)
	_apply_gravity(delta)
	move_and_slide()
	if _trex_motion_hit_obstacle(trex_space_direction):
		_begin_trex_alignment()


func _begin_trex_alignment() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_enter_state(DinosaurState.ALIGN, trex_align_duration)


func _update_align(delta: float) -> void:
	_apply_stopping_motion(delta)
	if ai_player == null or not is_instance_valid(ai_player):
		_enter_state(DinosaurState.IDLE, 0.0)
		return
	var target_direction := _flat_direction_to(ai_player.global_position)
	var current_forward := -global_basis.z
	current_forward.y = 0.0
	current_forward = current_forward.normalized()
	var angle := current_forward.angle_to(target_direction)
	if angle <= trex_align_tolerance:
		_lock_trex_charge(target_direction)
		return
	if state_time_left <= 0.0:
		# A circling player cannot hold the preparation forever. The T-Rex commits
		# to its current heading instead of snapping to the target.
		_lock_trex_charge(current_forward)
		return
	_face_direction_limited(target_direction, trex_align_turn_speed, delta)


func _lock_trex_charge(direction: Vector3) -> void:
	attack_hit_done = false
	charge_direction = direction.normalized() if direction.length_squared() > 0.0001 else -global_basis.z
	attack_started.emit(self, &"jaws")
	_enter_state(DinosaurState.WINDUP, trex_windup_duration)


func _update_windup(delta: float) -> void:
	_apply_stopping_motion(delta)
	if state_time_left <= 0.0:
		_enter_state(DinosaurState.ATTACK, trex_charge_duration)


func _update_attack(delta: float) -> void:
	if dinosaur_kind == &"trex":
		_update_trex_charge(delta)
		return
	_apply_stopping_motion(delta)
	_face_target(delta * 8.0)
	var hit_moment := 0.30 if pack_hunter else 0.48
	if not attack_hit_done and state_time_left <= hit_moment:
		attack_hit_done = _damage_target()
	if state_time_left <= 0.0:
		ai_attack_cooldown_timer = randf_range(ai_attack_cooldown_min, ai_attack_cooldown_max)
		_enter_state(DinosaurState.RECOVERY, 0.28 if pack_hunter else 0.62)


func _update_trex_charge(delta: float) -> void:
	velocity.x = charge_direction.x * trex_charge_speed
	velocity.z = charge_direction.z * trex_charge_speed
	_apply_gravity(delta)
	move_and_slide()
	if not attack_hit_done:
		attack_hit_done = _damage_target()
	if attack_hit_done or state_time_left <= 0.0 or _trex_motion_hit_obstacle(charge_direction):
		_finish_trex_charge()


func _trex_motion_hit_obstacle(motion_direction: Vector3) -> bool:
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var normal: Vector3 = collision.get_normal()
		if absf(normal.y) < 0.55 and normal.dot(motion_direction) < -0.35:
			return true
	return false


func _finish_trex_charge() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	ai_attack_cooldown_timer = randf_range(ai_attack_cooldown_min, ai_attack_cooldown_max)
	_enter_state(DinosaurState.RECOVERY, trex_recovery_duration)


func _update_recovery(delta: float) -> void:
	_apply_stopping_motion(delta)
	if dinosaur_kind != &"trex":
		_face_target(delta * 5.0)
	if state_time_left <= 0.0:
		if dinosaur_kind == &"trex" and _target_flat_distance() < trex_min_charge_distance:
			_begin_trex_create_space()
		else:
			_enter_state(DinosaurState.HUNT, 0.0)


func _apply_stopping_motion(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ai_move_speed * 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, ai_move_speed * 5.0 * delta)
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1


func _hunt_destination() -> Vector3:
	if not pack_hunter or ai_player == null:
		return ai_player.global_position
	var slot_angle := float(posmod(ai_guard_index * 137, 360)) * PI / 180.0
	var ring_radius := ai_attack_range * 0.78
	return ai_player.global_position + Vector3(cos(slot_angle), 0.0, sin(slot_angle)) * ring_radius


func _share_pack_target() -> void:
	if not pack_hunter or get_tree() == null:
		return
	var group_id := StringName(get_meta("formation_group", StringName()))
	for candidate: Node in get_tree().get_nodes_in_group("raptor_pack_hunter"):
		var ally := candidate as HopliteDinosaurEnemy
		if ally == null or ally == self or ally.dead:
			continue
		if group_id != StringName() and StringName(ally.get_meta("formation_group", StringName())) != group_id:
			continue
		if ai_player != null and is_instance_valid(ai_player) and ally.ai_player == null:
			ally.ai_player = ai_player
			ally._enter_state(DinosaurState.HUNT, 0.0)
		elif ai_player == null and ally.ai_player != null and is_instance_valid(ally.ai_player):
			ai_player = ally.ai_player
			_enter_state(DinosaurState.HUNT, 0.0)


func _separation_steering() -> Vector3:
	if get_tree() == null:
		return Vector3.ZERO
	var result := Vector3.ZERO
	var radius := 3.0 if pack_hunter else 10.0
	for candidate: Node in get_tree().get_nodes_in_group("dinosaur_enemy"):
		var other := candidate as HopliteDinosaurEnemy
		if other == null or other == self or other.dead:
			continue
		if pack_hunter and other.dinosaur_kind != dinosaur_kind:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.01 and distance < radius:
			result += away.normalized() * (1.0 - distance / radius)
	return result.normalized() * (0.34 if pack_hunter else 0.72) if result.length_squared() > 0.0001 else Vector3.ZERO


func _damage_target() -> bool:
	if ai_player == null or not is_instance_valid(ai_player) or _target_flat_distance() > ai_attack_range * 1.18:
		return false
	if absf(ai_player.global_position.y - global_position.y) > target_height * 0.46:
		return false
	var direction := _flat_direction_to(ai_player.global_position)
	if ai_player.has_method("receive_enemy_hit"):
		return bool(ai_player.call("receive_enemy_hit", ai_attack_damage, self, direction * (8.0 if pack_hunter else 14.0)))
	return false


func can_receive_hit_from(source: Node) -> bool:
	return not dead and not (faction == &"spartan" and source != null and source.is_in_group("player"))


func receive_anatomy_hit(hit: Variant, zone: StringName) -> void:
	if dead or not anatomy_defs.has(zone) or not zone_state.has(zone) or not can_receive_hit_from(hit.source):
		return
	var definition: Dictionary = anatomy_defs[zone]
	var state: Dictionary = zone_state[zone]
	if bool(state.get("severed", false)):
		return
	var damage := maxf(0.0, float(hit.damage) * float(definition.get("damage_mult", 1.0)))
	var sever := maxf(0.0, float(hit.sever_damage) * float(definition.get("sever_mult", 1.0)))
	var hit_source := hit.source as Node
	if StringName(hit.attack_context) == &"wall" or (hit_source != null and hit_source.is_in_group("player") and bool(hit_source.get("wall_run_active"))):
		sever *= 1.65
	health = maxf(0.0, health - damage)
	state["damage"] = float(state.get("damage", 0.0)) + damage
	state["sever"] = float(state.get("sever", 0.0)) + sever
	zone_state[zone] = state
	last_hit_zone = zone
	last_hit_damage = damage
	last_hit_sever = float(state["sever"])
	localized_hit.emit(self, zone, damage, sever)
	if pack_hunter:
		_share_pack_target()
	if bool(definition.get("severable", false)) and float(state["sever"]) >= float(definition.get("sever_threshold", 9999.0)):
		_sever_head(zone, hit)
		return
	if health <= 0.0:
		_die(false)


func receive_ai_hit(damage: float, attacker: Node3D, _hit_direction: Vector3) -> bool:
	if dead or not can_receive_hit_from(attacker):
		return false
	health = maxf(0.0, health - maxf(0.0, damage))
	if health <= 0.0:
		_die(false)
	return true


func alert_ai(duration: float = 8.0) -> void:
	ai_alert_timer = maxf(ai_alert_timer, duration)
	if dinosaur_state == DinosaurState.IDLE and ai_player != null:
		_enter_state(DinosaurState.HUNT, 0.0)


func is_wall_run_giant() -> bool:
	return not dead and match_perfect_hitbox and giant_traversal_mode != &"off"


func is_dead_for_combat() -> bool:
	return dead


func _sever_head(zone: StringName, hit: Variant) -> void:
	if head_severed:
		return
	head_severed = true
	for sever_zone: StringName in [&"head", &"neck"]:
		if zone_state.has(sever_zone):
			var state: Dictionary = zone_state[sever_zone]
			state["severed"] = true
			zone_state[sever_zone] = state
		if anatomy != null:
			anatomy.disable_zone(sever_zone)
		_disable_traversal_zone(sever_zone)
	severed_head_bone = _find_bone(_head_collapse_candidates())
	var head_transform := anatomy.get_zone_world_transform(&"head") if anatomy != null else global_transform
	var head_radius := anatomy.get_zone_world_radius(&"head") if anatomy != null else target_height * 0.10
	var detached := DinosaurDetachedLimbScript.new() as HopliteDetachedLimbProxy
	var debris_parent := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	debris_parent.add_child(detached)
	var hit_direction: Vector3 = hit.direction
	detached.setup(&"head", head_transform, head_radius, head_radius * 2.0, base_color, hit_direction * 2.2)
	zone_severed.emit(self, zone)
	_die(true)


func _die(_from_sever: bool) -> void:
	if dead:
		return
	dead = true
	dinosaur_state = DinosaurState.DEAD
	_set_attack_outline_active(false)
	velocity = Vector3.ZERO
	if body_collider != null:
		body_collider.set_deferred("disabled", true)
	if anatomy != null:
		anatomy.shutdown()
	for raw_zone: Variant in traversal_by_zone.keys():
		_disable_traversal_zone(StringName(raw_zone))
	if dinosaur_kind == &"trex":
		_play_animation(&"die")
	elif dinosaur_visual_pivot != null:
		create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(dinosaur_visual_pivot, "rotation:z", deg_to_rad(82.0), 0.72)
	died.emit(self)
	if get_tree() != null:
		get_tree().create_timer(corpse_lifetime).timeout.connect(queue_free)


func _enter_state(next_state: DinosaurState, duration: float) -> void:
	dinosaur_state = next_state
	_set_attack_outline_active(next_state == DinosaurState.WINDUP)
	state_time_left = duration
	match next_state:
		DinosaurState.IDLE, DinosaurState.ALIGN, DinosaurState.WINDUP, DinosaurState.RECOVERY:
			_play_animation(&"idle")
		DinosaurState.HUNT, DinosaurState.CREATE_SPACE:
			_play_animation(&"run")
		DinosaurState.ATTACK:
			_play_animation(&"attack")


func _play_animation(kind: StringName) -> void:
	if kind == current_animation_kind:
		return
	current_animation_kind = kind
	var candidates: Array[StringName]
	match kind:
		&"run": candidates = [&"loopRun", &"run", &"loopWalk", &"walk"]
		&"attack": candidates = [&"attack1", &"loopAttack", &"attack", &"loopJumpAtackLegsHead"]
		&"die": candidates = [&"die", &"death"]
		_: candidates = [&"loopFightIdle", &"loopIdle", &"idle", &"loopLookRound"]
	var pose_applied := false
	for player_node: AnimationPlayer in dinosaur_animation_players:
		var animation_name := _find_animation(player_node, candidates)
		if animation_name == StringName():
			continue
		var animation := player_node.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_NONE if kind in [&"attack", &"die"] else Animation.LOOP_LINEAR
		player_node.play(animation_name, 0.14 if not player_node.current_animation.is_empty() else 0.0, 1.0)
		player_node.advance(0.0)
		pose_applied = true
	if pose_applied:
		_recenter_visual_pivot()
		_ground_raptor_on_animated_feet()


func _find_animation(player_node: AnimationPlayer, candidates: Array[StringName]) -> StringName:
	var names := player_node.get_animation_list()
	for candidate: StringName in candidates:
		var wanted := String(candidate).to_lower().replace("_", "")
		for available: StringName in names:
			var normalized := String(available).to_lower().replace("_", "")
			if normalized == wanted or normalized.contains(wanted):
				return available
	return StringName()


func _build_traversal_surfaces() -> void:
	if not match_perfect_hitbox or anatomy == null:
		return
	var root := Node3D.new()
	root.name = "TraversalSurfaces"
	add_child(root)
	for raw_zone: Variant in anatomy.zone_runtime.keys():
		var zone := StringName(raw_zone)
		var runtime: Dictionary = anatomy.zone_runtime[zone]
		var source := runtime.get("collision") as CollisionShape3D
		if source == null or source.shape == null:
			continue
		var body := AnimatableBody3D.new()
		body.name = "Traversal_%s" % String(zone)
		body.top_level = true
		body.sync_to_physics = true
		body.collision_layer = TRAVERSAL_LAYER
		body.collision_mask = 0
		body.add_to_group("giant_wall_run_surface")
		body.set_meta("giant_owner", self)
		body.set_meta("damage_zone", zone)
		root.add_child(body)
		var collision := CollisionShape3D.new()
		collision.name = "Shape"
		collision.shape = source.shape.duplicate(true) as Shape3D
		body.add_child(collision)
		traversal_by_zone[zone] = {"body": body, "collision": collision}
		matched_walkable_surfaces.append(body)
	_sync_traversal_surfaces()


func _sync_traversal_surfaces() -> void:
	if anatomy == null:
		return
	for raw_zone: Variant in traversal_by_zone.keys():
		var zone := StringName(raw_zone)
		if not anatomy.zone_runtime.has(zone):
			continue
		var source := (anatomy.zone_runtime[zone] as Dictionary).get("collision") as CollisionShape3D
		var traversal: Dictionary = traversal_by_zone[zone]
		var body := traversal.get("body") as AnimatableBody3D
		var collision := traversal.get("collision") as CollisionShape3D
		if source == null or body == null or collision == null or collision.disabled:
			continue
		body.global_transform = source.global_transform
		if source.shape is CapsuleShape3D and collision.shape is CapsuleShape3D:
			(collision.shape as CapsuleShape3D).radius = (source.shape as CapsuleShape3D).radius
			(collision.shape as CapsuleShape3D).height = (source.shape as CapsuleShape3D).height
		elif source.shape is SphereShape3D and collision.shape is SphereShape3D:
			(collision.shape as SphereShape3D).radius = (source.shape as SphereShape3D).radius


func _disable_traversal_zone(zone: StringName) -> void:
	if not traversal_by_zone.has(zone):
		return
	var traversal: Dictionary = traversal_by_zone[zone]
	var body := traversal.get("body") as AnimatableBody3D
	var collision := traversal.get("collision") as CollisionShape3D
	if body != null:
		body.collision_layer = 0
	if collision != null:
		collision.set_deferred("disabled", true)


func _raptor_anatomy() -> Dictionary:
	return {
		&"head": _zone(["Velo_Head_TopSHJnt_033_033"], [], 0.42, &"sphere", 1.45, 2.0, true, 82.0),
		&"neck": _zone(["Velo_Neck_01SHJnt_027_027"], ["Velo_Neck_TopSHJnt_031_031"], 0.31, &"capsule", 1.20, 1.65, true, 96.0),
		&"torso": _zone(["Velo_Spine_01SHJnt_02_03"], ["Velo_Spine_TopSHJnt_06_07"], 0.57, &"capsule"),
		&"pelvis": _zone(["Velo_ROOTSHJnt_01_02"], ["Velo_Spine_02SHJnt_03_04"], 0.55, &"capsule"),
		&"tail_base": _zone(["Velo_Tail_01_01SHJnt_057_058"], ["Velo_Tail_01_04SHJnt_060_061"], 0.34, &"capsule"),
		&"tail_mid": _zone(["Velo_Tail_01_04SHJnt_060_061"], ["Velo_Tail_01_07SHJnt_063_064"], 0.23, &"capsule"),
		&"tail_tip": _zone(["Velo_Tail_01_07SHJnt_063_064"], ["Velo_Tail_01_09SHJnt_065_066"], 0.14, &"capsule"),
		&"thigh_l": _zone(["Velo_l_Leg_HipSHJnt_036_036"], ["Velo_l_Leg_Knee_CurveSHJnt_037_037"], 0.27, &"capsule"),
		&"shin_l": _zone(["Velo_l_Leg_Knee_CurveSHJnt_037_037"], ["Velo_l_Leg_AnkleSHJnt_038_038"], 0.22, &"capsule"),
		&"foot_l": _zone(["Velo_l_Leg_AnkleSHJnt_038_038"], ["Velo_l_Leg_ToeSHJnt_040_040"], 0.18, &"capsule"),
		&"thigh_r": _zone(["Velo_r_Leg_HipSHJnt_047_047"], ["Velo_r_Leg_Knee_CurveSHJnt_048_048"], 0.27, &"capsule"),
		&"shin_r": _zone(["Velo_r_Leg_Knee_CurveSHJnt_048_048"], ["Velo_r_Leg_AnkleSHJnt_049_049"], 0.22, &"capsule"),
		&"foot_r": _zone(["Velo_r_Leg_AnkleSHJnt_049_049"], ["Velo_r_Leg_ToeSHJnt_050_051"], 0.18, &"capsule"),
		&"arm_l": _zone(["Velo_l_Arm_Shoulder_CurveSHJnt_08_09"], ["Velo_l_Arm_WristSHJnt_010_011"], 0.14, &"capsule"),
		&"arm_r": _zone(["Velo_r_Arm_Shoulder_CurveSHJnt_018_00"], ["Velo_r_Arm_WristSHJnt_020_020"], 0.14, &"capsule"),
	}


func _trex_anatomy() -> Dictionary:
	return {
		&"head": _zone(["joint18_029"], ["joint19_030"], 0.78, &"capsule", 1.42, 2.0, true, 138.0),
		&"neck": _zone(["joint15_018"], ["joint17_025"], 0.70, &"capsule", 1.18, 1.65, true, 162.0),
		&"torso": _zone(["joint12_015"], ["joint15_018"], 1.22, &"capsule"),
		&"tail_base": _zone(["joint12_015"], ["joint24_038"], 0.78, &"capsule"),
		&"tail_mid": _zone(["joint24_038"], ["joint27_041"], 0.50, &"capsule"),
		&"tail_tip": _zone(["joint27_041"], ["joint29_043"], 0.28, &"capsule"),
		&"thigh_l": _zone(["joint1_045"], ["joint2_046"], 0.72, &"capsule"),
		&"shin_l": _zone(["joint2_046"], ["joint4_048"], 0.48, &"capsule"),
		&"foot_l": _zone(["joint4_048"], ["joint6_050"], 0.36, &"capsule"),
		&"thigh_r": _zone(["joint31_051"], ["joint2 1_052"], 0.72, &"capsule"),
		&"shin_r": _zone(["joint2 1_052"], ["joint4 1_054"], 0.48, &"capsule"),
		&"foot_r": _zone(["joint4 1_054"], ["joint6 1_056"], 0.36, &"capsule"),
		&"arm_l": _zone(["joint7_019"], ["joint10 1_022"], 0.24, &"capsule"),
		&"arm_r": _zone(["joint30_031"], ["joint10_034"], 0.24, &"capsule"),
	}


func _zone(
	bone_a: Array,
	bone_b: Array,
	radius: float,
	shape: StringName,
	damage_mult: float = 1.0,
	sever_mult: float = 1.0,
	severable: bool = false,
	sever_threshold: float = 9999.0
) -> Dictionary:
	return {"bone_a": bone_a, "bone_b": bone_b, "radius": radius, "shape": shape, "damage_mult": damage_mult, "sever_mult": sever_mult, "severable": severable, "sever_threshold": sever_threshold}


func _head_collapse_candidates() -> Array[String]:
	return ["joint17_025"] if dinosaur_kind == &"trex" else ["Velo_Neck_TopSHJnt_031_031"]


func _trex_bone_world_position(bone_index: int) -> Vector3:
	if skeleton == null or bone_index < 0 or bone_index >= skeleton.get_bone_count():
		return global_position
	var reference_index := skeleton.find_bone("joint12_015")
	if reference_index < 0:
		return skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
	var raw_world := skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
	var reference_world := skeleton.to_global(skeleton.get_bone_global_pose(reference_index).origin)
	var torso_anchor := to_global(Vector3(0.0, target_height * 0.53, 0.0))
	return torso_anchor + (raw_world - reference_world)


func _find_bone(candidates: Array) -> int:
	if skeleton == null:
		return -1
	for candidate: String in candidates:
		var exact := skeleton.find_bone(candidate)
		if exact >= 0:
			return exact
	return -1


func _target_flat_distance() -> float:
	if ai_player == null or not is_instance_valid(ai_player):
		return INF
	var offset := ai_player.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _flat_direction_to(world_point: Vector3) -> Vector3:
	var direction := world_point - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else -global_basis.z


func _face_target(weight: float) -> void:
	if ai_player != null and is_instance_valid(ai_player):
		_face_direction(_flat_direction_to(ai_player.global_position), weight)


func _face_direction(direction: Vector3, weight: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	var target_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	basis = basis.slerp(target_basis, clampf(weight, 0.0, 1.0)).orthonormalized()


func _face_direction_limited(direction: Vector3, angular_speed: float, delta: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	var current_forward := -global_basis.z
	current_forward.y = 0.0
	if current_forward.length_squared() <= 0.0001:
		return
	current_forward = current_forward.normalized()
	var flat_direction := direction
	flat_direction.y = 0.0
	flat_direction = flat_direction.normalized()
	var angle := current_forward.angle_to(flat_direction)
	if angle <= 0.0001:
		return
	_face_direction(flat_direction, minf(1.0, maxf(0.0, angular_speed) * delta / angle))


func _fit_visual_to_height(content: Node3D, wanted_height: float) -> void:
	var bounds := _node_bounds(content)
	if bounds.size.y <= 0.001:
		return
	var scale_value := wanted_height / bounds.size.y
	content.scale = Vector3.ONE * scale_value
	content.position = Vector3(
		-(bounds.position.x + bounds.size.x * 0.5) * scale_value,
		-bounds.position.y * scale_value,
		-(bounds.position.z + bounds.size.z * 0.5) * scale_value
	)


func _node_bounds(content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		var to_content := content.global_transform.affine_inverse() * mesh.global_transform
		var mesh_bounds := to_content * mesh.get_aabb()
		bounds = mesh_bounds if not initialized else bounds.merge(mesh_bounds)
		initialized = true
	return bounds


func _normalize_visual_pivot() -> void:
	var world_bounds := _visual_world_bounds()
	if world_bounds.size.y <= 0.001:
		return
	dinosaur_visual_pivot.scale *= target_height / world_bounds.size.y
	world_bounds = _visual_world_bounds()
	_recenter_visual_pivot(world_bounds)


func _recenter_visual_pivot(existing_bounds: AABB = AABB()) -> void:
	if dinosaur_visual_pivot == null or dinosaur_visual == null:
		return
	var world_bounds := existing_bounds if existing_bounds.size.length_squared() > 0.0001 else _visual_world_bounds()
	if world_bounds.size.length_squared() <= 0.0001:
		return
	var center := world_bounds.get_center()
	var correction_world := Vector3(
		global_position.x - center.x,
		global_position.y - world_bounds.position.y,
		global_position.z - center.z
	)
	dinosaur_visual_pivot.position += global_basis.inverse() * correction_world


func _ground_raptor_on_animated_feet() -> void:
	if dinosaur_kind != &"raptor" or skeleton == null or dinosaur_visual_pivot == null:
		return
	var lowest_foot_y := INF
	var found_foot := false
	for bone_index: int in raptor_ground_bone_indices:
		var foot_world := skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
		lowest_foot_y = minf(lowest_foot_y, foot_world.y)
		found_foot = true
	if not found_foot:
		return
	# The character origin represents the floor. Using the animated toe tips keeps
	# idle/run clips grounded even though their skinned AABBs differ.
	var correction_world := Vector3(0.0, global_position.y - lowest_foot_y, 0.0)
	dinosaur_visual_pivot.position += global_basis.inverse() * correction_world


func _cache_raptor_ground_bones() -> void:
	raptor_ground_bone_indices.clear()
	for bone_name: StringName in RAPTOR_GROUND_BONES:
		var bone_index := skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			raptor_ground_bone_indices.append(bone_index)


func _configure_dinosaur_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
	if not dinosaur_meshes.has(mesh_instance):
		dinosaur_meshes.append(mesh_instance)
	mesh_instance.visible = true
	mesh_instance.transparency = 0.0
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The raptor has valid animated bounds and can use normal occlusion. The Unity
	# T-Rex needs its custom skinned bounds workaround and therefore keeps the
	# explicit occlusion opt-out until a clean re-export replaces it.
	mesh_instance.ignore_occlusion_culling = dinosaur_kind == &"trex"
	if dinosaur_kind != &"trex" or mesh_instance.mesh == null:
		return
	# This Unity-authored skin has vertices and inverse bind poses hundreds of
	# source units away from its scene origin. Its normal static AABB can therefore
	# be rejected while the animated surface is actually on screen. A generous
	# custom AABB keeps the one solitary T-Rex renderable in every animation.
	var authored_bounds := mesh_instance.mesh.get_aabb()
	var skin_margin := maxf(authored_bounds.position.length() + authored_bounds.size.length(), 128.0)
	mesh_instance.custom_aabb = authored_bounds.grow(skin_margin)
	mesh_instance.extra_cull_margin = target_height * 4.0


func _visual_world_bounds() -> AABB:
	if dinosaur_kind == &"trex" and skeleton != null:
		var skinned_bounds := _world_skinned_bounds(dinosaur_visual)
		if skinned_bounds.size.length_squared() > 0.0001:
			return skinned_bounds
	return _world_mesh_bounds(dinosaur_visual)


func _world_skinned_bounds(content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null or mesh_instance.skin == null:
			continue
		var target_skeleton := mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D
		if target_skeleton == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty() or weights.is_empty():
				continue
			var influence_count := int(bones.size() / vertices.size())
			for vertex_index: int in range(vertices.size()):
				var skinned_point := Vector3.ZERO
				var total_weight := 0.0
				for influence_index: int in range(influence_count):
					var array_index := vertex_index * influence_count + influence_index
					var weight := weights[array_index]
					if weight <= 0.00001:
						continue
					var bind_index := bones[array_index]
					if bind_index < 0 or bind_index >= mesh_instance.skin.get_bind_count():
						continue
					var bone_index := mesh_instance.skin.get_bind_bone(bind_index)
					if bone_index < 0 and mesh_instance.skin.get_bind_name(bind_index) != StringName():
						bone_index = target_skeleton.find_bone(String(mesh_instance.skin.get_bind_name(bind_index)))
					if bone_index < 0:
						continue
					var skin_transform := target_skeleton.get_bone_global_pose(bone_index) * mesh_instance.skin.get_bind_pose(bind_index)
					skinned_point += (skin_transform * vertices[vertex_index]) * weight
					total_weight += weight
				if total_weight <= 0.00001:
					continue
				var world_point := mesh_instance.to_global(skinned_point / total_weight)
				bounds = AABB(world_point, Vector3.ZERO) if not initialized else bounds.expand(world_point)
				initialized = true
	return bounds


func _world_mesh_bounds(content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		for endpoint: int in range(8):
			var world_point := mesh_instance.to_global(mesh_bounds.get_endpoint(endpoint))
			bounds = AABB(world_point, Vector3.ZERO) if not initialized else bounds.expand(world_point)
			initialized = true
	return bounds
