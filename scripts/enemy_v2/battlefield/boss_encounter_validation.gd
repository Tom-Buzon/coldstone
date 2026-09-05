extends RefCounted

static func check(document: RefCounted, e: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var p: Dictionary = e.properties
	var prefix := "Boss « %s » : " % e.name
	var zone: Dictionary = document.find_entity(String(p.get("battlefield_id","")))
	if zone.get("type","") != "battlefield" or not zone.get("enabled",true) or zone.get("chapter","") != e.get("chapter",""):
		errors.append(prefix+"champ de bataille actif du même chapitre requis.")
	if p.get("archetype","") not in ["enemy_v2_giant","enemy_v2_hoplite","enemy_v2_infantry","enemy_v2_archer"] or int(p.get("count",0)) != 1:
		errors.append(prefix+"choisissez une unité V2 unique.")
	if p.get("spawn_condition","") != "battlefield": errors.append(prefix+"apparition réservée au gestionnaire de bataille.")
	var condition := String(p.get("boss_spawn_condition","loss_percent"))
	if condition not in ["start","loss_percent","target_dead","timer","trigger"]: errors.append(prefix+"condition inconnue.")
	if condition == "loss_percent":
		if float(p.get("boss_loss_percent",25)) < 1 or float(p.get("boss_loss_percent",25)) > 100: errors.append(prefix+"seuil de pertes entre 1 et 100 % requis.")
		var baseline := 0
		for other: Dictionary in document.entities():
			var op: Dictionary = other.get("properties",{})
			if other.get("enabled",true) and op.get("battlefield_id","") == p.get("battlefield_id","") and not op.get("battlefield_boss",false) and op.get("faction","athenian") == "athenian": baseline += int(op.get("count",0))
		if baseline == 0: errors.append(prefix+"peuplez d’abord l’armée ennemie ou choisissez un autre déclencheur.")
	if condition == "timer" and float(p.get("spawn_delay",30)) < 0: errors.append(prefix+"délai négatif.")
	if condition == "trigger":
		var target: Dictionary = document.find_entity(String(p.get("spawn_trigger","")))
		if target.is_empty(): target = document.find_by_name(String(p.get("spawn_trigger","")))
		if target.get("type","") != "trigger" or not target.get("enabled",true) or target.get("chapter","") != e.get("chapter",""): errors.append(prefix+"choisissez une zone de déclenchement active du même chapitre.")
	if condition == "target_dead":
		var targets: Array = document.enemy_entities_for_reference(String(p.get("spawn_dead_group","")),String(e.get("chapter","")))
		if targets.is_empty(): errors.append(prefix+"choisissez une cible existante sur la carte.")
		for target: Dictionary in targets:
			if not target.get("enabled",true) or int(target.properties.get("count",0)) <= 0: errors.append(prefix+"la cible doit être active et non vide.")
		if _cycles(document,e,[]): errors.append(prefix+"dépendance circulaire entre les cibles de mort.")
	for role: String in ["phalanx","infantry","archer"]:
		if int(p.get("boss_guard_"+role,0)) < 0 or int(p.get("boss_guard_"+role,0)) > 48: errors.append(prefix+"garde limitée à 48 soldats par type.")
	return errors

static func _cycles(document: RefCounted, e: Dictionary, path: Array) -> bool:
	if e.id in path: return true
	var p: Dictionary = e.properties
	var condition := String(p.get("boss_spawn_condition","")) if p.get("battlefield_boss",false) else String(p.get("spawn_condition",""))
	if condition not in ["target_dead","group_dead"]: return false
	var next := path.duplicate()
	next.append(e.id)
	for target: Dictionary in document.enemy_entities_for_reference(String(p.get("spawn_dead_group","")),String(e.get("chapter",""))):
		if _cycles(document,target,next): return true
	return false
