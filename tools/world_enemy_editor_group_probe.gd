extends SceneTree

class RecordingRuntime:
	extends HopliteWorldRuntime

	var spawned_entity_ids: Array[String] = []
	var removed_group_ids: Array[String] = []

	func spawn_enemy_group(entity: Dictionary, _target: Node3D, _existing_holder: Node3D = null, _count_override: int = -1, _start_index: int = 0) -> Array[Node]:
		spawned_entity_ids.append(String(entity.get("id", "")))
		return []

	func remove_enemy_group(group_id: String) -> int:
		removed_group_ids.append(group_id)
		return 1

	func refresh_protect_targets() -> void:
		pass

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var document := HopliteWorldDocument.new()
	var chapter_id := document.start_chapter()
	var alpha := _enemy_group("enemy_alpha", "Avant-garde", "alpha", chapter_id)
	var beta := _enemy_group("enemy_beta", "Arrière-garde", "beta", chapter_id)
	var reserve := _enemy_group("enemy_reserve", "Réserve", "reserve", chapter_id)
	var prop := HopliteWorldDocument.entity("prop", "Colonne", Vector3.ZERO, {"asset_id": "column"})
	prop["id"] = "prop_column"
	prop["chapter"] = chapter_id
	document.add_entity(alpha)
	document.add_entity(beta)
	document.add_entity(reserve)
	document.add_entity(prop)
	var enemy_group_id := document.create_editor_group("Ligne du rempart", ["enemy_alpha", "enemy_beta"], "enemy")
	var object_group_id := document.create_editor_group("Décor du rempart", ["prop_column"], "object")
	_expect(not enemy_group_id.is_empty() and not object_group_id.is_empty(), "typed enemy and object groups must be created")
	_expect(document.create_editor_group("Mélange interdit", ["enemy_alpha", "prop_column"]).is_empty(), "enemy troops and objects must not share one editor group")
	_expect(document.enemy_entities_for_reference(enemy_group_id, chapter_id).size() == 2, "enemy group reference must resolve every member troop")
	_expect(document.enemy_entities_for_reference(object_group_id, chapter_id).is_empty(), "object groups must never resolve as combat groups")

	var legacy_data := document.data.duplicate(true)
	legacy_data["version"] = 7
	for raw_group: Variant in legacy_data.get("editor_groups", []):
		(raw_group as Dictionary).erase("kind")
	var migrated := HopliteWorldDocument.new(legacy_data)
	_expect(int(migrated.data.get("version", 0)) == HopliteWorldDocument.CURRENT_VERSION, "legacy group documents must migrate to version 8")
	_expect(String(migrated.find_editor_group(enemy_group_id).get("kind", "")) == "enemy", "legacy all-enemy groups must migrate as enemy groups")
	_expect(String(migrated.find_editor_group(object_group_id).get("kind", "")) == "object", "legacy prop groups must migrate as object groups")

	var trigger_all := _trigger("trigger_all", "Toute la ligne morte", "group_dead", enemy_group_id, "none", "", chapter_id)
	var trigger_half := _trigger("trigger_half", "Moitié de la ligne morte", "group_dead_percent", enemy_group_id, "none", "", chapter_id)
	(trigger_half.get("properties", {}) as Dictionary)["threshold"] = 50.0
	var trigger_spawn := _trigger("trigger_spawn", "Faire apparaître la ligne", "player_enter", "", "spawn_group", enemy_group_id, chapter_id)
	var trigger_remove := _trigger("trigger_remove", "Retirer la ligne", "player_enter", "", "remove_group", enemy_group_id, chapter_id)
	document.add_entity(trigger_all)
	document.add_entity(trigger_half)
	document.add_entity(trigger_spawn)
	document.add_entity(trigger_remove)
	var stored_reserve := document.find_entity("enemy_reserve")
	(stored_reserve.get("properties", {}) as Dictionary)["spawn_condition"] = "group_dead"
	(stored_reserve.get("properties", {}) as Dictionary)["spawn_dead_group"] = enemy_group_id

	var runtime := RecordingRuntime.new()
	runtime.document = document
	runtime.active_chapter_id = chapter_id
	root.add_child(runtime)
	var event_runtime := HopliteWorldEventRuntime.new()
	root.add_child(event_runtime)
	event_runtime.configure(document, runtime)
	_expect((event_runtime.call("_find_enemy_groups", enemy_group_id) as Array).size() == 2, "event runtime must resolve a composite enemy group")

	event_runtime.call("_fire", trigger_spawn)
	_expect(runtime.spawned_entity_ids.has("enemy_alpha") and runtime.spawned_entity_ids.has("enemy_beta"), "spawn action must affect every troop in an enemy group")
	event_runtime.call("_fire", trigger_remove)
	_expect(runtime.removed_group_ids.has("alpha") and runtime.removed_group_ids.has("beta"), "remove action must affect every troop in an enemy group")

	event_runtime.call("_on_enemy_died", null, "alpha")
	_expect(event_runtime.fired.has("trigger_half"), "percent death trigger must aggregate deaths across the enemy group")
	_expect(not event_runtime.fired.has("trigger_all"), "full death trigger must wait for every member troop")
	event_runtime.call("_on_enemy_died", null, "beta")
	_expect(event_runtime.fired.has("trigger_all"), "full death trigger must fire after every member troop is dead")
	_expect(runtime.spawned_entity_ids.has("enemy_reserve"), "group-death spawn condition must accept a composite enemy group")

	var protected_alpha := Node3D.new()
	var protected_beta := Node3D.new()
	runtime.add_child(protected_alpha)
	runtime.add_child(protected_beta)
	runtime.enemies_by_group["alpha"] = [protected_alpha]
	runtime.enemies_by_group["beta"] = [protected_beta]
	var protect_target := runtime.call("_resolve_protect_target_node", enemy_group_id) as Node3D
	_expect(protect_target in [protected_alpha, protected_beta], "protection must resolve a living troop inside the selected enemy group")

	var budget := HopliteWorldEncounterBudget.new()
	budget.configure(document.entities_for_chapter(chapter_id), document.editor_groups())
	var dependencies := (budget.get("_direct_dependencies") as Dictionary).get("enemy_reserve", []) as Array
	_expect(dependencies.has("enemy_alpha") and dependencies.has("enemy_beta"), "encounter budget must include every troop referenced by an enemy group")

	print("WORLD_ENEMY_EDITOR_GROUP_OK")
	quit(0)

func _enemy_group(id: String, display_name: String, group_id: String, chapter_id: String) -> Dictionary:
	var entity := HopliteWorldDocument.entity("enemy_group", display_name, Vector3.ZERO, {
		"group_id": group_id,
		"archetype": "nathenian1",
		"count": 1,
		"spawn_condition": "trigger",
		"deployment_mode": "all",
	})
	entity["id"] = id
	entity["chapter"] = chapter_id
	return entity

func _trigger(id: String, display_name: String, condition: String, condition_group: String, action: String, action_target: String, chapter_id: String) -> Dictionary:
	var entity := HopliteWorldDocument.entity("trigger", display_name, Vector3.ZERO, {
		"condition": condition,
		"condition_group": condition_group,
		"threshold": 100.0,
		"action": action,
		"action_target": action_target,
		"once": true,
	})
	entity["id"] = id
	entity["chapter"] = chapter_id
	return entity

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("WORLD_ENEMY_EDITOR_GROUP_FAILED: " + message)
	quit(1)
