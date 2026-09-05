extends RefCounted
class_name HopliteProceduralMaterialLibrary

const TRIPLANAR_SHADER: Shader = preload("res://scripts/environment/triplanar_pbr.gdshader")
const TERRAIN_BLEND_SHADER: Shader = preload("res://scripts/environment/terrain_layer_blend.gdshader")
const MaterialCatalogScript = preload("res://scripts/environment/material_catalog.gd")
const TEXTURE_ROOT := "res://_source/environment_props_raw/texture"
const TERRAIN_TEXTURE_ROOT := "res://assets/environment/terrain"
const MAX_RUNTIME_TEXTURE_SIZE := 1024
const MAX_TERRAIN_CATALOG_TEXTURE_SIZE := 512
const MAX_TERRAIN_CATALOG_LAYERS := 32

static var texture_cache: Dictionary = {}
static var material_cache: Dictionary = {}
static var uv_material_cache: Dictionary = {}
static var terrain_material_cache: Dictionary = {}
static var terrain_catalog_texture_array: Texture2DArray

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
	result.set_shader_parameter("anti_tiling_strength", float(config.get("anti_tiling", 0.075)))
	result.set_shader_parameter("macro_variation_strength", float(config.get("macro_variation", 0.06)))
	result.set_shader_parameter("variation_seed", _style_seed(style))
	result.set_shader_parameter("mirror_repeat", bool(config.get("mirror_repeat", not config.has("normal"))))
	result.set_shader_parameter("secondary_rotation", float(config.get("secondary_rotation", 0.0)))

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
	var normal := _runtime_texture(String(config.get("normal", "")))
	if normal != null:
		result.normal_enabled = true
		result.normal_texture = normal
		result.normal_scale = float(config.get("normal_strength", 0.65))
	var roughness := _runtime_texture(String(config.get("roughness_map", "")))
	if roughness != null:
		result.roughness_texture = roughness
		result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	uv_material_cache[style] = result
	return result

static func terrain_material(properties: Dictionary) -> Material:
	var base_style := StringName(properties.get("material", "dirt_path"))
	var result := ShaderMaterial.new()
	result.shader = TERRAIN_BLEND_SHADER
	var styles: Array[String] = MaterialCatalogScript.all_ids()
	var tints := PackedColorArray()
	var scales := PackedFloat32Array()
	var roughness_values := PackedFloat32Array()
	var anti_tiling_values := PackedFloat32Array()
	var macro_variation_values := PackedFloat32Array()
	var seeds := PackedFloat32Array()
	var mirror_repeat_values := PackedFloat32Array()
	var secondary_rotations := PackedFloat32Array()
	for index in range(MAX_TERRAIN_CATALOG_LAYERS):
		var style := StringName(styles[index]) if index < styles.size() else base_style
		var config := _style_config(style)
		tints.append(config.get("tint", Color.WHITE))
		scales.append(float(config.get("scale", 0.24)))
		roughness_values.append(float(config.get("roughness", 0.9)))
		anti_tiling_values.append(float(config.get("anti_tiling", 0.075)))
		macro_variation_values.append(float(config.get("macro_variation", 0.06)))
		seeds.append(_style_seed(style))
		mirror_repeat_values.append(1.0 if bool(config.get("mirror_repeat", not config.has("normal"))) else 0.0)
		secondary_rotations.append(float(config.get("secondary_rotation", 0.0)))
	result.set_shader_parameter("catalog_textures", _terrain_catalog_texture_array())
	result.set_shader_parameter("base_layer_index", maxi(0, styles.find(String(base_style))))
	result.set_shader_parameter("catalog_layer_count", mini(styles.size(), MAX_TERRAIN_CATALOG_LAYERS))
	result.set_shader_parameter("layer_tints", tints)
	result.set_shader_parameter("layer_scales", scales)
	result.set_shader_parameter("layer_roughness", roughness_values)
	result.set_shader_parameter("layer_anti_tiling", anti_tiling_values)
	result.set_shader_parameter("layer_macro_variation", macro_variation_values)
	result.set_shader_parameter("layer_seeds", seeds)
	result.set_shader_parameter("layer_mirror_repeat", mirror_repeat_values)
	result.set_shader_parameter("layer_secondary_rotation", secondary_rotations)
	var active_layers := _terrain_active_layer_indices(properties)
	result.set_shader_parameter("active_layer_count", active_layers.size())
	result.set_shader_parameter("active_layer_indices", _padded_layer_indices(active_layers))
	var splat_maps := _terrain_splat_maps(properties, active_layers)
	for index in range(splat_maps.size()):
		result.set_shader_parameter("splat_map%d" % index, splat_maps[index])
	return result

static func update_terrain_material(material: Material, properties: Dictionary) -> Material:
	var shader_material := material as ShaderMaterial
	if shader_material == null or shader_material.shader != TERRAIN_BLEND_SHADER:
		return terrain_material(properties)
	var active_layers := _terrain_active_layer_indices(properties)
	var images := _terrain_splat_images(properties, active_layers)
	for index in range(images.size()):
		var parameter := "splat_map%d" % index
		var texture := shader_material.get_shader_parameter(parameter) as ImageTexture
		var image := images[index]
		if texture == null or texture.get_width() != image.get_width() or texture.get_height() != image.get_height():
			texture = ImageTexture.create_from_image(image)
			shader_material.set_shader_parameter(parameter, texture)
		else:
			texture.update(image)
	var styles: Array[String] = MaterialCatalogScript.all_ids()
	var base_style := StringName(properties.get("material", "dirt_path"))
	shader_material.set_shader_parameter("base_layer_index", maxi(0, styles.find(String(base_style))))
	shader_material.set_shader_parameter("catalog_layer_count", mini(styles.size(), MAX_TERRAIN_CATALOG_LAYERS))
	shader_material.set_shader_parameter("active_layer_count", active_layers.size())
	shader_material.set_shader_parameter("active_layer_indices", _padded_layer_indices(active_layers))
	return shader_material

static func _terrain_splat_maps(properties: Dictionary, active_layers: PackedInt32Array) -> Array[ImageTexture]:
	var images := _terrain_splat_images(properties, active_layers)
	var result: Array[ImageTexture] = []
	for image: Image in images:
		result.append(ImageTexture.create_from_image(image))
	return result

static func _terrain_splat_images(properties: Dictionary, active_layers: PackedInt32Array) -> Array[Image]:
	var resolution := int(properties.get("resolution", 65))
	var palette := properties.get("material_palette", []) as Array
	var weights := properties.get("material_weights", []) as Array
	# Keep the persistent 32-channel authoring data, but upload only the packed
	# textures that currently contain paint. Unused shader samplers stay dormant.
	var map_count := maxi(1, ceili(float(active_layers.size()) / 4.0))
	var result: Array[Image] = []
	for map_index in range(map_count):
		var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
		for z in range(resolution):
			for x in range(resolution):
				var vertex_index := z * resolution + x
				var color := Color(0.0, 0.0, 0.0, 0.0)
				for component in range(4):
					var active_index := map_index * 4 + component
					if active_index < active_layers.size():
						var palette_index := active_layers[active_index]
						color[component] = clampf(float(weights[vertex_index * palette.size() + palette_index]), 0.0, 1.0)
				image.set_pixel(x, z, color)
		result.append(image)
	return result

static func _terrain_active_layer_indices(properties: Dictionary) -> PackedInt32Array:
	var palette := properties.get("material_palette", []) as Array
	var weights := properties.get("material_weights", []) as Array
	var result := PackedInt32Array()
	for layer_index in range(mini(palette.size(), MAX_TERRAIN_CATALOG_LAYERS)):
		for vertex_index in range(int(weights.size() / maxi(1, palette.size()))):
			if float(weights[vertex_index * palette.size() + layer_index]) > 0.0001:
				result.append(layer_index)
				break
	return result

static func _padded_layer_indices(active_layers: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(MAX_TERRAIN_CATALOG_LAYERS)
	for index in range(active_layers.size()):
		result[index] = active_layers[index]
	return result

static func _terrain_catalog_texture_array() -> Texture2DArray:
	if terrain_catalog_texture_array != null:
		return terrain_catalog_texture_array
	var images: Array[Image] = []
	for style: String in MaterialCatalogScript.all_ids():
		var config := _style_config(StringName(style))
		var texture := _runtime_texture(String(config.get("albedo", "")))
		var image := texture.get_image() if texture != null else null
		if image == null or image.is_empty():
			image = Image.create(MAX_TERRAIN_CATALOG_TEXTURE_SIZE, MAX_TERRAIN_CATALOG_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
			image.fill(config.get("fallback", Color(0.48, 0.40, 0.31)))
		else:
			image = image.duplicate()
			if image.is_compressed():
				var decompress_error := image.decompress()
				if decompress_error != OK:
					push_warning("[TERRAIN MATERIAL] Could not decompress %s (error %d)." % [style, decompress_error])
			if image.has_mipmaps():
				image.clear_mipmaps()
			if image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)
			image.resize(MAX_TERRAIN_CATALOG_TEXTURE_SIZE, MAX_TERRAIN_CATALOG_TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		images.append(image)
	terrain_catalog_texture_array = Texture2DArray.new()
	var error := terrain_catalog_texture_array.create_from_images(images)
	if error != OK:
		push_error("[TERRAIN MATERIAL] Texture2DArray creation failed with error %d." % error)
	return terrain_catalog_texture_array

static func preview_path(style: StringName) -> String:
	return String(_style_config(style).get("albedo", ""))

static func albedo_texture(style: StringName) -> Texture2D:
	return _runtime_texture(String(_style_config(style).get("albedo", "")))

static func _runtime_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	if ResourceLoader.exists(path):
		var imported_texture := load(path) as Texture2D
		if imported_texture != null:
			texture_cache[path] = imported_texture
			return imported_texture
	if not FileAccess.file_exists(path):
		return null
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
	return MaterialCatalogScript.config(style)

static func _style_seed(style: StringName) -> float:
	return float(posmod(String(style).hash(), 10000)) / 10000.0
