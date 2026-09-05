extends Node
class_name HopliteBattleCrowdDirector

const CrowdSettingsScript = preload("res://scripts/ai/crowd_management_settings.gd")
const EngagementCoordinatorScript = preload("res://scripts/ai/crowd_engagement_coordinator.gd")
const GoreDirectorScript = preload("res://scripts/gore/gore_director.gd")

var cell_size: float = 3.0
var spatial_grid: Dictionary = {}
var crowd_settings: Dictionary = CrowdSettingsScript.defaults()
var engagement_coordinator: HopliteCrowdEngagementCoordinator = EngagementCoordinatorScript.new()
# Compatibility views kept public for diagnostics and older probes.
var engagement_slots: Dictionary = engagement_coordinator.slots
var engagement_frames: Dictionary = engagement_coordinator.frames
var attack_permissions: Dictionary = {}
var attack_wait_queues: Dictionary = {}
var next_attack_token: int = 1
var phalanx_slot_history: Dictionary = {}
var phalanx_cohort_states: Dictionary = {}
var phalanx_assignment_cache: Dictionary = {}
var phalanx_cache_frame: int = -1
var phalanx_group_build_count: int = 0
var phalanx_battle_layout_cache: Dictionary = {}
var phalanx_battle_layout_refresh_at: Dictionary = {}
var phalanx_sector_frames: Dictionary = {}
var phalanx_sortie_states: Dictionary = {}
var engagement_cleanup_timer: float = 0.0
var spatial_refresh_interval: float = 0.05
var spatial_refresh_accumulator: float = 0.0
var spatial_rebuild_count: int = 0
var group_snapshot_build_count: int = 0
var pressure_scan_count: int = 0
var combatant_ai_snapshot: Array[Node3D] = []
var enemy_target_snapshot: Array[Node] = []
var spartan_target_snapshot: Array[Node] = []
var phalanx_member_snapshot: Array[Node3D] = []
var local_pressure_cache: Dictionary = {}
var group_snapshots_dirty: bool = true

const ATTACK_PERMISSION_LIFETIME: float = 2.15
const PRESSURE_RADIUS: float = 10.0
const PHALANX_DEFAULT_COLUMNS: int = 5
const PHALANX_COHORT_RADIUS: float = 16.0

func _ready() -> void:
	add_to_group("crowd_director")
	process_physics_priority = 40
	if get_tree().get_first_node_in_group(&"gore_director") == null:
		var gore_director: Node = GoreDirectorScript.new()
		gore_director.name = "BattleGoreDirector"
		add_child(gore_director)
	reload_crowd_settings()
	_rebuild_spatial_grid()
	spatial_refresh_accumulator = spatial_refresh_interval

func reload_crowd_settings() -> void:
	crowd_settings = CrowdSettingsScript.read_project_settings()
	engagement_coordinator.configure(crowd_settings)
	spatial_refresh_interval = 1.0 / maxf(1.0, float(crowd_settings.get(&"spatial_refresh_hz", 20.0)))
	spatial_refresh_accumulator = minf(spatial_refresh_accumulator, spatial_refresh_interval)
	phalanx_assignment_cache.clear()
	phalanx_battle_layout_cache.clear()
	phalanx_battle_layout_refresh_at.clear()
	phalanx_sortie_states.clear()
	phalanx_cache_frame = -1
	local_pressure_cache.clear()

func _physics_process(delta: float) -> void:
	spatial_refresh_accumulator -= maxf(delta, 0.0)
	if spatial_refresh_accumulator <= 0.0:
		_rebuild_spatial_grid()
		spatial_refresh_accumulator = spatial_refresh_interval

	engagement_cleanup_timer -= delta
	if engagement_cleanup_timer <= 0.0:
		_cleanup_engagement_slots()
		engagement_cleanup_timer = 0.55

func invalidate_spatial_grid() -> void:
	# Membership changes are reflected on the next physics tick while ordinary
	# movement uses the cheaper 20 Hz tactical-neighbour cadence.
	spatial_refresh_accumulator = 0.0
	phalanx_cache_frame = -1
	group_snapshots_dirty = true

func invalidate_pressure_cache() -> void:
	local_pressure_cache.clear()

func _rebuild_spatial_grid() -> void:
	_ensure_group_snapshots()
	spatial_grid.clear()
	for node: Node3D in combatant_ai_snapshot:
		if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
			continue
		var key: Vector2i = _cell_for(node.global_position)
		if not spatial_grid.has(key):
			spatial_grid[key] = []
		var bucket: Array = spatial_grid[key]
		bucket.append(node)
		spatial_grid[key] = bucket
	spatial_rebuild_count += 1
	local_pressure_cache.clear()

func _ensure_group_snapshots() -> void:
	if not group_snapshots_dirty:
		return
	combatant_ai_snapshot.clear()
	for node: Node in get_tree().get_nodes_in_group("combatant_ai"):
		if node is Node3D and is_instance_valid(node):
			combatant_ai_snapshot.append(node as Node3D)
	enemy_target_snapshot.assign(get_tree().get_nodes_in_group("enemy"))
	spartan_target_snapshot.assign(get_tree().get_nodes_in_group("spartan_ally"))
	phalanx_member_snapshot.clear()
	for node: Node in get_tree().get_nodes_in_group("phalanx_unit"):
		if node is Node3D and is_instance_valid(node):
			phalanx_member_snapshot.append(node as Node3D)
	group_snapshots_dirty = false
	group_snapshot_build_count += 1

func target_candidates_for(requester_faction: StringName) -> Array[Node]:
	var target_group := &"enemy" if requester_faction == &"spartan" else &"spartan_ally"
	var snapshot_size := enemy_target_snapshot.size() if requester_faction == &"spartan" else spartan_target_snapshot.size()
	if get_tree().get_node_count_in_group(target_group) != snapshot_size:
		group_snapshots_dirty = true
	_ensure_group_snapshots()
	return enemy_target_snapshot if requester_faction == &"spartan" else spartan_target_snapshot

func _ensure_phalanx_snapshot() -> void:
	if get_tree().get_node_count_in_group(&"phalanx_unit") != phalanx_member_snapshot.size():
		group_snapshots_dirty = true
	_ensure_group_snapshots()

func fill_nearby_combatants(world_position: Vector3, result: Array[Node]) -> void:
	result.clear()
	var center: Vector2i = _cell_for(world_position)
	for offset_x: int in range(-1, 2):
		for offset_z: int in range(-1, 2):
			var key := Vector2i(center.x + offset_x, center.y + offset_z)
			if not spatial_grid.has(key):
				continue
			for value: Variant in spatial_grid[key]:
				if value is Node:
					result.append(value as Node)

func nearby_combatants(world_position: Vector3) -> Array[Node]:
	var result: Array[Node] = []
	fill_nearby_combatants(world_position, result)
	return result

func engagement_position(attacker: Node3D, target: Node3D, preferred_radius: float) -> Vector3:
	var assignment := engagement_assignment(attacker, target, preferred_radius)
	return assignment.get("position", target.global_position if target != null and is_instance_valid(target) else Vector3.ZERO)

func engagement_assignment(
	attacker: Node3D,
	target: Node3D,
	preferred_radius: float,
	participant: Dictionary = {}
) -> Dictionary:
	var resolved_participant := participant
	if resolved_participant.is_empty():
		resolved_participant = {"formation_kind": &"individual", "crowd_role": &"melee"}
	# Phalanx arcs live well outside the individual contact radius. They must not
	# consume contact slots or force ordinary melee into reserve rings.
	return engagement_coordinator.assignment(attacker, target, preferred_radius, resolved_participant)

func release_engagement(attacker: Node3D, target: Node3D) -> void:
	engagement_coordinator.release(attacker, target)

func phalanx_assignment(
	soldier: Node3D,
	target: Node3D,
	requested_columns: int = PHALANX_DEFAULT_COLUMNS,
	spacing: float = 1.08,
	rank_spacing: float = 1.18,
	front_distance: float = 2.42
) -> Dictionary:
	if soldier == null or target == null or not is_instance_valid(soldier) or not is_instance_valid(target):
		return {}
	var physics_frame := Engine.get_physics_frames()
	# Tests and membership-changing callers use -1 as an explicit invalidation.
	# Ordinary runtime frames keep the cohort result alive for a short tactical
	# interval: AI think timers are staggered, so a frame-only cache rebuilt the
	# whole formation once per soldier instead of once per cohort.
	if phalanx_cache_frame < 0:
		phalanx_assignment_cache.clear()
		phalanx_group_build_count = 0
		group_snapshots_dirty = true
		_ensure_group_snapshots()
	phalanx_cache_frame = physics_frame
	var now := Time.get_ticks_msec() * 0.001
	var soldier_id := soldier.get_instance_id()
	if phalanx_assignment_cache.has(soldier_id):
		var cached: Dictionary = phalanx_assignment_cache[soldier_id]
		var explicit_group := StringName(soldier.get_meta("formation_group", StringName()))
		var target_matches := explicit_group != StringName() or int(cached.get("target_id", -1)) == target.get_instance_id()
		if target_matches and now < float(cached.get("expires_at", 0.0)):
			return cached.get("assignment", {}) as Dictionary
	var candidates := _phalanx_candidates_for(soldier, target)
	if candidates.is_empty():
		return {}
	var resolved_target := target
	if StringName(soldier.get_meta("formation_group", StringName())) != StringName():
		resolved_target = _phalanx_authoritative_target(soldier, candidates, target)
	# The crowd settings panel is the single source of truth for global phalanx
	# geometry. Enemy profiles remain useful fallbacks for projects that invoke
	# this service without the shared settings contract.
	var resolved_columns := clampi(int(crowd_settings.get(&"phalanx_columns", requested_columns)), 3, 7)
	var resolved_spacing := float(crowd_settings.get(&"phalanx_column_spacing", spacing))
	var resolved_rank_spacing := float(crowd_settings.get(&"phalanx_rank_spacing", rank_spacing))
	var assignments := _build_phalanx_group_assignments(
		soldier, resolved_target, candidates, resolved_columns, resolved_spacing, resolved_rank_spacing, front_distance
	)
	# Publish movement tuning through the already cached tactical assignment.
	# Soldiers consume it when the assignment refreshes instead of reading
	# ProjectSettings in every physics callback.
	for raw_id: Variant in assignments.keys():
		var published := assignments[raw_id] as Dictionary
		published["formation_columns"] = resolved_columns
		published["formation_spacing"] = resolved_spacing
		published["formation_rank_spacing"] = resolved_rank_spacing
		published["move_speed_multiplier"] = float(crowd_settings.get(&"phalanx_move_speed_multiplier", 1.30))
		published["arrival_slowdown_distance"] = float(crowd_settings.get(&"phalanx_arrival_slowdown_distance", 0.55))
		published["arrival_min_speed_scale"] = float(crowd_settings.get(&"phalanx_arrival_min_speed_scale", 0.80))
		assignments[raw_id] = published
	phalanx_group_build_count += 1
	var refresh_hz := maxf(1.0, float(crowd_settings.get(&"phalanx_assignment_refresh_hz", 12.0)))
	var expires_at := now + 1.0 / refresh_hz
	for raw_id: Variant in assignments.keys():
		phalanx_assignment_cache[raw_id] = {
			"target_id": resolved_target.get_instance_id(),
			"expires_at": expires_at,
			"assignment": assignments[raw_id],
		}
	var result: Dictionary = phalanx_assignment_cache.get(soldier_id, {})
	return result.get("assignment", {}) as Dictionary

func _build_phalanx_group_assignments(
	soldier: Node3D,
	target: Node3D,
	candidates: Array[Node3D],
	requested_columns: int,
	spacing: float,
	rank_spacing: float,
	front_distance: float
) -> Dictionary:
	var columns := clampi(requested_columns, 3, 7)
	var cohort_key := _phalanx_cohort_key(soldier, target, candidates)
	var state: Dictionary = phalanx_cohort_states.get(cohort_key, {})
	var is_new_state := state.is_empty()
	var battle_layout := _phalanx_battle_layout_for(soldier, target)
	var slots := _reconcile_phalanx_slots(candidates, columns, state)
	var membership_ids: Array[int] = []
	for member: Node3D in candidates:
		membership_ids.append(member.get_instance_id())
	membership_ids.sort()
	var previous_membership: Array = state.get("membership_ids", [])
	if previous_membership != membership_ids:
		state["membership_ids"] = membership_ids
		state["membership_revision"] = int(state.get("membership_revision", 0)) + 1
	var centroid := Vector3.ZERO
	var veteran_count := 0
	for candidate: Node3D in candidates:
		centroid += candidate.global_position
		if StringName(candidate.get("behavior_mode")) == &"phalanx_veteran":
			veteran_count += 1
	centroid /= float(candidates.size())
	var desired_facing := target.global_position - centroid
	desired_facing.y = 0.0
	if desired_facing.length_squared() < 0.001:
		desired_facing = -target.global_basis.z
		desired_facing.y = 0.0
	desired_facing = desired_facing.normalized()
	var uses_shared_sector := bool(battle_layout.get("arc_active", false)) or int(battle_layout.get("support_level", 0)) > 0
	# A shared battle sector is a destination for this cohort, not a merged
	# formation state. As soon as two distinct cohorts are close enough to the
	# target, each one turns toward its own sector independently of the other
	# cohort's assembly/readiness.
	if uses_shared_sector:
		var layout_facing: Vector3 = battle_layout.get("facing", desired_facing)
		layout_facing.y = 0.0
		if layout_facing.length_squared() > 0.001:
			desired_facing = layout_facing.normalized()

	var row_count := maxi(1, ceili(float(candidates.size()) / float(columns)))
	var now := Time.get_ticks_msec() * 0.001
	if is_new_state:
		# The initial anchor stays at the cohort itself. Soldiers first close their
		# ranks here instead of each running toward a final slot beside the player.
		# Reconstruct the sign of the lateral axis from the persistent columns.
		# A fresh tactical state must never reinterpret a physical right file as
		# the left file merely because its new facing points the other way.
		var initial_line_right := _initial_phalanx_lateral_axis(desired_facing, centroid, candidates, slots)
		state = {
			"front_center": centroid + desired_facing * (float(row_count - 1) * rank_spacing * 0.5),
			"facing": desired_facing,
			"line_right": initial_line_right,
			"formed": false,
			"degraded": false,
			"assembly_started_at": now,
			"last_update": now,
			"last_seen": now,
		}
	state["member_slots"] = slots.duplicate(true)
	state["slot_columns"] = columns
	state["target_id"] = target.get_instance_id()
	var elapsed := clampf(now - float(state.get("last_update", now)), 0.0, 0.05)
	var cohort_facing: Vector3 = state.get("facing", desired_facing)
	var front_center: Vector3 = state.get("front_center", centroid)
	var line_right: Vector3 = state.get("line_right", cohort_facing.cross(Vector3.UP).normalized())
	var about_face_threshold := cos(deg_to_rad(float(crowd_settings.get(&"phalanx_about_face_threshold_degrees", 120.0))))
	var locked_straight_line := not uses_shared_sector and bool(state.get("formed", false))
	var pre_turn_target_delta := target.global_position - front_center
	pre_turn_target_delta.y = 0.0
	var pre_turn_half_width := float(mini(columns, candidates.size()) - 1) * spacing * 0.5
	var crosses_guarded_width := (
		locked_straight_line
		and pre_turn_target_delta.dot(cohort_facing) < float(crowd_settings.get(&"phalanx_intrusion_depth", 0.72))
		and absf(pre_turn_target_delta.dot(line_right)) <= pre_turn_half_width + float(crowd_settings.get(&"phalanx_intrusion_margin", 2.35))
		and pre_turn_target_delta.length() <= maxf(7.0, front_distance + float(row_count) * rank_spacing + 2.0)
	)
	var active_breach_before_turn := float(state.get("breach_until", 0.0)) > now
	# Small dead zone around the line plane prevents repeated flips when the
	# player strafes exactly along one shield edge.
	var changed_line_side := cohort_facing.dot(desired_facing) <= about_face_threshold
	var should_about_face := (
		not uses_shared_sector
		and not active_breach_before_turn
		and not crosses_guarded_width
		and (
			(locked_straight_line and changed_line_side)
			or (not locked_straight_line and cohort_facing.dot(desired_facing) <= about_face_threshold)
		)
	)
	if should_about_face:
		# A line has no privileged left-to-right direction. When the player
		# crosses far behind it, keep every occupied world slot fixed, reverse
		# the facing, and exchange front/rear rank roles. The characters rotate
		# individually in place instead of the whole rectangle orbiting its
		# anchor and collapsing through itself.
		var previous_facing := cohort_facing
		var last_row := maxi(0, row_count - 1)
		front_center -= previous_facing * float(last_row) * rank_spacing
		cohort_facing = -previous_facing
		for raw_member_id: Variant in slots.keys():
			var remapped := (slots[raw_member_id] as Dictionary).duplicate(true)
			var remapped_row := last_row - int(remapped.get("row", 0))
			remapped["row"] = remapped_row
			remapped["slot"] = remapped_row * columns + int(remapped.get("column", 0)) + columns / 2
			slots[raw_member_id] = remapped
		state["member_slots"] = slots.duplicate(true)
		state["front_center"] = front_center
		state["last_update"] = now
		elapsed = 0.0
	elif locked_straight_line:
		# A formed spear wall owns an undirected world-space line. Letting that
		# line chase a slowly orbiting player is what exchanged the left and
		# right files without ever tripping the old angular threshold. Hold the
		# lateral axis; only the discrete about-face above may change its normal.
		state["last_update"] = now
	elif elapsed > 0.0:
		var turn_speed := deg_to_rad(float(crowd_settings.get(&"phalanx_turn_speed_degrees", 45.0)))
		cohort_facing = _turn_flat_direction(cohort_facing, desired_facing, turn_speed * elapsed)
		state["last_update"] = now
	state["facing"] = cohort_facing
	state["last_seen"] = now

	var facing_right := cohort_facing.cross(Vector3.UP).normalized()
	# Preserve the undirected lateral axis. Without this sign continuity the
	# same physical left slot becomes right after a 180-degree turn.
	if facing_right.dot(line_right) < 0.0:
		facing_right = -facing_right
	line_right = facing_right
	state["line_right"] = line_right
	var breach_until := float(state.get("breach_until", 0.0))
	if bool(battle_layout.get("arc_active", false)) and breach_until > now:
		# The multi-cohort doctrine supersedes a solo penetration response. The
		# cohort joins its own allocated arc; its soldiers are never transferred
		# to, or held by, the neighbouring cohort.
		state.erase("breach_until")
		state.erase("breach_tactic")
		state.erase("breach_started_at")
		state.erase("breach_origin_front")
		state.erase("breach_origin_facing")
		state.erase("breach_origin_right")
		breach_until = 0.0
	if breach_until > 0.0 and now >= breach_until:
		# A breach response is temporary. Survivors then establish a fresh anchor
		# from their real positions and close ranks before advancing again.
		state.erase("breach_until")
		state.erase("breach_tactic")
		state.erase("breach_started_at")
		state.erase("breach_origin_front")
		state.erase("breach_origin_facing")
		state.erase("breach_origin_right")
		state["formed"] = false
		state["degraded"] = false
		state["assembly_started_at"] = now
		front_center = centroid + desired_facing * (float(row_count - 1) * rank_spacing * 0.5)
		state["front_center"] = front_center
		state["facing"] = desired_facing
		cohort_facing = desired_facing
		var reset_right := cohort_facing.cross(Vector3.UP).normalized()
		if reset_right.dot(line_right) < 0.0:
			reset_right = -reset_right
		line_right = reset_right
		state["line_right"] = line_right

	var target_from_front := target.global_position - front_center
	target_from_front.y = 0.0
	var target_depth := target_from_front.dot(cohort_facing)
	var target_lateral := target_from_front.dot(line_right)
	var formation_half_width := float(mini(columns, candidates.size()) - 1) * spacing * 0.5
	var formation_intrusion := (
		bool(state.get("formed", false))
		and not bool(battle_layout.get("arc_active", false))
		# The reaction begins as the player crosses the spear wall, not only once
		# he is already standing safely behind every shield.
		and target_depth < float(crowd_settings.get(&"phalanx_intrusion_depth", 0.72))
		and absf(target_lateral) <= formation_half_width + float(crowd_settings.get(&"phalanx_intrusion_margin", 2.35))
		and target_from_front.length() <= maxf(7.0, front_distance + float(row_count) * rank_spacing + 2.0)
	)
	if formation_intrusion and now >= float(state.get("breach_cooldown_until", 0.0)):
		# A penetrated spear wall has one clear doctrine: keep its mass together,
		# curve the shield front around the intruder, then press him back out.
		state["breach_tactic"] = &"expulsion_arc"
		state["breach_started_at"] = now
		state["breach_origin_front"] = front_center
		state["breach_origin_facing"] = cohort_facing
		state["breach_origin_right"] = line_right
		var response_duration := float(crowd_settings.get(&"phalanx_response_duration", 5.6))
		state["breach_until"] = now + response_duration
		state["breach_cooldown_until"] = now + response_duration + 0.2
		breach_until = float(state["breach_until"])

	if breach_until > now:
		var transition_duration := maxf(0.05, float(crowd_settings.get(&"phalanx_arc_transition", 1.35)))
		var breach_progress := clampf((now - float(state.get("breach_started_at", now))) / transition_duration, 0.0, 1.0)
		breach_progress = smoothstep(0.0, 1.0, breach_progress)
		state["last_seen"] = now
		phalanx_cohort_states[cohort_key] = state
		var breach_results: Dictionary = {}
		for candidate: Node3D in candidates:
			var candidate_slot: Dictionary = slots[candidate.get_instance_id()]
			var breach_assignment := _phalanx_expulsion_arc_assignment(
				candidate,
				target,
				desired_facing,
				int(candidate_slot.get("row", 0)),
				int(candidate_slot.get("column", 0)),
				int(candidate_slot.get("slot", 0)),
				spacing,
				rank_spacing,
				front_distance,
				columns,
				state.get("breach_origin_front", front_center),
				state.get("breach_origin_facing", cohort_facing),
				state.get("breach_origin_right", line_right),
				breach_progress
			)
			breach_results[candidate.get_instance_id()] = _complete_phalanx_assignment(
				candidate, candidates, breach_assignment, veteran_count, true, &"expulsion_arc"
			)
		return breach_results

	# A coordinated arc starts from the collective detection event, but remains
	# an independent destination for every cohort. It must not wait for either
	# this cohort's straight-line assembly or another cohort's readiness.
	var wants_battle_arc := bool(battle_layout.get("arc_active", false))
	var arc_blend := float(state.get("battle_arc_blend", 0.0))
	if elapsed > 0.0:
		var transition_duration := maxf(0.05, float(crowd_settings.get(&"phalanx_arc_transition", 1.35)))
		arc_blend = move_toward(arc_blend, 1.0 if wants_battle_arc else 0.0, elapsed / transition_duration)
	state["battle_arc_blend"] = arc_blend
	var coordinated_arc := wants_battle_arc or arc_blend > 0.001

	# Once a cohort owns a battle sector its conceptual anchor may advance even
	# while some of its soldiers are still arriving. The curved slots below are
	# still assigned and validated member by member.
	if elapsed > 0.0 and (bool(state.get("formed", false)) or uses_shared_sector):
		var desired_front_center := target.global_position - cohort_facing * maxf(front_distance, 1.8)
		if uses_shared_sector:
			desired_front_center = battle_layout.get("anchor_position", desired_front_center)
		var advance_delta: Vector3 = desired_front_center - front_center
		advance_delta.y = 0.0
		if advance_delta.length_squared() > 0.0001:
			var advance_speed := float(crowd_settings.get(&"phalanx_advance_speed", 3.25))
			front_center += advance_delta.normalized() * minf(advance_delta.length(), advance_speed * elapsed)
			state["front_center"] = front_center

	# Readiness is live state, not an assembly-only snapshot. A reserve that was
	# blocked during degraded formation becomes operational as soon as it reaches
	# its slot, and a promoted support soldier cannot attack through the vacancy
	# before physically filling it. In multi-cohort mode readiness is measured
	# against this cohort's own curved slot, never against another cohort.
	var ready_count := 0
	var member_readiness: Dictionary = {}
	var assembly_tolerance := float(crowd_settings.get(&"phalanx_assembly_tolerance", 0.92))
	for candidate: Node3D in candidates:
		var candidate_slot: Dictionary = slots.get(candidate.get_instance_id(), {})
		var candidate_row := int(candidate_slot.get("row", 0))
		var candidate_column := int(candidate_slot.get("column", 0))
		var staging_position := front_center + line_right * float(candidate_column) * spacing - cohort_facing * float(candidate_row) * rank_spacing
		if coordinated_arc:
			var staged_arc := _phalanx_coordinated_arc_assignment(
				target,
				candidate_row,
				candidate_column,
				int(candidate_slot.get("slot", 0)),
				columns,
				rank_spacing,
				front_distance,
				battle_layout,
				staging_position,
				arc_blend
			)
			staging_position = staged_arc.get("position", staging_position)
		var member_ready := candidate.global_position.distance_to(staging_position) <= assembly_tolerance
		member_readiness[candidate.get_instance_id()] = member_ready
		if member_ready:
			ready_count += 1
	state["member_readiness"] = member_readiness
	var required_ready := maxi(1, ceili(float(candidates.size()) * 0.90))
	if not bool(state.get("formed", false)):
		if ready_count >= required_ready:
			state["formed"] = true
			state["degraded"] = false
		elif now - float(state.get("assembly_started_at", now)) >= float(crowd_settings.get(&"phalanx_assembly_timeout", 3.5)):
			# Degraded assembly is intentionally based on a floor. With four
			# members, two blocked reserves must not keep the two operational
			# front-line soldiers in assembly forever (4 * 0.60 -> 2).
			var degraded_ratio := float(crowd_settings.get(&"phalanx_degraded_ready_ratio", 0.60))
			var degraded_required := maxi(2, floori(float(candidates.size()) * degraded_ratio))
			if ready_count >= degraded_required:
				state["formed"] = true
				state["degraded"] = true
	else:
		if bool(state.get("degraded", false)) and ready_count >= required_ready:
			state["degraded"] = false
	state["battle_layout"] = battle_layout.duplicate(true)
	phalanx_cohort_states[cohort_key] = state

	var results: Dictionary = {}
	var nearby_counts_by_member := _phalanx_nearby_counts_for(candidates)
	var published_readiness: Dictionary = state.get("member_readiness", {})
	for candidate: Node3D in candidates:
		var candidate_id := candidate.get_instance_id()
		var slot: Dictionary = slots[candidate_id]
		var row := int(slot.get("row", 0))
		var column := int(slot.get("column", 0))
		var current_slot := int(slot.get("slot", 0))
		var position := front_center + line_right * float(column) * spacing - cohort_facing * float(row) * rank_spacing
		var published_facing := cohort_facing
		if coordinated_arc:
			var arc_assignment := _phalanx_coordinated_arc_assignment(
				target, row, column, current_slot, columns, rank_spacing, front_distance,
				battle_layout, position, arc_blend
			)
			position = arc_assignment.get("position", position)
			published_facing = arc_assignment.get("facing", published_facing)
		var previous_slot := _remember_phalanx_slot(candidate_id, current_slot, row, column)
		var nearby: Vector2i = nearby_counts_by_member.get(candidate_id, Vector2i.ZERO)
		results[candidate_id] = {
			"position": position,
			"facing": published_facing,
			"row": row,
			"column": column,
			"slot": current_slot,
			"slot_changed": previous_slot >= 0 and previous_slot != current_slot,
			"cohort_revision": int(state.get("membership_revision", 1)),
			"cohort_key": cohort_key,
			"unit_count": candidates.size(),
			"nearby_allies": nearby.x,
			"nearby_veterans": nearby.y,
			"veteran_count": veteran_count,
			"broken": candidates.size() < 2,
			"front_rank": row == 0,
			"cohort_formed": bool(state.get("formed", false)),
			"degraded": bool(state.get("degraded", false)),
			"member_ready": bool(published_readiness.get(candidate_id, not bool(state.get("degraded", false)))),
			"breach": coordinated_arc,
			"breach_tactic": &"coordinated_arc" if coordinated_arc else &"none",
			"breach_role": &"arc_press" if coordinated_arc and row == 0 else &"arc_support" if coordinated_arc else &"line",
			"breach_can_attack": false,
			"breach_transition": arc_blend,
			"battle_primary": bool(battle_layout.get("primary", false)),
			"battle_support_level": int(battle_layout.get("support_level", 0)),
		}
		if coordinated_arc:
			results[candidate_id].merge(_phalanx_sortie_assignment(
				candidate, target, battle_layout, position, published_facing, row, now, assembly_tolerance
			), true)
	return results

func _phalanx_nearby_counts_for(candidates: Array[Node3D]) -> Dictionary:
	const NEARBY_RADIUS: float = 4.6
	var buckets: Dictionary = {}
	var counts: Dictionary = {}
	for candidate: Node3D in candidates:
		var position := candidate.global_position
		var key := Vector2i(floori(position.x / NEARBY_RADIUS), floori(position.z / NEARBY_RADIUS))
		if not buckets.has(key):
			buckets[key] = []
		var bucket: Array = buckets[key]
		bucket.append(candidate)
		buckets[key] = bucket
		counts[candidate.get_instance_id()] = Vector2i.ZERO

	var radius_squared := NEARBY_RADIUS * NEARBY_RADIUS
	for soldier: Node3D in candidates:
		var soldier_position := soldier.global_position
		var center := Vector2i(floori(soldier_position.x / NEARBY_RADIUS), floori(soldier_position.z / NEARBY_RADIUS))
		var nearby := Vector2i.ZERO
		for offset_x: int in range(-1, 2):
			for offset_z: int in range(-1, 2):
				var key := Vector2i(center.x + offset_x, center.y + offset_z)
				if not buckets.has(key):
					continue
				for value: Variant in buckets[key]:
					var candidate := value as Node3D
					if candidate == null or candidate == soldier:
						continue
					if candidate.global_position.distance_squared_to(soldier_position) > radius_squared:
						continue
					nearby.x += 1
					if StringName(candidate.get("behavior_mode")) == &"phalanx_veteran":
						nearby.y += 1
		counts[soldier.get_instance_id()] = nearby
	return counts

func _phalanx_expulsion_arc_assignment(
	soldier: Node3D,
	target: Node3D,
	target_direction: Vector3,
	row: int,
	column: int,
	slot: int,
	spacing: float,
	rank_spacing: float,
	front_distance: float,
	columns: int,
	origin_front: Vector3,
	origin_facing: Vector3,
	origin_right: Vector3,
	transition: float
) -> Dictionary:
	var facing := target_direction.normalized()
	if facing.length_squared() < 0.001:
		facing = (target.global_position - soldier.global_position).normalized()
	var mass_direction := -facing
	var half_columns := maxf(1.0, float(columns - 1) * 0.5)
	var normalized_column := clampf(float(column) / half_columns, -1.0, 1.0)
	# A 136-degree crescent wraps its tips around the player without closing a
	# full circle. Every soldier remains on the cohort's side of the player, so
	# opposing files never stop nose-to-nose as the old split-wing tactic did.
	var arc_half_angle := deg_to_rad(float(crowd_settings.get(&"phalanx_single_arc_degrees", 136.0)) * 0.5)
	var stable_right := origin_right.normalized()
	if stable_right.length_squared() < 0.001:
		stable_right = origin_facing.cross(Vector3.UP).normalized()
	var natural_arc_right := facing.cross(Vector3.UP).normalized()
	var arc_side_sign := 1.0 if natural_arc_right.dot(stable_right) >= 0.0 else -1.0
	var arc_angle := normalized_column * arc_half_angle * arc_side_sign
	var arc_direction := Basis(Vector3.UP, arc_angle) * mass_direction
	var arc_radius := maxf(1.98, front_distance * 0.82) + float(row) * rank_spacing * 0.82
	# The centre presses closest; the curved tips retain enough room to slide
	# around the target instead of colliding with the middle shields.
	arc_radius += absf(normalized_column) * 0.20
	var arc_position := target.global_position + arc_direction.normalized() * arc_radius

	var line_position := origin_front + stable_right * float(column) * spacing - origin_facing * float(row) * rank_spacing
	var position := line_position.lerp(arc_position, transition)
	var direct_facing := target.global_position - position
	direct_facing.y = 0.0
	if direct_facing.length_squared() > 0.001:
		direct_facing = direct_facing.normalized()
		# Flat yaw interpolation remains well-defined even for the exact 180°
		# reversal that occurs when the player crosses through the centre file.
		facing = _turn_flat_direction(origin_facing, direct_facing, PI * transition)

	return {
		"position": position,
		"facing": facing,
		"row": row,
		"column": column,
		"slot": slot,
		"breach_role": &"arc_press" if row == 0 else &"arc_support",
		"breach_can_attack": row == 0,
		"breach_transition": transition,
	}

func _phalanx_coordinated_arc_assignment(
	target: Node3D,
	row: int,
	column: int,
	slot: int,
	columns: int,
	rank_spacing: float,
	front_distance: float,
	layout: Dictionary,
	line_position: Vector3,
	transition: float
) -> Dictionary:
	if target == null or not is_instance_valid(target) or layout.is_empty():
		return {"position": line_position, "facing": Vector3.FORWARD, "row": row, "column": column, "slot": slot}
	var center_angle := float(layout.get("center_angle", 0.0))
	var segment_span := float(layout.get("segment_span", TAU / 3.0))
	# Use columns, not columns - 1: the half-slot margin makes neighbouring
	# cohorts meet end-to-end without stacking their edge soldiers together.
	# Positive line columns lie on `facing.cross(UP)`. In polar space that
	# tangent corresponds to a decreasing angle, so keep the minus sign to
	# preserve each soldier's side instead of crossing files through a ball.
	var column_angle := -float(column) / float(maxi(1, columns)) * segment_span
	var angle := center_angle + column_angle
	var support_level := int(layout.get("support_level", 0))
	var radius := maxf(float(layout.get("arc_radius", front_distance)), 1.8)
	if not layout.has("arc_radius"):
		radius += float(support_level) * float(crowd_settings.get(&"phalanx_support_ring_spacing", 2.65))
	radius += float(row) * rank_spacing * 0.82
	var radial := Vector3(cos(angle), 0.0, sin(angle))
	var arc_position := target.global_position + radial * radius
	var position := line_position.lerp(arc_position, smoothstep(0.0, 1.0, clampf(transition, 0.0, 1.0)))
	var facing := target.global_position - position
	facing.y = 0.0
	if facing.length_squared() < 0.001:
		facing = -radial
	return {
		"position": position,
		"facing": facing.normalized(),
		"row": row,
		"column": column,
		"slot": slot,
		"breach_role": &"arc_press" if row == 0 else &"arc_support",
		"breach_can_attack": row == 0 and transition >= 0.62,
		"breach_transition": transition,
	}

func _phalanx_sortie_assignment(
	soldier: Node3D,
	target: Node3D,
	layout: Dictionary,
	wall_position: Vector3,
	wall_facing: Vector3,
	row: int,
	now: float,
	arrival_tolerance: float
) -> Dictionary:
	if row != 0 or not bool(layout.get("primary", false)) or not bool(layout.get("arc_active", false)):
		return {
			"breach_tactic": &"coordinated_arc",
			"breach_role": &"arc_support" if row > 0 else &"arc_press",
			"breach_can_attack": false,
			"sortie_phase": &"inactive",
		}
	var faction := StringName(soldier.get("faction"))
	var state := _advance_phalanx_sortie_state(target, faction, now)
	var phase := StringName(state.get("phase", &"rest"))
	var selected_ids: Array = state.get("selected_ids", [])
	if not selected_ids.has(soldier.get_instance_id()) or phase == &"rest":
		return {
			"breach_tactic": &"coordinated_arc",
			"breach_role": &"arc_press",
			"breach_can_attack": false,
			"sortie_phase": phase,
		}

	var from_target := wall_position - target.global_position
	from_target.y = 0.0
	if from_target.length_squared() < 0.001:
		from_target = -wall_facing
	var radial := from_target.normalized()
	var attack_radius := maxf(0.5, float(crowd_settings.get(&"phalanx_sortie_attack_radius", 2.25)))
	var attack_position := target.global_position + radial * attack_radius
	var duration := maxf(0.05, _phalanx_sortie_phase_duration(phase))
	var progress := clampf((now - float(state.get("phase_started_at", now))) / duration, 0.0, 1.0)
	progress = smoothstep(0.0, 1.0, progress)
	var advance_blend := 1.0
	if phase == &"advance":
		advance_blend = progress
	elif phase == &"return":
		advance_blend = 1.0 - progress
	var position := wall_position.lerp(attack_position, advance_blend)
	var facing := target.global_position - position
	facing.y = 0.0
	if facing.length_squared() < 0.001:
		facing = wall_facing
	var reached_attack_post := soldier.global_position.distance_squared_to(attack_position) <= arrival_tolerance * arrival_tolerance
	return {
		"position": position,
		"facing": facing.normalized(),
		"breach_tactic": &"coordinated_sortie",
		"breach_role": &"sortie_striker",
		"breach_can_attack": phase == &"strike" and reached_attack_post,
		"sortie_phase": phase,
		"sortie_selected": true,
		"sortie_attack_position": attack_position,
	}


func _advance_phalanx_sortie_state(target: Node3D, faction: StringName, now: float) -> Dictionary:
	var state_key := "%d:%s" % [target.get_instance_id(), String(faction)]
	var state: Dictionary = phalanx_sortie_states.get(state_key, {})
	if state.is_empty():
		var initial_selection := _select_phalanx_sortie_members(target, faction, 0)
		state = {
			"target_id": target.get_instance_id(),
			"faction": faction,
			"phase": &"advance",
			"phase_started_at": now,
			"selected_ids": initial_selection.get("selected_ids", []),
			"cursor": int(initial_selection.get("next_cursor", 0)),
			"last_seen": now,
		}

	# Advance at most one full cycle when a frame arrives late. Keeping the
	# original phase boundary makes the cadence deterministic under frame drops.
	for transition_index: int in range(4):
		var phase := StringName(state.get("phase", &"rest"))
		var phase_duration := maxf(0.05, _phalanx_sortie_phase_duration(phase))
		var phase_started_at := float(state.get("phase_started_at", now))
		if now - phase_started_at < phase_duration:
			break
		state["phase_started_at"] = phase_started_at + phase_duration
		match phase:
			&"advance":
				state["phase"] = &"strike"
			&"strike":
				state["phase"] = &"return"
			&"return":
				state["phase"] = &"rest"
			_:
				var selection := _select_phalanx_sortie_members(target, faction, int(state.get("cursor", 0)))
				state["selected_ids"] = selection.get("selected_ids", [])
				state["cursor"] = int(selection.get("next_cursor", 0))
				state["phase"] = &"advance"
	state["last_seen"] = now
	phalanx_sortie_states[state_key] = state
	return state


func _phalanx_sortie_phase_duration(phase: StringName) -> float:
	match phase:
		&"advance":
			return float(crowd_settings.get(&"phalanx_sortie_advance_duration", 0.90))
		&"strike":
			return float(crowd_settings.get(&"phalanx_sortie_strike_duration", 1.35))
		&"return":
			return float(crowd_settings.get(&"phalanx_sortie_return_duration", 0.90))
		_:
			return float(crowd_settings.get(&"phalanx_sortie_rest_duration", 0.85))


func _select_phalanx_sortie_members(target: Node3D, faction: StringName, cursor: int) -> Dictionary:
	var layouts := _phalanx_battle_layouts_for_target(target)
	var eligible_ids: Array[int] = []
	_ensure_phalanx_snapshot()
	for node: Node3D in phalanx_member_snapshot:
		if not is_instance_valid(node):
			continue
		if StringName(node.get("faction")) != faction or node.get("ai_player") != target:
			continue
		if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
			continue
		var member := node
		var cohort_key := _phalanx_external_cohort_key(member)
		var layout := layouts.get(cohort_key, {}) as Dictionary
		if not bool(layout.get("primary", false)) or not bool(layout.get("arc_active", false)):
			continue
		var cohort_state := phalanx_cohort_states.get(cohort_key, {}) as Dictionary
		var member_slots := cohort_state.get("member_slots", {}) as Dictionary
		var slot := member_slots.get(member.get_instance_id(), {}) as Dictionary
		if int(slot.get("row", -1)) == 0:
			eligible_ids.append(member.get_instance_id())
	eligible_ids.sort()
	if eligible_ids.is_empty():
		return {"selected_ids": [], "next_cursor": 0}
	var selection_size := mini(eligible_ids.size(), maxi(1, int(crowd_settings.get(&"phalanx_sortie_size", 3.0))))
	var selected_ids: Array[int] = []
	var start := posmod(cursor, eligible_ids.size())
	for index: int in range(selection_size):
		selected_ids.append(eligible_ids[(start + index) % eligible_ids.size()])
	return {
		"selected_ids": selected_ids,
		"next_cursor": (start + selection_size) % eligible_ids.size(),
	}


func _complete_phalanx_assignment(
	soldier: Node3D,
	candidates: Array[Node3D],
	breach_assignment: Dictionary,
	veteran_count: int,
	breach: bool,
	breach_tactic: StringName
) -> Dictionary:
	var nearby_allies := 0
	var nearby_veterans := 0
	var radius_squared := 4.6 * 4.6
	for candidate: Node3D in candidates:
		if candidate != soldier and candidate.global_position.distance_squared_to(soldier.global_position) <= radius_squared:
			nearby_allies += 1
			if StringName(candidate.get("behavior_mode")) == &"phalanx_veteran":
				nearby_veterans += 1
	var current_slot := int(breach_assignment.get("slot", 0))
	var previous_slot := _remember_phalanx_slot(
		soldier.get_instance_id(),
		current_slot,
		int(breach_assignment.get("row", 0)),
		int(breach_assignment.get("column", 0))
	)
	var result := breach_assignment.duplicate(true)
	result.merge({
		"slot_changed": previous_slot >= 0 and previous_slot != current_slot,
		"unit_count": candidates.size(),
		"nearby_allies": nearby_allies,
		"nearby_veterans": nearby_veterans,
		"veteran_count": veteran_count,
		"broken": candidates.size() < 2,
		"front_rank": int(result.get("row", 0)) == 0,
		"cohort_formed": true,
		"breach": breach,
		"breach_tactic": breach_tactic,
	}, true)
	return result

func _phalanx_cohort_key(soldier: Node3D, target: Node3D, candidates: Array[Node3D]) -> String:
	var explicit_group := StringName(soldier.get_meta("formation_group", StringName()))
	if explicit_group != StringName():
		return "%s:%s" % [String(soldier.get("faction")), String(explicit_group)]
	var stable_member_id := candidates[0].get_instance_id() if not candidates.is_empty() else soldier.get_instance_id()
	return "%s:%d:%d" % [String(soldier.get("faction")), target.get_instance_id(), stable_member_id]

func _turn_flat_direction(current: Vector3, desired: Vector3, max_angle: float) -> Vector3:
	var current_yaw := atan2(-current.x, -current.z)
	var desired_yaw := atan2(-desired.x, -desired.z)
	var yaw_delta := wrapf(desired_yaw - current_yaw, -PI, PI)
	var next_yaw := current_yaw + clampf(yaw_delta, -max_angle, max_angle)
	return Vector3(-sin(next_yaw), 0.0, -cos(next_yaw)).normalized()

func _phalanx_candidates_for(soldier: Node3D, target: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var soldier_faction := StringName(soldier.get("faction"))
	var soldier_cohort := StringName(soldier.get_meta("formation_group", StringName()))
	_ensure_phalanx_snapshot()
	for node: Node3D in phalanx_member_snapshot:
		if not is_instance_valid(node):
			continue
		if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
			continue
		if StringName(node.get("faction")) != soldier_faction:
			continue
		var candidate := node
		var candidate_cohort := StringName(candidate.get_meta("formation_group", StringName()))
		if soldier_cohort != StringName():
			if candidate_cohort != soldier_cohort:
				continue
		else:
			var node_target: Variant = node.get("ai_player")
			if node_target != target:
				continue
			if candidate_cohort != StringName() or candidate.global_position.distance_squared_to(soldier.global_position) > PHALANX_COHORT_RADIUS * PHALANX_COHORT_RADIUS:
				continue
		result.append(candidate)
	result.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.get_instance_id() < b.get_instance_id())
	return result

func _phalanx_authoritative_target(soldier: Node3D, candidates: Array[Node3D], fallback: Node3D) -> Node3D:
	var cohort_key := _phalanx_cohort_key(soldier, fallback, candidates)
	var previous_target_id := int((phalanx_cohort_states.get(cohort_key, {}) as Dictionary).get("target_id", -1))
	var counts: Dictionary = {}
	var targets: Dictionary = {}
	for candidate: Node3D in candidates:
		var candidate_target: Variant = candidate.get("ai_player")
		if not (candidate_target is Node3D) or not is_instance_valid(candidate_target):
			continue
		var target_id := (candidate_target as Node3D).get_instance_id()
		counts[target_id] = int(counts.get(target_id, 0)) + 1
		targets[target_id] = candidate_target
	var best_target := fallback
	var best_count := -1
	for raw_target_id: Variant in counts.keys():
		var target_id := int(raw_target_id)
		var count := int(counts[target_id])
		if count > best_count or (count == best_count and target_id == previous_target_id):
			best_count = count
			best_target = targets[target_id] as Node3D
	return best_target

func _phalanx_battle_layout_for(soldier: Node3D, target: Node3D) -> Dictionary:
	if soldier == null or target == null or not is_instance_valid(soldier) or not is_instance_valid(target):
		return {}
	var layouts := _phalanx_battle_layouts_for_target(target)
	var cohort_key := _phalanx_external_cohort_key(soldier)
	return (layouts.get(cohort_key, {}) as Dictionary).duplicate(true)

func _phalanx_battle_layouts_for_target(target: Node3D) -> Dictionary:
	var target_id := target.get_instance_id()
	var now := Time.get_ticks_msec() * 0.001
	if phalanx_battle_layout_cache.has(target_id) and now < float(phalanx_battle_layout_refresh_at.get(target_id, 0.0)):
		return phalanx_battle_layout_cache[target_id] as Dictionary

	var cohorts: Dictionary = {}
	_ensure_phalanx_snapshot()
	for node: Node3D in phalanx_member_snapshot:
		if not is_instance_valid(node):
			continue
		if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
			continue
		if node.has_method("is_ai_participating_for_combat") and not bool(node.call("is_ai_participating_for_combat")):
			continue
		var node_target: Variant = node.get("ai_player")
		if node_target != target:
			continue
		var member := node
		var key := _phalanx_external_cohort_key(member)
		var descriptor: Dictionary = cohorts.get(key, {
			"cohort_key": key,
			"faction": StringName(member.get("faction")),
			"members": [],
			"centroid": Vector3.ZERO,
		})
		var members: Array = descriptor["members"]
		members.append(member)
		descriptor["members"] = members
		descriptor["centroid"] = (descriptor.get("centroid", Vector3.ZERO) as Vector3) + member.global_position
		cohorts[key] = descriptor

	var descriptors: Array[Dictionary] = []
	for raw_key: Variant in cohorts.keys():
		var descriptor := cohorts[raw_key] as Dictionary
		var members: Array = descriptor["members"]
		var centroid: Vector3 = descriptor["centroid"]
		centroid /= float(maxi(1, members.size()))
		descriptor["centroid"] = centroid
		descriptor["distance_squared"] = centroid.distance_squared_to(target.global_position)
		var from_target := centroid - target.global_position
		from_target.y = 0.0
		descriptor["angle"] = atan2(from_target.z, from_target.x) if from_target.length_squared() > 0.001 else 0.0
		descriptors.append(descriptor)

	descriptors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var faction_a := String(a.get("faction", &""))
		var faction_b := String(b.get("faction", &""))
		if faction_a != faction_b:
			return faction_a < faction_b
		var distance_a := float(a.get("distance_squared", INF))
		var distance_b := float(b.get("distance_squared", INF))
		if not is_equal_approx(distance_a, distance_b):
			return distance_a < distance_b
		return String(a.get("cohort_key", "")) < String(b.get("cohort_key", ""))
	)

	var by_faction: Dictionary = {}
	for descriptor: Dictionary in descriptors:
		# A distant cohort keeps its independent straight line and never reserves
		# a future hole. No arrival timestamp is retained.
		var coordination_distance := float(crowd_settings.get(&"phalanx_coordination_distance", 6.5))
		if float(descriptor.get("distance_squared", INF)) > coordination_distance * coordination_distance:
			continue
		var faction := StringName(descriptor.get("faction", &""))
		var faction_cohorts: Array = by_faction.get(faction, [])
		faction_cohorts.append(descriptor)
		by_faction[faction] = faction_cohorts

	var layouts: Dictionary = {}
	for raw_faction: Variant in by_faction.keys():
		var faction_cohorts: Array = by_faction[raw_faction]
		var primary_count := mini(faction_cohorts.size(), maxi(1, int(crowd_settings.get(&"phalanx_primary_cohorts", 4.0))))
		if primary_count <= 0:
			continue
		var coverage := deg_to_rad(float(crowd_settings.get(&"phalanx_single_arc_degrees", 136.0)))
		if primary_count == 2:
			coverage = deg_to_rad(float(crowd_settings.get(&"phalanx_two_coverage_degrees", 180.0)))
		elif primary_count == 3:
			coverage = deg_to_rad(float(crowd_settings.get(&"phalanx_three_coverage_degrees", 280.0)))
		elif primary_count >= 4:
			coverage = TAU
		var segment_span := coverage / float(primary_count)
		var frame_key := "%d:%s" % [target_id, String(raw_faction)]
		var ordered_cohorts := _fixed_phalanx_sector_order(
			frame_key, faction_cohorts, primary_count, segment_span, now
		)
		var frame: Dictionary = phalanx_sector_frames.get(frame_key, {})
		var base_angle := float(frame.get("base_angle", 0.0))
		var radius_multiplier := float(crowd_settings.get(&"phalanx_multi_arc_radius_multiplier", 2.0)) if primary_count >= 2 else 1.0
		for index: int in range(ordered_cohorts.size()):
			var descriptor := ordered_cohorts[index] as Dictionary
			var primary := index < primary_count
			var primary_index := index if primary else index % primary_count
			var support_level := 0 if primary else 1 + (index - primary_count) / primary_count
			# This world-space sector angle is frozen until the nearby cohort
			# composition changes. It never consumes the generic ring phase.
			var center_angle := base_angle + float(primary_index) * segment_span
			var member_count := (descriptor.get("members", []) as Array).size()
			var front_count := mini(PHALANX_DEFAULT_COLUMNS, member_count)
			var front_radius := maxf(1.8, 2.42 * radius_multiplier + float(support_level) * float(crowd_settings.get(&"phalanx_support_ring_spacing", 2.65)))
			var physical_half_width := atan2(float(maxi(1, front_count)) * 1.08 * 0.5, front_radius)
			var reserved_half_width := segment_span * 0.5 if primary_count >= 2 else minf(coverage * 0.5, physical_half_width)
			var radial := Vector3(cos(center_angle), 0.0, sin(center_angle))
			var cohort_key := String(descriptor.get("cohort_key", ""))
			layouts[cohort_key] = {
				"cohort_key": cohort_key,
				"primary": primary,
				"support_level": support_level,
				"primary_count": primary_count,
				"center_angle": center_angle,
				"segment_span": segment_span,
				"reserved_half_width": reserved_half_width,
				"arc_active": primary and primary_count >= 2,
				"arc_radius": front_radius,
				"anchor_position": target.global_position + radial * front_radius,
				"facing": -radial,
			}
	phalanx_battle_layout_cache[target_id] = layouts
	var layout_refresh_hz := maxf(1.0, float(crowd_settings.get(&"formation_layout_refresh_hz", 10.0)))
	phalanx_battle_layout_refresh_at[target_id] = now + 1.0 / layout_refresh_hz
	return layouts

func _fixed_phalanx_sector_order(
	frame_key: String,
	faction_cohorts: Array,
	primary_count: int,
	segment_span: float,
	now: float
) -> Array:
	var by_key: Dictionary = {}
	for raw_descriptor: Variant in faction_cohorts:
		var descriptor := raw_descriptor as Dictionary
		var cohort_key := String(descriptor.get("cohort_key", ""))
		by_key[cohort_key] = descriptor

	var nearest := faction_cohorts.duplicate()
	nearest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var distance_a := float(a.get("distance_squared", INF))
		var distance_b := float(b.get("distance_squared", INF))
		if not is_equal_approx(distance_a, distance_b):
			return distance_a < distance_b
		return String(a.get("cohort_key", "")) < String(b.get("cohort_key", ""))
	)
	var primary: Array = nearest.slice(0, primary_count)
	var support: Array = nearest.slice(primary_count)
	var primary_signature_parts: PackedStringArray = []
	for raw_descriptor: Variant in primary:
		primary_signature_parts.append(String((raw_descriptor as Dictionary).get("cohort_key", "")))
	primary_signature_parts.sort()
	var primary_signature := ",".join(primary_signature_parts)
	var frame: Dictionary = phalanx_sector_frames.get(frame_key, {})
	var same_topology := (
		String(frame.get("primary_signature", "")) == primary_signature
		and int(frame.get("primary_count", -1)) == primary_count
		and is_equal_approx(float(frame.get("segment_span", -1.0)), segment_span)
	)
	if same_topology:
		var stable_order: Array = []
		for raw_key: Variant in frame.get("ordered_keys", []):
			var cohort_key := String(raw_key)
			if by_key.has(cohort_key):
				stable_order.append(by_key[cohort_key])
		var stable_keys: Dictionary = {}
		for raw_descriptor: Variant in stable_order:
			stable_keys[String((raw_descriptor as Dictionary).get("cohort_key", ""))] = true
		for raw_descriptor: Variant in nearest:
			var cohort_key := String((raw_descriptor as Dictionary).get("cohort_key", ""))
			if not stable_keys.has(cohort_key):
				stable_order.append(raw_descriptor)
		var stable_order_keys: Array[String] = []
		for raw_descriptor: Variant in stable_order:
			stable_order_keys.append(String((raw_descriptor as Dictionary).get("cohort_key", "")))
		frame["ordered_keys"] = stable_order_keys
		frame["last_seen"] = now
		phalanx_sector_frames[frame_key] = frame
		return stable_order

	# Topology changes are rare. Select the closest primary cohorts, arrange
	# those by their current angle, then freeze the least-travel global phase.
	var optimized := _least_travel_phalanx_phase(primary, segment_span)
	primary = optimized.get("order", primary) as Array
	var base_angle := float(optimized.get("base_angle", float((primary[0] as Dictionary).get("angle", 0.0))))
	var ordered: Array = primary + support
	var ordered_keys: Array[String] = []
	for raw_descriptor: Variant in ordered:
		ordered_keys.append(String((raw_descriptor as Dictionary).get("cohort_key", "")))
	phalanx_sector_frames[frame_key] = {
		"primary_signature": primary_signature,
		"primary_count": primary_count,
		"segment_span": segment_span,
		"base_angle": base_angle,
		"ordered_keys": ordered_keys,
		"last_seen": now,
	}
	return ordered

func _least_travel_phalanx_phase(primary: Array, segment_span: float) -> Dictionary:
	if primary.is_empty():
		return {"order": [], "base_angle": 0.0}
	var angular_order := primary.duplicate()
	angular_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("angle", 0.0)) < float(b.get("angle", 0.0))
	)
	var best_order := angular_order.duplicate()
	var best_base := float((angular_order[0] as Dictionary).get("angle", 0.0))
	var best_cost := INF
	for reverse_order: bool in [false, true]:
		var source := angular_order.duplicate()
		if reverse_order:
			source.reverse()
		for shift: int in range(source.size()):
			var candidate_order: Array = []
			var sum_x := 0.0
			var sum_y := 0.0
			for index: int in range(source.size()):
				var descriptor := source[(index + shift) % source.size()] as Dictionary
				candidate_order.append(descriptor)
				var candidate_base := float(descriptor.get("angle", 0.0)) - float(index) * segment_span
				sum_x += cos(candidate_base)
				sum_y += sin(candidate_base)
			var candidate_phase := atan2(sum_y, sum_x) if absf(sum_x) + absf(sum_y) > 0.001 else float((candidate_order[0] as Dictionary).get("angle", 0.0))
			var cost := 0.0
			for index: int in range(candidate_order.size()):
				var observed := float((candidate_order[index] as Dictionary).get("angle", 0.0))
				var displacement := wrapf(candidate_phase + float(index) * segment_span - observed, -PI, PI)
				cost += displacement * displacement
			if cost < best_cost:
				best_cost = cost
				best_base = candidate_phase
				best_order = candidate_order
	return {"order": best_order, "base_angle": best_base}

func _phalanx_external_cohort_key(soldier: Node3D) -> String:
	var faction := StringName(soldier.get("faction"))
	var explicit_group := StringName(soldier.get_meta("formation_group", StringName()))
	if explicit_group != StringName():
		return "%s:%s" % [String(faction), String(explicit_group)]
	# Unlabelled phalanxes retain the legacy nearby-cohort behaviour. Their
	# shared fallback key is intentionally faction-scoped and only used for the
	# higher-level battle layout, never for persistent internal member slots.
	return "%s:implicit" % String(faction)

func _reconcile_phalanx_slots(candidates: Array[Node3D], columns: int, state: Dictionary) -> Dictionary:
	var desired := _build_phalanx_slots(candidates, columns)
	var previous: Dictionary = state.get("member_slots", {})
	if state.is_empty() or int(state.get("slot_columns", columns)) != columns:
		# Cohort states intentionally expire. Restore compatible descriptors from
		# the already-existing member history before assigning new vacancies, so
		# expiration, target changes or implicit-key changes cannot mirror files.
		previous = _phalanx_historical_slots(candidates, columns, desired)
		if previous.is_empty():
			return desired
	var candidate_ids: Dictionary = {}
	for candidate: Node3D in candidates:
		candidate_ids[candidate.get_instance_id()] = true
	var result: Dictionary = {}
	var occupied: Dictionary = {}
	var vacancies: Array[Dictionary] = []
	for raw_id: Variant in previous.keys():
		var member_id := int(raw_id)
		if not candidate_ids.has(member_id):
			vacancies.append((previous[raw_id] as Dictionary).duplicate(true))
			continue
		var preserved: Dictionary = (previous[raw_id] as Dictionary).duplicate(true)
		result[member_id] = preserved
		occupied[int(preserved.get("slot", -1))] = true
	# A casualty in an operational rank promotes the nearest support-rank
	# survivor into the exact vacancy. Only that survivor moves; its old rear
	# slot becomes the new vacancy, avoiding a full formation renumber.
	vacancies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	for vacancy: Dictionary in vacancies:
		var vacancy_row := int(vacancy.get("row", 0))
		var vacancy_column := int(vacancy.get("column", 0))
		var promoted_id := -1
		var promoted_score := INF
		for raw_member_id: Variant in result.keys():
			var member_id := int(raw_member_id)
			var current: Dictionary = result[member_id]
			var current_row := int(current.get("row", 0))
			if current_row <= vacancy_row:
				continue
			var score := float(current_row - vacancy_row) * 100.0 + float(abs(int(current.get("column", 0)) - vacancy_column))
			if score < promoted_score or (is_equal_approx(score, promoted_score) and member_id < promoted_id):
				promoted_id = member_id
				promoted_score = score
		if promoted_id >= 0:
			var released_slot := int((result[promoted_id] as Dictionary).get("slot", -1))
			occupied.erase(released_slot)
			result[promoted_id] = vacancy.duplicate(true)
			occupied[int(vacancy.get("slot", -1))] = true
	var available: Array[Dictionary] = []
	for raw_slot: Variant in desired.values():
		var descriptor := raw_slot as Dictionary
		if not occupied.has(int(descriptor.get("slot", -1))):
			available.append(descriptor)
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	for candidate: Node3D in candidates:
		var member_id := candidate.get_instance_id()
		if result.has(member_id):
			continue
		var historical := _phalanx_slot_history_descriptor(member_id, columns)
		var descriptor := _take_nearest_historical_slot(available, historical)
		if descriptor.is_empty():
			descriptor = available.pop_front() if not available.is_empty() else desired.get(member_id, {})
		result[member_id] = descriptor.duplicate(true)
		occupied[int(descriptor.get("slot", -1))] = true
	return result

func _take_nearest_historical_slot(available: Array[Dictionary], historical: Dictionary) -> Dictionary:
	if available.is_empty() or historical.is_empty():
		return {}
	var old_row := int(historical.get("row", 0))
	var old_column := int(historical.get("column", 0))
	var best_index := -1
	var best_score := INF
	for index: int in range(available.size()):
		var candidate := available[index]
		var new_column := int(candidate.get("column", 0))
		var sign_flip_penalty := 1000.0 if old_column != 0 and new_column != 0 and signi(old_column) != signi(new_column) else 0.0
		var score := sign_flip_penalty + float(abs(int(candidate.get("row", 0)) - old_row)) * 100.0 + float(abs(new_column - old_column))
		if score < best_score:
			best_score = score
			best_index = index
	return available.pop_at(best_index) if best_index >= 0 else {}

func _phalanx_historical_slots(candidates: Array[Node3D], columns: int, desired: Dictionary) -> Dictionary:
	var valid_coordinates: Dictionary = {}
	for raw_descriptor: Variant in desired.values():
		var descriptor := raw_descriptor as Dictionary
		valid_coordinates[Vector2i(int(descriptor.get("row", 0)), int(descriptor.get("column", 0)))] = true
	var restored: Dictionary = {}
	var occupied: Dictionary = {}
	for candidate: Node3D in candidates:
		var member_id := candidate.get_instance_id()
		var descriptor := _phalanx_slot_history_descriptor(member_id, columns)
		var slot := int(descriptor.get("slot", -1))
		var coordinates := Vector2i(int(descriptor.get("row", 0)), int(descriptor.get("column", 0)))
		if descriptor.is_empty() or not valid_coordinates.has(coordinates) or occupied.has(slot):
			continue
		restored[member_id] = descriptor
		occupied[slot] = true
	return restored

func _phalanx_slot_history_descriptor(member_id: int, columns: int) -> Dictionary:
	if not phalanx_slot_history.has(member_id):
		return {}
	var packed: Variant = phalanx_slot_history[member_id]
	if packed is Vector3i:
		var descriptor := packed as Vector3i
		if descriptor.x < 0 or descriptor.y < 0:
			return {}
		# Recompute the packed slot for the current width while retaining row and
		# lateral identity. A live columns-slider change may compact an edge file,
		# but it must not send that file across the centre.
		return {
			"slot": descriptor.y * columns + descriptor.z + columns / 2,
			"row": descriptor.y,
			"column": descriptor.z,
		}
	# Compatibility with a live editor session that still contains the former
	# integer-only history representation.
	var legacy_slot := int(packed)
	if legacy_slot < 0:
		return {}
	var legacy_row := floori(float(legacy_slot) / float(columns))
	return {
		"slot": legacy_slot,
		"row": legacy_row,
		"column": legacy_slot - legacy_row * columns - columns / 2,
	}

func _remember_phalanx_slot(member_id: int, slot: int, row: int, column: int) -> int:
	var previous_slot := -1
	if phalanx_slot_history.has(member_id):
		var previous: Variant = phalanx_slot_history[member_id]
		previous_slot = (previous as Vector3i).x if previous is Vector3i else int(previous)
	# Reuse the existing history entry and pack the full identity into one value;
	# no second per-member dictionary is introduced.
	phalanx_slot_history[member_id] = Vector3i(slot, row, column)
	return previous_slot

func _initial_phalanx_lateral_axis(
	desired_facing: Vector3,
	centroid: Vector3,
	candidates: Array[Node3D],
	slots: Dictionary
) -> Vector3:
	var lateral_axis := desired_facing.cross(Vector3.UP).normalized()
	var positive_sum := Vector3.ZERO
	var negative_sum := Vector3.ZERO
	var positive_count := 0
	var negative_count := 0
	for candidate: Node3D in candidates:
		var descriptor := slots.get(candidate.get_instance_id(), {}) as Dictionary
		var column := int(descriptor.get("column", 0))
		if column > 0:
			positive_sum += candidate.global_position
			positive_count += 1
		elif column < 0:
			negative_sum += candidate.global_position
			negative_count += 1
	var observed_positive_direction := Vector3.ZERO
	if positive_count > 0 and negative_count > 0:
		observed_positive_direction = positive_sum / float(positive_count) - negative_sum / float(negative_count)
	elif positive_count > 0:
		observed_positive_direction = positive_sum / float(positive_count) - centroid
	elif negative_count > 0:
		observed_positive_direction = centroid - negative_sum / float(negative_count)
	observed_positive_direction.y = 0.0
	if observed_positive_direction.length_squared() > 0.0001 and lateral_axis.dot(observed_positive_direction) < 0.0:
		lateral_axis = -lateral_axis
	return lateral_axis

func _build_phalanx_slots(candidates: Array[Node3D], columns: int) -> Dictionary:
	var regulars: Array[Node3D] = []
	var veterans: Array[Node3D] = []
	for candidate: Node3D in candidates:
		if StringName(candidate.get("behavior_mode")) == &"phalanx_veteran":
			veterans.append(candidate)
		else:
			regulars.append(candidate)
	var result: Dictionary = {}
	var total_remaining := candidates.size()
	var row := 0
	while total_remaining > 0:
		var row_size := mini(columns, total_remaining)
		var row_units: Array[Node3D] = []
		var row_veterans: Array[Node3D] = []
		var veterans_for_row := mini(2, veterans.size()) if row_size >= 3 else 0
		for index: int in range(veterans_for_row):
			row_veterans.append(veterans.pop_front())
		while row_units.size() + row_veterans.size() < row_size and not regulars.is_empty():
			row_units.append(regulars.pop_front())
		while row_units.size() + row_veterans.size() < row_size and not veterans.is_empty():
			row_units.append(veterans.pop_front())

		var columns_by_priority := _center_out_columns(row_size)
		for index: int in range(row_units.size()):
			_store_phalanx_slot(result, row_units[index], row, int(columns_by_priority[index]), columns)
		var edge_columns: Array[int] = []
		if row_size > 1:
			edge_columns = [row_size / 2, -(row_size / 2)]
		else:
			edge_columns = [0]
		for index: int in range(row_veterans.size()):
			_store_phalanx_slot(result, row_veterans[index], row, edge_columns[index % edge_columns.size()], columns)
		total_remaining -= row_size
		row += 1
	return result

func _center_out_columns(row_size: int) -> Array[int]:
	var result: Array[int] = [0]
	var offset := 1
	while result.size() < row_size:
		result.append(-offset)
		if result.size() < row_size:
			result.append(offset)
		offset += 1
	return result

func _store_phalanx_slot(result: Dictionary, soldier: Node3D, row: int, column: int, columns: int) -> void:
	result[soldier.get_instance_id()] = {
		"slot": row * columns + column + columns / 2,
		"row": row,
		"column": column,
	}

func request_attack_permission(attacker: Node3D, target: Node3D, capacity: int = 2) -> bool:
	return request_attack_lease(attacker, target, capacity) > 0

func request_attack_lease(attacker: Node3D, target: Node3D, capacity: int = 2) -> int:
	if not _is_attack_actor_eligible(attacker) or not _is_attack_actor_eligible(target):
		return 0
	var target_id := target.get_instance_id()
	var attacker_id := attacker.get_instance_id()
	var permissions: Dictionary = attack_permissions.get(target_id, {})
	_remove_expired_permissions(permissions)
	var now := Time.get_ticks_msec() * 0.001
	if permissions.has(attacker_id):
		var active_lease: Dictionary = permissions[attacker_id]
		active_lease["expires_at"] = now + float(crowd_settings.get(&"attack_lease_lifetime", ATTACK_PERMISSION_LIFETIME))
		permissions[attacker_id] = active_lease
		attack_permissions[target_id] = permissions
		_remove_attack_waiter(target_id, attacker_id)
		return int(active_lease.get("token", 0))
	var wait_queue: Array = _living_attack_waiters(attack_wait_queues.get(target_id, []))
	if permissions.size() >= maxi(1, capacity):
		attack_permissions[target_id] = permissions
		if not wait_queue.has(attacker_id):
			wait_queue.append(attacker_id)
		attack_wait_queues[target_id] = wait_queue
		return 0
	# A newly freed slot belongs to the oldest living requester. Polling more
	# frequently cannot let a later attacker skip the visible waiting line.
	if not wait_queue.is_empty():
		if not wait_queue.has(attacker_id):
			wait_queue.append(attacker_id)
		if int(wait_queue.front()) != attacker_id:
			attack_wait_queues[target_id] = wait_queue
			return 0
		wait_queue.pop_front()
		if wait_queue.is_empty():
			attack_wait_queues.erase(target_id)
		else:
			attack_wait_queues[target_id] = wait_queue
	var token := next_attack_token
	next_attack_token += 1
	permissions[attacker_id] = {
		"token": token,
		"expires_at": now + float(crowd_settings.get(&"attack_lease_lifetime", ATTACK_PERMISSION_LIFETIME)),
		"granted_at": now,
	}
	attack_permissions[target_id] = permissions
	return token

func has_attack_permission(attacker: Node3D, target: Node3D) -> bool:
	if not _is_attack_actor_eligible(attacker) or not _is_attack_actor_eligible(target):
		return false
	var target_id := target.get_instance_id()
	if not attack_permissions.has(target_id):
		return false
	var permissions: Dictionary = attack_permissions[target_id]
	_remove_expired_permissions(permissions)
	if permissions.is_empty():
		attack_permissions.erase(target_id)
		return false
	attack_permissions[target_id] = permissions
	return permissions.has(attacker.get_instance_id())

func _is_attack_actor_eligible(actor: Node3D) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return false
	if actor.has_method("is_dead_for_combat") and bool(actor.call("is_dead_for_combat")):
		return false
	if actor.has_method("is_ai_participating_for_combat") and not bool(actor.call("is_ai_participating_for_combat")):
		return false
	return true

func _living_attack_waiters(wait_queue: Array) -> Array:
	var index := 0
	while index < wait_queue.size():
		var candidate := instance_from_id(int(wait_queue[index])) as Node3D
		if _is_attack_actor_eligible(candidate):
			index += 1
		else:
			wait_queue.remove_at(index)
	return wait_queue

func is_attack_lease_valid(attacker: Node3D, target: Node3D, token: int) -> bool:
	if token <= 0 or not has_attack_permission(attacker, target):
		return false
	var lease: Dictionary = attack_permissions[target.get_instance_id()][attacker.get_instance_id()]
	return int(lease.get("token", 0)) == token

func attack_capacity_for(target: Node3D) -> int:
	# More bodies should create tactical pressure, not an unreadable blender.
	# Dense groups gain one extra attacker while the rest hold wings/reserve.
	var pressure := local_pressure(target)
	if pressure >= int(crowd_settings.get(&"dense_pressure_threshold", 10.0)):
		return maxi(1, int(crowd_settings.get(&"dense_attack_capacity", 3.0)))
	return maxi(1, int(crowd_settings.get(&"base_attack_capacity", 2.0)))

func local_pressure(target: Node3D) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	var target_id := target.get_instance_id()
	var cached: Dictionary = local_pressure_cache.get(target_id, {})
	if int(cached.get("spatial_revision", -1)) == spatial_rebuild_count:
		return int(cached.get("count", 0))
	var center := _cell_for(target.global_position)
	var pressure_radius := float(crowd_settings.get(&"pressure_radius", PRESSURE_RADIUS))
	var cell_radius := ceili(pressure_radius / cell_size)
	var radius_squared := pressure_radius * pressure_radius
	var count := 0
	for offset_x: int in range(-cell_radius, cell_radius + 1):
		for offset_z: int in range(-cell_radius, cell_radius + 1):
			var key := Vector2i(center.x + offset_x, center.y + offset_z)
			if not spatial_grid.has(key):
				continue
			for value: Variant in spatial_grid[key]:
				if value is Node3D and (value as Node3D).global_position.distance_squared_to(target.global_position) <= radius_squared:
					count += 1
	pressure_scan_count += 1
	local_pressure_cache[target_id] = {
		"spatial_revision": spatial_rebuild_count,
		"count": count,
	}
	return count

func release_attack_permission(attacker: Node3D, target: Node3D, token: int = 0) -> void:
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	var target_id := target.get_instance_id()
	_remove_attack_waiter(target_id, attacker.get_instance_id())
	if not attack_permissions.has(target_id):
		return
	var permissions: Dictionary = attack_permissions[target_id]
	if token > 0 and permissions.has(attacker.get_instance_id()):
		var active_lease: Dictionary = permissions[attacker.get_instance_id()]
		if int(active_lease.get("token", 0)) != token:
			return
	permissions.erase(attacker.get_instance_id())
	if permissions.is_empty():
		attack_permissions.erase(target_id)
	else:
		attack_permissions[target_id] = permissions

func cancel_attack_requests(attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	var attacker_id := attacker.get_instance_id()
	for raw_target_id: Variant in attack_wait_queues.keys():
		_remove_attack_waiter(int(raw_target_id), attacker_id)
	for raw_target_id: Variant in attack_permissions.keys():
		var target_id := int(raw_target_id)
		var permissions: Dictionary = attack_permissions[target_id]
		permissions.erase(attacker_id)
		if permissions.is_empty():
			attack_permissions.erase(target_id)
		else:
			attack_permissions[target_id] = permissions

func _cleanup_engagement_slots() -> void:
	var living_ids: Dictionary = {}
	_ensure_group_snapshots()
	for node: Node3D in combatant_ai_snapshot:
		if not node.has_method("is_dead_for_combat") or not bool(node.call("is_dead_for_combat")):
			living_ids[node.get_instance_id()] = true
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			living_ids[(node as Node3D).get_instance_id()] = true

	engagement_coordinator.cleanup(living_ids)

	for raw_target_id: Variant in attack_permissions.keys():
		var target_id: int = int(raw_target_id)
		if not living_ids.has(target_id):
			attack_permissions.erase(target_id)
			continue
		var permissions: Dictionary = attack_permissions[target_id]
		_remove_expired_permissions(permissions, living_ids)
		if permissions.is_empty():
			attack_permissions.erase(target_id)
		else:
			attack_permissions[target_id] = permissions

	for raw_target_id: Variant in attack_wait_queues.keys():
		var target_id: int = int(raw_target_id)
		if not living_ids.has(target_id):
			attack_wait_queues.erase(target_id)
			continue
		var wait_queue: Array = attack_wait_queues[target_id]
		var living_queue: Array = []
		for raw_attacker_id: Variant in wait_queue:
			if living_ids.has(int(raw_attacker_id)):
				living_queue.append(int(raw_attacker_id))
		if living_queue.is_empty():
			attack_wait_queues.erase(target_id)
		else:
			attack_wait_queues[target_id] = living_queue

	for raw_soldier_id: Variant in phalanx_slot_history.keys():
		if not living_ids.has(int(raw_soldier_id)):
			phalanx_slot_history.erase(raw_soldier_id)

	var now := Time.get_ticks_msec() * 0.001
	for raw_soldier_id: Variant in phalanx_assignment_cache.keys():
		var soldier_id := int(raw_soldier_id)
		var cached_assignment := phalanx_assignment_cache[raw_soldier_id] as Dictionary
		if not living_ids.has(soldier_id) or now >= float(cached_assignment.get("expires_at", 0.0)):
			phalanx_assignment_cache.erase(raw_soldier_id)
	for cohort_key: Variant in phalanx_cohort_states.keys():
		var state: Dictionary = phalanx_cohort_states[cohort_key]
		if now - float(state.get("last_seen", now)) > 2.0:
			phalanx_cohort_states.erase(cohort_key)
	for raw_frame_key: Variant in phalanx_sector_frames.keys():
		var frame: Dictionary = phalanx_sector_frames[raw_frame_key]
		if now - float(frame.get("last_seen", now)) > 2.0:
			phalanx_sector_frames.erase(raw_frame_key)
	for raw_sortie_key: Variant in phalanx_sortie_states.keys():
		var sortie_state: Dictionary = phalanx_sortie_states[raw_sortie_key]
		var target_id := int(sortie_state.get("target_id", -1))
		if not living_ids.has(target_id) or now - float(sortie_state.get("last_seen", now)) > 2.0:
			phalanx_sortie_states.erase(raw_sortie_key)

func _remove_expired_permissions(permissions: Dictionary, living_ids: Dictionary = {}) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for raw_attacker_id: Variant in permissions.keys():
		var attacker_id := int(raw_attacker_id)
		var lease_value: Variant = permissions[raw_attacker_id]
		var expires_at := float((lease_value as Dictionary).get("expires_at", 0.0)) if lease_value is Dictionary else float(lease_value)
		var expired := expires_at <= now
		var no_longer_living := not living_ids.is_empty() and not living_ids.has(attacker_id)
		if expired or no_longer_living:
			permissions.erase(raw_attacker_id)

func _remove_attack_waiter(target_id: int, attacker_id: int) -> void:
	if not attack_wait_queues.has(target_id):
		return
	var wait_queue: Array = attack_wait_queues[target_id]
	wait_queue.erase(attacker_id)
	if wait_queue.is_empty():
		attack_wait_queues.erase(target_id)
	else:
		attack_wait_queues[target_id] = wait_queue

func _cell_for(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.z / cell_size))
