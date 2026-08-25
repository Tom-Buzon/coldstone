extends RefCounted
class_name HopliteProceduralMaterialLibrary

const TRIPLANAR_SHADER: Shader = preload("res://scripts/environment/triplanar_pbr.gdshader")
const TERRAIN_BLEND_SHADER: Shader = preload("res://scripts/environment/terrain_layer_blend.gdshader")
const TEXTURE_ROOT := "res://_source/environment_props_raw/texture"
const TERRAIN_TEXTURE_ROOT := "res://assets/environment/terrain"
const MAX_RUNTIME_TEXTURE_SIZE := 1024

static var texture_cache: Dictionary = {}
static var material_cache: Dictionary = {}
static var uv_material_cache: Dictionary = {}
static var terrain_material_cache: Dictionary = {}

static func material(style: StringName) -> Material:
	if material_cache.has(style):
		return material_cache[style]
	var config := _style_config(style)
	var albedo := _runtime_texture(String(config.get("albedo", "")))
	if albedo == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = config.get("fallback", Color(0.48, 0.40, 0.31))
		fallback.roughness = float(config.get("roughness", 0.82))
		material_cache[style] = fallback
		return fallback

	var result := ShaderMaterial.new()
	result.shader = TRIPLANAR_SHADER
	result.set_shader_parameter("albedo_texture", albedo)
	result.set_shader_parameter("tint", config.get("tint", Color.WHITE))
	result.set_shader_parameter("texture_scale", float(config.get("scale", 0.28)))
	result.set_shader_parameter("blend_sharpness", float(config.get("blend", 5.0)))
	result.set_shader_parameter("roughness_value", float(config.get("roughness", 0.82)))
	result.set_shader_parameter("derived_relief", float(config.get("relief", 0.45)))

	var normal := _runtime_texture(String(config.get("normal", "")))
	if normal != null:
		result.set_shader_parameter("normal_texture", normal)
		result.set_shader_parameter("use_normal_texture", true)
		result.set_shader_parameter("normal_strength", float(config.get("normal_strength", 0.65)))
	var roughness := _runtime_texture(String(config.get("roughness_map", "")))
	if roughness != null:
		result.set_shader_parameter("roughness_texture", roughness)
		result.set_shader_parameter("use_roughness_texture", true)
	material_cache[style] = result
	return result

static func uv_material(style: StringName) -> Material:
	if uv_material_cache.has(style):
		return uv_material_cache[style]
	var config := _style_config(style)
	var result := StandardMaterial3D.new()
	result.albedo_color = config.get("tint", Color.WHITE)
	result.roughness = float(config.get("roughness", 0.82))
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var albedo := _runtime_texture(String(config.get("albedo", "")))
	if albedo != null:
		result.albedo_texture = albedo
	else:
		result.albedo_color = config.get("fallback", Color(0.48, 0.40, 0.31))
	uv_material_cache[style] = result
	return result

static func terrain_material(properties: Dictionary) -> Material:
	var base_style := StringName(properties.get("material", "dirt_path"))
	var styles: Array[StringName] = [base_style]
	var layers := properties.get("paint_layers", []) as Array
	for index in range(3):
		var layer_style := StringName(layers[index]) if index < layers.size() and not String(layers[index]).is_empty() else base_style
		styles.append(layer_style)
	var cache_key := "%s|%s|%s|%s" % [styles[0], styles[1], styles[2], styles[3]]
	if terrain_material_cache.has(cache_key):
		return terrain_material_cache[cache_key]
	var result := ShaderMaterial.new()
	result.shader = TERRAIN_BLEND_SHADER
	var base_texture: ImageTexture
	for index in range(styles.size()):
		var config := _style_config(styles[index])
		var texture := _runtime_texture(String(config.get("albedo", "")))
		if index == 0:
			base_texture = texture
		if texture == null:
			texture = base_texture
		result.set_shader_parameter("layer%d_texture" % index, texture)
		result.set_shader_parameter("layer%d_tint" % index, config.get("tint", Color.WHITE))
		result.set_shader_parameter("layer%d_scale" % index, float(config.get("scale", 0.24)))
		result.set_shader_parameter("layer%d_roughness" % index, float(config.get("roughness", 0.9)))
	terrain_material_cache[cache_key] = result
	return result

static func preview_path(style: StringName) -> String:
	return String(_style_config(style).get("albedo", ""))

static func _runtime_texture(path: String) -> ImageTexture:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK or image.is_empty():
		push_warning("[PBR MATERIAL] Could not load %s (error %d)." % [path, error])
		return null
	var largest_side := maxi(image.get_width(), image.get_height())
	if largest_side > MAX_RUNTIME_TEXTURE_SIZE:
		var ratio := float(MAX_RUNTIME_TEXTURE_SIZE) / float(largest_side)
		image.resize(
			maxi(1, roundi(float(image.get_width()) * ratio)),
			maxi(1, roundi(float(image.get_height()) * ratio)),
			Image.INTERPOLATE_LANCZOS
		)
	if not image.has_mipmaps():
		image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	texture_cache[path] = texture
	return texture

static func _style_config(style: StringName) -> Dictionary:
	match style:
		&"mediterranean_grass":
			return {
				"albedo": TERRAIN_TEXTURE_ROOT + "/mediterranean_grass_albedo.png",
				"tint": Color(0.38, 0.48, 0.42), "scale": 0.32,
				"roughness": 0.98, "relief": 0.42, "fallback": Color(0.31, 0.34, 0.12)
			}
		&"dirt_path":
			return {
				"albedo": TEXTURE_ROOT + "/Dusty_dirt_path_game_texture_202608221752.jpeg",
				"tint": Color(0.82, 0.76, 0.65), "scale": 0.18,
				"roughness": 0.96, "relief": 0.56, "fallback": Color(0.29, 0.22, 0.16)
			}
		&"scorched_ground":
			return {
				"albedo": TEXTURE_ROOT + "/Scorched_grass_and_bone_texture_202608221751.jpeg",
				"tint": Color(0.78, 0.68, 0.54), "scale": 0.20,
				"roughness": 0.98, "relief": 0.58, "fallback": Color(0.19, 0.14, 0.10)
			}
		&"cracked_weeds":
			return {
				"albedo": TEXTURE_ROOT + "/Patchy_weeds_on_cracked_earth_202608221751.jpeg",
				"tint": Color(0.76, 0.76, 0.62), "scale": 0.19,
				"roughness": 0.95, "relief": 0.50, "fallback": Color(0.23, 0.25, 0.17)
			}
		&"bone_gravel":
			return {
				"albedo": TEXTURE_ROOT + "/Game_texture_with_gravel_rocks_202608221923.jpeg",
				"tint": Color(0.83, 0.78, 0.68), "scale": 0.22,
				"roughness": 0.96, "relief": 0.68, "fallback": Color(0.24, 0.22, 0.19)
			}
		&"limestone_brick":
			return {
				"albedo": TEXTURE_ROOT + "/Limestone_brick_wall_texture_2K_202608212340.jpeg",
				"tint": Color(0.96, 0.92, 0.82), "scale": 0.23,
				"roughness": 0.82, "relief": 0.48, "fallback": Color(0.67, 0.61, 0.51)
			}
		&"fortress":
			return {
				"albedo": TEXTURE_ROOT + "/Limestone_fortress_wall_texture_2K_202608212340.jpeg",
				"tint": Color(0.93, 0.91, 0.86), "scale": 0.23,
				"roughness": 0.86, "relief": 0.62, "fallback": Color(0.62, 0.57, 0.48)
			}
		&"rough_stone":
			return {
				"albedo": TEXTURE_ROOT + "/Rough_stone_wall_texture_2K_202608212338.jpeg",
				"tint": Color(0.82, 0.78, 0.70), "scale": 0.30,
				"roughness": 0.92, "relief": 0.72, "fallback": Color(0.38, 0.34, 0.29)
			}
		&"marble":
			return {
				"albedo": TEXTURE_ROOT + "/Marble_wall_game_texture_2K_202608212340.jpeg",
				"tint": Color(0.96, 0.95, 0.90), "scale": 0.20,
				"roughness": 0.58, "relief": 0.24, "fallback": Color(0.76, 0.73, 0.66)
			}
		&"white_marble_floor":
			return {
				"albedo": TEXTURE_ROOT + "/White_marble_floor_texture_2K_202608212340.jpeg",
				"tint": Color(0.82, 0.80, 0.74), "scale": 0.19,
				"roughness": 0.54, "relief": 0.22, "fallback": Color(0.82, 0.80, 0.74)
			}
		&"mural":
			return {
				"albedo": TEXTURE_ROOT + "/Ancient_Greek_mural_game_texture_202608212338.jpeg",
				"tint": Color(0.90, 0.88, 0.80), "roughness": 0.78, "fallback": Color(0.24, 0.32, 0.40)
			}
		&"ornate_stone_wall":
			return {
				"albedo": TEXTURE_ROOT + "/Stone_wall_game_texture_2K_202608212340.jpeg",
				"tint": Color(0.88, 0.90, 0.94), "roughness": 0.88, "fallback": Color(0.17, 0.20, 0.25)
			}
		&"sandstone_floor":
			return {
				"albedo": TEXTURE_ROOT + "/Sandstone_floor_blocks_texture_2K_202608212340.jpeg",
				"tint": Color(0.83, 0.75, 0.62), "scale": 0.25,
				"roughness": 0.88, "relief": 0.42, "fallback": Color(0.49, 0.37, 0.25)
			}
		_:
			return {
				"albedo": TEXTURE_ROOT + "/Limestone_pavers_game_texture_2K_202608212340.jpeg",
				"tint": Color(0.88, 0.84, 0.75), "scale": 0.26,
				"roughness": 0.84, "relief": 0.38, "fallback": Color(0.55, 0.47, 0.36)
			}
