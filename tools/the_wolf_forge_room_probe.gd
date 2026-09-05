extends SceneTree

const SAVE_FILENAME := "laboratoire_de_thewolf.hoplite.json"
const WolfBossScript = preload("res://scripts/bosses/wolf_boss.gd")

var editor: Node
var document: HopliteWorldDocument


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(change_scene_to_file("res://world_editor.tscn") == OK, "scene World Forge indisponible")
	await process_frame
	await process_frame
	editor = current_scene
	_check(editor != null, "éditeur World Forge indisponible")
	_check(_library_contains(4, "the wolf — mid") and _library_contains(4, "the wolf — veteran"), "les deux boss sont absents de Personnages")
	_check(_library_contains(3, "wolf"), "le modèle Wolf animé est absent de Modèles 3D")
	_load_saved_room()
	document = editor.get("document") as HopliteWorldDocument
	_check(document != null, "document du laboratoire illisible")
	_check(String(document.data.get("name", "")) == "Laboratoire de theWolf", "nom du laboratoire incorrect")
	var report := document.validation_report()
	_check(bool(report.get("valid", false)), "validation du laboratoire invalide")
	_check((report.get("warnings", []) as Array).is_empty(), "le laboratoire conserve des avertissements")
	_check(int(report.get("mob_count", 0)) == 2, "le laboratoire ne déclare pas exactement les deux variantes")
	_check(not document.find_by_name("Veteran — pont aérien").is_empty(), "pont aérien Veteran absent")
	_check(not document.find_by_name("Mid — mur de course ouest").is_empty(), "route de wall-run Mid absente")

	editor.call("_start_test")
	await process_frame
	await process_frame
	_check(bool(editor.get("test_mode")), "le test Forge du laboratoire ne démarre pas")
	var runtime := editor.get("runtime") as HopliteWorldRuntime
	var events := editor.get("event_runtime") as HopliteWorldEventRuntime
	_check(runtime != null and runtime.player != null and events != null, "runtime, joueur ou événements absents")
	_check(runtime.living_count("thewolf_mid_test") == 0, "Mid apparaît avant son entrée")
	_check(runtime.living_count("thewolf_veteran_test") == 0, "Veteran apparaît avant son entrée")
	await _trigger_and_verify(runtime, events, "Entrée défi Mid", "thewolf_mid_test", false)
	await _trigger_and_verify(runtime, events, "Entrée défi Veteran", "thewolf_veteran_test", true)
	editor.call("_stop_test")
	await process_frame
	_check(not bool(editor.get("test_mode")), "le test Forge du laboratoire ne s'arrête pas")
	print("THE_WOLF_FORGE_ROOM_PROBE PASS entities=%d mobs=2 triggers=true mid=true veteran=true mobility_geometry=true" % document.entities().size())
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _load_saved_room() -> void:
	var picker := editor.get("save_picker") as OptionButton
	for index: int in range(picker.item_count):
		if String(picker.get_item_metadata(index)) == SAVE_FILENAME:
			picker.select(index)
			editor.call("_load_selected_world")
			return
	_fail("laboratoire absent du sélecteur de sauvegardes")


func _library_contains(category_index: int, text_fragment: String) -> bool:
	var picker := editor.get("library_category") as OptionButton
	picker.select(category_index)
	editor.call("_refresh_library")
	var wanted := text_fragment.to_lower()
	for candidate: Node in editor.find_children("*", "Button", true, false):
		if wanted in (candidate as Button).text.to_lower():
			return true
	return false


func _trigger_and_verify(runtime: HopliteWorldRuntime, events: HopliteWorldEventRuntime, trigger_name: String, group_id: String, veteran: bool) -> void:
	var trigger := document.find_by_name(trigger_name)
	_check(not trigger.is_empty(), "déclencheur absent : %s" % trigger_name)
	events.call("_on_player_entered_trigger", String(trigger.get("id", "")))
	await process_frame
	await physics_frame
	_check(runtime.living_count(group_id) == 1, "%s ne génère pas exactement un boss" % trigger_name)
	var group: Array = runtime.enemies_by_group.get(group_id, []) as Array
	_check(group.size() == 1, "groupe runtime incorrect : %s" % group_id)
	var boss := group[0] as Node if not group.is_empty() else null
	_check(boss != null and boss.get_script() == WolfBossScript, "%s n'utilise pas le contrôleur theWolf" % trigger_name)
	if boss != null:
		_check(bool(boss.get("veteran_mode")) == veteran, "%s charge le mauvais mode" % trigger_name)
		boss.call("set_ai_participation", false)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	push_error("THE_WOLF_FORGE_ROOM_PROBE_FAILED " + message)
	quit(1)
