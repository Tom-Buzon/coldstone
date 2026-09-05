extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const AEGIS_FANG: HopliteEquipmentItemData = preload("res://data/equipment/weapons/aegis_fang.tres")
const TITAN_AEGIS: HopliteEquipmentItemData = preload("res://data/equipment/shields/titan_aegis.tres")
const OUTPUT := "res://docs/hero_arsenal_player_probe.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1000, 760)
	var world := Node3D.new()
	world.name = "PlayerHeroArsenalVisualProbe"
	root.add_child(world)
	current_scene = world

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.026, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.55, 0.82)
	env.ambient_light_energy = 0.85
	environment.environment = env
	world.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color(0.74, 0.84, 1.0)
	key.light_energy = 1.65
	key.shadow_enabled = true
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28.0, 145.0, 0.0)
	rim.light_color = Color(1.0, 0.32, 0.08)
	rim.light_energy = 1.15
	world.add_child(rim)

	var floor_mesh := MeshInstance3D.new()
	var floor := PlaneMesh.new()
	floor.size = Vector2(8.0, 8.0)
	floor_mesh.mesh = floor
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.025, 0.035, 0.065)
	floor_material.metallic = 0.25
	floor_material.roughness = 0.34
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)

	var player := PlayerScript.new() as HopliteUALNativePlayer
	world.add_child(player)
	for _frame: int in range(12):
		await process_frame
		await physics_frame
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE), "Could not load base player")
	await process_frame
	assert(player.equip_item(AEGIS_FANG), "Could not equip Aegis Fang")
	assert(player.equip_item(TITAN_AEGIS), "Could not equip Titan Aegis")
	for _frame: int in range(8):
		await process_frame
		await physics_frame
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3.ZERO
	for node: Node in player.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	if player.animation_driver != null:
		player.animation_driver.set_locomotion(0.0)

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 40.0
	camera.look_at_from_position(Vector3(2.45, 1.50, -3.25), Vector3(0.0, 1.0, 0.0), Vector3.UP)
	if DisplayServer.get_name() == "headless":
		print("[PLAYER HERO ARSENAL VISUAL PROBE] SKIP capture — headless display has no render texture")
		quit(0)
		return
	for _frame: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	assert(error == OK, "Could not save hero arsenal player probe: %s" % error_string(error))
	print("[PLAYER HERO ARSENAL VISUAL PROBE] PASS — ", OUTPUT)
	quit(0)
