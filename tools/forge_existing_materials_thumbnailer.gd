extends SceneTree

const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const OUTPUT_PATH := "res://docs/world_editor/forge_existing_materials_stable.png"
const STYLES: Array[StringName] = [
	&"mediterranean_grass",
	&"poly_dirt",
	&"poly_sand",
	&"poly_mud_leaves",
	&"poly_stone_floor",
	&"poly_monastery_floor",
	&"poly_rock_ground",
	&"poly_plaster_wall",
]

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
	environment.ambient_light_color = Color(0.70, 0.75, 0.82)
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.light_energy = 0.58
	sun.shadow_enabled = true
	stage.add_child(sun)

	for index in range(STYLES.size()):
		var column := index % 4
		var row := index / 4
		var sample := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(8.3, 0.28, 7.2)
		sample.mesh = box
		sample.material_override = MaterialLibraryScript.material(STYLES[index])
		sample.position = Vector3((float(column) - 1.5) * 9.0, 0.0, (float(row) - 0.5) * 8.0)
		stage.add_child(sample)

	var camera := Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 36.0
	stage.add_child(camera)
	camera.position = Vector3(0.0, 29.0, 17.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	for _frame in range(10):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("FORGE_EXISTING_MATERIALS_THUMBNAIL %s (%s)" % [OUTPUT_PATH, error_string(error)])
	stage.free()
	quit(0 if error == OK else 1)
