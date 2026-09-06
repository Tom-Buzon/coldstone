extends CharacterBody3D
class_name HopliteAthenianEnemy

const UAL1_PATH := "res://assets/runtime/ual1/UAL1_Standard.glb"
const DriverScript = preload("res://scripts/animation/native_animation_driver.gd")
const SharedHopliteDriverScript = preload("res://scripts/animation/shared_hoplite_animation_driver.gd")
const AnimationRuntimeContract = preload("res://scripts/animation/enemy_animation_runtime_contract.gd")
const AnatomyScript = preload("res://scripts/enemy/anatomy_hitbox.gd")
const ShieldHitboxScript = preload("res://scripts/enemy/shield_hitbox.gd")
const AnatomyProfileScript = preload("res://scripts/enemy/anatomy_profile.gd")
const EnemyArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const MixamoCatalogScript = preload("res://scripts/enemy/mixamo_catalog.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")
const DetachedLimbScript = preload("res://scripts/gore/detached_limb_proxy.gd")
const SpartanDetachedLimbScript = preload("res://scripts/gore/spartan_detached_limb.gd")
const GoreDirectorScript = preload("res://scripts/gore/gore_director.gd")
const SpartanPackageScript = preload("res://scripts/enemy/spartan_character_package.gd")
const AuthoredPoseBridgeScript = preload("res://scripts/animation/authored_pose_bridge.gd")
const BloodBurstScript = preload("res://scripts/gore/blood_burst.gd")
const EnemyProjectileScript = preload("res://scripts/combat/enemy_projectile.gd")
const DebrisLifecycleScript = preload("res://scripts/gore/transient_rigid_debris_lifecycle.gd")
const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const EnemyNavigationComponentScript = preload("res://scripts/ai/enemy_navigation_component.gd")
const DORY_SPEAR_SCENE := preload("res://assets/weapons/dory_spear.glb")
const ASPIS_SHIELD_SCENE := preload("res://assets/weapons/aspis_shield.glb")

const IMPORTED_PHALANX_GEAR_ARCHETYPES: Array[StringName] = [
	&"spearman",
	&"ngeneral",
	&"ngeneral_veteran",
]

const RANGED_HEIGHT_SCAN_RADII: Array[float] = [2.8, 5.2]
const RANGED_HEIGHT_SCAN_DIRECTIONS := 8
const RANGED_MIN_USEFUL_HEIGHT := 0.48
const RANGED_MAX_CLIMB_HEIGHT := 2.75
const RANGED_MAX_PATH_RISE := 0.42
const RANGED_MAX_PRESERVED_DROP := 0.22
const RANGED_MAX_NORMAL_STEP_DOWN := 0.58
const RANGED_EDGE_LOOKAHEAD_MIN := 0.72
const RANGED_EDGE_LOOKAHEAD_MAX := 1.18
const MATCHED_WALKABLE_SURFACE_LAYER := 128
const GIANT_TRAVERSAL_SURFACE_LAYER := 256

static var _reported_character_packages: Dictionary = {}
static var _skin_material_cache: Dictionary = {}
static var _weapon_material_cache: Dictionary = {}
static var _lod_settings_refresh_deadline_msec: int = 0
static var _lod_settings_cache: Dictionary = {
	"enabled": true,
	"near_distance": 16.0,
	"far_distance": 38.0,
	"cull_distance": 90.0,
	"full_rate_distance": 3.8,
	"near_physics_divisor": 2,
	"medium_physics_divisor": 3,
	"far_physics_divisor": 5,
	"medium_animation_hz": 30.0,
	"far_animation_hz": 12.0,
	"shadow_distance": 8.0,
}

signal died(enemy: Node)
signal zone_severed(enemy: Node, zone: StringName)
signal localized_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float)
signal attack_started(enemy: Node, weapon_kind: StringName)
signal combat_phase_changed(enemy: Node, phase: int)

var max_health: float = 180.0
var health: float = 180.0
var dead: bool = false
var last_hit_zone: StringName = StringName()
var last_hit_damage: float = 0.0
var last_hit_sever: float = 0.0

var visual_root: Node3D
var mannequin_scene: Node
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var anatomy: HopliteAnatomyHitbox
var anatomy_defs: Dictionary = {}
var zone_state: Dictionary = {}
var hidden_bones: Dictionary = {}
var hidden_bones_dirty: bool = false

var right_hand_bone: String = ""
var left_hand_bone: String = ""
var sword_attachment: BoneAttachment3D
var shield_attachment: BoneAttachment3D
# Kept as sword_root/sword_dropped for compatibility with the existing lab code,
# but these now represent ANY right-hand weapon (sword, spear or axe).
var sword_root: Node3D
var shield_root: Node3D
var shield_rest_transform: Transform3D = Transform3D.IDENTITY
var shield_guard_root_anchored: bool = false
var shield_hitbox: HopliteShieldHitbox
var sword_dropped: bool = false
var shield_dropped: bool = false
var authored_weapon_visual: Node3D
var authored_shield_visual: Node3D

# V0.0.10 archetype data. One shared enemy controller handles every humanoid
# archetype; profiles only tune visuals, equipment, stats and tactical spacing.
var archetype_id: StringName = &"swordsman"
var archetype_name: String = "SWORDSMAN"
var skin_id: StringName = &"swordsman"
var faction: StringName = &"athenian"
var behavior_mode: StringName = &"aggressive"
var attack_style: StringName = &"light_mix"
var weapon_kind: StringName = &"sword"
var weapon_scale_factor: float = 1.0
var shield_enabled: bool = true
var shield_scale_factor: float = 1.0
var body_scale_factor: float = 1.0
# Uniform scale supplied by level/procedural tools. It must be known before
# _ready() builds the collider, anatomy and visual grounding runtime.
var external_scale_multiplier: float = 1.0
# Forge-only opt-in. Two lightweight horizontal physics surfaces follow the
# animated upper body so giant shoulders/head can behave like real ground.
var match_perfect_hitbox: bool = false
var giant_traversal_mode: StringName = &"auto"
var giant_capsule_radius_multiplier: float = -1.0
var giant_capsule_height_multiplier: float = -1.0
var giant_walkable_tops: bool = true
var matched_physical_colliders: Dictionary = {}
var matched_walkable_surfaces: Array[AnimatableBody3D] = []
var giant_traversal_body: AnimatableBody3D
var giant_traversal_collision: CollisionShape3D
var giant_traversal_head_body: AnimatableBody3D
var giant_traversal_head_collision: CollisionShape3D
var preferred_range_min: float = 0.0
var preferred_range_max: float = 1.65
var flank_distance: float = 0.0
var tactical_radius: float = 0.0
var separation_weight: float = 1.0
var approach_speed_multiplier: float = 1.0
var combat_rank: StringName = &"troop"
var attack_delivery: StringName = &"melee"
var projectile_kind: StringName = &"arrow"
var projectile_speed: float = 20.0
var projectile_gravity: float = 5.0
var projectile_spread: float = 0.02
var signature_source: StringName = StringName()
var signature_animations: Array = []
var signature_chance: float = 0.0

# Phalanx data is intentionally carried by the shared controller: the crowd
# director assigns slots, while each soldier owns only his current tactical state.
var formation_columns: int = 5
var formation_spacing: float = 1.08
var formation_rank_spacing: float = 1.18
var formation_move_speed_multiplier: float = 1.30
var formation_pursuit_limit: float = 7.5
var formation_role: StringName = &"none"
var formation_state: StringName = &"none"
var formation_slot: int = -1
var formation_row: int = -1
var formation_column: int = 0
var formation_facing: Vector3 = Vector3.FORWARD
var formation_unit_count: int = 0
var formation_nearby_allies: int = 0
var formation_nearby_veterans: int = 0
var formation_veteran_count: int = 0
var formation_reorganize_timer: float = 0.0
var formation_guard_active: bool = false
var formation_guard_pose_applied: bool = false
var formation_cohort_formed: bool = false
var formation_cohort_revision: int = 0
var formation_turn_speed: float = deg_to_rad(30.0)
var cohesion_radius: float = 4.4
var cohesion_guard_bonus: float = 0.0

# Defense remains deliberately small and data driven: shields/parries have an
# active frontal window, armor is passive, and light ranged units can evade.
var defense_mode: StringName = &"none"
var defense_chance: float = 0.0
var defense_duration: float = 0.55
var defense_cooldown: float = 1.5
var defense_damage_multiplier: float = 0.25
var defense_sever_multiplier: float = 0.15
var armor_damage_multiplier: float = 1.0
var armor_sever_multiplier: float = 1.0
var poise: float = 0.0
var defense_timer: float = 0.0
var defense_cooldown_timer: float = 0.0
var defense_reaction_timer: float = -1.0
var proactive_defense_requires_attack: bool = false
var defense_reaction_delay: float = 0.13
var defense_reaction_range: float = 3.60
var guard_max: float = 0.0
var guard_stamina: float = 0.0
var guard_regen: float = 0.0
var guard_regen_delay: float = 1.30
var guard_regen_timer: float = 0.0
var guard_break_timer: float = 0.0
var parry_counter_queued: bool = false
var phase_threshold: float = 0.0
var phase_speed_multiplier: float = 1.0
var phase_damage_multiplier: float = 1.0
var phase_three_threshold: float = 0.0
var phase_three_speed_multiplier: float = 1.0
var phase_three_damage_multiplier: float = 1.0
var phase_three_armor_damage_multiplier: float = 0.0
var combat_phase: int = 1
var combat_pattern: Array = []
var phase_two_pattern: Array = []
var phase_three_pattern: Array = []
var external_animation_keys: Array = []
var combat_pattern_cursor: int = 0
var active_attack_step: Dictionary = {}
var forced_attack_step: Dictionary = {}
var active_attack_slot: StringName = StringName()
var active_attack_windup_total: float = 0.0
var perfect_timing_indicator: MeshInstance3D
var perfect_timing_material: StandardMaterial3D

var body_material: StandardMaterial3D
var base_color: Color = Color(0.025, 0.18, 0.72)
var flash_tween: Tween
var status_label: Label3D
var combat_debug_visible: bool = false
var body_collider: CollisionShape3D
var death_collapse_tween: Tween
var corpse_fallback_rest_height: float = 0.40
var corpse_lifetime: float = 12.0
var miniboss_scale_factor: float = 1.20

# V0.0.5 AI. Static anatomy-test mannequins leave ai_enabled=false, so only the
# dedicated AI group pays for UAL2 donor/retargeting and steering.
var ai_enabled: bool = false
var is_miniboss: bool = false
var ai_player: Node3D
# Stable human-player reference. ai_player remains the immediate combat target so
# the existing movement code can also drive soldier-versus-soldier encounters.
var battle_player: Node3D
var claimed_ai_target: Node3D
var retaliation_target: Node3D
var retaliation_timer: float = 0.0
var ai_retaliation_duration: float = 3.6
var crowd_director: Node
var combatant_registry: Node
var ai_miniboss: Node3D
var ai_guard_index: int = 0
var ai_home_position: Vector3 = Vector3.ZERO
var ai_state: StringName = &"idle"
var ai_move_speed: float = 4.8
var ai_limp_speed: float = 1.85
var ai_crawl_speed: float = 0.72
var injury_state: StringName = &"healthy"
var ai_acceleration: float = 18.0
var ai_turn_response: float = 12.0
var ai_aggro_distance: float = 20.0
var ai_defend_radius: float = 8.0
var ai_boss_threat_radius: float = 7.0
var ai_guard_radius: float = 2.65
var ai_attack_range: float = 1.72
var ai_attack_damage: float = 14.0
var ai_attack_cooldown_min: float = 0.86
var ai_attack_cooldown_max: float = 1.12
var ai_attack_windup: float = 0.24
var ai_attack_recovery: float = 0.25
var ai_attack_anim_speed: float = 1.16
var ai_attack_cooldown_timer: float = 0.0
var ai_attack_pending: bool = false
var attack_outline_active: bool = false
var ai_attack_windup_timer: float = 0.0
var ai_attack_recovery_timer: float = 0.0
var ai_alert_timer: float = 0.0
var ai_animation_driver = null
var navigation_component: RefCounted
var navigation_mode_override: int = -1
var navigation_layers: int = 1

# Battle scenes can mark large fodder packs as mass_battle_mode. They keep the
# same anatomy/gore/AI but use only the imported UAL1 AnimationPlayer instead of
# instancing the heavier UAL2 donor/retarget stack on every single soldier.
var mass_battle_mode: bool = false
var simple_anim_lock_timer: float = 0.0
var simple_anim_state: StringName = StringName()

# V0.0.12 crowd-performance budget. Movement still integrates every physics frame,
# but expensive tactical decisions/separation are cached and refreshed at a lower
# frequency for large packs. Anatomy gets distance-based bone-tracking LOD too.
var ai_think_timer: float = 0.0
var cached_ai_goal: Dictionary = {}
var cached_ai_separation: Vector3 = Vector3.ZERO
var separation_candidates: Array[Node] = []
var cached_player_distance: float = INF
var performance_lod_timer: float = 0.0
var render_lod_level: int = -1
var secondary_hoplite_shadows_enabled: bool = true
var lod_animation_accumulator: float = 0.0
var direct_animation_sample_count: int = 0
var physics_full_step_count: int = 0
var physics_deferred_step_count: int = 0
var ai_goal_evaluation_count: int = 0
var physics_lod_accumulator: float = 0.0
var physics_lod_phase: int = 0
var lod_geometry_defaults: Dictionary = {}
var lod_particle_defaults: Dictionary = {}
var uses_mixamo_visual: bool = false
var mixamo_model_id: StringName = StringName()
var mixamo_model_override: StringName = StringName()
var mixamo_clips: Dictionary = {}
var mixamo_attack_cursor: int = 0
var mixamo_reaction_cooldown: float = 0.0
var visual_ground_offset: float = 0.0
var character_package_path: String = ""
var uses_spartan_package_visual: bool = false
var spartan_package_scene: PackedScene
var spartan_package_adapter = null
var gore_director: Node
var spartan_animation_donor: Node3D
var spartan_pose_bridge: HopliteAuthoredPoseBridge
var spartan_grounding_frames: int = -1
var spartan_corpse_grounding_timer: float = -1.0
var spartan_corpse_grounding_tick: float = 0.0
var attack_permission_claimed: bool = false
var attack_permission_waiting: bool = false
var attack_permission_target: Node3D
var attack_permission_token: int = 0
var coward_retreat_timer: float = 0.0
var ranged_retreat_delay_timer: float = 0.0
var ranged_close_contact := false
var ranged_retreat_delay: float = 0.82
var ranged_height_preference: float = 0.0
var ranged_height_scan_timer: float = 0.0
var ranged_height_target: Vector3 = Vector3.ZERO
var ranged_height_target_valid := false
var ranged_ground_cache_initialized: bool = false
var ranged_ground_cache_position: Vector3 = Vector3.ZERO
var ranged_ground_cache_result: Dictionary = {}
var ranged_ground_cache_deadline_msec: int = 0
var ranged_high_ground_active := false
var ranged_preserved_floor_y: float = -INF
var demo_patrol_enabled: bool = false
var demo_patrol_points: Array[Vector3] = []
var demo_patrol_index: int = 0
var demo_patrol_engage_distance: float = 6.5
var demo_patrol_move_speed: float = 0.0
var demo_patrol_interrupted: bool = false
var training_activation_pending: bool = false
var training_activation_center: Vector3 = Vector3.ZERO
var training_activation_radius: float = 0.0
var training_activation_check_timer: float = 0.0


func _exit_tree() -> void:
	# A living combatant may be removed by encounter/world cleanup without first
	# entering _die(). Release shared tactical ownership before its target remains
	# in the scene with a stale hoplite_ai_claims count.
	_invalidate_crowd_membership()
	_release_attack_permission(true)
	_set_combat_target(null)
	_set_attack_outline_active(false)


func _ready() -> void:
	# Apply the archetype before creating collision, visuals or AI runtime.
	# is_miniboss remains supported for older scene/setup code and maps to captain.
	if is_miniboss and archetype_id == &"swordsman":
		archetype_id = &"captain"
	_apply_archetype_profile()
	if character_package_path.is_empty():
		character_package_path = EnemyArchetypesScript.package_path(archetype_id)
	scale = Vector3.ONE * body_scale_factor * external_scale_multiplier

	collision_layer = 4
	# Enemy/enemy CharacterBody collisions explode in cost in a dense crowd and are
	# redundant with our steering separation. Keep world + player collision only.
	collision_mask = (1 | 2) if ai_enabled else 1
	process_priority = 100
	health = max_health
	ai_home_position = global_position
	ai_attack_cooldown_timer = randf_range(0.15, 0.55) if ai_enabled else 0.0
	ai_think_timer = randf_range(0.0, 0.12) if ai_enabled else 0.0
	performance_lod_timer = randf_range(0.0, 0.20) if ai_enabled else 0.0
	_build_body_collider()
	_load_mannequin()
	_build_matched_physical_colliders()
	_build_matched_walkable_surfaces()
	if ai_enabled:
		_build_navigation_component()
	if battle_player == null and ai_player != null:
		battle_player = ai_player
	if faction == &"spartan":
		add_to_group("ally")
		add_to_group("spartan_ally")
	else:
		add_to_group("enemy")
		add_to_group("athenian")
	add_to_group("damageable")
	add_to_group("combatant")
	if ai_enabled:
		set_physics_process(true)
		add_to_group("combatant_ai")
		add_to_group("ally_ai" if faction == &"spartan" else "enemy_ai")
		if _is_phalanx_unit():
			add_to_group("phalanx_unit")
	else:
		set_physics_process(false)
	if is_miniboss and faction != &"spartan":
		add_to_group("enemy_miniboss")
	if combat_rank in [&"elite", &"miniboss", &"boss"] and faction != &"spartan":
		add_to_group("enemy_epic")
	_connect_threat_awareness()
	_invalidate_crowd_membership()

func _invalidate_crowd_membership() -> void:
	if crowd_director == null or not is_instance_valid(crowd_director):
		crowd_director = get_tree().get_first_node_in_group("crowd_director") if get_tree() != null else null
	if crowd_director != null and crowd_director.has_method("invalidate_spatial_grid"):
		crowd_director.call("invalidate_spatial_grid")

func _apply_archetype_profile() -> void:
	var profile: Dictionary = EnemyArchetypesScript.profile(archetype_id)
	archetype_name = String(profile.get("display_name", "SWORDSMAN"))
	base_color = profile.get("color", base_color)
	skin_id = StringName(profile.get("skin", archetype_id))
	body_scale_factor = float(profile.get("scale", 1.0))
	max_health = float(profile.get("health", max_health))
	ai_move_speed = float(profile.get("move_speed", ai_move_speed))
	ai_attack_damage = float(profile.get("attack_damage", ai_attack_damage))
	ai_attack_range = float(profile.get("attack_range", ai_attack_range))
	ai_aggro_distance = float(profile.get("aggro_distance", ai_aggro_distance))
	weapon_kind = StringName(profile.get("weapon", &"sword"))
	weapon_scale_factor = float(profile.get("weapon_scale", 1.0))
	shield_enabled = bool(profile.get("shield", true))
	shield_scale_factor = float(profile.get("shield_scale", 1.0))
	behavior_mode = StringName(profile.get("behavior", &"aggressive"))
	attack_style = StringName(profile.get("attack_style", &"light_mix"))
	ai_attack_windup = float(profile.get("windup", ai_attack_windup))
	ai_attack_recovery = float(profile.get("recovery", ai_attack_recovery))
	ai_attack_cooldown_min = float(profile.get("cooldown_min", ai_attack_cooldown_min))
	ai_attack_cooldown_max = float(profile.get("cooldown_max", ai_attack_cooldown_max))
	ai_attack_anim_speed = float(profile.get("attack_anim_speed", ai_attack_anim_speed))
	preferred_range_min = float(profile.get("preferred_min", preferred_range_min))
	preferred_range_max = float(profile.get("preferred_max", preferred_range_max))
	flank_distance = float(profile.get("flank_distance", flank_distance))
	tactical_radius = float(profile.get("tactical_radius", 0.0))
	separation_weight = float(profile.get("separation_weight", 1.0))
	approach_speed_multiplier = float(profile.get("approach_speed_multiplier", 1.0))
	ranged_retreat_delay = float(profile.get("ranged_retreat_delay", ranged_retreat_delay))
	ranged_height_preference = float(profile.get("height_preference", 0.0))
	combat_rank = StringName(profile.get("rank", &"troop"))
	is_miniboss = is_miniboss or combat_rank == &"miniboss" or combat_rank == &"boss"
	attack_delivery = StringName(profile.get("attack_delivery", &"melee"))
	projectile_kind = StringName(profile.get("projectile_kind", &"arrow"))
	projectile_speed = float(profile.get("projectile_speed", projectile_speed))
	projectile_gravity = float(profile.get("projectile_gravity", projectile_gravity))
	projectile_spread = float(profile.get("projectile_spread", projectile_spread))
	signature_source = StringName(profile.get("signature_source", StringName()))
	signature_animations = Array(profile.get("signature_animations", []))
	signature_chance = float(profile.get("signature_chance", 0.0))
	formation_columns = int(profile.get("formation_columns", formation_columns))
	formation_spacing = float(profile.get("formation_spacing", formation_spacing))
	formation_rank_spacing = float(profile.get("formation_rank_spacing", formation_rank_spacing))
	formation_pursuit_limit = float(profile.get("formation_pursuit_limit", formation_pursuit_limit))
	formation_role = StringName(profile.get("formation_role", &"none"))
	formation_turn_speed = float(profile.get("formation_turn_speed", formation_turn_speed))
	cohesion_radius = float(profile.get("cohesion_radius", cohesion_radius))
	cohesion_guard_bonus = float(profile.get("cohesion_guard_bonus", 0.0))
	defense_mode = StringName(profile.get("defense", &"none"))
	defense_chance = float(profile.get("defense_chance", 0.0))
	defense_duration = float(profile.get("defense_duration", defense_duration))
	defense_cooldown = float(profile.get("defense_cooldown", defense_cooldown))
	defense_damage_multiplier = float(profile.get("defense_damage_multiplier", defense_damage_multiplier))
	defense_sever_multiplier = float(profile.get("defense_sever_multiplier", defense_sever_multiplier))
	armor_damage_multiplier = float(profile.get("armor_damage_multiplier", 1.0))
	armor_sever_multiplier = float(profile.get("armor_sever_multiplier", 1.0))
	poise = float(profile.get("poise", 0.0))
	defense_reaction_delay = float(profile.get("defense_reaction_delay", defense_reaction_delay))
	defense_reaction_range = float(profile.get("defense_reaction_range", defense_reaction_range))
	guard_max = float(profile.get("guard_max", 0.0))
	guard_stamina = guard_max
	guard_regen = float(profile.get("guard_regen", 0.0))
	guard_regen_delay = float(profile.get("guard_regen_delay", guard_regen_delay))
	phase_threshold = float(profile.get("phase_threshold", 0.0))
	phase_speed_multiplier = float(profile.get("phase_speed_multiplier", 1.0))
	phase_damage_multiplier = float(profile.get("phase_damage_multiplier", 1.0))
	phase_three_threshold = float(profile.get("phase_three_threshold", 0.0))
	phase_three_speed_multiplier = float(profile.get("phase_three_speed_multiplier", 1.0))
	phase_three_damage_multiplier = float(profile.get("phase_three_damage_multiplier", 1.0))
	phase_three_armor_damage_multiplier = float(profile.get("phase_three_armor_damage_multiplier", 0.0))
	combat_pattern = Array(profile.get("combat_pattern", []))
	phase_two_pattern = Array(profile.get("phase_two_pattern", []))
	phase_three_pattern = Array(profile.get("phase_three_pattern", []))
	external_animation_keys = Array(profile.get("external_animation_keys", []))
	if giant_traversal_mode == &"auto":
		giant_traversal_mode = StringName(profile.get("giant_traversal_mode", &"assisted"))
	if giant_capsule_radius_multiplier <= 0.0:
		giant_capsule_radius_multiplier = float(profile.get("giant_capsule_radius_multiplier", 0.90))
	if giant_capsule_height_multiplier <= 0.0:
		giant_capsule_height_multiplier = float(profile.get("giant_capsule_height_multiplier", 1.0))
	giant_walkable_tops = giant_walkable_tops and bool(profile.get("giant_walkable_tops", true))
	if faction == &"spartan":
		archetype_name = "SPARTAN " + archetype_name
		base_color = Color(0.62, 0.025, 0.018)
		skin_id = &"spartan"
		ai_aggro_distance = maxf(ai_aggro_distance, 34.0)

func _process(delta: float) -> void:
	_set_attack_outline_active(ai_attack_pending and not dead)
	var training_dormant := _update_training_activation(delta)
	if training_dormant and spartan_grounding_frames < 0:
		return
	_update_perfect_timing_indicator()
	simple_anim_lock_timer = maxf(0.0, simple_anim_lock_timer - delta)
	mixamo_reaction_cooldown = maxf(0.0, mixamo_reaction_cooldown - delta)
	var pose_stride := 1 if render_lod_level <= 0 else (2 if render_lod_level == 1 else 4)
	var update_pose_bridge := render_lod_level < 3 and (Engine.get_process_frames() + get_instance_id()) % pose_stride == 0
	var skeleton_sampled := false
	if uses_spartan_package_visual and spartan_pose_bridge != null and skeleton != null and update_pose_bridge:
		# SkeletonModifier3D normally evaluates during skeleton/render updates.
		# Apply once here too so physics grounding and anatomy see the same pose
		# during their first frames (headless tests do not run a render update).
		spartan_pose_bridge.call("_process_modification_with_delta", delta)
		skeleton.force_update_all_bone_transforms()
		skeleton_sampled = true
	if dead and uses_spartan_package_visual and spartan_corpse_grounding_timer >= 0.0:
		spartan_corpse_grounding_timer -= delta
		spartan_corpse_grounding_tick -= delta
		if spartan_corpse_grounding_tick <= 0.0:
			spartan_corpse_grounding_tick = 0.055
			_ground_spartan_corpse_visual()
		if spartan_corpse_grounding_timer <= 0.0:
			spartan_corpse_grounding_timer = -1.0
			_ground_spartan_corpse_visual()
			_retire_corpse_runtime()
	_update_injury_visual(delta)

	if ai_enabled and not dead:
		performance_lod_timer -= delta
		if performance_lod_timer <= 0.0:
			_update_performance_lod()
			performance_lod_timer = 0.20 if mass_battle_mode else 0.14

	if ai_enabled and not dead and (ai_animation_driver != null or _direct_animation_uses_manual_sampling()):
		lod_animation_accumulator += delta
		var lod_settings := _runtime_lod_settings()
		var animation_interval := 0.0
		if render_lod_level == 1:
			animation_interval = 1.0 / maxf(1.0, float(lod_settings["medium_animation_hz"]))
		elif render_lod_level == 2:
			animation_interval = 1.0 / maxf(1.0, float(lod_settings["far_animation_hz"]))
		elif render_lod_level >= 3:
			animation_interval = INF
		if animation_interval == 0.0 or lod_animation_accumulator + 0.000001 >= animation_interval:
			var sample_delta := lod_animation_accumulator
			var remainder := 0.0
			if animation_interval > 0.0 and animation_interval < INF and lod_animation_accumulator >= animation_interval:
				remainder = fmod(lod_animation_accumulator, animation_interval)
				sample_delta = lod_animation_accumulator - remainder
			if ai_animation_driver != null:
				ai_animation_driver.tick(sample_delta)
			elif animation_player != null:
				animation_player.advance(sample_delta)
				direct_animation_sample_count += 1
			skeleton_sampled = true
			lod_animation_accumulator = remainder
	if _is_phalanx_unit() and not dead and update_pose_bridge:
		_update_phalanx_equipment_pose()
	if skeleton != null and not hidden_bones.is_empty() and (hidden_bones_dirty or skeleton_sampled):
		# Prototype visual severing for the single-piece UAL1 mesh. A future gore
		# mesh can replace this without touching AnatomyHitbox / HitEvent.
		for raw_index: Variant in hidden_bones:
			var bone_index: int = int(raw_index)
			if bone_index >= 0 and bone_index < skeleton.get_bone_count():
				skeleton.set_bone_pose_scale(bone_index, Vector3(0.001, 0.001, 0.001))
		hidden_bones_dirty = false

	# String formatting + Label3D updates are pointless while diagnostics are hidden.
	if combat_debug_visible:
		_update_status_label()

func _physics_process(delta: float) -> void:
	if _defer_mass_battle_physics_step(delta):
		return
	delta += physics_lod_accumulator
	physics_lod_accumulator = 0.0
	physics_full_step_count += 1
	_update_matched_physical_colliders()
	_update_assisted_giant_traversal_collider()
	_update_matched_walkable_surfaces()
	if uses_spartan_package_visual and spartan_grounding_frames >= 0:
		spartan_grounding_frames -= 1
		if spartan_grounding_frames <= 0:
			spartan_grounding_frames = -1
			_ground_spartan_package_visual()
	if training_activation_pending:
		velocity = Vector3.ZERO
		return
	if not ai_enabled or dead:
		return
	if navigation_component == null:
		_build_navigation_component()

	ai_attack_cooldown_timer = maxf(0.0, ai_attack_cooldown_timer - delta)
	ai_attack_recovery_timer = maxf(0.0, ai_attack_recovery_timer - delta)
	ai_alert_timer = maxf(0.0, ai_alert_timer - delta)
	retaliation_timer = maxf(0.0, retaliation_timer - delta)
	coward_retreat_timer = maxf(0.0, coward_retreat_timer - delta)
	ranged_retreat_delay_timer = maxf(0.0, ranged_retreat_delay_timer - delta)
	ranged_height_scan_timer = maxf(0.0, ranged_height_scan_timer - delta)
	formation_reorganize_timer = maxf(0.0, formation_reorganize_timer - delta)
	_update_defense(delta)
	if retaliation_timer <= 0.0:
		retaliation_target = null
	if attack_permission_claimed and not ai_attack_pending and ai_attack_recovery_timer <= 0.0:
		_release_attack_permission()

	if ai_attack_pending and not _can_ai_attack():
		ai_attack_pending = false
		ai_attack_windup_timer = 0.0
		ai_attack_recovery_timer = 0.15
		_release_attack_permission()

	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if guard_break_timer > 0.0:
		_apply_attack_spacing(delta)
		_move_and_slide_with_ranged_height_guard()
		_ai_update_animation_speed()
		return

	if ai_attack_recovery_timer > 0.0 and not ai_attack_pending:
		_apply_attack_spacing(delta)
		if ai_player != null and is_instance_valid(ai_player):
			_ai_face_direction(ai_player.global_position - global_position, delta)
		_move_and_slide_with_ranged_height_guard()
		_ai_update_animation_speed()
		return

	if ai_attack_pending:
		_apply_pending_attack_motion(delta)
		if ai_player != null and is_instance_valid(ai_player):
			_ai_face_direction(ai_player.global_position - global_position, delta)
		ai_attack_windup_timer -= delta
		if ai_attack_windup_timer <= 0.0:
			_resolve_ai_attack()
		_move_and_slide_with_ranged_height_guard()
		_ai_update_animation_speed()
		return

	if parry_counter_queued and defense_timer <= 0.0 and guard_break_timer <= 0.0:
		parry_counter_queued = false
		if ai_player != null and is_instance_valid(ai_player) and _flat_distance_to(ai_player) <= ai_attack_range + 0.65 and _can_ai_attack():
			forced_attack_step = {
				"id": &"parry_counter",
				"slot": &"light2",
				"external": &"light2",
				"windup": 0.12,
				"recovery": 0.24,
				"cooldown": 0.62,
				"damage_mult": 1.08,
				"range_mult": 1.08,
				"lunge_speed": 4.8
			}
			ai_attack_cooldown_timer = 0.0
			_begin_ai_attack()
			_move_and_slide_with_ranged_height_guard()
			_ai_update_animation_speed()
			return

	ai_think_timer -= delta
	if ai_think_timer <= 0.0 or cached_ai_goal.is_empty():
		ai_goal_evaluation_count += 1
		cached_ai_goal = _ai_goal()
		# The distant autonomous fronts need separation just as much as combat
		# near the camera. The spatial grid keeps this query inexpensive.
		cached_ai_separation = _ai_separation_vector()
		ai_think_timer = _current_ai_think_interval()

	var goal: Dictionary = cached_ai_goal
	var active: bool = bool(goal.get("active", false))
	var attack_player: bool = bool(goal.get("attack_player", false))
	var face_target: bool = bool(goal.get("face_target", attack_player))
	var target: Vector3 = goal.get("target", global_position)
	if not attack_player and attack_permission_waiting:
		_cancel_pending_attack_request()

	if attack_player and ai_player != null and is_instance_valid(ai_player):
		var player_flat: Vector3 = ai_player.global_position - global_position
		player_flat.y = 0.0
		if _can_start_attack_at_distance(player_flat.length()) and ai_attack_cooldown_timer <= 0.0 and _can_ai_attack():
			_begin_ai_attack()
			_move_and_slide_with_ranged_height_guard()
			_ai_update_animation_speed()
			return

	var flat_to_goal: Vector3 = target - global_position
	flat_to_goal.y = 0.0
	var desired_velocity: Vector3 = Vector3.ZERO
	var applied_navigation_direction: Vector3 = Vector3.ZERO

	if active:
		var direction: Vector3 = flat_to_goal.normalized() if flat_to_goal.length_squared() > 0.0001 else Vector3.ZERO
		var navigation_speed_scale := 1.0
		var navigation_facing := Vector3.ZERO
		var navigation_holds_position := false
		if navigation_component != null:
			if _is_phalanx_unit():
				navigation_component.set_formation_anchor(target, formation_facing, formation_slot, formation_cohort_revision)
			else:
				navigation_component.set_destination(target)
			var navigation_intent: Variant = navigation_component.sample_intent(delta)
			if navigation_intent != null and bool(navigation_intent.valid):
				direction = navigation_intent.direction
				navigation_speed_scale = float(navigation_intent.speed_scale)
				navigation_facing = navigation_intent.facing_direction
			else:
				direction = Vector3.ZERO
				navigation_holds_position = true
		if not navigation_holds_position and cached_ai_separation.length() > 0.001:
			direction = (direction + cached_ai_separation * 1.35 * separation_weight).normalized()
		if direction.length_squared() > 0.0001:
			var guard_move_scale: float = 0.42 if defense_timer > 0.0 else 1.0
			var goal_move_speed := float(goal.get("move_speed", 0.0))
			var resolved_move_speed := goal_move_speed if goal_move_speed > 0.0 else _current_ai_move_speed() * approach_speed_multiplier
			if _is_phalanx_unit():
				resolved_move_speed *= formation_move_speed_multiplier
			desired_velocity = direction * resolved_move_speed * guard_move_scale * navigation_speed_scale
			applied_navigation_direction = direction
			var facing_direction := navigation_facing if navigation_facing.length_squared() > 0.001 else _combat_facing_direction(direction, face_target)
			_ai_face_direction(facing_direction, delta)
		elif face_target and ai_player != null and is_instance_valid(ai_player):
			_ai_face_direction(ai_player.global_position - global_position, delta)
	elif cached_ai_separation.length() > 0.001:
		if navigation_component != null:
			navigation_component.clear_destination()
		# A soldier who reached his assigned slot must still yield personal space;
		# otherwise stationary rings slowly collapse back into a single point.
		var separation_strength: float = clampf(cached_ai_separation.length(), 0.22, 0.70)
		desired_velocity = cached_ai_separation.normalized() * _current_ai_move_speed() * separation_strength * separation_weight
		_ai_face_direction(_combat_facing_direction(desired_velocity, face_target), delta)
	elif face_target and ai_player != null and is_instance_valid(ai_player):
		if navigation_component != null:
			navigation_component.clear_destination()
		_ai_face_direction(ai_player.global_position - global_position, delta)
	elif navigation_component != null:
		navigation_component.clear_destination()

	velocity.x = move_toward(velocity.x, desired_velocity.x, ai_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, ai_acceleration * delta)
	var navigation_previous_position := global_position
	_move_and_slide_with_ranged_height_guard()
	if navigation_component != null:
		navigation_component.notify_motion_applied(navigation_previous_position, global_position, delta, applied_navigation_direction)
	_ai_update_animation_speed()

func _build_navigation_component() -> void:
	if navigation_component != null:
		return
	navigation_component = EnemyNavigationComponentScript.new()
	var navigation_mode: int = EnemyNavigationComponentScript.Mode.DIRECT_STEERING
	var is_large_body := body_scale_factor * external_scale_multiplier >= 1.75 or archetype_id in [&"boss_colossus", &"bronze_colossus", &"giant_novice", &"giant_standard", &"giant_veteran"]
	if navigation_mode_override >= 0 and navigation_mode_override < EnemyNavigationComponentScript.Mode.size():
		navigation_mode = navigation_mode_override
	elif is_large_body:
		navigation_mode = EnemyNavigationComponentScript.Mode.LARGE_BODY
	elif _route_has_navigation_regions():
		# Ground units automatically consume a level-owned NavigationRegion3D.
		# Phalanx members still receive their local slot as the destination and
		# retain formation facing while the coarse path goes around obstacles.
		navigation_mode = EnemyNavigationComponentScript.Mode.NAVMESH_GROUND
	elif _is_phalanx_unit():
		navigation_mode = EnemyNavigationComponentScript.Mode.FORMATION_LOCAL
	navigation_component.configure(self, navigation_mode, {
		"arrival_distance": 0.28,
		"arrival_slowdown_distance": 0.55,
		"arrival_min_speed_scale": 0.80,
		"navigation_layers": navigation_layers,
		"formation_facing": _is_phalanx_unit(),
		"fallback_mode": EnemyNavigationComponentScript.Mode.FORMATION_LOCAL if _is_phalanx_unit() else EnemyNavigationComponentScript.Mode.DIRECT_STEERING,
		"minimum_progress_speed": 0.12,
		"stuck_timeout": 0.82 if navigation_mode != EnemyNavigationComponentScript.Mode.LARGE_BODY else 1.15,
		"recovery_duration": 0.48 if navigation_mode != EnemyNavigationComponentScript.Mode.LARGE_BODY else 0.72,
		"recovery_speed_scale": 0.72,
	})

func _route_has_navigation_regions() -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	# A freshly constructed Forge route registers its region node before the
	# NavigationServer uploads the region RID. Consulting the explicit scene group
	# closes that one-frame bootstrap gap without forcing factory-specific modes.
	for candidate: Node in get_tree().get_nodes_in_group("enemy_navigation_region"):
		var region := candidate as NavigationRegion3D
		if region != null and region.enabled and region.navigation_layers & navigation_layers:
			return true
	var map_rid := get_world_3d().navigation_map
	if not map_rid.is_valid():
		return false
	for region_rid: RID in NavigationServer3D.map_get_regions(map_rid):
		if NavigationServer3D.region_get_navigation_layers(region_rid) & navigation_layers:
			return true
	return false

func _ai_goal() -> Dictionary:
	_refresh_combat_target()
	if behavior_mode == &"ranged" and ranged_height_preference > 0.0:
		# Height awareness also runs while allied archers follow the commander;
		# otherwise a quiet formation order could walk them down the very ramp or
		# tower that combat logic would correctly preserve a moment later.
		_refresh_ranged_height_awareness()
	if demo_patrol_enabled and not demo_patrol_points.is_empty():
		var patrol_blocked := _is_active_retaliation_target()
		var commander_distance: float = INF
		if battle_player != null and is_instance_valid(battle_player):
			commander_distance = _flat_distance_to(battle_player)
		patrol_blocked = patrol_blocked or commander_distance <= demo_patrol_engage_distance
		if not patrol_blocked:
			if demo_patrol_interrupted:
				demo_patrol_index = nearest_patrol_index(demo_patrol_points, global_position)
				demo_patrol_interrupted = false
			var patrol_target: Vector3 = demo_patrol_points[demo_patrol_index]
			var patrol_delta: Vector3 = patrol_target - global_position
			patrol_delta.y = 0.0
			if patrol_delta.length() < 0.85:
				demo_patrol_index = (demo_patrol_index + 1) % demo_patrol_points.size()
				patrol_target = demo_patrol_points[demo_patrol_index]
				patrol_delta = patrol_target - global_position
				patrol_delta.y = 0.0
			if _is_phalanx_unit() and patrol_delta.length_squared() > 0.001:
				# Before combat activation the cohort follows its route as an
				# ordered block. Its shields face the direction of travel, never
				# the distant player waiting outside the activation radius.
				formation_facing = patrol_delta.normalized()
				formation_row = ai_guard_index / 5
				formation_column = ai_guard_index % 5 - 2
				formation_state = &"marche"
				formation_cohort_formed = true
				formation_guard_active = shield_enabled and not shield_dropped and guard_stamina > 0.0
			ai_state = &"patrol"
			return {"active": true, "target": patrol_target, "attack_player": false, "move_speed": demo_patrol_move_speed}
		demo_patrol_interrupted = true
	if faction == &"spartan" and battle_player != null and is_instance_valid(battle_player):
		var hostile_distance: float = INF
		if ai_player != null and is_instance_valid(ai_player):
			var hostile_delta: Vector3 = ai_player.global_position - global_position
			hostile_delta.y = 0.0
			hostile_distance = hostile_delta.length()
		# Between enemy waves the army reforms behind the human commander. As
		# soon as a hostile enters aggro range, normal archetype combat takes over.
		if hostile_distance > ai_aggro_distance:
			var formation_row: int = ai_guard_index / 7
			var formation_column: int = ai_guard_index % 7
			var follow_offset := Vector3((float(formation_column) - 3.0) * 1.65, 0.0, 5.5 + float(formation_row) * 2.0)
			var follow_target: Vector3 = battle_player.global_position + follow_offset
			var follow_delta: Vector3 = follow_target - global_position
			follow_delta.y = 0.0
			if behavior_mode == &"ranged":
				follow_target = _ranged_height_biased_target(follow_target, hostile_distance)
				follow_delta = follow_target - global_position
				follow_delta.y = 0.0
			ai_state = &"follow_commander" if follow_delta.length() > 2.2 else &"formation_hold"
			return {"active": follow_delta.length() > 2.2, "target": follow_target, "attack_player": false}
	if ai_player == null or not is_instance_valid(ai_player):
		ai_state = &"idle"
		return {"active": false, "target": global_position, "attack_player": false}

	var to_player: Vector3 = ai_player.global_position - global_position
	to_player.y = 0.0
	var player_distance: float = to_player.length()

	if is_miniboss:
		if player_distance <= ai_aggro_distance or ai_alert_timer > 0.0:
			return _ai_combat_goal(ai_player.global_position, player_distance, &"boss_attack", false)
		ai_state = &"boss_idle"
		return {"active": true, "target": ai_home_position, "attack_player": false}

	# Preserve the established squad rule: any fighter close enough to a living
	# captain protects him first. Archetype behavior only changes HOW it does so.
	var boss_alive: bool = ai_miniboss != null and is_instance_valid(ai_miniboss)
	if boss_alive and ai_miniboss.has_method("is_dead_for_combat"):
		boss_alive = not bool(ai_miniboss.call("is_dead_for_combat"))

	if boss_alive:
		var to_boss: Vector3 = ai_miniboss.global_position - global_position
		to_boss.y = 0.0
		if to_boss.length() <= ai_defend_radius:
			var boss_to_player: Vector3 = ai_player.global_position - ai_miniboss.global_position
			boss_to_player.y = 0.0
			var boss_player_distance: float = boss_to_player.length()
			if boss_player_distance <= ai_boss_threat_radius or ai_alert_timer > 0.0:
				var toward_player: Vector3 = boss_to_player.normalized() if boss_player_distance > 0.01 else -global_basis.z
				var lateral: Vector3 = Vector3(-toward_player.z, 0.0, toward_player.x)
				var lateral_slot: float = (float(ai_guard_index) - 2.0) * 0.42
				var intercept: Vector3 = ai_miniboss.global_position + toward_player * 2.15 + lateral * lateral_slot
				return _ai_combat_goal(intercept, player_distance, &"defend_boss", true)

			var angle: float = (TAU / 5.0) * float(ai_guard_index)
			var guard_offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * ai_guard_radius
			ai_state = &"guard"
			return {"active": true, "target": ai_miniboss.global_position + guard_offset, "attack_player": false}

	if player_distance <= ai_aggro_distance or ai_alert_timer > 0.0:
		return _ai_combat_goal(ai_player.global_position, player_distance, &"attack", false)

	ai_state = &"idle"
	return {"active": true, "target": ai_home_position, "attack_player": false}

func _ai_combat_goal(base_target: Vector3, player_distance: float, state_prefix: StringName, defending_boss: bool) -> Dictionary:
	if ai_player == null or not is_instance_valid(ai_player):
		return {"active": false, "target": global_position, "attack_player": false}
	# Formation actors are coordinated as one cohort footprint. They must never
	# reserve an individual ring slot before switching to their phalanx goal.
	if _is_phalanx_unit():
		if crowd_director == null or not is_instance_valid(crowd_director):
			crowd_director = get_tree().get_first_node_in_group("crowd_director") if get_tree() != null else null
		if crowd_director != null and crowd_director.has_method("release_engagement"):
			crowd_director.call("release_engagement", self, ai_player)
		return _phalanx_combat_goal(player_distance)

	var target: Vector3 = base_target
	var to_player: Vector3 = ai_player.global_position - global_position
	to_player.y = 0.0
	var player_dir: Vector3 = to_player.normalized() if to_player.length() > 0.01 else -global_basis.z
	var engagement_attack_ready := true
	var engagement_role := &"line"

	# Each opponent gets one persistent engagement slot. Eight fighters can form
	# the first ring; any extras wait on progressively wider rings instead of all
	# steering through the target's origin.
	if not defending_boss:
		var approach_radius: float = tactical_radius if tactical_radius > 0.0 else clampf(ai_attack_range * 0.92, 1.55, 2.20)
		if behavior_mode == &"reach":
			approach_radius = tactical_radius if tactical_radius > 0.0 else clampf((preferred_range_min + preferred_range_max) * 0.5, 1.85, 2.45)
		elif behavior_mode == &"ranged":
			approach_radius = tactical_radius if tactical_radius > 0.0 else (preferred_range_min + preferred_range_max) * 0.5
		var engagement := _engagement_assignment(ai_player, approach_radius)
		target = engagement.get("position", target)
		engagement_attack_ready = bool(engagement.get("attack_ready", true))
		engagement_role = StringName(engagement.get("role", &"line"))

	match behavior_mode:
		&"reach":
			# Spearmen work a band instead of hugging the player. Back away when
			# crowded, advance when too far, and attack from the spear's reach.
			if player_distance < preferred_range_min:
				target = global_position - player_dir * 1.35
				ai_state = &"spear_retreat"
			elif player_distance > preferred_range_max:
				ai_state = &"spear_advance"
			else:
				target = global_position
				ai_state = &"spear_hold"
		&"flank":
			if player_distance > ai_attack_range * 0.92:
				target = _orbit_position(ai_player, maxf(flank_distance, 2.10), 0.62)
				ai_state = &"flank"
			else:
				target = global_position
				ai_state = &"flank_attack"
		&"ranged":
			# The archer still gives ground, but the first melee contact pins him for
			# a short punish window. Re-entering the firing band rearms that delay.
			if player_distance < preferred_range_min:
				if not ranged_close_contact:
					ranged_close_contact = true
					ranged_retreat_delay_timer = ranged_retreat_delay
				if ranged_retreat_delay_timer > 0.0:
					target = global_position
					ai_state = &"ranged_cornered"
				else:
					target = global_position - player_dir * 1.25
					ai_state = &"ranged_retreat"
			elif player_distance > preferred_range_max:
				ranged_close_contact = false
				ai_state = &"ranged_advance"
			else:
				if player_distance > preferred_range_min + 1.35:
					ranged_close_contact = false
				target = global_position
				ai_state = &"ranged_aim"
			target = _ranged_height_biased_target(target, player_distance)
		&"coward":
			if coward_retreat_timer > 0.0 or health / maxf(max_health, 1.0) < 0.32:
				target = global_position - player_dir * (2.35 + coward_retreat_timer * 0.22)
				ai_state = &"coward_flee"
				return {"active": true, "target": target, "attack_player": false}
			if player_distance < preferred_range_min:
				target = global_position - player_dir * 1.75
				ai_state = &"coward_retreat"
			elif player_distance > preferred_range_max:
				ai_state = &"coward_advance"
			else:
				target = global_position
				ai_state = &"coward_strike"
		&"duelist":
			if ai_attack_cooldown_timer > 0.16 or player_distance > ai_attack_range * 0.92:
				target = _orbit_position(ai_player, maxf(tactical_radius, 1.95), 1.05)
				ai_state = &"duelist_circle"
			else:
				target = global_position
				ai_state = &"duelist_strike"
		&"guardian":
			# Guardians are the least eager to abandon the captain/intercept line.
			# Outside captain duty they still close normally.
			if defending_boss and player_distance > ai_attack_range + 0.35:
				target = base_target
				ai_state = &"hold_line"
			else:
				ai_state = &"shield_line"
		&"brute":
			ai_state = &"brute_charge" if player_distance > ai_attack_range else &"brute_attack"
		&"commander":
			if player_distance < 1.45:
				target = global_position - player_dir * 0.90
				ai_state = &"commander_reposition"
			else:
				ai_state = &"commander_hold" if defending_boss else &"commander_attack"
		&"juggernaut":
			ai_state = &"juggernaut_advance" if player_distance > ai_attack_range else &"juggernaut_crush"
		&"phase_boss":
			if combat_phase >= 3:
				ai_state = &"boss_phase_three_frenzy"
			elif combat_phase >= 2 and ai_attack_cooldown_timer > 0.12:
				target = _orbit_position(ai_player, maxf(tactical_radius, 2.35), 0.48)
				ai_state = &"boss_phase_two_circle"
			else:
				ai_state = &"boss_phase_%d" % combat_phase
		&"boss":
			ai_state = &"boss_attack"
		_:
			ai_state = state_prefix

	if not engagement_attack_ready and attack_delivery != &"projectile":
		ai_state = StringName("combat_" + String(engagement_role))
	return {
		"active": true,
		"target": target,
		"attack_player": engagement_attack_ready or attack_delivery == &"projectile",
		"face_target": true,
	}

func _is_phalanx_unit() -> bool:
	return behavior_mode == &"phalanx" or behavior_mode == &"phalanx_veteran"

func _uses_imported_phalanx_gear() -> bool:
	return archetype_id in IMPORTED_PHALANX_GEAR_ARCHETYPES

func is_phalanx_unit() -> bool:
	return _is_phalanx_unit()

func crowd_participant_descriptor() -> Dictionary:
	var crowd_role := &"melee"
	if is_miniboss:
		crowd_role = &"boss"
	elif behavior_mode == &"ranged" or attack_delivery == &"projectile":
		crowd_role = &"ranged"
	return {
		"formation_kind": &"phalanx" if _is_phalanx_unit() else &"individual",
		"crowd_role": crowd_role,
		"cohort_id": StringName(get_meta("formation_group", StringName())),
		"combat_rank": combat_rank,
	}

func _phalanx_combat_goal(player_distance: float) -> Dictionary:
	if ai_player == null or not is_instance_valid(ai_player):
		formation_guard_active = false
		formation_state = &"rassemblement"
		return {"active": true, "target": ai_home_position, "attack_player": false}
	if crowd_director == null or not is_instance_valid(crowd_director):
		crowd_director = get_tree().get_first_node_in_group("crowd_director") if get_tree() != null else null
	var assignment: Dictionary = {}
	if crowd_director != null and crowd_director.has_method("phalanx_assignment"):
		assignment = crowd_director.call(
			"phalanx_assignment",
			self,
			ai_player,
			formation_columns,
			formation_spacing,
			formation_rank_spacing,
			tactical_radius
		) as Dictionary
	if assignment.is_empty():
		formation_guard_active = false
		formation_state = &"rassemblement"
		ai_state = &"phalanx_rassemblement"
		return {"active": true, "target": ai_home_position, "attack_player": false}

	var assigned_position: Vector3 = assignment.get("position", global_position)
	formation_columns = int(assignment.get("formation_columns", formation_columns))
	formation_spacing = float(assignment.get("formation_spacing", formation_spacing))
	formation_rank_spacing = float(assignment.get("formation_rank_spacing", formation_rank_spacing))
	formation_move_speed_multiplier = float(assignment.get("move_speed_multiplier", formation_move_speed_multiplier))
	if navigation_component != null and navigation_component.has_method("set_arrival_profile"):
		navigation_component.set_arrival_profile(
			float(assignment.get("arrival_slowdown_distance", 0.55)),
			float(assignment.get("arrival_min_speed_scale", 0.80))
		)
	formation_facing = assignment.get("facing", ai_player.global_position - global_position)
	formation_facing.y = 0.0
	if formation_facing.length_squared() > 0.001:
		formation_facing = formation_facing.normalized()
	formation_row = int(assignment.get("row", 0))
	formation_column = int(assignment.get("column", 0))
	formation_unit_count = int(assignment.get("unit_count", 1))
	formation_nearby_allies = int(assignment.get("nearby_allies", 0))
	formation_nearby_veterans = int(assignment.get("nearby_veterans", 0))
	formation_veteran_count = int(assignment.get("veteran_count", 0))
	formation_cohort_formed = bool(assignment.get("cohort_formed", false))
	formation_cohort_revision = int(assignment.get("cohort_revision", formation_cohort_revision))
	var formation_member_ready := bool(assignment.get("member_ready", true))
	var breach_active := bool(assignment.get("breach", false))
	var breach_tactic := StringName(assignment.get("breach_tactic", &"none"))
	var new_slot := int(assignment.get("slot", formation_slot))
	if bool(assignment.get("slot_changed", false)) or (formation_slot >= 0 and formation_slot != new_slot):
		var veteran_reorganization := 1.35 if formation_veteran_count > 0 else 1.0
		formation_reorganize_timer = 0.82 / veteran_reorganization
	formation_slot = new_slot

	# A lone hoplite cannot form a phalanx, but he must remain a functional
	# opponent. Previously cohort_formed stayed false forever, so a spear unit
	# placed alone in the Forge only held his guard and never attacked.
	if formation_unit_count <= 1:
		formation_cohort_formed = true
		formation_state = &"duel"
		formation_guard_active = shield_enabled and not shield_dropped and guard_stamina > 0.0 and not ai_attack_pending
		ai_state = &"phalanx_duel"
		var duel_target := ai_player.global_position if player_distance > preferred_range_max else global_position
		return {
			"active": true,
			"target": duel_target,
			"attack_player": player_distance <= preferred_range_max + 0.42,
			"face_target": true,
		}

	var slot_distance := _flat_distance_to_position(assigned_position)
	var isolated := formation_unit_count < 2 or formation_nearby_allies <= 0
	var pursuit_distance := _flat_distance_to_position(ai_home_position)
	if not _can_ai_attack():
		formation_state = &"repli"
		formation_guard_active = shield_enabled and not shield_dropped and guard_stamina > 0.0
		ai_state = &"phalanx_repli_disarmed"
		return {
			"active": true,
			"target": assigned_position - formation_facing * 1.55,
			"attack_player": false,
		}
	if isolated and pursuit_distance > formation_pursuit_limit:
		formation_state = &"repli"
		formation_guard_active = shield_enabled and not shield_dropped and guard_stamina > 0.0
		ai_state = &"phalanx_repli"
		return {"active": true, "target": ai_home_position, "attack_player": false}

	if breach_active:
		formation_state = breach_tactic
	elif not formation_cohort_formed:
		formation_state = &"rassemblement"
	elif bool(assignment.get("broken", false)):
		formation_state = &"rupture"
	elif formation_reorganize_timer > 0.0:
		formation_state = &"reorganisation"
	elif slot_distance > 1.45:
		formation_state = &"rassemblement"
	elif slot_distance > 0.42:
		formation_state = &"marche"
	elif player_distance <= ai_attack_range:
		formation_state = &"attaque" if ai_attack_pending else &"garde"
	else:
		formation_state = &"poussee"

	var formation_reach := formation_rank_spacing * 0.72 if formation_row == 1 else 0.0
	var minimum_attack_distance := preferred_range_min * 0.68
	var maximum_attack_distance := minf(preferred_range_max + 0.42, ai_attack_range + formation_reach)
	var can_threaten := (
		formation_cohort_formed
		and formation_member_ready
		and formation_row <= 1
		and player_distance >= minimum_attack_distance
		and player_distance <= maximum_attack_distance
	)
	if breach_active:
		can_threaten = (
			bool(assignment.get("breach_can_attack", false))
			and player_distance >= minimum_attack_distance
			and player_distance <= minf(preferred_range_max + 0.62, ai_attack_range + formation_reach)
		)
		if breach_tactic == &"expulsion_arc":
			_queue_expulsion_shield_push(assignment)
		elif bool(forced_attack_step.get("expulsion_push", false)):
			forced_attack_step.clear()
	elif bool(forced_attack_step.get("expulsion_push", false)):
		forced_attack_step.clear()
	formation_guard_active = (
		shield_enabled
		and not shield_dropped
		and guard_stamina > 0.0
		and not ai_attack_pending
		and ai_attack_recovery_timer <= 0.0
		and formation_state in [&"rassemblement", &"marche", &"garde", &"poussee", &"reorganisation", &"rupture", &"expulsion_arc", &"coordinated_arc", &"coordinated_sortie"]
	)
	ai_state = StringName("phalanx_" + String(formation_state))
	return {"active": true, "target": assigned_position, "attack_player": can_threaten, "face_target": true}

func _queue_expulsion_shield_push(assignment: Dictionary) -> void:
	# The middle of the crescent performs the visible eviction work. Its three
	# front shields bash in the normal attack-token rhythm; tips keep their spear
	# patterns, so the response reads as a coordinated push rather than spam.
	if formation_row != 0 or absi(formation_column) > 1:
		return
	if float(assignment.get("breach_transition", 0.0)) < 0.68:
		return
	if ai_attack_pending or not forced_attack_step.is_empty():
		return
	for raw_step: Variant in combat_pattern:
		if not (raw_step is Dictionary):
			continue
		var step := raw_step as Dictionary
		if not String(step.get("id", "")).contains("shield_push"):
			continue
		forced_attack_step = step.duplicate(true)
		forced_attack_step["expulsion_push"] = true
		# Slightly longer recovery makes each shove legible and prevents a wall
		# of overlapping bash animations.
		forced_attack_step["recovery"] = maxf(float(forced_attack_step.get("recovery", ai_attack_recovery)), 0.42)
		return

func _flat_distance_to_position(position_value: Vector3) -> float:
	var delta_position := position_value - global_position
	delta_position.y = 0.0
	return delta_position.length()

func _orbit_position(target_node: Node3D, radius: float, angular_speed: float) -> Vector3:
	if target_node == null or not is_instance_valid(target_node):
		return global_position
	var direction_sign := -1.0 if ((ai_guard_index + get_instance_id()) % 2) == 0 else 1.0
	var seed_angle := fmod(float(get_instance_id() % 997) * 2.39996, TAU)
	var time_angle := Time.get_ticks_msec() * 0.001 * angular_speed * direction_sign
	var angle := seed_angle + time_angle
	return target_node.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius

func _ranged_height_biased_target(personality_target: Vector3, player_distance: float) -> Vector3:
	if ranged_height_preference <= 0.0:
		return personality_target
	_refresh_ranged_height_awareness()

	# Height is a tactical preference, not a new combat personality. An archer
	# still aims, advances and eventually retreats according to the ranged band;
	# he only takes a nearby climb while it does not erase the close-contact beat.
	var close_contact := player_distance < preferred_range_min
	if ranged_height_target_valid and not close_contact:
		ai_state = &"ranged_seek_height"
		return ranged_height_target

	# Once a useful height has been occupied, do not let a formation slot, home
	# point or retreat vector lure the archer down. Edge safety below enforces the
	# same rule on separation impulses and on platforms with no walkable exit.
	if ranged_high_ground_active and not _ranged_target_preserves_height(personality_target):
		ai_state = &"ranged_high_ground_hold"
		return global_position
	return personality_target

func _refresh_ranged_height_awareness(force: bool = false) -> void:
	if ranged_height_preference <= 0.0 or not is_inside_tree():
		return
	if not force and ranged_height_scan_timer > 0.0:
		return
	ranged_height_scan_timer = 0.72 + float((get_instance_id() + ai_guard_index) % 5) * 0.055
	ranged_height_target_valid = false

	var current_ground := _ranged_current_ground_sample()
	if current_ground.is_empty():
		return
	var current_floor_y := (current_ground.get("position", global_position) as Vector3).y
	if ranged_high_ground_active and current_floor_y < ranged_preserved_floor_y - 0.80:
		# Knockback or a collapsing surface may physically remove the archer from
		# his perch. Rebase after that forced fall so the AI does not freeze below it.
		ranged_high_ground_active = false
		ranged_preserved_floor_y = -INF
	elif ranged_high_ground_active:
		ranged_preserved_floor_y = maxf(ranged_preserved_floor_y, current_floor_y)

	var found_lower_ground := false
	var best_score := -INF
	var best_target := Vector3.ZERO
	var angle_offset := fmod(float((get_instance_id() + ai_guard_index * 17) % 360), 360.0) * PI / 180.0
	for radius: float in RANGED_HEIGHT_SCAN_RADII:
		for direction_index: int in range(RANGED_HEIGHT_SCAN_DIRECTIONS):
			var angle := angle_offset + TAU * float(direction_index) / float(RANGED_HEIGHT_SCAN_DIRECTIONS)
			var sample_position := global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
			var ground := _ranged_ground_sample(sample_position, RANGED_MAX_CLIMB_HEIGHT + 0.45, 2.6)
			if ground.is_empty():
				found_lower_ground = true
				continue
			var point := ground.get("position", sample_position) as Vector3
			var height_gain := point.y - current_floor_y
			if height_gain < -RANGED_MIN_USEFUL_HEIGHT:
				found_lower_ground = true
				continue
			if height_gain < RANGED_MIN_USEFUL_HEIGHT or height_gain > RANGED_MAX_CLIMB_HEIGHT:
				continue
			if not _ranged_has_walkable_climb_path(point, current_floor_y):
				continue
			var score := height_gain * (3.6 + ranged_height_preference) - radius * 0.34
			if score > best_score:
				best_score = score
				best_target = point

	if found_lower_ground or current_floor_y > ai_home_position.y + RANGED_MIN_USEFUL_HEIGHT:
		ranged_high_ground_active = true
		ranged_preserved_floor_y = maxf(ranged_preserved_floor_y, current_floor_y)
	if best_score > -INF:
		ranged_height_target = best_target
		ranged_height_target_valid = true

func _ranged_has_walkable_climb_path(candidate: Vector3, starting_floor_y: float) -> bool:
	var flat_path := candidate - global_position
	flat_path.y = 0.0
	var distance := flat_path.length()
	if distance < 0.20:
		return false
	var direction := flat_path / distance
	var samples := maxi(2, ceili(distance / 0.72))
	var previous_y := starting_floor_y
	for sample_index: int in range(1, samples + 1):
		var progress := float(sample_index) / float(samples)
		var sample_position := global_position + direction * distance * progress
		var ground := _ranged_ground_sample(sample_position, RANGED_MAX_CLIMB_HEIGHT + 0.45, 1.8)
		if ground.is_empty():
			return false
		var floor_y := (ground.get("position", sample_position) as Vector3).y
		if floor_y - previous_y > RANGED_MAX_PATH_RISE:
			return false
		if floor_y < starting_floor_y - RANGED_MAX_PRESERVED_DROP:
			return false
		previous_y = floor_y
	return candidate.y - previous_y <= RANGED_MAX_PATH_RISE + 0.08

func _ranged_target_preserves_height(target: Vector3) -> bool:
	if not ranged_high_ground_active or target.distance_squared_to(global_position) < 0.10:
		return true
	var ground := _ranged_ground_sample(target, RANGED_MAX_CLIMB_HEIGHT + 0.45, 3.2)
	if ground.is_empty():
		return false
	var target_floor_y := (ground.get("position", target) as Vector3).y
	return target_floor_y >= ranged_preserved_floor_y - RANGED_MAX_PRESERVED_DROP

func _ranged_ground_sample(sample_position: Vector3, scan_up: float, scan_down: float) -> Dictionary:
	if not is_inside_tree() or get_world_3d() == null:
		return {}
	var origin := Vector3(sample_position.x, global_position.y + scan_up, sample_position.z)
	var end := Vector3(sample_position.x, global_position.y - scan_down, sample_position.z)
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1, [get_rid()])
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal := hit.get("normal", Vector3.UP) as Vector3
	if normal.dot(Vector3.UP) < cos(floor_max_angle):
		return {}
	return hit

func _ranged_current_ground_sample() -> Dictionary:
	var now_msec := Time.get_ticks_msec()
	var moved := global_position - ranged_ground_cache_position
	moved.y = 0.0
	if ranged_ground_cache_initialized and now_msec < ranged_ground_cache_deadline_msec and moved.length_squared() <= 0.12 * 0.12:
		return ranged_ground_cache_result
	ranged_ground_cache_position = global_position
	ranged_ground_cache_result = _ranged_ground_sample(global_position, 0.55, 1.35)
	ranged_ground_cache_initialized = true
	ranged_ground_cache_deadline_msec = now_msec + 60
	return ranged_ground_cache_result

func _move_and_slide_with_ranged_height_guard() -> void:
	velocity = preload("res://scripts/abilities/flame_wall.gd").avoid(self, velocity, get_physics_process_delta_time())
	_constrain_ranged_velocity_to_height()
	move_and_slide()

func _constrain_ranged_velocity_to_height() -> void:
	if behavior_mode != &"ranged" or ranged_height_preference <= 0.0:
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_velocity.length()
	if speed < 0.05:
		return
	var current_ground := _ranged_current_ground_sample()
	if current_ground.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var current_floor_y := (current_ground.get("position", global_position) as Vector3).y
	var lookahead := clampf(speed * 0.24, RANGED_EDGE_LOOKAHEAD_MIN, RANGED_EDGE_LOOKAHEAD_MAX)
	var next_position := global_position + horizontal_velocity / speed * lookahead
	var next_ground := _ranged_ground_sample(next_position, 0.82, 0.62)
	var unsafe_drop := next_ground.is_empty()
	if not unsafe_drop:
		var next_floor_y := (next_ground.get("position", next_position) as Vector3).y
		var allowed_drop := RANGED_MAX_PRESERVED_DROP if ranged_high_ground_active else RANGED_MAX_NORMAL_STEP_DOWN
		unsafe_drop = next_floor_y < current_floor_y - allowed_drop
		if ranged_high_ground_active:
			unsafe_drop = unsafe_drop or next_floor_y < ranged_preserved_floor_y - RANGED_MAX_PRESERVED_DROP
	if unsafe_drop:
		# Do not synthesize a dodge off a roof. Holding the last safe tile keeps the
		# archer punishable when the player finally reaches an isolated platform.
		velocity.x = 0.0
		velocity.z = 0.0
		if ranged_high_ground_active:
			ai_state = &"ranged_high_ground_hold"

func _ai_separation_vector() -> Vector3:
	var push: Vector3 = Vector3.ZERO
	if get_tree() == null:
		return push
	if crowd_director == null or not is_instance_valid(crowd_director):
		crowd_director = get_tree().get_first_node_in_group("crowd_director")
	separation_candidates.clear()
	if crowd_director != null and crowd_director.has_method("fill_nearby_combatants"):
		crowd_director.call("fill_nearby_combatants", global_position, separation_candidates)
	else:
		separation_candidates.assign(get_tree().get_nodes_in_group("combatant_ai"))
	for other: Node in separation_candidates:
		if other == self or not (other is Node3D):
			continue
		if other.has_method("is_dead_for_combat") and bool(other.call("is_dead_for_combat")):
			continue
		var delta_pos: Vector3 = global_position - (other as Node3D).global_position
		delta_pos.y = 0.0
		var distance: float = delta_pos.length()
		var other_enemy := other as HopliteAthenianEnemy
		var same_faction: bool = other_enemy != null and other_enemy.faction == faction
		var same_phalanx_cohort := same_faction and _shares_phalanx_cohort(other_enemy)
		# Slot geometry already owns spacing inside a phalanx. The generic 1.78 m
		# personal space was wider than the authored 1.08/1.18 m formation grid, so
		# every member continuously pushed against its own assigned post.
		var cohort_space := maxf(0.68, minf(formation_spacing, formation_rank_spacing) * 0.74)
		var personal_space: float = cohort_space if same_phalanx_cohort else (1.78 if same_faction else 1.22)
		if distance < 0.025:
			# Perfect overlaps used to produce a zero vector and could therefore
			# remain locked forever. A stable per-pair angle breaks the symmetry.
			var pair_seed: int = int((get_instance_id() * 31 + other.get_instance_id() * 17) % 360)
			var escape_angle: float = deg_to_rad(float(pair_seed))
			delta_pos = Vector3(cos(escape_angle), 0.0, sin(escape_angle))
			distance = 0.025
		if distance < personal_space:
			var pressure: float = (personal_space - distance) / personal_space
			push += delta_pos.normalized() * (pressure * pressure + pressure * 0.45)
	return push

func _shares_phalanx_cohort(other: HopliteAthenianEnemy) -> bool:
	if other == null or not _is_phalanx_unit() or not other._is_phalanx_unit():
		return false
	var own_group := StringName(get_meta("formation_group", StringName()))
	var other_group := StringName(other.get_meta("formation_group", StringName()))
	if own_group == StringName() and other_group == StringName():
		# Legacy unlabelled phalanxes are grouped by proximity by the director; if
		# they can enter this local separation query they belong to that same cohort.
		return true
	return own_group != StringName() and own_group == other_group

func _apply_attack_spacing(delta: float) -> void:
	var target_velocity: Vector3 = Vector3.ZERO
	if cached_ai_separation.length() > 0.001:
		var spacing_speed: float = minf(_current_ai_move_speed() * 0.42, 1.85)
		target_velocity = cached_ai_separation.normalized() * spacing_speed * clampf(cached_ai_separation.length(), 0.30, 1.0)
	velocity.x = move_toward(velocity.x, target_velocity.x, ai_acceleration * 1.8 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ai_acceleration * 1.8 * delta)

func _apply_pending_attack_motion(delta: float) -> void:
	var lunge_speed := float(active_attack_step.get("lunge_speed", 0.0))
	var lunge_start := float(active_attack_step.get("lunge_start", 0.58))
	var windup_progress := 1.0 - ai_attack_windup_timer / maxf(active_attack_windup_total, 0.001)
	if lunge_speed <= 0.0 or windup_progress < lunge_start or ai_player == null or not is_instance_valid(ai_player):
		_apply_attack_spacing(delta)
		return
	var toward_target := ai_player.global_position - global_position
	toward_target.y = 0.0
	if toward_target.length_squared() < 0.001:
		_apply_attack_spacing(delta)
		return
	var desired := toward_target.normalized() * lunge_speed
	velocity.x = move_toward(velocity.x, desired.x, ai_acceleration * 2.2 * delta)
	velocity.z = move_toward(velocity.z, desired.z, ai_acceleration * 2.2 * delta)

func _connect_threat_awareness() -> void:
	var threat: Node = battle_player if battle_player != null else ai_player
	if threat == null or not threat.has_signal("combat_attack_started"):
		return
	var callback := Callable(self, "_on_threat_attack_started")
	if not threat.is_connected("combat_attack_started", callback):
		threat.connect("combat_attack_started", callback)

func _on_threat_attack_started(slot: StringName, context: StringName, power: float) -> void:
	if dead or defense_mode != &"shield" and defense_mode != &"parry":
		return
	if defense_cooldown_timer > 0.0 or guard_break_timer > 0.0 or ai_attack_pending:
		return
	if defense_mode == &"shield" and (not shield_enabled or shield_dropped or guard_stamina <= 0.0):
		return
	var threat: Node3D = battle_player if battle_player != null and is_instance_valid(battle_player) else ai_player
	if threat == null or _flat_distance_to(threat) > defense_reaction_range:
		return
	var toward_threat := threat.global_position - global_position
	toward_threat.y = 0.0
	var forward := -global_basis.z
	forward.y = 0.0
	if toward_threat.length_squared() > 0.001 and forward.normalized().dot(toward_threat.normalized()) < -0.15:
		return
	# A trained shield bearer should visibly answer an incoming swing. Profile
	# chance still differentiates parries, while a real aspis is dependable.
	# A shield bearer who is free, facing the threat and off cooldown commits to
	# the block. The cooldown/stamina system already prevents permanent turtling;
	# another random roll here made whole groups appear to never use their shield.
	var reaction_chance := 1.0 if defense_mode == &"shield" else defense_chance
	if slot == &"heavy":
		reaction_chance += 0.18 + power * 0.10
	elif slot == &"spin360":
		reaction_chance += 0.10
	if context == &"dash" or context == &"air":
		reaction_chance += 0.07
	if randf() > clampf(reaction_chance, 0.0, 1.0):
		return
	# A parry opens later and for less time; a shield is raised earlier and can
	# absorb the complete authored blade sweep. Both react once per player attack,
	# rather than rolling an opaque random chance every physics frame.
	var attack_delay := defense_reaction_delay
	if slot == &"heavy":
		attack_delay += 0.06 + power * 0.08
	elif slot == &"spin360":
		attack_delay += 0.025
	if defense_mode == &"parry":
		attack_delay += 0.045
	# Units sharing an archetype must not raise every shield on the same frame.
	# The stable instance-based phase is replayable and costs no per-frame RNG.
	var reaction_jitter := float(ProjectSettings.get_setting("hoplite/crowd/defense_reaction_jitter", 0.06))
	var reaction_phase := float((get_instance_id() * 37) % 1000) / 999.0 * 2.0 - 1.0
	attack_delay += reaction_phase * reaction_jitter
	defense_reaction_timer = maxf(0.015, attack_delay)

func _begin_defense_window() -> void:
	if dead or guard_break_timer > 0.0:
		return
	if defense_mode == &"shield" and (not shield_enabled or shield_dropped or shield_root == null or guard_stamina <= 0.0):
		return
	defense_timer = defense_duration
	defense_cooldown_timer = defense_cooldown + defense_duration
	ai_state = &"parry" if defense_mode == &"parry" else &"shield_guard"
	velocity.x *= 0.42
	velocity.z *= 0.42
	_set_shield_guard_active(defense_mode == &"shield")
	_update_shield_guard_visual()
	if ai_animation_driver != null:
		ai_animation_driver.begin_block()
		return
	if uses_mixamo_visual:
		var mixamo_guard := StringName(mixamo_clips.get("idle", StringName()))
		_play_simple_loop(mixamo_guard, 1.0)
		return
	if animation_player != null:
		var guard_clip := StringName(&"Idle_Shield" if animation_player.has_animation(&"Idle_Shield") else &"Sword_Block")
		if animation_player.has_animation(guard_clip):
			_play_simple_loop(guard_clip, 1.0)

func _end_defense_window() -> void:
	_set_shield_guard_active(false)
	if _formation_should_guard():
		_update_shield_guard_visual()
		return
	if shield_guard_root_anchored and not shield_dropped:
		_set_shield_guard_root_anchored(false)
	elif shield_root != null and not shield_dropped:
		shield_root.transform = shield_rest_transform
	if ai_animation_driver != null:
		ai_animation_driver.end_block()
	elif not dead:
		simple_anim_state = StringName()
		_play_idle()

func _play_defense_impact() -> void:
	if ai_animation_driver != null and ai_animation_driver.play_block_impact():
		return
	if animation_player == null:
		return
	var impact_clip := StringName(&"Shield_OneShot" if animation_player.has_animation(&"Shield_OneShot") else StringName())
	if impact_clip != StringName():
		var animation := animation_player.get_animation(impact_clip)
		simple_anim_lock_timer = minf(0.42, animation.length / 1.55) if animation != null else 0.32
		animation_player.play(impact_clip, 0.025, 1.55)
		simple_anim_state = impact_clip

func _update_defense(delta: float) -> void:
	defense_cooldown_timer = maxf(0.0, defense_cooldown_timer - delta)
	guard_regen_timer = maxf(0.0, guard_regen_timer - delta)
	if guard_break_timer > 0.0:
		guard_break_timer = maxf(0.0, guard_break_timer - delta)
		defense_reaction_timer = -1.0
		defense_timer = 0.0
		if guard_break_timer <= 0.0:
			ai_state = &"guard_recover"
		return
	if guard_max > 0.0 and guard_regen_timer <= 0.0 and defense_timer <= 0.0 and not ai_attack_pending:
		var cohesion_multiplier := 1.0 + cohesion_guard_bonus if formation_nearby_veterans > 0 else 1.0
		guard_stamina = minf(guard_max, guard_stamina + guard_regen * cohesion_multiplier * delta)
	if defense_timer > 0.0:
		_update_shield_guard_visual()
		defense_timer = maxf(0.0, defense_timer - delta)
		if defense_timer <= 0.0:
			_end_defense_window()
		return
	if defense_mode != &"shield" and defense_mode != &"parry":
		return
	if ai_player == null or not is_instance_valid(ai_player):
		defense_reaction_timer = -1.0
		return
	var threat_distance: float = _flat_distance_to(ai_player)
	if defense_reaction_timer >= 0.0:
		if threat_distance > defense_reaction_range:
			defense_reaction_timer = -1.0
			return
		defense_reaction_timer -= delta
		if defense_reaction_timer <= 0.0:
			# Recovery may still own the body for a few frames. Keep the prepared
			# reaction at zero and raise the shield as soon as that animation ends.
			if not ai_attack_pending and ai_attack_recovery_timer <= 0.0 and defense_cooldown_timer <= 0.0:
				defense_reaction_timer = -1.0
				_begin_defense_window()
		return
	if threat_distance > 3.1:
		proactive_defense_requires_attack = false
		return
	if ai_attack_pending or ai_attack_recovery_timer > 0.0 or defense_cooldown_timer > 0.0:
		return
	if (
		_is_phalanx_unit()
		and formation_cohort_formed
		and formation_row <= 1
		and ai_attack_cooldown_timer <= 0.0
		and threat_distance <= ai_attack_range + (formation_rank_spacing * 0.72 if formation_row == 1 else 0.0)
	):
		# Auto-guard used to reopen on the exact frame its cooldown ended. Because
		# attack eligibility is evaluated later in the same physics tick, a formed
		# shield line could turtle forever after its first pair of thrusts. Keep
		# reactive blocks intact, but yield this proactive window to the scheduler.
		return
	if _is_phalanx_unit() and proactive_defense_requires_attack:
		return
	# Shield infantry deliberately open an observable guard beat before their next
	# attack. This makes the behaviour immediately testable in the annex too.
	if defense_mode == &"shield":
		_begin_defense_window()
		if _is_phalanx_unit():
			proactive_defense_requires_attack = true

func _engagement_position(target_node: Node3D, preferred_radius: float) -> Vector3:
	return _engagement_assignment(target_node, preferred_radius).get("position", global_position)

func _engagement_assignment(target_node: Node3D, preferred_radius: float) -> Dictionary:
	if target_node == null or not is_instance_valid(target_node):
		return {"position": global_position, "role": &"invalid", "attack_ready": false}
	if crowd_director == null or not is_instance_valid(crowd_director):
		crowd_director = get_tree().get_first_node_in_group("crowd_director")
	if crowd_director != null and crowd_director.has_method("engagement_assignment"):
		var result: Variant = crowd_director.call("engagement_assignment", self, target_node, preferred_radius, crowd_participant_descriptor())
		if result is Dictionary:
			return result as Dictionary
	if crowd_director != null and crowd_director.has_method("engagement_position"):
		var legacy_position: Variant = crowd_director.call("engagement_position", self, target_node, preferred_radius)
		if typeof(legacy_position) == TYPE_VECTOR3:
			return {"position": legacy_position as Vector3, "role": &"line", "attack_ready": true}
	var angle: float = fmod(float(get_instance_id() * 137), 360.0)
	return {
		"position": target_node.global_position + Vector3(cos(deg_to_rad(angle)), 0.0, sin(deg_to_rad(angle))) * preferred_radius,
		"role": &"line",
		"attack_ready": true,
	}

func _current_ai_think_interval() -> float:
	# High-frequency physics is reserved for actual movement/contact. Tactical goal
	# selection does not need 60 Hz, especially for soldiers still crossing the field.
	if not mass_battle_mode:
		return 0.045 if cached_player_distance <= 9.0 else 0.085
	if _is_phalanx_unit():
		# The cohort director owns formation decisions. Soldiers only resample the
		# published order; local attacks, defense and collisions keep their own cadence.
		if cached_player_distance <= 7.0:
			return 0.10
		if cached_player_distance <= 14.0:
			return 0.16
		return 0.25
	if cached_player_distance <= 7.0:
		return 0.055
	if cached_player_distance <= 14.0:
		return 0.10
	return 0.18

func _defer_mass_battle_physics_step(delta: float) -> bool:
	if not mass_battle_mode or not ai_enabled or dead or training_activation_pending:
		physics_lod_phase = 0
		return false
	var lod_settings := _runtime_lod_settings()
	if not bool(lod_settings["enabled"]):
		physics_lod_phase = 0
		return false
	# Contact, authored attacks and defensive reactions retain full-rate physics.
	if (
		ai_attack_pending
		or attack_permission_claimed
		or ai_attack_recovery_timer > 0.0
		or defense_timer > 0.0
		or defense_reaction_timer >= 0.0
		or guard_break_timer > 0.0
		or parry_counter_queued
	):
		physics_lod_phase = 0
		return false
	var target_in_contact := false
	if ai_player != null and is_instance_valid(ai_player):
		var target_delta := ai_player.global_position - global_position
		target_delta.y = 0.0
		var full_rate_distance := float(lod_settings["full_rate_distance"])
		target_in_contact = target_delta.length_squared() <= full_rate_distance * full_rate_distance
	var divisor := int(lod_settings["near_physics_divisor"])
	if render_lod_level == 1:
		divisor = int(lod_settings["medium_physics_divisor"])
	elif render_lod_level >= 2:
		divisor = int(lod_settings["far_physics_divisor"])
	if target_in_contact:
		divisor = 1
	if divisor <= 1:
		physics_lod_phase = 0
		return false
	physics_lod_phase = (physics_lod_phase + 1) % divisor
	if physics_lod_phase == 0:
		return false
	physics_lod_accumulator += delta
	physics_deferred_step_count += 1
	return true

static func _runtime_lod_settings() -> Dictionary:
	var now_msec := Time.get_ticks_msec()
	if now_msec >= _lod_settings_refresh_deadline_msec:
		var enabled := bool(ProjectSettings.get_setting("hoplite/enemy_lod/enabled", true))
		var near_distance := float(ProjectSettings.get_setting("hoplite/enemy_lod/near_distance", 16.0))
		var far_distance := maxf(near_distance + 2.0, float(ProjectSettings.get_setting("hoplite/enemy_lod/far_distance", 38.0)))
		var cull_distance := maxf(far_distance + 5.0, float(ProjectSettings.get_setting("hoplite/enemy_lod/cull_distance", 90.0)))
		var full_rate_distance := clampf(float(ProjectSettings.get_setting("hoplite/enemy_lod/full_rate_distance", 3.8)), 2.0, near_distance)
		_lod_settings_cache["enabled"] = enabled
		_lod_settings_cache["near_distance"] = near_distance
		_lod_settings_cache["far_distance"] = far_distance
		_lod_settings_cache["cull_distance"] = cull_distance
		_lod_settings_cache["full_rate_distance"] = full_rate_distance
		_lod_settings_cache["near_physics_divisor"] = clampi(int(ProjectSettings.get_setting("hoplite/enemy_lod/near_physics_divisor", 2)), 1, 6)
		_lod_settings_cache["medium_physics_divisor"] = clampi(int(ProjectSettings.get_setting("hoplite/enemy_lod/medium_physics_divisor", 3)), 1, 8)
		_lod_settings_cache["far_physics_divisor"] = clampi(int(ProjectSettings.get_setting("hoplite/enemy_lod/far_physics_divisor", 5)), 1, 10)
		_lod_settings_cache["medium_animation_hz"] = clampf(float(ProjectSettings.get_setting("hoplite/enemy_lod/medium_animation_hz", 30.0)), 12.0, 60.0)
		_lod_settings_cache["far_animation_hz"] = clampf(float(ProjectSettings.get_setting("hoplite/enemy_lod/far_animation_hz", 12.0)), 4.0, 30.0)
		_lod_settings_cache["shadow_distance"] = clampf(float(ProjectSettings.get_setting("hoplite/enemy_lod/shadow_distance", 8.0)), 0.0, near_distance)
		_lod_settings_refresh_deadline_msec = now_msec + 250
	return _lod_settings_cache

static func invalidate_runtime_lod_settings_cache() -> void:
	_lod_settings_refresh_deadline_msec = 0

func _update_performance_lod() -> void:
	# Performance/anatomy precision follows the human camera, not the nearest AI
	# opponent. Otherwise every pair fighting on a 100-unit battlefield remains
	# permanently in sword-range LOD even when it is far outside the player's view.
	var lod_reference: Node3D = battle_player if battle_player != null and is_instance_valid(battle_player) else ai_player
	if lod_reference == null or not is_instance_valid(lod_reference):
		cached_player_distance = INF
	else:
		var delta_to_player: Vector3 = lod_reference.global_position - global_position
		delta_to_player.y = 0.0
		cached_player_distance = delta_to_player.length()

	var lod_settings := _runtime_lod_settings()
	var lod_enabled := bool(lod_settings["enabled"])
	var near_distance := float(lod_settings["near_distance"])
	var far_distance := float(lod_settings["far_distance"])
	var cull_distance := float(lod_settings["cull_distance"])
	var next_render_lod := 0
	if lod_enabled:
		if cached_player_distance > cull_distance:
			next_render_lod = 3
		elif cached_player_distance > far_distance:
			next_render_lod = 2
		elif cached_player_distance > near_distance:
			next_render_lod = 1
	var next_secondary_shadows := _secondary_hoplite_should_cast_shadows(next_render_lod, lod_enabled)
	if next_render_lod != render_lod_level or next_secondary_shadows != secondary_hoplite_shadows_enabled:
		secondary_hoplite_shadows_enabled = next_secondary_shadows
		_apply_render_lod(next_render_lod, lod_enabled, cull_distance)

	if anatomy == null:
		return
	var target_in_contact := false
	if ai_player != null and is_instance_valid(ai_player):
		var target_delta: Vector3 = ai_player.global_position - global_position
		target_delta.y = 0.0
		target_in_contact = target_delta.length_squared() <= 5.5 * 5.5
	var anatomy_in_combat := (
		combat_debug_visible
		or cached_player_distance <= 8.0
		or target_in_contact
		or ai_attack_pending
		or ai_attack_recovery_timer > 0.0
		or defense_timer > 0.0
		or ai_alert_timer > 0.0
		or retaliation_timer > 0.0
	)
	anatomy.set_tracking_enabled(anatomy_in_combat)
	if not anatomy_in_combat:
		return
	if combat_debug_visible or ai_attack_pending or defense_timer > 0.0 or cached_player_distance <= 3.8:
		# Exact following is reserved for the actual strike/guard window.
		anatomy.set_update_interval(0.0 if not mass_battle_mode else 0.030)
	elif cached_player_distance <= 10.0 or target_in_contact:
		anatomy.set_update_interval(0.065 if mass_battle_mode else 0.045)
	else:
		anatomy.set_update_interval(0.20 if mass_battle_mode else 0.12)

func _secondary_hoplite_should_cast_shadows(level: int, lod_enabled: bool) -> bool:
	if not lod_enabled:
		return true
	if level > 0 or mass_battle_mode:
		return false
	if not _is_phalanx_unit():
		return true
	var secondary: bool = formation_row > 0 or (formation_row == 0 and absi(formation_column) >= 2)
	return not secondary or cached_player_distance <= float(_runtime_lod_settings()["shadow_distance"])

func _direct_animation_uses_manual_sampling() -> bool:
	return (
		ai_animation_driver == null
		and animation_player != null
		and render_lod_level > 0
		and animation_player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)

func _apply_direct_animation_lod(level: int) -> void:
	if ai_animation_driver != null or animation_player == null:
		return
	if level <= 0:
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		# Re-sample immediately on wake so a player culled at LOD3 can never keep
		# its last far-away pose until the following idle frame.
		animation_player.advance(0.0)
		direct_animation_sample_count += 1
	else:
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func _apply_render_lod(level: int, lod_enabled: bool, cull_distance: float) -> void:
	render_lod_level = level
	lod_animation_accumulator = 0.0
	if ai_animation_driver != null and ai_animation_driver.has_method("set_simulation_lod"):
		ai_animation_driver.set_simulation_lod(level if lod_enabled else 0)
	_apply_direct_animation_lod(level if lod_enabled else 0)
	for candidate: Node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		if geometry == null:
			continue
		var instance_id := geometry.get_instance_id()
		if not lod_geometry_defaults.has(instance_id):
			lod_geometry_defaults[instance_id] = {
				"lod_bias": geometry.lod_bias,
				"range_end": geometry.visibility_range_end,
				"range_margin": geometry.visibility_range_end_margin,
				"fade_mode": geometry.visibility_range_fade_mode,
				"cast_shadow": geometry.cast_shadow,
			}
		var defaults := lod_geometry_defaults[instance_id] as Dictionary
		if not lod_enabled:
			geometry.lod_bias = float(defaults["lod_bias"])
			geometry.visibility_range_end = float(defaults["range_end"])
			geometry.visibility_range_end_margin = float(defaults["range_margin"])
			geometry.visibility_range_fade_mode = int(defaults["fade_mode"])
			geometry.cast_shadow = int(defaults["cast_shadow"])
			continue
		geometry.lod_bias = 1.0 if level == 0 else (0.55 if level == 1 else 0.22)
		geometry.visibility_range_end = cull_distance
		geometry.visibility_range_end_margin = 3.0
		# Compatibility renderer cannot use smooth range fades. Disabled fade mode
		# keeps the fast hysteresis path and avoids the transparent pipeline.
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		geometry.cast_shadow = int(defaults["cast_shadow"]) if level == 0 and secondary_hoplite_shadows_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for candidate: Node in find_children("*", "GPUParticles3D", true, false):
		var particles := candidate as GPUParticles3D
		if particles == null:
			continue
		var instance_id := particles.get_instance_id()
		if not lod_particle_defaults.has(instance_id):
			lod_particle_defaults[instance_id] = particles.emitting
		particles.emitting = bool(lod_particle_defaults[instance_id]) and (not lod_enabled or level <= 1)
	if status_label != null and not combat_debug_visible:
		status_label.visible = not lod_enabled or level == 0

func _begin_ai_attack() -> void:
	if ai_attack_pending or ai_player == null or not is_instance_valid(ai_player) or not _can_ai_attack():
		return
	# Melee and ranged attacks share the same bounded scheduler. Projectiles used
	# to bypass crowd capacity entirely, allowing every archer to fire together.
	if not _claim_attack_permission(ai_player):
		ai_state = &"pressure_wait"
		ai_attack_cooldown_timer = randf_range(0.16, 0.30)
		return
	ai_attack_pending = true
	proactive_defense_requires_attack = false
	_force_animation_sample()
	defense_timer = 0.0
	defense_reaction_timer = -1.0
	_set_shield_guard_active(false)
	if ai_animation_driver != null:
		ai_animation_driver.end_block()
	velocity.x = 0.0
	velocity.z = 0.0

	active_attack_step = forced_attack_step.duplicate(true) if not forced_attack_step.is_empty() else _next_combat_pattern_step()
	forced_attack_step.clear()
	active_attack_slot = StringName(active_attack_step.get("slot", _choose_ai_attack_slot()))
	active_attack_windup_total = float(active_attack_step.get("windup", ai_attack_windup))
	ai_attack_windup_timer = active_attack_windup_total
	ai_attack_cooldown_timer = float(active_attack_step.get("cooldown", randf_range(ai_attack_cooldown_min, ai_attack_cooldown_max)))
	ai_state = &"attack_windup"
	_spawn_perfect_timing_indicator()
	attack_started.emit(self, weapon_kind)
	if StringName(active_attack_step.get("special", StringName())) == &"shockwave":
		_spawn_shockwave_telegraph(float(active_attack_step.get("radius", 3.0)), active_attack_windup_total)

	var pattern_played: bool = _play_pattern_attack(active_attack_step, active_attack_slot)
	if pattern_played:
		pass
	elif _play_signature_attack():
		pass
	elif uses_mixamo_visual:
		_play_mixamo_attack_animation()
	elif ai_animation_driver != null:
		ai_animation_driver.play_attack_variant(active_attack_slot, &"idle", false, ai_attack_anim_speed)
	# Lightweight authored packages intentionally drive their hidden UAL1 donor
	# directly instead of allocating a full retarget driver per troop. They need
	# the same readable Sword_Attack fallback outside mass battles (Lab/Forge),
	# otherwise the hit resolves while the visual remains in locomotion/idle.
	elif mass_battle_mode or uses_spartan_package_visual:
		_play_mass_attack_animation()

func _next_combat_pattern_step() -> Dictionary:
	var pattern: Array = combat_pattern
	if combat_phase >= 3 and not phase_three_pattern.is_empty():
		pattern = phase_three_pattern
	elif combat_phase >= 2 and not phase_two_pattern.is_empty():
		pattern = phase_two_pattern
	if pattern.is_empty():
		return {}
	var index := posmod(combat_pattern_cursor, pattern.size())
	combat_pattern_cursor = (combat_pattern_cursor + 1) % pattern.size()
	var value: Variant = pattern[index]
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

func _play_pattern_attack(step: Dictionary, slot: StringName) -> bool:
	if step.is_empty():
		return false
	var direct_mixamo := StringName(step.get("mixamo", StringName()))
	if uses_mixamo_visual and animation_player != null and direct_mixamo != StringName():
		var direct_clip := StringName("mixamo/" + String(direct_mixamo))
		if animation_player.has_animation(direct_clip):
			var animation := animation_player.get_animation(direct_clip)
			var desired_duration := maxf(active_attack_windup_total + float(step.get("recovery", ai_attack_recovery)), 0.30)
			var playback_speed := float(step.get("animation_speed", ai_attack_anim_speed))
			if animation != null:
				playback_speed = float(step.get("animation_speed", clampf(animation.length / desired_duration, 0.72, 5.0)))
				simple_anim_lock_timer = animation.length / maxf(playback_speed, 0.05)
			else:
				simple_anim_lock_timer = desired_duration
			animation_player.play(direct_clip, 0.045, playback_speed)
			simple_anim_state = direct_clip
			return true
	if ai_animation_driver == null:
		return false
	var external_key := StringName(step.get("external", StringName()))
	if external_key != StringName() and ai_animation_driver.has_external_clip(external_key):
		var start_fraction := float(step.get("start_fraction", 0.04))
		var desired_duration := maxf(active_attack_windup_total + float(step.get("recovery", ai_attack_recovery)), 0.30)
		var source_duration: float = float(ai_animation_driver.external_clip_length(external_key)) * (1.0 - clampf(start_fraction, 0.0, 0.75))
		var synchronized_speed: float = clampf(source_duration / desired_duration, 0.72, 5.0) if source_duration > 0.0 else ai_attack_anim_speed
		return ai_animation_driver.play_external_attack(
			external_key,
			slot,
			&"enemy_pattern",
			bool(step.get("full_body", true)),
			float(step.get("animation_speed", synchronized_speed)),
			0.045,
			float(step.get("hips", 0.86)),
			false,
			start_fraction
		)
	var authored: Array = Array(step.get("authored", []))
	if not authored.is_empty():
		return bool(ai_animation_driver.play_authored_attack(authored, float(step.get("animation_speed", ai_attack_anim_speed)), bool(step.get("full_body", true)), float(step.get("hips", 0.86))))
	return false

func _choose_ai_attack_slot() -> StringName:
	match attack_style:
		&"heavy":
			return &"heavy"
		&"fast":
			return [&"light1", &"light2", &"light3"][randi() % 3]
		&"poke":
			# Placeholder until we author/import a dedicated spear thrust. Light2
			# has the most forward-readable motion in the current UAL combat pool.
			return &"light2"
		&"spear_compact":
			return &"light2" if randf() < 0.72 else &"light1"
		&"spear_veteran":
			return &"light2" if randf() < 0.82 else &"light1"
		&"harvest":
			return &"heavy"
		&"disciplined":
			return &"light2" if randf() < 0.62 else &"heavy"
		&"feint":
			return [&"light1", &"light2", &"light3"][randi() % 3]
		&"boss_combo":
			return &"heavy" if randf() < 0.40 else (&"light2" if randi() % 2 == 0 else &"light3")
		&"archer":
			return &"light2"
		&"captain":
			return &"heavy" if randf() < 0.52 else (&"light2" if randi() % 2 == 0 else &"light3")
		_:
			return &"light1" if randi() % 2 == 0 else &"light2"

func _resolve_ai_attack() -> void:
	if not ai_attack_pending:
		return
	if attack_permission_claimed and not _has_authoritative_attack_permission():
		ai_attack_pending = false
		ai_attack_windup_timer = 0.0
		ai_attack_recovery_timer = 0.16
		ai_state = &"pressure_wait"
		attack_permission_claimed = false
		attack_permission_target = null
		attack_permission_token = 0
		return
	if not _can_ai_attack():
		ai_attack_pending = false
		ai_state = &"disarmed"
		_release_attack_permission()
		return
	ai_attack_pending = false
	_clear_perfect_timing_indicator()
	ai_attack_recovery_timer = float(active_attack_step.get("recovery", ai_attack_recovery))
	ai_state = &"attack_recover"
	if ai_player == null or not is_instance_valid(ai_player):
		return

	var step_delivery := StringName(active_attack_step.get("delivery", attack_delivery))
	if step_delivery == &"projectile":
		if _has_clear_projectile_lane(ai_player):
			_spawn_ai_projectile(ai_player)
		active_attack_step.clear()
		return

	var to_player: Vector3 = ai_player.global_position - global_position
	to_player.y = 0.0
	var special := StringName(active_attack_step.get("special", StringName()))
	if special == &"telegraph":
		active_attack_step.clear()
		return
	if special == &"shockwave":
		_spawn_shockwave_release(float(active_attack_step.get("radius", 3.0)))
	var range_multiplier := float(active_attack_step.get("range_mult", 1.0))
	var rear_rank_reach := formation_rank_spacing * 0.72 if _is_phalanx_unit() and formation_row == 1 else 0.0
	var effective_range := float(active_attack_step.get("radius", ai_attack_range * range_multiplier)) if special == &"shockwave" else ai_attack_range * range_multiplier + 0.48 + rear_rank_reach
	if to_player.length() > effective_range:
		if to_player.length() <= effective_range + 3.2:
			_notify_player_attack_near_miss()
		active_attack_step.clear()
		return

	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var hit_dir: Vector3 = to_player.normalized() if to_player.length() > 0.01 else forward
	var arc_dot := float(active_attack_step.get("arc_dot", -1.0 if special == &"shockwave" else 0.10))
	if forward.dot(hit_dir) < arc_dot:
		_notify_player_attack_near_miss()
		active_attack_step.clear()
		return

	var damage: float = ai_attack_damage * float(active_attack_step.get("damage_mult", 1.0))
	if special == &"shockwave":
		var radius := maxf(float(active_attack_step.get("radius", 3.0)), 0.1)
		damage *= lerpf(1.0, 0.58, clampf(to_player.length() / radius, 0.0, 1.0))
	if ai_player.has_method("receive_enemy_hit"):
		ai_player.call("receive_enemy_hit", damage, self, hit_dir)
	elif ai_player.has_method("receive_ai_hit"):
		ai_player.call("receive_ai_hit", damage, self, hit_dir)
	active_attack_step.clear()
	active_attack_slot = StringName()

func _notify_player_attack_near_miss() -> void:
	if ai_player != null and is_instance_valid(ai_player) and ai_player.is_in_group("player") and ai_player.has_method("register_enemy_near_miss"):
		ai_player.call("register_enemy_near_miss", self)

func _spawn_perfect_timing_indicator() -> void:
	_clear_perfect_timing_indicator()
	if ai_player == null or not is_instance_valid(ai_player) or not ai_player.is_in_group("player"):
		return
	var delivery := StringName(active_attack_step.get("delivery", attack_delivery))
	if delivery == &"projectile" or global_position.distance_to(ai_player.global_position) > 8.0:
		return
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	perfect_timing_indicator = MeshInstance3D.new()
	perfect_timing_indicator.name = "PerfectDefenseTimingHalo"
	perfect_timing_indicator.top_level = true
	perfect_timing_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := TorusMesh.new()
	ring.inner_radius = 0.23
	ring.outer_radius = 0.29
	ring.rings = 24
	ring.ring_segments = 6
	perfect_timing_material = StandardMaterial3D.new()
	perfect_timing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	perfect_timing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	perfect_timing_material.albedo_color = Color(1.0, 0.69, 0.18, 0.0)
	perfect_timing_material.emission_enabled = true
	perfect_timing_material.emission = Color(1.0, 0.48, 0.08) * 1.4
	ring.material = perfect_timing_material
	perfect_timing_indicator.mesh = ring
	scene.add_child(perfect_timing_indicator)
	perfect_timing_indicator.global_position = global_position + Vector3.UP * 2.18
	perfect_timing_indicator.visible = false

func _update_perfect_timing_indicator() -> void:
	if perfect_timing_indicator == null or not is_instance_valid(perfect_timing_indicator):
		perfect_timing_indicator = null
		perfect_timing_material = null
		return
	if not ai_attack_pending or dead:
		_clear_perfect_timing_indicator()
		return
	perfect_timing_indicator.global_position = global_position + Vector3.UP * (2.18 * body_scale_factor)
	var cue_lead: float = minf(0.34, active_attack_windup_total)
	if ai_attack_windup_timer > cue_lead:
		perfect_timing_indicator.visible = false
		return
	perfect_timing_indicator.visible = true
	var readiness: float = 1.0 - clampf(ai_attack_windup_timer / maxf(cue_lead, 0.001), 0.0, 1.0)
	var response_window: float = smoothstep(0.38, 1.0, readiness)
	var pulse: float = 1.0 + sin(readiness * PI * 3.0) * 0.035 * response_window
	perfect_timing_indicator.scale = Vector3.ONE * lerpf(1.42, 0.86, readiness) * pulse
	if perfect_timing_material != null:
		var ready_color := Color(0.62, 0.94, 1.0) if ai_attack_windup_timer <= 0.20 else Color(1.0, 0.69, 0.18)
		perfect_timing_material.albedo_color = Color(ready_color.r, ready_color.g, ready_color.b, lerpf(0.08, 0.78, response_window))
		perfect_timing_material.emission = ready_color * lerpf(1.0, 2.4, response_window)

func _clear_perfect_timing_indicator() -> void:
	if perfect_timing_indicator != null and is_instance_valid(perfect_timing_indicator):
		perfect_timing_indicator.queue_free()
	perfect_timing_indicator = null
	perfect_timing_material = null

func _spawn_shockwave_telegraph(radius: float, duration: float) -> void:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	var disc := MeshInstance3D.new()
	disc.name = "EnemyShockwaveTelegraph"
	disc.top_level = true
	var mesh := CylinderMesh.new()
	mesh.height = 0.018
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 32
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.90, 0.16, 0.025, 0.10)
	material.emission_enabled = true
	material.emission = Color(0.72, 0.07, 0.01) * 1.8
	mesh.material = material
	disc.mesh = mesh
	scene.add_child(disc)
	disc.global_position = global_position + Vector3.UP * 0.035
	disc.scale = Vector3(0.12, 1.0, 0.12)
	var tween := disc.create_tween()
	tween.tween_property(disc, "scale", Vector3.ONE, maxf(duration, 0.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(disc.queue_free)

func _spawn_shockwave_release(radius: float) -> void:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "EnemyShockwaveRelease"
	ring.top_level = true
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - 0.16, 0.05)
	mesh.outer_radius = radius
	mesh.rings = 32
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.44, 0.06, 0.82)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.18, 0.01) * 2.6
	mesh.material = material
	ring.mesh = mesh
	scene.add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.06
	ring.scale = Vector3(0.18, 0.18, 0.18)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.12, 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color", Color(1.0, 0.24, 0.02, 0.0), 0.34)
	tween.chain().tween_callback(ring.queue_free)

func _claim_attack_permission(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if attack_permission_claimed and attack_permission_target == target:
		if crowd_director == null or not is_instance_valid(crowd_director):
			return true
		if _has_authoritative_attack_permission():
			return true
		# The director may have expired a stalled lease. Never let the local cache
		# continue authorizing attacks after the scheduler revoked it.
		attack_permission_claimed = false
		attack_permission_target = null
		attack_permission_token = 0
	if crowd_director == null or not is_instance_valid(crowd_director):
		crowd_director = get_tree().get_first_node_in_group("crowd_director") if get_tree() != null else null
	if crowd_director == null or not crowd_director.has_method("request_attack_permission"):
		attack_permission_waiting = false
		return true
	var attack_capacity := 3
	if crowd_director.has_method("attack_capacity_for"):
		attack_capacity = int(crowd_director.call("attack_capacity_for", target))
	if _is_phalanx_unit():
		# A line alternates one thrust or a neighboring pair instead of allowing
		# the whole front rank to fire on the same frame.
		attack_capacity = mini(attack_capacity, 2)
	if crowd_director.has_method("request_attack_lease"):
		attack_permission_token = int(crowd_director.call("request_attack_lease", self, target, attack_capacity))
		if attack_permission_token <= 0:
			attack_permission_waiting = true
			return false
	elif not bool(crowd_director.call("request_attack_permission", self, target, attack_capacity)):
		attack_permission_waiting = true
		return false
	else:
		attack_permission_token = 1
	attack_permission_claimed = true
	attack_permission_waiting = false
	attack_permission_target = target
	return true

func _release_attack_permission(cancel_waiting: bool = false) -> void:
	# A failed claim means the director has queued this attacker. Normal polling
	# must preserve that FIFO position; only teardown, target changes and explicit
	# participation changes cancel all pending requests.
	if cancel_waiting and crowd_director != null and is_instance_valid(crowd_director) and crowd_director.has_method("cancel_attack_requests"):
		crowd_director.call("cancel_attack_requests", self)
		attack_permission_waiting = false
	if not attack_permission_claimed:
		attack_permission_target = null
		attack_permission_token = 0
		return
	if crowd_director != null and is_instance_valid(crowd_director) and crowd_director.has_method("release_attack_permission"):
		crowd_director.call("release_attack_permission", self, attack_permission_target, attack_permission_token)
	attack_permission_claimed = false
	attack_permission_target = null
	attack_permission_token = 0


func _cancel_pending_attack_request() -> void:
	if crowd_director != null and is_instance_valid(crowd_director) and crowd_director.has_method("cancel_attack_requests"):
		crowd_director.call("cancel_attack_requests", self)
	attack_permission_waiting = false

func _has_authoritative_attack_permission() -> bool:
	if not attack_permission_claimed or attack_permission_target == null or not is_instance_valid(attack_permission_target):
		return false
	if crowd_director == null or not is_instance_valid(crowd_director):
		return true
	if crowd_director.has_method("is_attack_lease_valid"):
		return bool(crowd_director.call("is_attack_lease_valid", self, attack_permission_target, attack_permission_token))
	if crowd_director.has_method("has_attack_permission"):
		return bool(crowd_director.call("has_attack_permission", self, attack_permission_target))
	return true

func _play_signature_attack() -> bool:
	if signature_animations.is_empty() or randf() > signature_chance:
		return false
	if signature_source == &"ual2" and ai_animation_driver != null:
		return bool(ai_animation_driver.play_authored_attack(signature_animations, ai_attack_anim_speed, false, 0.52))
	# Proximity-gated training legions use the lightweight donor directly. They
	# still keep their authored class signature without allocating one complete
	# AnimationTree/driver per soldier.
	if signature_source != &"ual1" and signature_source != &"ual2":
		return false
	if animation_player == null:
		return false
	for candidate: Variant in signature_animations:
		var clip := StringName(candidate)
		if not animation_player.has_animation(clip):
			continue
		var animation := animation_player.get_animation(clip)
		if animation != null:
			animation.loop_mode = Animation.LOOP_NONE
			simple_anim_lock_timer = maxf(0.25, animation.length / maxf(ai_attack_anim_speed, 0.05))
		animation_player.play(clip, 0.04, ai_attack_anim_speed)
		simple_anim_state = clip
		return true
	return false

func _spawn_ai_projectile(target: Node3D) -> void:
	if get_tree().current_scene == null or target == null:
		return
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin := global_position + Vector3.UP * 1.38 + forward * 0.62
	if sword_attachment != null and is_instance_valid(sword_attachment):
		origin = sword_attachment.global_position + Vector3.UP * 0.10 + forward * 0.38
	var aim_point := target.global_position + Vector3.UP * 1.05
	if target.has_method("get_combat_aim_point"):
		aim_point = target.call("get_combat_aim_point") as Vector3
	var distance := origin.distance_to(aim_point)
	var travel_time := distance / maxf(projectile_speed, 1.0)
	if target is CharacterBody3D:
		aim_point += (target as CharacterBody3D).velocity * travel_time * 0.62
	aim_point.y += 0.5 * projectile_gravity * travel_time * travel_time
	var direction := (aim_point - origin).normalized()
	direction = (direction + Vector3(
		randf_range(-projectile_spread, projectile_spread),
		randf_range(-projectile_spread, projectile_spread),
		randf_range(-projectile_spread, projectile_spread)
	)).normalized()
	var projectile = EnemyProjectileScript.acquire(get_tree().current_scene, projectile_kind)
	projectile.name = "%sProjectile" % String(projectile_kind).capitalize()
	var target_mask: int = (1 | 4) if faction == &"spartan" else (1 | 2)
	projectile.setup(self, origin, direction * projectile_speed, ai_attack_damage, projectile_kind, projectile_gravity, target_mask)

func _has_clear_projectile_lane(target: Node3D) -> bool:
	if target == null or get_world_3d() == null:
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	var origin := global_position + Vector3.UP * 1.38 + forward.normalized() * 0.62
	var aim := target.global_position + Vector3.UP * 1.05
	if target.has_method("get_combat_aim_point"):
		aim = target.call("get_combat_aim_point") as Vector3
	var query := PhysicsRayQueryParameters3D.create(origin, aim, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _ai_update_animation_speed() -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var leg_count: int = _lost_leg_count()
	if defense_timer > 0.0:
		# Guard owns the upper body/pose until the defensive window closes. The
		# old locomotion update replaced Idle_Shield in the same physics frame,
		# which made package-based enemies look as though they never defended.
		return
	if uses_mixamo_visual:
		_update_mixamo_locomotion(horizontal_speed, leg_count)
		return
	if ai_animation_driver != null:
		if leg_count >= 2:
			# No dedicated crawl clip exists in UAL1, so keep modest upper-body motion
			# while the visual root is lowered/leaned by _update_injury_visual().
			ai_animation_driver.set_locomotion(0.24 if horizontal_speed > 0.08 else 0.0)
		else:
			ai_animation_driver.set_locomotion(clampf(horizontal_speed / 7.2, 0.0, 1.0))
		return

	var lightweight_package_animation := uses_spartan_package_visual and ai_animation_driver == null
	if (not mass_battle_mode and not lightweight_package_animation) or animation_player == null or dead:
		return
	if ai_attack_pending or ai_attack_recovery_timer > 0.0 or simple_anim_lock_timer > 0.0:
		return

	var desired: StringName = &"Idle"
	var speed_scale: float = 1.0
	if horizontal_speed > 0.14:
		desired = &"Jog_Fwd" if animation_player.has_animation("Jog_Fwd") else &"Walk"
		speed_scale = clampf(horizontal_speed / 4.9, 0.45, 1.45)
	elif animation_player.has_animation("Sword_Idle"):
		desired = &"Sword_Idle"

	_play_simple_loop(desired, speed_scale)

func _play_simple_loop(clip: StringName, speed_scale: float = 1.0) -> void:
	if animation_player == null or clip == StringName() or not animation_player.has_animation(clip):
		return
	if simple_anim_state == clip and animation_player.is_playing():
		return
	var anim: Animation = animation_player.get_animation(clip)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(clip, 0.08, speed_scale)
	simple_anim_state = clip

func _play_mass_attack_animation() -> void:
	if animation_player == null:
		return
	# A sword swing reads as a thrown javelin once a bow is attached to the left
	# hand. Large crowds without the selective bow donor therefore hold a neutral
	# pose for the release instead of borrowing any melee or pistol clip.
	if weapon_kind == &"bow":
		var bow_fallback: StringName = &"Idle"
		if animation_player.has_animation(bow_fallback):
			var bow_anim := animation_player.get_animation(bow_fallback)
			if bow_anim != null:
				bow_anim.loop_mode = Animation.LOOP_NONE
			simple_anim_lock_timer = maxf(0.28, active_attack_windup_total + 0.12)
			animation_player.play(bow_fallback, 0.06, 0.82)
			simple_anim_state = bow_fallback
		return
	var clip: StringName = &"Sword_Attack"
	if not animation_player.has_animation(clip):
		clip = &"Punch_Cross" if animation_player.has_animation("Punch_Cross") else &"Idle"
	if not animation_player.has_animation(clip):
		return
	var anim: Animation = animation_player.get_animation(clip)
	if anim != null:
		anim.loop_mode = Animation.LOOP_NONE
		simple_anim_lock_timer = maxf(0.22, anim.length / maxf(ai_attack_anim_speed, 0.05))
	else:
		simple_anim_lock_timer = 0.45
	animation_player.play(clip, 0.035, ai_attack_anim_speed)
	simple_anim_state = clip

func _update_mixamo_locomotion(horizontal_speed: float, leg_count: int) -> void:
	if animation_player == null or dead:
		return
	if ai_attack_pending or ai_attack_recovery_timer > 0.0 or simple_anim_lock_timer > 0.0:
		return
	var desired := StringName(mixamo_clips.get("idle", StringName()))
	var speed_scale: float = 0.88
	if horizontal_speed > 0.14 and leg_count < 2:
		desired = StringName(mixamo_clips.get("move", desired))
		speed_scale = clampf(horizontal_speed / 4.7, 0.55, 1.55)
	_play_simple_loop(desired, speed_scale)

func _play_mixamo_attack_animation() -> void:
	if animation_player == null:
		return
	var attacks: Array = mixamo_clips.get("attacks", [])
	if attacks.is_empty():
		return
	var choice_index: int = (mixamo_attack_cursor + ai_guard_index * 3 + randi()) % attacks.size()
	mixamo_attack_cursor = (mixamo_attack_cursor + 1) % attacks.size()
	var clip := StringName(attacks[choice_index])
	if not animation_player.has_animation(clip):
		return
	var animation := animation_player.get_animation(clip)
	var desired_duration: float = clampf(ai_attack_windup + ai_attack_recovery + 0.58, 0.72, 1.42)
	var playback_speed: float = ai_attack_anim_speed
	if animation != null:
		playback_speed = clampf(animation.length / desired_duration, 0.72, 3.25) * ai_attack_anim_speed
		simple_anim_lock_timer = animation.length / maxf(playback_speed, 0.05)
	else:
		simple_anim_lock_timer = desired_duration
	animation_player.play(clip, 0.055, playback_speed)
	simple_anim_state = clip

func _play_mixamo_reaction() -> bool:
	if not uses_mixamo_visual or animation_player == null or ai_attack_pending or ai_attack_recovery_timer > 0.0 or mixamo_reaction_cooldown > 0.0:
		return false
	var clip := StringName(mixamo_clips.get("reaction", StringName()))
	if clip == StringName() or not animation_player.has_animation(clip):
		return false
	var animation := animation_player.get_animation(clip)
	var playback_speed: float = 1.55
	simple_anim_lock_timer = minf(0.58, animation.length / playback_speed) if animation != null else 0.42
	mixamo_reaction_cooldown = 0.70
	animation_player.play(clip, 0.035, playback_speed)
	simple_anim_state = clip
	return true

func _play_hit_reaction() -> bool:
	if _play_mixamo_reaction():
		return true
	if ai_animation_driver != null and ai_animation_driver.has_method("play_block_impact"):
		ai_animation_driver.begin_block()
		if ai_animation_driver.play_block_impact():
			return true
		ai_animation_driver.end_block()
	# Some authored packages intentionally ship no block/hit donor. They still
	# receive a deterministic, bounded root-independent recoil instead of a
	# silent impact. The CharacterBody transform and physics remain untouched.
	if visual_root == null:
		return false
	var original_roll := visual_root.rotation.z
	visual_root.rotation.z = original_roll + 0.18
	var recoil := create_tween()
	recoil.tween_interval(0.35)
	recoil.tween_property(visual_root, "rotation:z", original_roll, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return true

func _ai_face_direction(direction: Vector3, delta: float) -> void:
	var flat: Vector3 = direction
	flat.y = 0.0
	if flat.length() < 0.001:
		return
	flat = flat.normalized()
	var target_yaw: float = atan2(-flat.x, -flat.z)
	if _is_phalanx_unit():
		var yaw_delta := wrapf(target_yaw - rotation.y, -PI, PI)
		# The arc must visibly unfold. A modest emergency cadence keeps the shield
		# response deliberate instead of snapping every hoplite through 180 degrees.
		var emergency_turn_multiplier := 1.58 if formation_state == &"expulsion_arc" else 1.0
		var allowed_turn := formation_turn_speed * emergency_turn_multiplier * delta
		rotation.y += clampf(yaw_delta, -allowed_turn, allowed_turn)
		return
	var amount: float = clampf(1.0 - exp(-ai_turn_response * delta), 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, amount)

func _combat_facing_direction(movement_direction: Vector3, attack_player: bool) -> Vector3:
	# Separation and engagement-slot steering can reverse from one think tick to
	# the next when several fighters overlap. In combat those vectors control feet,
	# not facing: keeping eyes on the opponent removes the rapid 180-degree loop
	# and also keeps the shield's frontal arc meaningful.
	if _is_phalanx_unit() and formation_facing.length_squared() > 0.001:
		return formation_facing
	if attack_player and ai_player != null and is_instance_valid(ai_player):
		var toward_target: Vector3 = ai_player.global_position - global_position
		toward_target.y = 0.0
		if toward_target.length_squared() > 0.001:
			return toward_target
	return movement_direction

func alert_ai(duration: float = 8.0) -> void:
	ai_alert_timer = maxf(ai_alert_timer, duration)

func is_ai_participating_for_combat() -> bool:
	return ai_enabled and not dead

func set_ai_participation(enabled: bool) -> void:
	if dead and enabled:
		return
	if not enabled:
		_release_attack_permission(true)
		_set_combat_target(null)
		ai_attack_pending = false
		ai_attack_windup_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		cached_ai_goal.clear()
		cached_ai_separation = Vector3.ZERO
		if navigation_component != null:
			navigation_component.clear_destination()
	ai_enabled = enabled
	collision_mask = (1 | 2) if ai_enabled else 1
	if not is_inside_tree():
		return
	if ai_enabled:
		set_physics_process(true)
		add_to_group("combatant_ai")
		add_to_group("ally_ai" if faction == &"spartan" else "enemy_ai")
		if _is_phalanx_unit():
			add_to_group("phalanx_unit")
		if ai_player == null and battle_player != null and is_instance_valid(battle_player):
			ai_player = battle_player
		_build_navigation_component()
		ai_think_timer = 0.0
	else:
		remove_from_group("combatant_ai")
		remove_from_group("ally_ai")
		remove_from_group("enemy_ai")
		remove_from_group("phalanx_unit")
		set_physics_process(false)
	_invalidate_crowd_membership()
	if combatant_registry != null and is_instance_valid(combatant_registry) and combatant_registry.has_method("refresh_liveness"):
		combatant_registry.call("refresh_liveness", self)

func configure_demo_patrol(points: Array[Vector3], phase: int = 0, engage_distance: float = 6.5, patrol_speed: float = 0.0) -> void:
	demo_patrol_points = points.duplicate()
	demo_patrol_index = posmod(phase, demo_patrol_points.size()) if not demo_patrol_points.is_empty() else 0
	demo_patrol_enabled = not demo_patrol_points.is_empty()
	demo_patrol_engage_distance = maxf(2.0, engage_distance)
	demo_patrol_move_speed = maxf(0.0, patrol_speed)
	demo_patrol_interrupted = false
	# The package uses the existing lightweight UAL1 loops directly. This is the
	# same inexpensive path used by mass-battle soldiers, without a UAL2 donor tree.
	mass_battle_mode = true
	cached_ai_goal.clear()
	ai_think_timer = 0.0

static func nearest_patrol_index(points: Array[Vector3], from_position: Vector3) -> int:
	if points.is_empty():
		return 0
	var nearest_index := 0
	var nearest_distance_squared := INF
	for index in range(points.size()):
		var offset := points[index] - from_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_index = index
	return nearest_index

func configure_training_activation(center: Vector3, radius: float) -> void:
	training_activation_center = center
	training_activation_radius = maxf(0.0, radius)
	training_activation_pending = training_activation_radius > 0.0
	training_activation_check_timer = randf_range(0.0, 0.18)
	if training_activation_pending:
		ai_state = &"training_wait"

func _update_training_activation(delta: float) -> bool:
	if not training_activation_pending or dead:
		return false
	training_activation_check_timer -= delta
	if training_activation_check_timer > 0.0:
		return true
	training_activation_check_timer = 0.18 + float(ai_guard_index % 3) * 0.025
	var reference := battle_player if battle_player != null and is_instance_valid(battle_player) else ai_player
	if reference == null or not is_instance_valid(reference):
		return true
	var offset: Vector3 = reference.global_position - training_activation_center
	offset.y = 0.0
	if offset.length() > training_activation_radius:
		return true
	training_activation_pending = false
	cached_ai_goal.clear()
	ai_think_timer = 0.0
	ai_attack_cooldown_timer = randf_range(0.30, 0.80)
	ai_state = &"training_awaken"
	_play_idle()
	print("[TRAINING LEGION] Activated %s near %s." % [archetype_name, training_activation_center])
	return false

func _refresh_combat_target() -> void:
	if get_tree() == null:
		return

	# Hostile soldiers want the human first whenever the player is genuinely in
	# their local aggro bubble. A recent attacker may briefly override that choice,
	# allowing a mob to defend itself without pursuing anyone across the whole map.
	if faction != &"spartan":
		if _is_active_retaliation_target():
			_set_combat_target(retaliation_target)
			return
		if battle_player != null and _is_valid_combat_target(battle_player):
			var player_distance: float = _flat_distance_to(battle_player)
			var player_limit: float = ai_aggro_distance * (1.15 if claimed_ai_target == battle_player else 1.0)
			if _is_phalanx_unit() and demo_patrol_enabled and not training_activation_pending:
				# The portal cohort begins assembly at the edge of its training
				# zone, not only after the player reaches ordinary melee aggro.
				player_limit = maxf(player_limit, demo_patrol_engage_distance)
			if player_distance <= player_limit:
				_set_combat_target(battle_player)
				return

	var best: Node3D = null
	var best_score: float = INF
	if crowd_director == null or not is_instance_valid(crowd_director):
		crowd_director = get_tree().get_first_node_in_group("crowd_director")
	var candidates: Array = []
	var used_candidate_snapshot := false
	if crowd_director != null and crowd_director.has_method("target_candidates_for"):
		var candidate_snapshot: Variant = crowd_director.call("target_candidates_for", faction)
		if candidate_snapshot is Array:
			candidates = candidate_snapshot as Array
			used_candidate_snapshot = true
	if not used_candidate_snapshot:
		candidates = get_tree().get_nodes_in_group("enemy" if faction == &"spartan" else "spartan_ally")

	for candidate: Node in candidates:
		if candidate == self or not (candidate is Node3D) or not _is_valid_combat_target(candidate as Node3D):
			continue
		var typed_candidate := candidate as Node3D
		var distance: float = _flat_distance_to(typed_candidate)
		var local_limit: float = ai_aggro_distance * (1.15 if claimed_ai_target == typed_candidate else 1.0)
		if distance > local_limit:
			continue
		var claims: int = int(candidate.get_meta("hoplite_ai_claims", 0))
		if claimed_ai_target == typed_candidate:
			claims = maxi(0, claims - 1)
		var claim_penalty: float = 1.15 if candidate.is_in_group("player") else 2.35
		var stability_bonus: float = 1.2 if claimed_ai_target == typed_candidate else 0.0
		var score: float = distance + float(claims) * claim_penalty - stability_bonus
		if score < best_score:
			best_score = score
			best = candidate as Node3D
	_set_combat_target(best)

func _is_valid_combat_target(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if candidate.has_method("is_dead_for_combat") and bool(candidate.call("is_dead_for_combat")):
		return false
	return true

func _flat_distance_to(candidate: Node3D) -> float:
	var delta_position: Vector3 = candidate.global_position - global_position
	delta_position.y = 0.0
	return delta_position.length()

func _is_active_retaliation_target() -> bool:
	if retaliation_timer <= 0.0 or not _is_valid_combat_target(retaliation_target):
		return false
	return _flat_distance_to(retaliation_target) <= ai_aggro_distance * 1.25

func _register_retaliation(attacker: Node3D) -> void:
	if attacker == null or attacker == self or not _is_valid_combat_target(attacker):
		return
	var hostile: bool = attacker == battle_player or attacker.is_in_group("player")
	if attacker is HopliteAthenianEnemy:
		hostile = (attacker as HopliteAthenianEnemy).faction != faction
	elif faction == &"spartan":
		hostile = attacker.is_in_group("enemy")
	else:
		hostile = attacker.is_in_group("spartan_ally")
	if not hostile:
		return
	retaliation_target = attacker
	retaliation_timer = ai_retaliation_duration
	ai_alert_timer = maxf(ai_alert_timer, ai_retaliation_duration)
	ai_think_timer = 0.0
	cached_ai_goal.clear()

func _set_combat_target(next_target: Node3D) -> void:
	if claimed_ai_target == next_target:
		ai_player = next_target
		return
	_release_attack_permission(true)
	if claimed_ai_target != null and is_instance_valid(claimed_ai_target):
		if crowd_director == null or not is_instance_valid(crowd_director):
			crowd_director = get_tree().get_first_node_in_group("crowd_director") if get_tree() != null else null
		if crowd_director != null and crowd_director.has_method("release_engagement"):
			crowd_director.call("release_engagement", self, claimed_ai_target)
		var old_claims: int = int(claimed_ai_target.get_meta("hoplite_ai_claims", 0))
		claimed_ai_target.set_meta("hoplite_ai_claims", maxi(0, old_claims - 1))
	claimed_ai_target = next_target
	ai_player = next_target
	if claimed_ai_target != null and is_instance_valid(claimed_ai_target):
		var new_claims: int = int(claimed_ai_target.get_meta("hoplite_ai_claims", 0))
		claimed_ai_target.set_meta("hoplite_ai_claims", new_claims + 1)

func hold_battlefield_position() -> void:
	set_ai_participation(false)
	ai_state = &"hold_the_city"
	velocity = Vector3.ZERO
	_set_combat_target(null)

func can_receive_hit_from(source: Node) -> bool:
	return not (faction == &"spartan" and source != null and source.is_in_group("player"))

func receive_ai_hit(damage: float, attacker: Node3D, hit_direction: Vector3) -> bool:
	if dead or attacker == null:
		return false
	if attacker is HopliteAthenianEnemy and (attacker as HopliteAthenianEnemy).faction == faction:
		return false

	var event = HitEventScript.new()
	event.source = attacker
	event.direction = hit_direction.normalized()
	event.normal = -event.direction
	event.damage = damage
	event.sever_damage = damage * 0.52
	event.blade_speed = 7.0
	event.attack_context = &"battlefield_ai"
	event.damage_type = &"slash"

	var roll: float = randf()
	var zone: StringName = &"torso"
	if roll < 0.07:
		zone = &"neck"
	elif roll < 0.20:
		zone = &"upper_arm_l" if randi() % 2 == 0 else &"upper_arm_r"
	elif roll < 0.34:
		zone = &"thigh_l" if randi() % 2 == 0 else &"thigh_r"
	if anatomy != null:
		event.position = anatomy.get_zone_world_center(zone)
	else:
		event.position = global_position + Vector3.UP * 1.1
	receive_anatomy_hit(event, zone)
	return true

func receive_spiral_smash(hit: Variant) -> bool:
	if dead or hit == null or not can_receive_hit_from(hit.source):
		return false

	# A vertical breach opens every active defense, including formation guard.
	# This is a short disengage/stagger rather than deleting the unit's guard
	# stamina, so shield troops can reform after the punish window.
	var guarding: bool = (defense_mode in [&"shield", &"parry"] and defense_timer > 0.0) or _formation_should_guard()
	defense_timer = 0.0
	defense_reaction_timer = -1.0
	defense_cooldown_timer = maxf(defense_cooldown_timer, 0.82 if guarding else 0.46)
	guard_break_timer = maxf(guard_break_timer, 0.46 if guarding else 0.24)
	ai_attack_pending = false
	ai_attack_windup_timer = 0.0
	ai_attack_recovery_timer = maxf(ai_attack_recovery_timer, 0.38 if guarding else 0.26)
	parry_counter_queued = false
	ai_state = &"spiral_smash_stagger"
	_end_defense_window()

	var push: Vector3 = hit.impulse
	push.y = 0.0
	if push.length() < 0.01:
		push = hit.direction.normalized() * 2.8
	var next_flat_velocity := Vector3(velocity.x, 0.0, velocity.z) + push
	if next_flat_velocity.length() > 5.0:
		next_flat_velocity = next_flat_velocity.normalized() * 5.0
	velocity.x = next_flat_velocity.x
	velocity.z = next_flat_velocity.z

	var zone: StringName = StringName(hit.body_part)
	if zone not in [&"thigh_l", &"thigh_r", &"shin_l", &"shin_r"] or _zone_is_severed(zone):
		var leg_candidates: Array[StringName] = [&"thigh_l", &"thigh_r", &"shin_l", &"shin_r"]
		zone = &"torso"
		for candidate: StringName in leg_candidates:
			if anatomy_defs.has(candidate) and not _zone_is_severed(candidate):
				zone = candidate
				break
	hit.body_part = zone
	if anatomy != null:
		hit.position = anatomy.get_zone_world_center(zone)
	else:
		hit.position = global_position + Vector3.UP * (0.58 if zone != &"torso" else 1.05)
	receive_anatomy_hit(hit, zone)
	return true

func _build_body_collider() -> void:
	body_collider = CollisionShape3D.new()
	body_collider.name = "BodyCollider"
	var capsule := CapsuleShape3D.new()
	var radius_multiplier := giant_capsule_radius_multiplier if _uses_assisted_giant_traversal() else 1.0
	var height_multiplier := giant_capsule_height_multiplier if _uses_assisted_giant_traversal() else 1.0
	var base_radius := 0.39 * clampf(radius_multiplier, 0.55, 1.35)
	var base_height := 1.82 * clampf(height_multiplier, 0.80, 1.25)
	capsule.radius = base_radius
	capsule.height = maxf(base_height, capsule.radius * 2.05)
	body_collider.shape = capsule
	body_collider.position = Vector3(0.0, base_height * 0.5, 0.0)
	add_child(body_collider)

func is_wall_run_giant() -> bool:
	return (
		not dead
		and match_perfect_hitbox
		and EnemyArchetypesScript.is_giant(archetype_id)
		and giant_traversal_mode != &"off"
	)

func _uses_assisted_giant_traversal() -> bool:
	return match_perfect_hitbox and EnemyArchetypesScript.is_giant(archetype_id) and giant_traversal_mode == &"assisted"

func _build_matched_physical_colliders() -> void:
	if not match_perfect_hitbox or anatomy == null:
		return
	# The segmented model volumes are excellent hit targets but poor traversal
	# geometry: animated arms expose floor-like facets and side probes receive
	# steep normals. Assisted Forge giants retain one smooth capsule for movement;
	# their anatomy Areas remain fully precise for damage and decapitation.
	if _uses_assisted_giant_traversal():
		_build_assisted_giant_traversal_collider()
		# Keep the CharacterBody shape alive so move_and_slide can resolve the
		# world floor. Removing layer 4 hides this imperfect scaled capsule from
		# the player; only the independent layer-256 surface handles traversal.
		body_collider.disabled = false
		collision_layer = 0
		return
	if giant_traversal_mode == &"off":
		return
	# The uniformly-scaled capsule is the source of the invisible repulsion
	# around giant heads. Prefer convex hulls generated once from the character's
	# real segmented meshes; the skeleton then only moves those model-derived
	# shapes. Older/unsegmented models keep a skeletal-volume fallback.
	_build_model_matched_physical_colliders()
	if matched_physical_colliders.is_empty():
		_build_anatomy_matched_physical_colliders()
	if not matched_physical_colliders.is_empty():
		body_collider.disabled = true
		_update_matched_physical_colliders()

func _build_assisted_giant_traversal_collider() -> void:
	giant_traversal_body = AnimatableBody3D.new()
	giant_traversal_body.name = "GiantTraversalSurface"
	giant_traversal_body.collision_layer = GIANT_TRAVERSAL_SURFACE_LAYER
	giant_traversal_body.collision_mask = 0
	giant_traversal_body.sync_to_physics = true
	giant_traversal_body.top_level = true
	giant_traversal_body.add_to_group("giant_wall_run_surface")
	giant_traversal_body.set_meta("giant_owner", self)
	giant_traversal_collision = CollisionShape3D.new()
	giant_traversal_collision.name = "SmoothShoulderCylinder"
	giant_traversal_body.add_child(giant_traversal_collision)
	add_child(giant_traversal_body)
	_build_assisted_giant_head_collider()
	_refresh_assisted_giant_traversal_shape(false)
	_update_assisted_giant_traversal_collider()

func _build_assisted_giant_head_collider() -> void:
	if anatomy == null or visual_root == null:
		return
	var head_zone_transform := anatomy.get_zone_world_transform(&"head")
	var head_frame := Transform3D(head_zone_transform.basis.orthonormalized(), head_zone_transform.origin)
	for raw_node: Node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if instance == null or instance.mesh == null or _matched_zone_from_model_mesh(instance.name) != &"head":
			continue
		var source_hull := instance.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		if source_hull == null or source_hull.points.size() < 4:
			continue
		var local_points := PackedVector3Array()
		local_points.resize(source_hull.points.size())
		var world_to_head := head_frame.affine_inverse()
		for point_index: int in range(source_hull.points.size()):
			local_points[point_index] = world_to_head * (instance.global_transform * source_hull.points[point_index])
		var fitted_hull := ConvexPolygonShape3D.new()
		fitted_hull.points = local_points
		giant_traversal_head_body = AnimatableBody3D.new()
		giant_traversal_head_body.name = "GiantTraversalHead"
		giant_traversal_head_body.collision_layer = GIANT_TRAVERSAL_SURFACE_LAYER
		giant_traversal_head_body.collision_mask = 0
		giant_traversal_head_body.sync_to_physics = true
		giant_traversal_head_body.top_level = true
		giant_traversal_head_body.add_to_group("giant_wall_run_surface")
		giant_traversal_head_body.set_meta("giant_owner", self)
		giant_traversal_head_collision = CollisionShape3D.new()
		giant_traversal_head_collision.name = "ExactHeadMesh"
		giant_traversal_head_collision.shape = fitted_hull
		giant_traversal_head_collision.set_meta("matched_model_mesh", instance.name)
		giant_traversal_head_body.add_child(giant_traversal_head_collision)
		add_child(giant_traversal_head_body)
		giant_traversal_head_body.global_transform = head_frame
		return

func _refresh_assisted_giant_traversal_shape(crawling: bool) -> void:
	if giant_traversal_collision == null:
		return
	var body_scale := maxf(absf(global_basis.get_scale().y), 0.01)
	var cylinder := giant_traversal_collision.shape as CylinderShape3D
	if cylinder == null:
		cylinder = CylinderShape3D.new()
		giant_traversal_collision.shape = cylinder
	var crawl_radius_scale := 0.82 if crawling else 1.0
	cylinder.radius = 0.39 * clampf(giant_capsule_radius_multiplier, 0.55, 1.35) * body_scale * crawl_radius_scale
	var base_height := (1.28 if crawling else 1.82) * clampf(giant_capsule_height_multiplier, 0.80, 1.25) * body_scale
	cylinder.height = maxf(base_height, 0.10 * body_scale)

func _update_assisted_giant_traversal_collider() -> void:
	if giant_traversal_body == null or giant_traversal_collision == null or dead:
		return
	var cylinder := giant_traversal_collision.shape as CylinderShape3D
	if cylinder == null:
		return
	if anatomy != null:
		# Follow the living core anatomy instead of the unmodified CharacterBody
		# origin. A flat-topped cylinder ends at the shoulder plane, while the real
		# head mesh owns collision above it.
		var body_scale := maxf(absf(global_basis.get_scale().y), 0.01)
		var torso_center := anatomy.get_zone_world_center(&"torso")
		var pelvis_center := anatomy.get_zone_world_center(&"pelvis")
		var head_center := anatomy.get_zone_world_center(&"head")
		var core_center := torso_center * 0.50 + pelvis_center * 0.30 + head_center * 0.20
		var crawling := _lost_leg_count() >= 2
		var natural_bottom := global_position.y
		if crawling:
			natural_bottom = pelvis_center.y - anatomy.get_zone_radius(&"pelvis") * body_scale * 0.72
		# End at the neck/shoulder junction, not at the legacy shoulder walkable
		# plane (which sits above this model's head centre).
		var shoulder_top := minf(torso_center.y + 0.30 * body_scale, head_center.y - 0.08 * body_scale)
		var natural_height := maxf(shoulder_top - natural_bottom, 0.10 * body_scale)
		cylinder.height = natural_height * clampf(giant_capsule_height_multiplier, 0.80, 1.25)
		var bottom := shoulder_top - cylinder.height
		giant_traversal_body.global_transform = Transform3D(
			global_basis.orthonormalized(),
			Vector3(core_center.x, (bottom + shoulder_top) * 0.5, core_center.z)
		)
	if giant_traversal_head_body != null and giant_traversal_head_collision != null and not _zone_is_severed(&"head"):
		var head_zone_transform := anatomy.get_zone_world_transform(&"head")
		giant_traversal_head_body.global_transform = Transform3D(head_zone_transform.basis.orthonormalized(), head_zone_transform.origin)

func _build_model_matched_physical_colliders() -> void:
	if visual_root == null:
		return
	for raw_node: Node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var zone := _matched_zone_from_model_mesh(instance.name)
		if zone == StringName() or matched_physical_colliders.has(zone):
			continue
		var source_hull := instance.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		if source_hull == null or source_hull.points.size() < 4:
			continue
		var zone_transform := anatomy.get_zone_world_transform(zone)
		var world_to_zone := zone_transform.affine_inverse()
		var fitted_points := PackedVector3Array()
		fitted_points.resize(source_hull.points.size())
		for point_index: int in range(source_hull.points.size()):
			var point_world: Vector3 = instance.global_transform * source_hull.points[point_index]
			fitted_points[point_index] = world_to_zone * point_world
		var fitted_hull := ConvexPolygonShape3D.new()
		fitted_hull.points = fitted_points
		var collision := CollisionShape3D.new()
		collision.name = "ModelPhysical_%s" % String(zone)
		collision.shape = fitted_hull
		collision.set_meta("matched_physical_zone", zone)
		collision.set_meta("matched_model_mesh", instance.name)
		add_child(collision)
		matched_physical_colliders[zone] = collision

func _matched_zone_from_model_mesh(mesh_name: String) -> StringName:
	var normalized := mesh_name.to_lower()
	for zone: StringName in [
		&"upper_arm_l", &"upper_arm_r", &"forearm_l", &"forearm_r",
		&"thigh_l", &"thigh_r", &"shin_l", &"shin_r", &"head", &"torso"
	]:
		if "body_%s" % String(zone) in normalized:
			return zone
	return StringName()

func _build_anatomy_matched_physical_colliders() -> void:
	for raw_zone: Variant in anatomy.zone_runtime.keys():
		var zone := StringName(raw_zone)
		var runtime: Dictionary = anatomy.zone_runtime[zone]
		var collision := CollisionShape3D.new()
		collision.name = "Physical_%s" % String(zone)
		collision.set_meta("matched_physical_zone", zone)
		if StringName(runtime.get("shape", &"sphere")) == &"capsule":
			collision.shape = CapsuleShape3D.new()
		else:
			collision.shape = SphereShape3D.new()
		add_child(collision)
		matched_physical_colliders[zone] = collision

func _update_matched_physical_colliders() -> void:
	if matched_physical_colliders.is_empty() or anatomy == null or dead:
		return
	var body_scale := maxf(global_basis.get_scale().y, 0.01)
	for raw_zone: Variant in matched_physical_colliders.keys():
		var zone := StringName(raw_zone)
		var collision := matched_physical_colliders[zone] as CollisionShape3D
		if collision == null:
			continue
		var zone_enabled := _matched_physical_zone_enabled(zone)
		if collision.disabled == zone_enabled:
			collision.set_deferred("disabled", not zone_enabled)
		if not zone_enabled:
			continue
		var radius_world := anatomy.get_zone_radius(zone) * body_scale
		if collision.shape is CapsuleShape3D:
			var capsule := collision.shape as CapsuleShape3D
			capsule.radius = radius_world
			capsule.height = maxf(anatomy.get_zone_length(zone) + radius_world * 2.0, radius_world * 2.05)
		elif collision.shape is SphereShape3D:
			(collision.shape as SphereShape3D).radius = radius_world
		# The transform supplied by AnatomyHitbox is world-space and unscaled;
		# dimensions above are therefore explicitly converted to world metres.
		collision.global_transform = anatomy.get_zone_world_transform(zone)

func _matched_physical_zone_enabled(zone: StringName) -> bool:
	if _zone_is_severed(zone):
		return false
	if zone == &"forearm_l" and _zone_is_severed(&"upper_arm_l"):
		return false
	if zone == &"forearm_r" and _zone_is_severed(&"upper_arm_r"):
		return false
	if zone == &"shin_l" and _zone_is_severed(&"thigh_l"):
		return false
	if zone == &"shin_r" and _zone_is_severed(&"thigh_r"):
		return false
	return true

func _set_matched_physical_colliders_enabled(enabled: bool) -> void:
	for raw_collision: Variant in matched_physical_colliders.values():
		var collision := raw_collision as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", not enabled)
	if giant_traversal_body != null:
		giant_traversal_body.collision_layer = GIANT_TRAVERSAL_SURFACE_LAYER if enabled else 0
	if giant_traversal_collision != null:
		giant_traversal_collision.set_deferred("disabled", not enabled)
	if giant_traversal_head_body != null:
		giant_traversal_head_body.collision_layer = GIANT_TRAVERSAL_SURFACE_LAYER if enabled else 0
	if giant_traversal_head_collision != null:
		giant_traversal_head_collision.set_deferred("disabled", not enabled)

func _build_matched_walkable_surfaces() -> void:
	if not match_perfect_hitbox or anatomy == null or giant_traversal_mode == &"off" or not giant_walkable_tops:
		return
	if _uses_assisted_giant_traversal():
		# The smooth cylinder already provides the shoulder ledge. Only retain a
		# compact stabilizer on the exact head hull; the old wide shoulder box cut
		# through the head and blocked close approaches.
		_add_matched_walkable_surface("HeadFloor", Vector3(0.62, 0.08, 0.54))
		_update_matched_walkable_surfaces()
		return
	_add_matched_walkable_surface("ShoulderFloor", Vector3(1.18, 0.10, 0.48))
	# Slightly wider than the anatomical head so the player's own capsule can
	# reach the top without being pushed off by the rounded head volume.
	_add_matched_walkable_surface("HeadFloor", Vector3(0.62, 0.08, 0.54))
	_update_matched_walkable_surfaces()

func _add_matched_walkable_surface(surface_name: String, reference_size: Vector3) -> void:
	var surface := AnimatableBody3D.new()
	surface.name = surface_name
	surface.collision_layer = MATCHED_WALKABLE_SURFACE_LAYER
	surface.collision_mask = 0
	surface.sync_to_physics = true
	surface.top_level = true
	surface.add_to_group("enemy_walkable_surface")
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = reference_size
	collision.shape = box
	surface.add_child(collision)
	add_child(surface)
	matched_walkable_surfaces.append(surface)

func _update_matched_walkable_surfaces() -> void:
	if matched_walkable_surfaces.is_empty() or anatomy == null or dead:
		return
	# Anatomy already follows the active skeleton and the injury presentation.
	# Keep the support planes horizontal, but inherit the enemy's yaw and scale.
	var body_scale := maxf(global_basis.get_scale().y, 0.01)
	var horizontal_basis := global_basis.orthonormalized().scaled(Vector3.ONE * body_scale)
	var torso_center := anatomy.get_zone_world_center(&"torso")
	var head_center := anatomy.get_zone_world_center(&"head")
	var head_radius := anatomy.get_zone_radius(&"head") * body_scale
	var torso_top := _matched_model_collider_world_top(&"torso")
	var head_top := _assisted_head_collider_world_top() if _uses_assisted_giant_traversal() else _matched_model_collider_world_top(&"head")
	var shoulder_floor_y := torso_top if is_finite(torso_top) else torso_center.y + 0.36 * body_scale
	var head_floor_y := head_top if is_finite(head_top) else head_center.y + head_radius + 0.025 * body_scale
	for surface: AnimatableBody3D in matched_walkable_surfaces:
		if surface.name == "ShoulderFloor":
			surface.global_transform = Transform3D(horizontal_basis, Vector3(torso_center.x, shoulder_floor_y, torso_center.z))
		elif surface.name == "HeadFloor":
			surface.global_transform = Transform3D(horizontal_basis, Vector3(head_center.x, head_floor_y, head_center.z))

func _assisted_head_collider_world_top() -> float:
	if giant_traversal_head_body == null or giant_traversal_head_collision == null or not giant_traversal_head_collision.shape is ConvexPolygonShape3D:
		return -INF
	var hull := giant_traversal_head_collision.shape as ConvexPolygonShape3D
	var highest := -INF
	for point: Vector3 in hull.points:
		highest = maxf(highest, (giant_traversal_head_body.global_transform * point).y)
	return highest

func _matched_model_collider_world_top(zone: StringName) -> float:
	var collision := matched_physical_colliders.get(zone) as CollisionShape3D
	if collision == null or not collision.shape is ConvexPolygonShape3D:
		return -INF
	var hull := collision.shape as ConvexPolygonShape3D
	var highest := -INF
	for point: Vector3 in hull.points:
		highest = maxf(highest, (collision.global_transform * point).y)
	return highest

func _set_matched_walkable_surfaces_enabled(enabled: bool) -> void:
	for surface: AnimatableBody3D in matched_walkable_surfaces:
		if surface == null or not is_instance_valid(surface):
			continue
		surface.collision_layer = MATCHED_WALKABLE_SURFACE_LAYER if enabled else 0
		for child: Node in surface.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", not enabled)

func _refresh_body_collider_for_injury() -> void:
	if body_collider == null or not body_collider.shape is CapsuleShape3D:
		return
	var crawling := _lost_leg_count() >= 2
	var capsule := body_collider.shape as CapsuleShape3D
	if _uses_assisted_giant_traversal():
		var internal_radius := 0.39 * clampf(giant_capsule_radius_multiplier, 0.55, 1.35)
		var internal_height := (1.28 if crawling else 1.82) * clampf(giant_capsule_height_multiplier, 0.80, 1.25)
		capsule.radius = internal_radius
		capsule.height = maxf(internal_height, internal_radius * 2.05)
		body_collider.position.y = internal_height * 0.5
		_refresh_assisted_giant_traversal_shape(crawling)
		_update_assisted_giant_traversal_collider()
		return
	capsule.height = 1.28 if crawling else 1.82
	body_collider.position.y = 0.64 if crawling else 0.91

func _load_mannequin() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Athenian_%s_Visual" % archetype_name
	add_child(visual_root)
	visual_root.rotation.y = PI

	# A validated per-archetype Mixamo override is explicit test/authored intent and
	# must win over the normal package-first route. Invalid cross-pool overrides do
	# not bypass the canonical package.
	var forced_mixamo_appearance: Dictionary = {}
	if faction != &"spartan" and mixamo_model_override != StringName():
		forced_mixamo_appearance = MixamoCatalogScript.appearance_for_model(archetype_id, mixamo_model_override)
		if forced_mixamo_appearance.is_empty():
			push_warning("Rejected Mixamo override %s outside archetype pool %s; using canonical selection." % [mixamo_model_override, archetype_id])
	if forced_mixamo_appearance.is_empty() and not character_package_path.is_empty() and _try_load_spartan_character_package():
		_finish_mannequin_setup()
		return

	var packed_path: String = UAL1_PATH
	if faction != &"spartan":
		var appearance: Dictionary = forced_mixamo_appearance
		if appearance.is_empty():
			appearance = MixamoCatalogScript.appearance(archetype_id, ai_guard_index, get_instance_id(), mass_battle_mode)
		var candidate_path: String = String(appearance.get("path", ""))
		if not candidate_path.is_empty() and ResourceLoader.exists(candidate_path):
			packed_path = candidate_path
			mixamo_model_id = StringName(appearance.get("id", StringName()))
			visual_root.scale = Vector3.ONE * float(appearance.get("scale", 1.0))
			visual_ground_offset = float(appearance.get("ground_offset", 0.0))
			visual_root.position.y = visual_ground_offset
			uses_mixamo_visual = true

	var packed: PackedScene = load(packed_path) as PackedScene
	if packed == null:
		_make_missing_marker()
		return

	mannequin_scene = packed.instantiate()
	visual_root.add_child(mannequin_scene)
	_disable_animation_trees(mannequin_scene)
	skeleton = _find_skeleton(mannequin_scene)
	animation_player = _find_best_animation_player(mannequin_scene)
	if skeleton == null or animation_player == null:
		_make_missing_marker()
		return

	animation_player.stop()
	if uses_mixamo_visual:
		mixamo_clips = MixamoCatalogScript.install_personality(animation_player, archetype_id)
	else:
		_tint_body()
	right_hand_bone = _find_hand_bone(true)
	left_hand_bone = _find_hand_bone(false)
	if uses_mixamo_visual:
		_build_mixamo_weapon()
	else:
		_build_equipment()
	if mass_battle_mode:
		_set_visual_shadows_enabled(visual_root, false)
	if ai_enabled and not mass_battle_mode and not uses_mixamo_visual:
		_setup_ai_animation_driver()
	elif uses_mixamo_visual and is_miniboss:
		_play_mixamo_intro()
	else:
		_play_idle()

	_finish_mannequin_setup()

func _finish_mannequin_setup() -> void:
	anatomy_defs = AnatomyProfileScript.default_humanoid()
	for raw_zone: Variant in anatomy_defs.keys():
		zone_state[StringName(raw_zone)] = {
			"sever": 0.0,
			"damage": 0.0,
			"severed": false
		}

	anatomy = AnatomyScript.new() as HopliteAnatomyHitbox
	anatomy.name = "AnatomyHitbox"
	add_child(anatomy)
	anatomy.configure(self, skeleton, anatomy_defs)
	anatomy.set_debug_visible(combat_debug_visible)

	# Label3D and debug geometry are lazy: the battlefield starts clean and cheap.
	if combat_debug_visible:
		_ensure_status_label()

	if not anatomy.debug_missing_bones.is_empty():
		print("[ATHENIAN] Missing anatomy bones: ", anatomy.debug_missing_bones)
	elif combat_debug_visible:
		print("[ATHENIAN ANATOMY MAP] ", anatomy.debug_mapping_summary())

	_update_performance_lod()

func _try_load_spartan_character_package() -> bool:
	var candidate_scene := _character_package_scene(character_package_path)
	if candidate_scene == null:
		push_warning("[SPARTAN PACKAGE] Missing resource: %s; using legacy visual." % character_package_path)
		return false
	var candidate_root := candidate_scene.instantiate() as Node3D
	if candidate_root == null:
		push_warning("[SPARTAN PACKAGE] Could not instantiate package; using legacy visual.")
		return false
	visual_root.add_child(candidate_root)

	var candidate_adapter = SpartanPackageScript.new()
	if not candidate_adapter.bind(candidate_root):
		if _uses_shared_hoplite_animation() and _finish_clean_hoplite_package(candidate_scene, candidate_root):
			return true
		push_warning("[SPARTAN PACKAGE] Validation failed (%s); using legacy visual." % candidate_adapter.validation_error)
		visual_root.remove_child(candidate_root)
		candidate_root.free()
		return false
	if _uses_shared_hoplite_animation():
		return _finish_shared_hoplite_package(candidate_scene, candidate_root, candidate_adapter)

	var donor_packed := load(UAL1_PATH) as PackedScene
	var donor_root := donor_packed.instantiate() as Node3D if donor_packed != null else null
	if donor_root == null:
		push_warning("[SPARTAN PACKAGE] UAL1 animation donor missing; using legacy visual.")
		visual_root.remove_child(candidate_root)
		candidate_root.free()
		return false
	donor_root.name = "SpartanUALAnimationDonor"
	donor_root.visible = false
	add_child(donor_root)
	_disable_animation_trees(donor_root)
	var donor_skeleton := _find_skeleton(donor_root)
	var donor_player := _find_best_animation_player(donor_root)
	if donor_skeleton == null or donor_player == null:
		push_warning("[SPARTAN PACKAGE] UAL1 animation donor is incomplete; using legacy visual.")
		donor_root.queue_free()
		visual_root.remove_child(candidate_root)
		candidate_root.free()
		return false

	var bridge := AuthoredPoseBridgeScript.new() as HopliteAuthoredPoseBridge
	bridge.name = "SpartanPackagePoseBridge"
	candidate_adapter.skeleton.add_child(bridge)
	bridge.set_rest_space_retarget(true)
	if not bridge.configure(donor_skeleton):
		push_warning("[SPARTAN PACKAGE] UAL animation mapping failed; using legacy visual.")
		donor_root.queue_free()
		visual_root.remove_child(candidate_root)
		candidate_root.free()
		return false
	bridge.set_attack_weight(1.0, true, 1.0)

	mannequin_scene = candidate_root
	skeleton = candidate_adapter.skeleton
	animation_player = donor_player
	spartan_animation_donor = donor_root
	spartan_pose_bridge = bridge
	spartan_package_scene = candidate_scene
	spartan_package_adapter = candidate_adapter
	uses_spartan_package_visual = true
	_register_gore_package()
	right_hand_bone = _find_hand_bone(true)
	left_hand_bone = _find_hand_bone(false)
	_build_character_package_equipment()
	# Generic troops use the package's single UAL1 donor directly. Weapon roles
	# that explicitly request a selective donor need the retarget driver too;
	# mass crowds still stay on the cheap procedural/UAL1 fallback.
	var needs_specialized_driver := AnimationRuntimeContract.needs_specialized_driver_values(
		combat_rank,
		behavior_mode,
		weapon_kind,
		external_animation_keys
	)
	if ai_enabled and not mass_battle_mode and needs_specialized_driver:
		_setup_ai_animation_driver()
	else:
		_play_idle()
	# Let the donor AnimationPlayer and pose bridge evaluate before measuring the
	# animated feet. This removes exporter/root-height differences without a
	# model-specific magic number and works on future packages using the same rig.
	spartan_grounding_frames = 20
	if not _reported_character_packages.has(character_package_path):
		print("[SPARTAN PACKAGE] Loaded %s (53 bones, segmented gore, UAL1 animation donor)." % character_package_path)
		_reported_character_packages[character_package_path] = true
	return true


func _finish_clean_hoplite_package(candidate_scene: PackedScene, candidate_root: Node3D) -> bool:
	# Clean UAL1 exports intentionally keep one skinned body mesh instead of the
	# segmented SPARTAN_ASSET gore schema. They can still use the exact shared
	# animation/equipment/anatomy path when the canonical 53-bone rig is intact.
	_disable_animation_trees(candidate_root)
	var candidate_skeleton := _find_skeleton(candidate_root)
	if candidate_skeleton == null or candidate_skeleton.get_bone_count() != 53:
		return false
	# Blender disambiguates the armature object and its root bone with the same
	# source name. Godot may consequently import the bone as root_2; normalize it
	# so the baked shared-library tracks targeting .:root resolve correctly.
	if candidate_skeleton.find_bone("root") < 0:
		for bone_index: int in range(candidate_skeleton.get_bone_count()):
			var imported_name := String(candidate_skeleton.get_bone_name(bone_index))
			if candidate_skeleton.get_bone_parent(bone_index) < 0 and imported_name.begins_with("root_"):
				for mesh_node: Node in candidate_root.find_children("*", "MeshInstance3D", true, false):
					var mesh_instance := mesh_node as MeshInstance3D
					if mesh_instance.skin == null:
						continue
					var instance_skin := mesh_instance.skin.duplicate() as Skin
					for bind_index: int in range(instance_skin.get_bind_count()):
						if String(instance_skin.get_bind_name(bind_index)) == imported_name:
							instance_skin.set_bind_name(bind_index, "root")
					mesh_instance.skin = instance_skin
				candidate_skeleton.set_bone_name(bone_index, "root")
				break
	for bone_name: String in [
		"root", "DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003",
		"DEF-neck", "DEF-head", "DEF-hand.L", "DEF-hand.R",
		"DEF-thigh.L", "DEF-shin.L", "DEF-foot.L",
		"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R",
	]:
		if candidate_skeleton.find_bone(bone_name) < 0:
			return false
	for player_node: Node in candidate_root.find_children("*", "AnimationPlayer", true, false):
		(player_node as AnimationPlayer).stop()
		player_node.queue_free()

	mannequin_scene = candidate_root
	skeleton = candidate_skeleton
	animation_player = AnimationPlayer.new()
	animation_player.name = "HopliteAnimationPlayer"
	animation_player.root_node = NodePath("..")
	skeleton.add_child(animation_player)
	spartan_package_scene = candidate_scene
	spartan_package_adapter = null
	uses_spartan_package_visual = true
	right_hand_bone = _find_hand_bone(true)
	left_hand_bone = _find_hand_bone(false)
	_build_character_package_equipment()
	_setup_ai_animation_driver()
	if ai_animation_driver == null:
		return false
	spartan_grounding_frames = 20
	if not _reported_character_packages.has(character_package_path):
		print("[HOPLITE CLEAN MODEL] Loaded %s (one skinned mesh, shared clips)." % character_package_path)
		_reported_character_packages[character_package_path] = true
	return true


func _finish_shared_hoplite_package(candidate_scene: PackedScene, candidate_root: Node3D, candidate_adapter: RefCounted) -> bool:
	mannequin_scene = candidate_root
	skeleton = candidate_adapter.get("skeleton") as Skeleton3D
	if skeleton == null:
		push_error("[HOPLITE SHARED ANIMATION] ngeneral package lost its canonical skeleton")
		return false
	if not candidate_adapter.call("optimize_body_meshes"):
		push_warning("[HOPLITE BODY] could not merge the ten skinned body zones; segmented fallback kept")
	animation_player = AnimationPlayer.new()
	animation_player.name = "HopliteAnimationPlayer"
	animation_player.root_node = NodePath("..")
	skeleton.add_child(animation_player)
	spartan_package_scene = candidate_scene
	spartan_package_adapter = candidate_adapter
	uses_spartan_package_visual = true
	_register_gore_package()
	right_hand_bone = _find_hand_bone(true)
	left_hand_bone = _find_hand_bone(false)
	_build_character_package_equipment()
	_setup_ai_animation_driver()
	if ai_animation_driver == null:
		push_error("[HOPLITE SHARED ANIMATION] shared driver setup failed")
		return false
	spartan_grounding_frames = 20
	if not _reported_character_packages.has(character_package_path):
		print("[HOPLITE SHARED ANIMATION] Loaded %s (one visible skeleton, shared clips, no donors)." % character_package_path)
		_reported_character_packages[character_package_path] = true
	return true

func _character_package_scene(path: String) -> PackedScene:
	return RuntimeGLTFCacheScript.scene(path)

func _ground_spartan_package_visual() -> void:
	if skeleton == null or visual_root == null:
		return
	var lowest_foot_y: float = INF
	for bone_name: String in ["DEF-foot.L", "DEF-toe.L", "DEF-foot.R", "DEF-toe.R"]:
		var bone_index: int = skeleton.find_bone(bone_name)
		if bone_index >= 0:
			var bone_world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin)
			lowest_foot_y = minf(lowest_foot_y, bone_world.y)
	if is_inf(lowest_foot_y):
		push_warning("[SPARTAN PACKAGE] Could not ground visual: foot bones missing.")
		return

	var floor_y: float = global_position.y
	var world := get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 2.5,
			global_position + Vector3.DOWN * 3.0,
			1,
			[get_rid()]
		)
		var collision: Dictionary = world.direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			# Decorative training pads are intentionally non-colliding; never snap
			# through one to a lower world floor behind the character origin.
			floor_y = maxf(floor_y, (collision.get("position", global_position) as Vector3).y)

	# Toe bones sit about 1.5 cm above the actual sole on the UAL reference rig.
	var correction: float = clampf(floor_y + 0.015 - lowest_foot_y, -1.50, 1.50)
	# correction is measured in world metres while visual_root.position is local.
	# Dividing by the inherited Y scale prevents overshoot/oscillation at x2+.
	var world_scale_y := maxf(absf(global_basis.get_scale().y), 0.01)
	visual_root.position.y += correction / world_scale_y
	visual_ground_offset = visual_root.position.y
	if combat_debug_visible:
		print("[SPARTAN PACKAGE] Grounded visual by %.3f m (floor %.3f, foot %.3f)." % [correction, floor_y, lowest_foot_y])

func _build_character_package_equipment() -> void:
	if skeleton == null or right_hand_bone.is_empty():
		return
	if weapon_kind != &"unarmed":
		sword_attachment = BoneAttachment3D.new()
		sword_attachment.name = "SpartanPackageWeaponAttachment"
		sword_attachment.bone_name = left_hand_bone if weapon_kind == &"bow" and not left_hand_bone.is_empty() else right_hand_bone
		skeleton.add_child(sword_attachment)
		sword_root = _make_right_hand_weapon()
		sword_root.name = "SpartanPackage%s" % String(weapon_kind).capitalize()
		sword_root.scale = Vector3.ONE * weapon_scale_factor
		sword_attachment.add_child(sword_root)
	if shield_enabled and not left_hand_bone.is_empty():
		shield_attachment = BoneAttachment3D.new()
		shield_attachment.name = "CharacterPackageShieldAttachment"
		shield_attachment.bone_name = left_hand_bone
		skeleton.add_child(shield_attachment)
		shield_root = _make_shield()
		shield_root.scale = Vector3.ONE * shield_scale_factor
		shield_attachment.add_child(shield_root)
		_attach_shield_hitbox(shield_root)

func _attach_shield_hitbox(parent: Node3D) -> void:
	if parent == null or shield_hitbox != null:
		return
	shield_hitbox = ShieldHitboxScript.new()
	shield_hitbox.name = "PhysicalShieldHitbox"
	shield_rest_transform = parent.transform
	parent.add_child(shield_hitbox)
	shield_hitbox.configure(self, 0.48)
	shield_hitbox.set_guard_active(false)

func _set_shield_guard_active(enabled: bool) -> void:
	if shield_hitbox != null:
		shield_hitbox.set_guard_active((enabled or _formation_should_guard()) and not dead and not shield_dropped)

func _formation_should_guard() -> bool:
	return (
		_is_phalanx_unit()
		and formation_guard_active
		and not ai_attack_pending
		and ai_attack_recovery_timer <= 0.0
		and guard_break_timer <= 0.0
	)

func _update_shield_guard_visual() -> void:
	if defense_mode != &"shield" or (defense_timer <= 0.0 and not _formation_should_guard()) or shield_root == null or shield_dropped:
		return
	# Some lightweight rigs do not contain a usable shield-raise clip, and wrist
	# axes vary between imported models. Place the aspis explicitly in front of the
	# torso for the active window, while retaining its authored/rest transform when
	# guard ends.
	var toward_threat: Vector3 = -global_basis.z
	if not _is_phalanx_unit() and ai_player != null and is_instance_valid(ai_player):
		toward_threat = ai_player.global_position - global_position
		toward_threat.y = 0.0
	if toward_threat.length_squared() < 0.001:
		toward_threat = -global_basis.z
	toward_threat = toward_threat.normalized()
	var body_scale: float = maxf(global_basis.get_scale().y, 0.01)
	var right: Vector3 = toward_threat.cross(Vector3.UP).normalized()
	var veteran_height := 0.08 if behavior_mode == &"phalanx_veteran" else 0.0
	var guard_position := global_position + Vector3.UP * ((1.08 + veteran_height) * body_scale)
	# The crawl injury lowers visual_root, its skeleton and the regular hand
	# attachment. This explicit guard pose used to ignore that offset, leaving the
	# shield (and its hitbox) floating above a legless defender's head.
	guard_position.y += (visual_root.position.y - visual_ground_offset) * body_scale
	# Keep the wrist and fingers behind the bronze plate. At 0.34 m the shared
	# package's long hand reached through the 9 cm shield mesh during guard.
	guard_position += toward_threat * (0.50 * body_scale)
	guard_position -= right * (0.10 * body_scale)
	var world_scale := shield_root.global_basis.get_scale()
	# The shield boss is on local -Z, matching Godot's default forward axis.
	var guard_basis := Basis.looking_at(toward_threat, Vector3.UP).orthonormalized()
	shield_root.global_transform = Transform3D(guard_basis.scaled(world_scale), guard_position)

func _set_shield_guard_root_anchored(enabled: bool) -> void:
	if shield_root == null or shield_attachment == null or shield_dropped:
		shield_guard_root_anchored = false
		return
	if enabled:
		if shield_root.get_parent() != self:
			# During guard the actor root owns the plate. Leaving it under the animated
			# hand made every arm sample drag the shield away before the next world-space
			# correction, which read as network lag even in a local 50+ FPS session.
			shield_root.reparent(self, true)
		shield_guard_root_anchored = true
		return
	if shield_root.get_parent() != shield_attachment:
		shield_root.reparent(shield_attachment, true)
	shield_root.transform = shield_rest_transform
	shield_guard_root_anchored = false

func _update_phalanx_equipment_pose() -> void:
	var wants_guard := _formation_should_guard()
	if wants_guard != formation_guard_pose_applied:
		formation_guard_pose_applied = wants_guard
		if ai_animation_driver != null:
			if wants_guard:
				ai_animation_driver.begin_block()
			elif defense_timer <= 0.0:
				ai_animation_driver.end_block()
		_set_shield_guard_root_anchored(wants_guard)
	_set_shield_guard_active(wants_guard)
	if wants_guard:
		_update_shield_guard_visual()

	if weapon_kind != &"spear" or sword_root == null or sword_dropped or sword_attachment == null:
		return
	var spear_origin := sword_attachment.global_position
	# Equipment follows the body's actually integrated yaw. formation_facing is a
	# 12 Hz tactical target and can jump ahead of the smoothly turning torso.
	var spear_direction := -global_basis.z
	if spear_direction.length_squared() < 0.001:
		spear_direction = -global_basis.z
	spear_direction.y = 0.0
	spear_direction = spear_direction.normalized()

	var rank_angle_degrees := 8.0
	if formation_row == 1:
		rank_angle_degrees = 25.0
	elif formation_row >= 2:
		rank_angle_degrees = 58.0
	if formation_state in [&"rassemblement", &"marche", &"repli"]:
		rank_angle_degrees = maxf(rank_angle_degrees, 52.0)
	var authored_pitch := float(active_attack_step.get("aim_pitch", 0.0))
	if ai_attack_pending and ai_player != null and is_instance_valid(ai_player):
		var aim_point := ai_player.global_position + Vector3.UP * (1.10 * maxf(body_scale_factor, 0.8))
		spear_direction = (aim_point - spear_origin).normalized()
		if formation_row == 1:
			authored_pitch = maxf(authored_pitch, 0.12)
	elif not ai_attack_pending:
		authored_pitch += deg_to_rad(rank_angle_degrees)
	spear_direction = (spear_direction + Vector3.UP * tan(authored_pitch)).normalized()

	var thrust_offset := 0.0
	if ai_attack_pending and active_attack_windup_total > 0.001:
		var thrust_progress := 1.0 - clampf(ai_attack_windup_timer / active_attack_windup_total, 0.0, 1.0)
		thrust_offset = smoothstep(0.35, 1.0, thrust_progress) * 0.22
	spear_origin += spear_direction * thrust_offset
	var spear_right := spear_direction.cross(Vector3.UP)
	if spear_right.length_squared() < 0.001:
		spear_right = global_basis.x
	spear_right = spear_right.normalized()
	var spear_side := spear_right.cross(spear_direction).normalized()
	var world_scale := sword_root.global_basis.get_scale()
	var spear_basis := Basis(spear_right, spear_direction, spear_side).orthonormalized()
	sword_root.global_transform = Transform3D(spear_basis.scaled(world_scale), spear_origin)

func receive_shield_hit(hit: Variant) -> bool:
	if dead or not shield_enabled or shield_dropped or shield_root == null:
		return false
	if defense_mode != &"shield" or (defense_timer <= 0.0 and not _formation_should_guard()) or shield_hitbox == null or not shield_hitbox.active:
		return false
	var source_node: Node3D = hit.source as Node3D
	if source_node == null or not _is_frontal_shield_threat(source_node):
		return false
	hit.body_part = &"shield"
	hit.hit_material = &"metal"
	hit.contact_type = &"shield"
	hit.position = shield_hitbox.global_position if shield_hitbox != null else shield_root.global_position
	guard_regen_timer = guard_regen_delay
	defense_timer = maxf(defense_timer, minf(defense_duration, 0.22))
	ai_state = &"shield_impact"
	_play_defense_impact()

	var incoming_guard_damage := float(hit.guard_damage)
	if incoming_guard_damage <= 0.0:
		incoming_guard_damage = maxf(float(hit.damage) * 0.80, 8.0)
	if guard_max > 0.0:
		guard_stamina = maxf(0.0, guard_stamina - incoming_guard_damage)
		if guard_stamina <= 0.0:
			hit.guard_broken = true
			hit.contact_type = &"guard_break"
			defense_timer = 0.0
			defense_reaction_timer = -1.0
			guard_break_timer = clampf(0.48 + incoming_guard_damage / maxf(guard_max, 1.0) * 0.32, 0.52, 0.94)
			defense_cooldown_timer = maxf(defense_cooldown_timer, guard_break_timer + 0.72)
			ai_attack_pending = false
			ai_attack_windup_timer = 0.0
			ai_attack_recovery_timer = guard_break_timer
			ai_state = &"guard_broken"
			_end_defense_window()
	if ai_enabled:
		var hit_source: Variant = hit.source
		if hit_source is Node3D:
			_register_retaliation(hit_source as Node3D)
		alert_ai(8.0)
	return true

func _is_frontal_shield_threat(source_node: Node3D) -> bool:
	if source_node == null or not is_instance_valid(source_node):
		return false
	var toward_source := source_node.global_position - global_position
	toward_source.y = 0.0
	if toward_source.length_squared() < 0.001:
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized().dot(toward_source.normalized()) >= 0.20

func receive_anatomy_hit(hit: Variant, zone: StringName) -> void:
	if dead or not anatomy_defs.has(zone) or not zone_state.has(zone):
		return
	set_meta(&"last_skill_source", hit.source.get_instance_id() if is_instance_valid(hit.source) else 0)
	if is_instance_valid(hit.source) and hit.source.has_method("observe_skill_target"): hit.source.observe_skill_target(self)
	if hit is HopliteHitEvent and hit.destroy_shield: _drop_shield()

	var definition: Dictionary = anatomy_defs[zone]
	var state: Dictionary = zone_state[zone]
	if bool(state.get("severed", false)):
		return

	var damage_mult: float = float(definition.get("damage_mult", 1.0))
	var sever_mult: float = float(definition.get("sever_mult", 1.0))
	var raw_damage: float = float(hit.damage)
	var raw_sever: float = float(hit.sever_damage)
	var protection := _incoming_damage_multipliers(hit)
	var contact: StringName = StringName(protection.get("contact", &"flesh"))
	hit.contact_type = contact
	hit.hit_material = &"metal" if contact in [&"shield", &"parry", &"armor", &"guard_break"] else &"flesh"
	var zone_damage: float = raw_damage * damage_mult * float(protection.get("damage", 1.0))
	var zone_sever: float = raw_sever * sever_mult * float(protection.get("sever", 1.0))

	health = maxf(0.0, health - zone_damage)
	_try_activate_combat_phase()
	state["damage"] = float(state.get("damage", 0.0)) + zone_damage
	state["sever"] = float(state.get("sever", 0.0)) + zone_sever
	zone_state[zone] = state

	last_hit_zone = zone
	last_hit_damage = zone_damage
	last_hit_sever = float(state["sever"])
	localized_hit.emit(self, zone, zone_damage, zone_sever)
	if ai_enabled:
		var hit_source: Variant = hit.source
		if hit_source is Node3D:
			_register_retaliation(hit_source as Node3D)
		alert_ai(8.0)
		if behavior_mode == &"coward":
			coward_retreat_timer = randf_range(1.25, 2.15)
		elif behavior_mode == &"ranged":
			ranged_close_contact = true
			ranged_retreat_delay_timer = maxf(ranged_retreat_delay_timer, 0.42)
		if ai_miniboss != null and is_instance_valid(ai_miniboss) and ai_miniboss.has_method("alert_ai"):
			ai_miniboss.call("alert_ai", 8.0)

	var hit_position: Vector3 = hit.position
	var hit_direction: Vector3 = hit.direction
	var blood_intensity: float = clampf(1.00 + zone_damage / 42.0 + zone_sever / 72.0, 1.05, 2.85)
	# A defended metal contact may still cause chip damage, but it must not
	# pretend the sword passed through the shield/armor by spawning flesh blood.
	if contact == &"flesh":
		_spawn_blood_hit(hit_position, hit_direction, blood_intensity, false)
	_flash_hit()
	if contact == &"flesh" and randf() > poise:
		_play_hit_reaction()

	var severable: bool = bool(definition.get("severable", false))
	var threshold: float = float(definition.get("sever_threshold", 9999.0))
	if severable and float(state["sever"]) >= threshold:
		_sever(zone, hit)
		# A non-fatal limb sever used to return before the ordinary health death
		# path, leaving an active actor at zero health. The sever consequence is
		# resolved first so its visual and equipment loss remain intact, then the
		# lethal-health invariant finalizes death exactly once.
		if health <= 0.0 and not dead:
			_die(false)
		return

	if health <= 0.0:
		_die(false)

func _incoming_damage_multipliers(hit: Variant) -> Dictionary:
	var damage_factor := armor_damage_multiplier
	var sever_factor := armor_sever_multiplier
	var base_contact: StringName = &"armor" if defense_mode == &"armor" else &"flesh"
	if defense_mode == &"dodge" and defense_cooldown_timer <= 0.0 and randf() < defense_chance:
		defense_cooldown_timer = defense_cooldown
		damage_factor *= 0.38
		sever_factor *= 0.22
		var evade_direction := global_basis.x * (-1.0 if randi() % 2 == 0 else 1.0)
		velocity += evade_direction.normalized() * 4.2
		ai_state = &"dodge"
		return {"damage": damage_factor, "sever": sever_factor, "contact": &"flesh"}

	if defense_timer <= 0.0 or (defense_mode != &"shield" and defense_mode != &"parry"):
		return {"damage": damage_factor, "sever": sever_factor, "contact": base_contact}
	if defense_mode == &"shield" and (shield_dropped or _zone_is_severed(&"upper_arm_l") or _zone_is_severed(&"forearm_l")):
		return {"damage": damage_factor, "sever": sever_factor, "contact": base_contact}
	var source_node: Node3D = hit.source as Node3D
	if source_node == null:
		return {"damage": damage_factor, "sever": sever_factor, "contact": base_contact}
	var toward_source := source_node.global_position - global_position
	toward_source.y = 0.0
	var forward := -global_basis.z
	forward.y = 0.0
	if toward_source.length_squared() < 0.001 or forward.normalized().dot(toward_source.normalized()) < 0.35:
		return {"damage": damage_factor, "sever": sever_factor, "contact": base_contact}
	guard_regen_timer = guard_regen_delay
	_play_defense_impact()
	if defense_mode == &"parry":
		# A successful parry consumes its narrow window and primes the duelist's
		# next attack immediately. The player's contact response supplies the
		# strong physical recoil.
		defense_timer = minf(defense_timer, 0.06)
		ai_attack_cooldown_timer = 0.0
		parry_counter_queued = true
		return {
			"damage": damage_factor * defense_damage_multiplier,
			"sever": sever_factor * defense_sever_multiplier,
			"contact": &"parry"
		}

	var incoming_guard_damage := float(hit.guard_damage)
	if incoming_guard_damage <= 0.0:
		incoming_guard_damage = maxf(float(hit.damage) * 0.80, 8.0)
	guard_stamina = maxf(0.0, guard_stamina - incoming_guard_damage)
	if guard_max > 0.0 and guard_stamina <= 0.0:
		hit.guard_broken = true
		defense_timer = 0.0
		defense_reaction_timer = -1.0
		guard_break_timer = clampf(0.42 + incoming_guard_damage / maxf(guard_max, 1.0) * 0.32, 0.48, 0.92)
		defense_cooldown_timer = maxf(defense_cooldown_timer, guard_break_timer + 0.72)
		ai_attack_pending = false
		ai_attack_windup_timer = 0.0
		ai_attack_recovery_timer = guard_break_timer
		ai_state = &"guard_broken"
		_end_defense_window()
		return {
			"damage": damage_factor * 0.62,
			"sever": sever_factor * 0.34,
			"contact": &"guard_break"
		}
	return {
		"damage": damage_factor * defense_damage_multiplier,
		"sever": sever_factor * defense_sever_multiplier,
		"contact": defense_mode
	}

func _try_activate_combat_phase() -> void:
	if health <= 0.0:
		return
	var health_ratio := health / maxf(max_health, 1.0)
	if combat_phase == 1 and phase_threshold > 0.0 and health_ratio <= phase_threshold:
		_activate_combat_phase(2, phase_speed_multiplier, phase_damage_multiplier)
	if combat_phase == 2 and phase_three_threshold > 0.0 and health_ratio <= phase_three_threshold:
		_activate_combat_phase(3, phase_three_speed_multiplier, phase_three_damage_multiplier)

func _activate_combat_phase(next_phase: int, speed_multiplier: float, damage_multiplier: float) -> void:
	combat_phase = next_phase
	ai_move_speed *= speed_multiplier
	ai_attack_damage *= damage_multiplier
	ai_attack_anim_speed *= speed_multiplier
	ai_attack_cooldown_min /= maxf(speed_multiplier, 0.1)
	ai_attack_cooldown_max /= maxf(speed_multiplier, 0.1)
	ai_attack_cooldown_timer = 0.0
	ai_attack_pending = false
	ai_attack_windup_timer = 0.0
	active_attack_step.clear()
	combat_pattern_cursor = 0
	ai_alert_timer = maxf(ai_alert_timer, 12.0)
	if next_phase >= 3 and phase_three_armor_damage_multiplier > 0.0:
		armor_damage_multiplier = phase_three_armor_damage_multiplier
	ai_state = &"phase_%d" % next_phase
	combat_phase_changed.emit(self, next_phase)

func _sever(hit_zone: StringName, hit: Variant) -> void:
	var hit_definition: Dictionary = anatomy_defs[hit_zone]
	var sever_target: StringName = StringName(hit_definition.get("sever_target", hit_zone))
	if not zone_state.has(sever_target):
		sever_target = hit_zone
	var target_state: Dictionary = zone_state[sever_target]
	if bool(target_state.get("severed", false)):
		return
	target_state["severed"] = true
	zone_state[sever_target] = target_state

	_disable_related_hitboxes(sever_target)
	_hide_zone_bone_chain(sever_target)

	var proxy_zone: StringName = StringName(hit_definition.get("proxy_zone", StringName()))
	if proxy_zone == StringName():
		proxy_zone = sever_target
	# A sever gets a second, much stronger directional burst at the cut point.
	_spawn_blood_hit(hit.position, hit.direction, clampf(2.10 + float(hit.sever_damage) / 70.0, 2.25, 3.20), true)
	_spawn_detached_proxy(proxy_zone, hit)
	_handle_equipment_loss(sever_target)
	_refresh_injury_state()
	zone_severed.emit(self, sever_target)

	var fatal: bool = bool(hit_definition.get("fatal_sever", false)) or sever_target == &"head"
	if fatal:
		_die(true)

func _disable_related_hitboxes(zone: StringName) -> void:
	if anatomy == null:
		return
	anatomy.disable_zone(zone)
	match zone:
		&"head":
			anatomy.disable_zone(&"neck")
		&"upper_arm_l":
			anatomy.disable_zone(&"forearm_l")
		&"upper_arm_r":
			anatomy.disable_zone(&"forearm_r")
		&"thigh_l":
			anatomy.disable_zone(&"shin_l")
		&"thigh_r":
			anatomy.disable_zone(&"shin_r")

func _hide_zone_bone_chain(zone: StringName) -> void:
	if uses_spartan_package_visual and spartan_package_adapter != null:
		if spartan_package_adapter.sever_body(zone):
			return
	if skeleton == null or anatomy == null:
		return
	var root_bone: int = anatomy.get_zone_primary_bone(zone)
	if root_bone < 0:
		return
	for bone_index: int in range(skeleton.get_bone_count()):
		if _bone_is_descendant_of(bone_index, root_bone):
			hidden_bones[bone_index] = true
	hidden_bones_dirty = not hidden_bones.is_empty()

func _bone_is_descendant_of(bone_index: int, root_bone: int) -> bool:
	var current: int = bone_index
	while current >= 0:
		if current == root_bone:
			return true
		current = skeleton.get_bone_parent(current)
	return false

func _spawn_detached_proxy(zone: StringName, hit: Variant) -> void:
	if anatomy == null or get_tree().current_scene == null:
		return
	var transform: Transform3D = anatomy.get_zone_world_transform(zone)
	# Anatomy collision transforms deliberately use an orthonormal world basis;
	# dimensions therefore need the already-scaled world radius as well. Passing
	# the authored local radius made Forge x3/x4 limbs collide at human size.
	var radius: float = anatomy.get_zone_world_radius(zone)
	var length: float = anatomy.get_zone_length(zone)
	var direction: Vector3 = hit.direction
	var sever_damage: float = hit.sever_damage
	var impulse: Vector3 = direction.normalized() * clampf(2.2 + sever_damage * 0.055, 2.5, 9.0)

	if uses_spartan_package_visual and spartan_package_scene != null and spartan_package_adapter != null:
		var director: Node = _get_gore_director()
		if director != null and director.spawn_spartan_fragment(
			spartan_package_scene, spartan_package_adapter, zone, transform, radius, length, impulse
		):
			return
		var detached = SpartanDetachedLimbScript.new()
		get_tree().current_scene.add_child(detached)
		if detached.setup(spartan_package_scene, spartan_package_adapter, zone, transform, radius, length, impulse):
			return
		detached.queue_free()
		push_warning("[SPARTAN PACKAGE] Real limb spawn failed for %s; using proxy fallback." % String(zone))

	var proxy = DetachedLimbScript.new()
	get_tree().current_scene.add_child(proxy)
	proxy.setup(zone, transform, radius, length, base_color, impulse)

func _handle_equipment_loss(zone: StringName) -> void:
	if zone == &"upper_arm_r" or zone == &"forearm_r":
		_drop_weapon()
	elif zone == &"upper_arm_l" or zone == &"forearm_l":
		if weapon_kind == &"bow":
			_drop_weapon()
		else:
			_drop_shield()

func _die(_from_sever: bool) -> void:
	if dead:
		return
	_release_attack_permission(true)
	_set_combat_target(null)
	dead = true
	# Death is an atomic exit from every AI consumer. Keeping a corpse in
	# combatant_ai made the spatial grid and formation scheduler continue to scan
	# it even though the registry already considered it dead.
	set_ai_participation(false)
	health = 0.0
	velocity = Vector3.ZERO
	ai_attack_pending = false
	ai_attack_windup_timer = 0.0
	ai_state = &"dead"
	_set_attack_outline_active(false)
	collision_layer = 0
	collision_mask = 0
	if body_collider != null:
		body_collider.set_deferred("disabled", true)
	_set_matched_physical_colliders_enabled(false)
	_set_matched_walkable_surfaces_enabled(false)
	if anatomy != null:
		anatomy.shutdown()
	set_physics_process(false)

	# Equipment should not remain rigidly upright in a dead hand. Procedural
	# weapons/shields become lightweight physics props before the body settles.
	_drop_weapon()
	_drop_shield()

	# The old V0.0.5-V0.0.7 corpse workaround rotated visual_root by ~90 degrees.
	# That avoided an upright corpse, but because the standing skeleton pose and
	# the root rotation were fighting each other it produced floating/twisted
	# bodies. The real problem was the AI AnimationTree continuing to own the
	# target skeleton after death. Shut the runtime driver/tree down completely,
	# then let the authored UAL1 Death01 animation own the corpse.
	_shutdown_ai_animation_for_death()

	if visual_root != null:
		# Crawl/limp presentation modifies the visual root while alive. Restore the
		# neutral character root before playing the authored death clip. Preserve Y
		# because UAL1 is intentionally flipped to face the correct direction.
		visual_root.position = Vector3(0.0, visual_ground_offset, 0.0)
		visual_root.rotation = Vector3(0.0, visual_root.rotation.y, 0.0)

	var played_authored_death: bool = false
	var corpse_settle_time: float = 0.85
	if animation_player != null and animation_player.has_animation("Death01"):
		var death_anim: Animation = animation_player.get_animation("Death01")
		if death_anim != null:
			death_anim.loop_mode = Animation.LOOP_NONE
			corpse_settle_time = maxf(0.18, death_anim.length + 0.12)
		animation_player.stop()
		animation_player.play("Death01", 0.035, 1.0)
		animation_player.advance(0.0)
		played_authored_death = true
		if uses_spartan_package_visual and death_anim != null:
			spartan_corpse_grounding_timer = corpse_settle_time
			spartan_corpse_grounding_tick = 0.0

	# UAL1 normally provides Death01. Keep a small deterministic fallback only for
	# replacement characters that do not ship a death animation.
	if not played_authored_death:
		_collapse_dead_body_fallback()

	# Keep the authored collapse visible, then turn the settled corpse into a
	# render-only prop: no process callback, particles or dynamic shadows.
	if spartan_corpse_grounding_timer < 0.0 and get_tree() != null:
		get_tree().create_timer(corpse_settle_time).timeout.connect(_retire_corpse_runtime)
	_schedule_corpse_release(corpse_settle_time)

	died.emit(self)


func _set_attack_outline_active(value: bool) -> void:
	var next_active := value and faction != &"spartan" and is_in_group(&"enemy")
	if next_active == attack_outline_active and is_in_group(&"enemy_attack_outline_subject") == next_active:
		return
	attack_outline_active = next_active
	if attack_outline_active:
		add_to_group(&"enemy_attack_outline_subject")
	else:
		remove_from_group(&"enemy_attack_outline_subject")

func _retire_corpse_runtime() -> void:
	if not dead:
		return
	for candidate: Node in find_children("*", "GPUParticles3D", true, false):
		var particles := candidate as GPUParticles3D
		if particles != null:
			particles.emitting = false
	for candidate: Node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		if geometry != null:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(false)

func _schedule_corpse_release(settle_delay: float = 0.0) -> void:
	if get_tree() == null or corpse_lifetime <= 0.0:
		return
	get_tree().create_timer(maxf(0.0, settle_delay) + corpse_lifetime).timeout.connect(_release_expired_corpse)

func _release_expired_corpse() -> void:
	if dead and is_inside_tree():
		queue_free()

func _ground_spartan_corpse_visual() -> void:
	if visual_root == null or anatomy == null:
		return
	var lowest_surface_y: float = anatomy.estimate_lowest_surface_y()
	if is_inf(lowest_surface_y):
		return
	var floor_y: float = global_position.y
	var world := get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 2.5,
			global_position + Vector3.DOWN * 3.0,
			1,
			[get_rid()]
		)
		var collision: Dictionary = world.direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			floor_y = maxf(floor_y, (collision.get("position", global_position) as Vector3).y)
	var correction: float = clampf(floor_y - lowest_surface_y, -1.80, 0.45)
	var world_scale_y := maxf(absf(global_basis.get_scale().y), 0.01)
	visual_root.position.y += correction / world_scale_y
	if combat_debug_visible:
		print("[SPARTAN PACKAGE] Grounded corpse by %.3f m." % correction)

func _shutdown_ai_animation_for_death() -> void:
	if ai_animation_driver == null:
		# Static anatomy targets can still contain imported AnimationTrees.
		if mannequin_scene != null:
			_disable_animation_trees(mannequin_scene)
		return

	ai_animation_driver.stop_movement_action()
	ai_animation_driver.stop_full_body()
	ai_animation_driver.set_locomotion(0.0)

	# AnimationTree is a child of HopliteNativeAnimationDriver and otherwise keeps
	# evaluating independently even though enemy._process() stops calling tick().
	var tree_value: Variant = ai_animation_driver.get("animation_tree")
	if tree_value is AnimationTree:
		(tree_value as AnimationTree).active = false

	# Zero the two retarget modifiers immediately so Death01 is not mixed with a
	# stale UAL2 run/attack pose during the frame the driver is removed.
	for property_name: String in ["movement_pose_bridge", "pose_bridge"]:
		var bridge_value: Variant = ai_animation_driver.get(property_name)
		if bridge_value is Node and (bridge_value as Node).has_method("set_attack_weight"):
			(bridge_value as Node).call("set_attack_weight", 0.0, false, 0.0)

	ai_animation_driver.queue_free()
	ai_animation_driver = null

	if mannequin_scene != null:
		_disable_animation_trees(mannequin_scene)

func _collapse_dead_body_fallback() -> void:
	if visual_root == null:
		return
	if death_collapse_tween != null and death_collapse_tween.is_valid():
		death_collapse_tween.kill()

	# Freeze the exact pose reached at death. Otherwise a looping Mixamo attack can
	# continue moving the bones after the actor is already lying on the ground.
	if animation_player != null:
		animation_player.stop(true)

	# Fallback only: rotate the standing mannequin sideways. A deterministic yaw,
	# pitch and local offset keep nearby deaths from forming one identical pile.
	var side: float = -1.0 if (get_instance_id() % 2) == 0 else 1.0
	var corpse_seed: float = float(get_instance_id() % 997)
	var spread_angle: float = deg_to_rad(fmod(corpse_seed * 137.5, 360.0))
	var spread_radius: float = 0.20 + fmod(corpse_seed, 5.0) * 0.035
	var target_rotation: Vector3 = visual_root.rotation
	target_rotation.z += deg_to_rad(88.0 * side)
	target_rotation.x += deg_to_rad(-9.0 + fmod(corpse_seed, 7.0) * 2.4)
	target_rotation.y += deg_to_rad(-14.0 + fmod(corpse_seed, 9.0) * 3.5)
	var target_position: Vector3 = visual_root.position
	target_position.x += cos(spread_angle) * spread_radius
	target_position.z += sin(spread_angle) * spread_radius
	target_position.y = (visual_ground_offset + 0.24) if uses_mixamo_visual else corpse_fallback_rest_height

	death_collapse_tween = create_tween()
	death_collapse_tween.set_trans(Tween.TRANS_QUAD)
	death_collapse_tween.set_ease(Tween.EASE_IN)
	death_collapse_tween.set_parallel(true)
	death_collapse_tween.tween_property(visual_root, "rotation", target_rotation, 0.36)
	death_collapse_tween.tween_property(visual_root, "position", target_position, 0.36)


func _spawn_blood_hit(world_position: Vector3, direction: Vector3, intensity: float = 1.0, sever: bool = false) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var director: Node = _get_gore_director()
	if director != null:
		director.spawn_blood(world_position, direction, intensity, sever)
		return
	var burst = BloodBurstScript.new()
	scene.add_child(burst)
	burst.setup(world_position, direction, intensity, sever)

func _get_gore_director() -> Node:
	if gore_director == null or not is_instance_valid(gore_director):
		gore_director = get_tree().get_first_node_in_group(&"gore_director") if get_tree() != null else null
		if gore_director == null and get_tree() != null:
			gore_director = GoreDirectorScript.new()
			gore_director.name = "GoreDirector"
			var owner: Node = get_tree().current_scene
			if owner == null:
				owner = get_tree().root
			owner.add_child(gore_director)
	return gore_director

func _register_gore_package() -> void:
	if spartan_package_scene == null:
		return
	var director: Node = _get_gore_director()
	if director != null:
		director.register_spartan_package(spartan_package_scene)

func _flash_hit() -> void:
	if body_material == null:
		return
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	body_material.albedo_color = Color(0.45, 0.06, 0.08)
	flash_tween = create_tween()
	flash_tween.tween_property(body_material, "albedo_color", base_color, 0.14)

func _update_status_label() -> void:
	if not combat_debug_visible or status_label == null:
		return
	if dead:
		status_label.text = archetype_name + " — DEAD"
		status_label.modulate = Color(0.65, 0.18, 0.18)
		return
	var zone_text: String = String(last_hit_zone) if last_hit_zone != StringName() else "none"
	var ai_text: String = "  AI=" + String(ai_state) if ai_enabled else ""
	var injury_text: String = "  BODY=" + String(injury_state)
	var guard_text: String = "  GUARD=%.0f/%.0f" % [guard_stamina, guard_max] if guard_max > 0.0 else ""
	var pattern_text: String = String(active_attack_step.get("id", &"free"))
	status_label.text = "%s  HP %.0f/%.0f%s%s%s\nweapon=%s behavior=%s phase=%d pattern=%s • last=%s dmg=%.0f sever=%.0f" % [archetype_name, health, max_health, ai_text, injury_text, guard_text, String(weapon_kind), String(behavior_mode), combat_phase, pattern_text, zone_text, last_hit_damage, last_hit_sever]

func set_combat_debug_visible(enabled: bool) -> void:
	combat_debug_visible = enabled
	if enabled:
		_ensure_status_label()
		_update_status_label()
	if status_label != null:
		status_label.visible = enabled
	if anatomy != null:
		anatomy.set_debug_visible(enabled)
		if enabled:
			anatomy.set_tracking_enabled(true)
			anatomy.set_update_interval(0.0)
		else:
			_update_performance_lod()

func _ensure_status_label() -> void:
	if status_label != null:
		return
	status_label = Label3D.new()
	status_label.name = "DamageDebug"
	status_label.position = Vector3(0.0, 2.32, 0.0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 32
	status_label.modulate = Color(1.0, 0.86, 0.20) if is_miniboss else base_color.lightened(0.42)
	status_label.visible = combat_debug_visible
	add_child(status_label)

func get_combat_aim_point() -> Vector3:
	if anatomy != null:
		return anatomy.get_zone_world_center(&"torso")
	return global_position + Vector3.UP * 1.10

func is_dead_for_combat() -> bool:
	return dead

func is_combat_zone_severed(zone: StringName) -> bool:
	return _zone_is_severed(zone)

func _zone_is_severed(zone: StringName) -> bool:
	if not zone_state.has(zone):
		return false
	var state: Dictionary = zone_state[zone]
	return bool(state.get("severed", false))

func _left_leg_lost() -> bool:
	return _zone_is_severed(&"thigh_l") or _zone_is_severed(&"shin_l")

func _right_leg_lost() -> bool:
	return _zone_is_severed(&"thigh_r") or _zone_is_severed(&"shin_r")

func _lost_leg_count() -> int:
	return (1 if _left_leg_lost() else 0) + (1 if _right_leg_lost() else 0)

func _right_arm_lost() -> bool:
	return _zone_is_severed(&"upper_arm_r") or _zone_is_severed(&"forearm_r")

func _can_ai_attack() -> bool:
	return not dead and not sword_dropped and not _right_arm_lost()

func _can_start_attack_at_distance(distance: float) -> bool:
	if defense_timer > 0.0 or defense_reaction_timer >= 0.0 or guard_break_timer > 0.0:
		return false
	var formation_reach := formation_rank_spacing * 0.72 if _is_phalanx_unit() and formation_row == 1 else 0.0
	if distance > ai_attack_range + formation_reach:
		return false
	if behavior_mode == &"ranged":
		return distance >= preferred_range_min * 0.82 and _has_clear_projectile_lane(ai_player)
	if behavior_mode == &"reach" and distance < preferred_range_min * 0.74:
		return false
	if _is_phalanx_unit() and (formation_row > 1 or distance < preferred_range_min * 0.68):
		return false
	if behavior_mode == &"flank" and distance > ai_attack_range * 0.98:
		return false
	return true

func _current_ai_move_speed() -> float:
	var lost: int = _lost_leg_count()
	if lost >= 2:
		return ai_crawl_speed
	if lost == 1:
		return minf(ai_move_speed, ai_limp_speed)
	return ai_move_speed

func _refresh_injury_state() -> void:
	var lost_legs: int = _lost_leg_count()
	if lost_legs >= 2:
		injury_state = &"crawl"
	elif lost_legs == 1:
		injury_state = &"limp"
	elif _right_arm_lost():
		injury_state = &"disarmed"
	else:
		injury_state = &"healthy"
	_refresh_body_collider_for_injury()

	if not _can_ai_attack():
		ai_attack_pending = false
		ai_attack_windup_timer = 0.0
		ai_attack_recovery_timer = 0.0

func _update_injury_visual(delta: float) -> void:
	if visual_root == null or dead:
		return
	var lost_legs: int = _lost_leg_count()
	var target_y: float = visual_ground_offset - 0.54 if lost_legs >= 2 else visual_ground_offset
	var target_x: float = deg_to_rad(-18.0) if lost_legs >= 2 else 0.0
	if lost_legs == 0 and uses_spartan_package_visual and not ai_attack_pending and ai_attack_recovery_timer <= 0.0:
		# The shared Jog_Fwd donor has a pronounced forward pitch on these new
		# 53-bone packages. Counter only the presentation root while locomoting;
		# gameplay facing, collisions and authored attacks remain untouched.
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		var locomotion_ratio := clampf(horizontal_speed / maxf(_current_ai_move_speed(), 0.1), 0.0, 1.0)
		target_x = deg_to_rad(-5.5) * locomotion_ratio
	visual_root.position.y = move_toward(visual_root.position.y, target_y, 3.8 * delta)
	visual_root.rotation.x = lerp_angle(visual_root.rotation.x, target_x, clampf(1.0 - exp(-8.0 * delta), 0.0, 1.0))

func _play_idle() -> void:
	if animation_player == null:
		return
	if uses_mixamo_visual:
		var mixamo_idle := StringName(mixamo_clips.get("idle", StringName()))
		_play_simple_loop(mixamo_idle, 0.88)
		return
	var clip: StringName = &"Idle"
	if animation_player.has_animation("Sword_Idle"):
		clip = &"Sword_Idle"
	if not animation_player.has_animation(clip):
		return
	var anim: Animation = animation_player.get_animation(clip)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(clip)
	simple_anim_state = clip

func _play_mixamo_intro() -> void:
	if animation_player == null:
		return
	var clip := StringName(mixamo_clips.get("taunt", StringName()))
	if clip == StringName() or not animation_player.has_animation(clip):
		_play_idle()
		return
	var animation := animation_player.get_animation(clip)
	var playback_speed: float = 1.18
	simple_anim_lock_timer = minf(1.65, animation.length / playback_speed) if animation != null else 1.20
	animation_player.play(clip, 0.04, playback_speed)
	simple_anim_state = clip

func _setup_ai_animation_driver() -> void:
	if mannequin_scene == null or skeleton == null or animation_player == null:
		return
	ai_animation_driver = SharedHopliteDriverScript.new() if _uses_shared_hoplite_animation() else DriverScript.new()
	ai_animation_driver.name = "AthenianAIDriver"
	add_child(ai_animation_driver)
	var enable_external := not external_animation_keys.is_empty()
	# Enemies never wall-run. Keep those four heavy Mixamo donors player-only.
	if not ai_animation_driver.configure(mannequin_scene, skeleton, animation_player, enable_external, external_animation_keys, false, archetype_id):
		ai_animation_driver.queue_free()
		ai_animation_driver = null
		_play_idle()
	elif ai_animation_driver.has_method("set_simulation_lod"):
		ai_animation_driver.set_simulation_lod(maxi(render_lod_level, 0))

func _force_animation_sample() -> void:
	if ai_animation_driver != null and ai_animation_driver.has_method("force_simulation_sample"):
		ai_animation_driver.force_simulation_sample()

func _uses_shared_hoplite_animation() -> bool:
	return AnimationRuntimeContract.uses_shared_driver(archetype_id)

func _tint_body() -> void:
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = base_color
	body_material.roughness = 0.60
	body_material.metallic = 0.04
	_override_mesh_materials(mannequin_scene, body_material)

func _build_equipment() -> void:
	if skeleton == null:
		return
	_build_armor_skin()
	if right_hand_bone != "" and weapon_kind != &"unarmed":
		sword_attachment = BoneAttachment3D.new()
		sword_attachment.name = "EnemyWeaponAttachment"
		sword_attachment.bone_name = left_hand_bone if weapon_kind == &"bow" and left_hand_bone != "" else right_hand_bone
		skeleton.add_child(sword_attachment)
		sword_root = _make_right_hand_weapon()
		sword_root.scale = Vector3.ONE * weapon_scale_factor
		sword_attachment.add_child(sword_root)
	if shield_enabled and left_hand_bone != "":
		shield_attachment = BoneAttachment3D.new()
		shield_attachment.name = "EnemyShieldAttachment"
		shield_attachment.bone_name = left_hand_bone
		skeleton.add_child(shield_attachment)
		shield_root = _make_shield()
		shield_root.scale = Vector3.ONE * shield_scale_factor
		shield_attachment.add_child(shield_root)
		_attach_shield_hitbox(shield_root)

func _build_mixamo_weapon() -> void:
	# Knight3 already has a skinned sword and shield authored into its model.
	# Other Mixamo characters receive a lightweight weapon attached directly to
	# their animated right hand, so it follows every locomotion/attack clip.
	if skeleton == null or right_hand_bone == "":
		return
	if weapon_kind == &"unarmed":
		return
	if mixamo_model_id == &"knight3":
		# Knight3 renders skinned authored equipment. Keep explicit hand anchors so
		# severing can hide those meshes and spawn ordinary detachable replacements.
		authored_weapon_visual = mannequin_scene.find_child("*Sword*", true, false) as Node3D
		authored_shield_visual = mannequin_scene.find_child("*Shield*", true, false) as Node3D
		sword_attachment = BoneAttachment3D.new()
		sword_attachment.name = "AuthoredWeaponDropAttachment"
		sword_attachment.bone_name = right_hand_bone
		skeleton.add_child(sword_attachment)
		sword_root = Node3D.new()
		sword_root.name = "AuthoredWeaponDropAnchor"
		sword_attachment.add_child(sword_root)
		# The authored shield also needs the same physical combat surface as
		# procedural equipment.
		if shield_enabled and left_hand_bone != "":
			shield_attachment = BoneAttachment3D.new()
			shield_attachment.name = "AuthoredShieldCollisionAttachment"
			shield_attachment.bone_name = left_hand_bone
			skeleton.add_child(shield_attachment)
			shield_root = Node3D.new()
			shield_root.name = "AuthoredShieldCollisionRoot"
			shield_attachment.add_child(shield_root)
			_attach_shield_hitbox(shield_root)
		return
	sword_attachment = BoneAttachment3D.new()
	sword_attachment.name = "MixamoWeaponAttachment"
	sword_attachment.bone_name = right_hand_bone
	skeleton.add_child(sword_attachment)
	sword_root = _make_right_hand_weapon()
	sword_root.name = "Mixamo%s" % String(weapon_kind).capitalize()
	sword_root.scale = Vector3.ONE * weapon_scale_factor
	sword_attachment.add_child(sword_root)
	# Most raw Mixamo bodies contain clothing only. A shield profile must still
	# own a visible aspis in the animated left hand; otherwise the mechanical
	# frontal block would be invisible and impossible to read.
	if shield_enabled and left_hand_bone != "":
		shield_attachment = BoneAttachment3D.new()
		shield_attachment.name = "MixamoShieldAttachment"
		shield_attachment.bone_name = left_hand_bone
		skeleton.add_child(shield_attachment)
		shield_root = _make_shield()
		shield_root.name = "MixamoShield"
		shield_root.scale = Vector3.ONE * shield_scale_factor
		shield_attachment.add_child(shield_root)
		_attach_shield_hitbox(shield_root)

func _build_armor_skin() -> void:
	var bronze := _make_skin_material(Color(0.47, 0.25, 0.075), 0.72, 0.30)
	var bright_bronze := _make_skin_material(Color(0.68, 0.39, 0.10), 0.78, 0.24)
	var iron := _make_skin_material(Color(0.22, 0.24, 0.26), 0.80, 0.29)
	var leather := _make_skin_material(Color(0.25, 0.105, 0.035), 0.05, 0.76)
	var linen := _make_skin_material(Color(0.72, 0.66, 0.49), 0.02, 0.82)
	var crest_color: Color = Color(0.56, 0.025, 0.018) if faction == &"spartan" else Color(0.055, 0.095, 0.16)
	var crest := _make_skin_material(crest_color, 0.02, 0.92)

	match skin_id:
		&"guardian":
			_add_cuirass(bronze, Vector3(0.62, 0.54, 0.34), true)
			_add_helmet(&"corinthian", bronze, crest, 1.20)
			_add_shoulders(bronze, 1.18)
			_add_greaves(bronze, 1.12)
			_add_skirt(leather, 6)
		&"spearman":
			_add_cuirass(linen, Vector3(0.50, 0.48, 0.27), false)
			_add_helmet(&"pilos", bronze, crest, 0.70)
			_add_skirt(leather, 4)
		&"flanker":
			_add_cuirass(leather, Vector3(0.39, 0.38, 0.22), false)
			_add_helmet(&"cap", iron, crest, 0.45)
			_add_cape(leather)
		&"brute":
			_add_cuirass(iron, Vector3(0.70, 0.57, 0.37), true)
			_add_helmet(&"horned", iron, crest, 0.95)
			_add_shoulders(iron, 1.34)
			_add_belt(bright_bronze)
		&"captain":
			_add_cuirass(bright_bronze, Vector3(0.62, 0.57, 0.34), true)
			_add_helmet(&"corinthian", bright_bronze, crest, 1.55)
			_add_shoulders(bright_bronze, 1.22)
			_add_greaves(bright_bronze, 1.18)
			_add_skirt(leather, 7)
			_add_belt(bright_bronze)
		&"warlord":
			_add_cuirass(iron, Vector3(0.72, 0.62, 0.40), true)
			_add_helmet(&"horned", iron, crest, 1.75)
			_add_shoulders(iron, 1.48)
			_add_greaves(bright_bronze, 1.26)
			_add_skirt(leather, 8)
			_add_belt(bright_bronze)
		&"spartan":
			_add_cuirass(bronze, Vector3(0.57, 0.53, 0.31), true)
			_add_helmet(&"corinthian", bronze, crest, 1.25)
			_add_shoulders(bronze, 1.08)
			_add_greaves(bronze, 1.08)
			_add_skirt(leather, 6)
		_:
			_add_cuirass(bronze, Vector3(0.51, 0.46, 0.29), false)
			_add_helmet(&"open", bronze, crest, 0.82)
			_add_skirt(leather, 5)

func _make_skin_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var key := _material_cache_key(color, roughness_value, metallic_value)
	if _skin_material_cache.has(key):
		return _skin_material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	_skin_material_cache[key] = material
	return material

func _skin_attachment(bone_name: String, node_name: String) -> BoneAttachment3D:
	if skeleton == null or skeleton.find_bone(bone_name) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	return attachment

func _add_cuirass(material: Material, size: Vector3, reinforced: bool) -> void:
	var chest := _skin_attachment("DEF-spine.002", "CuirassAttachment")
	if chest == null:
		return
	_add_box_piece(chest, "Cuirass", size, Vector3(0.0, 0.05, 0.0), material)
	if reinforced:
		_add_box_piece(chest, "ChestRidge", Vector3(size.x * 0.86, 0.075, size.z * 1.10), Vector3(0.0, 0.13, -size.z * 0.48), material)

func _add_belt(material: Material) -> void:
	var hips := _skin_attachment("DEF-hips", "BeltAttachment")
	if hips != null:
		_add_box_piece(hips, "CommandBelt", Vector3(0.55, 0.10, 0.31), Vector3(0.0, 0.08, 0.0), material)

func _add_skirt(material: Material, strip_count: int) -> void:
	var hips := _skin_attachment("DEF-hips", "PterugesAttachment")
	if hips == null:
		return
	for index: int in range(strip_count):
		var centered: float = float(index) - float(strip_count - 1) * 0.5
		var x: float = centered * 0.085
		_add_box_piece(hips, "Pteruge_%02d" % index, Vector3(0.068, 0.31, 0.055), Vector3(x, -0.14, -0.03 + absf(centered) * 0.012), material, Vector3(0.0, 0.0, centered * 2.0))

func _add_shoulders(material: Material, scale_value: float) -> void:
	for side: String in ["L", "R"]:
		var shoulder := _skin_attachment("DEF-upper_arm.%s" % side, "Pauldron%s" % side)
		if shoulder != null:
			_add_sphere_piece(shoulder, "Pauldron", Vector3(0.22, 0.14, 0.23) * scale_value, Vector3.ZERO, material)

func _add_greaves(material: Material, scale_value: float) -> void:
	for side: String in ["L", "R"]:
		var shin := _skin_attachment("DEF-shin.%s" % side, "Greave%s" % side)
		if shin != null:
			_add_cylinder_piece(shin, "Greave", 0.095 * scale_value, 0.36 * scale_value, Vector3(0.0, -0.14, -0.015), material)

func _add_cape(material: Material) -> void:
	var chest := _skin_attachment("DEF-spine.003", "CapeAttachment")
	if chest != null:
		_add_box_piece(chest, "ShortCape", Vector3(0.43, 0.62, 0.045), Vector3(0.0, -0.18, 0.16), material, Vector3(-9.0, 0.0, 0.0))

func _add_helmet(kind: StringName, metal: Material, crest: Material, crest_scale: float) -> void:
	var head := _skin_attachment("DEF-head", "HelmetAttachment")
	if head == null:
		return
	match kind:
		&"pilos":
			_add_cone_piece(head, "PilosHelmet", 0.23, 0.34, Vector3(0.0, 0.19, 0.0), metal)
		&"cap":
			_add_sphere_piece(head, "LeatherCap", Vector3(0.225, 0.12, 0.225), Vector3(0.0, 0.16, 0.0), metal)
		_:
			_add_cylinder_piece(head, "HelmetBand", 0.225, 0.24, Vector3(0.0, 0.08, 0.0), metal)
			_add_sphere_piece(head, "HelmetDome", Vector3(0.225, 0.15, 0.225), Vector3(0.0, 0.19, 0.0), metal)
			if kind == &"corinthian" or kind == &"horned":
				_add_box_piece(head, "CheekL", Vector3(0.055, 0.27, 0.07), Vector3(-0.17, -0.08, -0.07), metal, Vector3(0.0, 0.0, -7.0))
				_add_box_piece(head, "CheekR", Vector3(0.055, 0.27, 0.07), Vector3(0.17, -0.08, -0.07), metal, Vector3(0.0, 0.0, 7.0))
	if kind != &"cap":
		_add_box_piece(head, "Crest", Vector3(0.075, 0.25 * crest_scale, 0.34), Vector3(0.0, 0.34 + 0.08 * crest_scale, 0.0), crest)
	if kind == &"horned":
		_add_cone_piece(head, "HornL", 0.065, 0.29, Vector3(-0.22, 0.26, 0.0), metal, Vector3(0.0, 0.0, -48.0))
		_add_cone_piece(head, "HornR", 0.065, 0.29, Vector3(0.22, 0.26, 0.0), metal, Vector3(0.0, 0.0, 48.0))

func _add_box_piece(parent: Node3D, node_name: String, size: Vector3, position_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var piece := MeshInstance3D.new()
	piece.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.position = position_value
	piece.rotation_degrees = rotation_value
	piece.material_override = material
	parent.add_child(piece)

func _add_cylinder_piece(parent: Node3D, node_name: String, radius: float, height: float, position_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var piece := MeshInstance3D.new()
	piece.name = node_name
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	piece.mesh = mesh
	piece.position = position_value
	piece.rotation_degrees = rotation_value
	piece.material_override = material
	parent.add_child(piece)

func _add_cone_piece(parent: Node3D, node_name: String, radius: float, height: float, position_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var piece := MeshInstance3D.new()
	piece.name = node_name
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	piece.mesh = mesh
	piece.position = position_value
	piece.rotation_degrees = rotation_value
	piece.material_override = material
	parent.add_child(piece)

func _add_sphere_piece(parent: Node3D, node_name: String, scale_value: Vector3, position_value: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	piece.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	piece.mesh = mesh
	piece.scale = scale_value
	piece.position = position_value
	piece.material_override = material
	parent.add_child(piece)

func _make_right_hand_weapon() -> Node3D:
	match weapon_kind:
		&"spear":
			return _make_spear()
		&"hammer":
			return _make_hammer()
		&"axe":
			return _make_axe()
		&"farm_tool":
			return _make_farm_tool()
		&"gladius":
			return _make_gladius()
		&"bow":
			return _make_bow()
		&"greatsword":
			return _make_greatsword()
		_:
			return _make_sword()

func _drop_weapon() -> void:
	if sword_dropped or sword_root == null or get_tree().current_scene == null:
		return
	sword_dropped = true
	var t: Transform3D = sword_root.global_transform
	sword_root.visible = false
	if authored_weapon_visual != null:
		authored_weapon_visual.visible = false
	var body := RigidBody3D.new()
	body.name = "DroppedAthenian%s" % String(weapon_kind).capitalize()
	body.collision_layer = 16
	body.collision_mask = 1
	body.can_sleep = true
	get_tree().current_scene.add_child(body)
	body.global_transform = t
	# Duplicate the carried visual so PrimitiveMesh and Material resources remain
	# shared; rebuilding the procedural weapon here doubled every resource.
	var visual := _make_right_hand_weapon() if authored_weapon_visual != null else sword_root.duplicate() as Node3D
	if visual == null:
		visual = _make_right_hand_weapon()
	visual.visible = true
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	if weapon_kind == &"spear":
		shape.size = Vector3(0.10, 2.25, 0.10)
		collision.position.y = 0.48
	elif weapon_kind == &"farm_tool":
		shape.size = Vector3(0.42, 1.75, 0.12)
		collision.position.y = 0.46
	elif weapon_kind == &"bow":
		shape.size = Vector3(0.16, 1.34, 0.50)
		collision.position.y = 0.32
	elif weapon_kind == &"greatsword":
		shape.size = Vector3(0.16, 1.70, 0.10)
		collision.position.y = 0.62
	elif weapon_kind == &"hammer":
		shape.size = Vector3(0.68, 1.42, 0.34)
		collision.position.y = 0.48
	elif weapon_kind == &"axe":
		shape.size = Vector3(0.48, 1.16, 0.12)
		collision.position.y = 0.46
	else:
		shape.size = Vector3(0.10, 1.15, 0.08)
		collision.position.y = 0.42
	collision.shape = shape
	body.add_child(collision)
	body.apply_central_impulse(Vector3(randf_range(-1.2, 1.2), 2.5, randf_range(-1.2, 1.2)))
	var lifecycle = DebrisLifecycleScript.new()
	body.add_child(lifecycle)
	lifecycle.setup(body, collision, 12.0, 4.0)

func destroy_skill_shield() -> void:
	set_meta(&"skill_shield_destroyed", true)
	_drop_shield()

func _drop_shield() -> void:
	if shield_dropped or shield_root == null or get_tree().current_scene == null:
		return
	shield_dropped = true
	defense_reaction_timer = -1.0
	defense_timer = 0.0
	guard_stamina = 0.0
	if shield_hitbox != null:
		shield_hitbox.shutdown()
	_end_defense_window()
	var t: Transform3D = shield_root.global_transform
	shield_root.visible = false
	if authored_shield_visual != null:
		authored_shield_visual.visible = false
	var body := RigidBody3D.new()
	body.name = "DroppedAthenianShield"
	body.collision_layer = 16
	body.collision_mask = 1
	body.can_sleep = true
	get_tree().current_scene.add_child(body)
	body.global_transform = t
	var visual := _make_shield() if authored_shield_visual != null else shield_root.duplicate() as Node3D
	if visual == null:
		visual = _make_shield()
	visual.visible = true
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 0.10
	shape.radius = 0.48
	collision.shape = shape
	collision.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.add_child(collision)
	body.apply_central_impulse(Vector3(randf_range(-1.0, 1.0), 2.0, randf_range(-1.0, 1.0)))
	var lifecycle = DebrisLifecycleScript.new()
	body.add_child(lifecycle)
	lifecycle.setup(body, collision, 12.0, 4.0)

func _make_sword() -> Node3D:
	var root := Node3D.new()
	var bronze := _make_weapon_material(Color(0.33, 0.16, 0.05), 0.34, 0.55)
	var steel := _make_weapon_material(Color(0.68, 0.72, 0.76), 0.22, 0.82)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.065, 0.92, 0.025)
	blade.mesh = blade_mesh
	blade.position.y = 0.55
	blade.material_override = steel
	root.add_child(blade)

	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.30, 0.055, 0.06)
	guard.mesh = guard_mesh
	guard.position.y = 0.07
	guard.material_override = bronze
	root.add_child(guard)
	return root

func _make_gladius() -> Node3D:
	var root := Node3D.new()
	root.name = "ShortGladius"
	var bronze := _make_weapon_material(Color(0.42, 0.22, 0.06), 0.34, 0.62)
	var steel := _make_weapon_material(Color(0.64, 0.68, 0.70), 0.24, 0.78)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.075, 0.66, 0.028)
	blade.mesh = blade_mesh
	blade.position.y = 0.42
	blade.material_override = steel
	root.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.25, 0.055, 0.065)
	guard.mesh = guard_mesh
	guard.position.y = 0.06
	guard.material_override = bronze
	root.add_child(guard)
	return root

func _make_greatsword() -> Node3D:
	var root := Node3D.new()
	root.name = "FullArmorGreatsword"
	var dark_steel := _make_weapon_material(Color(0.28, 0.31, 0.34), 0.20, 0.88)
	var bronze := _make_weapon_material(Color(0.50, 0.28, 0.07), 0.30, 0.72)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.13, 1.48, 0.045)
	blade.mesh = blade_mesh
	blade.position.y = 0.90
	blade.material_override = dark_steel
	root.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.52, 0.075, 0.10)
	guard.mesh = guard_mesh
	guard.position.y = 0.12
	guard.material_override = bronze
	root.add_child(guard)
	return root

func _make_farm_tool() -> Node3D:
	var root := Node3D.new()
	root.name = "AgriculturalWarFork"
	var wood := _make_weapon_material(Color(0.23, 0.085, 0.022), 0.82, 0.0)
	var iron := _make_weapon_material(Color(0.25, 0.28, 0.30), 0.28, 0.82)
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.height = 1.64
	handle_mesh.top_radius = 0.030
	handle_mesh.bottom_radius = 0.037
	handle.mesh = handle_mesh
	handle.position.y = 0.56
	handle.material_override = wood
	root.add_child(handle)
	var crossbar := MeshInstance3D.new()
	var crossbar_mesh := BoxMesh.new()
	crossbar_mesh.size = Vector3(0.40, 0.055, 0.055)
	crossbar.mesh = crossbar_mesh
	crossbar.position.y = 1.39
	crossbar.material_override = iron
	root.add_child(crossbar)
	for x: float in [-0.16, 0.0, 0.16]:
		var tine := MeshInstance3D.new()
		var tine_mesh := CylinderMesh.new()
		tine_mesh.height = 0.40
		tine_mesh.top_radius = 0.0
		tine_mesh.bottom_radius = 0.022
		tine.mesh = tine_mesh
		tine.position = Vector3(x, 1.61, 0.0)
		tine.material_override = iron
		root.add_child(tine)
	return root

func _make_bow() -> Node3D:
	var root := Node3D.new()
	root.name = "HuntingBow"
	# Bow limbs run along local Y. Hand bones use the forearm as their primary
	# axis on the shared 53-bone package, so a quarter turn places the bow across
	# the wrist instead of continuing straight through the arm.
	root.rotation_degrees.z = 90.0
	var wood := _make_weapon_material(Color(0.30, 0.105, 0.025), 0.74, 0.0)
	var string_material := _make_weapon_material(Color(0.70, 0.65, 0.52), 0.92, 0.0)
	for upper: bool in [false, true]:
		var side := 1.0 if upper else -1.0
		var limb := MeshInstance3D.new()
		var limb_mesh := BoxMesh.new()
		limb_mesh.size = Vector3(0.045, 0.72, 0.055)
		limb.mesh = limb_mesh
		limb.position = Vector3(0.0, side * 0.34, 0.13)
		limb.rotation_degrees.x = side * 14.0
		limb.material_override = wood
		root.add_child(limb)
		var bow_string := MeshInstance3D.new()
		var string_mesh := BoxMesh.new()
		string_mesh.size = Vector3(0.010, 0.70, 0.010)
		bow_string.mesh = string_mesh
		bow_string.position = Vector3(0.0, side * 0.35, -0.12)
		bow_string.rotation_degrees.x = -side * 18.0
		bow_string.material_override = string_material
		root.add_child(bow_string)
	return root

func _make_weapon_material(color: Color, roughness_value: float, metallic_value: float) -> StandardMaterial3D:
	var key := _material_cache_key(color, roughness_value, metallic_value)
	if _weapon_material_cache.has(key):
		return _weapon_material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	material.metallic = metallic_value
	_weapon_material_cache[key] = material
	return material

func _material_cache_key(color: Color, roughness_value: float, metallic_value: float) -> String:
	return "%s|%.4f|%.4f" % [color.to_html(true), roughness_value, metallic_value]

func _make_spear() -> Node3D:
	if _uses_imported_phalanx_gear():
		return _instantiate_imported_phalanx_gear(DORY_SPEAR_SCENE, "DorySpear", "SM_Dory_Spear")
	# Non-phalanx spear users retain the lightweight procedural proxy.
	var root := Node3D.new()
	root.name = "DorySpear"

	var wood := _make_weapon_material(Color(0.26, 0.11, 0.035), 0.72, 0.0)
	var bronze := _make_weapon_material(Color(0.62, 0.34, 0.08), 0.28, 0.72)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.height = 2.05
	shaft_mesh.top_radius = 0.026
	shaft_mesh.bottom_radius = 0.030
	shaft.mesh = shaft_mesh
	shaft.position.y = 0.46
	shaft.material_override = wood
	root.add_child(shaft)

	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.height = 0.28
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.085
	tip.mesh = tip_mesh
	tip.position.y = 1.62
	tip.material_override = bronze
	root.add_child(tip)

	var butt := MeshInstance3D.new()
	var butt_mesh := CylinderMesh.new()
	butt_mesh.height = 0.14
	butt_mesh.top_radius = 0.035
	butt_mesh.bottom_radius = 0.055
	butt.mesh = butt_mesh
	butt.position.y = -0.63
	butt.material_override = bronze
	root.add_child(butt)
	return root

func _make_hammer() -> Node3D:
	var root := Node3D.new()
	root.name = "ColossusWarHammer"

	var wood := _make_weapon_material(Color(0.19, 0.065, 0.018), 0.78, 0.0)
	var bronze := _make_weapon_material(Color(0.45, 0.24, 0.055), 0.28, 0.76)
	var iron := _make_weapon_material(Color(0.24, 0.27, 0.30), 0.18, 0.90)

	var haft := MeshInstance3D.new()
	var haft_mesh := CylinderMesh.new()
	haft_mesh.height = 1.34
	haft_mesh.top_radius = 0.040
	haft_mesh.bottom_radius = 0.048
	haft.mesh = haft_mesh
	haft.position.y = 0.42
	haft.material_override = wood
	root.add_child(haft)

	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.height = 0.22
	collar_mesh.top_radius = 0.075
	collar_mesh.bottom_radius = 0.065
	collar.mesh = collar_mesh
	collar.position.y = 1.04
	collar.material_override = bronze
	root.add_child(collar)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.64, 0.30, 0.30)
	head.mesh = head_mesh
	head.position.y = 1.13
	head.material_override = iron
	root.add_child(head)

	for side: float in [-1.0, 1.0]:
		var striking_face := MeshInstance3D.new()
		var face_mesh := CylinderMesh.new()
		face_mesh.height = 0.12
		face_mesh.top_radius = 0.20
		face_mesh.bottom_radius = 0.16
		striking_face.mesh = face_mesh
		striking_face.position = Vector3(0.37 * side, 1.13, 0.0)
		striking_face.rotation_degrees.z = 90.0
		striking_face.material_override = bronze
		root.add_child(striking_face)
	return root

func _make_axe() -> Node3D:
	var root := Node3D.new()
	root.name = "WarAxe"

	var wood := _make_weapon_material(Color(0.22, 0.075, 0.022), 0.76, 0.0)
	var steel := _make_weapon_material(Color(0.38, 0.43, 0.48), 0.20, 0.88)
	var bronze := _make_weapon_material(Color(0.52, 0.27, 0.055), 0.30, 0.68)

	var haft := MeshInstance3D.new()
	var haft_mesh := CylinderMesh.new()
	haft_mesh.height = 1.12
	haft_mesh.top_radius = 0.032
	haft_mesh.bottom_radius = 0.040
	haft.mesh = haft_mesh
	haft.position.y = 0.43
	haft.material_override = wood
	root.add_child(haft)

	var socket := MeshInstance3D.new()
	var socket_mesh := BoxMesh.new()
	socket_mesh.size = Vector3(0.34, 0.16, 0.105)
	socket.mesh = socket_mesh
	socket.position = Vector3(0.0, 0.96, 0.0)
	socket.material_override = bronze
	root.add_child(socket)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.34, 0.32, 0.075)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.27, 0.92, 0.0)
	blade.rotation_degrees.z = -12.0
	blade.material_override = steel
	root.add_child(blade)
	return root

func _make_shield() -> Node3D:
	if _uses_imported_phalanx_gear():
		var imported_root := _instantiate_imported_phalanx_gear(ASPIS_SHIELD_SCENE, "AspisShield", "SM_Aspis_Shield")
		# The Blender aspis is authored with its handle side on the attachment's
		# outward axis. Rotate only the imported visual so the bronze face points
		# away from the left forearm. The physical guard root/hitbox keeps its
		# existing hand-space orientation.
		var imported_visual := imported_root.get_child(0) as Node3D if imported_root.get_child_count() > 0 else null
		if imported_visual != null:
			imported_visual.rotation.y = PI
			imported_visual.set_meta("aspis_face_corrected", true)
		return imported_root
	var root := Node3D.new()
	var shield := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = 0.09
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.48
	shield.mesh = mesh
	shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var material := _make_weapon_material(Color(0.52, 0.29, 0.075), 0.31, 0.72)
	shield.material_override = material
	root.add_child(shield)

	# The raised bronze boss makes the aspis readable even when every regular
	# soldier shares the same faction tunic colour.
	var boss := MeshInstance3D.new()
	boss.name = "ShieldBoss"
	var boss_mesh := SphereMesh.new()
	boss_mesh.radius = 0.13
	boss_mesh.height = 0.12
	boss.mesh = boss_mesh
	boss.position.z = -0.065
	boss.material_override = material
	root.add_child(boss)
	return root

func _instantiate_imported_phalanx_gear(scene: PackedScene, root_name: String, mesh_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	var imported_visual: Node = scene.instantiate()
	var equipment_mesh: MeshInstance3D = imported_visual as MeshInstance3D
	if equipment_mesh == null or equipment_mesh.name != mesh_name:
		equipment_mesh = imported_visual.find_child(mesh_name, true, false) as MeshInstance3D
	imported_visual.name = "Imported%sVisual" % root_name
	root.add_child(imported_visual)
	if equipment_mesh == null:
		push_error("[PHALANX EQUIPMENT] %s is missing from %s" % [mesh_name, scene.resource_path])
	return root

func _find_hand_bone(right: bool) -> String:
	if skeleton == null:
		return ""
	var desired_side: String = "r" if right else "l"
	var best_name: String = ""
	var best_score: int = -999
	for i: int in range(skeleton.get_bone_count()):
		var bone: String = skeleton.get_bone_name(i)
		var low: String = bone.to_lower()
		var compact: String = low.replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
		var score: int = 0
		if "hand" in compact:
			score += 30
		if "wrist" in compact:
			score += 12
		if "finger" in compact or "thumb" in compact:
			score -= 30
		var side: String = _bone_side(bone)
		if side == desired_side:
			score += 45
		elif side != "":
			score -= 60
		if score > best_score:
			best_score = score
			best_name = bone
	return best_name if best_score >= 25 else ""

func _bone_side(raw: String) -> String:
	var s: String = raw.to_lower()
	if ".r" in s or "_r" in s or "-r" in s or "right" in s:
		return "r"
	if ".l" in s or "_l" in s or "-l" in s or "left" in s:
		return "l"
	var compact: String = s.replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
	if compact.ends_with("r"):
		return "r"
	if compact.ends_with("l"):
		return "l"
	return ""

func _set_visual_shadows_enabled(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_set_visual_shadows_enabled(child, enabled)

func _override_mesh_materials(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child: Node in node.get_children():
		_override_mesh_materials(child, material)

func _disable_animation_trees(node: Node) -> void:
	if node is AnimationTree:
		(node as AnimationTree).active = false
	for child: Node in node.get_children():
		_disable_animation_trees(child)

func _find_best_animation_player(root: Node) -> AnimationPlayer:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	var best: AnimationPlayer = null
	var count_best: int = -1
	for p: AnimationPlayer in players:
		var count: int = p.get_animation_list().size()
		if count > count_best:
			count_best = count
			best = p
	return best

func _collect_animation_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for child: Node in node.get_children():
		_collect_animation_players(child, out)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var result: Skeleton3D = _find_skeleton(child)
		if result != null:
			return result
	return null

func _make_missing_marker() -> void:
	var label := Label3D.new()
	label.text = "UAL1 MISSING"
	label.position = Vector3(0, 1.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
