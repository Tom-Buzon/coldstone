extends Node3D
class_name HopliteAssetLibraryRoom

const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")
const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")
const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")

# IMPORTANT: keep this list synchronized with the catalog notice at the very top
# of README.md. Missing optional folders are simply ignored until they are made.
const CATALOG_ROOTS: Array[Dictionary] = [
	{"path": "res://assets/characters/3dgen_demo", "category": &"characters", "label": "PERSONNAGES"},
	{"path": "res://assets/environment", "category": &"environment", "label": "ENVIRONNEMENT"},
	{"path": "res://assets/weapons", "category": &"weapons", "label": "ARMES"},
	{"path": "res://assets/items", "category": &"items", "label": "OBJETS"},
	{"path": "res://assets/props", "category": &"props", "label": "DECORS"},
	{"path": "res://_source/environment_props_raw", "category": &"environment", "label": "ENVIRONNEMENT"},
	{"path": "res://_source/weapons_raw", "category": &"weapons", "label": "ARMES"},
	{"path": "res://_source/items_raw", "category": &"items", "label": "OBJETS"}
]

const SUPPORTED_EXTENSIONS := ["glb", "gltf"]
const COLUMNS := 6
const CELL_X := 4.6
const CELL_Z := 4.5
const ROOM_WIDTH := 30.0
const LOAD_INTERVAL := 0.10

const SUBCATEGORY_LABELS := {
	&"trees": "ARBRES",
	&"shrubs": "BUISSONS & PLANTES",
	&"ground_cover": "FLEURS, HERBES & SOUS-BOIS",
	&"rocks": "ROCHERS & GALETS",
	&"stone_paths": "CHEMINS DE PIERRE",
	&"architecture": "ARCHITECTURE & MONUMENTS",
	&"decor": "DÉCORS & OBJETS",
	&"weapons": "ARMES",
	&"items": "OBJETS",
}

const SUBCATEGORY_ORDER: Array[StringName] = [
	&"trees", &"shrubs", &"ground_cover", &"rocks", &"stone_paths",
	&"architecture", &"decor", &"weapons", &"items",
]

var catalog_entries: Array[Dictionary] = []
var pending_entries: Array[Dictionary] = []
var loaded_count: int = 0
var load_accumulator: float = 0.0
var room_depth: float = 18.0

func _ready() -> void:
	catalog_entries = _scan_catalog()
	pending_entries = catalog_entries.duplicate(true)
	var row_count := maxi(1, ceili(float(catalog_entries.size()) / float(COLUMNS)))
	room_depth = maxf(18.0, 6.0 + float(row_count) * CELL_X)
	_build_room_shell()
	_build_entrance_sign()
	set_process(not pending_entries.is_empty())
	print("[ASSET LIBRARY] Catalogued %d unique 3D exhibits from %d configured roots." % [catalog_entries.size(), CATALOG_ROOTS.size()])

func _process(delta: float) -> void:
	if pending_entries.is_empty():
		print("[ASSET LIBRARY] Loaded %d/%d exhibits." % [loaded_count, catalog_entries.size()])
		set_process(false)
		return
	load_accumulator += delta
	if load_accumulator < LOAD_INTERVAL:
		return
	load_accumulator = 0.0
	var entry: Dictionary = pending_entries.pop_front()
	_create_exhibit(entry, loaded_count)
	loaded_count += 1

func _scan_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for root_config: Dictionary in CATALOG_ROOTS:
		var discovered: Array[String] = []
		_collect_model_files(String(root_config["path"]), discovered)
		discovered.sort()
		for path: String in discovered:
			if _is_technical_variant(path):
				continue
			var logical_id := _logical_asset_id(path)
			var category := StringName(root_config["category"])
			var unique_key := "%s:%s" % [String(category), logical_id]
			if seen.has(unique_key):
				continue
			seen[unique_key] = true
			var subcategory := _subcategory_for(path, category)
			result.append({
				"path": path,
				"id": logical_id,
				"category": category,
				"category_label": String(root_config["label"]),
				"subcategory": subcategory,
				"subcategory_label": String(SUBCATEGORY_LABELS.get(subcategory, "DÉCORS & OBJETS")),
				"display_name": _display_name(path),
				"target_height": _suggested_target_height(path, subcategory),
				"brush_spacing": _suggested_brush_spacing(subcategory),
			})
	result.sort_custom(_sort_entries)
	return result

func _collect_model_files(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var child_path := directory_path.path_join(file_name)
			if directory.current_is_dir():
				_collect_model_files(child_path, output)
			elif SUPPORTED_EXTENSIONS.has(file_name.get_extension().to_lower()):
				output.append(child_path)
		file_name = directory.get_next()
	directory.list_dir_end()

func _is_technical_variant(path: String) -> bool:
	var base := path.get_file().get_basename().to_lower()
	if base.contains("collision") or base.contains("collider") or base.contains("proxy"):
		return true
	for lod_suffix: String in ["lod1", "lod2", "lod3", "lod4", "lod5"]:
		if base.contains(lod_suffix):
			return true
	return false

func _logical_asset_id(path: String) -> String:
	var value := path.get_file().get_basename().to_lower()
	for suffix: String in ["_lod0", "-lod0", " lod0"]:
		value = value.trim_suffix(suffix)
	var hyphen_parts := value.rsplit("-", true, 1)
	if hyphen_parts.size() == 2:
		var possible_timestamp := String(hyphen_parts[1])
		if possible_timestamp.length() >= 8 and possible_timestamp.is_valid_int():
			value = String(hyphen_parts[0])
	return value.replace("_", "").replace("-", "").replace(" ", "")

func _display_name(path: String) -> String:
	var value := path.get_file().get_basename()
	for suffix: String in ["_LOD0", "_lod0", "-LOD0", "-lod0"]:
		value = value.trim_suffix(suffix)
	var hyphen_parts := value.rsplit("-", true, 1)
	if hyphen_parts.size() == 2:
		var possible_timestamp := String(hyphen_parts[1])
		if possible_timestamp.length() >= 8 and possible_timestamp.is_valid_int():
			value = String(hyphen_parts[0])
	return value.replace("_", " ").capitalize()

func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	var category_a := String(a["category"])
	var category_b := String(b["category"])
	if category_a == category_b:
		var order_a := SUBCATEGORY_ORDER.find(StringName(a.get("subcategory", &"decor")))
		var order_b := SUBCATEGORY_ORDER.find(StringName(b.get("subcategory", &"decor")))
		if order_a != order_b:
			return order_a < order_b
		return String(a["display_name"]).naturalnocasecmp_to(String(b["display_name"])) < 0
	return category_a < category_b

func _subcategory_for(path: String, category: StringName) -> StringName:
	var lower_path := path.to_lower()
	for subcategory: StringName in [&"trees", &"shrubs", &"ground_cover", &"rocks", &"stone_paths"]:
		if lower_path.contains("/stylized_nature/%s/" % String(subcategory)):
			return subcategory
	match category:
		&"weapons": return &"weapons"
		&"items": return &"items"
		&"props": return &"decor"
	var filename := path.get_file().to_lower()
	if filename.contains("tree") or filename.contains("cypress"):
		return &"trees"
	if filename.contains("rock"):
		return &"rocks"
	if filename.contains("temple") or filename.contains("statue") or filename.contains("status") or filename.contains("fountain") or filename.contains("fontaine") or filename.contains("tomb") or filename.contains("tombe"):
		return &"architecture"
	return &"decor"

func _suggested_target_height(path: String, subcategory: StringName) -> float:
	match subcategory:
		&"trees": return 7.0
		&"shrubs": return 1.6
		&"ground_cover": return 0.65
		&"rocks": return 1.15
		&"stone_paths": return 0.18
	return AssetCatalogScript.target_height_for_path(path, 2.0)

func _suggested_brush_spacing(subcategory: StringName) -> float:
	match subcategory:
		&"trees": return 5.0
		&"shrubs": return 2.0
		&"ground_cover": return 0.75
		&"rocks": return 1.5
		&"stone_paths": return 1.0
		_: return 1.0

func _build_room_shell() -> void:
	var floor_center := Vector3(-room_depth * 0.5, -0.08, 0.0)
	_add_architecture_box("LibraryFloor", Vector3(room_depth, 0.16, ROOM_WIDTH), floor_center, &"pavers", true)
	_add_architecture_box("LibraryNorthWall", Vector3(room_depth, 3.8, 0.65), Vector3(-room_depth * 0.5, 1.9, -ROOM_WIDTH * 0.5), &"fortress", true)
	_add_architecture_box("LibrarySouthWall", Vector3(room_depth, 3.8, 0.65), Vector3(-room_depth * 0.5, 1.9, ROOM_WIDTH * 0.5), &"fortress", true)
	_add_architecture_box("LibraryBackWall", Vector3(0.65, 3.8, ROOM_WIDTH), Vector3(-room_depth, 1.9, 0.0), &"fortress", true)
	var front_segment_length := (ROOM_WIDTH - 4.5) * 0.5
	var front_offset := (ROOM_WIDTH + 4.5) * 0.25
	_add_architecture_box("LibraryFrontNorth", Vector3(0.65, 3.8, front_segment_length), Vector3(0.0, 1.9, -front_offset), &"fortress", true)
	_add_architecture_box("LibraryFrontSouth", Vector3(0.65, 3.8, front_segment_length), Vector3(0.0, 1.9, front_offset), &"fortress", true)
	_add_architecture_box("LibraryDoorLintel", Vector3(0.85, 0.8, 5.1), Vector3(0.0, 3.4, 0.0), &"marble", true)
	for side: float in [-1.0, 1.0]:
		_add_architecture_box("LibraryDoorPillar_%s" % str(side), Vector3(0.85, 3.4, 0.85), Vector3(0.0, 1.7, side * 2.5), &"marble", true)

	var light_count := maxi(2, ceili(room_depth / 8.0))
	for i: int in range(light_count):
		var light := OmniLight3D.new()
		light.name = "LibraryLight_%02d" % i
		light.position = Vector3(-4.0 - float(i) * 8.0, 3.5, 0.0)
		light.light_color = Color(1.0, 0.78, 0.52)
		light.light_energy = 1.25
		light.omni_range = 8.5
		light.shadow_enabled = false
		add_child(light)

func _build_entrance_sign() -> void:
	var sign := Label3D.new()
	sign.name = "AssetLibrarySign"
	sign.text = "BIBLIOTHEQUE DES ASSETS\n%d EXPOSITIONS AUTOMATIQUES" % catalog_entries.size()
	sign.position = Vector3(0.45, 4.55, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 42
	sign.outline_size = 8
	sign.modulate = Color(0.93, 0.78, 0.43)
	add_child(sign)

func _create_exhibit(entry: Dictionary, index: int) -> void:
	var row := index / COLUMNS
	var column := index % COLUMNS
	var column_center := (float(COLUMNS) - 1.0) * 0.5
	var exhibit := Node3D.new()
	exhibit.name = "Exhibit_%s" % String(entry["id"])
	exhibit.position = Vector3(-4.0 - float(row) * CELL_X, 0.0, (float(column) - column_center) * CELL_Z)
	exhibit.set_meta("catalog_path", entry["path"])
	exhibit.set_meta("catalog_category", entry["category"])
	add_child(exhibit)
	_build_pedestal(exhibit, entry)

	var packed := RuntimeGLTFCacheScript.scene(String(entry["path"]))
	var content := packed.instantiate() as Node3D if packed != null else null
	if content == null:
		_build_missing_marker(exhibit)
		return
	exhibit.add_child(content)
	_disable_runtime_activity(content)
	var bounds := _node_bounds_in_root(exhibit, content)
	if bounds.size.length_squared() <= 0.001:
		content.queue_free()
		_build_missing_marker(exhibit)
		return
	var category := StringName(entry["category"])
	var target_height := 2.15 if category == &"characters" else (1.65 if category == &"weapons" else 2.35)
	var vertical_scale := target_height / maxf(bounds.size.y, 0.01)
	var footprint_scale := 3.25 / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)
	var uniform_scale := minf(vertical_scale, footprint_scale)
	content.scale = Vector3.ONE * uniform_scale
	content.position = Vector3(
		-(bounds.position.x + bounds.size.x * 0.5) * uniform_scale,
		0.48 - bounds.position.y * uniform_scale,
		-(bounds.position.z + bounds.size.z * 0.5) * uniform_scale
	)
	content.rotation.y = PI

func _build_pedestal(parent: Node3D, entry: Dictionary) -> void:
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := BoxMesh.new()
	pedestal_mesh.size = Vector3(3.45, 0.42, 3.20)
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.21
	pedestal.material_override = MaterialLibraryScript.material(&"marble")
	parent.add_child(pedestal)
	var label := Label3D.new()
	label.name = "ExhibitLabel"
	label.text = "%s\n%s" % [String(entry["category_label"]), String(entry["display_name"])]
	label.position = Vector3(0.0, 0.52, 1.68)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 6
	label.modulate = _category_color(StringName(entry["category"]))
	parent.add_child(label)

func _build_missing_marker(parent: Node3D) -> void:
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.65, 1.25, 0.65)
	marker.mesh = mesh
	marker.position.y = 1.10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.05, 0.04)
	material.emission_enabled = true
	material.emission = Color(0.20, 0.01, 0.0)
	marker.material_override = material
	parent.add_child(marker)

func _disable_runtime_activity(root: Node) -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for candidate: Node in root.find_children("*", "AnimationPlayer", true, false):
		(candidate as AnimationPlayer).stop()
	for candidate: Node in root.find_children("*", "AnimationTree", true, false):
		(candidate as AnimationTree).active = false
	for candidate: Node in root.find_children("*", "CollisionObject3D", true, false):
		var collision_object := candidate as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

func _node_bounds_in_root(root: Node3D, content: Node3D) -> AABB:
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
		for corner_index: int in range(8):
			var local_point := root.to_local(mesh_instance.to_global(mesh_bounds.get_endpoint(corner_index)))
			if not initialized:
				bounds = AABB(local_point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(local_point)
	return bounds

func _add_architecture_box(node_name: String, size: Vector3, position_value: Vector3, style: StringName, collision_enabled: bool) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1 if collision_enabled else 0
	body.collision_mask = 1
	add_child(body)
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

func _category_color(category: StringName) -> Color:
	match category:
		&"characters": return Color(0.78, 0.88, 1.0)
		&"weapons": return Color(1.0, 0.70, 0.30)
		&"items": return Color(0.65, 1.0, 0.65)
		&"props": return Color(0.88, 0.72, 0.50)
		_: return Color(0.92, 0.86, 0.70)
