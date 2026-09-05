extends SceneTree

const ActorScript = preload("res://scripts/enemy_v2/enemy_actor_v2.gd")
const Catalog = preload("res://scripts/enemy_v2/hoplite_v2_catalog.gd")
const ShadowFactory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const OUTPUT := "res://docs/enemy_refactor/hoplite_v2_atlas_probe.png"
const BODY := "res://assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod0_22k_atlas.gltf"
const LODS: Array[String] = [
	"res://assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod1_8k_atlas.gltf",
	"res://assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod2_2k_atlas.gltf",
]

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111722")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d7e2f5")
	settings.ambient_light_energy = 1.0
	environment.environment = settings
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_energy = 1.8
	world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.25, 2.75)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.05, 0.0), Vector3.UP)
	camera.current = true
	world.add_child(camera)

	var definition := Catalog.definition(&"ngeneral").duplicate(true) as HopliteEnemyV2Definition
	definition.body_scene_path = BODY
	definition.body_lod_scene_paths = PackedStringArray(LODS)
	var actor := ActorScript.new() as HopliteEnemyActorV2
	_expect(actor.configure(definition), "atlased definition was rejected")
	actor.position.x = 0.55
	world.add_child(actor)
	var original := ShadowFactory.create(&"ngeneral") as HopliteEnemyActorV2
	original.position.x = -0.55
	world.add_child(original)
	for _frame: int in range(10):
		await process_frame
	_expect(actor.presentation != null and actor.presentation.skeleton != null, "atlased presentation did not install")
	if actor.presentation != null:
		_expect(actor.presentation.skeleton.get_bone_count() == 23, "atlasing changed the 23-bone rig")
		_expect(actor.presentation.lod_meshes.size() == 3, "atlased actor did not mount all three LODs")
		for mesh: MeshInstance3D in actor.presentation.lod_meshes:
			_expect(mesh.mesh != null and mesh.mesh.get_surface_count() == 2, "%s does not contain exactly opaque+cutout surfaces" % mesh.name)
	actor.equipment.set_weapon_visible(false)
	actor.equipment.set_shield_visible(false)
	original.equipment.set_weapon_visible(false)
	original.equipment.set_shield_visible(false)
	actor.play_semantic_animation(&"idle", 0.0)
	original.play_semantic_animation(&"idle", 0.0)
	for entry: Dictionary in [
		{"text": "ORIGINAL", "position": Vector3(-0.55, 2.15, 0.0)},
		{"text": "ATLAS TEST", "position": Vector3(0.55, 2.15, 0.0)},
	]:
		var label := Label3D.new()
		label.text = String(entry["text"])
		label.position = entry["position"]
		label.font_size = 22
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	for _frame: int in range(12):
		await process_frame
	_expect(actor.animation != null and actor.animation.current_semantic == &"idle", "shared donor no longer animates the atlased rig")
	await RenderingServer.frame_post_draw
	var save_error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	_expect(save_error == OK, "atlas visual capture failed: %s" % error_string(save_error))
	if failures.is_empty():
		print("HOPLITE_V2_ATLAS_PROBE PASS surfaces=2 lods=3 bones=23 animation=shared output=", OUTPUT)
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 ATLAS] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
