extends Node3D
class_name HopliteWorldEditorGrid

var grid_size := 1.0
var half_extent := 60.0
var minor_mesh: MeshInstance3D
var major_mesh: MeshInstance3D
var axis_mesh: MeshInstance3D

func _ready() -> void:
	name = "BlenderStyleGrid"
	position.y = 0.40
	_build()

func set_grid_size(value: float) -> void:
	grid_size = clampf(value, 0.25, 10.0)
	_build()

func set_half_extent(value: float) -> void:
	half_extent = clampf(value, 20.0, 1000.0)
	_build()

func _build() -> void:
	_clear_meshes()
	minor_mesh = _lines(_minor_segments(), Color(0.48, 0.56, 0.66, 0.22), 0.8)
	major_mesh = _lines(_major_segments(), Color(0.66, 0.72, 0.80, 0.42), 1.15)
	axis_mesh = _lines([
		Vector3(-half_extent, 0.016, 0), Vector3(half_extent, 0.016, 0),
		Vector3(0, 0.017, -half_extent), Vector3(0, 0.017, half_extent)
	], Color.WHITE, 1.7)
	add_child(minor_mesh)
	add_child(major_mesh)
	add_child(axis_mesh)
	var immediate := axis_mesh.mesh as ImmediateMesh
	if immediate != null:
		# A second pair of colored axes gives the familiar Blender orientation.
		var red := _material(Color(0.92, 0.20, 0.18, 0.90), 2.1)
		immediate.surface_begin(Mesh.PRIMITIVE_LINES, red)
		immediate.surface_add_vertex(Vector3.ZERO + Vector3.UP * 0.019)
		immediate.surface_add_vertex(Vector3(half_extent, 0.019, 0))
		immediate.surface_end()
		var blue := _material(Color(0.20, 0.48, 1.0, 0.92), 2.1)
		immediate.surface_begin(Mesh.PRIMITIVE_LINES, blue)
		immediate.surface_add_vertex(Vector3.ZERO + Vector3.UP * 0.020)
		immediate.surface_add_vertex(Vector3(0, 0.020, half_extent))
		immediate.surface_end()

func _minor_segments() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var half_cells := floori(half_extent / grid_size)
	var extent := float(half_cells) * grid_size
	for index in range(-half_cells, half_cells + 1):
		if index % 5 == 0:
			continue
		var offset := float(index) * grid_size
		result.append(Vector3(-extent, 0.012, offset))
		result.append(Vector3(extent, 0.012, offset))
		result.append(Vector3(offset, 0.012, -extent))
		result.append(Vector3(offset, 0.012, extent))
	return result

func _major_segments() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var half_cells := floori(half_extent / grid_size)
	var extent := float(half_cells) * grid_size
	for index in range(-half_cells, half_cells + 1, 5):
		var offset := float(index) * grid_size
		result.append(Vector3(-extent, 0.014, offset))
		result.append(Vector3(extent, 0.014, offset))
		result.append(Vector3(offset, 0.014, -extent))
		result.append(Vector3(offset, 0.014, extent))
	return result

func _lines(segments: Array[Vector3], color: Color, width: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, _material(color, width))
	for vertex: Vector3 in segments:
		immediate.surface_add_vertex(vertex)
	immediate.surface_end()
	instance.mesh = immediate
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _material(color: Color, width: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = false
	material.vertex_color_use_as_albedo = true
	material.set_meta("line_width", width)
	return material

func _clear_meshes() -> void:
	for child: Node in get_children():
		child.queue_free()
