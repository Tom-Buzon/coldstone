extends Node
## Scene-scoped shared targeting and encounter registry. No per-soldier world scans.
const TroopRuntime = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")
const Commander = preload("res://scripts/enemy_v2/battlefield/army_commander.gd")
const Factions = preload("res://scripts/enemy_v2/enemy_v2_factions.gd")
var escort: Node
var world: Node
var armies: Dictionary = {}
var zones: Dictionary = {}
var buckets: Dictionary = {}
var target_loads: Dictionary = {}
var elapsed := 0.0
var clock := 0.0
var local_groups: Dictionary = {}
var target_actors: Array[Node3D] = []
var target_cursor := 0
var last_update_usec := 0
var max_update_usec := 0
func configure(value: Node) -> void:
	world = value
	set_process(false)
	for entity: Dictionary in world.document.data.entities:
		if entity.type == "battlefield" and entity.get("enabled",true): zones[entity.id] = entity.duplicate(true)
func register_group(id: StringName, members: Array[Node], properties: Dictionary, mode: StringName) -> void:
	set_process(true)
	properties = properties.duplicate(true)
	properties["v2_persistent_fronts"] = true
	var zone_id := String(properties.get("battlefield_id",""))
	var faction := StringName(properties.get("faction","athenian"))
	if not zones.has(zone_id):
		world.enemy_v2_troop_runtime.register_group(id,members,world.player,properties,mode)
		var local_ids: Array = world.enemy_v2_troop_runtime.group_children.get(id,[id])
		for local_id: StringName in local_ids: local_groups[local_id] = properties.duplicate()
		for actor: Node in members:
			actor.set_meta("v2_encounter",self)
			actor.set_combat_target(null)
		return
	var key := zone_id + ":" + String(faction)
	if not armies.has(key):
		var runtime := TroopRuntime.new()
		runtime.name = "Army_" + key
		runtime.battle_layout = world.enemy_v2_troop_runtime.battle_layout
		runtime.threat_budget = world.enemy_v2_troop_runtime.threat_budget
		runtime.terrain_height_sampler = world._sample_v2_terrain_height
		add_child(runtime)
		var focus := Node3D.new()
		add_child(focus)
		focus.global_position = world.player.global_position
		var commander := Commander.new()
		commander.configure(runtime,focus,faction,zones[zone_id])
		armies[key] = commander
	var army = armies[key]
	army.runtime.register_group(id,members,army.focus,properties,mode)
	var ids: Array = army.runtime.group_children.get(id,[id])
	for child: StringName in ids:
		if army.runtime.battle_layout.records.has(child): army.runtime.battle_layout.records[child]["faction"] = faction
		if army.runtime.groups.has(child): army.register(child,army.runtime.groups[child],properties)
	for actor: Node in members:
		actor.set_meta("v2_encounter",self)
		actor.set_combat_target(null)
	if bool(properties.get("player_escort",false)) and faction == &"spartan":
		if escort == null:
			escort = preload("res://scripts/enemy_v2/battlefield/player_escort.gd").new()
			add_child(escort)
			escort.configure(self,army.runtime)
		escort.register_group(id,members,properties,mode,zones[zone_id].properties)

func _process(delta: float) -> void:
	if not is_instance_valid(world.player): return
	var started := Time.get_ticks_usec()
	for army: RefCounted in armies.values(): army.observe_player(world.player)
	clock += delta
	elapsed += delta
	if elapsed >= 0.2:
		elapsed = 0.0
		_refresh_snapshot()
	# Spread targeting over frames. Keep the cursor across snapshot refreshes so
	# large armies cannot starve soldiers at the end of the registry.
	var count := 0
	while not target_actors.is_empty() and count < mini(24,target_actors.size()) and Time.get_ticks_usec()-started < 2000:
		target_cursor %= target_actors.size()
		# An actor can be freed between the 0.2 s snapshot refreshes (notably when
		# the last battlefield group is removed). Keep the array value as Variant
		# until it has been validated: passing a freed Object to the typed
		# _update_target() parameter fails before that function's guard can run.
		var candidate: Variant = target_actors[target_cursor]
		if typeof(candidate) != TYPE_OBJECT or not is_instance_valid(candidate) or not candidate is Node3D:
			target_actors.remove_at(target_cursor)
			if target_actors.is_empty():
				set_process(false)
				break
			continue
		_update_target(candidate as Node3D)
		target_cursor += 1
		count += 1
	last_update_usec = Time.get_ticks_usec()-started
	max_update_usec = maxi(max_update_usec,last_update_usec)
func _refresh_snapshot() -> void:
	buckets.clear()
	target_loads.clear()
	var actors: Array[Node3D] = []
	for list: Array in world.enemies_by_group.values():
		for actor: Variant in list:
			if not is_instance_valid(actor) or not actor is HopliteEnemyActorV2 or actor.dead: continue
			actors.append(actor)
			if is_instance_valid(actor.combat_target):
				var target_id: int = actor.combat_target.get_instance_id()
				target_loads[target_id] = int(target_loads.get(target_id,0))+1
			var cell := _cell(actor.global_position)
			if not buckets.has(cell): buckets[cell] = []
			buckets[cell].append(actor)
	for army: RefCounted in armies.values(): army.refresh_snapshot()
	for army: RefCounted in armies.values():
		var opponents: Array[Dictionary] = []
		for other: RefCounted in armies.values():
			if other.battlefield_id != army.battlefield_id or other.faction == army.faction: continue
			for entry: Dictionary in other.snapshot.values(): opponents.append(entry)
		var objective: Vector3 = world.player.global_position
		if army.settings.get("mode","armies") == "armies" and not opponents.is_empty(): objective = opponents[0].anchor
		var activation: String = army.settings.get("activation","start")
		var local: Vector3 = army.zone_transform.affine_inverse() * world.player.global_position
		var inside: bool = absf(local.x) <= army.zone_size.x*0.5 and absf(local.z) <= army.zone_size.z*0.5
		if inside: army.settings["activated"] = true
		var active: bool = activation == "start" or army.settings.get("activated",false)
		# clear() preserves Array[Dictionary], unlike a bare [] in a Variant call.
		if army.settings.get("mode","armies") != "armies" and army.faction == &"athenian": opponents.clear()
		army.player = world.player
		army.update(clock,objective,opponents,active)
	target_actors = actors.filter(func(actor: Node3D) -> bool: return actor.has_meta("v2_encounter"))
	if target_actors.is_empty(): set_process(false)
	_update_local_groups()
func _update_target(actor: Node3D) -> void:
	if not is_instance_valid(actor) or actor.dead or not actor.has_meta("v2_encounter"): return
	var selected: Node3D
	var best := INF
	var commander = _commander_for(actor)
	if commander != null and commander.settings.get("activation","start") != "start" and not commander.settings.get("activated",false):
		_assign_target(actor,null)
		return
	if commander != null and actor.faction == &"athenian":
		var policy: StringName = commander.retinue.policy_for(actor.phalanx_group_id)
		if policy != &"normal" and bool(commander.groups.get(actor.phalanx_group_id,{}).get("champion_order",false)):
			var obstruction: Node3D
			if policy != &"guard" and actor.definition.unit_role != &"giant" and actor.global_position.distance_to(world.player.global_position)>5.0:
				var distance := 6.5*6.5
				for candidate: Node3D in nearby(actor.global_position,6.5,24,actor):
					var separation := actor.global_position.distance_squared_to(candidate.global_position)
					if separation < distance: distance = separation; obstruction = candidate
			_assign_target(actor,null if policy == &"guard" else (obstruction if obstruction != null else world.player))
			return
		if bool(commander.groups.get(actor.phalanx_group_id,{}).get("focus_player",false)) or actor.global_position.distance_to(world.player.global_position)<4.0:
			# A nearby enemy line must be fought through before chasing the player behind it.
			var contact: Node3D
			var nearest := 5.5 * 5.5
			if actor.global_position.distance_to(world.player.global_position)>5.0:
				for candidate: Node3D in nearby(actor.global_position,5.5,24,actor):
					var distance := actor.global_position.distance_squared_to(candidate.global_position)
					if distance < nearest: nearest = distance; contact = candidate
			_assign_target(actor,contact if contact != null else world.player)
			return
	if commander != null:
		var state: Dictionary = commander.runtime.groups.get(actor.phalanx_group_id,{})
		if state.has("manual_order"):
			var manual: Dictionary = state.manual_order
			var reach := 4.0 if manual.mode == &"hold" else 6.0
			var nearby_target: Node3D
			var distance := INF
			for candidate: Node3D in nearby(actor.global_position,reach,16,actor):
				if manual.mode == &"hold" and candidate.global_position.distance_to(actor.phalanx_target_position)>4.0: continue
				var d := actor.global_position.distance_squared_to(candidate.global_position)
				if d<distance: distance=d; nearby_target=candidate
			_assign_target(actor,nearby_target)
			return
	var versus_player: bool = commander != null and commander.settings.get("mode","armies") == "player"
	# A committed attack may retain its target until after that opponent's corpse
	# has been freed. Validate the property before recovering its Node3D type.
	var current: Variant = actor.combat_target
	if is_instance_valid(current) and current is HopliteEnemyActorV2 and not current.dead and actor.definition.unit_role != &"archer" and actor.global_position.distance_squared_to(current.global_position)<16.0:
		return # A live close duel doesn't require a new wide-area search.
	var candidates: Array[Node3D] = []
	if actor.definition.unit_role != &"archer": candidates = nearby(actor.global_position,7.0,24,actor)
	if candidates.is_empty(): candidates = nearby(actor.global_position,34.0,48,actor)
	candidates.append(world.player)
	for candidate: Node3D in candidates:
		if not is_instance_valid(candidate) or not Factions.hostile(actor,candidate): continue
		if versus_player and candidate != world.player: continue
		var distance := actor.global_position.distance_squared_to(candidate.global_position)
		if candidate == world.player and not versus_player:
			distance *= 4.0
			if commander != null and not bool(commander.groups.get(actor.phalanx_group_id,{}).get("focus_player",false)) and not candidates.is_empty(): distance += 900.0
		if actor.definition.unit_role == &"archer" and distance<81.0: distance += 500.0
		if candidate != world.player:
			distance += float(target_loads.get(candidate.get_instance_id(),0))*12.0
			if commander != null and candidate.phalanx_group_id == commander.groups.get(actor.phalanx_group_id,{}).get("target_group",&""): distance *= 0.65
		if candidate == actor.combat_target: distance *= 0.7
		if distance < best:
			best = distance
			selected = candidate
	if best > 40.0*40.0: selected = null
	_assign_target(actor,selected)

func _assign_target(actor: Node3D, target: Node3D) -> void:
	var old: Variant = actor.combat_target
	if old == target: return
	actor.set_combat_target(target)
	var actual: Variant = actor.combat_target
	if actual == old: return # An attack already committed keeps its target.
	if is_instance_valid(old):
		var id: int = old.get_instance_id()
		target_loads[id] = maxi(0,int(target_loads.get(id,0))-1)
	if is_instance_valid(actual):
		var id: int = actual.get_instance_id()
		target_loads[id] = int(target_loads.get(id,0))+1

func _commander_for(actor: Node) -> RefCounted:
	return armies.get(String(actor.get_meta("battlefield_id","")) + ":" + String(actor.faction))
func _update_local_groups() -> void:
	var runtime: Node = world.enemy_v2_troop_runtime
	for id: StringName in local_groups.keys():
		if not runtime.groups.has(id):
			local_groups.erase(id)
			continue
		var state: Dictionary = runtime.groups[id]
		var record: Dictionary = runtime.battle_layout.records.get(id,{})
		if record.is_empty(): continue
		var home: Vector3 = record.home_anchor
		var order: String = local_groups[id].get("v2_local_order","guard")
		var goal := home
		if order == "patrol": goal += Vector3(sin(clock*0.18)*6.0,0,cos(clock*0.18)*6.0)
		elif order == "escort": goal = world.player.global_position + Vector3(5,0,5)
		elif order == "pursue" and not state.members.is_empty():
			var first_member: Variant = state.members[0]
			if typeof(first_member) == TYPE_OBJECT and is_instance_valid(first_member):
				var target: Variant = first_member.combat_target
				if is_instance_valid(target): goal = home + (target.global_position-home).limit_length(18.0)
		record.command_assignment = {"position":goal,"facing":record.forward,"role":state.capabilities.role,"mission":StringName(order),"engage":true,"ring":0,"slot":id,"angle":0.0,"radius":0.0,"disorganized":false}
func nearby(position: Vector3, radius: float, limit: int = 48, hostile_to: Node = null) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var center := _cell(position)
	var reach := ceili(radius/12.0)
	# Visit the nearest cells first to avoid directional selection bias.
	for ring in range(reach+1):
		for x in range(-ring,ring+1):
			for z in range(-ring,ring+1):
				if maxi(absi(x),absi(z)) != ring: continue
				for raw_actor: Variant in buckets.get(center+Vector2i(x,z),[]):
					# Buckets share the snapshot lifetime with target_actors and can retain
					# a freed corpse until the next refresh.
					if typeof(raw_actor) != TYPE_OBJECT or not is_instance_valid(raw_actor) or not raw_actor is Node3D:
						continue
					var actor := raw_actor as Node3D
					if not actor.dead and (hostile_to == null or Factions.hostile(hostile_to,actor)) and actor.global_position.distance_squared_to(position) <= radius*radius:
						result.append(actor)
						if result.size() >= limit: return result
	return result
func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x/12.0),floori(position.z/12.0))

func remove_group(id: StringName) -> void:
	local_groups.erase(id)
	for army: RefCounted in armies.values():
		army.runtime.remove_group(id)
		army.groups.erase(id)
