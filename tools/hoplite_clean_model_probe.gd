extends SceneTree

const EnemyFactory := preload("res://scripts/enemy/enemy_factory.gd")
const MODEL_PATH := "res://assets/characters/3dgen_demo/hopliteClean1.glb"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -8.0)
	stage.add_child(target)
	var veteran: HopliteAthenianEnemy = EnemyFactory.spawn(stage, &"ngeneral_veteran", Vector3.ZERO, target, {
		"ai_enabled": false,
	})
	for _frame: int in range(3):
		await process_frame
		await physics_frame

	_expect(veteran != null, "factory returned null")
	if veteran != null:
		_expect(veteran.character_package_path == MODEL_PATH, "veteran resolved another package")
		_expect(veteran.mannequin_scene != null and veteran.mannequin_scene.find_child("Sketchfab_model", true, false) != null, "hopliteClean1 scene marker missing")
		_expect(veteran.skeleton != null and veteran.skeleton.get_bone_count() == 53, "canonical 53-bone skeleton missing")
		_expect(veteran.skeleton != null and veteran.skeleton.find_bone("root") >= 0, "clean root bone was not normalized")
		_expect(veteran.ai_animation_driver is HopliteSharedAnimationDriver, "shared hoplite animation driver missing")
		_expect(veteran.animation_player != null and veteran.animation_player.has_animation("Idle"), "shared animation library missing")
		_expect(veteran.find_children("*", "AnimationPlayer", true, false).size() == 1, "embedded animation player was not retired")
		_expect(veteran.anatomy != null and veteran.anatomy.debug_missing_bones.is_empty(), "anatomy did not map clean rig")
		_expect(veteran.sword_root != null and veteran.shield_root != null and veteran.shield_hitbox != null, "veteran spear/shield equipment incomplete")
		_expect(veteran.uses_spartan_package_visual and veteran.spartan_package_adapter == null, "clean single-mesh package route not active")
		if veteran.ai_animation_driver != null:
			veteran.skeleton.reset_bone_poses()
			veteran.ai_animation_driver.set_locomotion(0.65)
			veteran.ai_animation_driver.animation_tree.advance(0.20)
			veteran.skeleton.force_update_all_bone_transforms()
			_expect(_maximum_pose_angle(veteran.skeleton) > 0.05, "clean mesh stayed in bind pose under shared animation")

	if veteran != null:
		veteran.queue_free()
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("HOPLITE_CLEAN_MODEL_PROBE PASS: hopliteClean1 rig, shared animation, anatomy, spear and shield")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("HOPLITE_CLEAN_MODEL_PROBE FAIL: %d issue(s)" % failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _maximum_pose_angle(skeleton: Skeleton3D) -> float:
	var maximum := 0.0
	for bone_index: int in range(skeleton.get_bone_count()):
		maximum = maxf(maximum, skeleton.get_bone_pose_rotation(bone_index).get_angle())
	return maximum
