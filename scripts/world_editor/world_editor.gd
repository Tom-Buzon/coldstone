extends Node3D
class_name HopliteWorldEditor

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")
const WorldTerrainFoliageScript = preload("res://scripts/world_editor/world_terrain_foliage.gd")
const EventRuntimeScript = preload("res://scripts/world_editor/world_event_runtime.gd")
const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")
const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const EnemyArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const EditorGridScript = preload("res://scripts/world_editor/world_editor_grid.gd")
const AssetLibraryRoomScript = preload("res://scripts/environment/asset_library_room.gd")
const HelpCenterScript = preload("res://scripts/world_editor/world_editor_help.gd")

const SAVE_DIR := "user://hoplite_worlds"
const MATERIALS := ["mediterranean_grass", "pavers", "dirt_path", "scorched_ground", "cracked_weeds", "bone_gravel", "limestone_brick", "fortress", "rough_stone", "marble", "white_marble_floor", "mural", "ornate_stone_wall", "sandstone_floor"]
const ATMOSPHERE_PRESETS := {
	"Jour antique": {"sun_energy": 1.15, "ambient_energy": 0.72, "fog_density": 0.006, "sky_top": "#263850", "sky_horizon": "#d8ad78"},
	"Siege enfume": {"sun_energy": 0.66, "ambient_energy": 0.42, "fog_density": 0.027, "sky_top": "#1d2029", "sky_horizon": "#9e6549"},
	"Crepuscule sanglant": {"sun_energy": 0.82, "ambient_energy": 0.48, "fog_density": 0.014, "sky_top": "#151d38", "sky_horizon": "#d65c46"},
	"Nuit sacree": {"sun_energy": 0.18, "ambient_energy": 0.28, "fog_density": 0.019, "sky_top": "#080d20", "sky_horizon": "#31456b"}
}
const LAB_SCENE := "res://combat_lab.tscn"

var document: HopliteWorldDocument
var runtime: HopliteWorldRuntime
var event_runtime: HopliteWorldEventRuntime
var selected_id := ""
var undo_stack: Array[String] = []
var redo_stack: Array[String] = []
var dirty := false
var active_chapter_id := ""
var test_chapter_id := ""
var rebuilding_inspector := false
var preview_rebuild_pending := false
var test_mode := false
var ghost_mode := false
var tool_mode := "select"
var brush_type := "surface"
var brush_properties: Dictionary = {"shape": "floor", "size": [4.0, 0.35, 4.0], "material": "pavers"}
var brush_title := "Sol 4 × 4"
var active_material := "pavers"
var surface_brush_shape := "floor"
var surface_brush_size := Vector3(4.0, 0.35, 4.0)
var hover_id := ""
var resizing := false
var resize_axis := 0
var resize_sign := 1.0
var resize_start_scalar := 0.0
var resize_original_position := Vector3.ZERO
var resize_original_size := Vector3.ONE
var resize_axis_world := Vector3.RIGHT
var resize_original_uniform_scale := 1.0
var resize_uniform := false
var moving_entity := false
var move_mode := ""
var move_original_position := Vector3.ZERO
var move_drag_start_world := Vector3.ZERO
var move_vertical_start_scalar := 0.0
var move_bottom_offset := 0.0
var move_axis_origin := Vector3.ZERO
var move_drag_start_screen := Vector2.ZERO
var move_vertical_world_per_pixel := 0.01
var rotating_entity := false
var rotation_axis := 1
var rotation_start_mouse := Vector2.ZERO
var rotation_original := Vector3.ZERO
var capture_mode := ""
var capture_source_id := ""
var capture_route_id := ""
var capture_route_order := 0

var brush_painting := false
var brush_stroke_start := Vector3.ZERO
var brush_stroke_last := Vector3.ZERO
var brush_stroke_axis := -1
var brush_stroke_keys: Dictionary = {}
var brush_stroke_first_id := ""
var brush_stroke_wall_oriented := false

var terrain_tool := "raise"
var terrain_brush_radius := 4.0
var terrain_brush_strength := 0.45
var active_foliage_preset := "mediterranean_grass"
var terrain_painting := false
var terrain_stroke_last := Vector3(INF, INF, INF)
var terrain_flatten_height := 0.0

var camera_rig: Node3D
var camera_yaw: Node3D
var camera_pitch: Node3D
var editor_camera: Camera3D
var camera_target := Vector3.ZERO
var camera_distance := 30.0
var orbiting := false
var panning := false
var last_mouse_position := Vector2.ZERO

var canvas: CanvasLayer
var top_bar: Control
var tool_rail: Control
var viewport_hud: Control
var help_center: HopliteWorldEditorHelp
var left_panel: Control
var right_panel: Control
var bottom_bar: Control
var rotation_overlay: Control
var rotation_label: Label
var left_panel_toggle_button: Button
var right_panel_toggle_button: Button
var save_command_button: Button
var undo_command_button: Button
var redo_command_button: Button
var help_button: Button
var test_button: Button
var left_panel_open := true
var right_panel_open := true
var library_category: OptionButton
var library_items: VBoxContainer
var workspace_tabs: TabContainer
var ghost_mode_button: Button
var select_tool_button: Button
var brush_tool_button: Button
var eraser_tool_button: Button
var brush_label: Label
var guide_label: Label
var grid_size_picker: OptionButton
var map_extent_picker: OptionButton
var chapter_picker: OptionButton
var chapter_name_edit: LineEdit
var hierarchy: Tree
var hierarchy_filter: LineEdit
var inspector_content: VBoxContainer
var world_name: LineEdit
var save_picker: OptionButton
var population_label: Label
var status_label: Label
var test_overlay: Control
var test_status: Label
var narrative_panel: Control
var narrative_speaker: Label
var narrative_text: Label
var narrative_timer: Timer
var event_music_player: AudioStreamPlayer
var selection_marker: MeshInstance3D
var hover_marker: MeshInstance3D
var brush_cursor: MeshInstance3D
var ground_snap_marker: MeshInstance3D
var terrain_brush_marker: MeshInstance3D
var rotation_indicator: MeshInstance3D
var grid: HopliteWorldEditorGrid
var gizmo_root: Node3D
var gizmo_handles: Array[StaticBody3D] = []
var automatic_assets: Array[Dictionary] = []
var hovered_gizmo_handle: StaticBody3D
var brush_position_valid := true

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	document = WorldDocumentScript.new(WorldDocumentScript.example_world())
	active_chapter_id = document.start_chapter()
	var asset_scanner := AssetLibraryRoomScript.new()
	automatic_assets = asset_scanner.call("_scan_catalog") as Array[Dictionary]
	asset_scanner.free()
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) == "surface":
			selected_id = String(entity.get("id", ""))
			break
	_build_camera()
	grid = EditorGridScript.new() as HopliteWorldEditorGrid
	add_child(grid)
	grid.set_grid_size(float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0)))
	grid.set_half_extent(float((document.data.get("settings", {}) as Dictionary).get("map_half_extent", 60.0)))
	_build_ui()
	_build_editor_visuals()
	runtime = WorldRuntimeScript.new() as HopliteWorldRuntime
	runtime.name = "WorldRuntime"
	add_child(runtime)
	_rebuild_preview()
	_refresh_save_picker()
	_set_tool_mode("select")
	_set_status("EDITION UNIFIEE — choisissez une categorie, prenez un outil, puis agissez directement dans la vue 3D.")

func _process(delta: float) -> void:
	if preview_rebuild_pending and not test_mode:
		preview_rebuild_pending = false
		_rebuild_preview()
	if test_mode:
		_update_test_status()
		return
	_update_hover_and_cursor(last_mouse_position)
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		var movement := Vector3.ZERO
		if _shortcut_pressed("move_forward"): movement.z -= 1.0
		if _shortcut_pressed("move_back"): movement.z += 1.0
		if _shortcut_pressed("move_left"): movement.x -= 1.0
		if _shortcut_pressed("move_right"): movement.x += 1.0
		if ghost_mode and _shortcut_pressed("move_up"): movement.y += 1.0
		if ghost_mode and _shortcut_pressed("move_down"): movement.y -= 1.0
		if movement.length_squared() > 0.0:
			var forward := -camera_yaw.global_basis.z
			var right := camera_yaw.global_basis.x
			if not ghost_mode:
				forward.y = 0.0
				right.y = 0.0
			var speed_multiplier := 2.5 if _shortcut_pressed("move_fast") else 1.0
			var vertical := Vector3.UP * movement.y
			var direction := right * movement.x + forward * movement.z + vertical
			var speed := 10.0 if ghost_mode else camera_distance * 0.65
			camera_target += direction.normalized() * delta * speed * speed_multiplier
			camera_rig.position = camera_target
	_update_selection_marker()

func _unhandled_input(event: InputEvent) -> void:
	if help_center != null and help_center.visible:
		return
	if test_mode:
		if event is InputEventKey and _shortcut_matches(event, "return_lab"):
			_stop_test()
		return
	if rotating_entity:
		if event is InputEventMouseMotion:
			last_mouse_position = event.position
			_update_rotation(event.position)
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_finish_rotation(true)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_finish_rotation(false)
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_finish_rotation(false)
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_finish_rotation(true)
		return
	if not capture_mode.is_empty():
		if event is InputEventMouseButton and event.pressed:
			last_mouse_position = event.position
			if event.button_index == MOUSE_BUTTON_LEFT and not _mouse_over_editor_ui():
				if capture_mode == "patrol":
					_add_patrol_mapping_point(event.position)
				else:
					_capture_reference_at(event.position)
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_finish_capture_mode()
				return
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_finish_capture_mode()
			return
	if event is InputEventMouseButton:
		last_mouse_position = event.position
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if orbiting else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if panning else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = maxf(0.35, camera_distance * 0.84)
			if not ghost_mode:
				editor_camera.position.z = camera_distance
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = minf(1500.0, camera_distance * 1.16)
			if not ghost_mode:
				editor_camera.position.z = camera_distance
		elif event.button_index == MOUSE_BUTTON_LEFT and not _mouse_over_editor_ui():
			if event.pressed:
				_on_viewport_pressed(event.position)
			else:
				if resizing:
					_finish_resize()
				if moving_entity:
					_finish_move()
				if brush_painting:
					_finish_brush_stroke()
				if terrain_painting:
					_finish_terrain_stroke()
	elif event is InputEventMouseMotion:
		last_mouse_position = event.position
		if orbiting:
			camera_yaw.rotation.y -= event.relative.x * 0.008
			var pitch_min := deg_to_rad(-89.0)
			var pitch_max := deg_to_rad(89.0) if ghost_mode else deg_to_rad(70.0)
			camera_pitch.rotation.x = clampf(camera_pitch.rotation.x - event.relative.y * 0.008, pitch_min, pitch_max)
		elif panning:
			camera_target += (-camera_yaw.global_basis.x * event.relative.x + camera_pitch.global_basis.y * event.relative.y) * camera_distance * 0.0015
			camera_rig.position = camera_target
		elif resizing:
			_update_resize(event.position)
		elif moving_entity:
			_update_move(event.position)
		elif brush_painting and not _mouse_over_editor_ui():
			_continue_brush_stroke(event.position)
		elif terrain_painting and not _mouse_over_editor_ui():
			_continue_terrain_stroke(event.position)
	elif event is InputEventKey and event.pressed:
		if _shortcut_matches(event, "help"): _open_help()
		elif _shortcut_matches(event, "save"): _save_world()
		elif _shortcut_matches(event, "undo"): _undo()
		elif _shortcut_matches(event, "redo"): _redo()
		elif _shortcut_matches(event, "duplicate"): _duplicate_selected()
		elif _shortcut_matches(event, "delete"): _delete_selected()
		elif _shortcut_matches(event, "test"): _start_test()
		elif _shortcut_matches(event, "ghost"): _toggle_ghost_mode()
		elif _shortcut_matches(event, "rotate_x"): _begin_rotation(0)
		elif _shortcut_matches(event, "rotate_y"): _begin_rotation(1)
		elif _shortcut_matches(event, "return_lab"): _return_to_lab()
		elif _shortcut_matches(event, "select_tool"): _set_tool_mode("select")
		elif _shortcut_matches(event, "brush_tool"): _set_tool_mode("brush")
		elif _shortcut_matches(event, "eraser_tool"): _set_tool_mode("eraser")
		elif _shortcut_matches(event, "toggle_workspace"): _toggle_workspace_tab()
		elif _shortcut_matches(event, "focus"): _focus_selected()

func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "EditorCameraRig"
	add_child(camera_rig)
	camera_yaw = Node3D.new()
	camera_yaw.rotation.y = deg_to_rad(-42.0)
	camera_rig.add_child(camera_yaw)
	camera_pitch = Node3D.new()
	camera_pitch.rotation.x = deg_to_rad(-42.0)
	camera_yaw.add_child(camera_pitch)
	editor_camera = Camera3D.new()
	editor_camera.fov = 60.0
	editor_camera.near = 0.02
	editor_camera.far = 2000.0
	editor_camera.position.z = camera_distance
	editor_camera.current = true
	camera_pitch.add_child(editor_camera)

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(backdrop)
	# The Forge uses the same visual hierarchy as a desktop DCC: application
	# chrome, a compact command bar, persistent tools and docked workspaces.
	top_bar = _panel(Rect2(0, 0, 1280, 76), Color("15181d"))
	top_bar.anchor_right = 1.0
	top_bar.offset_right = 0.0
	canvas.add_child(top_bar)
	var top_stack := VBoxContainer.new()
	top_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_stack.add_theme_constant_override("separation", 0)
	top_bar.add_child(top_stack)
	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size.y = 30
	title_row.add_theme_constant_override("separation", 0)
	top_stack.add_child(title_row)
	var app_mark := _label(" H ", 15, Color("111317"))
	app_mark.custom_minimum_size = Vector2(34, 30)
	app_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	app_mark.add_theme_stylebox_override("normal", _flat_style(Color("c8893f"), Color("c8893f"), 0))
	title_row.add_child(app_mark)
	var brand := _label("  HOPLITE  /  WORLD FORGE", 13, Color("d8dde5"))
	brand.custom_minimum_size = Vector2(218, 30)
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(brand)
	var title_divider := VSeparator.new()
	title_row.add_child(title_divider)
	world_name = LineEdit.new()
	world_name.text = document.data.get("name", "Monde")
	world_name.custom_minimum_size = Vector2(250, 28)
	world_name.placeholder_text = "Nom du monde"
	world_name.text_submitted.connect(func(_text: String) -> void: _rename_world())
	world_name.focus_exited.connect(_rename_world)
	title_row.add_child(world_name)
	var title_spacer := Control.new()
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)
	var edition_badge := _label("●  MODE ÉDITION   ", 11, Color("70b7d1"))
	edition_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(edition_badge)

	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 46
	top.add_theme_constant_override("separation", 5)
	top_stack.add_child(top)
	var back_button := _button("‹  LABO", _return_to_lab, Color("252a31"))
	back_button.tooltip_text = "Quitter la Forge et revenir au laboratoire"
	top.add_child(back_button)
	left_panel_toggle_button = _button("▥  CONTENU", _toggle_left_panel, Color("252a31"))
	left_panel_toggle_button.tooltip_text = "Afficher ou masquer Construction"
	top.add_child(left_panel_toggle_button)
	right_panel_toggle_button = _button("▤  PROPRIÉTÉS", _toggle_right_panel, Color("252a31"))
	right_panel_toggle_button.tooltip_text = "Afficher ou masquer l'Inspecteur"
	top.add_child(right_panel_toggle_button)
	top.add_child(VSeparator.new())
	var new_button := _button("＋  NOUVEAU MONDE", _new_world, Color("303640"))
	new_button.tooltip_text = "Créer un nouveau monde vide"
	top.add_child(new_button)
	save_command_button = _button("SAUVEGARDER  Ctrl+S", _save_world, Color("8d5a2a"))
	save_command_button.tooltip_text = "Sauvegarder le monde courant"
	top.add_child(save_command_button)
	save_picker = OptionButton.new()
	save_picker.custom_minimum_size = Vector2(148, 30)
	save_picker.tooltip_text = "Mondes sauvegardés"
	top.add_child(save_picker)
	var load_button := _button("OUVRIR", _load_selected_world, Color("252a31"))
	load_button.tooltip_text = "Charger le monde sélectionné"
	top.add_child(load_button)
	top.add_child(VSeparator.new())
	undo_command_button = _button("↶", _undo, Color("252a31"))
	undo_command_button.tooltip_text = "Annuler  Ctrl+Z"
	top.add_child(undo_command_button)
	redo_command_button = _button("↷", _redo, Color("252a31"))
	redo_command_button.tooltip_text = "Rétablir  Ctrl+Y"
	top.add_child(redo_command_button)
	help_button = _button("?  AIDE  F1", _open_help, Color("2d4857"))
	help_button.tooltip_text = "Ouvrir le tutoriel, le wiki et les raccourcis personnalisables"
	top.add_child(help_button)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
	ghost_mode_button = _button("◎  NAVIGATION LIBRE  G", _toggle_ghost_mode, Color("303745"))
	top.add_child(ghost_mode_button)
	test_button = _button("▶  TESTER  F6", _start_test, Color("217765"))
	top.add_child(test_button)

	tool_rail = _panel(Rect2(0, 76, 56, 618), Color("181b20"))
	tool_rail.anchor_bottom = 1.0
	tool_rail.offset_bottom = -26.0
	canvas.add_child(tool_rail)
	var rail := VBoxContainer.new()
	rail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	rail.add_theme_constant_override("separation", 5)
	tool_rail.add_child(rail)
	var rail_title := _label("TOOLS", 9, Color("727b88"))
	rail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail.add_child(rail_title)
	select_tool_button = _tool_button("↖\nSELECT\n1", func() -> void: _set_tool_mode("select"), "Sélectionner et transformer  [1]")
	brush_tool_button = _tool_button("✚\nPLACE\n2", func() -> void: _set_tool_mode("brush"), "Placer ou peindre l'élément actif  [2]")
	eraser_tool_button = _tool_button("⌫\nERASE\n3", func() -> void: _set_tool_mode("eraser"), "Supprimer au clic  [3]")
	rail.add_child(select_tool_button)
	rail.add_child(brush_tool_button)
	rail.add_child(eraser_tool_button)
	rail.add_child(HSeparator.new())
	rail.add_child(_tool_button("◎\nFRAME\nF", _focus_selected, "Cadrer la sélection  [F]"))
	rail.add_child(_tool_button("◉\nFLY\nG", _toggle_ghost_mode, "Basculer la navigation libre  [G]"))

	left_panel = _panel(Rect2(56, 76, 320, 618), Color("1d2025"))
	left_panel.anchor_bottom = 1.0
	left_panel.offset_bottom = -26.0
	canvas.add_child(left_panel)
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	left.add_theme_constant_override("separation", 7)
	left_panel.add_child(left)
	var left_header := HBoxContainer.new()
	var content_titles := VBoxContainer.new()
	content_titles.add_theme_constant_override("separation", -3)
	content_titles.add_child(_label("CONTENU DU MONDE", 13, Color("e2e6ec")))
	content_titles.add_child(_label("CHAPITRES, ASSETS ET HIÉRARCHIE", 9, Color("747e8d")))
	left_header.add_child(content_titles)
	var left_header_spacer := Control.new(); left_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left_header.add_child(left_header_spacer)
	var left_close := _button("×", _toggle_left_panel, Color("25282e")); left_close.tooltip_text = "Fermer ce volet"; left_header.add_child(left_close)
	left.add_child(left_header)
	left.add_child(HSeparator.new())
	left.add_child(_section("MONDE ACTIF"))
	var chapter_row := HBoxContainer.new()
	chapter_row.add_child(_small_label("Chapitre"))
	chapter_picker = OptionButton.new()
	chapter_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_picker.item_selected.connect(_on_chapter_selected)
	chapter_row.add_child(chapter_picker)
	var add_chapter_button := _button("＋", _add_chapter, Color("285143"))
	add_chapter_button.tooltip_text = "Ajouter un chapitre vide"
	chapter_row.add_child(add_chapter_button)
	left.add_child(chapter_row)
	chapter_name_edit = LineEdit.new()
	chapter_name_edit.placeholder_text = "Renommer le chapitre…"
	chapter_name_edit.text_submitted.connect(func(_value: String) -> void: _rename_current_chapter())
	chapter_name_edit.focus_exited.connect(_rename_current_chapter)
	left.add_child(chapter_name_edit)
	var grid_row := HBoxContainer.new()
	grid_row.add_child(_small_label("Grille"))
	grid_size_picker = OptionButton.new()
	grid_size_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for grid_value: float in [0.5, 1.0, 2.0, 4.0]:
		grid_size_picker.add_item("%.1f m" % grid_value)
		grid_size_picker.set_item_metadata(grid_size_picker.item_count - 1, grid_value)
	grid_size_picker.select(1)
	grid_size_picker.item_selected.connect(_on_grid_size_selected)
	grid_row.add_child(grid_size_picker)
	left.add_child(grid_row)
	var extent_row := HBoxContainer.new()
	extent_row.add_child(_small_label("Étendue"))
	map_extent_picker = OptionButton.new()
	map_extent_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for extent_value: float in [60.0, 120.0, 250.0, 500.0]:
		map_extent_picker.add_item("%d × %d m" % [int(extent_value * 2.0), int(extent_value * 2.0)])
		map_extent_picker.set_item_metadata(map_extent_picker.item_count - 1, extent_value)
	map_extent_picker.item_selected.connect(_on_map_extent_selected)
	extent_row.add_child(map_extent_picker)
	left.add_child(extent_row)
	brush_label = _label("SÉLECTION  •  clic : choisir\nCtrl + glisser : plan  •  Maj + glisser : hauteur\nR : tourner  •  Maj+R : incliner", 11, Color("70b7d1"))
	brush_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brush_label.custom_minimum_size.y = 48
	brush_label.add_theme_stylebox_override("normal", _flat_style(Color("171a1f"), Color("30353d"), 3, 7))
	left.add_child(brush_label)
	workspace_tabs = TabContainer.new()
	workspace_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_tabs.add_theme_constant_override("side_margin", 0)
	left.add_child(workspace_tabs)
	var library_page := VBoxContainer.new()
	library_page.name = "BIBLIOTHÈQUE"
	library_page.add_theme_constant_override("separation", 8)
	workspace_tabs.add_child(library_page)
	var library_heading := _label("AJOUTER / PEINDRE", 9, Color("818b98"))
	library_heading.tooltip_text = "Choisissez le type d'élément à placer dans la vue 3D"
	library_page.add_child(library_heading)
	library_category = OptionButton.new()
	library_category.custom_minimum_size.y = 40
	library_category.add_theme_font_size_override("font_size", 12)
	library_category.add_theme_color_override("font_color", Color("f4f7fa"))
	library_category.add_theme_stylebox_override("normal", _flat_style(Color("31566a"), Color("70b7d1"), 3, 10))
	library_category.add_theme_stylebox_override("hover", _flat_style(Color("3a657b"), Color("8ec9dd"), 3, 10))
	library_category.add_theme_stylebox_override("pressed", _flat_style(Color("27495b"), Color("c8893f"), 3, 10))
	library_category.tooltip_text = "Catégorie d'éléments — les surfaces regroupent sols, murs et blocs"
	library_category.item_selected.connect(func(_index: int) -> void: _refresh_library())
	library_page.add_child(library_category)
	var library_scroll := ScrollContainer.new()
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library_items = VBoxContainer.new(); library_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_scroll.add_child(library_items); library_page.add_child(library_scroll)
	var hierarchy_page := VBoxContainer.new()
	hierarchy_page.name = "SCÈNE"
	hierarchy_page.add_theme_constant_override("separation", 8)
	workspace_tabs.add_child(hierarchy_page)
	hierarchy_filter = LineEdit.new(); hierarchy_filter.placeholder_text = "⌕  Filtrer les éléments…"
	hierarchy_filter.text_changed.connect(func(_text: String) -> void: _refresh_hierarchy())
	hierarchy_page.add_child(hierarchy_filter)
	hierarchy = Tree.new(); hierarchy.hide_root = true; hierarchy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hierarchy.item_selected.connect(_on_tree_selected)
	hierarchy_page.add_child(hierarchy)
	_refresh_library()

	right_panel = _panel(Rect2(942, 76, 338, 618), Color("1d2025"))
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -338.0
	right_panel.offset_right = 0.0
	right_panel.offset_bottom = -26.0
	canvas.add_child(right_panel)
	var right := VBoxContainer.new(); right.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	right_panel.add_child(right)
	var right_header := HBoxContainer.new()
	var inspector_titles := VBoxContainer.new()
	inspector_titles.add_theme_constant_override("separation", -3)
	inspector_titles.add_child(_label("PROPRIÉTÉS", 13, Color("e2e6ec")))
	inspector_titles.add_child(_label("SÉLECTION ET PARAMÈTRES", 9, Color("747e8d")))
	right_header.add_child(inspector_titles)
	var right_header_spacer := Control.new(); right_header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right_header.add_child(right_header_spacer)
	var right_close := _button("×", _toggle_right_panel, Color("25282e")); right_close.tooltip_text = "Fermer ce volet"; right_header.add_child(right_close)
	right.add_child(right_header)
	right.add_child(HSeparator.new())
	var inspector_scroll := ScrollContainer.new(); inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_content = VBoxContainer.new(); inspector_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_content.add_theme_constant_override("separation", 7)
	inspector_scroll.add_child(inspector_content); right.add_child(inspector_scroll)
	_rebuild_inspector()

	bottom_bar = _panel(Rect2(0, 694, 1280, 26), Color("15181d"))
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -26.0
	bottom_bar.offset_right = 0.0
	bottom_bar.offset_bottom = 0.0
	canvas.add_child(bottom_bar)
	var bottom := HBoxContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	bottom_bar.add_child(bottom)
	var ready_mark := _label("  ●  PRÊT ", 10, Color("72c7a7")); bottom.add_child(ready_mark)
	bottom.add_child(VSeparator.new())
	status_label = _label("Clic droit : orbite • Molette : zoom • Clic milieu : déplacer • F : cadrer", 11, Color("aeb6c2")); status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bottom.add_child(status_label)
	population_label = _label("0 mobs", 11, Color("72c7a7")); bottom.add_child(population_label)

	viewport_hud = _panel(Rect2(388, 88, 258, 32), Color(0.075, 0.084, 0.098, 0.92))
	var viewport_row := HBoxContainer.new()
	viewport_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	viewport_hud.add_child(viewport_row)
	viewport_row.add_child(_label("PERSPECTIVE", 10, Color("d3d9e2")))
	viewport_row.add_child(VSeparator.new())
	viewport_row.add_child(_label("●  ÉCLAIRÉ", 10, Color("70b7d1")))
	canvas.add_child(viewport_hud)

	rotation_overlay = _panel(Rect2(430, 88, 420, 52), Color(0.075, 0.084, 0.098, 0.97))
	rotation_overlay.visible = false
	canvas.add_child(rotation_overlay)
	rotation_label = _label("", 13, Color("e2a85f"))
	rotation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotation_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	rotation_overlay.add_child(rotation_label)

	_build_test_overlay()
	_apply_theme(canvas)
	_configure_library_categories()
	_refresh_chapter_picker()
	_build_help_center()

func _build_help_center() -> void:
	help_center = HelpCenterScript.new() as HopliteWorldEditorHelp
	help_center.name = "HelpCenter"
	canvas.add_child(help_center)
	help_center.shortcuts_changed.connect(func(_shortcuts: Dictionary) -> void:
		_refresh_shortcut_hints()
		_set_status("Raccourcis mis à jour et sauvegardés.")
	)
	_refresh_shortcut_hints()

func _open_help() -> void:
	if help_center == null:
		return
	help_center.open("start")

func _shortcut_matches(event: InputEventKey, action_id: String) -> bool:
	return help_center != null and help_center.matches(event, action_id)

func _shortcut_pressed(action_id: String) -> bool:
	return help_center != null and help_center.is_action_pressed(action_id)

func _shortcut_text(action_id: String, fallback: String) -> String:
	return help_center.binding_text(action_id) if help_center != null else fallback

func _refresh_shortcut_hints() -> void:
	if save_command_button != null:
		save_command_button.text = "SAUVEGARDER  %s" % _shortcut_text("save", "Ctrl+S")
	if undo_command_button != null:
		undo_command_button.tooltip_text = "Annuler  %s" % _shortcut_text("undo", "Ctrl+Z")
	if redo_command_button != null:
		redo_command_button.tooltip_text = "Rétablir  %s" % _shortcut_text("redo", "Ctrl+Y")
	if help_button != null:
		help_button.text = "?  AIDE  %s" % _shortcut_text("help", "F1")
	if test_button != null:
		test_button.text = "▶  TESTER  %s" % _shortcut_text("test", "F6")
	if select_tool_button != null:
		select_tool_button.text = "↖\nSELECT\n%s" % _shortcut_text("select_tool", "1")
	if brush_tool_button != null:
		brush_tool_button.text = "✚\nPLACE\n%s" % _shortcut_text("brush_tool", "2")
	if eraser_tool_button != null:
		eraser_tool_button.text = "⌫\nERASE\n%s" % _shortcut_text("eraser_tool", "3")
	_update_mode_buttons()

func _build_test_overlay() -> void:
	test_overlay = _panel(Rect2(0, 0, 1280, 52), Color("15191e"))
	test_overlay.anchor_right = 1.0
	test_overlay.offset_right = 0.0
	test_overlay.visible = false; canvas.add_child(test_overlay)
	var row := HBoxContainer.new(); row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8); test_overlay.add_child(row)
	row.add_child(_label("  ▶  SIMULATION LOCALE", 14, Color("72c7a7")))
	row.add_child(VSeparator.new())
	test_status = _label("", 12, Color("d9dee6")); test_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL; test_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; row.add_child(test_status)
	row.add_child(_button("■  ARRÊTER  Échap", _stop_test, Color("8a3f42")))
	narrative_panel = _panel(Rect2(300, 550, 680, 120), Color(0.055, 0.061, 0.072, 0.97)); narrative_panel.visible = false; canvas.add_child(narrative_panel)
	var narrative := VBoxContainer.new(); narrative.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14); narrative_panel.add_child(narrative)
	narrative_speaker = _label("NARRATEUR", 17, Color("e9b96e")); narrative.add_child(narrative_speaker)
	narrative_text = _label("", 18, Color.WHITE); narrative_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; narrative.add_child(narrative_text)
	narrative_timer = Timer.new(); narrative_timer.one_shot = true; narrative_timer.timeout.connect(func() -> void: narrative_panel.visible = false); add_child(narrative_timer)

func _toggle_workspace_tab() -> void:
	if workspace_tabs != null:
		workspace_tabs.current_tab = 1 - workspace_tabs.current_tab

func _toggle_ghost_mode() -> void:
	_set_ghost_mode(not ghost_mode)

func _toggle_left_panel() -> void:
	left_panel_open = not left_panel_open
	if left_panel != null:
		left_panel.visible = left_panel_open
	if left_panel_toggle_button != null:
		left_panel_toggle_button.modulate = Color.WHITE if left_panel_open else Color("70b7d1")

func _toggle_right_panel() -> void:
	right_panel_open = not right_panel_open
	if right_panel != null:
		right_panel.visible = right_panel_open
	if right_panel_toggle_button != null:
		right_panel_toggle_button.modulate = Color.WHITE if right_panel_open else Color("70b7d1")

func _set_ghost_mode(enabled: bool) -> void:
	if ghost_mode == enabled:
		return
	brush_painting = false
	resizing = false
	moving_entity = false
	_update_ground_snap_marker({})
	var camera_position := editor_camera.global_position
	var forward := -editor_camera.global_basis.z
	ghost_mode = enabled
	if ghost_mode:
		camera_target = camera_position
		camera_rig.global_position = camera_position
		editor_camera.position = Vector3.ZERO
		_set_status("MODE FANTOME — ZQSD/WASD : voler • Espace/E : monter • C : descendre • clic droit : regarder • clic gauche : editer.")
	else:
		camera_target = camera_position + forward * camera_distance
		camera_rig.global_position = camera_target
		editor_camera.position = Vector3(0.0, 0.0, camera_distance)
		camera_pitch.rotation.x = clampf(camera_pitch.rotation.x, deg_to_rad(-89.0), deg_to_rad(70.0))
		_set_status("VUE ORBITE — clic droit : tourner • clic milieu : deplacer • molette : zoom • G : mode fantome.")
	_update_mode_buttons()
	_update_selection_marker()

func _on_grid_size_selected(index: int) -> void:
	var value := float(grid_size_picker.get_item_metadata(index))
	(document.data.get("settings", {}) as Dictionary)["grid_size"] = value
	grid.set_grid_size(value)
	dirty = true
	_set_status("Pas de grille : %.1f m. Placements et redimensionnements sont maintenant aimantes a ce pas." % value)

func _on_map_extent_selected(index: int) -> void:
	var value := float(map_extent_picker.get_item_metadata(index))
	(document.data.get("settings", {}) as Dictionary)["map_half_extent"] = value
	grid.set_half_extent(value)
	dirty = true
	_set_status("Carte agrandie : %d × %d metres." % [int(value * 2.0), int(value * 2.0)])

func _refresh_chapter_picker() -> void:
	if chapter_picker == null:
		return
	chapter_picker.clear()
	var selected_index := 0
	for index in range(document.chapters().size()):
		var chapter := document.chapters()[index] as Dictionary
		chapter_picker.add_item(String(chapter.get("name", chapter.get("id", "Chapitre"))))
		chapter_picker.set_item_metadata(index, String(chapter.get("id", "")))
		if String(chapter.get("id", "")) == active_chapter_id:
			selected_index = index
	chapter_picker.select(selected_index)
	if chapter_picker.item_count > 0:
		active_chapter_id = String(chapter_picker.get_item_metadata(selected_index))
	if chapter_name_edit != null:
		chapter_name_edit.text = _chapter_name(active_chapter_id)
	if map_extent_picker != null:
		var extent := float((document.data.get("settings", {}) as Dictionary).get("map_half_extent", 60.0))
		for index in range(map_extent_picker.item_count):
			if is_equal_approx(float(map_extent_picker.get_item_metadata(index)), extent):
				map_extent_picker.select(index)
				break

func _on_chapter_selected(index: int) -> void:
	if index < 0 or index >= chapter_picker.item_count:
		return
	active_chapter_id = String(chapter_picker.get_item_metadata(index))
	selected_id = ""
	chapter_name_edit.text = _chapter_name(active_chapter_id)
	_rebuild_preview()
	_set_status("Chapitre ouvert dans la Forge : %s" % _chapter_name(active_chapter_id))

func _add_chapter() -> void:
	_push_undo()
	var chapter_number := document.chapters().size() + 1
	var chapter_id := "chapter_%d_%d" % [chapter_number, Time.get_ticks_msec() % 100000]
	(document.data["chapters"] as Array).append({"id": chapter_id, "name": "Chapitre %d" % chapter_number})
	active_chapter_id = chapter_id
	selected_id = ""
	dirty = true
	_refresh_chapter_picker()
	_rebuild_preview()
	_set_status("Nouveau chapitre vide cree. Ajoutez un depart joueur et reliez-le avec un passage.")

func _rename_current_chapter() -> void:
	if chapter_name_edit == null:
		return
	var value := chapter_name_edit.text.strip_edges()
	if value.is_empty():
		chapter_name_edit.text = _chapter_name(active_chapter_id)
		return
	for raw: Variant in document.chapters():
		var chapter := raw as Dictionary
		if String(chapter.get("id", "")) == active_chapter_id and String(chapter.get("name", "")) != value:
			_push_undo()
			chapter["name"] = value
			dirty = true
			_refresh_chapter_picker()
			return

func _chapter_name(chapter_id: String) -> String:
	for raw: Variant in document.chapters():
		var chapter := raw as Dictionary
		if String(chapter.get("id", "")) == chapter_id:
			return String(chapter.get("name", chapter_id))
	return chapter_id

func _chapter_exists(chapter_id: String) -> bool:
	for raw: Variant in document.chapters():
		if String((raw as Dictionary).get("id", "")) == chapter_id:
			return true
	return false

func _chapter_entities() -> Array[Dictionary]:
	return document.entities_for_chapter(active_chapter_id)

func _set_tool_mode(value: String) -> void:
	tool_mode = value
	resizing = false
	moving_entity = false
	terrain_painting = false
	_update_ground_snap_marker({})
	_update_mode_buttons()
	if brush_label != null:
		match tool_mode:
			"brush": brush_label.text = "PINCEAU  •  %s\nMaintenez le clic pour tracer  •  Maj : ligne" % brush_title
			"eraser": brush_label.text = "GOMME  •  survolez puis cliquez\nLa cible devient rouge avant suppression"
			"terrain": brush_label.text = "TERRAIN  •  %s\nClic-glisse : appliquer le pinceau" % _terrain_tool_label(terrain_tool)
			_: brush_label.text = "SÉLECTION  •  clic : choisir\nCtrl + glisser : plan  •  Maj + glisser : hauteur\nR : tourner  •  Maj+R : incliner"
	if brush_cursor != null:
		brush_cursor.visible = tool_mode == "brush"
	if terrain_brush_marker != null:
		terrain_brush_marker.visible = false
	_update_selection_marker()

func _update_mode_buttons() -> void:
	if select_tool_button != null:
		select_tool_button.modulate = Color.WHITE if tool_mode == "select" else Color(0.52, 0.57, 0.64)
		brush_tool_button.modulate = Color.WHITE if tool_mode == "brush" else Color(0.52, 0.57, 0.64)
		eraser_tool_button.modulate = Color.WHITE if tool_mode == "eraser" else Color(0.52, 0.57, 0.64)
	if ghost_mode_button != null:
		var ghost_shortcut := _shortcut_text("ghost", "G")
		ghost_mode_button.text = ("●  NAVIGATION LIBRE  %s" if ghost_mode else "◎  NAVIGATION LIBRE  %s") % ghost_shortcut
		ghost_mode_button.modulate = Color("72c7a7") if ghost_mode else Color(0.76, 0.79, 0.84)

func _entity_matches_mode(entity: Dictionary) -> bool:
	return not entity.is_empty()

func _refresh_library() -> void:
	for child in library_items.get_children(): child.queue_free()
	match library_category.selected:
		0:
			_add_terrain_builder()
		1:
			_add_surface_brush_builder()
			library_items.add_child(_section("PREREGLAGES RAPIDES"))
			_library_button("▰  SOL  4 × 4", "surface", {"shape": "floor", "size": [4.0, 0.35, 4.0], "material": active_material})
			_library_button("▥  MUR  4 × 3", "surface", {"shape": "wall", "size": [4.0, 3.0, 0.35], "material": active_material})
			_library_button("◼  BLOC  2 × 2 × 2", "surface", {"shape": "block", "size": [2.0, 2.0, 2.0], "material": active_material})
			var hint := _label("Choisissez une forme, puis cliquez dans la grille. Selectionnez-la ensuite pour tirer ses poignees.", 12, Color("8f9db2"))
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			library_items.add_child(hint)
		2:
			for material: String in MATERIALS:
				_add_material_card(material)
		3:
			var placeable_count := automatic_assets.filter(func(entry: Dictionary) -> bool: return StringName(entry.get("category", &"environment")) != &"characters").size()
			var count_label := _label("%d MODÈLES 3D • CLASSÉS PAR DOSSIER" % placeable_count, 11, Color("68d9b6"))
			library_items.add_child(count_label)
			_add_automatic_asset_folders()
		4:
			var troop_hint := _label("Placez une troupe comme un bloc, puis configurez son comportement et son apparition dans l'inspecteur.", 12, Color("9aaac1"))
			troop_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			library_items.add_child(troop_hint)
			_library_button("♟  TROUPE ENNEMIE — 6 soldats", "enemy_group", {"group_id": "nouvelle_troupe", "archetype": "nathenian1", "count": 6, "rank": "normal", "size_multiplier": 1.0, "match_perfect_hitbox": false, "behavior": "normal", "route_id": "", "protect_target": "", "spawn_condition": "start", "spawn_trigger": "", "spawn_dead_group": "", "spawn_delay": 3.0, "deployment_mode": "all", "formation": "line"})
			_library_button("▦  PHALANGE 15 — 4 veterans + 11 lanciers", "enemy_group", {"group_id": "phalange_mixte", "archetype": "ngeneral", "count": 15, "composition": [{"archetype": "ngeneral", "count": 11}, {"archetype": "ngeneral_veteran", "count": 4}], "rank": "normal", "size_multiplier": 1.0, "match_perfect_hitbox": false, "behavior": "normal", "route_id": "", "protect_target": "", "spawn_condition": "start", "spawn_trigger": "", "spawn_dead_group": "", "spawn_delay": 3.0, "deployment_mode": "all", "formation": "phalanx"})
			library_items.add_child(_section("GEANTS ESCALADABLES — SOLO / PETIT GROUPE"))
			for archetype: StringName in EnemyArchetypesScript.giant_ids():
				var profile := EnemyArchetypesScript.profile(archetype)
				_library_button("♜  %s" % String(profile.get("display_name", String(archetype))).capitalize(), "enemy_group", {"group_id": "groupe_%s" % String(archetype), "archetype": String(archetype), "count": 1, "rank": "normal", "size_multiplier": 1.0, "match_perfect_hitbox": bool(profile.get("forge_default_match_perfect_hitbox", true)), "giant_traversal_mode": "assisted", "giant_capsule_radius_multiplier": 0.90, "giant_capsule_height_multiplier": 1.0, "giant_walkable_tops": true, "behavior": "normal", "route_id": "", "protect_target": "", "spawn_condition": "start", "spawn_trigger": "", "spawn_dead_group": "", "spawn_delay": 3.0, "deployment_mode": "all", "formation": "line"})
			library_items.add_child(_section("AUTRES PERSONNAGES"))
			for archetype: StringName in EnemyArchetypesScript.all_ids():
				if EnemyArchetypesScript.is_giant(archetype):
					continue
				var profile := EnemyArchetypesScript.profile(archetype)
				_library_button("♙  %s" % String(profile.get("display_name", String(archetype))).capitalize(), "enemy_group", {"group_id": "groupe_%s" % String(archetype), "archetype": String(archetype), "count": 1, "rank": "miniboss" if EnemyArchetypesScript.is_miniboss(archetype) or EnemyArchetypesScript.is_boss(archetype) else "normal", "size_multiplier": 1.0, "match_perfect_hitbox": false, "behavior": "normal", "route_id": "", "protect_target": "", "spawn_condition": "start", "spawn_trigger": "", "spawn_dead_group": "", "spawn_delay": 3.0, "deployment_mode": "all", "formation": "line"})
			_library_button("⌖  Depart joueur", "player_spawn", {"radius": 1.0})
		5:
			var trigger_hint := _label("Les declencheurs sont des volumes invisibles en jeu. Leur nom peut aussi servir de reference aux troupes.", 12, Color("9aaac1"))
			trigger_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			library_items.add_child(trigger_hint)
			_library_button("◇  Point de patrouille", "patrol_point", {"route_id": "route_1", "order": 0, "wait": 1.0})
			_library_button("⬡  DECLENCHEUR — zone joueur", "trigger", {"size": [6.0, 3.0, 6.0], "condition": "player_enter", "condition_group": "", "threshold": 100.0, "action": "none", "action_target": "", "action_text": "", "action_speaker": "Narrateur", "action_duration": 4.0, "music_path": "", "once": true})
			_library_button("✦  Texte reutilisable (ne se declenche pas seul)", "narrative", {"speaker": "Narrateur", "text": "Votre texte...", "duration": 4.0})
			_library_button("▱  Zone d'atmosphere", "atmosphere_zone", {"size": [12.0, 5.0, 12.0], "preset": "Siege enfume", "sun_energy": 0.66, "ambient_energy": 0.42, "fog_density": 0.027})
		6:
			var door_hint := _label("Les portes peuvent etre ouvertes par n'importe quel declencheur. Choisissez ensuite leur style, leur taille et leur mouvement dans l'inspecteur.", 12, Color("9aaac1"))
			door_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			library_items.add_child(door_hint)
			_library_button("▥  PORTE BOIS — pivot gauche", "door", {"size": [3.0, 4.0, 0.45], "door_style": "wood", "open_motion": "pivot_left", "open_duration": 1.1, "starts_open": false})
			_library_button("▦  HERSE DE FER — verticale", "door", {"size": [4.0, 5.0, 0.55], "door_style": "iron", "open_motion": "vertical", "open_duration": 1.5, "starts_open": false})
			_library_button("▰  PORTE DE PIERRE — coulissante", "door", {"size": [4.5, 5.0, 0.7], "door_style": "stone", "open_motion": "slide_left", "open_duration": 1.8, "starts_open": false})
			_library_button("◈  PORTE DE BRONZE — pivot droit", "door", {"size": [3.5, 4.5, 0.5], "door_style": "bronze", "open_motion": "pivot_right", "open_duration": 1.25, "starts_open": false})
			library_items.add_child(_section("CHARGEMENT DE CHAPITRE"))
			_library_button("◉  Passage vers un chapitre", "chapter_portal", {"size": [3.0, 3.0, 1.5], "destination_chapter": "", "destination_spawn": "", "label": "CHAPITRE SUIVANT"})
			_library_button("⌖  Point d'arrivee / depart", "player_spawn", {"radius": 1.0, "spawn_id": "arrivee"})
		7:
			_library_button("☀  Lumiere omnidirectionnelle", "light", {"light_type": "omni", "color": "#ffb36b", "energy": 2.0, "range": 12.0, "shadows": false})
			_library_button("⌁  Projecteur", "light", {"light_type": "spot", "color": "#fff0d0", "energy": 3.0, "range": 18.0, "angle": 42.0, "shadows": true})

func _configure_library_categories() -> void:
	if library_category == null:
		return
	library_category.clear()
	var categories := [
		"⌁  TERRAIN — CRÉER & SCULPTER",
		"▰  SURFACES — SOLS, MURS, BLOCS",
		"▦  TEXTURES & MATÉRIAUX",
		"◆  OBJETS 3D",
		"♟  PERSONNAGES",
		"⬡  LOGIQUE & NARRATION",
		"▥  PORTES & CHAPITRES",
		"☀  LUMIÈRES",
	]
	for category: String in categories:
		library_category.add_item(category)
	library_category.select(0)
	_refresh_library()

func _add_automatic_asset_folders() -> void:
	var grouped: Dictionary = {}
	for entry: Dictionary in automatic_assets:
		if StringName(entry.get("category", &"environment")) == &"characters":
			continue
		var subcategory := StringName(entry.get("subcategory", &"decor"))
		if not grouped.has(subcategory):
			grouped[subcategory] = []
		(grouped[subcategory] as Array).append(entry)
	var folder_index := 0
	for subcategory: StringName in AssetLibraryRoomScript.SUBCATEGORY_ORDER:
		var entries := grouped.get(subcategory, []) as Array
		if entries.is_empty():
			continue
		var folder := FoldableContainer.new()
		folder.title = "%s  (%d)" % [String(AssetLibraryRoomScript.SUBCATEGORY_LABELS.get(subcategory, "DÉCORS & OBJETS")), entries.size()]
		folder.folded = folder_index > 1
		folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 4)
		folder.add_child(content)
		library_items.add_child(folder)
		for raw: Variant in entries:
			_add_asset_folder_button(content, raw as Dictionary)
		folder_index += 1

func _add_asset_folder_button(parent: VBoxContainer, entry: Dictionary) -> void:
	var display_name := String(entry.get("display_name", "Objet"))
	var asset_properties := {
		"asset_path": String(entry.get("path", "")),
		"asset_label": display_name,
		"target_height": float(entry.get("target_height", 2.0)),
		"brush_spacing": float(entry.get("brush_spacing", 1.0)),
	}
	var button := _button("◆  %s" % display_name, func() -> void: _select_brush("◆  %s" % display_name, "prop", asset_properties))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.tooltip_text = "%s\nHauteur initiale : %.2f m • espacement : %.2f m" % [display_name, float(asset_properties["target_height"]), float(asset_properties["brush_spacing"])]
	parent.add_child(button)

func _add_terrain_builder() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat_style(Color("222b2a"), Color("72c7a7"), 4, 9))
	library_items.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	content.add_child(_label("TERRAIN NATIF GODOT", 12, Color("8ee0bd")))
	var intro := _label("Un heightfield par chapitre : relief, collision et texture restent synchronises dans la Forge et en test.", 10, Color("b8c5c3"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var terrain := _active_terrain()
	if terrain.is_empty():
		content.add_child(_label("Aucun terrain dans ce chapitre. Choisissez une base reproductible :", 10, Color("e2a85f")))
	else:
		var selected_name := String(terrain.get("name", "Terrain"))
		content.add_child(_button("◎  SELECTIONNER  %s" % selected_name, func() -> void: _select_terrain_entity(terrain), Color("31566a")))
		var replace_hint := _label("Les prereglages ci-dessous regenerent ce terrain. Ctrl+Z restaure le relief precedent.", 10, Color("9aaac1"))
		replace_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(replace_hint)
	content.add_child(_button("▰  PLAINE 64 × 64 m", func() -> void: _create_terrain_preset("flat", "Plaine", "cracked_weeds", 0.0), Color("355447")))
	content.add_child(_button("⌁  COLLINES 64 × 64 m", func() -> void: _create_terrain_preset("rolling", "Collines", "dirt_path", 7.0), Color("355447")))
	content.add_child(_button("╱  CRETES 64 × 64 m", func() -> void: _create_terrain_preset("ridge", "Cretes", "rough_stone", 10.0), Color("355447")))
	content.add_child(_button("∨  VALLEE 64 × 64 m", func() -> void: _create_terrain_preset("valley", "Vallee", "scorched_ground", 9.0), Color("355447")))
	content.add_child(_button("≈  COTE 64 × 64 m", func() -> void: _create_terrain_preset("coast", "Cote", "sandstone_floor", 8.0), Color("355447")))
	if terrain.is_empty():
		return
	library_items.add_child(_section("SCULPTURE DIRECTE"))
	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 5)
	tools.add_theme_constant_override("v_separation", 5)
	library_items.add_child(tools)
	for definition: Dictionary in [
		{"mode": "raise", "label": "▲ Monter"},
		{"mode": "lower", "label": "▼ Creuser"},
		{"mode": "smooth", "label": "≈ Lisser"},
		{"mode": "flatten", "label": "▬ Aplanir"},
	]:
		var mode := String(definition["mode"])
		var button := _button(String(definition["label"]), func() -> void: _set_terrain_tool(mode), Color("356155") if terrain_tool == mode and tool_mode == "terrain" else Color("293b38"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(button)
	var radius_row := HBoxContainer.new()
	radius_row.add_child(_small_label("Rayon"))
	var radius_spin := _spin(terrain_brush_radius, 0.5, 24.0, 0.5)
	radius_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_spin.value_changed.connect(func(value: float) -> void: terrain_brush_radius = value)
	radius_row.add_child(radius_spin)
	library_items.add_child(radius_row)
	var strength_row := HBoxContainer.new()
	strength_row.add_child(_small_label("Force"))
	var strength_spin := _spin(terrain_brush_strength, 0.05, 4.0, 0.05)
	strength_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength_spin.value_changed.connect(func(value: float) -> void: terrain_brush_strength = value)
	strength_row.add_child(strength_spin)
	library_items.add_child(strength_row)
	var sculpt_hint := _label("Clic-glisse sur le terrain. Maj inverse Monter/Creuser. Aplanir prend la hauteur du premier clic.", 10, Color("9aaac1"))
	sculpt_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_items.add_child(sculpt_hint)
	library_items.add_child(_section("TEXTURE LOCALE"))
	var paint_hint := _label("Texture du pinceau : %s. Choisissez-en une dans Textures & matériaux, puis peignez seulement la zone souhaitée." % active_material.replace("_", " ").capitalize(), 10, Color("aebbd0"))
	paint_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_items.add_child(paint_hint)
	var paint_row := HBoxContainer.new()
	paint_row.add_theme_constant_override("separation", 5)
	var paint_button := _button("▦  PEINDRE", func() -> void: _set_terrain_tool("paint"), Color("356155") if terrain_tool == "paint" and tool_mode == "terrain" else Color("293b38"))
	paint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_row.add_child(paint_button)
	var erase_paint_button := _button("⌫  EFFACER", func() -> void: _set_terrain_tool("erase_material"), Color("60453b") if terrain_tool == "erase_material" and tool_mode == "terrain" else Color("342d2c"))
	erase_paint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_row.add_child(erase_paint_button)
	library_items.add_child(paint_row)
	library_items.add_child(_section("VEGETATION MULTIMESH"))
	_add_foliage_brush_picker(library_items)
	_add_library_brush_number("Rayon végétation", terrain_brush_radius, 0.5, 48.0, 0.5, func(value: float) -> void: terrain_brush_radius = value)
	_add_library_brush_number("Force / densité", terrain_brush_strength, 0.05, 4.0, 0.05, func(value: float) -> void: terrain_brush_strength = value)
	var foliage_row := HBoxContainer.new()
	foliage_row.add_theme_constant_override("separation", 5)
	var foliage_button := _button("♒  PEINDRE %s" % _foliage_display_name(active_foliage_preset).to_upper(), func() -> void: _set_terrain_tool("foliage"), Color("356155") if terrain_tool == "foliage" and tool_mode == "terrain" else Color("293b38"))
	foliage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foliage_row.add_child(foliage_button)
	var erase_foliage_button := _button("⌫  RETIRER", func() -> void: _set_terrain_tool("erase_foliage"), Color("60453b") if terrain_tool == "erase_foliage" and tool_mode == "terrain" else Color("342d2c"))
	erase_foliage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foliage_row.add_child(erase_foliage_button)
	library_items.add_child(foliage_row)
	var foliage_hint := _label("Chaque type peint est regroupé dans un MultiMesh : un draw call par type utilisé, sans créer un nœud par brin.", 10, Color("8ee0bd"))
	foliage_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_items.add_child(foliage_hint)

func _add_foliage_brush_picker(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_child(_small_label("Type local"))
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for preset: String in WorldTerrainScript.FOLIAGE_PRESETS:
		picker.add_item(_foliage_display_name(preset))
		picker.set_item_metadata(picker.item_count - 1, preset)
		if preset == active_foliage_preset:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int) -> void: _set_foliage_brush(String(picker.get_item_metadata(index))))
	row.add_child(picker)
	parent.add_child(row)

func _add_library_brush_number(title: String, value: float, minimum: float, maximum: float, step: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_child(_small_label(title))
	var spin := _spin(value, minimum, maximum, step)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(callback)
	row.add_child(spin)
	library_items.add_child(row)

func _set_foliage_brush(preset: String) -> void:
	if preset not in WorldTerrainScript.FOLIAGE_PRESETS:
		return
	active_foliage_preset = preset
	terrain_tool = "foliage"
	_set_tool_mode("terrain")
	_refresh_library()
	_set_status("VÉGÉTATION : %s • rayon %.1f m • force %.2f" % [_foliage_display_name(preset), terrain_brush_radius, terrain_brush_strength])

func _foliage_display_name(preset: String) -> String:
	return {
		"mediterranean_grass": "Herbe méditerranéenne",
		"wild_grass": "Herbes hautes",
		"clover": "Trèfles",
		"flowers": "Fleurs sauvages",
		"ferns": "Fougères",
		"shrubs": "Buissons",
		"mushrooms": "Champignons",
	}.get(preset, preset.replace("_", " ").capitalize())

func _active_terrain() -> Dictionary:
	var selected := document.find_entity(selected_id)
	if String(selected.get("type", "")) == "terrain":
		return selected
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		if String(entity.get("type", "")) == "terrain":
			return entity
	return {}

func _select_terrain_entity(terrain: Dictionary) -> void:
	if terrain.is_empty():
		return
	selected_id = String(terrain.get("id", ""))
	_refresh_hierarchy()
	_rebuild_inspector()
	_update_selection_marker()
	_focus_selected()

func _create_terrain_preset(generator: String, label: String, material: String, amplitude: float) -> void:
	_push_undo()
	var terrain := _active_terrain()
	var properties := WorldTerrainScript.default_properties(generator, WorldTerrainScript.DEFAULT_RESOLUTION, 1337)
	properties["material"] = material
	properties["amplitude"] = amplitude
	WorldTerrainScript.regenerate(properties)
	if terrain.is_empty():
		var position := camera_target
		var grid_value := float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0))
		position.x = snappedf(position.x, grid_value)
		position.y = 0.0
		position.z = snappedf(position.z, grid_value)
		terrain = WorldDocumentScript.entity("terrain", "Terrain — %s" % label, position, properties)
		terrain["chapter"] = active_chapter_id
		selected_id = document.add_entity(terrain)
	else:
		terrain["name"] = "Terrain — %s" % label
		terrain["properties"] = properties
		selected_id = String(terrain.get("id", ""))
	dirty = true
	_rebuild_preview()
	_refresh_library()
	_set_status("Terrain %s pret. Choisissez Monter, Creuser, Lisser ou Aplanir." % label.to_lower())

func _set_terrain_tool(mode: String) -> void:
	var terrain := _active_terrain()
	if terrain.is_empty():
		_set_status("Creez d'abord un terrain dans ce chapitre.", true)
		return
	selected_id = String(terrain.get("id", ""))
	terrain_tool = mode if mode in WorldTerrainScript.SCULPT_MODES or mode in WorldTerrainScript.PAINT_MODES else "raise"
	_set_tool_mode("terrain")
	_refresh_hierarchy()
	_rebuild_inspector()
	_refresh_library()
	_set_status("TERRAIN %s — clic-glisse sur le terrain." % _terrain_tool_label(terrain_tool).to_upper())

func _terrain_tool_label(mode: String) -> String:
	return {
		"raise": "Monter", "lower": "Creuser", "smooth": "Lisser", "flatten": "Aplanir",
		"paint": "Peindre %s" % active_material.replace("_", " "), "erase_material": "Effacer texture",
		"foliage": "Peindre %s" % _foliage_display_name(active_foliage_preset), "erase_foliage": "Effacer végétation",
	}.get(mode, "Sculpter")

func _add_material_card(material: String) -> void:
	var material_id := material
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat_style(Color("20252c"), Color("35536b") if material_id == active_material else Color("303741"), 3, 5))
	library_items.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	card.add_child(row)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(58, 44)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var preview_path := _material_preview_path(material_id)
	if not preview_path.is_empty():
		preview.texture = load(preview_path) as Texture2D
	row.add_child(preview)
	var prefix := "✓ " if material_id == active_material else "▦ "
	var button := _button(prefix + material_id.replace("_", " ").capitalize(), func() -> void: _select_material(material_id), Color("35536b") if material_id == active_material else Color("26344b"))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)

func _material_preview_path(style: String) -> String:
	var direct_path := MaterialLibraryScript.preview_path(StringName(style))
	if not direct_path.is_empty():
		return direct_path
	for filename: Variant in AssetCatalogScript.TEXTURES.keys():
		var definition := AssetCatalogScript.TEXTURES[filename] as Dictionary
		if String(definition.get("style", "")) == style:
			return MaterialLibraryScript.TEXTURE_ROOT + "/" + String(filename)
	return ""

func _add_surface_brush_builder() -> void:
	var surface_panel := PanelContainer.new()
	surface_panel.add_theme_stylebox_override("panel", _flat_style(Color("242a31"), Color("c8893f"), 4, 9))
	surface_panel.tooltip_text = "Outil principal de construction : créez rapidement un sol, un mur ou un bloc"
	library_items.add_child(surface_panel)
	var surface_content := VBoxContainer.new()
	surface_content.add_theme_constant_override("separation", 7)
	surface_panel.add_child(surface_content)
	var surface_title := HBoxContainer.new()
	var surface_icon := _label("▰", 20, Color("e2a85f"))
	surface_icon.custom_minimum_size.x = 28
	surface_title.add_child(surface_icon)
	var surface_titles := VBoxContainer.new()
	surface_titles.add_theme_constant_override("separation", -3)
	surface_titles.add_child(_label("CONSTRUCTEUR DE SURFACE", 11, Color("f0f2f5")))
	surface_titles.add_child(_label("OUTIL PRINCIPAL · SOL / MUR / BLOC", 9, Color("e2a85f")))
	surface_title.add_child(surface_titles)
	surface_content.add_child(surface_title)
	var surface_hint := _label("Définissez la forme et ses dimensions, puis activez le pinceau.", 10, Color("aeb6c2"))
	surface_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	surface_content.add_child(surface_hint)
	surface_content.add_child(HSeparator.new())
	var shape_row := HBoxContainer.new()
	shape_row.add_child(_small_label("Forme"))
	var shape_picker := OptionButton.new()
	shape_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shapes := [{"label": "Sol", "value": "floor"}, {"label": "Mur", "value": "wall"}, {"label": "Bloc", "value": "block"}]
	var selected_shape := 0
	for index in range(shapes.size()):
		var shape := shapes[index] as Dictionary
		shape_picker.add_item(String(shape.get("label", "Bloc")))
		shape_picker.set_item_metadata(index, String(shape.get("value", "block")))
		if String(shape.get("value", "")) == surface_brush_shape:
			selected_shape = index
	shape_picker.select(selected_shape)
	shape_picker.item_selected.connect(func(index: int) -> void:
		surface_brush_shape = String(shape_picker.get_item_metadata(index))
		if brush_type == "surface":
			brush_properties["shape"] = surface_brush_shape
	)
	shape_row.add_child(shape_picker)
	surface_content.add_child(shape_row)
	var dimension_box := VBoxContainer.new()
	dimension_box.add_child(_small_label("Dimensions"))
	var dimension_row := HBoxContainer.new()
	var axis_names := ["X — largeur", "Y — hauteur", "Z — profondeur"]
	for axis in range(3):
		var component := axis
		var axis_box := VBoxContainer.new()
		axis_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var axis_label := _label(String(axis_names[axis]), 10, Color("9aaac1"))
		axis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		axis_box.add_child(axis_label)
		var spin := _spin(surface_brush_size[component], 0.05, 500.0, 0.05)
		spin.value_changed.connect(func(value: float) -> void:
			surface_brush_size[component] = maxf(0.05, value)
			if brush_type == "surface":
				brush_properties["size"] = WorldDocumentScript.array3(surface_brush_size)
		)
		axis_box.add_child(spin)
		dimension_row.add_child(axis_box)
	dimension_box.add_child(dimension_row)
	surface_content.add_child(dimension_box)
	var equip_button := _button("✚  ACTIVER LE PINCEAU SURFACE  [2]", _equip_custom_surface_brush, Color("a56931"))
	equip_button.custom_minimum_size.y = 38
	equip_button.add_theme_font_size_override("font_size", 11)
	equip_button.tooltip_text = "Activer cette surface, puis cliquer ou tracer dans la vue 3D"
	surface_content.add_child(equip_button)

func _equip_custom_surface_brush() -> void:
	var names := {"floor": "Sol personnalise", "wall": "Mur personnalise", "block": "Bloc personnalise"}
	_select_brush(String(names.get(surface_brush_shape, "Surface personnalisee")), "surface", {"shape": surface_brush_shape, "size": WorldDocumentScript.array3(surface_brush_size), "material": active_material})

func _library_button(title: String, type: String, properties: Dictionary) -> void:
	var button := _button(title, func() -> void: _select_brush(title, type, properties))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.clip_text = true; button.tooltip_text = "%s\nChoisir ce pinceau, puis cliquer dans la vue" % title
	library_items.add_child(button)

func _select_brush(title: String, type: String, properties: Dictionary) -> void:
	brush_title = title.replace("▰", "").replace("▥", "").replace("◼", "").replace("◆", "").replace("♟", "").strip_edges()
	brush_type = type
	brush_properties = properties.duplicate(true)
	if type == "chapter_portal":
		_apply_portal_property_defaults(brush_properties)
	if type == "surface":
		brush_properties["material"] = active_material
		surface_brush_shape = String(brush_properties.get("shape", "block"))
		surface_brush_size = WorldDocumentScript.vector3(brush_properties.get("size", []), Vector3.ONE)
	_set_tool_mode("brush")
	_set_status("PINCEAU ACTIF : %s — cliquez dans la grille pour peindre." % brush_title)
	if library_category != null and library_category.selected == 1:
		_refresh_library()

func _select_material(material: String) -> void:
	active_material = material
	if brush_type == "surface":
		brush_properties["material"] = material
	var entity := document.find_entity(selected_id)
	if not entity.is_empty() and String(entity.get("type", "")) == "surface":
		_set_property(entity, "material", material)
		_rebuild_preview()
	elif not entity.is_empty() and String(entity.get("type", "")) == "terrain":
		_set_terrain_tool("paint")
		_set_status("Texture locale active : %s. Peignez maintenant uniquement les zones voulues." % material.replace("_", " "))
	else:
		_set_status("Texture active : %s. Elle est appliquee au pinceau de surface." % material.replace("_", " "))
	_refresh_library()

func _add_entity(type: String, properties: Dictionary) -> void:
	_push_undo()
	var labels := {"surface": "Nouvelle surface", "prop": "Nouveau decor", "light": "Nouvelle lumiere", "enemy_group": "Nouveau groupe", "patrol_point": "Point de patrouille", "trigger": "Nouvel evenement", "narrative": "Element narratif", "atmosphere_zone": "Zone d'atmosphere", "player_spawn": "Depart joueur", "door": "Nouvelle porte", "chapter_portal": "Passage de chapitre"}
	var position := camera_target
	position.x = snappedf(position.x, float((document.data["settings"] as Dictionary).get("grid_size", 1.0)))
	position.z = snappedf(position.z, float((document.data["settings"] as Dictionary).get("grid_size", 1.0)))
	var entity := WorldDocumentScript.entity(type, labels.get(type, "Element"), position, properties)
	entity["chapter"] = active_chapter_id
	selected_id = document.add_entity(entity)
	_mark_changed(); _rebuild_preview()
	_set_status("%s ajoute." % labels.get(type, "Element"))

func _refresh_hierarchy() -> void:
	hierarchy.clear()
	var root := hierarchy.create_item()
	var categories := {"TERRAIN": [], "DECOR": [], "PERSONNAGES": [], "LOGIQUE": [], "LUMIERES": []}
	for raw: Variant in _chapter_entities():
		var entity := raw as Dictionary
		if not hierarchy_filter.text.is_empty() and hierarchy_filter.text.to_lower() not in String(entity.get("name", "")).to_lower(): continue
		var type := String(entity.get("type", "")); var category := "DECOR"
		if type == "terrain": category = "TERRAIN"
		elif type == "enemy_group" or type == "player_spawn": category = "PERSONNAGES"
		elif type in ["patrol_point", "trigger", "narrative", "atmosphere_zone", "chapter_portal"]: category = "LOGIQUE"
		elif type == "light": category = "LUMIERES"
		(categories[category] as Array).append(entity)
	for category: String in categories:
		var category_item := hierarchy.create_item(root); category_item.set_text(0, category); category_item.set_selectable(0, false); category_item.set_custom_color(0, Color("e9b96e"))
		for entity: Dictionary in categories[category]:
			var item := hierarchy.create_item(category_item); item.set_text(0, String(entity.get("name", "Element"))); item.set_metadata(0, String(entity.get("id", "")))
			if String(entity.get("id", "")) == selected_id: item.select(0)

func _on_tree_selected() -> void:
	var item := hierarchy.get_selected()
	if item != null:
		selected_id = String(item.get_metadata(0))
		_rebuild_inspector()
		_update_selection_marker()

func _rebuild_inspector() -> void:
	rebuilding_inspector = true
	for child in inspector_content.get_children(): child.queue_free()
	var entity := document.find_entity(selected_id)
	if entity.is_empty():
		var empty := _label("Selectionnez un element dans la vue ou la hierarchie.", 15, Color("8f9db2")); empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inspector_content.add_child(empty)
		rebuilding_inspector = false; return
	inspector_content.add_child(_label(String(entity.get("type", "")).to_upper(), 12, Color("68d9b6")))
	_add_text_field("Nom", String(entity.get("name", "")), func(value: String) -> void: _set_entity_value(entity, "name", value))
	_add_check_field("Actif", bool(entity.get("enabled", true)), func(value: bool) -> void: _set_entity_value(entity, "enabled", value))
	inspector_content.add_child(_section("TRANSFORMATION"))
	_add_vector_fields("Position", entity, "position", 0.25)
	var entity_type := String(entity.get("type", ""))
	if entity_type != "terrain":
		_add_vector_fields("Rotation", entity, "rotation", 1.0)
	if entity_type == "terrain":
		var terrain_transform_hint := _label("Le terrain conserve une echelle 1:1 : un echantillon = un metre, pour aligner exactement rendu et collision.", 10, Color("9aaac1"))
		terrain_transform_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(terrain_transform_hint)
	elif entity_type == "prop":
		var global_scale := WorldDocumentScript.vector3(entity.get("scale", []), Vector3.ONE).x
		_add_number_field("Echelle globale (proportions conservees)", global_scale, 0.05, 25.0, 0.05, func(value: float) -> void: _set_uniform_entity_scale(entity, value))
	else:
		_add_vector_fields("Echelle", entity, "scale", 0.05)
	var properties := entity.get("properties", {}) as Dictionary
	match entity_type:
		"terrain": _inspect_terrain(entity, properties)
		"surface": _inspect_surface(entity, properties)
		"prop": _inspect_prop(entity, properties)
		"light": _inspect_light(entity, properties)
		"enemy_group": _inspect_enemy_group(entity, properties)
		"patrol_point": _inspect_patrol(entity, properties)
		"trigger": _inspect_trigger(entity, properties)
		"door": _inspect_door(entity, properties)
		"chapter_portal": _inspect_chapter_portal(entity, properties)
		"player_spawn": _inspect_player_spawn(entity, properties)
		"narrative": _inspect_narrative(entity, properties)
		"atmosphere_zone": _inspect_atmosphere(entity, properties)
	inspector_content.add_child(_section("ACTIONS"))
	inspector_content.add_child(_button("Dupliquer  Ctrl+D", _duplicate_selected))
	inspector_content.add_child(_button("Supprimer  Suppr", _delete_selected, Color("8f3c3c")))
	rebuilding_inspector = false

func _inspect_surface(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("GEOMETRIE & TEXTURE")); _add_option_field("Forme", ["floor", "wall", "block"], String(p.get("shape", "block")), func(v: String) -> void: _set_property(entity, "shape", v)); _add_vector_property("Dimensions", entity, p, "size", 0.25); _add_option_field("Texture", MATERIALS, String(p.get("material", "pavers")), func(v: String) -> void: _set_property(entity, "material", v))

func _inspect_terrain(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("RELIEF PROCEDURAL"))
	_add_option_field("Generateur", WorldTerrainScript.GENERATORS, String(p.get("generator", "rolling")), func(value: String) -> void: _set_property(entity, "generator", value))
	_add_option_field("Resolution (points par cote)", ["17", "33", "65", "129"], str(int(p.get("resolution", 65))), func(value: String) -> void: _set_terrain_resolution(entity, value.to_int()))
	_add_number_field("Largeur X (m)", float(p.get("width", 64.0)), WorldTerrainScript.MIN_SIZE, WorldTerrainScript.MAX_SIZE, 1.0, func(value: float) -> void: _set_terrain_dimension(entity, "width", value))
	_add_number_field("Profondeur Z (m)", float(p.get("depth", 64.0)), WorldTerrainScript.MIN_SIZE, WorldTerrainScript.MAX_SIZE, 1.0, func(value: float) -> void: _set_terrain_dimension(entity, "depth", value))
	_add_number_field("Seed reproductible", float(p.get("seed", 1337)), 0.0, 999999.0, 1.0, func(value: float) -> void: _set_property(entity, "seed", int(value)))
	_add_number_field("Amplitude (m)", float(p.get("amplitude", 7.0)), 0.0, 48.0, 0.25, func(value: float) -> void: _set_property(entity, "amplitude", value))
	_add_number_field("Frequence", float(p.get("frequency", 0.025)), 0.001, 0.25, 0.001, func(value: float) -> void: _set_property(entity, "frequency", value))
	_add_number_field("Octaves", float(p.get("octaves", 4)), 1.0, 8.0, 1.0, func(value: float) -> void: _set_property(entity, "octaves", int(value)))
	_add_option_field("Texture PBR de base", MATERIALS, String(p.get("material", "dirt_path")), func(value: String) -> void: _set_property(entity, "material", value))
	var resolution := int(p.get("resolution", 65))
	var terrain_info := _label("%d × %d points • %.0f × %.0f m • pas %.2f × %.2f m • collision HeightMapShape3D" % [resolution, resolution, float(p.get("width", 64.0)), float(p.get("depth", 64.0)), float(p.get("width", 64.0)) / float(resolution - 1), float(p.get("depth", 64.0)) / float(resolution - 1)], 10, Color("8ee0bd"))
	terrain_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(terrain_info)
	inspector_content.add_child(_button("↻  REGENERER LE RELIEF", func() -> void: _regenerate_terrain(entity), Color("315f73")))
	inspector_content.add_child(_section("SCULPTURE"))
	var sculpt_row := GridContainer.new()
	sculpt_row.columns = 2
	for definition: Dictionary in [
		{"mode": "raise", "label": "▲ Monter"}, {"mode": "lower", "label": "▼ Creuser"},
		{"mode": "smooth", "label": "≈ Lisser"}, {"mode": "flatten", "label": "▬ Aplanir"},
	]:
		var mode := String(definition["mode"])
		var tool_button := _button(String(definition["label"]), func() -> void: _set_terrain_tool(mode), Color("356155") if terrain_tool == mode and tool_mode == "terrain" else Color("293b38"))
		tool_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sculpt_row.add_child(tool_button)
	inspector_content.add_child(sculpt_row)
	_add_number_field("Rayon du pinceau", terrain_brush_radius, 0.5, 24.0, 0.5, func(value: float) -> void: terrain_brush_radius = value)
	_add_number_field("Force du pinceau", terrain_brush_strength, 0.05, 4.0, 0.05, func(value: float) -> void: terrain_brush_strength = value)
	inspector_content.add_child(_button("≈  LISSER TOUT LE TERRAIN", func() -> void: _smooth_entire_terrain(entity), Color("3a4d58")))
	inspector_content.add_child(_button("▬  APLATIR TOUT A ZERO", func() -> void: _flatten_entire_terrain(entity), Color("6b4a32")))
	inspector_content.add_child(_section("PEINTURE LOCALE"))
	_add_option_field("Texture du pinceau", MATERIALS, active_material, func(value: String) -> void: _select_material(value))
	var local_paint_row := HBoxContainer.new()
	local_paint_row.add_child(_button("▦  PEINDRE LA TEXTURE", func() -> void: _set_terrain_tool("paint"), Color("356155")))
	local_paint_row.add_child(_button("⌫  RETROUVER LA BASE", func() -> void: _set_terrain_tool("erase_material"), Color("5b4137")))
	inspector_content.add_child(local_paint_row)
	inspector_content.add_child(_section("VEGETATION MULTIMESH"))
	var foliage_labels: Array[String] = []
	for preset: String in WorldTerrainScript.FOLIAGE_PRESETS:
		foliage_labels.append(_foliage_display_name(preset))
	_add_mapped_option_field("Type du pinceau", foliage_labels, WorldTerrainScript.FOLIAGE_PRESETS, active_foliage_preset, func(value: String) -> void: _set_foliage_brush(value))
	_add_number_field("Rayon végétation", terrain_brush_radius, 0.5, 48.0, 0.5, func(value: float) -> void: terrain_brush_radius = value)
	_add_number_field("Force / densité", terrain_brush_strength, 0.05, 4.0, 0.05, func(value: float) -> void: terrain_brush_strength = value)
	_add_number_field("Seed végétation", float(p.get("foliage_seed", 9256)), 0.0, 999999.0, 1.0, func(value: float) -> void: _set_property(entity, "foliage_seed", int(value)))
	_add_number_field("Quantité", float(p.get("foliage_amount", 0.65)), 0.0, 2.0, 0.05, func(value: float) -> void: _set_property(entity, "foliage_amount", value))
	var foliage_paint_row := HBoxContainer.new()
	foliage_paint_row.add_child(_button("♒  PEINDRE %s" % _foliage_display_name(active_foliage_preset).to_upper(), func() -> void: _set_terrain_tool("foliage"), Color("356155")))
	foliage_paint_row.add_child(_button("⌫  RETIRER L'HERBE", func() -> void: _set_terrain_tool("erase_foliage"), Color("5b4137")))
	inspector_content.add_child(foliage_paint_row)

func _inspect_prop(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("DECOR"))
	if p.has("asset_path"):
		_add_text_field("Modele", String(p.get("asset_label", p.get("asset_path", "Objet"))), func(_v: String) -> void: pass)
		var scale_hint := _label("Utilisez l'echelle globale ou la poignee doree pour agrandir l'objet sans le deformer.", 12, Color("aebbd0"))
		scale_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(scale_hint)
		return
	var ids: Array = AssetCatalogScript.ASSETS.keys()
	ids.sort()
	var strings: Array[String] = []
	for id in ids:
		strings.append(String(id))
	_add_option_field("Objet", strings, String(p.get("asset_id", "crates")), func(v: String) -> void: _set_property(entity, "asset_id", v))

func _inspect_light(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("LUMIERE")); _add_option_field("Type", ["omni", "spot"], String(p.get("light_type", "omni")), func(v: String) -> void: _set_property(entity, "light_type", v)); _add_text_field("Couleur HTML", String(p.get("color", "#ffb36b")), func(v: String) -> void: _set_property(entity, "color", v)); _add_number_field("Intensite", float(p.get("energy", 2.0)), 0.0, 20.0, 0.1, func(v: float) -> void: _set_property(entity, "energy", v)); _add_number_field("Portee", float(p.get("range", 12.0)), 1.0, 100.0, 0.5, func(v: float) -> void: _set_property(entity, "range", v)); _add_check_field("Ombres en test", bool(p.get("shadows", false)), func(v: bool) -> void: _set_property(entity, "shadows", v))

func _inspect_enemy_group(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("TROUPE ENNEMIE"))
	var help := _label("Ce bloc represente un spawn complet. Choisissez son comportement, puis utilisez les boutons Carte pour le relier au monde.", 12, Color("aebbd0"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(help)
	_add_text_field("ID du groupe", String(p.get("group_id", "groupe")), func(v: String) -> void: _set_property(entity, "group_id", v))
	var ids: Array[String] = []
	for id in EnemyArchetypesScript.all_ids():
		ids.append(String(id))
	var composition := p.get("composition", []) as Array
	var deployment_mode := String(p.get("deployment_mode", "all"))
	if composition.is_empty():
		_add_option_field("Personnage", ids, String(p.get("archetype", "nathenian1")), func(v: String) -> void: _set_enemy_group_archetype(entity, v))
		_add_number_field("Total maximum" if deployment_mode != "all" else "Nombre", float(p.get("count", 6)), 1, 500, 1, func(v: float) -> void: _set_property(entity, "count", int(v)))
	else:
		inspector_content.add_child(_section("COMPOSITION MIXTE"))
		for composition_index in range(composition.size()):
			var entry := composition[composition_index] as Dictionary
			inspector_content.add_child(_label("Type %d" % (composition_index + 1), 11, Color("6fe1bd")))
			_add_option_field("Personnage", ids, String(entry.get("archetype", "ngeneral")), func(v: String) -> void: _set_composition_entry(entity, composition_index, "archetype", v))
			_add_number_field("Effectif", float(entry.get("count", 1)), 1, 500, 1, func(v: float) -> void: _set_composition_entry(entity, composition_index, "count", int(v)))
		inspector_content.add_child(_label("Total : %d soldats" % int(p.get("count", 0)), 12, Color("f1c979")))
		inspector_content.add_child(_button("Convertir en troupe uniforme", _clear_group_composition.bind(entity), Color("3b4354")))
	_add_option_field("Rang", ["normal", "miniboss"], String(p.get("rank", "normal")), func(v: String) -> void: _set_property(entity, "rank", v))
	_add_number_field("Taille", float(p.get("size_multiplier", 1.0)), 0.35, 4.0, 0.05, func(v: float) -> void: _set_property(entity, "size_multiplier", v))
	var inspected_archetype := StringName(p.get("archetype", "nathenian1"))
	if EnemyArchetypesScript.is_giant(inspected_archetype):
		inspector_content.add_child(_section("TRAVERSAL GEANT"))
		_add_checkbox_field("Activer le traversal geant", bool(p.get("match_perfect_hitbox", true)), func(v: bool) -> void: _set_property(entity, "match_perfect_hitbox", v))
		_add_mapped_option_field("Collision de locomotion", ["Assistee — corps lisse + vraie tete (recommande)", "Exacte — volumes du modele", "Desactivee"], ["assisted", "exact", "off"], String(p.get("giant_traversal_mode", "assisted")), func(v: String) -> void: _set_giant_traversal_mode(entity, v))
		if String(p.get("giant_traversal_mode", "assisted")) == "assisted":
			_add_number_field("Largeur corps wallrun", float(p.get("giant_capsule_radius_multiplier", 0.90)), 0.55, 1.35, 0.05, func(v: float) -> void: _set_property(entity, "giant_capsule_radius_multiplier", v))
			_add_number_field("Extension verticale corps", float(p.get("giant_capsule_height_multiplier", 1.0)), 0.80, 1.25, 0.05, func(v: float) -> void: _set_property(entity, "giant_capsule_height_multiplier", v))
		_add_checkbox_field("Appui stabilise au sommet de la tete", bool(p.get("giant_walkable_tops", true)), func(v: bool) -> void: _set_property(entity, "giant_walkable_tops", v))
		var traversal_help := _label("Le mode assiste conserve l'anatomie exacte pour les coups, utilise un corps cylindrique lisse jusqu'aux epaules pour le wallrun, puis le vrai mesh de tete pour l'approche et la decapitation. Le mode exact suit tous les meshes animes et peut produire de faux sols sur les membres.", 11, Color("aebbd0"))
		traversal_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(traversal_help)
	else:
		_add_checkbox_field("Match perfect hitbox", bool(p.get("match_perfect_hitbox", false)), func(v: bool) -> void: _set_property(entity, "match_perfect_hitbox", v))
		inspector_content.add_child(_label("Remplace la capsule par des volumes issus du modele. A reserver aux personnages importants.", 11, Color("aebbd0")))
	inspector_content.add_child(_section("COMPORTEMENT"))
	_add_mapped_option_field("Comportement", ["Combat libre", "Attend le joueur", "Patrouille", "Protege une cible"], ["normal", "wait", "patrol", "protect"], String(p.get("behavior", "normal")), func(v: String) -> void: _set_property(entity, "behavior", v))
	var behavior := String(p.get("behavior", "normal"))
	if behavior == "patrol":
		var route_id := String(p.get("route_id", ""))
		var point_count := _patrol_point_count(route_id)
		inspector_content.add_child(_label("Route : %s • %d point(s)" % [route_id if not route_id.is_empty() else "non tracee", point_count], 12, Color("6fe1bd")))
		inspector_content.add_child(_button("⌖  Tracer / completer la patrouille sur la carte", _begin_patrol_mapping.bind(entity), Color("205247")))
		if point_count > 0:
			inspector_content.add_child(_button("Effacer les points de cette patrouille", _clear_patrol_route.bind(entity), Color("593a3d")))
	elif behavior == "protect":
		var target_name := _entity_reference_label(String(p.get("protect_target", "")))
		inspector_content.add_child(_label("Cible : %s" % target_name, 12, Color("6fe1bd") if target_name != "Aucune" else Color("ef8a7e")))
		inspector_content.add_child(_button("◎  Choisir l'objet ou la troupe sur la carte", _begin_reference_capture.bind(entity, "protect"), Color("205247")))
	elif behavior == "wait":
		var wait_hint := _label("La troupe reste en attente jusqu'a ce que le joueur entre dans sa distance d'activation automatique.", 12, Color("aebbd0"))
		wait_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(wait_hint)
	_add_mapped_option_field("Formation", ["Ligne", "Colonne", "Carre", "Cercle", "Coin", "Phalange", "Arc", "Dispersee"], ["line", "column", "square", "circle", "wedge", "phalanx", "arc", "scattered"], String(p.get("formation", "line")), func(v: String) -> void: _set_property(entity, "formation", v))
	var derived := _enemy_derived_values(p)
	var derived_label := _label("Automatique pour ce personnage : espacement %.2f m • activation %.1f m" % [float(derived.spacing), float(derived.engage_distance)], 11, Color("8393aa"))
	derived_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(derived_label)
	inspector_content.add_child(_section("MODE DE DEPLOIEMENT"))
	_add_mapped_option_field("Mode", ["Toute la troupe d'un coup", "Vagues periodiques", "Reserve progressive"], ["all", "waves", "reserve"], deployment_mode, func(v: String) -> void: _set_property(entity, "deployment_mode", v))
	if deployment_mode == "waves":
		var waves_hint := _label("Envoie un lot a intervalle regulier. L'arret peut venir du total, d'un evenement, ou de la premiere mort dans une troupe choisie.", 11, Color("aebbd0"))
		waves_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(waves_hint)
		_add_number_field("Soldats par vague", float(p.get("wave_size", 3)), 1, 100, 1, func(v: float) -> void: _set_property(entity, "wave_size", int(v)))
		_add_number_field("Intervalle (secondes)", float(p.get("wave_interval", 5.0)), 0.1, 600.0, 0.25, func(v: float) -> void: _set_property(entity, "wave_interval", v))
		var legacy_stop_mode := "event" if not String(p.get("deployment_stop_trigger", "")).is_empty() else "total"
		var stop_mode := String(p.get("deployment_stop_mode", legacy_stop_mode))
		_add_mapped_option_field("Arret des vagues", ["Au total maximum", "Lors d'un evenement", "A la mort d'une unite"], ["total", "event", "unit_death"], stop_mode, func(v: String) -> void: _set_property(entity, "deployment_stop_mode", v))
		if stop_mode == "event":
			_add_trigger_reference_details(entity, p, "deployment_stop_trigger", "Evenement qui arrete les vagues")
			inspector_content.add_child(_button("⬡  Choisir l'evenement d'arret sur la carte", _begin_reference_capture.bind(entity, "deployment_stop_trigger"), Color("205247")))
		elif stop_mode == "unit_death":
			var death_hint := _label("Les vagues s'arretent des que n'importe quelle unite de cette troupe meurt. Vous pouvez choisir la troupe de vagues elle-meme.", 11, Color("f1c979"))
			death_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inspector_content.add_child(death_hint)
			_add_group_reference_details(entity, p, "deployment_stop_group", "Troupe dont une unite doit mourir", true)
			inspector_content.add_child(_button("☠  Choisir la troupe sur la carte", _begin_reference_capture.bind(entity, "deployment_stop_death"), Color("205247")))
	elif deployment_mode == "reserve":
		var reserve_hint := _label("Exemple 30 / 10 / 7 / 3 : 30 au total, 10 au depart, puis +3 des qu'il reste moins de 7 actifs.", 11, Color("aebbd0"))
		reserve_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(reserve_hint)
		_add_number_field("Actifs au depart", float(p.get("initial_active", 10)), 1, 500, 1, func(v: float) -> void: _set_property(entity, "initial_active", int(v)))
		_add_number_field("Seuil minimum actif", float(p.get("reinforce_threshold", 7)), 0, 500, 1, func(v: float) -> void: _set_property(entity, "reinforce_threshold", int(v)))
		_add_number_field("Renfort par lot", float(p.get("reinforce_amount", 3)), 1, 500, 1, func(v: float) -> void: _set_property(entity, "reinforce_amount", int(v)))
	inspector_content.add_child(_section("CONDITION DE SPAWN"))
	_add_mapped_option_field("Apparition", ["Au lancement", "Joueur traverse une zone", "Mort d'une troupe", "Apres un timer"], ["start", "trigger", "group_dead", "timer"], String(p.get("spawn_condition", "start" if bool(p.get("active_on_start", true)) else "trigger")), func(v: String) -> void: _set_property(entity, "spawn_condition", v))
	var spawn_condition := String(p.get("spawn_condition", "start" if bool(p.get("active_on_start", true)) else "trigger"))
	if spawn_condition == "trigger":
		inspector_content.add_child(_label("Zone : %s" % _entity_reference_label(String(p.get("spawn_trigger", ""))), 12, Color("6fe1bd")))
		inspector_content.add_child(_button("⬡  Choisir un declencheur sur la carte", _begin_reference_capture.bind(entity, "spawn_trigger"), Color("205247")))
	elif spawn_condition == "group_dead":
		_add_group_reference_details(entity, p, "spawn_dead_group", "Troupe qui doit mourir")
		inspector_content.add_child(_button("☠  Choisir une troupe sur la carte", _begin_reference_capture.bind(entity, "spawn_dead"), Color("205247")))
	elif spawn_condition == "timer":
		_add_number_field("Delai (secondes)", float(p.get("spawn_delay", 3.0)), 0.0, 600.0, 0.25, func(v: float) -> void: _set_property(entity, "spawn_delay", v))

func _inspect_patrol(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("PATROUILLE")); _add_text_field("ID de route", String(p.get("route_id", "route_1")), func(v: String) -> void: _set_property(entity, "route_id", v)); _add_number_field("Ordre", float(p.get("order", 0)), 0, 99, 1, func(v: float) -> void: _set_property(entity, "order", int(v))); _add_number_field("Attente (sec)", float(p.get("wait", 1.0)), 0, 30, 0.25, func(v: float) -> void: _set_property(entity, "wait", v))

func _inspect_trigger(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("DECLENCHEUR INVISIBLE"))
	var hint := _label("Cette hitbox est visible seulement dans la Forge. Son nom peut aussi servir de condition de spawn a une troupe.", 12, Color("aebbd0"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(hint)
	_add_vector_property("Taille de zone", entity, p, "size", 0.5)
	_add_mapped_option_field("Condition", ["Joueur traverse la zone", "Mort d'une troupe", "% d'une troupe elimine"], ["player_enter", "group_dead", "group_dead_percent"], String(p.get("condition", "player_enter")), func(v: String) -> void: _set_property(entity, "condition", v))
	var condition := String(p.get("condition", "player_enter"))
	if condition in ["group_dead", "group_dead_percent"]:
		var global_hint := _label("EVENEMENT GLOBAL : il se declenche a la mort de la troupe, ou que soit le joueur. La position et la taille de la box sont ignorees.", 12, Color("f1c979"))
		global_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(global_hint)
		_add_group_reference_details(entity, p, "condition_group", "Troupe observee")
		inspector_content.add_child(_button("☠  Choisir la troupe sur la carte", _begin_reference_capture.bind(entity, "trigger_condition_dead"), Color("205247")))
		if condition == "group_dead_percent":
			_add_number_field("Pourcentage mort", float(p.get("threshold", 100)), 1, 100, 1, func(v: float) -> void: _set_property(entity, "threshold", v))
	inspector_content.add_child(_section("EFFET DIRECT"))
	_add_mapped_option_field("Action", ["Aucun (nom seulement)", "Ouvrir une porte", "Faire apparaitre une troupe", "Retirer une troupe", "Retirer tous les ennemis", "Afficher une narration", "Changer la musique", "Changer l'atmosphere"], ["none", "open_door", "spawn_group", "remove_group", "remove_all_mobs", "narrative", "music", "atmosphere"], String(p.get("action", "none")), func(v: String) -> void: _set_property(entity, "action", v))
	var action := String(p.get("action", "none"))
	if action == "open_door":
		_add_door_reference_details(entity, p, "action_target", "Porte a ouvrir")
		inspector_content.add_child(_button("▥  Choisir la porte sur la carte", _begin_reference_capture.bind(entity, "action_door"), Color("205247")))
	elif action in ["spawn_group", "remove_group"]:
		_add_group_reference_details(entity, p, "action_target", "Troupe cible")
		inspector_content.add_child(_button("♟  Choisir une troupe sur la carte", _begin_reference_capture.bind(entity, "action_group"), Color("205247")))
	elif action == "narrative":
		var legacy_narrative_mode := "element" if not String(p.get("action_target", "")).is_empty() and String(p.get("action_text", "")).is_empty() else "direct"
		var narrative_mode := String(p.get("narrative_mode", legacy_narrative_mode))
		_add_mapped_option_field("Contenu", ["Message ecrit ici (simple)", "Element de narration reutilisable"], ["direct", "element"], narrative_mode, func(v: String) -> void: _set_property(entity, "narrative_mode", v))
		if narrative_mode == "element":
			_add_text_field("Element — nom ou ID", String(p.get("action_target", "")), func(v: String) -> void: _set_property(entity, "action_target", v.strip_edges()))
			inspector_content.add_child(_label("Element selectionne : %s" % _entity_reference_label(String(p.get("action_target", ""))), 11, Color("6fe1bd")))
			inspector_content.add_child(_button("✦  Choisir l'element de narration sur la carte", _begin_reference_capture.bind(entity, "action_narrative"), Color("205247")))
		else:
			var direct_hint := _label("Ce message sera affiche directement quand la condition ci-dessus est remplie.", 11, Color("6fe1bd"))
			direct_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inspector_content.add_child(direct_hint)
			_add_text_field("Intervenant", String(p.get("action_speaker", "Narrateur")), func(v: String) -> void: _set_property(entity, "action_speaker", v))
			_add_multiline_field("Message", String(p.get("action_text", "")), func(v: String) -> void: _set_property(entity, "action_text", v))
			_add_number_field("Duree", float(p.get("action_duration", 4.0)), 1.0, 30.0, 0.5, func(v: float) -> void: _set_property(entity, "action_duration", v))
	elif action == "music":
		var tracks := _music_track_paths()
		var track_labels: Array[String] = []
		for path in tracks:
			track_labels.append(path.get_file().get_basename().replace("_", " ").capitalize())
		if tracks.is_empty():
			inspector_content.add_child(_label("Aucune musique trouvee dans res://audio/track", 12, Color("ef8a7e")))
		else:
			_add_mapped_option_field("Musique", track_labels, tracks, String(p.get("music_path", tracks[0])), func(v: String) -> void: _set_property(entity, "music_path", v))
		_add_number_field("Volume (dB)", float(p.get("music_volume", -4.0)), -40.0, 6.0, 0.5, func(v: float) -> void: _set_property(entity, "music_volume", v))
	elif action == "atmosphere":
		_add_option_field("Ambiance", ATMOSPHERE_PRESETS.keys(), String(p.get("atmosphere_preset", "Siege enfume")), func(v: String) -> void: _apply_trigger_atmosphere_preset(entity, v))
	_add_check_field("Une seule fois", bool(p.get("once", true)), func(v: bool) -> void: _set_property(entity, "once", v))

func _inspect_door(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("PORTE ANIMEE"))
	var hint := _label("Cette porte bloque le joueur jusqu'a l'action Ouvrir une porte d'un declencheur. Ses dimensions restent entierement modifiables.", 12, Color("aebbd0"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(hint)
	_add_vector_property("Dimensions", entity, p, "size", 0.25)
	_add_mapped_option_field("Modele", ["Bois", "Grille de fer", "Pierre", "Bronze"], ["wood", "iron", "stone", "bronze"], String(p.get("door_style", "wood")), func(v: String) -> void: _set_property(entity, "door_style", v))
	_add_mapped_option_field("Ouverture", ["Pivot gauche", "Pivot droite", "Verticale / herse", "Coulisse a gauche", "Coulisse a droite"], ["pivot_left", "pivot_right", "vertical", "slide_left", "slide_right"], String(p.get("open_motion", "pivot_left")), func(v: String) -> void: _set_property(entity, "open_motion", v))
	_add_number_field("Duree d'ouverture", float(p.get("open_duration", 1.2)), 0.05, 20.0, 0.05, func(v: float) -> void: _set_property(entity, "open_duration", v))
	_add_check_field("Deja ouverte au chargement", bool(p.get("starts_open", false)), func(v: bool) -> void: _set_property(entity, "starts_open", v))

func _inspect_chapter_portal(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("PASSAGE DE CHAPITRE"))
	var hint := _label("Le chapitre courant est entierement decharge avant de construire la destination au point d'arrivee indique.", 12, Color("f1c979"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(hint)
	_add_vector_property("Taille du passage", entity, p, "size", 0.25)
	var labels: Array[String] = ["— Choisir un chapitre —"]
	var values: Array[String] = [""]
	for raw: Variant in document.chapters():
		var chapter := raw as Dictionary
		labels.append(String(chapter.get("name", chapter.get("id", "Chapitre"))))
		values.append(String(chapter.get("id", "")))
	var destination_chapter := String(p.get("destination_chapter", ""))
	_add_mapped_option_field("Destination", labels, values, destination_chapter, func(v: String) -> void: _set_portal_destination(entity, v))
	if destination_chapter.is_empty():
		var missing := _label("⚠ Choisissez une destination : sans elle, le passage reste inactif.", 12, Color("ef8a7e"))
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inspector_content.add_child(missing)
	else:
		var arrival_labels: Array[String] = ["Premier point disponible"]
		var arrival_values: Array[String] = [""]
		for arrival: Dictionary in document.entities_for_chapter(destination_chapter):
			if String(arrival.get("type", "")) != "player_spawn":
				continue
			var arrival_properties := arrival.get("properties", {}) as Dictionary
			var arrival_id := String(arrival_properties.get("spawn_id", arrival.get("id", "")))
			arrival_labels.append("%s  •  %s" % [String(arrival.get("name", "Arrivee")), arrival_id])
			arrival_values.append(arrival_id)
		_add_mapped_option_field("Arrivee rapide", arrival_labels, arrival_values, String(p.get("destination_spawn", "")), func(v: String) -> void: _set_property(entity, "destination_spawn", v))
	_add_text_field("ID du point d'arrivee", String(p.get("destination_spawn", "")), func(v: String) -> void: _set_property(entity, "destination_spawn", v.strip_edges()))
	_add_text_field("Etiquette", String(p.get("label", "CHAPITRE")), func(v: String) -> void: _set_property(entity, "label", v))

func _set_portal_destination(entity: Dictionary, chapter_id: String) -> void:
	if rebuilding_inspector:
		return
	var properties := entity.get("properties", {}) as Dictionary
	if String(properties.get("destination_chapter", "")) == chapter_id:
		return
	_push_undo()
	properties["destination_chapter"] = chapter_id
	properties["destination_spawn"] = _first_arrival_id(chapter_id)
	_mark_changed()
	_rebuild_inspector()

func _apply_portal_property_defaults(properties: Dictionary) -> void:
	if not String(properties.get("destination_chapter", "")).is_empty():
		return
	for raw: Variant in document.chapters():
		var chapter_id := String((raw as Dictionary).get("id", ""))
		if not chapter_id.is_empty() and chapter_id != active_chapter_id:
			properties["destination_chapter"] = chapter_id
			properties["destination_spawn"] = _first_arrival_id(chapter_id)
			return

func _first_arrival_id(chapter_id: String) -> String:
	if chapter_id.is_empty():
		return ""
	for entity: Dictionary in document.entities_for_chapter(chapter_id):
		if String(entity.get("type", "")) == "player_spawn":
			var properties := entity.get("properties", {}) as Dictionary
			return String(properties.get("spawn_id", entity.get("id", "")))
	return ""

func _inspect_player_spawn(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("ARRIVEE JOUEUR"))
	var hint := _label("Donnez un ID simple, par exemple entree_crypte. Un passage de chapitre peut teleporter exactement ici.", 12, Color("aebbd0"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(hint)
	_add_text_field("ID d'arrivee", String(p.get("spawn_id", "depart")), func(v: String) -> void: _set_property(entity, "spawn_id", v.strip_edges()))

func _inspect_narrative(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("NARRATION")); _add_text_field("Intervenant", String(p.get("speaker", "Narrateur")), func(v: String) -> void: _set_property(entity, "speaker", v)); _add_multiline_field("Texte", String(p.get("text", "")), func(v: String) -> void: _set_property(entity, "text", v)); _add_number_field("Duree", float(p.get("duration", 4)), 1, 30, 0.5, func(v: float) -> void: _set_property(entity, "duration", v))

func _inspect_atmosphere(entity: Dictionary, p: Dictionary) -> void:
	inspector_content.add_child(_section("ATMOSPHERE LOCALE")); _add_vector_property("Taille de zone", entity, p, "size", 0.5); _add_option_field("Preset", ATMOSPHERE_PRESETS.keys(), String(p.get("preset", "Siege enfume")), func(v: String) -> void: _apply_zone_preset(entity, v)); _add_number_field("Soleil", float(p.get("sun_energy", 0.66)), 0, 4, 0.05, func(v: float) -> void: _set_property(entity, "sun_energy", v)); _add_number_field("Ambiance", float(p.get("ambient_energy", 0.42)), 0, 3, 0.05, func(v: float) -> void: _set_property(entity, "ambient_energy", v)); _add_number_field("Brouillard", float(p.get("fog_density", 0.027)), 0, 0.15, 0.001, func(v: float) -> void: _set_property(entity, "fog_density", v))

func _add_vector_fields(title: String, entity: Dictionary, key: String, step: float) -> void:
	var value := WorldDocumentScript.vector3(entity.get(key, []), Vector3.ONE if key == "scale" else Vector3.ZERO)
	var box := VBoxContainer.new()
	box.add_child(_small_label(title))
	var row := HBoxContainer.new()
	for axis in range(3):
		var component := axis
		var spin := _spin(value[component], -10000, 10000, step)
		spin.value_changed.connect(func(v: float) -> void:
			var arr := entity[key] as Array
			_push_undo()
			arr[component] = v
			_mark_changed()
		)
		row.add_child(spin)
	box.add_child(row)
	inspector_content.add_child(box)

func _add_vector_property(title: String, entity: Dictionary, p: Dictionary, key: String, step: float) -> void:
	var value := WorldDocumentScript.vector3(p.get(key, [1,1,1]), Vector3.ONE)
	var box := VBoxContainer.new()
	box.add_child(_small_label(title))
	var row := HBoxContainer.new()
	for axis in range(3):
		var component := axis
		var spin := _spin(value[component], 0.0, 1000, step)
		spin.value_changed.connect(func(v: float) -> void:
			var arr := p[key] as Array
			_push_undo()
			arr[component] = maxf(0.01, v)
			_mark_changed()
		)
		row.add_child(spin)
	box.add_child(row)
	inspector_content.add_child(box)

func _add_text_field(title: String, value: String, callback: Callable) -> void:
	var box := VBoxContainer.new(); box.add_child(_small_label(title)); var edit := LineEdit.new(); edit.text = value; edit.text_submitted.connect(func(v: String) -> void: callback.call(v)); edit.focus_exited.connect(func() -> void: callback.call(edit.text)); box.add_child(edit); inspector_content.add_child(box)

func _add_multiline_field(title: String, value: String, callback: Callable) -> void:
	var box := VBoxContainer.new(); box.add_child(_small_label(title)); var edit := TextEdit.new(); edit.text = value; edit.custom_minimum_size.y = 88; edit.focus_exited.connect(func() -> void: callback.call(edit.text)); box.add_child(edit); inspector_content.add_child(box)

func _add_number_field(title: String, value: float, minimum: float, maximum: float, step: float, callback: Callable) -> void:
	var row := HBoxContainer.new(); row.add_child(_small_label(title)); var spin := _spin(value, minimum, maximum, step); spin.value_changed.connect(func(v: float) -> void: callback.call(v)); row.add_child(spin); inspector_content.add_child(row)

func _add_option_field(title: String, options: Array, value: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_child(_small_label(title))
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected := 0
	for index in range(options.size()):
		option.add_item(String(options[index]))
		if String(options[index]) == value:
			selected = index
	option.select(selected)
	option.item_selected.connect(func(index: int) -> void: callback.call(option.get_item_text(index)))
	row.add_child(option)
	inspector_content.add_child(row)

func _add_mapped_option_field(title: String, labels: Array, values: Array, value: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_child(_small_label(title))
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected := 0
	for index in range(mini(labels.size(), values.size())):
		option.add_item(String(labels[index]))
		option.set_item_metadata(index, String(values[index]))
		if String(values[index]) == value:
			selected = index
	option.select(selected)
	option.item_selected.connect(func(index: int) -> void: callback.call(String(option.get_item_metadata(index))))
	row.add_child(option)
	inspector_content.add_child(row)

func _add_check_field(title: String, value: bool, callback: Callable) -> void:
	var check := CheckButton.new(); check.text = title; check.button_pressed = value; check.toggled.connect(func(v: bool) -> void: callback.call(v)); inspector_content.add_child(check)

func _add_checkbox_field(title: String, value: bool, callback: Callable) -> void:
	var check := CheckBox.new()
	check.text = title
	check.button_pressed = value
	check.toggled.connect(func(v: bool) -> void: callback.call(v))
	inspector_content.add_child(check)

func _set_entity_value(entity: Dictionary, key: String, value: Variant) -> void:
	if rebuilding_inspector or entity.get(key) == value: return
	_push_undo(); entity[key] = value; _mark_changed()

func _set_uniform_entity_scale(entity: Dictionary, value: float) -> void:
	if rebuilding_inspector:
		return
	var safe_value := maxf(0.05, value)
	var current := WorldDocumentScript.vector3(entity.get("scale", []), Vector3.ONE)
	if is_equal_approx(current.x, safe_value) and is_equal_approx(current.y, safe_value) and is_equal_approx(current.z, safe_value):
		return
	_push_undo()
	entity["scale"] = [safe_value, safe_value, safe_value]
	_mark_changed()

func _set_property(entity: Dictionary, key: String, value: Variant) -> void:
	if rebuilding_inspector: return
	var p := entity.get("properties", {}) as Dictionary
	if p.get(key) == value: return
	_push_undo(); p[key] = value; _mark_changed()

func _set_terrain_resolution(entity: Dictionary, resolution: int) -> void:
	if rebuilding_inspector:
		return
	var properties := entity.get("properties", {}) as Dictionary
	if int(properties.get("resolution", 65)) == resolution:
		return
	_push_undo()
	WorldTerrainScript.resize_resolution(properties, resolution)
	dirty = true
	_rebuild_preview()
	_refresh_library()
	_set_status("Terrain rééchantillonné en %d × %d points sans perdre le relief ni la peinture." % [resolution, resolution])

func _set_terrain_dimension(entity: Dictionary, key: String, value: float) -> void:
	if rebuilding_inspector or key not in ["width", "depth"]:
		return
	var properties := entity.get("properties", {}) as Dictionary
	var safe_value := clampf(value, WorldTerrainScript.MIN_SIZE, WorldTerrainScript.MAX_SIZE)
	if is_equal_approx(float(properties.get(key, 64.0)), safe_value):
		return
	_push_undo()
	properties[key] = safe_value
	WorldTerrainScript.normalize(properties)
	dirty = true
	_rebuild_preview()
	_refresh_library()
	_set_status("Dimensions du terrain mises à jour : %.0f × %.0f m." % [float(properties["width"]), float(properties["depth"])])

func _regenerate_terrain(entity: Dictionary) -> void:
	if entity.is_empty():
		return
	_push_undo()
	WorldTerrainScript.regenerate(entity.get("properties", {}) as Dictionary)
	dirty = true
	_rebuild_preview()
	_set_status("Relief regenere avec le seed et les parametres courants.")

func _smooth_entire_terrain(entity: Dictionary) -> void:
	if entity.is_empty():
		return
	_push_undo()
	WorldTerrainScript.smooth_all(entity.get("properties", {}) as Dictionary, 2)
	dirty = true
	_rebuild_preview()
	_set_status("Terrain entier lisse en deux passes.")

func _flatten_entire_terrain(entity: Dictionary) -> void:
	if entity.is_empty():
		return
	_push_undo()
	var properties := entity.get("properties", {}) as Dictionary
	WorldTerrainScript.normalize(properties)
	var heights := properties.get("heights", []) as Array
	for index in range(heights.size()):
		heights[index] = 0.0
	properties["heights"] = heights
	WorldTerrainScript.normalize(properties)
	dirty = true
	_rebuild_preview()
	_set_status("Terrain aplati a la hauteur zero. Ctrl+Z restaure le relief.")

func _set_enemy_group_archetype(entity: Dictionary, value: String) -> void:
	if rebuilding_inspector:
		return
	var properties := entity.get("properties", {}) as Dictionary
	if String(properties.get("archetype", "")) == value:
		return
	_push_undo()
	properties["archetype"] = value
	if EnemyArchetypesScript.is_giant(StringName(value)):
		properties["match_perfect_hitbox"] = true
		properties["giant_traversal_mode"] = "assisted"
		properties["giant_capsule_radius_multiplier"] = 0.90
		properties["giant_capsule_height_multiplier"] = 1.0
		properties["giant_walkable_tops"] = true
	_mark_changed()
	_rebuild_inspector()

func _set_giant_traversal_mode(entity: Dictionary, value: String) -> void:
	if rebuilding_inspector:
		return
	var properties := entity.get("properties", {}) as Dictionary
	if String(properties.get("giant_traversal_mode", "assisted")) == value:
		return
	_push_undo()
	properties["giant_traversal_mode"] = value
	_mark_changed()
	_rebuild_inspector()

func _apply_zone_preset(entity: Dictionary, preset: String) -> void:
	_push_undo()
	var p := entity.get("properties", {}) as Dictionary
	p["preset"] = preset
	for key in ATMOSPHERE_PRESETS[preset]:
		p[key] = ATMOSPHERE_PRESETS[preset][key]
	_mark_changed()
	_rebuild_inspector()

func _apply_trigger_atmosphere_preset(entity: Dictionary, preset: String) -> void:
	if not ATMOSPHERE_PRESETS.has(preset):
		return
	_push_undo()
	var p := entity.get("properties", {}) as Dictionary
	p["atmosphere_preset"] = preset
	for key: Variant in ATMOSPHERE_PRESETS[preset]:
		p[key] = ATMOSPHERE_PRESETS[preset][key]
	_mark_changed()
	_rebuild_inspector()

func _music_track_paths() -> Array[String]:
	var result: Array[String] = []
	for filename in DirAccess.get_files_at("res://audio/track"):
		var lower := filename.to_lower()
		if lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3"):
			result.append("res://audio/track/" + filename)
	result.sort()
	return result

func _enemy_derived_values(properties: Dictionary) -> Dictionary:
	var profile := EnemyArchetypesScript.profile(StringName(properties.get("archetype", "nathenian1")))
	var profile_spacing := float(profile.get("formation_spacing", 0.0))
	var scale_value := float(profile.get("scale", 1.0)) * float(properties.get("size_multiplier", 1.0))
	var role := StringName(profile.get("role", &"infantry"))
	var spacing := profile_spacing
	if spacing <= 0.0:
		var base := 2.15 if role in [&"ranged", &"archer"] else (1.35 if role in [&"phalanx", &"guardian"] else 1.65)
		spacing = maxf(0.8, base * scale_value)
	var tactical_radius := float(profile.get("tactical_radius", 2.4))
	var profile_behavior := StringName(profile.get("behavior", &"aggressive"))
	var editor_behavior := String(properties.get("behavior", "normal"))
	var engage_distance := float(profile.get("aggro_distance", 18.0)) if editor_behavior in ["normal", "protect"] else clampf(tactical_radius * (1.7 if profile_behavior == &"ranged" else 2.6), 6.0, 24.0)
	return {"spacing": spacing, "engage_distance": engage_distance}

func _patrol_point_count(route_id: String) -> int:
	if route_id.is_empty():
		return 0
	var count := 0
	for raw: Variant in _chapter_entities():
		var candidate := raw as Dictionary
		var properties := candidate.get("properties", {}) as Dictionary
		if String(candidate.get("type", "")) == "patrol_point" and String(properties.get("route_id", "")) == route_id:
			count += 1
	return count

func _entity_reference_label(key: String) -> String:
	if key.is_empty():
		return "Aucune"
	var entity := document.find_entity(key)
	if entity.is_empty():
		entity = document.find_by_name(key)
	return String(entity.get("name", key)) if not entity.is_empty() else "%s (introuvable)" % key

func _group_reference_label(key: String) -> String:
	if key.is_empty():
		return "Aucune"
	for raw: Variant in _chapter_entities():
		var candidate := raw as Dictionary
		if String(candidate.get("type", "")) != "enemy_group":
			continue
		var properties := candidate.get("properties", {}) as Dictionary
		if key in [String(candidate.get("id", "")), String(candidate.get("name", "")), String(properties.get("group_id", ""))]:
			return String(candidate.get("name", key))
	return "%s (introuvable)" % key

func _add_group_reference_details(entity: Dictionary, properties: Dictionary, key: String, title: String, allow_self: bool = false) -> void:
	var reference := String(properties.get(key, ""))
	var labels: Array[String] = ["Aucune"]
	var values: Array[String] = [""]
	var quick_value := reference
	for raw: Variant in _chapter_entities():
		var candidate := raw as Dictionary
		if String(candidate.get("type", "")) != "enemy_group" or (not allow_self and String(candidate.get("id", "")) == String(entity.get("id", ""))):
			continue
		var candidate_properties := candidate.get("properties", {}) as Dictionary
		var candidate_group_id := String(candidate_properties.get("group_id", ""))
		labels.append("%s  —  %s" % [String(candidate.get("name", "Troupe")), candidate_group_id])
		values.append(candidate_group_id)
		if reference in [candidate_group_id, String(candidate.get("id", "")), String(candidate.get("name", ""))]:
			quick_value = candidate_group_id
	_add_mapped_option_field("Choix rapide", labels, values, quick_value, func(value: String) -> void: _set_property(entity, key, value))
	_add_text_field("%s — nom ou ID" % title, reference, func(value: String) -> void: _set_property(entity, key, value.strip_edges()))
	var resolved_name := _group_reference_label(reference)
	var details := _label("Selection actuelle : %s\nReference enregistree : %s" % [resolved_name, reference if not reference.is_empty() else "aucune"], 11, Color("6fe1bd") if not reference.is_empty() and not resolved_name.contains("introuvable") else Color("ef8a7e"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(details)

func _add_trigger_reference_details(entity: Dictionary, properties: Dictionary, key: String, title: String) -> void:
	var reference := String(properties.get(key, ""))
	var labels: Array[String] = ["Aucun — arret au total maximum"]
	var values: Array[String] = [""]
	var quick_value := reference
	for raw: Variant in _chapter_entities():
		var candidate := raw as Dictionary
		if String(candidate.get("type", "")) != "trigger":
			continue
		var candidate_id := String(candidate.get("id", ""))
		labels.append(String(candidate.get("name", "Declencheur")))
		values.append(candidate_id)
		if reference in [candidate_id, String(candidate.get("name", ""))]:
			quick_value = candidate_id
	_add_mapped_option_field("Choix rapide", labels, values, quick_value, func(value: String) -> void: _set_property(entity, key, value))
	_add_text_field("%s — nom ou ID" % title, reference, func(value: String) -> void: _set_property(entity, key, value.strip_edges()))
	var resolved := _entity_reference_label(reference)
	var details := _label("Evenement selectionne : %s" % resolved, 11, Color("6fe1bd") if not reference.is_empty() and not resolved.contains("introuvable") else Color("8393aa"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_content.add_child(details)

func _add_door_reference_details(entity: Dictionary, properties: Dictionary, key: String, title: String) -> void:
	var reference := String(properties.get(key, ""))
	var labels: Array[String] = ["Aucune"]
	var values: Array[String] = [""]
	var quick_value := reference
	for raw: Variant in _chapter_entities():
		var candidate := raw as Dictionary
		if String(candidate.get("type", "")) != "door":
			continue
		var candidate_id := String(candidate.get("id", ""))
		labels.append(String(candidate.get("name", "Porte")))
		values.append(candidate_id)
		if reference in [candidate_id, String(candidate.get("name", ""))]:
			quick_value = candidate_id
	_add_mapped_option_field("Choix rapide", labels, values, quick_value, func(value: String) -> void: _set_property(entity, key, value))
	_add_text_field("%s — nom ou ID" % title, reference, func(value: String) -> void: _set_property(entity, key, value.strip_edges()))
	var resolved := _entity_reference_label(reference)
	inspector_content.add_child(_label("Porte selectionnee : %s" % resolved, 11, Color("6fe1bd") if not reference.is_empty() and not resolved.contains("introuvable") else Color("ef8a7e")))

func _set_composition_entry(entity: Dictionary, index: int, key: String, value: Variant) -> void:
	if rebuilding_inspector:
		return
	var properties := entity.get("properties", {}) as Dictionary
	var composition := properties.get("composition", []) as Array
	if index < 0 or index >= composition.size():
		return
	var entry := composition[index] as Dictionary
	if entry.get(key) == value:
		return
	_push_undo()
	entry[key] = value
	var total := 0
	for raw: Variant in composition:
		if raw is Dictionary:
			total += maxi(0, int((raw as Dictionary).get("count", 0)))
	properties["count"] = total
	properties["archetype"] = String((composition[0] as Dictionary).get("archetype", properties.get("archetype", "nathenian1")))
	_mark_changed()
	_rebuild_inspector()

func _clear_group_composition(entity: Dictionary) -> void:
	var properties := entity.get("properties", {}) as Dictionary
	if not properties.has("composition"):
		return
	_push_undo()
	properties.erase("composition")
	_mark_changed()
	_rebuild_inspector()

func _mark_changed() -> void:
	dirty = true; preview_rebuild_pending = true; _refresh_hierarchy(); _update_population(); world_name.text = String(document.data.get("name", "Monde")) + " *"

func _rebuild_preview() -> void:
	if runtime == null: return
	preview_rebuild_pending = false
	runtime.build(document, true, Vector3.ZERO, INF, active_chapter_id); editor_camera.current = true; _refresh_hierarchy(); _rebuild_inspector(); _update_population(); _update_selection_marker()

func _update_population() -> void:
	var count := document.theoretical_mob_count(active_chapter_id); var limit := document.warning_limit(); population_label.text = "%d / %d mobs • %s" % [count, limit, _chapter_name(active_chapter_id)]; population_label.modulate = Color("ef6a62") if count >= limit else (Color("f0c56a") if count >= int(limit * 0.75) else Color("76d4ab")); if count >= limit: _set_status("ATTENTION : %d ennemis peuvent etre actifs dans ce chapitre." % count, true)

func _on_viewport_pressed(screen_position: Vector2) -> void:
	var hit := _ray_hit(screen_position, 32 | 16 | 1)
	var collider := hit.get("collider") as Node if not hit.is_empty() else null
	if tool_mode == "terrain":
		_begin_terrain_stroke(screen_position)
		return
	var move_modifier := "vertical" if Input.is_key_pressed(KEY_SHIFT) else ("horizontal" if Input.is_key_pressed(KEY_CTRL) else "")
	if tool_mode == "select" and not move_modifier.is_empty():
		var move_id := selected_id if collider != null and (collider.has_meta("gizmo_axis") or collider.has_meta("gizmo_uniform")) else _entity_id_from_hit(hit)
		var move_entity := document.find_entity(move_id)
		if not move_entity.is_empty() and _entity_matches_mode(move_entity):
			selected_id = move_id
			_refresh_hierarchy()
			_rebuild_inspector()
			_update_selection_marker()
			_begin_move(move_entity, screen_position, move_modifier)
			return
	if tool_mode == "select" and not hit.is_empty():
		if collider != null and (collider.has_meta("gizmo_axis") or collider.has_meta("gizmo_uniform")):
			_begin_resize(collider, screen_position)
			return
	if tool_mode == "brush":
		var placement := _placement_position(screen_position)
		if not brush_position_valid:
			_set_status("Placement impossible : visez le dessus d'un sol.", true)
			return
		_begin_brush_stroke(placement)
		return
	var entity_id := _entity_id_from_hit(hit)
	var entity := document.find_entity(entity_id)
	if entity.is_empty() or not _entity_matches_mode(entity):
		if tool_mode == "select":
			selected_id = ""
			_refresh_hierarchy()
			_rebuild_inspector()
			_update_selection_marker()
		return
	if tool_mode == "eraser":
		selected_id = entity_id
		_delete_selected()
		return
	selected_id = entity_id
	_refresh_hierarchy()
	_rebuild_inspector()
	_update_selection_marker()

func _ray_hit(screen_position: Vector2, mask: int) -> Dictionary:
	var origin := editor_camera.project_ray_origin(screen_position)
	var end := origin + editor_camera.project_ray_normal(screen_position) * 4000.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
	# Triggers and chapter passages are Area3D nodes. Keep them selectable just
	# like surfaces and props instead of letting the ray pass through to the floor.
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _entity_id_from_hit(hit: Dictionary) -> String:
	if hit.is_empty():
		return ""
	var node := hit.get("collider") as Node
	while node != null and not node.has_meta("world_entity_id"):
		node = node.get_parent()
	return String(node.get_meta("world_entity_id", "")) if node != null else ""

func _placement_position(screen_position: Vector2) -> Vector3:
	var hit := _ray_hit(screen_position, 1)
	var origin := editor_camera.project_ray_origin(screen_position)
	var direction := editor_camera.project_ray_normal(screen_position)
	var intersection: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	var point := intersection as Vector3 if intersection is Vector3 else Vector3.ZERO
	brush_position_valid = brush_type == "surface" and hit.is_empty()
	if not hit.is_empty():
		var hit_entity := document.find_entity(_entity_id_from_hit(hit))
		var properties := hit_entity.get("properties", {}) as Dictionary
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var hit_type := String(hit_entity.get("type", ""))
		var walkable_surface := hit_type == "terrain" or (hit_type == "surface" and String(properties.get("shape", "")) == "floor")
		if walkable_surface and normal.y > 0.40:
			point = hit.get("position", point)
			brush_position_valid = true
	var grid_value := float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0))
	point.x = snappedf(point.x, grid_value)
	point.z = snappedf(point.z, grid_value)
	if brush_type == "surface":
		var size := WorldDocumentScript.vector3(brush_properties.get("size", [1, 1, 1]), Vector3.ONE)
		point.y = snappedf(point.y, grid_value * 0.25) + size.y * 0.5
	elif brush_type in ["door", "chapter_portal"]:
		var size := WorldDocumentScript.vector3(brush_properties.get("size", [1, 1, 1]), Vector3.ONE)
		point.y += size.y * 0.5
	return point

func _begin_patrol_mapping(entity: Dictionary) -> void:
	if entity.is_empty():
		return
	var properties := entity.get("properties", {}) as Dictionary
	var route_id := String(properties.get("route_id", ""))
	if route_id.is_empty():
		route_id = "patrouille_%s" % _slug(String(properties.get("group_id", entity.get("name", "troupe"))))
		_push_undo()
		properties["route_id"] = route_id
		_mark_changed()
	capture_mode = "patrol"
	capture_source_id = String(entity.get("id", ""))
	capture_route_id = route_id
	capture_route_order = 0
	for raw: Variant in _chapter_entities():
		var point := raw as Dictionary
		var point_properties := point.get("properties", {}) as Dictionary
		if String(point.get("type", "")) == "patrol_point" and String(point_properties.get("route_id", "")) == route_id:
			capture_route_order = maxi(capture_route_order, int(point_properties.get("order", 0)) + 1)
	_show_capture_overlay("⌖  PATROUILLE • clic gauche : ajouter un point • Entree/clic droit : terminer")
	_set_status("PATROUILLE — cliquez directement sur le sol pour dessiner le trajet dans l'ordre.")

func _clear_patrol_route(entity: Dictionary) -> void:
	var properties := entity.get("properties", {}) as Dictionary
	var route_id := String(properties.get("route_id", ""))
	if route_id.is_empty():
		return
	_push_undo()
	var points_to_remove: Array[String] = []
	for raw: Variant in _chapter_entities():
		var point := raw as Dictionary
		var point_properties := point.get("properties", {}) as Dictionary
		if String(point.get("type", "")) == "patrol_point" and String(point_properties.get("route_id", "")) == route_id:
			points_to_remove.append(String(point.get("id", "")))
	for point_id in points_to_remove:
		document.remove_entity(point_id)
	_mark_changed()
	_rebuild_preview()
	_set_status("%d point(s) de patrouille effaces." % points_to_remove.size())

func _begin_reference_capture(entity: Dictionary, mode: String) -> void:
	if entity.is_empty():
		return
	capture_mode = mode
	capture_source_id = String(entity.get("id", ""))
	var instruction := "Cliquez une cible dans la scene"
	match mode:
		"protect": instruction = "◎  CIBLE A PROTEGER • cliquez un objet ou une troupe"
		"spawn_trigger": instruction = "⬡  CONDITION DE SPAWN • cliquez un declencheur"
		"spawn_dead", "trigger_condition_dead": instruction = "☠  CONDITION DE MORT • cliquez une autre troupe"
		"action_group": instruction = "♟  ACTION • cliquez la troupe cible"
		"action_door": instruction = "▥  OUVERTURE • cliquez la porte a ouvrir"
		"action_narrative": instruction = "✦  NARRATION • cliquez un texte reutilisable"
		"deployment_stop_trigger": instruction = "⬡  ARRET DES VAGUES • cliquez un declencheur"
		"deployment_stop_death": instruction = "☠  ARRET DES VAGUES • cliquez la troupe dont une mort doit tout arreter"
	_show_capture_overlay("%s • clic droit/Echap : annuler" % instruction)
	_set_status("SELECTION SUR CARTE — %s." % instruction)

func _show_capture_overlay(text: String) -> void:
	if rotation_overlay != null:
		rotation_overlay.visible = true
	if rotation_label != null:
		rotation_label.text = text
	if gizmo_root != null:
		gizmo_root.visible = false

func _finish_capture_mode() -> void:
	if capture_mode.is_empty():
		return
	var finished_mode := capture_mode
	capture_mode = ""
	capture_source_id = ""
	capture_route_id = ""
	capture_route_order = 0
	if rotation_overlay != null:
		rotation_overlay.visible = false
	_rebuild_preview()
	_set_status("Trace de patrouille termine." if finished_mode == "patrol" else "Selection sur carte terminee.")

func _add_patrol_mapping_point(screen_position: Vector2) -> void:
	_add_patrol_point_at(_map_ground_position(screen_position))

func _add_patrol_point_at(position: Vector3) -> String:
	if capture_mode != "patrol" or capture_route_id.is_empty():
		return ""
	_push_undo()
	var point_name := "%s • point %d" % [capture_route_id.replace("_", " ").capitalize(), capture_route_order + 1]
	var point := WorldDocumentScript.entity("patrol_point", point_name, position, {"route_id": capture_route_id, "order": capture_route_order, "wait": 1.0})
	point["chapter"] = active_chapter_id
	var point_id := document.add_entity(point)
	capture_route_order += 1
	dirty = true
	preview_rebuild_pending = false
	_rebuild_preview()
	_show_capture_overlay("⌖  PATROUILLE • %d point(s) • clic gauche : continuer • Entree/clic droit : terminer" % capture_route_order)
	_set_status("Point %d ajoute. Continuez a cliquer pour dessiner la ronde." % capture_route_order)
	return point_id

func _map_ground_position(screen_position: Vector2) -> Vector3:
	var hit := _ray_hit(screen_position, 1)
	var origin := editor_camera.project_ray_origin(screen_position)
	var direction := editor_camera.project_ray_normal(screen_position)
	var intersection: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	var point := intersection as Vector3 if intersection is Vector3 else Vector3.ZERO
	if not hit.is_empty() and (hit.get("normal", Vector3.ZERO) as Vector3).y > 0.55:
		point = hit.get("position", point)
	var grid_value := float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0))
	point.x = snappedf(point.x, grid_value)
	point.z = snappedf(point.z, grid_value)
	point.y += 0.08
	return point

func _capture_reference_at(screen_position: Vector2) -> void:
	var hit := _ray_hit(screen_position, 16)
	if hit.is_empty():
		hit = _ray_hit(screen_position, 1)
	var target := document.find_entity(_entity_id_from_hit(hit))
	if target.is_empty():
		_set_status("Aucun element selectionnable ici. Cliquez directement sur sa forme.", true)
		return
	_assign_captured_reference(target)

func _assign_captured_reference(target: Dictionary) -> bool:
	var source := document.find_entity(capture_source_id)
	if source.is_empty() or target.is_empty():
		return false
	var target_type := String(target.get("type", ""))
	var target_id := String(target.get("id", ""))
	if target_id == capture_source_id and capture_mode != "deployment_stop_death":
		_set_status("Choisissez un autre element.", true)
		return false
	var target_properties := target.get("properties", {}) as Dictionary
	var source_properties := source.get("properties", {}) as Dictionary
	var property_key := ""
	var property_value := target_id
	match capture_mode:
		"protect":
			if target_type not in ["prop", "enemy_group", "surface"]:
				_set_status("La cible a proteger doit etre un objet, une surface ou une troupe.", true)
				return false
			property_key = "protect_target"
		"spawn_trigger":
			if target_type != "trigger":
				_set_status("Choisissez une hitbox de type Declencheur.", true)
				return false
			property_key = "spawn_trigger"
		"spawn_dead":
			if target_type != "enemy_group":
				_set_status("Choisissez une troupe ennemie.", true)
				return false
			property_key = "spawn_dead_group"
			property_value = String(target_properties.get("group_id", target_id))
		"trigger_condition_dead":
			if target_type != "enemy_group":
				_set_status("Choisissez une troupe ennemie.", true)
				return false
			property_key = "condition_group"
			property_value = String(target_properties.get("group_id", target_id))
		"action_group":
			if target_type != "enemy_group":
				_set_status("Choisissez une troupe ennemie.", true)
				return false
			property_key = "action_target"
			property_value = String(target_properties.get("group_id", target_id))
		"action_door":
			if target_type != "door":
				_set_status("Choisissez une porte animee.", true)
				return false
			property_key = "action_target"
		"action_narrative":
			if target_type != "narrative":
				_set_status("Choisissez un element de narration.", true)
				return false
			property_key = "action_target"
		"deployment_stop_trigger":
			if target_type != "trigger":
				_set_status("Choisissez un declencheur d'evenement.", true)
				return false
			property_key = "deployment_stop_trigger"
		"deployment_stop_death":
			if target_type != "enemy_group":
				_set_status("Choisissez une troupe ennemie.", true)
				return false
			property_key = "deployment_stop_group"
			property_value = String(target_properties.get("group_id", target_id))
		_:
			return false
	_push_undo()
	source_properties[property_key] = property_value
	dirty = true
	preview_rebuild_pending = false
	var label := String(target.get("name", property_value))
	_finish_capture_mode()
	_set_status("Cible liee : %s." % label)
	return true

func _begin_brush_stroke(position: Vector3) -> void:
	_push_undo()
	brush_painting = true
	brush_stroke_start = position
	brush_stroke_last = position
	brush_stroke_axis = -1
	brush_stroke_keys.clear()
	_place_brush_at(position, false, Vector3.ZERO)
	brush_stroke_first_id = selected_id
	brush_stroke_wall_oriented = false
	brush_stroke_keys[_brush_stroke_key(position)] = true

func _continue_brush_stroke(screen_position: Vector2) -> void:
	var target := _placement_position(screen_position)
	if not brush_position_valid:
		return
	_paint_brush_stroke_to(target, Input.is_key_pressed(KEY_SHIFT))

func _paint_brush_stroke_to(target: Vector3, force_straight: bool) -> void:
	var stroke_delta := target - brush_stroke_start
	if force_straight:
		if brush_stroke_axis < 0 and Vector2(stroke_delta.x, stroke_delta.z).length() > 0.05:
			brush_stroke_axis = 0 if absf(stroke_delta.x) >= absf(stroke_delta.z) else 2
		if brush_stroke_axis == 0:
			target.z = brush_stroke_start.z
		elif brush_stroke_axis == 2:
			target.x = brush_stroke_start.x
	else:
		brush_stroke_axis = -1
	var spacing := _brush_stroke_spacing()
	var segment := target - brush_stroke_last
	segment.y = 0.0
	var distance := segment.length()
	if distance < spacing * 0.72:
		return
	var direction := segment.normalized()
	if brush_type == "surface" and String(brush_properties.get("shape", "")) == "wall" and not brush_stroke_wall_oriented:
		var first_wall := document.find_entity(brush_stroke_first_id)
		if not first_wall.is_empty():
			first_wall["rotation"] = [0.0, 90.0 if absf(direction.z) > absf(direction.x) else 0.0, 0.0]
		brush_stroke_wall_oriented = true
	var steps := maxi(1, floori(distance / spacing))
	var latest_placement := brush_stroke_last
	for step_index in range(1, steps + 1):
		var position := brush_stroke_last + direction * minf(distance, spacing * float(step_index))
		position.y = target.y
		var grid_value := float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0))
		position.x = snappedf(position.x, grid_value)
		position.z = snappedf(position.z, grid_value)
		var key := _brush_stroke_key(position)
		if brush_stroke_keys.has(key):
			continue
		var rotation := Vector3.ZERO
		if brush_type == "surface" and String(brush_properties.get("shape", "")) == "wall" and absf(direction.z) > absf(direction.x):
			rotation.y = 90.0
		_place_brush_at(position, false, rotation)
		brush_stroke_keys[key] = true
		latest_placement = position
	brush_stroke_last = latest_placement

func _finish_brush_stroke() -> void:
	brush_painting = false
	brush_stroke_keys.clear()
	brush_stroke_first_id = ""
	_set_status("Creation terminee. Maintenez Maj pendant le prochain trace pour forcer une ligne droite.")

func _begin_terrain_stroke(screen_position: Vector2) -> void:
	var hit := _ray_hit(screen_position, 1)
	var entity := document.find_entity(_entity_id_from_hit(hit))
	if entity.is_empty() or String(entity.get("type", "")) != "terrain":
		_set_status("Le pinceau terrain doit commencer sur un terrain.", true)
		return
	selected_id = String(entity.get("id", ""))
	_push_undo()
	terrain_painting = true
	terrain_stroke_last = Vector3(INF, INF, INF)
	var node := runtime.nodes_by_id.get(selected_id) as Node3D
	if node == null:
		return
	var local_position := node.to_local(hit.get("position", node.global_position))
	terrain_flatten_height = local_position.y
	_apply_terrain_stamp(entity, local_position)

func _continue_terrain_stroke(screen_position: Vector2) -> void:
	if not terrain_painting:
		return
	var hit := _ray_hit(screen_position, 1)
	var entity := document.find_entity(_entity_id_from_hit(hit))
	if entity.is_empty() or String(entity.get("id", "")) != selected_id:
		return
	var node := runtime.nodes_by_id.get(selected_id) as Node3D
	if node == null:
		return
	var local_position := node.to_local(hit.get("position", node.global_position))
	if terrain_stroke_last != Vector3(INF, INF, INF) and Vector2(local_position.x - terrain_stroke_last.x, local_position.z - terrain_stroke_last.z).length() < maxf(0.2, terrain_brush_radius * 0.18):
		return
	_apply_terrain_stamp(entity, local_position)

func _apply_terrain_stamp(entity: Dictionary, local_position: Vector3) -> void:
	var mode := terrain_tool
	if Input.is_key_pressed(KEY_SHIFT):
		if mode == "raise": mode = "lower"
		elif mode == "lower": mode = "raise"
	var properties := entity.get("properties", {}) as Dictionary
	var changed := false
	match mode:
		"paint": changed = WorldTerrainScript.paint_material(properties, local_position, active_material, terrain_brush_radius, terrain_brush_strength)
		"erase_material": changed = WorldTerrainScript.paint_material(properties, local_position, active_material, terrain_brush_radius, terrain_brush_strength, true)
		"foliage": changed = WorldTerrainScript.paint_foliage(properties, local_position, terrain_brush_radius, terrain_brush_strength, false, active_foliage_preset)
		"erase_foliage": changed = WorldTerrainScript.paint_foliage(properties, local_position, terrain_brush_radius, terrain_brush_strength, true)
		_: changed = WorldTerrainScript.sculpt(properties, local_position, mode, terrain_brush_radius, terrain_brush_strength, terrain_flatten_height)
	if not changed:
		return
	terrain_stroke_last = local_position
	dirty = true
	world_name.text = String(document.data.get("name", "Monde")) + " *"
	_rebuild_terrain_live(entity)
	_update_selection_marker()

func _rebuild_terrain_live(entity: Dictionary) -> void:
	var body := runtime.nodes_by_id.get(String(entity.get("id", ""))) as StaticBody3D
	if body == null:
		return
	var properties := entity.get("properties", {}) as Dictionary
	WorldTerrainScript.rebuild_body(body, properties, MaterialLibraryScript.terrain_material(properties))

func _finish_terrain_stroke() -> void:
	if not terrain_painting:
		return
	terrain_painting = false
	terrain_stroke_last = Vector3(INF, INF, INF)
	# Keep placed props alive and rebuild only the expensive vegetation batch.
	# Rebuilding the whole preview here caused imported meshes to flicker or vanish.
	var terrain := document.find_entity(selected_id)
	var body := runtime.nodes_by_id.get(selected_id) as StaticBody3D
	if not terrain.is_empty() and body != null:
		WorldTerrainFoliageScript.rebuild(body, terrain.get("properties", {}) as Dictionary, true)
	_update_selection_marker()
	_refresh_library()
	_set_status("Trait terrain terminé. Ctrl+Z annule tout le dernier passage.")

func _brush_stroke_spacing() -> float:
	var grid_value := float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0))
	if brush_type == "prop":
		return maxf(grid_value * 0.5, float(brush_properties.get("brush_spacing", grid_value)))
	if brush_type != "surface":
		return grid_value
	var size := WorldDocumentScript.vector3(brush_properties.get("size", [1, 1, 1]), Vector3.ONE)
	return maxf(grid_value, maxf(size.x, size.z))

func _brush_stroke_key(position: Vector3) -> String:
	return "%.3f|%.3f|%.3f" % [position.x, position.y, position.z]

func _place_brush_at(position: Vector3, record_undo: bool = true, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	if record_undo:
		_push_undo()
	var properties := brush_properties.duplicate(true)
	if brush_type == "surface":
		properties["material"] = active_material
	if brush_type == "enemy_group":
		var unique_suffix := str(Time.get_ticks_msec()).right(6)
		properties["group_id"] = "%s_%s" % [String(properties.get("group_id", "groupe")), unique_suffix]
	elif brush_type == "chapter_portal":
		_apply_portal_property_defaults(properties)
	var entity := WorldDocumentScript.entity(brush_type, brush_title, position, properties)
	entity["chapter"] = active_chapter_id
	entity["rotation"] = WorldDocumentScript.array3(rotation_degrees)
	selected_id = document.add_entity(entity)
	dirty = true
	preview_rebuild_pending = false
	_rebuild_preview()
	_set_status("%s pose. Gardez le clic enfonce pour continuer ; Maj force une ligne droite." % brush_title)

func _update_hover_and_cursor(screen_position: Vector2) -> void:
	if editor_camera == null or _mouse_over_editor_ui() or orbiting or panning or resizing or moving_entity or rotating_entity:
		_set_hovered_gizmo_handle(null)
		if hover_marker != null: hover_marker.visible = false
		return
	if tool_mode == "terrain":
		brush_cursor.visible = false
		hover_marker.visible = false
		_set_hovered_gizmo_handle(null)
		var terrain_hit := _ray_hit(screen_position, 1)
		var terrain_entity := document.find_entity(_entity_id_from_hit(terrain_hit))
		var terrain_valid := not terrain_entity.is_empty() and String(terrain_entity.get("type", "")) == "terrain"
		terrain_brush_marker.visible = terrain_valid
		if terrain_valid:
			var hit_position: Vector3 = terrain_hit.get("position", Vector3.ZERO)
			terrain_brush_marker.global_position = hit_position + Vector3.UP * 0.04
			terrain_brush_marker.scale = Vector3(terrain_brush_radius, 1.0, terrain_brush_radius)
			var terrain_material := terrain_brush_marker.material_override as StandardMaterial3D
			terrain_material.albedo_color = {
				"raise": Color(0.25, 0.95, 0.58, 0.42), "lower": Color(0.95, 0.35, 0.24, 0.42),
				"smooth": Color(0.30, 0.72, 1.0, 0.42), "flatten": Color(0.95, 0.73, 0.28, 0.42),
				"paint": Color(0.60, 0.92, 0.30, 0.48), "erase_material": Color(0.78, 0.72, 0.62, 0.44),
				"foliage": Color(0.18, 0.86, 0.30, 0.52), "erase_foliage": Color(0.88, 0.28, 0.18, 0.48),
			}.get(terrain_tool, Color(0.35, 0.95, 0.70, 0.42))
		return
	terrain_brush_marker.visible = false
	if tool_mode == "brush":
		_set_hovered_gizmo_handle(null)
		brush_cursor.visible = true
		brush_cursor.position = _placement_position(screen_position)
		_update_brush_cursor_shape()
		var cursor_material := brush_cursor.material_override as StandardMaterial3D
		cursor_material.albedo_color = Color(0.35, 0.95, 0.70, 0.36) if brush_position_valid else Color(1.0, 0.18, 0.14, 0.40)
		hover_marker.visible = false
		return
	brush_cursor.visible = false
	var reference_capture_active := not capture_mode.is_empty() and capture_mode != "patrol"
	var hit := _ray_hit(screen_position, 16 if reference_capture_active else (32 | 16 | 1))
	var collider := hit.get("collider") as Node if not hit.is_empty() else null
	if collider != null and (collider.has_meta("gizmo_axis") or collider.has_meta("gizmo_uniform")):
		_set_hovered_gizmo_handle(collider as StaticBody3D)
		hover_marker.visible = false
		return
	_set_hovered_gizmo_handle(null)
	hover_id = _entity_id_from_hit(hit)
	var entity := document.find_entity(hover_id)
	if entity.is_empty() or not _entity_matches_mode(entity):
		hover_marker.visible = false
		return
	var size := _entity_visual_size(entity)
	hover_marker.visible = true
	hover_marker.position = _entity_visual_center(entity)
	hover_marker.rotation_degrees = WorldDocumentScript.vector3(entity.get("rotation", []))
	hover_marker.scale = size * 1.045
	var material := hover_marker.material_override as StandardMaterial3D
	material.albedo_color = Color(1.0, 0.18, 0.14, 0.30) if tool_mode == "eraser" else Color(0.30, 0.76, 1.0, 0.20)

func _set_hovered_gizmo_handle(handle: StaticBody3D) -> void:
	if hovered_gizmo_handle == handle:
		return
	if hovered_gizmo_handle != null and is_instance_valid(hovered_gizmo_handle):
		var previous_mesh := hovered_gizmo_handle.get_child(0) as MeshInstance3D
		if previous_mesh != null:
			previous_mesh.scale = Vector3.ONE
	hovered_gizmo_handle = handle
	if hovered_gizmo_handle != null and is_instance_valid(hovered_gizmo_handle):
		var active_mesh := hovered_gizmo_handle.get_child(0) as MeshInstance3D
		if active_mesh != null:
			active_mesh.scale = Vector3.ONE * 1.55
		brush_label.text = "ECHELLE GLOBALE • cliquez-glissez\nLes proportions sont conservees" if hovered_gizmo_handle.has_meta("gizmo_uniform") else "POIGNEE SURVOLEE • cliquez-glissez\nRouge X  •  Vert hauteur  •  Bleu Z"
	elif tool_mode == "select" and brush_label != null:
		brush_label.text = "SÉLECTION  •  clic : choisir\nCtrl + glisser : plan  •  Maj + glisser : hauteur\nR : tourner  •  Maj+R : incliner"

func _build_editor_visuals() -> void:
	selection_marker = _transparent_box(Color(0.37, 0.94, 0.75, 0.20))
	selection_marker.visible = false
	add_child(selection_marker)
	hover_marker = _transparent_box(Color(0.30, 0.76, 1.0, 0.20))
	hover_marker.visible = false
	add_child(hover_marker)
	brush_cursor = _transparent_box(Color(0.35, 0.95, 0.70, 0.36))
	brush_cursor.visible = false
	add_child(brush_cursor)
	ground_snap_marker = _transparent_box(Color(0.18, 1.0, 0.48, 0.42))
	ground_snap_marker.visible = false
	add_child(ground_snap_marker)
	terrain_brush_marker = MeshInstance3D.new()
	terrain_brush_marker.name = "TerrainBrushMarker"
	var terrain_cursor_mesh := CylinderMesh.new()
	terrain_cursor_mesh.top_radius = 1.0
	terrain_cursor_mesh.bottom_radius = 1.0
	terrain_cursor_mesh.height = 0.025
	terrain_cursor_mesh.radial_segments = 48
	terrain_brush_marker.mesh = terrain_cursor_mesh
	var terrain_cursor_material := StandardMaterial3D.new()
	terrain_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	terrain_cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	terrain_cursor_material.albedo_color = Color(0.25, 0.95, 0.58, 0.42)
	terrain_cursor_material.no_depth_test = true
	terrain_brush_marker.material_override = terrain_cursor_material
	terrain_brush_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_brush_marker.visible = false
	add_child(terrain_brush_marker)
	rotation_indicator = MeshInstance3D.new()
	rotation_indicator.name = "RotationAxisIndicator"
	rotation_indicator.visible = false
	rotation_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rotation_indicator)
	gizmo_root = Node3D.new()
	gizmo_root.name = "SurfaceResizeGizmo"
	add_child(gizmo_root)

func _transparent_box(color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _update_brush_cursor_shape() -> void:
	if brush_type in ["surface", "door", "chapter_portal"]:
		brush_cursor.scale = WorldDocumentScript.vector3(brush_properties.get("size", [1, 1, 1]), Vector3.ONE) * 1.01
	else:
		brush_cursor.scale = Vector3(1.0, 0.08, 1.0)

func _entity_visual_size(entity: Dictionary) -> Vector3:
	var runtime_node := runtime.nodes_by_id.get(String(entity.get("id", ""))) as Node3D if runtime != null else null
	if runtime_node != null and runtime_node.has_meta("editor_local_bounds"):
		var bounds := runtime_node.get_meta("editor_local_bounds") as AABB
		var basis_scale := runtime_node.global_basis.get_scale().abs()
		return bounds.size * basis_scale
	var properties := entity.get("properties", {}) as Dictionary
	var entity_scale := WorldDocumentScript.vector3(entity.get("scale", []), Vector3.ONE).abs()
	if properties.has("size"):
		return WorldDocumentScript.vector3(properties.get("size", []), Vector3.ONE) * entity_scale
	match String(entity.get("type", "")):
		"enemy_group": return Vector3(5.0, 2.4, 4.0) * entity_scale
		"prop": return Vector3(1.6, 2.2, 1.6) * entity_scale
		"light": return Vector3.ONE * entity_scale
		_: return Vector3(1.4, 2.0, 1.4) * entity_scale

func _entity_visual_center(entity: Dictionary) -> Vector3:
	var runtime_node := runtime.nodes_by_id.get(String(entity.get("id", ""))) as Node3D if runtime != null else null
	if runtime_node != null and runtime_node.has_meta("editor_local_bounds"):
		var bounds := runtime_node.get_meta("editor_local_bounds") as AABB
		return runtime_node.to_global(bounds.get_center())
	return WorldDocumentScript.vector3(entity.get("position", []))

func _update_selection_marker() -> void:
	if selection_marker == null: return
	var entity := document.find_entity(selected_id); selection_marker.visible = not entity.is_empty() and not test_mode
	if entity.is_empty():
		_clear_gizmo()
		return
	selection_marker.position = _entity_visual_center(entity)
	selection_marker.rotation_degrees = WorldDocumentScript.vector3(entity.get("rotation", []))
	var size := _entity_visual_size(entity)
	selection_marker.scale = size * 1.03
	_refresh_gizmo(entity, size)

func _refresh_gizmo(entity: Dictionary, size: Vector3) -> void:
	var entity_type := String(entity.get("type", ""))
	var wants_gizmo := tool_mode == "select" and entity_type in ["surface", "prop"] and not test_mode and not rotating_entity
	var signature := "%s|%s|%s|%s|%s" % [selected_id, str(size), str(entity.get("position", [])), str(entity.get("rotation", [])), str(entity.get("scale", []))]
	if not wants_gizmo:
		_clear_gizmo()
		return
	if String(gizmo_root.get_meta("signature", "")) == signature:
		return
	_clear_gizmo()
	gizmo_root.set_meta("signature", signature)
	gizmo_root.visible = true
	gizmo_root.position = _entity_visual_center(entity)
	gizmo_root.rotation_degrees = WorldDocumentScript.vector3(entity.get("rotation", []))
	if entity_type == "prop":
		_add_uniform_scale_handle(size)
		return
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var colors := [Color("ef5555"), Color("65df7d"), Color("5794ff")]
	for axis_index in range(3):
		for sign_value in [-1.0, 1.0]:
			var handle := StaticBody3D.new()
			handle.collision_layer = 32
			handle.collision_mask = 0
			handle.position = axes[axis_index] * size[axis_index] * 0.5 * sign_value
			handle.set_meta("gizmo_axis", axis_index)
			handle.set_meta("gizmo_sign", sign_value)
			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3.ONE * maxf(0.32, camera_distance * 0.014)
			mesh_instance.mesh = mesh
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = colors[axis_index]
			material.emission_enabled = true
			material.emission = colors[axis_index] * 0.55
			material.no_depth_test = true
			mesh_instance.material_override = material
			handle.add_child(mesh_instance)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3.ONE * maxf(0.48, camera_distance * 0.020)
			collision.shape = shape
			handle.add_child(collision)
			gizmo_root.add_child(handle)
			gizmo_handles.append(handle)

func _add_uniform_scale_handle(size: Vector3) -> void:
	var handle := StaticBody3D.new()
	handle.collision_layer = 32
	handle.collision_mask = 0
	handle.position = Vector3(size.x, size.y, size.z) * 0.5
	handle.set_meta("gizmo_uniform", true)
	var camera_gap := editor_camera.global_position.distance_to(gizmo_root.global_position)
	var handle_size := clampf(camera_gap * 0.025, 0.28, 0.85)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = handle_size * 0.5
	mesh.height = handle_size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("f3b84f")
	material.emission_enabled = true
	material.emission = Color("f3b84f") * 0.7
	material.no_depth_test = true
	mesh_instance.material_override = material
	handle.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = handle_size * 0.72
	collision.shape = shape
	handle.add_child(collision)
	gizmo_root.add_child(handle)
	gizmo_handles.append(handle)

func _clear_gizmo() -> void:
	if gizmo_root == null:
		return
	gizmo_root.visible = false
	gizmo_root.remove_meta("signature")
	gizmo_handles.clear()
	for child: Node in gizmo_root.get_children():
		child.queue_free()

func _begin_rotation(axis: int) -> void:
	var entity := document.find_entity(selected_id)
	if entity.is_empty():
		_set_status("Rotation impossible : selectionnez d'abord un element.", true)
		return
	if tool_mode != "select":
		_set_tool_mode("select")
	_push_undo()
	rotating_entity = true
	rotation_axis = axis
	rotation_start_mouse = last_mouse_position
	rotation_original = WorldDocumentScript.vector3(entity.get("rotation", []))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_gizmo()
	if rotation_overlay != null:
		rotation_overlay.visible = true
	_update_rotation_indicator(entity)
	_update_rotation_label(0.0)
	_set_status("ROTATION ACTIVE — deplacez la souris • clic gauche/Entree : valider • clic droit/Echap : annuler • Ctrl : pas de 15°.")

func _update_rotation(screen_position: Vector2) -> void:
	var entity := document.find_entity(selected_id)
	if entity.is_empty():
		_finish_rotation(false)
		return
	var mouse_delta := screen_position.x - rotation_start_mouse.x if rotation_axis == 1 else -(screen_position.y - rotation_start_mouse.y)
	var angle := mouse_delta * 0.45
	angle = snappedf(angle, 15.0) if Input.is_key_pressed(KEY_CTRL) else snappedf(angle, 0.5)
	var rotation := rotation_original
	rotation[rotation_axis] = rotation_original[rotation_axis] + angle
	entity["rotation"] = WorldDocumentScript.array3(rotation)
	dirty = true
	var runtime_node := runtime.nodes_by_id.get(selected_id) as Node3D
	if runtime_node != null:
		runtime_node.rotation_degrees = rotation
	_update_selection_marker()
	_update_rotation_indicator(entity)
	_update_rotation_label(angle)

func _finish_rotation(commit: bool) -> void:
	if not rotating_entity:
		return
	var entity := document.find_entity(selected_id)
	if not commit and not entity.is_empty():
		entity["rotation"] = WorldDocumentScript.array3(rotation_original)
	rotating_entity = false
	if rotation_indicator != null:
		rotation_indicator.visible = false
	if rotation_overlay != null:
		rotation_overlay.visible = false
	preview_rebuild_pending = false
	_rebuild_preview()
	_set_status("Rotation validee." if commit else "Rotation annulee.")

func _update_rotation_label(angle: float) -> void:
	if rotation_label == null:
		return
	rotation_label.text = ("↻  HORIZONTALE • axe Y • %+.1f°" if rotation_axis == 1 else "↕  VERTICALE • axe local X • %+.1f°") % angle

func _update_rotation_indicator(entity: Dictionary) -> void:
	if rotation_indicator == null:
		return
	var size := _entity_visual_size(entity)
	var radius := maxf(0.8, (maxf(size.x, size.z) if rotation_axis == 1 else maxf(size.y, size.z)) * 0.62 + 0.35)
	var color := Color("f1c979") if rotation_axis == 1 else Color("ff6f68")
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.75
	material.no_depth_test = true
	var immediate := ImmediateMesh.new()
	for band: float in [-0.035, 0.0, 0.035]:
		immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
		for index in range(65):
			var angle := TAU * float(index) / 64.0
			var band_radius := radius + band
			immediate.surface_add_vertex(Vector3(cos(angle) * band_radius, 0.0, sin(angle) * band_radius))
		immediate.surface_end()
	rotation_indicator.mesh = immediate
	rotation_indicator.visible = true
	rotation_indicator.position = _entity_visual_center(entity)
	var entity_rotation := WorldDocumentScript.vector3(entity.get("rotation", []))
	rotation_indicator.rotation_degrees = Vector3.ZERO if rotation_axis == 1 else Vector3(0.0, entity_rotation.y, 90.0)

func _begin_move(entity: Dictionary, screen_position: Vector2, mode: String) -> void:
	_push_undo()
	moving_entity = true
	move_mode = mode
	move_original_position = WorldDocumentScript.vector3(entity.get("position", []))
	move_bottom_offset = _entity_bottom_offset(entity)
	if move_mode == "horizontal":
		move_drag_start_world = _screen_plane_point(screen_position, move_original_position.y)
		_set_status("DEPLACEMENT HORIZONTAL — gardez Ctrl et glissez sur le plan. Relachez pour valider.")
	else:
		move_axis_origin = _entity_visual_center(entity)
		move_drag_start_screen = screen_position
		var camera_gap := maxf(0.2, editor_camera.global_position.distance_to(move_axis_origin))
		var viewport_height := maxf(1.0, get_viewport().get_visible_rect().size.y)
		move_vertical_world_per_pixel = maxf(0.001, 2.0 * camera_gap * tan(deg_to_rad(editor_camera.fov * 0.5)) / viewport_height)
		_update_ground_snap_marker({})
		_set_status("DEPLACEMENT VERTICAL — gardez Maj et glissez. Le sol devient vert quand le bas est aligne.")

func _update_move(screen_position: Vector2) -> void:
	var entity := document.find_entity(selected_id)
	if entity.is_empty():
		_finish_move()
		return
	var new_position := move_original_position
	var grid_value := float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0))
	if move_mode == "horizontal":
		var current_point := _screen_plane_point(screen_position, move_original_position.y)
		var delta := current_point - move_drag_start_world
		new_position.x = snappedf(move_original_position.x + delta.x, grid_value)
		new_position.z = snappedf(move_original_position.z + delta.z, grid_value)
		_update_ground_snap_marker({})
	else:
		var vertical_delta := -(screen_position.y - move_drag_start_screen.y) * move_vertical_world_per_pixel
		new_position.y = move_original_position.y + vertical_delta
		var bottom_y := new_position.y + move_bottom_offset
		var support := _find_support_floor(entity, Vector2(new_position.x, new_position.z), bottom_y)
		if not support.is_empty():
			var support_top := float(support.get("top", bottom_y))
			var visual_height := _entity_visual_size(entity).y
			var snap_distance := clampf(maxf(grid_value * 0.65, visual_height * 0.35), 0.60, 2.0)
			if absf(bottom_y - support_top) <= snap_distance:
				new_position.y += support_top - bottom_y
				_update_ground_snap_marker(support.get("entity", {}) as Dictionary, new_position, support_top)
			else:
				_update_ground_snap_marker({})
		else:
			_update_ground_snap_marker({})
	entity["position"] = WorldDocumentScript.array3(new_position)
	dirty = true
	var runtime_node := runtime.nodes_by_id.get(selected_id) as Node3D
	if runtime_node != null:
		runtime_node.position = new_position
	_update_selection_marker()

func _finish_move() -> void:
	if not moving_entity:
		return
	var finished_mode := move_mode
	moving_entity = false
	move_mode = ""
	_update_ground_snap_marker({})
	preview_rebuild_pending = false
	_rebuild_preview()
	_set_status("Position verticale validee." if finished_mode == "vertical" else "Position horizontale validee.")

func _screen_plane_point(screen_position: Vector2, plane_height: float) -> Vector3:
	var origin := editor_camera.project_ray_origin(screen_position)
	var direction := editor_camera.project_ray_normal(screen_position)
	var intersection: Variant = Plane(Vector3.UP, plane_height).intersects_ray(origin, direction)
	return intersection as Vector3 if intersection is Vector3 else move_original_position

func _entity_bottom_offset(entity: Dictionary) -> float:
	var entity_scale := WorldDocumentScript.vector3(entity.get("scale", []), Vector3.ONE)
	if String(entity.get("type", "")) == "prop":
		var runtime_node := runtime.nodes_by_id.get(String(entity.get("id", ""))) as Node3D
		if runtime_node != null and runtime_node.has_meta("editor_local_bounds"):
			var bounds := runtime_node.get_meta("editor_local_bounds") as AABB
			return bounds.position.y * entity_scale.y
	var properties := entity.get("properties", {}) as Dictionary
	if properties.has("size"):
		return -WorldDocumentScript.vector3(properties.get("size", []), Vector3.ONE).y * entity_scale.y * 0.5
	return 0.0

func _find_support_floor(moved_entity: Dictionary, world_xz: Vector2, bottom_y: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for raw: Variant in _chapter_entities():
		var floor_entity := raw as Dictionary
		if String(floor_entity.get("id", "")) == String(moved_entity.get("id", "")) or not bool(floor_entity.get("enabled", true)):
			continue
		var floor_type := String(floor_entity.get("type", ""))
		var properties := floor_entity.get("properties", {}) as Dictionary
		if floor_type == "terrain":
			var terrain_node := runtime.nodes_by_id.get(String(floor_entity.get("id", ""))) as Node3D
			if terrain_node == null:
				continue
			var terrain_local := terrain_node.to_local(Vector3(world_xz.x, terrain_node.global_position.y, world_xz.y))
			if not WorldTerrainScript.contains_local_point(properties, terrain_local.x, terrain_local.z):
				continue
			var terrain_top := terrain_node.to_global(Vector3(terrain_local.x, WorldTerrainScript.height_at(properties, terrain_local.x, terrain_local.z), terrain_local.z)).y
			var terrain_distance := absf(bottom_y - terrain_top)
			if terrain_distance < best_distance:
				best_distance = terrain_distance
				best = {"entity": floor_entity, "top": terrain_top}
			continue
		if floor_type != "surface" or String(properties.get("shape", "")) != "floor":
			continue
		var floor_position := WorldDocumentScript.vector3(floor_entity.get("position", []))
		var floor_rotation := WorldDocumentScript.vector3(floor_entity.get("rotation", []))
		var floor_scale := WorldDocumentScript.vector3(floor_entity.get("scale", []), Vector3.ONE).abs()
		var floor_size := WorldDocumentScript.vector3(properties.get("size", []), Vector3.ONE) * floor_scale
		var basis := Basis.from_euler(Vector3(deg_to_rad(floor_rotation.x), deg_to_rad(floor_rotation.y), deg_to_rad(floor_rotation.z)))
		var local_point := basis.inverse() * (Vector3(world_xz.x, floor_position.y, world_xz.y) - floor_position)
		if absf(local_point.x) > floor_size.x * 0.5 or absf(local_point.z) > floor_size.z * 0.5:
			continue
		var top := floor_position.y + (basis * Vector3.UP).y * floor_size.y * 0.5
		var distance := absf(bottom_y - top)
		if distance < best_distance:
			best_distance = distance
			best = {"entity": floor_entity, "top": top}
	return best

func _update_ground_snap_marker(floor_entity: Dictionary, world_position: Vector3 = Vector3.ZERO, top_override: float = INF) -> void:
	if ground_snap_marker == null:
		return
	if floor_entity.is_empty():
		ground_snap_marker.visible = false
		return
	if String(floor_entity.get("type", "")) == "terrain":
		ground_snap_marker.visible = true
		ground_snap_marker.position = Vector3(world_position.x, top_override + 0.025, world_position.z)
		ground_snap_marker.rotation_degrees = Vector3.ZERO
		ground_snap_marker.scale = Vector3(2.0, 0.05, 2.0)
		return
	var properties := floor_entity.get("properties", {}) as Dictionary
	var size := WorldDocumentScript.vector3(properties.get("size", []), Vector3.ONE) * WorldDocumentScript.vector3(floor_entity.get("scale", []), Vector3.ONE).abs()
	var rotation := WorldDocumentScript.vector3(floor_entity.get("rotation", []))
	var basis := Basis.from_euler(Vector3(deg_to_rad(rotation.x), deg_to_rad(rotation.y), deg_to_rad(rotation.z)))
	ground_snap_marker.visible = true
	ground_snap_marker.position = WorldDocumentScript.vector3(floor_entity.get("position", [])) + basis * Vector3(0.0, size.y * 0.5 + 0.025, 0.0)
	ground_snap_marker.rotation_degrees = rotation
	ground_snap_marker.scale = Vector3(size.x * 1.01, 0.05, size.z * 1.01)

func _begin_resize(handle: Node, screen_position: Vector2) -> void:
	var entity := document.find_entity(selected_id)
	if entity.is_empty():
		return
	_push_undo()
	resizing = true
	resize_uniform = bool(handle.get_meta("gizmo_uniform", false))
	resize_axis = int(handle.get_meta("gizmo_axis", 0))
	resize_sign = float(handle.get_meta("gizmo_sign", 1.0))
	resize_original_position = WorldDocumentScript.vector3(entity.get("position", []))
	resize_original_size = _entity_visual_size(entity)
	resize_original_uniform_scale = WorldDocumentScript.vector3(entity.get("scale", []), Vector3.ONE).x
	resize_axis_world = (handle.global_position - gizmo_root.global_position).normalized() if resize_uniform else (gizmo_root.global_basis * [Vector3.RIGHT, Vector3.UP, Vector3.BACK][resize_axis]).normalized()
	resize_start_scalar = _ray_axis_scalar(screen_position, gizmo_root.global_position, resize_axis_world)
	_set_status("ECHELLE GLOBALE — tirez la poignee doree ; les proportions et l'ancrage au sol sont conserves." if resize_uniform else "REDIMENSIONNEMENT — tirez la poignee, relachez pour valider. La taille reste aimantee a la grille.")

func _update_resize(screen_position: Vector2) -> void:
	var entity := document.find_entity(selected_id)
	if entity.is_empty():
		return
	var current_scalar := _ray_axis_scalar(screen_position, gizmo_root.global_position, resize_axis_world)
	if resize_uniform:
		var uniform_delta := current_scalar - resize_start_scalar
		var reference_size := maxf(0.1, resize_original_size.length())
		var uniform_scale := snappedf(maxf(0.05, resize_original_uniform_scale * (1.0 + uniform_delta / reference_size)), 0.05)
		entity["scale"] = [uniform_scale, uniform_scale, uniform_scale]
		dirty = true
		var runtime_node := runtime.nodes_by_id.get(String(entity.get("id", ""))) as Node3D
		if runtime_node != null:
			runtime_node.scale = Vector3.ONE * uniform_scale
		_update_selection_marker()
		return
	var grid_value := float((document.data.get("settings", {}) as Dictionary).get("grid_size", 1.0))
	var delta := snappedf((current_scalar - resize_start_scalar) * resize_sign, grid_value)
	var new_size := resize_original_size
	new_size[resize_axis] = maxf(grid_value * 0.25, resize_original_size[resize_axis] + delta)
	var actual_delta := new_size[resize_axis] - resize_original_size[resize_axis]
	var new_position := resize_original_position + resize_axis_world * resize_sign * actual_delta * 0.5
	entity["position"] = WorldDocumentScript.array3(new_position)
	var properties := entity.get("properties", {}) as Dictionary
	properties["size"] = WorldDocumentScript.array3(new_size)
	dirty = true
	_update_surface_live(entity, new_position, new_size)
	_update_selection_marker()

func _finish_resize() -> void:
	var was_uniform := resize_uniform
	resizing = false
	resize_uniform = false
	preview_rebuild_pending = false
	_rebuild_preview()
	_set_status("Objet redimensionne proportionnellement et toujours ancre au sol." if was_uniform else "Surface redimensionnee. Choisissez TEXTURES pour changer son materiau en un clic.")

func _ray_axis_scalar(screen_position: Vector2, line_origin: Vector3, line_direction: Vector3) -> float:
	var ray_origin := editor_camera.project_ray_origin(screen_position)
	var ray_direction := editor_camera.project_ray_normal(screen_position).normalized()
	var w0 := line_origin - ray_origin
	var b := line_direction.dot(ray_direction)
	var d := line_direction.dot(w0)
	var e := ray_direction.dot(w0)
	var denominator := 1.0 - b * b
	if absf(denominator) < 0.0001:
		return -d
	return (b * e - d) / denominator

func _update_surface_live(entity: Dictionary, position: Vector3, size: Vector3) -> void:
	var node := runtime.nodes_by_id.get(String(entity.get("id", ""))) as Node3D
	if node == null:
		return
	node.position = position
	for child: Node in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			((child as MeshInstance3D).mesh as BoxMesh).size = size
		elif child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			((child as CollisionShape3D).shape as BoxShape3D).size = size

func _focus_selected() -> void:
	var entity := document.find_entity(selected_id)
	if entity.is_empty():
		return
	var center := _entity_visual_center(entity)
	var focus_distance := clampf(_entity_visual_size(entity).length() * 2.4, 5.0, 45.0)
	camera_distance = focus_distance
	if ghost_mode:
		camera_target = center + editor_camera.global_basis.z * focus_distance
		camera_rig.position = camera_target
		editor_camera.position = Vector3.ZERO
	else:
		camera_target = center
		camera_rig.position = camera_target
		editor_camera.position.z = camera_distance

func _duplicate_selected() -> void:
	if selected_id.is_empty(): return
	_push_undo(); selected_id = document.duplicate_entity(selected_id); _mark_changed(); _rebuild_preview(); _set_status("Element duplique.")

func _delete_selected() -> void:
	if selected_id.is_empty(): return
	_push_undo(); document.remove_entity(selected_id); selected_id = ""; _mark_changed(); _rebuild_preview(); _set_status("Element supprime. Annulation possible avec Ctrl+Z.")

func _push_undo() -> void:
	undo_stack.append(document.to_json())
	if undo_stack.size() > 60:
		undo_stack.pop_front()
	redo_stack.clear()

func _undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(document.to_json())
	var restored := WorldDocumentScript.from_json(undo_stack.pop_back())
	if restored != null:
		document = restored
		if not _chapter_exists(active_chapter_id):
			active_chapter_id = document.start_chapter()
		selected_id = ""
		dirty = true
		_refresh_chapter_picker()
		_rebuild_preview()
		_set_status("Modification annulee.")

func _redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(document.to_json())
	var restored := WorldDocumentScript.from_json(redo_stack.pop_back())
	if restored != null:
		document = restored
		if not _chapter_exists(active_chapter_id):
			active_chapter_id = document.start_chapter()
		selected_id = ""
		dirty = true
		_refresh_chapter_picker()
		_rebuild_preview()
		_set_status("Modification retablie.")

func _new_world() -> void:
	_push_undo(); document = WorldDocumentScript.new(); active_chapter_id = document.start_chapter(); selected_id = ""; dirty = true; world_name.text = String(document.data.name); _refresh_chapter_picker(); _rebuild_preview(); _set_status("Nouveau monde vide.")

func _rename_world() -> void:
	var value := world_name.text.trim_suffix(" *").strip_edges(); if value.is_empty(): return
	if String(document.data.get("name", "")) != value: _push_undo(); document.data["name"] = value; dirty = true
	world_name.text = value + (" *" if dirty else "")

func _save_world() -> void:
	_rename_world()
	var filename := _slug(String(document.data.get("name", "monde"))) + ".hoplite.json"
	var path := SAVE_DIR.path_join(filename)
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_set_status("Impossible de preparer la sauvegarde %s" % path, true)
		return
	file.store_string(document.to_json())
	file.flush()
	file.close()
	var global_target := ProjectSettings.globalize_path(path)
	var global_temporary := ProjectSettings.globalize_path(temporary_path)
	var global_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(global_backup)
		DirAccess.copy_absolute(global_target, global_backup)
		DirAccess.remove_absolute(global_target)
	var rename_error := DirAccess.rename_absolute(global_temporary, global_target)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(global_backup, global_target)
		_set_status("Sauvegarde interrompue (%s). L'ancienne version a ete conservee." % error_string(rename_error), true)
		return
	dirty = false
	world_name.text = String(document.data.name)
	_refresh_save_picker()
	_set_status("Monde sauvegarde avec copie de secours. Son portail est disponible dans le laboratoire.")

func _return_to_lab() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LAB_SCENE)

func _load_selected_world() -> void:
	if save_picker.item_count == 0: _set_status("Aucun monde sauvegarde.", true); return
	var path := SAVE_DIR.path_join(String(save_picker.get_item_metadata(save_picker.selected)))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Lecture impossible.", true)
		return
	var loaded := WorldDocumentScript.from_json(file.get_as_text())
	if loaded == null:
		_set_status("Fichier de monde invalide.", true)
		return
	_push_undo(); document = loaded; active_chapter_id = document.start_chapter(); selected_id = ""; dirty = false; world_name.text = String(document.data.name); _refresh_chapter_picker(); grid.set_half_extent(float((document.data.get("settings", {}) as Dictionary).get("map_half_extent", 60.0))); _rebuild_preview(); _set_status("Monde charge : %s" % path)

func _refresh_save_picker() -> void:
	if save_picker == null: return
	save_picker.clear()
	var files := DirAccess.get_files_at(SAVE_DIR)
	files.sort()
	for filename in files:
		if filename.ends_with(".hoplite.json"):
			save_picker.add_item(filename.trim_suffix(".hoplite.json"))
			save_picker.set_item_metadata(save_picker.item_count - 1, filename)

func _start_test() -> void:
	if test_mode: return
	var report := document.validation_report()
	if not bool(report.valid):
		_set_status("Test bloque : %s" % "; ".join(report.errors), true)
		return
	test_mode = true
	selection_marker.visible = false
	grid.visible = false
	brush_cursor.visible = false
	hover_marker.visible = false
	ground_snap_marker.visible = false
	gizmo_root.visible = false
	top_bar.visible = false
	tool_rail.visible = false
	viewport_hud.visible = false
	left_panel.visible = false
	right_panel.visible = false
	bottom_bar.visible = false
	test_overlay.visible = true
	test_chapter_id = active_chapter_id
	# F6 is an authoritative gameplay test: selection and editor camera must never
	# decide which encounters, triggers or props exist in the simulated chapter.
	runtime.build(document, false, Vector3.ZERO, INF, test_chapter_id)
	runtime.chapter_transition_requested.connect(_on_test_chapter_transition_requested)
	event_runtime = EventRuntimeScript.new() as HopliteWorldEventRuntime
	add_child(event_runtime)
	event_runtime.configure(document, runtime)
	event_runtime.narrative_requested.connect(_show_narrative)
	event_runtime.music_requested.connect(_play_event_music)
	event_runtime.status_changed.connect(func(message: String) -> void: test_status.text = message)
	_update_test_status()

func _stop_test() -> void:
	if not test_mode: return
	test_mode = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event_runtime != null:
		event_runtime.queue_free()
	event_runtime = null
	if event_music_player != null:
		event_music_player.stop()
	narrative_panel.visible = false
	test_overlay.visible = false
	top_bar.visible = true
	tool_rail.visible = true
	viewport_hud.visible = true
	left_panel.visible = left_panel_open
	right_panel.visible = right_panel_open
	bottom_bar.visible = true
	runtime.build(document, true, Vector3.ZERO, INF, active_chapter_id)
	grid.visible = true
	editor_camera.current = true
	_update_selection_marker()
	_set_status("Test arrete. Retour a l'edition.")

func _on_test_chapter_transition_requested(destination_chapter: String, destination_spawn: String) -> void:
	if not test_mode or destination_chapter.is_empty():
		return
	test_status.text = "Nettoyage du chapitre precedent…"
	if event_runtime != null and is_instance_valid(event_runtime):
		event_runtime.queue_free()
	event_runtime = null
	runtime.clear_world()
	await get_tree().process_frame
	await get_tree().process_frame
	test_chapter_id = destination_chapter
	runtime.build(document, false, Vector3.ZERO, INF, test_chapter_id, destination_spawn)
	event_runtime = EventRuntimeScript.new() as HopliteWorldEventRuntime
	add_child(event_runtime)
	event_runtime.configure(document, runtime)
	event_runtime.narrative_requested.connect(_show_narrative)
	event_runtime.music_requested.connect(_play_event_music)
	event_runtime.status_changed.connect(func(message: String) -> void: test_status.text = message)
	test_status.text = "Chapitre charge : %s" % _chapter_name(test_chapter_id)

func _update_test_status() -> void:
	if runtime == null or test_status == null: return
	var living := 0
	for group_id in runtime.enemies_by_group:
		living += runtime.living_count(String(group_id))
	test_status.text = "%d ennemis actifs • Echap pour revenir a l'editeur" % living

func _show_narrative(speaker: String, text: String, duration: float) -> void:
	narrative_speaker.text = speaker.to_upper(); narrative_text.text = text; narrative_panel.visible = true; narrative_timer.start(duration)

func _play_event_music(path: String, volume_db: float) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		_set_status("Musique introuvable : %s" % path, true)
		return
	if event_music_player == null:
		event_music_player = AudioStreamPlayer.new()
		event_music_player.name = "ForgeEventMusic"
		if AudioServer.get_bus_index("HopliteMusic") >= 0:
			event_music_player.bus = &"HopliteMusic"
		add_child(event_music_player)
	event_music_player.stop()
	event_music_player.stream = stream
	event_music_player.volume_db = volume_db
	event_music_player.play()

func _mouse_over_editor_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control(); if hovered == null: return false
	return _is_descendant_of(hovered, top_bar) or _is_descendant_of(hovered, tool_rail) or _is_descendant_of(hovered, viewport_hud) or _is_descendant_of(hovered, left_panel) or _is_descendant_of(hovered, right_panel) or _is_descendant_of(hovered, bottom_bar)

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

func _panel(rect: Rect2, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _flat_style(color, Color("30343b"), 3))
	return panel

func _button(text: String, callback: Callable, color: Color = Color("252a31")) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 30
	button.focus_mode = Control.FOCUS_NONE
	var style := _flat_style(color, color.lightened(0.10), 3, 9)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.10)
	hover.border_color = Color("5c8297")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	pressed.border_color = Color("c8893f")
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(callback)
	return button

func _tool_button(text: String, callback: Callable, tooltip: String) -> Button:
	var button := _button(text, callback, Color("20242a"))
	button.custom_minimum_size = Vector2(46, 66)
	button.add_theme_font_size_override("font_size", 9)
	button.tooltip_text = tooltip
	return button

func _flat_style(color: Color, border: Color, radius: int = 3, margin: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 4.0 if margin > 0.0 else 0.0
	style.content_margin_bottom = 4.0 if margin > 0.0 else 0.0
	return style

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label

func _small_label(text: String) -> Label:
	var label := _label(text, 11, Color("929aa6")); label.custom_minimum_size.x = 88; return label

func _section(text: String) -> Label:
	var label := _label(text, 10, Color("7f8996")); label.text = text.to_upper(); label.custom_minimum_size.y = 20; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; return label

func _spin(value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new(); spin.min_value = minimum; spin.max_value = maximum; spin.step = step; spin.value = value; spin.allow_greater = true; spin.allow_lesser = true; spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return spin

func _set_status(message: String, warning: bool = false) -> void:
	if status_label != null: status_label.text = message; status_label.modulate = Color("e86d67") if warning else Color("aeb6c2")

func _slug(value: String) -> String:
	var result := value.to_lower().strip_edges()
	for character in [" ", "'", "’", "/", "\\", ":", ";", ".", ","]:
		result = result.replace(character, "_")
	while "__" in result:
		result = result.replace("__", "_")
	return result if not result.is_empty() else "monde"

func _apply_theme(_root: Node) -> void:
	var theme := Theme.new()
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", Color("d7dce4"))
	theme.set_color("font_color", "Button", Color("e5e9ef"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("f2c58b"))
	theme.set_color("font_color", "LineEdit", Color("e6eaf0"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("6f7885"))
	theme.set_color("font_color", "TextEdit", Color("e6eaf0"))
	theme.set_color("font_color", "OptionButton", Color("e3e7ed"))
	theme.set_color("font_selected_color", "TabBar", Color("eef2f6"))
	theme.set_color("font_unselected_color", "TabBar", Color("858e9a"))
	theme.set_color("font_hovered_color", "TabBar", Color("cbd2dc"))
	theme.set_color("font_color", "Tree", Color("cbd1da"))
	theme.set_color("font_selected_color", "Tree", Color.WHITE)
	theme.set_color("font_hovered_color", "Tree", Color.WHITE)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("h_separation", "Tree", 6)
	theme.set_constant("v_separation", "Tree", 4)

	var field := _flat_style(Color("15181c"), Color("343941"), 3, 7)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = Color("5b8aa3")
	for type_name: String in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type_name, field)
		theme.set_stylebox("focus", type_name, field_focus)
	var option_normal := _flat_style(Color("20242a"), Color("363b43"), 3, 7)
	var option_hover := option_normal.duplicate() as StyleBoxFlat
	option_hover.bg_color = Color("292e35")
	option_hover.border_color = Color("536e7e")
	theme.set_stylebox("normal", "OptionButton", option_normal)
	theme.set_stylebox("hover", "OptionButton", option_hover)
	theme.set_stylebox("pressed", "OptionButton", field_focus)
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "TabContainer", _flat_style(Color("191c21"), Color("30353c"), 2))
	theme.set_stylebox("tab_selected", "TabBar", _flat_style(Color("2a3037"), Color("4d6e80"), 2, 9))
	theme.set_stylebox("tab_unselected", "TabBar", _flat_style(Color("181b20"), Color("292d34"), 2, 9))
	theme.set_stylebox("tab_hovered", "TabBar", _flat_style(Color("22272d"), Color("3d454f"), 2, 9))
	theme.set_stylebox("panel", "Tree", _flat_style(Color("171a1e"), Color("2d3239"), 2, 5))
	theme.set_stylebox("selected", "Tree", _flat_style(Color("31566a"), Color("31566a"), 2, 3))
	theme.set_stylebox("selected_focus", "Tree", _flat_style(Color("31566a"), Color("6090a8"), 2, 3))
	theme.set_stylebox("hovered", "Tree", _flat_style(Color("242a31"), Color("242a31"), 2, 3))
	var separator := StyleBoxLine.new()
	separator.color = Color("333840")
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_stylebox("separator", "VSeparator", separator)
	for control: Control in [top_bar, tool_rail, viewport_hud, left_panel, right_panel, bottom_bar, test_overlay, narrative_panel, rotation_overlay]:
		control.theme = theme
