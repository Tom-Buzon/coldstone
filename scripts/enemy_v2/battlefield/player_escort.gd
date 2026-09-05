extends Node
## Scene-owned player orders. Reuses V2 bodies, weapons, LOD and shared admission.
var service: Node
var runtime: Node
var members: Array[Node3D] = []
var mode: StringName = &"auto"
var group_ids: Array[StringName] = []
var destination := Vector3.ZERO
var label: Label
var marker: MeshInstance3D
var pending: StringName = &""
var census_elapsed := 0.0

func configure(value: Node, troop_runtime: Node) -> void:
	service = value
	runtime = troop_runtime
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(24,110)
	label.add_theme_color_override("font_color",Color("86c9ff"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)
	var reticle := Label.new()
	reticle.text = "+"
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position -= Vector2(5,10)

	marker = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 6
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("56c9ff")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.visible = false
	_refresh_label()

func register_group(id: StringName, actors: Array[Node], _properties: Dictionary, _role: StringName, settings: Dictionary) -> void:
	for child: StringName in runtime.group_children.get(id,[id]):
		if not group_ids.has(child): group_ids.append(child)
	for actor: Node3D in actors:
		actor.set_meta("player_escort",true)
		actor.combat_modifiers.configure(float(settings.get("bodyguard_power",4.0)))
		members.append(actor)
	_refresh_label()

func _process(delta: float) -> void:
	census_elapsed += delta
	if census_elapsed < 0.2: return
	census_elapsed = 0.0
	var previous := members.size()
	members = members.filter(func(a: Node3D) -> bool: return is_instance_valid(a) and not a.dead)
	if mode == &"attack":
		var moving := false
		for id: StringName in group_ids:
			if runtime.groups.has(id) and runtime.groups[id].has("manual_order"): moving = true
		if not moving:
			mode = &"auto"
			marker.visible = false
			_refresh_label()
	if previous != members.size(): _refresh_label()
	if members.is_empty(): marker.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or members.is_empty(): return
	if event.is_action_pressed("escort_attack"): pending = &"attack"
	elif event.is_action_pressed("escort_hold"): pending = &"hold"
	else: return
	get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if pending == &"": return
	var camera := get_viewport().get_camera_3d()
	if camera == null: pending = &""; return
	var screen := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(screen)*100.0,1)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y<0.5: label.text = "ESCORTE : visez un sol à moins de 100 m"
	else: issue(pending,hit.position)
	pending = &""

func issue(order: StringName, point: Vector3) -> void:
	if order not in [&"attack",&"hold"]: return
	pending = &""
	mode = order
	destination = point
	marker.global_position = point+Vector3.UP*0.12
	marker.visible = true
	var camera := get_viewport().get_camera_3d()
	var facing: Vector3 = -camera.global_basis.z if camera != null else Vector3.FORWARD
	facing.y = 0
	if facing.length_squared()<0.01: facing = Vector3.FORWARD
	facing = facing.normalized()
	var right := Vector3.UP.cross(facing)
	var width := 0.0
	var active_ids: Array[StringName] = []
	for id: StringName in group_ids:
		if not runtime.groups.has(id): continue
		active_ids.append(id)
		width += float(runtime.battle_layout.records[id].formation_width)+1.0
	var cursor := -width*0.5
	for id: StringName in active_ids:
		var span := float(runtime.battle_layout.records[id].formation_width)+1.0
		var state: Dictionary = runtime.groups[id]
		state.manual_order = {"mode":order,"position":point+right*(cursor+span*0.5),"facing":facing}
		cursor += span
		for actor: Node3D in state.members:
			actor.combat_modifiers.intercept_reach = 3.5 if mode == &"hold" else 10.0
			actor.combat.cancel_player_order()
			runtime.threat_budget.release(actor.get_instance_id())
			actor.set_combat_target(null)
	for army: RefCounted in service.armies.values():
		if army.runtime == runtime:
			army.next_orders = 0.0
			army.update(service.clock,army.focus.global_position,army.last_opponents,army.encounter_active)
	_refresh_label()

func _refresh_label() -> void:
	if label == null: return
	label.visible = not members.is_empty()
	label.text = "TROUPE ÉLITE %d — %s\nG : rejoindre puis combattre • H : tenir une ligne au point visé" % [members.size(),{"auto":"AUTONOME","attack":"ASSAUT","hold":"TENIR"}.get(String(mode),"")]
