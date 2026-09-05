extends SceneTree

## Compatibility pixel regression: fade must remove the inward-facing wall,
## keep the exterior translucent, then restore the authored double-sided wall.
const Fader = preload("res://scripts/camera/camera_occlusion_fader.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.05,0.4,0.8)
	stage.add_child(environment)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	var target := Node3D.new()
	target.position = Vector3(0,0,-4)
	stage.add_child(target)
	var arm := SpringArm3D.new()
	stage.add_child(arm)
	var fader := Fader.new()
	stage.add_child(fader)
	fader.configure(camera,target,arm)
	fader.apply_settings(true,0.12,0.42)
	fader.apply_outline_settings(Color.RED,0)
	fader.set_physics_process(false)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	(box.mesh as BoxMesh).size = Vector3(2,2,2)
	var authored := StandardMaterial3D.new()
	authored.cull_mode = BaseMaterial3D.CULL_DISABLED
	authored.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	authored.albedo_color = Color(0.65,0.03,0.08)
	box.mesh.surface_set_material(0, authored)
	stage.add_child(box)
	box.hide()
	var background: Color = await _pixel()
	box.show()
	var opaque_inside: Color = await _pixel()
	fader.call("_mark_occluded",box)
	fader.call("_process",1.0)
	var faded_inside: Color = await _pixel()
	camera.position.z = 3.0
	var faded_outside: Color = await _pixel()
	fader.apply_settings(false,0.12,0.42)
	fader.call("_process",1.0)
	camera.position.z = 0.0
	var restored_inside: Color = await _pixel()
	var passed := _distance(background, faded_inside) < 0.01 and _distance(background, opaque_inside) > 0.3 and _distance(background, faded_outside) > 0.01 and _distance(opaque_inside,restored_inside) < 0.01
	print("BACKFACE PIXELS background=",background," opaque_inside=",opaque_inside," faded_inside=",faded_inside," faded_outside=",faded_outside," restored_inside=",restored_inside)
	if not passed:
		push_error("Interior/exterior fade pixel regression")
		quit(1)
		return
	print("PASS: interior wall absent, exterior translucent, double-sided restoration")
	quit()
func _pixel() -> Color:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return image.get_pixel(image.get_width()/2, image.get_height()/2)
func _distance(a: Color,b: Color) -> float:
	return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))
