extends SceneTree

const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const OUTPUT_PATH := "res://docs/world_editor/forge_pbr_mud_antitiling.png"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_build_and_capture.call_deferred()

func _build_and_capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171d26")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.light_energy = 0.62
	stage.add_child(sun)

	var sample := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(32.0, 0.28, 18.0)
	sample.mesh = box
	sample.material_override = MaterialLibraryScript.material(&"poly_mud_leaves")
	stage.add_child(sample)

	var camera := Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	stage.add_child(camera)
	camera.position = Vector3(0.0, 27.0, 12.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	for _frame in range(10):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("FORGE_PBR_MUD_THUMBNAIL %s (%s)" % [OUTPUT_PATH, error_string(error)])
	stage.free()
	quit(0 if error == OK else 1)
