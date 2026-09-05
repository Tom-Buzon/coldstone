extends SceneTree

## Offline-only publisher for the 23-bone Hoplite V2 donor.
##
## V1 keeps using hoplite_animation_library_v4.res. This publisher consumes the
## dedicated 53-bone V2 offline bake, filters every track against the new
## skeleton, then refuses to save if a finger or an unknown bone remains.

const TARGET_SCENE := "res://assets/characters/enemy_v2/hoplite/hoplite_body_v2.gltf"
const SOURCE_LIBRARY := "res://assets/animations/enemy_v2/hoplite/hoplite_v2_source_53.res"
const OUTPUT_LIBRARY := "res://assets/animations/enemy_v2/hoplite/hoplite_v2_animation_library.res"
const OUTPUT_REPORT := "res://assets/animations/enemy_v2/hoplite/hoplite_v2_animation_library.report.json"
const EXPECTED_BONE_COUNT := 23

const REQUIRED_CLIPS: Array[StringName] = [
	&"Idle",
	&"Jog_Fwd",
	&"Sprint",
	&"Death01",
	&"ual2_idle_shield",
	&"ual2_shield_one_shot",
	&"ual2_sword_block",
	&"lancer_right_arm_thrust",
	&"spear_thrust",
	&"spear_thrust_low",
	&"spear_bayonet_step",
	&"shield_bash",
	&"block_idle",
	&"block_impact",
]


func _initialize() -> void:
	call_deferred(&"_publish")


func _publish() -> void:
	var failures: Array[String] = []
	var target_root := _instantiate_scene(TARGET_SCENE)
	if target_root == null:
		quit(1)
		return
	get_root().add_child(target_root)
	var target_skeleton := _find_skeleton(target_root)
	if target_skeleton == null:
		failures.append("target scene has no Skeleton3D")
	elif target_skeleton.get_bone_count() != EXPECTED_BONE_COUNT:
		failures.append("target skeleton has %d bones; expected %d" % [target_skeleton.get_bone_count(), EXPECTED_BONE_COUNT])

	var source := load(SOURCE_LIBRARY) as AnimationLibrary
	if source == null:
		failures.append("source library is missing: %s" % SOURCE_LIBRARY)

	var output := AnimationLibrary.new()
	var clip_report: Dictionary = {}
	if failures.is_empty():
		var allowed_bones := _allowed_bones(target_skeleton)
		var idle_pose := _filtered_animation(source.get_animation(&"Idle"), allowed_bones, failures, &"Idle")
		for clip_name: StringName in REQUIRED_CLIPS:
			var source_animation := source.get_animation(clip_name)
			if source_animation == null:
				failures.append("required source clip is missing: %s" % clip_name)
				continue
			var filtered := _filtered_animation(source_animation, allowed_bones, failures, clip_name)
			if filtered == null:
				continue
			var filled_tracks := 0
			if idle_pose != null and clip_name != &"Idle":
				filled_tracks = _fill_missing_pose_tracks(filtered, idle_pose)
			var add_error := output.add_animation(clip_name, filtered)
			if add_error != OK:
				failures.append("could not add %s: %s" % [clip_name, error_string(add_error)])
				continue
			clip_report[String(clip_name)] = {
				"length": filtered.length,
				"loop_mode": filtered.loop_mode,
				"tracks": filtered.get_track_count(),
				"idle_pose_tracks_added": filled_tracks,
			}

	if failures.is_empty():
		var make_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_LIBRARY.get_base_dir()))
		if make_error != OK and make_error != ERR_ALREADY_EXISTS:
			failures.append("could not create output directory: %s" % error_string(make_error))
		else:
			var save_error := ResourceSaver.save(output, OUTPUT_LIBRARY)
			if save_error != OK:
				failures.append("could not save library: %s" % error_string(save_error))

	var report := {
		"schema_version": 1,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"source_library": SOURCE_LIBRARY,
		"target_scene": TARGET_SCENE,
		"target_rig_id": "spartan_enemy_v2_23",
		"target_bone_count": target_skeleton.get_bone_count() if target_skeleton != null else 0,
		"required_clips": REQUIRED_CLIPS.map(func(clip: StringName) -> String: return String(clip)),
		"clips": clip_report,
		"errors": failures,
	}
	_write_json(OUTPUT_REPORT, report)
	if failures.is_empty():
		print("HOPLITE_V2_ANIMATION_LIBRARY PASS: ", OUTPUT_LIBRARY, " clips=", output.get_animation_list())
	else:
		for failure: String in failures:
			push_error("[HOPLITE V2 ANIMATION BUILD] " + failure)
	target_root.free()
	quit(0 if failures.is_empty() else 1)


func _filtered_animation(
	source: Animation,
	allowed_bones: Dictionary,
	failures: Array[String],
	clip_name: StringName
) -> Animation:
	var output := source.duplicate(true) as Animation
	for track_index: int in range(output.get_track_count() - 1, -1, -1):
		var path := output.track_get_path(track_index)
		if path.get_subname_count() == 0:
			output.remove_track(track_index)
			continue
		var bone_name := StringName(path.get_subname(path.get_subname_count() - 1))
		if _is_finger(bone_name):
			output.remove_track(track_index)
			continue
		if not allowed_bones.has(bone_name):
			failures.append("%s targets unknown bone %s" % [clip_name, bone_name])
			return null
		output.track_set_path(track_index, NodePath(".:%s" % bone_name))
	if output.get_track_count() == 0:
		failures.append("%s has no compatible tracks" % clip_name)
		return null
	return output


func _fill_missing_pose_tracks(animation: Animation, idle_pose: Animation) -> int:
	# Several spear/block sources animate only the torso. AnimationPlayer otherwise
	# preserves the last Jog_Fwd values for every missing leg track, freezing a run
	# stride during the attack. Bake the neutral lower-body pose offline instead.
	var existing: Dictionary = {}
	for track_index: int in range(animation.get_track_count()):
		existing[animation.track_get_path(track_index)] = true
	var added := 0
	for idle_index: int in range(idle_pose.get_track_count()):
		var path := idle_pose.track_get_path(idle_index)
		if existing.has(path) or idle_pose.track_get_key_count(idle_index) == 0:
			continue
		var output_index := animation.add_track(idle_pose.track_get_type(idle_index))
		animation.track_set_path(output_index, path)
		animation.track_set_interpolation_type(output_index, idle_pose.track_get_interpolation_type(idle_index))
		animation.track_set_interpolation_loop_wrap(output_index, idle_pose.track_get_interpolation_loop_wrap(idle_index))
		animation.track_set_enabled(output_index, idle_pose.track_is_enabled(idle_index))
		animation.track_insert_key(output_index, 0.0, idle_pose.track_get_key_value(idle_index, 0))
		existing[path] = true
		added += 1
	return added


func _allowed_bones(skeleton: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}
	for bone_index: int in range(skeleton.get_bone_count()):
		result[skeleton.get_bone_name(bone_index)] = true
	return result


func _is_finger(bone_name: StringName) -> bool:
	var name := String(bone_name)
	return name.begins_with("DEF-f_") or name.begins_with("DEF-thumb.")


func _instantiate_scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[HOPLITE V2 ANIMATION BUILD] missing scene: %s" % path)
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


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[HOPLITE V2 ANIMATION BUILD] could not write report: %s" % path)
		return
	file.store_string(JSON.stringify(value, "\t", false) + "\n")
