extends SceneTree

## Render with Compatibility. Reproduces a collider-free hoplite surrounding
## the camera while its origin lies behind the camera plane.
const Fader = preload("res://scripts/camera/camera_occlusion_fader.gd")
const Catalog = preload("res://scripts/enemy_v2/hoplite_v2_catalog.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(960,720)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var target := Node3D.new()
	stage.add_child(target)
	var model := (load("res://assets/runtime/ual1/UAL1_Standard.glb") as PackedScene).instantiate()
	target.add_child(model)
	var weapon := MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.08,1.8,0.08)
	weapon.mesh = blade
	weapon.position = Vector3(0.75,1.3,0)
	target.add_child(weapon)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08,0.35,0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	stage.add_child(env)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1.3,1.97)
	camera.look_at(Vector3(0,1.3,0))
	camera.current = true
	var arm := SpringArm3D.new()
	stage.add_child(arm)
	var fader := Fader.new()
	stage.add_child(fader)
	fader.configure(camera,target,arm)
	fader.apply_settings(true,0.12,0.42)
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	enemy.add_child((load(Catalog.definition(&"ngeneral").body_scene_path) as PackedScene).instantiate())
	stage.add_child(enemy)
	enemy.position = Vector3(0,0,2)
	enemy.add_to_group("camera_occlusion_dynamic_actor")
	for i in 20: await process_frame
	fader.call("_scan_occluders")
	fader.call("_process", 1.0)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tmp/hoplite_camera_inside.png")
	fader.outline.mask_viewport.get_texture().get_image().save_png("res://.tmp/hoplite_close_mask.png")
	var checked_surfaces := 0
	for node: Node in enemy.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name != &"SPARTAN_character_body":
			continue
		for index: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index) as BaseMaterial3D
			if material == null or not is_equal_approx(material.albedo_color.a, 0.12) or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				push_error("Body surface remained opaque around the camera")
				quit(1)
				return
			checked_surfaces += 1
	if checked_surfaces != 2:
		push_error("Expected the actual hoplite opaque and cutout body surfaces")
		quit(1)
		return
	print("PASS: camera inside real hoplite; both body surfaces faded")
	quit()
