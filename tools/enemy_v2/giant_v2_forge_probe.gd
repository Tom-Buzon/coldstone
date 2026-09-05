extends SceneTree
const WorldRuntime = preload("res://scripts/world_editor/world_runtime.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var runtime := WorldRuntime.new()
	root.add_child(runtime)
	var target := Node3D.new()
	runtime.add_child(target)
	var failures: Array[String] = []
	for size: float in [3.0, 2.0]:
		var actor: Node3D = runtime._spawn_forge_enemy(runtime, &"enemy_v2_giant", Vector3(0, 0, 12), target, {"scale_multiplier": size, "v2_combat_lab": true, "ai_enabled": true, "v2_troop_mode": "giant"})
		if actor == null:
			failures.append("Forge giant absent")
			continue
		if not actor.scale.is_equal_approx(Vector3.ONE):
			failures.append("physical root scaled")
		if not actor.presentation.visual_root.scale.is_equal_approx(Vector3.ONE * size):
			failures.append("visual size incorrect")
		if actor.combat == null or actor.definition.unit_role != &"giant":
			failures.append("modular giant combat absent")
		if not actor.is_wall_run_giant() or (actor.collision_layer & 256) == 0:
			failures.append("giant not recognized by player traversal")
		if actor.presentation.skeleton.get_bone_count() != 53:
			failures.append("wrong giant rig")
		actor.queue_free()
		await process_frame
	print("GIANT_V2_FORGE ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	runtime.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
