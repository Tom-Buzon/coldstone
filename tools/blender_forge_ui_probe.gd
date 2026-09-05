extends SceneTree

const WORLD_EDITOR_SCENE: PackedScene = preload("res://world_editor.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var editor := WORLD_EDITOR_SCENE.instantiate() as HopliteWorldEditor
	_expect(editor != null, "World editor scene could not be instantiated")
	if editor == null:
		_finish()
		return

	root.add_child(editor)
	await process_frame
	editor.library_category.select(3)
	editor.call("_refresh_library")
	await process_frame

	var blender_folder: FoldableContainer
	for child: Node in editor.library_items.get_children():
		if child is FoldableContainer and (child as FoldableContainer).title.begins_with("BLENDER — PRODUCTION V2"):
			blender_folder = child as FoldableContainer
			break
	_expect(blender_folder != null, "The 3D catalog has no separate Blender folder")
	if blender_folder != null:
		_expect(not blender_folder.folded, "The Blender folder should be visible by default")
		var nested_folders := blender_folder.find_children("*", "FoldableContainer", true, false)
		_expect(nested_folders.size() == 14, "The Blender folder must contain 14 family folders")

	editor.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("[BLENDER FORGE UI PROBE] PASS root_folder=1 family_folders=14")
		quit(0)
		return
	for failure: String in failures:
		printerr("[BLENDER FORGE UI PROBE] %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
