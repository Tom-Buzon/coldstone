extends SceneTree

const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")
const Combat = preload("res://scripts/enemy_v2/hoplite_v2_combat_component.gd")
var failures: Array[String] = []

class Target extends Node3D:
	var hits := 0
	func receive_enemy_hit(_damage: float, _source: Node, _direction: Vector3) -> void:
		hits += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var target := Target.new()
	target.position = Vector3(0, 0, 18)
	world.add_child(target)
	var archer := _spawn(world, target, &"archer_v2")
	var infantry := _spawn(world, target, &"infantry_v2")
	infantry.position.x = 8.0
	for actor: HopliteEnemyActorV2 in [archer, infantry]:
		_expect(actor.definition.validate().is_empty(), "invalid role definition")
		_expect(actor.presentation.skeleton.get_bone_count() == 23, "role lost shared skeleton")
		_expect(actor.presentation.lod_meshes.size() == 3, "role lost body LODs")
		_expect(actor.health_component.anatomy != null and actor.dismemberment != null, "role lost anatomy")
		_expect(actor.equipment.geometry.size() > 0, "equipment has no LOD geometry")
	_expect(archer.equipment.shield_hitbox == null, "archer carries a physical shield")
	_expect(infantry.equipment.shield_hitbox != null, "infantry lost buckler")
	archer.combat.attack_cooldown = 0.0
	archer.combat.formation_decision_tick(0.5, true, false)
	_expect(archer.combat.is_attack_committed(), "archer did not commit in range")
	_expect(archer.animation.current_semantic == &"bow_draw", "archer plays wrong animation")
	archer.combat.formation_action_tick(1.01)
	_expect(is_instance_valid(archer.combat.projectile), "archer did not release physical projectile")
	if is_instance_valid(archer.combat.projectile):
		var projectile: Node = archer.combat.projectile
		projectile.set_physics_process(false)
		for frame: int in range(70):
			if projectile.is_queued_for_deletion():
				break
			projectile._physics_process(1.0 / 60.0)
	_expect(target.hits == 1, "ballistic arrow did not hit stationary target")
	await process_frame
	archer.combat._transition(Combat.State.GUARD)
	archer.combat.attack_cooldown = 0.0
	archer.combat.formation_decision_tick(0.5, true, false)
	target.position.x = 5.0
	archer.combat.formation_action_tick(1.01)
	if is_instance_valid(archer.combat.projectile):
		var projectile: Node = archer.combat.projectile
		projectile.set_physics_process(false)
		for frame: int in range(150):
			if projectile.is_queued_for_deletion():
				break
			projectile._physics_process(1.0 / 60.0)
	_expect(target.hits == 1, "arrow homed onto target after aim lock")
	await process_frame
	archer.combat._transition(Combat.State.GUARD)
	target.position = Vector3(0, 0, 4)
	archer.combat.formation_decision_tick(0.5, true, false)
	for frame: int in range(100):
		archer.combat.formation_action_tick(1.0 / 60.0)
		archer.position += archer.combat.formation_motion_velocity() / 60.0
	_expect(archer.position.length() <= 4.1, "archer withdrawal was not bounded")
	_expect(archer.combat.retreat_cooldown > 0.0, "archer can kite without vulnerable pause")
	infantry.position = Vector3.ZERO
	target.position = Vector3(0, 0, 1.7)
	infantry.combat.standalone_origin = Vector3.ZERO
	infantry.combat.attack_cooldown = 0.0
	infantry.combat.formation_decision_tick(0.5, true, false)
	_expect(infantry.combat.is_attack_committed(), "infantry did not start sword cut")
	infantry.combat.formation_action_tick(0.6)
	_expect(target.hits == 2, "sword cut did not hit nearby target")
	infantry.combat._transition(Combat.State.GUARD)
	infantry.combat.attack_cooldown = 0.0
	infantry.combat.formation_decision_tick(0.5, true, false)
	target.position = Vector3(0, 0, -1.7)
	infantry.combat.formation_action_tick(0.6)
	_expect(target.hits == 2, "sword snapped around after commitment")
	for actor: HopliteEnemyActorV2 in [archer, infantry]:
		var hit := HitEvent.new()
		hit.source = target
		hit.damage = 1.0
		hit.sever_damage = 70.0
		hit.direction = Vector3.RIGHT
		hit.position = actor.position + Vector3.UP
		actor.receive_anatomy_hit(hit, &"forearm_l" if actor == archer else &"forearm_r")
		_expect(not actor.combat.weapon_available, "severed arm can still attack")
		_expect(actor.dismemberment.last_fragment != null, "role sever did not create fragment")
	world.free()
	for failure: String in failures:
		push_error(failure)
	print("ENEMY_V2_ROLES_PROBE ", "PASS" if failures.is_empty() else "FAIL", " : role assets, projectile hit/dodge, bounded retreat, sword facing, dismemberment")
	quit(0 if failures.is_empty() else 1)

func _spawn(world: Node3D, target: Node3D, id: StringName) -> HopliteEnemyActorV2:
	var actor := Factory.create(id)
	actor.combat_lab_enabled = true
	actor.combat_target = target
	actor.lod_reference = target
	world.add_child(actor)
	actor.combat.set_physics_process(false)
	return actor

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
