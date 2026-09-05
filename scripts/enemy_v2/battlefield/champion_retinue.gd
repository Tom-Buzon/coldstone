extends RefCounted
## Persistent ownership survives the champion's removal from the troop runtime.
## Only champion state is observed each frame; soldiers react on state changes.
var champions: Dictionary = {}
var owners: Dictionary = {}
var dirty := true

func refresh_bindings(groups: Dictionary, runtime: Node, settings: Dictionary) -> void:
	for id: StringName in groups:
		var group: Dictionary = groups[id]
		if (group.role != &"giant" and not group.get("is_champion",false)) or champions.has(id) or not runtime.groups.has(id): continue
		var members: Array = runtime.groups[id].members
		if members.is_empty(): continue
		champions[id] = {"actor":weakref(members[0]),"home":group.home,"position":group.anchor,"state":&"guard","guards":[]}
	for id: StringName in groups:
		if champions.has(id) or owners.has(id): continue
		var requested := StringName(groups[id].get("guard_of",&"auto"))
		if requested == &"none": continue
		var chosen := StringName()
		var best := INF
		for boss_id: StringName in champions:
			var boss: Dictionary = champions[boss_id]
			if boss.state == &"vengeance": continue
			if requested != &"auto" and requested != boss_id: continue
			if requested == &"auto" and groups.get(boss_id,{}).get("is_champion",false): continue
			if requested == &"auto" and boss.guards.size() >= int(settings.get("guards_per_champion",2)): continue
			var distance := (groups[id].anchor as Vector3).distance_squared_to(boss.position)
			if distance < best:
				best = distance
				chosen = boss_id
		if not chosen.is_empty():
			owners[id] = chosen
			champions[chosen].guards.append(id)
			dirty = true

func observe(player: Node3D, groups: Dictionary, runtime: Node, settings: Dictionary, active: bool) -> bool:
	var changed := dirty
	dirty = false
	var radius := float(settings.get("champion_aggro_radius",32.0))
	for id: StringName in champions:
		var boss: Dictionary = champions[id]
		var actor: Node3D = boss.actor.get_ref()
		var next: StringName = boss.state
		if not is_instance_valid(actor) or actor.dead:
			next = &"vengeance"
		else:
			boss.position = actor.global_position
			var distance := Vector2(player.global_position.x-boss.home.x,player.global_position.z-boss.home.z).length()
			var threshold := radius + (6.0 if boss.state == &"alert" else 0.0)
			next = &"alert" if active and distance <= threshold else &"guard"
		if next != boss.state:
			boss.state = next
			changed = true
	if changed:
		for id: StringName in groups:
			var policy := policy_for(id)
			if policy == &"normal" or not runtime.groups.has(id): continue
			if not champions.has(id) and policy != &"vengeance" and (policy != &"alert" or (groups[id].anchor as Vector3).distance_to(player.global_position)>=14.0): continue
			for actor: Node in runtime.groups[id].members:
				if is_instance_valid(actor): actor.set_combat_target(player if active and policy != &"guard" else null)
	return changed

func policy_for(id: StringName) -> StringName:
	var owner := id if champions.has(id) else StringName(owners.get(id,&""))
	return champions[owner].state if champions.has(owner) else &"normal"

func goal_for(id: StringName, group: Dictionary, context: Dictionary, settings: Dictionary) -> Vector3:
	var owner := id if champions.has(id) else StringName(owners.get(id,&""))
	var boss: Dictionary = champions[owner]
	var player: Vector3 = context.player
	if boss.state != &"guard":
		var direction: Vector3 = (player-(group.anchor as Vector3)).normalized()
		var distance := 15.0 if group.role == &"archer" else float(context.stand_off)
		return player - direction * distance
	if id == owner: return boss.home
	var slot: int = boss.guards.find(id)
	var radius := maxf(float(settings.get("champion_guard_radius",9.0)),float(context.get("group_width",6.0))*0.5+4.0)
	var angle := TAU * float(slot) / maxf(3.0,float(boss.guards.size()))
	return boss.position + Vector3(cos(angle),0,sin(angle))*radius
