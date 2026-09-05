extends SceneTree

const WorldDocument = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntime = preload("res://scripts/world_editor/world_runtime.gd")

const WORLD_PATH := "user://hoplite_worlds/champsdebataille_v2_150.hoplite.json"
const SAMPLE_FRAMES := 45


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world_path := _requested_world_path()
	var file := FileAccess.open(world_path, FileAccess.READ)
	if file == null:
		push_error("Battlefield render probe cannot open %s" % world_path)
		quit(1)
		return
	var document := WorldDocument.from_json(file.get_as_text())
	file.close()
	if document == null:
		push_error("Battlefield render probe document is invalid")
		quit(1)
		return
	var full_map := OS.get_cmdline_user_args().has("--full-map")
	if not full_map:
		_cap_document_to_fifty(document)
	var host := Node3D.new()
	host.name = "BattlefieldRenderProbe"
	root.add_child(host)
	current_scene = host
	var runtime := WorldRuntime.new()
	host.add_child(runtime)
	runtime.build(document, false)
	var timeout := 900
	while not runtime.pending_enemy_spawns.is_empty() and timeout > 0:
		await process_frame
		timeout -= 1
	if timeout <= 0:
		push_error("Battlefield render probe spawn timed out")
		quit(1)
		return
	for frame in range(30):
		await process_frame
	var actors := _v2_actors(runtime)
	if OS.get_cmdline_user_args().has("--settings-only"):
		print("HOPLITE_V2_BATTLEFIELD_RENDER_SETTINGS ", _lod_settings(actors))
		runtime.free()
		quit(0)
		return
	var population_label := str(actors.size())
	var results: Array[Dictionary] = []
	results.append(await _sample(StringName("battlefield_%s_full" % population_label), runtime, actors))
	for actor: HopliteEnemyActorV2 in actors:
		if actor.health_component != null and actor.health_component.anatomy != null:
			actor.health_component.anatomy.set_runtime_query_enabled(true)
			actor.health_component.anatomy.set_update_interval(1.0 / 15.0)
	results.append(await _sample(StringName("battlefield_%s_anatomy_15hz" % population_label), runtime, actors))
	for actor: HopliteEnemyActorV2 in actors:
		if actor.health_component != null and actor.health_component.anatomy != null:
			actor.health_component.anatomy.set_runtime_query_enabled(false)
	results.append(await _sample(StringName("battlefield_%s_anatomy_off" % population_label), runtime, actors))
	if runtime.enemy_v2_troop_runtime != null:
		runtime.enemy_v2_troop_runtime.set_process(false)
	for actor: HopliteEnemyActorV2 in actors:
		actor.set_physics_process(false)
	results.append(await _sample(StringName("battlefield_%s_member_physics_off" % population_label), runtime, actors))
	for actor: HopliteEnemyActorV2 in actors:
		if actor.performance_lod != null:
			actor.performance_lod.set_process(false)
		if actor.animation != null and actor.animation.player != null:
			actor.animation.player.active = false
	results.append(await _sample(StringName("battlefield_%s_animation_off" % population_label), runtime, actors))
	for actor: HopliteEnemyActorV2 in actors:
		actor.visible = false
		actor.process_mode = Node.PROCESS_MODE_DISABLED
	results.append(await _sample(&"battlefield_without_enemies", runtime, actors))
	print("HOPLITE_V2_BATTLEFIELD_RENDER_COST_PROBE ", JSON.stringify(results))
	runtime.queue_free()
	await process_frame
	host.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _requested_world_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			return argument.trim_prefix("--world=")
	return WORLD_PATH


func _cap_document_to_fifty(document: HopliteWorldDocument) -> void:
	var kept_phalanxes := 0
	for raw: Variant in document.data.get("entities", []):
		if not raw is Dictionary or String((raw as Dictionary).get("type", "")) != "enemy_group":
			continue
		var entity := raw as Dictionary
		var properties := entity.get("properties", {}) as Dictionary
		if StringName(properties.get("v2_troop_mode", &"")) == &"hoplite_phalanx" and kept_phalanxes < 2:
			kept_phalanxes += 1
			continue
		if String(properties.get("formation", "")) == "line" and kept_phalanxes >= 2:
			properties["count"] = 2
			properties["composition"] = [{"archetype": "enemy_v2_hoplite_veteran", "count": 2}]
			continue
		entity["enabled"] = false


func _v2_actors(runtime: HopliteWorldRuntime) -> Array[HopliteEnemyActorV2]:
	var result: Array[HopliteEnemyActorV2] = []
	for raw_group: Variant in runtime.enemies_by_group.values():
		for raw_actor: Variant in raw_group as Array:
			if raw_actor is HopliteEnemyActorV2:
				result.append(raw_actor as HopliteEnemyActorV2)
	return result


func _sample(label: StringName, runtime: HopliteWorldRuntime, actors: Array[HopliteEnemyActorV2]) -> Dictionary:
	for frame in range(12):
		await process_frame
	var samples: Array[float] = []
	var draw_calls_total := 0.0
	var primitives_total := 0.0
	var sample_frames := SAMPLE_FRAMES
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sample-frames="): sample_frames = clampi(int(argument.trim_prefix("--sample-frames=")), 30, 360)
	for frame in range(sample_frames):
		var started := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		draw_calls_total += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives_total += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	samples.sort()
	var total := 0.0
	for sample: float in samples:
		total += sample
	return {
		"scenario": String(label),
		"actors": actors.size(),
		"sample_frames": sample_frames,
		"average_frame_ms": snappedf(total / float(samples.size()), 0.001),
		"p95_frame_ms": snappedf(samples[int(floor(float(samples.size() - 1) * 0.95))], 0.001),
		"average_draw_calls": roundi(draw_calls_total / float(sample_frames)),
		"average_primitives": roundi(primitives_total / float(sample_frames)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"active_physics_objects": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"troop_decision_ticks": runtime.enemy_v2_troop_runtime.total_decision_ticks if runtime.enemy_v2_troop_runtime != null else -1,
		"lod_distribution": _lod_distribution(actors),
		"movement_distribution": _movement_distribution(actors),
		"anatomy_distribution": _anatomy_distribution(actors),
		"lod_settings": _lod_settings(actors),
	}


func _lod_distribution(actors: Array[HopliteEnemyActorV2]) -> Dictionary:
	var result := {"lod0": 0, "lod1": 0, "lod2": 0, "culled": 0}
	for actor: HopliteEnemyActorV2 in actors:
		var level := clampi(actor.simulation_lod_level, 0, 3)
		var key: String = ["lod0", "lod1", "lod2", "culled"][level]
		result[key] = int(result[key]) + 1
	return result


func _anatomy_distribution(actors: Array[HopliteEnemyActorV2]) -> Dictionary:
	var result := {"exact": 0, "coarse": 0, "off": 0}
	for actor: HopliteEnemyActorV2 in actors:
		var mode := String(actor.get_meta("enemy_v2_anatomy_mode", &"off"))
		if not result.has(mode):
			mode = "off"
		result[mode] = int(result[mode]) + 1
	return result


func _movement_distribution(actors: Array[HopliteEnemyActorV2]) -> Dictionary:
	var result := {"individual_physics": 0, "troop_transform": 0, "standalone": 0}
	for actor: HopliteEnemyActorV2 in actors:
		var mode := String(actor.get_meta(
			"enemy_v2_movement_mode",
			&"standalone" if not actor.troop_controlled else &"troop_transform"
		))
		if not result.has(mode):
			mode = "standalone"
		result[mode] = int(result[mode]) + 1
	return result


func _lod_settings(actors: Array[HopliteEnemyActorV2]) -> Dictionary:
	if actors.is_empty() or actors[0].performance_lod == null:
		return {}
	var settings := actors[0].performance_lod.current_settings
	return {
		"enabled": bool(settings.get("enabled", false)),
		"near": float(settings.get("near", 0.0)),
		"far": float(settings.get("far", 0.0)),
		"cull": float(settings.get("cull", 0.0)),
		"full_rate": float(settings.get("full_rate", 0.0)),
		"medium_hz": float(settings.get("medium_hz", 0.0)),
		"far_hz": float(settings.get("far_hz", 0.0)),
	}
