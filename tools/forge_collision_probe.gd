extends SceneTree

const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")
const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")

const GATE_PATH := "res://assets/blenderAseet/05_forteresse_verticale/fortress_gatehouse/fortress_gatehouse_LOD0.glb"
const GATE_COLLISION_PATH := "res://assets/blenderAseet/05_forteresse_verticale/fortress_gatehouse/fortress_gatehouse_collision.glb"
const GATE_PART_COUNT: int = 5
const ARCADE_PATH := "res://assets/blenderAseet/06_urbain/greek_house_arcade/greek_house_arcade_LOD0.glb"
const ARCADE_COLLISION_PATH := "res://assets/blenderAseet/06_urbain/greek_house_arcade/greek_house_arcade_collision.glb"
const ARCADE_PART_COUNT: int = 7
const TREE_DIRECTORY := "res://assets/environment/stylized_nature/trees"
const CYPRESS_PATH := "res://_source/environment_props_raw/cypressTree/cypressTree_LOD0.glb"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(AssetCatalogScript.authored_collision_path_for_visual(GATE_PATH) == GATE_COLLISION_PATH, "Forge must resolve the authored gatehouse collision proxy")
	_expect(AssetCatalogScript.default_collision_shape_for_path(GATE_PATH) == "convex", "assets with an authored proxy must default to optimized collision")
	_expect(AssetCatalogScript.authored_collision_path_for_visual(ARCADE_PATH) == ARCADE_COLLISION_PATH, "Forge must resolve the authored house arcade collision proxy")

	WorldRuntimeScript.convex_collision_cache.clear()
	WorldRuntimeScript.tree_trunk_bounds_cache.clear()
	var document := WorldDocumentScript.new(WorldDocumentScript.create_default())
	var first_id := _add_gate(document, "Gate A", Vector3.ZERO)
	var second_id := _add_gate(document, "Gate B", Vector3(14.0, 0.0, 0.0))
	var arcade_id := _add_arcade(document, Vector3(30.0, 0.0, 0.0))
	var tree_ids: Dictionary = {}
	var tree_files: Array[String] = []
	for file: String in DirAccess.get_files_at(TREE_DIRECTORY):
		if file.ends_with(".gltf"):
			tree_files.append(file)
	tree_files.sort()
	for tree_index: int in range(tree_files.size()):
		var tree_path := TREE_DIRECTORY.path_join(String(tree_files[tree_index]))
		tree_ids[tree_path] = _add_tree(document, tree_path, Vector3(42.0 + float(tree_index) * 8.0, 0.0, 0.0), 7.0)
	tree_ids[CYPRESS_PATH] = _add_tree(document, CYPRESS_PATH, Vector3(42.0 + float(tree_files.size()) * 8.0, 0.0, 0.0), 7.2)
	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	root.add_child(runtime)
	runtime.build(document, true)
	await physics_frame

	var first_holder := runtime.nodes_by_id.get(first_id) as Node3D
	var second_holder := runtime.nodes_by_id.get(second_id) as Node3D
	var first_body := _gameplay_body(first_holder)
	var second_body := _gameplay_body(second_holder)
	var arcade_body := _gameplay_body(runtime.nodes_by_id.get(arcade_id) as Node3D)
	_expect(first_body != null and second_body != null, "both gatehouses must build a gameplay StaticBody3D")
	_expect(arcade_body != null and int(arcade_body.get_meta("gameplay_collision_part_count", 0)) == ARCADE_PART_COUNT, "the house arcade must preserve its seven separated collision pieces")
	if first_body != null and second_body != null:
		var first_shapes := _collision_shapes(first_body)
		var second_shapes := _collision_shapes(second_body)
		_expect(String(first_body.get_meta("gameplay_collision_source", "")) == "authored", "the first gatehouse must use its authored proxy")
		_expect(String(second_body.get_meta("gameplay_collision_source", "")) == "cache", "the second identical gatehouse must reuse cached shapes")
		_expect(first_holder.scale == Vector3.ONE and first_body.scale == Vector3.ONE, "prop scale must be baked so physics bodies remain unscaled")
		_expect(first_shapes.size() == GATE_PART_COUNT and second_shapes.size() == GATE_PART_COUNT, "gatehouse collision must preserve its five separated convex pieces")
		for shape_node: CollisionShape3D in first_shapes:
			_expect(shape_node.shape is ConvexPolygonShape3D, "every authored proxy part must become a ConvexPolygonShape3D")
			_expect(shape_node.transform == Transform3D.IDENTITY, "authored points must be baked without transforming CollisionShape3D nodes")
		if first_shapes.size() == second_shapes.size() and not first_shapes.is_empty():
			_expect(first_shapes[0].shape == second_shapes[0].shape, "cached instances must share immutable Shape3D resources")
		var local_bounds := _convex_bounds(first_shapes)
		_expect(local_bounds.size.length_squared() > 0.0, "authored collision must have usable bounds")
		if local_bounds.size.length_squared() > 0.0:
			var opening_local := Vector3(local_bounds.get_center().x, local_bounds.position.y + local_bounds.size.y * 0.28, local_bounds.get_center().z)
			var opening_from := first_holder.to_global(opening_local + Vector3(0.0, 0.0, -local_bounds.size.z))
			var opening_to := first_holder.to_global(opening_local + Vector3(0.0, 0.0, local_bounds.size.z))
			var opening_query := PhysicsRayQueryParameters3D.create(opening_from, opening_to, 1)
			_expect(runtime.get_world_3d().direct_space_state.intersect_ray(opening_query).is_empty(), "the centered gate opening must remain traversable")
			var roof_from := first_holder.to_global(Vector3(opening_local.x, local_bounds.end.y + 1.0, opening_local.z))
			var roof_to := first_holder.to_global(Vector3(opening_local.x, local_bounds.position.y - 0.5, opening_local.z))
			var roof_query := PhysicsRayQueryParameters3D.create(roof_from, roof_to, 1)
			_expect(not runtime.get_world_3d().direct_space_state.intersect_ray(roof_query).is_empty(), "the upper gate structure must provide a walkable top collision")
	for tree_path: String in tree_ids:
		_validate_tree_collision(runtime.nodes_by_id.get(String(tree_ids[tree_path])) as Node3D, tree_path)

	if failures.is_empty():
		print("FORGE_COLLISION_PROBE_OK parts=%d cache_entries=%d trees=%d" % [GATE_PART_COUNT, WorldRuntimeScript.convex_collision_cache.size(), tree_ids.size()])
		runtime.free()
		quit(0)
		return
	for failure: String in failures:
		printerr("FORGE_COLLISION_PROBE_FAILED: " + failure)
	runtime.free()
	quit(1)

func _add_gate(document: HopliteWorldDocument, label: String, position: Vector3) -> String:
	var entity := WorldDocumentScript.entity("prop", label, position, {
		"asset_path": GATE_PATH,
		"asset_label": label,
		"target_height": 5.0,
		"collision_enabled": true,
		"collision_shape": "convex",
	})
	entity["chapter"] = document.start_chapter()
	entity["scale"] = WorldDocumentScript.array3(Vector3(1.2, 1.1, 0.8))
	return document.add_entity(entity)

func _add_arcade(document: HopliteWorldDocument, position: Vector3) -> String:
	var entity := WorldDocumentScript.entity("prop", "House arcade", position, {
		"asset_path": ARCADE_PATH,
		"asset_label": "House arcade",
		"target_height": 4.2,
		"collision_enabled": true,
		"collision_shape": "convex",
	})
	entity["chapter"] = document.start_chapter()
	return document.add_entity(entity)

func _add_tree(document: HopliteWorldDocument, path: String, position: Vector3, target_height: float) -> String:
	var label := path.get_file().get_basename()
	var entity := WorldDocumentScript.entity("prop", label, position, {
		"asset_path": path,
		"asset_label": label,
		"target_height": target_height,
		"collision_enabled": true,
		"collision_shape": "cylinder",
	})
	entity["chapter"] = document.start_chapter()
	return document.add_entity(entity)

func _validate_tree_collision(tree_holder: Node3D, tree_path: String) -> void:
	var tree_body := _gameplay_body(tree_holder, "cylinder")
	_expect(tree_body != null, "%s must build a gameplay cylinder" % tree_path.get_file())
	if tree_body == null:
		return
	var tree_shapes := _collision_shapes(tree_body)
	var visual_bounds := tree_holder.get_meta("editor_local_bounds", AABB()) as AABB
	_expect(String(tree_body.get_meta("gameplay_collision_source", "")) == "tree_trunk", "%s must use the dedicated trunk fitting path" % tree_path.get_file())
	_expect(tree_shapes.size() == 1 and tree_shapes[0].shape is CylinderShape3D, "%s must keep one CylinderShape3D" % tree_path.get_file())
	if tree_shapes.size() != 1 or not (tree_shapes[0].shape is CylinderShape3D):
		return
	var cylinder := tree_shapes[0].shape as CylinderShape3D
	var visual_width := maxf(visual_bounds.size.x, visual_bounds.size.z)
	_expect(cylinder.radius >= 0.20 and cylinder.radius <= 0.75, "%s cylinder radius must stay within a plausible trunk footprint" % tree_path.get_file())
	_expect(cylinder.radius * 2.0 < visual_width * 0.75, "%s cylinder must exclude the foliage width" % tree_path.get_file())
	_expect(is_equal_approx(cylinder.height, visual_bounds.size.y), "%s cylinder height must match the full visual height" % tree_path.get_file())
	_expect(is_equal_approx(tree_body.position.y + cylinder.height * 0.5, visual_bounds.end.y), "%s cylinder top must align with the tree summit" % tree_path.get_file())
	_expect(tree_body.scale == Vector3.ONE and tree_shapes[0].scale == Vector3.ONE, "%s collider dimensions must be baked without node scaling" % tree_path.get_file())
	var selection_body := _selection_body(tree_holder)
	var selection_shapes: Array[CollisionShape3D] = []
	if selection_body != null:
		selection_shapes = _collision_shapes(selection_body)
	_expect(selection_shapes.size() == 1 and selection_shapes[0].shape is BoxShape3D, "%s must retain its independent Forge selection box" % tree_path.get_file())
	if selection_shapes.size() == 1 and selection_shapes[0].shape is BoxShape3D:
		_expect((selection_shapes[0].shape as BoxShape3D).size.is_equal_approx(visual_bounds.size), "%s selection box must still cover the full visual, including foliage" % tree_path.get_file())

func _gameplay_body(holder: Node3D, shape_kind: String = "convex") -> StaticBody3D:
	if holder == null:
		return null
	for candidate: Node in holder.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if String(body.get_meta("gameplay_collision_shape", "")) == shape_kind:
			return body
	return null

func _selection_body(holder: Node3D) -> StaticBody3D:
	if holder == null:
		return null
	for candidate: Node in holder.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if body.collision_layer == 16:
			return body
	return null

func _collision_shapes(body: StaticBody3D) -> Array[CollisionShape3D]:
	var result: Array[CollisionShape3D] = []
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			result.append(child as CollisionShape3D)
	return result

func _convex_bounds(shapes: Array[CollisionShape3D]) -> AABB:
	var initialized := false
	var bounds := AABB()
	for shape_node: CollisionShape3D in shapes:
		if not (shape_node.shape is ConvexPolygonShape3D):
			continue
		for point: Vector3 in (shape_node.shape as ConvexPolygonShape3D).points:
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
