extends SceneTree
const Document = preload("res://scripts/world_editor/world_document.gd")
const Runtime = preload("res://scripts/world_editor/world_runtime.gd")
var failures: Array[String] = []
var samples: Array[float] = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var path := "res://.tmp_tools/champsdebataille_v2_commandement_414.hoplite.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world="): path = arg.trim_prefix("--world=")
	var document := Document.from_json(FileAccess.get_file_as_string(path))
	if document == null:
		push_error("Mixed world missing")
		quit(1)
		return
	_expect(bool(document.validation_report().get("valid", false)), "world validation failed")
	var host := Node3D.new()
	root.add_child(host)
	current_scene = host
	var runtime := Runtime.new()
	host.add_child(runtime)
	runtime.build(document, false)
	var timeout := 900
	while not runtime.pending_enemy_spawns.is_empty() and timeout > 0:
		await process_frame
		timeout -= 1
	_expect(timeout > 0, "spawn timeout")
	if runtime.player != null:
		runtime.player.set_physics_process(false)
	var army := runtime.enemy_v2_troop_runtime
	var counts: Dictionary = {}
	var starts: Dictionary = {}
	for id in army.group_ids:
		var state: Dictionary = army.groups[id]
		starts[id] = state["anchor"]
		var cap = state["capabilities"]
		counts[cap.role] = int(counts.get(cap.role,0)) + state["members"].size()
		for member in state["members"]:
			_expect(member.combat != null and member.health_component != null, "missing V2 combat/health")
			if cap.role == &"giant": _expect(member.scale.is_equal_approx(Vector3.ONE) and member.size_multiplier == 3.0, "giant scale is compounded")
	_expect(int(counts.get(&"phalanx",0)) == 288 and int(counts.get(&"archer",0)) == 48 and int(counts.get(&"giant",0)) == 2, "wrong mixed population")
	var frames := 300
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
	Engine.max_fps = 60
	for frame in range(frames):
		var started := Time.get_ticks_usec()
		await process_frame
		if frame > 30: samples.append(float(Time.get_ticks_usec()-started)/1000.0)
		if frame % 60 == 0:
			_expect(int(army.threat_budget.active_cost()) <= 6, "shared threat overflow")
	var moved := 0
	var phases: Dictionary = {}
	var rows: Array = []
	for id in army.group_ids:
		var state: Dictionary = army.groups[id]
		var distance: float = (state["anchor"] as Vector3).distance_to(starts[id])
		if distance > 0.5: moved += 1
		var phase: StringName = state.get("movement_phase",&"")
		phases[phase] = int(phases.get(phase,0))+1
		rows.append({"id":id,"distance":snappedf(distance,0.01),"phase":phase,"anchor":str(state["anchor"]),"cohesion":state["cohesion"]})
	_expect(moved >= 2, "fewer than two formations actually maneuvered")
	_expect(army.battle_layout.front_director.fronts.size() == 4, "four persistent fronts missing")
	var box := BoxShape3D.new()
	box.size = Vector3(10.2, 1.5, 4.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = 1
	for point: Vector3 in [Vector3(-1,1.2,-116),Vector3(19,1.2,-108),Vector3(72,1.2,-168),Vector3(-3,2.4,-180)]:
		query.transform = Transform3D(Basis.IDENTITY, point)
		var hits := host.get_world_3d().direct_space_state.intersect_shape(query, 8)
		var descriptions: Array = []
		for hit: Dictionary in hits:
			var collider: Node3D = hit["collider"]
			descriptions.append({"name":str(collider.name),"position":str(collider.global_position),"metadata":str(collider.get_meta_list())})
		print("TERRAIN_BLOCKERS ",point," ",JSON.stringify(descriptions))
	var snapshot: Dictionary = army.debug_snapshot()
	print("COMBINED_ARMS_SNAPSHOT ",JSON.stringify(snapshot))
	print("TRAFFIC_DIAGNOSTICS ",JSON.stringify(army.battle_layout.traffic.diagnostics))
	print("TRAFFIC_COUNTS ",JSON.stringify(army.battle_layout.traffic.rejection_counts))
	print("COMBINED_ARMS_MOVEMENT ",JSON.stringify(rows))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/combined_arms_player.png")
		var camera := Camera3D.new()
		host.add_child(camera)
		camera.position = Vector3(29,62,-66)
		camera.look_at(Vector3(29,0,-133))
		camera.current = true
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/combined_arms_overview.png")
	samples.sort()
	if not samples.is_empty(): print("COMBINED_ARMS_TIMING p95_ms=",samples[int(samples.size()*0.95)], " p99_ms=",samples[int(samples.size()*0.99)])
	runtime.free()
	host.free()
	if failures.is_empty():
		print("COMBINED_ARMS_RUNTIME PASS population=414 moved=",moved)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _expect(value: bool,message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
