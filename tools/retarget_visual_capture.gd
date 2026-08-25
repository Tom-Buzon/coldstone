extends SceneTree

const TARGET_PATH := "res://assets/runtime/ual1/UAL1_Standard.glb"
const BankScript = preload("res://scripts/animation/external_animation_bank.gd")
const CAPTURES := {
	&"light1": 0.50,
	&"light2": 0.50,
	&"heavy_max": 0.58,
	&"spin_high": 0.52,
	&"spin_low": 0.52,
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.name = "RetargetCaptureViewport"
	viewport.size = Vector2i(720, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.065, 0.085)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.88)
	env.ambient_light_energy = 1.1
	environment.environment = env
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_energy = 2.1
	stage.add_child(light)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(7.0, 7.0)
	floor.mesh = floor_mesh
	stage.add_child(floor)

	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(3.15, 1.55, 4.15)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.fov = 48.0
	camera.current = true

	var packed := load(TARGET_PATH) as PackedScene
	var mannequin := packed.instantiate() if packed != null else null
	if mannequin == null:
		quit(1)
		return
	var display_root := Node3D.new()
	display_root.rotation.y = PI
	display_root.add_child(mannequin)
	stage.add_child(display_root)
	_disable_animation_trees(mannequin)
	var skeleton := _find_skeleton(mannequin)
	var animation_player := _find_animation_player(mannequin)
	if skeleton == null or animation_player == null:
		quit(1)
		return
	animation_player.stop()
	_add_test_sword(skeleton)
	var bank := BankScript.new() as HopliteExternalAnimationBank
	stage.add_child(bank)
	if not bank.configure(skeleton):
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/retarget_captures"))
	for raw_key: Variant in CAPTURES:
		var key := StringName(raw_key)
		var donor: Dictionary = bank.donors.get(key, {})
		var donor_player := donor.get("player") as AnimationPlayer
		var source := donor.get("skeleton") as Skeleton3D
		var bridge := donor.get("bridge") as HopliteAuthoredPoseBridge
		var clip := StringName(donor.get("clip", StringName()))
		var animation := donor_player.get_animation(clip) if donor_player != null else null
		if source == null or bridge == null or animation == null:
			continue
		skeleton.reset_bone_poses()
		donor_player.play(clip)
		donor_player.advance(0.0)
		donor_player.seek(animation.length * float(CAPTURES[key]), true)
		donor_player.pause()
		source.advance(0.0)
		bridge.set_attack_weight(1.0, true, 1.0)
		bridge.call("_process_modification_with_delta", 0.0)
		await process_frame
		await process_frame
		var texture := viewport.get_texture()
		var image := texture.get_image() if texture != null else null
		var path := "res://.godot/retarget_captures/%s.png" % key
		if image == null:
			push_error("[RETARGET CAPTURE] renderer did not produce " + path)
		else:
			var error := image.save_png(ProjectSettings.globalize_path(path))
			print("[RETARGET CAPTURE] ", path, " size=", image.get_size(), " error=", error)
		bridge.set_attack_weight(0.0, false, 0.0)
	viewport.queue_free()
	await process_frame
	quit()

func _disable_animation_trees(node: Node) -> void:
	if node is AnimationTree:
		(node as AnimationTree).active = false
	for child: Node in node.get_children():
		_disable_animation_trees(child)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _add_test_sword(skeleton: Skeleton3D) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "DEF-hand.R"
	skeleton.add_child(attachment)
	var sword := Node3D.new()
	attachment.add_child(sword)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.075, 0.92, 0.035)
	blade.mesh = blade_mesh
	blade.position.y = 0.55
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color(0.72, 0.78, 0.88)
	blade_material.metallic = 0.85
	blade.material_override = blade_material
	sword.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.32, 0.055, 0.07)
	guard.mesh = guard_mesh
	guard.position.y = 0.07
	var guard_material := StandardMaterial3D.new()
	guard_material.albedo_color = Color(0.45, 0.19, 0.04)
	guard.material_override = guard_material
	sword.add_child(guard)
