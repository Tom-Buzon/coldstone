extends Node3D

const Energy = preload("res://scripts/abilities/skill_energy.gdshader")
const Javelin = preload("res://scripts/abilities/electric_javelin.gd")
var held_javelin: Node3D
var runtime: Node
var shell: MeshInstance3D
var energy: ShaderMaterial
var blade: MeshInstance3D
var blade_material: StandardMaterial3D
var accents: Array[Dictionary] = []
var trail_clock := 0.0
var sparks: CPUParticles3D
var spark_material: StandardMaterial3D
var sprays: Array[Dictionary] = []
var phase := 0.0
var last_trail := Vector3.ZERO

static func color_for(kind: StringName) -> Color:
	match kind:
		&"aura": return Color(1.0, 0.73, 0.10)
		&"flame": return Color(1.0, 0.22, 0.035)
		&"thunder": return Color(0.20, 0.78, 1.0)
		&"ares": return Color(1.0, 0.075, 0.13)
		&"plunge": return Color(0.38, 0.85, 1.0)
	return Color(1.0, 0.78, 0.2)

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _ready() -> void:
	held_javelin = Javelin.new()
	add_child(held_javelin)
	held_javelin.visible = false
	add_to_group(&"camera_occlusion_ignore")
	shell = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.78
	mesh.height = 2.8
	mesh.radial_segments = 24
	mesh.rings = 12
	shell.mesh = mesh
	shell.position.y = 1.2
	energy = ShaderMaterial.new()
	energy.shader = Energy
	shell.material_override = energy
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	blade = MeshInstance3D.new()
	var edge := BoxMesh.new()
	edge.size = Vector3(4.4, 0.055, 0.25)
	blade.mesh = edge
	blade_material = material(Color(1, 0.85, 0.3))
	blade.material_override = blade_material
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blade)
	sparks = CPUParticles3D.new()
	sparks.amount = 48
	sparks.lifetime = 0.55
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.65
	sparks.position.y = 0.8
	sparks.direction = Vector3.UP
	sparks.spread = 12
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3.UP
	var spark := CylinderMesh.new()
	spark.height = 0.28
	spark.top_radius = 0.005
	spark.bottom_radius = 0.022
	spark.radial_segments = 4
	spark_material = material(Color(1, 0.7, 0.1))
	spark.material = spark_material
	sparks.mesh = spark
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.7))
	ramp.set_color(1, Color(1, 1, 1, 0))
	sparks.color_ramp = ramp
	spark_material.vertex_color_use_as_albedo = true
	add_child(sparks)

func _process(delta: float) -> void:
	var real_delta := minf(delta / maxf(Engine.time_scale, 0.001), 0.05)
	phase += real_delta
	held_javelin.visible = runtime.ultimate == &"thunder"
	if held_javelin.visible:
		var camera: Camera3D = runtime.player.camera
		var forward: Vector3 = -camera.get_camera_transform().basis.z
		held_javelin.global_position = runtime.javelin_origin()
		held_javelin.look_at(held_javelin.global_position + forward, Vector3.RIGHT if absf(forward.y) > 0.98 else Vector3.UP)
		held_javelin.set_charge(runtime.thunder_charge)
	var kind: StringName = runtime.ultimate
	var powered: bool = kind != &"" or runtime.plunge_active
	shell.visible = powered
	sparks.emitting = powered
	if powered:
		if runtime.plunge_active: kind = &"plunge"
		spark_material.albedo_color = color_for(kind)
		energy.set_shader_parameter("tint", color_for(kind))
		energy.set_shader_parameter("strength", 0.8 + 0.2 * sin(phase * 13.0))
		shell.rotation.y += real_delta * (2.4 if kind == &"aura" else -0.8)
		var growth: float = 1.0 + (1.0 - runtime.cast_remaining / maxf(runtime.value(&"flame_cast"), 0.1)) * 0.3 if kind == &"flame" else 1.0
		shell.scale = Vector3.ONE * growth
	blade.visible = runtime.active(&"edge") and runtime.controls.edge_down and not runtime.ranged_active
	if blade.visible:
		var forward: Vector3 = Vector3(runtime.player.velocity.x, 0, runtime.player.velocity.z).normalized()
		if forward.length_squared() < 0.01: forward = runtime.player._camera_forward_flat()
		blade.global_position = runtime.player.global_position + Vector3.UP * 1.1
		blade.look_at(blade.global_position + forward)
		blade_material.albedo_color = Color(1, 0.95, 0.55, 1.0) if runtime.edge_active else Color(1, 0.65, 0.12, 0.28)
	trail_clock -= real_delta
	if trail_clock <= 0.0:
		trail_clock = 0.045
		var current: Vector3 = runtime.player.global_position + Vector3.UP
		if powered and last_trail.distance_to(current) > 0.12 and last_trail.distance_to(current) < 8.0:
			beam(last_trail, current, color_for(kind), 0.16 if kind == &"aura" else 0.08, 0.24)
		if runtime.edge_active:
			var right: Vector3 = blade.global_basis.x
			beam(blade.global_position - right * 2.2, blade.global_position + right * 2.2, Color(1, 0.8, 0.2), 0.08, 0.18)
		last_trail = current
	for i: int in range(sprays.size() - 1, -1, -1):
		sprays[i].ttl -= real_delta
		if sprays[i].ttl <= 0:
			if is_instance_valid(sprays[i].node): sprays[i].node.queue_free()
			sprays.remove_at(i)
	for i: int in range(accents.size() - 1, -1, -1):
		var entry: Dictionary = accents[i]
		entry.age += real_delta
		var node: MeshInstance3D = entry.node
		if not is_instance_valid(node):
			accents.remove_at(i)
			continue
		var t: float = clampf(entry.age / entry.life, 0.0, 1.0)
		if entry.grow > 0:
			var s: float = lerpf(0.15, entry.grow, 1.0 - pow(1.0 - t, 3.0))
			node.scale = Vector3.ONE * s if node.get_meta(&"isotropic", false) else Vector3(s, 1, s)
		var mat := node.material_override as StandardMaterial3D
		mat.albedo_color.a = float(entry.get("alpha", 1.0)) * (1.0 - smoothstep(float(entry.get("fade_start", 0.0)), 1.0, t))
		if t >= 1.0:
			node.queue_free()
			accents.remove_at(i)

func _register(mesh: Mesh, position: Vector3, color: Color, life: float, grow: float = 0.0) -> MeshInstance3D:
	# Bound simultaneous transient geometry, including chain kills.
	if accents.size() >= 96:
		var old: Dictionary = accents.pop_front()
		if is_instance_valid(old.node): old.node.queue_free()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	add_child(node)
	node.global_position = position
	accents.append({"node": node, "life": life, "age": 0.0, "grow": grow, "alpha": color.a})
	return node

func beam(from: Vector3, to: Vector3, color: Color, width: float, life: float) -> void:
	if from.distance_squared_to(to) < 0.001: return
	var mesh := CylinderMesh.new()
	mesh.top_radius = width * 0.3
	mesh.bottom_radius = width
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 6
	var node := _register(mesh, (from + to) * 0.5, color, life)
	var direction := (to - from).normalized()
	var right := direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01: right = Vector3.RIGHT
	node.global_basis = Basis(right, direction, right.cross(direction))

func burst(point: Vector3, color: Color, radius: float, debris: bool) -> void:
	for i: int in (3 if debris else 1):
		var ring := TorusMesh.new()
		ring.inner_radius = 0.90
		ring.outer_radius = 1.0
		ring.rings = 48
		ring.ring_segments = 6
		_register(ring, point + Vector3.UP * (0.08 + i * 0.10), color, 0.6 + i * 0.16, radius * (1.0 - i * 0.15))
	if debris:
		_dust(point, radius)
		for i: int in 12:
			var d := Vector3(cos(i * TAU / 12), 0, sin(i * TAU / 12))
			beam(point + d * 0.5, point + d * radius * 0.75 + Vector3.UP * (0.3 + (i % 4) * 0.3), color, 0.035, 0.26)

func thunder(from: Vector3, to: Vector3) -> void:
	var color := color_for(&"thunder")
	beam(from, to, color, 0.13, 0.35)
	var direction := (to - from).normalized()
	var side := direction.cross(Vector3.UP).normalized()
	var previous := from
	for i: int in range(1, 9):
		var point := from.lerp(to, i / 8.0) + side * sin(i * 2.1) * 0.30
		beam(previous, point, Color(0.75, 0.93, 1), 0.035, 0.22)
		previous = point
	burst(to, color, 1.1, true)

func _dust(point: Vector3, radius: float) -> void:
	if sprays.size() >= 6: return
	var particles := CPUParticles3D.new()
	particles.top_level = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 54
	particles.lifetime = 0.85
	particles.direction = Vector3.UP
	particles.spread = 78
	particles.initial_velocity_min = radius * 0.65
	particles.initial_velocity_max = radius * 1.4
	particles.gravity = Vector3(0, -12, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.5
	var stone := BoxMesh.new()
	stone.size = Vector3(0.10, 0.08, 0.12)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.38, 0.3, 0.22)
	stone.material = dust_mat
	particles.mesh = stone
	add_child(particles)
	particles.global_position = point + Vector3.UP * 0.12
	particles.emitting = true
	sprays.append({"node": particles, "ttl": 1.0})

func electric_explosion(point: Vector3, radius: float) -> void:
	var previous_ids := {}
	for entry: Dictionary in accents: previous_ids[entry.node.get_instance_id()] = true
	var cyan := color_for(&"thunder")
	burst(point, cyan, radius, true)
	var orb := SphereMesh.new()
	orb.radius = 0.5
	orb.height = 1.0
	orb.radial_segments = 24
	orb.rings = 12
	_register(orb, point, Color(0.7, 0.95, 1, 0.45), 0.45, radius * 1.2).set_meta(&"isotropic", true)
	# Radial branching bolts outline the real damage radius in all directions.
	for i: int in 12:
		var radial := Vector3(cos(i * TAU / 12), 0, sin(i * TAU / 12))
		var side := radial.cross(Vector3.UP)
		var previous := point
		for j: int in range(1, 5):
			var end := point + radial * radius * j / 4.0 + side * sin(i * 1.7 + j * 2.2) * radius * 0.12 + Vector3.UP * sin(j * PI / 4) * radius * 0.35
			beam(previous, end, Color(0.65, 0.93, 1), 0.08 if j < 3 else 0.045, 0.8)
			previous = end
	beam(point, point + Vector3.UP * radius * 2.5, cyan, 0.45, 0.65)

	for entry: Dictionary in accents:
		if previous_ids.has(entry.node.get_instance_id()): continue
		entry.life = maxf(entry.life, 1.35)
		entry["fade_start"] = 0.25
