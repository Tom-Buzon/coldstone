extends SceneTree
const Editor = preload("res://scripts/world_editor/world_editor.gd")
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _run() -> void:
	var editor := Editor.new()
	root.add_child(editor)
	current_scene = editor
	await process_frame
	editor.library_category.select(4)
	editor._refresh_library()
	var example: Button
	for node: Node in editor.library_items.get_children():
		if node is Button and node.text == "Ouvrir l’exemple : deux armées": example = node
	check(example != null,"example button missing")
	if example != null: example.pressed.emit()
	await process_frame
	editor._rebuild_inspector()
	check(editor.selected_id=="battlefield_demo","example selection missing")
	check(editor.gizmo_handles.size()>=4,"zone has no resize handles")
	var zone: Dictionary = editor.document.find_entity("battlefield_demo")
	var before := editor.document.to_json()
	editor._populate_battlefield(zone)
	await process_frame
	check(editor.document.theoretical_mob_count("chapter_1")==169,"populate UI wrong population")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/battlefield_forge.png")
	editor._delete_selected()
	check(editor.document.theoretical_mob_count("chapter_1")==0,"zone deletion leaves army")
	editor._undo()
	check(editor.document.theoretical_mob_count("chapter_1")==169,"undo fails to restore army")
	editor._load_battlefield_example("res://worlds/forge/bataille_v2_garde_rapprochee.hoplite.json")
	await process_frame
	check(editor.document.theoretical_mob_count("chapter_1")==176,"bodyguard example population wrong")
	check(editor.document.find_entity("battlefield_demo").properties.escort_infantry==6,"escort composition missing")
	editor._rebuild_inspector()
	if DisplayServer.get_name() != "headless":
		await process_frame
		(editor.inspector_content.get_parent() as ScrollContainer).scroll_vertical = 10000
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/escort_forge.png")
	editor.queue_free()
	await process_frame
	await process_frame
	print("BATTLEFIELD_FORGE ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
