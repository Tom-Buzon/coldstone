extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const EnemyScript = preload("res://scripts/enemy/athenian_enemy.gd")
const ProbeActorScript = preload("res://tools/enemy_patrol_probe_actor.gd")
const ProbeEnemyScript = preload("res://tools/enemy_patrol_probe_enemy.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var document := WorldDocumentScript.new()
	var chapter_id := document.start_chapter()
	var group := WorldDocumentScript.entity("enemy_group", "Patrouille test", Vector3.ZERO, {
		"group_id": "probe_patrol",
		"archetype": "nathenian1",
		"count": 2,
		"behavior": "patrol",
		"route_id": "probe_route",
		"patrol_speed": 2.25,
	})
	group["chapter"] = chapter_id
	document.add_entity(group)
	var marker := WorldDocumentScript.entity("patrol_point", "Point unique", Vector3(12.0, 0.0, -4.0), {
		"route_id": "probe_route",
		"order": 0,
		"wait": 0.0,
	})
	marker["chapter"] = chapter_id
	document.add_entity(marker)

	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	runtime.document = document
	runtime.active_chapter_id = chapter_id
	root.add_child(runtime)
	var first := ProbeActorScript.new()
	var second := ProbeActorScript.new()
	runtime.add_child(first)
	runtime.add_child(second)
	first.global_position = Vector3(2.0, 0.0, 3.0)
	second.global_position = Vector3(4.0, 0.0, 5.0)
	var enemies: Array[Node] = [first, second]
	runtime.call("_configure_group_behavior", enemies, group)

	_expect(first.configured_points.size() == 2, "a one-marker route must include the first enemy's initial position")
	_expect(second.configured_points.size() == 2, "every enemy must receive its own initial position")
	if first.configured_points.size() == 2:
		_expect(first.configured_points[0].is_equal_approx(Vector3(12.0, 0.0, -4.0)), "the authored marker must remain first")
		_expect(first.configured_points[1].is_equal_approx(Vector3(2.0, 0.0, 3.0)), "the first enemy's home must close its loop")
	if second.configured_points.size() == 2:
		_expect(second.configured_points[1].is_equal_approx(Vector3(4.0, 0.0, 5.0)), "the second enemy must not reuse another unit's home")
	for point_data: Dictionary in [
		{"name": "Troisieme", "position": Vector3(30.0, 0.0, -4.0), "order": 2},
		{"name": "Deuxieme", "position": Vector3(20.0, 0.0, -4.0), "order": 1},
	]:
		var extra_marker := WorldDocumentScript.entity("patrol_point", String(point_data["name"]), point_data["position"], {
			"route_id": "probe_route",
			"order": int(point_data["order"]),
			"wait": 0.0,
		})
		extra_marker["chapter"] = chapter_id
		document.add_entity(extra_marker)
	runtime.call("_configure_group_behavior", enemies, group)
	_expect(first.configured_points.size() == 4, "a multi-marker route must append home after every authored point")
	if first.configured_points.size() == 4:
		_expect(first.configured_points[0].is_equal_approx(Vector3(12.0, 0.0, -4.0)), "multi-marker patrol order 0 changed")
		_expect(first.configured_points[1].is_equal_approx(Vector3(20.0, 0.0, -4.0)), "multi-marker patrol order 1 changed")
		_expect(first.configured_points[2].is_equal_approx(Vector3(30.0, 0.0, -4.0)), "multi-marker patrol order 2 changed")
		_expect(first.configured_points[3].is_equal_approx(Vector3(2.0, 0.0, 3.0)), "home must remain last on a multi-marker route")

	var loop: Array[Vector3] = [Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), Vector3.ZERO]
	_expect(EnemyScript.nearest_patrol_index(loop, Vector3(18.0, 0.0, 1.0)) == 1, "patrol recovery must choose the nearest point after a chase")
	_expect(EnemyScript.nearest_patrol_index(loop, Vector3(1.0, 8.0, 1.0)) == 2, "patrol recovery distance must ignore vertical displacement")
	var patroller := ProbeEnemyScript.new() as HopliteAthenianEnemy
	var focus := Node3D.new()
	root.add_child(patroller)
	root.add_child(focus)
	patroller.global_position = Vector3(18.0, 0.0, 1.0)
	focus.global_position = Vector3(18.0, 0.0, 2.0)
	patroller.battle_player = focus
	patroller.ai_player = null
	patroller.configure_demo_patrol(loop, 0, 6.0, 2.0)
	patroller.call("_ai_goal")
	_expect(patroller.demo_patrol_interrupted, "focusing a nearby player must mark the patrol as interrupted")
	focus.global_position = Vector3(100.0, 0.0, 100.0)
	var resumed_goal := patroller.call("_ai_goal") as Dictionary
	_expect(not patroller.demo_patrol_interrupted, "losing the player must leave interruption state")
	_expect(patroller.demo_patrol_index == 1, "losing the player must rejoin the nearest patrol point")
	_expect(StringName(patroller.ai_state) == &"patrol" and bool(resumed_goal.get("active", false)), "the resumed goal must move the enemy again")

	patroller.free()
	focus.free()
	runtime.free()
	if failures.is_empty():
		print("ENEMY_PATROL_PROBE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("ENEMY_PATROL_PROBE_FAILED: " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
