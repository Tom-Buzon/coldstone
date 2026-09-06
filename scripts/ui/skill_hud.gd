extends CanvasLayer

const Profile = preload("res://scripts/abilities/skill_profile.gd")
const Icons = preload("res://scripts/ui/ultimate_icons.gd")
var icon: TextureRect
var runtime: Node
var label: Label
var detail: Label
var charge: ProgressBar
var reticle: Label

func configure(value: Node) -> void:
	runtime = value
	layer = 12
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_to_group(&"global_hud_combat")
	add_child(root)
	reticle = Label.new()
	reticle.text = "+"
	reticle.add_theme_font_size_override("font_size", 24)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-8, -17)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reticle)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -420
	panel.offset_right = -18
	panel.offset_top = -158
	panel.offset_bottom = -18
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.05, 0.94)
	style.border_color = Color(0.70, 0.43, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	icon = TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.custom_minimum_size = Vector2(76, 76)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	label = Label.new()
	label.add_theme_color_override("font_color", Color(1, 0.75, 0.35))
	stack.add_child(label)
	charge = ProgressBar.new()
	charge.custom_minimum_size.y = 16
	charge.show_percentage = false
	stack.add_child(charge)
	detail = Label.new()
	detail.add_theme_font_size_override("font_size", 13)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(detail)
	runtime.state_changed.connect(refresh)
	refresh()

func refresh() -> void:
	reticle.visible = runtime.ranged_active or (runtime.ultimate == &"thunder" or runtime.profile.selected_ultimate == &"thunder")
	var shown: StringName = runtime.ultimate if runtime.ultimate != &"" else runtime.profile.selected_ultimate
	icon.texture = Icons.texture_for(shown)
	icon.modulate = Color.WHITE if runtime.active(shown) else Color(0.4, 0.4, 0.4)
	var index: int = Profile.ULTIMATES.find(shown)
	var name: String = ["Aura meurtrière", "Fire Wall", "Coup de tonnerre", "Wrath of Ares"][maxi(index, 0)]
	label.text = name + (" · verrouillé" if not runtime.active(shown) else "")
	charge.value = runtime.ultimate_charge
	var mode: String = "JAVELOT" if runtime.ranged_active else "ÉPÉE"
	var state: String = _binding(&"skill_ultimate") + " · PRÊT" if runtime.ultimate_charge >= 100.0 else "%.0f / 100" % runtime.ultimate_charge
	if runtime.cast_remaining > 0.0: state = "CHARGE · %.1f s" % runtime.cast_remaining
	elif runtime.remaining > 0.0: state = "ACTIF · %.1f s" % runtime.remaining
	detail.text = "%s  |  %s\n%s · arme / tenir : ramasser   %s · tenir : roue\n%s · lame   %s · impact" % [mode, state, _binding(&"skill_weapon_swap"), _binding(&"skill_ultimate"), _binding(&"skill_edge"), _binding(&"skill_plunge")]

	if runtime.status_time > 0.0: detail.text = runtime.status_message
	if runtime.ultimate == &"thunder":
		charge.value = runtime.thunder_charge * 100.0
		detail.text = "JAVELOT ÉLECTRIQUE · %.0f %%\nMaintenir attaque : charger\nRelâcher : lancer · E : annuler" % (runtime.thunder_charge * 100.0)

func _binding(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			if event.physical_keycode == KEY_Q: return "A"
			return event.as_text_physical_keycode()
		if event is InputEventMouseButton: return event.as_text()
	return "—"
