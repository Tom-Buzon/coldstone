extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")

const LOBBY_PATH := "user://hoplite_worlds/lobbyy.hoplite.json"
const FORGE_PORTAL_ASSET := "res://assets/blenderAseet/07_portes/portal_world_forge/portal_world_forge_LOD0.glb"
const CAMPAIGN_PORTAL_ASSET := "res://assets/blenderAseet/07_portes/portal_official_campaign/portal_official_campaign_LOD0.glb"
const SAVED_WORLD_PORTAL_ASSET := "res://assets/blenderAseet/07_portes/portal_saved_world/portal_saved_world_LOD0.glb"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var file := FileAccess.open(LOBBY_PATH, FileAccess.READ)
	if file == null:
		_fail("lobby introuvable : %s" % LOBBY_PATH)
		return
	var document := WorldDocumentScript.from_json(file.get_as_text()) as HopliteWorldDocument
	file = null
	if document == null:
		_fail("JSON du lobby invalide")
		return
	var start_chapter := document.start_chapter()
	var forge_portal := _find_prop_by_asset(document, FORGE_PORTAL_ASSET)
	var sample_campaign := _find_prop_by_asset(document, CAMPAIGN_PORTAL_ASSET)
	if forge_portal.is_empty() or sample_campaign.is_empty():
		_fail("les portails exemple Forge/Campagne sont absents du lobby")
		return

	_configure_portal(forge_portal, "world_editor", "", "FORGE DE MONDES\nCREER & EDITER")
	_configure_portal(sample_campaign, "official_campaign", "procedural_campaign", "")
	_ensure_campaign_portal(document, start_chapter, "lobby_campaign_grand_siege", "Portail Campagne — Grand Siege", Vector3(19.0, 0.0, -17.0), Vector3(0.0, -66.0, 0.0), "grand_siege")
	_ensure_campaign_portal(document, start_chapter, "lobby_campaign_last_flame", "Portail Campagne — La Derniere Flamme", Vector3(27.0, 0.0, -11.0), Vector3(0.0, -80.0, 0.0), "last_flame")
	_ensure_saved_world_anchor(document, start_chapter)

	var report := document.validation_report()
	if not bool(report.get("valid", false)):
		_fail("la map migree est invalide : %s" % "; ".join(report.get("errors", []) as Array))
		return
	if not _save_atomically(document):
		return
	print("LOBBY_PORTALS_CONFIGURED path=%s campaigns=3 entities=%d" % [LOBBY_PATH, document.entities().size()])
	quit(0)


func _find_prop_by_asset(document: HopliteWorldDocument, asset_path: String) -> Dictionary:
	for raw: Variant in document.entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) != "prop":
			continue
		var properties := entity.get("properties", {}) as Dictionary
		if String(properties.get("asset_path", "")) == asset_path:
			return entity
	return {}


func _configure_portal(entity: Dictionary, role: String, campaign_id: String, label: String) -> void:
	var properties := entity.get("properties", {}) as Dictionary
	properties["portal_role"] = role
	properties["portal_label"] = label
	if not campaign_id.is_empty():
		properties["campaign_id"] = campaign_id


func _ensure_campaign_portal(
	document: HopliteWorldDocument,
	chapter_id: String,
	entity_id: String,
	display_name: String,
	position_value: Vector3,
	rotation_value: Vector3,
	campaign_id: String
) -> void:
	var entity := document.find_entity(entity_id)
	if entity.is_empty():
		entity = WorldDocumentScript.entity("prop", display_name, position_value, _portal_prop(CAMPAIGN_PORTAL_ASSET, "Portal Official Campaign", 6.0609))
		entity["id"] = entity_id
		entity["chapter"] = chapter_id
		document.add_entity(entity)
		entity = document.find_entity(entity_id)
	entity["position"] = WorldDocumentScript.array3(position_value)
	entity["rotation"] = WorldDocumentScript.array3(rotation_value)
	_configure_portal(entity, "official_campaign", campaign_id, "")


func _ensure_saved_world_anchor(document: HopliteWorldDocument, chapter_id: String) -> void:
	var entity := document.find_entity("lobby_saved_worlds_anchor")
	if entity.is_empty():
		entity = WorldDocumentScript.entity(
			"prop",
			"Zone portails — Stand et mondes crees",
			Vector3(-29.0, 0.0, 43.0),
			_portal_prop(SAVED_WORLD_PORTAL_ASSET, "Portal Saved World", 5.3436)
		)
		entity["id"] = "lobby_saved_worlds_anchor"
		entity["chapter"] = chapter_id
		entity["rotation"] = [0.0, 0.0, 0.0]
		document.add_entity(entity)
		entity = document.find_entity("lobby_saved_worlds_anchor")
	var properties := entity.get("properties", {}) as Dictionary
	properties["portal_role"] = "saved_worlds_anchor"
	properties["portal_columns"] = 9
	properties["portal_column_spacing"] = 7.25
	properties["portal_row_spacing"] = 8.0


func _portal_prop(asset_path: String, asset_label: String, target_height: float) -> Dictionary:
	return {
		"asset_path": asset_path,
		"asset_label": asset_label,
		"target_height": target_height,
		"brush_spacing": 1.0,
		"ground_offset": 0.0,
		"collision_enabled": false,
		"collision_shape": "box",
		"align_to_ground": false,
	}


func _save_atomically(document: HopliteWorldDocument) -> bool:
	var temporary_path := LOBBY_PATH + ".portal_migration.tmp"
	var backup_path := LOBBY_PATH + ".portal_migration.bak"
	var temporary := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary == null:
		_fail("impossible de creer la sauvegarde temporaire")
		return false
	temporary.store_string(document.to_json())
	temporary.flush()
	temporary = null
	var global_target := ProjectSettings.globalize_path(LOBBY_PATH)
	var global_temporary := ProjectSettings.globalize_path(temporary_path)
	var global_backup := ProjectSettings.globalize_path(backup_path)
	if not FileAccess.file_exists(backup_path):
		var backup_error := DirAccess.copy_absolute(global_target, global_backup)
		if backup_error != OK:
			_fail("copie de securite impossible : %s" % error_string(backup_error))
			return false
	var remove_error := DirAccess.remove_absolute(global_target)
	if remove_error != OK:
		_fail("remplacement du lobby impossible : %s" % error_string(remove_error))
		return false
	var rename_error := DirAccess.rename_absolute(global_temporary, global_target)
	if rename_error != OK:
		DirAccess.copy_absolute(global_backup, global_target)
		_fail("activation du lobby migre impossible : %s" % error_string(rename_error))
		return false
	return true


func _fail(message: String) -> void:
	push_error("LOBBY_PORTALS_CONFIGURATION_FAILED %s" % message)
	quit(1)
