extends CanvasLayer
class_name HopliteAtmosphereControlPanel

signal panel_toggled(open: bool)

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var panel_open := false
var root_control: Control
var value_labels: Dictionary = {}
var sliders: Dictionary = {}

const SLIDER_DEFINITIONS := [
	{"id": &"sun_energy", "label": "Lumiere du soleil", "min": 0.0, "max": 3.0, "step": 0.01},
	{"id": &"sun_height", "label": "Hauteur du soleil", "min": 5.0, "max": 85.0, "step": 1.0},
	{"id": &"ambient", "label": "Lumiere ambiante", "min": 0.0, "max": 1.8, "step": 0.01},
	{"id": &"exposure", "label": "Exposition", "min": 0.45, "max": 2.2, "step": 0.01},
	{"id": &"brazier", "label": "Puissance des braseros", "min": 0.0, "max": 2.5, "step": 0.01},
	{"id": &"flicker", "label": "Vie des flammes", "min": 0.0, "max": 0.55, "step": 0.01},
	{"id": &"smoke", "label": "Quantite de fumee", "min": 0.0, "max": 1.5, "step": 0.01},
	{"id": &"fog", "label": "Brume atmospherique", "min": 0.0, "max": 0.045, "step": 0.001}
]

func _ready() -> void:
	layer = 86
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_open(false)

func configure(environment_node: WorldEnvironment, sun_node: DirectionalLight3D) -> void:
	world_environment = environment_node
	sun = sun_node
	sync_from_environment()

func is_open() -> bool:
	return panel_open

func set_open(value: bool) -> void:
	panel_open = value
	if root_control != null:
		root_control.visible = value
	if is_inside_tree():
		get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	panel_toggled.emit(value)

func toggle() -> void:
	set_open(not panel_open)

func refresh_runtime_targets() -> void:
	_apply_brazier_settings()
	_apply_smoke()

func sync_from_environment() -> void:
	if sliders.is_empty() or sun == null or world_environment == null or world_environment.environment == null:
		return
	_set_slider(&"sun_energy", sun.light_energy)
	_set_slider(&"sun_height", absf(sun.rotation_degrees.x))
	_set_slider(&"ambient", world_environment.environment.ambient_light_energy)
	_set_slider(&"exposure", world_environment.environment.tonemap_exposure)
	_set_slider(&"fog", world_environment.environment.fog_density)
	if not sliders.has(&"brazier") or is_zero_approx((sliders[&"brazier"] as HSlider).value):
		_set_slider(&"brazier", 1.0)
		_set_slider(&"flicker", 0.14)
		_set_slider(&"smoke", 0.75)
	_apply_all()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_O or (panel_open and key.keycode == KEY_ESCAPE):
		toggle()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.005, 0.008, 0.012, 0.58)
	root_control.add_child(veil)
	var panel := ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-500.0, -340.0)
	panel.size = Vector2(470.0, 680.0)
	panel.color = Color(0.025, 0.032, 0.045, 0.97)
	root_control.add_child(panel)
	var accent := ColorRect.new()
	accent.position = Vector2.ZERO
	accent.size = Vector2(5.0, 680.0)
	accent.color = Color(0.92, 0.42, 0.10)
	panel.add_child(accent)
	var content := VBoxContainer.new()
	content.position = Vector2(30.0, 24.0)
	content.size = Vector2(410.0, 630.0)
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	var title := _label("ATELIER D'ATMOSPHERE", 25, Color(1.0, 0.72, 0.34))
	content.add_child(title)
	var help := _label("O : fermer  •  le jeu est en pause pendant le reglage", 13, Color(0.68, 0.71, 0.76))
	content.add_child(help)
	var preset_label := _label("PRESET DE COULEURS", 14, Color(0.86, 0.84, 0.78))
	content.add_child(preset_label)
	var presets := OptionButton.new()
	presets.add_item("Acte actuel", 0)
	presets.add_item("Champ de bataille — poussiere doree", 1)
	presets.add_item("Forteresse — torches et contraste", 2)
	presets.add_item("Donjon du boss — braises menacantes", 3)
	presets.add_item("Jour mediterraneen", 4)
	presets.add_item("Nuit bleue", 5)
	presets.item_selected.connect(_on_preset_selected)
	content.add_child(presets)
	for definition: Dictionary in SLIDER_DEFINITIONS:
		_add_slider(content, definition)
	var close_button := Button.new()
	close_button.text = "APPLIQUER ET REPRENDRE"
	close_button.custom_minimum_size.y = 40.0
	close_button.pressed.connect(set_open.bind(false))
	content.add_child(close_button)

func _add_slider(parent: VBoxContainer, definition: Dictionary) -> void:
	var id := StringName(definition["id"])
	var header := HBoxContainer.new()
	parent.add_child(header)
	var name_label := _label(String(definition["label"]), 14, Color(0.90, 0.89, 0.85))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := _label("0", 13, Color(1.0, 0.58, 0.22))
	value_label.custom_minimum_size.x = 62.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = float(definition["min"])
	slider.max_value = float(definition["max"])
	slider.step = float(definition["step"])
	slider.custom_minimum_size.y = 18.0
	slider.value_changed.connect(_on_slider_changed.bind(id))
	parent.add_child(slider)
	sliders[id] = slider
	value_labels[id] = value_label

func _on_slider_changed(value: float, id: StringName) -> void:
	_update_value_label(id, value)
	_apply_all()

func _set_slider(id: StringName, value: float) -> void:
	if not sliders.has(id):
		return
	(sliders[id] as HSlider).set_value_no_signal(value)
	_update_value_label(id, value)

func _value(id: StringName, fallback: float) -> float:
	return float((sliders[id] as HSlider).value) if sliders.has(id) else fallback

func _update_value_label(id: StringName, value: float) -> void:
	if value_labels.has(id):
		(value_labels[id] as Label).text = "%.3f" % value if id == &"fog" else "%.2f" % value

func _apply_all() -> void:
	if sun != null:
		sun.light_energy = _value(&"sun_energy", sun.light_energy)
		var rotation := sun.rotation_degrees
		rotation.x = -_value(&"sun_height", absf(rotation.x))
		sun.rotation_degrees = rotation
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ambient_light_energy = _value(&"ambient", world_environment.environment.ambient_light_energy)
		world_environment.environment.tonemap_exposure = _value(&"exposure", world_environment.environment.tonemap_exposure)
		world_environment.environment.fog_density = _value(&"fog", world_environment.environment.fog_density)
	_apply_brazier_settings()
	_apply_smoke()

func _apply_brazier_settings() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("campaign_brazier_light"):
		if node.has_method("configure_atmosphere"):
			node.call("configure_atmosphere", _value(&"brazier", 1.0), _value(&"flicker", 0.14))

func _apply_smoke() -> void:
	if get_tree() == null:
		return
	var density := _value(&"smoke", 0.75)
	for node: Node in get_tree().get_nodes_in_group("campaign_smoke"):
		if node is GPUParticles3D:
			var particles := node as GPUParticles3D
			particles.emitting = density > 0.01
			particles.amount_ratio = clampf(density / 1.5, 0.0, 1.0)

func _on_preset_selected(index: int) -> void:
	if index == 0:
		sync_from_environment()
		return
	match index:
		1:
			# Champ de bataille: #FFB46A sur un bleu-gris #52647A.
			_apply_color_preset(Color("ffb46a"), Color("52647a"), Color("8a6340"), 1.62, 24.0, 0.48, 1.12, 0.009, 0.72, 0.17, 0.90)
		2:
			# Forteresse: #D79557 sur un bleu desature #39465A.
			_apply_color_preset(Color("d79557"), Color("39465a"), Color("69513d"), 1.30, 31.0, 0.34, 1.16, 0.012, 1.18, 0.22, 0.82)
		3:
			# Donjon du boss: #C94B32 sur un bleu-noir #202737.
			_apply_color_preset(Color("c94b32"), Color("202737"), Color("3e1e1b"), 0.58, 16.0, 0.22, 1.24, 0.020, 1.50, 0.31, 1.20)
		4:
			_apply_color_preset(Color(1.0, 0.91, 0.76), Color(0.68, 0.76, 0.88), Color(0.74, 0.66, 0.52), 1.58, 62.0, 0.74, 1.08, 0.004, 0.82, 0.10, 0.42)
		5:
			_apply_color_preset(Color(0.46, 0.58, 1.0), Color(0.025, 0.055, 0.14), Color(0.08, 0.11, 0.22), 0.58, 38.0, 0.28, 1.30, 0.017, 1.25, 0.20, 0.92)

func _apply_color_preset(sun_color: Color, ambient_color: Color, fog_color: Color, sun_energy: float, sun_height: float, ambient: float, exposure: float, fog: float, brazier: float, flicker: float, smoke: float) -> void:
	if sun != null:
		sun.light_color = sun_color
	if world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = ambient_color
		environment.fog_light_color = fog_color
		if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:
			var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
			sky_material.sky_top_color = ambient_color.darkened(0.42)
			sky_material.sky_horizon_color = sun_color.lerp(Color.WHITE, 0.28)
	_set_slider(&"sun_energy", sun_energy)
	_set_slider(&"sun_height", sun_height)
	_set_slider(&"ambient", ambient)
	_set_slider(&"exposure", exposure)
	_set_slider(&"fog", fog)
	_set_slider(&"brazier", brazier)
	_set_slider(&"flicker", flicker)
	_set_slider(&"smoke", smoke)
	_apply_all()

func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
