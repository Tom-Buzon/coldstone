extends SceneTree

const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 180


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	if not DisplayServer.get_name().contains("headless"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Prime the shared PackedScene/AnimationLibrary caches before comparing counts.
	await _measure_scenario(&"cache_warmup", 1, 6.0, 0.0, false)
	var results: Array[Dictionary] = []
	results.append(await _measure_scenario(&"near_1", 1, 6.0, 0.0, true))
	results.append(await _measure_scenario(&"near_24", 24, 6.0, 0.0, true))
	results.append(await _measure_scenario(&"near_60_overlap", 60, 6.0, 0.0, true))
	results.append(await _measure_scenario(&"near_60_grid", 60, 6.0, 1.05, true))
	results.append(await _measure_scenario(&"far_60", 60, 52.0, 0.35, true))
	print("HOPLITE_V2_PERFORMANCE_PROBE ", JSON.stringify(results))
	quit(0)


func _measure_scenario(
	label: StringName,
	actor_count: int,
	distance: float,
	spacing: float,
	collect_result: bool
) -> Dictionary:
	var world := Node3D.new()
	world.name = "PerformanceProbe_%s" % label
	root.add_child(world)
	var reference := Node3D.new()
	reference.name = "LodReference"
	world.add_child(reference)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.55, 0.0)
	camera.far = 120.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, distance))
	camera.current = true
	var actors: Array[HopliteEnemyActorV2] = []
	for index: int in range(actor_count):
		var actor := Factory.create(&"ngeneral") as HopliteEnemyActorV2
		actor.initial_semantic = &"phalanx_cycle"
		actor.lod_reference = reference
		# The near stress case deliberately reproduces the Forge overlap reported by
		# the user. Far units are spread very slightly only to keep the count legible.
		var column := index % 10
		var row := index / 10
		actor.position = Vector3((float(column) - 4.5) * spacing, 0.0, distance + float(row) * spacing)
		world.add_child(actor)
		actors.append(actor)
	for _frame: int in range(WARMUP_FRAMES):
		await process_frame
	if not collect_result:
		world.queue_free()
		for _frame: int in range(3):
			await process_frame
		return {}
	var samples: Array[float] = []
	var draw_call_total := 0.0
	var primitive_total := 0.0
	for _frame: int in range(SAMPLE_FRAMES):
		var started := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		draw_call_total += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		primitive_total += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	samples.sort()
	var total := 0.0
	for sample: float in samples:
		total += sample
	var lod_counts := [0, 0, 0, 0]
	for actor: HopliteEnemyActorV2 in actors:
		var level := clampi(int(actor.get_meta("enemy_v2_lod_level", -1)), 0, 3)
		lod_counts[level] += 1
	var result := {
		"scenario": String(label),
		"actors": actor_count,
		"average_frame_ms": snappedf(total / float(samples.size()), 0.001),
		"p95_frame_ms": snappedf(samples[int(floor(float(samples.size() - 1) * 0.95))], 0.001),
		"average_draw_calls": roundi(draw_call_total / float(SAMPLE_FRAMES)),
		"average_primitives": roundi(primitive_total / float(SAMPLE_FRAMES)),
		"lod_counts": lod_counts,
		"nodes": _count_nodes(world),
		"skeletons": _count_type(world, &"Skeleton3D"),
		"mesh_instances": _count_type(world, &"MeshInstance3D"),
		"animation_players": _count_type(world, &"AnimationPlayer"),
	}
	if not actors.is_empty():
		result["mesh_surfaces_per_actor"] = _mesh_surface_breakdown(actors[0])
	world.queue_free()
	for _frame: int in range(5):
		await process_frame
	return result


func _count_nodes(node: Node) -> int:
	var result := 1
	for child: Node in node.get_children():
		result += _count_nodes(child)
	return result


func _count_type(node: Node, type_name: StringName) -> int:
	var result := 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children():
		result += _count_type(child, type_name)
	return result


func _mesh_surface_breakdown(node: Node) -> Dictionary:
	var result := {}
	_collect_mesh_surfaces(node, result)
	return result


func _collect_mesh_surfaces(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			var key := String(instance.name)
			result[key] = int(result.get(key, 0)) + instance.mesh.get_surface_count()
	for child: Node in node.get_children():
		_collect_mesh_surfaces(child, result)
