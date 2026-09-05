extends SceneTree

const FaunaAgentScript = preload("res://scripts/fauna/fauna_agent.gd")
const FaunaManagerScript = preload("res://scripts/fauna/fauna_manager.gd")
const WaterBlockerScript = preload("res://scripts/fauna/fauna_water_blocker.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_slope_and_animation_loop()
	await _test_water_rejection()
	await _test_eagle_flight_orientation()
	if failures.is_empty():
		print("FAUNA_TERRAIN_WATER_PROBE: PASS — animations, pente, eau et orientation de l'aigle validées.")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAUNA_TERRAIN_WATER_PROBE: " + failure)
	quit(1)


func _test_slope_and_animation_loop() -> void:
	var context := _create_context()
	var scene := context["scene"] as Node3D
	var manager := context["manager"] as HopliteFaunaManager
	_add_ramp(scene, -10.0)
	await physics_frame
	var start_sample: Variant = manager.project_ground_position(Vector3(-6.0, 5.0, -10.0), 0.3)
	var end_sample: Variant = manager.project_ground_position(Vector3(7.0, 5.0, -10.0), 0.3)
	_check(start_sample is Vector3 and end_sample is Vector3, "La pente de test n'est pas détectée par les rayons de sol.")
	if not start_sample is Vector3 or not end_sample is Vector3:
		await _destroy_context(scene)
		return
	var agent := _spawn_test_agent(manager, context["player"] as Node3D, &"wolf", start_sample as Vector3)
	agent.set_wander_target(end_sample as Vector3, true)
	for _index: int in range(100):
		await physics_frame
	_check(agent.global_position.y > (start_sample as Vector3).y + 0.35, "L'animal ne remonte pas la pente avec le terrain.")
	_check(agent.global_position.y < (end_sample as Vector3).y + 0.35, "L'animal dépasse verticalement la surface de la pente.")
	var locomotion_running := false
	for animation_player: AnimationPlayer in agent._animation_players:
		var current := String(animation_player.current_animation).to_lower()
		if animation_player.is_playing() and (current.ends_with("gallop") or current.ends_with("walk")):
			var animation := animation_player.get_animation(animation_player.current_animation)
			locomotion_running = animation != null and animation.loop_mode == Animation.LOOP_LINEAR
	_check(locomotion_running, "La locomotion s'arrête encore après la fin du premier clip.")
	agent.hold_position(1.5)
	for _index: int in range(80):
		await physics_frame
	var idle_running := false
	for animation_player: AnimationPlayer in agent._animation_players:
		var current := String(animation_player.current_animation).to_lower()
		if animation_player.is_playing() and current.ends_with("idle"):
			idle_running = animation_player.get_animation(animation_player.current_animation).loop_mode == Animation.LOOP_LINEAR
	_check(idle_running, "L'animation Idle ne reste pas en boucle.")
	await _destroy_context(scene)


func _test_water_rejection() -> void:
	var context := _create_context()
	var scene := context["scene"] as Node3D
	var manager := context["manager"] as HopliteFaunaManager
	_add_flat_ground(scene)
	var blocker := WaterBlockerScript.new() as HopliteFaunaWaterBlocker
	blocker.position = Vector3(0.0, 0.0, 10.0)
	blocker.configure(Vector2(4.0, 8.0), 0.75)
	scene.add_child(blocker)
	await physics_frame
	manager._refresh_water_blockers()
	var agent := _spawn_test_agent(manager, context["player"] as Node3D, &"wolf", Vector3(-5.0, 0.03, 10.0))
	agent.set_wander_target(Vector3(5.0, 0.03, 10.0), true)
	var entered_water := false
	for _index: int in range(180):
		await physics_frame
		if blocker.blocks_world_point(agent.global_position, agent.water_clearance_radius()):
			entered_water = true
			break
	_check(not entered_water, "L'animal est entré dans l'empreinte de la nappe d'eau.")
	_check(not manager.is_water_blocked(Vector3(-3.0, 0.03, 10.0), 0.2), "La marge d'eau bloque trop loin de la rive.")
	_check(manager.is_water_blocked(Vector3(0.0, 0.03, 10.0), 0.2), "Le centre de la nappe d'eau n'est pas reconnu comme interdit.")
	_check(not manager.is_water_blocked(Vector3(0.0, 2.0, 10.0), 0.2), "Une plateforme située au-dessus de l'eau devrait rester praticable.")
	await _destroy_context(scene)


func _test_eagle_flight_orientation() -> void:
	var context := _create_context()
	var scene := context["scene"] as Node3D
	var manager := context["manager"] as HopliteFaunaManager
	var agent := _spawn_test_agent(manager, context["player"] as Node3D, &"eagle", Vector3(0.0, 20.0, 0.0))
	var visual := agent.get_node_or_null("AnimatedVisual") as Node3D
	_check(visual != null and is_zero_approx(visual.rotation.y), "L'aigle reçoit encore le demi-tour prévu pour l'autre pack.")
	agent.set_wander_target(Vector3(12.0, 20.0, 0.0), false)
	for _index: int in range(30):
		await physics_frame
	var world_forward := -agent.global_basis.z.normalized()
	_check(world_forward.dot(Vector3.RIGHT) > 0.9, "L'aigle ne regarde pas dans le sens de son vol.")
	await _destroy_context(scene)


func _create_context() -> Dictionary:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player := Node3D.new()
	player.position = Vector3(0.0, 0.0, 24.0)
	scene.add_child(player)
	var manager := FaunaManagerScript.new() as HopliteFaunaManager
	manager.player = player
	scene.add_child(manager)
	manager.set_physics_process(false)
	return {"scene": scene, "player": player, "manager": manager}


func _spawn_test_agent(manager: HopliteFaunaManager, player: Node3D, species_id: StringName, spawn_position: Vector3) -> HopliteFaunaAgent:
	var agent := FaunaAgentScript.new() as HopliteFaunaAgent
	manager.add_child(agent)
	var configured := agent.configure(HopliteFaunaSettings.definition(species_id), 0, player, null, 77331, spawn_position, 4.0)
	_check(configured, "%s n'a pas pu être instancié pour le test." % String(species_id))
	agent.fauna_manager = manager
	return agent


func _add_flat_ground(scene: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 1.0, 40.0)
	collision.shape = shape
	body.position.y = -0.5
	body.add_child(collision)
	scene.add_child(body)


func _add_ramp(scene: Node3D, center_z: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([
		Vector3(-8.0, 0.0, center_z - 4.0), Vector3(8.0, 3.0, center_z - 4.0), Vector3(8.0, 3.0, center_z + 4.0),
		Vector3(-8.0, 0.0, center_z - 4.0), Vector3(8.0, 3.0, center_z + 4.0), Vector3(-8.0, 0.0, center_z + 4.0),
	]))
	collision.shape = shape
	body.add_child(collision)
	scene.add_child(body)


func _destroy_context(scene: Node3D) -> void:
	scene.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
