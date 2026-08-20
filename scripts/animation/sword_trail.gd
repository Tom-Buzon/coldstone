extends Node3D
class_name HopliteNativeSwordTrail

var mesh_instance: MeshInstance3D
var immediate: ImmediateMesh
var material: StandardMaterial3D
var samples: Array[Dictionary] = []
var lifetime: float = 0.18
var width: float = 0.075

func _ready() -> void:
    top_level = true
    global_transform = Transform3D.IDENTITY
    immediate = ImmediateMesh.new()
    mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = immediate
    add_child(mesh_instance)
    material = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

func push_point(world_position: Vector3, heavy: bool = false) -> void:
    if not samples.is_empty():
        var previous: Vector3 = samples[samples.size() - 1]["position"]
        if previous.distance_to(world_position) < 0.02:
            return
    samples.append({"position": world_position, "age": 0.0, "heavy": heavy})
    while samples.size() > 24:
        samples.pop_front()

func clear_fast() -> void:
    for sample: Dictionary in samples:
        sample["age"] = maxf(float(sample["age"]), lifetime * 0.65)

func _process(delta: float) -> void:
    for sample: Dictionary in samples:
        sample["age"] = float(sample["age"]) + delta
    while not samples.is_empty() and float(samples[0]["age"]) >= lifetime:
        samples.pop_front()
    _rebuild()

func _rebuild() -> void:
    immediate.clear_surfaces()
    if samples.size() < 2:
        return
    immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
    for i: int in range(samples.size() - 1):
        var a: Vector3 = samples[i]["position"]
        var b: Vector3 = samples[i + 1]["position"]
        var tangent: Vector3 = b - a
        if tangent.length() < 0.001:
            continue
        tangent = tangent.normalized()
        var side: Vector3 = tangent.cross(Vector3.UP)
        if side.length() < 0.08:
            side = tangent.cross(Vector3.RIGHT)
        side = side.normalized()
        var age0: float = clampf(float(samples[i]["age"]) / lifetime, 0.0, 1.0)
        var age1: float = clampf(float(samples[i + 1]["age"]) / lifetime, 0.0, 1.0)
        var heavy0: bool = bool(samples[i]["heavy"])
        var heavy1: bool = bool(samples[i + 1]["heavy"])
        var w0: float = width * (1.0 - age0 * 0.55) * (1.65 if heavy0 else 1.0)
        var w1: float = width * (1.0 - age1 * 0.55) * (1.65 if heavy1 else 1.0)
        var c0: Color = _trail_color(age0, heavy0)
        var c1: Color = _trail_color(age1, heavy1)
        _vertex(a - side * w0, c0)
        _vertex(a + side * w0, c0)
        _vertex(b + side * w1, c1)
        _vertex(a - side * w0, c0)
        _vertex(b + side * w1, c1)
        _vertex(b - side * w1, c1)
    immediate.surface_end()

func _vertex(position: Vector3, color: Color) -> void:
    immediate.surface_set_color(color)
    immediate.surface_add_vertex(position)

func _trail_color(age: float, heavy: bool) -> Color:
    var alpha: float = pow(1.0 - age, 1.25) * 0.95
    if heavy:
        return Color(1.0, 0.18, 0.025, alpha)
    return Color(1.0, 0.82, 0.30, alpha)
