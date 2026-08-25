extends SceneTree

const TerrainArcher = preload("res://tools/archer_high_ground_probe_actor.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe_platform_preservation()
	_probe_walkable_climb()
	_probe_contact_delay_priority()
	if failures.is_empty():
		print("ARCHER_HIGH_GROUND_PROBE PASS: preserve, climb, edge lock and delayed retreat")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _new_archer() -> TerrainArcher:
	var archer := TerrainArcher.new()
	archer.behavior_mode = &"ranged"
	archer.ranged_height_preference = 1.0
	archer.ai_home_position = Vector3(0.0, 2.0, 0.0)
	root.add_child(archer)
	return archer

func _probe_platform_preservation() -> void:
	var archer := _new_archer()
	archer.position = Vector3(0.0, 2.0, 0.0)
	archer.call("_refresh_ranged_height_awareness", true)
	_expect(archer.ranged_high_ground_active, "archer did not recognize lower ground around his platform")
	_expect(is_equal_approx(archer.ranged_preserved_floor_y, 2.0), "archer did not anchor the occupied platform height")
	var lower_target: Vector3 = archer.call("_ranged_height_biased_target", Vector3(5.0, 0.0, 0.0), 8.0)
	_expect(lower_target.is_equal_approx(archer.global_position), "ranged personality overrode the occupied high ground")

	archer.position = Vector3(1.55, 2.0, 0.0)
	archer.velocity = Vector3(4.0, 0.0, 0.0)
	archer.call("_constrain_ranged_velocity_to_height")
	_expect(Vector2(archer.velocity.x, archer.velocity.z).is_zero_approx(), "archer still walks or separates off a platform edge")
	archer.queue_free()

func _probe_walkable_climb() -> void:
	var archer := _new_archer()
	archer.terrain_mode = &"slope"
	archer.position = Vector3.ZERO
	archer.ai_home_position = Vector3.ZERO
	var climbable: bool = archer.call("_ranged_has_walkable_climb_path", Vector3(5.0, 1.5, 0.0), 0.0)
	_expect(climbable, "archer rejected a nearby continuous walkable slope")
	archer.velocity = Vector3(4.0, 0.0, 0.0)
	archer.call("_constrain_ranged_velocity_to_height")
	_expect(archer.velocity.x > 0.0, "height guard incorrectly blocked an uphill movement")
	archer.queue_free()

func _probe_contact_delay_priority() -> void:
	var archer := _new_archer()
	archer.terrain_mode = &"isolated_platform"
	archer.position = Vector3(0.0, 2.0, 0.0)
	archer.preferred_range_min = 3.65
	archer.ranged_retreat_delay_timer = 0.82
	archer.ranged_height_scan_timer = 1.0
	archer.ranged_height_target = Vector3(1.0, 3.0, 0.0)
	archer.ranged_height_target_valid = true
	var punish_target := Vector3(0.4, 2.0, 0.0)
	var resolved: Vector3 = archer.call("_ranged_height_biased_target", punish_target, 1.2)
	_expect(resolved.is_equal_approx(punish_target), "height seeking erased the archer's close-contact punish delay")
	archer.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
