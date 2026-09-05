extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const OUTPUT := "res://docs/world_editor/the_wolf_boss_preview.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1200, 700)
	var stage := Node3D.new()
	stage.name = "TheWolfVisualProbe"
	root.add_child(stage)
	current_scene = stage
	_build_environment(stage)
	var target := Node3D.new()
	target.add_to_group("player")
	target.position = Vector3(0.0, 0.0, 8.0)
	stage.add_child(target)
	var mid := EnemyFactory.spawn(stage, &"the_wolf_mid", Vector3(-3.2, 0.02, 0.0), target, {"ai_enabled": false, "performance_profile": "detailed"})
	var veteran := EnemyFactory.spawn(stage, &"the_wolf_veteran", Vector3(3.2, 0.02, 0.0), target, {"ai_enabled": false, "performance_profile": "detailed"})
	if mid == null or veteran == null:
		push_error("THE_WOLF_VISUAL_PROBE could not spawn both variants")
		quit(1)
		return
	# Present Veteran with its final moon-violet identity while Mid keeps phase 1.
	veteran.call("_activate_wolf_phase", 3, 1.0, 1.0)
	mid.call("_play_animation", &"idle_2")
	veteran.call("_play_animation", &"attack")
	var camera := Camera3D.new()
	stage.add_child(camera)
	# Gameplay forward is -Z, so this captures the face rather than the tail.
	camera.global_position = Vector3(0.0, 3.8, -12.0)
	camera.look_at(Vector3(0.0, 1.55, 0.0), Vector3.UP)
	camera.fov = 48.0
	camera.current = true
	for _frame: int in range(12):
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT)) if image != null else ERR_CANT_CREATE
	if error != OK:
		push_error("THE_WOLF_VISUAL_PROBE screenshot failed: %s" % error_string(error))
		quit(1)
		return
	print("THE_WOLF_VISUAL_PROBE PASS output=%s size=%s" % [OUTPUT, image.get_size()])
	quit(0)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("090d1f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6f6688")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("ffe0bd")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := StaticBody3D.new()
	floor.position.y = -0.15
	stage.add_child(floor)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(16.0, 0.3, 12.0)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("242432")
	material.roughness = 0.82
	mesh_instance.material_override = material
	floor.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collider.shape = shape
	floor.add_child(collider)
