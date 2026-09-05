extends "res://scripts/enemy_v2/hoplite_v2_health_component.gd"

func install(actor_value: CharacterBody3D, skeleton: Skeleton3D, runtime_value: HopliteEnemyV2RuntimeState) -> bool:
	actor = actor_value
	runtime_state = runtime_value
	zone_definitions = AnatomyProfileScript.default_humanoid()
	var size: float = actor.size_multiplier
	for zone: Variant in zone_definitions:
		zone_definitions[zone]["radius"] = float(zone_definitions[zone]["radius"]) * size
		zone_definitions[zone]["sever_threshold"] = float(zone_definitions[zone]["sever_threshold"]) * 2.4
	anatomy = AnatomyScript.new() as HopliteAnatomyHitbox
	anatomy.name = "GiantV2Anatomy"
	actor.add_child(anatomy)
	active = anatomy.configure(actor, skeleton, zone_definitions)
	return active

func apply_runtime_lod(_level: int, planar_distance: float) -> void:
	if anatomy == null or not active:
		return
	var reach: float = maxf(9.0, actor.size_multiplier * 3.6)
	anatomy.set_runtime_query_enabled(planar_distance <= reach)
	anatomy.set_update_interval(1.0 / 30.0)
	actor.set_meta("enemy_v2_anatomy_mode", &"exact" if planar_distance <= reach else &"off")

func receive_hit(hit: Variant, zone: StringName) -> void:
	if hit != null and actor != null and actor.combat != null and actor.combat.is_vulnerable():
		var amplified: Variant = hit.clone() if hit.has_method("clone") else null
		if amplified != null:
			amplified.damage *= 1.4
			super.receive_hit(amplified, zone)
			return
	super.receive_hit(hit, zone)
