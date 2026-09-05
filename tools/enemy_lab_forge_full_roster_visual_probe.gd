extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

var context: StringName = &"lab"
var failures: Array[String] = []
var render_metrics: Dictionary = {}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--context="):
			context = StringName(argument.trim_prefix("--context=").to_lower())
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	if context == &"lab":
		await _run_lab()
	elif context == &"forge":
		await _run_forge()
	else:
		failures.append("context must be lab or forge")
	if failures.is_empty():
		print("ENEMY_LAB_FORGE_FULL_ROSTER_VISUAL_PROBE PASS context=%s ids=22 output=%s" % [context, _output_path()])
		print("ENEMY_LAB_FORGE_RENDER_METRICS_JSON " + JSON.stringify(render_metrics, "", true))
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _run_lab() -> void:
	var packed := load("res://combat_lab.tscn") as PackedScene
	if packed == null or change_scene_to_packed(packed) != OK:
		failures.append("could not open the real Combat Lab scene")
		return
	for _frame: int in range(20):
		await process_frame
		await physics_frame
	var annex := Node3D.new()
	annex.name = "MissionFullRosterAnnex"
	annex.position.y = 42.0
	current_scene.add_child(annex)
	_add_stage_floor(annex, Color(0.20, 0.16, 0.10))
	_add_stage_light(annex, Color(1.0, 0.82, 0.58))
	var units: Array[Node] = []
	var ids: Array[StringName] = Archetypes.all_ids()
	for index: int in range(ids.size()):
		var unit := EnemyFactory.spawn(annex, ids[index], _grid_position(index), null, {
			"ai_enabled": false,
			"mass_battle_mode": false,
			"guard_index": index,
		})
		if unit == null:
			failures.append("Combat Lab annex failed to spawn %s" % ids[index])
			continue
		units.append(unit)
		_add_label(annex, ids[index], _grid_position(index) + Vector3(0.0, 3.25, 0.0))
	await _settle_and_validate(units, ids)
	await _capture(annex, Vector3(0.0, 10.0, 27.0), Vector3(0.0, 1.8, 1.5))

func _run_forge() -> void:
	var data := WorldDocumentScript.create_default()
	var entities: Array = []
	var spawn := WorldDocumentScript.entity("player_spawn", "Mission Spawn", Vector3(0.0, 0.05, 18.0), {"spawn_id": "mission_probe"})
	spawn["chapter"] = "chapter_1"
	entities.append(spawn)
	var floor := WorldDocumentScript.entity("surface", "Mission Roster Floor", Vector3(0.0, -0.10, 1.5), {"shape": "floor", "size": [28.0, 0.2, 22.0], "material": "pavers"})
	floor["chapter"] = "chapter_1"
	entities.append(floor)
	var ids: Array[StringName] = Archetypes.all_ids()
	for index: int in range(ids.size()):
		var group := WorldDocumentScript.entity("enemy_group", "Mission %s" % ids[index], _grid_position(index), {
			"group_id": "mission_%s" % ids[index],
			"archetype": String(ids[index]),
			"count": 1,
			"rank": "normal",
			"formation": "line",
			"spawn_condition": "start",
			"deployment_mode": "all",
		})
		group["chapter"] = "chapter_1"
		entities.append(group)
	data["entities"] = entities
	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	runtime.name = "MissionForgeFullRoster"
	root.add_child(runtime)
	current_scene = runtime
	runtime.build(WorldDocumentScript.new(data), false)
	if runtime.player != null:
		runtime.player.process_mode = Node.PROCESS_MODE_DISABLED
		runtime.player.set_process(false)
		runtime.player.set_physics_process(false)
		runtime.player.set_process_input(false)
		runtime.player.set_process_unhandled_input(false)
		runtime.player.visible = false
	var units: Array[Node] = []
	for index: int in range(ids.size()):
		var group_units := runtime.enemies_by_group.get("mission_%s" % ids[index], []) as Array
		if group_units.size() != 1:
			failures.append("Forge runtime did not create exactly one %s" % ids[index])
			continue
		var unit := group_units[0] as Node
		if unit.has_method("set_ai_participation"):
			unit.call("set_ai_participation", false)
		units.append(unit)
		_add_label(runtime, ids[index], _grid_position(index) + Vector3(0.0, 3.25, 0.0))
	await _settle_and_validate(units, ids)
	await _capture(runtime, Vector3(0.0, 10.0, 27.0), Vector3(0.0, 1.8, 1.5))

func _settle_and_validate(units: Array[Node], ids: Array[StringName]) -> void:
	for index: int in range(units.size()):
		var unit: Node = units[index]
		if unit.has_method("_play_idle"):
			unit.call("_play_idle")
		var driver: Node = unit.get("ai_animation_driver") as Node
		if driver != null and driver.has_method("force_simulation_sample"):
			driver.call("force_simulation_sample")
		var player: AnimationPlayer = unit.get("animation_player") as AnimationPlayer
		if player != null:
			player.advance(0.20)
		_pose_route_state(unit, index)
	for _frame: int in range(24):
		await process_frame
		await physics_frame
	for candidate: Node in root.find_children("*", "GPUParticles3D", true, false):
		var particles := candidate as GPUParticles3D
		if particles != null and (particles.name.begins_with("Blood") or (particles.get_parent() != null and particles.get_parent().name.begins_with("Blood"))):
			particles.emitting = false
			particles.visible = false
	_expect(units.size() == ids.size(), "%s roster contains %d/22 units" % [context, units.size()])
	var seen: Dictionary = {}
	for unit: Node in units:
		var archetype := StringName(unit.get("archetype_id"))
		seen[archetype] = true
		_expect(unit.get("skeleton") != null, "%s/%s has no visible skeleton" % [context, archetype])
		var anatomy: Node = unit.get("anatomy") as Node
		_expect(anatomy != null and (anatomy.get("zone_runtime") as Dictionary).size() == 12, "%s/%s anatomy is not 12/12" % [context, archetype])
	for archetype: StringName in ids:
		_expect(seen.has(archetype), "%s visual roster omitted %s" % [context, archetype])

func _pose_route_state(unit: Node, index: int) -> void:
	var driver: Node = unit.get("ai_animation_driver") as Node
	match index % 6:
		0:
			if driver != null:
				driver.call("set_locomotion", 0.72)
				driver.call("force_simulation_sample")
			elif unit.has_method("_play_simple_loop"):
				unit.call("_play_simple_loop", &"Jog_Fwd", 1.0)
		1:
			unit.call("_begin_defense_window")
		2:
			_expect(bool(unit.call("_play_hit_reaction")), "%s/%s could not start deterministic impact" % [context, unit.get("archetype_id")])
		3:
			unit.set("ai_attack_cooldown_timer", 0.0)
			unit.call("_begin_ai_attack")
			if not bool(unit.get("ai_attack_pending")):
				unit.call("_play_mass_attack_animation")
		4:
			unit.set("health", maxf(float(unit.get("max_health")), 1000.0))
			unit.set("max_health", unit.get("health"))
			unit.set("defense_mode", &"none")
			var hit := HitEvent.new()
			hit.damage = 1.0
			hit.sever_damage = 10000.0
			hit.position = (unit.get("anatomy") as Node).call("get_zone_world_center", &"upper_arm_r")
			hit.direction = Vector3.RIGHT
			unit.call("receive_anatomy_hit", hit, &"upper_arm_r")
			_expect(bool(unit.call("is_combat_zone_severed", &"upper_arm_r")), "%s/%s route section failed" % [context, unit.get("archetype_id")])
		5:
			unit.call("_die", false)
			_expect(bool(unit.get("dead")), "%s/%s route death failed" % [context, unit.get("archetype_id")])

func _capture(parent: Node3D, camera_position: Vector3, look_target: Vector3) -> void:
	for candidate: Node in root.find_children("*", "CanvasLayer", true, false):
		candidate.set("visible", false)
	var camera := Camera3D.new()
	parent.add_child(camera)
	var capture_environment := Environment.new()
	capture_environment.background_mode = Environment.BG_COLOR
	capture_environment.background_color = Color(0.055, 0.065, 0.085)
	capture_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	capture_environment.ambient_light_color = Color(0.76, 0.80, 0.90)
	capture_environment.ambient_light_energy = 0.72
	camera.environment = capture_environment
	camera.position = camera_position
	camera.look_at(parent.to_global(look_target), Vector3.UP)
	camera.fov = 58.0
	camera.current = true
	for _frame: int in range(4):
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	render_metrics = {
		"context": String(context),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_memory_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(_output_path()))
	_expect(error == OK, "%s screenshot save failed: %s" % [context, error_string(error)])

func _grid_position(index: int) -> Vector3:
	var column := index % 6
	var row_index := index / 6
	return Vector3((float(column) - 2.5) * 4.2, 0.05, (float(row_index) - 1.5) * 4.2)

func _add_stage_floor(parent: Node3D, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(28.0, 0.2, 22.0)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, -0.10, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _add_stage_light(parent: Node3D, color: Color) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_color = color
	light.light_energy = 1.6
	light.shadow_enabled = true
	parent.add_child(light)

func _add_label(parent: Node3D, id: StringName, position_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = String(id)
	label.position = position_value
	label.font_size = 34
	label.outline_size = 8
	label.modulate = Color(1.0, 0.90, 0.62)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _output_path() -> String:
	return "res://docs/enemy_refactor/%s_full_roster_visual_probe.png" % context

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
