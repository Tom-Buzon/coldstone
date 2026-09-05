extends RefCounted
class_name HopliteMaterialCatalog

const LEGACY_ROOT := "res://_source/environment_props_raw/texture"
const TERRAIN_ROOT := "res://assets/environment/terrain"
const PBR_ROOT := "res://assets/environment/materials/poly_haven"
const FORGE_VARIANT_ROOT := "res://assets/environment/materials/forge_variants"

const CATEGORY_ORDER: Array[StringName] = [&"natural_ground", &"stone_floor", &"walls", &"decorative"]
const CATEGORY_LABELS := {
	&"natural_ground": "SOLS NATURELS",
	&"stone_floor": "PIERRE, DALLES & PAVÉS",
	&"walls": "MURS & ARCHITECTURE",
	&"decorative": "DÉCORATIF & SPÉCIAL",
}

# Every entry can be used on every Forge surface and terrain layer. Categories
# are deliberately navigational metadata, never placement restrictions.
const ENTRIES := {
	&"mediterranean_grass": {"label": "Herbe méditerranéenne", "category": &"natural_ground", "albedo": TERRAIN_ROOT + "/mediterranean_grass_albedo.png", "tint": Color(0.38, 0.48, 0.42), "scale": 0.32, "roughness": 1.0, "relief": 0.0, "anti_tiling": 0.12, "macro_variation": 0.07, "mirror_repeat": true, "fallback": Color(0.31, 0.34, 0.12)},
	&"dirt_path": {"label": "Chemin poussiéreux", "category": &"natural_ground", "albedo": LEGACY_ROOT + "/Dusty_dirt_path_game_texture_202608221752.jpeg", "tint": Color(0.82, 0.76, 0.65), "scale": 0.18, "roughness": 0.96, "relief": 0.56, "fallback": Color(0.29, 0.22, 0.16)},
	&"poly_dirt": {"label": "Terre sèche PBR", "category": &"natural_ground", "albedo": PBR_ROOT + "/dirt/dirt_diff_1k.jpg", "normal": PBR_ROOT + "/dirt/dirt_nor_gl_1k.jpg", "roughness_map": PBR_ROOT + "/dirt/dirt_rough_1k.jpg", "scale": 0.46, "roughness": 1.0, "normal_strength": 0.72, "anti_tiling": 0.11, "macro_variation": 0.08, "secondary_rotation": 1.0472, "fallback": Color(0.30, 0.23, 0.17)},
	&"poly_sand": {"label": "Sable compact PBR", "category": &"natural_ground", "albedo": PBR_ROOT + "/sand_01/sand_01_diff_1k.jpg", "normal": PBR_ROOT + "/sand_01/sand_01_nor_gl_1k.jpg", "roughness_map": PBR_ROOT + "/sand_01/sand_01_rough_1k.jpg", "scale": 0.54, "roughness": 0.98, "normal_strength": 0.64, "anti_tiling": 0.12, "macro_variation": 0.06, "secondary_rotation": 0.7854, "fallback": Color(0.56, 0.43, 0.29)},
	&"poly_mud_leaves": {"label": "Boue & feuilles PBR", "category": &"natural_ground", "albedo": PBR_ROOT + "/brown_mud_leaves_01/brown_mud_leaves_01_diff_1k.jpg", "normal": PBR_ROOT + "/brown_mud_leaves_01/brown_mud_leaves_01_nor_gl_1k.jpg", "roughness_map": PBR_ROOT + "/brown_mud_leaves_01/brown_mud_leaves_01_rough_1k.jpg", "scale": 0.40, "roughness": 0.96, "normal_strength": 0.62, "anti_tiling": 0.14, "macro_variation": 0.12, "secondary_rotation": 1.5708, "fallback": Color(0.20, 0.16, 0.10)},
	&"scorched_ground": {"label": "Sol brûlé & os", "category": &"natural_ground", "albedo": LEGACY_ROOT + "/Scorched_grass_and_bone_texture_202608221751.jpeg", "tint": Color(0.78, 0.68, 0.54), "scale": 0.20, "roughness": 0.98, "relief": 0.58, "fallback": Color(0.19, 0.14, 0.10)},
	&"cracked_weeds": {"label": "Terre fissurée & herbes", "category": &"natural_ground", "albedo": LEGACY_ROOT + "/Patchy_weeds_on_cracked_earth_202608221751.jpeg", "tint": Color(0.76, 0.76, 0.62), "scale": 0.19, "roughness": 0.95, "relief": 0.50, "fallback": Color(0.23, 0.25, 0.17)},
	&"bone_gravel": {"label": "Gravier d'ossements", "category": &"natural_ground", "albedo": LEGACY_ROOT + "/Game_texture_with_gravel_rocks_202608221923.jpeg", "tint": Color(0.83, 0.78, 0.68), "scale": 0.22, "roughness": 0.96, "relief": 0.68, "fallback": Color(0.24, 0.22, 0.19)},
	&"trampled_earth": {"label": "Terre sèche piétinée", "category": &"natural_ground", "albedo": FORGE_VARIANT_ROOT + "/earth_trampled_dry.png", "tint": Color(0.82, 0.78, 0.70), "scale": 0.30, "roughness": 0.98, "relief": 0.48, "anti_tiling": 0.13, "macro_variation": 0.10, "mirror_repeat": true, "fallback": Color(0.39, 0.27, 0.16)},
	&"coastal_gravel": {"label": "Gravier côtier clair", "category": &"natural_ground", "albedo": FORGE_VARIANT_ROOT + "/gravel_coastal_mixed.png", "tint": Color(0.78, 0.76, 0.70), "scale": 0.34, "roughness": 0.96, "relief": 0.74, "anti_tiling": 0.12, "macro_variation": 0.08, "mirror_repeat": true, "fallback": Color(0.58, 0.53, 0.45)},

	&"pavers": {"label": "Pavés calcaires", "category": &"stone_floor", "albedo": LEGACY_ROOT + "/Limestone_pavers_game_texture_2K_202608212340.jpeg", "tint": Color(0.88, 0.84, 0.75), "scale": 0.26, "roughness": 0.84, "relief": 0.38, "fallback": Color(0.55, 0.47, 0.36)},
	&"poly_stone_floor": {"label": "Pavés anciens PBR", "category": &"stone_floor", "albedo": PBR_ROOT + "/stone_floor/stone_floor_diff_1k.jpg", "normal": PBR_ROOT + "/stone_floor/stone_floor_nor_gl_1k.jpg", "roughness_map": PBR_ROOT + "/stone_floor/stone_floor_rough_1k.jpg", "scale": 0.56, "roughness": 0.92, "normal_strength": 0.78, "anti_tiling": 0.06, "macro_variation": 0.05, "secondary_rotation": 0.2618, "fallback": Color(0.34, 0.28, 0.22)},
	&"poly_monastery_floor": {"label": "Dalles de monastère PBR", "category": &"stone_floor", "albedo": PBR_ROOT + "/monastery_stone_floor/monastery_stone_floor_diff_1k.jpg", "normal": PBR_ROOT + "/monastery_stone_floor/monastery_stone_floor_nor_gl_1k.jpg", "roughness_map": PBR_ROOT + "/monastery_stone_floor/monastery_stone_floor_rough_1k.jpg", "scale": 0.56, "roughness": 0.94, "normal_strength": 0.76, "anti_tiling": 0.06, "macro_variation": 0.05, "secondary_rotation": 0.3491, "fallback": Color(0.30, 0.29, 0.27)},
	&"poly_rock_ground": {"label": "Roche naturelle PBR", "category": &"stone_floor", "albedo": PBR_ROOT + "/aerial_rocks_04/aerial_rocks_04_diff_1k.jpg", "normal": PBR_ROOT + "/aerial_rocks_04/aerial_rocks_04_nor_gl_1k.jpg", "roughness_map": PBR_ROOT + "/aerial_rocks_04/aerial_rocks_04_rough_1k.jpg", "scale": 0.34, "roughness": 0.96, "normal_strength": 0.78, "anti_tiling": 0.11, "macro_variation": 0.09, "secondary_rotation": 1.0472, "fallback": Color(0.31, 0.30, 0.28)},
	&"sandstone_floor": {"label": "Dallage grès", "category": &"stone_floor", "albedo": LEGACY_ROOT + "/Sandstone_floor_blocks_texture_2K_202608212340.jpeg", "tint": Color(0.83, 0.75, 0.62), "scale": 0.25, "roughness": 0.88, "relief": 0.42, "fallback": Color(0.49, 0.37, 0.25)},
	&"white_marble_floor": {"label": "Marbre blanc au sol", "category": &"stone_floor", "albedo": LEGACY_ROOT + "/White_marble_floor_texture_2K_202608212340.jpeg", "tint": Color(0.82, 0.80, 0.74), "scale": 0.19, "roughness": 0.54, "relief": 0.22, "fallback": Color(0.82, 0.80, 0.74)},
	&"cool_marble_floor": {"label": "Marbre froid patiné", "category": &"stone_floor", "albedo": FORGE_VARIANT_ROOT + "/marble_cool_worn.png", "tint": Color(0.72, 0.74, 0.76), "scale": 0.25, "roughness": 0.60, "relief": 0.20, "anti_tiling": 0.045, "macro_variation": 0.035, "mirror_repeat": true, "fallback": Color(0.74, 0.75, 0.74)},
	&"mossy_flagstone": {"label": "Dalles humides & mousse", "category": &"stone_floor", "albedo": FORGE_VARIANT_ROOT + "/flagstone_damp_mossy.png", "tint": Color(0.86, 0.88, 0.83), "scale": 0.28, "roughness": 0.94, "relief": 0.62, "anti_tiling": 0.075, "macro_variation": 0.10, "mirror_repeat": true, "fallback": Color(0.25, 0.27, 0.23)},

	&"limestone_brick": {"label": "Briques calcaires", "category": &"walls", "albedo": LEGACY_ROOT + "/Limestone_brick_wall_texture_2K_202608212340.jpeg", "tint": Color(0.96, 0.92, 0.82), "scale": 0.23, "roughness": 0.82, "relief": 0.48, "fallback": Color(0.67, 0.61, 0.51)},
	&"fortress": {"label": "Muraille calcaire", "category": &"walls", "albedo": LEGACY_ROOT + "/Limestone_fortress_wall_texture_2K_202608212340.jpeg", "tint": Color(0.93, 0.91, 0.86), "scale": 0.23, "roughness": 0.86, "relief": 0.62, "fallback": Color(0.62, 0.57, 0.48)},
	&"rough_stone": {"label": "Maçonnerie brute", "category": &"walls", "albedo": LEGACY_ROOT + "/Rough_stone_wall_texture_2K_202608212338.jpeg", "tint": Color(0.82, 0.78, 0.70), "scale": 0.30, "roughness": 0.92, "relief": 0.72, "fallback": Color(0.38, 0.34, 0.29)},
	&"poly_plaster_wall": {"label": "Enduit ancien PBR", "category": &"walls", "albedo": PBR_ROOT + "/plastered_wall_03/plastered_wall_03_diff_1k.jpg", "normal": PBR_ROOT + "/plastered_wall_03/plastered_wall_03_nor_gl_1k.jpg", "roughness_map": PBR_ROOT + "/plastered_wall_03/plastered_wall_03_rough_1k.jpg", "scale": 0.52, "roughness": 0.90, "normal_strength": 0.60, "anti_tiling": 0.08, "macro_variation": 0.07, "secondary_rotation": 0.5236, "fallback": Color(0.61, 0.53, 0.44)},
	&"marble": {"label": "Mur de marbre", "category": &"walls", "albedo": LEGACY_ROOT + "/Marble_wall_game_texture_2K_202608212340.jpeg", "tint": Color(0.96, 0.95, 0.90), "scale": 0.20, "roughness": 0.58, "relief": 0.24, "fallback": Color(0.76, 0.73, 0.66)},
	&"limestone_ashlar_clean": {"label": "Calcaire taillé clair", "category": &"walls", "albedo": FORGE_VARIANT_ROOT + "/limestone_ashlar_clean.png", "tint": Color(0.72, 0.68, 0.60), "scale": 0.24, "roughness": 0.86, "relief": 0.42, "anti_tiling": 0.045, "macro_variation": 0.045, "mirror_repeat": true, "fallback": Color(0.72, 0.66, 0.55)},
	&"limestone_coastal": {"label": "Calcaire côtier vieilli", "category": &"walls", "albedo": FORGE_VARIANT_ROOT + "/limestone_coastal_weathered.png", "tint": Color(0.75, 0.70, 0.62), "scale": 0.25, "roughness": 0.91, "relief": 0.58, "anti_tiling": 0.055, "macro_variation": 0.07, "mirror_repeat": true, "fallback": Color(0.65, 0.61, 0.53)},
	&"sandstone_honey": {"label": "Grès miel taillé", "category": &"walls", "albedo": FORGE_VARIANT_ROOT + "/sandstone_honey_ashlar.png", "tint": Color(0.72, 0.62, 0.48), "scale": 0.24, "roughness": 0.89, "relief": 0.46, "anti_tiling": 0.045, "macro_variation": 0.055, "mirror_repeat": true, "fallback": Color(0.57, 0.38, 0.17)},
	&"volcanic_rubble": {"label": "Pierre volcanique sombre", "category": &"walls", "albedo": FORGE_VARIANT_ROOT + "/volcanic_rubble_dark.png", "scale": 0.28, "roughness": 0.97, "relief": 0.78, "anti_tiling": 0.07, "macro_variation": 0.075, "mirror_repeat": true, "fallback": Color(0.12, 0.12, 0.11)},

	&"mural": {"label": "Fresque grecque", "category": &"decorative", "albedo": LEGACY_ROOT + "/Ancient_Greek_mural_game_texture_202608212338.jpeg", "tint": Color(0.90, 0.88, 0.80), "roughness": 0.78, "fallback": Color(0.24, 0.32, 0.40)},
	&"ornate_stone_wall": {"label": "Frise de pierre", "category": &"decorative", "albedo": LEGACY_ROOT + "/Stone_wall_game_texture_2K_202608212340.jpeg", "tint": Color(0.88, 0.90, 0.94), "roughness": 0.88, "fallback": Color(0.17, 0.20, 0.25)},
}

static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in ENTRIES.keys():
		result.append(String(raw_id))
	return result

static func ids_for_category(category: StringName) -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in ENTRIES.keys():
		if StringName((ENTRIES[raw_id] as Dictionary).get("category", &"decorative")) == category:
			result.append(String(raw_id))
	return result

static func config(style: StringName) -> Dictionary:
	return (ENTRIES.get(style, ENTRIES[&"pavers"]) as Dictionary).duplicate()

static func label(style: StringName) -> String:
	return String((ENTRIES.get(style, {}) as Dictionary).get("label", String(style).replace("_", " ").capitalize()))
