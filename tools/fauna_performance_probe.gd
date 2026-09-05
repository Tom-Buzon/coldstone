extends SceneTree

const FaunaSettingsScript = preload("res://scripts/fauna/fauna_settings.gd")
const FaunaManagerScript = preload("res://scripts/fauna/fauna_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	_add_floor(scene)
	var player := Node3D.new()
	player.position.y = 0.05
	scene.add_child(player)
	var manager := FaunaManagerScript.new() as HopliteFaunaManager
	scene.add_child(manager)
	manager.configure(player)
	await process_frame

	var stress_values: Dictionary = FaunaSettingsScript.defaults()
	stress_values[&"budget"] = FaunaSettingsScript.MAX_TOTAL_ANIMALS
	stress_values[&"simulation_distance"] = 180.0
	for definition: Dictionary in FaunaSettingsScript.SPECIES:
		var species_id := StringName(definition["id"])
		stress_values[FaunaSettingsScript.species_key(species_id, "count")] = 12
	manager.reload_fauna_settings(stress_values)
	await _wait_for_population(manager, FaunaSettingsScript.MAX_TOTAL_ANIMALS)
	var stress_count := manager.get_total_active()
	var stress_ms := await _measure_physics_frames(180)

	var default_values: Dictionary = FaunaSettingsScript.defaults()
	default_values[&"simulation_distance"] = 180.0
	manager.reload_fauna_settings(default_values)
	var default_target := 0
	for raw_count: Variant in FaunaSettingsScript.target_counts(default_values).values():
		default_target += int(raw_count)
	await _wait_for_population(manager, default_target)
	var default_count := manager.get_total_active()
	var default_ms := await _measure_physics_frames(180)

	var mesh_count := scene.find_children("*", "MeshInstance3D", true, false).size()
	var animation_player_count := scene.find_children("*", "AnimationPlayer", true, false).size()
	print("FAUNA_PERFORMANCE_PROBE: default=%d physics=%.3fms | stress=%d physics=%.3fms | meshes=%d animation_players=%d hard_cap=%d" % [default_count, default_ms, stress_count, stress_ms, mesh_count, animation_player_count, FaunaSettingsScript.MAX_TOTAL_ANIMALS])
	if stress_count != FaunaSettingsScript.MAX_TOTAL_ANIMALS or default_count != default_target:
		push_error("FAUNA_PERFORMANCE_PROBE: population cap/reconciliation failed")
		quit(1)
		return
	quit(0)

func _add_floor(scene: Node3D) -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(420.0, 0.2, 420.0)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.1
	scene.add_child(floor)


func _wait_for_population(manager: HopliteFaunaManager, expected: int) -> void:
	for _frame: int in range(900):
		await physics_frame
		if manager.get_total_active() == expected:
			await physics_frame
			return


func _measure_physics_frames(frame_count: int) -> float:
	var total_seconds := 0.0
	for _frame: int in range(frame_count):
		await physics_frame
		total_seconds += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	return total_seconds * 1000.0 / float(frame_count)
