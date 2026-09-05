extends Node
class_name HopliteSharedAnimationDriver

const LIBRARY_VERSION := 4
const LIBRARY: AnimationLibrary = preload("res://assets/animations/hoplite_animation_library_v4.res")

static var _ready_reported: bool = false

const LOCOMOTION_IDLE := &"Idle"
const LOCOMOTION_JOG := &"Jog_Fwd"
const LOCOMOTION_SPRINT := &"Sprint"
const ACTION_CLIPS: Array[StringName] = [
	&"spear_thrust",
	&"spear_thrust_low",
	&"shield_bash",
	&"block_idle",
	&"block_impact",
]
const ACTION_SOURCE_CLIPS: Dictionary = {
	&"spear_thrust": &"spear_thrust",
	&"spear_thrust_low": &"spear_thrust_low",
	&"shield_bash": &"ual2_shield_one_shot",
	&"block_idle": &"ual2_idle_shield",
	&"block_impact": &"ual2_sword_block",
}
const ACTION_FILTER_BONES: Array[StringName] = [
	&"DEF-spine.001", &"DEF-spine.002", &"DEF-spine.003", &"DEF-neck", &"DEF-head",
	&"DEF-shoulder.L", &"DEF-upper_arm.L", &"DEF-forearm.L", &"DEF-hand.L",
	&"DEF-shoulder.R", &"DEF-upper_arm.R", &"DEF-forearm.R", &"DEF-hand.R",
	&"DEF-thumb.01.R",
]
var target_scene: Node
var target_skeleton: Skeleton3D
var target_player: AnimationPlayer
var animation_tree: AnimationTree
var tree_root: AnimationNodeBlendTree
var locomotion_space: AnimationNodeBlendSpace1D
var action_node: AnimationNodeAnimation

# Compatibility properties read by the generic enemy death shutdown path.
# Shared hoplites never create pose bridges or donor skeletons.
var movement_pose_bridge: Node = null
var pose_bridge: Node = null

var current_attack_clip: StringName = StringName()
var current_attack_slot: StringName = StringName()
var current_attack_context: StringName = StringName()
var attack_timer: float = 0.0
var attack_duration: float = 0.0
var attack_blend_in: float = 0.045
var attack_blend_out: float = 0.12
var block_active: bool = false
var block_impact_timer: float = 0.0
var speed_blend: float = 0.0
var configured: bool = false
var simulation_lod: int = 0
var simulation_interval: float = 0.0
var simulation_accumulator: float = 0.0
var simulation_sample_count: int = 0


func _physics_process(delta: float) -> void:
	# Animation evaluation belongs to the driver itself, never to the enemy AI
	# budget. Static mannequins and dormant/cached enemies must keep a live pose.
	if not configured or animation_tree == null or not animation_tree.active or simulation_lod >= 3:
		return
	if simulation_interval <= 0.0:
		_advance_simulation(maxf(delta, 0.0))
		return
	simulation_accumulator += maxf(delta, 0.0)
	if simulation_accumulator >= simulation_interval:
		_advance_simulation(simulation_accumulator)
		simulation_accumulator = 0.0


func configure(
	visible_scene: Node,
	skeleton: Skeleton3D,
	player: AnimationPlayer,
	_enable_external_bank: bool = true,
	_external_keys: Array = [],
	_enable_wall_movement: bool = false,
	_profile_id: StringName = StringName()
) -> bool:
	target_scene = visible_scene
	target_skeleton = skeleton
	target_player = player
	if target_skeleton == null or target_player == null:
		push_error("[HOPLITE SHARED ANIMATION] target skeleton/player missing")
		return false
	if target_skeleton.get_bone_count() != 53:
		push_error("[HOPLITE SHARED ANIMATION] canonical ngeneral rig must contain 53 bones")
		return false
	if not _validate_library():
		return false

	for library_name: StringName in target_player.get_animation_library_list():
		target_player.remove_animation_library(library_name)
	if target_player.add_animation_library(&"", LIBRARY) != OK:
		push_error("[HOPLITE SHARED ANIMATION] could not attach shared library")
		return false
	target_player.root_node = NodePath("..")
	if not _build_animation_tree():
		return false
	configured = true
	if not _ready_reported:
		print("[HOPLITE SHARED ANIMATION] READY library_v=", LIBRARY_VERSION, " clips=", LIBRARY.get_animation_list())
		_ready_reported = true
	return true


func tick(delta: float) -> void:
	if not configured or animation_tree == null:
		return
	if block_active:
		if block_impact_timer > 0.0:
			block_impact_timer = maxf(0.0, block_impact_timer - delta)
			if block_impact_timer <= 0.0:
				_start_action(&"block_idle", 1.0, 0.0)
		_set_action_blend(1.0)
		return

	if attack_timer <= 0.0:
		_set_action_blend(0.0)
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	var progress := current_attack_progress()
	var blend := 1.0
	if progress < attack_blend_in:
		blend = progress / maxf(attack_blend_in, 0.001)
	elif progress > 1.0 - attack_blend_out:
		blend = clampf((1.0 - progress) / maxf(attack_blend_out, 0.001), 0.0, 1.0)
	_set_action_blend(blend)
	if attack_timer <= 0.0:
		_finish_attack()

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


func set_locomotion(normalized_speed: float) -> void:
	if not configured:
		return
	speed_blend = clampf(normalized_speed, 0.0, 1.0)
	animation_tree.set("parameters/Locomotion/blend_position", speed_blend)


func begin_block() -> bool:
	if not configured:
		return false
	if block_active:
		return true
	_finish_attack()
	block_active = _start_action(&"block_idle", 1.0, 0.0)
	block_impact_timer = 0.0
	_set_action_blend(1.0 if block_active else 0.0)
	force_simulation_sample()
	return block_active


func end_block() -> void:
	if not block_active:
		return
	block_active = false
	block_impact_timer = 0.0
	current_attack_clip = StringName()
	_set_action_blend(0.0)


func play_block_impact() -> bool:
	if not block_active:
		return false
	var length := external_clip_length(&"block_impact")
	if length <= 0.0 or not _start_action(&"block_impact", 1.55, 0.0):
		return false
	block_impact_timer = length / 1.55
	_set_action_blend(1.0)
	force_simulation_sample()
	return true


func has_external_clip(key: StringName) -> bool:
	var source_clip := StringName(ACTION_SOURCE_CLIPS.get(key, StringName()))
	return (
		ACTION_CLIPS.has(key)
		and source_clip != StringName()
		and LIBRARY.has_animation(source_clip)
	)


func external_clip_length(key: StringName) -> float:
	var source_clip := StringName(ACTION_SOURCE_CLIPS.get(key, StringName()))
	var animation := LIBRARY.get_animation(source_clip) if has_external_clip(key) else null
	return animation.length if animation != null else 0.0


func play_external_attack(
	key: StringName,
	slot: StringName,
	context: StringName,
	_force_full_body: bool = false,
	custom_speed: float = -1.0,
	custom_blend: float = -1.0,
	_hips_weight: float = -1.0,
	_fast: bool = false,
	start_fraction: float = 0.0
) -> bool:
	if not configured or not has_external_clip(key):
		return false
	end_block()
	var speed := custom_speed if custom_speed > 0.0 else 1.0
	attack_blend_in = custom_blend if custom_blend >= 0.0 else 0.045
	attack_blend_out = 0.12
	current_attack_slot = slot
	current_attack_context = context
	# Preserve the public diagnostic contract used by the enemy probes and HUD.
	# The AnimationTree itself keeps using the bare library key.
	current_attack_clip = StringName("external:" + String(key))
	var source_length := external_clip_length(key)
	attack_duration = maxf(source_length * (1.0 - clampf(start_fraction, 0.0, 0.75)) / maxf(speed, 0.05), 0.10)
	attack_timer = attack_duration
	if not _start_action(key, speed, start_fraction):
		_finish_attack()
		return false
	_set_action_blend(0.001)
	force_simulation_sample()
	return true


func play_attack_variant(
	slot: StringName,
	context: StringName,
	force_full_body: bool = false,
	custom_speed: float = -1.0,
	custom_blend: float = -1.0,
	hips_weight: float = -1.0,
	fast: bool = false
) -> bool:
	var clip := &"spear_thrust_low" if slot == &"light1" else &"spear_thrust"
	return play_external_attack(clip, slot, context, force_full_body, custom_speed, custom_blend, hips_weight, fast)


func play_authored_attack(
	candidates: Array,
	custom_speed: float = 1.0,
	force_full_body: bool = false,
	hips_weight: float = 0.45
) -> bool:
	for raw_candidate: Variant in candidates:
		var candidate := StringName(raw_candidate)
		if has_external_clip(candidate):
			return play_external_attack(candidate, &"signature", &"idle", force_full_body, custom_speed, 0.06, hips_weight)
	return false


func stop_movement_action() -> void:
	pass


func stop_full_body() -> void:
	_finish_attack()
	end_block()


func current_attack_length() -> float:
	return attack_duration


func current_attack_progress() -> float:
	if attack_duration <= 0.001:
		return 0.0
	return clampf(1.0 - attack_timer / attack_duration, 0.0, 1.0)


func is_attack_active() -> bool:
	return attack_timer > 0.0


func _build_animation_tree() -> bool:
	locomotion_space = AnimationNodeBlendSpace1D.new()
	locomotion_space.min_space = 0.0
	locomotion_space.max_space = 1.0
	locomotion_space.snap = 0.01
	locomotion_space.value_label = "speed"
	# Each locomotion clip must keep its own playback clock. CYCLIC_MUTABLE can
	# pin runtime-built blend points to their first sample in Godot 4.7.
	locomotion_space.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_INDEPENDENT
	locomotion_space.add_blend_point(_animation_node(LOCOMOTION_IDLE), 0.0, -1, &"Idle")
	locomotion_space.add_blend_point(_animation_node(LOCOMOTION_JOG), 0.55, -1, &"Jog")
	locomotion_space.add_blend_point(_animation_node(LOCOMOTION_SPRINT), 1.0, -1, &"Sprint")

	action_node = _animation_node(StringName(ACTION_SOURCE_CLIPS[&"spear_thrust"]))
	var action_seek := AnimationNodeTimeSeek.new()
	var action_speed := AnimationNodeTimeScale.new()
	var action_blend := AnimationNodeBlend2.new()
	action_blend.sync = false
	action_blend.filter_enabled = true
	for bone_name: StringName in ACTION_FILTER_BONES:
		action_blend.set_filter_path(NodePath(".:%s" % bone_name), true)
	tree_root = AnimationNodeBlendTree.new()
	tree_root.add_node(&"Locomotion", locomotion_space, Vector2(0.0, 0.0))
	tree_root.add_node(&"Action", action_node, Vector2(240.0, 180.0))
	tree_root.add_node(&"ActionSeek", action_seek, Vector2(420.0, 180.0))
	tree_root.add_node(&"ActionSpeed", action_speed, Vector2(600.0, 180.0))
	tree_root.add_node(&"ActionBlend", action_blend, Vector2(700.0, 0.0))
	tree_root.connect_node(&"ActionSeek", 0, &"Action")
	tree_root.connect_node(&"ActionSpeed", 0, &"ActionSeek")
	tree_root.connect_node(&"ActionBlend", 0, &"Locomotion")
	tree_root.connect_node(&"ActionBlend", 1, &"ActionSpeed")
	tree_root.connect_node(&"output", 0, &"ActionBlend")

	animation_tree = AnimationTree.new()
	animation_tree.name = "HopliteAnimationTree"
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(target_player)
	animation_tree.tree_root = tree_root
	# The driver advances the tree from its own `_physics_process()`. Keeping the
	# mixer manual prevents Godot from evaluating it a second time.
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	target_player.stop()
	animation_tree.active = true
	animation_tree.set("parameters/Locomotion/blend_position", 0.0)
	animation_tree.set("parameters/ActionBlend/blend_amount", 0.0)
	animation_tree.set("parameters/ActionSpeed/scale", 1.0)
	animation_tree.advance(0.0)
	simulation_sample_count += 1
	return true


func _start_action(clip: StringName, speed: float, start_fraction: float) -> bool:
	if action_node == null or not has_external_clip(clip):
		return false
	var source_clip := StringName(ACTION_SOURCE_CLIPS[clip])
	_set_action_blend(0.001)
	action_node.animation = source_clip
	animation_tree.set("parameters/ActionSpeed/scale", maxf(speed, 0.05))
	var animation := LIBRARY.get_animation(source_clip)
	var source_offset := animation.length * clampf(start_fraction, 0.0, 0.75) if animation != null else 0.0
	# Seek requests are consumed only while their branch has weight. The tiny
	# blend above guarantees a one-shot reset without seeking locomotion forever.
	animation_tree.set("parameters/ActionSeek/seek_request", source_offset)
	animation_tree.advance(0.0)
	return true


func _finish_attack() -> void:
	attack_timer = 0.0
	attack_duration = 0.0
	current_attack_slot = StringName()
	current_attack_context = StringName()
	current_attack_clip = StringName()
	_set_action_blend(0.0)


func _set_action_blend(value: float) -> void:
	if animation_tree != null:
		var blend := clampf(value, 0.0, 1.0)
		animation_tree.set("parameters/ActionBlend/blend_amount", blend)


func _animation_node(clip: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip
	return node


func _validate_library() -> bool:
	for clip: StringName in [LOCOMOTION_IDLE, LOCOMOTION_JOG, LOCOMOTION_SPRINT, &"Death01"]:
		if not LIBRARY.has_animation(clip):
			push_error("[HOPLITE SHARED ANIMATION] missing core clip: %s" % clip)
			return false
	for clip: StringName in ACTION_CLIPS:
		var source_clip := StringName(ACTION_SOURCE_CLIPS.get(clip, StringName()))
		if source_clip == StringName() or not LIBRARY.has_animation(source_clip):
			push_error("[HOPLITE SHARED ANIMATION] missing action source for %s: %s" % [clip, source_clip])
			return false
	return true
