extends SceneTree

# This is an authoring driver, not a runtime level generator. It opens the real
# World Forge scene and uses its own authoring commands, brushes, validation and
# atomic save path so the resulting mission is identical to a hand-authored map.

const MISSION_NAME := "Le Serment des Cendres"

var editor: Node
var document: HopliteWorldDocument
var first_chapter_id := ""
var second_chapter_id := ""
var placed_assets: Array[String] = []
var missing_assets: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_error := change_scene_to_file("res://world_editor.tscn")
	if scene_error != OK:
		_fail("scene World Forge indisponible (%s)" % error_string(scene_error))
		return
	await process_frame
	await process_frame
	editor = current_scene
	if editor == null or not editor.has_method("_place_brush_at"):
		_fail("World Forge n'a pas expose ses outils d'authoring")
		return

	editor.call("_new_world")
	await process_frame
	document = editor.get("document") as HopliteWorldDocument
	if document == null:
		_fail("document World Forge indisponible")
		return

	(editor.get("world_name") as LineEdit).text = MISSION_NAME
	document.data["atmosphere"] = {
		"preset": "Siege enfume",
		"sun_energy": 0.72,
		"ambient_energy": 0.46,
		"fog_density": 0.018,
		"sky_top": "#171d2b",
		"sky_horizon": "#b35f45",
	}
	(document.data.get("settings", {}) as Dictionary)["mob_warning_limit"] = 36
	first_chapter_id = document.start_chapter()
	_rename_active_chapter("I — La Porte des Cendres")
	_build_ash_gate()

	editor.call("_add_chapter")
	await process_frame
	second_chapter_id = String(editor.get("active_chapter_id"))
	_rename_active_chapter("II — Le Sanctuaire du Titan")
	_build_titan_sanctuary()

	_switch_chapter(first_chapter_id)
	_place("Passage vers le sanctuaire", "chapter_portal", Vector3(0.0, 1.5, -28.0), {
		"size": [4.0, 3.0, 1.5],
		"destination_chapter": second_chapter_id,
		"destination_spawn": "sanctuaire_entree",
		"label": "SANCTUAIRE DU TITAN",
	})

	editor.call("_rebuild_preview")
	await process_frame
	var report := document.validation_report()
	if not bool(report.get("valid", false)):
		_fail("validation refusee : %s" % "; ".join(report.get("errors", []) as Array))
		return

	# Placements intentionally dirty the document and World Forge refreshes the
	# title field from the authoritative document name. Commit the requested name
	# after authoring, exactly as an author would before pressing Ctrl+S.
	document.data["name"] = MISSION_NAME
	(editor.get("world_name") as LineEdit).text = MISSION_NAME
	editor.call("_save_world")
	await process_frame
	var expected_path := "user://hoplite_worlds/%s.hoplite.json" % _slug(MISSION_NAME)
	if not FileAccess.file_exists(expected_path):
		_fail("la sauvegarde World Forge n'existe pas : %s" % expected_path)
		return

	print("WORLD_FORGE_MISSION_SAVED path=%s entities=%d mobs=%d warnings=%d" % [
		ProjectSettings.globalize_path(expected_path),
		document.entities().size(),
		int(report.get("mob_count", 0)),
		(report.get("warnings", []) as Array).size(),
	])
	print("WORLD_FORGE_MISSION_CHAPTERS first=%s second=%s assets=%s missing=%s" % [
		first_chapter_id,
		second_chapter_id,
		", ".join(placed_assets),
		", ".join(missing_assets),
	])
	for warning: Variant in report.get("warnings", []) as Array:
		print("WORLD_FORGE_MISSION_WARNING %s" % String(warning))
	quit(0)


func _build_ash_gate() -> void:
	editor.call("_create_terrain_preset", "flat", "Plaine des cendres", "scorched_ground", 0.0)
	_rename_selected("Sol calciné de la passe")
	_place("Départ — lignes hoplites", "player_spawn", Vector3(0.0, 0.1, 27.0), {
		"radius": 1.0,
		"spawn_id": "lignes_hoplites",
	})

	# A readable combat corridor with two arenas, hard side limits and gates.
	_surface("Muraille ouest", Vector3(-16.0, 2.5, 1.0), Vector3(1.0, 5.0, 58.0), "fortress")
	_surface("Muraille est", Vector3(16.0, 2.5, 1.0), Vector3(1.0, 5.0, 58.0), "fortress")
	_surface("Rempart d'entrée", Vector3(-10.0, 2.5, 30.0), Vector3(12.0, 5.0, 1.0), "fortress")
	_surface("Rempart d'entrée", Vector3(10.0, 2.5, 30.0), Vector3(12.0, 5.0, 1.0), "fortress")
	_surface("Traverse de la herse ouest", Vector3(-10.5, 2.5, 5.0), Vector3(11.0, 5.0, 1.0), "rough_stone")
	_surface("Traverse de la herse est", Vector3(10.5, 2.5, 5.0), Vector3(11.0, 5.0, 1.0), "rough_stone")
	_surface("Dernier rempart ouest", Vector3(-10.0, 2.5, -24.0), Vector3(12.0, 5.0, 1.0), "fortress")
	_surface("Dernier rempart est", Vector3(10.0, 2.5, -24.0), Vector3(12.0, 5.0, 1.0), "fortress")
	_surface("Estrade ouest", Vector3(-11.0, 0.6, -10.0), Vector3(7.0, 1.2, 10.0), "rough_stone")
	_surface("Estrade est", Vector3(11.0, 0.6, -10.0), Vector3(7.0, 1.2, 10.0), "rough_stone")

	var first_gate := _place("La Herse des Cendres", "door", Vector3(0.0, 2.5, 5.0), {
		"size": [10.0, 5.0, 0.6],
		"door_style": "iron",
		"open_motion": "vertical",
		"open_duration": 1.5,
		"starts_open": false,
	})
	var exit_gate := _place("La Porte du Sanctuaire", "door", Vector3(0.0, 2.5, -24.0), {
		"size": [8.0, 5.0, 0.7],
		"door_style": "bronze",
		"open_motion": "pivot_right",
		"open_duration": 1.3,
		"starts_open": false,
	})

	_place("Entrée dans la passe", "atmosphere_zone", Vector3(0.0, 3.0, 18.0), {
		"size": [30.0, 6.0, 22.0],
		"preset": "Siege enfume",
		"sun_energy": 0.62,
		"ambient_energy": 0.40,
		"fog_density": 0.028,
	})
	_place("Ordre de percée", "trigger", Vector3(0.0, 1.5, 23.0), _narrative_trigger(
		"THERON",
		"La fumée nous couvre. Brise leurs éclaireurs, lève la herse et ne laisse aucun renfort atteindre le sanctuaire.",
		5.5
	))
	_place("Musique de la percée", "trigger", Vector3(0.0, 1.5, 21.0), {
		"size": [12.0, 3.0, 3.0], "condition": "player_enter", "condition_group": "", "threshold": 100.0,
		"action": "music", "action_target": "", "music_path": "res://audio/track/Ripped Crown Run.mp3", "music_volume": -5.0, "once": true,
	})

	var scouts_trigger := _place("Zone — embuscade des éclaireurs", "trigger", Vector3(0.0, 1.5, 17.0), {
		"size": [20.0, 3.0, 5.0], "condition": "player_enter", "condition_group": "", "threshold": 100.0,
		"action": "narrative", "action_target": "", "action_text": "Boucliers hauts ! Ils sortent des cendres !", "action_speaker": "THERON", "action_duration": 3.0, "once": true,
	})
	_enemy_group("Éclaireurs de la passe", Vector3(0.0, 0.1, 12.5), {
		"group_id": "eclaireurs_cendres", "archetype": "nathenian1", "count": 5, "rank": "normal",
		"behavior": "normal", "formation": "arc", "spawn_condition": "trigger", "spawn_trigger": String(scouts_trigger.get("id", "")), "deployment_mode": "all",
	})
	_enemy_group("Tireurs des estrades", Vector3(0.0, 1.3, -8.0), {
		"group_id": "tireurs_estrades", "archetype": "nsbire2", "count": 4, "rank": "normal",
		"behavior": "protect", "protect_target": String(first_gate.get("id", "")), "formation": "line", "spawn_condition": "group_dead", "spawn_dead_group": "eclaireurs_cendres", "deployment_mode": "all",
	})
	_enemy_group("Phalange de réserve", Vector3(0.0, 0.1, -14.0), {
		"group_id": "phalange_reserve", "archetype": "ngeneral", "count": 9, "rank": "normal",
		"composition": [{"archetype": "ngeneral", "count": 7}, {"archetype": "ngeneral_veteran", "count": 2}],
		"behavior": "normal", "formation": "phalanx", "spawn_condition": "group_dead", "spawn_dead_group": "tireurs_estrades",
		"deployment_mode": "reserve", "initial_active": 5, "reinforce_threshold": 3, "reinforce_amount": 2,
	})

	_place("Lever la herse", "trigger", Vector3(0.0, 1.5, 7.0), _death_action("eclaireurs_cendres", "open_door", String(first_gate.get("id", ""))))
	_place("Annonce de la seconde ligne", "trigger", Vector3(0.0, 1.5, 6.0), _death_narrative(
		"eclaireurs_cendres", "THERON", "La herse cède. Leur seconde ligne se replie vers les archers — pousse maintenant !", 4.0
	))
	_place("Ouvrir la porte du sanctuaire", "trigger", Vector3(0.0, 1.5, -21.0), _death_action("phalange_reserve", "open_door", String(exit_gate.get("id", ""))))
	_place("Victoire dans la passe", "trigger", Vector3(0.0, 1.5, -20.0), _death_narrative(
		"phalange_reserve", "THERON", "La passe est nôtre. Au-delà de cette porte, leur champion garde le dernier brasier.", 5.0
	))

	_light("Brasier d'entrée ouest", Vector3(-7.0, 4.0, 24.0), "#ff7a3d", 3.2, 13.0)
	_light("Brasier d'entrée est", Vector3(7.0, 4.0, 24.0), "#ff7a3d", 3.2, 13.0)
	_light("Feu de la herse", Vector3(0.0, 5.0, 4.0), "#e65d35", 4.0, 18.0)
	_light("Lueur du sanctuaire", Vector3(0.0, 5.5, -22.0), "#c9a3ff", 3.5, 16.0)

	_asset("shield_barricade_straight_LOD0", "Barricade de boucliers ouest", Vector3(-8.0, 0.0, 10.0), Vector3(0.0, 18.0, 0.0))
	_asset("shield_barricade_straight_LOD0", "Barricade de boucliers est", Vector3(8.0, 0.0, 10.0), Vector3(0.0, -18.0, 0.0))
	_asset("fallen_column_walkable_LOD0", "Colonne abattue", Vector3(-9.0, 0.0, -17.0), Vector3(0.0, 32.0, 0.0))
	_asset("Rock_Medium_1", "Rocher de la brèche", Vector3(12.5, 0.0, 20.0), Vector3(0.0, 55.0, 0.0))


func _build_titan_sanctuary() -> void:
	editor.call("_create_terrain_preset", "flat", "Dalle sacrée", "bone_gravel", 0.0)
	_rename_selected("Dalle noire du sanctuaire")
	_place("Arrivée — sanctuaire", "player_spawn", Vector3(0.0, 0.1, 27.0), {
		"radius": 1.0,
		"spawn_id": "sanctuaire_entree",
	})

	_surface("Mur sacré ouest", Vector3(-19.0, 3.0, 0.0), Vector3(1.0, 6.0, 60.0), "rough_stone")
	_surface("Mur sacré est", Vector3(19.0, 3.0, 0.0), Vector3(1.0, 6.0, 60.0), "rough_stone")
	_surface("Mur du fond ouest", Vector3(-12.0, 3.0, -28.0), Vector3(14.0, 6.0, 1.0), "fortress")
	_surface("Mur du fond est", Vector3(12.0, 3.0, -28.0), Vector3(14.0, 6.0, 1.0), "fortress")
	_surface("Pilier ouest avant", Vector3(-13.0, 3.0, 10.0), Vector3(3.0, 6.0, 3.0), "marble")
	_surface("Pilier est avant", Vector3(13.0, 3.0, 10.0), Vector3(3.0, 6.0, 3.0), "marble")
	_surface("Pilier ouest arrière", Vector3(-13.0, 3.0, -10.0), Vector3(3.0, 6.0, 3.0), "marble")
	_surface("Pilier est arrière", Vector3(13.0, 3.0, -10.0), Vector3(3.0, 6.0, 3.0), "marble")
	_surface("Autel du brasier", Vector3(0.0, 1.0, -22.0), Vector3(9.0, 2.0, 6.0), "marble")

	var final_gate := _place("Sceau du dernier brasier", "door", Vector3(0.0, 3.0, -28.0), {
		"size": [10.0, 6.0, 0.8], "door_style": "stone", "open_motion": "slide_left", "open_duration": 2.0, "starts_open": false,
	})
	_place("Nuit du sanctuaire", "atmosphere_zone", Vector3(0.0, 3.5, 4.0), {
		"size": [36.0, 7.0, 58.0], "preset": "Nuit sacree", "sun_energy": 0.16, "ambient_energy": 0.25, "fog_density": 0.022,
	})
	var arena_trigger := _place("Franchir le cercle sacré", "trigger", Vector3(0.0, 1.5, 17.0), _narrative_trigger(
		"LE TAXIARQUE", "Tu as traversé mes lignes pour voler notre flamme. Entre donc : le Titan décidera à qui appartient l'aube.", 5.5
	))
	_enemy_group("Cercle des lanciers", Vector3(0.0, 0.1, 4.0), {
		"group_id": "cercle_lanciers", "archetype": "ngeneral", "count": 8, "rank": "normal",
		"composition": [{"archetype": "ngeneral", "count": 6}, {"archetype": "ngeneral_veteran", "count": 2}],
		"behavior": "normal", "formation": "circle", "spawn_condition": "trigger", "spawn_trigger": String(arena_trigger.get("id", "")), "deployment_mode": "all",
	})
	_enemy_group("Garde du Taxi arque", Vector3(0.0, 0.1, -6.0), {
		"group_id": "garde_taxiarque", "archetype": "ncenturion", "count": 5, "rank": "normal",
		"behavior": "protect", "protect_target": String(final_gate.get("id", "")), "formation": "wedge", "spawn_condition": "group_dead", "spawn_dead_group": "cercle_lanciers",
		"deployment_mode": "waves", "wave_size": 2, "wave_interval": 4.5, "deployment_stop_mode": "total",
	})
	_enemy_group("Le Titan aux Cendres", Vector3(0.0, 0.1, -15.0), {
		"group_id": "titan_cendres", "archetype": "giant_veteran", "count": 1, "rank": "boss", "size_multiplier": 1.0,
		"match_perfect_hitbox": true, "giant_traversal_mode": "assisted", "giant_walkable_tops": true,
		"behavior": "protect", "protect_target": String(final_gate.get("id", "")), "formation": "line", "spawn_condition": "group_dead", "spawn_dead_group": "garde_taxiarque", "deployment_mode": "all",
	})

	_place("Défi du Titan", "trigger", Vector3(0.0, 1.5, -2.0), _death_narrative(
		"cercle_lanciers", "LE TAXIARQUE", "Le cercle est rompu. Gardes, gagnez le temps nécessaire — réveillez le Titan !", 4.5
	))
	_place("Réveil du Titan", "trigger", Vector3(0.0, 1.5, -9.0), _death_narrative(
		"garde_taxiarque", "LE TITAN", "PETIT BOUCLIER. PETITE FLAMME. VIENS.", 4.0
	))
	_place("Briser le sceau", "trigger", Vector3(0.0, 1.5, -19.0), _death_action("titan_cendres", "open_door", String(final_gate.get("id", ""))))
	_place("Serment accompli", "trigger", Vector3(0.0, 1.5, -20.0), _death_narrative(
		"titan_cendres", "THERON", "Le Titan tombe. La flamme est libre. Le Serment des Cendres est accompli.", 6.0
	))

	_light("Flamme bleue ouest", Vector3(-11.0, 5.0, 11.0), "#6f91ff", 3.6, 15.0)
	_light("Flamme bleue est", Vector3(11.0, 5.0, 11.0), "#6f91ff", 3.6, 15.0)
	_light("Halo du Titan", Vector3(0.0, 7.0, -14.0), "#ff5f46", 5.0, 20.0)
	_light("Dernier brasier", Vector3(0.0, 6.0, -24.0), "#f3c45c", 5.5, 18.0)
	_asset("fire_grate_floor_LOD0", "Grille ardente ouest", Vector3(-8.0, 0.0, -2.0), Vector3.ZERO)
	_asset("fire_grate_floor_LOD0", "Grille ardente est", Vector3(8.0, 0.0, -2.0), Vector3.ZERO)
	_asset("falling_column_LOD0", "Colonne fissurée ouest", Vector3(-15.0, 0.0, -18.0), Vector3(0.0, 20.0, 0.0))
	_asset("falling_column_LOD0", "Colonne fissurée est", Vector3(15.0, 0.0, -18.0), Vector3(0.0, -20.0, 0.0))

	# A return portal makes the authored world traversable in both directions.
	_place("Retour aux lignes", "chapter_portal", Vector3(0.0, 1.5, -31.0), {
		"size": [4.0, 3.0, 1.5], "destination_chapter": first_chapter_id, "destination_spawn": "lignes_hoplites", "label": "RETOUR AUX LIGNES",
	})


func _surface(label: String, position: Vector3, size: Vector3, material: String) -> Dictionary:
	editor.set("active_material", material)
	return _place(label, "surface", position, {"shape": "block", "size": [size.x, size.y, size.z], "material": material})


func _light(label: String, position: Vector3, color: String, energy: float, light_range: float) -> Dictionary:
	return _place(label, "light", position, {
		"light_type": "omni", "color": color, "energy": energy, "range": light_range, "shadows": false,
	})


func _enemy_group(label: String, position: Vector3, overrides: Dictionary) -> Dictionary:
	var properties := {
		"group_id": "groupe", "archetype": "nathenian1", "count": 1, "rank": "normal", "size_multiplier": 1.0,
		"match_perfect_hitbox": false, "giant_traversal_mode": "assisted", "giant_capsule_radius_multiplier": 0.90,
		"giant_capsule_height_multiplier": 1.0, "giant_walkable_tops": true, "behavior": "normal", "route_id": "", "protect_target": "",
		"spawn_condition": "start", "spawn_trigger": "", "spawn_dead_group": "", "spawn_delay": 3.0,
		"deployment_mode": "all", "formation": "line", "performance_profile": "auto",
	}
	properties.merge(overrides, true)
	var group := _place(label, "enemy_group", position, properties)
	# World Forge gives every brush stroke a unique group id; the Inspector then
	# lets the author replace it with a readable reference used by mission logic.
	_set_property(group, "group_id", String(overrides.get("group_id", properties["group_id"])))
	return group


func _asset(path_fragment: String, label: String, position: Vector3, rotation: Vector3) -> Dictionary:
	var entries := editor.get("automatic_assets") as Array[Dictionary]
	for entry: Dictionary in entries:
		var path := String(entry.get("path", ""))
		if path_fragment.to_lower() not in path.to_lower():
			continue
		editor.call("_select_asset_brush", entry)
		editor.call("_place_brush_at", position, true, rotation)
		var entity := document.find_entity(String(editor.get("selected_id")))
		if not entity.is_empty():
			_set_entity_value(entity, "name", label)
			placed_assets.append(path_fragment)
		return entity
	missing_assets.append(path_fragment)
	return {}


func _place(label: String, type: String, position: Vector3, properties: Dictionary, rotation: Vector3 = Vector3.ZERO) -> Dictionary:
	editor.call("_select_brush", label, type, properties)
	editor.call("_place_brush_at", position, true, rotation)
	var entity := document.find_entity(String(editor.get("selected_id")))
	if entity.is_empty():
		_fail("placement refuse par la Forge : %s" % label)
		return {}
	_set_entity_value(entity, "name", label)
	return entity


func _rename_selected(label: String) -> void:
	var entity := document.find_entity(String(editor.get("selected_id")))
	if not entity.is_empty():
		_set_entity_value(entity, "name", label)


func _set_entity_value(entity: Dictionary, key: String, value: Variant) -> void:
	editor.call("_set_entity_value", entity, key, value)


func _set_property(entity: Dictionary, key: String, value: Variant) -> void:
	editor.call("_set_property", entity, key, value)


func _rename_active_chapter(label: String) -> void:
	var edit := editor.get("chapter_name_edit") as LineEdit
	edit.text = label
	editor.call("_rename_current_chapter")


func _switch_chapter(chapter_id: String) -> void:
	var picker := editor.get("chapter_picker") as OptionButton
	for index: int in range(picker.item_count):
		if String(picker.get_item_metadata(index)) == chapter_id:
			picker.select(index)
			editor.call("_on_chapter_selected", index)
			return
	_fail("chapitre introuvable : %s" % chapter_id)


func _narrative_trigger(speaker: String, text: String, duration: float) -> Dictionary:
	return {
		"size": [12.0, 3.0, 4.0], "condition": "player_enter", "condition_group": "", "threshold": 100.0,
		"action": "narrative", "action_target": "", "action_text": text, "action_speaker": speaker, "action_duration": duration, "once": true,
	}


func _death_action(group_id: String, action: String, target: String) -> Dictionary:
	return {
		"size": [1.0, 1.0, 1.0], "condition": "group_dead", "condition_group": group_id, "threshold": 100.0,
		"action": action, "action_target": target, "action_text": "", "action_speaker": "Narrateur", "action_duration": 4.0, "once": true,
	}


func _death_narrative(group_id: String, speaker: String, text: String, duration: float) -> Dictionary:
	return {
		"size": [1.0, 1.0, 1.0], "condition": "group_dead", "condition_group": group_id, "threshold": 100.0,
		"action": "narrative", "action_target": "", "action_text": text, "action_speaker": speaker, "action_duration": duration, "once": true,
	}


func _slug(value: String) -> String:
	return String(editor.call("_slug", value))


func _fail(message: String) -> void:
	push_error("WORLD_FORGE_MISSION_FAILED %s" % message)
	quit(1)
