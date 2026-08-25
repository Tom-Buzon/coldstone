extends RefCounted
class_name HopliteWorldTerrain

const MIN_RESOLUTION := 17
const MAX_RESOLUTION := 129
const DEFAULT_RESOLUTION := 65
const MIN_SIZE := 8.0
const MAX_SIZE := 512.0
const GENERATORS := ["flat", "rolling", "ridge", "valley", "coast"]
const SCULPT_MODES := ["raise", "lower", "smooth", "flatten"]
const PAINT_MODES := ["paint", "erase_material", "foliage", "erase_foliage"]
const FOLIAGE_PRESETS := ["mediterranean_grass", "wild_grass", "clover", "flowers", "ferns", "shrubs", "mushrooms"]

static func default_properties(generator: String = "rolling", resolution: int = DEFAULT_RESOLUTION, seed: int = 1337) -> Dictionary:
	var properties := {
		"resolution": resolution,
		"width": float(resolution - 1),
		"depth": float(resolution - 1),
		"generator": generator,
		"seed": seed,
		"amplitude": 7.0,
		"frequency": 0.025,
		"octaves": 4,
		"material": "dirt_path",
		"heights": [],
		"paint_layers": ["mediterranean_grass", "rough_stone", "sandstone_floor"],
		"material_weights": [],
		"foliage_density": [],
		"foliage_types": [],
		"foliage_preset": "mediterranean_grass",
		"foliage_seed": seed + 7919,
		"foliage_amount": 0.65,
	}
	normalize(properties)
	return properties

static func normalize(properties: Dictionary) -> void:
	var resolution := clampi(int(properties.get("resolution", DEFAULT_RESOLUTION)), MIN_RESOLUTION, MAX_RESOLUTION)
	if resolution % 2 == 0:
		resolution += 1 if resolution < MAX_RESOLUTION else -1
	properties["resolution"] = resolution
	properties["width"] = clampf(float(properties.get("width", resolution - 1)), MIN_SIZE, MAX_SIZE)
	properties["depth"] = clampf(float(properties.get("depth", resolution - 1)), MIN_SIZE, MAX_SIZE)
	var generator := String(properties.get("generator", "rolling"))
	properties["generator"] = generator if generator in GENERATORS else "rolling"
	properties["seed"] = int(properties.get("seed", 1337))
	properties["amplitude"] = clampf(float(properties.get("amplitude", 7.0)), 0.0, 48.0)
	properties["frequency"] = clampf(float(properties.get("frequency", 0.025)), 0.001, 0.25)
	properties["octaves"] = clampi(int(properties.get("octaves", 4)), 1, 8)
	properties["material"] = String(properties.get("material", "dirt_path"))
	var paint_layers := properties.get("paint_layers", []) as Array
	var normalized_layers: Array[String] = []
	for index in range(3):
		normalized_layers.append(String(paint_layers[index]) if index < paint_layers.size() else "")
	properties["paint_layers"] = normalized_layers
	var foliage_preset := String(properties.get("foliage_preset", "mediterranean_grass"))
	properties["foliage_preset"] = foliage_preset if foliage_preset == "none" or foliage_preset in FOLIAGE_PRESETS else "mediterranean_grass"
	properties["foliage_seed"] = int(properties.get("foliage_seed", int(properties["seed"]) + 7919))
	properties["foliage_amount"] = clampf(float(properties.get("foliage_amount", 0.65)), 0.0, 2.0)
	var expected := resolution * resolution
	var source := properties.get("heights", []) as Array
	if source.size() != expected:
		properties["heights"] = generate_heights(properties)
	else:
		var normalized_heights: Array[float] = []
		normalized_heights.resize(expected)
		for index in range(expected):
			normalized_heights[index] = clampf(float(source[index]), -64.0, 64.0)
		properties["heights"] = normalized_heights
	var material_weights := _normalize_float_array(properties.get("material_weights", []), expected * 3, 0.0, 1.0)
	for vertex_index in range(expected):
		var offset := vertex_index * 3
		var total := material_weights[offset] + material_weights[offset + 1] + material_weights[offset + 2]
		if total > 1.0:
			material_weights[offset] /= total
			material_weights[offset + 1] /= total
			material_weights[offset + 2] /= total
	properties["material_weights"] = material_weights
	var foliage_density := _normalize_float_array(properties.get("foliage_density", []), expected, 0.0, 1.0)
	properties["foliage_density"] = foliage_density
	var source_types := properties.get("foliage_types", []) as Array
	var fallback_type := FOLIAGE_PRESETS.find(String(properties["foliage_preset"]))
	if fallback_type < 0:
		fallback_type = 0
	var foliage_types: Array[int] = []
	foliage_types.resize(expected)
	for index in range(expected):
		foliage_types[index] = clampi(int(source_types[index]), 0, FOLIAGE_PRESETS.size() - 1) if index < source_types.size() else (fallback_type if foliage_density[index] > 0.001 else 0)
	properties["foliage_types"] = foliage_types
	_update_size(properties)

static func regenerate(properties: Dictionary) -> void:
	properties["heights"] = []
	normalize(properties)

static func generate_heights(properties: Dictionary) -> Array[float]:
	var resolution := clampi(int(properties.get("resolution", DEFAULT_RESOLUTION)), MIN_RESOLUTION, MAX_RESOLUTION)
	var generator := String(properties.get("generator", "rolling"))
	var amplitude := clampf(float(properties.get("amplitude", 7.0)), 0.0, 48.0)
	var width := clampf(float(properties.get("width", resolution - 1)), MIN_SIZE, MAX_SIZE)
	var depth := clampf(float(properties.get("depth", resolution - 1)), MIN_SIZE, MAX_SIZE)
	var noise := FastNoiseLite.new()
	noise.seed = int(properties.get("seed", 1337))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = clampf(float(properties.get("frequency", 0.025)), 0.001, 0.25)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = clampi(int(properties.get("octaves", 4)), 1, 8)
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0
	var heights: Array[float] = []
	heights.resize(resolution * resolution)
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	for z in range(resolution):
		for x in range(resolution):
			var local_x := lerpf(-half_width, half_width, float(x) / float(resolution - 1))
			var local_z := lerpf(-half_depth, half_depth, float(z) / float(resolution - 1))
			var primary := noise.get_noise_2d(local_x, local_z)
			var height := 0.0
			match generator:
				"flat":
					height = 0.0
				"ridge":
					height = (1.0 - absf(primary)) * amplitude - amplitude * 0.38
				"valley":
					var valley_axis := absf(local_x) / maxf(1.0, half_width)
					height = (valley_axis * valley_axis - 0.28) * amplitude + primary * amplitude * 0.24
				"coast":
					var coast_slope := local_x / maxf(1.0, half_width)
					height = coast_slope * amplitude * 0.72 + primary * amplitude * 0.42
				_:
					height = primary * amplitude
			heights[z * resolution + x] = clampf(height, -64.0, 64.0)
	return heights

static func rebuild_body(body: StaticBody3D, properties: Dictionary, material: Material) -> void:
	normalize(properties)
	var resolution := int(properties["resolution"])
	var heights := _packed_heights(properties)
	var mesh_instance := body.get_node_or_null("TerrainMesh") as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "TerrainMesh"
		body.add_child(mesh_instance)
	mesh_instance.mesh = _build_mesh(properties, heights)
	mesh_instance.material_override = material
	var collision := body.get_node_or_null("TerrainCollision") as CollisionShape3D
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "TerrainCollision"
		body.add_child(collision)
	var shape := HeightMapShape3D.new()
	shape.map_width = resolution
	shape.map_depth = resolution
	shape.map_data = heights
	collision.shape = shape
	collision.scale = Vector3(
		float(properties["width"]) / float(resolution - 1),
		1.0,
		float(properties["depth"]) / float(resolution - 1)
	)
	body.collision_layer = 1
	body.collision_mask = 0
	var bounds := local_bounds(properties)
	body.set_meta("editor_local_bounds", bounds)

static func sculpt(properties: Dictionary, local_position: Vector3, mode: String, radius: float, strength: float, flatten_height: float = 0.0) -> bool:
	normalize(properties)
	if mode not in SCULPT_MODES:
		return false
	var resolution := int(properties["resolution"])
	var heights := properties["heights"] as Array
	var safe_radius := clampf(radius, 0.5, 24.0)
	var safe_strength := clampf(strength, 0.01, 8.0)
	var width := float(properties["width"])
	var depth := float(properties["depth"])
	var step_x := width / float(resolution - 1)
	var step_z := depth / float(resolution - 1)
	var center_x := (local_position.x / width + 0.5) * float(resolution - 1)
	var center_z := (local_position.z / depth + 0.5) * float(resolution - 1)
	var radius_x := safe_radius / step_x
	var radius_z := safe_radius / step_z
	var min_x := maxi(0, floori(center_x - radius_x))
	var max_x := mini(resolution - 1, ceili(center_x + radius_x))
	var min_z := maxi(0, floori(center_z - radius_z))
	var max_z := mini(resolution - 1, ceili(center_z + radius_z))
	var source := heights.duplicate() if mode == "smooth" else heights
	var changed := false
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var distance := Vector2((float(x) - center_x) * step_x, (float(z) - center_z) * step_z).length()
			if distance > safe_radius:
				continue
			var falloff := 1.0 - distance / safe_radius
			falloff = falloff * falloff * (3.0 - 2.0 * falloff)
			var index := z * resolution + x
			var current := float(heights[index])
			var next := current
			match mode:
				"raise": next = current + safe_strength * falloff
				"lower": next = current - safe_strength * falloff
				"flatten": next = lerpf(current, flatten_height, minf(1.0, safe_strength * 0.22 * falloff))
				"smooth":
					var average := _neighbor_average(source, resolution, x, z)
					next = lerpf(current, average, minf(1.0, safe_strength * 0.18 * falloff))
			next = clampf(next, -64.0, 64.0)
			if not is_equal_approx(current, next):
				heights[index] = next
				changed = true
	if changed:
		properties["heights"] = heights
		_update_size(properties)
	return changed

static func smooth_all(properties: Dictionary, passes: int = 1) -> void:
	normalize(properties)
	var resolution := int(properties["resolution"])
	var heights := properties["heights"] as Array
	for _pass_index in range(clampi(passes, 1, 8)):
		var source := heights.duplicate()
		for z in range(resolution):
			for x in range(resolution):
				var index := z * resolution + x
				heights[index] = lerpf(float(source[index]), _neighbor_average(source, resolution, x, z), 0.55)
	properties["heights"] = heights
	_update_size(properties)

static func resize_resolution(properties: Dictionary, new_resolution: int) -> void:
	normalize(properties)
	var old_resolution := int(properties["resolution"])
	var target := clampi(new_resolution, MIN_RESOLUTION, MAX_RESOLUTION)
	if target % 2 == 0:
		target += 1 if target < MAX_RESOLUTION else -1
	if target == old_resolution:
		return
	var source_foliage_density := properties["foliage_density"] as Array
	var source_foliage_types := properties["foliage_types"] as Array
	properties["heights"] = _resample_grid(properties["heights"] as Array, old_resolution, target, 1)
	properties["material_weights"] = _resample_grid(properties["material_weights"] as Array, old_resolution, target, 3)
	properties["foliage_density"] = _resample_grid(source_foliage_density, old_resolution, target, 1)
	properties["foliage_types"] = _resample_foliage_types(source_foliage_types, source_foliage_density, old_resolution, target)
	properties["resolution"] = target
	normalize(properties)

static func paint_material(properties: Dictionary, local_position: Vector3, style: String, radius: float, strength: float, erase: bool = false) -> bool:
	normalize(properties)
	var resolution := int(properties["resolution"])
	var layers := properties["paint_layers"] as Array
	var weights := properties["material_weights"] as Array
	var slot := -1
	if not erase:
		slot = layers.find(style)
		if slot < 0:
			slot = _available_material_slot(layers, weights)
			layers[slot] = style
			for vertex_index in range(resolution * resolution):
				weights[vertex_index * 3 + slot] = 0.0
	var changed := _paint_grid_values(properties, local_position, radius, func(index: int, falloff: float) -> bool:
		var modified := false
		if erase:
			for channel in range(3):
				var weight_index := index * 3 + channel
				var current := float(weights[weight_index])
				var next := maxf(0.0, current - strength * 0.24 * falloff)
				if not is_equal_approx(current, next):
					weights[weight_index] = next
					modified = true
			return modified
		var selected_index := index * 3 + slot
		var current_selected := float(weights[selected_index])
		var next_selected := minf(1.0, current_selected + strength * 0.24 * falloff)
		if is_equal_approx(current_selected, next_selected):
			return false
		weights[selected_index] = next_selected
		var remaining := 1.0 - next_selected
		var other_total := 0.0
		for channel in range(3):
			if channel != slot:
				other_total += float(weights[index * 3 + channel])
		if other_total > remaining and other_total > 0.0001:
			var scale := remaining / other_total
			for channel in range(3):
				if channel != slot:
					weights[index * 3 + channel] = float(weights[index * 3 + channel]) * scale
		return true
	)
	if changed:
		properties["paint_layers"] = layers
		properties["material_weights"] = weights
	return changed

static func paint_foliage(properties: Dictionary, local_position: Vector3, radius: float, strength: float, erase: bool = false, preset: String = "mediterranean_grass") -> bool:
	normalize(properties)
	var density := properties["foliage_density"] as Array
	var foliage_types := properties["foliage_types"] as Array
	var preset_index := FOLIAGE_PRESETS.find(preset)
	if preset_index < 0:
		preset_index = 0
	var changed := _paint_grid_values(properties, local_position, radius, func(index: int, falloff: float) -> bool:
		var current := float(density[index])
		var delta := strength * 0.24 * falloff
		var next := maxf(0.0, current - delta) if erase else minf(1.0, current + delta)
		var type_changed := not erase and int(foliage_types[index]) != preset_index and falloff > 0.08
		if is_equal_approx(current, next) and not type_changed:
			return false
		density[index] = next
		if type_changed:
			foliage_types[index] = preset_index
		return true
	)
	if changed:
		properties["foliage_density"] = density
		properties["foliage_types"] = foliage_types
		properties["foliage_preset"] = FOLIAGE_PRESETS[preset_index]
	return changed

static func foliage_at(properties: Dictionary, local_x: float, local_z: float) -> float:
	if not _has_normalized_topology(properties):
		normalize(properties)
	return foliage_at_normalized(properties, local_x, local_z)

static func foliage_at_normalized(properties: Dictionary, local_x: float, local_z: float) -> float:
	return _sample_grid(properties["foliage_density"] as Array, int(properties["resolution"]), local_x, local_z, float(properties["width"]), float(properties["depth"]), 0)

static func foliage_preset_at_normalized(properties: Dictionary, local_x: float, local_z: float) -> String:
	var resolution := int(properties["resolution"])
	var width := float(properties["width"])
	var depth := float(properties["depth"])
	var x := clampi(roundi((local_x / width + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var z := clampi(roundi((local_z / depth + 0.5) * float(resolution - 1)), 0, resolution - 1)
	var types := properties["foliage_types"] as Array
	return FOLIAGE_PRESETS[clampi(int(types[z * resolution + x]), 0, FOLIAGE_PRESETS.size() - 1)]

static func normal_at(properties: Dictionary, local_x: float, local_z: float) -> Vector3:
	if not _has_normalized_topology(properties):
		normalize(properties)
	var resolution := int(properties["resolution"])
	var step_x := float(properties["width"]) / float(resolution - 1)
	var step_z := float(properties["depth"]) / float(resolution - 1)
	var left := height_at_normalized(properties, local_x - step_x, local_z)
	var right := height_at_normalized(properties, local_x + step_x, local_z)
	var back := height_at_normalized(properties, local_x, local_z - step_z)
	var front := height_at_normalized(properties, local_x, local_z + step_z)
	return Vector3((left - right) / step_x, 2.0, (back - front) / step_z).normalized()

static func height_at(properties: Dictionary, local_x: float, local_z: float) -> float:
	if not _has_normalized_topology(properties):
		normalize(properties)
	return height_at_normalized(properties, local_x, local_z)

static func height_at_normalized(properties: Dictionary, local_x: float, local_z: float) -> float:
	var resolution := int(properties["resolution"])
	var width := float(properties["width"])
	var depth := float(properties["depth"])
	var grid_x := clampf((local_x / width + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var grid_z := clampf((local_z / depth + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var x0 := floori(grid_x)
	var z0 := floori(grid_z)
	var x1 := mini(resolution - 1, x0 + 1)
	var z1 := mini(resolution - 1, z0 + 1)
	var tx := grid_x - float(x0)
	var tz := grid_z - float(z0)
	var heights := properties["heights"] as Array
	var top := lerpf(float(heights[z0 * resolution + x0]), float(heights[z0 * resolution + x1]), tx)
	var bottom := lerpf(float(heights[z1 * resolution + x0]), float(heights[z1 * resolution + x1]), tx)
	return lerpf(top, bottom, tz)

static func contains_local_point(properties: Dictionary, local_x: float, local_z: float) -> bool:
	var width := float(properties.get("width", int(properties.get("resolution", DEFAULT_RESOLUTION)) - 1))
	var depth := float(properties.get("depth", int(properties.get("resolution", DEFAULT_RESOLUTION)) - 1))
	return absf(local_x) <= width * 0.5 and absf(local_z) <= depth * 0.5

static func local_bounds(properties: Dictionary) -> AABB:
	normalize(properties)
	var resolution := int(properties["resolution"])
	var heights := properties["heights"] as Array
	var minimum := 0.0
	var maximum := 0.0
	if not heights.is_empty():
		minimum = float(heights[0])
		maximum = minimum
		for value: Variant in heights:
			minimum = minf(minimum, float(value))
			maximum = maxf(maximum, float(value))
	var width := float(properties["width"])
	var depth := float(properties["depth"])
	return AABB(Vector3(-width * 0.5, minimum, -depth * 0.5), Vector3(width, maxf(0.1, maximum - minimum), depth))

static func _build_mesh(properties: Dictionary, heights: PackedFloat32Array) -> ArrayMesh:
	var resolution := int(properties["resolution"])
	var width := float(properties["width"])
	var depth := float(properties["depth"])
	var step_x := width / float(resolution - 1)
	var step_z := depth / float(resolution - 1)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(resolution * resolution)
	normals.resize(resolution * resolution)
	uvs.resize(resolution * resolution)
	colors.resize(resolution * resolution)
	var material_weights := properties.get("material_weights", []) as Array
	for z in range(resolution):
		for x in range(resolution):
			var index := z * resolution + x
			vertices[index] = Vector3(float(x) * step_x - width * 0.5, heights[index], float(z) * step_z - depth * 0.5)
			uvs[index] = Vector2(float(x) * step_x, float(z) * step_z) / 8.0
			colors[index] = Color(
				float(material_weights[index * 3]),
				float(material_weights[index * 3 + 1]),
				float(material_weights[index * 3 + 2]),
				1.0
			)
			var left := heights[z * resolution + maxi(0, x - 1)]
			var right := heights[z * resolution + mini(resolution - 1, x + 1)]
			var back := heights[maxi(0, z - 1) * resolution + x]
			var front := heights[mini(resolution - 1, z + 1) * resolution + x]
			normals[index] = Vector3((left - right) / step_x, 2.0, (back - front) / step_z).normalized()
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var a := z * resolution + x
			var b := a + 1
			var c := a + resolution
			var d := c + 1
			# Godot considers clockwise triangles front-facing. Keep the top of the
			# heightfield visible while preserving upward-facing vertex normals.
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _packed_heights(properties: Dictionary) -> PackedFloat32Array:
	var source := properties.get("heights", []) as Array
	var result := PackedFloat32Array()
	result.resize(source.size())
	for index in range(source.size()):
		result[index] = float(source[index])
	return result

static func _neighbor_average(source: Array, resolution: int, x: int, z: int) -> float:
	var total := 0.0
	var count := 0
	for neighbor_z in range(maxi(0, z - 1), mini(resolution - 1, z + 1) + 1):
		for neighbor_x in range(maxi(0, x - 1), mini(resolution - 1, x + 1) + 1):
			total += float(source[neighbor_z * resolution + neighbor_x])
			count += 1
	return total / maxf(1.0, float(count))

static func _update_size(properties: Dictionary) -> void:
	var bounds := local_bounds_without_normalize(properties)
	properties["size"] = [bounds.size.x, bounds.size.y, bounds.size.z]

static func local_bounds_without_normalize(properties: Dictionary) -> AABB:
	var resolution := int(properties.get("resolution", DEFAULT_RESOLUTION))
	var heights := properties.get("heights", []) as Array
	var minimum := 0.0
	var maximum := 0.0
	if not heights.is_empty():
		minimum = float(heights[0])
		maximum = minimum
		for value: Variant in heights:
			minimum = minf(minimum, float(value))
			maximum = maxf(maximum, float(value))
	var width := float(properties.get("width", resolution - 1))
	var depth := float(properties.get("depth", resolution - 1))
	return AABB(Vector3(-width * 0.5, minimum, -depth * 0.5), Vector3(width, maxf(0.1, maximum - minimum), depth))

static func _normalize_float_array(source_value: Variant, expected: int, minimum: float, maximum: float) -> Array[float]:
	var source := source_value as Array
	var result: Array[float] = []
	result.resize(expected)
	for index in range(expected):
		result[index] = clampf(float(source[index]), minimum, maximum) if index < source.size() else minimum
	return result

static func _has_normalized_topology(properties: Dictionary) -> bool:
	var resolution := int(properties.get("resolution", 0))
	if resolution < MIN_RESOLUTION or not properties.has("width") or not properties.has("depth"):
		return false
	return (properties.get("heights", []) as Array).size() == resolution * resolution \
		and (properties.get("material_weights", []) as Array).size() == resolution * resolution * 3 \
		and (properties.get("foliage_density", []) as Array).size() == resolution * resolution \
		and (properties.get("foliage_types", []) as Array).size() == resolution * resolution

static func _available_material_slot(layers: Array, weights: Array) -> int:
	for index in range(3):
		if index >= layers.size() or String(layers[index]).is_empty():
			return index
	var totals := [0.0, 0.0, 0.0]
	for index in range(weights.size()):
		totals[index % 3] += float(weights[index])
	var weakest := 0
	for index in range(1, 3):
		if float(totals[index]) < float(totals[weakest]):
			weakest = index
	return weakest

static func _paint_grid_values(properties: Dictionary, local_position: Vector3, radius: float, operation: Callable) -> bool:
	var resolution := int(properties["resolution"])
	var width := float(properties["width"])
	var depth := float(properties["depth"])
	var step_x := width / float(resolution - 1)
	var step_z := depth / float(resolution - 1)
	var safe_radius := clampf(radius, 0.5, 48.0)
	var center_x := (local_position.x / width + 0.5) * float(resolution - 1)
	var center_z := (local_position.z / depth + 0.5) * float(resolution - 1)
	var radius_x := safe_radius / step_x
	var radius_z := safe_radius / step_z
	var changed := false
	for z in range(maxi(0, floori(center_z - radius_z)), mini(resolution - 1, ceili(center_z + radius_z)) + 1):
		for x in range(maxi(0, floori(center_x - radius_x)), mini(resolution - 1, ceili(center_x + radius_x)) + 1):
			var distance := Vector2((float(x) - center_x) * step_x, (float(z) - center_z) * step_z).length()
			if distance > safe_radius:
				continue
			var falloff := 1.0 - distance / safe_radius
			falloff = falloff * falloff * (3.0 - 2.0 * falloff)
			if bool(operation.call(z * resolution + x, falloff)):
				changed = true
	return changed

static func _sample_grid(source: Array, resolution: int, local_x: float, local_z: float, width: float, depth: float, component: int) -> float:
	var stride := maxi(1, int(source.size() / maxi(1, resolution * resolution)))
	var grid_x := clampf((local_x / width + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var grid_z := clampf((local_z / depth + 0.5) * float(resolution - 1), 0.0, float(resolution - 1))
	var x0 := floori(grid_x)
	var z0 := floori(grid_z)
	var x1 := mini(resolution - 1, x0 + 1)
	var z1 := mini(resolution - 1, z0 + 1)
	var tx := grid_x - float(x0)
	var tz := grid_z - float(z0)
	var top := lerpf(float(source[(z0 * resolution + x0) * stride + component]), float(source[(z0 * resolution + x1) * stride + component]), tx)
	var bottom := lerpf(float(source[(z1 * resolution + x0) * stride + component]), float(source[(z1 * resolution + x1) * stride + component]), tx)
	return lerpf(top, bottom, tz)

static func _resample_grid(source: Array, old_resolution: int, new_resolution: int, components: int) -> Array[float]:
	var result: Array[float] = []
	result.resize(new_resolution * new_resolution * components)
	for z in range(new_resolution):
		var source_z := float(z) / float(new_resolution - 1) * float(old_resolution - 1)
		var z0 := floori(source_z)
		var z1 := mini(old_resolution - 1, z0 + 1)
		var tz := source_z - float(z0)
		for x in range(new_resolution):
			var source_x := float(x) / float(new_resolution - 1) * float(old_resolution - 1)
			var x0 := floori(source_x)
			var x1 := mini(old_resolution - 1, x0 + 1)
			var tx := source_x - float(x0)
			for component in range(components):
				var top := lerpf(float(source[(z0 * old_resolution + x0) * components + component]), float(source[(z0 * old_resolution + x1) * components + component]), tx)
				var bottom := lerpf(float(source[(z1 * old_resolution + x0) * components + component]), float(source[(z1 * old_resolution + x1) * components + component]), tx)
				result[(z * new_resolution + x) * components + component] = lerpf(top, bottom, tz)
	return result

static func _resample_foliage_types(source: Array, source_density: Array, old_resolution: int, new_resolution: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(new_resolution * new_resolution)
	for z in range(new_resolution):
		var source_z_float := float(z) / float(new_resolution - 1) * float(old_resolution - 1)
		var source_z_min := clampi(floori(source_z_float), 0, old_resolution - 1)
		var source_z_max := mini(source_z_min + 1, old_resolution - 1)
		for x in range(new_resolution):
			var source_x_float := float(x) / float(new_resolution - 1) * float(old_resolution - 1)
			var source_x_min := clampi(floori(source_x_float), 0, old_resolution - 1)
			var source_x_max := mini(source_x_min + 1, old_resolution - 1)
			var best_source_index := source_z_min * old_resolution + source_x_min
			var best_density := float(source_density[best_source_index])
			for source_z: int in [source_z_min, source_z_max]:
				for source_x: int in [source_x_min, source_x_max]:
					var source_index: int = source_z * old_resolution + source_x
					var density := float(source_density[source_index])
					if density > best_density:
						best_density = density
						best_source_index = source_index
			result[z * new_resolution + x] = int(source[best_source_index])
	return result
