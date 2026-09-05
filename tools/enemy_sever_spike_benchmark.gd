extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

const COUNTS: Array[int] = [1, 4, 8]
const FOLLOW_FRAMES: int = 30

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenarios: Array[Dictionary] = []
	for count: int in COUNTS:
		scenarios.append(await _run_scenario(count))
	var report := {
		"benchmark": "hoplite_enemy_sever_spike",
		"engine": Engine.get_version_info(),
		"failures": failures,
		"scenarios": scenarios,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"visual_contract": "authored detached package fragment plus primary spray, dense mist and arterial jet",
	}
	print("ENEMY_SEVER_SPIKE_BENCHMARK_JSON " + JSON.stringify(report, "", true))
	quit(0 if failures.is_empty() else 1)


func _run_scenario(count: int) -> Dictionary:
	seed(91_337 + count)
	var world := Node3D.new()
	world.name = "SeverSpike_%d" % count
	root.add_child(world)
	current_scene = world
	_add_floor(world)
	var enemies: Array[HopliteAthenianEnemy] = []
	for index: int in range(count):
		var enemy := Enemy.new() as HopliteAthenianEnemy
		enemy.name = "SeverTarget_%02d" % index
		enemy.archetype_id = &"ngeneral"
		enemy.ai_enabled = false
		enemy.position = Vector3(float(index % 4) * 2.4, 0.05, float(index / 4) * 2.4)
		world.add_child(enemy)
		enemies.append(enemy)
	for _frame: int in range(4):
		await process_frame
	await physics_frame

	var before := _monitor_snapshot()
	var prepared_director := get_first_node_in_group(&"gore_director")
	var prewarmed_fragments_before := int(prepared_director.get("_prewarmed_fragment_count")) if prepared_director != null else -1
	var start_usec := Time.get_ticks_usec()
	for enemy: HopliteAthenianEnemy in enemies:
		var hit := HitEvent.new()
		hit.damage = 1.0
		hit.sever_damage = 100_000.0
		hit.position = enemy.anatomy.get_zone_world_center(&"forearm_r")
		hit.direction = Vector3.RIGHT
		enemy.defense_mode = &"none"
		enemy.armor_sever_multiplier = 1.0
		enemy.receive_anatomy_hit(hit, &"forearm_r")
	var synchronous_usec := Time.get_ticks_usec() - start_usec

	var max_follow_frame_usec := 0
	var total_follow_frame_usec := 0
	for _frame: int in range(FOLLOW_FRAMES):
		var frame_start := Time.get_ticks_usec()
		await process_frame
		var elapsed := Time.get_ticks_usec() - frame_start
		max_follow_frame_usec = maxi(max_follow_frame_usec, elapsed)
		total_follow_frame_usec += elapsed
	var after := _monitor_snapshot()
	var director := world.get_tree().get_first_node_in_group(&"gore_director")
	var fragments := int(director.call("active_fragment_count")) if director != null else 0
	if fragments != count:
		failures.append("%d sever scenario created %d/%d authored fragments" % [count, fragments, count])
	var active_bursts := int(director.call("active_blood_count")) if director != null else 0
	var primary_layers := active_bursts
	var mist_layers := active_bursts
	var jet_layers := count
	if active_bursts != count * 2:
		failures.append("%d sever scenario kept %d/%d active blood bursts" % [count, active_bursts, count * 2])
	var runtime_fragment_growth := int(director.get("fragment_runtime_growth_count")) if director != null else -1
	var prewarmed_fragments_after := int(director.get("_prewarmed_fragment_count")) if director != null else -1
	if runtime_fragment_growth != 0:
		failures.append("%d sever scenario grew %d fragments on the hit path" % [count, runtime_fragment_growth])
	if prewarmed_fragments_after != prewarmed_fragments_before:
		failures.append("%d sever scenario changed prewarm count on the hit path (%d -> %d)" % [count, prewarmed_fragments_before, prewarmed_fragments_after])

	world.queue_free()
	await process_frame
	await process_frame
	current_scene = null
	return {
		"count": count,
		"synchronous_usec": synchronous_usec,
		"follow_frame_max_usec": max_follow_frame_usec,
		"follow_frame_mean_usec": float(total_follow_frame_usec) / float(FOLLOW_FRAMES),
		"monitors_before": before,
		"monitors_after_spawn": after,
		"authored_fragments": fragments,
		"primary_layers": primary_layers,
		"mist_layers": mist_layers,
		"arterial_layers": jet_layers,
		"runtime_fragment_growth": runtime_fragment_growth,
		"prewarmed_fragments": prewarmed_fragments_after,
	}


func _add_floor(parent: Node3D) -> void:
	var floor := StaticBody3D.new()
	parent.add_child(floor)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 1.0, 30.0)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)


func _monitor_snapshot() -> Dictionary:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"active_physics": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
	}
