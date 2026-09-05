extends "res://tools/build_hoplite_animation_library.gd"

## Offline retarget only: no donor, pose bridge or V1 actor exists at runtime.
const ROLE_OUTPUT := "res://assets/animations/enemy_v2/hoplite/enemy_v2_roles.res"
const ROLE_DONORS := {
	&"sword_cut": "res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield slash (5).fbx",
	&"sword_heavy": "res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield attack (4).fbx",
	&"bow_draw": "res://assets/runtime/mixamo/animations/Bow Standing Aim Walk Back.fbx",
}

func _run() -> void:
	var canonical := _instantiate_scene(CANONICAL_SCENE)
	get_root().add_child(canonical)
	var skeleton := _find_skeleton(canonical)
	var library := load("res://assets/animations/enemy_v2/hoplite/hoplite_v2_animation_library.res").duplicate(true) as AnimationLibrary
	var failures := 0
	for key: StringName in ROLE_DONORS:
		var donor := _instantiate_scene(String(ROLE_DONORS[key]))
		var player := _find_animation_player(donor)
		var clip := StringName()
		for candidate: StringName in player.get_animation_list():
			if candidate != &"RESET":
				clip = candidate
				break
		donor.free()
		failures += await _bake_mixamo_full_body_clip(library, skeleton, ROLE_DONORS[key], clip, key)
	var target := _instantiate_scene("res://assets/characters/enemy_v2/hoplite/hoplite_body_v2.gltf")
	var target_skeleton := _find_skeleton(target)
	var idle := library.get_animation(&"Idle")
	for key: StringName in ROLE_DONORS:
		var animation := library.get_animation(key)
		for index: int in range(animation.get_track_count() - 1, -1, -1):
			var path := animation.track_get_path(index)
			var bone := StringName(path.get_subname(path.get_subname_count() - 1))
			if target_skeleton.find_bone(bone) < 0 or (key == &"bow_draw" and not ACTION_BONES.has(bone)):
				animation.remove_track(index)
		if key == &"bow_draw":
			for index: int in range(idle.get_track_count()):
				var path := idle.track_get_path(index)
				var bone := StringName(path.get_subname(path.get_subname_count() - 1))
				if ACTION_BONES.has(bone):
					continue
				var added := animation.add_track(idle.track_get_type(index))
				animation.track_set_path(added, path)
				animation.track_insert_key(added, 0.0, idle.track_get_key_value(index, 0))
		print("ROLE_CLIP ", key, " seconds=", animation.length, " tracks=", animation.get_track_count())
	if failures == 0:
		failures += int(ResourceSaver.save(library, ROLE_OUTPUT) != OK)
	canonical.free()
	target.free()
	print("ROLE_ANIMATION_BUILD ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
