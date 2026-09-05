extends SceneTree

const PortalHubScript = preload("res://scripts/world_editor/world_portal_hub.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene_error := change_scene_to_file("res://lobby.tscn")
	_check(scene_error == OK, "la scene lobby ne charge pas")
	await scene_changed
	await process_frame
	await process_frame
	var lobby := current_scene as HopliteWorldLobby
	_check(lobby != null, "le script de lobby est absent")
	_check(lobby.document != null and lobby.runtime != null and lobby.runtime.player != null, "le monde Forge lobbyy ou son joueur ne charge pas")
	_check(lobby.portal_hub != null, "le hub du lobby est absent")
	_check(String(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://lobby.tscn", "le lobby n'est pas la scene de demarrage")

	var role_counts := {"world_editor": 0, "official_campaign": 0, "saved_worlds_anchor": 0}
	var campaign_ids: Array[String] = []
	for entity: Dictionary in lobby.document.entities_for_chapter(lobby.document.start_chapter()):
		var properties := entity.get("properties", {}) as Dictionary
		var role := String(properties.get("portal_role", ""))
		if role_counts.has(role):
			role_counts[role] = int(role_counts[role]) + 1
			var runtime_node := lobby.runtime.nodes_by_id.get(String(entity.get("id", ""))) as Node3D
			_check(runtime_node != null, "un prop de portail n'a pas ete construit : %s" % String(entity.get("name", "?")))
			_check(runtime_node.get_node_or_null("PortalInteraction") is Area3D, "un portail auteur n'a pas de zone interactive : %s" % String(entity.get("name", "?")))
		if role == "official_campaign":
			campaign_ids.append(String(properties.get("campaign_id", "")))
	_check(int(role_counts["world_editor"]) == 1, "le portail Forge auteur doit etre unique")
	_check(int(role_counts["official_campaign"]) == 3, "trois portails Campagne auteurs sont requis")
	_check(int(role_counts["saved_worlds_anchor"]) == 1, "la zone Stand/mondes doit avoir une ancre unique")
	for expected: String in ["grand_siege", "procedural_campaign", "last_flame"]:
		_check(campaign_ids.has(expected), "campagne non affectee : %s" % expected)

	var expected_world_count := 0
	for filename: String in DirAccess.get_files_at("user://hoplite_worlds"):
		if filename.ends_with(".hoplite.json") and filename.naturalnocasecmp_to("lobbyy.hoplite.json") != 0:
			expected_world_count += 1
	expected_world_count = mini(expected_world_count, PortalHubScript.MAX_WORLD_PORTALS)
	var generated_world_count := 0
	for child: Node in lobby.portal_hub.get_children():
		if child.name.begins_with("SavedWorldPortal_"):
			generated_world_count += 1
	_check(generated_world_count == expected_world_count, "le catalogue dynamique ne correspond pas aux sauvegardes : %d/%d" % [generated_world_count, expected_world_count])

	var lab_return := PortalHubScript.new() as HopliteWorldPortalHub
	lab_return.configure_lab_return()
	lobby.add_child(lab_return)
	await process_frame
	var return_label_found := false
	for label_raw: Node in lab_return.find_children("*", "Label3D", true, false):
		if "RETOUR AU LOBBY" in (label_raw as Label3D).text:
			return_label_found = true
			break
	_check(return_label_found, "le stand n'a pas son portail de retour avec la nouvelle mesh")
	var lab_interactions := lab_return.find_children("PortalInteraction", "Area3D", true, false)
	var lab_authored_frames := lab_return.find_children("AuthoredPortalFrame", "Node3D", true, false)
	var expected_lab_portals := expected_world_count + 2 # Forge, mondes sauvegardes, retour lobby.
	_check(lab_interactions.size() == expected_lab_portals, "le stand doit conserver son catalogue et ajouter le retour lobby : %d/%d" % [lab_interactions.size(), expected_lab_portals])
	_check(lab_authored_frames.size() == expected_lab_portals, "un portail du stand utilise encore une mesh de remplacement : %d/%d" % [lab_authored_frames.size(), expected_lab_portals])

	print("LOBBY_PORTAL_PROBE_OK campaigns=3 generated_worlds=%d authored_roles=5 lab_portals=%d" % [generated_world_count, expected_lab_portals])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("LOBBY_PORTAL_PROBE_FAILED %s" % message)
		quit(1)
