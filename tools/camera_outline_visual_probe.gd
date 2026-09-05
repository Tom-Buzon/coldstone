extends SceneTree
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
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,2.2,5)
	camera.look_at(Vector3(0,1,0))
	camera.current = true
	var arm := SpringArm3D.new()
	stage.add_child(arm)
	var fader := Fader.new()
	stage.add_child(fader)
	fader.configure(camera,target,arm)
	fader.apply_settings(true,0.12,0.42)
	var enemy := (load(Catalog.definition(&"ngeneral").body_scene_path) as PackedScene).instantiate() as Node3D
	stage.add_child(enemy)
	enemy.position = Vector3(0,0,2)
	enemy.add_to_group("camera_occlusion_dynamic_actor")
	for i in 20: await process_frame
	fader.call("_scan_occluders")
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tmp/occlusion_outline.png")
	fader.outline.mask_viewport.get_texture().get_image().save_png("res://.tmp/occlusion_mask.png")
	var before: Image = fader.outline.mask_viewport.get_texture().get_image()
	assert(_turquoise_pixels(root.get_texture().get_image()) > 100, "No visible player silhouette")
	var skeleton := model.find_child("*", true, false) as Skeleton3D
	for node: Node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
	assert(skeleton != null)
	skeleton.set_bone_pose_rotation(0, Quaternion(Vector3.UP, 0.7))
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var after: Image = fader.outline.mask_viewport.get_texture().get_image()
	assert(before.get_data() != after.get_data(), "Animated/equipped mask did not update")
	var weapon_id := weapon.get_instance_id()
	weapon.hide()
	for i in 3: await process_frame
	assert(not fader.outline.copies.has(weapon_id), "Hidden equipment remained in silhouette")
	weapon.show()
	for i in 3: await process_frame
	assert(fader.outline.copies.has(weapon_id), "Re-equipped weapon missing from silhouette")
	fader.apply_outline_settings(Color.RED, 0.45)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(_turquoise_pixels(root.get_texture().get_image()) == 0, "Player outline color did not update")
	assert(is_equal_approx((fader.outline.overlay.material as ShaderMaterial).get_shader_parameter(&"outline_color").a, 0.45))
	fader.apply_outline_settings(Color.RED, 0.0)
	for i in 3: await process_frame
	assert(not fader.outline.overlay.visible, "Zero opacity must hide the outline")
	fader.apply_outline_settings(Color.RED, 1.0)
	fader.apply_settings(false, 0.12, 0.42)
	for i in 3: await process_frame
	assert(not fader.outline.overlay.visible, "Disabled occlusion must hide the outline")
	enemy.add_to_group(&"enemy_attack_outline_subject")
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(fader.outline.attack_overlay.visible, "Enemy warning pass did not render independently")
	assert(_red_pixels(root.get_texture().get_image()) > 100, "No visible scarlet enemy warning silhouette")
	print("PASS: separate rendered player/enemy silhouettes, equipment/pose update, color, opacity, disable")
	quit()

func _turquoise_pixels(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel := image.get_pixel(x,y)
			if pixel.r < 0.2 and pixel.g > 0.55 and pixel.b > 0.3:
				count += 1
	return count

func _red_pixels(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel := image.get_pixel(x,y)
			if pixel.r > 0.8 and pixel.g < 0.25 and pixel.b < 0.2:
				count += 1
	return count
