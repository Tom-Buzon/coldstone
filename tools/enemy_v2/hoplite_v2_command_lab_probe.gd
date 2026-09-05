extends SceneTree

const WorldDocument = preload("res://scripts/world_editor/world_document.gd")
const LayoutRuntime = preload("res://scripts/enemy_v2/enemy_v2_battle_layout_runtime.gd")
const FocusTracker = preload("res://scripts/enemy_v2/enemy_v2_tactical_focus_tracker.gd")
const OccupancyRuntime = preload("res://scripts/enemy_v2/enemy_v2_tactical_occupancy_runtime.gd")

const WORLD_PATH := "user://hoplite_worlds/champsdebataille_v2_commandement_414.hoplite.json"
const EXPECTED_SOLDIERS := 414
const EXPECTED_PHALANXES := 17

var failures: Array[String] = []
var mixed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
	_expect(file != null, "command laboratory world is missing")
	if file == null:
		_finish()
		return
	var document := WorldDocument.from_json(file.get_as_text())
	file.close()
	_expect(document != null, "command laboratory world is invalid")
	if document == null:
		_finish()
		return
	mixed = bool(document.data.get("settings", {}).get("enemy_v2_combined_arms", false))
	if mixed:
		_validate_mixed_document(document)
		_finish()
		return
	var soldiers := 0
	var phalanxes := 0
	var skirmishes := 0
	var far_authored := 0
	var player_position := Vector3.ZERO
	var phalanx_entities: Array[Dictionary] = []
	for raw: Variant in document.data.get("entities", []):
		if not raw is Dictionary:
			continue
		var entity := raw as Dictionary
		if String(entity.get("type", "")) == "player_spawn":
			player_position = WorldDocument.vector3(entity.get("position", []))
		if String(entity.get("type", "")) != "enemy_group":
			continue
		var properties := entity.get("properties", {}) as Dictionary
		var count := int(properties.get("count", 0))
		soldiers += count
		match StringName(properties.get("v2_troop_mode", &"")):
			&"hoplite_phalanx":
				phalanxes += 1
				phalanx_entities.append(entity)
			&"hoplite_skirmish": skirmishes += 1
		if WorldDocument.vector3(entity.get("position", [])).distance_to(player_position) > 65.0:
			far_authored += 1
	_expect(String(document.data.get("name", "")) == "champsDeBataille_V2_Commandement_414", "command laboratory has the wrong name")
	_expect(soldiers == EXPECTED_SOLDIERS, "command laboratory population is not 414")
	_expect(phalanxes == EXPECTED_PHALANXES and skirmishes == 1, "command laboratory must contain 17 phalanxes and one pressure squad")
	_expect(far_authored >= 5, "command laboratory does not keep enough durable LOD3 reserves")
	var lab_settings := document.data.get("settings", {}) as Dictionary
	var lod_override := lab_settings.get("enemy_lod_override", {}) as Dictionary
	_expect(float(lod_override.get("near_distance", 0.0)) == 10.0 and float(lod_override.get("far_distance", 0.0)) == 26.0 and float(lod_override.get("cull_distance", 0.0)) == 65.0, "command laboratory does not own a reproducible Performance LOD profile")

	var world := Node3D.new()
	root.add_child(world)
	var target := Node3D.new()
	target.position = player_position
	world.add_child(target)
	var layout := LayoutRuntime.new() as EnemyV2BattleLayoutRuntime
	for index: int in range(phalanx_entities.size()):
		var entity := phalanx_entities[index]
		var properties := entity.get("properties", {}) as Dictionary
		layout.register_group(
			StringName(properties.get("group_id", "phalanx_%d" % index)),
			target,
			WorldDocument.vector3(entity.get("position", [])),
			properties,
			&"hoplite_phalanx",
			24
		)
	var roles: Dictionary = {}
	var far_goals := 0
	for entity: Dictionary in phalanx_entities:
		var properties := entity.get("properties", {}) as Dictionary
		var assignment := layout.assignment(StringName(properties.get("group_id", "")))
		var role := StringName(assignment.get("role", &""))
		roles[role] = int(roles.get(role, 0)) + 1
		if (assignment.get("anchor_goal", Vector3.ZERO) as Vector3).distance_to(player_position) > 65.0:
			far_goals += 1
	_expect(int(roles.get(&"frontline", 0)) == 4, "layout did not cap active fronts at four")
	_expect(int(roles.get(&"support", 0)) == 4, "layout did not create the first support depth rank")
	_expect(int(roles.get(&"reserve", 0)) == 9, "layout did not preserve nine formations in reserve depth")
	_expect(far_goals >= 5, "strategic goals collapse the LOD3 reserves toward the player")

	var focus := FocusTracker.new()
	var focus_target := Node3D.new()
	world.add_child(focus_target)
	focus_target.position = Vector3.ZERO
	focus.call("register_target", focus_target)
	focus_target.position = Vector3.RIGHT * 7.0
	var before_handoff: Vector3 = focus.call("update_target", focus_target, 1000) as Vector3
	var after_handoff: Vector3 = focus.call("update_target", focus_target, 1000 + FocusTracker.HANDOFF_DWELL_MSEC + 1) as Vector3
	_expect(before_handoff.distance_to(Vector3.ZERO) < 0.01, "tactical focus followed a raw player displacement immediately")
	_expect(after_handoff.distance_to(focus_target.position) < 0.01, "tactical focus did not hand off after the stability delay")
	focus_target.position = Vector3.RIGHT * 30.0
	var hard_handoff: Vector3 = focus.call("update_target", focus_target, 2000) as Vector3
	_expect(hard_handoff.distance_to(focus_target.position) < 0.01, "tactical focus did not immediately hand off a grounded hard relocation")

	var occupancy := OccupancyRuntime.new()
	occupancy.call("update_footprint", &"blocker", Vector3(12.0, 0.0, 0.0), Vector3.FORWARD, 10.0, 4.0)
	var blocked_path := PackedVector3Array([Vector3.ZERO, Vector3(24.0, 0.0, 0.0)])
	var clear_path := PackedVector3Array([Vector3(0.0, 0.0, 18.0), Vector3(24.0, 0.0, 18.0)])
	_expect(occupancy.call("try_reserve_corridor", &"moving", blocked_path, 8.0) == null, "a corridor crossed an occupied formation footprint")
	_expect(occupancy.call("try_reserve_corridor", &"moving", clear_path, 8.0) != null, "a clear formation corridor was not granted")
	world.free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("HOPLITE_V2_COMMAND_LAB_PROBE PASS combined_arms=414 fronts=4 giant_scale=3" if mixed else "HOPLITE_V2_COMMAND_LAB_PROBE PASS soldiers=414 phalanxes=17 contacts=4 support=4 reserve=9 far_goals>=5 focus=stable corridors=exclusive")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 COMMAND LAB] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _validate_mixed_document(document: HopliteWorldDocument) -> void:
	var counts: Dictionary = {}
	var fronts: Dictionary = {}
	var total := 0
	for entity: Dictionary in document.data.get("entities", []):
		if entity.get("type") != "enemy_group": continue
		var properties: Dictionary = entity["properties"]
		var role := StringName(properties.get("v2_unit_role", &""))
		var count := int(properties.get("count", 0))
		counts[role] = int(counts.get(role, 0)) + count
		total += count
		fronts[int(properties.get("v2_front_id", -1))] = true
		_expect(bool(properties.get("v2_persistent_fronts", false)), "mixed unit has no front doctrine")
		if role == &"giant":
			_expect(count == 1 and float(properties.get("size_multiplier", 0)) == 3.0, "giant is not a scale-three singleton")
	_expect(total == 414 and fronts.size() == 4, "mixed population/front count mismatch")
	_expect(int(counts.get(&"phalanx",0)) == 288 and int(counts.get(&"archer",0)) == 48 and int(counts.get(&"infantry",0)) == 76 and int(counts.get(&"giant",0)) == 2, "mixed roles mismatch")
	_expect(bool(document.validation_report().get("valid",false)), "mixed document schema invalid")
