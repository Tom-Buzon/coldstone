extends CanvasLayer
class_name HopliteBattleQuestSystem

signal quest_completed(quest_id: StringName, reward_id: StringName)
signal quest_failed(quest_id: StringName)

var quests: Dictionary = {}
var quest_order: Array[StringName] = []
var phase_title: String = ""
var panel: PanelContainer
var phase_label: Label
var quest_list: VBoxContainer
var history_label: Label
var toast_label: Label
var toast_tween: Tween

func _ready() -> void:
    layer = 15
    _build_hud()
    _refresh_hud()

func register_quest(quest_id: StringName, title: String, description: String, target: int = 1, optional: bool = false, active: bool = false, reward_id: StringName = StringName()) -> void:
    quests[quest_id] = {
        "title": title,
        "description": description,
        "target": maxi(target, 1),
        "progress": 0,
        "optional": optional,
        "state": &"active" if active else &"locked",
        "reward": reward_id
    }
    if not quest_order.has(quest_id):
        quest_order.append(quest_id)
    _refresh_hud()

func set_phase(title: String) -> void:
    phase_title = title
    _refresh_hud()
    _show_toast(title, Color(0.96, 0.69, 0.24))

func announce(message: String, color: Color = Color(0.86, 0.91, 1.0)) -> void:
    _show_toast(message, color)

func activate(quest_id: StringName) -> void:
    if not quests.has(quest_id):
        return
    var quest: Dictionary = quests[quest_id]
    if StringName(quest.get("state", &"locked")) != &"locked":
        return
    quest["state"] = &"active"
    quests[quest_id] = quest
    _refresh_hud()
    _show_toast("NOUVEL OBJECTIF — " + String(quest.get("title", "")), Color(0.86, 0.91, 1.0))

func increment(quest_id: StringName, amount: int = 1) -> void:
    if not quests.has(quest_id):
        return
    var quest: Dictionary = quests[quest_id]
    if StringName(quest.get("state", &"locked")) != &"active":
        return
    var target: int = int(quest.get("target", 1))
    quest["progress"] = mini(target, int(quest.get("progress", 0)) + maxi(amount, 0))
    quests[quest_id] = quest
    if int(quest["progress"]) >= target:
        complete(quest_id)
    else:
        _refresh_hud()

func set_progress(quest_id: StringName, progress: int) -> void:
    if not quests.has(quest_id):
        return
    var quest: Dictionary = quests[quest_id]
    if StringName(quest.get("state", &"locked")) != &"active":
        return
    quest["progress"] = clampi(progress, 0, int(quest.get("target", 1)))
    quests[quest_id] = quest
    if int(quest["progress"]) >= int(quest.get("target", 1)):
        complete(quest_id)
    else:
        _refresh_hud()

func set_target(quest_id: StringName, target: int) -> void:
    if not quests.has(quest_id):
        return
    var quest: Dictionary = quests[quest_id]
    quest["target"] = maxi(target, 1)
    quest["progress"] = mini(int(quest.get("progress", 0)), int(quest["target"]))
    quests[quest_id] = quest
    _refresh_hud()

func complete(quest_id: StringName) -> void:
    if not quests.has(quest_id):
        return
    var quest: Dictionary = quests[quest_id]
    if StringName(quest.get("state", &"locked")) == &"completed":
        return
    quest["progress"] = int(quest.get("target", 1))
    quest["state"] = &"completed"
    quests[quest_id] = quest
    _refresh_hud()
    _show_toast("ACCOMPLI — " + String(quest.get("title", "")), Color(0.42, 1.0, 0.52))
    quest_completed.emit(quest_id, StringName(quest.get("reward", StringName())))

func fail(quest_id: StringName) -> void:
    if not quests.has(quest_id):
        return
    var quest: Dictionary = quests[quest_id]
    if StringName(quest.get("state", &"locked")) != &"active":
        return
    quest["state"] = &"failed"
    quests[quest_id] = quest
    _refresh_hud()
    _show_toast("ECHEC — " + String(quest.get("title", "")), Color(1.0, 0.25, 0.18))
    quest_failed.emit(quest_id)

func state_of(quest_id: StringName) -> StringName:
    if not quests.has(quest_id):
        return &"missing"
    return StringName((quests[quest_id] as Dictionary).get("state", &"missing"))

func progress_of(quest_id: StringName) -> int:
    if not quests.has(quest_id):
        return 0
    return int((quests[quest_id] as Dictionary).get("progress", 0))

func _build_hud() -> void:
    panel = PanelContainer.new()
    panel.name = "QuestPanel"
    panel.add_to_group("global_hud_objectives")
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.offset_left = -372.0
    panel.offset_top = 14.0
    panel.offset_right = -14.0
    panel.offset_bottom = 244.0
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.018, 0.022, 0.032, 0.93)
    panel_style.border_width_left = 5
    panel_style.border_color = Color(0.82, 0.34, 0.08)
    panel_style.corner_radius_top_left = 4
    panel_style.corner_radius_bottom_left = 4
    panel.add_theme_stylebox_override("panel", panel_style)
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 13)
    margin.add_theme_constant_override("margin_right", 11)
    margin.add_theme_constant_override("margin_top", 9)
    margin.add_theme_constant_override("margin_bottom", 9)
    panel.add_child(margin)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 6)
    margin.add_child(content)

    phase_label = Label.new()
    phase_label.add_theme_font_size_override("font_size", 16)
    phase_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
    phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(phase_label)

    var separator := HSeparator.new()
    separator.modulate = Color(0.82, 0.34, 0.08, 0.72)
    content.add_child(separator)

    quest_list = VBoxContainer.new()
    quest_list.add_theme_constant_override("separation", 4)
    content.add_child(quest_list)

    history_label = Label.new()
    history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    history_label.add_theme_font_size_override("font_size", 13)
    history_label.add_theme_color_override("font_color", Color(0.62, 0.67, 0.73))
    history_label.visible = false
    content.add_child(history_label)

    toast_label = Label.new()
    toast_label.anchor_left = 0.5
    toast_label.anchor_right = 0.5
    toast_label.offset_left = -340.0
    toast_label.offset_top = 88.0
    toast_label.offset_right = 340.0
    toast_label.offset_bottom = 132.0
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 24)
    toast_label.modulate.a = 0.0
    add_child(toast_label)

func _refresh_hud() -> void:
    if phase_label == null or quest_list == null or history_label == null:
        return
    phase_label.text = phase_title if not phase_title.is_empty() else "OBJECTIFS"
    for child: Node in quest_list.get_children():
        quest_list.remove_child(child)
        child.queue_free()

    var active_count: int = 0
    var main_added: bool = false
    for quest_id: StringName in quest_order:
        var quest: Dictionary = quests[quest_id]
        var state: StringName = StringName(quest.get("state", &"locked"))
        if state == &"active" and not bool(quest.get("optional", false)):
            if not main_added:
                _add_quest_card(quest)
                main_added = true
            else:
                _add_compact_quest_row(quest)
            active_count += 1
    for quest_id: StringName in quest_order:
        var quest: Dictionary = quests[quest_id]
        if StringName(quest.get("state", &"locked")) == &"active" and bool(quest.get("optional", false)):
            _add_compact_quest_row(quest)
            active_count += 1
    if active_count == 0:
        var empty := Label.new()
        empty.text = "Aucun objectif actif"
        empty.add_theme_color_override("font_color", Color(0.66, 0.70, 0.76))
        quest_list.add_child(empty)
    history_label.text = ""

func _add_quest_card(quest: Dictionary) -> void:
    var optional: bool = bool(quest.get("optional", false))
    var accent: Color = Color(0.42, 0.68, 1.0) if optional else Color(0.96, 0.52, 0.16)
    var card := PanelContainer.new()
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(accent.r * 0.10, accent.g * 0.10, accent.b * 0.10, 0.78)
    card_style.border_width_left = 3
    card_style.border_color = accent
    card_style.corner_radius_top_right = 4
    card_style.corner_radius_bottom_right = 4
    card.add_theme_stylebox_override("panel", card_style)
    quest_list.add_child(card)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 9)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_top", 5)
    margin.add_theme_constant_override("margin_bottom", 5)
    card.add_child(margin)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 3)
    margin.add_child(content)

    var title := Label.new()
    title.text = ("OPTIONNEL  •  " if optional else "PRINCIPAL  •  ") + String(quest.get("title", ""))
    title.add_theme_font_size_override("font_size", 14)
    title.add_theme_color_override("font_color", accent.lightened(0.18))
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(title)

    var description := Label.new()
    description.text = String(quest.get("description", ""))
    description.add_theme_font_size_override("font_size", 12)
    description.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90))
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(description)

    var target: int = int(quest.get("target", 1))
    if target > 1:
        var progress: int = int(quest.get("progress", 0))
        var progress_row := HBoxContainer.new()
        progress_row.add_theme_constant_override("separation", 8)
        content.add_child(progress_row)
        var bar := ProgressBar.new()
        bar.custom_minimum_size = Vector2(0.0, 9.0)
        bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.min_value = 0.0
        bar.max_value = float(target)
        bar.value = float(progress)
        bar.show_percentage = false
        progress_row.add_child(bar)
        var counter := Label.new()
        counter.text = "%d / %d" % [progress, target]
        counter.add_theme_font_size_override("font_size", 12)
        counter.add_theme_color_override("font_color", accent.lightened(0.22))
        progress_row.add_child(counter)

func _add_compact_quest_row(quest: Dictionary) -> void:
    var optional: bool = bool(quest.get("optional", false))
    var accent: Color = Color(0.42, 0.68, 1.0) if optional else Color(0.96, 0.52, 0.16)
    var row := PanelContainer.new()
    var row_style := StyleBoxFlat.new()
    row_style.bg_color = Color(accent.r * 0.075, accent.g * 0.075, accent.b * 0.075, 0.68)
    row_style.border_width_left = 2
    row_style.border_color = accent.darkened(0.08)
    row.add_theme_stylebox_override("panel", row_style)
    quest_list.add_child(row)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 8)
    margin.add_theme_constant_override("margin_right", 7)
    margin.add_theme_constant_override("margin_top", 3)
    margin.add_theme_constant_override("margin_bottom", 3)
    row.add_child(margin)

    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation", 7)
    margin.add_child(line)

    var label := Label.new()
    label.text = ("OPTIONNEL  •  " if optional else "PRINCIPAL  •  ") + String(quest.get("title", ""))
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", accent.lightened(0.18))
    line.add_child(label)

    var target: int = int(quest.get("target", 1))
    if target > 1:
        var counter := Label.new()
        counter.text = "%d/%d" % [int(quest.get("progress", 0)), target]
        counter.add_theme_font_size_override("font_size", 12)
        counter.add_theme_color_override("font_color", Color(0.84, 0.87, 0.92))
        line.add_child(counter)

func _show_toast(message: String, color: Color) -> void:
    if toast_label == null:
        return
    if toast_tween != null and toast_tween.is_valid():
        toast_tween.kill()
    toast_label.text = message
    toast_label.modulate = color
    toast_label.modulate.a = 0.0
    toast_tween = create_tween()
    toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.18)
    toast_tween.tween_interval(2.1)
    toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.45)
