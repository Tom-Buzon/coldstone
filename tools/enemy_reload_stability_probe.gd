extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")

const CYCLES := 5
const ENEMY_COUNT := 36
const OBJECT_TOLERANCE := 64
const MEMORY_TOLERANCE_BYTES := 4 * 1024 * 1024

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var baseline_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var baseline_combatants := get_nodes_in_group("combatant").size()
	var cycle_snapshots: Array[Dictionary] = []
	for cycle: int in range(CYCLES):
		var scenario := Node3D.new()
		scenario.name = "ReloadCycle_%d" % cycle
		root.add_child(scenario)
		var target := Node3D.new()
		target.position = Vector3.ZERO
		scenario.add_child(target)
		var director := CrowdDirector.new()
		scenario.add_child(director)
		var refs: Array[WeakRef] = []
		for index: int in range(ENEMY_COUNT):
			var enemy = EnemyFactory.spawn(scenario, &"swordsman", _spawn_position(index), target, {
				"ai_enabled": true,
				"mass_battle_mode": true,
			})
			if enemy != null:
				refs.append(weakref(enemy))
		_expect(refs.size() == ENEMY_COUNT, "cycle %d spawned %d/%d enemies" % [cycle, refs.size(), ENEMY_COUNT])
		for _frame: int in range(12):
			await physics_frame
		scenario.queue_free()
		for _frame: int in range(3):
			await process_frame
		var live_refs := 0
		for enemy_ref: WeakRef in refs:
			if enemy_ref.get_ref() != null:
				live_refs += 1
		var snapshot := {
			"cycle": cycle + 1,
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"memory": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"live_refs": live_refs,
			"combatants": get_nodes_in_group("combatant").size(),
		}
		cycle_snapshots.append(snapshot)
		_expect(live_refs == 0, "cycle %d retained %d enemy WeakRefs" % [cycle + 1, live_refs])
		_expect(int(snapshot["nodes"]) == baseline_nodes, "cycle %d node count did not return to baseline" % [cycle + 1])
		_expect(int(snapshot["combatants"]) == baseline_combatants, "cycle %d retained combatant group members" % [cycle + 1])

	var plateau := cycle_snapshots.slice(1)
	var object_values: Array[int] = []
	var memory_values: Array[int] = []
	for snapshot: Dictionary in plateau:
		object_values.append(int(snapshot["objects"]))
		memory_values.append(int(snapshot["memory"]))
	object_values.sort()
	memory_values.sort()
	var object_span: int = object_values.back() - object_values.front()
	var memory_span: int = memory_values.back() - memory_values.front()
	_expect(object_span <= OBJECT_TOLERANCE, "post-warm object plateau span %d exceeds %d" % [object_span, OBJECT_TOLERANCE])
	_expect(memory_span <= MEMORY_TOLERANCE_BYTES, "post-warm memory plateau span %d exceeds %d" % [memory_span, MEMORY_TOLERANCE_BYTES])
	print("ENEMY_RELOAD_STABILITY_JSON ", JSON.stringify({
		"cycles": cycle_snapshots,
		"object_span_after_warm": object_span,
		"memory_span_after_warm": memory_span,
		"object_tolerance": OBJECT_TOLERANCE,
		"memory_tolerance": MEMORY_TOLERANCE_BYTES,
	}))
	if failures.is_empty():
		print("ENEMY_RELOAD_STABILITY_PROBE PASS: 5 cycles, 36 active, zero WeakRefs/groups, stable post-warm plateau")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _spawn_position(index: int) -> Vector3:
	return Vector3((float(index % 9) - 4.0) * 1.8, 0.0, (float(index / 9) + 2.0) * 2.0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
