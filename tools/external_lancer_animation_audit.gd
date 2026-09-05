extends SceneTree

const SOURCE_PATH := "C:/Users/suean/Downloads/lancier-attack-animation-test.glb"


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var flags := GLTFDocument.IMPORT_FLAG_DISCARD_MESHES_AND_MATERIALS | GLTFDocument.IMPORT_FLAG_USE_NAMED_SKIN_BINDS
	var error := document.append_from_file(SOURCE_PATH, state, flags)
	if error != OK:
		push_error("LANCER_ANIMATION_AUDIT import failed: %s" % error_string(error))
		quit(1)
		return
	var scene := document.generate_scene(state)
	if scene == null:
		push_error("LANCER_ANIMATION_AUDIT generated no scene")
		quit(1)
		return
	root.add_child(scene)
	var skeleton := _find_skeleton(scene)
	var player := _find_animation_player(scene)
	print("LANCER_SCENE skeletons=", scene.find_children("*", "Skeleton3D", true, false).size(), " players=", scene.find_children("*", "AnimationPlayer", true, false).size())
	if skeleton == null or player == null:
		push_error("LANCER_ANIMATION_AUDIT missing Skeleton3D or AnimationPlayer")
		quit(1)
		return
	var bone_names: PackedStringArray = []
	for index: int in range(skeleton.get_bone_count()):
		bone_names.append(skeleton.get_bone_name(index))
	print("LANCER_SKELETON bones=", skeleton.get_bone_count(), " names=", bone_names)
	for animation_name: StringName in player.get_animation_list():
		var animation := player.get_animation(animation_name)
		print("LANCER_CLIP name=", animation_name, " length=", animation.length, " tracks=", animation.get_track_count())
		for track_index: int in range(animation.get_track_count()):
			var path := String(animation.track_get_path(track_index))
			print("LANCER_TRACK type=", animation.track_get_type(track_index), " path=", path, " keys=", animation.track_get_key_count(track_index))
	scene.free()
	quit(0)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
