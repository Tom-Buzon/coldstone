extends "res://tools/build_hoplite_animation_library.gd"

## Offline donor consumption; no legacy actor or donor skeleton at runtime.
func _run() -> void:
	var giant := _instantiate_scene("res://assets/characters/3dgen_demo/geant1-1787584159710.glb")
	get_root().add_child(giant)
	var skeleton := _find_skeleton(giant)
	var library := AnimationLibrary.new()
	var failures := _bake_scene_clips(library, skeleton, UAL1_SCENE, UAL1_CLIPS, true, false)
	var bank := load("res://scripts/animation/external_animation_bank.gd")
	var paths: Dictionary = bank.default_donor_paths()
	for key: StringName in [&"giant_punch", &"giant_swipe", &"giant_jump_attack_alt"]:
		failures += await _bake_mixamo_full_body_clip(library, skeleton, String(paths[key]), &"mixamo_com", key)
	if failures == 0:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/animations/enemy_v2/giant"))
		failures += int(ResourceSaver.save(library, "res://assets/animations/enemy_v2/giant/giant_v2_animation_library.res") != OK)
	print("GIANT_V2_ANIMATION_BUILD ", "PASS" if failures == 0 else "FAIL", " clips=", library.get_animation_list())
	giant.free()
	quit(0 if failures == 0 else 1)
