extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe_lethal_limb_sever_finalizes_death()
	if failures.is_empty():
		print("ENEMY_ANATOMY_REGRESSION_PROBE PASS: lethal sever always finalizes death")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _probe_lethal_limb_sever_finalizes_death() -> void:
	var enemy := Enemy.new()
	root.add_child(enemy)
	enemy.max_health = 20.0
	enemy.health = 20.0
	enemy.anatomy_defs[&"forearm_r"] = {
		"damage_mult": 1.0,
		"sever_mult": 1.0,
		"severable": true,
		"sever_threshold": 10.0,
		"fatal_sever": false,
		"sever_target": &"forearm_r",
		"proxy_zone": &"forearm_r"
	}
	enemy.zone_state[&"forearm_r"] = {
		"damage": 0.0,
		"sever": 0.0,
		"severed": false
	}

	var hit := HitEvent.new()
	hit.damage = 30.0
	hit.sever_damage = 20.0
	hit.position = enemy.global_position + Vector3.UP
	hit.direction = Vector3.RIGHT
	hit.source = null
	enemy.receive_anatomy_hit(hit, &"forearm_r")

	_expect(is_zero_approx(enemy.health), "lethal limb hit did not reduce health to zero")
	_expect(enemy.is_combat_zone_severed(&"forearm_r"), "limb sever did not complete")
	_expect(enemy.dead, "lethal limb sever left a living enemy at zero health")
	_expect(not enemy.ai_enabled, "death did not disable AI participation")
	_expect(not enemy.is_in_group("combatant_ai"), "death retained combatant_ai membership")
	_expect(enemy.navigation_component == null or not enemy.navigation_component.has_destination, "death retained an active navigation destination")
	enemy.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
