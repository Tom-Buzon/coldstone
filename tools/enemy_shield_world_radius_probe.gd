extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var guardian := EnemyFactory.spawn(world, &"guardian", Vector3.ZERO, null, {
		"ai_enabled": false,
		"mixamo_model_override": &"smallsbir5",
	})
	await process_frame
	_expect(guardian != null and guardian.shield_hitbox != null, "scaled guardian shield did not spawn")
	if guardian != null and guardian.shield_hitbox != null:
		var hitbox: HopliteShieldHitbox = guardian.shield_hitbox
		var world_scale := maxf(hitbox.global_basis.x.length(), maxf(hitbox.global_basis.y.length(), hitbox.global_basis.z.length()))
		var expected := hitbox.shield_radius * world_scale
		var actual := hitbox.zone_radius_from_shape_index(0)
		_expect(world_scale > 1.0, "probe fixture did not exercise inherited scaling")
		_expect(is_equal_approx(actual, expected), "shield query radius %.4f did not match physical world radius %.4f" % [actual, expected])
		_expect(actual > hitbox.shield_radius, "shield query still returned its local authored radius")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_SHIELD_WORLD_RADIUS_PROBE PASS: combat query radius matches inherited physical scale")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
