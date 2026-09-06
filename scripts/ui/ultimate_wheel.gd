extends Control

const Icons = preload("res://scripts/ui/ultimate_icons.gd")
const IDS: Array[StringName] = [&"aura", &"flame", &"thunder", &"ares"]
const NAMES := ["AURA MEURTRIÈRE", "FIRE WALL", "COUP DE TONNERRE", "WRATH OF ARES"]
const DETAILS := ["Vitesse · précision · rafales", "Charge · feu · terreur", "Javelot · puissance concentrée", "Force brute · destruction"]
const COLORS := [Color(1, 0.78, 0.18), Color(1, 0.32, 0.07), Color(0.3, 0.85, 1), Color(1, 0.12, 0.20)]
var runtime: Node
var selected := 0
var pointer := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false

func open() -> void:
	selected = maxi(IDS.find(runtime.profile.selected_ultimate), 0)
	pointer = Vector2.ZERO
	visible = true
	queue_redraw()

func choose(direction: Vector2) -> void:
	if direction.length() < 0.25: return
	selected = posmod(int(round((direction.angle() + PI * 0.5) / (PI * 0.5))), 4)
	queue_redraw()

func _draw() -> void:
	if not visible: return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.28
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.012, 0.025, 0.76))
	var font := ThemeDB.fallback_font
	for i: int in 4:
		var start := -PI * 0.75 + i * PI * 0.5 + 0.04
		var end := start + PI * 0.5 - 0.08
		var points := PackedVector2Array()
		for step: int in 33: points.append(center + Vector2.from_angle(lerpf(start, end, step / 32.0)) * radius)
		for step: int in range(32, -1, -1): points.append(center + Vector2.from_angle(lerpf(start, end, step / 32.0)) * radius * 0.52)
		var enabled: bool = runtime.active(IDS[i])
		var color: Color = COLORS[i] if enabled else Color(0.38, 0.40, 0.44)
		draw_colored_polygon(points, Color(color, 0.38 if selected == i else 0.10))
		draw_arc(center, radius, start, end, 36, color if selected == i else Color(color, 0.3), 4 if selected == i else 1, true)
		var icon_size := radius * 0.42
		var icon_center := center + Vector2.from_angle(-PI * 0.5 + i * PI * 0.5) * radius * 0.77
		draw_texture_rect(Icons.texture_for(IDS[i]), Rect2(icon_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false, Color.WHITE if enabled else Color(0.32, 0.32, 0.32))
		var label_point := center + Vector2.from_angle(-PI * 0.5 + i * PI * 0.5) * (radius + 32)
		if i == 1: label_point.x += 100
		elif i == 3: label_point.x -= 100
		var label: String = NAMES[i] + ("" if enabled else " · VERROUILLÉ")
		draw_string(font, label_point - Vector2(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	var gauge := "%.0f %%" % runtime.ultimate_charge
	draw_string(font, center - Vector2(font.get_string_size(gauge, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x * 0.5, -10), gauge, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, COLORS[selected])
	var detail: String = DETAILS[selected]
	draw_string(font, Vector2(center.x - font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x * 0.5, center.y + radius + 76), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var hint := "Souris / stick droit : choisir   ·   Relâcher : sélectionner   ·   Échap : annuler"
	draw_string(font, Vector2(center.x - font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x * 0.5, center.y + radius + 107), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.8, 0.85))
