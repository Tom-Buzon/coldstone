extends SceneTree

const PackageScript = preload("res://scripts/enemy/spartan_character_package.gd")
const SCENE := preload("res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb")
const OUTPUT := "res://docs/enemy_refactor/hoplite_merged_skin_visual_probe.png"

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	root.size = Vector2i(1000, 700)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.12, 0.15, 0.20)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color.WHITE
	environment_resource.ambient_light_energy = 1.2
	environment.environment = environment_resource
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	light.light_energy = 1.4
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.2, 5.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
	stage.add_child(camera)
	for index: int in range(2):
		var character := SCENE.instantiate() as Node3D
		character.position = Vector3(-0.8 if index == 0 else 0.8, 0.0, 0.0)
		stage.add_child(character)
		var adapter := PackageScript.new() as HopliteSpartanCharacterPackage
		if not adapter.bind(character):
			push_error("HOPLITE_MERGED_SKIN_PROBE bind failed")
			quit(1)
			return
		if index == 1 and not adapter.optimize_body_meshes():
			push_error("HOPLITE_MERGED_SKIN_PROBE merge failed")
			quit(1)
			return
		var skeleton := adapter.skeleton
		var upper_arm := skeleton.find_bone("DEF-upper_arm.L")
		var forearm := skeleton.find_bone("DEF-forearm.L")
		skeleton.set_bone_pose_rotation(upper_arm, Quaternion(Vector3.FORWARD, 1.15))
		skeleton.set_bone_pose_rotation(forearm, Quaternion(Vector3.UP, 0.85))
		skeleton.force_update_all_bone_transforms()
		if index == 1:
			print("HOPLITE_MERGED_SKIN_STATE parent=", adapter.merged_body.get_parent().get_path(), " skeleton_path=", adapter.merged_body.skeleton, " skin_binds=", adapter.merged_body.skin.get_bind_count(), " format=", adapter.merged_body.mesh.surface_get_format(0))
	var left_label := Label3D.new()
	left_label.text = "10 MESHES"
	left_label.position = Vector3(-0.8, 2.25, 0.0)
	left_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage.add_child(left_label)
	var right_label := Label3D.new()
	right_label.text = "MERGED"
	right_label.position = Vector3(0.8, 2.25, 0.0)
	right_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage.add_child(right_label)
	for _frame: int in range(5):
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if save_error != OK:
		push_error("HOPLITE_MERGED_SKIN_PROBE save failed")
		quit(1)
		return
	print("HOPLITE_MERGED_SKIN_PROBE saved=", OUTPUT)
	quit(0)
