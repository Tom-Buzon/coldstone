extends SceneTree
const Document = preload("res://scripts/world_editor/world_document.gd")
const Runtime = preload("res://scripts/world_editor/world_runtime.gd")
const Composer = preload("res://scripts/enemy_v2/battlefield/battlefield_composer.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _run() -> void:
	var doc := Document.new()
	var zone := Document.entity("battlefield","Test",Vector3.ZERO,Composer.defaults())
	zone.id = "battle"
	zone.properties.merge({"enemy_phalanx":4,"enemy_infantry":0,"enemy_archer":0,"enemy_giant":0,"ally_phalanx":2,"ally_infantry":0,"ally_archer":0,"ally_giant":0,"victory_cleanup_delay":2.0},true)
	doc.data.entities = [Document.entity("surface","Sol",Vector3(0,-0.2,0),{"shape":"floor","size":[220,0.4,220]}),Document.entity("player_spawn","Joueur",Vector3(40,0.1,40),{}),zone]
	Composer.populate(doc.data,zone)
	var boss := Document.entity("enemy_group","Champion",Vector3(0,0.1,-25),{"group_id":"boss","battlefield_id":"battle","battlefield_boss":true,"archetype":"enemy_v2_infantry","composition":[{"archetype":"enemy_v2_infantry","count":1}],"count":1,"v2_combat_lab":true,"v2_unit_role":"infantry","v2_troop_mode":"infantry","v2_persistent_fronts":true,"faction":"athenian","spawn_condition":"battlefield","boss_spawn_condition":"loss_percent","boss_loss_percent":25,"boss_guard_phalanx":2,"encounter_power":3,"boss_cinematic":false})
	doc.data.entities.append(boss)
	Composer.populate(doc.data,zone)
	check(not doc.find_entity(boss.id).is_empty(),"populate lost boss")
	doc = Document.from_json(doc.to_json())
	check(doc.validation_report().valid,"invalid document: "+str(doc.validation_report()))
	var host := Node3D.new()
	root.add_child(host)
	current_scene = host
	var world := Runtime.new()
	host.add_child(world)
	world.build(doc,false)
	var encounter: Node = world.world_root.get_node("BattlefieldEncounter")
	encounter.set_process(false)
	for frame in range(120):
		if world.pending_enemy_spawns.is_empty(): break
		await process_frame
	check(doc.theoretical_mob_count()==9,"guard missing from population budget")
	check(world.encounter_budget.planned_population_for(boss)==9,"guard missing from peak budget")
	check(not world.enemies_by_group.has("boss"),"boss spawned prematurely")
	var state: Dictionary = encounter.zones.battle
	state.active = true
	var e: Dictionary = encounter.bosses.boss.entity
	check(not encounter._ready_to_spawn(e,state),"loss triggered without deaths")
	encounter.deaths.battle_enemy_0 = 1
	check(encounter._ready_to_spawn(e,state),"25 percent did not trigger")
	var test := e.duplicate(true)
	test.properties.boss_spawn_condition = "timer"
	test.properties.spawn_delay = 10
	state.elapsed = 9.9
	check(not encounter._ready_to_spawn(test,state),"timer early")
	state.elapsed = 10.0
	check(encounter._ready_to_spawn(test,state),"timer failed")
	test.properties.boss_spawn_condition = "trigger"
	test.properties.spawn_trigger = "gate"
	check(not encounter._ready_to_spawn(test,state),"trigger early")
	encounter.entered.gate = true
	check(encounter._ready_to_spawn(test,state),"trigger failed")
	test.properties.boss_spawn_condition = "target_dead"
	test.properties.spawn_dead_group = "battle_enemy_0"
	check(not encounter._ready_to_spawn(test,state),"target partially dead")
	encounter.deaths.battle_enemy_0 = 4
	check(encounter._ready_to_spawn(test,state),"target death failed")
	check(not encounter._defeated("battle"),"victory before pending boss")
	encounter._spawn_boss("boss")
	encounter._spawn_boss("boss")
	check(not encounter._defeated("battle"),"victory during queued reinforcement")
	for frame in range(120):
		if world.pending_enemy_spawns.is_empty(): break
		await process_frame
	check(world.living_count("boss")==1,"boss not spawned once")
	var actor: Node3D = world.enemies_by_group.boss[0]
	check(actor.combat_modifiers.power==3,"boss power missing")
	var commander: RefCounted = world.battlefield_runtime._commander_for(actor)
	check(commander.retinue.champions.has(&"boss"),"infantry boss not a champion")
	var guards := 0
	for id: String in encounter.groups:
		if encounter.groups[id].properties.get("boss_guard",false):
			guards += world.living_count(id)
			check(commander.retinue.owners.get(StringName(id),&"")==&"boss","guard owner wrong")
	check(guards==2,"guard count incorrect")
	# Presentation restores camera and pause both normally and when destroyed early.
	var camera := root.get_camera_3d()
	encounter.presentation.present(actor,"Champion")
	encounter.presentation._process(0.01)
	check(paused,"cinematic did not pause simulation")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/boss_cinematic.png")
	encounter.presentation._process(2.1)
	check(not paused and root.get_camera_3d()==camera,"camera restoration failed")
	for id: String in encounter.groups:
		if encounter.groups[id].properties.get("faction","athenian")=="athenian": encounter.deaths[id] = encounter.groups[id].properties.count
	check(encounter._defeated("battle"),"victory did not resolve")
	encounter._process(0.3)
	check(encounter.zones.battle.victory,"victory not recorded")
	check(world.living_count("battle_ally_0")==2,"allies removed before message")
	encounter._process(2.1)
	check(world.living_count("battle_ally_0")==0,"allies not removed")
	encounter.presentation.present(actor,"Interrupted")
	encounter.presentation._process(0.01)
	encounter.presentation.free()
	check(not paused and root.get_camera_3d()==camera,"interrupted cinematic failed restoration")
	world.clear_world()
	host.queue_free()
	await process_frame
	if failures.is_empty(): print("BATTLEFIELD_BOSS_PROBE PASS")
	else:
		for message: String in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
