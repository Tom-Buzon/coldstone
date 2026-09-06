extends VBoxContainer

const Profile = preload("res://scripts/abilities/skill_profile.gd")
var runtime: Node
var tree: Tree
var items: Dictionary = {}
var spins: Dictionary = {}
var status: Label
var ultimate_option: OptionButton
var syncing := false

func configure(skill_runtime: Node) -> void:
	runtime = skill_runtime
	_build()
	runtime.profile.changed.connect(refresh)
	runtime.state_changed.connect(_refresh_status)
	refresh()

func _build() -> void:
	add_theme_constant_override("separation", 10)
	var heading := Label.new()
	heading.text = "FORGE DU HÉROS"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color(1.0, 0.73, 0.35))
	add_child(heading)
	var intro := Label.new()
	intro.text = "Activez chaque compétence. Les enfants nécessitent leurs prérequis. Les modifications sont appliquées immédiatement."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	var bar := HBoxContainer.new()
	add_child(bar)
	var base := Button.new()
	base.text = "Pack de base"
	base.pressed.connect(func(): runtime.profile.reset())
	bar.add_child(base)
	var all := Button.new()
	all.text = "Tout débloquer"
	all.pressed.connect(_unlock_all)
	bar.add_child(all)
	ultimate_option = OptionButton.new()
	for label: String in ["Aura meurtrière", "Fire Wall", "Coup de tonnerre", "Wrath of Ares"]: ultimate_option.add_item(label)
	ultimate_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ultimate_option.item_selected.connect(func(index: int):
		runtime.profile.selected_ultimate = Profile.ULTIMATES[index]
		runtime.profile.emit_changed())
	bar.add_child(ultimate_option)
	var pages := TabContainer.new()
	pages.name = "SkillPages"
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pages)
	tree = Tree.new()
	tree.name = "Compétences"
	tree.columns = 2
	tree.set_column_title(0, "Capacité / prérequis")
	tree.set_column_title(1, "Effet")
	tree.column_titles_visible = true
	tree.set_column_expand_ratio(0, 2)
	tree.set_column_expand_ratio(1, 3)
	tree.hide_root = true
	tree.custom_minimum_size.y = 280
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(tree)
	var root := tree.create_item()
	var branches: Array[TreeItem] = []
	for label: String in Profile.BRANCHES:
		var item := tree.create_item(root)
		item.set_text(0, label.to_upper())
		item.set_custom_color(0, Color(1.0, 0.73, 0.35))
		branches.append(item)
	var feature_branches: Dictionary = {}
	for definition: Dictionary in Profile.features():
		var same_branch: bool = feature_branches.get(definition.parent, -1) == definition.branch
		var parent: TreeItem = items[definition.parent] if same_branch else branches[definition.branch]
		var item := tree.create_item(parent)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_text(0, definition.label)
		item.set_text(1, definition.description)
		item.set_tooltip_text(1, definition.description)
		item.set_metadata(0, definition.id)
		items[definition.id] = item
		feature_branches[definition.id] = definition.branch
	tree.item_edited.connect(_edited)
	if bool(ProjectSettings.get_setting("hoplite/development/skill_tuning", true)):
		var scroll := ScrollContainer.new()
		scroll.name = "Dev · équilibrage"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		pages.add_child(scroll)
		var controls := VBoxContainer.new()
		controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_theme_constant_override("separation", 8)
		scroll.add_child(controls)
		var dev_note := Label.new()
		dev_note.text = "Laboratoire : cette branche peut être retirée du jeu final. Les valeurs sont sauvegardées à la fermeture du menu."
		dev_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls.add_child(dev_note)
		var actions := HBoxContainer.new()
		controls.add_child(actions)
		var fill := Button.new()
		fill.text = "Charger l'ultime"
		fill.pressed.connect(func(): runtime.add_charge(100.0))
		actions.add_child(fill)
		var recover := Button.new()
		recover.text = "Vie et mobilité au maximum"
		recover.pressed.connect(func():
			runtime.player.health = runtime.player.max_health
			runtime.player._restore_all_mobility_charges()
			runtime.player.spiral_stamina = runtime.player.max_spiral_stamina)
		actions.add_child(recover)
		for definition: Dictionary in Profile.controls():
			var row := HBoxContainer.new()
			controls.add_child(row)
			var label := Label.new()
			label.text = definition.label
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var spin := SpinBox.new()
			spin.min_value = definition.min
			spin.max_value = definition.max
			spin.step = definition.step
			spin.suffix = definition.unit
			spin.custom_minimum_size.x = 145
			spin.value_changed.connect(_tuned.bind(definition.id))
			row.add_child(spin)
			spins[definition.id] = spin
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

func _edited() -> void:
	if syncing: return
	var item := tree.get_edited()
	if item != null: runtime.profile.set_feature(item.get_metadata(0), item.is_checked(0))

func _tuned(amount: float, id: StringName) -> void:
	if not syncing: runtime.profile.set_tuning(id, amount)

func _unlock_all() -> void:
	for id: StringName in runtime.profile.enabled: runtime.profile.enabled[id] = true
	runtime.profile.emit_changed()

func refresh() -> void:
	syncing = true
	for id: StringName in items:
		var item: TreeItem = items[id]
		item.set_checked(0, runtime.profile.enabled[id])
		item.set_custom_color(0, Color(0.85, 0.95, 0.87) if runtime.active(id) else Color(0.52, 0.55, 0.60))
		item.set_tooltip_text(0, "Active" if runtime.active(id) else "Désactivée ou prérequis manquant")
	for id: StringName in spins: spins[id].set_value_no_signal(runtime.value(id))
	ultimate_option.select(Profile.ULTIMATES.find(runtime.profile.selected_ultimate))
	syncing = false
	_refresh_status()

func _refresh_status() -> void:
	if status == null: return
	status.text = "Ultime : %.0f / 100 — %s\nE : arme / maintenir : ramasser  •  F maintenu : lame  •  X : impact  •  A : ultime / maintenir : roue" % [runtime.ultimate_charge, "prêt" if runtime.ultimate_charge >= 100 and runtime.active(runtime.profile.selected_ultimate) else "débloquer et remplir la jauge"]

func flush() -> Error:
	var result: Error = runtime.flush_save()
	if result != OK: status.text = "Sauvegarde impossible : " + error_string(result) + ". Les changements restent actifs pour cette session."
	return result
