extends SceneTree
const Document = preload("res://scripts/world_editor/world_document.gd")
const Runtime = preload("res://scripts/world_editor/world_runtime.gd")
const Composer = preload("res://scripts/enemy_v2/battlefield/battlefield_composer.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	var props := Composer.defaults()
	props.enemy_phalanx = 0
	props.enemy_infantry = 12
	props.enemy_archer = 0
	props.enemy_giant = 0
	props.ally_phalanx = 0
	props.ally_infantry = 6
	props.ally_archer = 0
	props.escort_infantry = 4
	props.escort_phalanx = 1
	props.escort_archer = 1
	props.size = [100,4,120]
	var doc := Document.new()
	var zone := Document.entity("battlefield","Escort test",Vector3.ZERO,props)
	doc.data.entities = [Document.entity("surface","Floor",Vector3(0,-0.2,0),{"shape":"floor","size":[220,0.4,220],"material":"pavers"}),Document.entity("player_spawn","Player",Vector3(0,0.1,0),{}),zone]
	check(Composer.populate(doc.data,zone).errors.is_empty(),"compose mixed armies and escort")
	var host := Node3D.new()
	root.add_child(host)
	current_scene = host
	var world := Runtime.new()
	host.add_child(world)
	world.build(Document.from_json(doc.to_json()),false)
	for i in range(600):
		if world.pending_enemy_spawns.is_empty(): break
		await process_frame
	var service = world.battlefield_runtime
	check(service.armies.size()==2,"escort must not replace ally army")
	check(service.escort != null,"escort controller missing")
	if service.escort == null:
		print("ESCORT FAIL",failures)
		quit(1)
		return
	var escort = service.escort
	check(escort.members.size()==6,"mixed escort count")
	var regular = service.armies[String(zone.id)+":spartan"].runtime.groups.values()[0].members[0]
	check(regular.combat_modifiers.power==1,"regular allies got elite power")
	var actor: Node3D = escort.members[0]
	for unit: Node3D in escort.members:
		if unit.definition.unit_role == &"infantry": actor = unit; break
	check(actor.combat_modifiers.power==4,"escort power missing")
	world.player.set_physics_process(false)
	for army in service.armies.values(): army.runtime.set_process(false)
	for list: Array in world.enemies_by_group.values():
		for unit: Node in list:
			unit.set_physics_process(false)
			unit.combat.set_physics_process(false)
	service.set_process(false)
	escort.runtime.set_process(false)
	var target: Node3D = service.armies[String(zone.id)+":athenian"].runtime.groups.values()[0].members[0]
	target.combat.cancel_player_order()
	target.set_combat_target(actor)
	target.begin_attack_telegraph(&"probe",0.5)
	check(not target.attack_telegraph.active,"NPC duel creates player warning")
	target.set_combat_target(world.player)
	target.begin_attack_telegraph(&"probe",0.5)
	check(target.attack_telegraph.active,"player attack warning lost")
	target.clear_attack_telegraph()
	check(escort.mode==&"auto","elite troops must start autonomous")
	check(escort.runtime==service.armies[String(zone.id)+":spartan"].runtime,"elite troops have a separate simulation")
	actor.combat.state = actor.combat.State.ATTACK
	escort.issue(&"attack",Vector3(10,0.1,10))
	check(actor.combat.state==actor.combat.State.GUARD,"G does not interrupt attack")
	var state: Dictionary = escort.runtime.groups[actor.phalanx_group_id]
	check(state.manual_order.mode==&"attack","G order missing")
	escort.issue(&"hold",Vector3(-10,0.1,10))
	var held: Vector3 = state.manual_order.position
	world.player.global_position = Vector3(20,0.1,0)
	var allied = service.armies[String(zone.id)+":spartan"]
	allied.update(service.clock+5.0,Vector3.ZERO,allied.last_opponents,true)
	check(state.manual_order.position.is_equal_approx(held),"H follows player instead of holding")
	check(escort.runtime.battle_layout.records[actor.phalanx_group_id].command_assignment.mission==&"escort_hold","H does not reach normal troop runtime")
	escort.issue(&"shield",world.player.global_position)
	check(escort.mode==&"hold","retired B mode remains active")
	check(not InputMap.has_action(&"escort_shield"),"B input remains assigned")
	for action: StringName in [&"escort_attack",&"escort_hold"]: check(InputMap.has_action(action),"missing input action")
	# Physical-key input is routed through the scene; targeted orders raycast the floor.
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.global_position = Vector3(20,15,15)
	camera.look_at(Vector3(20,0,0))
	camera.current = true
	var gore_before: bool = world.player.player_presentation.gore_hud.is_enabled()
	for command: Array in [[KEY_G,&"attack"],[KEY_H,&"hold"],[KEY_B,&"hold"]]:
		var event := InputEventKey.new()
		event.physical_keycode = command[0]
		event.keycode = command[0]
		event.unicode = command[0]
		event.pressed = true
		Input.parse_input_event(event)
		await physics_frame
		await process_frame
		await physics_frame
		await process_frame
		check(escort.mode==command[1],"physical input or ground selection failed " + String(command[1]))
		event.pressed = false
		Input.parse_input_event(event)
	check(world.player.player_presentation.gore_hud.is_enabled()==gore_before,"G still toggles gore")
	escort.issue(&"attack",Vector3(0,0.1,15))
	for id: StringName in escort.group_ids:
		if escort.runtime.groups.has(id):
			var group: Dictionary = escort.runtime.groups[id]
			group.anchor = group.manual_order.position
	allied.next_orders = 0.0
	allied.update(service.clock+10.0,Vector3.ZERO,allied.last_opponents,true)
	for id: StringName in escort.group_ids:
		if escort.runtime.groups.has(id): check(not escort.runtime.groups[id].has("manual_order"),"G does not restore autonomous combat on arrival")
	var legacy := Document.entity("battlefield","Legacy",Vector3.ZERO,{"ally_doctrine":"bodyguard","ally_infantry":6})
	var legacy_group := Document.entity("enemy_group","Old escort",Vector3.ZERO,{"battlefield_id":legacy.id,"faction":"spartan","count":6})
	var migrated := Document.new({"entities":[legacy,legacy_group]})
	check(not migrated.find_entity(legacy.id).properties.has("ally_doctrine"),"retired doctrine not removed")
	check(migrated.find_entity(legacy.id).properties.escort_infantry==6,"legacy composition not migrated")
	check(migrated.find_entity(legacy_group.id).properties.player_escort,"legacy members not migrated")
	host.queue_free()
	await process_frame
	await process_frame
	print("PLAYER_ESCORT ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
