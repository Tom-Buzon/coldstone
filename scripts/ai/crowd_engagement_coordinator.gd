extends RefCounted
class_name HopliteCrowdEngagementCoordinator

## Target-centric individual engagement layout.
##
## The battle director remains the public facade. This light service owns only
## assignment data: proximity-driven contact handoff, low-travel angular slots,
## rotating reserve rings and the non-rotating inner boss pocket. It owns no
## Nodes and performs no movement.

var settings: Dictionary = {}
var slots: Dictionary = {}
var frames: Dictionary = {}
var records: Dictionary = {}
var next_registration_order: int = 1
var rebalance_after: Dictionary = {}


func configure(next_settings: Dictionary) -> void:
	settings = next_settings.duplicate(true)
	rebalance_after.clear()


func assignment(
	attacker: Node3D,
	target: Node3D,
	preferred_radius: float,
	participant: Dictionary
) -> Dictionary:
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return _invalid_assignment(target)
	if StringName(participant.get("formation_kind", &"individual")) == &"phalanx":
		release(attacker, target)
		return {
			"position": attacker.global_position,
			"role": &"formation_external",
			"attack_ready": false,
			"ring": -1,
			"slot": -1,
		}

	var target_id := target.get_instance_id()
	var attacker_id := attacker.get_instance_id()
	var target_records: Dictionary = records.get(target_id, {})
	var record: Dictionary = target_records.get(attacker_id, {})
	var needs_rebuild := record.is_empty()
	if record.is_empty():
		record = {
			"registration_order": next_registration_order,
		}
		next_registration_order += 1
	var previous_role := StringName(record.get("role", &"melee"))
	var next_role := StringName(participant.get("crowd_role", &"melee"))
	record["role"] = next_role
	needs_rebuild = needs_rebuild or previous_role != next_role
	record["preferred_radius"] = preferred_radius
	record["distance_squared"] = attacker.global_position.distance_squared_to(target.global_position)
	var from_target := attacker.global_position - target.global_position
	from_target.y = 0.0
	record["polar_angle"] = atan2(from_target.z, from_target.x) if from_target.length_squared() > 0.001 else _base_angle(target_id)
	var now := Time.get_ticks_msec() * 0.001
	record["last_seen"] = now
	target_records[attacker_id] = record
	records[target_id] = target_records
	_ensure_frame(attacker, target)
	var refresh_hz := maxf(1.0, float(settings.get(&"contact_rebalance_hz", 10.0)))
	if needs_rebuild or now >= float(rebalance_after.get(target_id, 0.0)):
		_rebuild_target_slots(target_id)
		rebalance_after[target_id] = now + 1.0 / refresh_hz
	record = (records[target_id] as Dictionary)[attacker_id]

	var crowd_role := StringName(record.get("role", &"melee"))
	if crowd_role == &"boss":
		return _boss_assignment(target, attacker_id)
	var ring := int(record.get("assigned_ring", 1))
	var ring_slot := int(record.get("ring_slot", 0))
	var angle := _ring_angle(target_id, ring, ring_slot, maxi(1, int(settings.get(&"slots_per_ring", 6.0))))
	var radius := float(settings.get(&"contact_radius", 1.78)) + float(ring) * float(settings.get(&"ring_spacing", 1.18))
	if crowd_role == &"ranged":
		radius = maxf(radius, preferred_radius)
	var assigned_position := target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	var slot_tolerance := maxf(0.1, float(settings.get(&"contact_slot_tolerance", 0.90)))
	var contact_reached := attacker.global_position.distance_squared_to(assigned_position) <= slot_tolerance * slot_tolerance
	var role := &"reserve"
	if ring == 0:
		role = &"line" if ring_slot in [0, 1] else &"wing"
	return {
		"position": assigned_position,
		"role": role,
		"attack_ready": ring == 0 and contact_reached,
		"contact_assigned": ring == 0,
		"contact_reached": contact_reached,
		"ring": ring,
		"slot": int(record.get("published_slot", ring_slot)),
		"rotates": true,
	}


func release(attacker: Node3D, target: Node3D) -> void:
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	var target_id := target.get_instance_id()
	if not records.has(target_id):
		return
	var target_records: Dictionary = records[target_id]
	target_records.erase(attacker.get_instance_id())
	if target_records.is_empty():
		records.erase(target_id)
		slots.erase(target_id)
		frames.erase(target_id)
		rebalance_after.erase(target_id)
		return
	records[target_id] = target_records
	rebalance_after[target_id] = 0.0


func cleanup(living_ids: Dictionary) -> void:
	for raw_target_id: Variant in records.keys():
		var target_id := int(raw_target_id)
		if not living_ids.has(target_id):
			records.erase(target_id)
			slots.erase(target_id)
			frames.erase(target_id)
			rebalance_after.erase(target_id)
			continue
		var target_records: Dictionary = records[target_id]
		for raw_attacker_id: Variant in target_records.keys():
			if not living_ids.has(int(raw_attacker_id)):
				target_records.erase(raw_attacker_id)
		if target_records.is_empty():
			records.erase(target_id)
			slots.erase(target_id)
			frames.erase(target_id)
			rebalance_after.erase(target_id)
		else:
			records[target_id] = target_records
			rebalance_after[target_id] = 0.0


func _rebuild_target_slots(target_id: int) -> void:
	if not records.has(target_id):
		return
	var target_records: Dictionary = records[target_id]
	var melee_ids: Array[int] = []
	var ranged_ids: Array[int] = []
	var boss_ids: Array[int] = []
	for raw_id: Variant in target_records.keys():
		var actor_id := int(raw_id)
		match StringName((target_records[raw_id] as Dictionary).get("role", &"melee")):
			&"boss": boss_ids.append(actor_id)
			&"ranged": ranged_ids.append(actor_id)
			_: melee_ids.append(actor_id)
	var contact_hysteresis := maxf(0.0, float(settings.get(&"contact_swap_hysteresis", 0.45)))
	var sorter := func(a: int, b: int) -> bool:
		var a_record := target_records[a] as Dictionary
		var b_record := target_records[b] as Dictionary
		var a_distance := sqrt(float(a_record.get("distance_squared", INF)))
		var b_distance := sqrt(float(b_record.get("distance_squared", INF)))
		if int(a_record.get("assigned_ring", 1)) == 0:
			a_distance -= contact_hysteresis
		if int(b_record.get("assigned_ring", 1)) == 0:
			b_distance -= contact_hysteresis
		if not is_equal_approx(a_distance, b_distance):
			return a_distance < b_distance
		return int(a_record.get("registration_order", 0)) < int(b_record.get("registration_order", 0))
	melee_ids.sort_custom(sorter)
	ranged_ids.sort_custom(sorter)
	boss_ids.sort_custom(sorter)
	var published: Dictionary = {}
	var ring_capacity := maxi(1, int(settings.get(&"slots_per_ring", 6.0)))
	var contact_angles := _available_ring_angles(target_id, 0)
	var contact_count := mini(melee_ids.size(), contact_angles.size())
	_assign_ring(target_records, melee_ids.slice(0, contact_count), 0, contact_angles, 0, published)
	var melee_cursor := contact_count
	var melee_ring := 1
	while melee_cursor < melee_ids.size():
		var ring_end := mini(melee_cursor + ring_capacity, melee_ids.size())
		var ring_angles: Array[float] = []
		for slot_index: int in range(ring_capacity):
			ring_angles.append(_ring_angle(target_id, melee_ring, slot_index, ring_capacity))
		_assign_ring(target_records, melee_ids.slice(melee_cursor, ring_end), melee_ring, ring_angles, melee_ring * 100, published)
		melee_cursor = ring_end
		melee_ring += 1

	var ranged_cursor := 0
	var ranged_ring := maxi(1, int(settings.get(&"ranged_min_ring", 2.0)))
	while ranged_cursor < ranged_ids.size():
		var ranged_end := mini(ranged_cursor + ring_capacity, ranged_ids.size())
		var ranged_angles: Array[float] = []
		for slot_index: int in range(ring_capacity):
			ranged_angles.append(_ring_angle(target_id, ranged_ring, slot_index, ring_capacity))
		_assign_ring(target_records, ranged_ids.slice(ranged_cursor, ranged_end), ranged_ring, ranged_angles, 10000 + ranged_ring * 100, published)
		ranged_cursor = ranged_end
		ranged_ring += 1
	for index: int in range(boss_ids.size()):
		var record := target_records[boss_ids[index]] as Dictionary
		record["lane_slot"] = index
		record["assigned_ring"] = -1
		record["published_slot"] = -1000 - index
		target_records[boss_ids[index]] = record
		published[boss_ids[index]] = -1000 - index
	records[target_id] = target_records
	slots[target_id] = published


func _assign_ring(
	target_records: Dictionary,
	actor_ids: Array,
	ring: int,
	angles: Array[float],
	published_base: int,
	published: Dictionary
) -> void:
	if actor_ids.is_empty() or angles.is_empty():
		return
	var free_slots: Array[int] = []
	for index: int in range(angles.size()):
		free_slots.append(index)
	for raw_actor_id: Variant in actor_ids:
		var actor_id := int(raw_actor_id)
		var record := target_records[actor_id] as Dictionary
		var polar_angle := float(record.get("polar_angle", angles[0]))
		var best_free_index := 0
		var best_cost := INF
		for free_index: int in range(free_slots.size()):
			var slot_index := free_slots[free_index]
			var cost := absf(wrapf(angles[slot_index] - polar_angle, -PI, PI))
			if cost < best_cost:
				best_cost = cost
				best_free_index = free_index
		var ring_slot: int = free_slots.pop_at(best_free_index)
		record["assigned_ring"] = ring
		record["ring_slot"] = ring_slot
		record["assigned_angle"] = angles[ring_slot]
		record["published_slot"] = published_base + ring_slot
		target_records[actor_id] = record
		published[actor_id] = int(record["published_slot"])


func _boss_assignment(target: Node3D, attacker_id: int) -> Dictionary:
	var target_id := target.get_instance_id()
	var record := (records[target_id] as Dictionary)[attacker_id] as Dictionary
	var index := int(record.get("lane_slot", 0))
	var boss_count := 1
	for raw_record: Variant in (records[target_id] as Dictionary).values():
		if StringName((raw_record as Dictionary).get("role", &"melee")) == &"boss":
			boss_count += 1
	boss_count = maxi(1, boss_count - 1)
	var base_angle := _base_angle(target_id)
	var angle := base_angle + float(index) * TAU / float(boss_count)
	var radius := float(settings.get(&"boss_inner_radius", 1.05))
	return {
		"position": target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius,
		"role": &"inner_boss",
		"attack_ready": true,
		"ring": -1,
		"slot": int(record.get("published_slot", -1000)),
		"rotates": false,
	}


func _ring_angle(target_id: int, ring: int, ring_slot: int, count: int) -> float:
	var stagger := 0.5 if (ring % 2) == 1 else 0.0
	return _base_angle(target_id) + (float(ring_slot) + stagger) * TAU / float(count) + _ring_phase(target_id, ring)


func _available_ring_angles(target_id: int, ring: int) -> Array[float]:
	var count := maxi(1, int(settings.get(&"slots_per_ring", 6.0)))
	var base_angle := _base_angle(target_id)
	var phase := _ring_phase(target_id, ring)
	var stagger := 0.5 if (ring % 2) == 1 else 0.0
	var result: Array[float] = []
	for index: int in range(count):
		result.append(base_angle + (float(index) + stagger) * TAU / float(count) + phase)
	return result


func _ensure_frame(attacker: Node3D, target: Node3D) -> void:
	var target_id := target.get_instance_id()
	if frames.has(target_id):
		return
	var forward := attacker.global_position - target.global_position
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = -target.global_basis.z
		forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	frames[target_id] = {
		"forward": forward.normalized(),
		"started_at": Time.get_ticks_msec() * 0.001,
	}


func _base_angle(target_id: int) -> float:
	var frame: Dictionary = frames.get(target_id, {})
	var forward: Vector3 = frame.get("forward", Vector3.FORWARD)
	return atan2(forward.z, forward.x)


func _ring_phase(target_id: int, ring: int) -> float:
	var frame: Dictionary = frames.get(target_id, {})
	var elapsed := maxf(0.0, Time.get_ticks_msec() * 0.001 - float(frame.get("started_at", 0.0)))
	var base_speed := deg_to_rad(float(settings.get(&"rotation_speed_degrees", 7.5)))
	var variation := float(settings.get(&"rotation_variation", 0.18))
	var deterministic_variation := (float((target_id + ring * 17) % 11) / 10.0 - 0.5) * 2.0 * variation
	var scale := float(settings.get(&"contact_rotation_scale", 0.35)) if ring == 0 else 1.0 + deterministic_variation
	var direction := -1.0 if (ring % 2) == 1 else 1.0
	return elapsed * base_speed * scale * direction


func _invalid_assignment(target: Node3D) -> Dictionary:
	return {
		"position": target.global_position if target != null and is_instance_valid(target) else Vector3.ZERO,
		"role": &"invalid",
		"attack_ready": false,
		"ring": -1,
		"slot": -1,
	}
