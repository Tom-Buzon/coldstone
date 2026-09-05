extends SceneTree

const SOURCE := "res://assets/animations/source_packs/spear/Bayonet_Stab.fbx"


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load(SOURCE) as PackedScene
	if packed == null:
		push_error("BAYONET_SOURCE_AUDIT missing imported scene")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var skeleton := _find_skeleton(scene)
	var player := _find_animation_player(scene)
	if skeleton == null or player == null:
		push_error("BAYONET_SOURCE_AUDIT missing skeleton or animation player")
		quit(1)
		return
	var bones := PackedStringArray()
	for bone_index: int in range(skeleton.get_bone_count()):
		bones.append(skeleton.get_bone_name(bone_index))
	print("BAYONET_RIG bones=", skeleton.get_bone_count(), " names=", bones)
	for clip_name: StringName in player.get_animation_list():
		var clip := player.get_animation(clip_name)
		print("BAYONET_CLIP name=", clip_name, " length=", clip.length, " tracks=", clip.get_track_count())
	scene.free()
	quit(0)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null
