extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://combat_lab.tscn") as PackedScene
	_expect(packed != null, "combat_lab.tscn could not be loaded")
	if packed == null:
		_finish()
		return
	var scene_error := change_scene_to_packed(packed)
	_expect(scene_error == OK, "combat lab scene change failed")
	# Enemy packages finish their grounding/equipment setup on deferred frames.
	for _frame: int in range(32):
		await process_frame

	var legion_total: int = 0
	var shield_total: int = 0
	for raw_enemy: Node in get_nodes_in_group("enemy"):
		var group_id := StringName(raw_enemy.get_meta("training_group", StringName()))
		if not String(group_id).begins_with("legion_"):
			continue
		legion_total += 1
		if StringName(raw_enemy.get("defense_mode")) != &"shield":
			continue
		shield_total += 1
		var hitbox: Variant = raw_enemy.get("shield_hitbox")
		_expect(hitbox is Area3D, "%s has no physical shield Area" % raw_enemy.name)
		if hitbox is Area3D:
			_expect((hitbox as Area3D).collision_layer == 0, "%s lowered shield still intercepts weapon queries" % raw_enemy.name)
			raw_enemy.call("_begin_defense_window")
			_expect(((hitbox as Area3D).collision_layer & 8) != 0, "%s raised shield is not on the weapon-hit layer" % raw_enemy.name)
			_expect(bool(hitbox.get("active")), "%s raised shield surface is inactive" % raw_enemy.name)
			raw_enemy.call("_end_defense_window")
			_expect((hitbox as Area3D).collision_layer == 0, "%s shield stayed active after guard ended" % raw_enemy.name)

	_expect(legion_total == 56, "shooting annex did not mount all 56 legion units (got %d)" % legion_total)
	_expect(shield_total == 14, "shooting annex did not mount all 14 shield units (got %d)" % shield_total)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SHOOTING_RANGE_SHIELD_PROBE PASS: 56 units, 14 guard-gated physical shields")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
