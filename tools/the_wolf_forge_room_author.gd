extends SceneTree

const ROOM_NAME := "Laboratoire de theWolf"

var editor: Node
var document: HopliteWorldDocument


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var error := change_scene_to_file("res://world_editor.tscn")
	if error != OK:
		_fail("World Forge indisponible : %s" % error_string(error))
		return
	await process_frame
	await process_frame
	editor = current_scene
	if editor == null or not editor.has_method("_place_brush_at"):
		_fail("les outils d'authoring de la Forge ne sont pas disponibles")
		return
	editor.call("_new_world")
	await process_frame
	document = editor.get("document") as HopliteWorldDocument
	if document == null:
		_fail("document Forge indisponible")
		return

	document.data["atmosphere"] = {
		"preset": "Nuit sacree",
		"sun_energy": 0.22,
		"ambient_energy": 0.34,
		"fog_density": 0.012,
		"sky_top": "#090d1f",
		"sky_horizon": "#4b2447",
	}
	(document.data.get("settings", {}) as Dictionary)["mob_warning_limit"] = 4
	editor.call("_create_terrain_preset", "flat", "Dalle du prédateur", "poly_stone_floor", 0.0)
	_rename_selected("Sol du laboratoire theWolf")
	_build_central_hub()
	_build_mid_arena()
	_build_veteran_arena()

	document.data["name"] = ROOM_NAME
	(editor.get("world_name") as LineEdit).text = ROOM_NAME
	editor.call("_rebuild_preview")
	await process_frame
	var report := document.validation_report()
	if not bool(report.get("valid", false)):
		_fail("validation refusée : %s" % "; ".join(report.get("errors", []) as Array))
		return
	editor.call("_save_world")
	await process_frame
	var expected_path := "user://hoplite_worlds/laboratoire_de_thewolf.hoplite.json"
	if not FileAccess.file_exists(expected_path):
		_fail("sauvegarde absente : %s" % expected_path)
		return
	print("THE_WOLF_FORGE_ROOM_SAVED path=%s entities=%d mobs=%d warnings=%d" % [
		ProjectSettings.globalize_path(expected_path),
		document.entities().size(),
		int(report.get("mob_count", 0)),
		(report.get("warnings", []) as Array).size(),
	])
	quit(0)


func _build_central_hub() -> void:
	_place("Départ — choix du défi", "player_spawn", Vector3(0.0, 0.1, 31.0), {
		"radius": 1.0,
		"spawn_id": "laboratoire_entree",
	})
	_place("Instructions mobilité", "trigger", Vector3(0.0, 1.6, 27.0), _narrative_trigger(
		"MAÎTRE DE LA FORGE",
		"Les coups au sol usent lentement son armure. Dash, slide, double saut et frappe de wall-run brisent son instinct — puis frappe le cœur lunaire.",
		7.0
	))
	_surface("Mur extérieur ouest", Vector3(-39.0, 4.0, -2.0), Vector3(1.0, 8.0, 58.0), "rough_stone")
	_surface("Mur extérieur est", Vector3(39.0, 4.0, -2.0), Vector3(1.0, 8.0, 58.0), "rough_stone")
	_surface("Séparation centrale", Vector3(0.0, 4.0, -7.0), Vector3(1.0, 8.0, 44.0), "fortress")
	_surface("Fond ouest", Vector3(-20.0, 4.0, -30.0), Vector3(39.0, 8.0, 1.0), "fortress")
	_surface("Fond est", Vector3(20.0, 4.0, -30.0), Vector3(39.0, 8.0, 1.0), "fortress")
	# Façade avec deux passages de huit mètres, un par aile.
	_surface("Façade gauche extérieure", Vector3(-34.0, 4.0, 22.0), Vector3(10.0, 8.0, 1.0), "fortress")
	_surface("Façade gauche intérieure", Vector3(-7.0, 4.0, 22.0), Vector3(14.0, 8.0, 1.0), "fortress")
	_surface("Façade droite intérieure", Vector3(7.0, 4.0, 22.0), Vector3(14.0, 8.0, 1.0), "fortress")
	_surface("Façade droite extérieure", Vector3(34.0, 4.0, 22.0), Vector3(10.0, 8.0, 1.0), "fortress")
	_light("Balise Mid", Vector3(-20.0, 5.2, 24.0), "#ef493c", 4.2, 14.0)
	_light("Balise Veteran", Vector3(20.0, 5.2, 24.0), "#b88cff", 4.8, 15.0)


func _build_mid_arena() -> void:
	var trigger := _place("Entrée défi Mid", "trigger", Vector3(-20.0, 1.5, 18.0), {
		"size": [9.0, 3.0, 5.0],
		"condition": "player_enter", "condition_group": "", "threshold": 100.0,
		"action": "narrative", "action_target": "",
		"action_text": "MID — deux phases. Utilise les murs pour ouvrir le cœur lunaire.",
		"action_speaker": "THE WOLF", "action_duration": 4.5, "music_path": "", "once": true,
	})
	_enemy_group("theWolf — Mid", Vector3(-20.0, 0.1, -13.0), {
		"group_id": "thewolf_mid_test", "archetype": "the_wolf_mid", "count": 1, "rank": "miniboss",
		"spawn_condition": "trigger", "spawn_trigger": String(trigger.get("id", "")),
	})
	_place("Victoire Mid", "trigger", Vector3(-20.0, 1.5, -23.0), _death_narrative(
		"thewolf_mid_test", "MAÎTRE DE LA FORGE", "Le cœur Mid est brisé. Retourne au vestibule ou tente l'aile Veteran.", 5.0
	))
	# Deux longues lignes et des ruptures verticales pour wall-run / double saut.
	_surface("Mid — mur de course ouest", Vector3(-34.0, 3.6, -5.0), Vector3(1.0, 7.2, 34.0), "rough_stone")
	_surface("Mid — mur de course intérieur", Vector3(-6.0, 3.6, -5.0), Vector3(1.0, 7.2, 34.0), "rough_stone")
	_surface("Mid — plateforme ouest", Vector3(-31.0, 3.2, -5.0), Vector3(6.0, 0.5, 4.0), "white_marble_floor")
	_surface("Mid — plateforme intérieure", Vector3(-9.0, 4.1, -14.0), Vector3(6.0, 0.5, 4.0), "white_marble_floor")
	_surface("Mid — pilier avant", Vector3(-27.0, 3.5, 9.0), Vector3(2.2, 7.0, 2.2), "marble")
	_surface("Mid — pilier arrière", Vector3(-13.0, 3.5, -18.0), Vector3(2.2, 7.0, 2.2), "marble")
	_light("Mid — lune rouge", Vector3(-20.0, 6.0, -8.0), "#ef493c", 4.6, 22.0)


func _build_veteran_arena() -> void:
	var trigger := _place("Entrée défi Veteran", "trigger", Vector3(20.0, 1.5, 18.0), {
		"size": [9.0, 3.0, 5.0],
		"condition": "player_enter", "condition_group": "", "threshold": 100.0,
		"action": "narrative", "action_target": "",
		"action_text": "VETERAN — trois phases. La troisième chasse punit l'immobilité.",
		"action_speaker": "THE WOLF", "action_duration": 4.5, "music_path": "", "once": true,
	})
	_enemy_group("theWolf — Veteran", Vector3(20.0, 0.1, -13.0), {
		"group_id": "thewolf_veteran_test", "archetype": "the_wolf_veteran", "count": 1, "rank": "miniboss",
		"spawn_condition": "trigger", "spawn_trigger": String(trigger.get("id", "")),
	})
	_place("Victoire Veteran", "trigger", Vector3(20.0, 1.5, -23.0), _death_narrative(
		"thewolf_veteran_test", "MAÎTRE DE LA FORGE", "Fenrir tombe. Les trois phases et la rupture de mobilité sont validées.", 5.5
	))
	_surface("Veteran — mur de course est", Vector3(34.0, 4.0, -5.0), Vector3(1.0, 8.0, 34.0), "rough_stone")
	_surface("Veteran — mur de course intérieur", Vector3(6.0, 4.0, -5.0), Vector3(1.0, 8.0, 34.0), "rough_stone")
	_surface("Veteran — plateforme est", Vector3(31.0, 3.6, -2.0), Vector3(6.0, 0.5, 4.0), "white_marble_floor")
	_surface("Veteran — plateforme intérieure", Vector3(9.0, 4.6, -14.0), Vector3(6.0, 0.5, 4.0), "white_marble_floor")
	_surface("Veteran — pont aérien", Vector3(20.0, 5.2, -21.0), Vector3(12.0, 0.55, 3.0), "marble")
	_surface("Veteran — pilier avant est", Vector3(28.0, 4.0, 9.0), Vector3(2.4, 8.0, 2.4), "marble")
	_surface("Veteran — pilier avant intérieur", Vector3(12.0, 4.0, 9.0), Vector3(2.4, 8.0, 2.4), "marble")
	_surface("Veteran — pilier arrière", Vector3(20.0, 4.0, -17.0), Vector3(2.4, 8.0, 2.4), "marble")
	_light("Veteran — lune violette", Vector3(20.0, 7.0, -8.0), "#b88cff", 5.4, 24.0)


func _surface(label: String, position: Vector3, size: Vector3, material: String) -> Dictionary:
	editor.set("active_material", material)
	return _place(label, "surface", position, {
		"shape": "block",
		"size": [size.x, size.y, size.z],
		"material": material,
	})


func _light(label: String, position: Vector3, color: String, energy: float, light_range: float) -> Dictionary:
	return _place(label, "light", position, {
		"light_type": "omni", "color": color, "energy": energy,
		"range": light_range, "shadows": false,
	})


func _enemy_group(label: String, position: Vector3, overrides: Dictionary) -> Dictionary:
	var properties := {
		"group_id": "thewolf", "archetype": "the_wolf_mid", "count": 1,
		"rank": "miniboss", "size_multiplier": 1.0,
		"match_perfect_hitbox": false, "behavior": "normal", "route_id": "",
		"protect_target": "", "spawn_condition": "start", "spawn_trigger": "",
		"spawn_dead_group": "", "spawn_delay": 0.0, "deployment_mode": "all",
		"formation": "line", "performance_profile": "detailed",
	}
	properties.merge(overrides, true)
	var group := _place(label, "enemy_group", position, properties)
	editor.call("_set_property", group, "group_id", String(properties["group_id"]))
	return group


func _narrative_trigger(speaker: String, text: String, duration: float) -> Dictionary:
	return {
		"size": [14.0, 3.0, 4.0], "condition": "player_enter",
		"condition_group": "", "threshold": 100.0, "action": "narrative",
		"action_target": "", "action_text": text, "action_speaker": speaker,
		"action_duration": duration, "music_path": "", "once": true,
	}


func _death_narrative(group_id: String, speaker: String, text: String, duration: float) -> Dictionary:
	return {
		"size": [2.0, 2.0, 2.0], "condition": "group_dead",
		"condition_group": group_id, "threshold": 100.0, "action": "narrative",
		"action_target": "", "action_text": text, "action_speaker": speaker,
		"action_duration": duration, "music_path": "", "once": true,
	}


func _place(label: String, type: String, position: Vector3, properties: Dictionary) -> Dictionary:
	editor.call("_select_brush", label, type, properties)
	editor.call("_place_brush_at", position, true, Vector3.ZERO)
	var entity := document.find_entity(String(editor.get("selected_id")))
	if entity.is_empty():
		_fail("placement refusé : %s" % label)
		return {}
	editor.call("_set_entity_value", entity, "name", label)
	return entity


func _rename_selected(label: String) -> void:
	var entity := document.find_entity(String(editor.get("selected_id")))
	if not entity.is_empty():
		editor.call("_set_entity_value", entity, "name", label)


func _fail(message: String) -> void:
	push_error("THE_WOLF_FORGE_ROOM: " + message)
	quit(1)
