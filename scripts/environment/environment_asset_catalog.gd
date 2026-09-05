extends RefCounted
class_name HopliteEnvironmentAssetCatalog

const RAW_ROOT := "res://_source/environment_props_raw"
const STYLIZED_NATURE_ROOT := "res://assets/environment/stylized_nature"
const STYLIZED_NATURE_THUMBNAIL_ROOT := STYLIZED_NATURE_ROOT + "/thumbnails"
const CATALOG_THUMBNAIL_ROOT := "res://docs/environment_asset_catalog/images"

# Canonical, gameplay-oriented registry. Raw meshes are normalized close to one
# metre, so target_height and collision proxy values deliberately define their
# useful world scale instead of trusting the source-file dimensions.
const ASSETS := {
	&"big_rock": {
		"label": "Amas de ruines monumentales", "folder": "bigRock",
		"hero": RAW_ROOT + "/bigRock/bigRock_LOD0.glb", "repeat": RAW_ROOT + "/bigRock/bigRock_LOD1.glb",
		"target_height": 4.2, "collision": &"box", "collision_size": Vector3(4.4, 2.2, 4.4),
		"zones": [&"walls", &"city"], "placement": "landmark de flanc; jamais comme petit rocher aleatoire"
	},
	&"brazier": {
		"label": "Brasero monumental sur pieds de lion", "folder": "brazier",
		"hero": RAW_ROOT + "/brazier/brazier_LOD0.glb", "repeat": RAW_ROOT + "/brazier/brazier_LOD1.glb",
		"target_height": 2.35, "collision": &"cylinder", "collision_radius": 0.86, "collision_height": 1.35,
		"zones": [&"walls", &"city", &"dungeon"], "placement": "par paire aux portes, autels et entrees"
	},
	&"crates": {
		"label": "Pile de caisses et bouteilles", "folder": "caisse",
		"hero": RAW_ROOT + "/caisse/caisses.glb", "repeat": RAW_ROOT + "/caisse/caisses.glb",
		"target_height": 1.85, "collision": &"box", "collision_size": Vector3(1.9, 1.55, 1.72),
		"zones": [&"walls", &"city"], "placement": "contre un mur ou dans un depot; assembler avec jarres"
	},
	&"catapult": {
		"label": "Catapulte de siege", "folder": "catapulte",
		"hero": RAW_ROOT + "/catapulte/catapulte.glb", "repeat": RAW_ROOT + "/catapulte/catapulte.glb",
		"target_height": 4.1, "collision": &"box", "collision_size": Vector3(4.45, 1.9, 4.25),
		"zones": [&"walls"], "placement": "batterie orientee vers la muraille, avec ravitaillement"
	},
	&"cypress_tree": {
		"label": "Cypres sur socle", "folder": "cypressTree",
		"hero": RAW_ROOT + "/cypressTree/cypressTree_LOD0.glb", "repeat": RAW_ROOT + "/cypressTree/cypressTree_LOD1.glb",
		"target_height": 7.2, "collision": &"cylinder", "collision_radius": 0.42, "collision_height": 2.2,
		"zones": [&"walls", &"city"], "placement": "alignement d'avenue, cour ou limite; jamais au milieu d'un axe de combat"
	},
	&"fountain": {
		"label": "Fontaine monumentale circulaire", "folder": "fontaine1",
		"hero": RAW_ROOT + "/fontaine1/fontaine1_LOD0.glb", "repeat": RAW_ROOT + "/fontaine1/fontaine1_LOD1.glb",
		"target_height": 3.45, "collision": &"cylinder", "collision_radius": 1.75, "collision_height": 1.05,
		"zones": [&"city"], "placement": "piece centrale unique d'une grande place"
	},
	&"jar": {
		"label": "Grande amphore sur socle", "folder": "jare",
		"hero": RAW_ROOT + "/jare/jare.glb", "repeat": RAW_ROOT + "/jare/jare.glb",
		"target_height": 1.35, "collision": &"none",
		"zones": [&"walls", &"city", &"dungeon"], "placement": "paire ou petit groupe contre un decor; collision omise pour la fluidite"
	},
	&"barricade": {
		"label": "Barricade de pieux avec ossements", "folder": "obstacle",
		"hero": RAW_ROOT + "/obstacle/obstacle.glb", "repeat": RAW_ROOT + "/obstacle/obstacle.glb",
		"target_height": 2.15, "collision": &"box", "collision_size": Vector3(2.18, 1.35, 1.15),
		"zones": [&"walls", &"city"], "placement": "modules cote a cote en ligne, avec une breche jouable"
	},
	&"athena_statue": {
		"label": "Statue d'Athena armee", "folder": "statusAthena",
		"hero": RAW_ROOT + "/statusAthena/statusAthena_LOD0.glb", "repeat": RAW_ROOT + "/statusAthena/statusAthena_LOD1.glb",
		"target_height": 6.4, "collision": &"box", "collision_size": Vector3(1.75, 1.15, 1.55),
		"zones": [&"city"], "placement": "repere civique, par paire a l'agora ou devant le temple"
	},
	&"lion_statue": {
		"label": "Lion assis sur piedestal", "folder": "statusLion",
		"hero": RAW_ROOT + "/statusLion/statusLion_LOD0.glb", "repeat": RAW_ROOT + "/statusLion/statusLion_LOD1.glb",
		"target_height": 3.15, "collision": &"box", "collision_size": Vector3(2.75, 1.2, 2.35),
		"zones": [&"city", &"dungeon"], "placement": "paire symetrique gardant un escalier, une porte ou un dais"
	},
	&"magistrate_statue": {
		"label": "Magistrat barbu sur trone", "folder": "statusMagistrale",
		"hero": RAW_ROOT + "/statusMagistrale/statusMagistrale_LOD0.glb", "repeat": RAW_ROOT + "/statusMagistrale/statusMagistrale_LOD1.glb",
		"target_height": 6.1, "collision": &"box", "collision_size": Vector3(4.1, 2.2, 4.2),
		"zones": [&"dungeon"], "placement": "landmark unique de salle du trone, derriere le boss"
	},
	&"temple": {
		"label": "Temple grec complet et endommage", "folder": "temple1",
		"hero": RAW_ROOT + "/temple1/temple1_LOD0.glb", "repeat": RAW_ROOT + "/temple1/temple1_LOD1.glb",
		"target_height": 11.5, "collision": &"none",
		"zones": [&"city", &"dungeon"], "placement": "silhouette architecturale majeure, hors de l'axe jouable"
	},
	&"tomb": {
		"label": "Tombeau-mausolee sculpte", "folder": "tombe1",
		"hero": RAW_ROOT + "/tombe1/tombe1_LOD0.glb", "repeat": RAW_ROOT + "/tombe1/tombe1_LOD1.glb",
		"target_height": 2.2, "collision": &"box", "collision_size": Vector3(2.0, 1.65, 2.35),
		"zones": [&"dungeon"], "placement": "rangees regulieres formant les bas-cotes d'une crypte"
	}
}

const TEXTURES := {
	"Ancient_Greek_mural_game_texture_202608212338.jpeg": {"style": &"mural", "meaning": "fresque narrative grecque bleue et degradee", "projection": &"uv_panel", "zones": [&"city", &"dungeon"]},
	"Dusty_dirt_path_game_texture_202608221752.jpeg": {"style": &"dirt_path", "meaning": "terre battue avec traces et debris", "projection": &"triplanar_floor", "zones": [&"walls"]},
	"Game_texture_with_gravel_rocks_202608221923.jpeg": {"style": &"bone_gravel", "meaning": "gravier sombre parseme d'os", "projection": &"triplanar_floor", "zones": [&"walls", &"dungeon"]},
	"Limestone_brick_wall_texture_2K_202608212340.jpeg": {"style": &"limestone_brick", "meaning": "blocs calcaires propres", "projection": &"triplanar_wall", "zones": [&"city"]},
	"Limestone_fortress_wall_texture_2K_202608212340.jpeg": {"style": &"fortress", "meaning": "fortification calcaire sale et ensanglantee", "projection": &"triplanar_wall", "zones": [&"walls", &"city"]},
	"Limestone_pavers_game_texture_2K_202608212340.jpeg": {"style": &"pavers", "meaning": "paves calcaires chauds", "projection": &"triplanar_floor", "zones": [&"city"]},
	"Marble_wall_game_texture_2K_202608212340.jpeg": {"style": &"marble", "meaning": "mur civique en marbre abime", "projection": &"triplanar_wall", "zones": [&"walls", &"city", &"dungeon"]},
	"Patchy_weeds_on_cracked_earth_202608221751.jpeg": {"style": &"cracked_weeds", "meaning": "terre fissuree envahie de vegetation", "projection": &"triplanar_floor", "zones": [&"walls", &"city"]},
	"Rough_stone_wall_texture_2K_202608212338.jpeg": {"style": &"rough_stone", "meaning": "maconnerie sombre et grossiere", "projection": &"triplanar", "zones": [&"walls", &"dungeon"]},
	"Sandstone_floor_blocks_texture_2K_202608212340.jpeg": {"style": &"sandstone_floor", "meaning": "dallage chaud de cour et terrasse", "projection": &"triplanar_floor", "zones": [&"walls", &"city"]},
	"Scorched_grass_and_bone_texture_202608221751.jpeg": {"style": &"scorched_ground", "meaning": "sol brule, herbes seches et os", "projection": &"triplanar_floor", "zones": [&"walls"]},
	"Stone_wall_game_texture_2K_202608212340.jpeg": {"style": &"ornate_stone_wall", "meaning": "mur bleu-noir avec frise grecque directionnelle", "projection": &"uv_panel", "zones": [&"dungeon"]},
	"White_marble_floor_texture_2K_202608212340.jpeg": {"style": &"white_marble_floor", "meaning": "dalles de marbre blanc tachees de sang", "projection": &"triplanar_floor", "zones": [&"city", &"dungeon"]}
}

static func definition(asset_id: StringName) -> Dictionary:
	return ASSETS.get(asset_id, {})

static func visual_path(asset_id: StringName, repeated: bool = false) -> String:
	var data: Dictionary = definition(asset_id)
	if data.is_empty():
		return ""
	var candidate := String(data.get("repeat" if repeated else "hero", ""))
	if candidate.is_empty() or not FileAccess.file_exists(candidate):
		candidate = String(data.get("hero", ""))
	return candidate

static func target_height(asset_id: StringName) -> float:
	return float(definition(asset_id).get("target_height", 1.0))

static func target_height_for_path(path: String, fallback: float = 2.0) -> float:
	var filename := path.get_file().to_lower()
	for raw: Variant in ASSETS.values():
		var value := raw as Dictionary
		if String(value.get("hero", "")).get_file().to_lower() == filename or String(value.get("repeat", "")).get_file().to_lower() == filename:
			return float(value.get("target_height", fallback))
	return fallback

static func preview_path_for_path(path: String) -> String:
	if path.begins_with(STYLIZED_NATURE_ROOT + "/"):
		var nature_preview := STYLIZED_NATURE_THUMBNAIL_ROOT.path_join(path.get_file().get_basename() + ".png")
		return nature_preview if FileAccess.file_exists(nature_preview) else ""
	for asset_id: Variant in ASSETS.keys():
		var value := ASSETS[asset_id] as Dictionary
		if path in [String(value.get("hero", "")), String(value.get("repeat", ""))]:
			var catalog_preview := CATALOG_THUMBNAIL_ROOT.path_join(String(asset_id) + ".png")
			return catalog_preview if FileAccess.file_exists(catalog_preview) else ""
	return ""

static func default_collision_enabled_for_path(path: String, asset_id: StringName = &"") -> bool:
	if path.replace("\\", "/").to_lower().contains("/assets/fauna/"):
		return false
	var policy := stylized_nature_collision_policy(path)
	if policy == &"non_blocking":
		return false
	if policy == &"blocking":
		return true
	var definition_data := definition(asset_id) if not asset_id.is_empty() else _definition_for_path(path)
	if not definition_data.is_empty():
		return String(definition_data.get("collision", "none")) != "none"
	var normalized := path.replace("\\", "/").to_lower()
	if normalized.contains("/stylized_nature/shrubs/") or normalized.contains("/stylized_nature/ground_cover/"):
		return false
	return true

static func stylized_nature_collision_policy(path: String) -> StringName:
	var normalized := path.replace("\\", "/").to_lower()
	if normalized.contains("/stylized_nature/stone_paths/"):
		return &"non_blocking"
	if normalized.contains("/stylized_nature/rocks/") and normalized.get_file().begins_with("pebble_"):
		return &"blocking"
	return &""

static func default_collision_shape_for_path(path: String, asset_id: StringName = &"") -> String:
	if path.replace("\\", "/").to_lower().contains("/assets/fauna/"):
		return "capsule"
	var definition_data := definition(asset_id) if not asset_id.is_empty() else _definition_for_path(path)
	var registered_shape := String(definition_data.get("collision", ""))
	if registered_shape in ["box", "cylinder", "capsule", "sphere", "convex"]:
		return registered_shape
	if not authored_collision_path_for_visual(path).is_empty():
		return "convex"
	var normalized := path.replace("\\", "/").to_lower()
	if normalized.contains("/stylized_nature/trees/"):
		return "cylinder"
	if normalized.contains("/stylized_nature/rocks/") and path.get_file().to_lower().begins_with("rock_medium_"):
		return "convex"
	return "box"

static func is_tree_asset(path: String, asset_id: StringName = &"") -> bool:
	if asset_id == &"cypress_tree":
		return true
	var normalized := path.replace("\\", "/").to_lower()
	return normalized.contains("/stylized_nature/trees/") or normalized.get_file().begins_with("cypresstree_")

static func definition_for_path(path: String, asset_id: StringName = &"") -> Dictionary:
	if not asset_id.is_empty():
		var registered := definition(asset_id)
		if not registered.is_empty():
			return registered
	return _definition_for_path(path).duplicate(true)

static func authored_collision_path_for_visual(path: String) -> String:
	if path.is_empty():
		return ""
	var base_name := path.get_file().get_basename()
	for suffix: String in ["_LOD0", "_lod0", "-LOD0", "-lod0", "_LOD1", "_lod1", "-LOD1", "-lod1"]:
		base_name = base_name.trim_suffix(suffix)
	var directory := path.get_base_dir()
	for suffix: String in ["_collision.glb", "_collider.glb", "_proxy.glb"]:
		var candidate := directory.path_join(base_name + suffix)
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			return candidate
	return ""

static func _definition_for_path(path: String) -> Dictionary:
	var filename := path.get_file().to_lower()
	for raw: Variant in ASSETS.values():
		var value := raw as Dictionary
		if String(value.get("hero", "")).get_file().to_lower() == filename or String(value.get("repeat", "")).get_file().to_lower() == filename:
			return value
	return {}

static func registered_folders() -> PackedStringArray:
	var folders := PackedStringArray()
	for value: Variant in ASSETS.values():
		folders.append(String((value as Dictionary).get("folder", "")))
	folders.sort()
	return folders

static func registered_texture_files() -> PackedStringArray:
	var files := PackedStringArray()
	for filename: Variant in TEXTURES.keys():
		files.append(String(filename))
	files.sort()
	return files

static func migrate_asset_path(path: String) -> String:
	if path.is_empty() or not path.begins_with(STYLIZED_NATURE_ROOT + "/"):
		return path
	if FileAccess.file_exists(path):
		return path
	var filename := path.get_file()
	var basename := filename.get_basename()
	var category := "ground_cover"
	if basename.begins_with("CommonTree") or basename.begins_with("DeadTree") or basename.begins_with("Pine_") or basename.begins_with("TwistedTree"):
		category = "trees"
	elif basename.begins_with("Bush_") or basename.begins_with("Plant_"):
		category = "shrubs"
	elif basename.begins_with("RockPath_"):
		category = "stone_paths"
	elif basename.begins_with("Pebble_") or basename.begins_with("Rock_Medium"):
		category = "rocks"
	var migrated := STYLIZED_NATURE_ROOT.path_join(category).path_join(filename)
	return migrated if FileAccess.file_exists(migrated) else path
