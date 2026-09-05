extends Node
## Scene-owned encounter lifecycle. Event counters, never per-soldier polling each frame.
const Presentation = preload("res://scripts/enemy_v2/battlefield/boss_presentation.gd")
var world: Node
var zones: Dictionary = {}
var groups: Dictionary = {}
var bosses: Dictionary = {}
var deaths: Dictionary = {}
var entered: Dictionary = {}
var presentation: Node
var tick := 0.0

func configure(value: Node) -> void:
	world = value
	presentation = Presentation.new()
	add_child(presentation)
	for e: Dictionary in world._chapter_entities():
		if not e.get("enabled",true) or not world._inside_portion(e): continue
		if e.type == "battlefield":
			zones[e.id] = {"entity":e,"active":false,"elapsed":0.0,"victory":false,"cleanup_at":-1.0,"baseline":0}
	for e: Dictionary in world._chapter_entities():
		var p: Dictionary = e.get("properties",{})
		if e.type != "enemy_group" or not e.get("enabled",true) or not world._inside_portion(e) or not zones.has(p.get("battlefield_id","")): continue
		var id := String(p.get("group_id",e.id))
		groups[id] = e
		if p.get("battlefield_boss",false):
			bosses[id] = {"entity":e,"spawned":false,"presented":false}
		elif p.get("faction","athenian") == "athenian":
			zones[p.battlefield_id].baseline += int(p.get("count",0))
	world.enemy_died.connect(_on_death)
	world.enemy_spawned.connect(_on_spawn)
	world.player_entered_trigger.connect(func(id: String) -> void: entered[id] = true)

func _on_death(_actor: Node, id: String) -> void:
	deaths[id] = int(deaths.get(id,0))+1

func _on_spawn(actor: Node, id: String) -> void:
	if not groups.has(id): return
	var p: Dictionary = groups[id].properties
	actor.set_meta("boss_presentation_height",float(p.get("size_multiplier",1.0))*2.0)
	if p.has("encounter_power") and actor.get("combat_modifiers") != null:
		actor.combat_modifiers.configure(float(p.encounter_power))
	if bosses.has(id) and not bosses[id].presented:
		bosses[id].presented = true
		if p.get("boss_cinematic",true): presentation.call_deferred("present",actor,String(groups[id].name))

func _process(delta: float) -> void:
	tick += delta
	if tick < 0.2: return
	var step := tick
	tick = 0.0
	for zone_id: String in zones:
		var state: Dictionary = zones[zone_id]
		var e: Dictionary = state.entity
		if not state.active:
			state.active = e.properties.get("activation","start") == "start" or _inside(e)
		if not state.active: continue
		state.elapsed += step
		if state.victory:
			if state.cleanup_at >= 0 and state.elapsed >= state.cleanup_at:
				for id: String in groups:
					var p: Dictionary = groups[id].properties
					if p.get("battlefield_id","") == zone_id and p.get("faction","athenian") == "spartan": world.remove_enemy_group(id)
				state.cleanup_at = -1.0
			continue
		for id: String in bosses:
			var boss: Dictionary = bosses[id]
			if boss.entity.properties.battlefield_id == zone_id and not boss.spawned and _ready_to_spawn(boss.entity,state): _spawn_boss(id)
		if _defeated(zone_id):
			state.victory = true
			presentation.message(String(e.properties.get("victory_message","Victoire ! Le champ de bataille est libéré.")))
			if e.properties.get("victory_remove_allies",true): state.cleanup_at = state.elapsed + maxf(2.0,float(e.properties.get("victory_cleanup_delay",4.0)))

func _inside(e: Dictionary) -> bool:
	if not is_instance_valid(world.player): return false
	var origin := Vector3(e.position[0],e.position[1],e.position[2])
	var rotation: Array = e.get("rotation",[0,0,0])
	var local: Vector3 = Basis(Vector3.UP,deg_to_rad(float(rotation[1]))).inverse()*(world.player.global_position-origin)
	var size: Array = e.properties.get("size",[100,4,100])
	var scale_value: Array = e.get("scale",[1,1,1])
	return absf(local.x)<=float(size[0])*float(scale_value[0])*0.5 and absf(local.z)<=float(size[2])*float(scale_value[2])*0.5

func _ready_to_spawn(e: Dictionary, state: Dictionary) -> bool:
	var p: Dictionary = e.properties
	match String(p.get("boss_spawn_condition","loss_percent")):
		"start": return true
		"timer": return state.elapsed >= maxf(0,float(p.get("spawn_delay",30)))
		"trigger":
			var key := String(p.get("spawn_trigger",""))
			if entered.has(key): return true
			for trigger: Dictionary in world._chapter_entities():
				if trigger.type == "trigger" and trigger.name == key and entered.has(trigger.id): return true
		"target_dead":
			var targets: Array = world.document.enemy_entities_for_reference(String(p.get("spawn_dead_group","")),world.active_chapter_id)
			if targets.is_empty(): return false
			for target: Dictionary in targets:
				if int(deaths.get(String(target.properties.get("group_id",target.id)),0)) < int(target.properties.get("count",1)): return false
			return true
		"loss_percent":
			var fallen := 0
			for id: String in groups:
				var gp: Dictionary = groups[id].properties
				if gp.get("battlefield_id","") == p.battlefield_id and gp.get("faction","athenian") == "athenian" and not gp.get("battlefield_boss",false) and not gp.get("boss_guard",false): fallen += int(deaths.get(id,0))
			return state.baseline > 0 and float(fallen)*100.0 >= float(state.baseline)*float(p.get("boss_loss_percent",25))
	return false

func _spawn_boss(id: String) -> void:
	if bosses[id].spawned: return
	bosses[id].spawned = true
	var e: Dictionary = bosses[id].entity
	world.queue_encounter_group(e)
	var p: Dictionary = e.properties
	var slot := 0
	for role: String in ["phalanx","infantry","archer"]:
		var remaining := clampi(int(p.get("boss_guard_"+role,0)),0,48)
		while remaining > 0:
			var count := mini(remaining,12)
			var guard: Dictionary = e.duplicate(true)
			guard.id = e.id + "_guard_" + str(slot)
			guard.name = String(e.name) + " — garde " + role
			guard.position = [float(e.position[0])+(slot%3-1)*8.0,float(e.position[1]),float(e.position[2])+8.0+float(slot/3)*6.0]
			var gp: Dictionary = guard.properties
			gp.group_id = guard.id
			gp.battlefield_boss = false
			gp.boss_guard = true
			gp.boss_budget_owner = e.id
			gp.guard_of = id
			gp.rank = "normal"
			gp.size_multiplier = 1.0
			gp.archetype = "enemy_v2_hoplite" if role == "phalanx" else "enemy_v2_"+role
			gp.composition = [{"archetype":gp.archetype,"count":count}]
			gp.count = count
			gp.v2_unit_role = role
			gp.v2_troop_mode = "hoplite_phalanx" if role == "phalanx" else role
			gp.formation_columns = 4
			gp.encounter_power = float(p.get("boss_guard_power",1.0))
			groups[guard.id] = guard
			world.queue_encounter_group(guard)
			remaining -= count
			slot += 1

func _defeated(zone_id: String) -> bool:
	var enemies := 0
	for task: Dictionary in world.pending_enemy_spawns:
		if task.entity.properties.get("battlefield_id","") == zone_id: return false
	for id: String in groups:
		var p: Dictionary = groups[id].properties
		if p.get("battlefield_id","") != zone_id or p.get("faction","athenian") != "athenian": continue
		enemies += int(p.get("count",0))
		if bosses.has(id) and not bosses[id].spawned: return false
		# Deaths, not missing actors: deferred waves must not count as defeated.
		if int(deaths.get(id,0)) < int(p.get("count",0)): return false
	return enemies > 0
