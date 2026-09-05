extends RefCounted
## One instance per army. Owns missions, not individual attacks or transforms.
const Difficulty = preload("res://scripts/enemy_v2/battlefield/army_difficulty.gd")
const Retinue = preload("res://scripts/enemy_v2/battlefield/champion_retinue.gd")
const Situation = preload("res://scripts/enemy_v2/battlefield/army_situation.gd")
var planner := preload("res://scripts/enemy_v2/battlefield/adaptive_army_planner.gd").new()
var snapshot: Dictionary = {}
var engagements := preload("res://scripts/enemy_v2/battlefield/army_engagement_planner.gd").new()
var runtime: Node
var focus: Node3D
var faction: StringName
var battlefield_id: String
var settings: Dictionary
var difficulty: Resource
var groups: Dictionary = {}
var next_orders := 0.0
var last_update := 0.0
var last_opponents: Array[Dictionary] = []
var retinue := Retinue.new()
var player: Node3D
var encounter_active := false
var zone_transform := Transform3D.IDENTITY
var zone_size := Vector3(100,4,100)
func configure(value: Node, reference: Node3D, team: StringName, zone: Dictionary) -> void:
	runtime = value
	focus = reference
	faction = team
	battlefield_id = zone.id
	settings = zone.properties
	difficulty = Difficulty.create(StringName(settings.get("difficulty","normal")))
	var rotation: Array = zone.get("rotation",[0,0,0])
	var pos: Array = zone.position
	zone_transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(rotation[1]))),Vector3(float(pos[0]),float(pos[1]),float(pos[2])))
	var size: Array = settings.get("size",[100,4,100])
	var scale_value: Array = zone.get("scale",[1,1,1])
	zone_size = Vector3(float(size[0])*float(scale_value[0]),float(size[1]),float(size[2])*float(scale_value[2]))
func register(id: StringName, state: Dictionary, properties: Dictionary = {}) -> void:
	groups[id] = {"is_champion":properties.get("battlefield_boss",false),"home":state.anchor,"anchor":state.anchor,"role":state.capabilities.role,"order":groups.size(),"initial_health":_health(state),"mission_until":0.0,"guard_of":StringName(properties.get("guard_of","auto"))}
	if faction == &"athenian": retinue.refresh_bindings(groups,runtime,settings)
	next_orders = 0.0
func refresh_snapshot() -> void:
	snapshot.clear()
	for id: StringName in groups.keys():
		if not runtime.groups.has(id): groups.erase(id); continue
		var state: Dictionary = runtime.groups[id]
		groups[id].anchor = state.anchor
		snapshot[id] = Situation.capture(id,state,runtime.battle_layout.records.get(id,{}),float(groups[id].initial_health))
func update(now: float, objective: Vector3, opponents: Array[Dictionary], active: bool) -> void:
	last_update = now
	last_opponents = opponents
	encounter_active = active
	focus.global_position = objective
	if now < next_orders: return
	next_orders = now + float(difficulty.reaction_seconds)
	refresh_snapshot()
	var tactical := planner.plan(snapshot,opponents,objective,now)
	var eligible: Dictionary = {}
	for id: StringName in groups:
		if groups[id].role != &"giant" and not groups[id].get("is_champion",false) and not runtime.groups[id].has("manual_order"): eligible[id] = groups[id]
	var player_position := player.global_position if is_instance_valid(player) else objective
	# Mobilization is a ceiling, reduced when troops are needed to survive the opposing army.
	var fraction := float(settings.get("player_focus_fraction",0.5))*clampf(planner.strength_ratio-0.7,0.15,1.0)
	engagements.choose_player_groups(eligible,player_position,fraction,float(settings.get("player_focus_radius",22.0)),opponents.is_empty() or settings.get("mode","armies")=="player")
	for id: StringName in groups:
		if not tactical.has(id) or not runtime.battle_layout.records.has(id): continue
		var group: Dictionary = groups[id]
		var state: Dictionary = runtime.groups[id]
		var record: Dictionary = runtime.battle_layout.records[id]
		var order: Dictionary = tactical[id]
		var local_objective: Vector3 = order.objective
		var goal: Vector3 = order.position
		var mission: StringName = order.mission
		var policy := retinue.policy_for(id) if faction == &"athenian" else &"normal"
		# Guards participate in army combat; only nearby player alerts commandeer them.
		var champion_order: bool = policy == &"vengeance" or (policy != &"normal" and ((group.role == &"giant" or group.get("is_champion",false)) or (policy == &"alert" and (group.anchor as Vector3).distance_to(player_position)<14.0)))
		var player_focus: bool = faction == &"athenian" and (engagements.pursuing.has(id) or (champion_order and policy != &"guard"))
		group.focus_player = player_focus
		group.champion_order = champion_order
		group.target_group = order.target_id
		if player_focus:
			local_objective = player_position
			var direction := (player_position-(group.anchor as Vector3)).normalized()
			goal = player_position-direction*(17.0 if group.role == &"archer" else float(record.get("formation_depth",3.0))*0.5+2.0)
			mission = &"player_intercept"
		if champion_order:
			var context := {"player":player_position,"stand_off":float(record.get("formation_depth",3.0))*0.5+2.0,"group_width":record.get("formation_width",6.0)}
			goal = retinue.goal_for(id,group,context,settings)
			mission = policy
		if active and group.role == &"archer" and mission != &"guard":
			goal = engagements.firing_position(id,goal,local_objective,zone_transform.basis.x,runtime)
		var facing := (local_objective-(group.anchor as Vector3)).normalized()
		if facing.length_squared()<0.01: facing = record.forward
		if state.has("manual_order"):
			var manual: Dictionary = state.manual_order
			goal = manual.position
			facing = manual.facing
			mission = &"escort_hold" if manual.mode == &"hold" else &"escort_attack"
			if manual.mode == &"attack" and (group.anchor as Vector3).distance_to(goal)<3.0:
				state.erase("manual_order")
		if not active: goal = group.home
		var local := zone_transform.affine_inverse()*goal
		local.x = clampf(local.x,-zone_size.x*0.5+3,zone_size.x*0.5-3)
		local.z = clampf(local.z,-zone_size.z*0.5+3,zone_size.z*0.5-3)
		if policy != &"vengeance" and not state.has("manual_order"): goal = zone_transform*local
		goal.y = (group.anchor as Vector3).y
		record.command_assignment = {"position":goal,"facing":facing,"role":group.role,"mission":mission if active else &"inactive","engage":active and not (champion_order and policy == &"guard"),"ring":0,"slot":id,"angle":0.0,"radius":0.0,"disorganized":not active}
		for member: Node in state.members:
			if is_instance_valid(member): member.set_meta("v2_player_pressure",difficulty.player_pressure)
func _health(state: Dictionary) -> float:
	var total := 0.0
	for actor: Node in state.members:
		if is_instance_valid(actor) and not actor.dead: total += actor.health
	return total

func observe_player(value: Node3D) -> void:
	player = value
	if faction == &"athenian" and retinue.observe(player,groups,runtime,settings,encounter_active):
		next_orders = 0.0
		# Recalculate missions immediately; weapon commitment is still respected.
		update(last_update,player.global_position,last_opponents,encounter_active)
