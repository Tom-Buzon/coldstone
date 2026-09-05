extends SceneTree

const RegistryScript = preload("res://scripts/enemy/combatant_registry.gd")

const DEFAULT_COMBATANT_COUNT := 56
const DEFAULT_ANALYZED_SAMPLES := 100
const DEFAULT_SEED := 73_031
const SACRIFICED_SAMPLES := 5


class BenchmarkCombatant extends Node:
	signal died(combatant: Node)

	var faction: StringName = &"athenian"
	var ai_enabled: bool = true
	var dead: bool = false

	func is_dead_for_combat() -> bool:
		return dead


var _combatant_count: int = DEFAULT_COMBATANT_COUNT
var _analyzed_samples: int = DEFAULT_ANALYZED_SAMPLES
var _seed_value: int = DEFAULT_SEED
var _initial_a_first: bool = true
var _run_index: int = 0
var _smoke_mode: bool = false
var _failures: Array[String] = []
var _measurement_issues: Array[String] = []
var _last_success_count: int = 0
var _checksum_sink: int = 0
var _control_batch_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _parse_arguments(OS.get_cmdline_user_args()):
		_finish({}, {})
		return

	var monitor_before_fixture := _object_snapshot()
	var stage := Node.new()
	stage.name = "EnemyRegistryOperationBenchmark"
	root.add_child(stage)
	var stage_ref: WeakRef = weakref(stage)
	var combatants: Array[Node] = []
	var combatant_refs: Array[WeakRef] = []
	for index: int in range(_combatant_count):
		var combatant := BenchmarkCombatant.new()
		combatant.name = "SyntheticCombatant_%03d" % index
		combatant.process_mode = Node.PROCESS_MODE_DISABLED
		stage.add_child(combatant)
		combatants.append(combatant)
		combatant_refs.append(weakref(combatant))

	var unregister_order := _seeded_order(combatants)
	var baseline_connections := _connection_count(combatants)
	var monitor_before := _object_snapshot()
	var cold_results: Dictionary = await _measure_cold(stage, combatants, unregister_order, baseline_connections)
	var monitor_after_cold := _object_snapshot()

	var warm_results: Dictionary = await _measure_warm(stage, combatants, unregister_order, baseline_connections)
	var monitor_after_warm := _object_snapshot()

	stage.queue_free()
	await process_frame
	await process_frame
	if stage_ref.get_ref() != null:
		_failures.append("fixture stage remained alive after teardown")
	var live_combatant_refs := 0
	for combatant_ref: WeakRef in combatant_refs:
		if combatant_ref.get_ref() != null:
			live_combatant_refs += 1
	if live_combatant_refs != 0:
		_failures.append("%d synthetic combatants remained alive after teardown" % live_combatant_refs)
	var stage_live_after := stage_ref.get_ref() != null
	combatants.clear()
	unregister_order.clear()
	combatant_refs.clear()
	stage_ref = null
	await process_frame
	var monitor_after_complete_teardown := _object_snapshot()
	_assert_complete_teardown("complete fixture teardown", monitor_before_fixture, monitor_after_complete_teardown)

	var structure := {
		"baseline_connections": baseline_connections,
		"checksum": _checksum_sink,
		"control_batch_count": _control_batch_count,
		"live_combatant_refs_after": live_combatant_refs,
		"monitors_after_complete_teardown": monitor_after_complete_teardown,
		"monitors_after_cold": monitor_after_cold,
		"monitors_after_warm": monitor_after_warm,
		"monitors_before_fixture": monitor_before_fixture,
		"monitors_before": monitor_before,
		"stage_live_after": stage_live_after,
	}
	_finish({"cold": cold_results, "warm": warm_results}, structure)


func _measure_cold(
	stage: Node,
	combatants: Array[Node],
	unregister_order: Array[Node],
	baseline_connections: int
) -> Dictionary:
	var control_usec: Array[float] = []
	var register_raw_usec: Array[float] = []
	var register_net_usec: Array[float] = []
	var unregister_raw_usec: Array[float] = []
	var unregister_net_usec: Array[float] = []
	var window_baseline: Dictionary = {}
	var total_samples := _analyzed_samples + SACRIFICED_SAMPLES
	for sample_index: int in range(total_samples):
		var registry: RegistryScript = RegistryScript.new()
		registry.name = "ColdRegistry_%03d" % sample_index
		stage.add_child(registry)
		var registry_ref: WeakRef = weakref(registry)
		var a_first := _sample_a_first(_order_index(sample_index))
		var control_elapsed: int
		var register_elapsed: int
		if a_first:
			control_elapsed = _measure_control_batch(combatants)
			register_elapsed = _measure_register_batch(registry, combatants)
		else:
			register_elapsed = _measure_register_batch(registry, combatants)
			control_elapsed = _measure_control_batch(combatants)
		if _last_success_count != _combatant_count:
			_failures.append("cold sample %d registered %d/%d" % [sample_index, _last_success_count, _combatant_count])
		var registered_snapshot: Array[Node] = registry.snapshot()
		if not _same_nodes(registered_snapshot, combatants):
			_failures.append("cold sample %d changed registration order" % sample_index)
		var validated_scripts: Dictionary = registry.get("_validated_scripts")
		if validated_scripts.size() != 1:
			_failures.append("cold sample %d cached %d Scripts instead of 1" % [sample_index, validated_scripts.size()])
		var unregister_elapsed := _measure_unregister_batch(registry, unregister_order)
		if _last_success_count != _combatant_count:
			_failures.append("cold sample %d unregistered %d/%d" % [sample_index, _last_success_count, _combatant_count])
		if registry.registered_count() != 0:
			_failures.append("cold sample %d did not return registry to zero" % sample_index)
		var connections_while_unregistered := _connection_count(combatants)
		var expected_connected := baseline_connections + _combatant_count * 2
		if connections_while_unregistered != expected_connected:
			_failures.append(
				"cold sample %d retained %d connections instead of %d after unregister"
				% [sample_index, connections_while_unregistered, expected_connected]
			)

		registry.queue_free()
		await process_frame
		if registry_ref.get_ref() != null:
			_failures.append("cold sample %d retained its registry" % sample_index)
		registry_ref = null
		var connections_after := _connection_count(combatants)
		if connections_after != baseline_connections:
			_failures.append(
				"cold sample %d left %d connections instead of %d"
				% [sample_index, connections_after, baseline_connections]
			)

		if sample_index < SACRIFICED_SAMPLES:
			if sample_index == SACRIFICED_SAMPLES - 1:
				window_baseline = _object_snapshot()
			continue
		var control_value := float(control_elapsed)
		control_usec.append(control_value)
		register_raw_usec.append(float(register_elapsed))
		register_net_usec.append(maxf(0.0, float(register_elapsed) - control_value))
		unregister_raw_usec.append(float(unregister_elapsed))
		unregister_net_usec.append(maxf(0.0, float(unregister_elapsed) - control_value))

	var window_after := _object_snapshot()
	_assert_stable_object_window("cold", window_baseline, window_after)
	var control_summary := _summary(control_usec)
	var register_raw_summary := _summary(register_raw_usec)
	var register_net_summary := _summary(register_net_usec)
	if float(control_summary["p95"]) > 50.0:
		_measurement_issues.append("cold control p95 %.3f us exceeded 50 us" % float(control_summary["p95"]))
	if float(control_summary["p95"]) > float(register_raw_summary["p50"]) * 0.10:
		_measurement_issues.append(
			"cold control p95 %.3f us exceeded 10%% of register p50 %.3f us"
			% [control_summary["p95"], register_raw_summary["p50"]]
		)
	return {
		"analyzed_samples": _analyzed_samples,
		"control_usec": control_summary,
		"register_net_usec": register_net_summary,
		"register_raw_usec": register_raw_summary,
		"raw_samples": {
			"control_usec": control_usec,
			"register_net_usec": register_net_usec,
			"register_raw_usec": register_raw_usec,
			"unregister_net_usec_diagnostic": unregister_net_usec,
			"unregister_raw_usec": unregister_raw_usec,
		},
		"sacrificed_samples": SACRIFICED_SAMPLES,
		"unregister_net_usec_diagnostic": _summary(unregister_net_usec),
		"unregister_raw_usec": _summary(unregister_raw_usec),
		"window_after": window_after,
		"window_baseline_after_sacrifice": window_baseline,
	}


func _measure_warm(
	stage: Node,
	combatants: Array[Node],
	unregister_order: Array[Node],
	baseline_connections: int
) -> Dictionary:
	var registry: RegistryScript = RegistryScript.new()
	registry.name = "WarmRegistry"
	stage.add_child(registry)
	var registry_ref: WeakRef = weakref(registry)
	if not registry.register_combatant(combatants[0]) or not registry.unregister_combatant(combatants[0]):
		_failures.append("warm registry preheat failed")

	var control_usec: Array[float] = []
	var register_net_usec: Array[float] = []
	var register_raw_usec: Array[float] = []
	var unregister_net_usec: Array[float] = []
	var unregister_raw_usec: Array[float] = []
	var window_baseline: Dictionary = {}
	var total_samples := _analyzed_samples + SACRIFICED_SAMPLES
	for sample_index: int in range(total_samples):
		var a_first := _sample_a_first(_order_index(sample_index))
		var control_elapsed: int
		var register_elapsed: int
		if a_first:
			control_elapsed = _measure_control_batch(combatants)
			register_elapsed = _measure_register_batch(registry, combatants)
		else:
			register_elapsed = _measure_register_batch(registry, combatants)
			control_elapsed = _measure_control_batch(combatants)
		if _last_success_count != _combatant_count:
			_failures.append("warm sample %d registered %d/%d" % [sample_index, _last_success_count, _combatant_count])
		if not _same_nodes(registry.snapshot(), combatants):
			_failures.append("warm sample %d changed registration order" % sample_index)
		var validated_scripts: Dictionary = registry.get("_validated_scripts")
		if validated_scripts.size() != 1:
			_failures.append("warm sample %d cached %d Scripts instead of 1" % [sample_index, validated_scripts.size()])
		var unregister_elapsed := _measure_unregister_batch(registry, unregister_order)
		if _last_success_count != _combatant_count:
			_failures.append("warm sample %d unregistered %d/%d" % [sample_index, _last_success_count, _combatant_count])
		if registry.registered_count() != 0:
			_failures.append("warm sample %d did not return registry to zero" % sample_index)
		var connections_while_unregistered := _connection_count(combatants)
		var expected_connected := baseline_connections + _combatant_count * 2
		if connections_while_unregistered != expected_connected:
			_failures.append(
				"warm sample %d retained %d connections instead of %d after unregister"
				% [sample_index, connections_while_unregistered, expected_connected]
			)
		if sample_index < SACRIFICED_SAMPLES:
			if sample_index == SACRIFICED_SAMPLES - 1:
				window_baseline = _object_snapshot()
			continue
		var control_value := float(control_elapsed)
		control_usec.append(control_value)
		register_raw_usec.append(float(register_elapsed))
		register_net_usec.append(maxf(0.0, float(register_elapsed) - control_value))
		unregister_raw_usec.append(float(unregister_elapsed))
		unregister_net_usec.append(maxf(0.0, float(unregister_elapsed) - control_value))

	var window_after := _object_snapshot()
	_assert_stable_object_window("warm", window_baseline, window_after)
	registry.queue_free()
	await process_frame
	if registry_ref.get_ref() != null:
		_failures.append("warm registry remained alive after teardown")
	registry_ref = null
	var connections_after := _connection_count(combatants)
	if connections_after != baseline_connections:
		_failures.append(
			"warm teardown left %d connections instead of %d"
			% [connections_after, baseline_connections]
		)
	return {
		"analyzed_samples": _analyzed_samples,
		"control_usec": _summary(control_usec),
		"register_net_usec": _summary(register_net_usec),
		"register_raw_usec": _summary(register_raw_usec),
		"raw_samples": {
			"control_usec": control_usec,
			"register_net_usec": register_net_usec,
			"register_raw_usec": register_raw_usec,
			"unregister_net_usec_diagnostic": unregister_net_usec,
			"unregister_raw_usec": unregister_raw_usec,
		},
		"sacrificed_samples": SACRIFICED_SAMPLES,
		"unregister_net_usec_diagnostic": _summary(unregister_net_usec),
		"unregister_raw_usec": _summary(unregister_raw_usec),
		"window_after": window_after,
		"window_baseline_after_sacrifice": window_baseline,
	}


func _measure_control_batch(combatants: Array[Node]) -> int:
	var checksum := 0
	var start_usec := Time.get_ticks_usec()
	for combatant: Node in combatants:
		checksum = checksum ^ combatant.get_instance_id()
		checksum += 1 if bool(combatant.get("ai_enabled")) else 0
		checksum = checksum ^ hash(combatant.get("faction"))
	var elapsed := Time.get_ticks_usec() - start_usec
	_checksum_sink += checksum
	_control_batch_count += 1
	return elapsed


func _measure_register_batch(registry: RegistryScript, combatants: Array[Node]) -> int:
	var successes := 0
	var start_usec := Time.get_ticks_usec()
	for combatant: Node in combatants:
		if registry.register_combatant(combatant):
			successes += 1
	var elapsed := Time.get_ticks_usec() - start_usec
	_last_success_count = successes
	return elapsed


func _measure_unregister_batch(registry: RegistryScript, combatants: Array[Node]) -> int:
	var successes := 0
	var start_usec := Time.get_ticks_usec()
	for combatant: Node in combatants:
		if registry.unregister_combatant(combatant):
			successes += 1
	var elapsed := Time.get_ticks_usec() - start_usec
	_last_success_count = successes
	return elapsed


func _seeded_order(combatants: Array[Node]) -> Array[Node]:
	var result := combatants.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value
	for index: int in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: Node = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temporary
	return result


func _sample_a_first(sample_index: int) -> bool:
	return _initial_a_first if sample_index % 2 == 0 else not _initial_a_first


func _order_index(sample_index: int) -> int:
	# Sacrificial and analyzed samples each start from the declared process order.
	return sample_index if sample_index < SACRIFICED_SAMPLES else sample_index - SACRIFICED_SAMPLES


func _connection_count(combatants: Array[Node]) -> int:
	var result := 0
	for combatant: Node in combatants:
		result += combatant.get_signal_connection_list(&"died").size()
		result += combatant.get_signal_connection_list(&"tree_exiting").size()
	return result


func _same_nodes(actual: Array[Node], expected: Array[Node]) -> bool:
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if actual[index] != expected[index]:
			return false
	return true


func _summary(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "max": 0.0, "mean": 0.0, "min": 0.0, "p50": 0.0, "p95": 0.0}
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var total := 0.0
	for value: float in sorted_values:
		total += value
	return {
		"count": sorted_values.size(),
		"max": sorted_values.back(),
		"mean": total / float(sorted_values.size()),
		"min": sorted_values.front(),
		"p50": _percentile(sorted_values, 0.50),
		"p95": _percentile(sorted_values, 0.95),
	}


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	var index := clampi(ceili(fraction * float(sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _object_snapshot() -> Dictionary:
	return {
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _assert_stable_object_window(label: String, baseline: Dictionary, after: Dictionary) -> void:
	if int(after["node_count"]) != int(baseline["node_count"]):
		_failures.append(
			"%s measured window changed node count %d -> %d"
			% [label, baseline["node_count"], after["node_count"]]
		)
	if int(after["object_count"]) != int(baseline["object_count"]):
		_failures.append(
			"%s measured window changed object count %d -> %d"
			% [label, baseline["object_count"], after["object_count"]]
		)
	if int(after["orphan_node_count"]) != int(baseline["orphan_node_count"]):
		_failures.append(
			"%s measured window changed orphan count %d -> %d"
			% [label, baseline["orphan_node_count"], after["orphan_node_count"]]
		)


func _assert_complete_teardown(label: String, baseline: Dictionary, after: Dictionary) -> void:
	# Global engine caches may populate during the run. Object stability is strict
	# inside each post-sacrifice window; complete teardown gates Nodes/orphans and
	# explicit WeakRef/connection ownership while still publishing OBJECT_COUNT.
	for metric: String in ["node_count", "orphan_node_count"]:
		if int(after[metric]) != int(baseline[metric]):
			_failures.append(
				"%s changed %s %d -> %d" % [label, metric, baseline[metric], after[metric]]
			)


func _parse_arguments(arguments: PackedStringArray) -> bool:
	for argument: String in arguments:
		if argument.begins_with("--combatants="):
			_combatant_count = _parse_bounded_int(argument.trim_prefix("--combatants="), "--combatants", 1, 512)
		elif argument.begins_with("--samples="):
			_analyzed_samples = _parse_bounded_int(argument.trim_prefix("--samples="), "--samples", 5, 1_000)
		elif argument.begins_with("--seed="):
			var raw_seed := argument.trim_prefix("--seed=")
			if raw_seed.is_valid_int():
				_seed_value = int(raw_seed)
			else:
				_failures.append("invalid --seed value: %s" % raw_seed)
		elif argument.begins_with("--initial-order="):
			var order := argument.trim_prefix("--initial-order=").strip_edges().to_upper()
			if order == "AB":
				_initial_a_first = true
			elif order == "BA":
				_initial_a_first = false
			else:
				_failures.append("--initial-order must be AB or BA: %s" % order)
		elif argument.begins_with("--run-index="):
			_run_index = _parse_bounded_int(argument.trim_prefix("--run-index="), "--run-index", 1, 15)
		elif argument == "--smoke":
			_smoke_mode = true
		else:
			_failures.append("unknown argument: %s" % argument)
	if _smoke_mode:
		if _run_index != 0:
			_failures.append("--smoke cannot be combined with --run-index")
	else:
		if _run_index == 0:
			_failures.append("acceptance mode requires --run-index=1..15; use --smoke for diagnostics")
		var expected_a_first := _run_index % 2 == 1
		if _initial_a_first != expected_a_first:
			_failures.append(
				"run %d requires initial order %s"
				% [_run_index, "AB" if expected_a_first else "BA"]
			)
	return _failures.is_empty()


func _parse_bounded_int(raw_value: String, option: String, minimum: int, maximum: int) -> int:
	if not raw_value.is_valid_int():
		_failures.append("invalid %s value: %s" % [option, raw_value])
		return minimum
	var value := int(raw_value)
	if value < minimum or value > maximum:
		_failures.append("%s must be between %d and %d: %d" % [option, minimum, maximum, value])
	return value


func _finish(measurements: Dictionary, structure: Dictionary) -> void:
	var structurally_valid := _failures.is_empty()
	var measurement_valid := _measurement_issues.is_empty()
	var status := "PASS" if structurally_valid and measurement_valid else ("INCONCLUSIVE" if structurally_valid else "FAIL")
	var report := {
		"analyzed_samples": _analyzed_samples,
		"benchmark": "hoplite_enemy_registry_operations",
		"combatant_count": _combatant_count,
		"control_contract": "Same-node instance ID/faction/AI traversal; absolute net microseconds, never a near-zero ratio.",
		"engine": Engine.get_version_info(),
		"failures": _failures,
		"headless": DisplayServer.get_name() == "headless",
		"initial_order": "AB" if _initial_a_first else "BA",
		"measurement_contract": "Cold uses one fresh registry per sample; warm persistent-registry values are diagnostic.",
		"measurement_issues": _measurement_issues,
		"measurements": measurements,
		"run_index": _run_index,
		"seed": _seed_value,
		"smoke_mode": _smoke_mode,
		"source_sha256": {
			"benchmark": _sha256_file("res://tools/enemy_registry_operation_benchmark.gd"),
			"registry": _sha256_file("res://scripts/enemy/combatant_registry.gd"),
		},
		"status": status,
		"structure": structure,
		"version": 1,
	}
	print("ENEMY_REGISTRY_OPERATION_BENCHMARK_JSON " + JSON.stringify(report, "", true))
	quit(0 if structurally_valid and measurement_valid else 1)


func _sha256_file(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
