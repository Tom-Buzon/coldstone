extends SceneTree
const Budget = preload("res://scripts/enemy_v2/enemy_v2_threat_budget.gd")
const Troops = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")
var failures: Array[String] = []
class Attacker extends Node3D:
	var dead := false
	var combat: Node
	var combat_target: Node3D
	func can_accept_phalanx_attack() -> bool: return true
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := Node3D.new()
	world.add_child(player)
	# An uninitialized NPC is sufficient for target classification.
	var npc := HopliteEnemyActorV2.new()
	var budget := Budget.new()
	var members: Array = []
	var ids: Array = []
	for i in range(64):
		var actor := Attacker.new()
		world.add_child(actor)
		actor.combat_target = npc
		actor.set_meta("v2_encounter", "probe")
		members.append(actor)
		ids.append(actor.get_instance_id())
		check(budget.request(actor,npc,&"melee",1,5.0),"NPC admission blocked at %d" % i)
	for i in range(6):
		var actor := Attacker.new()
		world.add_child(actor)
		actor.position = Vector3(0,0,3)
		var accepted := budget.request(actor,player,&"melee" if i<4 else &"ranged",1 if i<4 else 2,5.0)
		check(accepted == (i<5),"player budget contaminated by NPCs")
	var extra := Attacker.new()
	world.add_child(extra)
	check(budget.request(extra,npc,&"heavy",3,5.0),"player saturation blocked NPC")
	var troops := Troops.new()
	var profile := HopliteV2PhalanxProfile.new()
	profile.max_concurrent_attacks = 1
	var state := {"members":members,"front_rank":ids,"attack_leases":{},"attack_cursor":0,
		"profile":profile,"persistent_fronts":true,"capabilities":EnemyV2UnitCapabilities.new(),"target":player}
	# The first member occupies the only player slot; all others must still attack NPCs.
	members[0].combat_target = player
	troops._update_attack_leases(state,0.1,true)
	check(state.attack_leases.size()==64,"formation cap blocked NPC duels")
	check(troops.threat_budget.leases.size()==64,"shared budget blocked formation duels")
	state.attack_leases.clear()
	troops.threat_budget = Budget.new()
	for actor: Node3D in members: actor.combat_target = player
	troops._update_attack_leases(state,0.1,true)
	check(state.attack_leases.size()==1,"player formation cap lost")
	state.attack_leases.clear()
	troops.threat_budget = Budget.new()
	state.persistent_fronts = false
	for actor: Node3D in members: actor.combat_target = npc
	troops._update_attack_leases(state,0.1,true)
	check(state.attack_leases.size()==1,"legacy formation cap lost")
	troops.free()
	npc.free()
	world.free()
	print("BATTLEFIELD_ATTACK_BUDGET ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)
