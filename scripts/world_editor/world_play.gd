extends Node3D
class_name HopliteWorldPlay

const LAB_SCENE := "res://combat_lab.tscn"
const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const EventRuntimeScript = preload("res://scripts/world_editor/world_event_runtime.gd")

var document: HopliteWorldDocument
var runtime: HopliteWorldRuntime
var event_runtime: HopliteWorldEventRuntime
var status_label: Label
var narrative_panel: PanelContainer
var narrative_speaker: Label
var narrative_text: Label
var narrative_timer: Timer
var event_music_player: AudioStreamPlayer
var current_chapter_id := ""
var chapter_transitioning := false

func _ready() -> void:
	var path := String(get_tree().get_meta("hoplite_world_path", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_build_ui("MONDE INTROUVABLE")
		return
	document = WorldDocumentScript.from_json(file.get_as_text())
	if document == null:
		_build_ui("MONDE INVALIDE")
		return
	_build_ui(String(document.data.get("name", "Monde")))
	await _load_chapter(document.start_chapter(), "")

func _load_chapter(chapter_id: String, spawn_id: String) -> void:
	if chapter_transitioning:
		return
	chapter_transitioning = true
	if status_label != null:
		status_label.text = "Chargement du chapitre…"
	if narrative_panel != null:
		narrative_panel.visible = false
	if event_music_player != null:
		event_music_player.stop()
	if event_runtime != null and is_instance_valid(event_runtime):
		event_runtime.queue_free()
	event_runtime = null
	if runtime != null and is_instance_valid(runtime):
		runtime.clear_world()
		runtime.queue_free()
	runtime = null
	# Two frames guarantee that every enemy, tween, timer, collision shape and
	# tactical director from the previous chapter has left the SceneTree.
	await get_tree().process_frame
	await get_tree().process_frame
	current_chapter_id = chapter_id
	runtime = WorldRuntimeScript.new() as HopliteWorldRuntime
	runtime.name = "ChapterRuntime_%s" % chapter_id.validate_node_name()
	add_child(runtime)
	runtime.build(document, false, Vector3.ZERO, INF, chapter_id, spawn_id)
	runtime.chapter_transition_requested.connect(_on_chapter_transition_requested)
	event_runtime = EventRuntimeScript.new() as HopliteWorldEventRuntime
	event_runtime.name = "ChapterEvents_%s" % chapter_id.validate_node_name()
	add_child(event_runtime)
	event_runtime.configure(document, runtime)
	event_runtime.narrative_requested.connect(_show_narrative)
	event_runtime.music_requested.connect(_play_event_music)
	event_runtime.status_changed.connect(func(message: String) -> void: status_label.text = message)
	chapter_transitioning = false
	status_label.text = "Chapitre charge : %s" % _chapter_name(chapter_id)

func _on_chapter_transition_requested(destination_chapter: String, destination_spawn: String) -> void:
	await _load_chapter(destination_chapter, destination_spawn)

func _chapter_name(chapter_id: String) -> String:
	for raw: Variant in document.chapters():
		var chapter := raw as Dictionary
		if String(chapter.get("id", "")) == chapter_id:
			return String(chapter.get("name", chapter_id))
	return chapter_id

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_return_to_lab()

func _build_ui(title: String) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	var top := PanelContainer.new()
	top.position = Vector2(14, 14)
	top.size = Vector2(520, 66)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.052, 0.92)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8; style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	top.add_theme_stylebox_override("panel", style)
	canvas.add_child(top)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	top.add_child(row)
	var title_label := Label.new()
	title_label.text = "MONDE • %s" % title.to_upper()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("e9b96e"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var exit := Button.new()
	exit.text = "← LABORATOIRE  Echap"
	exit.pressed.connect(_return_to_lab)
	row.add_child(exit)
	status_label = Label.new()
	status_label.position = Vector2(18, 86)
	status_label.text = "Explorez le monde. Les events sont actifs."
	status_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(status_label)
	narrative_panel = PanelContainer.new()
	narrative_panel.position = Vector2(300, 550)
	narrative_panel.size = Vector2(680, 120)
	narrative_panel.visible = false
	narrative_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(narrative_panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	narrative_panel.add_child(box)
	narrative_speaker = Label.new(); narrative_speaker.add_theme_font_size_override("font_size", 17); narrative_speaker.add_theme_color_override("font_color", Color("e9b96e")); box.add_child(narrative_speaker)
	narrative_text = Label.new(); narrative_text.add_theme_font_size_override("font_size", 18); narrative_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(narrative_text)
	narrative_timer = Timer.new(); narrative_timer.one_shot = true; narrative_timer.timeout.connect(func() -> void: narrative_panel.visible = false); add_child(narrative_timer)

func _show_narrative(speaker: String, text: String, duration: float) -> void:
	narrative_speaker.text = speaker.to_upper()
	narrative_text.text = text
	narrative_panel.visible = true
	narrative_timer.start(duration)

func _play_event_music(path: String, volume_db: float) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		status_label.text = "Musique introuvable : %s" % path
		return
	if event_music_player == null:
		event_music_player = AudioStreamPlayer.new()
		event_music_player.name = "WorldEventMusic"
		if AudioServer.get_bus_index("HopliteMusic") >= 0:
			event_music_player.bus = &"HopliteMusic"
		add_child(event_music_player)
	event_music_player.stop()
	event_music_player.stream = stream
	event_music_player.volume_db = volume_db
	event_music_player.play()

func _return_to_lab() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LAB_SCENE)
