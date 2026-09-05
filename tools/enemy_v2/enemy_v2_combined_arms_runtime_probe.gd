extends SceneTree
const Document = preload("res://scripts/world_editor/world_document.gd")
const Runtime = preload("res://scripts/world_editor/world_runtime.gd")
var failures: Array[String] = []
var samples: Array[float] = []
var observed_threats: Dictionary = {}
var peak_threat := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var path := "user://hoplite_worlds/champsdebataille_v2_commandement_414.hoplite.json"
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
		if frame % 6 == 0:
			_observe_threats(army)
		if frame % 60 == 0:
			_expect(int(army.threat_budget.active_cost()) <= 6, "shared threat overflow")
	if OS.get_cmdline_user_args().has("--dynamic"):
		await _exercise_player_movement(army, runtime)
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
	_expect(army.battle_layout.active_anchor_conflict_count() == 0, "formations overlap after maneuvers")
	_expect(army.battle_layout.front_director.fronts.size() == 4, "four persistent fronts missing")
	var snapshot: Dictionary = army.debug_snapshot()
	print("COMBINED_ARMS_SNAPSHOT ",JSON.stringify(snapshot))
	print("COMBINED_ARMS_THREATS ",JSON.stringify(observed_threats), " peak_cost=",peak_threat)
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
	runtime.queue_free()
	await process_frame
	host.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("COMBINED_ARMS_RUNTIME PASS population=414 moved=",moved)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _expect(value: bool,message: String) -> void:
	if not value and not failures.has(message): failures.append(message)


func _exercise_player_movement(army: Node, runtime: Node) -> void:
	var player: Node3D = runtime.player
	var starting := player.global_position
	var goals: Array[Vector3] = [starting + Vector3(-10,0,-26), starting + Vector3(12,0,-12), starting + Vector3(-40,0,-17), starting + Vector3(40,0,-17), starting]
	var previous := starting
	for goal in goals:
		for frame in range(120):
			player.global_position = previous.lerp(goal, minf(1.0,float(frame)/80.0))
			player.health = player.max_health
			await process_frame
			if frame % 6 == 0: _observe_threats(army)
			if frame % 30 == 0:
				_expect(army.threat_budget.active_cost() <= 6, "pressure overflow during player traversal")
				for state: Dictionary in army.groups.values():
					var anchor: Vector3 = state["anchor"]
					_expect(anchor.is_finite(), "non-finite group anchor during traversal")
		previous = goal
	# Approach the actual miniboss position, not its original editor marker.
	for state: Dictionary in army.groups.values():
		if state["capabilities"].role != &"giant": continue
		var giant: Node3D = state["members"][0]
		for frame in range(300):
			player.global_position = giant.global_position + Vector3(0,0,4.2)
			player.health = player.max_health
			await process_frame
			if frame % 6 == 0: _observe_threats(army)
	_expect(int(observed_threats.get(&"heavy", 0)) > 0, "no giant threat during direct miniboss approach")
	player.global_position = starting
	print("COMBINED_ARMS_DYNAMIC completed traversal zigzag giant_flanks miniboss_contact return")

func _observe_threats(army: Node) -> void:
	peak_threat = maxi(peak_threat, army.threat_budget.active_cost())
	for lease: Dictionary in army.threat_budget.leases.values():
		var kind: StringName = lease["kind"]
		observed_threats[kind] = int(observed_threats.get(kind, 0)) + 1
