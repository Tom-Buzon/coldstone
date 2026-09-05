extends SceneTree

const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")

class CombatantDummy:
	extends Node3D

	var dead := false

	func is_dead_for_combat() -> bool:
		return dead

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var combatant := CombatantDummy.new()
	combatant.position = Vector3(1.0, 0.0, 1.0)
	combatant.add_to_group("combatant_ai")
	root.add_child(combatant)
	var director := CrowdDirector.new()
	root.add_child(director)
	director.set_physics_process(false)

	_expect(director.nearby_combatants(Vector3.ZERO).has(combatant), "initial rebuild omitted a live combatant")
	var initial_rebuilds: int = director.spatial_rebuild_count
	var initial_snapshot_builds: int = director.group_snapshot_build_count
	var reused_buffer: Array[Node] = []
	director.fill_nearby_combatants(Vector3.ZERO, reused_buffer)
	_expect(reused_buffer.has(combatant), "caller-owned nearby buffer omitted a live combatant")
	reused_buffer.append(director)
	director.fill_nearby_combatants(Vector3.ZERO, reused_buffer)
	_expect(not reused_buffer.has(director) and reused_buffer.has(combatant), "nearby buffer was not cleared and reused")
	combatant.position = Vector3(30.0, 0.0, 0.0)
	director._physics_process(0.016)
	director._physics_process(0.016)
	_expect(director.spatial_rebuild_count == initial_rebuilds, "spatial grid still rebuilt at physics-frame cadence")
	_expect(director.nearby_combatants(Vector3.ZERO).has(combatant), "grid refreshed before its tactical interval elapsed")
	director._physics_process(0.020)
	_expect(director.spatial_rebuild_count == initial_rebuilds + 1, "spatial grid did not rebuild at 20 Hz")
	_expect(director.group_snapshot_build_count == initial_snapshot_builds, "movement-only grid refresh rescanned SceneTree membership")
	_expect(not director.nearby_combatants(Vector3.ZERO).has(combatant), "scheduled rebuild retained a stale cell")
	_expect(director.nearby_combatants(combatant.global_position).has(combatant), "scheduled rebuild omitted the moved combatant")

	combatant.dead = true
	director.invalidate_spatial_grid()
	director._physics_process(0.001)
	_expect(not director.nearby_combatants(combatant.global_position).has(combatant), "invalidated rebuild retained a dead combatant")
	_expect(director.spatial_rebuild_count == initial_rebuilds + 2, "invalidation did not trigger exactly one rebuild")
	_expect(director.group_snapshot_build_count == initial_snapshot_builds + 1, "membership invalidation did not rebuild shared group snapshots exactly once")

	combatant.queue_free()
	director.queue_free()
	if failures.is_empty():
		print("CROWD_SPATIAL_CADENCE_PROBE PASS: initial snapshot, 20 Hz movement refresh, immediate membership invalidation")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
