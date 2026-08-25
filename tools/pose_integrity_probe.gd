extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy/athenian_enemy.gd")
const ArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "PoseIntegrityWorld"
	get_root().add_child(world)
	current_scene = world
	var failures := 0
	failures += await _probe_player(world)
	failures += await _probe_enemies(world)
	print("[POSE INTEGRITY] failures=", failures)
	world.free()
	quit(1 if failures > 0 else 0)

func _probe_player(world: Node3D) -> int:
	var player := PlayerScript.new() as HopliteUALNativePlayer
	world.add_child(player)
	for _frame: int in range(5):
		await physics_frame
		await process_frame
	if player.skeleton == null or player.animation_driver == null or player.animation_driver.external_bank == null:
		push_error("[POSE INTEGRITY] player animation system unavailable")
		player.queue_free()
		return 1
	var bank: HopliteExternalAnimationBank = player.animation_driver.external_bank
	var failures := 0
	for raw_key: Variant in bank.donors.keys():
		var key := StringName(raw_key)
		var donor: Dictionary = bank.donors[key]
		var donor_player := donor.get("player") as AnimationPlayer
		var source := donor.get("skeleton") as Skeleton3D
		var proxy := donor.get("proxy") as Skeleton3D
		var bridge := donor.get("bridge") as HopliteAuthoredPoseBridge
		var clip := StringName(donor.get("clip", StringName()))
		var animation := donor_player.get_animation(clip) if donor_player != null else null
		if source == null or proxy == null or bridge == null or animation == null:
			failures += 1
			continue
		var clip_failures := 0
		for fraction: float in [0.12, 0.32, 0.52, 0.72, 0.88]:
			donor_player.play(clip)
			donor_player.advance(0.0)
			donor_player.seek(animation.length * fraction, true)
			donor_player.pause()
			source.advance(0.0)
			bridge.set_attack_weight(1.0, true, 1.0)
			bridge.call("_process_modification_with_delta", 0.0)
			var reason := _skeleton_sanity(player.skeleton)
			if reason != "":
				clip_failures += 1
				push_error("[POSE INTEGRITY] %s @ %.2f: %s" % [key, fraction, reason])
		bridge.set_attack_weight(0.0, false, 0.0)
		donor_player.stop()
		failures += clip_failures
		print("[POSE INTEGRITY PLAYER] key=", key, " samples=5 failures=", clip_failures)
	player.queue_free()
	await process_frame
	return failures

func _probe_enemies(world: Node3D) -> int:
	var enemies: Array[HopliteAthenianEnemy] = []
	var cursor := 0
	for archetype: StringName in ArchetypesScript.roster_ids():
		var enemy := EnemyScript.new() as HopliteAthenianEnemy
		enemy.name = "PoseProbe_" + String(archetype)
		enemy.archetype_id = archetype
		enemy.character_package_path = ArchetypesScript.package_path(archetype)
		enemy.ai_enabled = false
		enemy.position = Vector3(float(cursor) * 3.0, 0.0, 0.0)
		world.add_child(enemy)
		enemies.append(enemy)
		cursor += 1
	for _frame: int in range(35):
		await physics_frame
		await process_frame
	var failures := 0
	for enemy: HopliteAthenianEnemy in enemies:
		if enemy.skeleton == null:
			push_error("[POSE INTEGRITY ENEMY] missing skeleton: " + enemy.name)
			failures += 1
			continue
		var head_y := _bone_world_y(enemy.skeleton, "DEF-head")
		var left_foot_y := _bone_world_y(enemy.skeleton, "DEF-foot.L")
		var right_foot_y := _bone_world_y(enemy.skeleton, "DEF-foot.R")
		var foot_y := (left_foot_y + right_foot_y) * 0.5
		var standing_height := head_y - foot_y
		var sane := _skeleton_sanity(enemy.skeleton)
		var upright := standing_height > 0.75
		if not upright or sane != "":
			push_error("[POSE INTEGRITY ENEMY] %s height=%.3f sanity=%s" % [enemy.name, standing_height, sane])
			failures += 1
		else:
			print("[POSE INTEGRITY ENEMY] ", enemy.name, " standing_height=", snappedf(standing_height, 0.001), " PASS")
	for enemy: HopliteAthenianEnemy in enemies:
		enemy.queue_free()
	await process_frame
	return failures

func _skeleton_sanity(skeleton: Skeleton3D) -> String:
	for index: int in range(skeleton.get_bone_count()):
		var pose := skeleton.get_bone_pose(index)
		if not pose.origin.is_finite() or not pose.basis.x.is_finite() or not pose.basis.y.is_finite() or not pose.basis.z.is_finite():
			return "non-finite transform on " + String(skeleton.get_bone_name(index))
		var determinant := absf(pose.basis.determinant())
		if determinant < 0.85 or determinant > 1.15:
			return "invalid scale/determinant %.3f on %s" % [determinant, skeleton.get_bone_name(index)]
	var head := _bone_global_origin(skeleton, "DEF-head")
	var hips := _bone_global_origin(skeleton, "DEF-hips")
	var left_hand := _bone_global_origin(skeleton, "DEF-hand.L")
	var right_hand := _bone_global_origin(skeleton, "DEF-hand.R")
	if head == Vector3.INF or hips == Vector3.INF:
		return "core bones missing"
	if head.distance_to(hips) < 0.25 or head.distance_to(hips) > 1.35:
		return "torso collapsed/extended"
	if left_hand.distance_to(hips) > 1.75 or right_hand.distance_to(hips) > 1.75:
		return "arm extended beyond anatomy"
	return ""

func _bone_global_origin(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	var index := skeleton.find_bone(bone_name)
	return skeleton.get_bone_global_pose(index).origin if index >= 0 else Vector3.INF

func _bone_world_y(skeleton: Skeleton3D, bone_name: String) -> float:
	var origin := _bone_global_origin(skeleton, bone_name)
	return skeleton.to_global(origin).y if origin != Vector3.INF else -INF
