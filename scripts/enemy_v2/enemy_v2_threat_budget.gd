extends RefCounted
class_name EnemyV2ThreatBudget

## Player-local admission; NPC duels only reserve attack commitment. Committed attacks retain their reservation, including
## recovery; movement and visual population never consume this budget.
const TOTAL_COST := 6
const MAX_SECTORS := 3
const CAPS := {&"melee": 4, &"ranged": 2, &"heavy": 1}
var leases: Dictionary = {}
var player_leases: Dictionary = {}
var _request_prune_frame: int = -1

func request(actor: Node3D, target: Node3D, kind: StringName, cost: int, seconds: float) -> bool:
	prune_once()
	var id := actor.get_instance_id()
	if leases.has(id):
		return true
	var target_id := target.get_instance_id()
	var npc := target is HopliteEnemyActorV2
	if npc:
		leases[id] = {"actor": weakref(actor), "target": target_id, "kind": kind,
			"cost": cost, "sector": -1, "until": Time.get_ticks_msec() + int(seconds * 1000.0)}
		return true
	var limit := int(actor.get_meta("v2_player_pressure", TOTAL_COST))
	var used := 0
	var same_kind := 0
	var sectors: Dictionary = {}
	var direction := actor.global_position - target.global_position
	var sector := posmod(int(floor((atan2(direction.z, direction.x) + PI) / (TAU / 8.0))), 8)
	for lease: Dictionary in player_leases.values():
		if int(lease["target"]) != target_id:
			continue
		used += int(lease["cost"])
		if lease["kind"] == kind:
			same_kind += 1
		sectors[int(lease["sector"])] = true
	if used + cost > limit or same_kind >= int(CAPS.get(kind, 1)):
		return false
	if not sectors.has(sector) and sectors.size() >= MAX_SECTORS:
		return false
	leases[id] = {"actor": weakref(actor), "target": target_id, "kind": kind,
		"cost": cost, "sector": sector, "until": Time.get_ticks_msec() + int(seconds * 1000.0)}
	player_leases[id] = leases[id]
	return true

func release(actor_id: int) -> void:
	leases.erase(actor_id)
	player_leases.erase(actor_id)

func prune_once() -> void:
	if _request_prune_frame != Engine.get_process_frames(): prune()

func prune() -> void:
	_request_prune_frame = Engine.get_process_frames()
	var now := Time.get_ticks_msec()
	for id: Variant in leases.keys():
		var lease: Dictionary = leases[id]
		var actor: Node = lease["actor"].get_ref()
		if actor == null:
			release(id)
			continue
		if not bool(actor.get("dead")) and now < int(lease["until"]): continue
		var combat: Node = actor.get("combat")
		var committed := false
		if combat != null:
			if combat.has_method("is_attack_committed"):
				committed = bool(combat.call("is_attack_committed"))
			elif combat.has_method("is_formation_engaged"):
				committed = bool(combat.call("is_formation_engaged"))
		if bool(actor.get("dead")) and not committed:
			release(id)
		elif now >= int(lease["until"]):
			if committed:
				lease["until"] = now + 250
			else:
				release(id)

func active_cost() -> int:
	prune()
	var result := 0
	for lease: Dictionary in leases.values():
		result += int(lease["cost"])
	return result


func release_if_idle(actor_id: int) -> void:
	if not leases.has(actor_id):
		return
	var actor: Node = leases[actor_id]["actor"].get_ref()
	var combat: Node = actor.get("combat") if actor != null else null
	if combat != null:
		if combat.has_method("is_attack_committed") and bool(combat.call("is_attack_committed")):
			return
		if not combat.has_method("is_attack_committed") and combat.has_method("is_formation_engaged") and bool(combat.call("is_formation_engaged")):
			return
	leases.erase(actor_id)
	player_leases.erase(actor_id)
