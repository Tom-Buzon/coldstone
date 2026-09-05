extends SceneTree

const NavigationComponent = preload("res://scripts/ai/enemy_navigation_component.gd")
const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")

const STEP_DELTA: float = 1.0 / 30.0
const MOVE_SPEED: float = 2.8
const MAX_STEPS: int = 360

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "EnemyNavigationNavmeshProbeWorld"
	root.add_child(world)
	current_scene = world

	var region := _build_ring_navigation_region()
	world.add_child(region)
	# Navigation nodes upload their data asynchronously to NavigationServer3D.
	# Wait explicit physics frames instead of relying on an arbitrary wall-clock delay.
	for _frame: int in range(3):
		await physics_frame

	await _probe_runtime_hoplite_selection(world)
	await _probe_real_path_retarget_and_arrival(world, region)
	await _probe_empty_map_fallback(world)
	await _probe_layer_mismatch_fallback(world)

	if failures.is_empty():
		print("ENEMY_NAVIGATION_NAVMESH_PROBE PASS: runtime_hoplite, real_path, detour, throttled_retarget, arrival, empty_map_fallback, layer_mismatch")
		world.queue_free()
		await process_frame
		quit(0)
		return

	for failure: String in failures:
		push_error("[ENEMY NAVMESH PROBE] " + failure)
	world.queue_free()
	await process_frame
	quit(1)


func _probe_runtime_hoplite_selection(world: Node3D) -> void:
	var target := Node3D.new()
	target.name = "RuntimeHopliteTarget"
	target.position = Vector3(4.0, 0.0, 0.0)
	world.add_child(target)
	var enemy = EnemyFactory.spawn(world, &"ngeneral", Vector3(-4.0, 0.0, 0.0), target, {
		"mass_battle_mode": true,
		"ai_enabled": true,
	})
	_expect(enemy != null, "factory did not create runtime hoplite")
	if enemy == null:
		target.queue_free()
		return
	enemy.set_meta("formation_group", &"navmesh_probe_hoplites")
	enemy.set_physics_process(false)
	await physics_frame
	var navigation = enemy.navigation_component
	_expect(navigation != null and navigation.mode == NavigationComponent.Mode.NAVMESH_GROUND, "runtime hoplite did not select NAVMESH_GROUND on a route with a usable region")
	_expect(enemy.get_node_or_null("NavigationAgent") is NavigationAgent3D, "runtime hoplite did not own a NavigationAgent3D")
	if navigation != null:
		navigation.set_formation_anchor(target.global_position, Vector3.RIGHT, 0, 1)
		var intent
		for _step: int in range(8):
			await physics_frame
			intent = navigation.sample_intent(STEP_DELTA)
			if intent.status == &"moving_navmesh":
				break
		_expect(intent.status == &"moving_navmesh" and intent.valid, "runtime hoplite did not consume NavigationServer path intent")
		_expect(intent.facing_direction.is_equal_approx(Vector3.RIGHT), "runtime hoplite lost formation facing while pathfinding")
	enemy.queue_free()
	target.queue_free()
	await process_frame


func _probe_real_path_retarget_and_arrival(world: Node3D, region: NavigationRegion3D) -> void:
	var body := CharacterBody3D.new()
	body.name = "RealPathBody"
	body.position = Vector3(-4.0, 0.0, 0.0)
	world.add_child(body)

	var navigation := NavigationComponent.new()
	navigation.configure(body, NavigationComponent.Mode.NAVMESH_GROUND, {
		"arrival_distance": 0.22,
		"fallback_mode": NavigationComponent.Mode.DIRECT_STEERING,
		"agent_radius": 0.20,
		"agent_height": 1.80,
		"stuck_timeout": 2.0,
	})

	var arrivals: Array[int] = []
	var failures_seen: Array[StringName] = []
	navigation.destination_reached.connect(func() -> void: arrivals.append(1))
	navigation.navigation_failed.connect(func(reason: StringName) -> void: failures_seen.append(reason))

	var destination := Vector3(4.0, 0.0, 0.0)
	navigation.set_destination(destination)
	await physics_frame

	var agent := body.get_node_or_null("NavigationAgent") as NavigationAgent3D
	_expect(agent != null, "real-map component did not create NavigationAgent3D")
	if agent == null:
		body.queue_free()
		await process_frame
		return
	_expect(agent.get_parent() is Node3D, "NavigationAgent3D parent is not Node3D")
	_expect(agent.get_navigation_map() == region.get_navigation_map(), "agent did not join the region's navigation map")
	navigation.sample_intent(STEP_DELTA)
	var map_queries_after_first_sample: int = navigation.navigation_map_query_count
	for _sample: int in range(5):
		await physics_frame
		navigation.sample_intent(STEP_DELTA)
	_expect(
		navigation.navigation_map_query_count == map_queries_after_first_sample,
		"stable NavigationServer map/layer readiness was requeried inside its bounded cache window"
	)
	var revision_before_small_update: int = navigation._destination_revision
	var agent_target_before_small_update := agent.target_position
	navigation.set_destination(destination + Vector3(0.08, 0.0, 0.0))
	_expect(navigation._destination_revision == revision_before_small_update, "sub-threshold moving target reset the semantic destination revision")
	_expect(agent.target_position.is_equal_approx(agent_target_before_small_update), "sub-threshold moving target forced an immediate NavAgent repath")
	await physics_frame
	navigation.sample_intent(STEP_DELTA)
	_expect(agent.target_position.is_equal_approx(agent_target_before_small_update), "intent sampling bypassed the sub-threshold NavAgent repath throttle")
	navigation.set_destination(destination)

	var saw_navmesh_intent := false
	var saw_detour := false
	var retargeted := false
	var arrived := false
	var path_point_count := 0
	for step: int in range(MAX_STEPS):
		if step == 28:
			destination = Vector3(4.0, 0.0, 2.15)
			navigation.set_destination(destination)
			retargeted = true
			_expect(agent.target_position.is_equal_approx(destination), "moving target was not forwarded to NavigationAgent3D")

		var previous := body.global_position
		var intent = navigation.sample_intent(STEP_DELTA)
		if intent.status == &"moving_navmesh":
			saw_navmesh_intent = true
			var current_path := agent.get_current_navigation_path()
			path_point_count = maxi(path_point_count, current_path.size())
			for point: Vector3 in current_path:
				if absf(point.z) >= 0.92:
					saw_detour = true
		if intent.status == &"arrived":
			arrived = true
			break
		if intent.valid:
			body.global_position += intent.direction * MOVE_SPEED * STEP_DELTA
			navigation.notify_motion_applied(previous, body.global_position, STEP_DELTA, intent.direction)
		await physics_frame

	_expect(saw_navmesh_intent, "usable region never produced moving_navmesh intent")
	_expect(saw_detour and path_point_count >= 3, "real path did not detour around the central navmesh hole")
	_expect(retargeted, "moving-target phase did not run")
	_expect(arrived, "agent did not reach the retargeted destination within the bounded step budget")
	_expect(body.global_position.distance_to(destination) <= 0.28, "arrival occurred outside configured tolerance")
	_expect(arrivals.size() == 1, "destination_reached was not emitted exactly once")
	_expect(failures_seen.is_empty(), "usable navigation map emitted failure: %s" % [failures_seen])

	body.queue_free()
	await process_frame


func _probe_empty_map_fallback(world: Node3D) -> void:
	var body := CharacterBody3D.new()
	body.name = "EmptyMapFallbackBody"
	body.position = Vector3.ZERO
	world.add_child(body)

	var navigation := NavigationComponent.new()
	var failures_seen: Array[StringName] = []
	navigation.navigation_failed.connect(func(reason: StringName) -> void: failures_seen.append(reason))
	navigation.configure(body, NavigationComponent.Mode.NAVMESH_GROUND, {
		"fallback_mode": NavigationComponent.Mode.DIRECT_STEERING,
	})
	var agent := body.get_node_or_null("NavigationAgent") as NavigationAgent3D
	_expect(agent != null, "empty-map component did not create NavigationAgent3D")
	if agent == null:
		body.queue_free()
		await process_frame
		return

	var empty_map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(empty_map, true)
	agent.set_navigation_map(empty_map)
	await physics_frame

	navigation.set_destination(Vector3(0.0, 0.0, 3.0))
	var first = navigation.sample_intent(STEP_DELTA)
	var second = navigation.sample_intent(STEP_DELTA)
	_expect(first.valid and first.status == &"fallback_direct", "empty map did not return controlled direct fallback")
	_expect(first.direction.is_equal_approx(Vector3.BACK), "empty-map fallback returned the wrong direct direction")
	_expect(second.valid and second.status == &"fallback_direct", "empty-map fallback was not stable across samples")
	_expect(failures_seen == [&"navmesh_unavailable"], "empty-map failure was not emitted exactly once")

	body.queue_free()
	await process_frame
	NavigationServer3D.free_rid(empty_map)


func _probe_layer_mismatch_fallback(world: Node3D) -> void:
	var body := CharacterBody3D.new()
	body.name = "LayerMismatchBody"
	world.add_child(body)
	var navigation := NavigationComponent.new()
	var failures_seen: Array[StringName] = []
	navigation.navigation_failed.connect(func(reason: StringName) -> void: failures_seen.append(reason))
	navigation.configure(body, NavigationComponent.Mode.NAVMESH_GROUND, {
		"fallback_mode": NavigationComponent.Mode.DIRECT_STEERING,
		"navigation_layers": 1,
	})
	var agent := body.get_node("NavigationAgent") as NavigationAgent3D
	var isolated_map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(isolated_map, true)
	var isolated_region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(isolated_region, isolated_map)
	NavigationServer3D.region_set_navigation_layers(isolated_region, 2)
	NavigationServer3D.region_set_navigation_mesh(isolated_region, _ring_navigation_mesh())
	agent.set_navigation_map(isolated_map)
	for _frame: int in range(3):
		await physics_frame
	navigation.set_destination(Vector3(0.0, 0.0, 3.0))
	var intent = navigation.sample_intent(STEP_DELTA)
	_expect(intent.valid and intent.status == &"fallback_direct", "layer mismatch did not enter controlled fallback")
	_expect(failures_seen == [&"navigation_layers_mismatch"], "layer mismatch did not emit its explicit reason once (got %s)" % [failures_seen])
	body.queue_free()
	await process_frame
	NavigationServer3D.free_rid(isolated_region)
	NavigationServer3D.free_rid(isolated_map)


func _build_ring_navigation_region() -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "ProgrammaticRingNavigationRegion"
	region.navigation_layers = 1
	region.navigation_mesh = _ring_navigation_mesh()
	return region


func _ring_navigation_mesh() -> NavigationMesh:
	var vertices := PackedVector3Array([
		Vector3(-5.0, 0.0, -3.0), Vector3(-1.0, 0.0, -3.0), Vector3(1.0, 0.0, -3.0), Vector3(5.0, 0.0, -3.0),
		Vector3(-5.0, 0.0, -1.0), Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.0, -1.0), Vector3(5.0, 0.0, -1.0),
		Vector3(-5.0, 0.0, 1.0), Vector3(-1.0, 0.0, 1.0), Vector3(1.0, 0.0, 1.0), Vector3(5.0, 0.0, 1.0),
		Vector3(-5.0, 0.0, 3.0), Vector3(-1.0, 0.0, 3.0), Vector3(1.0, 0.0, 3.0), Vector3(5.0, 0.0, 3.0),
	])
	var polygons: Array[PackedInt32Array] = [
		PackedInt32Array([0, 4, 5, 1]),
		PackedInt32Array([4, 8, 9, 5]),
		PackedInt32Array([8, 12, 13, 9]),
		PackedInt32Array([1, 5, 6, 2]),
		PackedInt32Array([9, 13, 14, 10]),
		PackedInt32Array([2, 6, 7, 3]),
		PackedInt32Array([6, 10, 11, 7]),
		PackedInt32Array([10, 14, 15, 11]),
	]
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = vertices
	for polygon: PackedInt32Array in polygons:
		navigation_mesh.add_polygon(polygon)

	return navigation_mesh


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
