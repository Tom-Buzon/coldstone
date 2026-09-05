extends RefCounted
## Group snapshots only: no scene traversal or unit AI in the tactical planner.
const ROLE_WEIGHT := {&"phalanx":1.15, &"infantry":1.0, &"archer":1.25, &"giant":12.0}
static func capture(id: StringName, state: Dictionary, record: Dictionary, initial_health: float) -> Dictionary:
	var health := 0.0
	var strength := 0.0
	var count := 0
	for actor: Node3D in state.members:
		if not is_instance_valid(actor) or actor.dead: continue
		count += 1
		health += actor.health
		strength += clampf(actor.health / maxf(1.0,actor.max_health),0.1,1.0) * actor.combat_modifiers.power
	var role: StringName = state.capabilities.role
	return {"id":id,"anchor":state.anchor,"role":role,"count":count,
		"strength":strength*float(ROLE_WEIGHT.get(role,1.0)),"health":health,
		"health_ratio":health/maxf(1.0,initial_health),"engaged":state.get("group_engaged",false),
		"breached":state.get("intrusion",false),"cohesion":state.get("cohesion",1.0),
		"width":record.get("formation_width",6.0),"depth":record.get("formation_depth",3.0),
		"forward":state.forward}
static func total(groups: Array) -> float:
	var result := 0.0
	for group: Dictionary in groups: result += float(group.get("strength",1.0))
	return result
static func center(groups: Array, fallback: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var weight := 0.0
	for group: Dictionary in groups:
		var power := maxf(1.0,float(group.get("strength",1.0)))
		sum += (group.anchor as Vector3)*power
		weight += power
	return sum / weight if weight>0 else fallback
static func local_strength(groups: Array, point: Vector3, radius: float = 24.0) -> float:
	var result := 0.0
	for group: Dictionary in groups:
		if (group.anchor as Vector3).distance_squared_to(point)<=radius*radius:
			result += float(group.get("strength",1.0))
	return result
