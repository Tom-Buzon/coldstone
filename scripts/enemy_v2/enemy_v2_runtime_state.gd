extends RefCounted
class_name HopliteEnemyV2RuntimeState

## Mutable per-instance data, deliberately separate from shared definitions.

var health: float = 0.0
var desired_velocity: Vector3 = Vector3.ZERO
var current_action: StringName = &"idle"
var simulation_tier: StringName = &"full"
var severed_zones: Dictionary = {}


func reset_from_definition(definition: HopliteEnemyV2Definition) -> void:
	health = definition.max_health
	desired_velocity = Vector3.ZERO
	current_action = &"idle"
	simulation_tier = &"full"
	severed_zones.clear()
