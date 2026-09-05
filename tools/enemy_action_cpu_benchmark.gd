extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")
const BeginMarker = preload("res://tools/enemy_action_cpu_marker_begin.gd")
const EndMarker = preload("res://tools/enemy_action_cpu_marker_end.gd")

const POSITION_SPACING := 1.80
const MIXED_ARCHETYPES: Array[StringName] = [
	&"swordsman", &"guardian", &"spearman", &"nsbire2", &"captain",
]

var enemy_count: int = 56
var warmup_frames: int = 120
var sample_frames: int = 240
var seed_value: int = 84_271
var scenario: StringName = &"steady_clean"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _parse_arguments(OS.get_cmdline_user_args()):
		_finish({})
		return
	seed(seed_value)
	var combatants_before := get_nodes_in_group("combatant").size()
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var benchmark_root := Node3D.new()
	benchmark_root.name = "EnemyActionCpuBenchmark"
	root.add_child(benchmark_root)
	_add_floor(benchmark_root)

	var target := Node3D.new()
	target.name = "StableActionBenchmarkTarget"
	target.position = Vector3.ZERO
	benchmark_root.add_child(target)
	var crowd_director: Node = null
	if scenario != &"steady_clean":
		crowd_director = CrowdDirector.new()
		crowd_director.name = "ActionBenchmarkCrowdDirector"
		benchmark_root.add_child(crowd_director)

	var enemy_refs: Array[WeakRef] = []
	var enemies: Array[HopliteAthenianEnemy] = []
	var spawn_start_usec := Time.get_ticks_usec()
	for index: int in range(enemy_count):
		var request: SpawnRequest = SpawnRequest.new()
		request.archetype = _archetype_for(index)
		request.position = _spawn_position(index)
		request.target = target
		request.ai_enabled = true
		request.mass_battle_mode = true
		request.guard_index = index
		request.has_name_override = true
		request.name_override = "ActionCpuEnemy_%03d" % index
		var enemy := EnemyFactory.spawn_request(benchmark_root, request)
		if enemy == null:
			failures.append("factory returned null at index %d" % index)
			continue
		enemies.append(enemy)
		enemy_refs.append(weakref(enemy))
	var spawn_wall_usec := Time.get_ticks_usec() - spawn_start_usec
	if enemies.size() != enemy_count:
		failures.append("spawned %d/%d enemies" % [enemies.size(), enemy_count])

	if scenario == &"steady_clean":
		for enemy: HopliteAthenianEnemy in enemies:
			enemy.ai_think_timer = INF
			enemy.cached_ai_goal = {
				"active": false,
				"attack_player": false,
				"face_target": false,
				"target": enemy.global_position,
			}
			enemy.cached_ai_separation = Vector3.ZERO

	var begin_marker: BeginMarker = BeginMarker.new()
	begin_marker.name = "CpuBeginMarker"
	begin_marker.process_physics_priority = -1_000
	benchmark_root.add_child(begin_marker)
	var end_marker: EndMarker = EndMarker.new()
	end_marker.name = "CpuEndMarker"
	end_marker.process_physics_priority = 1_000
	benchmark_root.add_child(end_marker)
	end_marker.configure(begin_marker, warmup_frames, sample_frames)
	await end_marker.sampling_completed

	var samples_usec := end_marker.samples_usec
	var objects_during := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var objects_at_sample_start := end_marker.object_count_at_sample_start
	var objects_at_sample_end := end_marker.object_count_at_sample_end
	var crowd_director_was_in_region := crowd_director != null
	var summary := _summarize(samples_usec)
	if scenario == &"steady_clean" and objects_at_sample_end != objects_at_sample_start:
		failures.append(
			"steady sample object count grew from %d to %d"
			% [objects_at_sample_start, objects_at_sample_end]
		)
	var auxiliary_refs: Array[WeakRef] = [
		weakref(benchmark_root),
		weakref(target),
		weakref(begin_marker),
		weakref(end_marker),
	]
	if crowd_director != null:
		auxiliary_refs.append(weakref(crowd_director))
	benchmark_root.queue_free()
	await process_frame
	await process_frame

	var live_enemy_refs := 0
	for enemy_ref: WeakRef in enemy_refs:
		if enemy_ref.get_ref() != null:
			live_enemy_refs += 1
	var live_auxiliary_refs := 0
	for auxiliary_ref: WeakRef in auxiliary_refs:
		if auxiliary_ref.get_ref() != null:
			live_auxiliary_refs += 1
	var combatants_after := get_nodes_in_group("combatant").size()
	var objects_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	if live_enemy_refs != 0 or live_auxiliary_refs != 0 or combatants_after != combatants_before:
		failures.append(
			"teardown failed: enemy refs=%d, auxiliary refs=%d, combatants %d -> %d"
			% [live_enemy_refs, live_auxiliary_refs, combatants_before, combatants_after]
		)

	_finish({
		"callback_region_elapsed_usec": summary,
		"combatants_before": combatants_before,
		"combatants_after": combatants_after,
		"crowd_director_in_region": crowd_director_was_in_region,
		"enemy_count": enemy_count,
		"live_auxiliary_refs_after": live_auxiliary_refs,
		"live_enemy_refs_after": live_enemy_refs,
		"object_count_after": objects_after,
		"object_count_before": objects_before,
		"object_count_during": objects_during,
		"object_count_sample_end": objects_at_sample_end,
		"object_count_sample_start": objects_at_sample_start,
		"physics_priority_region": {"begin": -1_000, "default_enemies": 0, "end": 1_000},
		"sample_frames": sample_frames,
		"scenario": String(scenario),
		"spawn_wall_usec": spawn_wall_usec,
		"warmup_frames": warmup_frames,
	})


func _archetype_for(index: int) -> StringName:
	if scenario == &"mixed_roles":
		return MIXED_ARCHETYPES[index % MIXED_ARCHETYPES.size()]
	return &"swordsman"


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


func _spawn_position(index: int) -> Vector3:
	var columns := ceili(sqrt(float(enemy_count)))
	var row := index / columns
	var column := index % columns
	var centered_column := float(column) - float(columns - 1) * 0.5
	return Vector3(centered_column * POSITION_SPACING, 0.05, 6.0 + float(row) * POSITION_SPACING)


func _summarize(samples_usec: PackedInt64Array) -> Dictionary:
	if samples_usec.is_empty():
		failures.append("CPU marker recorded no samples")
		return {}
	var sorted_samples: Array[int] = []
	sorted_samples.resize(samples_usec.size())
	var total: int = 0
	for index: int in range(samples_usec.size()):
		var value := int(samples_usec[index])
		sorted_samples[index] = value
		total += value
	sorted_samples.sort()
	return {
		"max": sorted_samples.back(),
		"mean": float(total) / float(sorted_samples.size()),
		"min": sorted_samples.front(),
		"p50": _percentile(sorted_samples, 0.50),
		"p95": _percentile(sorted_samples, 0.95),
		"p99": _percentile(sorted_samples, 0.99),
		"samples": sorted_samples.size(),
	}


func _percentile(sorted_values: Array[int], fraction: float) -> int:
	var index := clampi(ceili(fraction * float(sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _parse_arguments(arguments: PackedStringArray) -> bool:
	for argument: String in arguments:
		if argument.begins_with("--scenario="):
			scenario = StringName(argument.trim_prefix("--scenario=").strip_edges().to_lower())
		elif argument.begins_with("--count="):
			enemy_count = _parse_bounded_int(argument.trim_prefix("--count="), "--count", 1, 128)
		elif argument.begins_with("--warmup="):
			warmup_frames = _parse_bounded_int(argument.trim_prefix("--warmup="), "--warmup", 0, 10_000)
		elif argument.begins_with("--frames="):
			sample_frames = _parse_bounded_int(argument.trim_prefix("--frames="), "--frames", 1, 100_000)
		elif argument.begins_with("--seed="):
			seed_value = _parse_bounded_int(argument.trim_prefix("--seed="), "--seed", -2_147_483_648, 2_147_483_647)
		else:
			failures.append("unknown argument: %s" % argument)
	if scenario not in [&"steady_clean", &"realistic_active", &"mixed_roles"]:
		failures.append("--scenario must be steady_clean, realistic_active or mixed_roles")
	return failures.is_empty()


func _parse_bounded_int(raw_value: String, option: String, minimum: int, maximum: int) -> int:
	if not raw_value.is_valid_int():
		failures.append("invalid %s value: %s" % [option, raw_value])
		return minimum
	var value := int(raw_value)
	if value < minimum or value > maximum:
		failures.append("%s must be between %d and %d: %d" % [option, minimum, maximum, value])
	return value


func _finish(result: Dictionary) -> void:
	var report := {
		"benchmark": "hoplite_enemy_action_callback_region",
		"command_line": OS.get_cmdline_args(),
		"controller_sha256": FileAccess.get_sha256("res://scripts/enemy/athenian_enemy.gd"),
		"display_server": DisplayServer.get_name(),
		"engine": Engine.get_version_info(),
		"failures": failures,
		"known_environment_noise": "Windows root-certificate-store errors are unrelated to local headless callbacks; JSON PASS covers harness assertions only and does not whitelist other engine errors.",
		"measurement_source_sha256": {
			"benchmark": FileAccess.get_sha256("res://tools/enemy_action_cpu_benchmark.gd"),
			"begin_marker": FileAccess.get_sha256("res://tools/enemy_action_cpu_marker_begin.gd"),
			"end_marker": FileAccess.get_sha256("res://tools/enemy_action_cpu_marker_end.gd"),
		},
		"measurement_contract": "Monotonic elapsed wall time between physics-priority markers bracketing the callback region. Includes OS preemption/stalls and every physics callback in the priority interval; it is not thread CPU time or FSM-only attribution. Preallocated sample buffer; one scenario per fresh process.",
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"renderer": String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"result": result,
		"seed": seed_value,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"user_arguments": OS.get_cmdline_user_args(),
		"version": 2,
	}
	print("ENEMY_ACTION_CALLBACK_REGION_BENCHMARK_JSON " + JSON.stringify(report, "", true))
	quit(0 if failures.is_empty() else 1)
