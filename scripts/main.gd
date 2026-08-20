extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const AthenianScript = preload("res://scripts/enemy/athenian_enemy.gd")

var player: HopliteUALNativePlayer
var debug_label: Label
var debug_panel: ColorRect
var debug_title: Label
var debug_help: Label
var debug_overlay_visible: bool = false
var debug_world_labels: Array[Label3D] = []

var health_bar_fill: ColorRect
var health_bar_label: Label
const HEALTH_BAR_WIDTH: float = 286.0

func _ready() -> void:
	_build_environment()
	_build_ui()
	player = PlayerScript.new() as HopliteUALNativePlayer
	player.name = "SpartanUALNativeTest"
	player.position = Vector3(0.0, 0.05, 12.0)
	add_child(player)
	_build_training_ground()

func _process(_delta: float) -> void:
	if player == null:
		return
	_update_player_health_bar()
	if debug_overlay_visible and debug_label != null:
		debug_label.text = player.debug_text

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_I:
			_set_debug_overlay_visible(not debug_overlay_visible)
			get_viewport().set_input_as_handled()

func _set_debug_overlay_visible(enabled: bool) -> void:
	debug_overlay_visible = enabled
	if debug_panel != null:
		debug_panel.visible = enabled
	if debug_title != null:
		debug_title.visible = enabled
	if debug_help != null:
		debug_help.visible = enabled
	if debug_label != null:
		debug_label.visible = enabled
	for label: Label3D in debug_world_labels:
		if is_instance_valid(label):
			label.visible = enabled
	if player != null:
		player.set_combat_debug_visible(enabled)

func _update_player_health_bar() -> void:
	if player == null or health_bar_fill == null or health_bar_label == null:
		return
	var maximum: float = maxf(player.max_health, 1.0)
	var ratio: float = clampf(player.health / maximum, 0.0, 1.0)
	health_bar_fill.size.x = HEALTH_BAR_WIDTH * ratio
	health_bar_label.text = "SPARTAN   %.0f / %.0f" % [player.health, player.max_health]

func _build_environment() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.31, 0.62)
	sky_mat.sky_horizon_color = Color(0.82, 0.67, 0.43)
	sky_mat.ground_bottom_color = Color(0.07, 0.045, 0.032)
	sky_mat.ground_horizon_color = Color(0.38, 0.24, 0.14)
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_environment.environment = environment
	add_child(world_environment)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -32, 0)
	sun.light_color = Color(1.0, 0.83, 0.66)
	sun.light_energy = 1.20
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

func _build_training_ground() -> void:
	# Big open lane so acceleration, dash and attack variants have room to breathe.
	_add_box("Ground", Vector3(110, 0.35, 110), Vector3(0, -0.18, 0), Color(0.30, 0.175, 0.10), true)

	# Long sprint / dash runway.
	_add_box("Runway", Vector3(8.0, 0.04, 54.0), Vector3(-18.0, 0.02, 1.0), Color(0.23, 0.13, 0.085), false)
	for z: int in range(-22, 28, 5):
		_add_marker(Vector3(-21.7, 0.03, float(z)), 0.45)
		_add_marker(Vector3(-14.3, 0.03, float(z)), 0.45)

	# Dedicated parkour lane: low vault -> medium mantle -> high mantle -> staggered walls.
	_add_box("Vault_075", Vector3(5.2, 0.75, 1.0), Vector3(-6.0, 0.375, 2.0), Color(0.55, 0.38, 0.22), true)
	_add_box("Vault_105", Vector3(5.2, 1.05, 1.0), Vector3(-6.0, 0.525, -4.0), Color(0.52, 0.35, 0.20), true)
	_add_box("Mantle_150", Vector3(5.6, 1.50, 1.1), Vector3(-6.0, 0.75, -11.0), Color(0.49, 0.32, 0.18), true)
	_add_box("Mantle_205", Vector3(5.8, 2.05, 1.1), Vector3(-6.0, 1.025, -19.0), Color(0.46, 0.29, 0.17), true)
	_add_box("Mantle_255", Vector3(6.0, 2.55, 1.2), Vector3(-6.0, 1.275, -28.0), Color(0.43, 0.27, 0.16), true)

	_add_box("StaggerWallA", Vector3(4.0, 1.25, 1.0), Vector3(5.0, 0.625, -8.0), Color(0.48, 0.31, 0.18), true)
	_add_box("StaggerWallB", Vector3(4.0, 1.85, 1.0), Vector3(10.0, 0.925, -13.0), Color(0.45, 0.28, 0.16), true)
	_add_box("StaggerWallC", Vector3(4.0, 2.35, 1.0), Vector3(15.0, 1.175, -18.0), Color(0.42, 0.26, 0.15), true)

	# Large combat pad with spaced targets for idle/run/dash/air attack testing.
	_add_box("CombatPad", Vector3(50, 0.08, 40), Vector3(21, 0.04, 14), Color(0.21, 0.115, 0.075), false)
	# V0.0.2: actual blue UAL1 Athenians with bone-following anatomy hitboxes.
	# Keep the first batch small while validating localization / sever thresholds.
	var enemy_positions: Array[Vector3] = [
		Vector3(10, 0.05, 8),
		Vector3(15, 0.05, 7),
		Vector3(20, 0.05, 8),
		Vector3(25, 0.05, 7),
		Vector3(18, 0.05, 15)
	]
	for p: Vector3 in enemy_positions:
		_add_athenian(p)
	_add_world_label("PRECISION TARGETS", Vector3(18.0, 2.75, 5.3))

	# V0.0.3: second five-man pack deliberately compressed to validate cleave,
	# spin, dash and slide attacks against several anatomy Areas at once.
	var tight_group_positions: Array[Vector3] = [
		Vector3(22.3, 0.05, 21.0),
		Vector3(23.45, 0.05, 21.0),
		Vector3(24.60, 0.05, 21.0),
		Vector3(22.90, 0.05, 22.05),
		Vector3(24.05, 0.05, 22.05)
	]
	for p: Vector3 in tight_group_positions:
		_add_athenian(p)
	_add_world_label("GROUP DAMAGE TEST", Vector3(23.45, 2.75, 19.3))

	# V0.0.5: live AI squad. Spawn the yellow miniboss first so the five blue
	# guards can receive a stable boss reference before entering the tree.
	var miniboss = _add_athenian(Vector3(40.0, 0.05, 12.0), true, true, null, 0)
	var ai_group_positions: Array[Vector3] = [
		Vector3(37.4, 0.05, 9.8),
		Vector3(40.0, 0.05, 9.0),
		Vector3(42.6, 0.05, 9.8),
		Vector3(38.3, 0.05, 14.7),
		Vector3(41.7, 0.05, 14.7)
	]
	for i: int in range(ai_group_positions.size()):
		_add_athenian(ai_group_positions[i], true, false, miniboss, i)
	_add_world_label("AI SQUAD + YELLOW MINIBOSS", Vector3(40.0, 3.0, 7.0))

	for i: int in range(10):
		_add_column(Vector3(-22.0 + i * 5.0, 0.0, -40.0))

func _add_world_label(text_value: String, position_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.modulate = Color(0.82, 0.90, 1.0)
	label.visible = debug_overlay_visible
	add_child(label)
	debug_world_labels.append(label)

func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color, collision_enabled: bool) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	add_child(body)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mi.material_override = mat
	body.add_child(mi)
	if collision_enabled:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.collision_layer = 1

func _add_marker(position: Vector3, radius: float) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = 0.025
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	marker.mesh = mesh
	marker.position = position
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.48, 0.19)
	mat.emission_enabled = true
	mat.emission = Color(0.18, 0.07, 0.01)
	marker.material_override = mat
	add_child(marker)

func _add_column(position: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.position = position
	add_child(root)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.57, 0.40)
	mat.roughness = 0.72
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.height = 4.6
	cylinder.top_radius = 0.30
	cylinder.bottom_radius = 0.38
	shaft.mesh = cylinder
	shaft.position.y = 2.3
	shaft.material_override = mat
	root.add_child(shaft)
	var top: MeshInstance3D = MeshInstance3D.new()
	var top_mesh: BoxMesh = BoxMesh.new()
	top_mesh.size = Vector3(1.15, 0.22, 0.8)
	top.mesh = top_mesh
	top.position.y = 4.62
	top.material_override = mat
	root.add_child(top)

func _add_athenian(position: Vector3, ai_enabled: bool = false, miniboss: bool = false, boss_ref: Node3D = null, guard_index: int = 0):
	var enemy = AthenianScript.new() as HopliteAthenianEnemy
	enemy.position = position
	enemy.name = ("AthenianMiniboss" if miniboss else "Athenian_%02d" % get_tree().get_nodes_in_group("enemy").size())
	enemy.ai_enabled = ai_enabled
	enemy.is_miniboss = miniboss
	enemy.ai_player = player
	enemy.ai_miniboss = boss_ref
	enemy.ai_guard_index = guard_index
	if miniboss:
		enemy.base_color = Color(0.90, 0.62, 0.035)
		enemy.max_health = 460.0
		enemy.ai_attack_damage = 34.0
	add_child(enemy)
	return enemy

func _add_dummy(position: Vector3) -> void:
	var root: Node3D = Node3D.new()
	root.position = position
	add_child(root)
	var blue: StandardMaterial3D = StandardMaterial3D.new()
	blue.albedo_color = Color(0.035, 0.20, 0.68)
	blue.roughness = 0.58
	var torso: MeshInstance3D = MeshInstance3D.new()
	var torso_mesh: CylinderMesh = CylinderMesh.new()
	torso_mesh.height = 1.45
	torso_mesh.top_radius = 0.31
	torso_mesh.bottom_radius = 0.34
	torso.mesh = torso_mesh
	torso.position.y = 0.82
	torso.material_override = blue
	root.add_child(torso)
	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position.y = 1.72
	head.material_override = blue
	root.add_child(head)

	# Non-blocking combat sensor so slide slashes can be tested without turning
	# the training dummies into walls for the CharacterBody.
	var hit_area: Area3D = Area3D.new()
	hit_area.name = "SlideSlashTarget"
	hit_area.collision_layer = 4
	hit_area.collision_mask = 0
	root.add_child(hit_area)
	hit_area.add_to_group("damageable")
	var hit_shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 1.95
	hit_shape.shape = capsule
	hit_shape.position.y = 0.98
	hit_area.add_child(hit_shape)

func _on_slide_slash_contact(target: Node) -> void:
	if target == null:
		return
	var dummy_root: Node3D = target.get_parent() as Node3D
	if dummy_root == null:
		return
	# Lab feedback only. Real enemies can implement on_slide_slash(attacker)
	# or connect to the player's slide_slash_contact signal for their damage logic.
	var tween: Tween = dummy_root.create_tween()
	tween.tween_property(dummy_root, "scale", Vector3(1.16, 0.82, 1.16), 0.045)
	tween.tween_property(dummy_root, "scale", Vector3.ONE, 0.13)

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	# Clean game HUD: this is the only UI visible by default.
	var health_background: ColorRect = ColorRect.new()
	health_background.position = Vector2(18, 18)
	health_background.size = Vector2(302, 34)
	health_background.color = Color(0.025, 0.02, 0.025, 0.90)
	layer.add_child(health_background)

	var health_track: ColorRect = ColorRect.new()
	health_track.position = Vector2(8, 8)
	health_track.size = Vector2(HEALTH_BAR_WIDTH, 18)
	health_track.color = Color(0.16, 0.045, 0.045, 0.96)
	health_background.add_child(health_track)

	health_bar_fill = ColorRect.new()
	health_bar_fill.position = Vector2(8, 8)
	health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, 18)
	health_bar_fill.color = Color(0.72, 0.055, 0.035, 1.0)
	health_background.add_child(health_bar_fill)

	health_bar_label = Label.new()
	health_bar_label.position = Vector2(12, 5)
	health_bar_label.size = Vector2(278, 24)
	health_bar_label.text = "SPARTAN"
	health_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_bar_label.add_theme_font_size_override("font_size", 14)
	health_background.add_child(health_bar_label)

	# Laboratory diagnostics. Hidden by default; I reveals this entire layer AND
	# enables the former H anatomy/sword debug at the same time.
	debug_panel = ColorRect.new()
	debug_panel.position = Vector2(14, 64)
	debug_panel.size = Vector2(1235, 214)
	debug_panel.color = Color(0.025, 0.025, 0.035, 0.86)
	debug_panel.visible = debug_overlay_visible
	layer.add_child(debug_panel)

	debug_title = Label.new()
	debug_title.position = Vector2(28, 74)
	debug_title.text = "PROJECT HOPLITE — V0.0.9 CLEAN HUD / I DIAGNOSTICS"
	debug_title.add_theme_font_size_override("font_size", 23)
	debug_title.visible = debug_overlay_visible
	layer.add_child(debug_title)

	debug_help = Label.new()
	debug_help.position = Vector2(28, 106)
	debug_help.text = "ZQSD/WASD = mouvement • SPACE x2 = NinjaJump • SPACE obstacle = vault/mantle • SHIFT = dash • CTRL = slide\nLMB/J = light rapide • RMB/K = heavy • A/molette = 360 • I = diagnostics complets + hitboxes/lame • regarder haut/bas = incline les coups\nIA: 1 jambe = marche lente • 2 jambes = crawl • bras droit = désarmé • mort = Death01"
	debug_help.add_theme_font_size_override("font_size", 14)
	debug_help.visible = debug_overlay_visible
	layer.add_child(debug_help)

	debug_label = Label.new()
	debug_label.position = Vector2(28, 186)
	debug_label.text = "Starting UAL motion/combat lab..."
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_label.visible = debug_overlay_visible
	layer.add_child(debug_label)
