extends RefCounted
class_name HopliteProceduralMapGenerator

const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")
const BrazierLightScript = preload("res://scripts/campaign/campaign_brazier_light.gd")

var rng := RandomNumberGenerator.new()
var zone_root: Node3D
var active_generation_seed := 0

func generate(parent: Node3D, zone_id: StringName, generation_seed: int) -> Dictionary:
	rng.seed = generation_seed
	active_generation_seed = generation_seed
	zone_root = Node3D.new()
	zone_root.name = "Procedural_%s_%d" % [String(zone_id), generation_seed]
	parent.add_child(zone_root)
	match zone_id:
		&"walls":
			return _generate_walls()
		&"city":
			return _generate_city()
		&"dungeon":
			return _generate_dungeon()
		_:
			return _generate_walls()

func _generate_walls() -> Dictionary:
	var layout_variant := posmod(active_generation_seed, 3)
	# The approach is an outdoor battlefield, not an indoor tiled room. A dusty
	# road carries the combat while scorched and overgrown patches break repetition.
	_add_box("AssaultField", Vector3(94.0, 0.34, 92.0), Vector3(0.0, -0.17, 0.0), &"dirt_path", true)
	_add_ground_patch("ScorchedWest", Vector2(27.0, 22.0), Vector3(-31.0, 0.012, 19.0), &"scorched_ground", -12.0)
	_add_ground_patch("ScorchedEast", Vector2(22.0, 18.0), Vector3(31.0, 0.014, -1.0), &"scorched_ground", 17.0)
	_add_ground_patch("WeedsRear", Vector2(36.0, 14.0), Vector3(25.0, 0.016, 36.0), &"cracked_weeds", -6.0)
	_add_box("WestCliff", Vector3(3.0, 5.0, 92.0), Vector3(-47.0, 2.5, 0.0), &"rough_stone", true)
	_add_box("EastCliff", Vector3(3.0, 5.0, 92.0), Vector3(47.0, 2.5, 0.0), &"rough_stone", true)
	_add_box("RearBoundary", Vector3(94.0, 5.0, 3.0), Vector3(0.0, 2.5, -46.0), &"rough_stone", true)
	_add_box("ForwardEarthwork", Vector3(94.0, 2.4, 3.0), Vector3(0.0, 1.2, 46.0), &"rough_stone", true)
	_add_safety_perimeter(91.0, 89.0, 7.0)

	var gate_z := -18.0 + rng.randf_range(-2.5, 2.5)
	_add_box("FortressWallL", Vector3(39.0, 8.5, 3.0), Vector3(-27.5, 4.25, gate_z), &"fortress", true)
	_add_box("FortressWallR", Vector3(39.0, 8.5, 3.0), Vector3(27.5, 4.25, gate_z), &"fortress", true)
	_add_box("GateLintel", Vector3(16.0, 2.0, 3.4), Vector3(0.0, 7.5, gate_z), &"marble", true)
	for side: float in [-1.0, 1.0]:
		_add_tower(Vector3(side * 43.0, 0.0, gate_z), 5.0)
	for x: float in [-38.0, -31.0, -24.0, -17.0, 17.0, 24.0, 31.0, 38.0]:
		_add_box("Merlon_%d" % int(x), Vector3(3.2, 1.35, 3.4), Vector3(x, 9.15, gate_z), &"marble", true)

	# Three macro-layouts substantially change the approach instead of merely
	# nudging isolated props while preserving the same silhouette every run.
	var batteries: Array[Dictionary] = []
	match layout_variant:
		0:
			batteries = [
				{"position": Vector3(-31.0, 0.0, 17.0), "rotation": 8.0},
				{"position": Vector3(31.0, 0.0, 13.0), "rotation": -8.0},
				{"position": Vector3(-36.0, 0.0, 31.0), "rotation": 12.0}
			]
		1:
			batteries = [
				{"position": Vector3(-34.0, 0.0, 5.0), "rotation": 18.0},
				{"position": Vector3(25.0, 0.0, 27.0), "rotation": -12.0}
			]
		_:
			batteries = [
				{"position": Vector3(-27.0, 0.0, 31.0), "rotation": 7.0},
				{"position": Vector3(0.0, 0.0, 20.0), "rotation": 0.0},
				{"position": Vector3(29.0, 0.0, 31.0), "rotation": -7.0}
			]
	for battery: Dictionary in batteries:
		_add_prop(&"catapult", battery.position, float(battery.rotation), false)
		_add_supply_cluster(battery.position + Vector3(4.4, 0.0, 2.8), float(battery.rotation))

	# obstacle.glb is a modular spiked barricade: rows create a defensive line,
	# while separated segments retain an obvious breach for player and crowd flow.
	match layout_variant:
		0:
			_add_barricade_line(Vector3(-14.0, 0.0, 4.0), 6, -7.0)
			_add_barricade_line(Vector3(14.0, 0.0, 4.0), 6, 7.0)
			_add_barricade_line(Vector3(-24.0, 0.0, 27.0), 4, 12.0)
			_add_barricade_line(Vector3(25.0, 0.0, 24.0), 4, -14.0)
		1:
			_add_barricade_line(Vector3(-20.0, 0.0, -1.0), 7, -24.0)
			_add_barricade_line(Vector3(18.0, 0.0, 12.0), 7, 22.0)
			_add_barricade_line(Vector3(-8.0, 0.0, 31.0), 5, 4.0)
		_:
			_add_barricade_line(Vector3(-19.0, 0.0, 9.0), 5, 0.0)
			_add_barricade_line(Vector3(19.0, 0.0, 9.0), 5, 0.0)
			_add_barricade_line(Vector3(-28.0, 0.0, 23.0), 4, 90.0)
			_add_barricade_line(Vector3(28.0, 0.0, 23.0), 4, 90.0)
	_add_prop(&"big_rock", Vector3(-40.0, 0.0, -5.0 + float(layout_variant) * 8.0), -18.0, false, 4.8)
	_add_prop(&"big_rock", Vector3(39.0, 0.0, 32.0 - float(layout_variant) * 10.0), 38.0, true, 3.8)
	for index: int in range(7):
		_add_prop(&"cypress_tree", Vector3(-43.0, 0.0, -13.0 + float(index) * 8.0), rng.randf_range(-8.0, 8.0), true)
	_add_brazier(Vector3(-6.0, 0.0, gate_z + 2.0), 0.0)
	_add_brazier(Vector3(6.0, 0.0, gate_z + 2.0), 0.0)
	for light_z: float in [10.0, 34.0]:
		_add_brazier(Vector3(-9.0, 0.0, light_z), 0.0)
		_add_brazier(Vector3(9.0, 0.0, light_z), 0.0)
	_add_banner_line(gate_z + 1.65, Color(0.07, 0.20, 0.58))

	return {
		"zone_root": zone_root,
		"player_spawn": Vector3(0.0, 1.10, 37.0),
		"spawn_points": _ring_points(Vector3(0.0, 0.05, 4.0), Vector2(35.0, 29.0), 16, 0.22),
		"boss_spawn": Vector3(0.0, 0.05, gate_z - 10.0),
		"safe_bounds": Rect2(-44.5, -43.5, 89.0, 87.0),
		"variant": layout_variant,
		"variant_name": ["DOUBLE BRECHE", "LIGNES OBLIQUES", "COULOIR DE MORT"][layout_variant],
		"title": "ACTE I — PRISE DES MURAILLES",
		"objective": "Brisez les lignes ennemies et forcez la porte."
	}

func _generate_city() -> Dictionary:
	var layout_variant := posmod(active_generation_seed + 1, 3)
	_add_box("CityGround", Vector3(98.0, 0.34, 106.0), Vector3(0.0, -0.17, 0.0), &"pavers", true)
	_add_ground_patch("AbandonedGardenW", Vector2(18.0, 27.0), Vector3(-38.0, 0.012, 29.0), &"cracked_weeds", 0.0)
	_add_ground_patch("AbandonedGardenE", Vector2(17.0, 22.0), Vector3(39.0, 0.014, -28.0), &"cracked_weeds", 0.0)
	_add_box("CityBoundaryW", Vector3(3.0, 7.5, 106.0), Vector3(-49.0, 3.75, 0.0), &"fortress", true)
	_add_box("CityBoundaryE", Vector3(3.0, 7.5, 106.0), Vector3(49.0, 3.75, 0.0), &"fortress", true)
	_add_box("CityBack", Vector3(98.0, 7.5, 3.0), Vector3(0.0, 3.75, -53.0), &"fortress", true)
	_add_box("CityFront", Vector3(98.0, 4.0, 3.0), Vector3(0.0, 2.0, 53.0), &"fortress", true)
	_add_safety_perimeter(95.0, 103.0, 9.0)
	# Every decorative floor gets a unique elevation. The road and agora used to
	# share their top plane, producing z-fighting where their textures overlapped.
	_add_box("ProcessionalRoad", Vector3(19.0, 0.05, 102.0), Vector3(0.0, 0.025, 0.0), &"sandstone_floor", false)

	var plaza_anchors: Array[float] = [-14.0, 0.0, 14.0]
	var plaza_z := plaza_anchors[layout_variant] + rng.randf_range(-2.5, 2.5)
	var block_index := 0
	var district_rows: Array[float] = [39.0, 24.0, 9.0, -7.0, -23.0, -39.0]
	for row: int in range(district_rows.size()):
		var z := district_rows[row] + rng.randf_range(-2.8, 2.8)
		if absf(z - plaza_z) < 12.0:
			continue
		for side: float in [-1.0, 1.0]:
			# One missing plot in variants 1/2 creates a readable market courtyard
			# rather than the same perfectly mirrored street on every generation.
			if layout_variant > 0 and row == (1 if layout_variant == 1 else 4) and side == (-1.0 if layout_variant == 1 else 1.0):
				continue
			var width := rng.randf_range(14.0, 22.0)
			var depth := rng.randf_range(10.0, 16.0)
			var height := rng.randf_range(4.0, 7.0)
			var x := side * (26.5 + rng.randf_range(-4.0, 4.0))
			_add_city_house(block_index, Vector3(x, 0.0, z), Vector3(width, height, depth), side, row >= 4)
			block_index += 1

	_add_box("Agora", Vector3(42.0, 0.06, 28.0), Vector3(0.0, 0.085, plaza_z), &"white_marble_floor", false)
	_add_prop(&"fountain", Vector3(0.0, 0.0, plaza_z), rng.randf_range(0.0, 360.0), false)
	_add_prop(&"athena_statue", Vector3(-17.0, 0.0, plaza_z - 8.0), 20.0, false)
	_add_prop(&"athena_statue", Vector3(17.0, 0.0, plaza_z - 8.0), -20.0, true)
	_add_prop(&"temple", Vector3(0.0, 0.0, -48.0), 180.0, true, 10.5, false)
	_add_prop(&"lion_statue", Vector3(-7.0, 0.0, -39.0), 10.0, true)
	_add_prop(&"lion_statue", Vector3(7.0, 0.0, -39.0), -10.0, true)
	for z: float in [40.0, plaza_z + 17.0, plaza_z - 17.0, -39.0]:
		_add_prop(&"cypress_tree", Vector3(-12.0, 0.0, z), rng.randf_range(-6.0, 6.0), true)
		_add_prop(&"cypress_tree", Vector3(12.0, 0.0, z), rng.randf_range(-6.0, 6.0), true)
	for cluster: Dictionary in [
		{"position": Vector3(-20.0, 0.0, 31.0), "rotation": 18.0},
		{"position": Vector3(21.0, 0.0, 17.0), "rotation": -24.0},
		{"position": Vector3(-21.0, 0.0, -23.0), "rotation": 8.0},
		{"position": Vector3(22.0, 0.0, -39.0), "rotation": -14.0}
	]:
		_add_supply_cluster(cluster.position, float(cluster.rotation))
	_add_barricade_line(Vector3(-15.5, 0.0, 12.0), 4, 0.0)
	_add_barricade_line(Vector3(15.5, 0.0, 12.0), 4, 0.0)
	for light_z: float in [plaza_z - 10.0, plaza_z + 10.0, 38.0, -38.0]:
		_add_brazier(Vector3(-7.0, 0.0, light_z), 0.0)
		_add_brazier(Vector3(7.0, 0.0, light_z), 0.0)
	_add_wall_panel(Vector3(-14.0, 3.2, -51.35), Vector2(8.0, 4.0), 0.0, &"mural")
	_add_wall_panel(Vector3(14.0, 3.2, -51.35), Vector2(8.0, 4.0), 0.0, &"mural")
	_add_banner_line(-49.8, Color(0.47, 0.06, 0.035))

	return {
		"zone_root": zone_root,
		"player_spawn": Vector3(0.0, 1.10, 45.0),
		"spawn_points": _city_spawn_points(plaza_z),
		"boss_spawn": Vector3(0.0, 0.05, -39.0),
		"safe_bounds": Rect2(-47.0, -51.0, 94.0, 102.0),
		"variant": layout_variant,
		"variant_name": ["AGORA BASSE", "AGORA CENTRALE", "AGORA HAUTE"][layout_variant],
		"title": "ACTE II — PRISE DE LA VILLE",
		"objective": "Traversez les quartiers et écrasez les contre-attaques."
	}

func _generate_dungeon() -> Dictionary:
	var layout_variant := posmod(active_generation_seed + 2, 3)
	_add_box("DungeonFloor", Vector3(68.0, 0.40, 82.0), Vector3(0.0, -0.20, 0.0), &"rough_stone", true)
	_add_ground_patch("CryptGravel", Vector2(26.0, 29.0), Vector3(0.0, 0.012, 14.0), &"bone_gravel", 0.0)
	_add_box("DungeonWallW", Vector3(3.0, 8.0, 82.0), Vector3(-34.0, 4.0, 0.0), &"rough_stone", true)
	_add_box("DungeonWallE", Vector3(3.0, 8.0, 82.0), Vector3(34.0, 4.0, 0.0), &"rough_stone", true)
	_add_box("DungeonBack", Vector3(68.0, 8.0, 3.0), Vector3(0.0, 4.0, -41.0), &"rough_stone", true)
	_add_box("DungeonEntry", Vector3(68.0, 8.0, 3.0), Vector3(0.0, 4.0, 41.0), &"rough_stone", true)
	_add_safety_perimeter(65.0, 79.0, 9.0)
	_add_box("BossDais", Vector3(24.0, 0.9, 16.0), Vector3(0.0, 0.45, -24.0), &"white_marble_floor", true)
	var column_positions: Array[Vector3] = []
	match layout_variant:
		0:
			for x: float in [-24.0, -12.0, 12.0, 24.0]:
				for z: float in [-14.0, 10.0, 28.0]:
					column_positions.append(Vector3(x, 0.0, z))
		1:
			for x: float in [-21.0, -7.0, 7.0, 21.0]:
				for z: float in [-8.0, 14.0, 31.0]:
					column_positions.append(Vector3(x, 0.0, z))
		_:
			column_positions = [
				Vector3(-23.0, 0.0, 30.0), Vector3(23.0, 0.0, 30.0),
				Vector3(-15.0, 0.0, 17.0), Vector3(15.0, 0.0, 17.0),
				Vector3(-23.0, 0.0, 4.0), Vector3(23.0, 0.0, 4.0),
				Vector3(-15.0, 0.0, -9.0), Vector3(15.0, 0.0, -9.0)
			]
	for column_position: Vector3 in column_positions:
		_add_column(column_position)
	for side: float in [-1.0, 1.0]:
		for row: int in range(7):
			var tomb_x := 25.0
			if layout_variant == 1:
				tomb_x = 22.0 + float(row % 2) * 4.0
			elif layout_variant == 2 and row in [2, 4]:
				tomb_x = 19.0
			_add_prop(&"tomb", Vector3(side * tomb_x, 0.0, 31.0 - float(row) * 9.0), -90.0 * side, true)
	_add_prop(&"temple", Vector3(0.0, 0.0, -38.0), 180.0, true, 10.8, false)
	# The source faces +Z. Zero yaw keeps the magistrate looking down the nave
	# toward the arriving player instead of presenting the back of the throne.
	_add_prop(&"magistrate_statue", Vector3(0.0, 0.9, -31.0), 0.0, false)
	_add_prop(&"lion_statue", Vector3(-8.5, 0.9, -18.5), 22.0, true)
	_add_prop(&"lion_statue", Vector3(8.5, 0.9, -18.5), -22.0, true)
	for z: float in [-30.0, -15.0, 1.0, 17.0, 32.0]:
		_add_brazier(Vector3(-29.5, 0.0, z), 90.0)
		_add_brazier(Vector3(29.5, 0.0, z), -90.0)
	for z: float in [-32.0, -18.0, -4.0, 11.0, 26.0, 36.0]:
		_add_wall_torch(Vector3(-32.15, 3.45, z), 90.0)
		_add_wall_torch(Vector3(32.15, 3.45, z), -90.0)
	for z: float in [-24.0, -3.0, 19.0]:
		_add_wall_panel(Vector3(-32.4, 3.7, z), Vector2(7.5, 4.6), 90.0, &"ornate_stone_wall")
		_add_wall_panel(Vector3(32.4, 3.7, z), Vector2(7.5, 4.6), -90.0, &"ornate_stone_wall")
	_add_wall_panel(Vector3(-13.0, 4.0, -39.35), Vector2(9.0, 5.0), 0.0, &"mural")
	_add_wall_panel(Vector3(13.0, 4.0, -39.35), Vector2(9.0, 5.0), 0.0, &"mural")

	return {
		"zone_root": zone_root,
		"player_spawn": Vector3(0.0, 1.35, 33.0),
		"spawn_points": _dungeon_spawn_points(),
		# Dedicated clear lanes beside the entry. The act-III surge uses these two
		# points instead of guessing corners that may contain a tomb or a column.
		"entry_reinforcement_points": [Vector3(-18.0, 0.05, 34.0), Vector3(18.0, 0.05, 34.0)],
		"boss_spawn": Vector3(0.0, 0.95, -22.0),
		"safe_bounds": Rect2(-32.0, -39.0, 64.0, 78.0),
		"variant": layout_variant,
		"variant_name": ["COLONNADE ROYALE", "NEF DES TOMBES", "CRYPTE BRISEE"][layout_variant],
		"title": "ACTE III — PRISE DU DONJON",
		"objective": "Descendez seul. Trouvez NFullArmor. Tuez-le."
	}

func _ring_points(center: Vector3, radii: Vector2, count: int, phase: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index: int in range(count):
		var angle := phase + TAU * float(index) / float(count)
		var radius_scale := rng.randf_range(0.78, 1.0)
		points.append(center + Vector3(cos(angle) * radii.x * radius_scale, 0.0, sin(angle) * radii.y * radius_scale))
	return points

func _city_spawn_points(plaza_z: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for z: float in [39.0, 25.0, 11.0, -12.0, -27.0, -42.0]:
		points.append(Vector3(-7.0, 0.05, z))
		points.append(Vector3(7.0, 0.05, z))
	for x: float in [-18.0, -12.0, 12.0, 18.0]:
		points.append(Vector3(x, 0.05, plaza_z + rng.randf_range(-5.0, 5.0)))
	return points

func _dungeon_spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for z: float in [27.0, 15.0, 2.0, -10.0, -19.0]:
		points.append(Vector3(-16.0, 0.05, z))
		points.append(Vector3(0.0, 0.05, z))
		points.append(Vector3(16.0, 0.05, z))
	return points

func _add_box(node_name: String, size: Vector3, position_value: Vector3, style: StringName, collision_enabled: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1 if collision_enabled else 0
	body.collision_mask = 1
	zone_root.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = MaterialLibraryScript.material(style)
	body.add_child(mesh_instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return body

func _add_safety_perimeter(width: float, depth: float, height: float) -> void:
	# Tall invisible rails sit just inside the visual edge. They protect both the
	# player and knockback-driven crowds without adding more rendered geometry.
	_add_invisible_collision("SafetyWest", Vector3(0.55, height, depth), Vector3(-width * 0.5, height * 0.5, 0.0))
	_add_invisible_collision("SafetyEast", Vector3(0.55, height, depth), Vector3(width * 0.5, height * 0.5, 0.0))
	_add_invisible_collision("SafetyBack", Vector3(width, height, 0.55), Vector3(0.0, height * 0.5, -depth * 0.5))
	_add_invisible_collision("SafetyFront", Vector3(width, height, 0.55), Vector3(0.0, height * 0.5, depth * 0.5))

func _add_invisible_collision(node_name: String, size: Vector3, position_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	zone_root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _add_tower(position_value: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	body.collision_layer = 1
	zone_root.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = 10.0
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 5.0
	mesh_instance.material_override = MaterialLibraryScript.material(&"fortress")
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 10.0
	shape.radius = radius
	collision.shape = shape
	collision.position.y = 5.0
	body.add_child(collision)

func _add_column(position_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	body.collision_layer = 1
	zone_root.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = 5.5
	mesh.top_radius = 0.62
	mesh.bottom_radius = 0.76
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 2.75
	mesh_instance.material_override = MaterialLibraryScript.material(&"marble")
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 5.5
	shape.radius = 0.72
	collision.shape = shape
	collision.position.y = 2.75
	body.add_child(collision)

func _add_prop(asset_id: StringName, position_value: Vector3, rotation_y_degrees: float, repeated: bool = false, height_override: float = 0.0, collision_enabled: bool = true) -> Node3D:
	var definition: Dictionary = AssetCatalogScript.definition(asset_id)
	var path := AssetCatalogScript.visual_path(asset_id, repeated)
	if path.is_empty():
		push_warning("[PROCEDURAL MAP] Asset '%s' is absent from the environment catalog or disk." % asset_id)
		return null
	var packed := RuntimeGLTFCacheScript.scene(path)
	if packed == null:
		return null
	var holder := Node3D.new()
	holder.name = "Prop_%s_%d" % [String(asset_id), zone_root.get_child_count()]
	holder.position = position_value
	holder.rotation_degrees.y = rotation_y_degrees
	zone_root.add_child(holder)
	var content := packed.instantiate() as Node3D
	if content == null:
		holder.queue_free()
		return null
	holder.add_child(content)
	_disable_activity(content)
	var bounds := _node_bounds(holder, content)
	var target_height := height_override if height_override > 0.0 else AssetCatalogScript.target_height(asset_id)
	if bounds.size.length_squared() > 0.001:
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		content.scale = Vector3.ONE * scale_value
		content.position = Vector3(
			-(bounds.position.x + bounds.size.x * 0.5) * scale_value,
			-bounds.position.y * scale_value,
			-(bounds.position.z + bounds.size.z * 0.5) * scale_value
		)
	if collision_enabled:
		_add_catalog_collision(holder, definition)
	return holder

func _add_catalog_collision(holder: Node3D, definition: Dictionary) -> void:
	var kind := StringName(definition.get("collision", &"none"))
	if kind == &"none":
		return
	var body := StaticBody3D.new()
	body.name = "GameplayCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	holder.add_child(body)
	var collision := CollisionShape3D.new()
	if kind == &"cylinder":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(definition.get("collision_radius", 0.5))
		cylinder.height = float(definition.get("collision_height", 1.0))
		collision.shape = cylinder
		collision.position.y = cylinder.height * 0.5
	else:
		var box := BoxShape3D.new()
		box.size = definition.get("collision_size", Vector3.ONE)
		collision.shape = box
		collision.position.y = box.size.y * 0.5
	body.add_child(collision)

func _add_ground_patch(node_name: String, size: Vector2, position_value: Vector3, style: StringName, rotation_y_degrees: float) -> void:
	var patch := _add_box(node_name, Vector3(size.x, 0.035, size.y), position_value, style, false)
	patch.rotation_degrees.y = rotation_y_degrees

func _add_city_house(index: int, base_position: Vector3, size: Vector3, side: float, fortified: bool) -> void:
	var wall_style: StringName = &"fortress" if fortified else &"limestone_brick"
	_add_box("House_%02d" % index, size, base_position + Vector3.UP * size.y * 0.5, wall_style, true)
	_add_box("Cornice_%02d" % index, Vector3(size.x + 0.55, 0.30, size.z + 0.55), base_position + Vector3.UP * (size.y - 0.12), &"marble", false)
	_add_box("Roof_%02d" % index, Vector3(size.x + 0.9, 0.42, size.z + 0.9), base_position + Vector3.UP * (size.y + 0.21), &"sandstone_floor", false)

	# All façades face the processional road. A recessed dark door, a shallow
	# awning and two columns turn the procedural blocks into readable street fronts.
	var facade_x := base_position.x - side * (size.x * 0.5 + 0.06)
	var door_z := base_position.z + rng.randf_range(-size.z * 0.18, size.z * 0.18)
	var door := _add_box("Door_%02d" % index, Vector3(1.55, 2.65, 0.12), Vector3(facade_x, 1.325, door_z), &"rough_stone", false)
	door.rotation_degrees.y = 90.0
	var awning := _add_box("Awning_%02d" % index, Vector3(1.65, 0.14, 3.1), Vector3(facade_x - side * 0.68, 2.82, door_z), &"fortress" if index % 2 == 0 else &"marble", false)
	awning.rotation_degrees.y = 0.0
	if size.y >= 5.0:
		_add_facade_column(Vector3(facade_x - side * 0.30, 0.0, door_z - 2.05), minf(4.2, size.y - 0.45))
		_add_facade_column(Vector3(facade_x - side * 0.30, 0.0, door_z + 2.05), minf(4.2, size.y - 0.45))

func _add_facade_column(position_value: Vector3, height: float) -> void:
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = 0.20
	mesh.bottom_radius = 0.27
	mesh.radial_segments = 10
	column.mesh = mesh
	column.material_override = MaterialLibraryScript.material(&"marble")
	column.position = position_value + Vector3.UP * height * 0.5
	zone_root.add_child(column)

func _add_barricade_line(center: Vector3, count: int, rotation_y_degrees: float, spacing: float = 2.08) -> void:
	var rotation := deg_to_rad(rotation_y_degrees)
	var local_axis := Vector3(cos(rotation), 0.0, -sin(rotation))
	for index: int in range(count):
		var offset := (float(index) - float(count - 1) * 0.5) * spacing
		_add_prop(&"barricade", center + local_axis * offset, rotation_y_degrees, true)

func _add_supply_cluster(center: Vector3, rotation_y_degrees: float) -> void:
	var rotation := deg_to_rad(rotation_y_degrees)
	var right := Vector3(cos(rotation), 0.0, -sin(rotation))
	var forward := Vector3(sin(rotation), 0.0, cos(rotation))
	_add_prop(&"crates", center, rotation_y_degrees, true)
	_add_prop(&"jar", center + right * 1.35 + forward * 0.25, rotation_y_degrees + 18.0, true)
	_add_prop(&"jar", center - right * 1.05 + forward * 0.72, rotation_y_degrees - 24.0, true, 1.05)

func _add_brazier(position_value: Vector3, rotation_y_degrees: float) -> void:
	_add_prop(&"brazier", position_value, rotation_y_degrees, true)
	_add_torch(position_value + Vector3.UP * 2.18, 10.5, 2.7)

func _add_wall_torch(position_value: Vector3, rotation_y_degrees: float) -> void:
	var mount := Node3D.new()
	mount.name = "WallTorch_%d" % zone_root.get_child_count()
	mount.position = position_value
	mount.rotation_degrees.y = rotation_y_degrees
	zone_root.add_child(mount)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.065, 0.025)
	metal.metallic = 0.72
	metal.roughness = 0.38
	var bracket := MeshInstance3D.new()
	var bracket_mesh := BoxMesh.new()
	bracket_mesh.size = Vector3(0.13, 0.13, 0.72)
	bracket.mesh = bracket_mesh
	bracket.position.z = 0.28
	bracket.material_override = metal
	mount.add_child(bracket)
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.height = 0.18
	cup_mesh.top_radius = 0.27
	cup_mesh.bottom_radius = 0.15
	cup_mesh.radial_segments = 12
	cup.mesh = cup_mesh
	cup.position = Vector3(0.0, -0.04, 0.63)
	cup.material_override = metal
	mount.add_child(cup)
	# `transform` is enough because mount and torch share zone_root coordinates;
	# unlike to_global(), it also works in headless generation before the first frame.
	var flame_position := mount.transform * Vector3(0.0, 0.18, 0.63)
	_add_torch(flame_position, 8.2, 2.35)

func _add_wall_panel(position_value: Vector3, size: Vector2, rotation_y_degrees: float, style: StringName) -> void:
	var panel := MeshInstance3D.new()
	panel.name = "Panel_%s_%d" % [String(style), zone_root.get_child_count()]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.10)
	panel.mesh = mesh
	panel.material_override = MaterialLibraryScript.uv_material(style)
	panel.position = position_value
	panel.rotation_degrees.y = rotation_y_degrees
	zone_root.add_child(panel)

func _disable_activity(root: Node) -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for candidate: Node in root.find_children("*", "AnimationPlayer", true, false):
		(candidate as AnimationPlayer).stop()
	for candidate: Node in root.find_children("*", "CollisionObject3D", true, false):
		var collision := candidate as CollisionObject3D
		collision.collision_layer = 0
		collision.collision_mask = 0

func _node_bounds(root: Node3D, content: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	var meshes: Array[MeshInstance3D] = []
	if content is MeshInstance3D:
		meshes.append(content as MeshInstance3D)
	for candidate: Node in content.find_children("*", "MeshInstance3D", true, false):
		meshes.append(candidate as MeshInstance3D)
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.get_aabb()
		var mesh_to_root := _transform_to_ancestor(mesh_instance, root)
		for corner: int in range(8):
			var point := mesh_to_root * mesh_bounds.get_endpoint(corner)
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds

func _transform_to_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

func _add_banner_line(z_value: float, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	for x: float in [-9.0, 9.0]:
		var banner := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.2, 4.6, 0.12)
		banner.mesh = mesh
		banner.position = Vector3(x, 5.6, z_value)
		banner.material_override = material
		zone_root.add_child(banner)

func _add_torch(position_value: Vector3, light_range: float = 9.0, energy: float = 2.3) -> void:
	var light := BrazierLightScript.new()
	light.position = position_value
	light.light_color = Color(1.0, 0.30, 0.045)
	light.light_energy = energy
	light.base_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	zone_root.add_child(light)
	var flame := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.36
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.16, 0.01) * 3.2
	material.albedo_color = Color(1.0, 0.32, 0.03)
	mesh.material = material
	flame.mesh = mesh
	light.add_child(flame)

	var smoke := GPUParticles3D.new()
	smoke.name = "LivingSmoke"
	smoke.add_to_group("campaign_smoke")
	smoke.amount = 18
	smoke.lifetime = 3.2
	smoke.preprocess = 2.0
	smoke.randomness = 0.72
	smoke.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3.0, 5.0, 3.0))
	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.direction = Vector3.UP
	smoke_process.spread = 22.0
	smoke_process.initial_velocity_min = 0.34
	smoke_process.initial_velocity_max = 0.82
	smoke_process.gravity = Vector3(0.10, 0.16, 0.04)
	smoke_process.scale_min = 0.20
	smoke_process.scale_max = 0.58
	smoke_process.color = Color(0.14, 0.12, 0.11, 0.34)
	smoke.process_material = smoke_process
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.55, 0.55)
	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.albedo_color = Color(0.20, 0.17, 0.15, 0.30)
	smoke_quad.material = smoke_material
	smoke.draw_pass_1 = smoke_quad
	light.add_child(smoke)
