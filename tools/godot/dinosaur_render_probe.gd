extends SceneTree

const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const BACKGROUND := Color(0.95, 0.0, 0.85, 1.0)

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for archetype: StringName in [&"velociraptor", &"tyrannosaurus"]:
		await _render_dinosaur(archetype)
	print("[DINOSAUR RENDER PROBE] RESULT=", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)


func _render_dinosaur(archetype: StringName) -> void:
	var viewport := SubViewport.new()
	viewport.name = "%sViewport" % String(archetype)
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.4
	environment_node.environment = environment
	stage.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	light.light_energy = 1.8
	stage.add_child(light)
	var enemy := EnemyFactoryScript.spawn(stage, archetype, Vector3.ZERO, null, {
		"ai_enabled": false,
		"match_perfect_hitbox": false,
	}) as HopliteDinosaurEnemy
	await process_frame
	await process_frame
	var camera := Camera3D.new()
	camera.fov = 42.0
	stage.add_child(camera)
	camera.current = true
	for animation_kind: StringName in [&"idle", &"run", &"attack"]:
		enemy._play_animation(animation_kind)
		for _frame: int in range(8):
			await process_frame
		var bounds := enemy._visual_world_bounds()
		var center := bounds.get_center()
		var radius := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		camera.look_at_from_position(center + Vector3(radius * 0.72, radius * 0.28, radius * 1.55), center, Vector3.UP)
		await process_frame
		await process_frame
		var changed_pixels := _count_changed_pixels(viewport.get_texture().get_image())
		var visible := changed_pixels >= 40
		print("[DINOSAUR RENDER PROBE] ", "PASS " if visible else "FAIL ", archetype, " ", animation_kind, " rendered pixels=", changed_pixels)
		_failed = _failed or not visible
	viewport.queue_free()
	await process_frame


func _count_changed_pixels(image: Image) -> int:
	var changed_pixels := 0
	for y: int in range(0, image.get_height(), 3):
		for x: int in range(0, image.get_width(), 3):
			var pixel := image.get_pixel(x, y)
			var color_delta := absf(pixel.r - BACKGROUND.r) + absf(pixel.g - BACKGROUND.g) + absf(pixel.b - BACKGROUND.b)
			if color_delta > 0.08:
				changed_pixels += 1
	return changed_pixels
