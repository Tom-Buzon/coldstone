extends Node

## Two isolated masks render the player and attack-warning enemies with distinct
## colors. Each pass combines the animated body and equipped meshes into one
## silhouette whose outside edge remains visible independently of world depth.
const OUTLINE_SHADER = preload("res://scripts/camera/player_occlusion_outline.gdshader")
const ATTACK_OUTLINE_GROUP := &"enemy_attack_outline_subject"
const DEFAULT_COLOR := Color(0.0, 0.78622156, 0.5315931, 1.0)
const DEFAULT_ATTACK_COLOR := Color(1.0, 0.141, 0.0, 1.0)

var fader: Node
var color := DEFAULT_COLOR
var attack_color := DEFAULT_ATTACK_COLOR
var opacity := 0.68

var mask_viewport: SubViewport
var mask_camera: Camera3D
var overlay: TextureRect
var attack_mask_viewport: SubViewport
var attack_mask_camera: Camera3D
var attack_overlay: TextureRect
var mask_material: StandardMaterial3D
var copies: Dictionary = {}
var attack_copies: Dictionary = {}


func _ready() -> void:
	mask_material = StandardMaterial3D.new()
	mask_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask_material.albedo_color = Color.WHITE
	mask_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	mask_viewport = _create_mask_viewport()
	mask_camera = _create_mask_camera(mask_viewport)
	attack_mask_viewport = _create_mask_viewport()
	attack_mask_camera = _create_mask_camera(attack_mask_viewport)

	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)
	overlay = _create_overlay(mask_viewport, canvas)
	attack_overlay = _create_overlay(attack_mask_viewport, canvas)
	RenderingServer.frame_pre_draw.connect(_update_mask)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_update_mask):
		RenderingServer.frame_pre_draw.disconnect(_update_mask)


func _create_mask_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.add_to_group(&"camera_occlusion_ignore")
	add_child(viewport)
	return viewport


func _create_mask_camera(viewport: SubViewport) -> Camera3D:
	var result := Camera3D.new()
	viewport.add_child(result)
	result.current = true
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	result.environment = environment
	return result


func _create_overlay(viewport: SubViewport, canvas: CanvasLayer) -> TextureRect:
	var result := TextureRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.texture = viewport.get_texture()
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	result.material = material
	canvas.add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.hide()
	return result


func _update_mask() -> void:
	var valid_fader: bool = is_instance_valid(fader) and is_instance_valid(fader.camera) and is_instance_valid(fader.target)
	if not valid_fader:
		_deactivate_all_passes()
		return
	var camera: Camera3D = fader.camera
	if not camera.is_current() or opacity <= 0.0:
		_deactivate_all_passes()
		return

	var player_active: bool = fader.enabled and fader.get_active_occluder_count() > 0
	var attack_subjects := _active_attack_subjects()
	_update_player_pass(camera, player_active)
	_update_attack_pass(camera, attack_subjects)


func _update_player_pass(camera: Camera3D, active: bool) -> void:
	_set_pass_active(mask_viewport, overlay, active)
	var seen: Dictionary = {}
	if active:
		_sync_mask_camera(mask_viewport, mask_camera, camera)
		_collect_subject_meshes(fader.target, camera, seen, copies, mask_viewport)
		var material := overlay.material as ShaderMaterial
		material.set_shader_parameter(&"outline_color", Color(color, opacity))
	_remove_stale_copies(seen, copies)


func _update_attack_pass(camera: Camera3D, subjects: Array[Node3D]) -> void:
	var active := not subjects.is_empty()
	_set_pass_active(attack_mask_viewport, attack_overlay, active)
	var seen: Dictionary = {}
	if active:
		_sync_mask_camera(attack_mask_viewport, attack_mask_camera, camera)
		for subject: Node3D in subjects:
			_collect_subject_meshes(subject, camera, seen, attack_copies, attack_mask_viewport)
		var material := attack_overlay.material as ShaderMaterial
		material.set_shader_parameter(&"outline_color", Color(attack_color, opacity))
	_remove_stale_copies(seen, attack_copies)


func _deactivate_all_passes() -> void:
	_set_pass_active(mask_viewport, overlay, false)
	_set_pass_active(attack_mask_viewport, attack_overlay, false)
	_remove_stale_copies({}, copies)
	_remove_stale_copies({}, attack_copies)


func _set_pass_active(viewport: SubViewport, pass_overlay: TextureRect, active: bool) -> void:
	if viewport == null or pass_overlay == null:
		return
	pass_overlay.visible = active
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _sync_mask_camera(viewport: SubViewport, pass_camera: Camera3D, source: Camera3D) -> void:
	viewport.size = Vector2i(source.get_viewport().get_visible_rect().size)
	pass_camera.global_transform = source.get_camera_transform()
	pass_camera.projection = source.projection
	pass_camera.fov = source.fov
	pass_camera.size = source.size
	pass_camera.near = source.near
	pass_camera.far = source.far
	pass_camera.keep_aspect = source.keep_aspect
	pass_camera.frustum_offset = source.frustum_offset


func _active_attack_subjects() -> Array[Node3D]:
	var subjects: Array[Node3D] = []
	if get_tree() == null:
		return subjects
	for node: Node in get_tree().get_nodes_in_group(ATTACK_OUTLINE_GROUP):
		if node is Node3D and is_instance_valid(node) and node.is_inside_tree() and node.is_visible_in_tree():
			subjects.append(node as Node3D)
	return subjects


func _collect_subject_meshes(subject: Node3D, camera: Camera3D, seen: Dictionary, destination_copies: Dictionary, destination_viewport: SubViewport) -> void:
	for node: Node in subject.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		if is_ancestor_of(source) or source.mesh == null or not source.is_visible_in_tree():
			continue
		# Immediate meshes are combat trails/debug drawings, not equipment.
		if source.mesh is ImmediateMesh or (source.layers & camera.cull_mask) == 0:
			continue
		if source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		var id := source.get_instance_id()
		seen[id] = true
		var copy := destination_copies.get(id) as MeshInstance3D
		if copy == null:
			copy = MeshInstance3D.new()
			copy.mesh = source.mesh
			copy.skin = source.skin
			_install_mask_materials(copy, source)
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			destination_viewport.add_child(copy)
			var skeleton := source.get_node_or_null(source.skeleton) as Skeleton3D
			if skeleton != null:
				copy.skeleton = skeleton.get_path()
			destination_copies[id] = copy
		copy.global_transform = source.global_transform
		if copy.mesh != source.mesh:
			copy.mesh = source.mesh
			_install_mask_materials(copy, source)
		for index: int in source.get_blend_shape_count():
			copy.set_blend_shape_value(index, source.get_blend_shape_value(index))


func _remove_stale_copies(seen: Dictionary, destination_copies: Dictionary) -> void:
	for id: Variant in destination_copies.keys():
		if not seen.has(id):
			(destination_copies[id] as MeshInstance3D).queue_free()
			destination_copies.erase(id)


func _install_mask_materials(copy: MeshInstance3D, source: MeshInstance3D) -> void:
	# Preserve cutout textures (hair, straps, etc.) instead of outlining the
	# invisible rectangles around them. The mask uses alpha, not RGB.
	for index: int in source.mesh.get_surface_count():
		var authored := source.get_active_material(index) as BaseMaterial3D
		if authored == null or authored.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			copy.set_surface_override_material(index, mask_material)
			continue
		var cutout := authored.duplicate() as BaseMaterial3D
		cutout.next_pass = null
		cutout.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cutout.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		cutout.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		copy.set_surface_override_material(index, cutout)
