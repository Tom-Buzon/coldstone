extends SceneTree

const SOURCE_PATH := "res://.tmp_tools/forge_pbr_replacement/mud_leaves_source.png"
const MATERIAL_ROOT := "res://assets/environment/materials/poly_haven/brown_mud_leaves_01"
const ALBEDO_PATH := MATERIAL_ROOT + "/brown_mud_leaves_01_diff_1k.jpg"
const NORMAL_PATH := MATERIAL_ROOT + "/brown_mud_leaves_01_nor_gl_1k.jpg"
const ROUGHNESS_PATH := MATERIAL_ROOT + "/brown_mud_leaves_01_rough_1k.jpg"
const TARGET_SIZE := 1024

func _initialize() -> void:
	var albedo := Image.new()
	var error := albedo.load(ProjectSettings.globalize_path(SOURCE_PATH))
	if error != OK or albedo.is_empty():
		push_error("FORGE PBR MAP BUILDER: cannot load %s (%s)" % [SOURCE_PATH, error_string(error)])
		quit(1)
		return
	albedo.resize(TARGET_SIZE, TARGET_SIZE, Image.INTERPOLATE_LANCZOS)
	albedo.convert(Image.FORMAT_RGB8)
	error = albedo.save_jpg(ProjectSettings.globalize_path(ALBEDO_PATH), 0.94)
	if error != OK:
		push_error("FORGE PBR MAP BUILDER: cannot save albedo (%s)" % error_string(error))
		quit(1)
		return

	var normal := albedo.duplicate()
	normal.convert(Image.FORMAT_L8)
	normal.bump_map_to_normal_map(1.8)
	error = normal.save_jpg(ProjectSettings.globalize_path(NORMAL_PATH), 0.96)
	if error != OK:
		push_error("FORGE PBR MAP BUILDER: cannot save normal (%s)" % error_string(error))
		quit(1)
		return

	var roughness := Image.create(TARGET_SIZE, TARGET_SIZE, false, Image.FORMAT_L8)
	for y in range(TARGET_SIZE):
		for x in range(TARGET_SIZE):
			var source := albedo.get_pixel(x, y)
			var leaf_signal := clampf((source.g - source.r * 0.92) * 4.0, 0.0, 1.0)
			var luminance := source.get_luminance()
			var value := clampf(0.97 - leaf_signal * 0.11 + (0.45 - luminance) * 0.05, 0.82, 0.99)
			roughness.set_pixel(x, y, Color(value, value, value))
	error = roughness.save_jpg(ProjectSettings.globalize_path(ROUGHNESS_PATH), 0.96)
	if error != OK:
		push_error("FORGE PBR MAP BUILDER: cannot save roughness (%s)" % error_string(error))
		quit(1)
		return

	print("FORGE_PBR_MAPS_OK size=%d albedo=%s normal=%s roughness=%s" % [TARGET_SIZE, ALBEDO_PATH, NORMAL_PATH, ROUGHNESS_PATH])
	quit(0)
