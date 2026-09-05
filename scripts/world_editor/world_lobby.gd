extends "res://scripts/world_editor/world_play.gd"
class_name HopliteWorldLobby

const LOBBY_WORLD_PATH := "user://hoplite_worlds/lobbyy.hoplite.json"
const FALLBACK_SCENE := "res://combat_lab.tscn"
const WorldPortalHubScript = preload("res://scripts/world_editor/world_portal_hub.gd")

var portal_hub: HopliteWorldPortalHub


func _world_path() -> String:
	return LOBBY_WORLD_PATH


func _is_home_world() -> bool:
	return true


func _after_world_loaded(path: String) -> void:
	portal_hub = WorldPortalHubScript.new() as HopliteWorldPortalHub
	portal_hub.configure_lobby(runtime, document, path)
	add_child(portal_hub)
	if status_label != null:
		status_label.text = "LOBBY • Forge a gauche • campagnes a droite • mondes et stand dans la zone dediee"


func _on_world_load_failed(message: String, path: String) -> void:
	push_error("[LOBBY] %s: %s" % [message, path])
	var scene_error := get_tree().change_scene_to_file(FALLBACK_SCENE)
	if scene_error != OK:
		super(message, path)
