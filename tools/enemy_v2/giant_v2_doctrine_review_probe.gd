extends SceneTree
## Independent regression scenarios for the doctrine/attack admission contract.
const Layout = preload("res://scripts/enemy_v2/enemy_v2_battle_layout_runtime.gd")
const Director = preload("res://scripts/enemy_v2/enemy_v2_front_director.gd")
const Capabilities = preload("res://scripts/enemy_v2/enemy_v2_unit_capabilities.gd")
const Budget = preload("res://scripts/enemy_v2/enemy_v2_threat_budget.gd")
const Arrow = preload("res://scripts/enemy_v2/archer_v2_projectile.gd")
const Troops = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")
class ProjectileCombat extends Node:
	var projectile: Node3D
	func is_attack_committed() -> bool:
		return is_instance_valid(projectile) and not projectile.is_queued_for_deletion()
class Combatant extends Node3D:
	var dead := false
	var combat: Node
class Target extends Node3D:
	var hits := 0
	func receive_enemy_hit(_damage: float, _source: Node, _direction: Vector3) -> bool:
		hits += 1
		return true
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func expect(condition: bool, label: String) -> void:
	print("DOCTRINE_REVIEW ", "PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)
func record(target: Node3D, front: int, origin: Vector3, role: StringName = &"phalanx") -> Dictionary:
	return {"persistent_fronts": true, "target_id": target.get_instance_id(), "front_id": front,
		"front_origin": origin, "front_forward": Vector3.BACK, "home_anchor": origin,
		"current_anchor": origin, "forward": Vector3.BACK, "capabilities": Capabilities.from_properties({"v2_unit_role": role}, role),
		"member_count": 24, "original_count": 24, "registration_order": front + 1, "disorganized_until": 0}
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Target.new()
	target.position = Vector3(0, 0, 10)
	world.add_child(target)
	# Real deaths notify one at a time, even when one sword sweep kills many.
	var layout := Layout.new()
	layout.register_group(&"losses", target, Vector3.ZERO, {"v2_persistent_fronts": true, "v2_unit_role": "phalanx"}, &"hoplite_phalanx", 24)
	for remaining: int in range(23, 15, -1):
		layout.update_group(&"losses", Vector3.ZERO, remaining)
	expect(int(layout.records[&"losses"].disorganized_until) > Time.get_ticks_msec(), "sequential casualties preserve breach window")
	# A completely destroyed front must still expose its hole to its neighbour.
	var director := Director.new()
	var records := {&"destroyed": record(target, 0, Vector3.ZERO), &"neighbour": record(target, 1, Vector3(12, 0, 0))}
	records[&"destroyed"].disorganized_until = 4000
	director.update(records, target.get_instance_id(), target, 1000)
	director.update(records, target.get_instance_id(), target, 1800)
	expect(records[&"neighbour"].assignment.mission == &"cover_flank", "neighbour covers an observed breach")
	records.erase(&"destroyed")
	director.update(records, target.get_instance_id(), target, 1900)
	expect(records[&"neighbour"].assignment.mission == &"cover_flank", "destroying last group preserves adjacent response")
	# An absent role must not leave mandatory empty slots or prevent orders.
	for role: StringName in [&"phalanx", &"archer", &"infantry", &"giant"]:
		var single_director := Director.new()
		var single := {&"single": record(target, 0, Vector3.ZERO, role)}
		single_director.update(single, target.get_instance_id(), target, 1000)
		expect(not single[&"single"].assignment.is_empty(), "single-role doctrine " + String(role))
	# An arrow remains dangerous after its shooter dies. Admission must account
	# for it until impact/expiry instead of admitting two replacement archers.
	target.position = Vector3.ZERO
	var budget := Budget.new()
	var shooters: Array[Combatant] = []
	for index: int in range(4):
		var shooter := Combatant.new()
		shooter.position = Vector3(-6.0 + float(index) * 0.5, 0, -8)
		world.add_child(shooter)
		shooter.combat = ProjectileCombat.new()
		shooter.add_child(shooter.combat)
		shooters.append(shooter)
	for index: int in range(2):
		budget.request(shooters[index], target, &"ranged", 2, 4.0)
		var projectile := Arrow.new()
		world.add_child(projectile)
		projectile.launch(shooters[index].position + Vector3.UP, Vector3.UP, shooters[index], target, 1)
		projectile.set_physics_process(false)
		shooters[index].combat.projectile = projectile
		shooters[index].dead = true
	budget.prune()
	expect(budget.active_cost() == 4, "dead shooters keep danger budget for live arrows")
	var replacement := budget.request(shooters[2], target, &"ranged", 2, 4.0)
	expect(not replacement, "in-flight volley blocks premature replacement volley")
	for index: int in range(2):
		var projectile: Node = shooters[index].combat.projectile
		for frame: int in range(40):
			if not projectile.is_queued_for_deletion():
				projectile._physics_process(1.0 / 60.0)
	expect(target.hits == 2, "arrows from dead shooters remain physically dangerous")
	var troops := Troops.new()
	world.add_child(troops)
	troops.battle_layout.register_group(&"low_line", target, Vector3(20, 0, 0), {"v2_persistent_fronts": true, "v2_unit_role": "phalanx", "formation_columns": 4}, &"hoplite_phalanx", 12)
	expect(not troops.is_fire_lane_clear(&"archers", Vector3.ZERO, Vector3(40, 0, 0)), "ground-level allied line blocks arrows")
	expect(troops.is_fire_lane_clear(&"archers", Vector3(0, 10, 0), Vector3(40, 0, 0)), "high-ground arrow lane clears low allied line")
	print("DOCTRINE_REVIEW_RESULT ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
