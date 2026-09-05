extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var first := EnemyFactory.spawn(world, &"guardian", Vector3.ZERO, null, {"ai_enabled": false, "mixamo_model_override": &"smallsbir5"})
	var second := EnemyFactory.spawn(world, &"guardian", Vector3(2.0, 0.0, 0.0), null, {"ai_enabled": false, "mixamo_model_override": &"smallsbir5"})
	await process_frame
	_expect(first != null and second != null, "guardian cache fixtures failed to spawn")
	if first != null and second != null:
		var first_material := _first_material(first.sword_root)
		var second_material := _first_material(second.sword_root)
		_expect(first_material != null and first_material == second_material, "identical procedural weapons retained per-instance materials")
		var skin_a: Material = first._make_skin_material(Color(0.1, 0.2, 0.3), 0.5, 0.7)
		var skin_b: Material = second._make_skin_material(Color(0.1, 0.2, 0.3), 0.5, 0.7)
		_expect(skin_a == skin_b, "identical procedural armour retained per-instance materials")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_MATERIAL_CACHE_PROBE PASS: procedural weapon and armour materials are shared by immutable parameters")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _first_material(root_node: Node) -> Material:
	if root_node == null:
		return null
	for candidate: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.material_override != null:
			return mesh_instance.material_override
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
