extends RefCounted
## Pure authoring: produces normal V2 groups, never a second runtime AI.
const ROLES := ["phalanx", "infantry", "archer", "giant"]
const IDS := ["enemy_v2_hoplite", "enemy_v2_infantry", "enemy_v2_archer", "enemy_v2_giant"]
const CHUNKS := [24, 12, 12, 1]
static func defaults() -> Dictionary:
	return {"size": [70.0, 4.0, 90.0], "mode": "armies", "difficulty": "normal", "enemy_phalanx": 48, "enemy_infantry": 24, "enemy_archer": 12, "enemy_giant": 1, "ally_phalanx": 48, "ally_infantry": 24, "ally_archer": 12, "ally_giant": 0, "giant_scale": 3.0, "activation": "start", "deployment_spacing":11.5, "front_gap":12.0, "player_focus_radius":22.0, "player_focus_fraction":0.5, "guards_per_champion":2, "champion_aggro_radius":32.0, "champion_guard_radius":9.0, "escort_phalanx":0, "escort_infantry":0, "escort_archer":0, "escort_giant":0, "bodyguard_power":4.0}
static func compose(zone: Dictionary) -> Dictionary:
	var p: Dictionary = zone.properties
	var size := Vector3(float(p.size[0]), float(p.size[1]), float(p.size[2]))
	var origin := Vector3(float(zone.position[0]), float(zone.position[1]), float(zone.position[2]))
	var scale_data: Array = zone.get("scale", [1,1,1])
	size *= Vector3(float(scale_data[0]), float(scale_data[1]), float(scale_data[2])).abs()
	var rotation: Array = zone.get("rotation", [0,0,0])
	var basis := Basis(Vector3.UP, deg_to_rad(float(rotation[1])))
	var cell := maxf(float(p.get("deployment_spacing",11.5)), float(p.get("giant_scale", 3.0)) * 2.2 + 4.0)
	var max_columns := maxi(1, int((size.x - 8.0) / cell))
	var entities: Array[Dictionary] = []
	var errors: Array[String] = []
	var escort_total := 0
	for role: String in ROLES: escort_total += int(p.get("escort_"+role,0))
	if escort_total>24: errors.append("Escorte : maximum 24 unités. Réduisez ses effectifs.")
	var escort_depth := cell * 2.0
	var total := 0
	for camp: String in (["enemy", "ally", "escort"] if p.get("mode", "armies") == "armies" else ["enemy", "escort"]):
		var entries: Array[Dictionary] = []
		for role_index in range(ROLES.size()):
			var remaining := clampi(int(p.get(camp + "_" + ROLES[role_index], 0)), 0, 500)
			while remaining > 0:
				var count := mini(remaining, CHUNKS[role_index])
				entries.append({"role":ROLES[role_index], "archetype":IDS[role_index], "count":count})
				remaining -= count
		var columns := mini(max_columns,maxi(1,ceili(sqrt(float(entries.size())*2.0))))
		# Champions lead from the front rather than being trapped behind the line.
		for entry: Dictionary in entries.duplicate():
			if entry.role == "giant":
				entries.erase(entry)
				entries.insert(mini(columns / 2,entries.size()),entry)
		var rows := ceili(float(entries.size()) / columns)
		if camp == "ally": escort_depth = maxf(escort_depth,float(rows)*cell)
		if size.x < cell + 8.0 or float(rows) * cell + 10.0 > size.z * 0.5:
			errors.append("%s : agrandissez la zone ou réduisez les effectifs (au moins %.0f m de profondeur)." % ["Alliés" if camp == "ally" else "Ennemis", (rows * cell + 10.0) * 2.0])
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			var sign_value := 1.0 if camp in ["ally","escort"] else -1.0
			var x := (float(i % columns) - float(columns - 1) * 0.5) * cell
			var z := sign_value * (maxf(6.0,float(p.get("front_gap",12.0))*0.5) + float(i / columns) * cell)
			if camp == "escort": z += escort_depth
			var pos := origin + basis * Vector3(x, 0.1, z)
			var forward := basis * Vector3(0,0,-sign_value)
			var id := "%s_%s_%d" % [zone.id, camp, i]
			var props := {"group_id":id, "archetype":entry.archetype, "count":entry.count, "composition":[{"archetype":entry.archetype,"count":entry.count}], "formation":"phalanx", "formation_columns":8 if entry.role == "phalanx" else (1 if entry.role == "giant" else 4), "formation_spacing":0.95, "formation_rank_spacing":1.0, "size_multiplier":float(p.get("giant_scale",3.0)) if entry.role == "giant" else 1.0, "v2_combat_lab":true, "v2_animation":"idle", "v2_troop_mode":"hoplite_phalanx" if entry.role == "phalanx" else entry.role, "v2_unit_role":entry.role, "v2_persistent_fronts":true, "v2_front_id":i % columns, "v2_front_origin":[pos.x,pos.y,pos.z], "v2_front_forward":[forward.x,0,forward.z], "battlefield_id":zone.id, "player_escort":camp == "escort", "faction":"spartan" if camp in ["ally","escort"] else "athenian", "deployment_locked":false, "spawn_condition":"start", "deployment_mode":"all", "behavior":"normal"}
			entities.append({"id":id,"type":"enemy_group","name":"%s — %s %d" % ["Escorte" if camp == "escort" else ("Alliés" if camp == "ally" else "Ennemis"),{"phalanx":"Hoplites","infantry":"Fantassins","archer":"Archers","giant":"Géant"}[entry.role],i+1],"position":[pos.x,pos.y,pos.z],"rotation":[0,rad_to_deg(atan2(forward.x,forward.z)),0],"scale":[1,1,1],"enabled":true,"chapter":zone.get("chapter","chapter_1"),"properties":props})
			total += int(entry.count)
	return {"entities":entities,"errors":errors,"population":total}
static func populate(data: Dictionary, zone: Dictionary) -> Dictionary:
	var result := compose(zone)
	if not result.errors.is_empty(): return result
	var preserved: Dictionary = {}
	var keep: Array = []
	for entity: Dictionary in data.entities:
		if entity.get("properties",{}).get("battlefield_id","") != zone.id:
			keep.append(entity)
		elif entity.properties.get("battlefield_boss",false):
			keep.append(entity)
		elif entity.properties.get("deployment_locked",false):
			preserved[entity.id] = entity
	for entity: Dictionary in result.entities:
		keep.append(preserved.get(entity.id,entity))
		preserved.erase(entity.id)
	for entity: Dictionary in preserved.values(): keep.append(entity)
	var deployed: Array = keep.filter(func(e: Dictionary) -> bool: return e.get("properties",{}).get("battlefield_id","") == zone.id and not e.get("properties",{}).get("battlefield_boss",false))
	var origin := Vector3(float(zone.position[0]),float(zone.position[1]),float(zone.position[2]))
	var rotation: Array = zone.get("rotation",[0,0,0])
	var inverse := Basis(Vector3.UP,deg_to_rad(float(rotation[1]))).inverse()
	var size: Array = zone.properties.size
	var scale_value: Array = zone.get("scale",[1,1,1])
	result.population = 0
	for entity: Dictionary in deployed:
		result.population += int(entity.properties.get("count",0))
		var pos := Vector3(float(entity.position[0]),float(entity.position[1]),float(entity.position[2]))
		var local := inverse * (pos-origin)
		if absf(local.x)+5 > float(size[0])*absf(float(scale_value[0]))*0.5 or absf(local.z)+5 > float(size[2])*absf(float(scale_value[2]))*0.5:
			result.errors.append("Placement hors zone : " + String(entity.name))
		for other: Dictionary in deployed:
			if other.id == entity.id: break
			var other_pos := Vector3(float(other.position[0]),float(other.position[1]),float(other.position[2]))
			if Vector2(pos.x-other_pos.x,pos.z-other_pos.z).length() < 10.0:
				result.errors.append("Placements trop proches : %s / %s. Déplacez ou déverrouillez ces groupes." % [entity.name,other.name])
	if not result.errors.is_empty(): return result
	data.entities = keep
	return result

static func bodyguard_preset() -> Dictionary:
	var p := defaults()
	p.escort_infantry = 6
	p.ally_phalanx = 0
	p.ally_infantry = 0
	p.ally_archer = 0
	p.ally_giant = 0
	p.enemy_phalanx = 96
	p.enemy_infantry = 48
	p.enemy_archer = 24
	p.enemy_giant = 2
	p.size = [80.0,4.0,100.0]
	return p
