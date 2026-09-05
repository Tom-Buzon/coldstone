extends SceneTree

const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")

var failures: Array[String] = []

class MortalActor extends Node3D:
	var dead := false
	var ai_enabled := true
	func is_dead_for_combat() -> bool:
		return dead
	func is_ai_participating_for_combat() -> bool:
		return ai_enabled and not dead

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := CrowdDirector.new()
	root.add_child(director)
	var target := Node3D.new()
	target.add_to_group("player")
	root.add_child(target)
	var attackers: Array[Node3D] = []
	for index: int in range(4):
		var attacker := Node3D.new()
		attacker.name = "Attacker%d" % index
		attacker.add_to_group("combatant_ai")
		root.add_child(attacker)
		attackers.append(attacker)
	director.invalidate_spatial_grid()
	director._physics_process(0.001)
	var pressure_scans_before: int = director.pressure_scan_count
	var first_pressure := director.local_pressure(target)
	var second_pressure := director.local_pressure(target)
	_expect(first_pressure == second_pressure and first_pressure == attackers.size(), "local pressure cache changed the spatial result")
	_expect(director.pressure_scan_count == pressure_scans_before + 1, "same-grid local pressure was scanned more than once")

	_expect(director.request_attack_permission(attackers[0], target, 2), "first attacker did not receive a lease")
	_expect(director.request_attack_permission(attackers[1], target, 2), "second attacker did not fill capacity")
	_expect(not director.request_attack_permission(attackers[2], target, 2), "third attacker exceeded capacity")
	_expect(not director.request_attack_permission(attackers[3], target, 2), "fourth attacker exceeded capacity")

	director.release_attack_permission(attackers[1], target)
	_expect(not director.request_attack_permission(attackers[3], target, 2), "late requester skipped the FIFO waiter")
	_expect(director.request_attack_permission(attackers[2], target, 2), "oldest waiter did not receive the freed lease")
	_expect(director.has_method("has_attack_permission"), "scheduler exposes no authoritative lease query")
	if director.has_method("has_attack_permission"):
		_expect(bool(director.call("has_attack_permission", attackers[2], target)), "granted lease was not observable")
		director.release_attack_permission(attackers[2], target)
		_expect(not bool(director.call("has_attack_permission", attackers[2], target)), "released lease remained authoritative")

	_expect(director.has_method("request_attack_lease") and director.has_method("is_attack_lease_valid"), "scheduler exposes no generation-token lease API")
	if director.has_method("request_attack_lease") and director.has_method("is_attack_lease_valid"):
		var token_target := Node3D.new()
		token_target.add_to_group("player")
		root.add_child(token_target)
		var token_one := int(director.call("request_attack_lease", attackers[2], token_target, 2))
		_expect(token_one > 0, "tokenized lease request returned no generation")
		var permissions: Dictionary = director.attack_permissions[token_target.get_instance_id()]
		var lease: Dictionary = permissions[attackers[2].get_instance_id()]
		lease["expires_at"] = Time.get_ticks_msec() * 0.001 - 0.1
		permissions[attackers[2].get_instance_id()] = lease
		director.attack_permissions[token_target.get_instance_id()] = permissions
		_expect(not bool(director.call("is_attack_lease_valid", attackers[2], token_target, token_one)), "expired generation remained valid")
		var token_two := int(director.call("request_attack_lease", attackers[2], token_target, 2))
		_expect(token_two > token_one, "replacement lease did not advance its generation")
		director.call("release_attack_permission", attackers[2], token_target, token_one)
		_expect(bool(director.call("is_attack_lease_valid", attackers[2], token_target, token_two)), "stale release revoked a newer lease")
		token_target.queue_free()

	var dead_attacker := MortalActor.new()
	var dead_target := MortalActor.new()
	root.add_child(dead_attacker)
	root.add_child(dead_target)
	dead_attacker.dead = true
	_expect(director.request_attack_lease(dead_attacker, target, 2) == 0, "dead attacker received a direct scheduler lease")
	dead_attacker.dead = false
	dead_target.dead = true
	_expect(director.request_attack_lease(dead_attacker, dead_target, 2) == 0, "dead target received a direct scheduler lease")
	dead_target.dead = false
	var disabled_waiter := MortalActor.new()
	root.add_child(disabled_waiter)
	var disable_target := Node3D.new()
	root.add_child(disable_target)
	var holder := MortalActor.new()
	var late_attacker := MortalActor.new()
	root.add_child(holder)
	root.add_child(late_attacker)
	_expect(director.request_attack_lease(holder, disable_target, 1) > 0, "disable scenario holder received no lease")
	_expect(director.request_attack_lease(disabled_waiter, disable_target, 1) == 0, "disable scenario waiter was not queued")
	disabled_waiter.ai_enabled = false
	director.cancel_attack_requests(disabled_waiter)
	_expect(director.request_attack_lease(disabled_waiter, disable_target, 1) == 0, "disabled attacker received a direct scheduler lease")
	director.release_attack_permission(holder, disable_target)
	_expect(director.request_attack_lease(late_attacker, disable_target, 1) > 0, "disabled waiter remained at the FIFO head")
	disabled_waiter.queue_free()
	disable_target.queue_free()
	holder.queue_free()
	late_attacker.queue_free()
	dead_attacker.queue_free()
	dead_target.queue_free()

	for attacker: Node3D in attackers:
		attacker.queue_free()
	target.queue_free()
	director.queue_free()
	if failures.is_empty():
		print("ATTACK_SCHEDULER_PROBE PASS: capacity, FIFO fairness, liveness and authoritative leases")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
