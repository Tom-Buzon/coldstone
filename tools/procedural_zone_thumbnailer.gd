extends SceneTree

const MapGeneratorScript = preload("res://scripts/campaign/procedural_map_generator.gd")
const OUTPUT_DIR := "res://docs/environment_asset_catalog/zones"

var stage: Node3D
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_stage()
	call_deferred("_capture_zones")

func _build_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.09, 0.12, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.66, 0.76)
	environment.ambient_light_energy = 0.88
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = environment
	stage.add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.78, 0.58)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 48.0
	stage.add_child(camera)

func _capture_zones() -> void:
	await process_frame
	var zone_ids: Array[StringName] = [&"walls", &"city", &"dungeon"]
	for index: int in range(zone_ids.size()):
		var zone_id := zone_ids[index]
		for seed_offset: int in range(3):
			var generator := MapGeneratorScript.new() as HopliteProceduralMapGenerator
			var layout := generator.generate(stage, zone_id, 7200 + seed_offset)
			var generated := layout.get("zone_root") as Node3D
			var variant := int(layout.get("variant", -1))
			_configure_shot(zone_id)
			await process_frame
			await process_frame
			await process_frame
			var image := root.get_texture().get_image()
			var output_path := "%s/%s_v%d.png" % [OUTPUT_DIR, String(zone_id), variant]
			var error := image.save_png(ProjectSettings.globalize_path(output_path))
			print("[ZONE THUMBNAIL] %s variant %d -> %s (%s)" % [zone_id, variant, output_path, error_string(error)])
			generated.free()
	stage.free()
	quit(0)

func _configure_shot(zone_id: StringName) -> void:
	match zone_id:
		&"walls":
			environment.background_color = Color(0.12, 0.17, 0.25)
			sun.light_color = Color(1.0, 0.69, 0.47)
			camera.position = Vector3(66.0, 58.0, 76.0)
			camera.look_at(Vector3(0.0, 1.5, -2.0), Vector3.UP)
		&"city":
			environment.background_color = Color(0.17, 0.22, 0.30)
			sun.light_color = Color(1.0, 0.83, 0.67)
			camera.position = Vector3(70.0, 67.0, 82.0)
			camera.look_at(Vector3(0.0, 1.4, -4.0), Vector3.UP)
		_:
			environment.background_color = Color(0.018, 0.020, 0.028)
			environment.ambient_light_color = Color(0.34, 0.39, 0.52)
			environment.ambient_light_energy = 0.64
			sun.light_color = Color(0.44, 0.52, 0.72)
			camera.position = Vector3(50.0, 53.0, 63.0)
			camera.look_at(Vector3(0.0, 1.0, -5.0), Vector3.UP)
