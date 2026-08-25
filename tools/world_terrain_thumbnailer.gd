extends SceneTree

const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")
const WorldTerrainFoliageScript = preload("res://scripts/world_editor/world_terrain_foliage.gd")
const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const OUTPUT_PATH := "res://docs/world_editor/terrain_layers_preview.png"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_build_and_capture")

func _build_and_capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.48, 0.60, 0.68)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.68)
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.84, 0.65)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	stage.add_child(sun)
	var properties := WorldTerrainScript.default_properties("rolling", 65, 6021)
	properties["width"] = 84.0
	properties["depth"] = 62.0
	properties["amplitude"] = 5.5
	properties["material"] = "dirt_path"
	WorldTerrainScript.regenerate(properties)
	WorldTerrainScript.paint_material(properties, Vector3(-14.0, 0.0, 2.0), "mediterranean_grass", 19.0, 7.0)
	WorldTerrainScript.paint_material(properties, Vector3(19.0, 0.0, -7.0), "rough_stone", 10.0, 5.0)
	WorldTerrainScript.paint_foliage(properties, Vector3(-14.0, 0.0, 2.0), 17.0, 7.0)
	var terrain := StaticBody3D.new()
	WorldTerrainScript.rebuild_body(terrain, properties, MaterialLibraryScript.terrain_material(properties))
	WorldTerrainFoliageScript.rebuild(terrain, properties, false)
	stage.add_child(terrain)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 47.0
	stage.add_child(camera)
	camera.position = Vector3(56.0, 43.0, 66.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	for _frame in range(8):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("WORLD_TERRAIN_THUMBNAIL %s (%s)" % [OUTPUT_PATH, error_string(error)])
	stage.free()
	quit(0 if error == OK else 1)
