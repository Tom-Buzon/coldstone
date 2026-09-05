extends SceneTree

const FaderScript = preload("res://scripts/camera/camera_occlusion_fader.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "TrainingGround"
	root.add_child(world)
	current_scene = world
	var target := Node3D.new()
	world.add_child(target)
	var arm := SpringArm3D.new()
	arm.collision_mask = 5
	world.add_child(arm)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.0, 4.0)
	world.add_child(camera)

	var fader := FaderScript.new() as HopliteCameraOcclusionFader
	world.add_child(fader)
	fader.configure(camera, target, arm)
	fader.apply_settings(true, 0.12, 0.30)

	var blocker := _box(Vector3(0.0, 2.56, 2.0))
	world.add_child(blocker)
	var large_blocker := _static_box(world, Vector3(0.0, 3.28, 3.0), Vector3(30.0, 2.0, 0.5))
	var roof := _static_box(world, Vector3(0.0, 2.56, 2.0), Vector3(30.0, 0.20, 2.0))
	var side_layer := _static_box(world, Vector3(0.30, 2.56, 2.0), Vector3(0.14, 20.0, 1.0))
	var camera_wall := _static_box(world, Vector3(0.40, 4.0, 4.0), Vector3(0.12, 20.0, 0.60))
	var base_terrain := _static_box(world, Vector3(0.0, 2.70, 2.0), Vector3(60.0, 0.12, 2.0), "BaseTerrain")
	var clear_visual := _box(Vector3(3.0, 2.56, 2.0))
	world.add_child(clear_visual)
	var front_contact_body := StaticBody3D.new()
	front_contact_body.position = Vector3(0.0, 1.12, -0.28)
	world.add_child(front_contact_body)
	var front_contact := _box(Vector3.ZERO, Vector3(0.8, 2.2, 1.4))
	front_contact_body.add_child(front_contact)
	var front_contact_collision := CollisionShape3D.new()
	var front_contact_shape := BoxShape3D.new()
	front_contact_shape.size = Vector3(0.8, 2.2, 1.4)
	front_contact_collision.shape = front_contact_shape
	front_contact_body.add_child(front_contact_collision)
	var broad_batch := _box(Vector3(0.0, -4.0, 2.0), Vector3(40.0, 8.0, 40.0))
	world.add_child(broad_batch)
	var player_visual := _box(Vector3(0.0, 1.12, 0.0))
	target.add_child(player_visual)
	for index: int in 128:
		var distant_visual := _box(Vector3(32.0 + float(index % 16), float(index / 16), -24.0))
		world.add_child(distant_visual)
	await physics_frame
	fader.call("_scan_occluders")
	for index: int in 12:
		fader.call("_process", 0.05)

	_require(arm.collision_mask == 0, "enabled readability pass must let the SpringArm keep its ideal distance")
	_require(fader.get_active_occluder_count() == 5, "all five blocking layers around a large building should be marked as occluders")
	_require(_surface_alpha(blocker) < 0.20, "blocking geometry did not receive a Compatibility-safe transparent material")
	_require(_surface_alpha(large_blocker) < 0.20, "large colliding geometry did not receive a Compatibility-safe transparent material")
	_require(_surface_alpha(roof) < 0.20, "an elevated roof crossing the camera view was not faded")
	_require(_surface_alpha(side_layer) < 0.20, "an offset building layer inside the protected corridor was not faded")
	_require(_surface_alpha(camera_wall) < 0.20, "a wall overlapping the camera was not faded")
	_require(is_equal_approx(_surface_alpha(base_terrain), 1.0), "the base terrain must never receive camera occlusion fading")
	_require(blocker.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "faded geometry still casts an opaque shadow")
	_require(blocker.material_overlay == null, "camera occlusion should not add an outline overlay")
	_require(is_equal_approx(_surface_alpha(clear_visual), 1.0), "off-axis geometry was faded")
	_require(is_equal_approx(_surface_alpha(front_contact), 1.0), "geometry touching the front of the player was incorrectly classified as camera occlusion")
	_require(is_equal_approx(_surface_alpha(broad_batch), 1.0), "a large batch was faded from its coarse AABB without a real collision hit")
	_require(is_equal_approx(_surface_alpha(player_visual), 1.0), "player-owned geometry must never be faded")
	_require(fader.get_registered_visual_count() >= 138, "automatically added render nodes were not registered")
	_require(fader.get_last_visual_candidate_count() < 16, "the spatial query visited distant visuals instead of only the camera corridor")

	var registered_before_late_add := fader.get_registered_visual_count()
	var late_blocker := _box(Vector3(-0.28, 2.56, 2.0))
	world.add_child(late_blocker)
	await process_frame
	fader.call("_scan_occluders")
	for index: int in 12:
		fader.call("_process", 0.05)
	_require(fader.get_registered_visual_count() == registered_before_late_add + 1, "a runtime-added visual was not registered automatically")
	_require(_surface_alpha(late_blocker) < 0.20, "a runtime-added render-only occluder was not faded")
	late_blocker.queue_free()
	await process_frame
	_require(fader.get_registered_visual_count() == registered_before_late_add, "a removed visual remained in the spatial registry")
	var moving_body := AnimatableBody3D.new()
	moving_body.position = Vector3(12.0, 2.56, 2.0)
	world.add_child(moving_body)
	var moving_visual := _box(Vector3.ZERO)
	moving_body.add_child(moving_visual)
	var moving_collision := CollisionShape3D.new()
	var moving_shape := BoxShape3D.new()
	moving_shape.size = Vector3(0.8, 2.2, 0.8)
	moving_collision.shape = moving_shape
	moving_body.add_child(moving_collision)
	await physics_frame
	moving_body.position = Vector3(-0.28, 2.56, 2.0)
	await physics_frame
	fader.call("_scan_occluders")
	for index: int in 12:
		fader.call("_process", 0.05)
	_require(_surface_alpha(moving_visual) < 0.20, "a moving physics occluder was not followed live by the collision pass")
	moving_body.queue_free()
	await process_frame

	# Enemy V2 mass mode has no active CharacterBody collider. Its dedicated
	# dynamic cache must still preserve the ordinary see-through-camera feature.
	var mass_actor := CharacterBody3D.new()
	mass_actor.position = Vector3(0.55, 0.0, 1.0)
	mass_actor.collision_layer = 0
	mass_actor.collision_mask = 0
	mass_actor.add_to_group(&"camera_occlusion_dynamic_actor")
	world.add_child(mass_actor)
	var mass_visual := _box(Vector3(0.0, 1.10, 0.0))
	mass_actor.add_child(mass_visual)
	await process_frame
	fader.call("_refresh_dynamic_actor_cache")
	fader.call("_scan_occluders")
	for index: int in 12:
		fader.call("_process", 0.05)
	_require(_surface_alpha(mass_visual) < 0.20, "a collider-free Enemy V2 mass actor did not fade between camera and player")
	mass_actor.queue_free()
	await process_frame

	var authoritative_owner := Node3D.new()
	authoritative_owner.position = Vector3(0.0, 0.0, 2.0)
	authoritative_owner.set_meta(&"camera_occlusion_collider_authoritative", true)
	world.add_child(authoritative_owner)
	# Reproduce a malformed imported skin: the rendered AABB is nowhere near
	# the separate traversal collider even though that collider blocks the ray.
	var authoritative_visual := _box(Vector3(128.0, 2.56, 0.0))
	authoritative_owner.add_child(authoritative_visual)
	var authoritative_body := AnimatableBody3D.new()
	authoritative_body.position = Vector3(12.0, 2.56, 2.0)
	authoritative_body.set_meta(&"giant_owner", authoritative_owner)
	world.add_child(authoritative_body)
	var authoritative_collision := CollisionShape3D.new()
	var authoritative_shape := BoxShape3D.new()
	authoritative_shape.size = Vector3(0.8, 2.2, 0.8)
	authoritative_collision.shape = authoritative_shape
	authoritative_body.add_child(authoritative_collision)
	await physics_frame
	authoritative_body.position = Vector3(-0.28, 2.56, 2.0)
	await physics_frame
	fader.call("_scan_occluders")
	for index: int in 12:
		fader.call("_process", 0.05)
	_require(_surface_alpha(authoritative_visual) < 0.20, "an authoritative collider did not fade a malformed imported visual")

	# A tail/traversal collider may remain behind the player while the giant's
	# centre is already in front. That must not hide the entire creature.
	authoritative_owner.position = Vector3(0.0, 0.0, -4.0)
	await physics_frame
	fader.call("_scan_occluders")
	for index: int in 20:
		fader.call("_process", 0.05)
	_require(is_equal_approx(_surface_alpha(authoritative_visual), 1.0), "a giant in front of the player stayed hidden because its tail collider crossed the camera corridor")
	authoritative_body.queue_free()
	authoritative_owner.queue_free()
	await process_frame

	fader.apply_settings(false, 0.12, 0.30)
	for index: int in 12:
		fader.call("_process", 0.05)
	_require(arm.collision_mask == 5, "disabling readability did not restore the SpringArm collision mask")
	_require(blocker.get_surface_override_material(0) == null, "disabling readability did not restore original surface materials")
	_require(large_blocker.get_surface_override_material(0) == null, "large blocker surface material was not restored")
	_require(roof.get_surface_override_material(0) == null, "roof surface material was not restored")
	_require(side_layer.get_surface_override_material(0) == null, "offset layer surface material was not restored")
	_require(camera_wall.get_surface_override_material(0) == null, "camera-overlap surface material was not restored")
	_require(base_terrain.get_surface_override_material(0) == null, "the base terrain unexpectedly received a surface override")
	_require(blocker.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "disabling readability did not restore shadow casting")
	_require(blocker.material_overlay == null, "disabling readability did not restore the original material overlay")

	current_scene = null
	world.queue_free()
	if failures.is_empty():
		print("PASS: camera occlusion readability")
		quit(0)
		return
	for failure: String in failures:
		push_error("[CAMERA OCCLUSION] " + failure)
	quit(1)


func _box(position: Vector3, size: Vector3 = Vector3(0.8, 2.2, 0.8)) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.46, 0.78, 1.0)
	mesh.material = material
	visual.mesh = mesh
	visual.position = position
	return visual


func _static_box(parent: Node3D, position: Vector3, size: Vector3, body_name: String = "") -> MeshInstance3D:
	var body := StaticBody3D.new()
	if not body_name.is_empty():
		body.name = body_name
	body.position = position
	parent.add_child(body)
	var visual := _box(Vector3.ZERO, size)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return visual


func _surface_alpha(visual: MeshInstance3D) -> float:
	var material := visual.get_surface_override_material(0) as BaseMaterial3D
	if material == null:
		material = visual.mesh.surface_get_material(0) as BaseMaterial3D
	return material.albedo_color.a if material != null else 1.0


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
