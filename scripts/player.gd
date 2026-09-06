extends CharacterBody3D
class_name HopliteUALNativePlayer

signal slide_slash_contact(target: Node)
signal combat_hit(target: Node, zone: StringName, hit: Variant)
signal combat_attack_started(slot: StringName, context: StringName, power: float)
signal damage_received(damage: float, attacker: Node)
signal combat_blocked(blocked_damage: float, attacker: Node)
signal perfect_response_started(kind: StringName)
signal perfect_response_consumed
signal movement_sfx_requested(kind: StringName)
signal combat_resources_changed
signal player_skin_changed(skin_id: StringName)
signal player_skin_parts_changed
signal equipment_changed(slot: HopliteEquipmentItemData.Slot, item: HopliteEquipmentItemData)

const DriverScript = preload("res://scripts/animation/native_animation_driver.gd")
const TrailScript = preload("res://scripts/animation/sword_trail.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")
const CombatFeedbackScript = preload("res://scripts/combat/combat_feedback.gd")
const PlayerCombatHUDScript = preload("res://scripts/ui/player_combat_hud.gd")
const PlayerPresentationScript = preload("res://scripts/ui/player_presentation.gd")
const CameraOcclusionFaderScript = preload("res://scripts/camera/camera_occlusion_fader.gd")
const PlayerSkinCatalogScript = preload("res://scripts/player/player_skin_catalog.gd")
const WeaponTuningScript = preload("res://scripts/equipment/weapon_tuning.gd")
const SkillRuntimeScript = preload("res://scripts/abilities/skill_runtime.gd")
var skills: Node
const UAL1_PATH := "res://assets/runtime/ual1/UAL1_Standard.glb"
const PLAYER_SKIN_BASE: StringName = &"base"
const PLAYER_SKIN_NOON: StringName = &"noon_t1"
const PLAYER_SKIN_SAMUS: StringName = &"samus_woopsy"
const PLAYER_SKINS: Array[Dictionary] = [
	{"id": PLAYER_SKIN_BASE, "label": "HOPLITE D'ORIGINE", "path": UAL1_PATH},
	{"id": PLAYER_SKIN_NOON, "label": "NOON T1", "path": "res://assets/characters/player_skins/noonT1.glb"},
	{"id": PLAYER_SKIN_SAMUS, "label": "SAMUS WOOPSY", "path": "res://assets/characters/player_skins/samusWoopsy.glb"},
]
const DEFAULT_WEAPON := preload("res://data/equipment/weapons/xiphos.tres")
const DEFAULT_SHIELD := preload("res://data/equipment/shields/aspis.tres")
const GLOBAL_SETTINGS_PATH: String = "user://hoplite_global_settings_v1.cfg"
const CAMERA_SETTINGS_PATH: String = "user://hoplite_camera_settings_v1.cfg"
const CAMERA_DISTANCE_MIN: float = 1.0
const CAMERA_DISTANCE_MAX: float = 12.0
const EPIC_WALL_RUN_LOOK_INPUT_SCALE: float = 0.12
const EPIC_RUN_CAMERA_SETTING_DEFINITIONS: Array[Dictionary] = [
	{"id": &"shield_camera_height", "group": "SHIELD RUN", "label": "HAUTEUR CAMÉRA", "min": -0.4, "max": 1.4, "step": 0.05, "default": 0.10, "unit": "m", "description": "Hauteur de base de la caméra par rapport aux pieds du joueur."},
	{"id": &"shield_camera_distance", "group": "SHIELD RUN", "label": "DISTANCE CAMÉRA", "min": 3.0, "max": 9.0, "step": 0.1, "default": 3.0, "unit": "m", "description": "Distance finale derrière le joueur. Une valeur élevée réduit l'effet de rapprochement."},
	{"id": &"shield_camera_pitch", "group": "SHIELD RUN", "label": "ANGLE VERS LE HAUT", "min": 0.0, "max": 28.0, "step": 0.5, "default": 6.5, "unit": "deg", "description": "Contre-plongée appliquée depuis la caméra basse."},
	{"id": &"shield_fov_zoom", "group": "SHIELD RUN", "label": "PUISSANCE DU ZOOM FOV", "min": 0.0, "max": 12.0, "step": 0.25, "default": 6.0, "unit": "deg", "description": "Réduction du champ de vision. Zéro conserve le FOV du wall run ordinaire."},
	{"id": &"shield_time_scale", "group": "SHIELD RUN", "label": "VITESSE DU MONDE", "min": 0.45, "max": 1.0, "step": 0.01, "default": 0.90, "unit": "percent", "description": "Pourcentage de vitesse du monde pendant le run. Plus bas signifie davantage de ralenti."},
	{"id": &"shield_transition_duration", "group": "SHIELD RUN", "label": "DURÉE EASE IN / OUT", "min": 0.12, "max": 1.0, "step": 0.02, "default": 0.30, "unit": "s", "description": "Temps de montée et de sortie du cadrage cinématique."},
	{"id": &"giant_camera_height", "group": "GIANT RUN", "label": "HAUTEUR CAMÉRA", "min": -1.2, "max": 0.8, "step": 0.05, "default": 0.10, "unit": "m", "description": "Position verticale de la caméra de contre-plongée."},
	{"id": &"giant_camera_distance", "group": "GIANT RUN", "label": "DISTANCE CAMÉRA", "min": 3.0, "max": 10.0, "step": 0.1, "default": 3.0, "unit": "m", "description": "Distance finale de la caméra basse derrière le déplacement."},
	{"id": &"giant_camera_pitch", "group": "GIANT RUN", "label": "ANGLE VERS LE HAUT", "min": 5.0, "max": 42.0, "step": 0.5, "default": 22.0, "unit": "deg", "description": "Force de la contre-plongée regardant le joueur depuis dessous."},
	{"id": &"giant_fov_zoom", "group": "GIANT RUN", "label": "PUISSANCE DU ZOOM FOV", "min": 0.0, "max": 12.0, "step": 0.25, "default": 4.0, "unit": "deg", "description": "Réduction du champ de vision, indépendante de la distance caméra."},
	{"id": &"giant_time_scale", "group": "GIANT RUN", "label": "VITESSE DU MONDE", "min": 0.45, "max": 1.0, "step": 0.01, "default": 0.70, "unit": "percent", "description": "Pourcentage de vitesse du monde pendant le Giant Run."},
	{"id": &"giant_transition_duration", "group": "GIANT RUN", "label": "DURÉE EASE IN / OUT", "min": 0.12, "max": 1.0, "step": 0.02, "default": 0.40, "unit": "s", "description": "Temps de montée et de sortie de la contre-plongée."},
]

# Fast, momentum-preserving locomotion. Steering changes direction without
# shrinking the horizontal velocity vector, so turning does not cost speed.
var max_speed: float = 7.2
var acceleration: float = 9.2
var deceleration: float = 13.5
var air_acceleration: float = 4.8
var movement_turn_response: float = 22.0
var air_turn_response: float = 10.0
var turn_speed: float = 14.0
var jump_velocity: float = 8.8
var gravity: float = 24.0
var max_jumps: int = 2
var jumps_used: int = 0

# No authored landing recovery: touching the floor returns immediately to
# locomotion, unless a slide was armed in the air.
var dash_speed: float = 19.0
var dash_end_speed: float = 12.0
var dash_duration: float = 0.27
var dash_time: float = 0.0
var dash_cooldown: float = 0.38
var dash_cooldown_timer: float = 0.0
var dash_variant_grace: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_max_charges: int = 1
var dash_charges: int = 1
var dash_recharge_duration: float = 3.0
var dash_recharge_timer: float = 0.0

# CTRL slide: 70% of dash top speed, 60% of the implemented dash distance.
var slide_speed_ratio: float = 0.70
var slide_distance_ratio: float = 0.60
var slide_time: float = 0.0
var slide_armed: bool = false
var slide_direction: Vector3 = Vector3.ZERO
var slide_turn_response: float = 8.0
# UAL2 Slide is authored around the donor hips/root height. The CharacterBody
# origin is at the feet, so lower only the visible mannequin while sliding.
# This does NOT move the collider or add root motion.
var slide_visual_drop: float = 0.62
var slide_visual_vertical_speed: float = 14.0
var slide_slash_active_time: float = 0.0
var slide_slash_radius: float = 1.05
var slide_slash_contacts: Dictionary = {}
var slide_max_charges: int = 2
var slide_charges: int = 2
var slide_recharge_duration: float = 1.5
var slide_recharge_timer: float = 0.0

var parkour_active: bool = false
var parkour_kind: StringName = StringName()
var parkour_elapsed: float = 0.0
var parkour_duration: float = 0.0
var parkour_start: Vector3 = Vector3.ZERO
var parkour_end: Vector3 = Vector3.ZERO
var parkour_arc: float = 0.0
var parkour_exit_direction: Vector3 = Vector3.ZERO
# A mantle that takes priority over an active wall run must rearm the wall-run
# gate on exit. Waiting for is_on_floor() leaves a one-frame hole where an
# immediate jump can keep wall running locked for the whole airborne phase.
var parkour_started_from_wall_run: bool = false
# CTRL pressed during vault/mantle is buffered and converted into a slide on exit.
var parkour_slide_queued: bool = false
var parkour_debug_reason: String = "ready"
var parkour_probe_distance: float = 1.65
var parkour_min_height: float = 0.30
var parkour_vault_max_height: float = 1.20
var parkour_max_height: float = 2.75
# If CTRL was buffered during a mantle, trim the last ~20% of the authored
# climb and hand control straight to the slide. At this point the body is
# already essentially on top of the ledge, so the tiny snap to parkour_end is
# preferable to a visible pause between mantle and slide.
var parkour_slide_early_exit_progress: float = 0.80

# Airborne wall running. One airborne sequence allows two wall contacts total;
# touching the ground resets the sequence. Passive detachment never rearms it.
const ENEMY_BODY_COLLISION_LAYER: int = 4
const PHALANX_SHIELD_WALL_RUN_LAYER: int = 64
const GIANT_TRAVERSAL_COLLISION_LAYER: int = 256
const GIANT_TRAVERSAL_SURFACE_GROUP: StringName = &"giant_wall_run_surface"

# ONE-SWITCH ROLLBACK: set this to false to restore world-only wall running.
# Enemy bodies and shields keep their normal collision behavior either way.
@export var experimental_enemy_wall_run_enabled: bool = true
var experimental_enemy_wall_run_min_scale: float = 1.55
var experimental_phalanx_shield_min_count: int = 3
var experimental_phalanx_shield_neighbor_radius: float = 2.45
var experimental_dynamic_release_repulsion_scale: float = 0.20
var wall_run_active: bool = false
var wall_run_mode: StringName = StringName()
var wall_run_surface_kind: StringName = &"world"
var wall_run_normal: Vector3 = Vector3.ZERO
var wall_run_last_tangent: Vector3 = Vector3.ZERO
var wall_run_distance: float = 0.0
var wall_run_vertical_rise: float = 0.0
var wall_run_vertical_time: float = 0.0
var wall_run_attach_available: bool = true
var wall_run_attach_cooldown: float = 0.0
var wall_run_repulsion_control_lock: float = 0.0
var wall_run_repulsion_control_lock_duration: float = 0.18
var wall_run_chain_armed_by_jump: bool = false
var wall_run_passive_detach_locked: bool = false
var wall_run_release_input_guard: bool = false
var wall_run_release_input_guard_timer: float = 0.0
var wall_run_release_input_guard_duration: float = 0.06
var wall_run_release_normal: Vector3 = Vector3.ZERO
var wall_run_just_started: bool = false
var wall_run_runs_used: int = 0
var wall_run_max_chain_runs: int = 2
var wall_run_debug_reason: String = "ready"
var wall_run_max_distance: float = 10.0
var wall_run_probe_distance: float = 0.92
var wall_run_horizontal_speed: float = 9.2
var wall_run_diagonal_speed: float = 7.7
var wall_run_diagonal_vertical_speed: float = 3.4
var wall_run_vertical_speed: float = 5.8
var wall_run_vertical_max_rise: float = 2.65
var wall_run_vertical_max_time: float = 0.72
var wall_run_wall_pressure: float = 1.45
var wall_jump_up_speed: float = 8.6
var wall_jump_tangent_speed: float = 4.6
var wall_run_horizontal_repulsion_angle: float = 25.0
var wall_run_horizontal_repulsion_force: float = 8.8
var wall_run_diagonal_repulsion_angle: float = 50.0
var wall_run_diagonal_repulsion_force: float = 10.0
var wall_run_vertical_repulsion_angle: float = 90.0
var wall_run_vertical_repulsion_force: float = 11.2
var wall_run_horizontal_detach_momentum_retention: float = 1.0
var wall_run_horizontal_detach_repulsion_scale: float = 0.10
var wall_run_corner_max_angle: float = 100.0
var wall_run_corner_follow_active: bool = false
var wall_run_corner_tangent: Vector3 = Vector3.ZERO
var wall_run_corner_input_reference: Vector3 = Vector3.ZERO
var wall_run_lateral_min_tangent: float = 0.18
var giant_traversal_support_active: bool = false

var visual_root: Node3D
var visual_flipped: bool = true
var mannequin_scene: Node
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_driver: HopliteNativeAnimationDriver
var player_skin_id: StringName = PLAYER_SKIN_BASE
var player_skins: Array[Dictionary] = []
var player_skin_parts: Array[Dictionary] = []
var visual_base_height := 0.0

var camera_yaw: Node3D
var camera_pitch: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var camera_occlusion_fader: HopliteCameraOcclusionFader
var camera_mode: int = 0
var camera_pitch_value: float = -0.20
var camera_distance: float = 3.5
var camera_pivot_height: float = 1.68
var camera_shoulder_offset: float = 0.0
var mouse_sensitivity: float = 0.00105
var camera_rest_pitch: float = -0.20
var camera_base_fov: float = 72.0
var epic_wall_run_camera_settings: Dictionary = {}

var right_hand_bone: String = ""
var left_hand_bone: String = ""
var sword_attachment: BoneAttachment3D
var shield_attachment: BoneAttachment3D
var sword_root: Node3D
var shield_root: Node3D
var shield_rest_transform: Transform3D = Transform3D.IDENTITY
var sword_base: Marker3D
var sword_tip: Marker3D
var sword_trail: HopliteNativeSwordTrail
var sword_blade_material: StandardMaterial3D
var sword_base_color: Color = Color(0.72, 0.76, 0.78)
var sword_preset: int = 0
var shield_visible: bool = true
var equipped_weapon: HopliteEquipmentItemData = DEFAULT_WEAPON
var equipped_shield: HopliteEquipmentItemData = DEFAULT_SHIELD
var nearby_equipment_pickups: Array[Area3D] = []
var current_weapon_tuning: Dictionary = {}

# V0.0.3 weapon contact: the WHOLE blade is a swept capsule. We sample the
# previous/current blade transforms so fast animation frames cannot tunnel
# through thin anatomy zones. One enemy can still be damaged once per swing.
var weapon_hit_radius: float = 0.12
var weapon_damage_multiplier: float = 1.0
var weapon_hit_mask: int = 8
var previous_sword_base_position: Vector3 = Vector3.ZERO
var previous_sword_tip_position: Vector3 = Vector3.ZERO
var weapon_hit_targets: Dictionary = {}
var weapon_swing_active: bool = false
var weapon_whoosh_emitted: bool = false
var weapon_last_slot: StringName = StringName()
var weapon_last_progress: float = 0.0
var last_heavy_release_ratio: float = 0.0

# One primary mouse button handles both attack weights: release before the
# threshold for a light, keep holding to enter the heavy charge pose.
var primary_attack_held: bool = false
var primary_hold_time: float = 0.0
var primary_heavy_started: bool = false
var primary_heavy_threshold: float = 0.22

# Smooth three-dimensional aim assist. Ordinary attacks keep a bounded horizontal
# correction; airborne attacks also adjust altitude progressively toward the target.
var aim_assist_enabled: bool = true
var aim_assist_max_distance: float = 3.90
var aim_assist_cone_degrees: float = 40.0
var aim_assist_max_correction_degrees: float = 19.0
var attack_assist_target: Node3D
var attack_assist_slot: StringName = StringName()
var attack_assist_context: StringName = &"idle"
var attack_assist_startup_remaining: float = 0.0
var attack_assist_lock_remaining: float = 0.0
var attack_assist_lunge_remaining: float = 0.0
var attack_assist_ideal_distance: float = 1.80
var attack_assist_rotation_degrees: float = 0.0
var attack_assist_initial_direction: Vector3 = Vector3.FORWARD
var attack_facing_direction: Vector3 = Vector3.FORWARD
var attack_assist_vertical_response: float = 8.0
var attack_assist_max_vertical_speed: float = 8.5
var combat_feedback: HopliteCombatFeedback
var player_combat_hud: CanvasLayer
var player_presentation: HoplitePlayerPresentation

# H combat diagnostics (F8 is reserved by the Godot editor to stop the running project).
var combat_debug_visible: bool = false
var debug_blade_mesh: MeshInstance3D
var debug_sweep_mesh_instance: MeshInstance3D
var debug_sweep_mesh: ImmediateMesh
var debug_line_material: StandardMaterial3D
var debug_last_zone: StringName = StringName()
var debug_last_blade_speed: float = 0.0
var debug_last_candidates: String = "none"

var light_step: int = 0
var combo_timer: float = 0.0
var combo_light_count: int = 0
var heavy_charging: bool = false
var heavy_charge_pose_started: bool = false
var heavy_charge: float = 0.0
var heavy_charge_max: float = 1.55
var heavy_charge_context: StringName = &"idle"
var fast_heavy_candidate: bool = false
var heavy_charge_max_feedback_emitted: bool = false
var spin_active_time: float = 0.0
var spin_total_time: float = 0.0
var spin_rotation_total: float = 0.0
var spin_vertical_direction: int = 0
var spin_input_cooldown_timer: float = 0.0
var spin_up_air_used: bool = false
var combat_refusal_log_msec: int = -2000
var spiral_active_request_id: int = 0
var next_combat_action_request_id: int = 1
var spiral_down_air_impact_pending: bool = false
var spiral_down_air_hit_targets: Dictionary = {}
var spiral_down_enemy_passthrough: bool = false
var spiral_down_collision_restore_timer: float = 0.0
var spiral_down_saved_collision_layer: int = 0
var spiral_down_saved_collision_mask: int = 0
var spiral_down_impact_radius: float = 4.15
var spiral_down_impact_damage: float = 68.0
var spiral_down_impact_sever_damage: float = 38.0
var spiral_down_impact_guard_damage: float = 120.0
var spiral_down_impact_knockback: float = 2.8
var max_spiral_stamina: float = 12.0
var spiral_stamina: float = 0.0
var spiral_stamina_cost: float = 3.0
var spiral_hit_reward: float = 1.0
var spiral_perfect_reward: float = 2.0

# RMB shield defense. Blocking is deliberately directional: the aspis stops
# attacks in a generous frontal arc but does not protect the player's back.
var shield_blocking: bool = false
var shield_block_half_angle_degrees: float = 62.0
var shield_move_multiplier: float = 0.48
var last_blocked_damage: float = 0.0

# A late guard/dash opens a short real-time response window. Time ownership and
# the smooth slow-motion envelope live in CombatFeedback so gameplay code remains
# deterministic even while Engine.time_scale changes.
var perfect_block_timing_ms: int = 220
var perfect_dodge_timing_ms: int = 190
var perfect_slide_timing_ms: int = 230
var shield_block_started_ms: int = -100000
var dodge_started_ms: int = -100000
var slide_started_ms: int = -100000
var perfect_response_source: Node3D
var perfect_counter_range: float = 7.25
var perfect_counter_dash_active: bool = false
var perfect_counter_dash_duration: float = 0.34
var perfect_counter_dash_speed: float = 25.0
var counter_light_animation_cursor: int = 0
var counter_dash_animation_cursor: int = 0
var perfect_counter_aoe_pending: bool = false
var perfect_counter_aoe_radius: float = 3.75
var perfect_counter_aoe_damage: float = 82.0

# Lightweight player health for the first enemy-AI combat lab. This is deliberately
# separate from the future Spartan anatomy system; it only proves enemy attacks.
var max_health: float = 300.0
var health: float = 300.0
var enemy_hit_invulnerability: float = 0.22
var enemy_hit_invulnerability_timer: float = 0.0
var last_enemy_damage: float = 0.0
var health_regen_delay: float = 5.0
var health_regen_elapsed: float = 0.0
var health_regen_rate: float = 9.0
var perfect_regen_rate: float = 24.0
var perfect_recovery_active: bool = false
var perfect_recovery_damage_multiplier: float = 1.20

var resource_error: String = ""
var debug_text: String = ""
var debug_text_time_left := 0.0
var weapon_sweep_capsule := CapsuleShape3D.new()
var weapon_sweep_query := PhysicsShapeQueryParameters3D.new()
var weapon_sweep_candidates: Dictionary = {}
var slide_slash_sphere := SphereShape3D.new()
var slide_slash_query := PhysicsShapeQueryParameters3D.new()
var slide_slash_candidates: Dictionary = {}
var wall_run_raycast_query := PhysicsRayQueryParameters3D.new()
var world_raycast_query := PhysicsRayQueryParameters3D.new()
var attack_assist_los_query := PhysicsRayQueryParameters3D.new()
var self_raycast_exclusion: Array[RID] = []

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	# Layers 128/256 are reserved for Forge giant tops/smooth traversal bodies.
	collision_mask = 1 | 4 | 128 | GIANT_TRAVERSAL_COLLISION_LAYER
	_ensure_slide_input_action()
	_build_collider()
	_configure_combat_queries()
	_load_camera_settings()
	_build_camera()
	combat_feedback = CombatFeedbackScript.new() as HopliteCombatFeedback
	combat_feedback.name = "CombatFeedback"
	add_child(combat_feedback)
	combat_feedback.configure(camera, self)
	combat_feedback.configure_epic_wall_run_settings(epic_wall_run_camera_settings)
	skills = SkillRuntimeScript.new()
	skills.name = "Skills"
	add_child(skills)
	skills.configure(self)
	player_combat_hud = PlayerCombatHUDScript.new() as CanvasLayer
	player_combat_hud.name = "PlayerCombatHUD"
	add_child(player_combat_hud)
	player_combat_hud.call("configure", self)
	player_presentation = PlayerPresentationScript.new() as HoplitePlayerPresentation
	player_presentation.name = "PlayerPresentation"
	add_child(player_presentation)
	player_presentation.configure(self)
	player_skins = PlayerSkinCatalogScript.scan()
	player_skin_id = _load_saved_player_skin_id()
	if not _load_player_skin(player_skin_id):
		var failed_skin := player_skin_id
		player_skin_id = PLAYER_SKIN_BASE
		_load_player_skin(player_skin_id)
		push_warning("[PLAYER SKIN] Could not load %s; using the base Hoplite." % String(failed_skin))
	if sword_base != null and sword_tip != null:
		previous_sword_base_position = sword_base.global_position
		previous_sword_tip_position = sword_tip.global_position
		_build_weapon_debug_visuals()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_collider() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.82
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.91, 0.0)
	add_child(collision)

func _build_camera() -> void:
	camera_yaw = Node3D.new()
	camera_yaw.name = "CameraYaw"
	camera_yaw.top_level = true
	get_tree().current_scene.add_child(camera_yaw)
	camera_yaw.global_position = global_position + Vector3(0.0, camera_pivot_height, 0.0)
	camera_pitch = Node3D.new()
	camera_yaw.add_child(camera_pitch)
	camera_pitch.rotation.x = camera_pitch_value
	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = camera_distance
	spring_arm.position.x = camera_shoulder_offset
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.12
	camera_pitch.add_child(spring_arm)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = camera_base_fov
	spring_arm.add_child(camera)
	camera_occlusion_fader = CameraOcclusionFaderScript.new() as HopliteCameraOcclusionFader
	camera_occlusion_fader.name = "CameraOcclusionFader"
	add_child(camera_occlusion_fader)
	camera_occlusion_fader.configure(camera, self, spring_arm)

func _load_player_skin(skin_id: StringName) -> bool:
	var definition := _player_skin_definition(skin_id)
	if definition.is_empty():
		resource_error = "Unknown player skin: " + String(skin_id)
		return false
	visual_base_height = 0.0
	visual_root = Node3D.new()
	visual_root.name = "PlayerSkin_%s" % String(skin_id)
	add_child(visual_root)
	visual_root.rotation.y = PI if visual_flipped else 0.0
	var skin_path := String(definition["path"])
	var packed: PackedScene = load(skin_path) as PackedScene
	if packed == null:
		resource_error = "Player skin GLB missing: " + skin_path
		if skin_id == PLAYER_SKIN_BASE:
			_missing_marker()
		return false
	mannequin_scene = packed.instantiate()
	visual_root.add_child(mannequin_scene)
	_disable_animation_trees(mannequin_scene)
	animation_player = _find_best_animation_player(mannequin_scene)
	skeleton = _find_skeleton(mannequin_scene)
	if skeleton == null or animation_player == null:
		resource_error = "Player skin Skeleton3D/AnimationPlayer not found: " + skin_path
		return false
	animation_player.stop()
	if skin_id == PLAYER_SKIN_BASE:
		_tint_mannequin()
	right_hand_bone = _find_hand_bone(true)
	left_hand_bone = _find_hand_bone(false)
	if right_hand_bone == "" or left_hand_bone == "":
		resource_error = "Player skin hand bones are incompatible: " + skin_path
		return false
	_discover_player_skin_parts(skin_id)
	_build_weapons()
	animation_driver = DriverScript.new() as HopliteNativeAnimationDriver
	animation_driver.name = "NativeUALDriver_%s" % String(skin_id)
	add_child(animation_driver)
	if not animation_driver.configure(mannequin_scene, skeleton, animation_player):
		resource_error = "Native UAL animation setup failed for skin: " + skin_path
		return false
	_connect_animation_driver_action_signals()
	if skin_id != PLAYER_SKIN_BASE:
		call_deferred("_ground_player_skin_visual")
	print("[PLAYER SKIN] %s active — UAL animation and hand equipment ready" % String(definition["label"]))
	return true


func _connect_animation_driver_action_signals() -> void:
	if animation_driver == null:
		return
	if not animation_driver.combat_action_started.is_connected(_on_combat_action_started):
		animation_driver.combat_action_started.connect(_on_combat_action_started)
	if not animation_driver.combat_action_finished.is_connected(_on_combat_action_finished):
		animation_driver.combat_action_finished.connect(_on_combat_action_finished)
	if not animation_driver.combat_actions_cancelled.is_connected(_on_combat_actions_cancelled):
		animation_driver.combat_actions_cancelled.connect(_on_combat_actions_cancelled)


func toggle_player_visual() -> bool:
	cycle_player_skin()
	return uses_alternate_visual()

func uses_alternate_visual() -> bool:
	return player_skin_id != PLAYER_SKIN_BASE

func cycle_player_skin() -> StringName:
	_ensure_player_skin_catalog()
	var next_index := (get_player_skin_index() + 1) % player_skins.size()
	set_player_skin_by_index(next_index)
	return player_skin_id

func set_player_skin_by_index(index: int) -> bool:
	_ensure_player_skin_catalog()
	if index < 0 or index >= player_skins.size():
		return false
	return set_player_skin(StringName(player_skins[index]["id"]))

func set_player_skin(requested_id: StringName) -> bool:
	if _player_skin_definition(requested_id).is_empty():
		requested_id = PLAYER_SKIN_BASE
	if requested_id == player_skin_id and visual_root != null and animation_driver != null:
		return true
	_clear_visual_setup()
	resource_error = ""
	if _load_player_skin(requested_id):
		player_skin_id = requested_id
		_reset_visual_combat_state()
		player_skin_changed.emit(player_skin_id)
		return true
	var skin_error := resource_error
	_clear_visual_setup()
	player_skin_id = PLAYER_SKIN_BASE
	_load_player_skin(player_skin_id)
	_reset_visual_combat_state()
	player_skin_changed.emit(player_skin_id)
	if skin_error != "":
		push_warning("[PLAYER SKIN] Fallback to base: " + skin_error)
	return false

func get_player_skin_id() -> StringName:
	return player_skin_id

func get_player_skin_index() -> int:
	_ensure_player_skin_catalog()
	for index: int in range(player_skins.size()):
		if StringName(player_skins[index]["id"]) == player_skin_id:
			return index
	return 0

func get_player_skin_definitions() -> Array[Dictionary]:
	_ensure_player_skin_catalog()
	return player_skins.duplicate(true)

func get_player_skin_parts() -> Array[Dictionary]:
	return player_skin_parts.duplicate(true)

func get_player_skin_label() -> String:
	var definition := _player_skin_definition(player_skin_id)
	return String(definition.get("label", "HOPLITE D'ORIGINE"))

func _player_skin_definition(skin_id: StringName) -> Dictionary:
	_ensure_player_skin_catalog()
	for definition: Dictionary in player_skins:
		if StringName(definition["id"]) == skin_id:
			return definition
	return {}

func _ensure_player_skin_catalog() -> void:
	if player_skins.is_empty():
		player_skins = PlayerSkinCatalogScript.scan()

func _load_saved_player_skin_id() -> StringName:
	var config := ConfigFile.new()
	if config.load(GLOBAL_SETTINGS_PATH) != OK:
		return PLAYER_SKIN_BASE
	var saved_id := StringName(config.get_value("display", "player_skin", String(PLAYER_SKIN_BASE)))
	return saved_id if not _player_skin_definition(saved_id).is_empty() else PLAYER_SKIN_BASE

func _ground_player_skin_visual() -> void:
	if player_skin_id == PLAYER_SKIN_BASE or visual_root == null or skeleton == null:
		return
	var lowest_foot_y := INF
	for bone_name: String in ["DEF-foot.L", "DEF-toe.L", "DEF-foot.R", "DEF-toe.R"]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			lowest_foot_y = minf(lowest_foot_y, skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin).y)
	if is_inf(lowest_foot_y):
		return
	visual_base_height = clampf(global_position.y + 0.015 - lowest_foot_y, -1.0, 1.0)
	visual_root.position.y = visual_base_height
	print("[PLAYER SKIN] %s grounded by %.3f m" % [get_player_skin_label(), visual_base_height])

func set_player_skin_part_enabled(part_id: StringName, enabled: bool) -> bool:
	for index: int in range(player_skin_parts.size()):
		var definition: Dictionary = player_skin_parts[index]
		if StringName(definition.get("id", StringName())) != part_id:
			continue
		var node_path := NodePath(String(definition.get("path", "")))
		var mesh: MeshInstance3D = null
		if mannequin_scene != null:
			mesh = mannequin_scene.get_node_or_null(node_path) as MeshInstance3D
		if mesh == null:
			return false
		mesh.visible = enabled
		definition["enabled"] = enabled
		player_skin_parts[index] = definition
		var config := ConfigFile.new()
		config.load(GLOBAL_SETTINGS_PATH)
		config.set_value(_player_skin_parts_section(player_skin_id), String(part_id), enabled)
		var error := config.save(GLOBAL_SETTINGS_PATH)
		if error != OK:
			push_warning("[PLAYER SKIN PART] Could not save %s: %s" % [String(part_id), error_string(error)])
		player_skin_parts_changed.emit()
		return true
	return false

func _discover_player_skin_parts(skin_id: StringName) -> void:
	player_skin_parts.clear()
	if mannequin_scene == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_player_skin_meshes(mannequin_scene, meshes)
	var config := ConfigFile.new()
	config.load(GLOBAL_SETTINGS_PATH)
	var section := _player_skin_parts_section(skin_id)
	for mesh: MeshInstance3D in meshes:
		var path := String(mannequin_scene.get_path_to(mesh))
		var part_id := StringName(path)
		var enabled := mesh.visible
		if config.has_section_key(section, path):
			enabled = bool(config.get_value(section, path, enabled))
		mesh.visible = enabled
		player_skin_parts.append({
			"id": part_id,
			"path": path,
			"label": _player_skin_mesh_label(mesh),
			"enabled": enabled,
		})

func _collect_player_skin_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_player_skin_meshes(child, output)

func _player_skin_mesh_label(mesh: MeshInstance3D) -> String:
	var label := String(mesh.name).replace("_", " ").capitalize()
	var material_names: Array[String] = []
	if mesh.mesh != null:
		for surface_index: int in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface_index)
			if material != null and material.resource_name != "" and not material.resource_name in material_names:
				material_names.append(material.resource_name)
	if not material_names.is_empty():
		label += " — " + ", ".join(material_names)
	return label

func _player_skin_parts_section(skin_id: StringName) -> String:
	return "player_skin_parts:%s" % String(skin_id)

func _clear_visual_setup() -> void:
	if skills != null:
		skills.cancel_plunge()
		skills.cancel_preparation()
	# Visual replacement can happen during an aerial Spiral Down. It is also an
	# action interruption and must restore the temporary collision policy before
	# the old animation driver (and its signals) is freed.
	_finish_spiral_action(true)
	shield_blocking = false
	weapon_swing_active = false
	heavy_charging = false
	primary_attack_held = false
	if sword_trail != null and is_instance_valid(sword_trail):
		sword_trail.free()
	if animation_driver != null and is_instance_valid(animation_driver):
		animation_driver.free()
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.free()
	visual_root = null
	player_skin_parts.clear()
	visual_base_height = 0.0
	mannequin_scene = null
	skeleton = null
	animation_player = null
	animation_driver = null
	right_hand_bone = ""
	left_hand_bone = ""
	sword_attachment = null
	shield_attachment = null
	sword_root = null
	shield_root = null
	sword_base = null
	sword_tip = null
	sword_trail = null
	sword_blade_material = null

func _reset_visual_combat_state() -> void:
	weapon_hit_targets.clear()
	previous_sword_base_position = sword_base.global_position if sword_base != null else Vector3.ZERO
	previous_sword_tip_position = sword_tip.global_position if sword_tip != null else Vector3.ZERO
	if shield_attachment != null:
		shield_attachment.visible = shield_visible

func _missing_marker() -> void:
	var label: Label3D = Label3D.new()
	label.text = "RUN SETUP_ASSETS.bat"
	label.font_size = 48
	label.modulate = Color(1.0, 0.15, 0.05)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.5, 0)
	visual_root.add_child(label)

func observe_skill_target(target: Node) -> void:
	# Connect before damage: newly spawned enemies may die on their first hit.
	if skills != null: skills.observe_enemy(target)

func _physics_process(delta: float) -> void:
	if skills != null:
		skills.tick(delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	dash_variant_grace = maxf(0.0, dash_variant_grace - delta)
	wall_run_attach_cooldown = maxf(0.0, wall_run_attach_cooldown - delta)
	wall_run_repulsion_control_lock = maxf(0.0, wall_run_repulsion_control_lock - delta)
	wall_run_release_input_guard_timer = maxf(0.0, wall_run_release_input_guard_timer - delta)
	if wall_run_release_input_guard_timer <= 0.0:
		wall_run_release_input_guard = false
	slide_slash_active_time = maxf(0.0, slide_slash_active_time - delta)
	enemy_hit_invulnerability_timer = maxf(0.0, enemy_hit_invulnerability_timer - delta)
	spin_input_cooldown_timer = maxf(0.0, spin_input_cooldown_timer - delta)
	_update_spiral_down_enemy_passthrough(delta)
	_update_mobility_resources(delta)
	_update_health_recovery(delta)

	if parkour_active:
		# Parkour owns movement while active, but CTRL is still accepted as a
		# buffered combo input. The slide starts on the exact frame the mantle/
		# vault finishes instead of being lost by this early return.
		if Input.is_action_just_pressed("slide"):
			_queue_slide_after_parkour()
		_update_parkour(delta)
		if animation_driver != null:
			animation_driver.set_locomotion(0.0)
		return

	var was_on_floor: bool = is_on_floor()
	_sync_spiral_attack_state()
	if is_on_floor():
		_reset_wall_run_after_landing()
	elif wall_run_active:
		if _update_wall_run(delta):
			# Wall movement owns move_and_slide(), but combat still needs its normal
			# blade sweep pass on this physics frame.
			_update_weapon_hit_detection(delta)
			if animation_driver != null:
				animation_driver.set_locomotion(0.0)
			return

	if not is_on_floor():
		var gravity_scale: float = 1.0
		if animation_driver != null:
			var active_slot: StringName = animation_driver.current_attack_slot_name()
			var attack_context: StringName = animation_driver.current_attack_context_name()
			if active_slot == &"spin360" and attack_context == &"air":
				gravity_scale = 2.15 if spin_vertical_direction < 0 else 1.0
		velocity.y -= gravity * gravity_scale * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		jumps_used = 0
		spin_up_air_used = false

	# CTRL on the ground starts the slide immediately. In the air it arms the
	# slide; the slide begins on the exact landing frame, with no landing recovery.
	if Input.is_action_just_pressed("slide") and (skills == null or not skills.controls.wheel.visible):
		_request_slide()

	if Input.is_action_just_pressed("jump") and (skills == null or (skills.active(&"jump") and not skills.controls.wheel.visible)):
		if _try_start_parkour():
			return
		if jumps_used < max_jumps:
			_stop_slide(true, false)
			# Heavy charge is intentionally preserved through jumps.
			var is_second_jump: bool = jumps_used == 1
			velocity.y = skills.jump_speed(jumps_used) if skills != null else (jump_velocity if not is_second_jump else jump_velocity * 0.92)
			jumps_used += 1
			movement_sfx_requested.emit(&"jump")
			if animation_driver != null:
				# A second jump after a wall release interrupts the previous wall donor
				# immediately with the proven diagonal aerial twist. Ordinary jumps keep
				# the exact UAL2 NinjaJump_Start clip.
				var ninja_speed: float = 1.12 if is_second_jump else 1.0
				var wall_twist_started: bool = is_second_jump and animation_driver.play_wall_release_double_jump()
				if not wall_twist_started and animation_driver.play_ninja_jump(ninja_speed) <= 0.0:
					animation_driver.play_full_body(&"jump")

	# A normal jump may put the body in range of a wall on this same physics
	# frame. The just-started guard lets that jump become the vertical approach
	# instead of immediately being interpreted as a wall jump away.
	if not is_on_floor() and _try_start_wall_run():
		if _update_wall_run(delta):
			_update_weapon_hit_detection(delta)
			if animation_driver != null:
				animation_driver.set_locomotion(0.0)
			return

	if Input.is_action_just_pressed("dash") and (skills == null or not skills.controls.wheel.visible):
		if _perfect_response_available() and _do_perfect_counter_dash():
			pass
		elif dash_cooldown_timer <= 0.0 and dash_charges > 0:
			_start_regular_dash()

	var move_dir: Vector3 = _desired_move_direction()
	move_dir = _filter_wall_run_release_input(move_dir)
	var move_multiplier: float = shield_move_multiplier if shield_blocking else (0.55 if heavy_charging else 1.0)

	if skills != null and skills.owns_aura_movement() and skills.aura_velocity.length_squared() > 0.01:
		velocity.x = skills.aura_velocity.x
		velocity.z = skills.aura_velocity.z
		slide_time = maxf(0.0, slide_time - delta)
	elif slide_time > 0.0:
		_update_slide_motion(move_dir, delta)
	elif dash_time > 0.0:
		if skills != null:
			skills.steer_dash(delta)
		dash_time = maxf(0.0, dash_time - delta)
		var active_dash_duration: float = perfect_counter_dash_duration if perfect_counter_dash_active else dash_duration
		var dash_ratio: float = clampf(dash_time / maxf(active_dash_duration, 0.001), 0.0, 1.0)
		var current_dash_speed: float = lerpf(15.0, perfect_counter_dash_speed, dash_ratio) if perfect_counter_dash_active else lerpf(dash_end_speed, dash_speed, dash_ratio)
		velocity.x = dash_direction.x * current_dash_speed
		velocity.z = dash_direction.z * current_dash_speed
		if dash_time <= 0.0:
			perfect_counter_dash_active = false
	elif wall_run_repulsion_control_lock > 0.0:
		# Preserve the release impulse for a short beat. Without this guard the
		# regular air steering immediately blends most of the kick away, making a
		# numerically strong launch feel strangely soft to the player.
		pass
	else:
		_update_free_movement(move_dir, move_multiplier, delta)

	if spin_vertical_direction < 0 and animation_driver != null and animation_driver.current_attack_context_name() == &"air":
		# The descending spiral is a near-vertical drop, not a forward air dash.
		velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 32.0 * delta)

	var attack_assist_owns_facing: bool = _update_attack_assist(delta)
	if slide_time > 0.0 and slide_direction.length() > 0.05:
		_face_direction(slide_direction, delta * 1.7)
	elif attack_assist_owns_facing:
		pass
	elif _should_face_camera_for_attack():
		var active_aim_slot: StringName = StringName()
		if animation_driver != null:
			active_aim_slot = animation_driver.current_attack_slot_name()
		if active_aim_slot == &"charge":
			active_aim_slot = &"heavy"
		var base_facing: Vector3 = _camera_forward_flat() if shield_blocking else attack_facing_direction
		var facing_target: Vector3 = base_facing if shield_blocking else _attack_aim_direction(base_facing, active_aim_slot)
		_face_direction(facing_target, delta * 2.0)
	elif dash_time > 0.0 and dash_direction.length() > 0.05:
		_face_direction(dash_direction, delta * 1.8)
	elif move_dir.length() > 0.10 and not wall_run_release_input_guard:
		_face_direction(move_dir, delta)

	# A close perfect counter owns displacement through its collision-aware lunge.
	# Clear prior dash/run velocity so the strike cannot drift past its target.
	if attack_assist_context == &"counter_light" and attack_assist_lock_remaining > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0

	if spiral_down_air_impact_pending:
		# is_on_floor() may remain true for one cached frame after an enemy support is
		# disabled. Reassert the plunge after the generic floor branch zeroed Y.
		velocity.y = minf(velocity.y, -10.0)
	var position_before_move: Vector3 = global_position
	if skills != null and skills.plunge_active:
		velocity.y = minf(velocity.y, -24.0)
	if skills != null and skills.owns_aura_movement() and is_instance_valid(skills.aura_target):
		velocity.x = skills.aura_velocity.x
		velocity.z = skills.aura_velocity.z
	_move_with_traversal_platform_policy()
	if spiral_down_air_impact_pending and velocity.y > 0.0:
		# Godot can convert cached overlap recovery into a huge upward velocity on the
		# first pass-through frame. Reject that solver artifact and advance slightly
		# below the old support so the next frame continues toward real terrain.
		global_position = position_before_move + Vector3.DOWN * 0.08
		velocity.y = -10.0

	if not was_on_floor and is_on_floor():
		if skills != null:
			skills.on_landed()
		_reset_wall_run_after_landing()
		if spiral_down_air_impact_pending:
			_trigger_spiral_down_impact()
		if slide_armed:
			# Exact contact-frame conversion: no Jump_Land/NinjaJump_Land is ever
			# played and horizontal momentum is immediately converted into slide.
			_start_slide(true)
		elif animation_driver != null:
			# Direct landing: kill only jump/movement overlays and let locomotion
			# pick Idle/Jog/Sprint immediately from the actual horizontal speed.
			animation_driver.stop_movement_action()
			if dash_time <= 0.0:
				animation_driver.stop_full_body()

	if slide_time > 0.0 and slide_slash_active_time > 0.0:
		_scan_slide_slash_contacts()

	_update_weapon_hit_detection(delta)
	_update_perfect_counter_aoe()

	if animation_driver != null:
		var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
		animation_driver.set_locomotion(clampf(horizontal_speed / max_speed, 0.0, 1.0))

func _process(delta: float) -> void:
	reconcile_combat_holds()
	_update_slide_visual_height(delta)
	_update_gamepad_camera(delta)
	_update_camera(delta)

	# Gameplay attacks are polled directly instead of relying on _unhandled_input.
	# LMB is resolved here as tap=light / hold=heavy, while J and K remain direct
	# keyboard fallbacks for isolated combat testing.
	if not parkour_active and (skills == null or not skills.controls.wheel.visible):
		var close_counter_triggered := false
		if not wall_run_active and InputMap.has_action(&"counter_close") and Input.is_action_just_pressed(&"counter_close") and _perfect_response_available():
			close_counter_triggered = _do_perfect_counter_light()
		if wall_run_active:
			if shield_blocking:
				_set_shield_blocking(false)
		else:
			_update_shield_block_input()
		if not close_counter_triggered:
			_update_primary_attack_input(delta)
		if Input.is_action_just_pressed("attack_light"):
			_do_light_attack()
		if not wall_run_active and Input.is_action_just_pressed("spin_attack_up"):
			_do_spin_attack(1)
		if not wall_run_active and Input.is_action_just_pressed("spin_attack_down"):
			_do_spin_attack(-1)
		if Input.is_action_just_pressed("attack_heavy"):
			_begin_heavy_input()
		if Input.is_action_just_released("attack_heavy") and heavy_charging and not primary_attack_held:
			_release_heavy_attack()
	elif shield_blocking:
		_set_shield_blocking(false)

	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0 and not Input.is_action_pressed("attack_light"):
		light_step = 0
		combo_light_count = 0

	if heavy_charging:
		var charge_rate: float = skills.value(&"ares_charge") if skills != null and skills.ultimate == &"ares" else 1.0
		heavy_charge = minf(heavy_charge_max, heavy_charge + delta * charge_rate)
		var ratio: float = clampf(heavy_charge / heavy_charge_max, 0.0, 1.0)
		if not heavy_charge_pose_started and (not fast_heavy_candidate or heavy_charge >= 0.12):
			if animation_driver != null:
				heavy_charge_pose_started = animation_driver.begin_heavy_charge(heavy_charge_context)
		if heavy_charge_pose_started and animation_driver != null:
			animation_driver.update_heavy_charge(ratio)
		_set_sword_charge_visual(ratio)
		if ratio >= 0.999 and not heavy_charge_max_feedback_emitted:
			heavy_charge_max_feedback_emitted = true
			if combat_feedback != null:
				combat_feedback.charge_max_reached(sword_tip.global_position if sword_tip != null else global_position + Vector3.UP)

	if spin_active_time > 0.0:
		var step: float = minf(delta, spin_active_time)
		spin_active_time -= step
		if spin_total_time > 0.001:
			rotate_y((spin_rotation_total / spin_total_time) * step)
		if spin_active_time <= 0.0:
			var spiral_still_active: bool = animation_driver != null and animation_driver.current_attack_slot_name() == &"spin360"
			if not spiral_still_active and not spiral_down_air_impact_pending:
				spin_vertical_direction = 0

	if animation_driver != null:
		animation_driver.set_attack_aim_pitch(_current_attack_aim_pitch())
		animation_driver.tick(delta)
		if animation_driver.is_attack_active() and not animation_driver.is_heavy_charging() and sword_tip != null and sword_trail != null:
			sword_trail.push_point(sword_tip.global_position, animation_driver.current_attack_is_heavy())
	_update_shield_guard_visual()
	if skills != null:
		skills.presentation()
	debug_text_time_left -= delta
	if debug_text_time_left <= 0.0:
		var debug_hz := clampf(float(ProjectSettings.get_setting("hoplite/performance/debug_refresh_hz", 6.0)), 1.0, 20.0)
		debug_text_time_left += 1.0 / debug_hz
		_update_debug_text()

func _configure_combat_queries() -> void:
	self_raycast_exclusion = [get_rid()]
	weapon_sweep_query.collision_mask = weapon_hit_mask
	weapon_sweep_query.collide_with_bodies = false
	weapon_sweep_query.collide_with_areas = true
	weapon_sweep_query.exclude = self_raycast_exclusion
	slide_slash_query.collision_mask = weapon_hit_mask
	slide_slash_query.collide_with_bodies = false
	slide_slash_query.collide_with_areas = true
	slide_slash_query.exclude = self_raycast_exclusion
	wall_run_raycast_query.exclude = self_raycast_exclusion
	world_raycast_query.collision_mask = 1
	world_raycast_query.exclude = self_raycast_exclusion
	world_raycast_query.collide_with_bodies = true
	world_raycast_query.collide_with_areas = false
	attack_assist_los_query.collision_mask = 1
	attack_assist_los_query.exclude = self_raycast_exclusion
	attack_assist_los_query.collide_with_areas = false
	attack_assist_los_query.collide_with_bodies = true

func _unhandled_input(event: InputEvent) -> void:
	if skills != null and skills.controls.wheel.visible: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var camera_guidance_active: bool = _epic_wall_run_camera_guidance_active()
		var look_scale: float = EPIC_WALL_RUN_LOOK_INPUT_SCALE if camera_guidance_active else 1.0
		camera_yaw.rotation.y -= motion.relative.x * mouse_sensitivity * look_scale
		camera_pitch_value = clampf(camera_pitch_value - motion.relative.y * mouse_sensitivity * look_scale, -1.05, 0.50)
		if not camera_guidance_active:
			camera_pitch.rotation.x = camera_pitch_value
		return
	if parkour_active:
		return

	# Combat actions are handled in _process() so fast clicks cannot be swallowed
	# by UI/unhandled-input routing. This block is reserved for editor/debug keys.
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_F2:
				visual_flipped = not visual_flipped
				if visual_root != null:
					visual_root.rotation.y = PI if visual_flipped else 0.0
			KEY_F3:
				_cycle_sword_preset()
			KEY_F4:
				shield_visible = not shield_visible
				if shield_attachment != null:
					shield_attachment.visible = shield_visible
			KEY_P:
				toggle_player_visual()
				get_viewport().set_input_as_handled()
			KEY_PAGEUP:
				if animation_driver != null:
					animation_driver.preview_next()
			KEY_PAGEDOWN:
				if animation_driver != null:
					animation_driver.preview_prev()
			KEY_ENTER, KEY_KP_ENTER:
				if animation_driver != null:
					animation_driver.preview_play()

func _update_gamepad_camera(delta: float) -> void:
	if skills != null and skills.controls.wheel.visible: return
	if camera_yaw == null or camera_pitch == null:
		return
	if not InputMap.has_action(&"camera_left"):
		return
	var look := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down", 0.16)
	if look.length_squared() < 0.001:
		return
	var sensitivity := 2.35
	var camera_guidance_active: bool = _epic_wall_run_camera_guidance_active()
	var look_scale: float = EPIC_WALL_RUN_LOOK_INPUT_SCALE if camera_guidance_active else 1.0
	camera_yaw.rotation.y -= look.x * sensitivity * delta * look_scale
	camera_pitch_value = clampf(camera_pitch_value - look.y * sensitivity * 0.78 * delta * look_scale, -1.05, 0.50)
	if not camera_guidance_active:
		camera_pitch.rotation.x = camera_pitch_value

func reconcile_combat_holds() -> void:
	var primary_down := Input.is_action_pressed("attack_primary")
	var heavy_down := Input.is_action_pressed("attack_heavy")
	if heavy_charging and not primary_down and not heavy_down and not Input.is_action_just_released("attack_primary") and not Input.is_action_just_released("attack_heavy"):
		_cancel_heavy_charge()
	# Skills can own a held pose; every other orphaned driver hold must release.
	var skill_charge: bool = skills != null and (skills.cast_remaining > 0.0 or skills.ultimate == &"thunder")
	if animation_driver != null and animation_driver.is_heavy_charging() and not heavy_charging and not skill_charge:
		animation_driver.cancel_heavy_charge()
	if animation_driver != null and animation_driver.is_block_active() and not shield_blocking:
		animation_driver.end_block()
	if primary_attack_held and not Input.is_action_pressed("attack_primary") and not Input.is_action_just_released("attack_primary"):
		_reset_primary_attack_input()
		_cancel_heavy_charge()

func _update_primary_attack_input(delta: float) -> void:
	if skills != null and skills.ultimate == &"thunder":
		_reset_primary_attack_input()
		return
	reconcile_combat_holds()
	if Input.is_action_just_pressed("attack_primary"):
		if _perfect_response_available() and _do_perfect_counter_light():
			_reset_primary_attack_input()
			return
		# Starting an attack while RMB is held is intentionally ignored; this keeps
		# defense predictable instead of dropping the shield because of a stray click.
		if shield_blocking:
			return
		primary_attack_held = true
		primary_hold_time = 0.0
		primary_heavy_started = false

	if primary_attack_held and Input.is_action_pressed("attack_primary"):
		primary_hold_time += delta
		if not primary_heavy_started and primary_hold_time >= primary_heavy_threshold:
			_begin_heavy_input(primary_hold_time)
			primary_heavy_started = heavy_charging

	if Input.is_action_just_released("attack_primary") and primary_attack_held:
		if primary_heavy_started and heavy_charging:
			_release_heavy_attack()
		elif not primary_heavy_started:
			_do_light_attack()
		_reset_primary_attack_input()

func _reset_primary_attack_input() -> void:
	primary_attack_held = false
	primary_hold_time = 0.0
	primary_heavy_started = false

func _update_shield_block_input() -> void:
	if skills != null and (not skills.active(&"block") or skills.ranged_active or skills.cast_remaining > 0.0):
		_set_shield_blocking(false)
		return
	var combat_busy: bool = heavy_charging or primary_attack_held
	if animation_driver != null:
		combat_busy = combat_busy or animation_driver.is_attack_active()
	var wants_block: bool = Input.is_action_pressed("block") and not combat_busy and dash_time <= 0.0 and slide_time <= 0.0
	if wants_block != shield_blocking:
		_set_shield_blocking(wants_block)

func _set_shield_blocking(enabled: bool) -> void:
	if shield_blocking == enabled:
		return
	shield_blocking = enabled
	if shield_blocking:
		shield_block_started_ms = Time.get_ticks_msec()
	if animation_driver == null:
		return
	if shield_blocking:
		animation_driver.begin_block()
	else:
		animation_driver.end_block()
	_set_shield_guard_visual_enabled(shield_blocking)

func _start_regular_dash() -> void:
	if skills != null and (not skills.active(&"dash") or skills.plunge_active): return
	if dash_charges <= 0:
		return
	_consume_dash_charge()
	_stop_slide(false, false)
	# Heavy charge is intentionally preserved through a regular dash.
	dash_time = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_variant_grace = 0.20
	perfect_counter_dash_active = false
	dodge_started_ms = Time.get_ticks_msec()
	dash_direction = _desired_move_direction()
	if dash_direction.length() < 0.05:
		var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		dash_direction = flat_velocity.normalized() if flat_velocity.length() > 0.2 else _camera_forward_flat()
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed
	movement_sfx_requested.emit(&"dash")
	if animation_driver != null:
		animation_driver.stop_movement_action()
		animation_driver.play_full_body(&"dash")

func _perfect_response_available() -> bool:
	if skills != null and not skills.active(&"perfect"): return false
	return combat_feedback != null and combat_feedback.is_perfect_response_active()

func _start_perfect_response(kind: StringName, attacker: Node) -> void:
	if skills != null and not skills.active(&"perfect"): return
	perfect_response_source = attacker as Node3D if attacker is Node3D else null
	_reset_primary_attack_input()
	_restore_all_mobility_charges()
	_add_spiral_stamina(spiral_perfect_reward)
	_activate_perfect_recovery()
	if combat_feedback != null:
		combat_feedback.start_perfect_response(kind, perfect_response_source)
	perfect_response_started.emit(kind)

func _do_perfect_counter_dash() -> bool:
	if skills != null and not skills.active(&"dash"): return false
	if animation_driver == null:
		return false
	var target: Node3D = _find_perfect_counter_target()
	if target == null:
		return false
	_cancel_heavy_charge()
	_stop_slide(false, false)
	_set_shield_blocking(false)
	var direction: Vector3 = _flat_direction_to(target)
	if direction.length() < 0.01:
		return false
	_face_direction(direction, 1.0)
	dash_direction = direction
	dash_time = perfect_counter_dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_variant_grace = 0.0
	perfect_counter_dash_active = true
	dodge_started_ms = -100000
	velocity.x = direction.x * perfect_counter_dash_speed
	velocity.z = direction.z * perfect_counter_dash_speed
	animation_driver.stop_movement_action()
	var counter_dash_key: StringName = [&"run_jump", &"air_down"][counter_dash_animation_cursor % 2]
	counter_dash_animation_cursor += 1
	var counter_dash_speed_value: float = 3.25 if counter_dash_key == &"run_jump" else 2.15
	var counter_dash_start: float = 0.28 if counter_dash_key == &"run_jump" else 0.14
	var played: bool = animation_driver.play_external_attack(counter_dash_key, &"heavy", &"counter_dash", true, counter_dash_speed_value, 0.032, 1.0, true, counter_dash_start)
	if not played:
		played = animation_driver.play_external_attack(&"heavy_fast", &"heavy", &"counter_dash", true, 1.92, 0.032, 1.0, true, 0.06)
	if not played:
		perfect_counter_dash_active = false
		return false
	last_heavy_release_ratio = 1.0
	_lock_perfect_counter_target(target, &"heavy", &"counter_dash")
	combat_attack_started.emit(&"heavy", &"counter_dash", 1.0)
	movement_sfx_requested.emit(&"dash")
	if combat_feedback != null:
		combat_feedback.attack_started(&"heavy", 1.0)
		combat_feedback.consume_perfect_response()
	perfect_response_consumed.emit()
	perfect_response_source = null
	return true

func _do_perfect_counter_light() -> bool:
	if animation_driver == null:
		return false
	var target: Node3D = _find_perfect_counter_target()
	if target == null:
		return false
	_cancel_heavy_charge()
	_stop_slide(false, false)
	dash_time = 0.0
	dash_variant_grace = 0.0
	perfect_counter_dash_active = false
	velocity.x = 0.0
	velocity.z = 0.0
	_set_shield_blocking(false)
	var direction: Vector3 = _flat_direction_to(target)
	if direction.length() < 0.01:
		return false
	_face_direction(direction, 1.0)
	var counter_light_key: StringName = [&"counter_light", &"counter_light_alt"][counter_light_animation_cursor % 2]
	counter_light_animation_cursor += 1
	var counter_light_speed_value: float = 2.45 if counter_light_key == &"counter_light" else 3.65
	var counter_light_start: float = 0.12 if counter_light_key == &"counter_light" else 0.28
	# The input is a light tap, but a Perfect Response is still a fully charged
	# riposte. Only the authored animation differs from the dash counter.
	var played: bool = animation_driver.play_external_attack(counter_light_key, &"heavy", &"counter_light", true, counter_light_speed_value, 0.026, 0.94, true, counter_light_start)
	if not played:
		played = animation_driver.play_external_attack(&"heavy_fast", &"heavy", &"counter_light", true, 2.18, 0.028, 0.92, true, 0.08)
	if not played:
		return false
	last_heavy_release_ratio = 1.0
	_lock_perfect_counter_target(target, &"heavy", &"counter_light")
	perfect_counter_aoe_pending = true
	combat_attack_started.emit(&"heavy", &"counter_light", 1.0)
	if combat_feedback != null:
		combat_feedback.attack_started(&"heavy", 1.0)
		combat_feedback.consume_perfect_response()
	perfect_response_consumed.emit()
	perfect_response_source = null
	return true

func _lock_perfect_counter_target(target: Node3D, slot: StringName, context: StringName) -> void:
	_clear_attack_assist()
	attack_assist_target = target
	attack_assist_slot = slot
	attack_assist_context = context
	attack_assist_initial_direction = _flat_direction_to(target)
	attack_assist_startup_remaining = 0.22
	attack_assist_lock_remaining = maxf(0.84, animation_driver.current_attack_length() + 0.18)
	attack_assist_ideal_distance = 1.55
	var target_distance: float = global_position.distance_to(target.global_position)
	attack_assist_lunge_remaining = 0.78 if context == &"counter_dash" else clampf(target_distance - attack_assist_ideal_distance, 0.0, perfect_counter_range)
	attack_assist_rotation_degrees = 180.0

func _find_perfect_counter_target() -> Node3D:
	if perfect_response_source != null and is_instance_valid(perfect_response_source) and _perfect_counter_target_is_valid(perfect_response_source):
		return perfect_response_source
	if get_tree() == null:
		return null
	var best: Node3D
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node3D):
			continue
		var candidate := node as Node3D
		if not _perfect_counter_target_is_valid(candidate):
			continue
		var offset: Vector3 = candidate.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _perfect_counter_target_is_valid(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_dead_for_combat") and bool(target.call("is_dead_for_combat")):
		return false
	var offset: Vector3 = target.global_position - global_position
	offset.y = 0.0
	return offset.length() <= perfect_counter_range and _attack_assist_has_line_of_sight(_combat_target_aim_position(target))

func _flat_direction_to(target: Node3D) -> Vector3:
	if target == null:
		return Vector3.ZERO
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.01 else Vector3.ZERO

func _log_combat_refusal(reason: StringName) -> void:
	var now := Time.get_ticks_msec()
	if now - combat_refusal_log_msec < 2000: return
	combat_refusal_log_msec = now
	print("[COMBAT INPUT REFUSED] reason=", reason, " context=", _combat_context(), " heavy=", heavy_charging, " primary=", primary_attack_held, " block=", shield_blocking, " spiral=", spiral_active_request_id, " spiral_impact=", spiral_down_air_impact_pending, " driver_slot=", animation_driver.current_attack_slot_name() if animation_driver != null else &"none", " driver_charge=", animation_driver.is_heavy_charging() if animation_driver != null else false, " ultimate=", skills.ultimate if skills != null else &"none", " plunge=", skills.plunge_active if skills != null else false)

func _do_light_attack() -> void:
	if skills != null:
		if not skills.attack_allowed(&"light", _combat_context()):
			_log_combat_refusal(&"light_skill_gate")
			return
		if skills.request_ranged(): return
	if not wall_run_active and _perfect_response_available() and _do_perfect_counter_light():
		return
	if animation_driver == null or heavy_charging or shield_blocking:
		_log_combat_refusal(&"light_combat_gate")
		return
	attack_facing_direction = _attack_input_facing_direction()

	if combo_timer <= 0.0:
		light_step = 0
		combo_light_count = 0
	var next_step: int = (light_step % 3) + 1
	var slot: StringName = StringName("light%d" % next_step)
	var context: StringName = _combat_context()
	# Slide attacks deliberately stay upper-body weighted: the legs keep the slide
	# pose while the sword gets its own low/wide contextual slash variant.
	var full_body: bool = context == &"air" or context == &"dash" or context == &"slide"
	var custom_speed: float = -1.0
	var custom_blend: float = 0.035 if context == &"slide" else 0.045
	var hips_weight: float = 1.0 if full_body else (0.12 if context == &"wall" else (0.48 if context == &"run" else 0.38))
	var start_fraction: float = 0.10
	var external_key: StringName = slot
	match context:
		&"slide":
			external_key = &"slide_left" if next_step == 1 or next_step == 3 else &"slide_right"
			custom_speed = 2.55
			start_fraction = 0.09
		&"air":
			# Ordinary aerial lights keep their normal sword silhouettes. air_down is
			# reserved exclusively for the explicit Spiral Down input.
			external_key = slot
			custom_speed = 2.35 if slot == &"light1" else (2.45 if slot == &"light2" else 1.85)
			start_fraction = 0.10
		&"dash":
			external_key = &"dash_attack"
			custom_speed = 2.75
			start_fraction = 0.12
		&"wall":
			# Compact upper-body cuts: wall movement retains complete ownership of
			# feet, hips and trajectory.
			external_key = slot
			custom_speed = 2.50 if slot == &"light1" else (2.60 if slot == &"light2" else 2.00)
			start_fraction = 0.10
		_:
			custom_speed = 2.35 if slot == &"light1" else (2.45 if slot == &"light2" else 1.85)
	var played: bool = false
	if animation_driver.has_external_clip(external_key):
		played = animation_driver.request_external_attack(external_key, slot, context, full_body, custom_speed, custom_blend, hips_weight, false, start_fraction)
	else:
		played = animation_driver.request_attack_variant(slot, context, full_body, custom_speed, custom_blend, hips_weight)

	if played:
		combat_attack_started.emit(slot, context, 0.0)
		_begin_attack_assist(slot, context)
		if combat_feedback != null:
			combat_feedback.attack_started(slot, 0.0)
		light_step = next_step
		combo_light_count = mini(3, combo_light_count + 1)
		combo_timer = 1.05
		if context == &"dash":
			var forward: Vector3 = _camera_forward_flat()
			_add_horizontal_impulse(forward, 2.2, dash_speed)
		elif context == &"slide":
			slide_slash_active_time = maxf(slide_slash_active_time, minf(maxf(slide_time, 0.10), 0.28))
			slide_slash_contacts.clear()

func _begin_heavy_input(initial_charge: float = 0.0) -> void:
	if skills != null and not skills.attack_allowed(&"heavy", _combat_context()): return
	if animation_driver == null or heavy_charging or shield_blocking:
		return
	attack_facing_direction = _attack_input_facing_direction()
	# Heavy can begin while running, airborne, dashing or sliding. Movement owns
	# the lower body while the held charge remains an upper-body combat layer.
	heavy_charging = true
	heavy_charge = clampf(initial_charge, 0.0, heavy_charge_max)
	heavy_charge_context = _combat_context()
	fast_heavy_candidate = combo_timer > 0.0 and combo_light_count >= 2
	heavy_charge_pose_started = false
	heavy_charge_max_feedback_emitted = false
	if not fast_heavy_candidate:
		heavy_charge_pose_started = animation_driver.begin_heavy_charge(heavy_charge_context)

func _release_heavy_attack() -> void:
	if skills != null:
		if not skills.attack_allowed(&"heavy", _combat_context()):
			_cancel_heavy_charge()
			return
		if skills.request_ranged(lerpf(1.0, 2.0, clampf(heavy_charge / heavy_charge_max, 0.0, 1.0))):
			_cancel_heavy_charge()
			return
	if animation_driver == null:
		_cancel_heavy_charge()
		return
	var ratio: float = clampf(heavy_charge / heavy_charge_max, 0.0, 1.0)
	var context: StringName = _combat_context()
	var fast_combo: bool = fast_heavy_candidate and heavy_charge <= 0.28
	var played: bool = false
	var heavy_external_key: StringName = &"heavy_fast" if fast_combo else (&"heavy_max" if ratio >= 0.84 else &"heavy_release")
	if animation_driver.has_external_clip(heavy_external_key):
		if heavy_charge_pose_started:
			animation_driver.cancel_heavy_charge()
		var external_speed: float = 2.25 if fast_combo else (1.58 if ratio >= 0.84 else lerpf(1.82, 1.48, ratio))
		var external_full_body: bool = context == &"run" or context == &"air" or context == &"dash"
		var external_hips: float = 0.12 if context == &"wall" else (0.86 if external_full_body else 0.68)
		played = animation_driver.play_external_attack(heavy_external_key, &"heavy", context, external_full_body, external_speed, 0.055, external_hips, fast_combo, 0.08)
	elif heavy_charge_pose_started:
		played = animation_driver.release_heavy_charge(context, ratio, fast_combo)
	else:
		played = animation_driver.play_attack_exact(&"heavy", context, [&"Sword_Regular_C", &"Sword_Regular_Combo"], context == &"run" or context == &"air" or context == &"dash", 1.48 if fast_combo else -1.0, 0.04 if fast_combo else -1.0, 0.12 if context == &"wall" else (0.82 if context == &"run" else -1.0), fast_combo)

	if played:
		combat_attack_started.emit(&"heavy", context, ratio)
		_begin_attack_assist(&"heavy", context)
		if combat_feedback != null:
			combat_feedback.attack_started(&"heavy", ratio)
		last_heavy_release_ratio = ratio
		var forward: Vector3 = _attack_assist_direction(_camera_forward_flat())
		var impulse: float = (4.7 if fast_combo else lerpf(3.0, 7.4, ratio))
		var heavy_speed_cap: float = dash_speed if context == &"dash" else max_speed + (2.6 if fast_combo else lerpf(2.0, 4.0, ratio))
		# Ground heavies keep their committed lunge. In the air the existing arc is
		# untouched unless aim assist actually acquired a target.
		if context != &"wall" and (context != &"air" or attack_assist_target != null):
			_add_horizontal_impulse(forward, impulse, heavy_speed_cap)

	heavy_charging = false
	heavy_charge_pose_started = false
	heavy_charge = 0.0
	fast_heavy_candidate = false
	heavy_charge_max_feedback_emitted = false
	combo_timer = 0.0
	combo_light_count = 0
	_set_sword_charge_visual(0.0)

func _cancel_heavy_charge() -> void:
	if not heavy_charging:
		return
	heavy_charging = false
	heavy_charge_pose_started = false
	heavy_charge = 0.0
	fast_heavy_candidate = false
	heavy_charge_max_feedback_emitted = false
	if animation_driver != null:
		animation_driver.cancel_heavy_charge()
	_set_sword_charge_visual(0.0)

func _do_spin_attack(vertical_direction: int = 1) -> void:
	if skills != null and (not skills.active(&"spin_up" if vertical_direction > 0 else &"spin_down") or skills.ranged_active or skills.plunge_active or skills.cast_remaining > 0.0 or skills.ultimate == &"thunder"): return
	if animation_driver == null or heavy_charging or shield_blocking or spin_input_cooldown_timer > 0.0:
		return
	if spiral_stamina + 0.001 < spiral_stamina_cost:
		return
	attack_facing_direction = _attack_input_facing_direction()
	var requested_direction: int = 1 if vertical_direction >= 0 else -1
	var context: StringName = _combat_context()
	# A dense enemy capsule can be reported as the current floor. Spiral Down must
	# still become an aerial plunge in that case instead of playing its grounded
	# low sweep while the player stands on somebody's head.
	if requested_direction < 0 and context != &"air" and _is_standing_on_enemy_body():
		context = &"air"
	var combo_fast: bool = combo_timer > 0.0 and combo_light_count > 0
	var external_spin_key: StringName = _spiral_external_key(requested_direction, context)
	var speed: float = _spiral_animation_speed(requested_direction, context, combo_fast)
	var external_spin: bool = animation_driver.has_external_clip(external_spin_key)
	var action_metadata := {
		&"request_id": next_combat_action_request_id,
		&"spiral_direction": requested_direction,
		&"combo_fast": combo_fast,
		&"external": external_spin,
		&"blocked_capabilities": [&"wall_attach"] if requested_direction < 0 else [],
	}
	next_combat_action_request_id += 1
	# Buffering (one active + three queued) is what makes all four stored spiral
	# charges playable as complete attacks. Restarting the clip on every wheel tick
	# used to trap the pose in its first, left-facing frames.
	var spin_played: bool = animation_driver.request_external_attack(external_spin_key, &"spin360", context, true, speed, 0.045, 1.0, combo_fast, 0.06 if context == &"air" and requested_direction < 0 else 0.10, action_metadata) if external_spin else false
	if not spin_played:
		action_metadata[&"external"] = false
		var spin_candidates: Array = [&"Sword_Regular_A", &"Sword_Regular_B"] if requested_direction > 0 else [&"Sword_Regular_B", &"Sword_Regular_A"]
		spin_played = animation_driver.play_attack_exact(&"spin360", context, spin_candidates, true, 1.24 if combo_fast else -1.0, 0.045 if combo_fast else -1.0, 1.0, combo_fast, action_metadata)
	if spin_played:
		_add_spiral_stamina(-spiral_stamina_cost)
		spin_input_cooldown_timer = 0.20
		combo_timer = 0.0
		combo_light_count = 0

func _spiral_external_key(direction: int, context: StringName) -> StringName:
	if direction < 0 and context == &"air":
		return &"air_down"
	return &"spin_high" if direction >= 0 else &"spin_low"

func _spiral_animation_speed(direction: int, context: StringName, combo_fast: bool) -> float:
	if direction < 0 and context == &"air":
		return 1.95 if combo_fast else 1.72
	if direction > 0:
		return 3.05 if combo_fast else 2.65
	return 3.20 if combo_fast else 2.85

func _sync_spiral_attack_state() -> void:
	if animation_driver == null:
		return
	var action := animation_driver.current_combat_action_metadata()
	if animation_driver.current_attack_slot_name() != &"spin360":
		if spiral_active_request_id != 0:
			_finish_spiral_action(true)
		elif not spiral_down_air_impact_pending:
			spin_vertical_direction = 0
		return
	var request_id: int = int(action.get(&"request_id", 0))
	if request_id == spiral_active_request_id:
		return
	_start_spiral_action(action)


func _on_combat_action_started(action: Dictionary) -> void:
	if skills != null: skills.on_combat_action_started(action)
	if StringName(action.get(&"slot", StringName())) == &"spin360":
		_start_spiral_action(action)


func _on_combat_action_finished(action: Dictionary, reason: StringName) -> void:
	if int(action.get(&"request_id", 0)) != spiral_active_request_id:
		return
	_finish_spiral_action(reason != &"finished")


func _on_combat_actions_cancelled(_actions: Array[Dictionary], reason: StringName) -> void:
	if reason != &"finished" and (spiral_active_request_id != 0 or spiral_down_air_impact_pending or spiral_down_enemy_passthrough):
		_finish_spiral_action(true)


func _start_spiral_action(action: Dictionary) -> void:
	var clip: StringName = animation_driver.current_attack_clip if animation_driver != null else StringName()
	var request_id: int = int(action.get(&"request_id", 0))
	if request_id <= 0 or request_id == spiral_active_request_id:
		return
	if spiral_active_request_id != 0:
		_finish_spiral_action(true)
	spiral_active_request_id = request_id
	var direction: int = int(action.get(&"spiral_direction", _spiral_direction_from_clip(clip)))
	var context: StringName = StringName(action.get(&"context", animation_driver.current_attack_context_name()))
	var combo_fast: bool = bool(action.get(&"combo_fast", false))
	var using_external: bool = bool(action.get(&"external", String(clip).begins_with("external:")))
	spin_vertical_direction = direction
	spin_total_time = maxf(0.38, animation_driver.current_attack_length() * 0.88)
	spin_active_time = spin_total_time
	# Retargeting strips the donor root yaw from Standing Melee Attack 360 Low,
	# leaving only about half of its sword orbit. Restore one exact world-space
	# revolution for grounded low variants; TAU returns the player's facing to the
	# same heading, including while running, dashing or sliding.
	if direction < 0 and context != &"air":
		spin_rotation_total = TAU
	else:
		spin_rotation_total = 0.0 if using_external else TAU * (1.20 if context == &"air" else 1.0)
	combat_attack_started.emit(&"spin360", context, 1.0 if combo_fast else 0.0)
	_begin_attack_assist(&"spin360", context)
	if combat_feedback != null:
		combat_feedback.attack_started(&"spin360", 1.0 if combo_fast else 0.0)

	# Movement impulses belong to the frame where the buffered attack actually
	# starts, not to the earlier input frame.
	if context == &"air" and (not is_on_floor() or _is_standing_on_enemy_body()):
		if direction > 0 and not spin_up_air_used:
			velocity.y = maxf(velocity.y, jump_velocity * 0.72)
			spin_up_air_used = true
			movement_sfx_requested.emit(&"jump")
		elif direction < 0:
			spiral_down_air_impact_pending = true
			spiral_down_air_hit_targets.clear()
			spiral_down_collision_restore_timer = 0.0
			_set_spiral_down_enemy_passthrough(true)
			velocity.y = minf(velocity.y, -10.0)
			velocity.x *= 0.18
			velocity.z *= 0.18
	elif context == &"dash":
		_add_horizontal_impulse(_camera_forward_flat(), 2.4, dash_speed)


func _finish_spiral_action(interrupted: bool) -> void:
	spiral_active_request_id = 0
	spin_active_time = 0.0
	spin_total_time = 0.0
	spin_rotation_total = 0.0
	if interrupted and (spiral_down_air_impact_pending or spiral_down_enemy_passthrough):
		spiral_down_air_impact_pending = false
		spiral_down_air_hit_targets.clear()
		_set_spiral_down_enemy_passthrough(false)
	if not spiral_down_air_impact_pending:
		spin_vertical_direction = 0

func _spiral_direction_from_clip(clip: StringName) -> int:
	var label: String = String(clip)
	return -1 if "spin_low" in label or "air_down" in label else 1

func _set_spiral_down_enemy_passthrough(enabled: bool) -> void:
	if enabled:
		if not spiral_down_enemy_passthrough:
			spiral_down_saved_collision_layer = collision_layer
			spiral_down_saved_collision_mask = collision_mask
		# World geometry stays on layer 1. Hiding the player's body layer as well as
		# enemy layer 4 prevents enemy CharacterBodies from resolving the overlap in
		# their own move_and_slide pass and catapulting the player upward.
		collision_layer = 0
		collision_mask = 1
		spiral_down_enemy_passthrough = true
		return
	collision_layer = spiral_down_saved_collision_layer if spiral_down_saved_collision_layer != 0 else 2
	collision_mask = spiral_down_saved_collision_mask if spiral_down_saved_collision_mask != 0 else (1 | 4 | 128 | GIANT_TRAVERSAL_COLLISION_LAYER)
	spiral_down_enemy_passthrough = false
	spiral_down_collision_restore_timer = 0.0

func _update_spiral_down_enemy_passthrough(delta: float) -> void:
	if not spiral_down_enemy_passthrough:
		return
	if spiral_down_air_impact_pending:
		return
	spiral_down_collision_restore_timer = maxf(0.0, spiral_down_collision_restore_timer - delta)
	if spiral_down_collision_restore_timer <= 0.0:
		_set_spiral_down_enemy_passthrough(false)

func _trigger_spiral_down_impact() -> void:
	if not spiral_down_air_impact_pending:
		return
	spiral_down_air_impact_pending = false
	# Keep body exceptions briefly after impact while the weak radial knockback
	# clears overlapping enemies away from the player capsule.
	spiral_down_collision_restore_timer = 0.28
	var impact_position: Vector3 = global_position + Vector3.UP * 0.08
	if combat_feedback != null:
		combat_feedback.spiral_smash(impact_position, spiral_down_impact_radius)

	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node3D):
			continue
		var target: Node3D = node as Node3D
		if target == self or (target.has_method("is_dead_for_combat") and bool(target.call("is_dead_for_combat"))):
			continue
		var world_offset: Vector3 = target.global_position - global_position
		if absf(world_offset.y) > 2.7:
			continue
		world_offset.y = 0.0
		var distance: float = world_offset.length()
		if distance > spiral_down_impact_radius:
			continue
		var direction: Vector3 = world_offset.normalized() if distance > 0.01 else -global_basis.z
		var target_id: int = target.get_instance_id()
		var already_cut: bool = spiral_down_air_hit_targets.has(target_id)
		var event = HitEventScript.new()
		event.source = self
		event.position = target.global_position + Vector3.UP * 0.52
		event.normal = Vector3.UP
		event.direction = direction
		event.impulse = direction * spiral_down_impact_knockback
		# A target already crossed by the descending blade receives a smaller impact
		# component, while targets elsewhere in the circle receive the full smash.
		event.damage = spiral_down_impact_damage * (0.38 if already_cut else 1.0)
		event.sever_damage = spiral_down_impact_sever_damage * (0.32 if already_cut else 1.0)
		event.guard_damage = spiral_down_impact_guard_damage
		event.blade_speed = 14.0
		event.attack_slot = &"spin360"
		event.attack_context = &"air"
		event.attack_vertical_direction = -1
		event.damage_type = &"spiral_smash"
		event.hit_material = &"flesh"
		event.contact_type = &"shockwave"
		event.body_part = &"thigh_l" if direction.dot(global_basis.x) < 0.0 else &"thigh_r"
		var accepted: bool = false
		if target.has_method("receive_spiral_smash"):
			accepted = bool(target.call("receive_spiral_smash", event))
		elif target.has_method("receive_ai_hit"):
			accepted = bool(target.call("receive_ai_hit", event.damage, self, direction))
		if not accepted:
			continue
		combat_hit.emit(target, event.body_part, event)
		_register_combat_hit_stamina()
	spiral_down_air_hit_targets.clear()

func _combat_context() -> StringName:
	if wall_run_active:
		return &"wall"
	if slide_time > 0.0:
		return &"slide"
	if dash_time > 0.0 or dash_variant_grace > 0.0:
		return &"dash"
	if not is_on_floor():
		return &"air"
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 2.8:
		return &"run"
	return &"idle"

func _is_standing_on_enemy_body() -> bool:
	if not is_on_floor():
		return false
	for index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(index)
		if collision == null or collision.get_normal().y < 0.55:
			continue
		var collider: Object = collision.get_collider()
		if collider is Node and ((collider as Node).is_in_group("enemy") or (collider as Node).is_in_group("enemy_walkable_surface")):
			return true
	return false

func _should_face_camera_for_attack() -> bool:
	if slide_time > 0.0 or spin_active_time > 0.0:
		return false
	return shield_blocking or heavy_charging or (animation_driver != null and animation_driver.is_attack_active())

func _ensure_slide_input_action() -> void:
	if not InputMap.has_action("slide"):
		InputMap.add_action("slide")
	for existing: InputEvent in InputMap.action_get_events("slide"):
		if existing is InputEventKey:
			var key_event: InputEventKey = existing as InputEventKey
			if key_event.keycode == KEY_CTRL:
				return
	var ctrl_event: InputEventKey = InputEventKey.new()
	ctrl_event.keycode = KEY_CTRL
	InputMap.action_add_event("slide", ctrl_event)

func _dash_nominal_distance() -> float:
	return ((dash_speed + dash_end_speed) * 0.5) * dash_duration

func _slide_speed() -> float:
	return dash_speed * slide_speed_ratio

func _slide_duration() -> float:
	return (_dash_nominal_distance() * slide_distance_ratio) / maxf(_slide_speed(), 0.001)

func _request_slide() -> void:
	if skills != null and (not skills.active(&"slide") or skills.plunge_active): return
	if parkour_active or slide_time > 0.0 or slide_armed or slide_charges <= 0:
		return

	# Entering/arming a slide does not cancel an already-held heavy charge.
	dash_time = 0.0
	dash_variant_grace = 0.0

	var wanted: Vector3 = _desired_move_direction()
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if wanted.length() > 0.05:
		slide_direction = wanted
	elif flat_velocity.length() > 0.20:
		slide_direction = flat_velocity.normalized()
	else:
		slide_direction = _camera_forward_flat()

	if is_on_floor():
		_start_slide(false)
	else:
		slide_armed = true

func _start_slide(from_air: bool) -> void:
	if skills != null and not skills.active(&"slide"): return
	if slide_charges <= 0:
		slide_armed = false
		return
	_consume_slide_charge()
	slide_armed = false
	slide_time = _slide_duration()
	slide_started_ms = Time.get_ticks_msec()

	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if from_air and flat_velocity.length() > 0.20:
		slide_direction = flat_velocity.normalized()
	elif slide_direction.length() < 0.05:
		slide_direction = _desired_move_direction()
		if slide_direction.length() < 0.05:
			slide_direction = _camera_forward_flat()
	slide_direction.y = 0.0
	slide_direction = slide_direction.normalized()

	var speed: float = _slide_speed()
	velocity.x = slide_direction.x * speed
	velocity.z = slide_direction.z * speed
	movement_sfx_requested.emit(&"slide")

	if animation_driver != null:
		animation_driver.start_slide_visual(_slide_duration())

func _stop_slide(_preserve_momentum: bool = true, play_exit: bool = true) -> void:
	# Always notify the animation driver. Previously _update_slide_motion() could
	# reduce slide_time to zero first, making this function think no slide was
	# active and leaving the UAL2 Slide loop stuck forever.
	slide_time = 0.0
	slide_armed = false
	slide_slash_active_time = 0.0
	slide_slash_contacts.clear()
	if animation_driver != null:
		if play_exit:
			animation_driver.finish_slide_visual()
		else:
			animation_driver.cancel_slide_visual()

func _update_slide_motion(move_dir: Vector3, delta: float) -> void:
	slide_time = maxf(0.0, slide_time - delta)
	if move_dir.length() > 0.05:
		slide_direction = _steer_flat_direction(slide_direction, move_dir, slide_turn_response, delta)

	var speed: float = _slide_speed()
	velocity.x = slide_direction.x * speed
	velocity.z = slide_direction.z * speed

	if slide_time <= 0.0:
		_stop_slide(true, true)

func _update_slide_visual_height(delta: float) -> void:
	if visual_root == null:
		return
	var target_y: float = visual_base_height - slide_visual_drop if slide_time > 0.0 else visual_base_height
	visual_root.position.y = move_toward(
		visual_root.position.y,
		target_y,
		slide_visual_vertical_speed * delta
	)

func _update_free_movement(move_dir: Vector3, move_multiplier: float, delta: float) -> void:
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = flat_velocity.length()

	if move_dir.length() > 0.05:
		# Direction stays normalized for parkour/dashes; ordinary locomotion
		# also respects the stick magnitude after InputMap's radial deadzone.
		var input_strength := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length()
		var target_speed: float = max_speed * move_multiplier * input_strength
		var speed_rate: float = acceleration if is_on_floor() else air_acceleration
		var next_speed: float = current_speed

		if current_speed < target_speed:
			next_speed = move_toward(current_speed, target_speed, speed_rate * delta)
		elif current_speed > target_speed:
			# Overspeed from attacks/dash bleeds off, but steering itself never
			# reduces magnitude. This keeps movement-combo momentum readable.
			var overspeed_rate: float = deceleration if is_on_floor() else air_acceleration
			next_speed = move_toward(current_speed, target_speed, overspeed_rate * delta)

		var current_dir: Vector3 = move_dir
		if current_speed > 0.05:
			current_dir = flat_velocity / current_speed
		var response: float = movement_turn_response if is_on_floor() else air_turn_response
		var steered: Vector3 = _steer_flat_direction(current_dir, move_dir, response, delta)
		velocity.x = steered.x * next_speed
		velocity.z = steered.z * next_speed
	else:
		var next_speed: float = move_toward(current_speed, 0.0, deceleration * delta)
		if current_speed > 0.001:
			var coast_dir: Vector3 = flat_velocity / current_speed
			velocity.x = coast_dir.x * next_speed
			velocity.z = coast_dir.z * next_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0

func _steer_flat_direction(from_dir: Vector3, to_dir: Vector3, response: float, delta: float) -> Vector3:
	var a: Vector3 = from_dir
	var b: Vector3 = to_dir
	a.y = 0.0
	b.y = 0.0
	if b.length() < 0.001:
		return a.normalized() if a.length() > 0.001 else Vector3.ZERO
	if a.length() < 0.001:
		return b.normalized()
	a = a.normalized()
	b = b.normalized()
	var weight: float = clampf(1.0 - exp(-response * delta), 0.0, 1.0)
	var from_angle: float = atan2(a.x, a.z)
	var to_angle: float = atan2(b.x, b.z)
	var angle: float = lerp_angle(from_angle, to_angle, weight)
	return Vector3(sin(angle), 0.0, cos(angle)).normalized()

func _scan_slide_slash_contacts() -> void:
	if get_world_3d() == null:
		return

	var contact_center: Vector3 = global_position + Vector3.UP * 0.82 + slide_direction * 0.36
	slide_slash_sphere.radius = slide_slash_radius
	slide_slash_query.shape = slide_slash_sphere
	slide_slash_query.transform = Transform3D(Basis.IDENTITY, contact_center)

	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(slide_slash_query, 48)
	slide_slash_candidates.clear()

	for result: Dictionary in hits:
		var collider: Node = result.get("collider") as Node
		if collider == null or collider == self:
			continue
		var combat_owner: Node = collider.call("get_combat_owner") as Node if collider.has_method("get_combat_owner") else collider
		var id: int = combat_owner.get_instance_id() if combat_owner != null else collider.get_instance_id()
		if slide_slash_contacts.has(id):
			continue

		var shape_index: int = int(result.get("shape", -1))
		if collider.has_method("receive_weapon_hit") and collider.has_method("zone_from_shape_index"):
			var zone: StringName = StringName(collider.call("zone_from_shape_index", shape_index))
			if zone == StringName():
				continue
			var center: Vector3 = global_position
			if collider is Node3D:
				center = (collider as Node3D).global_position
			if collider.has_method("zone_world_center_from_shape_index"):
				var center_value: Variant = collider.call("zone_world_center_from_shape_index", shape_index)
				if center_value is Vector3:
					center = center_value
			var radius: float = 0.18
			if collider.has_method("zone_radius_from_shape_index"):
				radius = float(collider.call("zone_radius_from_shape_index", shape_index))
			var priority: float = 0.0
			if collider.has_method("zone_priority_from_shape_index"):
				priority = float(collider.call("zone_priority_from_shape_index", shape_index))
			var score: float = contact_center.distance_to(center) / maxf(slide_slash_radius + radius, 0.01) - priority * 0.22
			var current_best: Dictionary = slide_slash_candidates.get(id, {})
			if current_best.is_empty() or score < float(current_best.get("score", INF)):
				slide_slash_candidates[id] = {
					"collider": collider,
					"zone": zone,
					"shape_index": shape_index,
					"hit_position": center,
					"score": score
				}
		else:
			var target: Node = _resolve_slide_slash_target(collider)
			if target != null and target != self:
				slide_slash_contacts[id] = true
				slide_slash_contact.emit(target)
				if target.has_method("on_slide_slash"):
					target.call("on_slide_slash", self)

	for raw_id: Variant in slide_slash_candidates:
		var candidate: Dictionary = slide_slash_candidates[raw_id]
		var collider: Node = candidate.get("collider") as Node
		if collider == null:
			continue
		var id: int = int(raw_id)
		if slide_slash_contacts.has(id):
			continue
		var zone: StringName = StringName(candidate.get("zone", StringName()))
		var shape_index: int = int(candidate.get("shape_index", -1))
		var event = _make_slide_contact_hit()
		event.body_part = zone
		event.hit_material = &"flesh"
		event.contact_type = &"blade"
		var hit_position_value: Variant = candidate.get("hit_position", event.position)
		if hit_position_value is Vector3:
			event.position = hit_position_value
		var accepted: bool = false
		if collider.has_method("receive_weapon_hit_zone"):
			accepted = bool(collider.call("receive_weapon_hit_zone", event, zone))
		else:
			accepted = bool(collider.call("receive_weapon_hit", event, shape_index))
		if accepted:
			slide_slash_contacts[id] = true
			debug_last_zone = zone
			_apply_attacker_contact_response(event, collider)
			combat_hit.emit(collider, zone, event)
			_register_combat_hit_stamina()
			if combat_feedback != null:
				combat_feedback.weapon_hit(event, zone, _combat_feedback_target(collider))
			slide_slash_contact.emit(collider)

func _update_weapon_hit_detection(delta: float) -> void:
	if sword_base == null or sword_tip == null or animation_driver == null or get_world_3d() == null:
		return

	var current_base: Vector3 = sword_base.global_position
	var current_tip: Vector3 = sword_tip.global_position
	if previous_sword_base_position == Vector3.ZERO:
		previous_sword_base_position = current_base
	if previous_sword_tip_position == Vector3.ZERO:
		previous_sword_tip_position = current_tip

	var attack_active: bool = animation_driver.is_attack_active() and not animation_driver.is_heavy_charging()
	var slot: StringName = animation_driver.current_attack_slot_name()
	if slot in [&"aura", &"javelin", &"skill_plunge"] or (skills != null and (skills.ranged_active or skills.ultimate == &"aura")):
		attack_active = false
	var progress: float = animation_driver.current_attack_progress()

	if not attack_active or slot == StringName() or slot == &"charge":
		weapon_swing_active = false
		weapon_whoosh_emitted = false
		weapon_hit_targets.clear()
		weapon_last_slot = StringName()
		weapon_last_progress = 0.0
		previous_sword_base_position = current_base
		previous_sword_tip_position = current_tip
		_update_weapon_debug_visuals(current_base, current_tip, current_base, current_tip)
		return

	var new_swing: bool = not weapon_swing_active or slot != weapon_last_slot or progress + 0.12 < weapon_last_progress
	if new_swing:
		weapon_swing_active = true
		weapon_whoosh_emitted = false
		weapon_hit_targets.clear()
		previous_sword_base_position = current_base
		previous_sword_tip_position = current_tip

	weapon_last_slot = slot
	weapon_last_progress = progress

	var base_sweep: Vector3 = current_base - previous_sword_base_position
	var tip_sweep: Vector3 = current_tip - previous_sword_tip_position
	var max_sweep_length: float = maxf(base_sweep.length(), tip_sweep.length())
	var blade_speed: float = max_sweep_length / maxf(delta, 0.001)
	debug_last_blade_speed = blade_speed
	if not weapon_whoosh_emitted and blade_speed >= _minimum_whoosh_speed(slot):
		weapon_whoosh_emitted = true
		if combat_feedback != null:
			combat_feedback.blade_whoosh(slot, blade_speed, animation_driver.current_attack_context_name())

	_update_weapon_debug_visuals(previous_sword_base_position, previous_sword_tip_position, current_base, current_tip)

	# Animation progress only defines a broad safety window. Actual contact is
	# primarily gated by real blade velocity so slow anticipation/recovery poses
	# do not deal damage while fast frames remain responsive.
	if not _attack_is_in_hit_window(slot, progress) or blade_speed < _minimum_blade_hit_speed(slot):
		previous_sword_base_position = current_base
		previous_sword_tip_position = current_tip
		return

	var active_hit_radius: float = _weapon_hit_radius_for_slot(slot)
	var samples: int = clampi(int(ceil(max_sweep_length / maxf(active_hit_radius * 0.90, 0.06))) + 1, 2, 10)
	weapon_sweep_candidates.clear()
	weapon_sweep_capsule.radius = active_hit_radius

	for i: int in range(samples):
		var alpha: float = float(i) / float(maxi(samples - 1, 1))
		var sample_base: Vector3 = previous_sword_base_position.lerp(current_base, alpha)
		var sample_tip: Vector3 = previous_sword_tip_position.lerp(current_tip, alpha)
		var blade_segment: Vector3 = sample_tip - sample_base
		var blade_length: float = blade_segment.length()
		if blade_length < 0.04:
			continue

		weapon_sweep_capsule.height = blade_length + active_hit_radius * 2.0
		weapon_sweep_query.shape = weapon_sweep_capsule
		weapon_sweep_query.transform = Transform3D(_basis_y_along(blade_segment), sample_base.lerp(sample_tip, 0.5))
		var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(weapon_sweep_query, 48)

		for result: Dictionary in hits:
			var collider: Node = result.get("collider") as Node
			if collider == null or not collider.has_method("receive_weapon_hit"):
				continue
			# Anatomy and shield are separate Areas, but represent one combatant. Key
			# candidates by their owner so a swing stops on the shield instead of also
			# damaging the body during the same physics frame.
			var combat_owner: Node = collider.call("get_combat_owner") as Node if collider.has_method("get_combat_owner") else collider
			var target_id: int = combat_owner.get_instance_id() if combat_owner != null else collider.get_instance_id()
			if weapon_hit_targets.has(target_id):
				continue

			var shape_index: int = int(result.get("shape", -1))
			var zone: StringName = StringName()
			if collider.has_method("zone_from_shape_index"):
				zone = StringName(collider.call("zone_from_shape_index", shape_index))
			if zone == StringName():
				continue

			var zone_center: Vector3 = global_position
			if collider is Node3D:
				zone_center = (collider as Node3D).global_position
			if collider.has_method("zone_world_center_from_shape_index"):
				var zone_center_value: Variant = collider.call("zone_world_center_from_shape_index", shape_index)
				if zone_center_value is Vector3:
					zone_center = zone_center_value
			var zone_radius: float = 0.18
			if collider.has_method("zone_radius_from_shape_index"):
				zone_radius = float(collider.call("zone_radius_from_shape_index", shape_index))
			var zone_priority: float = 0.0
			if collider.has_method("zone_priority_from_shape_index"):
				zone_priority = float(collider.call("zone_priority_from_shape_index", shape_index))

			var closest: Vector3 = _closest_point_on_segment(zone_center, sample_base, sample_tip)
			var center_distance: float = closest.distance_to(zone_center)
			var normalized_distance: float = center_distance / maxf(zone_radius + active_hit_radius, 0.01)
			# Priority only breaks overlapping/near-equal anatomy candidates. It
			# cannot make a distant head beat a blade physically inside the torso.
			var score: float = normalized_distance - zone_priority * 0.26

			var current_best: Dictionary = weapon_sweep_candidates.get(target_id, {})
			if current_best.is_empty() or score < float(current_best.get("score", INF)):
				weapon_sweep_candidates[target_id] = {
					"collider": collider,
					"shape_index": shape_index,
					"zone": zone,
					"hit_position": closest,
					"score": score,
					"distance": center_distance
				}

	var candidate_debug: Array[String] = []
	for raw_target_id: Variant in weapon_sweep_candidates:
		var candidate: Dictionary = weapon_sweep_candidates[raw_target_id]
		var collider: Node = candidate.get("collider") as Node
		if collider == null:
			continue
		var target_id: int = int(raw_target_id)
		if weapon_hit_targets.has(target_id):
			continue

		var shape_index: int = int(candidate.get("shape_index", -1))
		var zone: StringName = StringName(candidate.get("zone", StringName()))
		var hit_position: Vector3 = current_tip
		var hit_position_value: Variant = candidate.get("hit_position", current_tip)
		if hit_position_value is Vector3:
			hit_position = hit_position_value
		var motion: Vector3 = tip_sweep if tip_sweep.length() >= base_sweep.length() else base_sweep
		var event = _make_weapon_hit_event(slot, animation_driver.current_attack_context_name(), hit_position, motion, blade_speed)
		event.body_part = zone
		event.hit_material = &"flesh"
		event.contact_type = &"blade"
		event.blade_contact_ratio = clampf(previous_sword_base_position.distance_to(hit_position) / maxf(previous_sword_base_position.distance_to(previous_sword_tip_position), 0.01), 0.0, 1.0)
		_apply_zone_specific_hit_bonus(event, slot, zone)

		var accepted: bool = false
		if collider.has_method("receive_weapon_hit_zone"):
			accepted = bool(collider.call("receive_weapon_hit_zone", event, zone))
		else:
			accepted = bool(collider.call("receive_weapon_hit", event, shape_index))

		if accepted:
			weapon_hit_targets[target_id] = true
			if slot == &"spin360" and animation_driver.current_attack_context_name() == &"air" and spin_vertical_direction < 0 and spiral_down_air_impact_pending:
				spiral_down_air_hit_targets[target_id] = true
			debug_last_zone = zone
			candidate_debug.append("%s %.2fm" % [String(zone), float(candidate.get("distance", 0.0))])
			_apply_attacker_contact_response(event, collider)
			combat_hit.emit(collider, zone, event)
			_register_combat_hit_stamina()
			if combat_feedback != null:
				combat_feedback.weapon_hit(event, zone, _combat_feedback_target(collider))

	debug_last_candidates = ", ".join(candidate_debug) if not candidate_debug.is_empty() else "none"
	previous_sword_base_position = current_base
	previous_sword_tip_position = current_tip

func _minimum_blade_hit_speed(slot: StringName) -> float:
	match slot:
		&"heavy": return 0.28
		&"spin360": return 0.70
		&"light1", &"light2", &"light3": return 0.60
		_: return 0.55

func _apply_attacker_contact_response(event: Variant, target: Node) -> void:
	if event == null:
		return
	var contact: StringName = StringName(event.contact_type)
	if contact not in [&"shield", &"parry", &"armor", &"guard_break"]:
		# Flesh slightly absorbs momentum but still lets the cut continue.
		velocity.x *= 0.96
		velocity.z *= 0.96
		return
	var recoil_direction: Vector3 = global_basis.z
	if target is Node3D:
		recoil_direction = global_position - (target as Node3D).global_position
	recoil_direction.y = 0.0
	if recoil_direction.length() < 0.01:
		recoil_direction = global_basis.z
	# First cancel momentum still carrying the attacker into a solid defense. Merely
	# adding a small opposite impulse left a running/dashing player moving forward,
	# so the shield did not feel like it had stopped the blade.
	if contact == &"shield" or contact == &"parry":
		var toward_defender := -recoil_direction.normalized()
		var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
		var approach_speed := maxf(0.0, flat_velocity.dot(toward_defender))
		flat_velocity -= toward_defender * approach_speed
		velocity.x = flat_velocity.x
		velocity.z = flat_velocity.z
	var recoil: float = 3.4 if contact == &"parry" else (0.85 if contact == &"guard_break" else (2.8 if contact == &"shield" else 1.25))
	_add_horizontal_impulse(recoil_direction.normalized(), recoil, max_speed + 2.0)

func _minimum_whoosh_speed(slot: StringName) -> float:
	match slot:
		&"heavy": return 1.35
		&"spin360": return 1.65
		_: return 1.55

func _weapon_hit_radius_for_slot(slot: StringName) -> float:
	match slot:
		# Wide authored silhouettes get a small tolerance around the real blade,
		# preventing centimetre-scale marker misses without adding frontal damage.
		&"heavy": return weapon_hit_radius * 1.38
		&"spin360": return weapon_hit_radius * 1.24
		_: return weapon_hit_radius

func _attack_is_in_hit_window(slot: StringName, progress: float) -> bool:
	match slot:
		&"heavy":
			return progress >= 0.16 and progress <= 0.84
		&"spin360":
			return progress >= 0.08 and progress <= 0.90
		&"light1", &"light2", &"light3":
			return progress >= 0.10 and progress <= 0.82
		_:
			return progress >= 0.12 and progress <= 0.80

func _closest_point_on_segment(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var length_sq: float = ab.length_squared()
	if length_sq <= 0.000001:
		return a
	var t: float = clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return a + ab * t

func _attack_aim_direction(preferred_direction: Vector3, attack_slot: StringName = StringName()) -> Vector3:
	var preferred: Vector3 = preferred_direction
	preferred.y = 0.0
	if preferred.length() < 0.01:
		preferred = -global_basis.z
		preferred.y = 0.0
	preferred = preferred.normalized()

	if not aim_assist_enabled or get_tree() == null:
		return preferred
	var result: Dictionary = _find_attack_assist_target(preferred, attack_slot)
	if result.is_empty():
		return preferred
	var direction_value: Variant = result.get("direction", preferred)
	return direction_value if direction_value is Vector3 else preferred

func _begin_attack_assist(slot: StringName, context: StringName) -> void:
	_clear_attack_assist()
	if not aim_assist_enabled or context == &"slide" or context == &"wall":
		return
	var preferred: Vector3 = attack_facing_direction
	preferred.y = 0.0
	if preferred.length() < 0.01:
		preferred = _camera_forward_flat()
	preferred = preferred.normalized()
	var result: Dictionary = _find_attack_assist_target(preferred, slot)
	if result.is_empty():
		return
	attack_assist_target = result.get("target") as Node3D
	if attack_assist_target == null:
		return
	attack_assist_slot = slot
	attack_assist_context = context
	attack_assist_initial_direction = preferred
	attack_assist_startup_remaining = 0.17
	attack_assist_lock_remaining = 0.68
	attack_assist_ideal_distance = 1.78
	attack_assist_lunge_remaining = 0.38
	attack_assist_rotation_degrees = 40.0
	match slot:
		&"heavy":
			attack_assist_lock_remaining = 0.92
			attack_assist_ideal_distance = 1.90
			attack_assist_lunge_remaining = 0.50
			attack_assist_rotation_degrees = 45.0
		&"spin360":
			attack_assist_lock_remaining = 0.68
			attack_assist_ideal_distance = 1.72
			attack_assist_lunge_remaining = 0.24
			attack_assist_rotation_degrees = 54.0
	if context == &"air":
		attack_assist_lunge_remaining *= 0.45
	elif context == &"dash":
		attack_assist_lunge_remaining *= 0.70

func _update_attack_assist(delta: float) -> bool:
	if attack_assist_target == null or not is_instance_valid(attack_assist_target):
		_clear_attack_assist()
		return false
	if attack_assist_target.has_method("is_dead_for_combat") and bool(attack_assist_target.call("is_dead_for_combat")):
		_clear_attack_assist()
		return false
	attack_assist_lock_remaining = maxf(0.0, attack_assist_lock_remaining - delta)
	if attack_assist_lock_remaining <= 0.0:
		_clear_attack_assist()
		return false

	var target_position: Vector3 = _combat_target_aim_position(attack_assist_target)
	var full_offset: Vector3 = target_position - (global_position + Vector3.UP * 1.05)
	var to_target: Vector3 = target_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	var tracking_limit: float = perfect_counter_range + 1.0 if attack_assist_context in [&"counter_dash", &"counter_light"] else aim_assist_max_distance + 1.75
	if distance < 0.12 or distance > tracking_limit:
		_clear_attack_assist()
		return false
	var target_direction: Vector3 = to_target / distance

	if attack_assist_context == &"air" and attack_assist_slot != &"spin360":
		var desired_vertical_speed: float = clampf(
			full_offset.y * 5.0,
			-attack_assist_max_vertical_speed,
			attack_assist_max_vertical_speed
		)
		var vertical_weight: float = 1.0 - exp(-attack_assist_vertical_response * delta)
		velocity.y = lerpf(velocity.y, desired_vertical_speed, vertical_weight)

	var perfect_tracking: bool = attack_assist_context in [&"counter_dash", &"counter_light"]
	if perfect_tracking:
		# Perfect counters are true lock-ons: a moving target remains centred for
		# the complete authored attack instead of only during its first 220 ms.
		_face_direction(target_direction, 1.0)
	elif attack_assist_startup_remaining > 0.0:
		attack_assist_startup_remaining = maxf(0.0, attack_assist_startup_remaining - delta)
		var signed_angle: float = atan2(attack_assist_initial_direction.cross(target_direction).y, attack_assist_initial_direction.dot(target_direction))
		var limited_angle: float = clampf(signed_angle, -deg_to_rad(attack_assist_rotation_degrees), deg_to_rad(attack_assist_rotation_degrees))
		var limited_direction: Vector3 = (Basis(Vector3.UP, limited_angle) * attack_assist_initial_direction).normalized()
		# turn_speed * delta * 0.72 yields a progressive body turn over roughly
		# 150 ms instead of a one-frame lock-on snap.
		_face_direction(limited_direction, delta * 0.72)

	if attack_assist_lunge_remaining > 0.0 and distance > attack_assist_ideal_distance:
		var lunge_speed: float = 18.0 if perfect_tracking else 3.0
		var lunge_step: float = minf(attack_assist_lunge_remaining, minf(distance - attack_assist_ideal_distance, lunge_speed * delta))
		attack_assist_lunge_remaining -= lunge_step
		# Apply only the bounded displacement requested by the profile.
		# move_and_collide keeps walls authoritative even for full-auto counters.
		move_and_collide(target_direction * lunge_step)
	return true

func _attack_assist_direction(fallback: Vector3) -> Vector3:
	if attack_assist_target == null or not is_instance_valid(attack_assist_target):
		return fallback
	var direction: Vector3 = _combat_target_aim_position(attack_assist_target) - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.01 else fallback

func _clear_attack_assist() -> void:
	attack_assist_target = null
	attack_assist_slot = StringName()
	attack_assist_context = &"idle"
	attack_assist_startup_remaining = 0.0
	attack_assist_lock_remaining = 0.0
	attack_assist_lunge_remaining = 0.0

func _find_attack_assist_target(preferred: Vector3, attack_slot: StringName) -> Dictionary:
	if get_tree() == null:
		return {}
	var best_target: Node3D
	var best_direction: Vector3 = preferred
	var best_score: float = INF
	var max_distance: float = aim_assist_max_distance
	var cone_degrees: float = aim_assist_cone_degrees
	var correction_degrees: float = aim_assist_max_correction_degrees
	var angle_score_weight: float = 1.55
	match attack_slot:
		&"light1", &"light2", &"light3":
			# Light chains now acquire a nearby frontal target reliably in a crowd,
			# while keeping less reach/correction than heavy and spiral attacks.
			max_distance = 4.60
			cone_degrees = 54.0
			correction_degrees = 30.0
			angle_score_weight = 1.25
		&"heavy":
			max_distance = 5.00
			cone_degrees = 58.0
			correction_degrees = 36.0
			angle_score_weight = 1.20
		&"spin360":
			max_distance = 5.20
			cone_degrees = 74.0
			correction_degrees = 54.0
			angle_score_weight = 0.90
	var max_angle: float = deg_to_rad(cone_degrees)
	if skills != null:
		var assist: float = skills.aim_multiplier(_combat_context())
		if assist <= 0.0: return {}
		max_angle = minf(PI, max_angle * assist)
		correction_degrees = minf(180.0, correction_degrees * assist)
	var move_direction: Vector3 = _desired_move_direction()

	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if node == null or not (node is Node3D):
			continue
		if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
			continue
		var target_node: Node3D = node as Node3D
		var target_position: Vector3 = _combat_target_aim_position(target_node)
		var to_target: Vector3 = target_position - global_position
		to_target.y = 0.0
		var distance: float = to_target.length()
		if distance < 0.15 or distance > max_distance:
			continue
		var direction: Vector3 = to_target / distance
		var angle: float = acos(clampf(preferred.dot(direction), -1.0, 1.0))
		if angle > max_angle:
			continue
		if not _attack_assist_has_line_of_sight(target_position):
			continue
		var move_angle: float = 0.0
		if move_direction.length() > 0.10:
			move_angle = acos(clampf(move_direction.normalized().dot(direction), -1.0, 1.0))
		var score: float = angle * angle_score_weight + move_angle * 0.22 + distance * 0.085
		if score < best_score:
			best_score = score
			best_direction = direction
			best_target = target_node

	if best_score == INF:
		return {}

	var signed_angle: float = atan2(preferred.cross(best_direction).y, preferred.dot(best_direction))
	var correction: float = clampf(signed_angle, -deg_to_rad(correction_degrees), deg_to_rad(correction_degrees))
	return {
		"target": best_target,
		"direction": (Basis(Vector3.UP, correction) * preferred).normalized(),
		"score": best_score
	}

func _combat_target_aim_position(target: Node3D) -> Vector3:
	var target_position: Vector3 = target.global_position + Vector3.UP * 1.05
	if target.has_method("get_combat_aim_point"):
		var aim_point_value: Variant = target.call("get_combat_aim_point")
		if aim_point_value is Vector3:
			target_position = aim_point_value
	return target_position

func _attack_assist_has_line_of_sight(target_position: Vector3) -> bool:
	if get_world_3d() == null:
		return true
	var origin: Vector3 = global_position + Vector3.UP * 1.05
	attack_assist_los_query.from = origin
	attack_assist_los_query.to = target_position
	return get_world_3d().direct_space_state.intersect_ray(attack_assist_los_query).is_empty()

func _attack_vertical_pitch() -> float:
	# Use the actual camera forward vector rather than the raw pitch variable so
	# this remains correct if the camera rig changes later. Positive = aim up,
	# negative = aim down. The bridge distributes this over spine/chest bones.
	if camera != null:
		var forward: Vector3 = -camera.global_basis.z
		if forward.length() > 0.001:
			forward = forward.normalized()
			return clampf(asin(clampf(forward.y, -1.0, 1.0)) * 0.92, -0.82, 0.58)
	return clampf(camera_pitch_value * 0.92, -0.82, 0.58)

func get_combat_feedback() -> HopliteCombatFeedback:
	return combat_feedback

func _combat_feedback_target(collider: Node) -> Node:
	if collider != null and collider.has_method("get_combat_owner"):
		var owner_value: Variant = collider.call("get_combat_owner")
		if owner_value is Node:
			return owner_value as Node
	return collider

func _current_attack_aim_pitch() -> float:
	if spin_active_time > 0.0:
		return 0.64 if spin_vertical_direction > 0 else -0.76
	if attack_assist_target != null and is_instance_valid(attack_assist_target):
		var offset: Vector3 = _combat_target_aim_position(attack_assist_target) - (global_position + Vector3.UP * 1.05)
		var horizontal_distance: float = Vector2(offset.x, offset.z).length()
		if horizontal_distance > 0.05:
			return clampf(atan2(offset.y, horizontal_distance) * 0.92, -0.82, 0.58)
	return _attack_vertical_pitch()

func set_combat_debug_visible(enabled: bool) -> void:
	combat_debug_visible = enabled
	if debug_blade_mesh != null:
		debug_blade_mesh.visible = combat_debug_visible
	if debug_sweep_mesh_instance != null:
		debug_sweep_mesh_instance.visible = combat_debug_visible
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("set_combat_debug_visible"):
			enemy.call("set_combat_debug_visible", combat_debug_visible)
	print("[COMBAT DEBUG] I = ", combat_debug_visible)

func _build_weapon_debug_visuals() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	debug_blade_mesh = MeshInstance3D.new()
	debug_blade_mesh.name = "DebugSwordHitCapsule"
	debug_blade_mesh.top_level = true
	debug_blade_mesh.visible = combat_debug_visible
	debug_blade_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var capsule := CapsuleMesh.new()
	capsule.radius = weapon_hit_radius
	capsule.height = maxf(sword_base.global_position.distance_to(sword_tip.global_position) + weapon_hit_radius * 2.0, weapon_hit_radius * 2.05)
	capsule.radial_segments = 8
	capsule.rings = 3
	var blade_debug_mat := StandardMaterial3D.new()
	blade_debug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blade_debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blade_debug_mat.no_depth_test = true
	blade_debug_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.34)
	capsule.material = blade_debug_mat
	debug_blade_mesh.mesh = capsule
	scene.add_child(debug_blade_mesh)

	debug_sweep_mesh = ImmediateMesh.new()
	debug_sweep_mesh_instance = MeshInstance3D.new()
	debug_sweep_mesh_instance.name = "DebugSwordTemporalSweep"
	debug_sweep_mesh_instance.top_level = true
	debug_sweep_mesh_instance.visible = combat_debug_visible
	debug_sweep_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug_sweep_mesh_instance.mesh = debug_sweep_mesh
	debug_line_material = StandardMaterial3D.new()
	debug_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_line_material.no_depth_test = true
	debug_line_material.albedo_color = Color(1.0, 0.38, 0.06, 0.95)
	scene.add_child(debug_sweep_mesh_instance)

func _update_weapon_debug_visuals(previous_base: Vector3, previous_tip: Vector3, current_base: Vector3, current_tip: Vector3) -> void:
	if debug_blade_mesh == null or debug_sweep_mesh == null:
		return
	var segment: Vector3 = current_tip - current_base
	if segment.length() > 0.02:
		debug_blade_mesh.global_transform = Transform3D(_basis_y_along(segment), current_base.lerp(current_tip, 0.5))

	if not combat_debug_visible:
		return
	debug_sweep_mesh.clear_surfaces()
	debug_sweep_mesh.surface_begin(Mesh.PRIMITIVE_LINES, debug_line_material)
	_debug_line(previous_base, current_base)
	_debug_line(previous_tip, current_tip)
	_debug_line(previous_base, previous_tip)
	_debug_line(current_base, current_tip)
	debug_sweep_mesh.surface_end()

func _debug_line(a: Vector3, b: Vector3) -> void:
	if debug_sweep_mesh == null:
		return
	debug_sweep_mesh.surface_add_vertex(a)
	debug_sweep_mesh.surface_add_vertex(b)

func _make_weapon_hit_event(slot: StringName, context: StringName, hit_position: Vector3, sweep: Vector3, blade_speed: float) -> Variant:
	var event = HitEventScript.new()
	event.source = self
	event.position = hit_position
	var direction: Vector3 = sweep.normalized() if sweep.length() > 0.01 else _camera_forward_flat()
	event.direction = direction
	event.normal = -direction
	event.blade_speed = blade_speed
	event.attack_slot = slot
	event.attack_context = context
	event.attack_charge_ratio = last_heavy_release_ratio if slot == &"heavy" else 0.0
	event.attack_vertical_direction = spin_vertical_direction if slot == &"spin360" else 0
	event.damage_type = &"slash"

	match slot:
		&"light1":
			event.damage = 18.0
			event.sever_damage = 16.0
			event.guard_damage = 24.0
		&"light2":
			event.damage = 20.0
			event.sever_damage = 18.0
			event.guard_damage = 29.0
		&"light3":
			event.damage = 24.0
			event.sever_damage = 23.0
			event.guard_damage = 38.0
		&"heavy":
			event.damage = lerpf(39.0, 76.0, last_heavy_release_ratio)
			event.sever_damage = lerpf(50.0, 112.0, last_heavy_release_ratio)
			event.guard_damage = lerpf(62.0, 132.0, last_heavy_release_ratio)
		&"spin360":
			event.damage = 30.0
			event.sever_damage = 34.0
			event.guard_damage = 52.0
		_:
			event.damage = 18.0
			event.sever_damage = 14.0
			event.guard_damage = 20.0

	var movement_speed: float = Vector2(velocity.x, velocity.z).length()
	var physical_bonus: float = clampf(0.90 + blade_speed * 0.025 + movement_speed * 0.018, 0.90, 1.55)
	event.damage *= physical_bonus
	event.sever_damage *= physical_bonus
	event.guard_damage *= physical_bonus
	if perfect_recovery_active:
		event.damage *= perfect_recovery_damage_multiplier
		event.sever_damage *= perfect_recovery_damage_multiplier
		event.guard_damage *= perfect_recovery_damage_multiplier

	match context:
		&"run":
			event.damage *= 1.05
			event.sever_damage *= 1.08
		&"air":
			event.damage *= 1.10
			event.sever_damage *= 1.16
		&"dash":
			event.damage *= 1.18
			event.sever_damage *= 1.34
			event.guard_damage *= 1.28
		&"slide":
			event.damage *= 1.12
			event.sever_damage *= 1.32
			event.guard_damage *= 1.18
		&"counter_light":
			event.damage *= 1.30
			event.sever_damage *= 1.38
			event.guard_damage *= 1.42
		&"counter_dash":
			event.damage *= 1.34
			event.sever_damage *= 1.42
			event.guard_damage *= 1.48

	# Spiral Up earns its aerial reward on the blade itself. Spiral Down reserves
	# most of that payoff for the true 360-degree landing impact, avoiding an
	# accidental double one-shot on the enemy crossed during descent.
	if slot == &"spin360" and context == &"air":
		if spin_vertical_direction < 0:
			event.damage *= 1.35
			event.sever_damage *= 1.28
			event.guard_damage *= 1.45
		else:
			event.damage *= 1.85
			event.sever_damage *= 2.00
			event.guard_damage *= 1.55

	event.damage *= weapon_damage_multiplier
	event.sever_damage *= weapon_damage_multiplier
	event.guard_damage *= weapon_damage_multiplier

	event.impulse = direction * clampf(2.5 + event.sever_damage * 0.045, 3.0, 10.0)
	if skills != null:
		skills.modify_hit(event)
	return event

func _apply_zone_specific_hit_bonus(event: Variant, slot: StringName, zone: StringName) -> void:
	if event == null:
		return
	if slot == &"spin360" and spin_vertical_direction > 0 and (zone == &"neck" or zone == &"head"):
		# Upward spirals lift the blade through the neck line. The regular damage
		# rises only slightly; the large sever multiplier is the decapitation reward.
		event.damage *= 1.08
		event.sever_damage *= 2.10
		event.damage_type = &"decapitation"
		event.impulse = event.direction * clampf(2.5 + event.sever_damage * 0.045, 3.0, 10.0)
	elif slot == &"spin360" and spin_vertical_direction < 0 and zone in [&"thigh_l", &"thigh_r", &"shin_l", &"shin_r"]:
		# The grounded low circle is a leg-control attack, not a torso slash. Direct
		# low contacts therefore carry the payoff even outside the aerial smash.
		event.damage *= 1.42
		event.sever_damage *= 1.32
		event.guard_damage *= 1.12
		event.damage_type = &"low_sweep"
		event.impulse = event.direction * clampf(2.2 + event.sever_damage * 0.035, 2.6, 7.0)

func _make_slide_contact_hit() -> Variant:
	var event = HitEventScript.new()
	event.source = self
	event.position = global_position + Vector3.UP * 0.78 + slide_direction * 0.38
	event.direction = slide_direction.normalized() if slide_direction.length() > 0.01 else _camera_forward_flat()
	event.normal = -event.direction
	event.attack_slot = &"slide_contact"
	event.attack_context = &"slide"
	event.damage_type = &"slash"
	event.damage = 25.0
	event.sever_damage = 36.0
	event.guard_damage = 44.0
	event.blade_speed = _slide_speed()
	event.impulse = event.direction * 5.5
	if skills != null: skills.modify_hit(event)
	return event

func _resolve_slide_slash_target(collider: Node) -> Node:
	var current: Node = collider
	var depth: int = 0
	while current != null and depth < 5:
		if current.is_in_group("damageable") or current.has_method("on_slide_slash"):
			return current
		current = current.get_parent()
		depth += 1
	return null

func _basis_y_along(segment: Vector3) -> Basis:
	var y_axis: Vector3 = segment.normalized()
	var helper: Vector3 = Vector3.RIGHT
	if absf(y_axis.dot(helper)) > 0.92:
		helper = Vector3.FORWARD
	var z_axis: Vector3 = helper.cross(y_axis).normalized()
	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _add_horizontal_impulse(direction: Vector3, impulse: float, speed_cap: float) -> void:
	var flat_direction: Vector3 = direction
	flat_direction.y = 0.0
	if flat_direction.length() < 0.001:
		return
	flat_direction = flat_direction.normalized()

	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	flat_velocity += flat_direction * impulse

	var cap: float = maxf(0.0, speed_cap)
	if cap > 0.0 and flat_velocity.length() > cap:
		flat_velocity = flat_velocity.normalized() * cap

	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z

func _consume_dash_charge() -> void:
	if dash_charges <= 0:
		return
	dash_charges -= 1
	if dash_recharge_timer <= 0.0:
		dash_recharge_timer = dash_recharge_duration
	combat_resources_changed.emit()

func _consume_slide_charge() -> void:
	if slide_charges <= 0:
		return
	slide_charges -= 1
	if slide_recharge_timer <= 0.0:
		slide_recharge_timer = slide_recharge_duration
	combat_resources_changed.emit()

func _update_mobility_resources(delta: float) -> void:
	var changed: bool = false
	if dash_charges < dash_max_charges:
		dash_recharge_timer = maxf(0.0, dash_recharge_timer - delta)
		if dash_recharge_timer <= 0.0:
			dash_charges += 1
			changed = true
			if dash_charges < dash_max_charges:
				dash_recharge_timer = dash_recharge_duration
	else:
		dash_recharge_timer = 0.0
	if slide_charges < slide_max_charges:
		slide_recharge_timer = maxf(0.0, slide_recharge_timer - delta)
		if slide_recharge_timer <= 0.0:
			slide_charges += 1
			changed = true
			if slide_charges < slide_max_charges:
				slide_recharge_timer = slide_recharge_duration
	else:
		slide_recharge_timer = 0.0
	if changed:
		combat_resources_changed.emit()

func _restore_all_mobility_charges() -> void:
	var changed: bool = dash_charges != dash_max_charges or slide_charges != slide_max_charges
	dash_charges = dash_max_charges
	slide_charges = slide_max_charges
	dash_recharge_timer = 0.0
	slide_recharge_timer = 0.0
	if changed:
		combat_resources_changed.emit()

func _add_spiral_stamina(amount: float) -> void:
	var next_value: float = clampf(spiral_stamina + amount, 0.0, max_spiral_stamina)
	if is_equal_approx(next_value, spiral_stamina):
		return
	spiral_stamina = next_value
	combat_resources_changed.emit()

func _activate_perfect_recovery() -> void:
	perfect_recovery_active = true
	health_regen_elapsed = health_regen_delay
	combat_resources_changed.emit()

func _update_health_recovery(delta: float) -> void:
	health_regen_elapsed += delta
	if health >= max_health:
		return
	if not perfect_recovery_active and health_regen_elapsed < health_regen_delay:
		return
	var rate: float = perfect_regen_rate if perfect_recovery_active else health_regen_rate
	health = minf(max_health, health + rate * delta)

func _register_combat_hit_stamina() -> void:
	_add_spiral_stamina(spiral_hit_reward)

func _update_perfect_counter_aoe() -> void:
	if not perfect_counter_aoe_pending or animation_driver == null:
		return
	if not animation_driver.is_attack_active():
		perfect_counter_aoe_pending = false
		return
	if animation_driver.current_attack_context_name() != &"counter_light":
		perfect_counter_aoe_pending = false
		return
	if animation_driver.current_attack_progress() < 0.20:
		return
	perfect_counter_aoe_pending = false
	var damage_multiplier: float = perfect_recovery_damage_multiplier if perfect_recovery_active else 1.0
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node3D):
			continue
		var target: Node3D = node as Node3D
		if target.has_method("is_dead_for_combat") and bool(target.call("is_dead_for_combat")):
			continue
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0.0
		if offset.length() > perfect_counter_aoe_radius:
			continue
		if not _attack_assist_has_line_of_sight(_combat_target_aim_position(target)):
			continue
		var direction: Vector3 = offset.normalized() if offset.length() > 0.01 else -global_basis.z
		var accepted: bool = false
		if target.has_method("receive_ai_hit"):
			accepted = bool(target.call("receive_ai_hit", perfect_counter_aoe_damage * damage_multiplier, self, direction))
		if not accepted:
			continue
		var event = HitEventScript.new()
		event.source = self
		event.position = _combat_target_aim_position(target)
		event.direction = direction
		event.normal = -direction
		event.impulse = direction * 9.0
		event.damage = perfect_counter_aoe_damage * damage_multiplier
		event.sever_damage = event.damage * 0.72
		event.guard_damage = event.damage * 1.35
		event.blade_speed = 14.0
		event.attack_slot = &"counter_wave"
		event.attack_context = &"counter_light"
		event.damage_type = &"shockwave"
		event.body_part = &"torso"
		combat_hit.emit(target, &"torso", event)
		_register_combat_hit_stamina()
		if combat_feedback != null:
			combat_feedback.weapon_hit(event, &"torso", target)

func _move_with_traversal_platform_policy() -> void:
	# Godot normally adds the last moving-platform velocity when a CharacterBody
	# leaves it. Animated dinosaur bones can legitimately move much faster than
	# the dinosaur root, so that inheritance becomes an occasional catapult.
	# Keep platform following while contact exists, but suppress only the leave
	# impulse from an identified giant traversal support.
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING if giant_traversal_support_active else CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	move_and_slide()
	giant_traversal_support_active = _has_giant_traversal_floor_collision()
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING if giant_traversal_support_active else CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY

func _has_giant_traversal_floor_collision() -> bool:
	var floor_dot_threshold := cos(floor_max_angle)
	var up := up_direction.normalized()
	for collision_index: int in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if collision == null or collision.get_normal().dot(up) < floor_dot_threshold:
			continue
		var collider := collision.get_collider() as Node
		if collider != null and collider.is_in_group(GIANT_TRAVERSAL_SURFACE_GROUP):
			return true
	return false

func _try_start_wall_run() -> bool:
	if skills != null and not skills.active(&"wall"): return false
	if wall_run_active or not wall_run_attach_available or wall_run_attach_cooldown > 0.0 or wall_run_runs_used >= wall_run_max_chain_runs:
		return _reject_wall_run("availability/cooldown/chain limit")
	# The first contact is free. Any following contact in the same airborne
	# sequence must have been explicitly armed by jumping away from the wall.
	if wall_run_runs_used > 0 and not wall_run_chain_armed_by_jump:
		return _reject_wall_run("next contact not armed by wall jump")
	if is_on_floor() or parkour_active or get_world_3d() == null:
		return _reject_wall_run("grounded, parkour active, or world unavailable")
	if spiral_down_air_impact_pending:
		return _reject_wall_run("Spiral Down impact pending")
	if animation_driver != null and animation_driver.current_action_blocks(&"wall_attach"):
		return _reject_wall_run("active combat action blocks wall_attach")

	var desired: Vector3 = _desired_move_direction()
	_refresh_wall_run_release_input_guard(desired)
	if desired.length() < 0.05:
		return _reject_wall_run("no movement input")
	var hit: Dictionary = _find_wall_run_surface(desired)
	if hit.is_empty():
		return _reject_wall_run("no valid wall surface")
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	normal.y = 0.0
	if normal.length() < 0.70:
		return _reject_wall_run("wall normal is not horizontal enough")
	normal = normal.normalized()
	# Holding the same forward input after a vertical wall jump must not pivot the
	# player back into the wall or spend the second run on that same surface. A
	# real input release clears this guard and restores intentional reattachment.
	if wall_run_release_input_guard and wall_run_release_normal.length() > 0.70 and normal.dot(wall_run_release_normal.normalized()) > 0.72:
		return _reject_wall_run("release guard rejects same surface")

	var tangent_input: Vector3 = desired - normal * desired.dot(normal)
	var into_wall: float = maxf(0.0, -desired.dot(normal))
	if tangent_input.length() < 0.22 and into_wall < 0.35:
		return _reject_wall_run("insufficient tangent or inward input")
	# A head-on vertical run must come from a real upward jump. This prevents a
	# falling player from regaining height merely by holding forward at a wall.
	if tangent_input.length() < 0.22 and velocity.y <= 0.35:
		return _reject_wall_run("vertical attach requires upward velocity")

	if skills != null and not skills.wall_allowed(_wall_run_hit_kind(hit)): return false
	_begin_wall_run(normal, desired, _wall_run_hit_kind(hit))
	return true


func _reject_wall_run(reason: String) -> bool:
	wall_run_debug_reason = "rejected: " + reason
	return false


func _begin_wall_run(normal: Vector3, desired: Vector3, surface_kind: StringName = &"world") -> void:
	# Wall running is a mobility extension of combat: held primary/direct-heavy
	# input, accumulated charge and its upper-body pose all survive attachment.
	_set_shield_blocking(false)
	_stop_slide(false, false)
	dash_time = 0.0
	dash_variant_grace = 0.0
	wall_run_active = true
	wall_run_surface_kind = surface_kind if surface_kind != StringName() else &"world"
	wall_run_attach_available = false
	wall_run_chain_armed_by_jump = false
	wall_run_passive_detach_locked = false
	wall_run_release_input_guard = false
	wall_run_release_input_guard_timer = 0.0
	wall_run_release_normal = Vector3.ZERO
	wall_run_just_started = true
	wall_run_runs_used += 1
	wall_run_normal = normal.normalized()
	wall_run_last_tangent = _wall_tangent(desired).normalized()
	wall_run_distance = 0.0
	wall_run_vertical_rise = 0.0
	wall_run_vertical_time = 0.0
	wall_run_corner_follow_active = false
	wall_run_corner_tangent = Vector3.ZERO
	wall_run_corner_input_reference = Vector3.ZERO
	wall_run_mode = _classify_wall_run_mode(desired, true)
	wall_run_debug_reason = "attached %s on %s (%d/%d)" % [String(wall_run_mode), String(wall_run_surface_kind), wall_run_runs_used, wall_run_max_chain_runs]
	if animation_driver != null:
		animation_driver.clear_wall_release_air_pose()
		animation_driver.play_wall_run_visual(wall_run_mode, _wall_run_should_mirror(wall_run_last_tangent))
	_sync_wall_run_feedback()

func _update_wall_run(delta: float) -> bool:
	if not wall_run_active:
		return false

	var started_now: bool = wall_run_just_started
	wall_run_just_started = false

	# Reaching a climbable lip wins over both the vertical exhaustion and the
	# wall-jump input. This keeps the authored mantle readable at the top.
	if _wall_run_surface_allows_parkour() and (wall_run_mode == &"vertical" or wall_run_mode == &"diagonal"):
		if _try_start_parkour(-wall_run_normal, true):
			wall_run_debug_reason = "top -> climb priority"
			return true

	if Input.is_action_just_pressed("jump") and not started_now:
		_perform_wall_jump()
		_move_with_traversal_platform_policy()
		if is_on_floor():
			_reset_wall_run_after_landing()
		return true

	var raw_desired: Vector3 = _desired_move_direction()
	if raw_desired.length() < 0.05:
		_detach_wall_run("input released", false)
		return false
	var desired: Vector3 = _wall_run_effective_direction(raw_desired)

	var wall_hit: Dictionary = _try_transfer_wall_corner(raw_desired) if wall_run_mode == &"horizontal" and wall_run_surface_kind == &"world" else {}
	if wall_hit.is_empty():
		wall_hit = _probe_current_wall()
	if wall_hit.is_empty():
		_detach_wall_run("wall lost", false)
		return false
	if wall_run_corner_follow_active:
		desired = _wall_run_effective_direction(raw_desired)
	var refreshed_normal: Vector3 = wall_hit.get("normal", wall_run_normal)
	refreshed_normal.y = 0.0
	if refreshed_normal.length() > 0.70:
		wall_run_normal = wall_run_normal.lerp(refreshed_normal.normalized(), clampf(delta * 18.0, 0.0, 1.0)).normalized()
	if _wall_run_lateral_course_is_exhausted(desired):
		_detach_wall_run("curved surface course exhausted", false)
		return false

	var next_mode: StringName = _classify_wall_run_mode(desired, false)
	if next_mode == &"vertical" and wall_run_mode != &"vertical" and velocity.y < -0.50:
		next_mode = &"diagonal" if _wall_tangent(desired).length() > 0.22 else &"horizontal"
	if next_mode != wall_run_mode:
		wall_run_mode = next_mode
		wall_run_debug_reason = "transition -> %s" % String(wall_run_mode)

	if wall_run_mode == &"vertical" and (wall_run_vertical_rise >= wall_run_vertical_max_rise or wall_run_vertical_time >= wall_run_vertical_max_time):
		_detach_wall_run("vertical exhausted", true)
		return false

	var tangent: Vector3 = _wall_tangent(desired)
	if tangent.length() < 0.10:
		tangent = _wall_tangent(Vector3(velocity.x, 0.0, velocity.z))
	if tangent.length() > 0.001:
		tangent = tangent.normalized()
		wall_run_last_tangent = tangent
	if animation_driver != null:
		animation_driver.play_wall_run_visual(wall_run_mode, _wall_run_should_mirror(tangent))

	match wall_run_mode:
		&"vertical":
			velocity = -wall_run_normal * wall_run_wall_pressure + Vector3.UP * wall_run_vertical_speed
			_face_direction(-wall_run_normal, delta * 2.8)
		&"diagonal":
			if tangent.length() < 0.10:
				_detach_wall_run("no diagonal tangent", false)
				return false
			velocity.x = tangent.x * wall_run_diagonal_speed - wall_run_normal.x * wall_run_wall_pressure
			velocity.z = tangent.z * wall_run_diagonal_speed - wall_run_normal.z * wall_run_wall_pressure
			velocity.y = wall_run_diagonal_vertical_speed
			_face_direction(tangent, delta * 2.2)
		_:
			if tangent.length() < 0.10:
				_detach_wall_run("no horizontal tangent", false)
				return false
			velocity.x = tangent.x * wall_run_horizontal_speed - wall_run_normal.x * wall_run_wall_pressure
			velocity.z = tangent.z * wall_run_horizontal_speed - wall_run_normal.z * wall_run_wall_pressure
			velocity.y = move_toward(velocity.y, -0.45, 13.0 * delta)
			_face_direction(tangent, delta * 2.2)

	var before_move: Vector3 = global_position
	_move_with_traversal_platform_policy()
	var travelled: float = global_position.distance_to(before_move)
	wall_run_distance += travelled
	if wall_run_mode == &"vertical":
		wall_run_vertical_time += delta
		wall_run_vertical_rise += maxf(0.0, global_position.y - before_move.y)

	if is_on_floor():
		_reset_wall_run_after_landing()
		return true
	if wall_run_distance >= wall_run_max_distance:
		_detach_wall_run("distance exhausted", wall_run_mode == &"vertical")
		return true
	if wall_run_mode == &"vertical" and (wall_run_vertical_rise >= wall_run_vertical_max_rise or wall_run_vertical_time >= wall_run_vertical_max_time):
		_detach_wall_run("vertical exhausted", true)
		return true
	return true

func _perform_wall_jump() -> void:
	var released_mode: StringName = wall_run_mode
	var released_surface_kind: StringName = wall_run_surface_kind
	var desired: Vector3 = _desired_move_direction()
	var tangent: Vector3 = _wall_tangent(desired)
	if tangent.length() < 0.10:
		tangent = wall_run_last_tangent
	if tangent.length() > 0.10:
		tangent = tangent.normalized()
	velocity = tangent * wall_jump_tangent_speed + Vector3.UP * wall_jump_up_speed
	velocity += _wall_run_repulsion(released_mode, tangent, released_surface_kind)
	wall_run_repulsion_control_lock = _wall_run_release_lock_duration(released_mode, false)
	wall_run_active = false
	wall_run_mode = StringName()
	wall_run_surface_kind = &"world"
	wall_run_attach_available = wall_run_runs_used < wall_run_max_chain_runs
	wall_run_chain_armed_by_jump = wall_run_attach_available
	wall_run_passive_detach_locked = false
	wall_run_release_input_guard = released_mode == &"vertical"
	wall_run_release_input_guard_timer = wall_run_release_input_guard_duration if wall_run_release_input_guard else 0.0
	wall_run_release_normal = wall_run_normal
	wall_run_attach_cooldown = 0.16
	wall_run_just_started = false
	jumps_used = 1
	wall_run_corner_follow_active = false
	if skills != null:
		skills.on_wall_jump(released_surface_kind)
	wall_run_debug_reason = "wall jump -> %s (%d/%d)" % ["chain armed" if wall_run_attach_available else "chain spent", wall_run_runs_used, wall_run_max_chain_runs]
	_sync_wall_run_feedback()
	movement_sfx_requested.emit(&"jump")
	if animation_driver != null:
		if released_mode == &"vertical":
			animation_driver.finish_wall_run_visual(true)
		else:
			animation_driver.stop_wall_run_visual()
			if animation_driver.play_ninja_jump(1.14) <= 0.0:
				animation_driver.play_full_body(&"jump")
		animation_driver.request_wall_release_air_pose()
	# Run To Flip already provides the vertical release rotation. Keeping the
	# CharacterBody facing the wall avoids the extra scripted quarter/half turn;
	# the perpendicular velocity alone carries the player away correctly.
	if released_mode != &"vertical":
		var jump_facing: Vector3 = wall_run_normal + tangent * 0.55
		if jump_facing.length() > 0.05:
			_face_direction(jump_facing.normalized(), 1.0)

func _detach_wall_run(reason: String, vertical_flip: bool) -> void:
	if not wall_run_active:
		return
	var released_mode: StringName = wall_run_mode
	var released_surface_kind: StringName = wall_run_surface_kind
	var released_tangent: Vector3 = wall_run_last_tangent
	var released_mirrored: bool = _wall_run_should_mirror(released_tangent)
	var detach_repulsion: Vector3 = _wall_run_repulsion(released_mode, released_tangent, released_surface_kind)
	var passive_dynamic_vertical: bool = released_surface_kind == &"giant_enemy" and released_mode == &"vertical"
	if passive_dynamic_vertical:
		# Losing the animated surface at the top of a giant is not a jump input.
		# Preserve a small cresting velocity so the player can settle on its back,
		# but reject the old +11.2 m/s automatic launch.
		detach_repulsion = Vector3.ZERO
		velocity.y = minf(velocity.y, 2.2)
	if released_mode == &"horizontal":
		# Preserve the complete running momentum. Only the additional kick is
		# reduced by 90%, so detachment continues naturally along the wall without
		# reading as a second jump-strength launch.
		velocity.x *= wall_run_horizontal_detach_momentum_retention
		velocity.z *= wall_run_horizontal_detach_momentum_retention
		detach_repulsion *= wall_run_horizontal_detach_repulsion_scale
	velocity += detach_repulsion
	wall_run_repulsion_control_lock = 0.0 if passive_dynamic_vertical else _wall_run_release_lock_duration(released_mode, true)
	wall_run_active = false
	wall_run_mode = StringName()
	wall_run_surface_kind = &"world"
	wall_run_attach_available = false
	wall_run_chain_armed_by_jump = false
	wall_run_passive_detach_locked = true
	wall_run_release_input_guard = true
	wall_run_release_input_guard_timer = wall_run_release_input_guard_duration
	wall_run_release_normal = wall_run_normal
	wall_run_just_started = false
	wall_run_corner_follow_active = false
	wall_run_debug_reason = reason
	_sync_wall_run_feedback()
	if animation_driver != null:
		if vertical_flip or released_mode == &"vertical":
			animation_driver.finish_wall_run_visual(true)
		elif not animation_driver.play_wall_run_detach_visual(released_mode, released_mirrored):
			animation_driver.stop_wall_run_visual()
		animation_driver.request_wall_release_air_pose()

func _reset_wall_run_after_landing() -> void:
	if animation_driver != null:
		animation_driver.clear_wall_release_air_pose()
	if wall_run_active or not wall_run_attach_available or wall_run_distance > 0.0:
		if animation_driver != null:
			animation_driver.stop_wall_run_visual()
	wall_run_active = false
	wall_run_mode = StringName()
	wall_run_surface_kind = &"world"
	wall_run_normal = Vector3.ZERO
	wall_run_last_tangent = Vector3.ZERO
	wall_run_distance = 0.0
	wall_run_vertical_rise = 0.0
	wall_run_vertical_time = 0.0
	wall_run_attach_available = true
	wall_run_attach_cooldown = 0.0
	wall_run_repulsion_control_lock = 0.0
	wall_run_chain_armed_by_jump = false
	wall_run_passive_detach_locked = false
	wall_run_release_input_guard = false
	wall_run_release_input_guard_timer = 0.0
	wall_run_release_normal = Vector3.ZERO
	wall_run_just_started = false
	wall_run_runs_used = 0
	wall_run_corner_follow_active = false
	wall_run_corner_tangent = Vector3.ZERO
	wall_run_corner_input_reference = Vector3.ZERO
	_sync_wall_run_feedback()
	wall_run_debug_reason = "grounded -> rearmed"

func _classify_wall_run_mode(desired: Vector3, _initial_contact: bool) -> StringName:
	var tangent_amount: float = _wall_tangent(desired).length()
	var into_wall: float = maxf(0.0, -desired.dot(wall_run_normal))
	if into_wall > 0.42 and tangent_amount < 0.38 and velocity.y > -0.50:
		return &"vertical"
	if tangent_amount > 0.22 and into_wall > 0.16:
		return &"diagonal"
	return &"horizontal"

func _wall_tangent(direction: Vector3) -> Vector3:
	var flat: Vector3 = direction
	flat.y = 0.0
	return flat - wall_run_normal * flat.dot(wall_run_normal)

func _wall_run_lateral_course_is_exhausted(desired: Vector3) -> bool:
	if wall_run_mode != &"horizontal" and wall_run_mode != &"diagonal":
		return false
	var flat_desired: Vector3 = desired
	flat_desired.y = 0.0
	if flat_desired.length() < 0.05 or wall_run_normal.length() < 0.70:
		return false
	flat_desired = flat_desired.normalized()
	var projected_tangent: Vector3 = _wall_tangent(flat_desired)
	# On a convex surface the refreshed normal eventually points in the same
	# direction as the held input. The tangent projection then crosses zero; if it
	# is normalized anyway, numerical noise turns it into a full-speed reversal
	# and the player oscillates around the same strip of the cylinder.
	if flat_desired.dot(wall_run_normal) <= 0.0:
		return false
	if projected_tangent.length() < wall_run_lateral_min_tangent:
		return true
	if wall_run_last_tangent.length() < 0.10:
		return false
	return projected_tangent.normalized().dot(wall_run_last_tangent.normalized()) <= 0.0

func _wall_run_effective_direction(raw_desired: Vector3) -> Vector3:
	if wall_run_corner_follow_active:
		if raw_desired.dot(wall_run_corner_input_reference) >= 0.55:
			return wall_run_corner_tangent
		wall_run_corner_follow_active = false
	return raw_desired

func _wall_run_should_mirror(tangent: Vector3) -> bool:
	if wall_run_mode == &"vertical" or tangent.length() < 0.10:
		return false
	var run_direction: Vector3 = tangent.normalized()
	var character_right: Vector3 = Vector3(-run_direction.z, 0.0, run_direction.x)
	var toward_wall: Vector3 = -wall_run_normal
	# The source Mixamo cycle is treated as wall-on-left. Reflect the authored
	# pose whenever the contacted wall is on the character's right.
	return toward_wall.dot(character_right) > 0.0

func _wall_run_repulsion(mode: StringName, tangent: Vector3, surface_kind: StringName = &"world") -> Vector3:
	var angle_degrees: float = wall_run_horizontal_repulsion_angle
	var force: float = wall_run_horizontal_repulsion_force
	if mode == &"diagonal":
		angle_degrees = wall_run_diagonal_repulsion_angle
		force = wall_run_diagonal_repulsion_force
	elif mode == &"vertical":
		angle_degrees = wall_run_vertical_repulsion_angle
		force = wall_run_vertical_repulsion_force

	var along_wall: Vector3 = tangent
	if along_wall.length() < 0.10:
		along_wall = wall_run_last_tangent
	if along_wall.length() < 0.10:
		along_wall = Vector3(-wall_run_normal.z, 0.0, wall_run_normal.x)
	along_wall = along_wall.normalized()
	var angle: float = deg_to_rad(angle_degrees)
	var direction: Vector3 = along_wall * cos(angle) + wall_run_normal * sin(angle)
	# World tuning is intentionally untouched. Dynamic combat surfaces keep the
	# same authored direction, but horizontal/diagonal release kick is reduced by
	# 80% so a shield line or moving boss does not eject the player violently.
	var surface_scale: float = 1.0
	if surface_kind != &"world" and (mode == &"horizontal" or mode == &"diagonal"):
		surface_scale = experimental_dynamic_release_repulsion_scale
	return direction.normalized() * force * surface_scale

func _wall_run_release_lock_duration(mode: StringName, passive_detach: bool) -> float:
	# Vertical already reads well and keeps its original timing. Horizontal and
	# diagonal releases need a slightly longer uncontested beat, especially when
	# the player is still holding a diagonal input at automatic detachment.
	if mode == &"vertical":
		return wall_run_repulsion_control_lock_duration
	var duration: float = 0.24 if mode == &"horizontal" else 0.28
	return duration + (0.10 if passive_detach else 0.0)

func _filter_wall_run_release_input(move_dir: Vector3) -> Vector3:
	_refresh_wall_run_release_input_guard(move_dir)
	if not wall_run_release_input_guard or is_on_floor() or wall_run_release_normal.length() < 0.70:
		return move_dir
	var release_normal: Vector3 = wall_run_release_normal.normalized()
	var toward_released_wall: float = minf(0.0, move_dir.dot(release_normal))
	var filtered: Vector3 = move_dir - release_normal * toward_released_wall
	# Preserve the residual magnitude. Normalizing a tiny camera-relative tangent
	# used to turn numerical drift into a full lateral command, making the
	# character rotate 90 degrees along the wall.
	return filtered if filtered.length() > 0.001 else Vector3.ZERO

func _refresh_wall_run_release_input_guard(move_dir: Vector3) -> void:
	if not wall_run_release_input_guard:
		return
	# This guard exists only for the first instant of the release. It protects the
	# outward impulse even if forward is still held, then expires independently of
	# that held input so a double jump can deliberately return to the same wall.
	if (
		wall_run_release_input_guard_timer <= 0.0
		or is_on_floor()
		or wall_run_release_normal.length() < 0.70
		or move_dir.length() < 0.05
		or move_dir.dot(wall_run_release_normal.normalized()) >= -0.08
	):
		wall_run_release_input_guard = false
		wall_run_release_input_guard_timer = 0.0

func _try_transfer_wall_corner(raw_desired: Vector3) -> Dictionary:
	var hit: Dictionary = _find_wall_run_corner_surface()
	if hit.is_empty():
		return {}
	var raw_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	var new_normal: Vector3 = Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()
	if new_normal.length() < 0.70:
		return {}

	var old_normal: Vector3 = wall_run_normal
	var old_tangent: Vector3 = wall_run_last_tangent
	if old_tangent.length() < 0.10:
		old_tangent = _wall_tangent(Vector3(velocity.x, 0.0, velocity.z)).normalized()
	if old_tangent.length() < 0.10:
		return {}

	var normal_angle: float = rad_to_deg(acos(clampf(old_normal.dot(new_normal), -1.0, 1.0)))
	if normal_angle > wall_run_corner_max_angle:
		wall_run_debug_reason = "corner %.0fdeg rejected" % normal_angle
		return {}
	var almost_straight: bool = normal_angle <= 8.0
	# At an interior corner the new surface normal faces against the current
	# travel. At an exterior building corner it faces with the travel (the 270°
	# route), which must detach instead of wrapping around the façade.
	if not _wall_run_corner_is_interior(old_normal, old_tangent, new_normal):
		wall_run_debug_reason = "exterior corner rejected"
		return {}

	var next_tangent: Vector3 = old_tangent
	if not almost_straight:
		next_tangent = old_normal - new_normal * old_normal.dot(new_normal)
		if next_tangent.length() < 0.10:
			return {}
		next_tangent = next_tangent.normalized()

	wall_run_normal = new_normal
	wall_run_last_tangent = next_tangent
	wall_run_corner_tangent = next_tangent
	wall_run_corner_input_reference = raw_desired.normalized()
	wall_run_corner_follow_active = true
	wall_run_debug_reason = "interior corner %.0fdeg" % normal_angle
	return hit

func _find_wall_run_corner_surface() -> Dictionary:
	var travel: Vector3 = wall_run_last_tangent
	if travel.length() < 0.10:
		travel = _wall_tangent(Vector3(velocity.x, 0.0, velocity.z))
	if travel.length() < 0.10:
		return {}
	travel = travel.normalized()
	var best: Dictionary = {}
	var best_distance: float = INF
	var reach: float = wall_run_probe_distance
	for height: float in [0.48, 1.22]:
		var from_point: Vector3 = global_position + Vector3.UP * height
		var hit: Dictionary = _raycast_world(from_point, from_point + travel * reach)
		if hit.is_empty():
			continue
		var raw_normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if absf(raw_normal.dot(Vector3.UP)) > 0.48:
			continue
		var normal: Vector3 = Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()
		var angle: float = rad_to_deg(acos(clampf(wall_run_normal.dot(normal), -1.0, 1.0)))
		if angle <= 8.0:
			continue
		var point: Vector3 = hit.get("position", from_point)
		var distance: float = from_point.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = hit
	return best

func _wall_run_corner_is_interior(old_normal: Vector3, old_tangent: Vector3, new_normal: Vector3) -> bool:
	var angle: float = rad_to_deg(acos(clampf(old_normal.normalized().dot(new_normal.normalized()), -1.0, 1.0)))
	if angle > wall_run_corner_max_angle:
		return false
	if angle <= 8.0:
		return true
	return new_normal.normalized().dot(old_tangent.normalized()) < -0.05

func _probe_current_wall() -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for height: float in [0.48, 1.22]:
		var from_point: Vector3 = global_position + Vector3.UP * height
		var to_point: Vector3 = from_point - wall_run_normal * wall_run_probe_distance
		for hit: Dictionary in _wall_run_raycast_candidates(from_point, to_point):
			if _wall_run_hit_kind(hit) != wall_run_surface_kind:
				continue
			var normal: Vector3 = hit.get("normal", Vector3.ZERO)
			if absf(normal.dot(Vector3.UP)) > 0.48:
				continue
			var flat_normal: Vector3 = Vector3(normal.x, 0.0, normal.z).normalized()
			if flat_normal.dot(wall_run_normal) < 0.55:
				continue
			var point: Vector3 = hit.get("position", from_point)
			var distance: float = from_point.distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = hit
	if best.is_empty() and wall_run_surface_kind == &"phalanx_shields":
		best = _probe_next_phalanx_shield()
	return best

func _probe_next_phalanx_shield() -> Dictionary:
	var travel: Vector3 = wall_run_last_tangent
	if travel.length() < 0.10:
		travel = _wall_tangent(Vector3(velocity.x, 0.0, velocity.z))
	if travel.length() < 0.10:
		return {}
	travel = travel.normalized()
	var best: Dictionary = {}
	var best_distance: float = INF
	# The physical aspides have small gaps between them. Probe progressively
	# ahead along the established run tangent so the next raised shield takes
	# ownership before the current one leaves the exact side ray.
	for forward_offset: float in [0.24, 0.48, 0.72, 0.96]:
		for height: float in [0.48, 1.22]:
			var from_point: Vector3 = global_position + travel * forward_offset + Vector3.UP * height
			var to_point: Vector3 = from_point - wall_run_normal * (wall_run_probe_distance + 0.18)
			var hit: Dictionary = _raycast_wall_run_layer(from_point, to_point, PHALANX_SHIELD_WALL_RUN_LAYER, true)
			if _wall_run_hit_kind(hit) != &"phalanx_shields":
				continue
			var raw_normal: Vector3 = hit.get("normal", Vector3.ZERO)
			if absf(raw_normal.dot(Vector3.UP)) > 0.48:
				continue
			var normal: Vector3 = Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()
			if normal.dot(wall_run_normal) < 0.45:
				continue
			var point: Vector3 = hit.get("position", from_point)
			var distance: float = from_point.distance_to(point) + forward_offset * 0.20
			if distance < best_distance:
				best_distance = distance
				best = hit
	return best

func _find_wall_run_surface(desired: Vector3) -> Dictionary:
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var probes: Array[Vector3] = []
	_append_wall_probe(probes, desired)
	_append_wall_probe(probes, Vector3(-desired.z, 0.0, desired.x))
	_append_wall_probe(probes, Vector3(desired.z, 0.0, -desired.x))
	if flat_velocity.length() > 0.20:
		var travel: Vector3 = flat_velocity.normalized()
		_append_wall_probe(probes, travel)
		_append_wall_probe(probes, Vector3(-travel.z, 0.0, travel.x))
		_append_wall_probe(probes, Vector3(travel.z, 0.0, -travel.x))

	var best: Dictionary = {}
	var best_score: float = INF
	for probe: Vector3 in probes:
		for height: float in [0.48, 1.22]:
			var from_point: Vector3 = global_position + Vector3.UP * height
			var to_point: Vector3 = from_point + probe * wall_run_probe_distance
			for hit: Dictionary in _wall_run_raycast_candidates(from_point, to_point):
				if _wall_run_hit_kind(hit) == StringName():
					continue
				var raw_normal: Vector3 = hit.get("normal", Vector3.ZERO)
				if absf(raw_normal.dot(Vector3.UP)) > 0.48:
					continue
				var normal: Vector3 = Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()
				if normal.length() < 0.70:
					continue
				var tangent_amount: float = (desired - normal * desired.dot(normal)).length()
				var approach: float = maxf(-desired.dot(normal), -flat_velocity.normalized().dot(normal) if flat_velocity.length() > 0.20 else 0.0)
				if tangent_amount < 0.22 and approach < 0.30:
					continue
				var point: Vector3 = hit.get("position", from_point)
				var score: float = from_point.distance_to(point) - approach * 0.14
				if score < best_score:
					best_score = score
					best = hit
	return best

func _wall_run_raycast_candidates(from_point: Vector3, to_point: Vector3) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var world_hit: Dictionary = _raycast_world(from_point, to_point)
	if not world_hit.is_empty():
		hits.append(world_hit)
	if not experimental_enemy_wall_run_enabled:
		return hits
	var enemy_hit: Dictionary = _raycast_wall_run_layer(from_point, to_point, ENEMY_BODY_COLLISION_LAYER, false)
	if not enemy_hit.is_empty():
		hits.append(enemy_hit)
	var giant_hit: Dictionary = _raycast_wall_run_layer(from_point, to_point, GIANT_TRAVERSAL_COLLISION_LAYER, false)
	if not giant_hit.is_empty():
		hits.append(giant_hit)
	var shield_hit: Dictionary = _raycast_wall_run_layer(from_point, to_point, PHALANX_SHIELD_WALL_RUN_LAYER, true)
	if not shield_hit.is_empty():
		hits.append(shield_hit)
	return hits

func _raycast_wall_run_layer(from_point: Vector3, to_point: Vector3, layer: int, collide_with_areas: bool) -> Dictionary:
	wall_run_raycast_query.from = from_point
	wall_run_raycast_query.to = to_point
	wall_run_raycast_query.collision_mask = layer
	wall_run_raycast_query.collide_with_bodies = not collide_with_areas
	wall_run_raycast_query.collide_with_areas = collide_with_areas
	return get_world_3d().direct_space_state.intersect_ray(wall_run_raycast_query)

func _wall_run_hit_kind(hit: Dictionary) -> StringName:
	if hit.is_empty():
		return StringName()
	var collider: Object = hit.get("collider") as Object
	if not (collider is Node):
		return StringName()
	var node: Node = collider as Node
	if node is CollisionObject3D and ((node as CollisionObject3D).collision_layer & 1) != 0:
		return &"world"
	if not experimental_enemy_wall_run_enabled:
		return StringName()
	if node.is_in_group("giant_wall_run_surface"):
		var owner: Object = node.get_meta("giant_owner", null) as Object
		if owner is Node and is_instance_valid(owner) and owner.has_method("is_wall_run_giant") and bool(owner.call("is_wall_run_giant")):
			return &"giant_enemy"
		return StringName()
	if node.is_in_group("wall_run_phalanx_shield") and _phalanx_shield_line_is_wall_runnable(node as Node3D):
		return &"phalanx_shields"
	if node.is_in_group("enemy") and node is Node3D:
		if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
			return StringName()
		# Forge giant archetypes opt in explicitly, even while previewed at size 1.
		# Legacy oversized enemies keep the scale fallback below.
		if node.has_method("is_wall_run_giant") and bool(node.call("is_wall_run_giant")):
			return &"giant_enemy"
		var enemy_scale: float = absf((node as Node3D).global_basis.get_scale().y)
		if enemy_scale >= experimental_enemy_wall_run_min_scale:
			return &"giant_enemy"
	return StringName()

func _wall_run_surface_allows_parkour() -> bool:
	# Dynamic combatants are wall-run anchors only. Mantling one would teleport
	# the player with a landing point sampled from moving anatomy/equipment.
	return wall_run_surface_kind == &"world"

func _phalanx_shield_line_is_wall_runnable(candidate: Node3D) -> bool:
	if candidate == null or not candidate.is_in_group("wall_run_phalanx_shield"):
		return false
	if candidate is CollisionObject3D and (((candidate as CollisionObject3D).collision_layer & PHALANX_SHIELD_WALL_RUN_LAYER) == 0):
		return false
	var neighbors: int = 0
	for raw_node: Node in get_tree().get_nodes_in_group("wall_run_phalanx_shield"):
		if not (raw_node is Node3D) or not is_instance_valid(raw_node):
			continue
		var shield: Node3D = raw_node as Node3D
		if shield is CollisionObject3D and (((shield as CollisionObject3D).collision_layer & PHALANX_SHIELD_WALL_RUN_LAYER) == 0):
			continue
		if absf(shield.global_position.y - candidate.global_position.y) > 0.70:
			continue
		var flat_offset: Vector2 = Vector2(shield.global_position.x - candidate.global_position.x, shield.global_position.z - candidate.global_position.z)
		if flat_offset.length() <= experimental_phalanx_shield_neighbor_radius:
			neighbors += 1
	return neighbors >= experimental_phalanx_shield_min_count

func _dynamic_wall_run_surface_blocks_parkour(direction: Vector3) -> bool:
	if not experimental_enemy_wall_run_enabled:
		return false
	for height: float in [0.58, 1.12]:
		var from_point: Vector3 = global_position + Vector3.UP * height
		var to_point: Vector3 = from_point + direction * parkour_probe_distance
		for hit: Dictionary in _wall_run_raycast_candidates(from_point, to_point):
			var kind: StringName = _wall_run_hit_kind(hit)
			if kind == &"giant_enemy" or kind == &"phalanx_shields":
				return true
	return false

func _append_wall_probe(probes: Array[Vector3], direction: Vector3) -> void:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.05:
		return
	flat = flat.normalized()
	for existing: Vector3 in probes:
		if existing.dot(flat) > 0.985:
			return
	probes.append(flat)

func _try_start_parkour(direction_override: Vector3 = Vector3.ZERO, force_climb: bool = false) -> bool:
	if skills != null and not skills.active(&"parkour"): return false
	if get_world_3d() == null:
		parkour_debug_reason = "no world"
		return false

	var direction: Vector3 = direction_override if direction_override.length() > 0.05 else _desired_move_direction()
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if direction.length() < 0.05 and flat_velocity.length() > 0.20:
		direction = flat_velocity.normalized()
	if direction.length() < 0.05:
		direction = _camera_forward_flat()
	direction.y = 0.0
	direction = direction.normalized()
	# Do not ray through an eligible moving combat surface and mantle scenery
	# hidden behind it. The jump remains available to start the enemy wall run on
	# the same frame.
	if _dynamic_wall_run_surface_blocks_parkour(direction):
		parkour_debug_reason = "dynamic wall-run surface blocks mantle"
		return false

	var wall_hit: Dictionary = _find_parkour_wall(direction)
	if wall_hit.is_empty():
		parkour_debug_reason = "no wall in probe"
		return false

	var wall_normal: Vector3 = wall_hit.get("normal", Vector3.ZERO)
	if absf(wall_normal.dot(Vector3.UP)) > 0.55:
		parkour_debug_reason = "surface is not a wall"
		return false

	var wall_point: Vector3 = wall_hit.get("position", global_position + direction * parkour_probe_distance)
	var top_info: Dictionary = _find_parkour_top(wall_point, direction)
	if top_info.is_empty():
		parkour_debug_reason = "top surface not found"
		return false

	var top_point: Vector3 = top_info.get("point", Vector3.ZERO)
	var top_depth: float = float(top_info.get("depth", 0.25))
	var obstacle_height: float = top_point.y - global_position.y
	if obstacle_height < parkour_min_height or obstacle_height > parkour_max_height:
		parkour_debug_reason = "height %.2f outside %.2f..%.2f" % [obstacle_height, parkour_min_height, parkour_max_height]
		return false

	var extent: Dictionary = _find_parkour_top_extent(wall_point, direction, top_point.y, top_depth)
	var last_top_depth: float = float(extent.get("last_depth", top_depth))
	var edge_depth: float = float(extent.get("edge_depth", last_top_depth + 0.25))

	if obstacle_height <= parkour_vault_max_height and not force_climb:
		var landing: Vector3 = _find_vault_landing(wall_point, direction, edge_depth, top_point.y)
		if landing == Vector3.ZERO:
			parkour_debug_reason = "no safe landing behind vault"
			return false
		var travel_distance: float = Vector2(landing.x - global_position.x, landing.z - global_position.z).length()
		var vault_duration: float = clampf(travel_distance / maxf(max_speed * 1.25, 0.1), 0.34, 0.58)
		var vault_arc: float = maxf(0.58, obstacle_height + 0.30)
		_begin_parkour(&"vault", landing, vault_duration, vault_arc, direction)
		parkour_debug_reason = "vault %.2fm" % obstacle_height
	else:
		var usable_depth: float = maxf(top_depth, last_top_depth - 0.18)
		var mantle_depth: float = minf(top_depth + 0.55, usable_depth)
		var climb_end: Vector3 = wall_point + direction * mantle_depth
		climb_end.y = top_point.y + 0.055
		if not _parkour_has_headroom(climb_end):
			parkour_debug_reason = "mantle blocked above"
			return false
		var climb_duration: float = remap(clampf(obstacle_height, parkour_vault_max_height, parkour_max_height), parkour_vault_max_height, parkour_max_height, 0.52, 0.88)
		_begin_parkour(&"climb", climb_end, climb_duration, 0.18, direction)
		parkour_debug_reason = "mantle %.2fm" % obstacle_height
	return true

func _find_parkour_wall(direction: Vector3) -> Dictionary:
	var best_hit: Dictionary = {}
	var best_distance: float = INF
	var probe_heights: Array[float] = [0.32, 0.58, 0.86, 1.12]
	for height: float in probe_heights:
		var from_point: Vector3 = global_position + Vector3.UP * height
		var hit: Dictionary = _raycast_world(from_point, from_point + direction * parkour_probe_distance)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if absf(normal.dot(Vector3.UP)) > 0.62:
			continue
		var hit_point: Vector3 = hit.get("position", from_point + direction * parkour_probe_distance)
		var distance: float = global_position.distance_to(hit_point)
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit

func _find_parkour_top(wall_point: Vector3, direction: Vector3) -> Dictionary:
	var depths: Array[float] = [0.10, 0.22, 0.36, 0.52, 0.72, 0.96, 1.24]
	for depth: float in depths:
		var sample: Vector3 = wall_point + direction * depth
		var from_point: Vector3 = Vector3(sample.x, global_position.y + parkour_max_height + 0.70, sample.z)
		var to_point: Vector3 = Vector3(sample.x, global_position.y + parkour_min_height - 0.10, sample.z)
		var hit: Dictionary = _raycast_world(from_point, to_point)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if normal.dot(Vector3.UP) < 0.68:
			continue
		var point: Vector3 = hit.get("position", Vector3.ZERO)
		var height: float = point.y - global_position.y
		if height >= parkour_min_height and height <= parkour_max_height:
			return {"point": point, "depth": depth}
	return {}

func _find_parkour_top_extent(wall_point: Vector3, direction: Vector3, top_y: float, start_depth: float) -> Dictionary:
	var last_depth: float = start_depth
	var edge_depth: float = start_depth + 0.30
	var step: float = 0.20
	var max_depth: float = 3.20
	var depth: float = start_depth + step

	while depth <= max_depth:
		var sample: Vector3 = wall_point + direction * depth
		var from_point: Vector3 = Vector3(sample.x, top_y + 0.42, sample.z)
		var to_point: Vector3 = Vector3(sample.x, top_y - 0.34, sample.z)
		var hit: Dictionary = _raycast_world(from_point, to_point)
		var same_top: bool = false
		if not hit.is_empty():
			var normal: Vector3 = hit.get("normal", Vector3.ZERO)
			var point: Vector3 = hit.get("position", Vector3.ZERO)
			same_top = normal.dot(Vector3.UP) >= 0.68 and absf(point.y - top_y) <= 0.22
		if not same_top:
			edge_depth = depth
			break
		last_depth = depth
		edge_depth = depth + step
		depth += step

	return {"last_depth": last_depth, "edge_depth": edge_depth}

func _find_vault_landing(wall_point: Vector3, direction: Vector3, edge_depth: float, top_y: float) -> Vector3:
	var extras: Array[float] = [0.42, 0.68, 0.94, 1.20]
	for extra: float in extras:
		var sample: Vector3 = wall_point + direction * (edge_depth + extra)
		var from_point: Vector3 = Vector3(sample.x, top_y + 1.35, sample.z)
		var to_point: Vector3 = Vector3(sample.x, global_position.y - 1.60, sample.z)
		var hit: Dictionary = _raycast_world(from_point, to_point)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var point: Vector3 = hit.get("position", Vector3.ZERO)
		if normal.dot(Vector3.UP) >= 0.68 and point.y <= top_y - 0.18:
			return point + Vector3.UP * 0.055
	return Vector3.ZERO

func _parkour_has_headroom(end_position: Vector3) -> bool:
	var from_point: Vector3 = end_position + Vector3.UP * 0.18
	var to_point: Vector3 = end_position + Vector3.UP * 1.90
	return _raycast_world(from_point, to_point).is_empty()

func _queue_slide_after_parkour() -> void:
	if not parkour_active or parkour_slide_queued or slide_charges <= 0:
		return

	parkour_slide_queued = true

	var requested_direction: Vector3 = _desired_move_direction()
	if requested_direction.length() > 0.05:
		slide_direction = requested_direction
	elif parkour_exit_direction.length() > 0.05:
		slide_direction = parkour_exit_direction
	else:
		slide_direction = _camera_forward_flat()

	parkour_debug_reason = "slide buffered"

func _begin_parkour(kind: StringName, end_position: Vector3, duration: float, arc: float, direction: Vector3) -> void:
	# Parkour is the one movement state that intentionally breaks a heavy charge.
	# Do it only after a valid vault/mantle has actually been accepted.
	parkour_started_from_wall_run = wall_run_active
	if animation_driver != null:
		animation_driver.clear_wall_release_air_pose()
	if wall_run_active:
		wall_run_active = false
		wall_run_mode = StringName()
		wall_run_attach_available = false
		wall_run_just_started = false
		_sync_wall_run_feedback()
		if animation_driver != null:
			animation_driver.stop_wall_run_visual()
	_cancel_heavy_charge()
	_reset_primary_attack_input()
	_set_shield_blocking(false)
	_stop_slide(false, false)
	dash_time = 0.0
	dash_variant_grace = 0.0
	parkour_active = true
	parkour_kind = kind
	parkour_elapsed = 0.0
	parkour_duration = maxf(duration, 0.2)
	parkour_start = global_position
	parkour_end = end_position
	parkour_arc = arc
	parkour_exit_direction = direction.normalized()
	parkour_slide_queued = false
	velocity = Vector3.ZERO
	if animation_driver != null:
		animation_driver.stop_full_body()
		if not animation_driver.play_donor_action(kind, 1.08):
			animation_driver.play_full_body(&"jump")

func _update_parkour(delta: float) -> void:
	parkour_elapsed += delta
	var t: float = clampf(parkour_elapsed / parkour_duration, 0.0, 1.0)

	if parkour_kind == &"climb":
		# Mantle rises early and translates over the lip later. This reads like a
		# pull-up instead of interpolating straight through the obstacle.
		var lift_t: float = smoothstep(0.0, 0.70, t)
		var forward_t: float = smoothstep(0.12, 1.0, t)
		var p: Vector3 = parkour_start
		p.x = lerpf(parkour_start.x, parkour_end.x, forward_t)
		p.z = lerpf(parkour_start.z, parkour_end.z, forward_t)
		p.y = lerpf(parkour_start.y, parkour_end.y, lift_t) + sin(t * PI) * parkour_arc
		global_position = p
	else:
		var eased: float = smoothstep(0.0, 1.0, t)
		var base: Vector3 = parkour_start.lerp(parkour_end, eased)
		global_position = base + Vector3.UP * (sin(t * PI) * parkour_arc)

	if parkour_exit_direction.length() > 0.05:
		_face_direction(parkour_exit_direction, delta * 2.8)

	# A buffered slide should feel like a direct movement combo, not mantle ->
	# pause -> slide. For climbs, once ~80% of the mantle is complete the body is
	# already over the lip, so finish the last few centimetres immediately and
	# give control to the slide. Vaults keep almost their complete authored arc.
	var slide_exit_progress: float = parkour_slide_early_exit_progress if parkour_kind == &"climb" else 0.96
	if parkour_slide_queued and t >= slide_exit_progress:
		global_position = parkour_end
		parkour_debug_reason = "early exit -> buffered slide"
		_finish_parkour()
		return

	if t >= 1.0:
		_finish_parkour()

func _finish_parkour() -> void:
	# End parkour with NO inherited forward impulse. No input after a climb means
	# the player stays exactly on the ledge.
	var rearm_wall_run: bool = parkour_started_from_wall_run
	parkour_started_from_wall_run = false
	parkour_active = false
	parkour_kind = StringName()
	jumps_used = 0
	velocity = Vector3.ZERO
	if rearm_wall_run:
		_reset_wall_run_after_landing()
		wall_run_debug_reason = "parkour exit -> rearmed"

	# Stop the retargeted parkour donor immediately as well. Otherwise the
	# authored clip can visually keep taking a final step after mechanics stop.
	if animation_driver != null:
		animation_driver.stop_movement_action()

	var queued_slide: bool = parkour_slide_queued
	parkour_slide_queued = false

	if queued_slide:
		# CTRL during the climb is a combo buffer. Prefer the direction currently
		# held by the player; otherwise continue over the climbed lip.
		var requested_direction: Vector3 = _desired_move_direction()
		if requested_direction.length() > 0.05:
			slide_direction = requested_direction
		elif parkour_exit_direction.length() > 0.05:
			slide_direction = parkour_exit_direction
		else:
			slide_direction = _camera_forward_flat()
		parkour_debug_reason = "exit -> buffered slide"
		_start_slide(false)
	else:
		# Normal exit deliberately remains still. On the next physics frame the
		# regular locomotion code reads live input; no input means no movement.
		parkour_debug_reason = "exit -> player control"

func _raycast_world(from_point: Vector3, to_point: Vector3) -> Dictionary:
	world_raycast_query.from = from_point
	world_raycast_query.to = to_point
	return get_world_3d().direct_space_state.intersect_ray(world_raycast_query)

func _set_sword_charge_visual(ratio: float) -> void:
	if sword_blade_material == null:
		return
	var t: float = clampf(ratio, 0.0, 1.0)
	var charged_color := Color(1.0, 0.015, 0.005)
	var emission_strength: float = t * 1.65
	if t >= 0.999:
		# An unmistakable but local pulse marks the charge cap. It remains on the
		# blade and never flashes the whole scene.
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
		charged_color = Color(1.0, 0.16 + pulse * 0.14, 0.015)
		emission_strength = 1.85 + pulse * 0.75
	sword_blade_material.albedo_color = sword_base_color.lerp(charged_color, t)
	sword_blade_material.emission_enabled = t > 0.01
	sword_blade_material.emission = charged_color * emission_strength

func _desired_move_direction() -> Vector3:
	if skills != null and skills.controls.wheel.visible: return Vector3.ZERO
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward: Vector3 = _camera_forward_flat()
	var right: Vector3 = _camera_right_flat()
	var result: Vector3 = right * input_vec.x + forward * -input_vec.y
	return result.normalized() if result.length() > 0.001 else Vector3.ZERO

func _attack_input_facing_direction() -> Vector3:
	var camera_forward: Vector3 = _camera_forward_flat()
	var move_direction: Vector3 = _desired_move_direction()
	# Backward attacks retain the character's current orientation instead of
	# snapping toward the top of the screen/camera forward axis.
	if move_direction.length() > 0.05 and move_direction.dot(camera_forward) < -0.25:
		var current_forward: Vector3 = -global_basis.z
		current_forward.y = 0.0
		return current_forward.normalized()
	return camera_forward

func _camera_forward_flat() -> Vector3:
	if camera_yaw == null:
		return -global_basis.z.normalized()
	var forward: Vector3 = -camera_yaw.global_basis.z
	forward.y = 0.0
	return forward.normalized()

func _camera_right_flat() -> Vector3:
	if camera_yaw == null:
		return global_basis.x.normalized()
	var right: Vector3 = camera_yaw.global_basis.x
	right.y = 0.0
	return right.normalized()

func _face_direction(direction: Vector3, delta_or_amount: float) -> void:
	var flat: Vector3 = direction
	flat.y = 0.0
	if flat.length() < 0.001:
		return
	var target_yaw: float = atan2(-flat.x, -flat.z)
	var amount: float = 1.0 - exp(-turn_speed * maxf(delta_or_amount, 0.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, amount)

func _update_camera(delta: float) -> void:
	if camera_yaw == null or spring_arm == null or camera == null:
		return
	# CombatFeedback owns the cinematic envelope and orientation blend. Player
	# owns the collision-aware rig translation, so lowering the pivot and moving
	# the SpringArm never bypasses camera collision.
	_sync_wall_run_feedback()
	var epic_run_camera_active: bool = _epic_wall_run_camera_guidance_active()
	var epic_camera_strength: float = combat_feedback.epic_camera_blend_strength() if epic_run_camera_active else 0.0
	var epic_camera_response: float = combat_feedback.epic_camera_follow_response() if epic_run_camera_active else 8.0
	var epic_camera_motion_response: float = epic_camera_response * maxf(0.08, epic_camera_strength) if epic_run_camera_active else epic_camera_response
	var camera_delta: float = delta
	if epic_run_camera_active:
		camera_delta = clampf(delta / maxf(Engine.time_scale, 0.001), 0.0, 0.05)
	var focused_pivot_height: float = camera_pivot_height
	var focused_camera_distance: float = camera_distance
	if combat_feedback != null:
		focused_pivot_height = combat_feedback.epic_camera_focus_height(camera_pivot_height)
		focused_camera_distance = combat_feedback.epic_camera_distance(camera_distance)
	var target: Vector3 = global_position + Vector3(0.0, focused_pivot_height, 0.0)

	# Horizontal lag made dash/attack speed spikes look like the character was
	# shooting away from the screen centre and then snapping back afterward.
	camera_yaw.global_position.x = target.x
	camera_yaw.global_position.z = target.z
	camera_yaw.global_position.y = lerpf(
		camera_yaw.global_position.y,
		target.y,
		1.0 - exp(-epic_camera_response * camera_delta)
	)

	# During an enemy wall run the camera looks along the run direction. Since the
	# SpringArm camera sits on +Z, aligning its -Z forward vector with travel puts
	# it on the opposite side: a run to the right therefore places it to the left.
	var wall_run_camera_direction: Vector3 = _epic_wall_run_camera_direction()
	if wall_run_camera_direction.length_squared() > 0.01:
		var chase_yaw: float = atan2(-wall_run_camera_direction.x, -wall_run_camera_direction.z)
		camera_yaw.rotation.y = lerp_angle(
			camera_yaw.rotation.y,
			chase_yaw,
			1.0 - exp(-epic_camera_motion_response * camera_delta)
		)
	else:
		# Free camera by default. Only an actively assisted epic enemy may guide the
		# horizontal framing, and even then the correction remains deliberately smooth.
		var epic_target: Node3D = _active_epic_focus_target()
		if epic_target != null:
			var toward_epic: Vector3 = epic_target.global_position - global_position
			toward_epic.y = 0.0
			if toward_epic.length() > 0.05:
				var epic_yaw: float = atan2(-toward_epic.x, -toward_epic.z)
				camera_yaw.rotation.y = lerp_angle(camera_yaw.rotation.y, epic_yaw, 1.0 - exp(-2.4 * camera_delta))

	# Flattening the SpringArm while its pivot descends makes the camera itself
	# travel toward foot height. CombatFeedback then supplies the upward viewing
	# angle; the user's saved pitch is only restored after the cinematic releases.
	var guided_pitch: float = lerpf(camera_pitch_value, 0.0, epic_camera_strength) if epic_run_camera_active else camera_pitch_value
	camera_pitch.rotation.x = lerp_angle(
		camera_pitch.rotation.x,
		guided_pitch,
		1.0 - exp(-epic_camera_motion_response * camera_delta)
	)

	# CombatFeedback is the single owner of Camera3D offsets/FOV/rotation. It
	# composes ordinary wall-run motion with parries, executions and the distinct
	# giant/shield adrenaline profiles without competing property writers.
	camera.position.y = lerpf(camera.position.y, 0.0, 1.0 - exp(-13.0 * camera_delta))
	spring_arm.spring_length = lerpf(spring_arm.spring_length, focused_camera_distance, 1.0 - exp(-epic_camera_response * camera_delta))
	spring_arm.position.x = lerpf(spring_arm.position.x, camera_shoulder_offset, 1.0 - exp(-9.0 * camera_delta))
	if skills != null and skills.cinema != null: skills.cinema.apply_rig()

func _sync_wall_run_feedback() -> void:
	if combat_feedback == null:
		return
	combat_feedback.set_wall_run_state(wall_run_active, wall_run_surface_kind, wall_run_mode, _wall_run_camera_side())

func _wall_run_camera_side() -> float:
	if not wall_run_active or wall_run_mode == &"vertical" or wall_run_last_tangent.length() < 0.10:
		return 0.0
	var travel: Vector3 = wall_run_last_tangent.normalized()
	var travel_right: Vector3 = Vector3(-travel.z, 0.0, travel.x)
	return signf(wall_run_normal.dot(travel_right))

func _epic_wall_run_camera_guidance_active() -> bool:
	return combat_feedback != null and combat_feedback.is_epic_wall_run_active()

func _epic_wall_run_camera_direction() -> Vector3:
	if not wall_run_active or not _epic_wall_run_camera_guidance_active():
		return Vector3.ZERO
	var travel: Vector3 = wall_run_last_tangent
	if wall_run_mode == &"vertical" or travel.length_squared() < 0.01:
		travel = -global_basis.z
	travel.y = 0.0
	if travel.length_squared() < 0.01:
		return Vector3.ZERO
	return travel.normalized()

func _active_epic_focus_target() -> Node3D:
	if attack_assist_target == null or not is_instance_valid(attack_assist_target):
		return null
	if attack_assist_lock_remaining <= 0.0 or not attack_assist_target.is_in_group("enemy_epic"):
		return null
	return attack_assist_target

func get_camera_mode_labels() -> Array[String]:
	return ["TPS GLOBAL"]

func get_camera_mode() -> int:
	return camera_mode

func get_camera_distance() -> float:
	return camera_distance

func get_epic_wall_run_camera_setting_definitions() -> Array[Dictionary]:
	return EPIC_RUN_CAMERA_SETTING_DEFINITIONS

func get_epic_wall_run_camera_setting(id: StringName) -> float:
	return float(epic_wall_run_camera_settings.get(id, _epic_wall_run_camera_setting_default(id)))

func set_epic_wall_run_camera_setting(id: StringName, value: float, persist: bool = true) -> void:
	var definition: Dictionary = _epic_wall_run_camera_setting_definition(id)
	if definition.is_empty():
		return
	epic_wall_run_camera_settings[id] = clampf(value, float(definition["min"]), float(definition["max"]))
	if combat_feedback != null:
		combat_feedback.configure_epic_wall_run_settings(epic_wall_run_camera_settings)
	if persist:
		_save_camera_settings()

func set_camera_mode(_value: int, use_preset_distance: bool = true) -> void:
	camera_mode = 0
	_apply_camera_mode_profile(use_preset_distance)
	recenter_camera_tps()
	_save_camera_settings()

func set_camera_distance(value: float, persist: bool = true) -> void:
	camera_distance = clampf(value, CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)
	if persist:
		_save_camera_settings()

func save_camera_settings() -> void:
	_save_camera_settings()

func reset_camera_tps() -> void:
	camera_mode = 0
	_apply_camera_mode_profile(true)
	_reset_epic_wall_run_camera_settings()
	if combat_feedback != null:
		combat_feedback.configure_epic_wall_run_settings(epic_wall_run_camera_settings)
	recenter_camera_tps()
	_save_camera_settings()

func recenter_camera_tps() -> void:
	if camera_yaw != null:
		camera_yaw.rotation.y = rotation.y
	camera_pitch_value = camera_rest_pitch
	if camera_pitch != null:
		camera_pitch.rotation.x = camera_pitch_value

func _apply_camera_mode_profile(use_preset_distance: bool) -> void:
	camera_mode = 0
	camera_pivot_height = 1.68
	camera_shoulder_offset = 0.0
	camera_rest_pitch = -0.20
	if use_preset_distance:
		camera_distance = 3.5

func _load_camera_settings() -> void:
	_reset_epic_wall_run_camera_settings()
	var config := ConfigFile.new()
	if config.load(CAMERA_SETTINGS_PATH) == OK:
		camera_distance = clampf(float(config.get_value("camera", "distance", camera_distance)), CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)
		for definition: Dictionary in EPIC_RUN_CAMERA_SETTING_DEFINITIONS:
			var id := StringName(definition["id"])
			epic_wall_run_camera_settings[id] = clampf(
				float(config.get_value("epic_wall_run", String(id), definition["default"])),
				float(definition["min"]),
				float(definition["max"])
			)
	camera_mode = 0
	_apply_camera_mode_profile(false)
	camera_pitch_value = camera_rest_pitch

func _save_camera_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "mode", camera_mode)
	config.set_value("camera", "distance", camera_distance)
	for definition: Dictionary in EPIC_RUN_CAMERA_SETTING_DEFINITIONS:
		var id := StringName(definition["id"])
		config.set_value("epic_wall_run", String(id), get_epic_wall_run_camera_setting(id))
	var error: Error = config.save(CAMERA_SETTINGS_PATH)
	if error != OK:
		push_warning("[CAMERA] Could not save settings: %s" % error_string(error))

func _reset_epic_wall_run_camera_settings() -> void:
	epic_wall_run_camera_settings.clear()
	for definition: Dictionary in EPIC_RUN_CAMERA_SETTING_DEFINITIONS:
		epic_wall_run_camera_settings[StringName(definition["id"])] = float(definition["default"])

func _epic_wall_run_camera_setting_definition(id: StringName) -> Dictionary:
	for definition: Dictionary in EPIC_RUN_CAMERA_SETTING_DEFINITIONS:
		if StringName(definition["id"]) == id:
			return definition
	return {}

func _epic_wall_run_camera_setting_default(id: StringName) -> float:
	var definition: Dictionary = _epic_wall_run_camera_setting_definition(id)
	return float(definition.get("default", 0.0))

func _build_weapons() -> void:
	if right_hand_bone != "":
		sword_attachment = BoneAttachment3D.new()
		sword_attachment.name = "SwordAttachment"
		sword_attachment.bone_name = right_hand_bone
		skeleton.add_child(sword_attachment)
		sword_root = _make_sword()
		sword_attachment.add_child(sword_root)
		sword_trail = TrailScript.new() as HopliteNativeSwordTrail
		sword_trail.name = "SwordTrail"
		get_tree().current_scene.add_child(sword_trail)
	if left_hand_bone != "":
		shield_attachment = BoneAttachment3D.new()
		shield_attachment.name = "ShieldAttachment"
		shield_attachment.bone_name = left_hand_bone
		skeleton.add_child(shield_attachment)
		shield_root = _make_shield()
		shield_attachment.add_child(shield_root)
		shield_rest_transform = shield_root.transform

func _set_shield_guard_visual_enabled(enabled: bool) -> void:
	if shield_root == null:
		return
	if enabled:
		# Keep the shield parented to the wrist so running/turning animations move it.
		# Only its orientation is corrected globally by _update_shield_guard_visual().
		shield_root.top_level = false
		_update_shield_guard_visual()
	else:
		shield_root.top_level = false
		shield_root.transform = shield_rest_transform

func _update_shield_guard_visual() -> void:
	if not shield_blocking or shield_root == null:
		return
	# Preserve the imported hand-space offset exactly: the attachment owns the
	# shield position while the player runs, jumps and turns.
	shield_root.position = shield_rest_transform.origin
	# Imported shield fronts point along local +Z. During guard, face that axis in
	# the player's forward direction while keeping local +Y vertical.
	var player_basis := Basis(Vector3.UP, rotation.y).orthonormalized()
	var guard_orientation := Basis(-player_basis.x, player_basis.y, -player_basis.z)
	var authored_scale := shield_rest_transform.basis.get_scale()
	shield_root.global_basis = guard_orientation.scaled(authored_scale)

func _make_sword() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Weapon_%s" % String(equipped_weapon.item_id)
	current_weapon_tuning = WeaponTuningScript.load_values(equipped_weapon)
	sword_blade_material = null
	if equipped_weapon.visual_scene == null:
		push_error("[PLAYER EQUIPMENT] Weapon %s has no visual scene" % String(equipped_weapon.item_id))
		return root
	var imported_visual: Node = equipped_weapon.visual_scene.instantiate()
	imported_visual.name = "ImportedWeaponVisual"
	root.add_child(imported_visual)
	var weapon_mesh: MeshInstance3D = _find_equipment_mesh(imported_visual, equipped_weapon.visual_mesh_name)
	if weapon_mesh == null:
		push_error("[PLAYER EQUIPMENT] Weapon %s has no %s mesh" % [equipped_weapon.item_id, equipped_weapon.visual_mesh_name])
	else:
		_configure_weapon_blade_material(weapon_mesh, equipped_weapon.blade_material_name)
	sword_base = Marker3D.new()
	sword_base.name = "SwordBladeBase"
	sword_base.position = Vector3(0.0, float(current_weapon_tuning[&"blade_base"]), 0.0)
	root.add_child(sword_base)
	sword_tip = Marker3D.new()
	sword_tip.name = "SwordBladeTip"
	sword_tip.position = Vector3(0.0, float(current_weapon_tuning[&"blade_tip"]), 0.0)
	root.add_child(sword_tip)
	weapon_hit_radius = float(current_weapon_tuning[&"hit_radius"])
	weapon_damage_multiplier = float(current_weapon_tuning[&"damage_multiplier"])
	root.position = WeaponTuningScript.hand_position(current_weapon_tuning)
	root.rotation_degrees = WeaponTuningScript.hand_rotation_degrees(current_weapon_tuning)
	root.scale = equipped_weapon.hand_scale * float(current_weapon_tuning[&"scale"])
	_apply_sword_preset(root)
	return root

func _configure_weapon_blade_material(weapon_mesh: MeshInstance3D, material_hint: StringName) -> void:
	# Localize the mesh resource before replacing one surface. Surface overrides on
	# a queued imported GLB can leave Godot's dummy/headless renderer querying a
	# material after its override RID has been released during equipment swaps.
	weapon_mesh.mesh = weapon_mesh.mesh.duplicate() as Mesh
	var steel_surface: int = -1
	for surface_index: int in range(weapon_mesh.mesh.get_surface_count()):
		var material: Material = weapon_mesh.mesh.surface_get_material(surface_index)
		if material != null and String(material_hint) in material.resource_name:
			steel_surface = surface_index
			break
	if steel_surface < 0:
		push_error("[PLAYER EQUIPMENT] Weapon %s has no %s surface" % [equipped_weapon.item_id, material_hint])
		return
	var imported_steel: StandardMaterial3D = weapon_mesh.mesh.surface_get_material(steel_surface) as StandardMaterial3D
	if imported_steel == null:
		push_error("[PLAYER EQUIPMENT] %s must use StandardMaterial3D" % material_hint)
		return
	sword_blade_material = imported_steel.duplicate() as StandardMaterial3D
	sword_blade_material.resource_local_to_scene = true
	sword_base_color = sword_blade_material.albedo_color
	weapon_mesh.mesh.surface_set_material(steel_surface, sword_blade_material)

func _make_shield() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Shield_%s" % String(equipped_shield.item_id)
	if equipped_shield.visual_scene == null:
		push_error("[PLAYER EQUIPMENT] Shield %s has no visual scene" % String(equipped_shield.item_id))
		return root
	var imported_visual: Node = equipped_shield.visual_scene.instantiate()
	imported_visual.name = "ImportedShieldVisual"
	root.add_child(imported_visual)
	if _find_equipment_mesh(imported_visual, equipped_shield.visual_mesh_name) == null:
		push_error("[PLAYER EQUIPMENT] Shield %s has no %s mesh" % [equipped_shield.item_id, equipped_shield.visual_mesh_name])
	root.position = equipped_shield.hand_position
	root.rotation_degrees = equipped_shield.hand_rotation_degrees
	root.scale = equipped_shield.hand_scale
	return root

func _find_equipment_mesh(visual: Node, expected_name: StringName) -> MeshInstance3D:
	if visual is MeshInstance3D and (expected_name == &"" or visual.name == expected_name):
		return visual as MeshInstance3D
	if expected_name != &"":
		var exact: MeshInstance3D = visual.find_child(String(expected_name), true, false) as MeshInstance3D
		if exact != null:
			return exact
	var fallback_meshes: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
	return fallback_meshes.front() as MeshInstance3D if not fallback_meshes.is_empty() else null

func equip_item(item: HopliteEquipmentItemData) -> bool:
	if not can_equip_item(item):
		return false
	match item.slot:
		HopliteEquipmentItemData.Slot.WEAPON:
			equipped_weapon = item
			_rebuild_equipped_weapon()
		HopliteEquipmentItemData.Slot.SHIELD:
			equipped_shield = item
			_rebuild_equipped_shield()
		_:
			return false
	equipment_changed.emit(item.slot, item)
	return true

func equipped_item_for_slot(slot: HopliteEquipmentItemData.Slot) -> HopliteEquipmentItemData:
	return equipped_weapon if slot == HopliteEquipmentItemData.Slot.WEAPON else equipped_shield

func refresh_weapon_tuning(item_id: StringName) -> void:
	if equipped_weapon != null and equipped_weapon.item_id == item_id:
		current_weapon_tuning = WeaponTuningScript.load_values(equipped_weapon)
		if sword_root != null and sword_base != null and sword_tip != null:
			sword_base.position.y = float(current_weapon_tuning[&"blade_base"])
			sword_tip.position.y = float(current_weapon_tuning[&"blade_tip"])
			weapon_hit_radius = float(current_weapon_tuning[&"hit_radius"])
			weapon_damage_multiplier = float(current_weapon_tuning[&"damage_multiplier"])
			_apply_sword_preset(sword_root)
			previous_sword_base_position = sword_base.global_position
			previous_sword_tip_position = sword_tip.global_position
	for candidate: Node in get_tree().get_nodes_in_group(&"equipment_pickup"):
		if candidate.has_method("refresh_tuning_visual"):
			candidate.call("refresh_tuning_visual", item_id)

func can_equip_item(item: HopliteEquipmentItemData) -> bool:
	if item == null or _equipment_swap_locked():
		return false
	match item.slot:
		HopliteEquipmentItemData.Slot.WEAPON:
			return sword_attachment != null and item.has_valid_weapon_contact() and (equipped_weapon == null or equipped_weapon.item_id != item.item_id)
		HopliteEquipmentItemData.Slot.SHIELD:
			return shield_attachment != null and (equipped_shield == null or equipped_shield.item_id != item.item_id)
	return false

func _equipment_swap_locked() -> bool:
	return heavy_charging or primary_attack_held or shield_blocking or (animation_driver != null and animation_driver.is_attack_active())

func _rebuild_equipped_weapon() -> void:
	weapon_swing_active = false
	weapon_hit_targets.clear()
	if sword_root != null and is_instance_valid(sword_root):
		sword_root.queue_free()
	sword_root = _make_sword()
	sword_attachment.add_child(sword_root)
	previous_sword_base_position = sword_base.global_position
	previous_sword_tip_position = sword_tip.global_position

func _rebuild_equipped_shield() -> void:
	if shield_root != null and is_instance_valid(shield_root):
		shield_root.queue_free()
	shield_root = _make_shield()
	shield_attachment.add_child(shield_root)
	shield_rest_transform = shield_root.transform
	shield_attachment.visible = shield_visible

func register_equipment_pickup(pickup: Area3D) -> void:
	if pickup != null and not pickup in nearby_equipment_pickups:
		nearby_equipment_pickups.append(pickup)

func unregister_equipment_pickup(pickup: Area3D) -> void:
	nearby_equipment_pickups.erase(pickup)

func _collect_nearest_equipment_pickup() -> bool:
	var nearest := nearest_equipment_pickup(true)
	if nearest == null or not nearest.has_method("collect_by"):
		return false
	return bool(nearest.call("collect_by", self))

func nearest_equipment_pickup(include_fresh_forge_pickups: bool = false) -> Area3D:
	# The group scan makes a freshly spawned Forge pickup usable on the very first
	# E press, even before Area3D emits body_entered on the next physics tick.
	if include_fresh_forge_pickups:
		for candidate: Node in get_tree().get_nodes_in_group(&"equipment_pickup"):
			if candidate is Area3D and not candidate in nearby_equipment_pickups:
				nearby_equipment_pickups.append(candidate as Area3D)
	var nearest: Area3D = null
	var nearest_distance_squared: float = INF
	for index: int in range(nearby_equipment_pickups.size() - 1, -1, -1):
		var pickup: Area3D = nearby_equipment_pickups[index]
		if not is_instance_valid(pickup):
			nearby_equipment_pickups.remove_at(index)
			continue
		if pickup.has_method("can_be_collected_by") and not bool(pickup.call("can_be_collected_by", self)):
			continue
		var distance_squared: float = global_position.distance_squared_to(pickup.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = pickup
			nearest_distance_squared = distance_squared
	return nearest

func equipment_pickup_prompt() -> String:
	var pickup := nearest_equipment_pickup()
	if pickup == null:
		return ""
	return String(pickup.call("interaction_label")) if pickup.has_method("interaction_label") else "Équipement"

func _cycle_sword_preset() -> void:
	sword_preset = (sword_preset + 1) % 6
	if sword_root != null:
		_apply_sword_preset(sword_root)

func _apply_sword_preset(root: Node3D) -> void:
	var rotations: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(0, 0, -90),
		Vector3(90, 0, 0),
		Vector3(-90, 0, 0),
		Vector3(0, 90, 0),
		Vector3(0, -90, 90)
	]
	if current_weapon_tuning.is_empty():
		current_weapon_tuning = WeaponTuningScript.load_values(equipped_weapon)
	root.rotation_degrees = WeaponTuningScript.hand_rotation_degrees(current_weapon_tuning) + rotations[sword_preset]
	root.position = WeaponTuningScript.hand_position(current_weapon_tuning)
	root.scale = equipped_weapon.hand_scale * float(current_weapon_tuning[&"scale"])

func _find_hand_bone(right: bool) -> String:
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

func _tint_mannequin() -> void:
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.48, 0.025, 0.018)
	red.roughness = 0.62
	red.metallic = 0.05
	_override_mesh_materials(mannequin_scene, red)

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

func receive_enemy_hit(damage: float, attacker: Node = null, hit_direction: Vector3 = Vector3.ZERO) -> bool:
	if damage <= 0.0:
		return false
	if register_enemy_near_miss(attacker):
		return true
	if enemy_hit_invulnerability_timer > 0.0:
		return false
	if _shield_blocks_hit(attacker, hit_direction):
		var now_ms: int = Time.get_ticks_msec()
		var perfect_block: bool = now_ms - shield_block_started_ms <= perfect_block_timing_ms
		last_blocked_damage = damage
		last_enemy_damage = 0.0
		combat_blocked.emit(damage, attacker)
		if animation_driver != null:
			animation_driver.play_block_impact()
		if combat_feedback != null:
			combat_feedback.shield_blocked(damage, attacker)
		if perfect_block:
			shield_block_started_ms = -100000
			_start_perfect_response(&"block", attacker)
		return true
	enemy_hit_invulnerability_timer = enemy_hit_invulnerability
	last_enemy_damage = damage
	health_regen_elapsed = 0.0
	perfect_recovery_active = false
	health = maxf(0.0, health - damage)

	var push: Vector3 = hit_direction
	if push.length() < 0.01 and attacker is Node3D:
		push = global_position - (attacker as Node3D).global_position
	push.y = 0.0
	if push.length() > 0.01:
		push = push.normalized()
		velocity.x += push.x * 2.2
		velocity.z += push.z * 2.2

	damage_received.emit(damage, attacker)
	return true

func register_enemy_near_miss(attacker: Node = null) -> bool:
	if perfect_counter_dash_active or _perfect_response_available():
		return false
	var now_ms: int = Time.get_ticks_msec()
	var perfect_dash: bool = dash_time > 0.0 and now_ms - dodge_started_ms <= perfect_dodge_timing_ms
	var perfect_slide: bool = slide_time > 0.0 and now_ms - slide_started_ms <= perfect_slide_timing_ms
	if not perfect_dash and not perfect_slide:
		return false
	dodge_started_ms = -100000
	slide_started_ms = -100000
	_start_perfect_response(&"dodge", attacker)
	return true

func _shield_blocks_hit(attacker: Node, hit_direction: Vector3) -> bool:
	if not shield_blocking or not shield_visible:
		return false
	var toward_attacker: Vector3 = Vector3.ZERO
	if attacker is Node3D:
		toward_attacker = (attacker as Node3D).global_position - global_position
	elif hit_direction.length() > 0.01:
		# Enemy hit direction points from the attacker toward the player.
		toward_attacker = -hit_direction
	toward_attacker.y = 0.0
	if toward_attacker.length() < 0.01:
		return false
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	return forward.dot(toward_attacker.normalized()) >= cos(deg_to_rad(shield_block_half_angle_degrees))

func _update_debug_text() -> void:
	var status: String = animation_driver.debug_summary() if animation_driver != null else "UAL NATIVE=OFF"
	var charge_pct: int = int(clampf(heavy_charge / heavy_charge_max, 0.0, 1.0) * 100.0)
	var movement_state: String
	if parkour_active:
		movement_state = "PARKOUR:" + String(parkour_kind) + ("+SLIDE" if parkour_slide_queued else "")
	elif wall_run_active:
		movement_state = "WALL_RUN:" + String(wall_run_mode).to_upper()
	elif shield_blocking:
		movement_state = "BLOCK"
	elif slide_armed:
		movement_state = "SLIDE_ARMED"
	else:
		movement_state = String(_combat_context()).to_upper()
	var slide_y: float = visual_root.position.y if visual_root != null else 0.0
	var combat_debug: String = "ON" if combat_debug_visible else "OFF"
	debug_text = "V0.0.18  HP=%.0f/%.0f  STAMINA=%.0f/%.0f  DASH=%d/%d  SLIDE=%d/%d  STATE=%s  speed=%.2f  slideY=%.2f  comboLights=%d  charge=%d%%  blocked=%.0f\n%s\nI diagnostics=%s • bladeSpeed=%.2f • selected=%s • candidates=%s\nAimAssist=%.0fdeg/%.1fm + vertical • swordPitch=%.0fdeg • regen=%s • parkourProbe=%s" % [health, max_health, spiral_stamina, max_spiral_stamina, dash_charges, dash_max_charges, slide_charges, slide_max_charges, movement_state, Vector2(velocity.x, velocity.z).length(), slide_y, combo_light_count, charge_pct, last_blocked_damage, status, combat_debug, debug_last_blade_speed, String(debug_last_zone), debug_last_candidates, aim_assist_max_correction_degrees, aim_assist_max_distance, rad_to_deg(_current_attack_aim_pitch()), "BOOST" if perfect_recovery_active else "NORMAL", parkour_debug_reason]
	debug_text += "\nWallRun=%s/%s %.1f/%.1fm • vertical=%.1fm/%.1fs • runs=%d/%d • attach=%s • %s" % [String(wall_run_mode) if wall_run_active else "off", String(wall_run_surface_kind), wall_run_distance, wall_run_max_distance, wall_run_vertical_rise, wall_run_vertical_time, wall_run_runs_used, wall_run_max_chain_runs, "READY" if wall_run_attach_available else "LOCKED", wall_run_debug_reason]
	if resource_error != "":
		debug_text += "\nERROR: " + resource_error
