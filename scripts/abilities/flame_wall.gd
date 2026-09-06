extends Node3D

const Damage = preload("res://scripts/abilities/skill_damage.gd")
const FlameShader = preload("res://scripts/abilities/flame_wall.gdshader")
static var walls: Array[Node3D] = []
var source: Node3D
var length := 15.0
var duration := 15.0
var dps := 36.0
var burn_duration := 3.0
var elapsed := 0.0
var tick := 0.0
var burning: Dictionary = {}
var flames: CPUParticles3D
var flame_material: ShaderMaterial

func _ready() -> void:
	walls.append(self)
	add_to_group(&"camera_occlusion_ignore")
	flame_material = ShaderMaterial.new()
	flame_material.shader = FlameShader
	flame_material.set_shader_parameter("wall_length", length)
	# Three shared-material sheets give the barrier volume from either side.
	for side: int in 3:
		var sheet := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(length, 2.8)
		sheet.mesh = quad
		sheet.material_override = flame_material
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.position = Vector3((side - 1) * 0.3, 1.4, -length * 0.5)
		sheet.rotation.y = PI * 0.5
		add_child(sheet)
	flames = CPUParticles3D.new()
	flames.amount = 80
	flames.lifetime = 0.8
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(0.35, 0.05, length * 0.5)
	flames.position.z = -length * 0.5
	flames.direction = Vector3.UP
	flames.spread = 18.0
	flames.initial_velocity_min = 3.0
	flames.initial_velocity_max = 5.0
	flames.gravity = Vector3(0, 0.4, 0)
	flames.scale_amount_min = 0.025
	flames.scale_amount_max = 0.07
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	flames.mesh = mesh
	var colors := Gradient.new()
	colors.set_color(0, Color(1, 0.85, 0.25, 0.95))
	colors.set_color(1, Color(0.6, 0.04, 0.01, 0.0))
	flames.color_ramp = colors
	add_child(flames)

func _exit_tree() -> void:
	walls.erase(self)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	elapsed += delta
	flames.emitting = elapsed < duration
	flame_material.set_shader_parameter("strength", minf(elapsed / 0.15, clampf((duration - elapsed) / 0.4, 0.0, 1.0)))
	tick += delta
	if tick < 0.20: return
	var step := tick
	tick = 0.0
	if elapsed < duration:
		for node: Node in get_tree().get_nodes_in_group(&"enemy"):
			if not node is Node3D or not Damage.alive(node): continue
			var local := to_local(node.global_position)
			if absf(local.x) <= 0.85 and local.z <= 0.5 and local.z >= -length - 0.5 and absf(local.y) <= 2.5:
				burning[node.get_instance_id()] = burn_duration + step
	for id: int in burning.keys():
		var target := instance_from_id(id) as Node3D
		if not Damage.alive(target):
			burning.erase(id)
			continue
		burning[id] -= step
		Damage.deal(source, target, dps * step, target.global_position - global_position, 0.0, &"burn")
		if burning[id] <= 0.0: burning.erase(id)
	if elapsed > duration + 1.0 and burning.is_empty(): queue_free()

static func avoid(body: Node3D, desired: Vector3, delta: float) -> Vector3:
	var result := desired
	for wall: Node3D in walls:
		if not is_instance_valid(wall) or wall.elapsed >= wall.duration: continue
		var p: Vector3 = wall.to_local(body.global_position)
		var future: Vector3 = wall.to_local(body.global_position + result * maxf(delta, 0.35))
		if absf(p.y) > 3.0 or p.z > 1.2 or p.z < -wall.length - 1.2: continue
		if absf(p.x) < 1.5 or (signf(p.x) != signf(future.x) and absf(future.x) < 2.0):
			var side := signf(p.x)
			if is_zero_approx(side): side = 1.0 if body.get_instance_id() % 2 == 0 else -1.0
			var local_velocity: Vector3 = wall.global_basis.inverse() * result
			# Respect the side of the barrier, flee its edge, and move toward an end.
			local_velocity.x = side * maxf(2.5, absf(local_velocity.x))
			local_velocity.z = 2.0 if p.z > -wall.length * 0.5 else -2.0
			result = wall.global_basis * local_velocity
	return result
