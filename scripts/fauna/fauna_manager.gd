extends Node3D
class_name HopliteFaunaManager

const FaunaAgentScript = preload("res://scripts/fauna/fauna_agent.gd")
const GLOBAL_SETTINGS_PATH := "user://hoplite_global_settings_v1.cfg"
const SPAWN_INTERVAL := 0.12
const AUDIT_INTERVAL := 0.50
const MINIMUM_SPAWN_DISTANCE := 14.0

var player: Node3D
var values: Dictionary = HopliteFaunaSettings.defaults()
var agents_by_species: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _spawn_queue: Array[StringName] = []
var _spawn_accumulator := 0.0
var _audit_accumulator := 0.0
var _agent_serial := 0
var _water_blockers: Array[HopliteFaunaWaterBlocker] = []


func configure(owner_player: Node3D) -> void:
	player = owner_player
	name = "RuntimeFauna"
	add_to_group("fauna_manager")
	for definition: Dictionary in HopliteFaunaSettings.SPECIES:
		agents_by_species[StringName(definition["id"])] = []
	var config := ConfigFile.new()
	config.load(GLOBAL_SETTINGS_PATH)
	values = HopliteFaunaSettings.load_from_config(config)
	_rng.seed = int(values[&"seed"])
	_refresh_water_blockers()
	call_deferred("reload_fauna_settings", values)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_spawn_accumulator += delta
	if not _spawn_queue.is_empty() and _spawn_accumulator >= SPAWN_INTERVAL:
		_spawn_accumulator = 0.0
		_spawn_one(_spawn_queue.pop_front())
	_audit_accumulator += delta
	if _audit_accumulator >= AUDIT_INTERVAL:
		_audit_accumulator = 0.0
		_audit_agents()


func reload_fauna_settings(new_values: Dictionary = {}) -> void:
	_refresh_water_blockers()
	var previous_seed := int(values.get(&"seed", 0))
	if new_values.is_empty():
		var config := ConfigFile.new()
		config.load(GLOBAL_SETTINGS_PATH)
		values = HopliteFaunaSettings.load_from_config(config)
	else:
		values = HopliteFaunaSettings.sanitize(new_values)
	var next_seed := int(values[&"seed"])
	if next_seed != previous_seed:
		_rng.seed = next_seed
	for definition: Dictionary in HopliteFaunaSettings.SPECIES:
		var species_id := StringName(definition["id"])
		var behavior_index := int(values[HopliteFaunaSettings.species_key(species_id, "behavior")])
		for raw_agent: Variant in _valid_agents(species_id):
			(raw_agent as HopliteFaunaAgent).set_behavior(behavior_index, float(values[&"logic_hz"]))
	_reconcile_population()


func reshuffle(new_seed: int) -> void:
	values[&"seed"] = maxi(1, new_seed)
	_rng.seed = int(values[&"seed"])
	_clear_all_agents()
	_reconcile_population()


func assign_wander_target(agent: HopliteFaunaAgent, fast: bool = false) -> void:
	if agent == null or not is_instance_valid(agent):
		return
	var definition := agent.definition
	var radius := float(definition.get("wander_radius", 15.0))
	for _attempt: int in range(12):
		var angle := _rng.randf_range(-PI, PI)
		var distance := sqrt(_rng.randf()) * radius
		var desired := agent.home_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		if agent.airborne:
			var altitude_min := float(definition.get("altitude_min", 14.0))
			var altitude_max := float(definition.get("altitude_max", 28.0))
			desired.y = player.global_position.y + _rng.randf_range(altitude_min, altitude_max)
			agent.set_wander_target(desired, fast)
			return
		var projected: Variant = project_ground_position(desired, agent.water_clearance_radius())
		if projected is Vector3:
			agent.set_wander_target(projected as Vector3, fast)
			return
	agent.hold_position(0.8)


func assign_specific_target(agent: HopliteFaunaAgent, desired: Vector3, fast: bool) -> void:
	if agent == null or not is_instance_valid(agent):
		return
	if agent.airborne:
		desired.y = clampf(desired.y, player.global_position.y + 10.0, player.global_position.y + 38.0)
		agent.set_wander_target(desired, fast)
	else:
		var projected: Variant = project_ground_position(desired, agent.water_clearance_radius())
		if projected is Vector3:
			agent.set_wander_target(projected as Vector3, fast)
		else:
			assign_wander_target(agent, false)


func project_ground_position(candidate: Vector3, water_margin: float = 0.4) -> Variant:
	if get_world_3d() == null:
		return null
	var reference_y := player.global_position.y if player != null and is_instance_valid(player) else candidate.y
	var ray_origin_y := maxf(candidate.y, reference_y) + 80.0
	var from := Vector3(candidate.x, ray_origin_y, candidate.z)
	var to := Vector3(candidate.x, ray_origin_y - 240.0, candidate.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var hit_position: Vector3 = result.get("position", candidate)
	hit_position += Vector3.UP * 0.03
	return null if is_water_blocked(hit_position, water_margin) else hit_position


func is_water_blocked(world_point: Vector3, footprint_margin: float = 0.4) -> bool:
	for blocker: HopliteFaunaWaterBlocker in _water_blockers:
		if blocker != null and is_instance_valid(blocker) and blocker.blocks_world_point(world_point, footprint_margin):
			return true
	return false


func get_total_active() -> int:
	var total := 0
	for definition: Dictionary in HopliteFaunaSettings.SPECIES:
		total += _valid_agents(StringName(definition["id"])).size()
	return total


func get_requested_total() -> int:
	var total := 0
	for raw_count: Variant in HopliteFaunaSettings.target_counts(values).values():
		total += int(raw_count)
	return total


func get_active_counts() -> Dictionary:
	var result: Dictionary = {}
	for definition: Dictionary in HopliteFaunaSettings.SPECIES:
		var species_id := StringName(definition["id"])
		result[species_id] = _valid_agents(species_id).size()
	return result


func _reconcile_population() -> void:
	_spawn_queue.clear()
	var targets := HopliteFaunaSettings.target_counts(values)
	for definition: Dictionary in HopliteFaunaSettings.SPECIES:
		var species_id := StringName(definition["id"])
		var agents := _valid_agents(species_id)
		var target := int(targets.get(species_id, 0))
		while agents.size() > target:
			var agent := agents.pop_back() as HopliteFaunaAgent
			if agent != null:
				agent.queue_free()
		agents_by_species[species_id] = agents
		for _index in range(agents.size(), target):
			_spawn_queue.append(species_id)
	set_physics_process(bool(values[&"enabled"]) and (not _spawn_queue.is_empty() or get_total_active() > 0))


func _spawn_one(species_id: StringName) -> void:
	if not bool(values[&"enabled"]):
		return
	var definition := HopliteFaunaSettings.definition(species_id)
	if definition.is_empty():
		return
	var spawn_position := _sample_spawn_position(definition)
	var agent := FaunaAgentScript.new() as HopliteFaunaAgent
	_agent_serial += 1
	agent.name = "%s_%03d" % [String(species_id).capitalize().replace(" ", ""), _agent_serial]
	add_child(agent)
	var behavior_index := int(values[HopliteFaunaSettings.species_key(species_id, "behavior")])
	var seed_value := int(values[&"seed"]) + _agent_serial * 7919 + String(species_id).hash()
	if not agent.configure(definition, behavior_index, player, self, seed_value, spawn_position, float(values[&"logic_hz"])):
		agent.queue_free()
		return
	var agents := _valid_agents(species_id)
	agents.append(agent)
	agents_by_species[species_id] = agents


func _sample_spawn_position(definition: Dictionary) -> Vector3:
	var spawn_radius := float(values[&"spawn_radius"])
	var airborne := bool(definition.get("airborne", false))
	var water_margin := clampf(float(definition.get("target_height", 1.0)) * 0.25, 0.28, 0.70)
	for _attempt: int in range(16):
		var angle := _rng.randf_range(-PI, PI)
		var distance := _rng.randf_range(MINIMUM_SPAWN_DISTANCE, spawn_radius)
		var candidate := player.global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		if airborne:
			candidate.y = player.global_position.y + _rng.randf_range(float(definition.get("altitude_min", 14.0)), float(definition.get("altitude_max", 28.0)))
			return candidate
		var projected: Variant = project_ground_position(candidate, water_margin)
		if projected is Vector3:
			return projected as Vector3
	var fallback: Variant = project_ground_position(player.global_position, water_margin)
	return fallback as Vector3 if fallback is Vector3 else player.global_position


func _audit_agents() -> void:
	_refresh_water_blockers()
	var full_simulation_distance := float(values[&"full_simulation_distance"])
	var simulation_distance := float(values[&"simulation_distance"])
	var far_physics_divisor := int(values[&"far_physics_divisor"])
	var recycle_distance := float(values[&"spawn_radius"]) + 28.0
	for definition: Dictionary in HopliteFaunaSettings.SPECIES:
		var species_id := StringName(definition["id"])
		for raw_agent: Variant in _valid_agents(species_id):
			var agent := raw_agent as HopliteFaunaAgent
			var distance := agent.global_position.distance_to(player.global_position)
			if distance > recycle_distance:
				agent.relocate(_sample_spawn_position(definition))
				distance = agent.global_position.distance_to(player.global_position)
			var active := distance <= simulation_distance
			agent.set_simulation_active(active)
			if active:
				agent.set_physics_divisor(1 if distance <= full_simulation_distance else far_physics_divisor)


func _valid_agents(species_id: StringName) -> Array:
	var valid: Array = []
	for raw_agent: Variant in agents_by_species.get(species_id, []):
		if raw_agent is HopliteFaunaAgent and is_instance_valid(raw_agent):
			valid.append(raw_agent)
	agents_by_species[species_id] = valid
	return valid


func _clear_all_agents() -> void:
	_spawn_queue.clear()
	for definition: Dictionary in HopliteFaunaSettings.SPECIES:
		var species_id := StringName(definition["id"])
		for raw_agent: Variant in _valid_agents(species_id):
			(raw_agent as HopliteFaunaAgent).queue_free()
		agents_by_species[species_id] = []


func _refresh_water_blockers() -> void:
	_water_blockers.clear()
	if get_tree() == null:
		return
	for candidate: Node in get_tree().get_nodes_in_group("fauna_water_blocker"):
		if candidate is HopliteFaunaWaterBlocker:
			_water_blockers.append(candidate as HopliteFaunaWaterBlocker)
