extends RefCounted
class_name HopliteV2ShadowFactory

const Actor = preload("res://scripts/enemy_v2/enemy_actor_v2.gd")
const Catalog = preload("res://scripts/enemy_v2/hoplite_v2_catalog.gd")

## Lab-only constructor. Production remains owned by enemy_factory.gd/V1.
static func create(archetype_id: StringName) -> HopliteEnemyActorV2:
	var definition := Catalog.definition(archetype_id)
	if definition == null:
		return null
	var actor := (load("res://scripts/enemy_v2/giant_v2_actor.gd").new() if definition.unit_role == &"giant" else Actor.new()) as HopliteEnemyActorV2
	actor.name = "%s_ShadowV2" % String(archetype_id).to_pascal_case()
	if not actor.configure(definition):
		actor.free()
		return null
	return actor
