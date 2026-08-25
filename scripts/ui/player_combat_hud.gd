extends CanvasLayer
class_name HoplitePlayerCombatHUD

class ActionBubble:
	extends Control

	var fill_ratio := 0.0
	var accent := Color.WHITE
	var is_ready := false
	var pulse := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func set_state(ratio: float, ready: bool) -> void:
		fill_ratio = clampf(ratio, 0.0, 1.0)
		is_ready = ready
		queue_redraw()

	func _process(delta: float) -> void:
		pulse = fmod(pulse + delta * 2.2, TAU)
		if is_ready:
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		var glow: float = 0.5 + sin(pulse) * 0.5
		draw_circle(center + Vector2(0.0, 4.0), radius + 3.0, Color(0.0, 0.0, 0.0, 0.58))
		if is_ready:
			draw_circle(center, radius + 7.0, Color(accent.r, accent.g, accent.b, 0.055 + glow * 0.045))
		draw_circle(center, radius + 2.0, Color(0.055, 0.065, 0.078, 0.98))
		draw_circle(center, radius - 2.0, Color(0.012, 0.017, 0.024, 0.97))

		# La recharge remplit la bulle dans le sens horaire.
		if fill_ratio > 0.001:
			var points := PackedVector2Array([center])
			var steps := maxi(3, int(ceil(42.0 * fill_ratio)))
			for index: int in range(steps + 1):
				var angle: float = -PI * 0.5 + TAU * fill_ratio * float(index) / float(steps)
				points.append(center + Vector2(cos(angle), sin(angle)) * (radius - 5.0))
			draw_colored_polygon(points, Color(accent.r, accent.g, accent.b, 0.78 if is_ready else 0.58))
			draw_circle(center, radius * 0.55, Color(0.018, 0.024, 0.034, 0.82))

		draw_arc(center, radius + 1.0, 0.0, TAU, 72, Color(0.72, 0.76, 0.79, 0.32), 2.0, true)
		draw_arc(center, radius - 3.0, -2.65, -0.48, 30, Color(1.0, 1.0, 1.0, 0.18), 1.5, true)
		draw_arc(center, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * fill_ratio, 56, accent.lightened(0.22), 2.6, true)
		if is_ready:
			draw_arc(center, radius + 6.0, -2.75, -0.42, 28, Color(accent.r, accent.g, accent.b, 0.35 + glow * 0.35), 2.0, true)
		draw_circle(center + Vector2(0.0, -radius - 4.0), 2.5, accent.lightened(0.35))

var player: Node
var root: Control
var dash_card: Dictionary = {}
var slide_card: Dictionary = {}
var spiral_card: Dictionary = {}
var health_bar: ProgressBar
var health_value: Label
var health_state: Label
var state_label: Label

const DASH_COLOR := Color(0.18, 0.80, 1.0, 1.0)
const SLIDE_COLOR := Color(1.0, 0.66, 0.16, 1.0)
const SPIRAL_COLOR := Color(1.0, 0.20, 0.08, 1.0)
const BRONZE := Color(0.82, 0.63, 0.34, 1.0)
const TEXT_MAIN := Color(0.92, 0.94, 0.95, 1.0)
const TEXT_MUTED := Color(0.53, 0.59, 0.65, 1.0)

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()

func configure(player_node: Node) -> void:
	player = player_node
	_sync_hud()

func _process(_delta: float) -> void:
	_sync_hud()

func _build_hud() -> void:
	root = Control.new()
	root.name = "GlobalCombatResourceHUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_to_group("global_hud_combat")
	add_child(root)

	var frame := PanelContainer.new()
	frame.name = "HopliteCombatCluster"
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 18.0
	frame.offset_right = 380.0
	frame.offset_top = -164.0
	frame.offset_bottom = -14.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0.009, 0.013, 0.020, 0.90), Color(BRONZE.r, BRONZE.g, BRONZE.b, 0.66), 16, 2))
	root.add_child(frame)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 9)
	outer.add_theme_constant_override("margin_right", 9)
	outer.add_theme_constant_override("margin_top", 6)
	outer.add_theme_constant_override("margin_bottom", 5)
	frame.add_child(outer)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	outer.add_child(content)
	_build_vitality_header(content)

	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1.0
	divider.color = Color(BRONZE.r, BRONZE.g, BRONZE.b, 0.24)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 4)
	content.add_child(action_row)

	dash_card = _build_action_bubble("DASH", "D", "MAJ", DASH_COLOR)
	slide_card = _build_action_bubble("GLISSADE", "S", "CTRL", SLIDE_COLOR)
	spiral_card = _build_action_bubble("SPIRALE", "Ω", "MOLETTE", SPIRAL_COLOR)
	action_row.add_child(dash_card["card"])
	action_row.add_child(slide_card["card"])
	action_row.add_child(spiral_card["card"])

	state_label = Label.new()
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 8)
	state_label.add_theme_color_override("font_color", TEXT_MUTED)
	content.add_child(state_label)

func _build_vitality_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	parent.add_child(header)

	var crest := PanelContainer.new()
	crest.custom_minimum_size = Vector2(34.0, 34.0)
	crest.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.075, 0.034, 0.92), Color(BRONZE.r, BRONZE.g, BRONZE.b, 0.82), 9, 1))
	header.add_child(crest)

	var crest_label := Label.new()
	crest_label.text = "Λ"
	crest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest_label.add_theme_font_size_override("font_size", 20)
	crest_label.add_theme_color_override("font_color", BRONZE.lightened(0.25))
	crest_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	crest_label.add_theme_constant_override("shadow_offset_x", 2)
	crest_label.add_theme_constant_override("shadow_offset_y", 2)
	crest.add_child(crest_label)

	var vital_column := VBoxContainer.new()
	vital_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vital_column.add_theme_constant_override("separation", 2)
	header.add_child(vital_column)

	var title_row := HBoxContainer.new()
	vital_column.add_child(title_row)
	var title := Label.new()
	title.text = "HOPLITE"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", BRONZE.lightened(0.22))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	title_row.add_child(title)

	health_state = Label.new()
	health_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_state.add_theme_font_size_override("font_size", 8)
	health_state.add_theme_color_override("font_color", TEXT_MUTED)
	title_row.add_child(health_state)

	var bar_shell := PanelContainer.new()
	bar_shell.custom_minimum_size.y = 17.0
	bar_shell.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.025, 0.028, 1.0), Color(0.48, 0.30, 0.24, 0.8), 6, 1))
	vital_column.add_child(bar_shell)
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 3)
	bar_margin.add_theme_constant_override("margin_right", 3)
	bar_margin.add_theme_constant_override("margin_top", 2)
	bar_margin.add_theme_constant_override("margin_bottom", 2)
	bar_shell.add_child(bar_margin)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 11.0
	health_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.add_theme_stylebox_override("background", _panel_style(Color(0.065, 0.035, 0.04, 1.0), Color.TRANSPARENT, 3, 0))
	health_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.84, 0.055, 0.045, 1.0), Color(1.0, 0.39, 0.22, 0.90), 3, 1))
	bar_margin.add_child(health_bar)

	health_value = Label.new()
	health_value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_value.add_theme_font_size_override("font_size", 9)
	health_value.add_theme_color_override("font_color", TEXT_MAIN)
	health_value.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	health_value.add_theme_constant_override("shadow_offset_x", 1)
	health_value.add_theme_constant_override("shadow_offset_y", 1)
	bar_shell.add_child(health_value)

	var health_caption := Label.new()
	health_caption.text = "VITALITÉ"
	health_caption.add_theme_font_size_override("font_size", 7)
	health_caption.add_theme_color_override("font_color", TEXT_MUTED)
	vital_column.add_child(health_caption)

func _build_action_bubble(action_text: String, glyph: String, input_text: String, accent: Color) -> Dictionary:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(108.0, 72.0)
	card.add_theme_constant_override("separation", -3)
	var meter := ActionBubble.new()
	meter.custom_minimum_size = Vector2(56.0, 56.0)
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.accent = accent
	card.add_child(meter)

	var glyph_label := Label.new()
	glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph_label.text = glyph
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_label.add_theme_font_size_override("font_size", 17)
	glyph_label.add_theme_color_override("font_color", accent.lightened(0.30))
	glyph_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	glyph_label.add_theme_constant_override("outline_size", 4)
	glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(glyph_label)

	var charge := Label.new()
	charge.position = Vector2(32.0, 36.0)
	charge.size = Vector2(22.0, 15.0)
	charge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	charge.add_theme_font_size_override("font_size", 7)
	charge.add_theme_color_override("font_color", TEXT_MAIN)
	charge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	charge.add_theme_constant_override("outline_size", 3)
	charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(charge)

	var action := Label.new()
	action.text = action_text
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 8)
	action.add_theme_color_override("font_color", accent.lightened(0.20))
	card.add_child(action)
	var input := Label.new()
	input.text = input_text
	input.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 7)
	input.add_theme_color_override("font_color", TEXT_MUTED)
	card.add_child(input)

	return {"card": card, "meter": meter, "charge": charge, "action": action, "input": input, "accent": accent}

func _sync_hud() -> void:
	if root == null:
		return
	if player == null or not is_instance_valid(player):
		root.visible = false
		return

	var current_health: float = maxf(0.0, float(player.get("health")))
	var maximum_health: float = maxf(1.0, float(player.get("max_health")))
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	health_value.text = "%d  /  %d" % [int(ceil(current_health)), int(ceil(maximum_health))]

	var recovery_active: bool = bool(player.get("perfect_recovery_active"))
	var shield_active: bool = bool(player.get("shield_blocking"))
	if recovery_active:
		health_state.text = "SURCHARGE PARFAITE"
		health_state.add_theme_color_override("font_color", Color(0.42, 1.0, 0.70))
	elif shield_active:
		health_state.text = "BOUCLIER LEVÉ"
		health_state.add_theme_color_override("font_color", Color(0.50, 0.82, 1.0))
	else:
		health_state.text = "EN COMBAT"
		health_state.add_theme_color_override("font_color", TEXT_MUTED)

	var dash_charges: int = int(player.get("dash_charges"))
	var dash_max: int = maxi(1, int(player.get("dash_max_charges")))
	var dash_timer: float = float(player.get("dash_recharge_timer"))
	var dash_duration: float = maxf(0.001, float(player.get("dash_recharge_duration")))
	var dash_fill: float = 1.0 if dash_charges >= dash_max else 1.0 - dash_timer / dash_duration
	_set_bubble(dash_card, dash_fill, dash_charges > 0, "%d/%d" % [dash_charges, dash_max])

	var slide_charges: int = int(player.get("slide_charges"))
	var slide_max: int = maxi(1, int(player.get("slide_max_charges")))
	var slide_timer: float = float(player.get("slide_recharge_timer"))
	var slide_duration: float = maxf(0.001, float(player.get("slide_recharge_duration")))
	var slide_fill: float = 1.0 if slide_charges >= slide_max else 1.0 - slide_timer / slide_duration
	_set_bubble(slide_card, slide_fill, slide_charges > 0, "%d/%d" % [slide_charges, slide_max])

	var stamina: float = float(player.get("spiral_stamina"))
	var stamina_max: float = maxf(1.0, float(player.get("max_spiral_stamina")))
	var spiral_cost: float = maxf(1.0, float(player.get("spiral_stamina_cost")))
	var spiral_slots: int = maxi(1, int(round(stamina_max / spiral_cost)))
	var stored_spirals: int = mini(spiral_slots, int(floor(stamina / spiral_cost)))
	var spiral_fill: float = 1.0 if stored_spirals >= spiral_slots else fmod(stamina, spiral_cost) / spiral_cost
	_set_bubble(spiral_card, spiral_fill, stored_spirals > 0, "%d/%d" % [stored_spirals, spiral_slots])

	if recovery_active:
		state_label.text = "✦  SOIN ACCÉLÉRÉ   •   DÉGÂTS RENFORCÉS  ✦"
		state_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.70))
	else:
		state_label.text = "IMPACT +1   •   PERFECT +2 STAMINA"
		state_label.add_theme_color_override("font_color", TEXT_MUTED)

func _set_bubble(card: Dictionary, ratio: float, ready: bool, charge_text: String) -> void:
	if card.is_empty():
		return
	var meter := card.get("meter") as ActionBubble
	var charge := card.get("charge") as Label
	var action := card.get("action") as Label
	var accent: Color = card.get("accent", Color.WHITE)
	if meter != null:
		meter.set_state(ratio, ready)
	if charge != null:
		charge.text = charge_text
		charge.add_theme_color_override("font_color", TEXT_MAIN if ready else TEXT_MUTED)
	if action != null:
		action.add_theme_color_override("font_color", accent.lightened(0.20) if ready else TEXT_MUTED)

func _panel_style(background: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
