extends SceneTree

const ImpostorBatch = preload("res://scripts/enemy_v2/hoplite_v2_impostor_batch.gd")
const ShadowFactory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const OUTPUT := "res://docs/enemy_refactor/hoplite_v2_far_impostor_probe.png"


class FakeActor:
	extends Node3D
	var dead := false

	func impostor_visual_scale() -> float:
		return 1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(800, 500)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202a38")
	environment.environment = settings
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.2, 7.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.1, 0.0), Vector3.UP)
	camera.current = true
	world.add_child(camera)
	var batch := ImpostorBatch.new() as HopliteV2ImpostorBatch
	world.add_child(batch)
	var actual := ShadowFactory.create(&"ngeneral") as HopliteEnemyActorV2
	actual.position = Vector3(-1.25, 0.0, 0.0)
	world.add_child(actual)
	actual.play_semantic_animation(&"block_idle", 0.0)
	var actor := FakeActor.new()
	actor.position = Vector3(1.25, 0.0, 0.0)
	world.add_child(actor)
	batch.set_actor_active(actor, true)
	for _frame: int in range(14):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("HOPLITE_V2_IMPOSTOR_VISUAL_PROBE save failed: %s" % error_string(error))
		quit(1)
		return
	print("HOPLITE_V2_IMPOSTOR_VISUAL_PROBE PASS comparison=actual_vs_impostor output=", OUTPUT)
	quit(0)
