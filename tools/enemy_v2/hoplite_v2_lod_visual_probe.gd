extends SceneTree

const OUTPUT := "res://docs/enemy_refactor/hoplite_v2_lod_comparison.png"
const LIBRARY_PATH := "res://assets/animations/enemy_v2/hoplite/hoplite_v2_animation_library.res"
const LIBRARY_NAME: StringName = &"hoplite_v2"
const CLIP: StringName = &"hoplite_v2/spear_thrust"
const LODS := [
	{"label": "45K SOURCE", "path": "res://assets/characters/enemy_v2/hoplite/hoplite_body_v2.gltf"},
	{"label": "22K LOD0", "path": "res://assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod0_22k.gltf"},
	{"label": "8K LOD1", "path": "res://assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod1_8k.gltf"},
	{"label": "2.5K LOD2", "path": "res://assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod2_2k.gltf"},
]


func _initialize() -> void:
	print("HOPLITE_V2_LOD_VISUAL_PROBE initialize")
	call_deferred(&"_run")


func _run() -> void:
	print("HOPLITE_V2_LOD_VISUAL_PROBE setup")
	root.size = Vector2i(1600, 760)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	_add_environment(world)
	var library := load(LIBRARY_PATH) as AnimationLibrary
	if library == null:
		_fail("animation library is missing")
		return
	for index: int in range(LODS.size()):
		print("HOPLITE_V2_LOD_VISUAL_PROBE loading=", LODS[index].path)
		var packed := load(String(LODS[index].path)) as PackedScene
		if packed == null:
			_fail("LOD scene is missing: %s" % LODS[index].path)
			return
		var model := packed.instantiate() as Node3D
		if model == null:
			_fail("LOD root is not Node3D: %s" % LODS[index].path)
			return
		model.position.x = (float(index) - 1.5) * 1.35
		world.add_child(model)
		var skeleton := _find_skeleton(model)
		if skeleton == null or skeleton.get_bone_count() != 23:
			_fail("LOD does not expose the canonical 23-bone skeleton: %s" % LODS[index].path)
			return
		var player := AnimationPlayer.new()
		player.name = "LODProbeAnimationPlayer"
		skeleton.add_child(player)
		if player.add_animation_library(LIBRARY_NAME, library) != OK or not player.has_animation(CLIP):
			_fail("LOD could not bind the shared donor: %s" % LODS[index].path)
			return
		player.play(CLIP)
		var label := Label3D.new()
		label.text = String(LODS[index].label)
		label.position = model.position + Vector3(0.0, 2.25, 0.0)
		label.font_size = 28
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	print("HOPLITE_V2_LOD_VISUAL_PROBE models_ready")
	for _frame: int in range(24):
		await process_frame
	print("HOPLITE_V2_LOD_VISUAL_PROBE frames_ready")
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if save_error != OK:
		_fail("could not save comparison: %s" % error_string(save_error))
		return
	print("HOPLITE_V2_LOD_VISUAL_PROBE PASS output=", OUTPUT)
	quit(0)


func _add_environment(world: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111722")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c9d8f4")
	settings.ambient_light_energy = 0.9
	environment.environment = settings
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_energy = 1.8
	key.shadow_enabled = true
	world.add_child(key)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.2, 6.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.05, 0.0), Vector3.UP)
	camera.current = true
	world.add_child(camera)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error("HOPLITE_V2_LOD_VISUAL_PROBE " + message)
	quit(1)
