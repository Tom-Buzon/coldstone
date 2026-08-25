extends CanvasLayer
class_name HopliteGoreHUD

signal enabled_changed(enabled: bool)

const SETTINGS_PATH: String = "user://hoplite_gore_settings_v1.cfg"

var enabled: bool = true
var root: Control
var feedback_root: Control
var combo_label: Label
var grade_label: Label
var event_label: Label
var hit_marker: Label
var hit_value_label: Label
var callout_label: Label
var hint_label: Label
var cinematic_tint: ColorRect
var cinematic_top_bar: ColorRect
var cinematic_bottom_bar: ColorRect
var cinematic_caption: Label
var perfect_tint: ColorRect
var perfect_frame: Panel
var perfect_frame_style: StyleBoxFlat
var perfect_label: Label
var perfect_window_label: Label
var perfect_hint_label: Label
var perfect_bar_background: ColorRect
var perfect_bar_fill: ColorRect

var combo_count: int = 0
var combo_timer: float = 0.0
var combo_window: float = 2.35
var hit_marker_timer: float = 0.0
var hit_value_timer: float = 0.0
var callout_timer: float = 0.0
var contact_batch_count: int = 0
var last_contact_ms: int = -100000
var cinematic_elapsed: float = 0.0
var cinematic_duration: float = 0.0
var perfect_elapsed: float = 0.0
var perfect_duration: float = 0.0
var perfect_accent_color: Color = Color(1.0, 0.82, 0.32)
var previous_ticks_usec: int = 0
var events: Array[String] = []

func _ready() -> void:
    layer = 30
    process_mode = Node.PROCESS_MODE_ALWAYS
    previous_ticks_usec = Time.get_ticks_usec()
    _build_ui()
    _load_settings()
    set_enabled(enabled, false)

func _process(_delta: float) -> void:
    var now_usec: int = Time.get_ticks_usec()
    var delta: float = clampf(float(now_usec - previous_ticks_usec) / 1000000.0, 0.0, 0.05)
    previous_ticks_usec = now_usec
    if combo_timer > 0.0:
        combo_timer = maxf(0.0, combo_timer - delta)
        if combo_timer <= 0.0:
            combo_count = 0
            _refresh_combo()

    hit_marker_timer = maxf(0.0, hit_marker_timer - delta)
    hit_value_timer = maxf(0.0, hit_value_timer - delta)
    callout_timer = maxf(0.0, callout_timer - delta)

    if hit_marker != null:
        hit_marker.modulate.a = clampf(hit_marker_timer / 0.16, 0.0, 1.0)
        var marker_progress: float = 1.0 - clampf(hit_marker_timer / 0.20, 0.0, 1.0)
        var marker_scale: float = lerpf(1.34, 1.0, minf(marker_progress / 0.34, 1.0))
        hit_marker.scale = Vector2.ONE * marker_scale
    if hit_value_label != null:
        hit_value_label.modulate.a = clampf(hit_value_timer / 0.52, 0.0, 1.0)
    if callout_label != null:
        callout_label.modulate.a = clampf(callout_timer / 0.82, 0.0, 1.0)
    _update_cinematic_overlay(delta)
    _update_perfect_response_overlay(delta)

func set_enabled(value: bool, save_setting: bool = true) -> void:
    var changed: bool = enabled != value
    enabled = value
    if root != null:
        root.visible = enabled
    if save_setting:
        _save_settings()
    if changed:
        if enabled:
            _big_callout("GORE MODE")
            _push_event("GORE MODE  ACTIVE")
        enabled_changed.emit(enabled)

func is_enabled() -> bool:
    return enabled

func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load(SETTINGS_PATH) == OK:
        enabled = bool(config.get_value("interface", "gore_hud", enabled))

func _save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("interface", "gore_hud", enabled)
    var error: Error = config.save(SETTINGS_PATH)
    if error != OK:
        push_warning("[GORE HUD] Could not save settings: %s" % error_string(error))

func register_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float) -> int:
    combo_count += 1
    combo_timer = combo_window

    var enemy_name: String = _enemy_display_name(enemy)
    _push_event("HIT  %s  +%.0f" % [enemy_name, damage])
    if sever_damage >= 45.0:
        _push_event("TRAUMA  %s" % _pretty_zone(zone))
    _refresh_combo()
    return combo_count

func register_contact(zone: StringName, damage: float, defended: bool = false) -> int:
    var now_ms: int = Time.get_ticks_msec()
    if now_ms - last_contact_ms <= 145:
        contact_batch_count += 1
    else:
        contact_batch_count = 1
    last_contact_ms = now_ms
    hit_marker_timer = 0.20
    hit_value_timer = 0.52

    if hit_marker != null:
        hit_marker.text = "X"
        hit_marker.modulate = Color(1.0, 0.78, 0.28, 1.0) if defended else Color(1.0, 0.13, 0.055, 1.0)
        hit_marker.pivot_offset = hit_marker.size * 0.5
    if hit_value_label != null:
        if contact_batch_count > 1:
            hit_value_label.text = "%d TARGETS" % contact_batch_count
        elif defended:
            hit_value_label.text = "BLOCKED HIT"
        elif zone == &"head" or zone == &"neck":
            hit_value_label.text = "HEAD HIT  +%.0f" % damage
        else:
            hit_value_label.text = "+%.0f" % damage
        hit_value_label.modulate = Color(1.0, 0.82, 0.44, 1.0)
    return contact_batch_count

func register_cinematic(kind: StringName, intensity: float = 1.0) -> void:
    if not enabled:
        return
    cinematic_elapsed = 0.0
    cinematic_duration = lerpf(0.68, 0.82, clampf(intensity, 0.0, 1.0))
    var caption: String = "EXECUTION"
    if kind == &"decapitation":
        caption = "DECAPITATION"
    elif kind == &"dismemberment":
        caption = "DISMEMBERMENT"
    if cinematic_caption != null:
        cinematic_caption.text = caption
    _big_callout(caption)

func register_sever(enemy: Node, zone: StringName) -> void:
    if zone == &"head":
        _big_callout("DECAPITATION")
        _push_event("DECAPITATION  %s" % _enemy_display_name(enemy))
    else:
        _big_callout("DISMEMBERMENT")
        _push_event("SEVERED  %s  %s" % [_enemy_display_name(enemy), _pretty_zone(zone)])

func register_kill(enemy: Node) -> void:
    var title: String = "KILL"
    if enemy != null:
        var archetype_value: Variant = enemy.get("archetype_id")
        var elite_value: Variant = enemy.get("is_miniboss")
        var archetype: StringName = StringName(archetype_value) if archetype_value != null else StringName()
        var elite: bool = bool(elite_value) if elite_value != null else false
        if archetype == &"warlord":
            title = "WARLORD SLAIN"
        elif elite:
            title = "CAPTAIN DOWN"
    _big_callout(title)
    _push_event(title + "  " + _enemy_display_name(enemy))

func register_player_hurt(damage: float) -> void:
    _push_event("DAMAGE TAKEN  -%.0f" % damage)

func register_perfect_response(kind: StringName) -> void:
    perfect_elapsed = 0.0
    perfect_duration = 0.92
    var is_dodge: bool = kind == &"dodge"
    perfect_accent_color = Color(0.48, 0.90, 1.0) if is_dodge else Color(1.0, 0.76, 0.20)
    if perfect_label != null:
        perfect_label.text = "PERFECT DODGE" if is_dodge else "PERFECT BLOCK"
        perfect_label.modulate = Color(perfect_accent_color.r, perfect_accent_color.g, perfect_accent_color.b, 0.0)
    if perfect_window_label != null:
        perfect_window_label.text = "COUNTER WINDOW"
        perfect_window_label.modulate = Color(perfect_accent_color.r, perfect_accent_color.g, perfect_accent_color.b, 0.0)
    if perfect_hint_label != null:
        perfect_hint_label.text = "SHIFT  CHARGED COUNTER     •     LIGHT  POWER RIPOSTE"
        perfect_hint_label.modulate = Color(0.86, 0.91, 0.94, 0.0)
    if perfect_tint != null:
        perfect_tint.color = Color(0.08, 0.26, 0.36, 0.0) if is_dodge else Color(0.36, 0.22, 0.035, 0.0)
    if perfect_frame_style != null:
        perfect_frame_style.border_color = Color(perfect_accent_color.r, perfect_accent_color.g, perfect_accent_color.b, 0.82)
    if perfect_bar_fill != null:
        perfect_bar_fill.color = perfect_accent_color
    _push_event(("PERFECT DODGE" if is_dodge else "PERFECT BLOCK") + "  •  COUNTER READY")

func consume_perfect_response() -> void:
    if perfect_duration <= 0.0:
        return
    perfect_elapsed = maxf(perfect_elapsed, perfect_duration - 0.26)

func _build_ui() -> void:
    var hoplite_theme := Theme.new()
    var hoplite_font := SystemFont.new()
    # Cinzel/Trajan keep the monumental antique silhouette when installed.
    # Palatino and Georgia are dependable classical fallbacks on Windows.
    hoplite_font.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Palatino Linotype", "Georgia"])
    hoplite_theme.default_font = hoplite_font

    root = Control.new()
    root.name = "GoreHUDRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.theme = hoplite_theme
    add_child(root)

    feedback_root = Control.new()
    feedback_root.name = "CombatConfirmationRoot"
    feedback_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    feedback_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_root.theme = hoplite_theme
    add_child(feedback_root)

    _build_cinematic_overlay()
    _build_perfect_response_overlay()

    # V0.0.14: no dark rectangles. Combo + impact feedback live cleanly at the
    # top-middle of the screen so the battlefield stays visible underneath.
    combo_label = Label.new()
    combo_label.anchor_left = 0.5
    combo_label.anchor_right = 0.5
    combo_label.offset_left = -260.0
    combo_label.offset_right = 260.0
    combo_label.offset_top = 18.0
    combo_label.offset_bottom = 62.0
    combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    combo_label.add_theme_font_size_override("font_size", 34)
    combo_label.add_theme_constant_override("outline_size", 7)
    combo_label.add_theme_color_override("font_outline_color", Color(0.06, 0.015, 0.01, 0.92))
    combo_label.modulate = Color(1.0, 0.78, 0.18)
    root.add_child(combo_label)

    grade_label = Label.new()
    grade_label.anchor_left = 0.5
    grade_label.anchor_right = 0.5
    grade_label.offset_left = -220.0
    grade_label.offset_right = 220.0
    grade_label.offset_top = 55.0
    grade_label.offset_bottom = 86.0
    grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    grade_label.add_theme_font_size_override("font_size", 20)
    grade_label.add_theme_constant_override("outline_size", 6)
    grade_label.add_theme_color_override("font_outline_color", Color(0.06, 0.01, 0.005, 0.92))
    grade_label.modulate = Color(0.96, 0.12, 0.055)
    root.add_child(grade_label)

    hit_marker = Label.new()
    hit_marker.text = "X"
    hit_marker.anchor_left = 0.5
    hit_marker.anchor_right = 0.5
    hit_marker.anchor_top = 0.5
    hit_marker.anchor_bottom = 0.5
    hit_marker.offset_left = -28.0
    hit_marker.offset_right = 28.0
    hit_marker.offset_top = -32.0
    hit_marker.offset_bottom = 24.0
    hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hit_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hit_marker.add_theme_font_size_override("font_size", 34)
    hit_marker.add_theme_constant_override("outline_size", 5)
    hit_marker.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.005, 0.92))
    hit_marker.modulate = Color(1.0, 0.18, 0.07, 0.0)
    feedback_root.add_child(hit_marker)

    hit_value_label = Label.new()
    hit_value_label.anchor_left = 0.5
    hit_value_label.anchor_right = 0.5
    hit_value_label.anchor_top = 0.5
    hit_value_label.anchor_bottom = 0.5
    hit_value_label.offset_left = -125.0
    hit_value_label.offset_right = 125.0
    hit_value_label.offset_top = 24.0
    hit_value_label.offset_bottom = 49.0
    hit_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hit_value_label.add_theme_font_size_override("font_size", 14)
    hit_value_label.add_theme_constant_override("outline_size", 4)
    hit_value_label.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.005, 0.92))
    hit_value_label.modulate = Color(1.0, 0.77, 0.46, 0.0)
    feedback_root.add_child(hit_value_label)

    # Major gore events are intentionally huge and central: this is the arcade
    # punctuation layer, not a debug readout.
    callout_label = Label.new()
    callout_label.anchor_left = 0.08
    callout_label.anchor_right = 0.92
    callout_label.anchor_top = 0.31
    callout_label.anchor_bottom = 0.31
    callout_label.offset_top = -52.0
    callout_label.offset_bottom = 64.0
    callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    callout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    callout_label.add_theme_font_size_override("font_size", 82)
    callout_label.add_theme_constant_override("outline_size", 12)
    callout_label.add_theme_color_override("font_outline_color", Color(0.045, 0.004, 0.002, 0.96))
    callout_label.modulate = Color(1.0, 0.055, 0.018, 0.0)
    root.add_child(callout_label)

    # Small transparent combat history in the lower-right corner.
    event_label = Label.new()
    event_label.anchor_left = 1.0
    event_label.anchor_right = 1.0
    event_label.anchor_top = 1.0
    event_label.anchor_bottom = 1.0
    event_label.offset_left = -340.0
    event_label.offset_right = -20.0
    event_label.offset_top = -142.0
    event_label.offset_bottom = -22.0
    event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    event_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    event_label.add_theme_font_size_override("font_size", 12)
    event_label.add_theme_constant_override("outline_size", 4)
    event_label.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.008, 0.88))
    event_label.modulate = Color(0.92, 0.76, 0.62, 0.82)
    root.add_child(event_label)

    hint_label = Label.new()
    hint_label.anchor_left = 0.0
    hint_label.anchor_bottom = 1.0
    hint_label.anchor_top = 1.0
    hint_label.offset_left = 18.0
    hint_label.offset_right = 250.0
    hint_label.offset_top = -42.0
    hint_label.offset_bottom = -16.0
    hint_label.text = "G  GORE MODE"
    hint_label.add_theme_font_size_override("font_size", 12)
    hint_label.add_theme_constant_override("outline_size", 4)
    hint_label.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.008, 0.88))
    hint_label.modulate = Color(0.72, 0.58, 0.50, 0.70)
    root.add_child(hint_label)

    _refresh_combo()
    _refresh_events()

func _build_cinematic_overlay() -> void:
    cinematic_tint = ColorRect.new()
    cinematic_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cinematic_tint.color = Color(0.32, 0.0, 0.005, 0.0)
    cinematic_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(cinematic_tint)

    cinematic_top_bar = ColorRect.new()
    cinematic_top_bar.anchor_right = 1.0
    cinematic_top_bar.offset_bottom = 0.0
    cinematic_top_bar.color = Color(0.012, 0.004, 0.003, 0.96)
    cinematic_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(cinematic_top_bar)

    cinematic_bottom_bar = ColorRect.new()
    cinematic_bottom_bar.anchor_top = 1.0
    cinematic_bottom_bar.anchor_right = 1.0
    cinematic_bottom_bar.anchor_bottom = 1.0
    cinematic_bottom_bar.offset_top = 0.0
    cinematic_bottom_bar.color = Color(0.012, 0.004, 0.003, 0.96)
    cinematic_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(cinematic_bottom_bar)

    cinematic_caption = Label.new()
    cinematic_caption.anchor_left = 0.5
    cinematic_caption.anchor_right = 0.5
    cinematic_caption.anchor_top = 1.0
    cinematic_caption.anchor_bottom = 1.0
    cinematic_caption.offset_left = -320.0
    cinematic_caption.offset_right = 320.0
    cinematic_caption.offset_top = -58.0
    cinematic_caption.offset_bottom = -16.0
    cinematic_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cinematic_caption.add_theme_font_size_override("font_size", 23)
    cinematic_caption.add_theme_constant_override("outline_size", 6)
    cinematic_caption.add_theme_color_override("font_outline_color", Color(0.03, 0.0, 0.0, 0.98))
    cinematic_caption.modulate = Color(1.0, 0.24, 0.08, 0.0)
    root.add_child(cinematic_caption)

func _build_perfect_response_overlay() -> void:
    perfect_tint = ColorRect.new()
    perfect_tint.name = "PerfectResponseTint"
    perfect_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    perfect_tint.color = Color(0.36, 0.22, 0.035, 0.0)
    perfect_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_root.add_child(perfect_tint)

    perfect_frame_style = StyleBoxFlat.new()
    perfect_frame_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
    perfect_frame_style.border_color = Color(1.0, 0.76, 0.20, 0.82)
    perfect_frame_style.set_border_width_all(3)
    perfect_frame_style.set_corner_radius_all(18)
    perfect_frame = Panel.new()
    perfect_frame.name = "PerfectResponseFrame"
    perfect_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    perfect_frame.offset_left = 12.0
    perfect_frame.offset_top = 12.0
    perfect_frame.offset_right = -12.0
    perfect_frame.offset_bottom = -12.0
    perfect_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    perfect_frame.add_theme_stylebox_override("panel", perfect_frame_style)
    perfect_frame.modulate.a = 0.0
    feedback_root.add_child(perfect_frame)

    perfect_label = Label.new()
    perfect_label.name = "PerfectResponseLabel"
    perfect_label.anchor_left = 0.5
    perfect_label.anchor_right = 0.5
    perfect_label.anchor_top = 0.30
    perfect_label.anchor_bottom = 0.30
    perfect_label.offset_left = -280.0
    perfect_label.offset_right = 280.0
    perfect_label.offset_top = -34.0
    perfect_label.offset_bottom = 30.0
    perfect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    perfect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    perfect_label.add_theme_font_size_override("font_size", 48)
    perfect_label.add_theme_constant_override("outline_size", 10)
    perfect_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.035, 0.94))
    perfect_label.modulate = Color(1.0, 0.82, 0.32, 0.0)
    perfect_label.pivot_offset = Vector2(280.0, 32.0)
    feedback_root.add_child(perfect_label)

    perfect_window_label = Label.new()
    perfect_window_label.name = "PerfectCounterWindowLabel"
    perfect_window_label.anchor_left = 0.5
    perfect_window_label.anchor_right = 0.5
    perfect_window_label.anchor_top = 0.30
    perfect_window_label.anchor_bottom = 0.30
    perfect_window_label.offset_left = -220.0
    perfect_window_label.offset_right = 220.0
    perfect_window_label.offset_top = 32.0
    perfect_window_label.offset_bottom = 56.0
    perfect_window_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    perfect_window_label.add_theme_font_size_override("font_size", 16)
    perfect_window_label.add_theme_constant_override("outline_size", 5)
    perfect_window_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.035, 0.94))
    perfect_window_label.modulate = Color(1.0, 0.82, 0.32, 0.0)
    feedback_root.add_child(perfect_window_label)

    perfect_bar_background = ColorRect.new()
    perfect_bar_background.name = "PerfectCounterTimeBackground"
    perfect_bar_background.anchor_left = 0.5
    perfect_bar_background.anchor_right = 0.5
    perfect_bar_background.anchor_top = 0.30
    perfect_bar_background.anchor_bottom = 0.30
    perfect_bar_background.offset_left = -210.0
    perfect_bar_background.offset_right = 210.0
    perfect_bar_background.offset_top = 59.0
    perfect_bar_background.offset_bottom = 66.0
    perfect_bar_background.color = Color(0.015, 0.025, 0.035, 0.72)
    perfect_bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    perfect_bar_background.modulate.a = 0.0
    feedback_root.add_child(perfect_bar_background)

    perfect_bar_fill = ColorRect.new()
    perfect_bar_fill.name = "PerfectCounterTimeFill"
    perfect_bar_fill.anchor_left = 0.5
    perfect_bar_fill.anchor_right = 0.5
    perfect_bar_fill.anchor_top = 0.30
    perfect_bar_fill.anchor_bottom = 0.30
    perfect_bar_fill.offset_left = -210.0
    perfect_bar_fill.offset_right = 210.0
    perfect_bar_fill.offset_top = 59.0
    perfect_bar_fill.offset_bottom = 66.0
    perfect_bar_fill.color = Color(1.0, 0.76, 0.20)
    perfect_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    perfect_bar_fill.modulate.a = 0.0
    feedback_root.add_child(perfect_bar_fill)

    perfect_hint_label = Label.new()
    perfect_hint_label.name = "PerfectResponseHint"
    perfect_hint_label.anchor_left = 0.5
    perfect_hint_label.anchor_right = 0.5
    perfect_hint_label.anchor_top = 0.30
    perfect_hint_label.anchor_bottom = 0.30
    perfect_hint_label.offset_left = -360.0
    perfect_hint_label.offset_right = 360.0
    perfect_hint_label.offset_top = 74.0
    perfect_hint_label.offset_bottom = 106.0
    perfect_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    perfect_hint_label.add_theme_font_size_override("font_size", 18)
    perfect_hint_label.add_theme_constant_override("outline_size", 6)
    perfect_hint_label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.035, 0.92))
    perfect_hint_label.modulate = Color(0.86, 0.91, 0.94, 0.0)
    feedback_root.add_child(perfect_hint_label)

func _update_perfect_response_overlay(delta: float) -> void:
    var amount: float = 0.0
    var progress: float = 1.0
    if perfect_duration > 0.0 and perfect_elapsed < perfect_duration:
        perfect_elapsed += delta
        progress = clampf(perfect_elapsed / perfect_duration, 0.0, 1.0)
        if progress < 0.11:
            amount = smoothstep(0.0, 0.11, progress)
        elif progress < 0.70:
            amount = 1.0
        else:
            amount = 1.0 - smoothstep(0.70, 1.0, progress)
    if perfect_label != null:
        perfect_label.modulate.a = amount
        perfect_label.scale = Vector2.ONE * lerpf(1.10, 1.0, clampf(progress / 0.18, 0.0, 1.0))
    if perfect_window_label != null:
        perfect_window_label.modulate.a = amount * (0.82 + sin(perfect_elapsed * 15.0) * 0.18)
    if perfect_hint_label != null:
        perfect_hint_label.modulate.a = amount * 0.96
    if perfect_tint != null:
        perfect_tint.color.a = amount * 0.115
    if perfect_frame != null:
        perfect_frame.modulate.a = amount * (0.78 + sin(perfect_elapsed * 12.0) * 0.12)
    if perfect_bar_background != null:
        perfect_bar_background.modulate.a = amount * 0.72
    if perfect_bar_fill != null:
        perfect_bar_fill.modulate.a = amount
        perfect_bar_fill.size.x = 420.0 * clampf(1.0 - progress, 0.0, 1.0)

func _update_cinematic_overlay(delta: float) -> void:
    var amount: float = 0.0
    if cinematic_duration > 0.0 and cinematic_elapsed < cinematic_duration:
        cinematic_elapsed += delta
        var progress: float = clampf(cinematic_elapsed / cinematic_duration, 0.0, 1.0)
        if progress < 0.18:
            amount = sin(progress / 0.18 * PI * 0.5)
        elif progress < 0.64:
            amount = 1.0
        else:
            amount = sin((1.0 - progress) / 0.36 * PI * 0.5)
    var bar_height: float = 66.0 * amount
    if cinematic_top_bar != null:
        cinematic_top_bar.offset_bottom = bar_height
    if cinematic_bottom_bar != null:
        cinematic_bottom_bar.offset_top = -bar_height
    if cinematic_tint != null:
        cinematic_tint.color.a = 0.16 * amount
    if cinematic_caption != null:
        cinematic_caption.modulate.a = amount

func _refresh_combo() -> void:
    if combo_label == null or grade_label == null:
        return
    if combo_count <= 0:
        combo_label.text = ""
        grade_label.text = ""
        return
    combo_label.text = "%d HIT COMBO" % combo_count
    grade_label.text = _combo_grade(combo_count)

func _combo_grade(count: int) -> String:
    if count >= 20:
        return "BLOODSTORM"
    if count >= 15:
        return "CARNAGE"
    if count >= 10:
        return "SAVAGE"
    if count >= 6:
        return "BRUTAL"
    if count >= 3:
        return "VIOLENT"
    return "HIT"

func _big_callout(text_value: String) -> void:
    if callout_label == null:
        return
    callout_label.text = text_value
    var font_size: int = 58
    if text_value == "DECAPITATION" or text_value == "DISMEMBERMENT" or text_value == "DÉCAPITATION" or text_value == "DÉMEMBREMENT":
        font_size = 90
    elif text_value == "WARLORD SLAIN":
        font_size = 82
    elif text_value == "CAPTAIN DOWN":
        font_size = 68
    callout_label.add_theme_font_size_override("font_size", font_size)
    callout_timer = 0.92
    callout_label.modulate.a = 1.0

func _push_event(text_value: String) -> void:
    events.push_front(text_value)
    while events.size() > 5:
        events.pop_back()
    _refresh_events()

func _refresh_events() -> void:
    if event_label == null:
        return
    var combined: String = ""
    for i: int in range(events.size()):
        if i > 0:
            combined += "\n"
        combined += events[i]
    event_label.text = combined

func _pretty_zone(zone: StringName) -> String:
    return String(zone).replace("_", " ").to_upper()

func _enemy_display_name(enemy: Node) -> String:
    if enemy == null:
        return "ATHENIAN"
    var value: Variant = enemy.get("archetype_name")
    if value != null and String(value) != "":
        return String(value)
    return "ATHENIAN"
