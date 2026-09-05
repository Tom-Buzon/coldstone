extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")

const CORPSE_COUNT := 36
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "EnemyCorpseMassTTLProbeWorld"
	root.add_child(world)
	current_scene = world
	var corpse_refs: Array[WeakRef] = []
	for index: int in range(CORPSE_COUNT):
		var enemy = EnemyFactory.spawn(world, &"swordsman", Vector3(float(index % 9) * 2.0, 0.0, float(index / 9) * 2.0), null, {
			"ai_enabled": false,
			"mass_battle_mode": true,
		})
		_expect(enemy != null, "factory failed to create corpse fixture %d" % index)
		if enemy == null:
			continue
		enemy.corpse_lifetime = 0.05
		corpse_refs.append(weakref(enemy))
		enemy.call("_die", false)
	await create_timer(1.35).timeout
	await process_frame
	var survivors := 0
	for corpse_ref: WeakRef in corpse_refs:
		if corpse_ref.get_ref() != null:
			survivors += 1
	_expect(survivors == 0, "%d/%d expired corpses remained alive" % [survivors, corpse_refs.size()])
	var remaining_enemy_bodies := 0
	for child: Node in world.get_children():
		if child is CharacterBody3D:
			remaining_enemy_bodies += 1
	_expect(remaining_enemy_bodies == 0, "corpse world retained %d enemy bodies after global TTL" % remaining_enemy_bodies)
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_CORPSE_MASS_TTL_PROBE PASS: 36/36 corpses retired and released")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
