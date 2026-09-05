extends SceneTree

const SAVE_FILENAME := "le_serment_des_cendres.hoplite.json"
const PortalHubScript = preload("res://scripts/world_editor/world_portal_hub.gd")

var editor: Node
var document: HopliteWorldDocument


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_error := change_scene_to_file("res://world_editor.tscn")
	_check(scene_error == OK, "scene World Forge indisponible")
	await process_frame
	await process_frame
	editor = current_scene
	_check(editor != null, "éditeur indisponible")
	_load_saved_mission()
	document = editor.get("document") as HopliteWorldDocument
	_check(document != null, "document sauvegardé illisible")
	_check(String(document.data.get("name", "")) == "Le Serment des Cendres", "nom de mission incorrect")
	_check(document.chapters().size() == 2, "la mission doit avoir deux chapitres")
	var report := document.validation_report()
	_check(bool(report.get("valid", false)), "validation World Forge invalide")
	_check((report.get("warnings", []) as Array).is_empty(), "la mission conserve des avertissements")

	var chapters := document.chapters()
	var first_id := String((chapters[0] as Dictionary).get("id", ""))
	var second_id := String((chapters[1] as Dictionary).get("id", ""))
	await _probe_ash_gate(first_id)
	await _probe_titan_sanctuary(second_id)
	await _probe_lab_portal()
	print("WORLD_FORGE_MISSION_PROBE_OK chapters=2 entities=%d mobs=%d" % [document.entities().size(), int(report.get("mob_count", 0))])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _load_saved_mission() -> void:
	var picker := editor.get("save_picker") as OptionButton
	for index: int in range(picker.item_count):
		if String(picker.get_item_metadata(index)) == SAVE_FILENAME:
			picker.select(index)
			editor.call("_load_selected_world")
			return
	_fail("mission absente du sélecteur de sauvegardes")


func _probe_ash_gate(chapter_id: String) -> void:
	_switch_chapter(chapter_id)
	var first_gate := document.find_by_name("La Herse des Cendres")
	var exit_gate := document.find_by_name("La Porte du Sanctuaire")
	var scouts_trigger := document.find_by_name("Zone — embuscade des éclaireurs")
	_check(not first_gate.is_empty() and not exit_gate.is_empty() and not scouts_trigger.is_empty(), "logique du premier chapitre incomplète")

	editor.call("_start_test")
	await process_frame
	await process_frame
	_check(bool(editor.get("test_mode")), "F6 n'a pas démarré le premier chapitre")
	var runtime := editor.get("runtime") as HopliteWorldRuntime
	var events := editor.get("event_runtime") as HopliteWorldEventRuntime
	_check(runtime != null and runtime.player != null and events != null, "joueur ou runtime absent au premier chapitre")
	_check(runtime.living_count("eclaireurs_cendres") == 0, "les éclaireurs apparaissent avant leur zone")
	events.call("_on_player_entered_trigger", String(scouts_trigger.get("id", "")))
	await process_frame
	_check(runtime.living_count("eclaireurs_cendres") == 5, "la zone n'a pas généré les cinq éclaireurs")
	_kill_group(runtime, "eclaireurs_cendres")
	await process_frame
	_check(bool((runtime.nodes_by_id.get(String(first_gate.get("id", ""))) as Node).get_meta("door_open", false)), "la herse ne s'ouvre pas après les éclaireurs")
	_check(runtime.living_count("tireurs_estrades") == 4, "les tireurs ne prennent pas la relève")
	_kill_group(runtime, "tireurs_estrades")
	await process_frame
	_check(runtime.living_count("phalange_reserve") == 5, "la réserve n'active pas ses cinq soldats initiaux")
	_kill_group(runtime, "phalange_reserve")
	await process_frame
	# Crossing the threshold twice while the five initial soldiers die deploys
	# the four authored reservists in two reinforcement batches.
	_check(runtime.living_count("phalange_reserve") == 4, "la réserve progressive ne déploie pas ses quatre renforts")
	_kill_group(runtime, "phalange_reserve")
	await process_frame
	_check(bool((runtime.nodes_by_id.get(String(exit_gate.get("id", ""))) as Node).get_meta("door_open", false)), "la porte du sanctuaire ne s'ouvre pas")
	editor.call("_stop_test")
	await process_frame
	_check(not bool(editor.get("test_mode")), "le premier test F6 ne s'arrête pas")


func _probe_titan_sanctuary(chapter_id: String) -> void:
	_switch_chapter(chapter_id)
	var arena_trigger := document.find_by_name("Franchir le cercle sacré")
	var final_gate := document.find_by_name("Sceau du dernier brasier")
	var guard := document.find_by_name("Garde du Taxi arque")
	_check(not arena_trigger.is_empty() and not final_gate.is_empty() and not guard.is_empty(), "logique du sanctuaire incomplète")

	editor.call("_start_test")
	await process_frame
	await process_frame
	_check(bool(editor.get("test_mode")), "F6 n'a pas démarré le sanctuaire")
	var runtime := editor.get("runtime") as HopliteWorldRuntime
	var events := editor.get("event_runtime") as HopliteWorldEventRuntime
	_check(runtime != null and runtime.player != null and events != null, "joueur ou runtime absent au sanctuaire")
	events.call("_on_player_entered_trigger", String(arena_trigger.get("id", "")))
	await process_frame
	_check(runtime.living_count("cercle_lanciers") == 8, "le cercle des lanciers ne se forme pas")
	_kill_group(runtime, "cercle_lanciers")
	await process_frame
	_check(runtime.living_count("garde_taxiarque") == 2, "la première vague de gardes est incorrecte")
	_kill_group(runtime, "garde_taxiarque")
	events.call("_tick_deployment", String(guard.get("id", "")))
	await process_frame
	_check(runtime.living_count("garde_taxiarque") == 2, "la deuxième vague de gardes est incorrecte")
	_kill_group(runtime, "garde_taxiarque")
	events.call("_tick_deployment", String(guard.get("id", "")))
	await process_frame
	_check(runtime.living_count("garde_taxiarque") == 1, "la dernière garde n'arrive pas")
	_kill_group(runtime, "garde_taxiarque")
	await process_frame
	_check(runtime.living_count("titan_cendres") == 1, "le Titan n'apparaît pas après sa garde")
	_kill_group(runtime, "titan_cendres")
	await process_frame
	var gate_node := runtime.nodes_by_id.get(String(final_gate.get("id", ""))) as Node
	_check(gate_node != null and bool(gate_node.get_meta("door_open", false)), "le sceau final ne s'ouvre pas")
	var narrative_text := editor.get("narrative_text") as Label
	_check(narrative_text != null and "Serment des Cendres" in narrative_text.text, "la narration finale ne s'affiche pas")
	editor.call("_stop_test")
	await process_frame
	_check(not bool(editor.get("test_mode")), "le test final F6 ne s'arrête pas")


func _probe_lab_portal() -> void:
	var hub := PortalHubScript.new() as HopliteWorldPortalHub
	editor.add_child(hub)
	await process_frame
	var mission_visible := false
	for child: Node in hub.find_children("*", "Label3D", true, false):
		if "LE SERMENT DES CENDRES" in (child as Label3D).text:
			mission_visible = true
			break
	_check(mission_visible, "le portail de la mission n'apparaît pas dans le laboratoire")
	hub.queue_free()
	await process_frame


func _kill_group(runtime: HopliteWorldRuntime, group_id: String) -> void:
	var enemies := (runtime.enemies_by_group.get(group_id, []) as Array).duplicate()
	for enemy_raw: Variant in enemies:
		var enemy := enemy_raw as Node
		if enemy == null or not is_instance_valid(enemy) or bool(enemy.get("dead")):
			continue
		enemy.set("dead", true)
		enemy.emit_signal("died", enemy)


func _switch_chapter(chapter_id: String) -> void:
	var picker := editor.get("chapter_picker") as OptionButton
	for index: int in range(picker.item_count):
		if String(picker.get_item_metadata(index)) == chapter_id:
			picker.select(index)
			editor.call("_on_chapter_selected", index)
			return
	_fail("chapitre introuvable : %s" % chapter_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	push_error("WORLD_FORGE_MISSION_PROBE_FAILED %s" % message)
	quit(1)
