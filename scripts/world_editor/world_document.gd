extends RefCounted
class_name HopliteWorldDocument

const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")
const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")
const EncounterBudgetScript = preload("res://scripts/world_editor/world_encounter_budget.gd")
const AtmosphereCatalogScript = preload("res://scripts/environment/world_atmosphere_catalog.gd")

const CURRENT_VERSION := 10
const COLLISION_POLICY_VERSION := 5
const DEFAULT_WARNING_LIMIT := 300

var data: Dictionary = {}

func _init(source: Dictionary = {}) -> void:
	data = source.duplicate(true) if not source.is_empty() else create_default()
	_normalize()

static func create_default() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"name": "Nouveau monde",
		"settings": {
			"grid_size": 1.0,
			"map_half_extent": 60.0,
			"test_radius": 32.0,
			"mob_warning_limit": DEFAULT_WARNING_LIMIT
		},
		"chapters": [{"id": "chapter_1", "name": "Chapitre 1"}],
		"start_chapter": "chapter_1",
		"atmosphere": AtmosphereCatalogScript.defaults(),
		"entities": [],
		"editor_groups": [],
		"events": []
	}

static func example_world() -> Dictionary:
	var result := create_default()
	result["name"] = "Bac a sable des Thermopyles"
	result["chapters"] = [
		{"id": "agora", "name": "I — Agora assiegee"},
		{"id": "cryptes", "name": "II — Cryptes du rempart"}
	]
	result["start_chapter"] = "agora"
	var guard := _chapter_entity("enemy_group", "Garde de l'agora", Vector3(0, 0.1, -2), {
		"group_id": "garde_agora", "archetype": "nathenian1", "count": 8,
		"rank": "normal", "size_multiplier": 1.0, "behavior": "patrol",
		"route_id": "ronde_agora", "protect_target": "", "spawn_condition": "start",
		"spawn_trigger": "", "spawn_dead_group": "", "spawn_delay": 3.0, "formation": "line"
	}, "agora")
	var gate := _chapter_entity("door", "Porte nord de l'agora", Vector3(0, 2.5, -15), {
		"size": [4.0, 5.0, 0.55], "door_style": "iron", "open_motion": "vertical",
		"open_duration": 1.4, "starts_open": false
	}, "agora")
	var open_gate_trigger := _chapter_entity("trigger", "Ouvrir la porte apres la garde", Vector3(0, 1.5, -10), {
		"size": [2.0, 2.0, 2.0], "condition": "group_dead", "condition_group": "garde_agora",
		"threshold": 100.0, "action": "open_door", "action_target": String(gate.get("id", "")), "once": true
	}, "agora")
	result["entities"] = [
		_chapter_entity("player_spawn", "Depart de l'agora", Vector3(0, 0.05, 12), {"radius": 1.0, "spawn_id": "entree_agora"}, "agora"),
		entity("surface", "Place d'entrainement", Vector3.ZERO, {"shape": "floor", "size": [30.0, 0.35, 30.0], "material": "pavers"}),
		_chapter_entity("surface", "Mur nord gauche", Vector3(-8.5, 2.5, -15), {"shape": "wall", "size": [13.0, 5.0, 0.5], "material": "fortress"}, "agora"),
		_chapter_entity("surface", "Mur nord droit", Vector3(8.5, 2.5, -15), {"shape": "wall", "size": [13.0, 5.0, 0.5], "material": "fortress"}, "agora"),
		entity("surface", "Mur ouest", Vector3(-15, 2.5, 0), {"shape": "wall", "size": [0.5, 5.0, 30.0], "material": "rough_stone"}),
		entity("surface", "Mur est", Vector3(15, 2.5, 0), {"shape": "wall", "size": [0.5, 5.0, 30.0], "material": "rough_stone"}),
		entity("prop", "Brasero gauche", Vector3(-5, 0, -7), {"asset_id": "brazier"}),
		entity("prop", "Brasero droit", Vector3(5, 0, -7), {"asset_id": "brazier"}),
		entity("light", "Lueur centrale", Vector3(0, 4, -4), {"light_type": "omni", "color": "#ff8a35", "energy": 3.0, "range": 13.0}),
		entity("patrol_point", "Patrouille A", Vector3(-8, 0.1, 2), {"route_id": "ronde_agora", "order": 0, "wait": 1.0}),
		entity("patrol_point", "Patrouille B", Vector3(8, 0.1, 2), {"route_id": "ronde_agora", "order": 1, "wait": 1.0}),
		guard,
		gate,
		open_gate_trigger,
		entity("narrative", "Annonce de l'agora", Vector3(0, 1.0, 7), {
			"speaker": "Le capitaine", "text": "La porte est tenue. Brisez leur ligne !", "duration": 4.0
		}),
		entity("atmosphere_zone", "Ombre de la porte", Vector3(0, 2.5, -9), {
			"size": [18.0, 5.0, 8.0], "preset": "Siege enfume", "sun_energy": 0.62,
			"ambient_energy": 0.42, "fog_density": 0.025
		}),
		_chapter_entity("trigger", "Entrer dans l'agora", Vector3(0, 1.5, 6), {
			"size": [12.0, 3.0, 4.0], "condition": "player_enter", "condition_group": "",
			"threshold": 100.0, "action": "narrative", "action_target": "Annonce de l'agora",
			"action_text": "", "once": true
		}, "agora"),
		_chapter_entity("surface", "Passage derriere la porte", Vector3(0, 0.175, -19), {"shape": "floor", "size": [6.0, 0.35, 8.0], "material": "rough_stone"}, "agora"),
		_chapter_entity("chapter_portal", "Descendre dans les cryptes", Vector3(0, 1.5, -21.5), {"size": [3.0, 3.0, 1.5], "destination_chapter": "cryptes", "destination_spawn": "entree_cryptes", "label": "CRYPTES"}, "agora"),
		_chapter_entity("player_spawn", "Arrivee dans les cryptes", Vector3(0, 0.05, 10), {"radius": 1.0, "spawn_id": "entree_cryptes"}, "cryptes"),
		_chapter_entity("surface", "Sol des cryptes", Vector3(0, 0.175, 0), {"shape": "floor", "size": [24.0, 0.35, 28.0], "material": "bone_gravel"}, "cryptes"),
		_chapter_entity("surface", "Fond des cryptes", Vector3(0, 3.0, -14), {"shape": "wall", "size": [24.0, 6.0, 0.5], "material": "rough_stone"}, "cryptes"),
		_chapter_entity("light", "Lueur des cryptes", Vector3(0, 4, 1), {"light_type": "omni", "color": "#6c86ff", "energy": 2.8, "range": 16.0}, "cryptes"),
		_chapter_entity("chapter_portal", "Remonter vers l'agora", Vector3(0, 1.5, 12), {"size": [3.0, 3.0, 1.5], "destination_chapter": "agora", "destination_spawn": "entree_agora", "label": "AGORA"}, "cryptes")
	]
	for raw: Variant in result["entities"]:
		var value := raw as Dictionary
		if not value.has("chapter"):
			value["chapter"] = "agora"
	return result

static func _chapter_entity(type: String, display_name: String, position: Vector3, properties: Dictionary, chapter_id: String) -> Dictionary:
	var value := entity(type, display_name, position, properties)
	value["chapter"] = chapter_id
	return value

static func entity(type: String, display_name: String, position: Vector3, properties: Dictionary = {}) -> Dictionary:
	var id := "%s_%d_%d" % [type, Time.get_ticks_usec(), randi_range(100, 999)]
	return {
		"id": id,
		"type": type,
		"name": display_name,
		"position": [position.x, position.y, position.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"enabled": true,
		"properties": properties.duplicate(true)
	}

func entities() -> Array:
	return data.get("entities", []) as Array

func chapters() -> Array:
	return data.get("chapters", []) as Array

func start_chapter() -> String:
	return String(data.get("start_chapter", "chapter_1"))

func entities_for_chapter(chapter_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in entities():
		var value := raw as Dictionary
		if String(value.get("chapter", start_chapter())) == chapter_id:
			result.append(value)
	return result

func add_entity(value: Dictionary) -> String:
	var copy := value.duplicate(true)
	if String(copy.get("id", "")).is_empty():
		copy["id"] = "entity_%d_%d" % [Time.get_ticks_usec(), randi_range(100, 999)]
	(data["entities"] as Array).append(copy)
	return String(copy["id"])

func remove_entity(id: String) -> bool:
	var values := data["entities"] as Array
	for index in range(values.size()):
		if String((values[index] as Dictionary).get("id", "")) == id:
			values.remove_at(index)
			_remove_entity_from_editor_groups(id)
			return true
	return false

func editor_groups() -> Array:
	return data.get("editor_groups", []) as Array

func find_editor_group(id: String) -> Dictionary:
	for raw: Variant in editor_groups():
		var group := raw as Dictionary
		if String(group.get("id", "")) == id:
			return group
	return {}

func find_editor_group_reference(key: String) -> Dictionary:
	if key.is_empty():
		return {}
	for raw: Variant in editor_groups():
		var group := raw as Dictionary
		if key in [String(group.get("id", "")), String(group.get("name", ""))]:
			return group
	return {}

func editor_groups_for_entity(entity_id: String, kind: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in editor_groups():
		var group := raw as Dictionary
		if not kind.is_empty() and String(group.get("kind", "object")) != kind:
			continue
		if entity_id in (group.get("entity_ids", []) as Array):
			result.append(group)
	return result

func create_editor_group(display_name: String, entity_ids: Array, kind: String = "") -> String:
	var normalized_ids := _valid_unique_entity_ids(entity_ids)
	if normalized_ids.is_empty():
		return ""
	var normalized_kind := kind if kind in ["enemy", "object"] else _infer_editor_group_kind(normalized_ids)
	if normalized_kind.is_empty() or not _entity_ids_match_group_kind(normalized_ids, normalized_kind):
		return ""
	var id := "editor_group_%d_%d" % [Time.get_ticks_usec(), randi_range(100, 999)]
	editor_groups().append({
		"id": id,
		"name": display_name.strip_edges() if not display_name.strip_edges().is_empty() else "Nouveau groupe",
		"kind": normalized_kind,
		"entity_ids": normalized_ids,
	})
	return id

func set_editor_group_members(id: String, entity_ids: Array) -> bool:
	var group := find_editor_group(id)
	if group.is_empty():
		return false
	var normalized_ids := _valid_unique_entity_ids(entity_ids)
	if not _entity_ids_match_group_kind(normalized_ids, String(group.get("kind", "object"))):
		return false
	group["entity_ids"] = normalized_ids
	return true

func rename_editor_group(id: String, display_name: String) -> bool:
	var group := find_editor_group(id)
	var safe_name := display_name.strip_edges()
	if group.is_empty() or safe_name.is_empty():
		return false
	group["name"] = safe_name
	return true

func remove_editor_group(id: String) -> bool:
	var groups := editor_groups()
	for index in range(groups.size()):
		if String((groups[index] as Dictionary).get("id", "")) == id:
			groups.remove_at(index)
			return true
	return false

func _remove_entity_from_editor_groups(entity_id: String) -> void:
	for raw: Variant in editor_groups():
		var group := raw as Dictionary
		var ids := group.get("entity_ids", []) as Array
		ids.erase(entity_id)
	for index in range(editor_groups().size() - 1, -1, -1):
		var group := editor_groups()[index] as Dictionary
		if (group.get("entity_ids", []) as Array).is_empty():
			editor_groups().remove_at(index)

func _valid_unique_entity_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_id: Variant in values:
		var id := String(raw_id)
		if not id.is_empty() and not result.has(id) and not find_entity(id).is_empty():
			result.append(id)
	return result

func _infer_editor_group_kind(entity_ids: Array) -> String:
	if entity_ids.is_empty():
		return ""
	var enemy_count := 0
	for raw_id: Variant in entity_ids:
		var entity := find_entity(String(raw_id))
		if String(entity.get("type", "")) == "enemy_group":
			enemy_count += 1
	if enemy_count == entity_ids.size():
		return "enemy"
	if enemy_count == 0:
		return "object"
	return ""

func _entity_ids_match_group_kind(entity_ids: Array, kind: String) -> bool:
	if entity_ids.is_empty():
		return true
	return _infer_editor_group_kind(entity_ids) == kind

func enemy_entities_for_reference(reference: String, chapter_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if reference.is_empty():
		return result
	var editor_group := find_editor_group_reference(reference)
	if not editor_group.is_empty() and String(editor_group.get("kind", "object")) == "enemy":
		for raw_id: Variant in editor_group.get("entity_ids", []):
			var member := find_entity(String(raw_id))
			if String(member.get("type", "")) != "enemy_group":
				continue
			if not chapter_id.is_empty() and String(member.get("chapter", start_chapter())) != chapter_id:
				continue
			result.append(member)
		return result
	for raw: Variant in entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) != "enemy_group":
			continue
		if not chapter_id.is_empty() and String(entity.get("chapter", start_chapter())) != chapter_id:
			continue
		var properties := entity.get("properties", {}) as Dictionary
		if reference in [String(entity.get("id", "")), String(entity.get("name", "")), String(properties.get("group_id", ""))]:
			result.append(entity)
	return result

func find_entity(id: String) -> Dictionary:
	for raw: Variant in entities():
		var value := raw as Dictionary
		if String(value.get("id", "")) == id:
			return value
	return {}

func find_by_name(display_name: String) -> Dictionary:
	for raw: Variant in entities():
		var value := raw as Dictionary
		if String(value.get("name", "")) == display_name:
			return value
	return {}

func duplicate_entity(id: String) -> String:
	var source := find_entity(id)
	if source.is_empty():
		return ""
	var copy := source.duplicate(true)
	copy["id"] = "%s_copy_%d" % [id, Time.get_ticks_usec()]
	copy["name"] = "%s (copie)" % String(source.get("name", "Element"))
	var position := vector3(source.get("position", [0, 0, 0])) + Vector3(1.0, 0.0, 1.0)
	copy["position"] = array3(position)
	(data["entities"] as Array).append(copy)
	return String(copy["id"])

func theoretical_mob_count(chapter_id: String = "") -> int:
	var total := 0
	for raw: Variant in entities():
		var value := raw as Dictionary
		if not chapter_id.is_empty() and String(value.get("chapter", start_chapter())) != chapter_id:
			continue
		if String(value.get("type", "")) == "enemy_group" and bool(value.get("enabled", true)):
			total += maxi(0, int((value.get("properties", {}) as Dictionary).get("count", 0)))
	return total

func warning_limit() -> int:
	return maxi(1, int((data.get("settings", {}) as Dictionary).get("mob_warning_limit", DEFAULT_WARNING_LIMIT)))

func validation_report() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var ids: Dictionary = {}
	var group_ids: Dictionary = {}
	var player_spawns_by_chapter: Dictionary = {}
	var terrains_by_chapter: Dictionary = {}
	var chapter_ids: Dictionary = {}
	for raw_chapter: Variant in chapters():
		var chapter := raw_chapter as Dictionary
		var chapter_id := String(chapter.get("id", ""))
		if chapter_id.is_empty():
			errors.append("Un chapitre ne possede pas d'identifiant.")
		elif chapter_ids.has(chapter_id):
			errors.append("Identifiant de chapitre duplique : %s" % chapter_id)
		chapter_ids[chapter_id] = true
		player_spawns_by_chapter[chapter_id] = 0
		terrains_by_chapter[chapter_id] = 0
	if not chapter_ids.has(start_chapter()):
		errors.append("Le chapitre de depart est introuvable.")
	for raw: Variant in entities():
		var value := raw as Dictionary
		var id := String(value.get("id", ""))
		if id.is_empty():
			errors.append("Un element ne possede pas d'identifiant.")
		elif ids.has(id):
			errors.append("Identifiant duplique : %s" % id)
		ids[id] = true
		var type := String(value.get("type", ""))
		var properties := value.get("properties", {}) as Dictionary
		if type == "terrain":
			var terrain_chapter := String(value.get("chapter", start_chapter()))
			terrains_by_chapter[terrain_chapter] = int(terrains_by_chapter.get(terrain_chapter, 0)) + 1
			var resolution := int(properties.get("resolution", 0))
			var heights := properties.get("heights", []) as Array
			var material_weights := properties.get("material_weights", []) as Array
			var material_palette := properties.get("material_palette", []) as Array
			var foliage_density := properties.get("foliage_density", []) as Array
			var foliage_types := properties.get("foliage_types", []) as Array
			var foliage_layers := properties.get("foliage_layers", []) as Array
			var width := float(properties.get("width", 0.0))
			var depth := float(properties.get("depth", 0.0))
			if resolution < WorldTerrainScript.MIN_RESOLUTION or resolution > WorldTerrainScript.MAX_RESOLUTION or resolution % 2 == 0:
				errors.append("Le terrain '%s' possede une resolution invalide." % String(value.get("name", id)))
			elif heights.size() != resolution * resolution:
				errors.append("Le relief du terrain '%s' est incomplet." % String(value.get("name", id)))
			elif material_palette.is_empty() or material_weights.size() != resolution * resolution * material_palette.size() or foliage_density.size() != resolution * resolution or foliage_types.size() != resolution * resolution or foliage_layers.size() != resolution * resolution * WorldTerrainScript.FOLIAGE_PRESETS.size():
				errors.append("Les cartes peintes du terrain '%s' sont incompletes." % String(value.get("name", id)))
			if width < WorldTerrainScript.MIN_SIZE or width > WorldTerrainScript.MAX_SIZE or depth < WorldTerrainScript.MIN_SIZE or depth > WorldTerrainScript.MAX_SIZE:
				errors.append("Le terrain '%s' possede des dimensions invalides." % String(value.get("name", id)))
		elif type == "prop" and properties.has("portal_role"):
			var portal_role := String(properties.get("portal_role", ""))
			if portal_role not in ["", "world_editor", "official_campaign", "saved_worlds_anchor"]:
				errors.append("Le portail '%s' possede un role de lobby inconnu." % String(value.get("name", id)))
			elif portal_role == "official_campaign" and String(properties.get("campaign_id", "")) not in ["grand_siege", "procedural_campaign", "last_flame"]:
				errors.append("Le portail '%s' doit choisir une campagne existante." % String(value.get("name", id)))
		elif type == "player_spawn":
			var entity_chapter := String(value.get("chapter", start_chapter()))
			player_spawns_by_chapter[entity_chapter] = int(player_spawns_by_chapter.get(entity_chapter, 0)) + 1
		elif type == "enemy_group":
			var group_id := String(properties.get("group_id", ""))
			if group_id.is_empty():
				errors.append("Le groupe '%s' n'a pas d'identifiant de groupe." % String(value.get("name", id)))
			elif group_ids.has(group_id):
				warnings.append("Plusieurs groupes utilisent '%s'. Ils seront traites ensemble." % group_id)
			group_ids[group_id] = true
			if int(properties.get("count", 0)) <= 0:
				warnings.append("Le groupe '%s' est vide." % String(value.get("name", id)))
			var fallback := "start" if bool(properties.get("active_on_start", true)) else "trigger"
			var spawn_condition := String(properties.get("spawn_condition", fallback))
			if spawn_condition not in ["start", "trigger", "group_dead", "timer"]:
				errors.append("La troupe '%s' utilise une condition de spawn inconnue." % String(value.get("name", id)))
			elif spawn_condition == "trigger" and String(properties.get("spawn_trigger", "")).is_empty():
				errors.append("La troupe '%s' attend un declencheur non renseigne." % String(value.get("name", id)))
			elif spawn_condition == "group_dead" and String(properties.get("spawn_dead_group", "")).is_empty():
				errors.append("La troupe '%s' attend la mort d'une troupe non renseignee." % String(value.get("name", id)))
			elif spawn_condition == "timer" and float(properties.get("spawn_delay", 0.0)) < 0.0:
				errors.append("La troupe '%s' possede un timer negatif." % String(value.get("name", id)))
			var behavior := String(properties.get("behavior", "normal"))
			if behavior == "patrol" and String(properties.get("route_id", "")).is_empty():
				warnings.append("La troupe '%s' patrouille sans route tracee." % String(value.get("name", id)))
			elif behavior == "protect" and String(properties.get("protect_target", "")).is_empty():
				warnings.append("La troupe '%s' ne possede aucune cible a proteger." % String(value.get("name", id)))
			var deployment_mode := String(properties.get("deployment_mode", "all"))
			if deployment_mode not in ["all", "waves", "reserve"]:
				errors.append("La troupe '%s' utilise un mode de deploiement inconnu." % String(value.get("name", id)))
			elif deployment_mode == "waves":
				if int(properties.get("wave_size", 0)) <= 0 or float(properties.get("wave_interval", 0.0)) <= 0.0:
					errors.append("La troupe '%s' possede une vague ou un intervalle invalide." % String(value.get("name", id)))
				var legacy_stop_mode := "event" if not String(properties.get("deployment_stop_trigger", "")).is_empty() else "total"
				var stop_mode := String(properties.get("deployment_stop_mode", legacy_stop_mode))
				if stop_mode not in ["total", "event", "unit_death"]:
					errors.append("La troupe '%s' utilise un arret de vagues inconnu." % String(value.get("name", id)))
				elif stop_mode == "event" and String(properties.get("deployment_stop_trigger", "")).is_empty():
					errors.append("La troupe '%s' attend un evenement d'arret non renseigne." % String(value.get("name", id)))
				elif stop_mode == "unit_death" and String(properties.get("deployment_stop_group", "")).is_empty():
					errors.append("La troupe '%s' attend une troupe dont la mort d'une unite arretera les vagues." % String(value.get("name", id)))
			elif deployment_mode == "reserve":
				var total_count := int(properties.get("count", 0))
				var initial_active := int(properties.get("initial_active", 0))
				var threshold := int(properties.get("reinforce_threshold", 0))
				if initial_active <= 0 or initial_active > total_count:
					errors.append("La troupe '%s' doit avoir un effectif initial compris dans son total." % String(value.get("name", id)))
				if threshold > initial_active:
					warnings.append("Le seuil de '%s' depasse son effectif initial : les renforts arriveront immediatement." % String(value.get("name", id)))
		elif type == "trigger":
			var condition := String(properties.get("condition", "player_enter"))
			if condition in ["group_dead", "group_dead_percent"] and String(properties.get("condition_group", "")).is_empty():
				errors.append("Le declencheur '%s' attend un groupe non renseigne." % String(value.get("name", id)))
			var action := String(properties.get("action", "none"))
			if action in ["spawn_group", "remove_group"] and String(properties.get("action_target", "")).is_empty():
				errors.append("Le declencheur '%s' a une action sans cible." % String(value.get("name", id)))
			elif action == "music" and String(properties.get("music_path", "")).is_empty():
				errors.append("Le declencheur '%s' doit choisir une musique." % String(value.get("name", id)))
			elif action == "narrative" and String(properties.get("action_text", "")).is_empty() and String(properties.get("action_target", "")).is_empty():
				warnings.append("Le declencheur '%s' affiche une narration vide." % String(value.get("name", id)))
			elif action == "open_door" and String(properties.get("action_target", "")).is_empty():
				errors.append("Le declencheur '%s' doit choisir une porte." % String(value.get("name", id)))
		elif type == "chapter_portal":
			var destination_chapter := String(properties.get("destination_chapter", ""))
			if destination_chapter.is_empty():
				errors.append("Le passage '%s' ne possede pas de chapitre de destination." % String(value.get("name", id)))
			elif not chapter_ids.has(destination_chapter):
				errors.append("Le passage '%s' vise un chapitre introuvable." % String(value.get("name", id)))
	for raw_chapter: Variant in chapters():
		var chapter := raw_chapter as Dictionary
		var chapter_id := String(chapter.get("id", ""))
		if int(player_spawns_by_chapter.get(chapter_id, 0)) == 0:
			warnings.append("Le chapitre '%s' ne possede aucun point d'arrivee joueur." % String(chapter.get("name", chapter_id)))
		if int(terrains_by_chapter.get(chapter_id, 0)) > 1:
			warnings.append("Le chapitre '%s' contient plusieurs terrains superposes." % String(chapter.get("name", chapter_id)))
	var mob_count := theoretical_mob_count()
	if mob_count >= warning_limit():
		warnings.append("%d ennemis peuvent etre actifs (seuil : %d)." % [mob_count, warning_limit()])
	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings, "mob_count": mob_count}

func to_json() -> String:
	data["version"] = CURRENT_VERSION
	return JSON.stringify(data, "  ", false)

static func from_json(text: String) -> HopliteWorldDocument:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return null
	return HopliteWorldDocument.new(parsed as Dictionary)

func _normalize() -> void:
	var source_version := int(data.get("version", 1))
	data["version"] = source_version
	data["name"] = String(data.get("name", "Monde sans nom"))
	if not data.get("settings") is Dictionary:
		data["settings"] = {}
	var settings := data["settings"] as Dictionary
	settings["grid_size"] = float(settings.get("grid_size", 1.0))
	settings["map_half_extent"] = clampf(float(settings.get("map_half_extent", 60.0)), 20.0, 1000.0)
	settings["test_radius"] = float(settings.get("test_radius", 32.0))
	settings["mob_warning_limit"] = int(settings.get("mob_warning_limit", DEFAULT_WARNING_LIMIT))
	if not data.get("atmosphere") is Dictionary:
		data["atmosphere"] = create_default()["atmosphere"]
	else:
		data["atmosphere"] = AtmosphereCatalogScript.normalized(data["atmosphere"] as Dictionary)
	if not data.get("entities") is Array:
		data["entities"] = []
	if not data.get("events") is Array:
		data["events"] = []
	if not data.get("editor_groups") is Array:
		data["editor_groups"] = []
	if not data.get("chapters") is Array or (data.get("chapters", []) as Array).is_empty():
		data["chapters"] = [{"id": "chapter_1", "name": "Chapitre 1"}]
	var first_chapter := String(((data["chapters"] as Array)[0] as Dictionary).get("id", "chapter_1"))
	data["start_chapter"] = String(data.get("start_chapter", first_chapter))
	for raw: Variant in data["entities"]:
		if not raw is Dictionary:
			continue
		var value := raw as Dictionary
		value["chapter"] = String(value.get("chapter", data["start_chapter"]))
		value["position"] = _normalized_array3(value.get("position", [0, 0, 0]), [0.0, 0.0, 0.0])
		value["rotation"] = _normalized_array3(value.get("rotation", [0, 0, 0]), [0.0, 0.0, 0.0])
		value["scale"] = _normalized_array3(value.get("scale", [1, 1, 1]), [1.0, 1.0, 1.0])
		if not value.get("properties") is Dictionary:
			value["properties"] = {}
		var properties := value["properties"] as Dictionary
		if String(value.get("type", "")) == "terrain":
			WorldTerrainScript.normalize(properties)
		elif String(value.get("type", "")) == "prop" and properties.has("asset_path"):
			properties["asset_path"] = AssetCatalogScript.migrate_asset_path(String(properties.get("asset_path", "")))
			if source_version < COLLISION_POLICY_VERSION:
				var collision_policy := AssetCatalogScript.stylized_nature_collision_policy(String(properties["asset_path"]))
				if collision_policy == &"blocking":
					properties["collision_enabled"] = true
				elif collision_policy == &"non_blocking":
					properties["collision_enabled"] = false
			if properties.has("portal_role"):
				var portal_role := String(properties.get("portal_role", ""))
				if portal_role not in ["", "world_editor", "official_campaign", "saved_worlds_anchor"]:
					portal_role = ""
				properties["portal_role"] = portal_role
				properties["portal_label"] = String(properties.get("portal_label", ""))
				if portal_role == "official_campaign":
					properties["campaign_id"] = String(properties.get("campaign_id", "procedural_campaign"))
				elif portal_role == "saved_worlds_anchor":
					properties["portal_columns"] = clampi(int(properties.get("portal_columns", 9)), 1, 17)
					properties["portal_column_spacing"] = clampf(float(properties.get("portal_column_spacing", 7.25)), 5.0, 30.0)
					properties["portal_row_spacing"] = clampf(float(properties.get("portal_row_spacing", 8.0)), 5.0, 30.0)
		elif String(value.get("type", "")) == "enemy_group":
			properties["performance_profile"] = EncounterBudgetScript.normalize_profile(properties.get("performance_profile", "auto"))
			if properties.has("v2_animation"):
				var v2_animation := String(properties.get("v2_animation", "idle"))
				if v2_animation not in ["phalanx_cycle", "idle", "move", "sprint", "death", "spear_thrust", "spear_thrust_low", "shield_bash", "block_idle", "block_impact"]:
					v2_animation = "idle"
				properties["v2_animation"] = v2_animation
			properties["v2_combat_lab"] = bool(properties.get("v2_combat_lab", false))
			properties["match_perfect_hitbox"] = bool(properties.get("match_perfect_hitbox", false))
			var traversal_mode := String(properties.get("giant_traversal_mode", "assisted"))
			if traversal_mode not in ["assisted", "exact", "off"]:
				traversal_mode = "assisted"
			properties["giant_traversal_mode"] = traversal_mode
			properties["giant_capsule_radius_multiplier"] = clampf(float(properties.get("giant_capsule_radius_multiplier", 0.90)), 0.55, 1.35)
			properties["giant_capsule_height_multiplier"] = clampf(float(properties.get("giant_capsule_height_multiplier", 1.0)), 0.80, 1.25)
			properties["giant_walkable_tops"] = bool(properties.get("giant_walkable_tops", true))
			var fallback := "start" if bool(properties.get("active_on_start", true)) else "trigger"
			properties["spawn_condition"] = String(properties.get("spawn_condition", fallback))
			properties["spawn_trigger"] = String(properties.get("spawn_trigger", ""))
			properties["spawn_dead_group"] = String(properties.get("spawn_dead_group", ""))
			properties["spawn_delay"] = maxf(0.0, float(properties.get("spawn_delay", 3.0)))
			properties["formation"] = String(properties.get("formation", "line"))
			properties["deployment_mode"] = String(properties.get("deployment_mode", "all"))
			properties["wave_size"] = maxi(1, int(properties.get("wave_size", 3)))
			properties["wave_interval"] = maxf(0.1, float(properties.get("wave_interval", 5.0)))
			properties["deployment_stop_trigger"] = String(properties.get("deployment_stop_trigger", ""))
			var legacy_stop_mode := "event" if not String(properties["deployment_stop_trigger"]).is_empty() else "total"
			properties["deployment_stop_mode"] = String(properties.get("deployment_stop_mode", legacy_stop_mode))
			properties["deployment_stop_group"] = String(properties.get("deployment_stop_group", ""))
			properties["initial_active"] = maxi(1, int(properties.get("initial_active", mini(10, maxi(1, int(properties.get("count", 1)))))))
			properties["reinforce_threshold"] = maxi(0, int(properties.get("reinforce_threshold", 7)))
			properties["reinforce_amount"] = maxi(1, int(properties.get("reinforce_amount", 3)))
			if properties.get("composition") is Array:
				var composition_total := 0
				for composition_raw: Variant in properties["composition"]:
					if composition_raw is Dictionary:
						composition_total += maxi(0, int((composition_raw as Dictionary).get("count", 0)))
				if composition_total > 0:
					properties["count"] = composition_total
		elif String(value.get("type", "")) == "door":
			properties["size"] = _normalized_array3(properties.get("size", [3.0, 4.0, 0.45]), [3.0, 4.0, 0.45])
			properties["door_style"] = String(properties.get("door_style", "wood"))
			properties["open_motion"] = String(properties.get("open_motion", "pivot_left"))
			properties["open_duration"] = maxf(0.05, float(properties.get("open_duration", 1.2)))
			properties["starts_open"] = bool(properties.get("starts_open", false))
		elif String(value.get("type", "")) == "chapter_portal":
			properties["size"] = _normalized_array3(properties.get("size", [3.0, 3.0, 1.5]), [3.0, 3.0, 1.5])
			properties["destination_chapter"] = String(properties.get("destination_chapter", ""))
			properties["destination_spawn"] = String(properties.get("destination_spawn", ""))
		elif String(value.get("type", "")) == "player_spawn":
			properties["spawn_id"] = String(properties.get("spawn_id", "depart"))
		elif String(value.get("type", "")) == "water":
			properties["size"] = _normalized_array3(properties.get("size", [12.0, 0.08, 12.0]), [12.0, 0.08, 12.0])
			properties["size"][0] = clampf(float(properties["size"][0]), 0.5, 500.0)
			properties["size"][1] = clampf(float(properties["size"][1]), 0.01, 1.0)
			properties["size"][2] = clampf(float(properties["size"][2]), 0.5, 500.0)
			properties["shallow_color"] = String(properties.get("shallow_color", "#167e93"))
			properties["deep_color"] = String(properties.get("deep_color", "#062b4a"))
			properties["texture"] = String(properties.get("texture", "none"))
			properties["texture_scale"] = clampf(float(properties.get("texture_scale", 4.0)), 0.25, 32.0)
			properties["texture_strength"] = clampf(float(properties.get("texture_strength", 0.18)), 0.0, 1.0)
			properties["opacity"] = clampf(float(properties.get("opacity", 0.68)), 0.05, 1.0)
			properties["wave_scale"] = clampf(float(properties.get("wave_scale", 0.55)), 0.05, 4.0)
			properties["wave_speed"] = clampf(float(properties.get("wave_speed", 0.7)), 0.0, 4.0)
			properties["wave_height"] = clampf(float(properties.get("wave_height", 0.08)), 0.0, 0.5)
			properties["roughness"] = clampf(float(properties.get("roughness", 0.18)), 0.02, 1.0)
		elif String(value.get("type", "")) == "fire":
			properties["amount"] = clampi(int(properties.get("amount", 48)), 8, 128)
			properties["size"] = clampf(float(properties.get("size", 1.0)), 0.15, 8.0)
			properties["lifetime"] = clampf(float(properties.get("lifetime", 1.15)), 0.35, 3.0)
			properties["core_color"] = String(properties.get("core_color", "#ffdc52"))
			properties["edge_color"] = String(properties.get("edge_color", "#ff3608"))
			properties["light_enabled"] = bool(properties.get("light_enabled", false))
			properties["light_energy"] = clampf(float(properties.get("light_energy", 1.8)), 0.0, 8.0)
			properties["light_range"] = clampf(float(properties.get("light_range", 7.0)), 0.5, 30.0)
	var known_entity_ids: Dictionary = {}
	for raw: Variant in data["entities"]:
		if raw is Dictionary:
			known_entity_ids[String((raw as Dictionary).get("id", ""))] = true
	var normalized_groups: Array = []
	var known_group_ids: Dictionary = {}
	for raw: Variant in data["editor_groups"]:
		if not raw is Dictionary:
			continue
		var source_group := raw as Dictionary
		var group_id := String(source_group.get("id", ""))
		if group_id.is_empty() or known_group_ids.has(group_id):
			group_id = "editor_group_%d_%d" % [Time.get_ticks_usec(), randi_range(100, 999)]
		known_group_ids[group_id] = true
		var member_ids: Array[String] = []
		for member_raw: Variant in source_group.get("entity_ids", []):
			var member_id := String(member_raw)
			if known_entity_ids.has(member_id) and not member_ids.has(member_id):
				member_ids.append(member_id)
		if member_ids.is_empty():
			continue
		var group_name := String(source_group.get("name", "Groupe")).strip_edges()
		if group_name.is_empty():
			group_name = "Groupe"
		var group_kind := String(source_group.get("kind", ""))
		if group_kind not in ["enemy", "object"]:
			group_kind = _infer_editor_group_kind(member_ids)
			if group_kind.is_empty():
				group_kind = "object"
		normalized_groups.append({
			"id": group_id,
			"name": group_name,
			"kind": group_kind,
			"entity_ids": member_ids,
		})
	data["editor_groups"] = normalized_groups
	data["version"] = CURRENT_VERSION

static func _normalized_array3(value: Variant, fallback: Array) -> Array:
	if value is Array and value.size() >= 3:
		return [float(value[0]), float(value[1]), float(value[2])]
	return fallback.duplicate()

static func vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

static func array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
