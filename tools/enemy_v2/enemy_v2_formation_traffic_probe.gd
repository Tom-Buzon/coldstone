extends SceneTree

const Occupancy = preload("res://scripts/enemy_v2/enemy_v2_tactical_occupancy_runtime.gd")
const Scheduler = preload("res://scripts/enemy_v2/enemy_v2_formation_traffic_scheduler.gd")
const Navigation = preload("res://scripts/enemy_v2/enemy_v2_formation_navigation.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_atomic_and_horizon()
	_test_progress_and_stall()
	_test_horizon_extension_conflict()
	_test_oriented_sweeps()
	_test_parallel_routes()
	_test_local_capacity_fairness()
	_test_solve_frame_budget()
	await _test_terrain()
	if failures.is_empty():
		print("ENEMY_V2_FORMATION_TRAFFIC_PROBE PASS atomic horizon progress yield rotation parallel terrain")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[V2 TRAFFIC] " + failure)
		quit(1)


func _test_atomic_and_horizon() -> void:
	var occupancy := Occupancy.new()
	var path := PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 100)])
	var first := occupancy.try_reserve_corridor(&"a", path, 2.0, 0, 1000)
	_expect(first != null, "initial reservation rejected")
	occupancy.update_footprint(&"obstacle", Vector3(20, 0, 0), Vector3.FORWARD, 4, 4)
	var failed := occupancy.try_reserve_corridor(&"a", PackedVector3Array([Vector3(20, 0, 0), Vector3(20, 0, 20)]), 2.0, 0, 1100)
	_expect(failed == null, "route through occupied footprint accepted")
	_expect(occupancy.reservations.get(&"a") == first, "failed replacement destroyed old reservation")
	# Crossing occurs far beyond A's horizon: B can complete a local crossing now.
	var crossing := occupancy.try_reserve_corridor(&"b", PackedVector3Array([Vector3(-8, 0, 70), Vector3(8, 0, 70)]), 2.0, 0, 1100)
	_expect(crossing != null, "whole future path blocked an unrelated manoeuvre")
	var near_crossing := occupancy.try_reserve_corridor(&"c", PackedVector3Array([Vector3(-8, 0, 8), Vector3(8, 0, 8)]), 2.0, 0, 1100)
	_expect(near_crossing == null, "conflicting near horizons both accepted")


func _test_progress_and_stall() -> void:
	var occupancy := Occupancy.new()
	var first := occupancy.try_reserve_corridor(&"march", PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 60)]), 2.0, 0, 1000)
	var first_cells: Array = first.cells.duplicate()
	occupancy.update_progress(&"march", Vector3(0, 0, 12), 2000)
	var released := false
	for cell: Vector2i in first_cells:
		if not occupancy.corridor_owners.has(cell):
			released = true
	_expect(released, "passed corridor cells were never released")
	_expect(first.last_progress_at_msec == 2000, "forward progress did not renew lease")
	occupancy.update_progress(&"march", Vector3(0, 0, 12), 6000)
	_expect(not occupancy.reservations.has(&"march"), "stationary live formation retained its lease forever")
	_expect(occupancy.get_route_status(&"march", 6000) == &"yielding", "stalled group did not report yield")
	var immediate_retry := occupancy.try_reserve_corridor(&"march", PackedVector3Array([Vector3(0, 0, 12), Vector3(0, 0, 30)]), 2.0, 0, 6001)
	_expect(immediate_retry == null, "stalled owner instantly reacquired lane without yielding")
	var later_retry := occupancy.try_reserve_corridor(&"march", PackedVector3Array([Vector3(0, 0, 12), Vector3(0, 0, 30)]), 2.0, 0, 7200)
	_expect(later_retry != null, "bounded yield never allowed retry")


func _test_horizon_extension_conflict() -> void:
	var occupancy := Occupancy.new()
	occupancy.update_footprint(&"blocker", Vector3(0, 0, 34), Vector3.FORWARD, 3, 3)
	var reservation := occupancy.try_reserve_corridor(&"march", PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 70)]), 3.0, 0, 1000)
	_expect(reservation != null, "distant blocker prevented initial local lease")
	occupancy.update_progress(&"march", Vector3(0, 0, 14), 2000)
	_expect(occupancy.get_route_status(&"march", 2000) == &"waiting_corridor", "rolling horizon extension ignored newly encountered blocker")
	occupancy.remove_group(&"blocker")
	occupancy.update_progress(&"march", Vector3(0, 0, 14), 2300)
	_expect(occupancy.get_route_status(&"march", 2300) == &"moving", "temporarily blocked horizon never resumed after clearance")

func _test_oriented_sweeps() -> void:
	var occupancy := Occupancy.new()
	occupancy.update_footprint(&"wide", Vector3.ZERO, Vector3.FORWARD, 12, 2)
	occupancy.update_footprint(&"neighbor", Vector3(0, 0, 5), Vector3.FORWARD, 2, 2)
	_expect(not occupancy.rotation_is_clear(&"wide", Vector3.ZERO, Vector3.FORWARD, Vector3.RIGHT), "rotating wing passed through neighboring formation")
	_expect(occupancy.rotation_is_clear(&"wide", Vector3.ZERO, Vector3.FORWARD, Vector3.BACK) == false, "180-degree rotation missed its intermediate wing sweep")
	occupancy.update_footprint(&"neighbor", Vector3(8, 0, 0), Vector3.FORWARD, 2, 2)
	var proposed := Vector3(2.0, 0, 0)
	_expect(occupancy.constrain_motion(&"wide", Vector3.ZERO, proposed, Vector3.FORWARD, Vector3.FORWARD) == Vector3.ZERO, "wide side overlap escaped center-depth exclusion")
	occupancy.update_footprint(&"neighbor", Vector3(4, 0, 0), Vector3.FORWARD, 2, 2)
	_expect(occupancy.overlap_count() == 1, "SAT conflict counter missed overlapping wings")
	_expect(occupancy.constrain_motion(&"wide", Vector3.ZERO, Vector3(-0.2, 0, 0), Vector3.FORWARD, Vector3.FORWARD) != Vector3.ZERO, "existing overlap could not move apart")
	var corrected := occupancy.resolve_overlap(&"wide", Vector3.ZERO, 0.3)
	_expect(corrected.length() > 0.01 and corrected.length() <= 0.3001, "SAT overlap escape ignored bounded movement budget")


func _test_parallel_routes() -> void:
	var occupancy := Occupancy.new()
	var scheduler := Scheduler.new(occupancy)
	for index: int in range(6):
		var start := Vector3(float(index) * 18.0, 0, 0)
		var route := scheduler.request_route(StringName("front_%d" % index), start, start + Vector3.BACK * 35.0, Vector3(0, 0, 500), 6.0, 0, 2.0, Vector3.BACK, 2.0, 1000 + index)
		_expect(route.size() == 2, "independent front did not receive direct collective route")
	_expect(occupancy.active_corridor_count(1100) == 6, "parallel manoeuvres remained limited to four corridors")


func _test_local_capacity_fairness() -> void:
	var occupancy := Occupancy.new()
	var scheduler := Scheduler.new(occupancy)
	for row: int in [-1, 1]:
		for column: int in [-3, -1, 1, 3]:
			var start := Vector3(float(column) * 6.0, 0, float(row) * 18.0)
			var id := StringName("busy_%d_%d" % [row,column])
			occupancy.try_reserve_corridor(id, PackedVector3Array([start,start+Vector3.RIGHT*2.0]), 1.0, 20, 1000, 1.0)
	_expect(occupancy.active_corridor_count(1100) == 8, "capacity fixture did not reserve eight distinct lanes")
	var remote := scheduler.request_route(&"remote", Vector3(300,0,0), Vector3(300,0,8), Vector3.ZERO, 1, 0, 1, Vector3.FORWARD, 2, 1200)
	_expect(not remote.is_empty(), "eight remote leases starved an unrelated front")
	var initial := scheduler.request_route(&"waiter", Vector3.ZERO, Vector3(0,0,8), Vector3.ZERO, 1, 0, 1, Vector3.BACK, 2, 1500)
	_expect(initial.is_empty(), "new local lease bypassed full local capacity")
	# Simulate holders still making progress: only lease age, not stalled TTL,
	# can make room for the waiting group in this regression.
	for id: Variant in occupancy.reservations:
		occupancy.reservations[id].last_progress_at_msec = 6000
		occupancy.reservations[id].expires_at_msec = 18000
	var eventual := scheduler.request_route(&"waiter", Vector3.ZERO, Vector3(0,0,8), Vector3.ZERO, 1, 0, 1, Vector3.BACK, 2, 6000)
	_expect(not eventual.is_empty(), "aged local request starved behind eight progressing leases")
	var yielded := 0
	for id: Variant in occupancy.route_states:
		if occupancy.route_states[id] == &"yielding":
			yielded += 1
	_expect(yielded == 1, "fair handoff did not yield exactly one older lease")
	_expect(occupancy.active_corridor_count(6000) == 9, "fair handoff exceeded local capacity or evicted remote lane")

	# Preemption is atomic and never removes the actual occupied footprint.
	var atomic := Occupancy.new()
	atomic.try_reserve_corridor(&"holder", PackedVector3Array([Vector3.ZERO,Vector3(0,0,12)]), 1, 0, 1000, 1)
	atomic.update_footprint(&"solid", Vector3(8,0,0), Vector3.FORWARD, 3, 3)
	var owners: Array[StringName] = [&"holder"]
	var rejected := atomic.try_reserve_corridor(&"new", PackedVector3Array([Vector3(8,0,0),Vector3(8,0,12)]), 1, 20, 1500, 1, owners)
	_expect(rejected == null and atomic.reservations.has(&"holder"), "failed fair handoff destroyed another owner's lease")

func _test_solve_frame_budget() -> void:
	var scheduler := Scheduler.new()
	for index: int in range(3):
		var start := Vector3(float(index) * 50, 0, 0)
		var route := scheduler.request_route(StringName("budget_%d" % index), start, start+Vector3.BACK*8, Vector3.ZERO, 1, 0, 1, Vector3.BACK, 2, 1000)
		_expect(route.is_empty() if index == 2 else not route.is_empty(), "per-frame route solve count exceeded two or rejected an allowed solve")
	var deferred_route := scheduler.request_route(&"budget_2", Vector3(100,0,0), Vector3(100,0,8), Vector3.ZERO, 1, 0, 1, Vector3.BACK, 2, 1001)
	_expect(not deferred_route.is_empty(), "deferred solve could not resume on next frame")

func _test_terrain() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_add_box(world, Vector3(0, -0.5, 0), Vector3(70, 1, 70))
	_add_box(world, Vector3(0, 2, 0), Vector3(4, 4, 8))
	_add_box(world, Vector3(0, 4, 12), Vector3(5, 1, 5))
	var hill := StaticBody3D.new()
	hill.position = Vector3(100, 0, 0)
	var terrain_shape := HeightMapShape3D.new()
	terrain_shape.map_width = 17
	terrain_shape.map_depth = 17
	var heights := PackedFloat32Array()
	for z: int in range(17):
		for x: int in range(17):
			heights.append(float(x) * 0.25)
	terrain_shape.map_data = heights
	var terrain_collision := CollisionShape3D.new()
	terrain_collision.shape = terrain_shape
	hill.add_child(terrain_collision)
	world.add_child(hill)
	await physics_frame
	await physics_frame
	var navigation := Navigation.new()
	navigation.configure_world(world)
	navigation.begin_request()
	_expect(not navigation.path_is_clear(PackedVector3Array([Vector3(-15, 0, 0), Vector3(15, 0, 0)]), 3, 2), "formation path ignored wall")
	navigation.begin_request()
	_expect(navigation.path_is_clear(PackedVector3Array([Vector3(-15, 0, 12), Vector3(15, 0, 12)]), 3, 2), "clear lane over floor was rejected")
	navigation.begin_request()
	_expect(not navigation.path_is_clear(PackedVector3Array([Vector3(-15, 0, 12), Vector3(15, 0, 12)]), 3, 2, Vector3.ZERO, 6.0), "giant route ignored overhead clearance")
	navigation.begin_request()
	_expect(navigation.path_is_clear(PackedVector3Array([Vector3(100,2,-5),Vector3(100,2,5)]),12,2), "wide formation treated walkable hillside as a wall")
	navigation.begin_request()
	_expect(not navigation.path_is_clear(PackedVector3Array([Vector3(25, 0, 20), Vector3(45, 0, 20)]), 3, 2), "formation route stepped beyond ground support")
	world.free()


func _add_box(parent: Node3D, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
