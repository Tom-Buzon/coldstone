extends Node
class_name HopliteV2TroopRuntime

const PhalanxProfile = preload("res://scripts/enemy_v2/hoplite_v2_phalanx_profile.gd")
const BattleLayoutRuntime = preload("res://scripts/enemy_v2/enemy_v2_battle_layout_runtime.gd")
const Capabilities = preload("res://scripts/enemy_v2/enemy_v2_unit_capabilities.gd")
const ThreatBudget = preload("res://scripts/enemy_v2/enemy_v2_threat_budget.gd")
const ImpostorBatch = preload("res://scripts/enemy_v2/hoplite_v2_impostor_batch.gd")

enum PhalanxState { ASSEMBLE, ADVANCE, ENGAGE, RECOVER, HOLD }
enum BreachState { CLOSED, CANDIDATE, CHANNEL, FLANKED, CLOSING }

const GROUP_ENGAGEMENT_DISTANCE := 5.25
const BREACH_CONFIRM_MSEC := 160
const BREACH_CLOSE_MSEC := 900
const BREACH_ENTER_DEPTH := 0.55
const BREACH_EXIT_HYSTERESIS := 0.22
const BREACH_FLANK_DEPTH := 0.70
const BREACH_CHANNEL_CLEARANCE := 1.85
const BREACH_REACTION_COLUMN_RADIUS := 2
const BREACH_MAX_VERTICAL_OFFSET := 2.20

var terrain_height_sampler: Callable
var threat_budget: RefCounted = ThreatBudget.new()
var group_children: Dictionary = {}
var groups: Dictionary = {}
var group_ids: Array[StringName] = []
var total_decision_ticks: int = 0
var battle_layout: EnemyV2BattleLayoutRuntime = BattleLayoutRuntime.new()
var impostor_batch: HopliteV2ImpostorBatch
var debug_overlay_enabled: bool = false
var debug_overlay: CanvasLayer
var debug_label: Label
var debug_elapsed: float = 0.0


func _ready() -> void:
	process_priority = 20
	battle_layout.front_director.set("fire_lane_validator", is_fire_lane_clear)
	impostor_batch = ImpostorBatch.new() as HopliteV2ImpostorBatch
	impostor_batch.name = "EnemyV2FarImpostorBatch"
	add_child(impostor_batch)
	set_process(not groups.is_empty())


func register_phalanx(group_id: StringName, members: Array[Node], target: Node3D, properties: Dictionary) -> bool:
	return register_group(group_id, members, target, properties, &"hoplite_phalanx")


func register_group(group_id: StringName, members: Array[Node], target: Node3D, properties: Dictionary, mode: StringName = &"hoplite_phalanx") -> bool:
	if group_id.is_empty() or members.is_empty():
		return false
	remove_group(group_id)
	# Forge compositions may contain several families. Each family owns its
	# execution and pressure contract, even when authored as one editor group.
	if bool(properties.get("v2_persistent_fronts", false)):
		var families: Dictionary = {}
		for member: Node in members:
			if member is HopliteEnemyActorV2 and member.definition != null:
				var family: StringName = member.definition.unit_role
				if not families.has(family): families[family] = []
				families[family].append(member)
		if families.size() == 1:
			var only_role := StringName(families.keys()[0])
			if only_role != &"phalanx":
				properties = properties.duplicate()
				properties["v2_unit_role"] = only_role
				mode = only_role
		if families.size() > 1:
			var children: Array[StringName] = []
			for family: StringName in families:
				var child_id := StringName("%s/%s" % [group_id, family])
				var child_properties := properties.duplicate()
				child_properties["v2_unit_role"] = family
				var child_mode := &"hoplite_phalanx" if family == &"phalanx" else family
				var child_members: Array[Node] = []
				child_members.assign(families[family])
				if register_group(child_id, child_members, target, child_properties, child_mode):
					children.append(child_id)
			group_children[group_id] = children
			return not children.is_empty()
	var profile := PhalanxProfile.from_properties(properties) as HopliteV2PhalanxProfile
	var capabilities := Capabilities.from_properties(properties, mode)
	var persistent := bool(properties.get("v2_persistent_fronts", false))
	if persistent:
		profile.advance_speed = capabilities.move_speed
		if capabilities.role != &"phalanx":
			profile.minimum_cohesion_ratio = 0.3
			profile.cohesion_tolerance = 1.8
			profile.max_concurrent_attacks = 2 if capabilities.role == &"archer" else (1 if capabilities.role == &"giant" else 3)
	var valid_members: Array[Node3D] = []
	var centroid := Vector3.ZERO
	for member: Node in members:
		if member is Node3D and bool(member.get_meta("forge_enemy_v2", false)) and member.has_method("bind_phalanx_runtime"):
			var actor := member as Node3D
			valid_members.append(actor)
			centroid += actor.global_position
	if valid_members.is_empty():
		return false
	if bool(properties.get("v2_command_lab", false)):
		set_debug_overlay_enabled(true)
	centroid /= float(valid_members.size())
	var initial_forward := Vector3.FORWARD
	if target != null and is_instance_valid(target):
		initial_forward = _planar_direction(centroid, target.global_position, Vector3.FORWARD)
	elif valid_members[0] != null:
		initial_forward = valid_members[0].global_basis.z.normalized()
	if persistent:
		var authored_forward: Variant = properties.get("v2_front_forward")
		if authored_forward is Array and authored_forward.size() >= 3:
			var direction := Vector3(float(authored_forward[0]), 0.0, float(authored_forward[2]))
			if direction.length_squared() > 0.001: initial_forward = direction.normalized()
	var phase := float(abs(hash(group_id)) % 997) / 997.0
	var state := {
		"persistent_fronts": persistent,
		"capabilities": capabilities,
		"original_count": valid_members.size(),
		"last_slot_count": valid_members.size(),
		"slots_rebuild_at": 0,
		"members": valid_members,
		"target": target,
		"profile": profile,
		"mode": mode,
		"slots": {},
		"front_rank": [],
		"active_columns": profile.columns,
		"anchor": centroid,
		"forward": initial_forward,
		"state": PhalanxState.ASSEMBLE,
		"elapsed": phase / profile.near_decision_hz,
		"attack_cursor": 0,
		"attack_leases": {},
		"decision_ticks": 0,
		"cohesion": 0.0,
		"battle_role": &"unassigned",
		"battle_ring": -1,
		"movement_phase": &"hold",
		"group_engaged": false,
		"intrusion": false,
		"breach_state": BreachState.CLOSED,
		"breach_candidate_since_msec": 0,
		"breach_close_at_msec": 0,
		"breach_lateral": 0.0,
		"breach_column": -1,
	}
	groups[group_id] = state
	_rebuild_slots(group_id, state)
	battle_layout.register_group(group_id, target, centroid, properties, mode, valid_members.size())
	group_ids.append(group_id)
	set_process(true)
	return true


func remove_group(group_id: StringName) -> void:
	if group_children.has(group_id):
		for child_id: StringName in group_children[group_id]:
			remove_group(child_id)
		group_children.erase(group_id)
	if not groups.has(group_id):
		return
	var state := groups[group_id] as Dictionary
	for member: Node3D in state.get("members", []):
		if member != null and is_instance_valid(member) and member.has_method("unbind_phalanx_runtime"):
			threat_budget.call("release_if_idle", member.get_instance_id())
			member.call("unbind_phalanx_runtime", self)
	battle_layout.remove_group(group_id)
	groups.erase(group_id)
	group_ids.erase(group_id)
	set_process(not groups.is_empty())


func unregister_member(group_id: StringName, member: Node) -> void:
	if not groups.has(group_id) or member == null:
		return
	var state := groups[group_id] as Dictionary
	var members := state.get("members", []) as Array
	var member_id := member.get_instance_id()
	threat_budget.call("release_if_idle", member_id)
	if member.has_method("unbind_phalanx_runtime"):
		member.call("unbind_phalanx_runtime", self)
	members.erase(member)
	(state.get("attack_leases", {}) as Dictionary).erase(member_id)
	if members.is_empty():
		remove_group(group_id)
	else:
		_rebuild_slots(group_id, state)
		battle_layout.update_group(group_id, state["anchor"] as Vector3, members.size())


func _process(delta: float) -> void:
	threat_budget.call("prune")
	for index in range(group_ids.size() - 1, -1, -1):
		var group_id := group_ids[index]
		if not groups.has(group_id):
			continue
		var state := groups[group_id] as Dictionary
		_tick_mass_members(state, delta)
		var profile := state["profile"] as HopliteV2PhalanxProfile
		var target := state.get("target") as Node3D
		var distance := INF
		if target != null and is_instance_valid(target):
			distance = (target.global_position - (state["anchor"] as Vector3)).length()
		var hz := profile.far_decision_hz if distance >= profile.far_decision_distance else profile.near_decision_hz
		var interval := 1.0 / maxf(0.5, hz)
		state["elapsed"] = float(state["elapsed"]) + delta
		if float(state["elapsed"]) < interval:
			continue
		var elapsed := minf(float(state["elapsed"]), interval * 3.0)
		state["elapsed"] = fmod(float(state["elapsed"]), interval)
		_tick_group(group_id, state, elapsed)
	_tick_debug_overlay(delta)


func set_debug_overlay_enabled(enabled: bool) -> void:
	debug_overlay_enabled = enabled
	if enabled and debug_overlay == null:
		debug_overlay = CanvasLayer.new()
		debug_overlay.name = "EnemyV2CommandDebugOverlay"
		debug_overlay.layer = 80
		add_child(debug_overlay)
		var panel := PanelContainer.new()
		panel.position = Vector2(18.0, 122.0)
		panel.custom_minimum_size = Vector2(355.0, 132.0)
		debug_overlay.add_child(panel)
		debug_label = Label.new()
		debug_label.add_theme_font_size_override("font_size", 14)
		debug_label.text = "ENEMY V2 — initialisation"
		panel.add_child(debug_label)
	if debug_overlay != null:
		debug_overlay.visible = enabled


func debug_snapshot() -> Dictionary:
	var roles := {&"frontline": 0, &"support": 0, &"reserve": 0, &"approach": 0, &"skirmish": 0}
	var lod_counts: Array[int] = [0, 0, 0, 0]
	var soldier_count := 0
	var breach_count := 0
	var attacker_count := 0
	var wrong_way_attack_count := 0
	for raw_group_id: Variant in group_ids:
		if not groups.has(raw_group_id):
			continue
		var state := groups[raw_group_id] as Dictionary
		var role := StringName(state.get("battle_role", &"unassigned"))
		roles[role] = int(roles.get(role, 0)) + 1
		if int(state.get("breach_state", BreachState.CLOSED)) in [BreachState.CHANNEL, BreachState.FLANKED]:
			breach_count += 1
		for member: Node3D in state.get("members", []):
			if member == null or not is_instance_valid(member):
				continue
			soldier_count += 1
			var lod_level := clampi(int(member.get("simulation_lod_level")), 0, 3)
			lod_counts[lod_level] += 1
			var combat_value: Variant = member.get("combat")
			if combat_value is Node and combat_value.has_method("is_attack_committed") and bool(combat_value.call("is_attack_committed")):
				attacker_count += 1
			if combat_value is HopliteV2CombatComponent and (combat_value as HopliteV2CombatComponent).state == HopliteV2CombatComponent.State.ATTACK and member.definition.unit_role == &"phalanx":
				if not combat_value.has_method("is_attack_committed"):
					attacker_count += 1
				var target := state.get("target") as Node3D
				if target != null and is_instance_valid(target):
					var direction := target.global_position - member.global_position
					direction.y = 0.0
					if direction.length_squared() > 0.0001 and member.global_basis.z.normalized().dot(direction.normalized()) < HopliteV2CombatComponent.ATTACK_FACING_DOT - 0.05:
						wrong_way_attack_count += 1
	return {
		"groups": groups.size(),
		"soldiers": soldier_count,
		"roles": roles,
		"lod_counts": lod_counts,
		"impostors": impostor_batch.active_count() if impostor_batch != null else 0,
		"corridors": battle_layout.active_corridor_count(),
		"anchor_conflicts": battle_layout.active_anchor_conflict_count(),
		"breaches": breach_count,
		"attackers": attacker_count,
		"wrong_way_attacks": wrong_way_attack_count,
		"decision_ticks": total_decision_ticks,
		"threat_cost": threat_budget.call("active_cost"),
		"fronts": battle_layout.front_director.get("fronts").size(),
	}


func _tick_debug_overlay(delta: float) -> void:
	if not debug_overlay_enabled or debug_label == null:
		return
	debug_elapsed += delta
	if debug_elapsed < 0.25:
		return
	debug_elapsed = fmod(debug_elapsed, 0.25)
	var snapshot := debug_snapshot()
	var roles := snapshot["roles"] as Dictionary
	var lod_counts := snapshot["lod_counts"] as Array
	debug_label.text = (
		"ENEMY V2 — COMMANDEMENT SPATIAL\n"
		+ "Groupes %d  Soldats %d  Corridors %d  Breches %d\n" % [snapshot["groups"], snapshot["soldiers"], snapshot["corridors"], snapshot["breaches"]]
		+ "Conflits ancres %d  Attaquants %d  Attaques inversees %d\n" % [snapshot["anchor_conflicts"], snapshot["attackers"], snapshot["wrong_way_attacks"]]
		+ "Contact %d  Soutien %d  Reserve %d  Approche %d  Escarmouche %d\n" % [roles.get(&"frontline", 0), roles.get(&"support", 0), roles.get(&"reserve", 0), roles.get(&"approach", 0), roles.get(&"skirmish", 0)]
		+ "Tireurs %d  Geants %d\n" % [roles.get(&"ranged", 0), roles.get(&"giant", 0)]
		+ "Fronts %d  Menace %d/6\n" % [snapshot["fronts"], snapshot["threat_cost"]]
		+ "LOD0 %d  LOD1 %d  LOD2 %d  LOD3 %d  Imposteurs %d" % [lod_counts[0], lod_counts[1], lod_counts[2], lod_counts[3], snapshot["impostors"]]
	)


func _tick_group(group_id: StringName, state: Dictionary, delta: float) -> void:
	_prune_members(group_id, state)
	if not groups.has(group_id):
		return
	if int(state.get("slots_rebuild_at", 0)) > 0 and Time.get_ticks_msec() >= int(state["slots_rebuild_at"]):
		state["slots_rebuild_at"] = 0
		_rebuild_slots(group_id, state)
	var persistent := bool(state.get("persistent_fronts", false))
	var capabilities: EnemyV2UnitCapabilities = state.get("capabilities")
	var members := state["members"] as Array
	var target := state.get("target") as Node3D
	var profile := state["profile"] as HopliteV2PhalanxProfile
	var anchor := state["anchor"] as Vector3
	var forward := state["forward"] as Vector3
	var previous_forward := forward
	battle_layout.update_group(
		group_id,
		anchor,
		members.size(),
		float(state.get("cohesion", 0.0)),
		bool(state.get("group_engaged", false)),
		bool(state.get("intrusion", false)),
		forward
	)
	var strategic := battle_layout.assignment(group_id)
	if not strategic.is_empty():
		forward = strategic.get("facing", forward) as Vector3
	elif target != null and is_instance_valid(target):
		forward = _planar_direction(anchor, target.global_position, forward)
	if persistent:
		var turn := previous_forward.signed_angle_to(forward, Vector3.UP)
		forward = previous_forward.rotated(Vector3.UP, clampf(turn, -capabilities.turn_speed * delta, capabilities.turn_speed * delta)).normalized()
		forward = battle_layout.constrain_front_rotation(group_id, previous_forward, forward)
	_preserve_world_slots_for_about_face(state, previous_forward, forward)
	state["forward"] = forward
	var right := Vector3.UP.cross(forward).normalized()
	var cohesion_count := 0
	var minimum_member_distance := INF
	var any_member_engaged := false
	var engaged_count := 0
	var close_combat_candidates: Array[Dictionary] = []
	for member: Node3D in members:
		var local_slot := (state["slots"] as Dictionary).get(member.get_instance_id(), Vector3.ZERO) as Vector3
		var slot_position := anchor + right * local_slot.x + forward * local_slot.z
		if _planar_distance(member.global_position, slot_position) <= profile.cohesion_tolerance:
			cohesion_count += 1
		if target != null and is_instance_valid(target):
			var member_distance := _planar_distance(member.global_position, target.global_position)
			minimum_member_distance = minf(minimum_member_distance, member_distance)
			if member_distance <= GROUP_ENGAGEMENT_DISTANCE:
				close_combat_candidates.append({"id": member.get_instance_id(), "distance": member_distance})
		if member.has_method("is_phalanx_combat_engaged") and bool(member.call("is_phalanx_combat_engaged")):
			any_member_engaged = true
			engaged_count += 1
	var cohesion := float(cohesion_count) / maxf(1.0, float(members.size()))
	close_combat_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var close_combat_members: Array[int] = []
	for candidate: Dictionary in close_combat_candidates:
		close_combat_members.append(int(candidate["id"]))
	state["cohesion"] = cohesion
	var now_msec := Time.get_ticks_msec()
	var local_reaction := _update_breach_state(state, target, anchor, forward, right, now_msec) if not persistent or capabilities.role == &"phalanx" else false
	var intrusion := int(state.get("breach_state", BreachState.CLOSED)) in [BreachState.CHANNEL, BreachState.FLANKED]
	var group_engaged := any_member_engaged or minimum_member_distance <= GROUP_ENGAGEMENT_DISTANCE
	state["intrusion"] = intrusion
	state["group_engaged"] = group_engaged
	var anchor_goal := anchor
	if not strategic.is_empty():
		anchor_goal = strategic.get("anchor_goal", anchor) as Vector3
		anchor_goal.y = anchor.y
		state["battle_role"] = strategic.get("role", &"unassigned")
		state["battle_ring"] = int(strategic.get("ring", -1))
		state["movement_phase"] = strategic.get("movement_phase", &"hold")
	elif target != null and is_instance_valid(target):
		anchor_goal = target.global_position - forward * profile.desired_target_distance
		anchor_goal.y = anchor.y
	var anchor_error := _planar_distance(anchor, anchor_goal)
	var next_state := int(state["state"])
	var stop_for_combat := local_reaction or group_engaged
	if persistent:
		stop_for_combat = local_reaction or bool(strategic.get("disorganized", false)) or engaged_count >= maxi(1, ceili(float(members.size()) * 0.4))
	if stop_for_combat:
		next_state = PhalanxState.ENGAGE
	elif cohesion < profile.minimum_cohesion_ratio:
		next_state = PhalanxState.RECOVER if int(state["decision_ticks"]) > 6 else PhalanxState.ASSEMBLE
	elif anchor_error > profile.target_distance_hysteresis:
		next_state = PhalanxState.ADVANCE
	elif bool(strategic.get("engage", true)):
		next_state = PhalanxState.ENGAGE
	else:
		next_state = PhalanxState.HOLD
	state["state"] = next_state
	if next_state == PhalanxState.ADVANCE and not local_reaction and target != null and is_instance_valid(target):
		var anchor_direction := _planar_direction(anchor, anchor_goal, forward)
		var movement_scale := 1.0
		if persistent:
			movement_scale = clampf(cohesion, 0.3, 1.0) * clampf(0.4 + maxf(0.0, forward.dot(anchor_direction)), 0.4, 1.0)
		var advance := minf(profile.advance_speed * delta * movement_scale, anchor_error)
		var proposed_anchor := anchor + anchor_direction * advance
		anchor = battle_layout.constrain_anchor_step(group_id, anchor, proposed_anchor)
	# Severe pre-existing overlap is repaired even when local combat temporarily
	# freezes the strategic order. This is a tiny group-level correction, not
	# per-soldier avoidance, and therefore remains bounded for large armies.
	anchor = battle_layout.resolve_anchor_overlap(group_id, anchor, profile.advance_speed * delta * 0.65)
	if persistent and terrain_height_sampler.is_valid():
		anchor.y = float(terrain_height_sampler.call(anchor))
	state["anchor"] = anchor
	# Publish the final corrected anchor, not the position from the beginning of
	# this decision tick. Later formations therefore reserve against the actual
	# result and cannot enter a slot that has just been occupied.
	battle_layout.update_group(group_id, anchor, members.size(), cohesion, group_engaged, intrusion, forward)
	var attack_engaging := next_state == PhalanxState.ENGAGE
	if persistent:
		attack_engaging = (group_engaged or capabilities.role == &"archer" or capabilities.role == &"giant") and not bool(strategic.get("disorganized", false))
		if capabilities.role in [&"archer", &"giant"]:
			close_combat_members.clear()
			for member: Node3D in members:
				close_combat_members.append(member.get_instance_id())
	_update_attack_leases(state, delta, attack_engaging, close_combat_members)
	right = Vector3.UP.cross(forward).normalized()
	var leases := state["attack_leases"] as Dictionary
	for member_index: int in range(members.size()):
		var member := members[member_index] as Node3D
		var local_slot := (state["slots"] as Dictionary).get(member.get_instance_id(), Vector3.ZERO) as Vector3
		var slot_position := anchor + right * local_slot.x + forward * local_slot.z
		var member_facing := forward
		var member_id := member.get_instance_id()
		if local_reaction and target != null and is_instance_valid(target):
			slot_position = _breach_slot_position(state, member_index, anchor, forward, right)
			slot_position.y = anchor.y
			if _member_reacts_to_breach(state, member_index):
				member_facing = _planar_direction(slot_position, target.global_position, forward)
		# Close defenders and leased attackers acknowledge the real player position
		# even while the army keeps a stable strategic focus. This prevents a local
		# reaction from walking or striking backwards after the player crosses a line.
		if target != null and is_instance_valid(target) and (close_combat_members.has(member_id) or leases.has(member_id)):
			member_facing = _planar_direction(member.global_position, target.global_position, member_facing)
		if persistent and terrain_height_sampler.is_valid():
			slot_position.y = float(terrain_height_sampler.call(slot_position))
		member.call(
			"set_phalanx_intent",
			slot_position,
			member_facing,
			next_state == PhalanxState.ADVANCE or _planar_distance(member.global_position, slot_position) > profile.arrival_tolerance,
			leases.has(member_id),
			delta
		)
	state["decision_ticks"] = int(state["decision_ticks"]) + 1
	total_decision_ticks += 1


func _tick_mass_members(state: Dictionary, delta: float) -> void:
	for member: Node3D in state.get("members", []):
		if member != null and is_instance_valid(member) and member.has_method("formation_mass_tick"):
			member.call("formation_mass_tick", delta)


func _update_attack_leases(state: Dictionary, delta: float, engaging: bool, eligible_override: Array = []) -> void:
	var leases := state["attack_leases"] as Dictionary
	for raw_member_id: Variant in leases.keys():
		var remaining := float(leases[raw_member_id]) - delta
		if remaining <= 0.0 or not engaging:
			leases.erase(raw_member_id)
		else:
			leases[raw_member_id] = remaining
	if not engaging:
		return
	var profile := state["profile"] as HopliteV2PhalanxProfile
	var front_rank: Array = eligible_override if not eligible_override.is_empty() else state["front_rank"] as Array
	var members := state["members"] as Array
	if front_rank.is_empty() or leases.size() >= profile.max_concurrent_attacks:
		return
	var members_by_id: Dictionary = {}
	for member: Node3D in members:
		members_by_id[member.get_instance_id()] = member
	var attempts := 0
	while leases.size() < profile.max_concurrent_attacks and attempts < front_rank.size():
		var cursor := int(state["attack_cursor"]) % front_rank.size()
		var member_id := int(front_rank[cursor])
		state["attack_cursor"] = (cursor + 1) % front_rank.size()
		attempts += 1
		if leases.has(member_id) or not members_by_id.has(member_id):
			continue
		var member := members_by_id[member_id] as Node
		if member.has_method("can_accept_phalanx_attack") and bool(member.call("can_accept_phalanx_attack")):
			var duration := profile.attack_permission_seconds
			if bool(state.get("persistent_fronts", false)):
				var cap: EnemyV2UnitCapabilities = state["capabilities"]
				var target: Node3D = state.get("target")
				var combat: Node = member.get("combat")
				if combat != null and combat.has_method("attack_budget_seconds"):
					duration = maxf(duration, float(combat.call("attack_budget_seconds")))
				if target == null or not bool(threat_budget.call("request", member, target, cap.threat_kind, cap.threat_cost, duration)):
					continue
			leases[member_id] = duration


func _prune_members(group_id: StringName, state: Dictionary) -> void:
	var members := state["members"] as Array
	var removed_any := false
	for index in range(members.size() - 1, -1, -1):
		var member := members[index] as Node
		if member == null or not is_instance_valid(member) or bool(member.get("dead")):
			if member != null and is_instance_valid(member):
				(state["attack_leases"] as Dictionary).erase(member.get_instance_id())
			members.remove_at(index)
			removed_any = true
	if members.is_empty():
		groups.erase(group_id)
		group_ids.erase(group_id)
		set_process(not groups.is_empty())
		battle_layout.remove_group(group_id)
	elif removed_any:
		_rebuild_slots(group_id, state)
		battle_layout.update_group(group_id, state["anchor"] as Vector3, members.size())


func _rebuild_slots(group_id: StringName, state: Dictionary) -> void:
	var members := state["members"] as Array
	if bool(state.get("persistent_fronts", false)) and int(state.get("last_slot_count", members.size())) > members.size():
		state["last_slot_count"] = members.size()
		state["slots_rebuild_at"] = Time.get_ticks_msec() + 2400
		return
	members.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return int(a.get_meta("formation_unit_index", 0)) < int(b.get_meta("formation_unit_index", 0))
	)
	var profile := state["profile"] as HopliteV2PhalanxProfile
	var mode := StringName(state.get("mode", &"hoplite_phalanx"))
	var compact := mode == &"hoplite_skirmish" or members.size() <= BattleLayoutRuntime.REMNANT_MAX_MEMBERS or (bool(state.get("persistent_fronts", false)) and members.size() <= ceili(float(state.get("original_count", members.size())) * 0.25))
	var columns := profile.columns
	if compact:
		columns = clampi(ceili(sqrt(float(members.size()) * 1.5)), 1, 3)
	else:
		columns = mini(columns, maxi(1, members.size()))
	var row_count := ceili(float(members.size()) / float(columns))
	var slots: Dictionary = {}
	var front_rank: Array[int] = []
	for index: int in range(members.size()):
		var member := members[index] as Node3D
		var row := int(index / columns)
		var column := index % columns
		var row_width := mini(columns, members.size() - row * columns)
		var lateral := (float(column) - float(row_width - 1) * 0.5) * profile.column_spacing
		var depth := (float(row_count - 1) * 0.5 - float(row)) * profile.rank_spacing
		slots[member.get_instance_id()] = Vector3(lateral, 0.0, depth)
		if row == 0:
			front_rank.append(member.get_instance_id())
		member.call("bind_phalanx_runtime", self, group_id, row, column, profile, mode)
		if member.has_method("set_far_impostor_batch"):
			member.call("set_far_impostor_batch", impostor_batch)
	state["slots"] = slots
	state["front_rank"] = front_rank
	state["active_columns"] = columns
	state["attack_cursor"] = 0
	var leases := state["attack_leases"] as Dictionary
	for raw_id: Variant in leases.keys():
		if not slots.has(int(raw_id)):
			leases.erase(raw_id)


func group_snapshot(group_id: StringName) -> Dictionary:
	if not groups.has(group_id):
		return {}
	var state := groups[group_id] as Dictionary
	var strategic := battle_layout.assignment(group_id)
	var strategic_goal := strategic.get("anchor_goal", state["anchor"]) as Vector3
	return {
		"member_count": (state["members"] as Array).size(),
		"state": int(state["state"]),
		"decision_ticks": int(state["decision_ticks"]),
		"cohesion": float(state["cohesion"]),
		"attack_lease_count": (state["attack_leases"] as Dictionary).size(),
		"front_rank_count": (state["front_rank"] as Array).size(),
		"columns": (state["profile"] as HopliteV2PhalanxProfile).columns,
		"active_columns": int(state.get("active_columns", 0)),
		"mode": StringName(state.get("mode", &"")),
		"battle_role": StringName(state.get("battle_role", &"unassigned")),
		"battle_ring": int(state.get("battle_ring", -1)),
		"movement_phase": StringName(state.get("movement_phase", &"hold")),
		"group_engaged": bool(state.get("group_engaged", false)),
		"intrusion": bool(state.get("intrusion", false)),
		"breach_state": int(state.get("breach_state", BreachState.CLOSED)),
		"breach_column": int(state.get("breach_column", -1)),
		"local_reaction": int(state.get("breach_state", BreachState.CLOSED)) != BreachState.CLOSED,
		"anchor": state["anchor"] as Vector3,
		"strategic_goal": strategic_goal,
		"strategic_goal_error": _planar_distance(state["anchor"] as Vector3, strategic_goal),
		"target_distance": _planar_distance(
			state["anchor"] as Vector3,
			(state["target"] as Node3D).global_position
		) if state.get("target") is Node3D and is_instance_valid(state["target"] as Node3D) else INF,
	}


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _update_breach_state(
	state: Dictionary,
	target: Node3D,
	anchor: Vector3,
	forward: Vector3,
	right: Vector3,
	now_msec: int
) -> bool:
	if target == null or not is_instance_valid(target):
		state["breach_state"] = BreachState.CLOSED
		return false
	var profile := state["profile"] as HopliteV2PhalanxProfile
	var member_count := (state["members"] as Array).size()
	var columns := maxi(1, int(state.get("active_columns", 1)))
	var rows := maxi(1, ceili(float(member_count) / float(columns)))
	var to_target := target.global_position - anchor
	var vertical_offset := absf(to_target.y)
	to_target.y = 0.0
	var half_width := float(columns - 1) * profile.column_spacing * 0.5 + 0.90
	var front_depth := float(rows - 1) * profile.rank_spacing * 0.5
	var back_depth := -front_depth
	var lateral := to_target.dot(right)
	var depth := to_target.dot(forward)
	var inside_lateral := absf(lateral) <= half_width
	var grounded := true
	if target.has_method("is_on_floor"):
		grounded = bool(target.call("is_on_floor"))
	var valid_height := vertical_offset <= BREACH_MAX_VERTICAL_OFFSET
	var behind_first_rank := depth <= front_depth - BREACH_ENTER_DEPTH
	var back_in_front := depth >= front_depth - BREACH_EXIT_HYSTERESIS
	var behind_last_rank := depth < back_depth - BREACH_FLANK_DEPTH
	var inside_formation_depth := depth >= back_depth - BREACH_FLANK_DEPTH
	var breach_state := int(state.get("breach_state", BreachState.CLOSED))
	match breach_state:
		BreachState.CLOSED:
			if inside_lateral and valid_height and grounded and behind_first_rank and inside_formation_depth:
				state["breach_state"] = BreachState.CANDIDATE
				state["breach_candidate_since_msec"] = now_msec
				state["breach_lateral"] = clampf(lateral, -half_width, half_width)
				state["breach_column"] = clampi(roundi(lateral / profile.column_spacing + float(columns - 1) * 0.5), 0, columns - 1)
		BreachState.CANDIDATE:
			if not inside_lateral or not valid_height or back_in_front:
				state["breach_state"] = BreachState.CLOSED
				state["breach_candidate_since_msec"] = 0
			elif grounded and now_msec - int(state.get("breach_candidate_since_msec", now_msec)) >= BREACH_CONFIRM_MSEC:
				state["breach_state"] = BreachState.CHANNEL
		BreachState.CHANNEL:
			if behind_last_rank and grounded:
				state["breach_state"] = BreachState.FLANKED
			elif not inside_lateral or back_in_front:
				state["breach_state"] = BreachState.CLOSING
				state["breach_close_at_msec"] = now_msec + BREACH_CLOSE_MSEC
		BreachState.FLANKED:
			if back_in_front or not inside_lateral:
				state["breach_state"] = BreachState.CLOSING
				state["breach_close_at_msec"] = now_msec + BREACH_CLOSE_MSEC
		BreachState.CLOSING:
			if inside_lateral and valid_height and grounded and behind_first_rank and inside_formation_depth:
				state["breach_state"] = BreachState.CHANNEL
			elif now_msec >= int(state.get("breach_close_at_msec", 0)):
				state["breach_state"] = BreachState.CLOSED
				state["breach_candidate_since_msec"] = 0
				state["breach_column"] = -1
	return int(state.get("breach_state", BreachState.CLOSED)) != BreachState.CLOSED


static func _breach_slot_position(
	state: Dictionary,
	member_index: int,
	anchor: Vector3,
	forward: Vector3,
	right: Vector3
) -> Vector3:
	var members := state["members"] as Array
	var columns := maxi(1, int(state.get("active_columns", 1)))
	if member_index < 0 or member_index >= members.size():
		return anchor
	var member := members[member_index] as Node3D
	var local_slot := (state.get("slots", {}) as Dictionary).get(member.get_instance_id(), Vector3.ZERO) as Vector3
	if not _member_reacts_to_breach(state, member_index):
		return anchor + right * local_slot.x + forward * local_slot.z
	var breach_lateral := float(state.get("breach_lateral", 0.0))
	var breach_column := clampi(int(state.get("breach_column", 0)), 0, columns - 1)
	var column := member_index % columns
	var side := -1.0 if column <= breach_column else 1.0
	var lateral := local_slot.x
	if side < 0.0:
		lateral = minf(lateral, breach_lateral - BREACH_CHANNEL_CLEARANCE)
	else:
		lateral = maxf(lateral, breach_lateral + BREACH_CHANNEL_CLEARANCE)
	var result := anchor + right * lateral + forward * local_slot.z
	result.y = anchor.y
	return result


static func _member_reacts_to_breach(state: Dictionary, member_index: int) -> bool:
	var columns := maxi(1, int(state.get("active_columns", 1)))
	var breach_column := int(state.get("breach_column", -1))
	if breach_column < 0:
		return false
	var column := member_index % columns
	return absi(column - breach_column) <= BREACH_REACTION_COLUMN_RADIUS


static func _preserve_world_slots_for_about_face(state: Dictionary, previous_forward: Vector3, next_forward: Vector3) -> void:
	if previous_forward.length_squared() < 0.001 or next_forward.length_squared() < 0.001:
		return
	if previous_forward.normalized().dot(next_forward.normalized()) > -0.70:
		return
	# Both formation axes reverse during a 180° order. Mirroring both local slot
	# coordinates preserves every soldier's world-space place, so each hoplite
	# turns on himself instead of exchanging the left and right columns.
	var slots := state.get("slots", {}) as Dictionary
	for raw_member_id: Variant in slots.keys():
		var local_slot := slots[raw_member_id] as Vector3
		slots[raw_member_id] = Vector3(-local_slot.x, local_slot.y, -local_slot.z)


static func _planar_direction(from: Vector3, to: Vector3, fallback: Vector3) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return fallback
	return direction.normalized()


func is_fire_lane_clear(group_id: StringName, origin: Vector3, destination: Vector3) -> bool:
	var occupancy: RefCounted = battle_layout.occupancy
	if not occupancy.has_method("nearby_group_ids"):
		return true
	var segment := destination - origin
	segment.y = 0.0
	var length := segment.length()
	if length <= 0.1:
		return true
	var direction := segment / length
	var ids: Array = occupancy.call("nearby_group_ids", (origin + destination) * 0.5, length * 0.5 + 8.0)
	for id: Variant in ids:
		if StringName(id) == group_id or not battle_layout.records.has(id):
			continue
		var record: Dictionary = battle_layout.records[id]
		var offset: Vector3 = record["current_anchor"] - origin
		var forward: Vector3 = record["forward"]
		var right := Vector3.UP.cross(forward)
		var enter := 0.0
		var leave := length
		for axis_index in range(2):
			var axis := right if axis_index == 0 else forward
			var extent := float(record["formation_width"] if axis_index == 0 else record["formation_depth"]) * 0.5 + 0.25
			var center := offset.dot(axis)
			var speed := direction.dot(axis)
			if absf(speed) < 0.001:
				if absf(center) > extent:
					enter = length + 1.0
			else:
				var a := (center - extent) / speed
				var b := (center + extent) / speed
				enter = maxf(enter, minf(a,b))
				leave = minf(leave, maxf(a,b))
		if enter <= leave and leave > 0.5 and enter < length - 1.0:
			var cap: EnemyV2UnitCapabilities = record.get("capabilities")
			var body_top := float((record["current_anchor"] as Vector3).y) + (cap.body_height if cap != null else 2.0)
			var entry_height := lerpf(origin.y + 1.4, destination.y + 1.0, clampf(enter / length,0.0,1.0))
			var exit_height := lerpf(origin.y + 1.4, destination.y + 1.0, clampf(leave / length,0.0,1.0))
			# The ballistic arc lies above this chord, so this is conservative.
			if minf(entry_height,exit_height) > body_top + 0.3:
				continue
			return false
	return true
