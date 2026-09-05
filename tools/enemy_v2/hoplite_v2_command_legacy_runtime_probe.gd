extends SceneTree

const WorldDocument = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntime = preload("res://scripts/world_editor/world_runtime.gd")
const TroopRuntime = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")

const WORLD_PATH := "user://hoplite_worlds/champsdebataille_v2_commandement_414_before_combined_arms_20260905.hoplite.json"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
	_expect(file != null, "command laboratory world is missing")
	if file == null:
		_finish(0, 0)
		return
	var document := WorldDocument.from_json(file.get_as_text())
	file.close()
	_expect(document != null, "command laboratory world is invalid")
	if document == null:
		_finish(0, 0)
		return
	var original_lod_settings: Dictionary = {}
	for raw_key: Variant in WorldRuntime.WORLD_ENEMY_LOD_SETTING_KEYS.values():
		var project_key := String(raw_key)
		original_lod_settings[project_key] = ProjectSettings.get_setting(project_key)
	var runtime := WorldRuntime.new()
	root.add_child(runtime)
	runtime.document = document
	runtime.call("_apply_document_runtime_overrides")
	_expect(float(ProjectSettings.get_setting("hoplite/enemy_lod/cull_distance", 0.0)) == 65.0, "the command laboratory did not apply its own LOD profile")
	runtime.editing = false
	runtime.world_root = Node3D.new()
	runtime.world_root.name = "CommandLabRuntimeProbeRoot"
	runtime.add_child(runtime.world_root)
	runtime.enemy_v2_troop_runtime = TroopRuntime.new()
	runtime.enemy_v2_troop_runtime.name = "EnemyV2TroopRuntime"
	runtime.world_root.add_child(runtime.enemy_v2_troop_runtime)
	var target := Node3D.new()
	target.name = "CommandLabPlayerTarget"
	for raw: Variant in document.data.get("entities", []):
		if raw is Dictionary and String((raw as Dictionary).get("type", "")) == "player_spawn":
			target.position = WorldDocument.vector3((raw as Dictionary).get("position", []))
			break
	runtime.world_root.add_child(target)
	var spawn_started := Time.get_ticks_msec()
	for raw: Variant in document.data.get("entities", []):
		if not raw is Dictionary:
			continue
		var entity := raw as Dictionary
		if String(entity.get("type", "")) != "enemy_group":
			continue
		var holder := Node3D.new()
		holder.name = String(entity.get("name", "EnemyGroup")).validate_node_name()
		holder.position = WorldDocument.vector3(entity.get("position", []))
		holder.rotation_degrees = WorldDocument.vector3(entity.get("rotation", []))
		runtime.world_root.add_child(holder)
		runtime.spawn_enemy_group(entity, target, holder, -1, 0, true)
	var spawn_msec := Time.get_ticks_msec() - spawn_started
	var troop_runtime := runtime.enemy_v2_troop_runtime
	_expect(troop_runtime.groups.size() == 18, "runtime did not register 17 phalanxes and one pressure squad")
	var spawned := 0
	for raw_members: Variant in runtime.enemies_by_group.values():
		spawned += (raw_members as Array).size()
	_expect(spawned == 414, "runtime did not instantiate all 414 command-lab soldiers")
	troop_runtime.set_process(false)
	var command_started := Time.get_ticks_usec()
	for frame: int in range(60):
		troop_runtime._process(1.0 / 60.0)
	var command_usec := Time.get_ticks_usec() - command_started
	var snapshot := troop_runtime.debug_snapshot()
	print("HOPLITE_V2_COMMAND_LAB_RUNTIME_SNAPSHOT ", snapshot)
	var roles := snapshot.get("roles", {}) as Dictionary
	var lod_counts := snapshot.get("lod_counts", []) as Array
	_expect(int(roles.get(&"frontline", 0)) == 4, "runtime lost the four active fronts")
	_expect(int(roles.get(&"support", 0)) == 4, "runtime lost the first support rank")
	_expect(int(roles.get(&"reserve", 0)) == 9, "runtime lost the reserve depth")
	_expect(int(roles.get(&"skirmish", 0)) == 1, "runtime lost the pressure squad")
	_expect(lod_counts.size() == 4 and int(lod_counts[3]) >= 200, "far reserves did not enter the intended impostor LOD")
	_expect(int(snapshot.get("impostors", 0)) == int(lod_counts[3]), "LOD3 soldiers and shared impostor batch disagree")
	_expect(int(snapshot.get("corridors", 0)) <= 4, "formation traffic exceeded its bounded corridor budget")
	_expect(int(snapshot.get("anchor_conflicts", 0)) == 0, "the initial command lab contains overlapping formation anchors")
	_expect(int(snapshot.get("wrong_way_attacks", 0)) == 0, "the initial command lab contains a backwards attack")
	_expect(command_usec < 250000, "one simulated second of formation command exceeded 250 ms wall time")
	_test_dynamic_micro_behaviors(troop_runtime, target)
	runtime.clear_world()
	for raw_key: Variant in original_lod_settings.keys():
		var project_key := String(raw_key)
		_expect(ProjectSettings.get_setting(project_key) == original_lod_settings[project_key], "the laboratory leaked its LOD override: %s" % project_key)
	runtime.free()
	_finish(spawn_msec, command_usec)


func _test_dynamic_micro_behaviors(troop_runtime: HopliteV2TroopRuntime, target: Node3D) -> void:
	var frontline_ids: Array[StringName] = []
	var support_ids: Array[StringName] = []
	for group_id: StringName in troop_runtime.group_ids:
		if not troop_runtime.groups.has(group_id):
			continue
		var state := troop_runtime.groups[group_id] as Dictionary
		match StringName(state.get("battle_role", &"")):
			&"frontline": frontline_ids.append(group_id)
			&"support": support_ids.append(group_id)
	_expect(not frontline_ids.is_empty(), "dynamic probe found no frontline formation")
	if frontline_ids.is_empty():
		return
	var tested_id := frontline_ids[0]
	var tested_state := troop_runtime.groups[tested_id] as Dictionary
	var anchor := tested_state["anchor"] as Vector3
	var old_forward := (tested_state["forward"] as Vector3).normalized()
	# Place the target immediately behind one line without moving the whole army
	# focus. The formation and its closest defenders must turn locally first.
	target.global_position = anchor - old_forward * 2.8
	var observed_attack := false
	var wrong_way_attacks := 0
	for frame: int in range(240):
		troop_runtime._process(1.0 / 60.0)
		for member: Node3D in (tested_state["members"] as Array):
			if member == null or not is_instance_valid(member) or member.get("combat") == null:
				continue
			var combat: HopliteV2CombatComponent = member.get("combat") as HopliteV2CombatComponent
			if combat.state != HopliteV2CombatComponent.State.ATTACK:
				continue
			observed_attack = true
			var target_direction := target.global_position - member.global_position
			target_direction.y = 0.0
			if target_direction.length_squared() > 0.0001 and member.global_basis.z.normalized().dot(target_direction.normalized()) < HopliteV2CombatComponent.ATTACK_FACING_DOT - 0.05:
				wrong_way_attacks += 1
	var local_forward := tested_state["forward"] as Vector3
	var local_threat := target.global_position - (tested_state["anchor"] as Vector3)
	local_threat.y = 0.0
	_expect(local_threat.length_squared() < 0.0001 or local_forward.normalized().dot(local_threat.normalized()) >= 0.65, "the penetrated frontline still presents its back to the target")
	_expect(observed_attack, "the locally turned frontline never resumed attacking")
	_expect(wrong_way_attacks == 0, "one or more real formation actors attacked through their back arc")

	# Force the old failure mode once: two support anchors start at the same
	# location. The bounded group-level correction must separate them even while
	# cohesion recovery prevents an ordinary strategic advance.
	_expect(support_ids.size() >= 2, "dynamic probe found fewer than two support formations")
	if support_ids.size() < 2:
		return
	var overlap_origin := target.global_position + Vector3(20.0, 0.0, 20.0)
	for index: int in range(2):
		var group_id := support_ids[index]
		var state := troop_runtime.groups[group_id] as Dictionary
		state["anchor"] = overlap_origin
		troop_runtime.battle_layout.update_group(group_id, overlap_origin, (state["members"] as Array).size(), 1.0, false, false, state["forward"] as Vector3)
	for frame: int in range(120):
		troop_runtime._process(1.0 / 60.0)
	var first_anchor := (troop_runtime.groups[support_ids[0]] as Dictionary)["anchor"] as Vector3
	var second_anchor := (troop_runtime.groups[support_ids[1]] as Dictionary)["anchor"] as Vector3
	_expect(Vector2(first_anchor.x - second_anchor.x, first_anchor.z - second_anchor.z).length() >= 3.0, "two real phalanx anchors remained stacked after overlap recovery")


func _finish(spawn_msec: int, command_usec: int) -> void:
	if failures.is_empty():
		print("HOPLITE_V2_COMMAND_LAB_RUNTIME_PROBE PASS soldiers=414 groups=18 impostors>=200 corridors<=4 spawn_ms=%d command_1s_us=%d" % [spawn_msec, command_usec])
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 COMMAND LAB RUNTIME] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
