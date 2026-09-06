extends Node3D

var charge := 0.0
var shaft: MeshInstance3D
var head: MeshInstance3D
var corona: MeshInstance3D
var lightning: ImmediateMesh
var arc_timer := 0.0
var phase := 0.0

func _ready() -> void:
	add_to_group(&"camera_occlusion_ignore")
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(0.80, 0.96, 1.0)
	var blue := white.duplicate() as StandardMaterial3D
	blue.albedo_color = Color(0.08, 0.56, 1)
	shaft = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = 0.04
	cylinder.bottom_radius = 0.04
	cylinder.radial_segments = 8
	shaft.mesh = cylinder
	shaft.rotation.x = PI * 0.5
	shaft.material_override = white
	add_child(shaft)
	head = MeshInstance3D.new()
	var tip := CylinderMesh.new()
	tip.height = 0.65
	tip.top_radius = 0.0
	tip.bottom_radius = 0.19
	tip.radial_segments = 4
	head.mesh = tip
	head.rotation.x = -PI * 0.5
	head.material_override = white
	add_child(head)
	corona = MeshInstance3D.new()
	var halo := SphereMesh.new()
	halo.radius = 0.17
	halo.height = 1.0
	halo.radial_segments = 12
	halo.rings = 6
	corona.mesh = halo
	corona.rotation.x = PI * 0.5
	var glow := blue.duplicate() as StandardMaterial3D
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color.a = 0.24
	corona.material_override = glow
	add_child(corona)
	lightning = ImmediateMesh.new()
	var arcs := MeshInstance3D.new()
	arcs.mesh = lightning
	arcs.material_override = blue
	add_child(arcs)
	for child: Node in get_children():
		if child is GeometryInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	refresh(0.0)

func set_charge(value: float) -> void:
	charge = clampf(value, 0.0, 1.0)
	if shaft != null: refresh(0.0)

func _process(delta: float) -> void:
	refresh(minf(delta / maxf(Engine.time_scale, 0.01), 0.05))

func refresh(delta: float) -> void:
	phase += delta
	var length := lerpf(1.7, 4.8, charge)
	var width := lerpf(1.0, 2.8, charge)
	shaft.scale = Vector3(width, length, width)
	head.scale = Vector3.ONE * lerpf(0.8, 1.8, charge)
	head.position.z = -length * 0.5 - 0.20
	corona.scale = Vector3(width, length + 0.5, width)
	arc_timer -= delta
	if arc_timer > 0.0: return
	arc_timer = 1.0 / 24.0
	lightning.clear_surfaces()
	lightning.surface_begin(Mesh.PRIMITIVE_LINES)
	for strand: int in 4:
		var previous := Vector3(0, 0, length * 0.5)
		for i: int in range(1, 17):
			var t := i / 16.0
			var angle := strand * PI * 0.5 + t * TAU * 2.0 + phase * 18
			var radius := sin(t * PI) * (0.12 + charge * 0.24) * (0.7 + 0.3 * sin(i * 17 + phase * 31))
			var point := Vector3(cos(angle) * radius, sin(angle) * radius, lerpf(length * 0.5, -length * 0.5 - 0.5, t))
			lightning.surface_add_vertex(previous)
			lightning.surface_add_vertex(point)
			previous = point
	lightning.surface_end()
