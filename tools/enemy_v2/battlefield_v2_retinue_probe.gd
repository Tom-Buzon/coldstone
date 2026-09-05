extends SceneTree
const Document = preload("res://scripts/world_editor/world_document.gd")
const Runtime = preload("res://scripts/world_editor/world_runtime.gd")
const Composer = preload("res://scripts/enemy_v2/battlefield/battlefield_composer.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _run() -> void:
	var props := Composer.bodyguard_preset()
	props.enemy_phalanx = 48
	props.enemy_infantry = 24
	props.enemy_archer = 12
	var doc := Document.new()
	var zone := Document.entity("battlefield","Retinues",Vector3.ZERO,props)
	doc.data.entities = [Document.entity("surface","Floor",Vector3(0,-0.2,0),{"shape":"floor","size":[220,0.4,220],"material":"pavers"}),Document.entity("player_spawn","Player",Vector3(0,0.1,90),{}),zone]
	check(Composer.populate(doc.data,zone).errors.is_empty(),"preset capacity invalid")
	var host := Node3D.new()
	root.add_child(host)
	current_scene = host
	var world := Runtime.new()
	host.add_child(world)
	world.build(Document.from_json(doc.to_json()),false)
	for frame in range(600):
		if world.pending_enemy_spawns.is_empty(): break
		await process_frame
	world.player.set_physics_process(false)
	var service: Node = world.battlefield_runtime
	service.set_process(false)
	for army: RefCounted in service.armies.values():
		army.runtime.set_process(false)
		army.next_orders = 0.0
		for state: Dictionary in army.runtime.groups.values():
			for actor: Node in state.members:
				actor.set_physics_process(false)
				actor.combat.set_physics_process(false)
				actor.combat.state = actor.combat.State.GUARD
	service._refresh_snapshot()
	var enemy = service.armies[String(zone.id)+":athenian"]
	var escort = service.escort
	escort.runtime.set_process(false)
	enemy.observe_player(world.player)
	check(enemy.retinue.champions.size()==2,"two independent champions missing")
	var ids: Array = enemy.retinue.champions.keys()
	var first: Dictionary = enemy.retinue.champions[ids[0]]
	var second: Dictionary = enemy.retinue.champions[ids[1]]
	check(first.guards.size()==2 and second.guards.size()==2,"guard quotas wrong")
	check(first.state==&"guard" and second.state==&"guard","boss seeks allies outside perimeter")
	var boss: Node3D = first.actor.get_ref()
	check(boss.combat_target==null,"sleeping boss has a target")
	var away: Vector3 = ((first.home as Vector3)-(second.home as Vector3)).normalized()
	world.player.global_position = first.home + away*31.0
	enemy.observe_player(world.player)
	check(first.state==&"alert" and boss.combat_target==world.player,"boss does not focus at 31m")
	check(second.state==&"guard","other boss alerted outside perimeter")
	for id: StringName in first.guards:
		if (enemy.groups[id].anchor as Vector3).distance_to(world.player.global_position)<14.0:
			for actor: Node in enemy.runtime.groups[id].members: check(actor.combat_target==world.player,"nearby guards did not acquire player immediately")
	boss.dead = true
	enemy.runtime.remove_group(ids[0])
	enemy.observe_player(world.player)
	world.player.global_position = Vector3(100,0.1,90)
	enemy.observe_player(world.player)
	enemy.next_orders = 0.0
	var empty: Array[Dictionary] = []
	enemy.update(100,world.player.global_position,empty,true)
	for id: StringName in first.guards:
		check(enemy.retinue.policy_for(id)==&"vengeance","guard lost vengeance")
		var actor: Node3D = enemy.runtime.groups[id].members[0]
		service._update_target(actor)
		check(actor.combat_target==world.player,"vengeance range cut off")
		check((enemy.runtime.battle_layout.records[id].command_assignment.position as Vector3).x>70.0,"vengeance clamped to battlefield")
	check(second.state==&"guard","unrelated retinue entered vengeance")
	var elite: Node3D = escort.members[0]
	check(escort.members.size()==6,"elite count wrong")
	check(is_equal_approx(elite.effective_attack_damage(),elite.definition.attack_damage*4.0),"elite damage not applied")
	var attacker: Node3D = enemy.runtime.groups[first.guards[0]].members[0]
	check(attacker.effective_attack_damage()==attacker.definition.attack_damage,"shared enemy definition mutated")
	attacker.set_combat_target(elite)
	var budget = enemy.runtime.threat_budget
	check(budget.request(attacker,elite,&"melee",1,2.0),"NPC permit setup failed")
	var guard_state: Dictionary = enemy.runtime.groups[first.guards[0]]
	guard_state.attack_leases[attacker.get_instance_id()] = 2.0
	attacker.set_combat_target(world.player)
	check(not budget.leases.has(attacker.get_instance_id()),"old target permit retained")
	check(not guard_state.attack_leases.has(attacker.get_instance_id()),"old group permit retained")
	attacker.set_combat_target(elite)
	attacker.combat.state = attacker.combat.State.ATTACK
	attacker.set_combat_target(world.player)
	check(attacker.combat_target==elite,"committed attack switched target")
	attacker.combat.state = attacker.combat.State.GUARD
	elite.combat.state = elite.combat.State.STUNNED
	var hp: float = elite.health
	elite.receive_ai_hit(16,attacker,Vector3.RIGHT)
	var mult: float = elite.health_component.zone_definitions[&"torso"].damage_mult
	check(is_equal_approx(hp-elite.health,4.0*mult),"elite resistance not applied")
	elite.global_position = world.player.global_position+Vector3(0,0,2.4)
	attacker.global_position = world.player.global_position+Vector3(10,0,0)
	service._refresh_snapshot()
	escort.issue(&"attack",world.player.global_position)
	attacker.global_position = elite.global_position+Vector3(2,0,0)
	service._refresh_snapshot()
	service._update_target(elite)
	check(elite.combat_target==attacker,"elite troop does not engage nearby threat")
	escort.issue(&"hold",world.player.global_position)
	check(escort.runtime.groups[elite.phalanx_group_id].manual_order.position.distance_to(world.player.global_position)<10,"H order missing")
	host.queue_free()
	await process_frame
	await process_frame
	print("BATTLEFIELD_RETINUE ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
