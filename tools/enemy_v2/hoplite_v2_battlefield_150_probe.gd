extends SceneTree

const WorldDocument = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntime = preload("res://scripts/world_editor/world_runtime.gd")
const HopliteV2TroopRuntime = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")

const WORLD_PATH := "user://hoplite_worlds/champsdebataille_v2_150.hoplite.json"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
	_expect(file != null, "champsDeBataille_V2_150 is missing")
	if file == null:
		_finish()
		return
	var document := WorldDocument.from_json(file.get_as_text())
	file.close()
	_expect(document != null, "champsDeBataille_V2_150 is invalid")
	if document == null:
		_finish()
		return
	var authored_total := 0
	var authored_phalanxes := 0
	for raw: Variant in document.data.get("entities", []):
		if raw is Dictionary and _is_reference_stress_group(raw as Dictionary):
			var properties := (raw as Dictionary).get("properties", {}) as Dictionary
			authored_total += int(properties.get("count", 0))
			if StringName(properties.get("v2_troop_mode", &"")) == &"hoplite_phalanx":
				authored_phalanxes += 1
	_expect(authored_total == 150, "battlefield must author exactly 150 soldiers")
	_expect(authored_phalanxes == 6, "battlefield must author six coordinated phalanxes")

	var runtime := WorldRuntime.new()
	get_root().add_child(runtime)
	runtime.editing = false
	runtime.world_root = Node3D.new()
	runtime.world_root.name = "Battlefield150ProbeRoot"
	runtime.add_child(runtime.world_root)
	runtime.enemy_v2_troop_runtime = HopliteV2TroopRuntime.new()
	runtime.enemy_v2_troop_runtime.name = "EnemyV2TroopRuntime"
	runtime.world_root.add_child(runtime.enemy_v2_troop_runtime)
	var target := Node3D.new()
	target.name = "LightweightPlayerTarget"
	target.position = Vector3(0.0, 0.0, 20.0)
	runtime.world_root.add_child(target)
	for raw: Variant in document.data.get("entities", []):
		if not raw is Dictionary or not _is_reference_stress_group(raw as Dictionary):
			continue
		var entity := raw as Dictionary
		var holder := Node3D.new()
		holder.name = String(entity.get("name", "EnemyGroup")).validate_node_name()
		holder.position = WorldDocument.vector3(entity.get("position", []))
		holder.rotation_degrees = WorldDocument.vector3(entity.get("rotation", []))
		runtime.world_root.add_child(holder)
		runtime.spawn_enemy_group(entity, target, holder, -1, 0, true)
	var spawned_total := 0
	var troop_controlled_total := 0
	for raw_enemies: Variant in runtime.enemies_by_group.values():
		for actor: Node in raw_enemies as Array:
			if actor == null or not is_instance_valid(actor):
				continue
			spawned_total += 1
			if bool(actor.get("troop_controlled")):
				troop_controlled_total += 1
	_expect(spawned_total == 150, "battlefield runtime did not spawn 150 soldiers")
	_expect(troop_controlled_total == 150, "all six phalanxes and the veteran squad must use shared troop control")
	var troop_runtime := runtime.enemy_v2_troop_runtime
	_expect(troop_runtime != null, "battlefield has no EnemyV2 TroopRuntime")
	if troop_runtime != null:
		_expect(troop_runtime.groups.size() == 7, "battlefield did not register six phalanxes plus one skirmish brain")
		var initial_goal_errors: Dictionary = {}
		var phalanx_count := 0
		var skirmish_count := 0
		for raw_group_id: Variant in troop_runtime.groups.keys():
			var snapshot := troop_runtime.group_snapshot(StringName(raw_group_id))
			if StringName(snapshot.get("mode", &"")) == &"hoplite_phalanx":
				phalanx_count += 1
				_expect(int(snapshot.get("member_count", 0)) == 24, "a battlefield phalanx lost its 24-member contract")
				_expect(int(snapshot.get("front_rank_count", 0)) == 8, "a battlefield phalanx lost its eight-unit front rank")
			else:
				skirmish_count += 1
				_expect(int(snapshot.get("member_count", 0)) == 6, "the veteran squad lost its six-member contract")
				_expect(int(snapshot.get("front_rank_count", 0)) == 3, "the veteran squad did not use a compact three-wide front")
			initial_goal_errors[StringName(raw_group_id)] = float(snapshot.get("strategic_goal_error", INF))
		_expect(phalanx_count == 6 and skirmish_count == 1, "battlefield troop modes are not split into six phalanxes and one skirmish squad")
		troop_runtime.set_process(false)
		var ticks_before := troop_runtime.total_decision_ticks
		for frame in range(60):
			troop_runtime._process(1.0 / 60.0)
		var ticks_for_one_second := troop_runtime.total_decision_ticks - ticks_before
		_expect(ticks_for_one_second <= 70, "troop decisions exceeded the seven-group cadence budget")
		var frontline_count := 0
		var support_count := 0
		var reserve_count := 0
		var approach_count := 0
		var skirmish_role_count := 0
		for raw_group_id: Variant in troop_runtime.groups.keys():
			var snapshot := troop_runtime.group_snapshot(StringName(raw_group_id))
			_expect(
				float(snapshot.get("strategic_goal_error", INF)) <= float(initial_goal_errors.get(StringName(raw_group_id), INF)) + 0.05,
				"a battlefield troop moved away from its reserved military sector"
			)
			match StringName(snapshot.get("battle_role", &"")):
				&"frontline": frontline_count += 1
				&"support": support_count += 1
				&"reserve": reserve_count += 1
				&"approach": approach_count += 1
				&"skirmish": skirmish_role_count += 1
		_expect(
			frontline_count >= 0
			and frontline_count <= 4
			and approach_count <= 1
			and frontline_count + support_count + reserve_count + approach_count == 6
			and skirmish_role_count == 1,
			"strategic layout did not maintain bounded contacts, depth ranks, staged approach, and the independent skirmish squad"
		)
		# Regression: killing the authored front rank must promote a new line instead
		# of leaving the whole formation without attack permissions.
		for raw_group_id: Variant in troop_runtime.groups.keys():
			var group_id := StringName(raw_group_id)
			var snapshot := troop_runtime.group_snapshot(group_id)
			if StringName(snapshot.get("mode", &"")) != &"hoplite_phalanx":
				continue
			var state := troop_runtime.groups[group_id] as Dictionary
			var former_front := (state["front_rank"] as Array).duplicate()
			var members_by_id: Dictionary = {}
			for member: Node3D in state["members"] as Array:
				members_by_id[member.get_instance_id()] = member
			for raw_member_id: Variant in former_front:
				troop_runtime.unregister_member(group_id, members_by_id[int(raw_member_id)] as Node)
			var reflowed := troop_runtime.group_snapshot(group_id)
			_expect(int(reflowed.get("member_count", 0)) == 16, "front-rank casualties did not persist in the troop state")
			_expect(int(reflowed.get("front_rank_count", 0)) == 8, "survivors were not promoted into a new attack-capable front rank")
			break
	runtime.free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("HOPLITE_V2_BATTLEFIELD_150_PROBE PASS: soldiers=150 phalanxes=6 skirmish=1 troop_members=150 strategic_sectors=7")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 BATTLEFIELD 150] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


static func _is_reference_stress_group(entity: Dictionary) -> bool:
	if String(entity.get("type", "")) != "enemy_group":
		return false
	var properties := entity.get("properties", {}) as Dictionary
	return String(properties.get("group_id", "")).begins_with("stress_v2_")
