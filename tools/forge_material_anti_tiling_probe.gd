extends SceneTree

const MaterialCatalogScript = preload("res://scripts/environment/material_catalog.gd")
const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")

const VARIANT_IDS: Array[StringName] = [
	&"trampled_earth",
	&"coastal_gravel",
	&"cool_marble_floor",
	&"mossy_flagstone",
	&"limestone_ashlar_clean",
	&"limestone_coastal",
	&"sandstone_honey",
	&"volcanic_rubble",
]
const STABILITY_IDS: Array[StringName] = [
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
	_check(MaterialCatalogScript.all_ids().size() >= 29, "catalog exposes at least 29 materials")
	for style: StringName in VARIANT_IDS:
		var config := MaterialCatalogScript.config(style)
		var path := String(config.get("albedo", ""))
		_check(path.begins_with(MaterialCatalogScript.FORGE_VARIANT_ROOT), "%s uses the Forge variant root" % style)
		_check(ResourceLoader.exists(path), "%s is imported by Godot" % path)
		var texture := MaterialLibraryScript.albedo_texture(style)
		_check(texture is CompressedTexture2D, "%s uses the imported compressed texture" % style)
		_check(maxi(texture.get_width(), texture.get_height()) <= 1024, "%s respects the 1K runtime budget" % style)
		var material := MaterialLibraryScript.material(style) as ShaderMaterial
		_check(material != null, "%s creates a shader material" % style)
		_check(bool(material.get_shader_parameter("mirror_repeat")), "%s enables seamless mirrored repetition" % style)
		_check(float(material.get_shader_parameter("anti_tiling_strength")) > 0.0, "%s enables coordinate variation" % style)

	var pbr_material := MaterialLibraryScript.material(&"poly_stone_floor") as ShaderMaterial
	_check(pbr_material != null, "PBR control material exists")
	_check(not bool(pbr_material.get_shader_parameter("mirror_repeat")), "authored seamless PBR texture keeps regular repeat")
	_check(pbr_material.shader.code.contains("sample_normal_plane"), "PBR shader decorrelates aligned normal samples")
	_check(pbr_material.shader.code.contains("weights.x > 0.003"), "triplanar shader skips invisible projection axes")
	_check(float((MaterialLibraryScript.material(&"poly_mud_leaves") as ShaderMaterial).get_shader_parameter("secondary_rotation")) > 1.5, "organic PBR material rotates its secondary sample")

	for style: StringName in STABILITY_IDS:
		var config := MaterialCatalogScript.config(style)
		for map_key: String in ["albedo", "normal", "roughness_map"]:
			var path := String(config.get(map_key, ""))
			if path.is_empty():
				continue
			_check(ResourceLoader.exists(path), "%s %s is imported" % [style, map_key])
			var texture := load(path) as Texture2D
			_check(texture is CompressedTexture2D, "%s %s uses compressed import" % [style, map_key])
			_check(texture.get_image().has_mipmaps(), "%s %s exposes runtime mipmaps" % [style, map_key])
			var import_settings := FileAccess.get_file_as_string(path + ".import")
			_check(import_settings.contains("compress/mode=2"), "%s %s is VRAM compressed" % [style, map_key])
			_check(import_settings.contains("mipmaps/generate=true"), "%s %s has mipmaps" % [style, map_key])
			if map_key == "normal":
				_check(import_settings.contains("compress/normal_map=1"), "%s normal map is identified correctly" % style)

	var grass_config := MaterialCatalogScript.config(&"mediterranean_grass")
	_check(is_zero_approx(float(grass_config.get("relief", -1.0))), "grass disables unstable derivative relief")
	_check(float(grass_config.get("roughness", 0.0)) >= 0.99, "grass suppresses specular sparkle")

	var terrain_properties := WorldTerrainScript.default_properties("flat", 17, 909)
	terrain_properties["material"] = "trampled_earth"
	for style in ["coastal_gravel", "mossy_flagstone", "sandstone_honey"]:
		WorldTerrainScript.paint_material(terrain_properties, Vector3.ZERO, style, 4.0, 2.0)
	var terrain_material := MaterialLibraryScript.terrain_material(terrain_properties) as ShaderMaterial
	_check(terrain_material != null, "terrain anti-tiling material exists")
	_check(terrain_material.get_shader_parameter("catalog_textures") is Texture2DArray, "terrain uses one catalog Texture2DArray")
	var anti_tiling := terrain_material.get_shader_parameter("layer_anti_tiling") as PackedFloat32Array
	var mirror_repeat := terrain_material.get_shader_parameter("layer_mirror_repeat") as PackedFloat32Array
	for style in ["trampled_earth", "coastal_gravel", "mossy_flagstone", "sandstone_honey"]:
		var index := MaterialCatalogScript.all_ids().find(style)
		_check(index >= 0 and anti_tiling[index] > 0.0, "terrain layer %s varies coordinates" % style)
		_check(index >= 0 and mirror_repeat[index] > 0.5, "terrain layer %s repeats seamlessly" % style)

	print("FORGE_MATERIAL_ANTI_TILING_OK variants=%d stable=%d catalog=%d" % [VARIANT_IDS.size(), STABILITY_IDS.size(), MaterialCatalogScript.all_ids().size()])
	quit(0)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("FORGE MATERIAL ANTI-TILING FAILED: %s" % label)
	quit(1)
