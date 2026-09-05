extends Node
class_name HopliteNativeAnimationDriver

signal combat_action_started(action: Dictionary)
signal combat_action_finished(action: Dictionary, reason: StringName)
signal combat_actions_cancelled(actions: Array[Dictionary], reason: StringName)

const UAL2_PATH := "res://assets/runtime/ual2/UAL2_Standard.glb"
const BridgeScript = preload("res://scripts/animation/authored_pose_bridge.gd")
const ExternalBankScript = preload("res://scripts/animation/external_animation_bank.gd")
const VERBOSE_SETTING := "debug/hoplite/verbose_animation"

static var _ready_reported: bool = false

var target_scene: Node
var target_skeleton: Skeleton3D
var target_player: AnimationPlayer

# UAL2 is instantiated twice on purpose:
# - movement_source_* drives full-body retargeted movement such as slide/parkour/ninja jump.
# - source_* remains dedicated to combat, so upper-body sword attacks can be layered
#   over a full-body slide without stealing the slide AnimationPlayer.
var movement_source_scene: Node
var movement_source_skeleton: Skeleton3D
var movement_source_player: AnimationPlayer

var source_scene: Node
var source_skeleton: Skeleton3D
var source_player: AnimationPlayer

var animation_tree: AnimationTree
var tree_root: AnimationNodeBlendTree
var locomotion_space: AnimationNodeBlendSpace1D
var full_body_machine: AnimationNodeStateMachine
var full_body_blend: AnimationNodeBlend2
var full_body_playback: AnimationNodeStateMachinePlayback
var movement_pose_bridge: HopliteAuthoredPoseBridge
var pose_bridge: HopliteAuthoredPoseBridge
var external_bank: Node
var wall_movement_bank: Node
var attack_uses_external_donor: bool = false

var slot_map: Dictionary = {}
var variant_pools: Dictionary = {}
var movement_pools: Dictionary = {}
var attack_candidates: Array[StringName] = []
var preview_index: int = 0

var current_attack_slot: StringName = StringName()
var current_attack_context: StringName = &"idle"
var current_attack_clip: StringName = StringName()
var attack_timer: float = 0.0
var attack_duration: float = 0.0
var attack_full_body: bool = false
var attack_hips_weight: float = 0.0
var attack_speed: float = 1.0
var attack_blend_in: float = 0.06
var attack_blend_out: float = 0.12
var attack_queue: Array[Dictionary] = []
var current_attack_chain_point: float = 0.58
var current_action_metadata: Dictionary = {}
var _next_action_request_id: int = 1

var charge_active: bool = false
var charge_clip: StringName = StringName()
var charge_context: StringName = &"idle"
var charge_ratio: float = 0.0
var block_active: bool = false
var block_clip: StringName = StringName()
var block_impact_timer: float = 0.0

var donor_action_timer: float = 0.0
var donor_action_duration: float = 0.0
var donor_action_slot: StringName = StringName()

# A wall release often outlives its authored flip clip. Keep an airborne ninja
# pose ready behind those one-shots so the legs never fall back to standing
# locomotion before the CharacterBody actually lands.
var wall_release_air_pose_requested: bool = false
var wall_release_air_pose_active: bool = false

# Mixamo wall-run clips use their own bank/bridges. Keeping them separate from
# the combat bank prevents an upper-body attack cleanup from accidentally
# stopping a full-body parkour pose.
var wall_visual_mode: StringName = StringName()
var wall_visual_timer: float = 0.0
var wall_visual_duration: float = 0.0
var wall_visual_looping: bool = false
var wall_visual_mirrored: bool = false

# Dedicated UAL2 slide visual state. Mechanical movement remains in player.gd;
# this state only retargets the authored Slide_Start / Slide / Slide_Exit poses.
var slide_visual_active: bool = false
var slide_visual_phase: StringName = StringName()
var slide_visual_phase_timer: float = 0.0
var slide_visual_phase_duration: float = 0.0

var full_body_timer: float = 0.0
var full_body_duration: float = 0.0
var speed_blend: float = 0.0
var configured: bool = false
var simulation_lod: int = 0
var simulation_interval: float = 0.0
var simulation_accumulator: float = 0.0
var simulation_sample_count: int = 0

func _physics_process(delta: float) -> void:
	if not configured or animation_tree == null or not animation_tree.active or simulation_lod >= 3:
		return
	if simulation_interval <= 0.0:
		_advance_simulation(maxf(delta, 0.0))
		return
	simulation_accumulator += maxf(delta, 0.0)
	if simulation_accumulator >= simulation_interval:
		_advance_simulation(simulation_accumulator)
		simulation_accumulator = 0.0

func set_simulation_lod(level: int) -> void:
	simulation_lod = clampi(level, 0, 3)
	simulation_interval = 0.0
	if simulation_lod == 1:
		simulation_interval = 1.0 / 30.0
	elif simulation_lod == 2:
		simulation_interval = 1.0 / 12.0
	simulation_accumulator = 0.0
	if animation_tree != null:
		animation_tree.active = simulation_lod < 3

func force_simulation_sample() -> void:
	if not configured or animation_tree == null:
		return
	var should_pause := simulation_lod >= 3
	animation_tree.active = true
	_advance_simulation(0.0)
	if should_pause:
		animation_tree.active = false

func _advance_simulation(delta: float) -> void:
	animation_tree.advance(maxf(delta, 0.0))
	simulation_sample_count += 1

func configure(visible_scene: Node, skeleton: Skeleton3D, player: AnimationPlayer, enable_external_bank: bool = true, external_keys: Array = [], enable_wall_movement: bool = true, profile_id: StringName = StringName()) -> bool:
	target_scene = visible_scene
	target_skeleton = skeleton
	target_player = player
	if target_skeleton == null or target_player == null:
		push_error("[UAL NATIVE] target skeleton/player missing")
		return false

	var packed: PackedScene = load(UAL2_PATH) as PackedScene
	if packed == null:
		push_error("[UAL NATIVE] UAL2 missing: " + UAL2_PATH)
		return false

	# Movement donor first: its full-body pose is applied before the combat bridge.
	# That ordering lets the combat bridge overwrite only upper-body bones during
	# slide attacks while the legs keep the actual UAL2 slide animation.
	movement_source_scene = packed.instantiate()
	movement_source_scene.name = "UAL2_Movement_Donor_Hidden"
	add_child(movement_source_scene)
	_disable_animation_trees(movement_source_scene)
	if movement_source_scene is Node3D:
		(movement_source_scene as Node3D).visible = false
	movement_source_player = _find_best_animation_player(movement_source_scene)
	movement_source_skeleton = _find_skeleton(movement_source_scene)
	if movement_source_player == null or movement_source_skeleton == null:
		push_error("[UAL NATIVE] UAL2 movement AnimationPlayer/Skeleton3D missing")
		return false
	movement_source_player.stop()

	movement_pose_bridge = BridgeScript.new() as HopliteAuthoredPoseBridge
	movement_pose_bridge.name = "UAL2MovementPoseBridge"
	target_skeleton.add_child(movement_pose_bridge)
	# Retarget rotations only. Slide ground height is handled by player.gd on the
	# visible mannequin root; donor positional/root tracks are never imported.
	if not movement_pose_bridge.configure(movement_source_skeleton):
		push_error("[UAL NATIVE] movement pose bridge could not map rigs")
		return false

	# Independent combat donor.
	source_scene = packed.instantiate()
	source_scene.name = "UAL2_Combat_Donor_Hidden"
	add_child(source_scene)
	_disable_animation_trees(source_scene)
	if source_scene is Node3D:
		(source_scene as Node3D).visible = false
	source_player = _find_best_animation_player(source_scene)
	source_skeleton = _find_skeleton(source_scene)
	if source_player == null or source_skeleton == null:
		push_error("[UAL NATIVE] UAL2 combat AnimationPlayer/Skeleton3D missing")
		return false
	source_player.stop()

	pose_bridge = BridgeScript.new() as HopliteAuthoredPoseBridge
	pose_bridge.name = "UAL2CombatPoseBridge"
	target_skeleton.add_child(pose_bridge)
	if not pose_bridge.configure(source_skeleton):
		push_error("[UAL NATIVE] combat pose bridge could not map rigs")
		return false

	# Enemies reuse this driver for UAL2 locomotion/signature moves, but they do
	# not need the player's 18 Mixamo attacks. Avoid constructing an entire donor
	# bank for every AI actor.
	if enable_external_bank:
		external_bank = ExternalBankScript.new()
		external_bank.name = "ExternalAnimationBank"
		add_child(external_bank)
		external_bank.configure(target_skeleton, external_keys, profile_id)

		if enable_wall_movement:
			wall_movement_bank = ExternalBankScript.new()
			wall_movement_bank.name = "WallRunAnimationBank"
			add_child(wall_movement_bank)
			wall_movement_bank.configure(target_skeleton, [&"wall_run", &"wall_run_diagonal", &"wall_run_vertical", &"wall_run_detach_twist"])
			wall_movement_bank.move_pose_bridges_before(pose_bridge)

	_build_slot_map()
	if not _build_locomotion_tree():
		return false
	configured = true
	if not _ready_reported:
		print("[UAL NATIVE V2.12] READY - native retarget driver")
		_ready_reported = true
	if _verbose_diagnostics():
		print("[UAL NATIVE V2.12] slots: ", slot_debug())
	_print_variant_summary()
	return true

func tick(delta: float) -> void:
	if not configured:
		return

	# Combat layer. This bridge was added after movement_pose_bridge, so these
	# upper-body rotations can sit on top of the authored slide pose.
	if block_active:
		if block_impact_timer > 0.0:
			block_impact_timer = maxf(0.0, block_impact_timer - delta)
			_set_active_attack_weight(1.0, false, 0.82)
			if block_impact_timer <= 0.0 and external_bank != null:
				external_bank.hold(&"block_idle", 0.46, false, 0.72)
		else:
			_set_active_attack_weight(1.0, false, 0.72)
	elif charge_active:
		if pose_bridge != null and not attack_uses_external_donor:
			# A held heavy charge is a persistent upper-body layer. Jump, dash and
			# slide keep ownership of the lower body until the attack is released.
			pose_bridge.set_attack_weight(1.0, false, 0.50)
	elif attack_timer > 0.0:
		attack_timer -= delta
		var progress: float = current_attack_progress()
		var blend: float = 1.0
		if progress < attack_blend_in:
			blend = progress / maxf(attack_blend_in, 0.001)
		elif progress > (1.0 - attack_blend_out):
			blend = clampf((1.0 - progress) / maxf(attack_blend_out, 0.001), 0.0, 1.0)
		_set_active_attack_weight(blend, attack_full_body, attack_hips_weight)

		if not attack_queue.is_empty() and progress >= current_attack_chain_point:
			var queued: Dictionary = attack_queue[0]
			attack_queue.remove_at(0)
			if bool(queued.get("external", false)):
				_start_external_attack(
					StringName(queued.get("external_key", StringName())),
					StringName(queued.get("slot", StringName())),
					StringName(queued.get("context", &"idle")),
					bool(queued.get("full_body", false)),
					float(queued.get("speed", 1.0)),
					float(queued.get("blend", 0.07)),
					float(queued.get("hips", 0.35)),
					float(queued.get("start_fraction", 0.0)),
					bool(queued.get("fast", false)),
					queued.get("metadata", {}) as Dictionary,
					&"chained"
				)
			else:
				_start_attack_clip(
					StringName(queued.get("slot", StringName())),
					StringName(queued.get("context", &"idle")),
					StringName(queued.get("clip", StringName())),
					bool(queued.get("full_body", false)),
					float(queued.get("speed", 1.0)),
					float(queued.get("blend", 0.07)),
					float(queued.get("hips", 0.35)),
					float(queued.get("start_fraction", 0.0)),
					bool(queued.get("fast", false)),
					queued.get("metadata", {}) as Dictionary,
					&"chained"
				)
		elif attack_timer <= 0.0:
			_finish_attack(&"finished")
	else:
		_set_active_attack_weight(0.0, false, 0.0)

	# Full-body UAL2 movement layer (slide / parkour / ninja jump).
	if slide_visual_active or slide_visual_phase == &"exit":
		_tick_slide_visual(delta)
	elif donor_action_timer > 0.0:
		donor_action_timer -= delta
		var donor_progress: float = 1.0 - maxf(donor_action_timer, 0.0) / maxf(donor_action_duration, 0.001)
		var donor_blend: float = 1.0
		if donor_progress < 0.06:
			donor_blend = donor_progress / 0.06
		elif donor_progress > 0.90:
			donor_blend = clampf((1.0 - donor_progress) / 0.10, 0.0, 1.0)
		if movement_pose_bridge != null:
			movement_pose_bridge.set_attack_weight(donor_blend, true, 1.0)
		if donor_action_timer <= 0.0:
			_finish_donor_action()
	elif wall_release_air_pose_active:
		# _tick_wall_release_air_pose owns the weight. It may temporarily hide
		# this pose while a new flip, dash or other full-body action is playing.
		pass
	elif movement_pose_bridge != null:
		movement_pose_bridge.set_attack_weight(0.0, false, 0.0)

	_tick_wall_run_visual(delta)
	_tick_wall_release_air_pose()

	if full_body_timer > 0.0:
		full_body_timer -= delta
		var full_progress: float = 1.0 - maxf(full_body_timer, 0.0) / maxf(full_body_duration, 0.001)
		var full_blend: float = 1.0
		if full_progress < 0.08:
			full_blend = full_progress / 0.08
		elif full_progress > 0.84:
			full_blend = clampf((1.0 - full_progress) / 0.16, 0.0, 1.0)
		animation_tree.set("parameters/FullBodyBlend/blend_amount", full_blend)
		if full_body_timer <= 0.0:
			animation_tree.set("parameters/FullBodyBlend/blend_amount", 0.0)

func set_locomotion(normalized_speed: float) -> void:
	if not configured:
		return
	speed_blend = clampf(normalized_speed, 0.0, 1.0)
	animation_tree.set("parameters/Locomotion/blend_position", speed_blend)

func set_attack_aim_pitch(pitch_radians: float) -> void:
	if pose_bridge != null:
		pose_bridge.set_attack_aim_pitch(pitch_radians)
	if external_bank != null:
		# External clips already author the blade's vertical arc. Adding camera
		# pitch on top made every imported slash climb upward and heavily distorted
		# the dedicated spins. Horizontal aim assist remains handled by player.gd.
		external_bank.set_aim_pitch(0.0)

func begin_block() -> bool:
	if not configured or source_player == null:
		return false
	if block_active:
		return true
	_finish_attack(&"block")
	if external_bank != null and external_bank.hold(&"block_idle", 0.46, false, 0.72):
		block_active = true
		block_clip = &"external:block_idle"
		block_impact_timer = 0.0
		attack_uses_external_donor = true
		return true
	# Sword_Block retargets the UAL2 left arm behind the UAL1 torso. Idle_Shield
	# keeps the aspis on the actual frontal side of this target rig.
	block_clip = &"Idle_Shield" if source_player.has_animation(&"Idle_Shield") else &"Sword_Block"
	if block_clip == StringName() or not source_player.has_animation(block_clip):
		return false
	block_active = true
	source_player.play(block_clip, 0.07, 1.0)
	source_player.advance(0.0)
	var anim: Animation = source_player.get_animation(block_clip)
	if anim != null:
		source_player.seek(anim.length * 0.48, true)
	source_player.pause()
	if pose_bridge != null:
		pose_bridge.set_attack_weight(1.0, false, 0.58)
	return true

func end_block() -> void:
	if not block_active:
		return
	block_active = false
	block_clip = StringName()
	block_impact_timer = 0.0
	if attack_uses_external_donor and external_bank != null:
		external_bank.stop()
		attack_uses_external_donor = false
	if source_player != null:
		source_player.stop()
	if pose_bridge != null:
		pose_bridge.set_attack_weight(0.0, false, 0.0)

func is_block_active() -> bool:
	return block_active

func play_block_impact() -> bool:
	if not block_active or external_bank == null or not external_bank.has_clip(&"block_impact"):
		return false
	var duration: float = external_bank.play(&"block_impact", 0.025, 1.45, false, 0.82, 0.0)
	if duration <= 0.0:
		return false
	attack_uses_external_donor = true
	block_impact_timer = duration
	return true

func play_attack_variant(slot: StringName, context: StringName, force_full_body: bool = false, custom_speed: float = -1.0, custom_blend: float = -1.0, hips_weight: float = -1.0, fast: bool = false) -> bool:
	if not configured:
		return false
	end_block()
	var clip: StringName = _choose_attack_variant(slot, context)
	if clip == StringName():
		return false
	var profile: Dictionary = _attack_profile(slot, context, fast)
	var full_body_value: bool = force_full_body or bool(profile.get("full_body", false))
	var speed_value: float = custom_speed if custom_speed > 0.0 else float(profile.get("speed", 1.0))
	var blend_value: float = custom_blend if custom_blend >= 0.0 else float(profile.get("blend", 0.07))
	var hips_value: float = hips_weight if hips_weight >= 0.0 else float(profile.get("hips", 0.35))
	return _start_attack_clip(slot, context, clip, full_body_value, speed_value, blend_value, hips_value, 0.0, fast)

# Explicit fallback used for attacks whose silhouette must remain recognizable.
# It keeps the gameplay slot/context intact (unlike signature enemy actions) and
# never silently substitutes an unrelated dash or multi-hit combo animation.
func play_attack_exact(slot: StringName, context: StringName, candidates: Array, force_full_body: bool = false, custom_speed: float = -1.0, custom_blend: float = -1.0, hips_weight: float = -1.0, fast: bool = false, action_metadata: Dictionary = {}) -> bool:
	if not configured or source_player == null:
		return false
	end_block()
	var clip: StringName = _first_existing_attack_clip(candidates)
	if clip == StringName():
		return false
	var profile: Dictionary = _attack_profile(slot, context, fast)
	var full_body_value: bool = force_full_body or bool(profile.get("full_body", false))
	var speed_value: float = custom_speed if custom_speed > 0.0 else float(profile.get("speed", 1.0))
	var blend_value: float = custom_blend if custom_blend >= 0.0 else float(profile.get("blend", 0.07))
	var hips_value: float = hips_weight if hips_weight >= 0.0 else float(profile.get("hips", 0.35))
	return _start_attack_clip(slot, context, clip, full_body_value, speed_value, blend_value, hips_value, 0.0, fast, action_metadata)

func has_external_clip(key: StringName) -> bool:
	return external_bank != null and external_bank.has_clip(key)

func external_clip_length(key: StringName) -> float:
	return float(external_bank.clip_length(key)) if external_bank != null and external_bank.has_clip(key) else 0.0

func play_external_attack(key: StringName, slot: StringName, context: StringName, force_full_body: bool = false, custom_speed: float = -1.0, custom_blend: float = -1.0, hips_weight: float = -1.0, fast: bool = false, start_fraction: float = 0.0, action_metadata: Dictionary = {}) -> bool:
	if not configured or external_bank == null or not external_bank.has_clip(key):
		return false
	end_block()
	var profile: Dictionary = _attack_profile(slot, context, fast)
	var full_body_value: bool = force_full_body or bool(profile.get("full_body", false))
	var speed_value: float = custom_speed if custom_speed > 0.0 else float(profile.get("speed", 1.0))
	var blend_value: float = custom_blend if custom_blend >= 0.0 else float(profile.get("blend", 0.07))
	var hips_value: float = hips_weight if hips_weight >= 0.0 else float(profile.get("hips", 0.35))
	return _start_external_attack(key, slot, context, full_body_value, speed_value, blend_value, hips_value, start_fraction, fast, action_metadata)

func request_external_attack(key: StringName, slot: StringName, context: StringName, force_full_body: bool = false, custom_speed: float = -1.0, custom_blend: float = -1.0, hips_weight: float = -1.0, fast: bool = false, start_fraction: float = 0.0, action_metadata: Dictionary = {}) -> bool:
	if not configured or external_bank == null or not external_bank.has_clip(key):
		return false
	end_block()
	var profile: Dictionary = _attack_profile(slot, context, fast)
	var full_body_value: bool = force_full_body or bool(profile.get("full_body", false))
	var speed_value: float = custom_speed if custom_speed > 0.0 else float(profile.get("speed", 1.0))
	var blend_value: float = custom_blend if custom_blend >= 0.0 else float(profile.get("blend", 0.07))
	var hips_value: float = hips_weight if hips_weight >= 0.0 else float(profile.get("hips", 0.35))
	var metadata := _normalize_action_metadata(slot, context, action_metadata)
	if attack_timer <= 0.0 and not charge_active:
		return _start_external_attack(key, slot, context, full_body_value, speed_value, blend_value, hips_value, start_fraction, fast, metadata)
	if attack_queue.size() >= 3:
		return false
	attack_queue.append({
		"external": true,
		"external_key": key,
		"slot": slot,
		"context": context,
		"full_body": full_body_value,
		"speed": speed_value,
		"blend": blend_value,
		"hips": hips_value,
		"start_fraction": start_fraction,
		"fast": fast,
		"metadata": metadata,
	})
	return true

func request_attack_variant(slot: StringName, context: StringName, force_full_body: bool = false, custom_speed: float = -1.0, custom_blend: float = -1.0, hips_weight: float = -1.0, fast: bool = false, action_metadata: Dictionary = {}) -> bool:
	if not configured:
		return false
	end_block()
	var clip: StringName = _choose_attack_variant(slot, context)
	if clip == StringName():
		return false
	var profile: Dictionary = _attack_profile(slot, context, fast)
	var full_body_value: bool = force_full_body or bool(profile.get("full_body", false))
	var speed_value: float = custom_speed if custom_speed > 0.0 else float(profile.get("speed", 1.0))
	var blend_value: float = custom_blend if custom_blend >= 0.0 else float(profile.get("blend", 0.07))
	var hips_value: float = hips_weight if hips_weight >= 0.0 else float(profile.get("hips", 0.35))
	var metadata := _normalize_action_metadata(slot, context, action_metadata)
	if attack_timer <= 0.0 and not charge_active:
		return _start_attack_clip(slot, context, clip, full_body_value, speed_value, blend_value, hips_value, 0.0, fast, metadata)
	# Three buffered attacks is enough for very fast clicking without storing a
	# long autopilot combo. Earlier versions only kept two and could visibly drop
	# a click when the player tapped faster than the authored chain point.
	if attack_queue.size() >= 3:
		return false
	attack_queue.append({
		"slot": slot,
		"context": context,
		"clip": clip,
		"full_body": full_body_value,
		"speed": speed_value,
		"blend": blend_value,
		"hips": hips_value,
		"start_fraction": 0.0,
		"fast": fast,
		"metadata": metadata,
	})
	return true

# Compatibility wrappers used by older lab scripts.
func play_attack(slot: StringName, force_full_body: bool = false, custom_speed: float = -1.0, custom_blend: float = -1.0, hips_weight: float = -1.0) -> bool:
	return play_attack_variant(slot, &"idle", force_full_body, custom_speed, custom_blend, hips_weight, false)

# Enemy classes may request one of the exact UAL2 clips inventoried for their
# signature move (shield bash, farm swing, dash...). Keeping that choice here
# preserves the same pose bridge and blend lifecycle as ordinary attacks.
func play_authored_attack(candidates: Array, custom_speed: float = 1.0, force_full_body: bool = false, hips_weight: float = 0.45) -> bool:
	if not configured or source_player == null:
		return false
	end_block()
	for candidate: Variant in candidates:
		var clip := StringName(candidate)
		if source_player.has_animation(clip):
			return _start_attack_clip(&"signature", &"idle", clip, force_full_body, custom_speed, 0.06, hips_weight, 0.0, false)
	return false

func request_attack(slot: StringName, force_full_body: bool = false, custom_speed: float = -1.0, custom_blend: float = -1.0, hips_weight: float = -1.0) -> bool:
	return request_attack_variant(slot, &"idle", force_full_body, custom_speed, custom_blend, hips_weight, false)

func begin_heavy_charge(context: StringName) -> bool:
	if not configured:
		return false
	end_block()
	_finish_attack(&"heavy_charge")
	charge_context = context
	charge_clip = _choose_attack_variant(&"heavy", context)
	if charge_clip == StringName() or not source_player.has_animation(charge_clip):
		return false
	charge_active = true
	charge_ratio = 0.0
	source_player.play(charge_clip, 0.08, 1.0)
	source_player.advance(0.0)
	var anim: Animation = source_player.get_animation(charge_clip)
	var hold_time: float = anim.length * 0.14
	source_player.seek(hold_time, true)
	source_player.pause()
	if pose_bridge != null:
		# Keep the anticipation pose mobile from the first frame of charging.
		pose_bridge.set_attack_weight(1.0, false, 0.50)
	current_attack_slot = &"charge"
	current_attack_context = context
	current_attack_clip = charge_clip
	current_action_metadata = _normalize_action_metadata(&"charge", context, {})
	combat_action_started.emit(current_action_metadata.duplicate(true))
	return true

func update_heavy_charge(ratio: float) -> void:
	if not charge_active or charge_clip == StringName():
		return
	charge_ratio = clampf(ratio, 0.0, 1.0)
	var anim: Animation = source_player.get_animation(charge_clip)
	if anim == null:
		return
	# Scrub through the anticipation section while held. If the authored clip is an
	# overhead attack this literally raises the sword further as charge grows.
	var pose_time: float = anim.length * lerpf(0.12, 0.30, charge_ratio)
	source_player.seek(pose_time, true)
	source_player.pause()

func release_heavy_charge(context: StringName, ratio: float, fast_combo: bool = false) -> bool:
	if not configured:
		return false
	var final_ratio: float = clampf(ratio, 0.0, 1.0)
	var clip: StringName = charge_clip
	if clip == StringName() or not source_player.has_animation(clip) or context != charge_context:
		clip = _choose_attack_variant(&"heavy", context)
	charge_active = false
	charge_ratio = 0.0
	charge_clip = StringName()
	source_player.stop(true)
	if clip == StringName():
		_finish_attack(&"heavy_release_failed")
		return false
	var profile: Dictionary = _attack_profile(&"heavy", context, fast_combo)
	var speed_value: float = 1.45 if fast_combo else lerpf(1.05, 0.86, final_ratio)
	var blend_value: float = 0.045 if fast_combo else lerpf(0.07, 0.10, final_ratio)
	var start_fraction: float = 0.20 if fast_combo else lerpf(0.12, 0.24, final_ratio)
	# Running heavies must own the hips during the release. Previously the run
	# locomotion kept masking most of the selected dash clip, producing motion and
	# damage state without a readable sword attack.
	var full_body_value: bool = context == &"run" or context == &"air" or context == &"dash"
	var hips_value: float = 0.82 if full_body_value else lerpf(0.54, 0.72, final_ratio)
	return _start_attack_clip(&"heavy", context, clip, full_body_value, speed_value, blend_value, hips_value, start_fraction, fast_combo)

func cancel_heavy_charge() -> void:
	if not charge_active:
		return
	charge_active = false
	charge_clip = StringName()
	charge_ratio = 0.0
	source_player.stop()
	current_attack_slot = StringName()
	current_attack_clip = StringName()
	_emit_current_action_finished(&"cancelled")
	if pose_bridge != null:
		pose_bridge.set_attack_weight(0.0, false, 0.0)

func play_donor_action(slot: StringName, speed: float = 1.0) -> bool:
	if not configured:
		return false
	var clip: StringName = _choose_movement_variant(slot)
	if clip == StringName() or movement_source_player == null or not movement_source_player.has_animation(clip):
		return false
	cancel_slide_visual()
	return _play_exact_movement_action(clip, slot, speed) > 0.0

func play_ninja_jump(speed: float = 1.0) -> float:
	if not configured:
		return 0.0
	# A fresh jump must own the full body immediately. This is especially
	# important after a wall release: the independent wall donor is added after
	# the UAL2 movement bridge and would otherwise mask NinjaJump_Start until its
	# old flip finishes.
	stop_wall_run_visual()
	stop_full_body()
	cancel_slide_visual()
	var clip: StringName = StringName(slot_map.get(&"ninja_jump_start", StringName()))
	return _play_exact_movement_action(clip, &"ninja_jump", speed)

func play_wall_release_double_jump() -> bool:
	if not configured or not wall_release_air_pose_requested or wall_movement_bank == null:
		return false
	stop_movement_action()
	stop_full_body()
	cancel_slide_visual()
	wall_movement_bank.stop()
	wall_visual_mode = &"wall_double_jump_twist"
	wall_visual_timer = 0.0
	wall_visual_duration = 0.0
	wall_visual_looping = false
	wall_visual_mirrored = false
	# Front Twist Flip is the proven diagonal wall-jump animation. Skip its
	# planted preparation and play its compact airborne rotation as the actual
	# second jump, at the moment the input is pressed rather than after the first
	# vertical backflip has already finished.
	wall_visual_duration = wall_movement_bank.play(&"wall_run_detach_twist", 0.025, 1.18, true, 1.0, 0.18)
	wall_visual_timer = wall_visual_duration
	if wall_visual_timer <= 0.0:
		wall_visual_mode = StringName()
		return false
	wall_movement_bank.set_mirrored(false)
	wall_movement_bank.set_weight(1.0, true, 1.0)
	return true

func request_wall_release_air_pose() -> void:
	if not configured:
		return
	wall_release_air_pose_requested = true

func clear_wall_release_air_pose() -> void:
	wall_release_air_pose_requested = false
	if wall_release_air_pose_active:
		_finish_donor_action(true)

func _tick_wall_release_air_pose() -> void:
	if not wall_release_air_pose_requested:
		return
	var overridden: bool = (
		wall_visual_mode != StringName()
		or donor_action_timer > 0.0
		or slide_visual_active
		or slide_visual_phase == &"exit"
		or full_body_timer > 0.0
	)
	if overridden:
		if wall_release_air_pose_active and movement_pose_bridge != null:
			movement_pose_bridge.set_attack_weight(0.0, false, 0.0)
		return
	if not wall_release_air_pose_active:
		_start_wall_release_air_pose()
	if wall_release_air_pose_active and movement_pose_bridge != null:
		movement_pose_bridge.set_attack_weight(1.0, true, 1.0)

func _start_wall_release_air_pose() -> void:
	if movement_source_player == null:
		return
	var clip: StringName = StringName(slot_map.get(&"ninja_jump_idle", StringName()))
	var hold_still: bool = false
	if clip == StringName() or not movement_source_player.has_animation(clip):
		# Safe fallback for an incomplete animation package: hold the tucked part
		# of NinjaJump_Start instead of ever revealing the upright locomotion.
		clip = StringName(slot_map.get(&"ninja_jump_start", StringName()))
		hold_still = true
	if clip == StringName() or not movement_source_player.has_animation(clip):
		return
	_finish_donor_action(true)
	var anim: Animation = movement_source_player.get_animation(clip)
	if not hold_still:
		anim.loop_mode = Animation.LOOP_LINEAR
	movement_source_player.play(clip, 0.055, 1.0)
	movement_source_player.advance(0.0)
	if hold_still:
		movement_source_player.seek(anim.length * 0.56, true)
		movement_source_player.pause()
	wall_release_air_pose_active = true
	if movement_pose_bridge != null:
		movement_pose_bridge.set_attack_weight(0.001, true, 1.0)

func stop_movement_action() -> void:
	_finish_donor_action(true)

func current_movement_action_slot() -> StringName:
	return donor_action_slot

func play_wall_run_visual(mode: StringName, mirrored: bool = false) -> bool:
	if not configured or wall_movement_bank == null:
		return false
	if wall_visual_mode == mode and wall_visual_mirrored == mirrored and (wall_visual_looping or wall_visual_timer > 0.0):
		return true

	stop_movement_action()
	stop_full_body()
	cancel_slide_visual()
	wall_movement_bank.stop()
	wall_visual_mode = mode
	wall_visual_timer = 0.0
	wall_visual_duration = 0.0
	wall_visual_looping = mode == &"horizontal" or mode == &"diagonal"
	wall_visual_mirrored = mirrored and mode != &"vertical"

	var key: StringName = &"wall_run"
	var speed: float = 1.0
	if mode == &"diagonal":
		key = &"wall_run_diagonal"
		speed = 1.05
	elif mode == &"vertical":
		key = &"wall_run_vertical"
		speed = 1.0

	if wall_visual_looping:
		if wall_movement_bank.play_loop(key, 0.045, speed, true, 1.0):
			wall_movement_bank.set_mirrored(wall_visual_mirrored)
			wall_movement_bank.set_weight(1.0, true, 1.0)
			return true
	else:
		wall_visual_duration = wall_movement_bank.play(key, 0.035, speed, true, 1.0)
		wall_visual_timer = wall_visual_duration
		if wall_visual_timer > 0.0:
			wall_movement_bank.set_mirrored(false)
			return true

	wall_visual_mode = StringName()
	wall_visual_looping = false
	return false

func finish_wall_run_visual(keep_vertical_flip: bool = false) -> void:
	if keep_vertical_flip and wall_visual_mode == &"vertical" and wall_visual_timer > 0.0:
		# Run To Flip contains the authored detachment/backflip. Mechanics release
		# the wall first, then this one-shot is allowed to finish in the air. If
		# the player jumps early, skip the remaining approach steps so the actual
		# flip is still shown immediately.
		var remaining: float = wall_movement_bank.seek_active_fraction(0.32)
		if remaining > 0.0:
			wall_visual_duration = remaining
			wall_visual_timer = remaining
			wall_visual_mode = &"vertical_release"
			return
	# If the authored vertical approach has already ended, use the proven compact
	# diagonal flip as the release itself. It must not be chained automatically
	# after an already visible backflip; the next acrobatic beat belongs to the
	# player's real second-jump input.
	if keep_vertical_flip and _start_vertical_release_twist():
		return
	stop_wall_run_visual()

func _start_vertical_release_twist() -> bool:
	if not configured or wall_movement_bank == null:
		return false
	wall_movement_bank.stop()
	wall_visual_mode = &"vertical_twist_release"
	wall_visual_timer = 0.0
	wall_visual_duration = 0.0
	wall_visual_looping = false
	wall_visual_mirrored = false
	# Fallback release for the case where Run To Flip has already expired. This is
	# the same tucked silhouette that works for the diagonal release, kept
	# unmirrored for a straight vertical eject.
	wall_visual_duration = wall_movement_bank.play(&"wall_run_detach_twist", 0.025, 1.10, true, 1.0, 0.18)
	wall_visual_timer = wall_visual_duration
	if wall_visual_timer <= 0.0:
		wall_visual_mode = StringName()
		return false
	wall_movement_bank.set_mirrored(false)
	wall_movement_bank.set_weight(1.0, true, 1.0)
	return true

func play_wall_run_detach_visual(released_mode: StringName, mirrored: bool) -> bool:
	if not configured or wall_movement_bank == null or released_mode == &"vertical":
		return false
	stop_movement_action()
	stop_full_body()
	cancel_slide_visual()
	wall_movement_bank.stop()
	wall_visual_mode = &"twist_release"
	wall_visual_timer = 0.0
	wall_visual_duration = 0.0
	wall_visual_looping = false
	wall_visual_mirrored = mirrored

	# Front Twist Flip was authored as a ground take-off. Positional/root tracks
	# are already ignored by the pose bridge; beginning slightly inside the clip
	# also removes the planted preparation so it reads as an airborne wall eject.
	var speed: float = 1.12 if released_mode == &"horizontal" else 1.04
	var start_fraction: float = 0.18 if released_mode == &"horizontal" else 0.15
	wall_visual_duration = wall_movement_bank.play(&"wall_run_detach_twist", 0.035, speed, true, 1.0, start_fraction)
	wall_visual_timer = wall_visual_duration
	if wall_visual_timer > 0.0:
		wall_movement_bank.set_mirrored(wall_visual_mirrored)
		wall_movement_bank.set_weight(1.0, true, 1.0)
		return true
	wall_visual_mode = StringName()
	wall_visual_mirrored = false
	return false

func stop_wall_run_visual() -> void:
	wall_visual_mode = StringName()
	wall_visual_timer = 0.0
	wall_visual_duration = 0.0
	wall_visual_looping = false
	wall_visual_mirrored = false
	if wall_movement_bank != null:
		wall_movement_bank.stop()

func _tick_wall_run_visual(delta: float) -> void:
	if wall_movement_bank == null or wall_visual_mode == StringName():
		return
	if wall_visual_looping:
		wall_movement_bank.set_weight(1.0, true, 1.0)
		return
	wall_visual_timer = maxf(0.0, wall_visual_timer - delta)
	# Hand off before Run To Flip reaches its long, extended-leg recovery. In
	# source time this is roughly 78% through the full clip: the backflip reads
	# completely, then NinjaJump_Idle immediately supplies the tucked airborne
	# silhouette. A twist is reserved for an actual second-jump input.
	if (
		wall_visual_mode == &"vertical_release"
		and wall_release_air_pose_requested
		and wall_visual_duration > 0.001
		and wall_visual_timer <= wall_visual_duration * 0.32
	):
		stop_wall_run_visual()
		return
	var weight: float = 1.0
	var vertical_air_chain: bool = (
		wall_visual_mode == &"vertical_release"
		or wall_visual_mode == &"vertical_twist_release"
		or wall_visual_mode == &"wall_double_jump_twist"
	)
	# Never reveal locomotion immediately before NinjaJump_Idle. Lateral/diagonal
	# release blending stays untouched.
	if not vertical_air_chain and wall_visual_duration > 0.001 and wall_visual_timer < wall_visual_duration * 0.18:
		weight = clampf(wall_visual_timer / (wall_visual_duration * 0.18), 0.0, 1.0)
	wall_movement_bank.set_weight(weight, true, 1.0)
	if wall_visual_timer <= 0.0:
		stop_wall_run_visual()

func start_slide_visual(mechanical_duration: float) -> bool:
	if not configured or movement_source_player == null:
		return false
	_finish_donor_action(true)
	stop_full_body()
	slide_visual_active = true
	slide_visual_phase = StringName()
	slide_visual_phase_timer = 0.0
	slide_visual_phase_duration = 0.0

	var start_clip: StringName = StringName(slot_map.get(&"slide_start", StringName()))
	var loop_clip: StringName = StringName(slot_map.get(&"slide_loop", StringName()))
	if start_clip != StringName() and movement_source_player.has_animation(start_clip):
		# The mechanical slide is intentionally short. Compress only the authored
		# entry so we still reach the actual Slide clip before the movement ends.
		var anim: Animation = movement_source_player.get_animation(start_clip)
		var desired_start_time: float = clampf(mechanical_duration * 0.36, 0.055, 0.085)
		var speed: float = maxf(anim.length / maxf(desired_start_time, 0.001), 1.0)
		_play_slide_clip(start_clip, &"start", speed, false)
		return true
	if loop_clip != StringName() and movement_source_player.has_animation(loop_clip):
		_play_slide_clip(loop_clip, &"loop", 1.0, true)
		return true
	slide_visual_active = false
	return false

func finish_slide_visual() -> void:
	if not configured:
		return
	if not slide_visual_active and slide_visual_phase != &"start" and slide_visual_phase != &"loop":
		return
	slide_visual_active = false
	var exit_clip: StringName = StringName(slot_map.get(&"slide_exit", StringName()))
	if exit_clip != StringName() and movement_source_player != null and movement_source_player.has_animation(exit_clip):
		# Exit is visual recovery only: controls are already back, so play it fast.
		_play_slide_clip(exit_clip, &"exit", 1.65, false)
	else:
		cancel_slide_visual()

func cancel_slide_visual() -> void:
	slide_visual_active = false
	slide_visual_phase = StringName()
	slide_visual_phase_timer = 0.0
	slide_visual_phase_duration = 0.0
	if movement_source_player != null and donor_action_timer <= 0.0:
		movement_source_player.stop()
	if movement_pose_bridge != null and donor_action_timer <= 0.0:
		movement_pose_bridge.set_attack_weight(0.0, false, 0.0)

func _play_slide_clip(clip: StringName, phase: StringName, speed: float, loop_clip: bool) -> void:
	if movement_source_player == null or clip == StringName() or not movement_source_player.has_animation(clip):
		return
	movement_source_player.play(clip, 0.025, speed)
	movement_source_player.advance(0.0)
	var anim: Animation = movement_source_player.get_animation(clip)
	if loop_clip:
		anim.loop_mode = Animation.LOOP_LINEAR
	slide_visual_phase = phase
	slide_visual_phase_duration = maxf(anim.length / maxf(absf(speed), 0.05), 0.03)
	slide_visual_phase_timer = slide_visual_phase_duration
	if movement_pose_bridge != null:
		movement_pose_bridge.set_attack_weight(0.001, true, 1.0)

func _tick_slide_visual(delta: float) -> void:
	if movement_pose_bridge != null:
		var blend: float = 1.0
		if slide_visual_phase == &"exit" and slide_visual_phase_duration > 0.001:
			var progress: float = 1.0 - maxf(slide_visual_phase_timer, 0.0) / slide_visual_phase_duration
			if progress > 0.72:
				blend = clampf((1.0 - progress) / 0.28, 0.0, 1.0)
		movement_pose_bridge.set_attack_weight(blend, true, 1.0)

	if slide_visual_phase == &"start":
		slide_visual_phase_timer -= delta
		if slide_visual_phase_timer <= 0.0 and slide_visual_active:
			var loop_clip: StringName = StringName(slot_map.get(&"slide_loop", StringName()))
			if loop_clip != StringName() and movement_source_player.has_animation(loop_clip):
				_play_slide_clip(loop_clip, &"loop", 1.0, true)
	elif slide_visual_phase == &"exit":
		slide_visual_phase_timer -= delta
		if slide_visual_phase_timer <= 0.0:
			slide_visual_phase = StringName()
			if movement_source_player != null:
				movement_source_player.stop()
			if movement_pose_bridge != null:
				movement_pose_bridge.set_attack_weight(0.0, false, 0.0)

func _play_exact_movement_action(clip: StringName, slot: StringName, speed: float = 1.0) -> float:
	if clip == StringName() or movement_source_player == null or not movement_source_player.has_animation(clip):
		return 0.0
	_finish_donor_action(true)
	movement_source_player.play(clip, 0.045, speed)
	movement_source_player.advance(0.0)
	var anim: Animation = movement_source_player.get_animation(clip)
	donor_action_duration = maxf(anim.length / maxf(absf(speed), 0.05), 0.08)
	donor_action_timer = donor_action_duration
	donor_action_slot = slot
	if movement_pose_bridge != null:
		movement_pose_bridge.set_attack_weight(0.001, true, 1.0)
	if _verbose_diagnostics():
		print("[UAL NATIVE] MOVEMENT ACTION ", slot, " -> ", clip, " duration=", donor_action_duration)
	return donor_action_duration

func _finish_donor_action(force: bool = false) -> void:
	if not force and donor_action_timer <= 0.0 and donor_action_slot == StringName() and not wall_release_air_pose_active:
		return
	donor_action_timer = 0.0
	donor_action_duration = 0.0
	donor_action_slot = StringName()
	wall_release_air_pose_active = false
	if movement_source_player != null:
		movement_source_player.stop()
	if movement_pose_bridge != null:
		movement_pose_bridge.set_attack_weight(0.0, false, 0.0)

func _normalize_action_metadata(slot: StringName, context: StringName, metadata: Dictionary) -> Dictionary:
	var result: Dictionary = metadata.duplicate(true)
	result[&"slot"] = slot
	result[&"context"] = context
	if int(result.get(&"request_id", 0)) <= 0:
		result[&"request_id"] = _next_action_request_id
		_next_action_request_id += 1
	return result


func _emit_current_action_finished(reason: StringName) -> void:
	if current_action_metadata.is_empty():
		return
	var finished_action := current_action_metadata.duplicate(true)
	current_action_metadata.clear()
	combat_action_finished.emit(finished_action, reason)


func _start_attack_clip(slot: StringName, context: StringName, clip: StringName, full_body_value: bool, speed_value: float, blend_value: float, hips_value: float, start_fraction: float, fast: bool, action_metadata: Dictionary = {}, replacement_reason: StringName = &"replaced") -> bool:
	if clip == StringName() or not source_player.has_animation(clip):
		if _verbose_diagnostics():
			print("[UAL NATIVE] missing attack clip ", slot, " / ", context, " -> ", clip)
		return false
	_emit_current_action_finished(replacement_reason)
	if external_bank != null:
		external_bank.stop()
	attack_uses_external_donor = false
	source_player.play(clip, blend_value, speed_value)
	source_player.advance(0.0)
	var anim: Animation = source_player.get_animation(clip)
	var fraction: float = clampf(start_fraction, 0.0, 0.75)
	if fraction > 0.001:
		source_player.seek(anim.length * fraction, true)
	current_attack_slot = slot
	current_attack_context = context
	current_attack_clip = clip
	attack_full_body = full_body_value
	attack_hips_weight = hips_value
	attack_speed = speed_value

	var profile: Dictionary = _attack_profile(slot, context, fast)
	attack_blend_in = float(profile.get("blend_in", 0.055))
	attack_blend_out = float(profile.get("blend_out", 0.10))
	current_attack_chain_point = float(profile.get("chain", 0.58))
	attack_duration = maxf((anim.length * (1.0 - fraction)) / maxf(absf(speed_value), 0.05), 0.12)
	attack_timer = attack_duration
	current_action_metadata = _normalize_action_metadata(slot, context, action_metadata)
	if pose_bridge != null:
		pose_bridge.set_attack_weight(0.001, attack_full_body, attack_hips_weight)
	combat_action_started.emit(current_action_metadata.duplicate(true))
	if _verbose_diagnostics():
		print("[UAL NATIVE] ATTACK ", slot, "/", context, " -> ", clip, " speed=", speed_value, " fast=", fast)
	return true

func _start_external_attack(key: StringName, slot: StringName, context: StringName, full_body_value: bool, speed_value: float, blend_value: float, hips_value: float, start_fraction: float, fast: bool, action_metadata: Dictionary = {}, replacement_reason: StringName = &"replaced") -> bool:
	if external_bank == null or not external_bank.has_clip(key):
		return false
	if source_player != null:
		source_player.stop()
	if pose_bridge != null:
		pose_bridge.set_attack_weight(0.0, false, 0.0)
	var duration: float = external_bank.play(key, blend_value, speed_value, full_body_value, hips_value, start_fraction)
	if duration <= 0.0:
		return false
	_emit_current_action_finished(replacement_reason)
	attack_uses_external_donor = true
	current_attack_slot = slot
	current_attack_context = context
	current_attack_clip = StringName("external:%s" % String(key))
	attack_full_body = full_body_value
	attack_hips_weight = hips_value
	attack_speed = speed_value
	var profile: Dictionary = _attack_profile(slot, context, fast)
	attack_blend_in = float(profile.get("blend_in", 0.055))
	attack_blend_out = float(profile.get("blend_out", 0.10))
	current_attack_chain_point = float(profile.get("chain", 0.58))
	attack_duration = duration
	attack_timer = duration
	current_action_metadata = _normalize_action_metadata(slot, context, action_metadata)
	combat_action_started.emit(current_action_metadata.duplicate(true))
	if _verbose_diagnostics():
		print("[UAL NATIVE] EXTERNAL ATTACK ", slot, "/", context, " -> ", key, " duration=", snappedf(duration, 0.001))
	return true

func _set_active_attack_weight(value: float, full_body_value: bool, hips_value: float) -> void:
	if attack_uses_external_donor and external_bank != null:
		external_bank.set_weight(value, full_body_value, hips_value)
	elif pose_bridge != null:
		pose_bridge.set_attack_weight(value, full_body_value, hips_value)

func _finish_attack(reason: StringName = &"cancelled") -> void:
	var cancelled_actions: Array[Dictionary] = []
	for queued: Dictionary in attack_queue:
		var metadata := queued.get("metadata", {}) as Dictionary
		if not metadata.is_empty():
			cancelled_actions.append(metadata.duplicate(true))
	_emit_current_action_finished(reason)
	if external_bank != null:
		external_bank.stop()
	attack_uses_external_donor = false
	current_attack_slot = StringName()
	current_attack_context = &"idle"
	current_attack_clip = StringName()
	attack_timer = 0.0
	attack_duration = 0.0
	attack_full_body = false
	attack_hips_weight = 0.0
	attack_queue.clear()
	if not cancelled_actions.is_empty() or reason != &"finished":
		combat_actions_cancelled.emit(cancelled_actions, reason)
	if not charge_active and source_player != null:
		source_player.stop()
	if pose_bridge != null and not charge_active:
		pose_bridge.set_attack_weight(0.0, false, 0.0)

func _attack_profile(slot: StringName, context: StringName, fast: bool = false) -> Dictionary:
	var result: Dictionary
	match slot:
		&"light1": result = {"speed": 1.55, "blend": 0.040, "blend_in": 0.028, "blend_out": 0.055, "chain": 0.30, "hips": 0.30, "full_body": false}
		&"light2": result = {"speed": 1.62, "blend": 0.038, "blend_in": 0.026, "blend_out": 0.052, "chain": 0.28, "hips": 0.38, "full_body": false}
		&"light3": result = {"speed": 1.48, "blend": 0.042, "blend_in": 0.030, "blend_out": 0.065, "chain": 0.40, "hips": 0.52, "full_body": false}
		&"heavy": result = {"speed": 0.92, "blend": 0.085, "blend_in": 0.055, "blend_out": 0.12, "chain": 0.78, "hips": 0.64, "full_body": false}
		&"spin360": result = {"speed": 1.08, "blend": 0.06, "blend_in": 0.04, "blend_out": 0.08, "chain": 0.78, "hips": 1.0, "full_body": true}
		_: result = {"speed": 1.0, "blend": 0.06, "blend_in": 0.05, "blend_out": 0.10, "chain": 0.58, "hips": 0.40, "full_body": false}

	if context == &"run":
		result["speed"] = float(result["speed"]) * 1.05
		result["hips"] = maxf(float(result["hips"]), 0.48)
	elif context == &"air":
		result["speed"] = float(result["speed"]) * 1.04
		result["full_body"] = true
		result["hips"] = 1.0
	elif context == &"dash":
		result["speed"] = float(result["speed"]) * 1.10
		result["full_body"] = true
		result["hips"] = 0.90
	elif context == &"slide":
		# Keep the slide in the lower body and layer a fast low/wide sword motion
		# over it. This gives slide attacks their own readable silhouette.
		result["speed"] = float(result["speed"]) * 1.16
		result["full_body"] = false
		result["hips"] = maxf(float(result["hips"]), 0.42)
		result["blend"] = minf(float(result["blend"]), 0.045)
		result["blend_in"] = minf(float(result["blend_in"]), 0.035)
		result["chain"] = minf(float(result["chain"]), 0.46)
	elif context == &"wall":
		# Wall movement owns the lower body. Sword attacks and held heavy charges
		# remain readable upper-body layers without twisting the run pose off-wall.
		result["speed"] = float(result["speed"]) * 1.08
		result["full_body"] = false
		result["hips"] = 0.12
		result["blend"] = minf(float(result["blend"]), 0.045)
		result["blend_in"] = minf(float(result["blend_in"]), 0.035)
	if fast:
		result["speed"] = float(result["speed"]) * 1.30
		result["blend"] = 0.035
		result["blend_in"] = 0.025
		result["chain"] = 0.52
	return result

func play_full_body(slot: StringName) -> bool:
	if not configured or not slot_map.has(slot):
		return false
	var clip: StringName = StringName(slot_map[slot])
	if clip == StringName() or not target_player.has_animation(clip):
		return false
	var state_name: StringName = _full_state_name_for_slot(slot)
	if state_name == StringName():
		return false
	full_body_playback.start(state_name)
	var anim: Animation = target_player.get_animation(clip)
	full_body_duration = maxf(anim.length, 0.12)
	full_body_timer = full_body_duration
	animation_tree.set("parameters/FullBodyBlend/blend_amount", 0.001)
	return true

func stop_full_body() -> void:
	if not configured or animation_tree == null:
		return
	full_body_timer = 0.0
	full_body_duration = 0.0
	animation_tree.set("parameters/FullBodyBlend/blend_amount", 0.0)

func current_full_body_duration() -> float:
	return full_body_duration

func is_attack_active() -> bool:
	return attack_timer > 0.0 or charge_active

func is_heavy_charging() -> bool:
	return charge_active

func current_attack_is_heavy() -> bool:
	return current_attack_slot == &"heavy" or current_attack_slot == &"spin360" or current_attack_slot == &"charge"

func current_attack_length() -> float:
	return attack_duration

func current_attack_slot_name() -> StringName:
	return current_attack_slot

func current_attack_context_name() -> StringName:
	return current_attack_context


func current_combat_action_metadata() -> Dictionary:
	return current_action_metadata.duplicate(true)


func current_action_blocks(capability: StringName) -> bool:
	var blocked_capabilities := current_action_metadata.get(&"blocked_capabilities", []) as Array
	return blocked_capabilities.has(capability)


func current_attack_progress() -> float:
	if attack_duration <= 0.001 or attack_timer <= 0.0:
		return 0.0
	return clampf(1.0 - attack_timer / attack_duration, 0.0, 1.0)

func preview_next() -> String:
	if attack_candidates.is_empty():
		return ""
	preview_index = (preview_index + 1) % attack_candidates.size()
	return String(attack_candidates[preview_index])

func preview_prev() -> String:
	if attack_candidates.is_empty():
		return ""
	preview_index -= 1
	if preview_index < 0:
		preview_index = attack_candidates.size() - 1
	return String(attack_candidates[preview_index])

func preview_current() -> String:
	if attack_candidates.is_empty():
		return ""
	return String(attack_candidates[preview_index])

func preview_play() -> bool:
	if attack_candidates.is_empty():
		return false
	var clip: StringName = attack_candidates[preview_index]
	if not source_player.has_animation(clip):
		return false
	_finish_attack()
	source_player.play(clip)
	current_attack_slot = &"preview"
	current_attack_clip = clip
	var anim: Animation = source_player.get_animation(clip)
	attack_duration = maxf(anim.length, 0.12)
	attack_timer = attack_duration
	attack_full_body = true
	if pose_bridge != null:
		pose_bridge.set_attack_weight(0.001, true, 1.0)
	if _verbose_diagnostics():
		print("[UAL NATIVE PREVIEW FULL BODY] ", clip)
	return true

func slot_debug() -> String:
	var keys: Array[StringName] = [&"idle", &"walk", &"run", &"light1", &"light2", &"light3", &"heavy", &"spin360", &"jump", &"dash", &"slide_start", &"slide_loop", &"slide_exit", &"ninja_jump_start", &"roll"]
	var parts: Array[String] = []
	for key: StringName in keys:
		var value: StringName = StringName(slot_map.get(key, StringName()))
		parts.append("%s=%s" % [String(key), String(value)])
	return " | ".join(parts)

func debug_summary() -> String:
	if not configured:
		return "UAL NATIVE=OFF"
	var bridge_mode: String = "FULL" if attack_full_body and attack_timer > 0.0 else "UPPER"
	if charge_active:
		bridge_mode = "CHARGE"
	elif slide_visual_active or slide_visual_phase == &"exit":
		bridge_mode = "SLIDE:" + String(slide_visual_phase)
	elif donor_action_timer > 0.0:
		bridge_mode = "MOVE:" + String(donor_action_slot)
	return "UAL speed=%.2f action=%s/%s clip=%s mode=%s preview=%s" % [speed_blend, String(current_attack_slot), String(current_attack_context), String(current_attack_clip), bridge_mode, preview_current()]

func _build_slot_map() -> void:
	slot_map.clear()
	var target_names: PackedStringArray = target_player.get_animation_list()
	slot_map[&"idle"] = _exact_or_best(target_names, "Idle", ["idle"], ["talk", "torch", "crouch"])
	slot_map[&"walk"] = _exact_or_best(target_names, "Jog_Fwd", ["jog", "fwd"], ["crouch", "back"])
	slot_map[&"run"] = _exact_or_best(target_names, "Sprint", ["sprint"], ["enter", "exit"])
	if StringName(slot_map[&"run"]) == StringName():
		slot_map[&"run"] = slot_map[&"walk"]
	slot_map[&"jump"] = _exact_or_best(target_names, "Jump_Start", ["jump", "start"], ["attack"])
	slot_map[&"dash"] = _exact_or_best(target_names, "Roll", ["roll"], ["rm"])
	# UAL1 has no slide. Exact slide and NinjaJump_Start live in UAL2 and are
	# retargeted by movement_pose_bridge. No crouch fallback anymore.
	slot_map[&"roll"] = _exact_or_best(target_names, "Roll", ["roll"], ["rm"])
	if StringName(slot_map[&"roll"]) == StringName():
		slot_map[&"roll"] = slot_map[&"dash"]

	attack_candidates.clear()
	var source_names: PackedStringArray = source_player.get_animation_list()
	slot_map[&"slide_start"] = _first_existing(source_names, ["Slide_Start"])
	slot_map[&"slide_loop"] = _first_existing(source_names, ["Slide"])
	slot_map[&"slide_exit"] = _first_existing(source_names, ["Slide_Exit"])
	slot_map[&"ninja_jump_start"] = _first_existing(source_names, ["NinjaJump_Start"])
	slot_map[&"ninja_jump_idle"] = _first_existing(source_names, ["NinjaJump_Idle"])
	for raw_name: String in source_names:
		var low: String = raw_name.to_lower()
		if "sword" in low or _contains_any(low, ["attack", "combo", "slash", "melee", "strike", "spin", "swing", "stab", "thrust", "heavy"]):
			attack_candidates.append(StringName(raw_name))
	if attack_candidates.is_empty():
		for raw_name: String in source_names:
			attack_candidates.append(StringName(raw_name))

	slot_map[&"light1"] = _first_existing(source_names, ["Sword_Regular_A", "Sword_Attack_A", "Sword_A"])
	slot_map[&"light2"] = _first_existing(source_names, ["Sword_Regular_B", "Sword_Attack_B", "Sword_B"])
	slot_map[&"light3"] = _first_existing(source_names, ["Sword_Regular_C", "Sword_Attack_C", "Sword_C"])
	# Stable temporary semantics while dedicated authored Heavy/spiral clips are
	# being sourced. The runtime selectors below use the same explicit order.
	slot_map[&"heavy"] = _first_existing(source_names, ["Sword_Regular_C", "Sword_Regular_Combo"])
	slot_map[&"spin360"] = _first_existing(source_names, ["Sword_Regular_A", "Sword_Regular_B"])
	_rebuild_variant_pools()
	_build_movement_pools(source_names)
	if attack_candidates.size() > 0:
		preview_index = 0

func _rebuild_variant_pools() -> void:
	variant_pools.clear()
	var families: Array[StringName] = [&"light1", &"light2", &"light3", &"heavy", &"spin360"]
	var contexts: Array[StringName] = [&"idle", &"run", &"air", &"dash", &"slide"]
	for family: StringName in families:
		for context: StringName in contexts:
			var key: String = _pool_key(family, context)
			variant_pools[key] = _rank_attack_pool(family, context, 4)

func _build_movement_pools(source_names: PackedStringArray) -> void:
	movement_pools.clear()
	var all_names: Array[StringName] = []
	for raw_name: String in source_names:
		all_names.append(StringName(raw_name))
	movement_pools["vault"] = _rank_generic_pool(all_names, ["vault", "obstacle", "parkour", "jump_over", "jump over", "hurdle"], ["attack", "hit", "death"], 4)
	var vault_pool: Array = movement_pools.get("vault", [])
	if vault_pool.is_empty():
		movement_pools["vault"] = _rank_generic_pool(all_names, ["jump", "roll", "dodge"], ["attack", "hit", "death", "idle"], 3)

	movement_pools["climb"] = _rank_generic_pool(all_names, ["climb", "mantle", "ledge", "wall", "pullup", "pull_up", "ledge_up"], ["attack", "hit", "death"], 4)
	var climb_pool: Array = movement_pools.get("climb", [])
	if climb_pool.is_empty():
		movement_pools["climb"] = _rank_generic_pool(all_names, ["jump", "reach", "pull"], ["attack", "hit", "death", "idle"], 3)

func _choose_attack_variant(family: StringName, context: StringName) -> StringName:
	# Until dedicated authored clips are imported, stable semantic fallbacks beat
	# the old heuristic: Heavy always uses the vertical finisher, and a spiral is
	# never replaced by Sword_Dash_RM or the three-second regular combo.
	if family == &"heavy":
		return _first_existing_attack_clip([&"Sword_Regular_C", &"Sword_Regular_Combo"])
	if family == &"spin360":
		return _first_existing_attack_clip([&"Sword_Regular_A", &"Sword_Regular_B"])
	var key: String = _pool_key(family, context)
	var pool: Array = variant_pools.get(key, [])
	if pool.is_empty():
		pool = variant_pools.get(_pool_key(family, &"idle"), [])
	if pool.is_empty():
		return StringName(slot_map.get(family, StringName()))
	# Context may deliberately change the authored clip, but identical gameplay
	# state/input must never produce a random swing direction or timing.
	return StringName(pool[0])

func _first_existing_attack_clip(candidates: Array) -> StringName:
	if source_player == null:
		return StringName()
	for candidate: Variant in candidates:
		var clip := StringName(candidate)
		if source_player.has_animation(clip):
			return clip
	return StringName()

func _choose_movement_variant(slot: StringName) -> StringName:
	var pool: Array = movement_pools.get(String(slot), [])
	if pool.is_empty():
		return StringName()
	return StringName(pool[0])

func _rank_attack_pool(family: StringName, context: StringName, limit: int) -> Array[StringName]:
	var scored: Array[Dictionary] = []
	for clip: StringName in attack_candidates:
		var low: String = String(clip).to_lower()
		if _contains_any(low, ["_rec", "recovery", "knockback", "hit_", "/hit", "block", "parry", "death", "receive"]):
			continue
		var score: int = 0
		if "sword" in low:
			score += 20
		match family:
			&"light1":
				if "sword_regular_a" in low or "sword_attack_a" in low:
					score += 90
				if "slash" in low or "regular" in low:
					score += 18
				if "combo" in low:
					score -= 10
			&"light2":
				if "sword_regular_b" in low or "sword_attack_b" in low:
					score += 90
				if "reverse" in low or "regular" in low:
					score += 18
				if "combo" in low:
					score -= 8
			&"light3":
				if "sword_regular_c" in low or "sword_attack_c" in low:
					score += 90
				if "overhead" in low or "vertical" in low or "regular" in low:
					score += 20
				if "combo" in low:
					score -= 5
			&"heavy":
				if _contains_any(low, ["heavy", "power", "strong", "charged", "overhead", "smash"]):
					score += 72
				if "sword_regular_c" in low:
					score += 18
				if "combo" in low:
					score += 6
			&"spin360":
				if _contains_any(low, ["spin", "360", "whirl", "round", "wide"]):
					score += 82
				if "combo" in low:
					score += 20
				if "regular" in low:
					score += 8

		match context:
			&"idle":
				if _contains_any(low, ["dash", "run", "sprint", "air", "aerial", "jump"]):
					score -= 22
			&"run":
				if _contains_any(low, ["run", "sprint", "forward", "fwd"]):
					score += 72
				if "dash" in low:
					score += 28
				if _contains_any(low, ["air", "aerial", "jump"]):
					score -= 22
			&"air":
				if _contains_any(low, ["air", "aerial", "jump", "fall"]):
					score += 110
				if "dash" in low:
					score += 8
			&"dash":
				if "dash" in low:
					score += 120
				if "rm" in low:
					score += 8
				if _contains_any(low, ["air", "aerial"]):
					score -= 10
			&"slide":
				if _contains_any(low, ["slide", "low", "sweep", "wide", "run", "sprint", "dash"]):
					score += 76
				if _contains_any(low, ["air", "aerial", "jump", "overhead"]):
					score -= 24
		if score > 5:
			scored.append({"clip": clip, "score": score})
	scored.sort_custom(_sort_score_desc)
	var result: Array[StringName] = []
	for item: Dictionary in scored:
		var clip: StringName = StringName(item["clip"])
		if not result.has(clip):
			result.append(clip)
		if result.size() >= limit:
			break
	# Manual/default slot is always a valid fallback and also adds variety.
	var manual: StringName = StringName(slot_map.get(family, StringName()))
	if manual != StringName() and source_player.has_animation(manual) and not result.has(manual):
		result.append(manual)
	if result.size() > limit:
		result.resize(limit)
	return result

func _rank_generic_pool(names: Array[StringName], positives: Array, negatives: Array, limit: int) -> Array[StringName]:
	var scored: Array[Dictionary] = []
	for clip: StringName in names:
		var low: String = String(clip).to_lower()
		var score: int = 0
		for p: Variant in positives:
			if String(p).to_lower() in low:
				score += 20
		for n: Variant in negatives:
			if String(n).to_lower() in low:
				score -= 30
		if score > 0:
			scored.append({"clip": clip, "score": score})
	scored.sort_custom(_sort_score_desc)
	var result: Array[StringName] = []
	for item: Dictionary in scored:
		var clip: StringName = StringName(item["clip"])
		if not result.has(clip):
			result.append(clip)
		if result.size() >= limit:
			break
	return result

func _best_family_clip(family: StringName, context: StringName) -> StringName:
	var pool: Array[StringName] = _rank_attack_pool(family, context, 1)
	if pool.is_empty():
		return StringName()
	return pool[0]

func _pool_key(family: StringName, context: StringName) -> String:
	return String(family) + "|" + String(context)

func _print_variant_summary() -> void:
	for key: Variant in variant_pools.keys():
		var pool: Array = variant_pools[key]
		var names: Array[String] = []
		for value: Variant in pool:
			names.append(String(value))
		if _verbose_diagnostics():
			print("[UAL VARIANTS] ", String(key), " = ", ", ".join(names))
	for key: Variant in movement_pools.keys():
		var pool: Array = movement_pools[key]
		var names: Array[String] = []
		for value: Variant in pool:
			names.append(String(value))
		if _verbose_diagnostics():
			print("[UAL PARKOUR] ", String(key), " = ", ", ".join(names))

func _verbose_diagnostics() -> bool:
	return bool(ProjectSettings.get_setting(VERBOSE_SETTING, false))

func _build_locomotion_tree() -> bool:
	var idle_clip: StringName = StringName(slot_map.get(&"idle", StringName()))
	var walk_clip: StringName = StringName(slot_map.get(&"walk", StringName()))
	var run_clip: StringName = StringName(slot_map.get(&"run", StringName()))
	if idle_clip == StringName() or run_clip == StringName():
		push_error("[UAL NATIVE] Idle/Run clips missing")
		return false
	if walk_clip == StringName():
		walk_clip = run_clip
	for clip: StringName in [idle_clip, walk_clip, run_clip]:
		var anim: Animation = target_player.get_animation(clip)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR

	locomotion_space = AnimationNodeBlendSpace1D.new()
	locomotion_space.min_space = 0.0
	locomotion_space.max_space = 1.0
	locomotion_space.snap = 0.01
	locomotion_space.value_label = "speed"
	locomotion_space.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	locomotion_space.add_blend_point(_anim_node(idle_clip), 0.0, -1, &"Idle")
	locomotion_space.add_blend_point(_anim_node(walk_clip), 0.48, -1, &"Jog")
	locomotion_space.add_blend_point(_anim_node(run_clip), 1.0, -1, &"Sprint")

	full_body_machine = AnimationNodeStateMachine.new()
	_add_full_state(&"Jump", &"jump")
	_add_full_state(&"Dash", &"dash")
	_add_full_state(&"Roll", &"roll")
	full_body_blend = AnimationNodeBlend2.new()

	tree_root = AnimationNodeBlendTree.new()
	tree_root.add_node("Locomotion", locomotion_space, Vector2(0, 0))
	tree_root.add_node("FullBodySM", full_body_machine, Vector2(250, 220))
	tree_root.add_node("FullBodyBlend", full_body_blend, Vector2(520, 60))
	tree_root.connect_node("FullBodyBlend", 0, "Locomotion")
	tree_root.connect_node("FullBodyBlend", 1, "FullBodySM")
	tree_root.connect_node("output", 0, "FullBodyBlend")

	animation_tree = AnimationTree.new()
	animation_tree.name = "NativeUALAnimationTree"
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(target_player)
	animation_tree.tree_root = tree_root
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	target_player.stop()
	animation_tree.active = true
	animation_tree.set("parameters/Locomotion/blend_position", 0.0)
	animation_tree.set("parameters/FullBodyBlend/blend_amount", 0.0)
	full_body_playback = animation_tree.get("parameters/FullBodySM/playback") as AnimationNodeStateMachinePlayback
	if full_body_playback == null:
		push_error("[UAL NATIVE] full body playback missing")
		return false
	return true

func _add_full_state(state_name: StringName, slot: StringName) -> void:
	var clip: StringName = StringName(slot_map.get(slot, StringName()))
	if clip == StringName():
		clip = StringName(slot_map.get(&"idle", StringName()))
	full_body_machine.add_node(state_name, _anim_node(clip), Vector2(float(full_body_machine.get_node_list().size()) * 170.0, 0.0))

func _full_state_name_for_slot(slot: StringName) -> StringName:
	match slot:
		&"jump": return &"Jump"
		&"dash": return &"Dash"
		&"roll": return &"Roll"
		_: return StringName()

func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = clip
	return node

func _first_existing(names: PackedStringArray, candidates: Array[String]) -> StringName:
	for wanted: String in candidates:
		for raw_name: String in names:
			if raw_name == wanted or raw_name.ends_with("/" + wanted):
				return StringName(raw_name)
	return StringName()

func _exact_or_best(names: PackedStringArray, exact: String, positives: Array, negatives: Array) -> StringName:
	for raw_name: String in names:
		if raw_name == exact or raw_name.ends_with("/" + exact):
			return StringName(raw_name)
	var best: StringName = StringName()
	var best_score: int = -99999
	for raw_name: String in names:
		var low: String = raw_name.to_lower()
		var score: int = 0
		for term_value: Variant in positives:
			if String(term_value).to_lower() in low:
				score += 10
		for term_value: Variant in negatives:
			if String(term_value).to_lower() in low:
				score -= 18
		if score > best_score:
			best_score = score
			best = StringName(raw_name)
	return best if best_score > 0 else StringName()

func _sort_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))

func _contains_any(text: String, terms: Array) -> bool:
	for term_value: Variant in terms:
		if String(term_value).to_lower() in text:
			return true
	return false

func _disable_animation_trees(node: Node) -> void:
	if node is AnimationTree:
		(node as AnimationTree).active = false
	for child: Node in node.get_children():
		_disable_animation_trees(child)

func _find_best_animation_player(root: Node) -> AnimationPlayer:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	var best: AnimationPlayer = null
	var best_count: int = -1
	for player: AnimationPlayer in players:
		var count: int = player.get_animation_list().size()
		if count > best_count:
			best_count = count
			best = player
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
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
