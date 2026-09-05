extends SceneTree
const Planner = preload("res://scripts/enemy_v2/battlefield/adaptive_army_planner.gd")
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func group(id: StringName, pos: Vector3, strength: float, engaged: bool = false) -> Dictionary:
	return {"id":id,"anchor":pos,"strength":strength,"role":&"infantry","width":6.0,"depth":3.0,"health_ratio":1.0,"engaged":engaged,"forward":Vector3.FORWARD}
func _initialize() -> void:
	var planner := Planner.new()
	var own := {}
	for i in range(6): own[StringName(str(i))] = group(StringName(str(i)),Vector3(i*5-12,0,-12),20.0)
	var enemies: Array[Dictionary] = [group(&"e0",Vector3(-5,0,0),20.0,true),group(&"e1",Vector3(5,0,0),20.0,true)]
	var orders := planner.plan(own,enemies,Vector3.ZERO,1.0)
	check(orders.size()==own.size(),"some groups unassigned")
	var envelopment := 0
	for order: Dictionary in orders.values():
		if order.mission==&"envelop": envelopment += 1
	check(envelopment>0,"superior army never envelops")
	enemies[0].health_ratio = 0.3
	enemies[0].breached = true
	orders = planner.plan(own,enemies,Vector3.ZERO,5.0)
	check(orders.values().any(func(o: Dictionary) -> bool: return o.mission==&"exploit"),"breach not exploited")
	var weak := {&"front":group(&"front",Vector3.ZERO,6.0,true),&"reserve":group(&"reserve",Vector3(0,0,-12),12.0)}
	weak[&"front"].health_ratio = 0.4
	enemies = [group(&"strong",Vector3(0,0,5),80.0,true)]
	orders = planner.plan(weak,enemies,Vector3.ZERO,10.0)
	check(orders[&"reserve"].mission==&"reinforce","weak front gets no reinforcements")
	check(orders[&"front"].mission==&"contain","outnumbered front does not adapt")
	var ranged := {&"bow":group(&"bow",Vector3.ZERO,12.0)}
	ranged[&"bow"].role = &"archer"
	orders = planner.plan(ranged,enemies,Vector3.ZERO,15.0)
	check(orders[&"bow"].mission==&"withdraw_fire","archers do not withdraw from melee")
	orders = planner.plan(ranged,[],Vector3.ZERO,20.0)
	check(orders[&"bow"].target_id==&"","dead target retained")
	var occupancy := preload("res://scripts/enemy_v2/enemy_v2_tactical_occupancy_runtime.gd").new()
	occupancy.update_footprint(&"crossing",Vector3(7,0,5),Vector3.FORWARD,10.0,3.0)
	occupancy.update_footprint(&"far",Vector3(50,0,50),Vector3.FORWARD,6.0,3.0)
	var along: Array = occupancy.groups_along_segment(Vector3.ZERO,Vector3(14,0,10))
	check(along.has(&"crossing") and not along.has(&"far"),"shooting broad phase lost a crossing formation")
	print("ADAPTIVE_ARMY ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
