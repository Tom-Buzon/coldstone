extends SceneTree
const Layout = preload("res://scripts/enemy_v2/enemy_v2_battle_layout_runtime.gd")
const Budget = preload("res://scripts/enemy_v2/enemy_v2_threat_budget.gd")
var failures: Array[String] = []
class Attacker extends Node3D:
	var dead := false
	var combat: Node
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Node3D.new()
	world.add_child(target)
	var layout := Layout.new()
	for lane in range(2):
		for rank in range(3):
			var x := -12.0 if lane == 0 else 12.0
			var id := StringName("lane%d_rank%d" % [lane, rank])
			layout.register_group(id, target, Vector3(x, 0, -18 - rank * 20), {"v2_persistent_fronts": true,
				"v2_front_id": lane, "v2_front_origin": [x,0,-12], "v2_front_forward": [0,0,1]}, &"hoplite_phalanx",24)
	layout.front_director.update(layout.records, target.get_instance_id(), target, 1000)
	var first: Dictionary = layout.records[&"lane0_rank0"]["assignment"].duplicate()
	var second: Dictionary = layout.records[&"lane1_rank0"]["assignment"]
	_expect(first["role"] == &"frontline" and second["role"] == &"frontline", "independent fronts must advance concurrently")
	_expect(first["position"].x == -12.0 and second["position"].x == 12.0, "fronts preserve world-space lanes")
	target.position.x = 6.0
	layout.front_director.update(layout.records, target.get_instance_id(), target, 3000)
	_expect(layout.records[&"lane0_rank0"]["assignment"]["position"].x == first["position"].x, "a player feint moved the entire front")
	layout.records[&"lane0_rank0"]["disorganized_until"] = 6500
	layout.front_director.update(layout.records, target.get_instance_id(), target, 3500)
	layout.front_director.update(layout.records, target.get_instance_id(), target, 4300)
	_expect(layout.records[&"lane0_rank0"]["assignment"]["mission"] == &"reform", "breach has no exploitation window")
	_expect(layout.records[&"lane1_rank0"]["assignment"]["mission"] == &"cover_flank", "neighbor did not react to breach")
	var budget := Budget.new()
	var actors: Array[Attacker] = []
	for i in range(8):
		var actor := Attacker.new()
		world.add_child(actor)
		actor.position = Vector3(0,0,3)
		actors.append(actor)
	var melee := 0
	for i in range(5):
		if budget.request(actors[i],target,&"melee",1,2.0): melee += 1
	_expect(melee == 4, "melee admission is not bounded")
	_expect(budget.request(actors[5],target,&"ranged",2,2.0), "remaining pressure should allow one volley")
	_expect(not budget.request(actors[6],target,&"heavy",3,2.0), "heavy attack overfilled shared pressure")
	actors[0].dead = true
	budget.prune()
	_expect(budget.active_cost() == 5, "death did not release pressure")
	world.free()
	if failures.is_empty():
		print("ENEMY_V2_FRONTS_PROBE PASS independent_fronts stable_lanes breach_neighbor pressure_budget")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
