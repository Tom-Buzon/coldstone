extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const CombatantRegistry = preload("res://scripts/enemy/combatant_registry.gd")

const DEFAULT_COUNTS: Array[int] = [12, 56]
const DEFAULT_WARMUP_FRAMES := 120
const DEFAULT_SAMPLE_FRAMES := 120
const DEFAULT_SEED := 13_371
const DEFAULT_ARCHETYPE: StringName = &"swordsman"
const POSITION_SPACING := 1.80


class MetricAccumulator:
	extends RefCounted

	var count: int = 0
	var total: float = 0.0
	var minimum: float = INF
	var maximum: float = -INF
	var values: Array[float] = []

	func add(value: float) -> void:
		count += 1
		total += value
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
		values.append(value)

	func summary() -> Dictionary:
		if count == 0:
			return {"max": 0.0, "mean": 0.0, "min": 0.0}
		var sorted_values := values.duplicate()
		sorted_values.sort()
		return {
			"max": maximum,
			"mean": total / float(count),
			"min": minimum,
			"p50": _percentile(sorted_values, 0.50),
			"p95": _percentile(sorted_values, 0.95),
			"p99": _percentile(sorted_values, 0.99),
		}

	func count_above(threshold: float) -> int:
		var result := 0
		for value: float in values:
			if value > threshold:
				result += 1
		return result

	func _percentile(sorted_values: Array[float], fraction: float) -> float:
		var index := clampi(ceili(fraction * float(sorted_values.size())) - 1, 0, sorted_values.size() - 1)
		return sorted_values[index]


var _counts: Array[int] = DEFAULT_COUNTS.duplicate()
var _warmup_frames: int = DEFAULT_WARMUP_FRAMES
var _sample_frames: int = DEFAULT_SAMPLE_FRAMES
var _seed_value: int = DEFAULT_SEED
var _archetype: StringName = DEFAULT_ARCHETYPE
var _modes: Array[StringName] = [&"idle", &"active"]
var _registry_enabled: bool = false
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _parse_arguments(OS.get_cmdline_user_args()):
		_finish([])
		return

	var scenario_results: Array[Dictionary] = []
	var scenario_index := 0
	for mode: StringName in _modes:
		for enemy_count: int in _counts:
			scenario_results.append(await _run_scenario(enemy_count, mode == &"active", scenario_index))
			scenario_index += 1
	_finish(scenario_results)


func _run_scenario(enemy_count: int, ai_enabled: bool, scenario_index: int) -> Dictionary:
	# Reset the global RNG because the enemy controller staggers internal timers
	# with randf_range(). Positions, targets and request data are deterministic.
	seed(_seed_value + enemy_count + (1_000_000 if ai_enabled else 0))

	var combatants_before := get_nodes_in_group("combatant").size()
	var monitor_before := _monitor_snapshot()
	var scenario_root := Node3D.new()
	scenario_root.name = "EnemyBenchmark_%s_%d" % ["active" if ai_enabled else "idle", enemy_count]
	root.add_child(scenario_root)
	_add_floor(scenario_root)

	var target := Node3D.new()
	target.name = "StableBenchmarkTarget"
	target.position = Vector3.ZERO
	scenario_root.add_child(target)

	var crowd_director := CrowdDirector.new()
	crowd_director.name = "BenchmarkCrowdDirector"
	scenario_root.add_child(crowd_director)
	var combatant_registry: CombatantRegistry
	var registry_ref: WeakRef
	if _registry_enabled:
		combatant_registry = CombatantRegistry.new()
		combatant_registry.name = "BenchmarkCombatantRegistry"
		scenario_root.add_child(combatant_registry)
		registry_ref = weakref(combatant_registry)

	var enemy_refs: Array[WeakRef] = []
	var spawn_start_usec := Time.get_ticks_usec()
	for index: int in range(enemy_count):
		var request: SpawnRequest = SpawnRequest.new()
		request.archetype = _archetype
		request.position = _spawn_position(index, enemy_count)
		request.target = target
		request.ai_enabled = ai_enabled
		request.mass_battle_mode = true
		request.guard_index = index
		request.has_name_override = true
		request.name_override = "BenchmarkEnemy_%03d" % index
		request.combatant_registry = combatant_registry
		var enemy := EnemyFactory.spawn_request(scenario_root, request)
		if enemy == null:
			_failures.append("factory returned null for enemy %d in %s/%d" % [index, "active" if ai_enabled else "idle", enemy_count])
			continue
		enemy_refs.append(weakref(enemy))
	var spawn_wall_ms := float(Time.get_ticks_usec() - spawn_start_usec) / 1_000.0

	var spawned_count := enemy_refs.size()
	if spawned_count != enemy_count:
		_failures.append("spawned %d/%d enemies in %s scenario" % [spawned_count, enemy_count, "active" if ai_enabled else "idle"])
	var combatants_during := get_nodes_in_group("combatant").size()
	if combatants_during - combatants_before != spawned_count:
		_failures.append(
			"combatant group delta was %d instead of %d in %s/%d"
			% [combatants_during - combatants_before, spawned_count, "active" if ai_enabled else "idle", enemy_count]
		)
	var registry_registered_during := combatant_registry.registered_count() if combatant_registry != null else 0
	if _registry_enabled and registry_registered_during != spawned_count:
		_failures.append("registry contained %d/%d spawned enemies" % [registry_registered_during, spawned_count])

	for _frame: int in range(_warmup_frames):
		await physics_frame
	for enemy_ref: WeakRef in enemy_refs:
		var enemy := enemy_ref.get_ref() as HopliteAthenianEnemy
		if enemy != null:
			enemy.ai_goal_evaluation_count = 0
			enemy.physics_full_step_count = 0
			enemy.physics_deferred_step_count = 0

	var physics_tick_interval_wall_ms := MetricAccumulator.new()
	var sample_start_usec := Time.get_ticks_usec()
	for _frame: int in range(_sample_frames):
		var frame_start_usec := Time.get_ticks_usec()
		await physics_frame
		physics_tick_interval_wall_ms.add(float(Time.get_ticks_usec() - frame_start_usec) / 1_000.0)
	var sample_wall_ms := float(Time.get_ticks_usec() - sample_start_usec) / 1_000.0
	var monitor_during := _monitor_snapshot()
	var ai_goal_evaluations := 0
	var physics_full_steps := 0
	var physics_deferred_steps := 0
	for enemy_ref: WeakRef in enemy_refs:
		var enemy := enemy_ref.get_ref() as HopliteAthenianEnemy
		if enemy != null:
			ai_goal_evaluations += enemy.ai_goal_evaluation_count
			physics_full_steps += enemy.physics_full_step_count
			physics_deferred_steps += enemy.physics_deferred_step_count
	var tick_interval_summary := physics_tick_interval_wall_ms.summary()
	var frame_budget_ms := 1_000.0 / float(Engine.physics_ticks_per_second)
	tick_interval_summary["budget_ms"] = frame_budget_ms
	tick_interval_summary["over_budget_count"] = physics_tick_interval_wall_ms.count_above(frame_budget_ms)

	scenario_root.queue_free()
	await process_frame
	await process_frame

	var leaked_instances := 0
	for enemy_ref: WeakRef in enemy_refs:
		if is_instance_valid(enemy_ref.get_ref()):
			leaked_instances += 1
	var combatants_after := get_nodes_in_group("combatant").size()
	var registry_live_after := registry_ref != null and registry_ref.get_ref() != null
	var cleanup_ok := leaked_instances == 0 and combatants_after == combatants_before and not registry_live_after
	if not cleanup_ok:
		_failures.append(
			"cleanup failed in %s/%d: %d live refs, combatants %d -> %d"
			% ["active" if ai_enabled else "idle", enemy_count, leaked_instances, combatants_before, combatants_after]
		)
	var monitor_after := _monitor_snapshot()

	return {
		"ai_enabled": ai_enabled,
		"archetype": String(_archetype),
		"structural_cleanup": {
			"combatants_after": combatants_after,
			"combatants_before": combatants_before,
			"live_enemy_refs": leaked_instances,
			"ok": cleanup_ok,
		},
		"enemy_count": enemy_count,
		"engine_time_monitors_diagnostic": {
			"fps_snapshot": float(Performance.get_monitor(Performance.TIME_FPS)),
			"note": "Slow-refresh snapshots only; not independent per-frame measurements and not a regression gate.",
			"physics_process_ms_snapshot": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1_000.0,
			"process_ms_snapshot": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1_000.0,
		},
		"mass_battle_mode": true,
		"script_work_counters": {
			"ai_goal_evaluations": ai_goal_evaluations,
			"physics_deferred_steps": physics_deferred_steps,
			"physics_full_steps": physics_full_steps,
			"physics_total_callbacks": physics_full_steps + physics_deferred_steps,
		},
		"monitors_after_structural_cleanup": monitor_after,
		"monitors_before": monitor_before,
		"monitors_during": monitor_during,
		"physics_tick_interval_wall_ms": tick_interval_summary,
		"resource_cache_state": "first_scenario_in_process" if scenario_index == 0 else "warmed_by_previous_scenario",
		"registry_enabled": _registry_enabled,
		"registry_live_ref_after": registry_live_after,
		"registry_registered_during": registry_registered_during,
		"sample_frames": _sample_frames,
		"sample_wall_ms": sample_wall_ms,
		"spawn_wall_ms": spawn_wall_ms,
		"spawned_count": spawned_count,
		"stable_target_assigned": true,
		"targeting_ai_enabled": ai_enabled,
		"warmup_frames": _warmup_frames,
	}


func _add_floor(parent: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "BenchmarkFloor"
	floor_body.position.y = -0.5
	parent.add_child(floor_body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 1.0, 80.0)
	collision.shape = shape
	floor_body.add_child(collision)


func _spawn_position(index: int, enemy_count: int) -> Vector3:
	var columns := ceili(sqrt(float(enemy_count)))
	var row := index / columns
	var column := index % columns
	var centered_column := float(column) - float(columns - 1) * 0.5
	return Vector3(centered_column * POSITION_SPACING, 0.05, 6.0 + float(row) * POSITION_SPACING)


func _monitor_snapshot() -> Dictionary:
	return {
		"memory_static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"physics_3d_active_objects": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


func _parse_arguments(arguments: PackedStringArray) -> bool:
	for argument: String in arguments:
		if argument.begins_with("--counts="):
			var parsed_counts: Array[int] = []
			var raw_counts := argument.trim_prefix("--counts=")
			if raw_counts.strip_edges().is_empty():
				_failures.append("--counts cannot be empty")
				continue
			for raw_count: String in raw_counts.split(",", false):
				var value := raw_count.strip_edges()
				if not value.is_valid_int():
					_failures.append("invalid --counts value: %s" % value)
					continue
				var count := int(value)
				if count < 1 or count > 512:
					_failures.append("--counts entries must be between 1 and 512: %d" % count)
					continue
				parsed_counts.append(count)
			if not parsed_counts.is_empty():
				_counts = parsed_counts
		elif argument.begins_with("--warmup="):
			_warmup_frames = _parse_positive_int(argument.trim_prefix("--warmup="), "--warmup", true)
		elif argument.begins_with("--frames="):
			_sample_frames = _parse_positive_int(argument.trim_prefix("--frames="), "--frames", false)
		elif argument.begins_with("--seed="):
			var raw_seed := argument.trim_prefix("--seed=")
			if raw_seed.is_valid_int():
				_seed_value = int(raw_seed)
			else:
				_failures.append("invalid --seed value: %s" % raw_seed)
		elif argument.begins_with("--archetype="):
			var raw_archetype := argument.trim_prefix("--archetype=").strip_edges()
			if raw_archetype.is_empty():
				_failures.append("--archetype cannot be empty")
			else:
				_archetype = StringName(raw_archetype)
		elif argument.begins_with("--mode="):
			var mode := StringName(argument.trim_prefix("--mode=").strip_edges().to_lower())
			match mode:
				&"idle":
					_modes = [&"idle"]
				&"active":
					_modes = [&"active"]
				&"both":
					_modes = [&"idle", &"active"]
				_:
					_failures.append("--mode must be idle, active or both: %s" % mode)
		elif argument.begins_with("--registry="):
			var registry_mode := argument.trim_prefix("--registry=").strip_edges().to_lower()
			if registry_mode == "on":
				_registry_enabled = true
			elif registry_mode == "off":
				_registry_enabled = false
			else:
				_failures.append("--registry must be on or off: %s" % registry_mode)
		else:
			_failures.append("unknown argument: %s" % argument)
	if not Archetypes.all_ids().has(_archetype):
		_failures.append("unknown canonical archetype: %s" % _archetype)
	return _failures.is_empty() and not _counts.is_empty() and _sample_frames > 0 and _warmup_frames >= 0


func _parse_positive_int(raw_value: String, option: String, allow_zero: bool) -> int:
	if not raw_value.is_valid_int():
		_failures.append("invalid %s value: %s" % [option, raw_value])
		return 0
	var value := int(raw_value)
	var minimum := 0 if allow_zero else 1
	if value < minimum or value > 100_000:
		_failures.append("%s must be between %d and 100000: %d" % [option, minimum, value])
	return value


func _finish(scenarios: Array[Dictionary]) -> void:
	var report := {
		"benchmark": "hoplite_enemy_performance",
		"command_line": OS.get_cmdline_args(),
		"cleanup_contract": "WeakRefs and combatant groups validate scene teardown only; memory/resource snapshots are not leak proof.",
		"display_server": DisplayServer.get_name(),
		"engine": Engine.get_version_info(),
		"failures": _failures,
		"headless": DisplayServer.get_name() == "headless",
		"measurement_contract": "Spawn wall time, structural snapshots and paced physics-tick intervals. Engine TIME_* values are diagnostic snapshots only.",
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"renderer": String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"registry_enabled": _registry_enabled,
		"scenarios": scenarios,
		"seed": _seed_value,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"user_arguments": OS.get_cmdline_user_args(),
		"version": 3,
	}
	print("ENEMY_PERFORMANCE_BENCHMARK_JSON " + JSON.stringify(report, "", true))
	quit(0 if _failures.is_empty() else 1)
