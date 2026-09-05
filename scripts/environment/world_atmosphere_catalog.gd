extends RefCounted
class_name HopliteWorldAtmosphereCatalog

const SKY_ROOT := "res://assets/environment/skyboxes/poly_haven"

const SKIES := {
	"procedural": {"label": "Ciel procédural", "path": ""},
	"cloud_layers": {"label": "Nuages de midi", "path": SKY_ROOT + "/cloud_layers_1k.hdr"},
	"belfast_sunset": {"label": "Crépuscule pur", "path": SKY_ROOT + "/belfast_sunset_puresky_1k.hdr"},
	"dikhololo_sunset": {"label": "Savane au couchant", "path": SKY_ROOT + "/dikhololo_sunset_1k.hdr"},
}

const PRESETS := {
	"Jour antique": {"sky_id": "procedural", "sun_energy": 1.15, "sun_rotation_x": -48.0, "sun_rotation_y": -28.0, "sun_color": "#f9dfb2", "ambient_energy": 0.72, "fog_density": 0.006, "fog_height": 0.0, "fog_height_density": 0.0, "fog_color": "#d8ad78", "sky_top": "#263850", "sky_horizon": "#d8ad78", "background_energy": 1.0, "exposure": 1.08, "saturation": 1.0},
	"Ciel nuageux": {"sky_id": "cloud_layers", "sun_energy": 0.92, "sun_rotation_x": -55.0, "sun_rotation_y": -22.0, "sun_color": "#fff0d0", "ambient_energy": 0.78, "fog_density": 0.004, "fog_height": 0.0, "fog_height_density": 0.0, "fog_color": "#b9c4cf", "sky_top": "#52677c", "sky_horizon": "#c6c4b9", "background_energy": 0.86, "exposure": 1.02, "saturation": 0.92},
	"Siege enfume": {"sky_id": "dikhololo_sunset", "sun_energy": 0.66, "sun_rotation_x": -28.0, "sun_rotation_y": -34.0, "sun_color": "#ffb06e", "ambient_energy": 0.42, "fog_density": 0.027, "fog_height": 1.5, "fog_height_density": 0.08, "fog_color": "#9e6549", "sky_top": "#1d2029", "sky_horizon": "#9e6549", "background_energy": 0.72, "exposure": 1.05, "saturation": 0.92},
	"Crepuscule sanglant": {"sky_id": "belfast_sunset", "sun_energy": 0.82, "sun_rotation_x": -14.0, "sun_rotation_y": -52.0, "sun_color": "#ff9365", "ambient_energy": 0.48, "fog_density": 0.014, "fog_height": 0.0, "fog_height_density": 0.03, "fog_color": "#d65c46", "sky_top": "#151d38", "sky_horizon": "#d65c46", "background_energy": 0.82, "exposure": 1.08, "saturation": 1.08},
	"Nuit sacree": {"sky_id": "procedural", "sun_energy": 0.18, "sun_rotation_x": -38.0, "sun_rotation_y": 18.0, "sun_color": "#8aa6d8", "ambient_energy": 0.28, "fog_density": 0.019, "fog_height": 0.0, "fog_height_density": 0.02, "fog_color": "#31456b", "sky_top": "#080d20", "sky_horizon": "#31456b", "background_energy": 0.36, "exposure": 1.15, "saturation": 0.82},
}

static func sky_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in SKIES.keys():
		result.append(String(raw_id))
	return result

static func sky_labels() -> Array[String]:
	var result: Array[String] = []
	for sky_id: String in sky_ids():
		result.append(String((SKIES[sky_id] as Dictionary).get("label", sky_id)))
	return result

static func sky_path(sky_id: String) -> String:
	return String((SKIES.get(sky_id, SKIES["procedural"]) as Dictionary).get("path", ""))

static func defaults() -> Dictionary:
	var result := (PRESETS["Jour antique"] as Dictionary).duplicate(true)
	result["preset"] = "Jour antique"
	return result

static func normalized(values: Dictionary) -> Dictionary:
	var result := defaults()
	for key: Variant in values:
		result[key] = values[key]
	result["sky_id"] = String(result.get("sky_id", "procedural")) if SKIES.has(String(result.get("sky_id", "procedural"))) else "procedural"
	return result
