extends RefCounted
class_name EnemyV2FrontDirector

## World-space missions. Fronts outlive individual groups and only relocate
## after the player has actually left their operating area.
const Capabilities = preload("res://scripts/enemy_v2/enemy_v2_unit_capabilities.gd")
var fire_lane_validator: Callable
var fronts: Dictionary = {}
var observations: Dictionary = {}

func update(records: Dictionary, target_id: int, target: Node3D, now: int = -1) -> void:
	if target == null or not is_instance_valid(target):
		return
	if now < 0:
		now = Time.get_ticks_msec()
	var player := target.global_position
	var observation: Dictionary = observations.get(target_id, {"position": player, "time": now, "velocity": Vector3.ZERO})
	var dt := float(now - int(observation["time"])) / 1000.0
	if dt >= 0.1:
		var sampled := (player - (observation["position"] as Vector3)) / dt
		sampled.y = 0.0
		# A leap/teleport must not become perfect landing prediction.
		if sampled.length() > 18.0:
			sampled = Vector3.ZERO
		observation["velocity"] = (observation["velocity"] as Vector3).lerp(sampled, 0.35)
		observation["position"] = player
		observation["time"] = now
	observations[target_id] = observation
	var predicted := player + (observation["velocity"] as Vector3).limit_length(8.0) * 0.6
	var grouped: Dictionary = {}
	for id: Variant in records:
		var record: Dictionary = records[id]
		if int(record["target_id"]) != target_id or not bool(record.get("persistent_fronts", false)):
			continue
		var key := "%d:%s" % [target_id, record["front_id"]]
		if not grouped.has(key):
			grouped[key] = []
		grouped[key].append(id)
		if not fronts.has(key):
			fronts[key] = {"origin": record["front_origin"], "forward": record["front_forward"], "away_since": 0,
				"breach_until": 0, "breach_at": 0, "breach_position": Vector3.ZERO, "revision": 1}
	for key: String in grouped:
		var front: Dictionary = fronts[key]
		var origin: Vector3 = front["origin"]
		if _distance(origin, player) > 48.0:
			if int(front["away_since"]) == 0:
				front["away_since"] = now
			elif now - int(front["away_since"]) > 2400:
				front["origin"] = origin + (player - origin).limit_length(18.0)
				front["away_since"] = now
				front["revision"] = int(front["revision"]) + 1
		else:
			front["away_since"] = 0
		var phalanxes: Array = []
		for id: Variant in grouped[key]:
			var record: Dictionary = records[id]
			var cap: EnemyV2UnitCapabilities = record["capabilities"]
			if cap.role == &"phalanx":
				phalanxes.append(id)
			if int(record.get("disorganized_until", 0)) > int(front["breach_until"]):
				front["breach_until"] = record["disorganized_until"]
				front["breach_at"] = now
				front["breach_position"] = record["current_anchor"]
		phalanxes.sort_custom(func(a: Variant, b: Variant) -> bool:
			return _assignment_cost(records[a], front) < _assignment_cost(records[b], front))
		for id: Variant in grouped[key]:
			var record: Dictionary = records[id]
			var cap: EnemyV2UnitCapabilities = record["capabilities"]
			var current: Vector3 = record["current_anchor"]
			var home: Vector3 = (record["home_anchor"] as Vector3) + ((front["origin"] as Vector3) - (record["front_origin"] as Vector3))
			var forward: Vector3 = front["forward"]
			var right := Vector3.UP.cross(forward).normalized()
			var goal: Vector3 = front["origin"]
			var facing := forward
			var role: StringName = cap.role
			var mission: StringName = &"hold_line"
			var rank := phalanxes.find(id)
			var disorganized := now < int(record.get("disorganized_until", 0))
			var front_open := now < int(front["breach_until"])
			var target_distance := _distance(current, player)
			if cap.role == &"phalanx":
				role = &"frontline" if rank == 0 else (&"support" if rank == 1 else &"reserve")
				# Rank destinations lie on one axis, with clear lateral supply lanes.
				goal -= forward * (16.0 if rank == 1 else (48.0 + float(maxi(0, rank - 2)) * 16.0 if rank >= 2 else 0.0))
				if rank >= 1:
					goal += right * (2.0 if rank % 2 == 1 else -2.0)
				if rank == 0 and not front_open:
					var depth := (player - goal).dot(forward)
					goal += forward * clampf(depth - cap.preferred_range, 0.0, 12.0)
					mission = &"push_front"
				if disorganized:
					goal = current
					mission = &"reform"
				elif front_open and rank == 0:
					goal = current
					mission = &"hold_breach"
				# Adjacent front reacts late, without filling the player's passage.
				for other_key: String in fronts:
					if other_key == key or rank != 0 or not other_key.begins_with("%d:" % target_id):
						continue
					var other: Dictionary = fronts[other_key]
					if now < int(other["breach_until"]) and now - int(other["breach_at"]) >= 700 and _distance(current, other["breach_position"]) < 30.0:
						facing = _direction(current, other["breach_position"], forward)
						mission = &"cover_flank"
			elif cap.role == &"archer":
				goal = home
				if _distance(goal, player) < 12.0:
					goal += _direction(player, goal, -forward) * 6.0
				elif _distance(goal, player) > 32.0:
					goal += _direction(goal, predicted, forward) * minf(10.0, _distance(goal, player) - 27.0)
				goal = home + (goal - home).limit_length(cap.pursuit_leash)
				facing = _direction(current, player, forward)
				mission = &"support_fire"
				if fire_lane_validator.is_valid() and not bool(fire_lane_validator.call(StringName(id), goal, player)):
					var best_cost := INF
					for offset: float in [-6.0, 6.0, -10.0, 10.0]:
						var candidate := home + right * offset
						var distance := _distance(candidate, player)
						if distance < 10.0 or distance > 33.0:
							continue
						if bool(fire_lane_validator.call(StringName(id), candidate, player)):
							var cost := _distance(current, candidate) + absf(distance - 22.0) * 0.25
							if cost < best_cost:
								best_cost = cost
								goal = candidate
					mission = &"reposition_fire"
				role = &"ranged"
			elif cap.role == &"giant":
				goal = predicted - _direction(current, predicted, forward) * cap.preferred_range
				# Advance along the deployment avenue before converging on the player.
				# A diagonal intercept from the rear would cut through allied ranks.
				if (predicted - current).dot(forward) > 16.0:
					goal = home + forward * maxf(0.0, (predicted - home).dot(forward) - 12.0)
				goal = home + (goal - home).limit_length(cap.pursuit_leash)
				facing = _direction(current, player, forward)
				mission = &"zone_pressure"
			else:
				# Short, imperfect interception; no army-wide pursuit of every feint.
				goal = predicted - _direction(current, predicted, forward) * cap.preferred_range
				goal += right * float(int(record["registration_order"]) % 3 - 1) * 3.0
				goal = home + (goal - home).limit_length(cap.pursuit_leash)
				facing = _direction(current, player, forward)
				mission = &"intercept" if _distance(home, player) <= cap.pursuit_leash else &"hold_flank"
				role = &"skirmish"
			goal.y = current.y
			# Hold each mission long enough to read it and avoid order thrashing.
			var previous: Dictionary = record.get("assignment", {})
			if not previous.is_empty() and now < int(record.get("mission_until", 0)) and not disorganized and mission == previous.get("mission"):
				goal = previous.get("position", goal)
			else:
				record["mission_until"] = now + (1600 if cap.role == &"phalanx" else 1100)
			record["admitted"] = rank == 0 and cap.role == &"phalanx"
			record["approach_phase"] = &"none"
			record["assignment"] = {"position": goal, "facing": facing, "role": role, "mission": mission,
				"engage": not disorganized and (rank == 0 or cap.role != &"phalanx"), "ring": maxi(0, rank),
				"slot": record["front_id"], "angle": atan2(forward.z, forward.x), "radius": target_distance,
				"front_revision": front["revision"], "disorganized": disorganized}
			if record.has("command_assignment"):
				record["assignment"] = record["command_assignment"].duplicate()
				if disorganized:
					record["assignment"]["disorganized"] = true
					record["assignment"]["engage"] = false


func _assignment_cost(record: Dictionary, front: Dictionary) -> float:
	var cap: EnemyV2UnitCapabilities = record["capabilities"]
	var cost := _distance(record["current_anchor"], front["origin"]) / maxf(0.5, cap.move_speed)
	cost += (1.0 - (record["forward"] as Vector3).dot(front["forward"])) * 3.0
	if bool(record.get("admitted", false)):
		cost -= 9.0
	if int(record.get("member_count", 0)) <= int(record.get("original_count", 1)) / 4:
		cost += 30.0
	return cost

static func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func _direction(a: Vector3, b: Vector3, fallback: Vector3) -> Vector3:
	var offset := b - a
	offset.y = 0.0
	return offset.normalized() if offset.length_squared() > 0.001 else fallback
