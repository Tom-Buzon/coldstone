extends CanvasLayer
class_name HopliteAudioSettings

signal closed

const GLOBAL_SETTINGS_PATH := "user://hoplite_global_settings_v1.cfg"
const DEVICE_AUTO := 0
const DEVICE_MNK := 1
const DEVICE_GAMEPAD := 2

const ATMOSPHERE_SLIDERS := [
	{"id": &"sun_energy", "label": "LUMIERE PRINCIPALE", "min": 0.0, "max": 3.0, "step": 0.01},
	{"id": &"sun_height", "label": "HAUTEUR DE LA LUMIERE", "min": 5.0, "max": 85.0, "step": 1.0},
	{"id": &"ambient", "label": "LUMIERE AMBIANTE", "min": 0.0, "max": 1.8, "step": 0.01},
	{"id": &"exposure", "label": "EXPOSITION", "min": 0.45, "max": 2.2, "step": 0.01},
	{"id": &"brazier", "label": "PUISSANCE DES BRASEROS", "min": 0.0, "max": 2.5, "step": 0.01},
	{"id": &"flicker", "label": "VIE DES FLAMMES", "min": 0.0, "max": 0.55, "step": 0.01},
	{"id": &"smoke", "label": "QUANTITE DE FUMEE", "min": 0.0, "max": 1.5, "step": 0.01},
	{"id": &"fog", "label": "BRUME ATMOSPHERIQUE", "min": 0.0, "max": 0.045, "step": 0.001},
]

const ATMOSPHERE_PRESETS := [
	{"name": "Acte actuel"},
	{"name": "Champ de bataille — poussiere doree", "sun": Color("ffb46a"), "ambient_color": Color("52647a"), "fog_color": Color("8a6340"), "values": [1.62, 24.0, 0.48, 1.12, 0.009, 0.72, 0.17, 0.90]},
	{"name": "Forteresse — torches et contraste", "sun": Color("d79557"), "ambient_color": Color("39465a"), "fog_color": Color("69513d"), "values": [1.30, 31.0, 0.34, 1.16, 0.012, 1.18, 0.22, 0.82]},
	{"name": "Donjon — braises menacantes", "sun": Color("c94b32"), "ambient_color": Color("202737"), "fog_color": Color("3e1e1b"), "values": [0.58, 16.0, 0.22, 1.24, 0.020, 1.50, 0.31, 1.20]},
	{"name": "Jour mediterraneen", "sun": Color(1.0, 0.91, 0.76), "ambient_color": Color(0.68, 0.76, 0.88), "fog_color": Color(0.74, 0.66, 0.52), "values": [1.58, 62.0, 0.74, 1.08, 0.004, 0.82, 0.10, 0.42]},
	{"name": "Nuit bleue lisible", "sun": Color(0.62, 0.72, 1.0), "ambient_color": Color(0.18, 0.28, 0.50), "fog_color": Color(0.16, 0.20, 0.32), "values": [1.65, 38.0, 0.92, 1.26, 0.006, 1.25, 0.20, 0.78]},
	{"name": "Aube brumeuse", "sun": Color("ffc6a0"), "ambient_color": Color("71819a"), "fog_color": Color("9a8174"), "values": [1.12, 12.0, 0.66, 1.16, 0.016, 0.75, 0.12, 1.10]},
	{"name": "Crepuscule de bronze", "sun": Color("ef874f"), "ambient_color": Color("5c4965"), "fog_color": Color("8b5542"), "values": [1.38, 18.0, 0.52, 1.20, 0.011, 1.05, 0.18, 0.72]},
	{"name": "Athenes en flammes", "sun": Color("ff6338"), "ambient_color": Color("382a36"), "fog_color": Color("6d3025"), "values": [0.92, 21.0, 0.38, 1.30, 0.018, 1.75, 0.32, 1.25]},
	{"name": "Orage froid", "sun": Color("a8b9d8"), "ambient_color": Color("303a4c"), "fog_color": Color("46515d"), "values": [0.72, 48.0, 0.42, 1.14, 0.022, 0.62, 0.24, 1.05]},
]

const LOD_PROFILES := [
	{"name": "QUALITE", "near": 24.0, "far": 58.0, "cull": 135.0, "threshold": 1.0},
	{"name": "EQUILIBRE", "near": 16.0, "far": 38.0, "cull": 90.0, "threshold": 2.0},
	{"name": "PERFORMANCE", "near": 10.0, "far": 26.0, "cull": 65.0, "threshold": 4.0},
	{"name": "PERSONNALISE"},
]

const ACTIONS := [
	{"id": &"move_forward", "label": "AVANCER", "mnk": "Z", "pad": "Stick G haut"},
	{"id": &"move_back", "label": "RECULER", "mnk": "S", "pad": "Stick G bas"},
	{"id": &"move_left", "label": "ALLER A GAUCHE", "mnk": "Q", "pad": "Stick G gauche"},
	{"id": &"move_right", "label": "ALLER A DROITE", "mnk": "D", "pad": "Stick G droite"},
	{"id": &"jump", "label": "SAUT / DOUBLE SAUT", "mnk": "Espace", "pad": "Croix / A"},
	{"id": &"dash", "label": "DASH / CONTRE DASH", "mnk": "Maj", "pad": "Rond / B"},
	{"id": &"slide", "label": "GLISSADE", "mnk": "Ctrl", "pad": "Carré / X"},
	{"id": &"block", "label": "PARADE", "mnk": "Clic droit", "pad": "L2 / LT"},
	{"id": &"attack_primary", "label": "ATTAQUE LEGERE / LOURDE", "mnk": "Clic gauche", "pad": "R2 / RT"},
	{"id": &"spin_attack_up", "label": "SPIRALE HAUTE", "mnk": "Molette haut", "pad": "R1 / RB"},
	{"id": &"spin_attack_down", "label": "SPIRALE BASSE", "mnk": "Molette bas", "pad": "L1 / LB"},
	{"id": &"toggle_settings", "label": "MENU PARAMETRES", "mnk": "²", "pad": "Options / Menu"},
	{"id": &"camera_left", "label": "CAMERA GAUCHE", "mnk": "Souris", "pad": "Stick D gauche", "mnk_locked": true},
	{"id": &"camera_right", "label": "CAMERA DROITE", "mnk": "Souris", "pad": "Stick D droite", "mnk_locked": true},
	{"id": &"camera_up", "label": "CAMERA HAUT", "mnk": "Souris", "pad": "Stick D haut", "mnk_locked": true},
	{"id": &"camera_down", "label": "CAMERA BAS", "mnk": "Souris", "pad": "Stick D bas", "mnk_locked": true},
]

var combat_audio: HopliteCombatAudio
var player: HopliteUALNativePlayer
var gore_hud: HopliteGoreHUD
var root: Control
var panel: PanelContainer
var tabs: TabContainer
var camera_mode_option: OptionButton
var camera_distance_slider: HSlider
var camera_distance_value: Label
var track_option: OptionButton
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var master_value: Label
var music_value: Label
var sfx_value: Label
var device_option: OptionButton
var remap_buttons: Dictionary = {}
var sfx_detail_sliders: Dictionary = {}
var display_toggles: Dictionary = {}
var atmosphere_environment: WorldEnvironment
var atmosphere_sun: DirectionalLight3D
var atmosphere_preset_option: OptionButton
var atmosphere_sliders: Dictionary = {}
var atmosphere_value_labels: Dictionary = {}
var atmosphere_aux_values := {&"brazier": 1.0, &"flicker": 0.14, &"smoke": 0.75}
var atmosphere_scene_instance_id := 0
var atmosphere_snapshot: Dictionary = {}
var lod_enabled_toggle: CheckButton
var lod_profile_option: OptionButton
var lod_sliders: Dictionary = {}
var lod_value_labels: Dictionary = {}
var lod_enabled := true
var lod_profile := 1
var lod_near_distance := 16.0
var lod_far_distance := 38.0
var lod_cull_distance := 90.0
var lod_mesh_threshold := 2.0
var detail_overlay: PanelContainer
var detail_list: VBoxContainer
var capture_overlay: PanelContainer
var capture_label: Label
var opened := false
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var previous_tree_paused := false
var toggle_block_until_ms := 0
var preferred_device := DEVICE_AUTO
var awaiting_action: StringName = StringName()
var awaiting_device := ""
var visual_settings := {
	&"combat_hud": true,
	&"combat_feedback": true,
	&"objectives": true,
	&"narration": true,
	&"gore": true,
}

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_gameplay_actions(not _has_saved_bindings())
	_load_global_settings()
	_build_ui()
	if gore_hud != null and not gore_hud.enabled_changed.is_connected(_on_gore_enabled_changed):
		gore_hud.enabled_changed.connect(_on_gore_enabled_changed)
	_sync_all()
	_apply_visual_settings()
	_apply_visible(false)

func _input(event: InputEvent) -> void:
	if not opened:
		return
	if awaiting_action != StringName():
		if _try_capture_binding(event):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_settings") and Time.get_ticks_msec() >= toggle_block_until_ms:
		set_open(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _is_settings_key(key) and Time.get_ticks_msec() >= toggle_block_until_ms:
			set_open(false)
			get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	if value == opened:
		return
	opened = value
	_apply_visible(opened)
	if opened:
		previous_mouse_mode = Input.mouse_mode
		previous_tree_paused = get_tree().paused
		toggle_block_until_ms = Time.get_ticks_msec() + 140
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		_sync_all()
		if tabs != null:
			tabs.grab_focus()
	else:
		_cancel_capture()
		if detail_overlay != null:
			detail_overlay.visible = false
		get_tree().paused = previous_tree_paused
		Input.mouse_mode = previous_mouse_mode
		closed.emit()

func is_open() -> bool:
	return opened

func _exit_tree() -> void:
	if opened and get_tree() != null:
		get_tree().paused = previous_tree_paused
		Input.mouse_mode = previous_mouse_mode

func _is_settings_key(key: InputEventKey) -> bool:
	return key.unicode == 0x00B2 or key.keycode == KEY_QUOTELEFT or key.physical_keycode == KEY_QUOTELEFT

func _apply_visible(value: bool) -> void:
	if root != null:
		root.visible = value

func _build_ui() -> void:
	root = Control.new()
	root.name = "GlobalSettingsRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -540.0
	panel.offset_right = 540.0
	panel.offset_top = -340.0
	panel.offset_bottom = 340.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.028, 0.038, 0.985), Color(0.88, 0.45, 0.10)))
	root.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 9)
	panel.add_child(outer)
	var title := Label.new()
	title.text = "PARAMETRES DE COMBAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
	outer.add_child(title)
	tabs = TabContainer.new()
	tabs.focus_mode = Control.FOCUS_ALL
	tabs.custom_minimum_size = Vector2(1040.0, 570.0)
	tabs.add_theme_font_size_override("font_size", 17)
	outer.add_child(tabs)
	_build_camera_tab()
	_build_audio_tab()
	_build_display_tab()
	_build_atmosphere_tab()
	_build_gameplay_tab()
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(footer)
	var close_button := Button.new()
	close_button.text = "²  FERMER — SAUVEGARDE AUTOMATIQUE"
	close_button.custom_minimum_size = Vector2(360.0, 38.0)
	close_button.pressed.connect(_on_close_pressed)
	footer.add_child(close_button)
	_build_sfx_detail_overlay()
	_build_capture_overlay()

func _build_camera_tab() -> void:
	var tab := _new_tab("CAMERA")
	tab.add_child(_section_label("POSITION ET CADRAGE"))
	camera_mode_option = OptionButton.new()
	camera_mode_option.custom_minimum_size = Vector2(620.0, 42.0)
	camera_mode_option.item_selected.connect(_on_camera_mode_selected)
	tab.add_child(_labeled_control("Mode caméra", camera_mode_option))
	camera_distance_slider = HSlider.new()
	camera_distance_slider.min_value = 3.5
	camera_distance_slider.max_value = 12.0
	camera_distance_slider.step = 0.1
	camera_distance_slider.custom_minimum_size = Vector2(480.0, 34.0)
	camera_distance_slider.value_changed.connect(_on_camera_distance_changed)
	camera_distance_value = Label.new()
	camera_distance_value.custom_minimum_size = Vector2(82.0, 30.0)
	camera_distance_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var distance_row := HBoxContainer.new()
	distance_row.add_child(camera_distance_slider)
	distance_row.add_child(camera_distance_value)
	tab.add_child(_labeled_control("Distance", distance_row))
	var reset_button := Button.new()
	reset_button.text = "RÉINITIALISER LE CADRAGE GLOBAL"
	reset_button.custom_minimum_size = Vector2(360.0, 42.0)
	reset_button.pressed.connect(_on_reset_camera_pressed)
	tab.add_child(reset_button)
	tab.add_child(_body_label("Mode global unique : la souris ou le stick droit garde le contrôle libre. Aucun recentrage automatique sur la direction du joueur ; seul le focus d'un adversaire épique engagé peut guider doucement le cadrage."))

func _build_audio_tab() -> void:
	var tab := _new_tab("SON")
	tab.add_child(_section_label("MIXAGE GLOBAL"))
	track_option = OptionButton.new()
	track_option.custom_minimum_size = Vector2(620.0, 40.0)
	track_option.item_selected.connect(_on_track_selected)
	tab.add_child(_labeled_control("Musique", track_option))
	var master := _volume_row("MASTER")
	master_slider = master[0]
	master_value = master[1]
	tab.add_child(master[2])
	var music := _volume_row("MUSIQUE")
	music_slider = music[0]
	music_value = music[1]
	tab.add_child(music[2])
	var sfx := _volume_row("SFX")
	sfx_slider = sfx[0]
	sfx_value = sfx[1]
	tab.add_child(sfx[2])
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	var detail_button := Button.new()
	detail_button.text = "DETAIL — REGLER CHAQUE SFX"
	detail_button.custom_minimum_size = Vector2(390.0, 44.0)
	detail_button.pressed.connect(_toggle_sfx_detail)
	tab.add_child(detail_button)
	tab.add_child(_body_label("Le volume SFX global reste un multiplicateur. Le détail permet ensuite de couper ou doser séparément impacts, armes, voix, gore et déplacements."))

func _build_display_tab() -> void:
	var tab := _new_tab("AFFICHAGE")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(990.0, 500.0)
	tab.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(_section_label("ELEMENTS VISUELS"))
	var definitions := [
		{&"id": &"combat_hud", &"label": "BARRE DE VIE ET HUD PRINCIPAL"},
		{&"id": &"combat_feedback", &"label": "COMBO, IMPACTS ET CONTRES PARFAITS"},
		{&"id": &"objectives", &"label": "OBJECTIFS ET PHASE DE MISSION"},
		{&"id": &"narration", &"label": "CARTONS NARRATIFS"},
		{&"id": &"gore", &"label": "GORE MODE ET DEMEMBREMENTS"},
	]
	for definition: Dictionary in definitions:
		var id := StringName(definition[&"id"])
		var toggle := CheckButton.new()
		toggle.text = String(definition[&"label"])
		toggle.custom_minimum_size = Vector2(720.0, 44.0)
		toggle.toggled.connect(_on_visual_toggled.bind(id))
		display_toggles[id] = toggle
		content.add_child(toggle)
	content.add_child(_section_label("LOD DES ENNEMIS"))
	lod_enabled_toggle = CheckButton.new()
	lod_enabled_toggle.text = "LOD AUTOMATIQUE SELON LA DISTANCE"
	lod_enabled_toggle.toggled.connect(_on_lod_enabled_toggled)
	content.add_child(lod_enabled_toggle)
	lod_profile_option = OptionButton.new()
	for profile: Dictionary in LOD_PROFILES:
		lod_profile_option.add_item(String(profile["name"]))
	lod_profile_option.item_selected.connect(_on_lod_profile_selected)
	content.add_child(_labeled_control("Profil", lod_profile_option))
	_add_lod_slider(content, &"near", "FIN DU LOD PROCHE", 6.0, 40.0, 1.0)
	_add_lod_slider(content, &"far", "DEBUT DU LOD LOINTAIN", 18.0, 90.0, 1.0)
	_add_lod_slider(content, &"cull", "DISTANCE D'OCCULTATION", 45.0, 180.0, 1.0)
	_add_lod_slider(content, &"threshold", "AGRESSIVITE DES MESHES", 0.5, 8.0, 0.1)
	content.add_child(_body_label("Le LOD combine la décimation automatique des meshes importés, la baisse de fréquence des animations, la suppression des ombres lointaines et l'occultation finale. Les collisions et l'IA restent actives."))
	content.add_child(_body_label("Les réglages d'affichage suivent le joueur entre le stand, les batailles et la campagne."))

func _build_atmosphere_tab() -> void:
	var tab := _new_tab("ATMOSPHERE")
	tab.add_child(_section_label("ATELIER D'ATMOSPHERE"))
	atmosphere_preset_option = OptionButton.new()
	for preset: Dictionary in ATMOSPHERE_PRESETS:
		atmosphere_preset_option.add_item(String(preset["name"]))
	atmosphere_preset_option.item_selected.connect(_on_atmosphere_preset_selected)
	tab.add_child(_labeled_control("Template", atmosphere_preset_option))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(990.0, 430.0)
	tab.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	for definition: Dictionary in ATMOSPHERE_SLIDERS:
		_add_atmosphere_slider(content, definition)
	content.add_child(_body_label("Ces valeurs agissent sur la scène actuelle. Le template Acte actuel relit l'ambiance prévue par la mission."))

func _build_gameplay_tab() -> void:
	var tab := _new_tab("JOUABILITE")
	var device_row := HBoxContainer.new()
	device_row.add_child(_fixed_label("DEVICE", 220.0))
	device_option = OptionButton.new()
	device_option.add_item("AUTO — DERNIERE ENTREE", DEVICE_AUTO)
	device_option.add_item("CLAVIER / SOURIS", DEVICE_MNK)
	device_option.add_item("MANETTE", DEVICE_GAMEPAD)
	device_option.custom_minimum_size = Vector2(430.0, 38.0)
	device_option.item_selected.connect(_on_device_selected)
	device_row.add_child(device_option)
	tab.add_child(device_row)
	var header := HBoxContainer.new()
	header.add_child(_fixed_label("ACTION", 360.0))
	header.add_child(_fixed_label("CLAVIER / SOURIS", 250.0))
	header.add_child(_fixed_label("MANETTE", 250.0))
	tab.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(990.0, 405.0)
	tab.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for definition: Dictionary in ACTIONS:
		var action := StringName(definition["id"])
		var row := HBoxContainer.new()
		row.add_child(_fixed_label(String(definition["label"]), 360.0))
		row.add_child(_remap_button(action, "mnk", String(definition["mnk"]), bool(definition.get("mnk_locked", false))))
		row.add_child(_remap_button(action, "gamepad", String(definition["pad"]), false))
		list.add_child(row)
	var context := Label.new()
	context.text = "LOURDE : maintenir Attaque • CONTRE DASH : Dash pendant l'ouverture parfaite\nCONTRE RAPPROCHE : clic droit ou R2 pendant l'ouverture parfaite"
	context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.add_theme_color_override("font_color", Color(1.0, 0.68, 0.28))
	context.add_theme_font_size_override("font_size", 15)
	list.add_child(context)
	var reset := Button.new()
	reset.text = "RESTAURER LES TOUCHES PAR DEFAUT"
	reset.pressed.connect(_reset_bindings)
	list.add_child(reset)

func _build_sfx_detail_overlay() -> void:
	detail_overlay = PanelContainer.new()
	detail_overlay.anchor_left = 0.5
	detail_overlay.anchor_right = 0.5
	detail_overlay.anchor_top = 0.5
	detail_overlay.anchor_bottom = 0.5
	detail_overlay.offset_left = -440.0
	detail_overlay.offset_right = 440.0
	detail_overlay.offset_top = -300.0
	detail_overlay.offset_bottom = 300.0
	detail_overlay.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.022, 0.032, 0.995), Color(0.28, 0.55, 1.0)))
	detail_overlay.visible = false
	root.add_child(detail_overlay)
	var stack := VBoxContainer.new()
	detail_overlay.add_child(stack)
	var title := _section_label("DETAIL DE CHAQUE SFX")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(830.0, 500.0)
	stack.add_child(scroll)
	detail_list = VBoxContainer.new()
	detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_list)
	var close := Button.new()
	close.text = "RETOUR AU MIXAGE"
	close.pressed.connect(_toggle_sfx_detail)
	stack.add_child(close)

func _build_capture_overlay() -> void:
	capture_overlay = PanelContainer.new()
	capture_overlay.anchor_left = 0.5
	capture_overlay.anchor_right = 0.5
	capture_overlay.anchor_top = 0.5
	capture_overlay.anchor_bottom = 0.5
	capture_overlay.offset_left = -330.0
	capture_overlay.offset_right = 330.0
	capture_overlay.offset_top = -80.0
	capture_overlay.offset_bottom = 80.0
	capture_overlay.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.025, 0.04, 1.0), Color(1.0, 0.55, 0.10)))
	capture_overlay.visible = false
	root.add_child(capture_overlay)
	capture_label = Label.new()
	capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capture_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	capture_label.add_theme_font_size_override("font_size", 20)
	capture_overlay.add_child(capture_label)

func _new_tab(title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	tabs.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	return stack

func _section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
	return label

func _body_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.86))
	return label

func _fixed_label(text_value: String, width: float) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(width, 36.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_fixed_label(label_text.to_upper(), 240.0))
	row.add_child(control)
	return row

func _volume_row(label_text: String) -> Array:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(500.0, 34.0)
	var value := Label.new()
	value.custom_minimum_size = Vector2(70.0, 32.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var controls := HBoxContainer.new()
	controls.add_child(slider)
	controls.add_child(value)
	return [slider, value, _labeled_control(label_text, controls)]

func _add_atmosphere_slider(parent: VBoxContainer, definition: Dictionary) -> void:
	var id := StringName(definition["id"])
	var slider := HSlider.new()
	slider.min_value = float(definition["min"])
	slider.max_value = float(definition["max"])
	slider.step = float(definition["step"])
	slider.custom_minimum_size = Vector2(560.0, 30.0)
	var value := Label.new()
	value.custom_minimum_size = Vector2(82.0, 30.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var controls := HBoxContainer.new()
	controls.add_child(slider)
	controls.add_child(value)
	parent.add_child(_labeled_control(String(definition["label"]), controls))
	atmosphere_sliders[id] = slider
	atmosphere_value_labels[id] = value
	slider.value_changed.connect(_on_atmosphere_slider_changed.bind(id))

func _add_lod_slider(parent: VBoxContainer, id: StringName, label_text: String, minimum: float, maximum: float, step_value: float) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.custom_minimum_size = Vector2(520.0, 30.0)
	var value := Label.new()
	value.custom_minimum_size = Vector2(90.0, 30.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var controls := HBoxContainer.new()
	controls.add_child(slider)
	controls.add_child(value)
	parent.add_child(_labeled_control(label_text, controls))
	lod_sliders[id] = slider
	lod_value_labels[id] = value
	slider.value_changed.connect(_on_lod_slider_changed.bind(id))

func _panel_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 10.0
	return style

func _remap_button(action: StringName, device: String, fallback: String, locked: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(250.0, 36.0)
	button.text = fallback
	button.disabled = locked
	if not locked:
		button.pressed.connect(_begin_capture.bind(action, device))
	remap_buttons["%s|%s" % [String(action), device]] = button
	return button

func _sync_all() -> void:
	_sync_from_audio()
	_sync_from_camera()
	_sync_from_display()
	_sync_from_atmosphere()
	_sync_from_lod()
	_sync_bindings()
	if device_option != null:
		device_option.select(clampi(preferred_device, 0, 2))

func _sync_from_audio() -> void:
	if track_option == null:
		return
	track_option.clear()
	if combat_audio == null:
		track_option.add_item("AUDIO INDISPONIBLE")
		track_option.disabled = true
		return
	var names := combat_audio.get_track_names()
	for track_name: String in names:
		track_option.add_item(track_name)
	track_option.disabled = names.is_empty()
	if not names.is_empty():
		track_option.select(clampi(combat_audio.get_current_track_index(), 0, names.size() - 1))
	master_slider.set_value_no_signal(combat_audio.get_master_volume() * 100.0)
	music_slider.set_value_no_signal(combat_audio.get_music_volume() * 100.0)
	sfx_slider.set_value_no_signal(combat_audio.get_sfx_volume() * 100.0)
	_refresh_volume_labels()
	_rebuild_sfx_detail()

func _rebuild_sfx_detail() -> void:
	if detail_list == null:
		return
	for child: Node in detail_list.get_children():
		child.queue_free()
	sfx_detail_sliders.clear()
	if combat_audio == null:
		return
	for key: StringName in combat_audio.get_sfx_category_keys():
		var row := HBoxContainer.new()
		row.add_child(_fixed_label(String(key).replace("_", " ").to_upper(), 310.0))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.custom_minimum_size = Vector2(380.0, 32.0)
		slider.set_value_no_signal(combat_audio.get_sfx_category_volume(key) * 100.0)
		slider.value_changed.connect(_on_sfx_category_changed.bind(key))
		row.add_child(slider)
		var value := Label.new()
		value.name = "Value"
		value.text = "%d%%" % int(round(slider.value))
		value.custom_minimum_size = Vector2(70.0, 30.0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		sfx_detail_sliders[key] = slider
		detail_list.add_child(row)

func _sync_from_camera() -> void:
	if camera_mode_option == null:
		return
	camera_mode_option.clear()
	var labels: Array[String] = ["TPS GLOBAL"]
	if player != null:
		labels = player.get_camera_mode_labels()
	for mode_label: String in labels:
		camera_mode_option.add_item(mode_label)
	camera_mode_option.disabled = true
	camera_distance_slider.editable = player != null
	if player != null:
		camera_mode_option.select(clampi(player.get_camera_mode(), 0, labels.size() - 1))
		camera_distance_slider.set_value_no_signal(player.get_camera_distance())
	_refresh_camera_label()

func _sync_from_display() -> void:
	for raw_id: Variant in display_toggles.keys():
		var id := StringName(raw_id)
		(display_toggles[id] as CheckButton).set_pressed_no_signal(bool(visual_settings.get(id, true)))

func _sync_from_atmosphere() -> void:
	_discover_atmosphere_targets()
	var available := atmosphere_environment != null and atmosphere_environment.environment != null and atmosphere_sun != null
	if atmosphere_preset_option != null:
		atmosphere_preset_option.disabled = not available
		atmosphere_preset_option.select(0)
	for raw_slider: Variant in atmosphere_sliders.values():
		(raw_slider as HSlider).editable = available
	if not available:
		return
	var environment := atmosphere_environment.environment
	_set_atmosphere_slider(&"sun_energy", atmosphere_sun.light_energy)
	_set_atmosphere_slider(&"sun_height", absf(atmosphere_sun.rotation_degrees.x))
	_set_atmosphere_slider(&"ambient", environment.ambient_light_energy)
	_set_atmosphere_slider(&"exposure", environment.tonemap_exposure)
	_set_atmosphere_slider(&"fog", environment.fog_density)
	_set_atmosphere_slider(&"brazier", float(atmosphere_aux_values[&"brazier"]))
	_set_atmosphere_slider(&"flicker", float(atmosphere_aux_values[&"flicker"]))
	_set_atmosphere_slider(&"smoke", float(atmosphere_aux_values[&"smoke"]))

func _discover_atmosphere_targets() -> void:
	atmosphere_environment = null
	atmosphere_sun = null
	if get_tree() == null or get_tree().current_scene == null:
		return
	for candidate: Node in get_tree().current_scene.find_children("*", "WorldEnvironment", true, false):
		var environment_candidate := candidate as WorldEnvironment
		if environment_candidate != null and environment_candidate.environment != null:
			atmosphere_environment = environment_candidate
			break
	for candidate: Node in get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false):
		atmosphere_sun = candidate as DirectionalLight3D
		if atmosphere_sun != null:
			break
	if atmosphere_environment != null and atmosphere_environment.environment != null and atmosphere_sun != null:
		var scene_id := get_tree().current_scene.get_instance_id()
		if scene_id != atmosphere_scene_instance_id:
			atmosphere_scene_instance_id = scene_id
			var environment := atmosphere_environment.environment
			var sky_top := Color(0.02, 0.04, 0.10)
			var sky_horizon := Color(0.18, 0.26, 0.42)
			if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:
				var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
				sky_top = sky_material.sky_top_color
				sky_horizon = sky_material.sky_horizon_color
			atmosphere_snapshot = {
				"sun_color": atmosphere_sun.light_color,
				"ambient_color": environment.ambient_light_color,
				"fog_color": environment.fog_light_color,
				"sky_top": sky_top,
				"sky_horizon": sky_horizon,
				"values": [atmosphere_sun.light_energy, absf(atmosphere_sun.rotation_degrees.x), environment.ambient_light_energy, environment.tonemap_exposure, environment.fog_density, float(atmosphere_aux_values[&"brazier"]), float(atmosphere_aux_values[&"flicker"]), float(atmosphere_aux_values[&"smoke"])],
			}

func _set_atmosphere_slider(id: StringName, value: float) -> void:
	var slider := atmosphere_sliders.get(id) as HSlider
	if slider == null:
		return
	slider.set_value_no_signal(value)
	_update_atmosphere_value(id, value)

func _update_atmosphere_value(id: StringName, value: float) -> void:
	var label := atmosphere_value_labels.get(id) as Label
	if label != null:
		label.text = "%.3f" % value if id == &"fog" else "%.2f" % value

func _sync_from_lod() -> void:
	if lod_enabled_toggle != null:
		lod_enabled_toggle.set_pressed_no_signal(lod_enabled)
	if lod_profile_option != null:
		lod_profile_option.select(clampi(lod_profile, 0, LOD_PROFILES.size() - 1))
	var values := {&"near": lod_near_distance, &"far": lod_far_distance, &"cull": lod_cull_distance, &"threshold": lod_mesh_threshold}
	for raw_id: Variant in values.keys():
		var id := StringName(raw_id)
		var slider := lod_sliders.get(id) as HSlider
		if slider != null:
			slider.editable = lod_enabled
			slider.set_value_no_signal(float(values[id]))
		_update_lod_value(id, float(values[id]))

func _update_lod_value(id: StringName, value: float) -> void:
	var label := lod_value_labels.get(id) as Label
	if label == null:
		return
	label.text = "%.1f px" % value if id == &"threshold" else "%.0f m" % value

func _sync_bindings() -> void:
	for definition: Dictionary in ACTIONS:
		var action := StringName(definition["id"])
		for device: String in ["mnk", "gamepad"]:
			var button := remap_buttons.get("%s|%s" % [String(action), device]) as Button
			if button == null or button.disabled:
				continue
			var fallback_key := "pad" if device == "gamepad" else "mnk"
			button.text = _event_text(_first_event_for_device(action, device), String(definition[fallback_key]))

func _refresh_camera_label() -> void:
	if camera_distance_value != null:
		camera_distance_value.text = "%.1f m" % camera_distance_slider.value

func _refresh_volume_labels() -> void:
	if master_value != null:
		master_value.text = "%d%%" % int(round(master_slider.value))
		music_value.text = "%d%%" % int(round(music_slider.value))
		sfx_value.text = "%d%%" % int(round(sfx_slider.value))

func _ensure_gameplay_actions(force_defaults: bool = false) -> void:
	for definition: Dictionary in ACTIONS:
		var action := StringName(definition["id"])
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.20)
		if force_defaults:
			InputMap.action_erase_events(action)
		if force_defaults or _first_event_for_device(action, "mnk") == null:
			var mnk := _default_mnk_event(action)
			if mnk != null:
				InputMap.action_add_event(action, mnk)
		if force_defaults or _first_event_for_device(action, "gamepad") == null:
			var pad := _default_gamepad_event(action)
			if pad != null:
				InputMap.action_add_event(action, pad)
	_sync_contextual_counter_bindings()

func _default_mnk_event(action: StringName) -> InputEvent:
	match action:
		&"move_forward": return _key_event(KEY_W)
		&"move_back": return _key_event(KEY_S)
		&"move_left": return _key_event(KEY_A)
		&"move_right": return _key_event(KEY_D)
		&"jump": return _key_event(KEY_SPACE)
		&"dash": return _key_event(KEY_SHIFT)
		&"slide": return _key_event(KEY_CTRL)
		&"block": return _mouse_event(MOUSE_BUTTON_RIGHT)
		&"attack_primary": return _mouse_event(MOUSE_BUTTON_LEFT)
		&"spin_attack_up": return _mouse_event(MOUSE_BUTTON_WHEEL_UP)
		&"spin_attack_down": return _mouse_event(MOUSE_BUTTON_WHEEL_DOWN)
		&"toggle_settings": return _key_event(KEY_QUOTELEFT)
	return null

func _default_gamepad_event(action: StringName) -> InputEvent:
	match action:
		&"move_forward": return _joy_motion(JOY_AXIS_LEFT_Y, -1.0)
		&"move_back": return _joy_motion(JOY_AXIS_LEFT_Y, 1.0)
		&"move_left": return _joy_motion(JOY_AXIS_LEFT_X, -1.0)
		&"move_right": return _joy_motion(JOY_AXIS_LEFT_X, 1.0)
		&"jump": return _joy_button(JOY_BUTTON_A)
		&"dash": return _joy_button(JOY_BUTTON_B)
		&"slide": return _joy_button(JOY_BUTTON_X)
		&"block": return _joy_motion(JOY_AXIS_TRIGGER_LEFT, 1.0)
		&"attack_primary": return _joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0)
		&"spin_attack_up": return _joy_button(JOY_BUTTON_RIGHT_SHOULDER)
		&"spin_attack_down": return _joy_button(JOY_BUTTON_LEFT_SHOULDER)
		&"toggle_settings": return _joy_button(JOY_BUTTON_START)
		&"camera_left": return _joy_motion(JOY_AXIS_RIGHT_X, -1.0)
		&"camera_right": return _joy_motion(JOY_AXIS_RIGHT_X, 1.0)
		&"camera_up": return _joy_motion(JOY_AXIS_RIGHT_Y, -1.0)
		&"camera_down": return _joy_motion(JOY_AXIS_RIGHT_Y, 1.0)
	return null

func _key_event(physical_key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	return event

func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event

func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event

func _joy_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event

func _first_event_for_device(action: StringName, device: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		if device == "gamepad" and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return event
		if device == "mnk" and (event is InputEventKey or event is InputEventMouseButton):
			return event
	return null

func _begin_capture(action: StringName, device: String) -> void:
	awaiting_action = action
	awaiting_device = device
	capture_label.text = "APPUYEZ SUR LA NOUVELLE TOUCHE\n%s — %s\nEchap pour annuler" % [String(action).replace("_", " ").to_upper(), "MANETTE" if device == "gamepad" else "CLAVIER / SOURIS"]
	capture_overlay.visible = true

func _try_capture_binding(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_capture()
		return true
	var accepted: InputEvent
	if awaiting_device == "mnk":
		if event is InputEventKey and event.pressed and not event.echo:
			accepted = event.duplicate()
		elif event is InputEventMouseButton and event.pressed:
			accepted = event.duplicate()
	else:
		if event is InputEventJoypadButton and event.pressed:
			accepted = event.duplicate()
		elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.65:
			accepted = event.duplicate()
			(accepted as InputEventJoypadMotion).axis_value = signf((accepted as InputEventJoypadMotion).axis_value)
	if accepted == null:
		return false
	_replace_device_event(awaiting_action, awaiting_device, accepted)
	_save_binding(awaiting_action, awaiting_device, accepted)
	_sync_contextual_counter_bindings()
	_cancel_capture()
	_sync_bindings()
	return true

func _replace_device_event(action: StringName, device: String, replacement: InputEvent) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		var is_pad := existing is InputEventJoypadButton or existing is InputEventJoypadMotion
		if (device == "gamepad" and is_pad) or (device == "mnk" and not is_pad):
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, replacement)

func _sync_contextual_counter_bindings() -> void:
	if not InputMap.has_action(&"counter_close"):
		InputMap.add_action(&"counter_close", 0.20)
	InputMap.action_erase_events(&"counter_close")
	var mnk := _first_event_for_device(&"block", "mnk")
	var pad := _first_event_for_device(&"attack_primary", "gamepad")
	if mnk != null:
		InputMap.action_add_event(&"counter_close", mnk.duplicate())
	if pad != null:
		InputMap.action_add_event(&"counter_close", pad.duplicate())

func _cancel_capture() -> void:
	awaiting_action = StringName()
	awaiting_device = ""
	if capture_overlay != null:
		capture_overlay.visible = false

func _event_text(event: InputEvent, fallback: String) -> String:
	if event == null:
		return fallback
	if event is InputEventKey:
		var key := event as InputEventKey
		match key.physical_keycode:
			KEY_W: return "Z"
			KEY_A: return "Q"
			KEY_SPACE: return "Espace"
			KEY_SHIFT: return "Maj"
			KEY_CTRL: return "Ctrl"
			KEY_QUOTELEFT: return "²"
		return key.as_text_physical_keycode()
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Clic gauche"
			MOUSE_BUTTON_RIGHT: return "Clic droit"
			MOUSE_BUTTON_WHEEL_UP: return "Molette haut"
			MOUSE_BUTTON_WHEEL_DOWN: return "Molette bas"
	if event is InputEventJoypadButton:
		return _joy_button_text((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			return _joy_axis_text(motion.axis)
		return "%s %s" % [_joy_axis_text(motion.axis), "+" if motion.axis_value > 0.0 else "-"]
	return fallback

func _joy_button_text(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_A: return "Croix / A"
		JOY_BUTTON_B: return "Rond / B"
		JOY_BUTTON_X: return "Carré / X"
		JOY_BUTTON_Y: return "Triangle / Y"
		JOY_BUTTON_LEFT_SHOULDER: return "L1 / LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "R1 / RB"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_START: return "Options / Menu"
	return "Bouton %d" % int(button)

func _joy_axis_text(axis: JoyAxis) -> String:
	match axis:
		JOY_AXIS_LEFT_X: return "Stick G horizontal"
		JOY_AXIS_LEFT_Y: return "Stick G vertical"
		JOY_AXIS_RIGHT_X: return "Stick D horizontal"
		JOY_AXIS_RIGHT_Y: return "Stick D vertical"
		JOY_AXIS_TRIGGER_LEFT: return "L2 / LT"
		JOY_AXIS_TRIGGER_RIGHT: return "R2 / RT"
	return "Axe %d" % int(axis)

func _save_binding(action: StringName, device: String, event: InputEvent) -> void:
	var config := _global_config()
	config.set_value("input_%s" % device, String(action), event)
	config.save(GLOBAL_SETTINGS_PATH)

func _load_global_settings() -> void:
	var config := ConfigFile.new()
	if config.load(GLOBAL_SETTINGS_PATH) != OK:
		_apply_enemy_lod_settings(false)
		return
	preferred_device = clampi(int(config.get_value("gameplay", "device", DEVICE_AUTO)), DEVICE_AUTO, DEVICE_GAMEPAD)
	for raw_id: Variant in visual_settings.keys():
		var id := StringName(raw_id)
		visual_settings[id] = bool(config.get_value("display", String(id), visual_settings[id]))
	for definition: Dictionary in ACTIONS:
		var action := StringName(definition["id"])
		for device: String in ["mnk", "gamepad"]:
			var section := "input_%s" % device
			if not config.has_section_key(section, String(action)):
				continue
			var saved: Variant = config.get_value(section, String(action))
			if saved is InputEvent:
				_replace_device_event(action, device, saved as InputEvent)
	lod_enabled = bool(config.get_value("enemy_lod", "enabled", lod_enabled))
	lod_profile = clampi(int(config.get_value("enemy_lod", "profile", lod_profile)), 0, LOD_PROFILES.size() - 1)
	lod_near_distance = float(config.get_value("enemy_lod", "near_distance", lod_near_distance))
	lod_far_distance = float(config.get_value("enemy_lod", "far_distance", lod_far_distance))
	lod_cull_distance = float(config.get_value("enemy_lod", "cull_distance", lod_cull_distance))
	lod_mesh_threshold = float(config.get_value("enemy_lod", "mesh_threshold", lod_mesh_threshold))
	_sync_contextual_counter_bindings()
	_apply_enemy_lod_settings(false)

func _has_saved_bindings() -> bool:
	var config := ConfigFile.new()
	if config.load(GLOBAL_SETTINGS_PATH) != OK:
		return false
	return config.has_section("input_mnk") or config.has_section("input_gamepad")

func _global_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(GLOBAL_SETTINGS_PATH)
	return config

func _save_visual_settings() -> void:
	var config := _global_config()
	for raw_id: Variant in visual_settings.keys():
		var id := StringName(raw_id)
		config.set_value("display", String(id), bool(visual_settings[id]))
	config.save(GLOBAL_SETTINGS_PATH)

func _apply_visual_settings() -> void:
	if gore_hud != null:
		gore_hud.set_enabled(bool(visual_settings[&"gore"]))
		if gore_hud.root != null:
			gore_hud.root.visible = bool(visual_settings[&"combat_feedback"])
		if gore_hud.feedback_root != null:
			gore_hud.feedback_root.visible = bool(visual_settings[&"combat_feedback"])
	_set_group_visible(&"global_hud_combat", bool(visual_settings[&"combat_hud"]))
	_set_group_visible(&"global_hud_objectives", bool(visual_settings[&"objectives"]))
	_set_group_visible(&"global_hud_narration", bool(visual_settings[&"narration"]))

func _set_group_visible(group_name: StringName, value: bool) -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group(group_name):
		if node is CanvasItem:
			(node as CanvasItem).visible = value

func _on_track_selected(index: int) -> void:
	if combat_audio != null:
		combat_audio.play_track(index)

func _on_camera_mode_selected(index: int) -> void:
	if player != null:
		player.set_camera_mode(index, true)
		camera_distance_slider.set_value_no_signal(player.get_camera_distance())
	_refresh_camera_label()

func _on_camera_distance_changed(value: float) -> void:
	if player != null:
		player.set_camera_distance(value)
	_refresh_camera_label()

func _on_reset_camera_pressed() -> void:
	if player != null:
		player.reset_camera_tps()
	_sync_from_camera()

func _on_master_changed(value: float) -> void:
	if combat_audio != null:
		combat_audio.set_master_volume(value / 100.0)
	_refresh_volume_labels()

func _on_music_changed(value: float) -> void:
	if combat_audio != null:
		combat_audio.set_music_volume(value / 100.0)
	_refresh_volume_labels()

func _on_sfx_changed(value: float) -> void:
	if combat_audio != null:
		combat_audio.set_sfx_volume(value / 100.0)
	_refresh_volume_labels()

func _on_sfx_category_changed(value: float, key: StringName) -> void:
	if combat_audio != null:
		combat_audio.set_sfx_category_volume(key, value / 100.0)
	var slider := sfx_detail_sliders.get(key) as HSlider
	if slider != null and slider.get_parent() != null:
		var value_label := slider.get_parent().get_node_or_null("Value") as Label
		if value_label != null:
			value_label.text = "%d%%" % int(round(value))

func _toggle_sfx_detail() -> void:
	if detail_overlay != null:
		detail_overlay.visible = not detail_overlay.visible
		if detail_overlay.visible:
			_rebuild_sfx_detail()

func _on_atmosphere_slider_changed(value: float, id: StringName) -> void:
	_update_atmosphere_value(id, value)
	if id in [&"brazier", &"flicker", &"smoke"]:
		atmosphere_aux_values[id] = value
	_apply_atmosphere_values()

func _on_atmosphere_preset_selected(index: int) -> void:
	if index < 0 or index >= ATMOSPHERE_PRESETS.size():
		return
	_discover_atmosphere_targets()
	if atmosphere_environment == null or atmosphere_environment.environment == null or atmosphere_sun == null:
		return
	var preset: Dictionary = atmosphere_snapshot if index == 0 else ATMOSPHERE_PRESETS[index]
	if preset.is_empty():
		return
	atmosphere_sun.light_color = preset.get("sun_color", preset.get("sun", atmosphere_sun.light_color))
	var environment := atmosphere_environment.environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = preset.get("ambient_color", environment.ambient_light_color)
	environment.fog_light_color = preset.get("fog_color", environment.fog_light_color)
	if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:
		var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
		if index == 0:
			sky_material.sky_top_color = preset.get("sky_top", sky_material.sky_top_color)
			sky_material.sky_horizon_color = preset.get("sky_horizon", sky_material.sky_horizon_color)
		else:
			var ambient_color: Color = preset.get("ambient_color", environment.ambient_light_color)
			var sun_color: Color = preset.get("sun", atmosphere_sun.light_color)
			sky_material.sky_top_color = ambient_color.darkened(0.42)
			sky_material.sky_horizon_color = sun_color.lerp(Color.WHITE, 0.28)
	var values: Array = preset.get("values", [])
	if values.size() >= 8:
		_set_atmosphere_slider(&"sun_energy", float(values[0]))
		_set_atmosphere_slider(&"sun_height", float(values[1]))
		_set_atmosphere_slider(&"ambient", float(values[2]))
		_set_atmosphere_slider(&"exposure", float(values[3]))
		_set_atmosphere_slider(&"fog", float(values[4]))
		_set_atmosphere_slider(&"brazier", float(values[5]))
		_set_atmosphere_slider(&"flicker", float(values[6]))
		_set_atmosphere_slider(&"smoke", float(values[7]))
		atmosphere_aux_values[&"brazier"] = float(values[5])
		atmosphere_aux_values[&"flicker"] = float(values[6])
		atmosphere_aux_values[&"smoke"] = float(values[7])
	_apply_atmosphere_values()

func _apply_atmosphere_values() -> void:
	if atmosphere_environment == null or atmosphere_environment.environment == null or atmosphere_sun == null:
		return
	atmosphere_sun.light_energy = (atmosphere_sliders[&"sun_energy"] as HSlider).value
	var rotation := atmosphere_sun.rotation_degrees
	rotation.x = -(atmosphere_sliders[&"sun_height"] as HSlider).value
	atmosphere_sun.rotation_degrees = rotation
	var environment := atmosphere_environment.environment
	environment.ambient_light_energy = (atmosphere_sliders[&"ambient"] as HSlider).value
	environment.tonemap_exposure = (atmosphere_sliders[&"exposure"] as HSlider).value
	environment.fog_density = (atmosphere_sliders[&"fog"] as HSlider).value
	for node: Node in get_tree().get_nodes_in_group("campaign_brazier_light"):
		if node.has_method("configure_atmosphere"):
			node.call("configure_atmosphere", float(atmosphere_aux_values[&"brazier"]), float(atmosphere_aux_values[&"flicker"]))
	var smoke_density := float(atmosphere_aux_values[&"smoke"])
	for node: Node in get_tree().get_nodes_in_group("campaign_smoke"):
		if node is GPUParticles3D:
			var particles := node as GPUParticles3D
			particles.emitting = smoke_density > 0.01
			particles.amount_ratio = clampf(smoke_density / 1.5, 0.0, 1.0)

func _on_lod_enabled_toggled(enabled: bool) -> void:
	lod_enabled = enabled
	_apply_enemy_lod_settings()
	_sync_from_lod()

func _on_lod_profile_selected(index: int) -> void:
	lod_profile = clampi(index, 0, LOD_PROFILES.size() - 1)
	if lod_profile < LOD_PROFILES.size() - 1:
		var profile: Dictionary = LOD_PROFILES[lod_profile]
		lod_near_distance = float(profile["near"])
		lod_far_distance = float(profile["far"])
		lod_cull_distance = float(profile["cull"])
		lod_mesh_threshold = float(profile["threshold"])
	_sync_from_lod()
	_apply_enemy_lod_settings()

func _on_lod_slider_changed(value: float, id: StringName) -> void:
	match id:
		&"near": lod_near_distance = value
		&"far": lod_far_distance = value
		&"cull": lod_cull_distance = value
		&"threshold": lod_mesh_threshold = value
	lod_profile = LOD_PROFILES.size() - 1
	lod_far_distance = maxf(lod_far_distance, lod_near_distance + 2.0)
	lod_cull_distance = maxf(lod_cull_distance, lod_far_distance + 5.0)
	_update_lod_value(id, value)
	if lod_profile_option != null:
		lod_profile_option.select(lod_profile)
	_apply_enemy_lod_settings()

func _apply_enemy_lod_settings(save: bool = true) -> void:
	ProjectSettings.set_setting("hoplite/enemy_lod/enabled", lod_enabled)
	ProjectSettings.set_setting("hoplite/enemy_lod/near_distance", lod_near_distance)
	ProjectSettings.set_setting("hoplite/enemy_lod/far_distance", lod_far_distance)
	ProjectSettings.set_setting("hoplite/enemy_lod/cull_distance", lod_cull_distance)
	ProjectSettings.set_setting("hoplite/enemy_lod/mesh_threshold", lod_mesh_threshold)
	if get_tree() != null and get_tree().root != null:
		get_tree().root.mesh_lod_threshold = lod_mesh_threshold if lod_enabled else 1.0
		for enemy: Node in get_tree().get_nodes_in_group("enemy"):
			if enemy.has_method("_update_performance_lod"):
				enemy.call("_update_performance_lod")
	if not save:
		return
	var config := _global_config()
	config.set_value("enemy_lod", "enabled", lod_enabled)
	config.set_value("enemy_lod", "profile", lod_profile)
	config.set_value("enemy_lod", "near_distance", lod_near_distance)
	config.set_value("enemy_lod", "far_distance", lod_far_distance)
	config.set_value("enemy_lod", "cull_distance", lod_cull_distance)
	config.set_value("enemy_lod", "mesh_threshold", lod_mesh_threshold)
	config.save(GLOBAL_SETTINGS_PATH)

func _on_visual_toggled(enabled: bool, id: StringName) -> void:
	visual_settings[id] = enabled
	_save_visual_settings()
	_apply_visual_settings()

func _on_gore_enabled_changed(enabled: bool) -> void:
	visual_settings[&"gore"] = enabled
	var toggle := display_toggles.get(&"gore") as CheckButton
	if toggle != null:
		toggle.set_pressed_no_signal(enabled)

func _on_device_selected(index: int) -> void:
	preferred_device = clampi(index, DEVICE_AUTO, DEVICE_GAMEPAD)
	var config := _global_config()
	config.set_value("gameplay", "device", preferred_device)
	config.save(GLOBAL_SETTINGS_PATH)

func _reset_bindings() -> void:
	_ensure_gameplay_actions(true)
	var config := _global_config()
	for definition: Dictionary in ACTIONS:
		var action := String(definition["id"])
		config.erase_section_key("input_mnk", action)
		config.erase_section_key("input_gamepad", action)
	config.save(GLOBAL_SETTINGS_PATH)
	_sync_bindings()

func _on_close_pressed() -> void:
	set_open(false)
