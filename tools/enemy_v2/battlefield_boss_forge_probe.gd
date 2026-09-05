extends SceneTree
const Editor = preload("res://scripts/world_editor/world_editor.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var editor := Editor.new()
	root.add_child(editor)
	current_scene = editor
	await process_frame
	editor._load_battlefield_example("res://worlds/forge/bataille_v2_deux_armees.hoplite.json")
	var zone: Dictionary = editor.document.find_entity("battlefield_demo")
	editor._add_battlefield_boss(zone)
	await process_frame
	editor._rebuild_inspector()
	var boss: Dictionary = editor.document.find_entity(editor.selected_id)
	assert(boss.properties.battlefield_boss)
	assert(editor.document.validation_report().valid)
	for condition: String in ["start","loss_percent","timer","trigger","target_dead"]:
		boss.properties.boss_spawn_condition = condition
		editor._rebuild_inspector()
		await process_frame
	boss.properties.boss_spawn_condition = "loss_percent"
	editor._rebuild_inspector()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tmp_tools/boss_forge.png")
	editor._populate_battlefield(zone)
	assert(not editor.document.find_entity(boss.id).is_empty())
	boss.properties.boss_spawn_condition = "target_dead"
	boss.properties.spawn_dead_group = boss.properties.group_id
	assert(not editor.document.validation_report().valid)
	editor.queue_free()
	await process_frame
	print("BATTLEFIELD_BOSS_FORGE_PROBE PASS")
	quit()
