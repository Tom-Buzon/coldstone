extends CanvasLayer
class_name HopliteCampaignLoadingScreen

var veil: ColorRect
var act_label: Label
var title_label: Label
var tip_label: Label
var progress_fill: ColorRect
var progress_label: Label
var bronze_lines: Array[ColorRect] = []

func _ready() -> void:
	layer = 90
	_build_ui()
	visible = false

func transition_in(act_number: int, title: String, tip: String) -> void:
	visible = true
	act_label.text = "CHRONIQUE  %s" % _roman(act_number)
	title_label.text = title
	tip_label.text = tip
	set_progress(0.0, "ABANDON DE LA ZONE PRECEDENTE")
	veil.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 1.0, 0.32)
	await tween.finished
	set_progress(0.18, "LES PORTES SE REFERMENT")
	await get_tree().process_frame

func transition_out() -> void:
	set_progress(1.0, "PRET AU COMBAT")
	await get_tree().create_timer(0.22).timeout
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 0.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false

func set_progress(value: float, status: String) -> void:
	var ratio := clampf(value, 0.0, 1.0)
	progress_fill.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	progress_fill.position = Vector2(0.0, 0.0)
	progress_fill.size = Vector2(520.0 * ratio, 5.0)
	progress_label.text = "%s   %d%%" % [status, roundi(ratio * 100.0)]

func _build_ui() -> void:
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.018, 0.012, 0.014, 1.0)
	add_child(veil)

	var ember := ColorRect.new()
	ember.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ember.color = Color(0.24, 0.025, 0.012, 0.24)
	veil.add_child(ember)

	for y_ratio: float in [0.16, 0.84]:
		var line := ColorRect.new()
		line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		line.anchor_top = y_ratio
		line.anchor_bottom = y_ratio
		line.offset_top = -1.0
		line.offset_bottom = 1.0
		line.color = Color(0.74, 0.46, 0.17, 0.82)
		veil.add_child(line)
		bronze_lines.append(line)

	act_label = _label(veil, 23, Color(0.78, 0.52, 0.24), HORIZONTAL_ALIGNMENT_CENTER)
	act_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	act_label.position = Vector2(-300.0, 150.0)
	act_label.size = Vector2(600.0, 34.0)
	act_label.add_theme_constant_override("letter_spacing", 7)

	title_label = _label(veil, 48, Color(0.95, 0.89, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_label.position = Vector2(-480.0, 202.0)
	title_label.size = Vector2(960.0, 70.0)
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.add_theme_color_override("font_outline_color", Color(0.20, 0.015, 0.01, 0.9))

	var maxim := _label(veil, 19, Color(0.68, 0.58, 0.48), HORIZONTAL_ALIGNMENT_CENTER)
	maxim.text = "UNE CITE. UN HOPLITE. AUCUN REPLI."
	maxim.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	maxim.position = Vector2(-380.0, 282.0)
	maxim.size = Vector2(760.0, 32.0)

	var progress_back := ColorRect.new()
	progress_back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress_back.position = Vector2(-260.0, -132.0)
	progress_back.size = Vector2(520.0, 5.0)
	progress_back.color = Color(0.18, 0.15, 0.14)
	veil.add_child(progress_back)
	progress_fill = ColorRect.new()
	progress_fill.color = Color(0.92, 0.31, 0.055)
	progress_back.add_child(progress_fill)

	progress_label = _label(veil, 15, Color(0.82, 0.70, 0.58), HORIZONTAL_ALIGNMENT_CENTER)
	progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress_label.position = Vector2(-340.0, -112.0)
	progress_label.size = Vector2(680.0, 28.0)

	tip_label = _label(veil, 17, Color(0.61, 0.57, 0.54), HORIZONTAL_ALIGNMENT_CENTER)
	tip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tip_label.position = Vector2(-440.0, -72.0)
	tip_label.size = Vector2(880.0, 34.0)

func _label(parent: Control, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	parent.add_child(label)
	return label

func _roman(value: int) -> String:
	return ["I", "II", "III"][clampi(value - 1, 0, 2)]
