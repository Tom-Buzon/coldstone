extends SceneTree

const ImpostorBatch = preload("res://scripts/enemy_v2/hoplite_v2_impostor_batch.gd")
const ShadowFactory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const ATLAS := "res://assets/characters/enemy_v2/hoplite/impostor/hoplite_v2_guard_cycle.png"

var failures: Array[String] = []


class FakeActor:
	extends Node3D
	var dead := false

	func impostor_visual_scale() -> float:
		return 1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	_expect(image != null and image.get_size() == Vector2i(1024, 320), "the four-frame impostor atlas is missing or has the wrong dimensions")
	var world := Node3D.new()
	root.add_child(world)
	var batch := ImpostorBatch.new() as HopliteV2ImpostorBatch
	world.add_child(batch)
	await process_frame
	_expect(batch.installed, "the shared MultiMesh impostor renderer did not install")
	var first := FakeActor.new()
	first.position = Vector3(12.0, 0.0, -8.0)
	world.add_child(first)
	var second := FakeActor.new()
	second.position = Vector3(-25.0, 0.0, 19.0)
	world.add_child(second)
	batch.set_actor_active(first, true)
	batch.set_actor_active(second, true)
	await process_frame
	_expect(batch.active_count() == 2, "far actors were not compacted into the shared batch")
	_expect(batch.multi_mesh != null and batch.multi_mesh.visible_instance_count == 2, "the MultiMesh does not expose exactly the active far soldiers")
	_expect(batch.multi_mesh.instance_count >= 16, "the impostor capacity does not grow in reusable chunks")
	_expect(batch.multi_mesh.mesh.get_aabb().size.y >= 7.0, "the impostor quad lost its calibrated far-distance coverage")
	_expect(batch.tracked.has(first.get_instance_id()) and batch.tracked.has(second.get_instance_id()), "the shared batch lost one of its independent actor references")
	batch.set_actor_active(first, false)
	await process_frame
	_expect(batch.active_count() == 1 and batch.multi_mesh.visible_instance_count == 1, "returning to 3D did not release the far impostor")
	batch.set_actor_active(second, false)
	await process_frame
	var camera := Camera3D.new()
	world.add_child(camera)
	var actual := ShadowFactory.create(&"ngeneral") as HopliteEnemyActorV2
	actual.position = Vector3(100.0, 0.0, 0.0)
	actual.lod_reference = camera
	world.add_child(actual)
	await process_frame
	actual.troop_controlled = true
	actual.set_far_impostor_batch(batch)
	await process_frame
	_expect(actual.simulation_lod_level == 3, "a far V2 actor did not enter impostor LOD")
	_expect(not actual.performance_lod.is_processing(), "the per-actor LOD callback kept running behind the shared impostor")
	_expect(not actual.animation.player.active, "the hidden far skeleton kept advancing its AnimationPlayer")
	actual.position = Vector3.ZERO
	actual.far_impostor_lod_tick()
	_expect(actual.simulation_lod_level < 3, "the shared batch did not wake an actor returning to 3D range")
	_expect(actual.performance_lod.is_processing() and actual.animation.player.active, "returning to 3D did not restore LOD and animation processing")
	world.free()
	if failures.is_empty():
		print("HOPLITE_V2_IMPOSTOR_PROBE PASS atlas=4x256 batch=shared capacity=chunked lod_wake=centralized")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 IMPOSTOR] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
