extends SceneTree

const BridgeScript = preload("res://scripts/animation/authored_pose_bridge.gd")
const HumanoidRetargetScript = preload("res://scripts/animation/humanoid_retarget_proxy.gd")

const CANONICAL_SCENE := "res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb"
const UAL1_SCENE := "res://assets/runtime/ual1/UAL1_Standard.glb"
const UAL2_SCENE := "res://assets/runtime/ual2/UAL2_Standard.glb"
const LANCER_SCENE := "res://assets/animations/sources/lancier_attack_animation_test.glb"
const LANCER_SOURCE_CLIP := &"SPARTAN_SkeletonAction"
const LANCER_RIGHT_ARM_CLIP := &"lancer_right_arm_thrust"
const BAYONET_SCENE := "res://assets/animations/source_packs/spear/Bayonet_Stab.fbx"
const BAYONET_SOURCE_CLIP := &"mixamo_com"
const BAYONET_OUTPUT_CLIP := &"spear_bayonet_step"
const OUTPUT_PATH := "res://assets/animations/hoplite_animation_library_v4.res"
const V2_OUTPUT_PATH := "res://assets/animations/enemy_v2/hoplite/hoplite_v2_source_53.res"
const SAMPLE_FPS := 30.0

const UAL1_CLIPS: Dictionary = {
	&"Idle": &"Idle",
	&"Jog_Fwd": &"Jog_Fwd",
	&"Sprint": &"Sprint",
	&"Death01": &"Death01",
}

const UAL2_CLIPS: Dictionary = {
	&"ual2_idle_shield": &"Idle_Shield",
	&"ual2_shield_one_shot": &"Shield_OneShot",
	&"ual2_sword_block": &"Sword_Block",
}

const ACTION_ALIASES: Dictionary = {
	&"shield_bash": &"ual2_shield_one_shot",
	&"block_idle": &"ual2_idle_shield",
	&"block_impact": &"ual2_sword_block",
}

const SPEAR_COMPOSITES: Dictionary = {
	&"spear_thrust": &"ual2_shield_one_shot",
	&"spear_thrust_low": &"ual2_sword_block",
}

const LOOPING_CLIPS: Dictionary = {
	&"Idle": true,
	&"Jog_Fwd": true,
	&"Sprint": true,
	&"ual2_idle_shield": true,
	&"block_idle": true,
}

const ACTION_BONES: Dictionary = {
	&"DEF-spine.001": true,
	&"DEF-spine.002": true,
	&"DEF-spine.003": true,
	&"DEF-neck": true,
	&"DEF-head": true,
	&"DEF-shoulder.L": true,
	&"DEF-upper_arm.L": true,
	&"DEF-forearm.L": true,
	&"DEF-hand.L": true,
	&"DEF-shoulder.R": true,
	&"DEF-upper_arm.R": true,
	&"DEF-forearm.R": true,
	&"DEF-hand.R": true,
}

const LANCER_RIGHT_ARM_BONES: Dictionary = {
	&"DEF-upper_arm.R": true,
	&"DEF-forearm.R": true,
	&"DEF-hand.R": true,
	&"DEF-thumb.01.R": true,
}

const LEFT_GUARD_BONES: Dictionary = {
	&"DEF-shoulder.L": true,
	&"DEF-upper_arm.L": true,
	&"DEF-forearm.L": true,
	&"DEF-hand.L": true,
}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var v2_mode := "--v2" in OS.get_cmdline_user_args()
	var output_path := V2_OUTPUT_PATH if v2_mode else OUTPUT_PATH
	var canonical_root := _instantiate_scene(CANONICAL_SCENE)
	if canonical_root == null:
		quit(1)
		return
	get_root().add_child(canonical_root)
	var canonical_skeleton := _find_skeleton(canonical_root)
	if canonical_skeleton == null or canonical_skeleton.get_bone_count() != 53:
		push_error("[HOPLITE LIBRARY BUILD] canonical ngeneral skeleton is missing or no longer has 53 bones")
		canonical_root.free()
		quit(1)
		return

	var library := AnimationLibrary.new()
	var failures: int = 0
	failures += _bake_scene_clips(library, canonical_skeleton, UAL1_SCENE, UAL1_CLIPS, true, false)
	failures += _bake_scene_clips(library, canonical_skeleton, UAL2_SCENE, UAL2_CLIPS, false, true)
	if v2_mode:
		failures += await _bake_mixamo_full_body_clip(
			library,
			canonical_skeleton,
			BAYONET_SCENE,
			BAYONET_SOURCE_CLIP,
			BAYONET_OUTPUT_CLIP
		)
	failures += _extract_lancer_right_arm_clip(library, canonical_skeleton)
	failures += _add_spear_composites(library, v2_mode)
	failures += _add_action_aliases(library)

	if failures == 0:
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
		if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
			push_error("[HOPLITE LIBRARY BUILD] could not create output directory: %s" % error_string(directory_error))
			failures += 1
		else:
			var save_error := ResourceSaver.save(library, output_path)
			if save_error != OK:
				push_error("[HOPLITE LIBRARY BUILD] save failed: %s" % error_string(save_error))
				failures += 1
			else:
				print("[HOPLITE LIBRARY BUILD] mode=", "v2" if v2_mode else "v1", " saved=", output_path, " clips=", library.get_animation_list())

	canonical_root.free()
	quit(1 if failures > 0 else 0)


func _bake_mixamo_full_body_clip(
	library: AnimationLibrary,
	target_skeleton: Skeleton3D,
	source_path: String,
	source_clip: StringName,
	output_name: StringName
) -> int:
	var source_root := _instantiate_scene(source_path)
	if source_root == null:
		return 1
	get_root().add_child(source_root)
	var source_skeleton := _find_skeleton(source_root)
	var source_player := _find_animation_player(source_root)
	if source_skeleton == null or source_player == null or not source_player.has_animation(source_clip):
		push_error("[HOPLITE LIBRARY BUILD] incomplete Mixamo source: %s/%s" % [source_path, source_clip])
		source_root.free()
		return 1
	source_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var retarget: Dictionary = HumanoidRetargetScript.build(source_skeleton, source_player, target_skeleton)
	var proxy := retarget.get("proxy") as Skeleton3D
	if proxy == null:
		push_error("[HOPLITE LIBRARY BUILD] Mixamo retarget mapping failed: %s" % source_path)
		source_root.free()
		return 1
	var bridge := BridgeScript.new() as HopliteAuthoredPoseBridge
	bridge.name = "HopliteMixamoOfflineBakeBridge"
	target_skeleton.add_child(bridge)
	if not bridge.configure(proxy, true):
		push_error("[HOPLITE LIBRARY BUILD] Mixamo pose bridge failed: %s" % source_path)
		bridge.free()
		source_root.free()
		return 1
	bridge.set_rest_space_retarget(false)
	bridge.set_mixamo_runtime_guards(true, true)
	bridge.set_attack_weight(1.0, true, 1.0)
	var source_animation := source_player.get_animation(source_clip)
	var result := Animation.new()
	result.length = source_animation.length
	result.loop_mode = Animation.LOOP_NONE
	result.step = 1.0 / SAMPLE_FPS
	var tracks: Dictionary = {}
	for bone_index: int in range(target_skeleton.get_bone_count()):
		var track_index := result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(track_index, NodePath(".:%s" % target_skeleton.get_bone_name(bone_index)))
		result.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
		tracks[bone_index] = track_index
	var sample_count := maxi(2, ceili(source_animation.length * SAMPLE_FPS) + 1)
	source_player.play(source_clip)
	for sample_index: int in range(sample_count):
		var time := minf(float(sample_index) / SAMPLE_FPS, source_animation.length)
		source_player.seek(time, true)
		source_player.advance(0.0)
		# Let Godot's native RetargetModifier3D convert the Mixamo rest space,
		# then sample the already-converted proxy into the canonical UAL rig.
		await process_frame
		source_skeleton.force_update_all_bone_transforms()
		proxy.force_update_all_bone_transforms()
		target_skeleton.reset_bone_poses()
		bridge.call(&"_process_modification_with_delta", 0.0)
		for raw_bone_index: Variant in tracks:
			var bone_index := int(raw_bone_index)
			result.track_insert_key(
				int(tracks[bone_index]),
				time,
				target_skeleton.get_bone_pose_rotation(bone_index)
			)
	bridge.set_attack_weight(0.0, false, 0.0)
	source_player.stop()
	target_skeleton.reset_bone_poses()
	var add_error := library.add_animation(output_name, result)
	if add_error != OK:
		push_error("[HOPLITE LIBRARY BUILD] could not add Mixamo clip %s: %s" % [output_name, error_string(add_error)])
		bridge.free()
		source_root.free()
		return 1
	print("[HOPLITE LIBRARY CLIP] name=", output_name, " source=", source_path, " length=", snappedf(result.length, 0.001), " tracks=", result.get_track_count())
	bridge.free()
	source_root.free()
	return 0


func _bake_scene_clips(
	library: AnimationLibrary,
	target_skeleton: Skeleton3D,
	source_path: String,
	clips: Dictionary,
	rest_space_retarget: bool,
	actions_only: bool
) -> int:
	var source_root := _instantiate_scene(source_path)
	if source_root == null:
		return clips.size()
	get_root().add_child(source_root)
	var source_skeleton := _find_skeleton(source_root)
	var source_player := _find_animation_player(source_root)
	if source_skeleton == null or source_player == null:
		push_error("[HOPLITE LIBRARY BUILD] incomplete source: %s" % source_path)
		source_root.free()
		return clips.size()
	source_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

	var bridge := BridgeScript.new() as HopliteAuthoredPoseBridge
	bridge.name = "HopliteLibraryBakeBridge"
	target_skeleton.add_child(bridge)
	bridge.set_rest_space_retarget(rest_space_retarget)
	if not bridge.configure(source_skeleton, true):
		push_error("[HOPLITE LIBRARY BUILD] retarget mapping failed: %s" % source_path)
		bridge.free()
		source_root.free()
		return clips.size()

	var failures: int = 0
	for raw_output_name: Variant in clips:
		var output_name := StringName(raw_output_name)
		var source_name := StringName(clips[output_name])
		if not source_player.has_animation(source_name):
			push_error("[HOPLITE LIBRARY BUILD] %s is missing %s" % [source_path, source_name])
			failures += 1
			continue
		var animation := _sample_clip(
			target_skeleton,
			source_skeleton,
			source_player,
			bridge,
			source_name,
			actions_only,
			LOOPING_CLIPS.has(output_name)
		)
		if animation == null or library.add_animation(output_name, animation) != OK:
			push_error("[HOPLITE LIBRARY BUILD] failed to bake %s" % output_name)
			failures += 1

	bridge.free()
	source_root.free()
	return failures


func _extract_lancer_right_arm_clip(library: AnimationLibrary, canonical_skeleton: Skeleton3D) -> int:
	var source_root := _instantiate_lancer_animation_source()
	if source_root == null:
		return 1
	get_root().add_child(source_root)
	var source_skeleton := _find_skeleton(source_root)
	var source_player := _find_animation_player(source_root)
	if source_skeleton == null or source_player == null or not source_player.has_animation(LANCER_SOURCE_CLIP):
		push_error("[HOPLITE LIBRARY BUILD] lancer source rig or animation is missing")
		source_root.free()
		return 1
	if not _skeletons_match(canonical_skeleton, source_skeleton):
		push_error("[HOPLITE LIBRARY BUILD] lancer source is not the canonical 53-bone hoplite rig")
		source_root.free()
		return 1

	var source_animation := source_player.get_animation(LANCER_SOURCE_CLIP)
	var result := source_animation.duplicate(true) as Animation
	var kept_tracks := 0
	var forearm_position_found := false
	for track_index: int in range(result.get_track_count() - 1, -1, -1):
		var track_path := result.track_get_path(track_index)
		var bone_name := StringName(track_path.get_subname(track_path.get_subname_count() - 1)) if track_path.get_subname_count() > 0 else StringName()
		var track_type := result.track_get_type(track_index)
		if not LANCER_RIGHT_ARM_BONES.has(bone_name) or track_type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
			result.remove_track(track_index)
			continue
		result.track_set_path(track_index, NodePath(".:%s" % bone_name))
		kept_tracks += 1
		if bone_name == &"DEF-forearm.R" and track_type == Animation.TYPE_POSITION_3D:
			forearm_position_found = true
	result.loop_mode = Animation.LOOP_NONE
	if kept_tracks != 5 or not forearm_position_found:
		push_error("[HOPLITE LIBRARY BUILD] expected five lancer right-arm tracks including forearm position; got %s" % kept_tracks)
		source_root.free()
		return 1
	var add_error := library.add_animation(LANCER_RIGHT_ARM_CLIP, result)
	if add_error != OK:
		push_error("[HOPLITE LIBRARY BUILD] could not add lancer right-arm clip: %s" % error_string(add_error))
		source_root.free()
		return 1
	print("[HOPLITE LIBRARY CLIP] name=", LANCER_RIGHT_ARM_CLIP, " length=", snappedf(result.length, 0.001), " tracks=", kept_tracks)
	source_root.free()
	return 0


func _instantiate_lancer_animation_source() -> Node:
	# This source folder is .gdignore'd on purpose: Godot must never import the
	# Blender mesh, materials or embedded textures as runtime resources. The
	# offline builder asks GLTFDocument for animation/skeleton data only.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var flags := GLTFDocument.IMPORT_FLAG_DISCARD_MESHES_AND_MATERIALS | GLTFDocument.IMPORT_FLAG_USE_NAMED_SKIN_BINDS
	var source_path := ProjectSettings.globalize_path(LANCER_SCENE)
	var import_error := document.append_from_file(source_path, state, flags)
	if import_error != OK:
		push_error("[HOPLITE LIBRARY BUILD] lancer source import failed: %s" % error_string(import_error))
		return null
	var generated_scene := document.generate_scene(state)
	if generated_scene == null:
		push_error("[HOPLITE LIBRARY BUILD] lancer source generated no animation scene")
	return generated_scene


func _skeletons_match(canonical: Skeleton3D, source: Skeleton3D) -> bool:
	if canonical.get_bone_count() != source.get_bone_count():
		return false
	for bone_index: int in range(canonical.get_bone_count()):
		if canonical.get_bone_name(bone_index) != source.get_bone_name(bone_index):
			return false
	return true


func _add_action_aliases(library: AnimationLibrary) -> int:
	var failures: int = 0
	for raw_output_name: Variant in ACTION_ALIASES:
		var output_name := StringName(raw_output_name)
		var source_name := StringName(ACTION_ALIASES[output_name])
		var source_animation := library.get_animation(source_name)
		if source_animation == null or library.add_animation(output_name, source_animation) != OK:
			push_error("[HOPLITE LIBRARY BUILD] failed to alias %s from %s" % [output_name, source_name])
			failures += 1
	return failures


func _add_spear_composites(library: AnimationLibrary, keep_left_guard: bool = false) -> int:
	var lancer := library.get_animation(LANCER_RIGHT_ARM_CLIP)
	var guard := library.get_animation(&"ual2_idle_shield")
	if lancer == null or (keep_left_guard and guard == null):
		push_error("[HOPLITE LIBRARY BUILD] lancer or requested guard source is missing before composite bake")
		return SPEAR_COMPOSITES.size()
	var failures := 0
	for raw_output_name: Variant in SPEAR_COMPOSITES:
		var output_name := StringName(raw_output_name)
		var base_name := StringName(SPEAR_COMPOSITES[output_name])
		var base := library.get_animation(base_name)
		if base == null:
			push_error("[HOPLITE LIBRARY BUILD] spear composite base is missing: %s" % base_name)
			failures += 1
			continue
		var composite := base.duplicate(true) as Animation
		# Replace the UAL2 right arm instead of layering a second AnimationTree
		# branch on every runtime soldier. The torso and shield arm stay intact.
		for track_index: int in range(composite.get_track_count() - 1, -1, -1):
			var path := composite.track_get_path(track_index)
			var bone_name := StringName(path.get_subname(path.get_subname_count() - 1)) if path.get_subname_count() > 0 else StringName()
			if LANCER_RIGHT_ARM_BONES.has(bone_name):
				composite.remove_track(track_index)
		for lancer_track: int in range(lancer.get_track_count()):
			_copy_animation_track(lancer, lancer_track, composite)
		if keep_left_guard:
			_apply_constant_guard_arm(composite, guard, 1.0)
		composite.length = maxf(base.length, lancer.length)
		composite.loop_mode = Animation.LOOP_NONE
		if library.add_animation(output_name, composite) != OK:
			push_error("[HOPLITE LIBRARY BUILD] failed to bake spear composite %s" % output_name)
			failures += 1
		else:
			print("[HOPLITE LIBRARY COMPOSITE] name=", output_name, " base=", base_name, " tracks=", composite.get_track_count())
	return failures


func _apply_constant_guard_arm(animation: Animation, guard: Animation, sample_time: float) -> void:
	# The old UAL2 action bases moved the left forearm during a thrust, turning the
	# aspis edge-on. Bake the validated guard pose into the four left-arm bones so
	# the shield remains a real defensive plane while the torso/right arm attack.
	for track_index: int in range(animation.get_track_count() - 1, -1, -1):
		var path := animation.track_get_path(track_index)
		var bone_name := StringName(path.get_subname(path.get_subname_count() - 1)) if path.get_subname_count() > 0 else StringName()
		if LEFT_GUARD_BONES.has(bone_name):
			animation.remove_track(track_index)
	for guard_track: int in range(guard.get_track_count()):
		var path := guard.track_get_path(guard_track)
		var bone_name := StringName(path.get_subname(path.get_subname_count() - 1)) if path.get_subname_count() > 0 else StringName()
		if not LEFT_GUARD_BONES.has(bone_name) or guard.track_get_type(guard_track) != Animation.TYPE_ROTATION_3D:
			continue
		var output_track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(output_track, path)
		animation.track_set_interpolation_type(output_track, Animation.INTERPOLATION_LINEAR)
		animation.track_insert_key(output_track, 0.0, guard.rotation_track_interpolate(guard_track, sample_time))


func _copy_animation_track(source: Animation, source_track: int, target: Animation) -> void:
	var target_track := target.add_track(source.track_get_type(source_track))
	target.track_set_path(target_track, source.track_get_path(source_track))
	target.track_set_enabled(target_track, source.track_is_enabled(source_track))
	target.track_set_imported(target_track, source.track_is_imported(source_track))
	target.track_set_interpolation_type(target_track, source.track_get_interpolation_type(source_track))
	target.track_set_interpolation_loop_wrap(target_track, source.track_get_interpolation_loop_wrap(source_track))
	for key_index: int in range(source.track_get_key_count(source_track)):
		target.track_insert_key(
			target_track,
			source.track_get_key_time(source_track, key_index),
			source.track_get_key_value(source_track, key_index),
			source.track_get_key_transition(source_track, key_index)
		)


func _sample_clip(
	target_skeleton: Skeleton3D,
	source_skeleton: Skeleton3D,
	source_player: AnimationPlayer,
	bridge: HopliteAuthoredPoseBridge,
	source_name: StringName,
	actions_only: bool,
	looping: bool
) -> Animation:
	var source_animation := source_player.get_animation(source_name)
	if source_animation == null or source_animation.length <= 0.0:
		return null
	var result := Animation.new()
	result.length = source_animation.length
	result.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	result.step = 1.0 / SAMPLE_FPS

	var track_by_bone: Dictionary = {}
	for bone_index: int in range(target_skeleton.get_bone_count()):
		var bone_name := target_skeleton.get_bone_name(bone_index)
		if actions_only and not ACTION_BONES.has(bone_name):
			continue
		var track_index := result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(track_index, NodePath(".:%s" % bone_name))
		result.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
		track_by_bone[bone_index] = track_index

	source_player.play(source_name)
	source_player.advance(0.0)
	bridge.set_attack_weight(1.0, true, 1.0)
	var sample_count := maxi(2, ceili(source_animation.length * SAMPLE_FPS) + 1)
	for sample_index: int in range(sample_count):
		var time := minf(float(sample_index) / SAMPLE_FPS, source_animation.length)
		source_player.seek(time, true)
		# `seek()` changes playback time, while `advance(0)` forces AnimationPlayer
		# to write that sample to the donor skeleton before the pose bridge reads it.
		source_player.advance(0.0)
		source_skeleton.force_update_all_bone_transforms()
		target_skeleton.reset_bone_poses()
		bridge.call(&"_process_modification_with_delta", 0.0)
		for raw_bone_index: Variant in track_by_bone:
			var bone_index := int(raw_bone_index)
			var track_index := int(track_by_bone[bone_index])
			result.track_insert_key(track_index, time, target_skeleton.get_bone_pose_rotation(bone_index))

	bridge.set_attack_weight(0.0, false, 0.0)
	source_player.stop()
	target_skeleton.reset_bone_poses()
	print("[HOPLITE LIBRARY CLIP] name=", source_name, " length=", snappedf(result.length, 0.001), " tracks=", result.get_track_count(), " samples=", sample_count)
	return result


func _instantiate_scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[HOPLITE LIBRARY BUILD] missing scene: %s" % path)
		return null
	return packed.instantiate()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
