extends SceneTree

const Player = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := Player.new()
	world.add_child(player)
	await process_frame
	await process_frame
	var settings: Node = player.player_presentation.audio_settings
	if settings == null or settings.skill_tree_panel == null:
		push_error("Skill tree missing from Settings")
		quit(1)
		return
	settings.set_open(true)
	for index: int in settings.tabs.get_tab_count():
		if settings.tabs.get_tab_title(index) == "Compétences": settings.tabs.current_tab = index
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	screenshot.save_png("res://.godot/skill_tree_preview.png")
	var nested: TabContainer = settings.skill_tree_panel.get_node("SkillPages")
	if nested.get_tab_count() > 1:
		nested.current_tab = 1
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/skill_dev_preview.png")
	print("PASS: skill tree and Dev menu rendered")
	settings.set_open(false)
	current_scene = null
	world.queue_free()
	await process_frame
	quit()
