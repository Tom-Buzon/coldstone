extends RefCounted
## Tactical choices use bounded group snapshots, independent of actor/weapon execution.
const Situation = preload("res://scripts/enemy_v2/battlefield/army_situation.gd")
var orders: Dictionary = {}
var previous_enemies: Dictionary = {}
var gaps: Array[Dictionary] = []
var strength_ratio := 1.0
func plan(own: Dictionary, enemies: Array[Dictionary], fallback: Vector3, now: float) -> Dictionary:
	var friends: Array = own.values()
	strength_ratio = Situation.total(friends)/maxf(1.0,Situation.total(enemies))
	var friendly_center := Situation.center(friends,fallback)
	var enemy_center := Situation.center(enemies,fallback)
	var forward := (enemy_center-friendly_center).normalized()
	if forward.length_squared()<0.01: forward = Vector3.FORWARD
	var right := Vector3.UP.cross(forward).normalized()
	var enemy_ids := {}
	for enemy: Dictionary in enemies: enemy_ids[enemy.id] = enemy
	for id: Variant in previous_enemies:
		if not enemy_ids.has(id): gaps.append({"position":previous_enemies[id].anchor,"until":now+8.0})
	previous_enemies = enemy_ids
	gaps = gaps.filter(func(g: Dictionary) -> bool: return float(g.until)>now)
	var threatened: Dictionary = {}
	for friend: Dictionary in friends:
		if not bool(friend.get("engaged",false)): continue
		var nearby_enemy := Situation.local_strength(enemies,friend.anchor)
		var nearby_friend := Situation.local_strength(friends,friend.anchor)
		if nearby_enemy>nearby_friend*1.25 or float(friend.get("health_ratio",1.0))<0.55:
			threatened[friend.id] = friend
	var assigned := {}
	var reinforced := {}
	var next := {}
	# Front groups pin first; fresh rear groups can exploit their pressure.
	var sorted: Array = own.keys()
	sorted.sort_custom(func(a: Variant,b: Variant) -> bool: return (own[a].anchor as Vector3).distance_squared_to(enemy_center)<(own[b].anchor as Vector3).distance_squared_to(enemy_center))
	for id: StringName in sorted:
		var group: Dictionary = own[id]
		if enemies.is_empty():
			next[id] = {"position":group.anchor,"objective":fallback,"mission":&"rally","target_id":&""}
			continue
		var enemy := _choose_target(group,enemies,assigned,now)
		var point: Vector3 = enemy.anchor
		var direction := (point-(group.anchor as Vector3)).normalized()
		if direction.length_squared()<0.01: direction = forward
		var side := 1.0 if ((group.anchor as Vector3)-enemy_center).dot(right)>=0 else -1.0
		var enemy_forward: Vector3 = enemy.get("forward",forward)
		var extent := absf(direction.dot(enemy_forward))*float(enemy.get("depth",3.0))*0.5+absf(direction.dot(Vector3.UP.cross(enemy_forward)))*float(enemy.get("width",6.0))*0.5
		var stand_off := float(group.get("depth",3.0))*0.5+extent+0.45
		var goal := point-direction*stand_off
		var mission: StringName = &"fix"
		var local_ratio := Situation.local_strength(friends,point)/maxf(1.0,Situation.local_strength(enemies,point))
		var load := float(assigned.get(enemy.id,0.0))
		if group.role == &"archer":
			mission = &"fire_support"
			goal = point-direction*17.0
			if (group.anchor as Vector3).distance_to(point)<10.0:
				mission = &"withdraw_fire"
				goal = (group.anchor as Vector3)-direction*7.0
		elif not bool(group.get("engaged",false)) and not threatened.is_empty() and strength_ratio<1.25:
			var endangered: Dictionary = {}
			var distance := INF
			for need: Dictionary in threatened.values():
				if need.id == id or reinforced.has(need.id): continue
				var d := (group.anchor as Vector3).distance_squared_to(need.anchor)
				if d<distance: distance=d; endangered=need
			if not endangered.is_empty():
				mission = &"reinforce"
				goal = endangered.anchor+right*side*(float(endangered.get("width",6.0))+float(group.get("width",6.0)))*0.5
				reinforced[endangered.id] = true
		if group.role != &"archer" and mission != &"reinforce":
			if (bool(enemy.get("breached",false)) or float(enemy.get("health_ratio",1.0))<0.6) and local_ratio>0.8:
				mission = &"exploit"
			elif not gaps.is_empty() and not bool(group.get("engaged",false)) and strength_ratio>0.85:
				for gap: Dictionary in gaps:
					if (gap.position as Vector3).distance_to(group.anchor)<22.0:
						mission = &"exploit"
						goal = (gap.position as Vector3).move_toward(point,8.0)
						break
			elif (strength_ratio>1.2 or local_ratio>1.35) and (load>float(enemy.get("strength",1.0))*0.65 or bool(enemy.get("engaged",false))):
				mission = &"envelop"
				# Approach outside the front before turning inward; don't cut through allies.
				var flank := point+right*side*(float(enemy.get("width",6.0))*0.5+float(group.get("depth",3.0))*0.5+1.5)
				goal = flank
				if absf(((group.anchor as Vector3)-point).dot(right))<float(enemy.get("width",6.0))*0.5+2.0 and ((group.anchor as Vector3)-point).dot(forward)<-5.0:
					goal = flank-forward*8.0
			elif local_ratio<0.75 and bool(group.get("engaged",false)):
				mission = &"contain"
				# Limited fallback keeps the line in contact rather than fleeing to spawn.
				goal = (group.anchor as Vector3)-direction*2.0
		assigned[enemy.id] = load+float(group.get("strength",1.0))
		var old: Dictionary = orders.get(id,{})
		# Preserve a maneuver briefly, but never persist a dead target or a new emergency.
		if not old.is_empty() and now<float(old.get("until",0.0)) and old.target_id==enemy.id and mission not in [&"reinforce",&"contain",&"withdraw_fire"]:
			if (group.anchor as Vector3).distance_to(old.position)>2.0 and old.mission in [&"envelop",&"exploit"]:
				goal=old.position; mission=old.mission
		next[id] = {"position":goal,"objective":point,"mission":mission,"target_id":enemy.id,"until":now+2.5 if old.is_empty() or old.mission!=mission else old.get("until",now)}
	orders = next
	return next
func _choose_target(group: Dictionary, enemies: Array[Dictionary], assigned: Dictionary, now: float) -> Dictionary:
	var best := INF
	var chosen: Dictionary = enemies[0]
	var previous: Dictionary = orders.get(group.id,{})
	for enemy: Dictionary in enemies:
		var distance := (group.anchor as Vector3).distance_squared_to(enemy.anchor)
		var load := float(assigned.get(enemy.id,0.0))/maxf(1.0,float(enemy.get("strength",1.0)))
		var score := distance+load*120.0
		if float(enemy.get("health_ratio",1.0))<0.6: score *= 0.8
		if previous.get("target_id",&"")==enemy.id: score *= 0.75 if now<float(previous.get("until",0.0)) else 0.9
		if score<best: best=score; chosen=enemy
	return chosen
