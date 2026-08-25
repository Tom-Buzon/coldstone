extends SceneTree

const ASSET_PATH := "res://assets/characters/3dgen_demo/perso-1787423482233.glb"

func _initialize() -> void:
	var packed := load(ASSET_PATH) as PackedScene
	assert(packed != null, "Player variant GLB is not importable")
	var instance := packed.instantiate() as Node3D
	assert(instance != null, "Player variant GLB could not be instantiated")
	var skeleton := _find_skeleton(instance)
	assert(skeleton != null, "Player variant has no Skeleton3D")
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	print("[PLAYER VARIANT ASSET] bones=%d meshes=%d hand.L=%d hand.R=%d" % [skeleton.get_bone_count(), meshes.size(), skeleton.find_bone("DEF-hand.L"), skeleton.find_bone("DEF-hand.R")])
	assert(skeleton.find_bone("DEF-hand.L") >= 0 and skeleton.find_bone("DEF-hand.R") >= 0, "Player variant is not compatible with UAL weapons")
	instance.free()
	quit(0)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
