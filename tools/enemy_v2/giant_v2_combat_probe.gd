extends SceneTree
const Giant = preload("res://scripts/enemy_v2/giant_v2_actor.gd")
const Definition = preload("res://scripts/enemy_v2/giant_v2_definition.gd")
const Hit = preload("res://scripts/combat/hit_event.gd")
class Target extends CharacterBody3D:
	var hits: int = 0
	func receive_enemy_hit(_damage: float, _source: Node, _direction: Vector3) -> bool:
		hits += 1
		return true
	func register_enemy_near_miss(_source: Node) -> bool:
		return true
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Target.new()
	target.position = Vector3(0, 0, 4.0)
	world.add_child(target)
	var actor := Giant.new()
	expect(actor.configure(Definition.create()), "definition valid")
	actor.set_visual_scale(3.0)
	actor.combat_lab_enabled = true
	actor.combat_target = target
	actor.lod_reference = target
	actor.troop_controlled = true
	world.add_child(actor)
	actor.set_physics_process(false)
	await process_frame
	expect(actor.presentation.skeleton.get_bone_count() == 53, "real giant skeleton")
	expect(actor.presentation.lod_meshes.size() == 10, "real segmented mesh")
	expect(actor.scale.is_equal_approx(Vector3.ONE), "unscaled physics root")
	expect(actor.presentation.visual_root.scale.is_equal_approx(Vector3.ONE * 3), "single visual multiplier")
	expect(actor.health_component.anatomy.zone_runtime.size() == 12, "12 anatomy zones")
	var combat: Node = actor.combat
	combat.attack_cooldown = 0.0
	combat.formation_decision_tick(0.1, false, false)
	expect(not combat.is_attack_committed(), "no strike without permission")
	combat.formation_decision_tick(0.1, true, false)
	expect(combat.is_attack_committed(), "strike authorized")
	var origin: Vector3 = combat.impact_center
	target.position = Vector3(7, 0, 0)
	combat.formation_action_tick(1.1)
	expect(target.hits == 0, "committed aim dodged")
	expect(combat.impact_center.is_equal_approx(origin), "impact does not home")
	expect(combat.is_vulnerable(), "recovery vulnerability")
	var hit := Hit.new()
	hit.damage = 10.0
	hit.source = target
	var before: float = actor.health
	actor.receive_anatomy_hit(hit, &"torso")
	expect(is_equal_approx(before - actor.health, 14.0), "recovery damage bonus")
	combat.formation_action_tick(2.0)
	target.position = Vector3(0, 0, 4)
	combat.attack_cooldown = 0.0
	combat.formation_decision_tick(0.1, true, false)
	combat.formation_action_tick(1.4)
	expect(target.hits == 1, "swipe hits once")
	combat.formation_action_tick(0.5)
	expect(target.hits == 1, "impact cannot repeat")
	hit.sever_damage = 500.0
	hit.direction = Vector3.RIGHT
	expect(actor.dismemberment.sever(&"forearm_l", hit), "giant true fragment")
	expect(not actor.presentation.package.body_parts[&"forearm_l"].visible, "sever hides true body part")
	expect(actor.dismemberment.last_fragment != null, "fragment spawned")
	combat.formation_action_tick(2.0)
	target.position = Vector3(0, 2.0, 4)
	combat.attack_cooldown = 0.0
	combat.formation_decision_tick(0.1, true, false)
	expect(combat.current_pattern.id == &"giant_slam", "third pattern is ground slam")
	combat.formation_action_tick(1.8)
	expect(target.hits == 1, "jump clears committed ground slam")
	actor.dismemberment.sever(&"thigh_l", hit)
	expect(is_equal_approx(actor.locomotion_factor, 0.55), "single leg slows giant")
	actor.dismemberment.sever(&"thigh_r", hit)
	expect(is_zero_approx(actor.locomotion_factor), "two legs collapse giant")
	expect(actor.health_component.anatomy.get_zone_world_radius(&"torso") > 0.9, "scaled damage volumes")
	hit.damage = 1000.0
	actor.receive_anatomy_hit(hit, &"torso")
	expect(actor.dead, "giant killed through common hit pipeline")
	expect(not actor.is_in_group("enemy"), "death leaves enemy registry")
	expect(not actor.health_component.anatomy.query_enabled, "death disables damage volumes")
	print("GIANT_V2_COMBAT ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
