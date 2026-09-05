extends RefCounted
class_name HopliteFaunaSettings

const CONFIG_SECTION := "fauna"
const CONFIG_SCHEMA_VERSION := 2
const MAX_TOTAL_ANIMALS := 64

const BEHAVIORS: Array[Dictionary] = [
	{"id": &"passive", "label": "PAISIBLE", "description": "Se promène et ignore le joueur."},
	{"id": &"wary", "label": "MÉFIANT", "description": "S’éloigne lorsque le joueur approche."},
	{"id": &"skittish", "label": "PEUREUX", "description": "Détecte plus loin et fuit rapidement."},
	{"id": &"territorial", "label": "TERRITORIAL", "description": "Tient sa zone et vient intimider le joueur."},
]

const SPECIES: Array[Dictionary] = [
	{"id": &"cow", "label": "VACHE", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Cow.gltf", "target_height": 1.65, "default_count": 2, "default_behavior": 0, "walk_speed": 0.85, "run_speed": 3.2, "wander_radius": 14.0, "flee_distance": 8.0},
	{"id": &"donkey", "label": "ÂNE", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Donkey.gltf", "target_height": 1.50, "default_count": 1, "default_behavior": 0, "walk_speed": 0.95, "run_speed": 3.4, "wander_radius": 15.0, "flee_distance": 8.0},
	{"id": &"deer", "label": "BICHE", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Deer.gltf", "target_height": 1.55, "default_count": 2, "default_behavior": 2, "walk_speed": 1.25, "run_speed": 5.2, "wander_radius": 20.0, "flee_distance": 15.0},
	{"id": &"alpaca", "label": "ALPAGA", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Alpaca.gltf", "target_height": 1.45, "default_count": 1, "default_behavior": 1, "walk_speed": 1.0, "run_speed": 3.8, "wander_radius": 14.0, "flee_distance": 10.0},
	{"id": &"bull", "label": "TAUREAU", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Bull.gltf", "target_height": 1.80, "default_count": 1, "default_behavior": 3, "walk_speed": 0.9, "run_speed": 4.2, "wander_radius": 13.0, "flee_distance": 8.0},
	{"id": &"fox", "label": "RENARD", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Fox.gltf", "target_height": 0.72, "default_count": 2, "default_behavior": 1, "walk_speed": 1.25, "run_speed": 4.8, "wander_radius": 22.0, "flee_distance": 12.0},
	{"id": &"shiba_inu", "label": "SHIBA INU", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/ShibaInu.gltf", "target_height": 0.82, "default_count": 1, "default_behavior": 0, "walk_speed": 1.2, "run_speed": 4.4, "wander_radius": 13.0, "flee_distance": 8.0},
	{"id": &"stag", "label": "CERF", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Stag.gltf", "target_height": 1.85, "default_count": 1, "default_behavior": 1, "walk_speed": 1.2, "run_speed": 5.0, "wander_radius": 20.0, "flee_distance": 13.0},
	{"id": &"husky", "label": "HUSKY", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Husky.gltf", "target_height": 0.90, "default_count": 1, "default_behavior": 0, "walk_speed": 1.2, "run_speed": 4.5, "wander_radius": 14.0, "flee_distance": 8.0},
	{"id": &"wolf", "label": "LOUP", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Wolf.gltf", "target_height": 1.00, "default_count": 2, "default_behavior": 3, "walk_speed": 1.3, "run_speed": 5.0, "wander_radius": 24.0, "flee_distance": 11.0},
	{"id": &"white_horse", "label": "CHEVAL BLANC", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Horse_White.gltf", "target_height": 1.78, "default_count": 1, "default_behavior": 0, "walk_speed": 1.2, "run_speed": 5.2, "wander_radius": 16.0, "flee_distance": 9.0},
	{"id": &"horse", "label": "CHEVAL", "model_path": "res://assets/fauna/quaternius_ultimate_animated_animals/models/Horse.gltf", "target_height": 1.78, "default_count": 2, "default_behavior": 0, "walk_speed": 1.2, "run_speed": 5.2, "wander_radius": 16.0, "flee_distance": 9.0},
	{"id": &"eagle", "label": "AIGLE", "model_path": "res://assets/fauna/quaternius_eagle/Eagle.glb", "target_height": 1.05, "default_count": 2, "default_behavior": 1, "walk_speed": 5.0, "run_speed": 8.0, "wander_radius": 34.0, "flee_distance": 13.0, "airborne": true, "altitude_min": 16.0, "altitude_max": 30.0, "visual_yaw_degrees": 0.0},
	{"id": &"pterodactyl", "label": "PTÉRODACTYLE", "model_path": "res://assets/fauna/sketchfab_pterodactyl/pterodactyl.glb", "target_height": 2.20, "default_count": 2, "default_behavior": 0, "walk_speed": 6.2, "run_speed": 9.0, "wander_radius": 46.0, "flee_distance": 15.0, "airborne": true, "altitude_min": 19.0, "altitude_max": 36.0, "visual_yaw_degrees": 180.0},
]


static func species_key(species_id: StringName, suffix: String) -> StringName:
	return StringName("%s_%s" % [String(species_id), suffix])


static func defaults() -> Dictionary:
	var result := {
		&"enabled": true,
		&"budget": 20,
		&"spawn_radius": 68.0,
		&"full_simulation_distance": 38.0,
		&"simulation_distance": 82.0,
		&"far_physics_divisor": 3,
		&"logic_hz": 4.0,
		&"seed": 1337,
	}
	for definition: Dictionary in SPECIES:
		var species_id := StringName(definition["id"])
		result[species_key(species_id, "enabled")] = true
		result[species_key(species_id, "count")] = int(definition["default_count"])
		result[species_key(species_id, "behavior")] = int(definition["default_behavior"])
	return result


static func sanitize(values: Dictionary) -> Dictionary:
	var result := defaults()
	result[&"enabled"] = bool(values.get(&"enabled", result[&"enabled"]))
	result[&"budget"] = clampi(int(values.get(&"budget", result[&"budget"])), 0, MAX_TOTAL_ANIMALS)
	result[&"spawn_radius"] = clampf(float(values.get(&"spawn_radius", result[&"spawn_radius"])), 24.0, 160.0)
	result[&"simulation_distance"] = clampf(float(values.get(&"simulation_distance", result[&"simulation_distance"])), 24.0, 180.0)
	result[&"full_simulation_distance"] = clampf(float(values.get(&"full_simulation_distance", result[&"full_simulation_distance"])), 8.0, float(result[&"simulation_distance"]))
	result[&"far_physics_divisor"] = clampi(int(values.get(&"far_physics_divisor", result[&"far_physics_divisor"])), 1, 8)
	result[&"logic_hz"] = clampf(float(values.get(&"logic_hz", result[&"logic_hz"])), 1.0, 10.0)
	result[&"seed"] = maxi(1, int(values.get(&"seed", result[&"seed"])))
	for definition: Dictionary in SPECIES:
		var species_id := StringName(definition["id"])
		var enabled_key := species_key(species_id, "enabled")
		var count_key := species_key(species_id, "count")
		var behavior_key := species_key(species_id, "behavior")
		result[enabled_key] = bool(values.get(enabled_key, result[enabled_key]))
		result[count_key] = clampi(int(values.get(count_key, result[count_key])), 0, 12)
		result[behavior_key] = clampi(int(values.get(behavior_key, result[behavior_key])), 0, BEHAVIORS.size() - 1)
	return result


static func load_from_config(config: ConfigFile) -> Dictionary:
	var result := defaults()
	for raw_key: Variant in result.keys():
		var key := StringName(raw_key)
		result[key] = config.get_value(CONFIG_SECTION, String(key), result[key])
	return sanitize(result)


static func save_to_config(config: ConfigFile, values: Dictionary) -> Dictionary:
	var clean := sanitize(values)
	for raw_key: Variant in clean.keys():
		var key := StringName(raw_key)
		config.set_value(CONFIG_SECTION, String(key), clean[key])
	config.set_value(CONFIG_SECTION, "schema_version", CONFIG_SCHEMA_VERSION)
	return clean


static func target_counts(values: Dictionary) -> Dictionary:
	var clean := sanitize(values)
	var targets: Dictionary = {}
	for definition: Dictionary in SPECIES:
		targets[StringName(definition["id"])] = 0
	if not bool(clean[&"enabled"]):
		return targets
	var budget := int(clean[&"budget"])
	var remaining: Dictionary = {}
	for definition: Dictionary in SPECIES:
		var species_id := StringName(definition["id"])
		remaining[species_id] = int(clean[species_key(species_id, "count")]) if bool(clean[species_key(species_id, "enabled")]) else 0
	while budget > 0:
		var allocated := false
		for definition: Dictionary in SPECIES:
			var species_id := StringName(definition["id"])
			if int(remaining[species_id]) <= 0:
				continue
			targets[species_id] = int(targets[species_id]) + 1
			remaining[species_id] = int(remaining[species_id]) - 1
			budget -= 1
			allocated = true
			if budget <= 0:
				break
		if not allocated:
			break
	return targets


static func definition(species_id: StringName) -> Dictionary:
	for candidate: Dictionary in SPECIES:
		if StringName(candidate["id"]) == species_id:
			return candidate
	return {}


static func definition_for_model(path: String) -> Dictionary:
	var normalized := path.replace("\\", "/").to_lower()
	for candidate: Dictionary in SPECIES:
		if String(candidate["model_path"]).to_lower() == normalized:
			return candidate
	return {}


static func behavior_id(index: int) -> StringName:
	return StringName(BEHAVIORS[clampi(index, 0, BEHAVIORS.size() - 1)]["id"])
