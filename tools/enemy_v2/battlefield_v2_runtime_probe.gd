extends SceneTree
const Document = preload("res://scripts/world_editor/world_document.gd")
const Runtime = preload("res://scripts/world_editor/world_runtime.gd")
const Composer = preload("res://scripts/enemy_v2/battlefield/battlefield_composer.gd")
var failures: Array[String] = []
var attack_groups: Dictionary = {}
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)
func _run() -> void:
	var doc := Document.new()
	doc.data.name = "Bataille V2 — garde rapprochée" if OS.get_cmdline_user_args().has("--bodyguard") else "Bataille V2 — deux armées"
	var zone := Document.entity("battlefield","Bataille — assaut contre défense",Vector3.ZERO,(Composer.bodyguard_preset() if OS.get_cmdline_user_args().has("--bodyguard") else Composer.defaults()))
	var stress := OS.get_cmdline_user_args().has("--stress")
	if stress:
		zone.properties.merge({"size":[160,4,160],"enemy_phalanx":150,"enemy_infantry":200,"enemy_archer":60,"enemy_giant":5,"ally_phalanx":120,"ally_infantry":96,"ally_archer":24,"ally_giant":0,"escort_phalanx":6},true)
		if OS.get_cmdline_user_args().has("--no-escort"): zone.properties.escort_phalanx = 0
	zone.id = "battlefield_demo"
	doc.data.entities = [Document.entity("surface","Sol",Vector3(0,-0.2,0),{"shape":"floor","size":[220,0.4,220],"material":"pavers"}),Document.entity("player_spawn","Joueur",Vector3(0,0.1,-1),{"radius":1.0}),zone]
	var result := Composer.populate(doc.data,zone)
	check(result.errors.is_empty(),"composer default invalid: " + str(result.errors))
	doc = Document.from_json(doc.to_json())
	check(doc.validation_report().valid,"document invalid: " + str(doc.validation_report()))
	if OS.get_cmdline_user_args().has("--generate"):
		var path := "res://worlds/forge/bataille_v2_garde_rapprochee.hoplite.json" if OS.get_cmdline_user_args().has("--bodyguard") else "res://worlds/forge/bataille_v2_deux_armees.hoplite.json"
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(doc.to_json())
		file.close()
	var host := Node3D.new()
	root.add_child(host)
	current_scene = host
	var runtime := Runtime.new()
	host.add_child(runtime)
	runtime.build(doc,false)
	for frame in range(900):
		if runtime.pending_enemy_spawns.is_empty(): break
		await process_frame
	var service: Node = runtime.battlefield_runtime
	check(service.armies.size()==2,"army commanders mismatch")
	var initial := {}
	var actors: Array[Node] = []
	for army: RefCounted in service.armies.values():
		for id: StringName in army.runtime.groups:
			initial[id] = army.runtime.groups[id].anchor
			actors.append_array(army.runtime.groups[id].members)
	if service.escort != null:
		if not stress: service.escort.issue(&"attack",Vector3(0,0.1,-6))
	var expected := (655 if OS.get_cmdline_user_args().has("--no-escort") else 661) if stress else (176 if OS.get_cmdline_user_args().has("--bodyguard") else 169)
	check(actors.size()>=expected*0.9 and actors.size()<=expected,"population mismatch " + str(actors.size()))
	var enemy: Node3D
	var ally: Node3D
	for actor: Node in actors:
		if actor.faction == &"spartan": ally = actor
		else: enemy = actor
	if ally != null and enemy != null:
		var before: float = ally.health
		ally.receive_ai_hit(10.0,ally,Vector3.FORWARD)
		check(ally.health == before,"friendly damage")
		ally.receive_ai_hit(10.0,enemy,Vector3.FORWARD)
		check(ally.health < before,"enemy cannot damage ally")
	var unit: Node3D = ally
	if unit != null and not bool(unit.get_meta("player_escort",false)):
		var commander = service._commander_for(unit)
		commander.settings.activation = "enter"
		commander.settings.activated = false
		unit.combat.state = unit.combat.State.GUARD
		service._update_target(unit)
		check(unit.combat_target == null,"inactive army targets opponents")
		commander.settings.activation = "start"
	for actor: Node in actors:
		actor.attack_started.connect(func(unit: Node, _kind: StringName) -> void: attack_groups[unit.phalanx_group_id] = int(attack_groups.get(unit.phalanx_group_id,0))+1)
	var start_health := 0.0
	for actor: Node in actors: start_health += actor.health
	runtime.player.set_physics_process(false)
	Engine.max_fps = 60
	var frame_times: Array[float] = []
	var previous_usec := Time.get_ticks_usec()
	var troop_usec := 0.0
	var service_usec := 0.0
	var physics_ms := 0.0
	var process_ms := 0.0
	var observed_targets := 0
	var peak_npc_attacks := 0
	var frames := 900
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
	for frame in range(frames):
		await process_frame
		frame_times.append(float(Time.get_ticks_usec()-previous_usec)/1000.0)
		previous_usec = Time.get_ticks_usec()
		for army: RefCounted in service.armies.values(): troop_usec += army.runtime.last_update_usec
		service_usec += service.last_update_usec
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		if frame == 600 and OS.get_cmdline_user_args().has("--orders") and service.escort != null: service.escort.issue(&"hold",runtime.player.global_position)
		if frame % 30 == 0:
			var costs := {}
			for lease: Dictionary in runtime.enemy_v2_troop_runtime.threat_budget.leases.values():
				costs[lease.target] = int(costs.get(lease.target,0))+int(lease.cost)
			check(int(costs.get(runtime.player.get_instance_id(),0)) <= 6,"player pressure overflow")
			var npc_attacks := 0
			for lease: Dictionary in runtime.enemy_v2_troop_runtime.threat_budget.leases.values():
				if lease.target != runtime.player.get_instance_id(): npc_attacks += 1
			peak_npc_attacks = maxi(peak_npc_attacks,npc_attacks)
			for actor: Node in actors:
				if is_instance_valid(actor) and not actor.dead and actor.combat_target is HopliteEnemyActorV2: observed_targets += 1
	print("CPU_MS troops=",troop_usec/frames/1000.0," service=",service_usec/frames/1000.0," physics=",physics_ms/frames," process=",process_ms/frames)
	frame_times.sort()
	print("FRAME_MS median=",frame_times[frame_times.size()/2]," p95=",frame_times[int(frame_times.size()*0.95)])
	print("PEAK_NPC_ATTACKS ",peak_npc_attacks)
	var moved := 0
	var dormant: Array[StringName] = []
	var missions := {}
	for army: RefCounted in service.armies.values():
		for id: StringName in army.runtime.groups:
			if (army.runtime.groups[id].anchor as Vector3).distance_to(initial[id]) > 3.0: moved += 1
			if not attack_groups.has(id) and (army.runtime.groups[id].anchor as Vector3).distance_to(initial[id])<1.0: dormant.append(id)
			var record: Dictionary = army.runtime.battle_layout.records[id]
			missions[id] = {"anchor":str(army.runtime.groups[id].anchor),"mission":str(record.get("command_assignment",{}).get("mission","missing"))}
	if OS.get_cmdline_user_args().has("--diagnose"):
		for army: RefCounted in service.armies.values():
			for id: StringName in army.runtime.groups:
				var state: Dictionary = army.runtime.groups[id]
				print("ACTIVITY ",id," state=",state.state," cohesion=",state.cohesion," phase=",state.movement_phase," engaged=",state.group_engaged," route=",army.runtime.battle_layout.traffic.diagnostics.get(id,{}))
	var end_health := 0.0
	for actor: Node in actors:
		if is_instance_valid(actor): end_health += actor.health
	check(observed_targets > 0,"no opposing army targets")
	check(moved > 0,"armies remain at spawn")
	check(end_health < start_health,"no army combat damage")
	print("DORMANT_GROUPS ",dormant)
	print("GROUP_ATTACKS ",JSON.stringify(attack_groups))
	print("BATTLEFIELD_COST last_us=",service.last_update_usec," peak_us=",service.max_update_usec)
	print("BATTLEFIELD_DATA moved=",moved," targets=",observed_targets," damage=",start_health-end_health," missions=",JSON.stringify(missions))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/battlefield_player.png")
		print("VISUAL_SAMPLE ",actors[0].global_position," ",actors[80].global_position," ",actors[100].global_position)
		var camera := Camera3D.new()
		host.add_child(camera)
		camera.position = Vector3(12,19,29)
		camera.look_at(Vector3.ZERO)
		camera.current = true
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/battlefield_armies.png")
	var local: Node3D = runtime._spawn_forge_enemy(host,&"enemy_v2_infantry",Vector3(44,0.1,0),runtime.player,{"faction":&"spartan","ai_enabled":true,"v2_combat_lab":true,"v2_troop_mode":&"infantry"})
	var local_members: Array[Node] = [local]
	service.register_group(&"local_probe",local_members,{"faction":"spartan","v2_local_order":"guard"},&"infantry")
	var local_record: Dictionary = runtime.enemy_v2_troop_runtime.battle_layout.records[&"local_probe"]
	service._update_local_groups()
	check(local_record.command_assignment.position == local_record.home_anchor,"local guard moves home")
	service.local_groups[&"local_probe"]["v2_local_order"] = "patrol"
	service._update_local_groups()
	check((local_record.command_assignment.position as Vector3).distance_to(local_record.home_anchor)>5.0,"local patrol absent")
	service.local_groups[&"local_probe"]["v2_local_order"] = "escort"
	service._update_local_groups()
	check((local_record.command_assignment.position as Vector3).distance_to(runtime.player.global_position + Vector3(5,0,5))<0.1,"local escort absent")
	runtime.remove_enemy_group("local_probe")
	check(not service.local_groups.has(&"local_probe"),"local cleanup missing")
	host.queue_free()
	await process_frame
	await process_frame
	print("BATTLEFIELD_V2 ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
