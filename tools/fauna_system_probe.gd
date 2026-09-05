extends SceneTree

const FaunaSettingsScript = preload("res://scripts/fauna/fauna_settings.gd")
const FaunaManagerScript = preload("res://scripts/fauna/fauna_manager.gd")
const AssetLibraryRoomScript = preload("res://scripts/environment/asset_library_room.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_settings_contract()
	_validate_imported_models()
	_validate_forge_catalog()
	await _validate_runtime_population()
	await _validate_settings_tab()
	if failures.is_empty():
		print("FAUNA_SYSTEM_PROBE: PASS — 13 espèces, imports animés, Forge, population et onglet FAUNE validés.")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAUNA_SYSTEM_PROBE: " + failure)
	quit(1)


func _validate_settings_contract() -> void:
	_check(FaunaSettingsScript.SPECIES.size() == 13, "La liste doit contenir exactement 13 espèces.")
	var defaults: Dictionary = FaunaSettingsScript.defaults()
	var targets: Dictionary = FaunaSettingsScript.target_counts(defaults)
	var total := 0
	for raw_count: Variant in targets.values():
		total += int(raw_count)
	_check(total <= int(defaults[&"budget"]), "Le budget global n'est pas respecté.")
	var eagle_count := 0
	var ultimate_count := 0
	for definition: Dictionary in FaunaSettingsScript.SPECIES:
		var path := String(definition["model_path"])
		if path.contains("quaternius_eagle"):
			eagle_count += 1
			_check(is_zero_approx(float(definition.get("visual_yaw_degrees", 180.0))), "L'aigle doit conserver l'axe avant natif du petit pack.")
		elif path.contains("quaternius_ultimate_animated_animals"):
			ultimate_count += 1
	_check(eagle_count == 1, "Le petit pack doit exposer uniquement l'aigle.")
	_check(ultimate_count == 12, "Le pack Ultimate doit exposer ses 12 animaux.")


func _validate_imported_models() -> void:
	for definition: Dictionary in FaunaSettingsScript.SPECIES:
		var species_id := StringName(definition["id"])
		var path := String(definition["model_path"])
		_check(ResourceLoader.exists(path), "%s : ressource importée introuvable." % path)
		var packed := load(path) as PackedScene
		_check(packed != null, "%s : le modèle n'est pas une scène instanciable." % path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		var mesh_count := instance.find_children("*", "MeshInstance3D", true, false).size()
		var animation_players := instance.find_children("*", "AnimationPlayer", true, false)
		_check(mesh_count > 0, "%s : aucun mesh importé." % String(species_id))
		_check(not animation_players.is_empty(), "%s : aucun AnimationPlayer importé." % String(species_id))
		var expected := "flying" if species_id == &"eagle" else "idle"
		var found_expected := false
		var animation_count := 0
		for raw_player: Node in animation_players:
			var animation_player := raw_player as AnimationPlayer
			animation_count += animation_player.get_animation_list().size()
			for animation_name: StringName in animation_player.get_animation_list():
				var normalized := String(animation_name).to_lower()
				if normalized == expected or normalized.ends_with("|" + expected) or normalized.ends_with("/" + expected):
					found_expected = true
		_check(animation_count >= 2, "%s : animations insuffisantes." % String(species_id))
		_check(found_expected, "%s : animation %s absente." % [String(species_id), expected])
		instance.free()


func _validate_forge_catalog() -> void:
	var library := AssetLibraryRoomScript.new() as HopliteAssetLibraryRoom
	var fauna_entries: Array[Dictionary] = []
	for entry: Dictionary in library._scan_catalog():
		if StringName(entry["category"]) == &"fauna":
			fauna_entries.append(entry)
	_check(fauna_entries.size() == 13, "La Forge doit cataloguer les 13 modèles de faune.")
	for entry: Dictionary in fauna_entries:
		_check(not bool(entry["collision_enabled"]), "%s : collision Forge activée par défaut." % String(entry["display_name"]))
		_check(StringName(entry["subcategory"]) == &"animals", "%s : sous-catégorie Forge incorrecte." % String(entry["display_name"]))
	library.free()


func _validate_runtime_population() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player := Node3D.new()
	scene.add_child(player)
	var manager := FaunaManagerScript.new() as HopliteFaunaManager
	scene.add_child(manager)
	manager.configure(player)
	await process_frame
	var values: Dictionary = FaunaSettingsScript.defaults()
	values[&"budget"] = 2
	for definition: Dictionary in FaunaSettingsScript.SPECIES:
		var species_id := StringName(definition["id"])
		values[FaunaSettingsScript.species_key(species_id, "count")] = 0
	values[FaunaSettingsScript.species_key(&"cow", "count")] = 1
	values[FaunaSettingsScript.species_key(&"eagle", "count")] = 1
	values[FaunaSettingsScript.species_key(&"cow", "behavior")] = 3
	manager.reload_fauna_settings(values)
	for _index: int in range(4):
		manager._physics_process(0.2)
	_check(manager.get_total_active() == 2, "Le gestionnaire n'a pas créé la population cible de 2 animaux.")
	var counts: Dictionary = manager.get_active_counts()
	_check(int(counts.get(&"cow", 0)) == 1 and int(counts.get(&"eagle", 0)) == 1, "Le spawn par espèce ne respecte pas la cible.")
	var cow_agents: Array = manager._valid_agents(&"cow")
	if not cow_agents.is_empty():
		_check((cow_agents[0] as HopliteFaunaAgent).behavior_id == &"territorial", "Le comportement par espèce n'est pas appliqué.")
	scene.queue_free()
	await process_frame


func _validate_settings_tab() -> void:
	var settings := AudioSettingsScript.new() as HopliteAudioSettings
	root.add_child(settings)
	await process_frame
	_check(settings.tabs != null, "Le menu Paramètres n'a pas construit son TabContainer.")
	if settings.tabs != null:
		_check(settings.tabs.get_node_or_null("FAUNE") != null, "L'onglet FAUNE est absent des Paramètres.")
	_check(settings.fauna_species_toggles.size() == 13, "L'onglet FAUNE ne propose pas les 13 espèces.")
	settings.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
