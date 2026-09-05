extends SceneTree

const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")


class FakeEnemy extends Node:
	var dead: bool = false


func _init() -> void:
	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	var living_enemy := FakeEnemy.new()
	var dead_enemy := FakeEnemy.new()
	dead_enemy.dead = true
	var expired_enemy := FakeEnemy.new()
	runtime.enemies_by_group["probe"] = [living_enemy, dead_enemy, expired_enemy]
	expired_enemy.free()

	if runtime.living_count("probe") != 1:
		push_error("WORLD_RUNTIME_LIVING_COUNT_FAILED stale reference changed the living count")
		quit(1)
		return
	var retained := runtime.enemies_by_group.get("probe", []) as Array
	if retained.size() != 2 or not retained.has(living_enemy) or not retained.has(dead_enemy):
		push_error("WORLD_RUNTIME_LIVING_COUNT_FAILED stale reference was not pruned safely")
		quit(1)
		return

	living_enemy.free()
	dead_enemy.free()
	runtime.free()
	print("WORLD_RUNTIME_LIVING_COUNT_PROBE PASS: freed references are pruned before casting")
	quit()
