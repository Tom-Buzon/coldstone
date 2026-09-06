extends RefCounted

const Hit = preload("res://scripts/combat/hit_event.gd")

static func alive(target: Node) -> bool:
	return is_instance_valid(target) and target.is_inside_tree() and not (target.has_method("is_dead_for_combat") and target.is_dead_for_combat())

static func deal(source: Node3D, target: Node3D, amount: float, direction: Vector3, push: float, kind: StringName, sever: float = 0.0, destroy_shield: bool = false, zone: StringName = &"torso", contact_point: Vector3 = Vector3.INF) -> bool:
	if not alive(target): return false
	if target.has_method("can_receive_hit_from") and not target.can_receive_hit_from(source): return false
	var hit := Hit.new()
	hit.source = source
	hit.position = target.global_position + Vector3.UP if contact_point == Vector3.INF else contact_point
	hit.direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	hit.impulse = hit.direction * push
	hit.damage = amount
	hit.sever_damage = sever
	hit.guard_damage = amount * 2.0
	hit.damage_type = kind
	hit.attack_slot = &"heavy" if destroy_shield or kind == &"aura" else &"skill"
	hit.attack_charge_ratio = 1.0 if destroy_shield or kind == &"aura" else 0.0
	hit.contact_type = &"shockwave"
	hit.body_part = zone
	if kind == &"thunder": hit.contact_type = &"projectile"
	hit.destroy_shield = destroy_shield
	target.set_meta(&"last_skill_source", source.get_instance_id())
	if source.has_method("observe_skill_target"): source.observe_skill_target(target)
	var accepted := false
	if target.has_method("receive_anatomy_hit"):
		if destroy_shield and target.has_method("destroy_skill_shield"):
			target.destroy_skill_shield()
		if kind in [&"javelin", &"aura"] and target.has_method("receive_shield_hit") and target.receive_shield_hit(hit):
			accepted = true
		else:
			target.receive_anatomy_hit(hit, zone)
			accepted = true
	elif target.has_method("receive_spiral_smash"):
		accepted = target.receive_spiral_smash(hit)
	elif target.has_method("receive_ai_hit"):
		accepted = target.receive_ai_hit(amount, source, hit.direction)
	if accepted:
		if push > 0.0 and alive(target):
			var combat: Variant = target.get("combat")
			if combat is Node and combat.has_method("on_guard_broken"):
				combat.on_guard_broken(0.28, minf(push * 0.20, 6.0), hit.direction)
			elif target is CharacterBody3D:
				target.velocity += hit.impulse
		if source.has_signal("combat_hit"):
			source.emit_signal("combat_hit", target, zone, hit)
	return accepted

static func radial(source: Node3D, point: Vector3, radius: float, amount: float, push: float, kind: StringName, exclude_id: int = 0) -> void:
	for node: Node in source.get_tree().get_nodes_in_group(&"enemy"):
		if not node is Node3D or node.get_instance_id() == exclude_id or not alive(node): continue
		var offset: Vector3 = node.global_position - point
		if offset.length_squared() > radius * radius: continue
		# Do not damage through solid architecture.
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, node.global_position + Vector3.UP, 1)
		if not source.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		deal(source, node, amount, offset, push, kind)
