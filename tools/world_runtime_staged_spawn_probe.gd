extends SceneTree

const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_per_frame: Variant = ProjectSettings.get_setting("hoplite/performance/spawn_per_frame", 2)
	var previous_budget: Variant = ProjectSettings.get_setting("hoplite/performance/spawn_budget_ms", 3.0)
	ProjectSettings.set_setting("hoplite/performance/spawn_per_frame", 1)
	ProjectSettings.set_setting("hoplite/performance/spawn_budget_ms", 12.0)

	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	root.add_child(runtime)
	runtime.editing = false
	runtime.world_root = Node3D.new()
	runtime.add_child(runtime.world_root)
	var holder := Node3D.new()
	runtime.world_root.add_child(holder)
	var entity := {
		"id": "staged_spawn_probe",
		"properties": {
			"group_id": "staged_probe",
			"count": 3,
			"archetype": "swordsman",
			"formation": "line",
		}
	}
	runtime.call("_queue_enemy_group_spawn", entity, null, holder, 3)
	runtime.set_process(false)

	for expected_count: int in range(1, 4):
		runtime.call("_process", 0.0)
		runtime.set_process(false)
		if holder.get_child_count() != expected_count:
			_fail("expected %d staged enemies after pass, got %d" % [expected_count, holder.get_child_count()])
			return
	if not runtime.pending_enemy_spawns.is_empty():
		_fail("spawn queue did not drain after the final staged enemy")
		return

	ProjectSettings.set_setting("hoplite/performance/spawn_per_frame", previous_per_frame)
	ProjectSettings.set_setting("hoplite/performance/spawn_budget_ms", previous_budget)
	runtime.queue_free()
	await process_frame
	print("WORLD_RUNTIME_STAGED_SPAWN_PROBE PASS: one configured enemy was created per processing pass")
	quit(0)


func _fail(message: String) -> void:
	push_error("WORLD_RUNTIME_STAGED_SPAWN_PROBE FAILED: " + message)
	quit(1)
