extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const Director = preload("res://scripts/ai/battle_crowd_director.gd")
const DetachedLimb = preload("res://scripts/gore/spartan_detached_limb.gd")

class ProbeTarget:
	extends CharacterBody3D
	func receive_enemy_hit(_damage: float, _attacker: Node = null, _direction: Vector3 = Vector3.ZERO) -> bool:
		return true
	func get_combat_aim_point() -> Vector3:
		return global_position + Vector3.UP

class ProbeSoldier:
	extends Node3D
	var faction: StringName = &"athenian"
	var behavior_mode: StringName = &"phalanx"
	var ai_player: Node3D
	func is_dead_for_combat() -> bool:
		return false

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var target := ProbeTarget.new()
	target.name = "PhalanxProbeTarget"
	target.position = Vector3(0.0, 0.0, -20.0)
	root.add_child(target)
	var director := Director.new()
	root.add_child(director)
	var standard := _spawn_hoplite(&"ngeneral", target, Vector3(-0.5, 0.0, 0.0))
	var veteran := _spawn_hoplite(&"ngeneral_veteran", target, Vector3(0.5, 0.0, 0.0))
	await process_frame
	await process_frame
	await physics_frame

	_probe_runtime_shape(standard, "standard")
	_probe_runtime_shape(veteran, "veteran")
	_probe_cohort_personal_space(standard, veteran)
	_probe_guarded_shield_ownership(standard)
	var standard_library: AnimationLibrary = standard.animation_player.get_animation_library(&"")
	var veteran_library: AnimationLibrary = veteran.animation_player.get_animation_library(&"")
	_expect(standard_library != null and standard_library == veteran_library, "standard/veteran do not share the same AnimationLibrary resource")
	_expect(standard_library.get_animation(&"spear_thrust") != standard_library.get_animation(&"ual2_shield_one_shot"), "spear action was not baked as a distinct Blender/UAL2 composite")
	_expect(standard_library.get_animation(&"block_idle") == standard_library.get_animation(&"ual2_idle_shield"), "guard action did not reuse the baked UAL2 clip")
	_validate_lancer_right_arm_clip(standard_library)
	var sprint_motion := _maximum_animation_key_motion(standard_library.get_animation(&"Sprint"))
	print("HOPLITE_LIBRARY_MOTION Sprint=", sprint_motion)
	print("HOPLITE_LIBRARY_SHIN_MOTION Sprint=", _animation_bone_motion(standard_library.get_animation(&"Sprint"), &"DEF-shin.L"))
	_expect(sprint_motion > 0.01, "baked Sprint clip contains no changing rotation keys")
	_expect(standard.animation_player != veteran.animation_player, "soldiers unexpectedly share AnimationPlayer state")
	_expect(standard.ai_animation_driver.animation_tree != veteran.ai_animation_driver.animation_tree, "soldiers unexpectedly share AnimationTree state")
	_expect(not standard.ai_animation_driver.tree_root.has_node(&"LancerRightArm"), "hoplite still owns a permanent per-soldier lancer blend branch")
	var standard_body := standard.find_child("SPARTAN_body_merged", true, false) as MeshInstance3D
	var veteran_body := _find_skinned_body(veteran.mannequin_scene)
	_expect(standard_body != null and veteran_body != null, "standard merged body or veteran clean body is missing")
	_expect(standard_body == null or veteran_body == null or standard_body.mesh != veteran_body.mesh, "veteran unexpectedly reuses the standard NGeneral body")
	standard.skeleton.reset_bone_poses()
	standard.ai_enabled = false
	standard.ai_animation_driver.stop_full_body()
	standard.ai_animation_driver.set_locomotion(1.0)
	standard.ai_animation_driver.tick(0.35)
	await physics_frame
	await physics_frame
	standard.skeleton.force_update_all_bone_transforms()
	_expect(_maximum_pose_angle(standard.skeleton) > 0.05, "AnimationTree advanced but left the canonical skeleton in T-pose")
	var shin_index := standard.skeleton.find_bone("DEF-shin.L")
	var shin_before := standard.skeleton.get_bone_pose_rotation(shin_index)
	for _frame: int in range(8):
		await physics_frame
	var shin_after := standard.skeleton.get_bone_pose_rotation(shin_index)
	print("HOPLITE_LOCOMOTION_TIMELINE shin_delta=", shin_before.angle_to(shin_after))
	_expect(shin_before.angle_to(shin_after) > 0.002, "AnimationTree is posed but its locomotion timeline is frozen")
	var guard_started: bool = standard.ai_animation_driver.begin_block()
	standard.ai_animation_driver.set_locomotion(1.0)
	var guarded_shin_before := standard.skeleton.get_bone_pose_rotation(shin_index)
	for _frame: int in range(8):
		await physics_frame
	var guarded_shin_after := standard.skeleton.get_bone_pose_rotation(shin_index)
	var guarded_shin_motion := guarded_shin_before.angle_to(guarded_shin_after)
	print("HOPLITE_GUARDED_LOCOMOTION shin_delta=", guarded_shin_motion)
	_expect(guard_started and guarded_shin_motion > 0.002, "upper-body guard froze the locomotion legs")
	standard.ai_animation_driver.end_block()
	var attack_started: bool = standard.ai_animation_driver.play_external_attack(&"spear_thrust", &"probe", &"probe")
	standard.ai_animation_driver.call("_set_action_blend", 1.0)
	var action_before := _capture_pose(standard.skeleton)
	var hand_index := standard.skeleton.find_bone("DEF-hand.R")
	standard.skeleton.force_update_all_bone_transforms()
	var hand_position_before := standard.skeleton.get_bone_global_pose(hand_index).origin
	standard.ai_animation_driver.animation_tree.advance(0.18)
	standard.skeleton.force_update_all_bone_transforms()
	var action_motion := _maximum_pose_delta(standard.skeleton, action_before)
	var right_arm_motion := _maximum_named_pose_delta(
		standard.skeleton,
		action_before,
		[&"DEF-upper_arm.R", &"DEF-forearm.R", &"DEF-hand.R", &"DEF-thumb.01.R"]
	)
	print("HOPLITE_ACTION_TIMELINE spear_thrust_delta=", action_motion)
	_expect(attack_started and action_motion > 0.01, "shared spear action did not advance through the AnimationTree")
	_expect(right_arm_motion > 0.01, "Blender lancer right-arm override did not advance during the shared spear action")
	_expect(hand_position_before.distance_to(standard.skeleton.get_bone_global_pose(hand_index).origin) > 0.01, "Blender lancer arm did not advance the spear hand at runtime")
	standard.ai_animation_driver.stop_full_body()

	director.phalanx_cache_frame = -1
	var standard_assignment: Dictionary = director.phalanx_assignment(standard, target)
	var veteran_assignment: Dictionary = director.phalanx_assignment(veteran, target)
	_expect(not standard_assignment.is_empty() and not veteran_assignment.is_empty(), "formation assignments are missing")
	_expect(director.phalanx_group_build_count == 1, "formation was rebuilt %d times for one cohort" % director.phalanx_group_build_count)
	await physics_frame
	director.phalanx_assignment(standard, target)
	_expect(director.phalanx_group_build_count == 1, "staggered soldier decisions rebuilt the same cohort inside its tactical cache window")
	_probe_fifteen_unit_cache(director, target)

	standard.ai_alert_timer = 0.0
	standard.retaliation_timer = 0.0
	standard.ai_attack_pending = false
	standard.ai_attack_recovery_timer = 0.0
	standard.defense_timer = 0.0
	standard.call("_update_performance_lod")
	_expect(not standard.anatomy.tracking_enabled, "anatomy still tracks bones outside combat")
	target.position = Vector3(0.0, 0.0, -2.0)
	standard.call("_update_performance_lod")
	_expect(standard.anatomy.tracking_enabled and standard.anatomy.update_interval <= 0.001, "anatomy did not return to exact tracking at contact")

	target.position = Vector3(0.0, 0.0, -10.0)
	standard.formation_row = 1
	standard.call("_update_performance_lod")
	_expect(not standard.secondary_hoplite_shadows_enabled, "secondary-rank shadow stayed enabled beyond 8 m")
	veteran.formation_row = 0
	veteran.formation_column = 0
	veteran.call("_update_performance_lod")
	_expect(veteran.secondary_hoplite_shadows_enabled, "front-centre hoplite lost its near shadow")

	_probe_dismemberment(standard)
	if failures.is_empty():
		print("HOPLITE_PHALANX_OPTIMIZATION_PROBE PASS: shared rig/library, standard merged gore body, veteran clean body, cached formation, sleeping anatomy, shadow policy")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _spawn_hoplite(archetype: StringName, target: Node3D, spawn_position: Vector3) -> HopliteAthenianEnemy:
	var enemy := Enemy.new() as HopliteAthenianEnemy
	enemy.name = "OptimizationProbe_" + String(archetype)
	enemy.archetype_id = archetype
	enemy.ai_enabled = true
	enemy.ai_player = target
	enemy.battle_player = target
	enemy.position = spawn_position
	root.add_child(enemy)
	return enemy

func _probe_runtime_shape(enemy: Node, label: String) -> void:
	_expect(enemy.skeleton != null, "%s canonical skeleton missing" % label)
	_expect(enemy.find_children("*", "Skeleton3D", true, false).size() == 1, "%s does not have exactly one Skeleton3D" % label)
	_expect(enemy.find_children("*", "AnimationPlayer", true, false).size() == 1, "%s does not have exactly one AnimationPlayer" % label)
	_expect(enemy.find_children("*", "AnimationTree", true, false).size() == 1, "%s does not have exactly one AnimationTree" % label)
	var body := enemy.find_child("SPARTAN_body_merged", true, false) as MeshInstance3D
	if body == null:
		body = _find_skinned_body(enemy.mannequin_scene)
	_expect(body != null and body.mesh != null and body.mesh.get_surface_count() == 1, "%s body is not one skinned surface" % label)
	if body != null and body.mesh != null:
		var arrays: Array = body.mesh.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
		_expect(not vertices.is_empty() and bones.size() >= vertices.size() * 4 and weights.size() == bones.size(), "%s body lost its skin weights" % label)
		_expect(body.skin != null and body.skin.get_bind_count() == 53, "%s body lost its canonical Skin binds" % label)
		if body.name == "SPARTAN_body_merged":
			var surface: Dictionary = RenderingServer.mesh_get_surface(body.mesh.get_rid(), 0)
			_expect((surface.get("lods", []) as Array).size() >= 1, "%s merged body lost its imported LOD indices" % label)
	for donor_marker: String in ["SpartanUALAnimationDonor", "*UAL2*", "*ExternalDonor*", "*WallRunAnimationBank*"]:
		_expect(enemy.find_child(donor_marker, true, false) == null, "%s still instances %s" % [label, donor_marker])

func _find_skinned_body(root_node: Node) -> MeshInstance3D:
	if root_node == null:
		return null
	for mesh_node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.skin != null:
			return mesh_instance
	return null

func _probe_cohort_personal_space(standard: HopliteAthenianEnemy, veteran: HopliteAthenianEnemy) -> void:
	standard.set_meta("formation_group", &"sync_probe")
	veteran.set_meta("formation_group", &"sync_probe")
	standard.position = Vector3(-0.5, 0.0, 0.0)
	veteran.position = Vector3(0.5, 0.0, 0.0)
	var same_cohort_push: Vector3 = standard.call("_ai_separation_vector")
	veteran.set_meta("formation_group", &"other_probe")
	var other_cohort_push: Vector3 = standard.call("_ai_separation_vector")
	_expect(same_cohort_push.length() < 0.001, "same-cohort personal space still fights the authored one-metre slot spacing")
	_expect(other_cohort_push.length() > 0.01, "separate cohorts lost their normal collision spacing")
	veteran.set_meta("formation_group", &"sync_probe")

func _probe_guarded_shield_ownership(enemy: HopliteAthenianEnemy) -> void:
	_expect(enemy.shield_root != null and enemy.shield_attachment != null, "guard synchronization probe has no shield attachment")
	if enemy.shield_root == null or enemy.shield_attachment == null:
		return
	enemy.rotation.y = deg_to_rad(24.0)
	enemy.formation_facing = Vector3.RIGHT
	enemy.formation_guard_active = true
	enemy.ai_attack_pending = false
	enemy.ai_attack_recovery_timer = 0.0
	enemy.guard_break_timer = 0.0
	enemy.call("_update_phalanx_equipment_pose")
	var body_forward := -enemy.global_basis.z.normalized()
	var shield_forward := -enemy.shield_root.global_basis.z.normalized()
	_expect(enemy.shield_root.get_parent() == enemy and enemy.shield_guard_root_anchored, "guarded shield remained under the animated hand")
	_expect(body_forward.dot(shield_forward) > 0.999, "guarded shield follows the tactical target instead of the body's integrated yaw")
	var stable_local_transform := enemy.shield_root.transform
	enemy.ai_animation_driver.animation_tree.advance(0.12)
	enemy.skeleton.force_update_all_bone_transforms()
	_expect(enemy.shield_root.transform.is_equal_approx(stable_local_transform), "an arm animation sample moved the root-anchored guard shield")
	enemy.formation_guard_active = false
	enemy.call("_update_phalanx_equipment_pose")
	_expect(enemy.shield_root.get_parent() == enemy.shield_attachment and not enemy.shield_guard_root_anchored, "lowered shield did not return to its authored hand attachment")
	_expect(enemy.shield_root.transform.is_equal_approx(enemy.shield_rest_transform), "lowered shield did not recover its authored local transform")

func _maximum_pose_angle(skeleton: Skeleton3D) -> float:
	var maximum := 0.0
	for bone_index: int in range(skeleton.get_bone_count()):
		maximum = maxf(maximum, skeleton.get_bone_pose_rotation(bone_index).get_angle())
	return maximum

func _capture_pose(skeleton: Skeleton3D) -> Array[Quaternion]:
	var pose: Array[Quaternion] = []
	for bone_index: int in range(skeleton.get_bone_count()):
		pose.append(skeleton.get_bone_pose_rotation(bone_index))
	return pose

func _maximum_pose_delta(skeleton: Skeleton3D, before: Array[Quaternion]) -> float:
	var maximum := 0.0
	for bone_index: int in range(mini(skeleton.get_bone_count(), before.size())):
		maximum = maxf(maximum, before[bone_index].angle_to(skeleton.get_bone_pose_rotation(bone_index)))
	return maximum

func _maximum_named_pose_delta(skeleton: Skeleton3D, before: Array[Quaternion], bone_names: Array[StringName]) -> float:
	var maximum := 0.0
	for bone_name: StringName in bone_names:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0 and bone_index < before.size():
			maximum = maxf(maximum, before[bone_index].angle_to(skeleton.get_bone_pose_rotation(bone_index)))
	return maximum

func _validate_lancer_right_arm_clip(library: AnimationLibrary) -> void:
	var animation := library.get_animation(&"lancer_right_arm_thrust")
	_expect(animation != null, "shared library is missing the Blender lancer right-arm clip")
	if animation == null:
		return
	var allowed := {
		&"DEF-upper_arm.R": true,
		&"DEF-forearm.R": true,
		&"DEF-hand.R": true,
		&"DEF-thumb.01.R": true,
	}
	var forearm_position := false
	_expect(animation.get_track_count() == 5, "lancer clip contains %d tracks instead of the five right-arm tracks" % animation.get_track_count())
	for track_index: int in range(animation.get_track_count()):
		var path := animation.track_get_path(track_index)
		var bone_name := StringName(path.get_subname(path.get_subname_count() - 1)) if path.get_subname_count() > 0 else StringName()
		_expect(allowed.has(bone_name), "lancer clip leaked a non-right-arm track: %s" % path)
		if bone_name == &"DEF-forearm.R" and animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
			forearm_position = true
	_expect(forearm_position, "lancer clip lost the authored forearm position track")

func _maximum_animation_key_motion(animation: Animation) -> float:
	var maximum := 0.0
	if animation == null:
		return maximum
	for track_index: int in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D or animation.track_get_key_count(track_index) < 2:
			continue
		var first: Quaternion = animation.track_get_key_value(track_index, 0)
		for key_index: int in range(1, animation.track_get_key_count(track_index)):
			var current: Quaternion = animation.track_get_key_value(track_index, key_index)
			maximum = maxf(maximum, first.angle_to(current))
	return maximum

func _animation_bone_motion(animation: Animation, bone_name: StringName) -> float:
	var maximum := 0.0
	if animation == null:
		return maximum
	for track_index: int in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D or animation.track_get_key_count(track_index) < 2:
			continue
		if String(animation.track_get_path(track_index)).get_slice(":", 1) != String(bone_name):
			continue
		var first: Quaternion = animation.track_get_key_value(track_index, 0)
		for key_index: int in range(1, animation.track_get_key_count(track_index)):
			maximum = maxf(maximum, first.angle_to(animation.track_get_key_value(track_index, key_index)))
	return maximum

func _probe_fifteen_unit_cache(director: Node, target: Node3D) -> void:
	var soldiers: Array[Node3D] = []
	for index: int in range(15):
		var soldier := ProbeSoldier.new()
		soldier.name = "CacheSoldier_%02d" % index
		soldier.ai_player = target
		soldier.behavior_mode = &"phalanx_veteran" if index % 5 == 0 else &"phalanx"
		soldier.position = Vector3(float(index % 5), 0.0, float(index / 5))
		soldier.set_meta("formation_group", &"fifteen_unit_probe")
		root.add_child(soldier)
		soldier.add_to_group("phalanx_unit")
		soldiers.append(soldier)
	director.phalanx_cache_frame = -1
	var snapshot_builds_before: int = director.group_snapshot_build_count
	var last_assignment: Dictionary = {}
	for soldier: Node3D in soldiers:
		last_assignment = director.phalanx_assignment(soldier, target)
	_expect(int(last_assignment.get("unit_count", 0)) == 15, "15-unit cohort was not assembled as one group")
	_expect(director.phalanx_group_build_count == 1, "15-unit formation was rebuilt %d times" % director.phalanx_group_build_count)
	_expect(director.group_snapshot_build_count == snapshot_builds_before + 1, "15 staggered soldiers rebuilt phalanx membership more than once")
	for soldier: Node3D in soldiers:
		soldier.queue_free()

func _probe_dismemberment(enemy: Node) -> void:
	var adapter: RefCounted = enemy.spartan_package_adapter
	_expect(adapter != null, "dismemberment adapter missing")
	if adapter == null:
		return
	var limb := DetachedLimb.new()
	root.add_child(limb)
	var detached_ok: bool = limb.setup(
		enemy.spartan_package_scene,
		adapter,
		&"forearm_l",
		enemy.skeleton.global_transform,
		0.12,
		0.36,
		Vector3.ZERO
	)
	_expect(detached_ok, "detached forearm could not be created")
	var detached_body := limb.find_child("SPARTAN_body_merged", true, false) as MeshInstance3D
	_expect(detached_body != null and detached_body.mesh.get_surface_count() == 1, "detached limb restored the segmented body")
	var severed_ok: bool = bool(adapter.call("sever_body", &"forearm_l"))
	_expect(severed_ok, "source forearm sever failed")
	var visibility: Dictionary = adapter.get("body_zone_visibility") as Dictionary
	_expect(not bool(visibility.get(&"forearm_l", true)), "severed forearm zone remained visible")
	limb.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
