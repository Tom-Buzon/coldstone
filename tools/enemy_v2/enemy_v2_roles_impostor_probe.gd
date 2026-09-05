extends SceneTree
const Batch = preload("res://scripts/enemy_v2/hoplite_v2_impostor_batch.gd")
const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var reference := Node3D.new()
	world.add_child(reference)
	var batch := Batch.new()
	world.add_child(batch)
	var actors: Array[HopliteEnemyActorV2] = []
	for id: StringName in [&"ngeneral", &"archer_v2", &"infantry_v2"]:
		var actor := Factory.create(id)
		actor.position = Vector3(120, 0, actors.size() * 3)
		actor.lod_reference = reference
		world.add_child(actor)
		actor.troop_controlled = true
		actor.set_far_impostor_batch(batch)
		actors.append(actor)
	await process_frame
	await process_frame
	_expect(batch.active_count() == 3, "manager count must include all three roles")
	_expect(batch.role_batches.size() == 2, "role manager must create exactly two additional batches")
	for role: StringName in [&"archer", &"infantry"]:
		var role_batch: Node = batch.role_batches.get(role)
		_expect(role_batch != null and role_batch.installed, "role atlas did not load: %s" % role)
		if role_batch != null and role_batch.installed:
			_expect(role_batch.multi_mesh.visible_instance_count == 1, "role does not have exactly one visible instance")
			var texture: Texture2D = role_batch.multi_mesh.mesh.material.get_shader_parameter(&"impostor_atlas")
			_expect(texture.resource_path.ends_with("%s_v2_cycle.png" % role), "role shares a spear atlas")
	for actor: HopliteEnemyActorV2 in actors:
		_expect(not actor.performance_lod.is_processing(), "hidden role still runs per-actor LOD processing")
		actor.position = Vector3.ZERO
		actor.far_impostor_lod_tick()
		_expect(actor.simulation_lod_level < 3 and actor.performance_lod.is_processing(), "role did not wake when player approached")
	await process_frame
	_expect(batch.active_count() == 0, "woken actors remain in role batches")
	world.free()
	for failure: String in failures:
		push_error(failure)
	print("ENEMY_V2_ROLES_IMPOSTOR_PROBE ", "PASS" if failures.is_empty() else "FAIL", " batches=3 independent_atlases=true lod_wake=true")
	quit(int(not failures.is_empty()))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
