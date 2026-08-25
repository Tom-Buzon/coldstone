extends Node
class_name HopliteWorldEventRuntime

signal narrative_requested(speaker: String, text: String, duration: float)
signal music_requested(path: String, volume_db: float)
signal event_fired(event_name: String)
signal status_changed(message: String)

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const ATMOSPHERE_PRESETS := {
	"Jour antique": {"sun_energy": 1.15, "ambient_energy": 0.72, "fog_density": 0.006, "sky_top": "#263850", "sky_horizon": "#d8ad78"},
	"Siege enfume": {"sun_energy": 0.66, "ambient_energy": 0.42, "fog_density": 0.027, "sky_top": "#1d2029", "sky_horizon": "#9e6549"},
	"Crepuscule sanglant": {"sun_energy": 0.82, "ambient_energy": 0.48, "fog_density": 0.014, "sky_top": "#151d38", "sky_horizon": "#d65c46"},
	"Nuit sacree": {"sun_energy": 0.18, "ambient_energy": 0.28, "fog_density": 0.019, "sky_top": "#080d20", "sky_horizon": "#31456b"}
}

var document: HopliteWorldDocument
var runtime: HopliteWorldRuntime
var fired: Dictionary = {}
var group_initial: Dictionary = {}
var group_deaths: Dictionary = {}
var spawned_groups: Dictionary = {}
var deployment_states: Dictionary = {}

func configure(source: HopliteWorldDocument, world_runtime: HopliteWorldRuntime) -> void:
	document = source
	runtime = world_runtime
	fired.clear()
	group_initial.clear()
	group_deaths.clear()
	spawned_groups.clear()
	deployment_states.clear()
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) != "enemy_group":
			continue
		var properties := entity.get("properties", {}) as Dictionary
		var group_id := String(properties.get("group_id", ""))
		group_initial[group_id] = int(group_initial.get(group_id, 0)) + maxi(0, int(properties.get("count", 0)))
		var fallback := "start" if bool(properties.get("active_on_start", true)) else "trigger"
		var spawn_condition := String(properties.get("spawn_condition", fallback))
		var deployment_mode := String(properties.get("deployment_mode", "all"))
		if deployment_mode != "all":
			deployment_states[String(entity.get("id", ""))] = {"entity": entity, "active": false, "stopped": false, "deployed": 0, "timer": null}
		if spawn_condition == "start" and deployment_mode == "all":
			spawned_groups[String(entity.get("id", ""))] = true
		elif spawn_condition == "start":
			_activate_deployment(entity)
		elif spawn_condition == "timer":
			_schedule_group_spawn(entity, maxf(0.0, float(properties.get("spawn_delay", 3.0))))
	if not runtime.player_entered_trigger.is_connected(_on_player_entered_trigger):
		runtime.player_entered_trigger.connect(_on_player_entered_trigger)
	if not runtime.player_entered_atmosphere.is_connected(_on_player_entered_atmosphere):
		runtime.player_entered_atmosphere.connect(_on_player_entered_atmosphere)
	if not runtime.enemy_died.is_connected(_on_enemy_died):
		runtime.enemy_died.connect(_on_enemy_died)

func _on_player_entered_trigger(trigger_id: String) -> void:
	var trigger := document.find_entity(trigger_id)
	if trigger.is_empty():
		return
	var properties := trigger.get("properties", {}) as Dictionary
	if String(properties.get("condition", "player_enter")) == "player_enter":
		_fire(trigger)
	for raw: Variant in _chapter_entities():
		var group := raw as Dictionary
		if String(group.get("type", "")) != "enemy_group":
			continue
		var group_properties := group.get("properties", {}) as Dictionary
		if String(group_properties.get("spawn_condition", "start")) != "trigger":
			continue
		var reference := String(group_properties.get("spawn_trigger", ""))
		if reference in [trigger_id, String(trigger.get("name", ""))]:
			_spawn_group_entity(group)

func _on_player_entered_atmosphere(zone_id: String) -> void:
	var zone := document.find_entity(zone_id)
	if zone.is_empty():
		return
	var properties := zone.get("properties", {}) as Dictionary
	var values := (document.data.get("atmosphere", {}) as Dictionary).duplicate(true)
	for key: Variant in properties.keys():
		if key in ["sun_energy", "ambient_energy", "fog_density", "sky_top", "sky_horizon", "preset"]:
			values[key] = properties[key]
	runtime.apply_atmosphere(values)
	status_changed.emit("Atmosphere : %s" % String(properties.get("preset", zone.get("name", "Zone"))))

func _on_enemy_died(_enemy: Node, group_id: String) -> void:
	group_deaths[group_id] = int(group_deaths.get(group_id, 0)) + 1
	_stop_deployments_for_unit_death(group_id)
	for raw: Variant in _chapter_entities():
		var trigger := raw as Dictionary
		if String(trigger.get("type", "")) != "trigger":
			continue
		var properties := trigger.get("properties", {}) as Dictionary
		var condition := String(properties.get("condition", ""))
		if condition not in ["group_dead", "group_dead_percent"] or not _group_reference_matches(String(properties.get("condition_group", "")), group_id):
			continue
		var initial := maxi(1, int(group_initial.get(group_id, 1)))
		var deaths := int(group_deaths.get(group_id, 0))
		var threshold := 100.0 if condition == "group_dead" else clampf(float(properties.get("threshold", 100.0)), 1.0, 100.0)
		if float(deaths) / float(initial) * 100.0 >= threshold:
			_fire(trigger)
	for raw: Variant in _chapter_entities():
		var group := raw as Dictionary
		if String(group.get("type", "")) != "enemy_group":
			continue
		var properties := group.get("properties", {}) as Dictionary
		if String(properties.get("spawn_condition", "start")) != "group_dead":
			continue
		var reference := String(properties.get("spawn_dead_group", ""))
		if not _group_reference_matches(reference, group_id):
			continue
		if int(group_deaths.get(group_id, 0)) >= maxi(1, int(group_initial.get(group_id, 1))):
			_spawn_group_entity(group)
	_update_reserve_deployments()

func _fire(trigger: Dictionary) -> void:
	var trigger_id := String(trigger.get("id", ""))
	var properties := trigger.get("properties", {}) as Dictionary
	if bool(properties.get("once", true)) and fired.has(trigger_id):
		return
	fired[trigger_id] = true
	_stop_deployments_for_trigger(trigger)
	var action := String(properties.get("action", "none"))
	var target := String(properties.get("action_target", ""))
	match action:
		"open_door":
			if runtime.open_door(target):
				status_changed.emit("Porte ouverte : %s" % target)
			else:
				status_changed.emit("Porte introuvable : %s" % target)
		"spawn_group":
			var group := _find_enemy_group(target)
			if not group.is_empty():
				_spawn_group_entity(group)
		"remove_group":
			var removed_group := _find_enemy_group(target)
			var removed_group_properties := removed_group.get("properties", {}) as Dictionary
			var removed_group_id := String(removed_group_properties.get("group_id", target))
			_stop_deployment(String(removed_group.get("id", "")))
			var removed := runtime.remove_enemy_group(removed_group_id)
			status_changed.emit("%d ennemis retires du groupe %s" % [removed, removed_group_id])
		"remove_all_mobs":
			_stop_all_deployments()
			var removed_total := 0
			for group_id: Variant in runtime.enemies_by_group.keys():
				removed_total += runtime.remove_enemy_group(String(group_id))
			status_changed.emit("Nettoyage de scene : %d ennemis retires" % removed_total)
		"narrative":
			var legacy_narrative_mode := "element" if not target.is_empty() and String(properties.get("action_text", "")).is_empty() else "direct"
			var narrative_mode := String(properties.get("narrative_mode", legacy_narrative_mode))
			var narrative_properties: Dictionary = {}
			if narrative_mode == "element":
				var narrative := document.find_entity(target)
				if narrative.is_empty():
					narrative = document.find_by_name(target)
				narrative_properties = narrative.get("properties", {}) as Dictionary
			var text := String(narrative_properties.get("text", "...")) if narrative_mode == "element" else String(properties.get("action_text", "..."))
			var speaker := String(narrative_properties.get("speaker", "Narrateur")) if narrative_mode == "element" else String(properties.get("action_speaker", "Narrateur"))
			var duration := float(narrative_properties.get("duration", 4.0)) if narrative_mode == "element" else float(properties.get("action_duration", 4.0))
			narrative_requested.emit(speaker, text, duration)
		"music":
			var path := String(properties.get("music_path", ""))
			if not path.is_empty():
				music_requested.emit(path, float(properties.get("music_volume", -4.0)))
				status_changed.emit("Musique : %s" % path.get_file().get_basename().replace("_", " ").capitalize())
		"atmosphere":
			var zone := document.find_entity(target)
			if zone.is_empty():
				zone = document.find_by_name(target)
			if not zone.is_empty():
				_on_player_entered_atmosphere(String(zone.get("id", "")))
			else:
				var values := (document.data.get("atmosphere", {}) as Dictionary).duplicate(true)
				var preset := String(properties.get("atmosphere_preset", "Siege enfume"))
				if ATMOSPHERE_PRESETS.has(preset):
					values.merge(ATMOSPHERE_PRESETS[preset], true)
				for key: Variant in ["sun_energy", "ambient_energy", "fog_density", "sky_top", "sky_horizon"]:
					if properties.has(key):
						values[key] = properties[key]
				runtime.apply_atmosphere(values)
				status_changed.emit("Atmosphere : %s" % preset)
		_:
			status_changed.emit("Evenement sans action : %s" % String(trigger.get("name", trigger_id)))
	event_fired.emit(String(trigger.get("name", trigger_id)))

func _schedule_group_spawn(group: Dictionary, delay: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.01, delay)
	timer.timeout.connect(func() -> void:
		_spawn_group_entity(group)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

func _spawn_group_entity(group: Dictionary) -> Array[Node]:
	var properties := group.get("properties", {}) as Dictionary
	if String(properties.get("deployment_mode", "all")) != "all":
		return _activate_deployment(group)
	var entity_id := String(group.get("id", ""))
	if spawned_groups.has(entity_id):
		return []
	spawned_groups[entity_id] = true
	var spawned := runtime.spawn_enemy_group(group, runtime.player)
	runtime.refresh_protect_targets()
	status_changed.emit("%d ennemis generes : %s" % [spawned.size(), String(group.get("name", entity_id))])
	return spawned

func _activate_deployment(group: Dictionary) -> Array[Node]:
	var entity_id := String(group.get("id", ""))
	var state := deployment_states.get(entity_id, {}) as Dictionary
	if state.is_empty():
		state = {"entity": group, "active": false, "stopped": false, "deployed": 0, "timer": null}
		deployment_states[entity_id] = state
	if bool(state.get("active", false)) or bool(state.get("stopped", false)):
		return []
	state["active"] = true
	var properties := group.get("properties", {}) as Dictionary
	var mode := String(properties.get("deployment_mode", "all"))
	var initial_amount := int(properties.get("wave_size", 3)) if mode == "waves" else int(properties.get("initial_active", 10))
	var spawned := _spawn_deployment_batch(group, initial_amount)
	var timer := Timer.new()
	timer.one_shot = false
	timer.wait_time = maxf(0.1, float(properties.get("wave_interval", 5.0))) if mode == "waves" else 0.35
	timer.timeout.connect(_tick_deployment.bind(entity_id))
	add_child(timer)
	state["timer"] = timer
	timer.start()
	return spawned

func _tick_deployment(entity_id: String) -> void:
	var state := deployment_states.get(entity_id, {}) as Dictionary
	if state.is_empty() or not bool(state.get("active", false)) or bool(state.get("stopped", false)):
		_stop_deployment(entity_id)
		return
	var group := state.get("entity", {}) as Dictionary
	var properties := group.get("properties", {}) as Dictionary
	var total := maxi(0, int(properties.get("count", 0)))
	if int(state.get("deployed", 0)) >= total:
		_stop_deployment(entity_id)
		return
	if String(properties.get("deployment_mode", "all")) == "waves":
		_spawn_deployment_batch(group, maxi(1, int(properties.get("wave_size", 3))))
	else:
		var group_id := String(properties.get("group_id", ""))
		var threshold := maxi(0, int(properties.get("reinforce_threshold", 7)))
		if runtime.living_count(group_id) < threshold:
			_spawn_deployment_batch(group, maxi(1, int(properties.get("reinforce_amount", 3))))

func _spawn_deployment_batch(group: Dictionary, requested_amount: int) -> Array[Node]:
	var entity_id := String(group.get("id", ""))
	var state := deployment_states.get(entity_id, {}) as Dictionary
	if state.is_empty() or bool(state.get("stopped", false)):
		return []
	var properties := group.get("properties", {}) as Dictionary
	var total := maxi(0, int(properties.get("count", 0)))
	var deployed := maxi(0, int(state.get("deployed", 0)))
	var amount := mini(maxi(0, requested_amount), maxi(0, total - deployed))
	if amount <= 0:
		return []
	var spawned := runtime.spawn_enemy_group(group, runtime.player, null, amount, deployed)
	state["deployed"] = deployed + spawned.size()
	status_changed.emit("Renforts %s : +%d • %d/%d deployes" % [String(group.get("name", entity_id)), spawned.size(), int(state.get("deployed", 0)), total])
	return spawned

func _update_reserve_deployments() -> void:
	for raw_id: Variant in deployment_states.keys():
		var state := deployment_states[raw_id] as Dictionary
		var group := state.get("entity", {}) as Dictionary
		var properties := group.get("properties", {}) as Dictionary
		if String(properties.get("deployment_mode", "")) == "reserve" and bool(state.get("active", false)) and not bool(state.get("stopped", false)):
			_tick_deployment(String(raw_id))

func _stop_deployments_for_trigger(trigger: Dictionary) -> void:
	var trigger_id := String(trigger.get("id", ""))
	var trigger_name := String(trigger.get("name", ""))
	for raw_id: Variant in deployment_states.keys():
		var state := deployment_states[raw_id] as Dictionary
		var group := state.get("entity", {}) as Dictionary
		var properties := group.get("properties", {}) as Dictionary
		var legacy_stop_mode := "event" if not String(properties.get("deployment_stop_trigger", "")).is_empty() else "total"
		if String(properties.get("deployment_stop_mode", legacy_stop_mode)) != "event":
			continue
		var stop_reference := String(properties.get("deployment_stop_trigger", ""))
		if not stop_reference.is_empty() and stop_reference in [trigger_id, trigger_name]:
			_stop_deployment(String(raw_id))
			status_changed.emit("Renforts arretes : %s" % String(group.get("name", raw_id)))

func _stop_deployments_for_unit_death(dead_group_id: String) -> void:
	for raw_id: Variant in deployment_states.keys():
		var state := deployment_states[raw_id] as Dictionary
		if not bool(state.get("active", false)) or bool(state.get("stopped", false)):
			continue
		var group := state.get("entity", {}) as Dictionary
		var properties := group.get("properties", {}) as Dictionary
		if String(properties.get("deployment_mode", "")) != "waves" or String(properties.get("deployment_stop_mode", "total")) != "unit_death":
			continue
		if _group_reference_matches(String(properties.get("deployment_stop_group", "")), dead_group_id):
			_stop_deployment(String(raw_id))
			status_changed.emit("Vagues arretees par une mort : %s" % String(group.get("name", raw_id)))

func _stop_deployment(entity_id: String) -> void:
	var state := deployment_states.get(entity_id, {}) as Dictionary
	if state.is_empty():
		return
	state["stopped"] = true
	state["active"] = false
	var timer := state.get("timer") as Timer
	if timer != null and is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	state["timer"] = null

func _stop_all_deployments() -> void:
	for raw_id: Variant in deployment_states.keys():
		_stop_deployment(String(raw_id))

func _group_reference_matches(reference: String, dead_group_id: String) -> bool:
	if reference == dead_group_id:
		return true
	var observed := _find_enemy_group(reference)
	if observed.is_empty():
		return false
	var properties := observed.get("properties", {}) as Dictionary
	return String(properties.get("group_id", "")) == dead_group_id

func _find_enemy_group(key: String) -> Dictionary:
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) != "enemy_group":
			continue
		var properties := entity.get("properties", {}) as Dictionary
		if String(properties.get("group_id", "")) == key or String(entity.get("id", "")) == key or String(entity.get("name", "")) == key:
			return entity
	return {}

func _chapter_entities() -> Array[Dictionary]:
	return document.entities_for_chapter(runtime.active_chapter_id)
