extends SceneTree

const BattlefieldRuntime = preload("res://scripts/enemy_v2/battlefield/battlefield_runtime.gd")
const PlayerEscort = preload("res://scripts/enemy_v2/battlefield/player_escort.gd")


class FakeWorld extends Node:
	var player: Node3D


class FakeActor extends Node3D:
	var dead := false
	var combat_target: Node3D

	func set_combat_target(value: Node3D) -> void:
		combat_target = value


func _initialize() -> void:
	var world := FakeWorld.new()
	root.add_child(world)
	world.player = Node3D.new()
	world.add_child(world.player)

	var runtime := BattlefieldRuntime.new()
	world.add_child(runtime)
	runtime.world = world

	# Reproduce the gap between snapshot refreshes: the cached entry survives,
	# but its actor has already left the SceneTree and been freed.
	var defeated_actor := Node3D.new()
	world.add_child(defeated_actor)
	runtime.target_actors.append(defeated_actor)
	defeated_actor.free()

	runtime._process(0.016)
	if not runtime.target_actors.is_empty():
		push_error("Battlefield runtime retained a freed target actor")
		quit(1)
		return

	# The spatial cache has the same refresh cadence and must tolerate the same
	# lifetime gap while another surviving actor asks for nearby opponents.
	var bucket_actor := Node3D.new()
	world.add_child(bucket_actor)
	var cell := runtime._cell(Vector3.ZERO)
	runtime.buckets[cell] = [bucket_actor]
	bucket_actor.free()
	if not runtime.nearby(Vector3.ZERO, 8.0).is_empty():
		push_error("Battlefield runtime returned a freed spatial-cache actor")
		quit(1)
		return

	# A survivor can still own a committed target after that target is freed.
	# Reassignment must clear it without first coercing the stale value to Node3D.
	var survivor := FakeActor.new()
	var old_target := Node3D.new()
	world.add_child(survivor)
	world.add_child(old_target)
	survivor.combat_target = old_target
	old_target.free()
	runtime._assign_target(survivor, null)
	if survivor.combat_target != null:
		push_error("Battlefield runtime retained a freed committed combat target")
		quit(1)
		return

	# Player escorts keep their own 0.2 s registry and require the same guard.
	var escort := PlayerEscort.new()
	world.add_child(escort)
	escort.marker = MeshInstance3D.new()
	escort.add_child(escort.marker)
	var escort_actor := FakeActor.new()
	world.add_child(escort_actor)
	escort.members.append(escort_actor)
	escort_actor.free()
	escort._process(0.2)
	if not escort.members.is_empty():
		push_error("Player escort retained a freed battlefield actor")
		quit(1)
		return

	print("PASS: freed battlefield actors, spatial entries, combat targets and escorts are handled safely")
	quit(0)
