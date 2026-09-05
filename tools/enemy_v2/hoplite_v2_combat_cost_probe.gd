extends SceneTree

const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")

const ACTOR_COUNT := 50
const WARMUP_FRAMES := 12
const SAMPLE_FRAMES := 45


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	if not DisplayServer.get_name().contains("headless"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var results: Array[Dictionary] = []
	await _measure(&"warmup", 1, false, &"full", false)
	results.append(await _measure(&"visual_only_50", ACTOR_COUNT, false, &"full", true))
	results.append(await _measure(&"combat_anatomy_full_50", ACTOR_COUNT, true, &"full", true))
	results.append(await _measure(&"combat_anatomy_15hz_50", ACTOR_COUNT, true, &"15hz", true))
	results.append(await _measure(&"combat_anatomy_off_50", ACTOR_COUNT, true, &"off", true))
	print("HOPLITE_V2_COMBAT_COST_PROBE ", JSON.stringify(results))
	quit(0)


func _measure(label: StringName, count: int, combat_enabled: bool, anatomy_mode: StringName, collect: bool) -> Dictionary:
	var world := Node3D.new()
	world.name = String(label)
	root.add_child(world)
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, 12.0)
	world.add_child(target)
	var reference := Node3D.new()
	world.add_child(reference)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 7.5, -5.0)
	camera.far = 100.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 7.0))
	camera.current = true
	var actors: Array[HopliteEnemyActorV2] = []
	for index in range(count):
		var actor := Factory.create(&"ngeneral") as HopliteEnemyActorV2
		actor.position = Vector3((float(index % 10) - 4.5) * 1.20, 0.0, 5.0 + float(index / 10) * 1.05)
		actor.initial_semantic = &"block_idle"
		actor.lod_reference = reference
		actor.combat_lab_enabled = combat_enabled
		actor.combat_target = target if combat_enabled else null
		actor.troop_controlled = combat_enabled
		world.add_child(actor)
		actors.append(actor)
		if combat_enabled and actor.health_component != null and actor.health_component.anatomy != null:
			if anatomy_mode == &"15hz":
				actor.health_component.anatomy.set_update_interval(1.0 / 15.0)
			elif anatomy_mode == &"off":
				actor.health_component.anatomy.set_tracking_enabled(false)
	for frame in range(WARMUP_FRAMES):
		await physics_frame
	if not collect:
		world.queue_free()
		await process_frame
		return {}
	var samples: Array[float] = []
	var draw_calls_total := 0.0
	var primitives_total := 0.0
	for frame in range(SAMPLE_FRAMES):
		var started := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		draw_calls_total += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives_total += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	samples.sort()
	var total := 0.0
	for sample: float in samples:
		total += sample
	var result := {
		"scenario": String(label),
		"average_physics_frame_ms": snappedf(total / float(samples.size()), 0.001),
		"p95_physics_frame_ms": snappedf(samples[int(floor(float(samples.size() - 1) * 0.95))], 0.001),
		"nodes": _count_nodes(world),
		"anatomy_shapes": _count_anatomy_shapes(actors),
		"active_physics_objects": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"average_draw_calls": roundi(draw_calls_total / float(SAMPLE_FRAMES)),
		"average_primitives": roundi(primitives_total / float(SAMPLE_FRAMES)),
	}
	if combat_enabled:
		for actor: HopliteEnemyActorV2 in actors:
			actor.health_component.anatomy.set_physics_process(false)
		var manual_started := Time.get_ticks_usec()
		for iteration in range(30):
			for actor: HopliteEnemyActorV2 in actors:
				actor.health_component.anatomy.force_update()
		result["forced_anatomy_update_ms"] = snappedf(
			float(Time.get_ticks_usec() - manual_started) / 1000.0 / 30.0,
			0.001
		)
	world.queue_free()
	for frame in range(3):
		await process_frame
	return result


func _count_anatomy_shapes(actors: Array[HopliteEnemyActorV2]) -> int:
	var result := 0
	for actor: HopliteEnemyActorV2 in actors:
		if actor.health_component != null and actor.health_component.anatomy != null:
			result += actor.health_component.anatomy.zone_runtime.size()
	return result


func _count_nodes(node: Node) -> int:
	var result := 1
	for child: Node in node.get_children():
		result += _count_nodes(child)
	return result
