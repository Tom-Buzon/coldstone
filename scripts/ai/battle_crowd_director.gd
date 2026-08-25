extends Node
class_name HopliteBattleCrowdDirector

var cell_size: float = 3.0
var spatial_grid: Dictionary = {}
var engagement_slots: Dictionary = {}
var engagement_frames: Dictionary = {}
var attack_permissions: Dictionary = {}
var phalanx_slot_history: Dictionary = {}
var phalanx_cohort_states: Dictionary = {}
var engagement_cleanup_timer: float = 0.0

const ENGAGEMENT_SLOTS_PER_RING: int = 6
const ENGAGEMENT_RING_SPACING: float = 1.18
const ENGAGEMENT_MIN_RADIUS: float = 1.78
const ATTACK_PERMISSION_LIFETIME: float = 2.15
const PRESSURE_RADIUS: float = 10.0
const PHALANX_DEFAULT_COLUMNS: int = 5
const PHALANX_COHORT_RADIUS: float = 16.0
const PHALANX_ASSEMBLY_TOLERANCE: float = 0.92
const PHALANX_ADVANCE_SPEED: float = 1.65
const PHALANX_TURN_SPEED: float = deg_to_rad(28.0)

func _ready() -> void:
    add_to_group("crowd_director")
    process_physics_priority = 40

func _physics_process(delta: float) -> void:
    spatial_grid.clear()
    for node: Node in get_tree().get_nodes_in_group("combatant_ai"):
        if not (node is Node3D):
            continue
        if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
            continue
        var key: Vector2i = _cell_for((node as Node3D).global_position)
        if not spatial_grid.has(key):
            spatial_grid[key] = []
        var bucket: Array = spatial_grid[key]
        bucket.append(node)
        spatial_grid[key] = bucket

    engagement_cleanup_timer -= delta
    if engagement_cleanup_timer <= 0.0:
        _cleanup_engagement_slots()
        engagement_cleanup_timer = 0.55

func nearby_combatants(world_position: Vector3) -> Array[Node]:
    var result: Array[Node] = []
    var center: Vector2i = _cell_for(world_position)
    for offset_x: int in range(-1, 2):
        for offset_z: int in range(-1, 2):
            var key := Vector2i(center.x + offset_x, center.y + offset_z)
            if not spatial_grid.has(key):
                continue
            for value: Variant in spatial_grid[key]:
                if value is Node:
                    result.append(value as Node)
    return result

func engagement_position(attacker: Node3D, target: Node3D, preferred_radius: float) -> Vector3:
    var assignment := engagement_assignment(attacker, target, preferred_radius)
    return assignment.get("position", target.global_position if target != null and is_instance_valid(target) else Vector3.ZERO)

func engagement_assignment(attacker: Node3D, target: Node3D, preferred_radius: float) -> Dictionary:
    if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
        return {
            "position": target.global_position if target != null and is_instance_valid(target) else Vector3.ZERO,
            "role": &"invalid",
            "attack_ready": false,
            "ring": -1,
        }

    var target_id: int = target.get_instance_id()
    var attacker_id: int = attacker.get_instance_id()
    var assignments: Dictionary = engagement_slots.get(target_id, {})
    var slot: int = int(assignments.get(attacker_id, -1))

    if slot < 0:
        slot = _first_free_engagement_slot(assignments)
    else:
        # When an inner fighter leaves or dies, outer-ring soldiers advance into
        # the newly freed position instead of preserving a hollow formation.
        var occupied: Dictionary = _occupied_engagement_slots(assignments, attacker_id)
        for candidate: int in range(slot):
            if not occupied.has(candidate):
                slot = candidate
                break

    assignments[attacker_id] = slot
    engagement_slots[target_id] = assignments

    var ring: int = slot / ENGAGEMENT_SLOTS_PER_RING
    var ring_slot: int = slot % ENGAGEMENT_SLOTS_PER_RING
    var phase: float = 0.5 if (ring % 2) == 1 else 0.0
    # Freeze a tactical frame when contact begins. Following every twitch of the
    # target's facing would make the whole crowd orbit when the player simply
    # turns; the frame is released with the engagement instead.
    var target_forward: Vector3 = engagement_frames.get(target_id, Vector3.ZERO)
    if target_forward.length_squared() < 0.001:
        target_forward = attacker.global_position - target.global_position
        target_forward.y = 0.0
        if target_forward.length_squared() < 0.001:
            target_forward = -target.global_basis.z
            target_forward.y = 0.0
        if target_forward.length_squared() < 0.001:
            target_forward = Vector3.FORWARD
        target_forward = target_forward.normalized()
        engagement_frames[target_id] = target_forward
    var base_angle := atan2(target_forward.z, target_forward.x)
    var angle: float = base_angle + (float(ring_slot) + phase) * TAU / float(ENGAGEMENT_SLOTS_PER_RING)
    var radius: float = maxf(preferred_radius, ENGAGEMENT_MIN_RADIUS) + float(ring) * ENGAGEMENT_RING_SPACING
    var role := &"reserve"
    if ring == 0:
        role = &"line" if ring_slot in [0, 1, ENGAGEMENT_SLOTS_PER_RING - 1] else &"wing"
    return {
        "position": target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius,
        "role": role,
        # Six soldiers occupy the contact ring. Everybody else visibly holds a
        # second/third line and advances when a contact slot is actually freed.
        "attack_ready": ring == 0,
        "ring": ring,
        "slot": slot,
    }

func release_engagement(attacker: Node3D, target: Node3D) -> void:
    if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
        return
    var target_id: int = target.get_instance_id()
    if not engagement_slots.has(target_id):
        return
    var assignments: Dictionary = engagement_slots[target_id]
    assignments.erase(attacker.get_instance_id())
    if assignments.is_empty():
        engagement_slots.erase(target_id)
        engagement_frames.erase(target_id)
    else:
        engagement_slots[target_id] = assignments

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
    var candidates := _phalanx_candidates_for(soldier, target)
    if candidates.is_empty():
        return {}
    var columns := clampi(requested_columns, 3, 7)
    var slots := _build_phalanx_slots(candidates, columns)
    var soldier_id := soldier.get_instance_id()
    if not slots.has(soldier_id):
        return {}

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

    var row_count := maxi(1, ceili(float(candidates.size()) / float(columns)))
    var cohort_key := _phalanx_cohort_key(soldier, target, candidates)
    var now := Time.get_ticks_msec() * 0.001
    var state: Dictionary = phalanx_cohort_states.get(cohort_key, {})
    if state.is_empty():
        # The initial anchor stays at the cohort itself. Soldiers first close their
        # ranks here instead of each running toward a final slot beside the player.
        state = {
            "front_center": centroid + desired_facing * (float(row_count - 1) * rank_spacing * 0.5),
            "facing": desired_facing,
            "formed": false,
            "last_update": now,
            "last_seen": now,
        }
    var elapsed := clampf(now - float(state.get("last_update", now)), 0.0, 0.05)
    var cohort_facing: Vector3 = state.get("facing", desired_facing)
    if elapsed > 0.0:
        cohort_facing = _turn_flat_direction(cohort_facing, desired_facing, PHALANX_TURN_SPEED * elapsed)
        state["last_update"] = now
    state["facing"] = cohort_facing
    state["last_seen"] = now

    var front_center: Vector3 = state.get("front_center", centroid)
    var line_right := cohort_facing.cross(Vector3.UP).normalized()
    var breach_until := float(state.get("breach_until", 0.0))
    if breach_until > 0.0 and now >= breach_until:
        # A breach response is temporary. Survivors then establish a fresh anchor
        # from their real positions and close ranks before advancing again.
        state.erase("breach_until")
        state.erase("breach_tactic")
        state.erase("breach_started_at")
        state.erase("breach_origin_front")
        state.erase("breach_origin_facing")
        state["formed"] = false
        front_center = centroid + desired_facing * (float(row_count - 1) * rank_spacing * 0.5)
        state["front_center"] = front_center
        state["facing"] = desired_facing
        cohort_facing = desired_facing
        line_right = cohort_facing.cross(Vector3.UP).normalized()

    var target_from_front := target.global_position - front_center
    target_from_front.y = 0.0
    var target_depth := target_from_front.dot(cohort_facing)
    var target_lateral := target_from_front.dot(line_right)
    var formation_half_width := float(mini(columns, candidates.size()) - 1) * spacing * 0.5
    var formation_intrusion := (
        bool(state.get("formed", false))
        # The reaction begins as the player crosses the spear wall, not only once
        # he is already standing safely behind every shield.
        and target_depth < 0.72
        and absf(target_lateral) <= formation_half_width + 2.35
        and target_from_front.length() <= maxf(7.0, front_distance + float(row_count) * rank_spacing + 2.0)
    )
    if formation_intrusion and now >= float(state.get("breach_cooldown_until", 0.0)):
        # A penetrated spear wall has one clear doctrine: keep its mass together,
        # curve the shield front around the intruder, then press him back out.
        state["breach_tactic"] = &"expulsion_arc"
        state["breach_started_at"] = now
        state["breach_origin_front"] = front_center
        state["breach_origin_facing"] = cohort_facing
        state["breach_until"] = now + 5.6
        state["breach_cooldown_until"] = now + 5.8
        breach_until = float(state["breach_until"])

    if breach_until > now:
        var breach_slot: Dictionary = slots[soldier_id]
        var breach_progress := clampf((now - float(state.get("breach_started_at", now))) / 1.35, 0.0, 1.0)
        breach_progress = smoothstep(0.0, 1.0, breach_progress)
        var breach_assignment := _phalanx_expulsion_arc_assignment(
            soldier,
            target,
            desired_facing,
            int(breach_slot.get("row", 0)),
            int(breach_slot.get("column", 0)),
            int(breach_slot.get("slot", 0)),
            spacing,
            rank_spacing,
            front_distance,
            columns,
            state.get("breach_origin_front", front_center),
            state.get("breach_origin_facing", cohort_facing),
            breach_progress
        )
        state["last_seen"] = now
        phalanx_cohort_states[cohort_key] = state
        return _complete_phalanx_assignment(
            soldier,
            candidates,
            breach_assignment,
            veteran_count,
            true,
            &"expulsion_arc"
        )

    if not bool(state.get("formed", false)):
        var ready_count := 0
        for candidate: Node3D in candidates:
            var candidate_slot: Dictionary = slots.get(candidate.get_instance_id(), {})
            var candidate_row := int(candidate_slot.get("row", 0))
            var candidate_column := int(candidate_slot.get("column", 0))
            var staging_position := front_center + line_right * float(candidate_column) * spacing - cohort_facing * float(candidate_row) * rank_spacing
            if candidate.global_position.distance_to(staging_position) <= PHALANX_ASSEMBLY_TOLERANCE:
                ready_count += 1
        var required_ready := maxi(1, ceili(float(candidates.size()) * 0.90))
        if ready_count >= required_ready:
            state["formed"] = true
    elif elapsed > 0.0:
        # Once formed, only the shared anchor advances. Individual soldiers keep
        # following their relative slots, so the wall moves as one slow body.
        var desired_front_center := target.global_position - cohort_facing * maxf(front_distance, 1.8)
        var advance_delta: Vector3 = desired_front_center - front_center
        advance_delta.y = 0.0
        if advance_delta.length_squared() > 0.0001:
            front_center += advance_delta.normalized() * minf(advance_delta.length(), PHALANX_ADVANCE_SPEED * elapsed)
            state["front_center"] = front_center
    phalanx_cohort_states[cohort_key] = state

    var slot: Dictionary = slots[soldier_id]
    var row := int(slot.get("row", 0))
    var column := int(slot.get("column", 0))
    var position := front_center + line_right * float(column) * spacing - cohort_facing * float(row) * rank_spacing
    var previous_slot := int(phalanx_slot_history.get(soldier_id, -1))
    var current_slot := int(slot.get("slot", 0))
    phalanx_slot_history[soldier_id] = current_slot

    var nearby_allies := 0
    var nearby_veterans := 0
    var radius_squared := 4.6 * 4.6
    for candidate: Node3D in candidates:
        if candidate != soldier and candidate.global_position.distance_squared_to(soldier.global_position) <= radius_squared:
            nearby_allies += 1
            if StringName(candidate.get("behavior_mode")) == &"phalanx_veteran":
                nearby_veterans += 1
    return {
        "position": position,
        "facing": cohort_facing,
        "row": row,
        "column": column,
        "slot": current_slot,
        "slot_changed": previous_slot >= 0 and previous_slot != current_slot,
        "unit_count": candidates.size(),
        "nearby_allies": nearby_allies,
        "nearby_veterans": nearby_veterans,
        "veteran_count": veteran_count,
        "broken": candidates.size() < 2,
        "front_rank": row == 0,
        "cohort_formed": bool(state.get("formed", false)),
        "breach": false,
        "breach_tactic": &"none",
        "breach_role": &"line",
        "breach_can_attack": false,
    }

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
    var arc_angle := normalized_column * deg_to_rad(68.0)
    var arc_direction := Basis(Vector3.UP, arc_angle) * mass_direction
    var arc_radius := maxf(1.98, front_distance * 0.82) + float(row) * rank_spacing * 0.82
    # The centre presses closest; the curved tips retain enough room to slide
    # around the target instead of colliding with the middle shields.
    arc_radius += absf(normalized_column) * 0.20
    var arc_position := target.global_position + arc_direction.normalized() * arc_radius

    var origin_right := origin_facing.cross(Vector3.UP).normalized()
    var line_position := origin_front + origin_right * float(column) * spacing - origin_facing * float(row) * rank_spacing
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
    var previous_slot := int(phalanx_slot_history.get(soldier.get_instance_id(), -1))
    phalanx_slot_history[soldier.get_instance_id()] = current_slot
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
        return "%s:%s:%d" % [String(soldier.get("faction")), String(explicit_group), target.get_instance_id()]
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
    for node: Node in get_tree().get_nodes_in_group("phalanx_unit"):
        if not (node is Node3D) or not is_instance_valid(node):
            continue
        if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
            continue
        if StringName(node.get("faction")) != soldier_faction:
            continue
        var node_target: Variant = node.get("ai_player")
        if node_target != target:
            continue
        var candidate := node as Node3D
        var candidate_cohort := StringName(candidate.get_meta("formation_group", StringName()))
        if soldier_cohort != StringName():
            if candidate_cohort != soldier_cohort:
                continue
        elif candidate_cohort != StringName() or candidate.global_position.distance_to(soldier.global_position) > PHALANX_COHORT_RADIUS:
            continue
        result.append(candidate)
    result.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.get_instance_id() < b.get_instance_id())
    return result

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
    if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
        return false
    var target_id := target.get_instance_id()
    var attacker_id := attacker.get_instance_id()
    var permissions: Dictionary = attack_permissions.get(target_id, {})
    _remove_expired_permissions(permissions)
    var now := Time.get_ticks_msec() * 0.001
    if permissions.has(attacker_id):
        permissions[attacker_id] = now + ATTACK_PERMISSION_LIFETIME
        attack_permissions[target_id] = permissions
        return true
    if permissions.size() >= maxi(1, capacity):
        attack_permissions[target_id] = permissions
        return false
    permissions[attacker_id] = now + ATTACK_PERMISSION_LIFETIME
    attack_permissions[target_id] = permissions
    return true

func attack_capacity_for(target: Node3D) -> int:
    # More bodies should create tactical pressure, not an unreadable blender.
    # Dense groups gain one extra attacker while the rest hold wings/reserve.
    var pressure := local_pressure(target)
    if pressure >= 10:
        return 3
    return 2

func local_pressure(target: Node3D) -> int:
    if target == null or not is_instance_valid(target):
        return 0
    var center := _cell_for(target.global_position)
    var cell_radius := ceili(PRESSURE_RADIUS / cell_size)
    var radius_squared := PRESSURE_RADIUS * PRESSURE_RADIUS
    var count := 0
    for offset_x: int in range(-cell_radius, cell_radius + 1):
        for offset_z: int in range(-cell_radius, cell_radius + 1):
            var key := Vector2i(center.x + offset_x, center.y + offset_z)
            if not spatial_grid.has(key):
                continue
            for value: Variant in spatial_grid[key]:
                if value is Node3D and (value as Node3D).global_position.distance_squared_to(target.global_position) <= radius_squared:
                    count += 1
    return count

func release_attack_permission(attacker: Node3D, target: Node3D) -> void:
    if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
        return
    var target_id := target.get_instance_id()
    if not attack_permissions.has(target_id):
        return
    var permissions: Dictionary = attack_permissions[target_id]
    permissions.erase(attacker.get_instance_id())
    if permissions.is_empty():
        attack_permissions.erase(target_id)
    else:
        attack_permissions[target_id] = permissions

func _first_free_engagement_slot(assignments: Dictionary) -> int:
    var occupied: Dictionary = _occupied_engagement_slots(assignments, -1)
    var slot: int = 0
    while occupied.has(slot):
        slot += 1
    return slot

func _occupied_engagement_slots(assignments: Dictionary, ignored_attacker_id: int) -> Dictionary:
    var occupied: Dictionary = {}
    for raw_attacker_id: Variant in assignments.keys():
        if int(raw_attacker_id) == ignored_attacker_id:
            continue
        occupied[int(assignments[raw_attacker_id])] = true
    return occupied

func _cleanup_engagement_slots() -> void:
    var living_ids: Dictionary = {}
    for node: Node in get_tree().get_nodes_in_group("combatant_ai"):
        if node is Node3D and (not node.has_method("is_dead_for_combat") or not bool(node.call("is_dead_for_combat"))):
            living_ids[(node as Node3D).get_instance_id()] = true
    for node: Node in get_tree().get_nodes_in_group("player"):
        if node is Node3D:
            living_ids[(node as Node3D).get_instance_id()] = true

    for raw_target_id: Variant in engagement_slots.keys():
        var target_id: int = int(raw_target_id)
        if not living_ids.has(target_id):
            engagement_slots.erase(target_id)
            engagement_frames.erase(target_id)
            continue
        var assignments: Dictionary = engagement_slots[target_id]
        for raw_attacker_id: Variant in assignments.keys():
            if not living_ids.has(int(raw_attacker_id)):
                assignments.erase(raw_attacker_id)
        if assignments.is_empty():
            engagement_slots.erase(target_id)
            engagement_frames.erase(target_id)
        else:
            engagement_slots[target_id] = assignments

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

    for raw_soldier_id: Variant in phalanx_slot_history.keys():
        if not living_ids.has(int(raw_soldier_id)):
            phalanx_slot_history.erase(raw_soldier_id)

    var now := Time.get_ticks_msec() * 0.001
    for cohort_key: Variant in phalanx_cohort_states.keys():
        var state: Dictionary = phalanx_cohort_states[cohort_key]
        if now - float(state.get("last_seen", now)) > 2.0:
            phalanx_cohort_states.erase(cohort_key)

func _remove_expired_permissions(permissions: Dictionary, living_ids: Dictionary = {}) -> void:
    var now := Time.get_ticks_msec() * 0.001
    for raw_attacker_id: Variant in permissions.keys():
        var attacker_id := int(raw_attacker_id)
        var expired := float(permissions[raw_attacker_id]) <= now
        var no_longer_living := not living_ids.is_empty() and not living_ids.has(attacker_id)
        if expired or no_longer_living:
            permissions.erase(raw_attacker_id)

func _cell_for(world_position: Vector3) -> Vector2i:
    return Vector2i(floori(world_position.x / cell_size), floori(world_position.z / cell_size))
