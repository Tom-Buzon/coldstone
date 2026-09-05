extends RefCounted
class_name EnemyV2FormationFootprint

var owner_id: StringName = &""
var center := Vector3.ZERO
var forward := Vector3.FORWARD
var width: float = 1.0
var depth: float = 1.0


func configure(
	owner_value: StringName,
	center_value: Vector3,
	forward_value: Vector3,
	width_value: float,
	depth_value: float
) -> RefCounted:
	owner_id = owner_value
	center = center_value
	forward = Vector3(forward_value.x, 0.0, forward_value.z)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	width = maxf(0.5, width_value)
	depth = maxf(0.5, depth_value)
	return self


## Separating-axis test in XZ. The signed depth is useful when recovering an
## existing overlap: accept movement only when it reduces the penetration.
func overlap_depth(other: RefCounted, margin: float = 0.0) -> float:
	var right := Vector3.UP.cross(forward)
	var other_forward: Vector3 = other.get("forward")
	var other_right := Vector3.UP.cross(other_forward)
	var offset: Vector3 = other.get("center") - center
	var minimum := INF
	for axis: Vector3 in [right, forward, other_right, other_forward]:
		var self_radius := absf(axis.dot(right)) * width * 0.5 + absf(axis.dot(forward)) * depth * 0.5
		var other_radius := absf(axis.dot(other_right)) * float(other.get("width")) * 0.5 + absf(axis.dot(other_forward)) * float(other.get("depth")) * 0.5
		var penetration := self_radius + other_radius + margin - absf(offset.dot(axis))
		if penetration <= 0.0:
			return 0.0
		minimum = minf(minimum, penetration)
	return minimum


func overlaps(other: RefCounted, margin: float = 0.0) -> bool:
	return overlap_depth(other, margin) > 0.0


func covered_cells(cell_size: float, extra_margin: float = 0.0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var safe_cell_size := maxf(0.5, cell_size)
	var right := Vector3.UP.cross(forward).normalized()
	var half_width := width * 0.5 + maxf(0.0, extra_margin)
	var half_depth := depth * 0.5 + maxf(0.0, extra_margin)
	var corners: Array[Vector3] = [
		center + right * half_width + forward * half_depth,
		center + right * half_width - forward * half_depth,
		center - right * half_width + forward * half_depth,
		center - right * half_width - forward * half_depth,
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner: Vector3 in corners:
		minimum.x = minf(minimum.x, corner.x)
		minimum.y = minf(minimum.y, corner.z)
		maximum.x = maxf(maximum.x, corner.x)
		maximum.y = maxf(maximum.y, corner.z)
	var minimum_cell := Vector2i(floori(minimum.x / safe_cell_size), floori(minimum.y / safe_cell_size))
	var maximum_cell := Vector2i(floori(maximum.x / safe_cell_size), floori(maximum.y / safe_cell_size))
	for cell_x: int in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y: int in range(minimum_cell.y, maximum_cell.y + 1):
			var sample := Vector3(
				(float(cell_x) + 0.5) * safe_cell_size,
				center.y,
				(float(cell_y) + 0.5) * safe_cell_size
			)
			var offset := sample - center
			if absf(offset.dot(right)) <= half_width + safe_cell_size * 0.72 and absf(offset.dot(forward)) <= half_depth + safe_cell_size * 0.72:
				result.append(Vector2i(cell_x, cell_y))
	return result
