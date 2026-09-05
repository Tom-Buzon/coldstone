extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var knight: HopliteAthenianEnemy
	for index: int in range(12):
		var candidate := Enemy.new() as HopliteAthenianEnemy
		candidate.archetype_id = &"captain"
		candidate.ai_guard_index = index
		candidate.ai_enabled = false
		world.add_child(candidate)
		if candidate.mixamo_model_id == &"knight3":
			knight = candidate
			break
		candidate.queue_free()
		await process_frame
	_expect(knight != null, "captain pool produced no knight3 authored-equipment variant")
	if knight != null:
		_expect(knight.authored_weapon_visual != null and knight.authored_shield_visual != null, "knight3 authored equipment meshes were not resolved")
		_expect(knight.sword_root != null and knight.shield_root != null, "knight3 lacks detachable equipment anchors")
		knight.max_health = 100000.0
		knight.health = knight.max_health
		knight.defense_mode = &"none"
		knight.armor_sever_multiplier = 1.0
		var right_hit := HitEvent.new()
		right_hit.damage = 1.0
		right_hit.sever_damage = 100000.0
		right_hit.position = knight.anatomy.get_zone_world_center(&"forearm_r")
		right_hit.direction = Vector3.RIGHT
		knight.receive_anatomy_hit(right_hit, &"forearm_r")
		await process_frame
		_expect(knight.sword_dropped, "knight3 authored sword did not detach")
		_expect(not knight.authored_weapon_visual.visible, "knight3 authored sword stayed visible after section")
		var left_hit := HitEvent.new()
		left_hit.damage = 1.0
		left_hit.sever_damage = 100000.0
		left_hit.position = knight.anatomy.get_zone_world_center(&"forearm_l")
		left_hit.direction = Vector3.LEFT
		knight.receive_anatomy_hit(left_hit, &"forearm_l")
		await process_frame
		_expect(knight.shield_dropped, "knight3 authored shield did not detach")
		_expect(not knight.authored_shield_visual.visible, "knight3 authored shield stayed visible after section")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_AUTHORED_EQUIPMENT_PROBE PASS: knight3 sword/shield anchors, hide and detached replacements")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
