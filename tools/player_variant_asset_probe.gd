extends SceneTree

const ASSET_PATHS := [
	"res://assets/characters/player_skins/noonT1.glb",
	"res://assets/characters/player_skins/samusWoopsy.glb",
]

func _initialize() -> void:
	for asset_path: String in ASSET_PATHS:
		var packed := load(asset_path) as PackedScene
		assert(packed != null, "Player skin GLB is not importable: %s" % asset_path)
		var instance := packed.instantiate() as Node3D
		assert(instance != null, "Player skin GLB could not be instantiated: %s" % asset_path)
		var skeleton := _find_skeleton(instance)
		assert(skeleton != null, "Player skin has no Skeleton3D: %s" % asset_path)
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		print("[PLAYER SKIN ASSET] %s bones=%d meshes=%d hand.L=%d hand.R=%d" % [asset_path, skeleton.get_bone_count(), meshes.size(), skeleton.find_bone("DEF-hand.L"), skeleton.find_bone("DEF-hand.R")])
		assert(skeleton.get_bone_count() == 53, "Player skin does not use the canonical 53-bone UAL rig: %s" % asset_path)
		assert(skeleton.find_bone("DEF-hand.L") >= 0 and skeleton.find_bone("DEF-hand.R") >= 0, "Player skin is not compatible with UAL weapons: %s" % asset_path)
		instance.free()
	print("[PLAYER SKIN ASSET] PASS — Noon T1 and Samus Woopsy are UAL-compatible")
	quit(0)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
