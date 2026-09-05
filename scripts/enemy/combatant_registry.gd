extends Node
class_name HopliteCombatantRegistry

signal combatant_registered(combatant: Node)
signal combatant_unregistered(instance_id: int)
signal combatant_liveness_changed(combatant: Node, living: bool)

var _entries: Dictionary[int, bool] = {}
var _living: Dictionary[int, bool] = {}
var _registration_order: Array[int] = []
var _validated_scripts: Dictionary[Script, bool] = {}


func _ready() -> void:
	add_to_group("combatant_registry")


func register_combatant(combatant: Node) -> bool:
	if not is_inside_tree() or combatant == null or not is_instance_valid(combatant) or not combatant.is_inside_tree():
		return false
	if combatant.get_tree() != get_tree():
		return false
	if not _contract_is_compatible(combatant):
		return false
	var instance_id := combatant.get_instance_id()
	var existing := _node_for_id(instance_id)
	if existing == combatant:
		return false
	if existing != null:
		_remove_id(instance_id)

	_entries[instance_id] = true
	_living[instance_id] = _read_living(combatant)
	_registration_order.append(instance_id)

	var tree_exit_callback := Callable(self, "_on_combatant_tree_exiting").bind(instance_id)
	if not combatant.tree_exiting.is_connected(tree_exit_callback):
		combatant.tree_exiting.connect(tree_exit_callback, CONNECT_ONE_SHOT)
	if combatant.has_signal("died"):
		var death_callback := Callable(self, "_on_combatant_died").bind(instance_id)
		if not combatant.is_connected("died", death_callback):
			combatant.connect("died", death_callback)

	combatant_registered.emit(combatant)
	return true


func unregister_combatant(combatant: Node) -> bool:
	if combatant == null or not is_instance_valid(combatant):
		return false
	return _remove_id(combatant.get_instance_id())


func refresh_liveness(combatant: Node) -> bool:
	if combatant == null or not is_instance_valid(combatant):
		return false
	var instance_id := combatant.get_instance_id()
	if _node_for_id(instance_id) != combatant:
		return false
	var next_living := _read_living(combatant)
	var previous_living := bool(_living.get(instance_id, false))
	_living[instance_id] = next_living
	if next_living != previous_living:
		combatant_liveness_changed.emit(combatant, next_living)
	return next_living


func contains(combatant: Node) -> bool:
	if combatant == null or not is_instance_valid(combatant):
		return false
	return _node_for_id(combatant.get_instance_id()) == combatant


func registered_count() -> int:
	_prune_stale_entries()
	return _entries.size()


func living_count(faction_filter: StringName = StringName(), ai_enabled_only: bool = false) -> int:
	return snapshot(faction_filter, true, ai_enabled_only).size()


func snapshot(
	faction_filter: StringName = StringName(),
	living_only: bool = false,
	ai_enabled_only: bool = false
) -> Array[Node]:
	var result: Array[Node] = []
	var stale_ids: Array[int] = []
	for instance_id: int in _registration_order:
		var combatant := _node_for_id(instance_id)
		if combatant == null:
			stale_ids.append(instance_id)
			continue
		if living_only and not bool(_living.get(instance_id, false)):
			continue
		if faction_filter != StringName() and StringName(combatant.get("faction")) != faction_filter:
			continue
		if ai_enabled_only and not bool(combatant.get("ai_enabled")):
			continue
		result.append(combatant)
	for instance_id: int in stale_ids:
		_remove_id(instance_id)
	return result


func _on_combatant_died(_combatant: Variant, instance_id: int) -> void:
	var combatant := _node_for_id(instance_id)
	if combatant == null:
		return
	if bool(_living.get(instance_id, false)):
		_living[instance_id] = false
		combatant_liveness_changed.emit(combatant, false)


func _on_combatant_tree_exiting(instance_id: int) -> void:
	_remove_id(instance_id)


func _node_for_id(instance_id: int) -> Node:
	if not _entries.has(instance_id):
		return null
	return instance_from_id(instance_id) as Node


func _remove_id(instance_id: int) -> bool:
	if not _entries.has(instance_id):
		return false
	_entries.erase(instance_id)
	_living.erase(instance_id)
	_registration_order.erase(instance_id)
	combatant_unregistered.emit(instance_id)
	return true


func _prune_stale_entries() -> void:
	var stale_ids: Array[int] = []
	for instance_id: int in _registration_order:
		if _node_for_id(instance_id) == null:
			stale_ids.append(instance_id)
	for instance_id: int in stale_ids:
		_remove_id(instance_id)


func _read_living(combatant: Node) -> bool:
	if combatant.has_method("is_dead_for_combat"):
		return not bool(combatant.call("is_dead_for_combat"))
	return true


func _contract_is_compatible(combatant: Node) -> bool:
	var script := combatant.get_script() as Script
	if script != null and _validated_scripts.has(script):
		return bool(_validated_scripts[script])
	var compatible := (
		_has_property(combatant, &"faction")
		and _has_property(combatant, &"ai_enabled")
		and typeof(combatant.get("faction")) == TYPE_STRING_NAME
		and typeof(combatant.get("ai_enabled")) == TYPE_BOOL
		and (not combatant.has_signal("died") or _has_compatible_death_signal(combatant))
	)
	if script != null:
		_validated_scripts[script] = compatible
	return compatible


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", StringName())) == property_name:
			return true
	return false


func _has_compatible_death_signal(object: Object) -> bool:
	for signal_info: Dictionary in object.get_signal_list():
		if StringName(signal_info.get("name", StringName())) != &"died":
			continue
		var arguments: Array = signal_info.get("args", [])
		return arguments.size() == 1 and int(arguments[0].get("type", TYPE_NIL)) == TYPE_OBJECT
	return false
