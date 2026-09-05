extends RefCounted
class_name HopliteHumanoidRetargetProxy

const MIXAMO_MAP_PATH := "res://assets/retarget/mixamo_humanoid_bone_map.tres"
const UAL1_MAP_PATH := "res://assets/retarget/ual1_humanoid_bone_map.tres"

# Builds a light, mesh-free UAL1 skeleton between a Mixamo donor and the visible
# character. Godot's RetargetModifier3D performs the difficult model-space rest
# conversion; the ordinary pose bridge only blends an already-UAL1-compatible
# proxy pose into gameplay.
static func build(source_skeleton: Skeleton3D, source_player: AnimationPlayer, target_skeleton: Skeleton3D) -> Dictionary:
	if source_skeleton == null or source_player == null or target_skeleton == null:
		return {}
	var source_map := load(MIXAMO_MAP_PATH) as BoneMap
	var target_map := load(UAL1_MAP_PATH) as BoneMap
	if source_map == null or target_map == null or source_map.profile == null:
		push_error("[HUMANOID RETARGET] BoneMap resources are missing")
		return {}
	var profile := source_map.profile
	var renamed_tracks := _rename_animation_tracks(source_player, source_map, source_skeleton)
	var renamed_bones := _rename_source_bones(source_skeleton, source_map)
	var proxy := _build_target_proxy(target_skeleton, target_map, profile)
	if proxy == null:
		return {}

	var modifier := RetargetModifier3D.new()
	modifier.name = "GodotHumanoidRetarget"
	modifier.profile = profile
	modifier.use_global_pose = false
	# Position tracks are the main source of stretched bodies with rigs of
	# different proportions. Combat owns displacement on CharacterBody3D.
	modifier.set_position_enabled(false)
	modifier.set_rotation_enabled(true)
	modifier.set_scale_enabled(false)
	source_skeleton.add_child(modifier)
	modifier.add_child(proxy)
	if bool(ProjectSettings.get_setting("debug/hoplite/verbose_animation", false)):
		print("[HUMANOID RETARGET] profile_bones=", profile.bone_size, " source_bones=", renamed_bones, " tracks=", renamed_tracks, " proxy_bones=", proxy.get_bone_count())
	return {"modifier": modifier, "proxy": proxy, "source_map": source_map, "target_map": target_map}

static func _rename_animation_tracks(player: AnimationPlayer, bone_map: BoneMap, skeleton: Skeleton3D) -> int:
	var actual_to_profile: Dictionary = {}
	var profile := bone_map.profile
	for index: int in range(profile.bone_size):
		var profile_name := profile.get_bone_name(index)
		var actual_name := bone_map.get_skeleton_bone_name(profile_name)
		if actual_name != StringName() and skeleton.find_bone(actual_name) >= 0:
			actual_to_profile[String(actual_name)] = String(profile_name)

	var replacements := 0
	var library_names := player.get_animation_library_list()
	for library_name: StringName in library_names:
		var old_library := player.get_animation_library(library_name)
		if old_library == null:
			continue
		var new_library := AnimationLibrary.new()
		for animation_name: StringName in old_library.get_animation_list():
			var source_animation := old_library.get_animation(animation_name)
			if source_animation == null:
				continue
			var animation := source_animation.duplicate(true) as Animation
			for track_index: int in range(animation.get_track_count()):
				var path := animation.track_get_path(track_index)
				if path.get_subname_count() < 1:
					continue
				var actual_bone := String(path.get_subname(path.get_subname_count() - 1))
				if not actual_to_profile.has(actual_bone):
					continue
				var raw_path := String(path)
				var colon := raw_path.rfind(":" + actual_bone)
				if colon < 0:
					continue
				animation.track_set_path(track_index, NodePath(raw_path.left(colon + 1) + String(actual_to_profile[actual_bone])))
				replacements += 1
			new_library.add_animation(animation_name, animation)
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, new_library)
	return replacements

static func _rename_source_bones(skeleton: Skeleton3D, bone_map: BoneMap) -> int:
	var renamed := 0
	var profile := bone_map.profile
	for index: int in range(profile.bone_size):
		var profile_name := profile.get_bone_name(index)
		var actual_name := bone_map.get_skeleton_bone_name(profile_name)
		var bone_index := skeleton.find_bone(actual_name)
		if actual_name == StringName() or bone_index < 0:
			continue
		skeleton.set_bone_name(bone_index, profile_name)
		renamed += 1
	return renamed

static func _build_target_proxy(target: Skeleton3D, bone_map: BoneMap, profile: SkeletonProfile) -> Skeleton3D:
	var proxy := Skeleton3D.new()
	proxy.name = "UAL1HumanoidPoseProxy"
	var profile_to_proxy: Dictionary = {}
	var profile_to_target: Dictionary = {}
	for index: int in range(profile.bone_size):
		var profile_name := profile.get_bone_name(index)
		var target_name := bone_map.get_skeleton_bone_name(profile_name)
		var target_index := target.find_bone(target_name)
		# glTF guarantees unique node names and may suffix the armature root
		# (for example `root_2`) when a mesh/object already owns `root`. The
		# humanoid map still calls that profile bone `Root`; resolve the unique
		# parentless target bone so the proxy keeps the correct hips parent space.
		# Omitting it makes full-body Mixamo poses rotate the whole target sideways.
		if target_index < 0 and profile.get_bone_parent(index) == StringName():
			target_index = _unique_root_bone(target)
		if target_name == StringName() or target_index < 0:
			continue
		var proxy_index := proxy.get_bone_count()
		proxy.add_bone(profile_name)
		profile_to_proxy[profile_name] = proxy_index
		profile_to_target[profile_name] = target_index

	for index: int in range(profile.bone_size):
		var profile_name := profile.get_bone_name(index)
		if not profile_to_proxy.has(profile_name):
			continue
		var proxy_index := int(profile_to_proxy[profile_name])
		var target_index := int(profile_to_target[profile_name])
		var parent_name := profile.get_bone_parent(index)
		while parent_name != StringName() and not profile_to_proxy.has(parent_name):
			var parent_profile_index := profile.find_bone(parent_name)
			parent_name = profile.get_bone_parent(parent_profile_index) if parent_profile_index >= 0 else StringName()
		var target_global_rest := target.get_bone_global_rest(target_index)
		var proxy_rest := target_global_rest
		if parent_name != StringName():
			var parent_proxy_index := int(profile_to_proxy[parent_name])
			var parent_target_index := int(profile_to_target[parent_name])
			proxy.set_bone_parent(proxy_index, parent_proxy_index)
			proxy_rest = target.get_bone_global_rest(parent_target_index).affine_inverse() * target_global_rest
		proxy.set_bone_rest(proxy_index, proxy_rest)
	proxy.reset_bone_poses()
	return proxy

static func _unique_root_bone(skeleton: Skeleton3D) -> int:
	var result := -1
	for bone_index: int in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(bone_index) >= 0:
			continue
		if result >= 0:
			return -1
		result = bone_index
	return result
