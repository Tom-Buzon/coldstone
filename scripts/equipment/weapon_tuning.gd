extends RefCounted
class_name HopliteWeaponTuning

const CONFIG_PATH := "user://hoplite_global_settings_v1.cfg"
const SCHEMA_VERSION := 1
static var _runtime_overrides: Dictionary = {}

const DEFINITIONS: Array[Dictionary] = [
	{"id": &"scale", "label": "TAILLE", "min": 0.20, "max": 1.60, "step": 0.01, "unit": "x", "description": "Échelle uniforme du modèle équipé."},
	{"id": &"position_x", "label": "POSITION X", "min": -0.60, "max": 0.60, "step": 0.01, "unit": "m", "description": "Décalage latéral dans la main."},
	{"id": &"position_y", "label": "POSITION Y", "min": -0.60, "max": 0.60, "step": 0.01, "unit": "m", "description": "Décalage le long de la poignée."},
	{"id": &"position_z", "label": "POSITION Z", "min": -0.60, "max": 0.60, "step": 0.01, "unit": "m", "description": "Décalage avant/arrière dans la main."},
	{"id": &"rotation_x", "label": "ROTATION X", "min": -180.0, "max": 180.0, "step": 1.0, "unit": "deg", "description": "Rotation locale autour de X."},
	{"id": &"rotation_y", "label": "ROTATION Y", "min": -180.0, "max": 180.0, "step": 1.0, "unit": "deg", "description": "Rotation locale autour de Y."},
	{"id": &"rotation_z", "label": "ROTATION Z", "min": -180.0, "max": 180.0, "step": 1.0, "unit": "deg", "description": "Rotation locale autour de Z."},
	{"id": &"blade_base", "label": "DÉBUT DU CONTACT", "min": -0.25, "max": 2.50, "step": 0.01, "unit": "m", "description": "Début réel de la lame depuis la poignée."},
	{"id": &"blade_tip", "label": "FIN DU CONTACT", "min": -0.20, "max": 3.00, "step": 0.01, "unit": "m", "description": "Extrémité réelle de la lame."},
	{"id": &"hit_radius", "label": "ÉPAISSEUR DU CONTACT", "min": 0.02, "max": 0.40, "step": 0.01, "unit": "m", "description": "Tolérance autour du segment de lame."},
	{"id": &"damage_multiplier", "label": "PUISSANCE", "min": 0.25, "max": 3.00, "step": 0.05, "unit": "x", "description": "Multiplicateur des dégâts, dégâts de membre et dégâts de garde."},
]


static func defaults(item: HopliteEquipmentItemData) -> Dictionary:
	if item == null:
		return {}
	return {
		&"scale": 1.0,
		&"position_x": item.hand_position.x,
		&"position_y": item.hand_position.y,
		&"position_z": item.hand_position.z,
		&"rotation_x": item.hand_rotation_degrees.x,
		&"rotation_y": item.hand_rotation_degrees.y,
		&"rotation_z": item.hand_rotation_degrees.z,
		&"blade_base": item.blade_base_y,
		&"blade_tip": item.blade_tip_y,
		&"hit_radius": item.hit_radius,
		&"damage_multiplier": item.damage_multiplier,
	}


static func load_values(item: HopliteEquipmentItemData) -> Dictionary:
	var values := defaults(item)
	if values.is_empty():
		return values
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	var section := _section(item.item_id)
	for definition: Dictionary in DEFINITIONS:
		var id := StringName(definition["id"])
		values[id] = clampf(
			float(config.get_value(section, String(id), values[id])),
			float(definition["min"]),
			float(definition["max"])
		)
	var runtime_values := _runtime_overrides.get(section, {}) as Dictionary
	for raw_id: Variant in runtime_values.keys():
		values[StringName(raw_id)] = float(runtime_values[raw_id])
	values[&"blade_tip"] = maxf(float(values[&"blade_tip"]), float(values[&"blade_base"]) + 0.05)
	return values


static func set_runtime_value(item: HopliteEquipmentItemData, id: StringName, value: float) -> void:
	var definition := definition_for(id)
	if item == null or definition.is_empty():
		return
	var section := _section(item.item_id)
	var values := _runtime_overrides.get(section, {}) as Dictionary
	values[id] = clampf(value, float(definition["min"]), float(definition["max"]))
	_runtime_overrides[section] = values


static func save_value(item: HopliteEquipmentItemData, id: StringName, value: float) -> Error:
	var definition := definition_for(id)
	if item == null or definition.is_empty():
		return ERR_INVALID_PARAMETER
	set_runtime_value(item, id, value)
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	var section := _section(item.item_id)
	config.set_value(section, "schema_version", SCHEMA_VERSION)
	config.set_value(section, String(id), clampf(value, float(definition["min"]), float(definition["max"])))
	return config.save(CONFIG_PATH)


static func save_entries(entries: Array[Dictionary]) -> Error:
	if entries.is_empty():
		return OK
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	for entry: Dictionary in entries:
		var item := entry.get("item") as HopliteEquipmentItemData
		var id := StringName(entry.get("id", StringName()))
		var definition := definition_for(id)
		if item == null or definition.is_empty():
			continue
		var value := clampf(float(entry.get("value", 0.0)), float(definition["min"]), float(definition["max"]))
		set_runtime_value(item, id, value)
		var section := _section(item.item_id)
		config.set_value(section, "schema_version", SCHEMA_VERSION)
		config.set_value(section, String(id), value)
	return config.save(CONFIG_PATH)


static func reset(item: HopliteEquipmentItemData) -> Error:
	if item == null:
		return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	var section := _section(item.item_id)
	_runtime_overrides.erase(section)
	if config.has_section(section):
		config.erase_section(section)
	return config.save(CONFIG_PATH)


static func definition_for(id: StringName) -> Dictionary:
	for definition: Dictionary in DEFINITIONS:
		if StringName(definition["id"]) == id:
			return definition
	return {}


static func hand_position(values: Dictionary) -> Vector3:
	return Vector3(float(values[&"position_x"]), float(values[&"position_y"]), float(values[&"position_z"]))


static func hand_rotation_degrees(values: Dictionary) -> Vector3:
	return Vector3(float(values[&"rotation_x"]), float(values[&"rotation_y"]), float(values[&"rotation_z"]))


static func _section(item_id: StringName) -> String:
	return "weapon_%s" % String(item_id)
