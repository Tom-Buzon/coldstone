extends Node3D
class_name HopliteBloodBurst

# The three visible layers are retained exactly. Nodes, meshes and process
# materials are now built once and rearmed by HopliteGoreDirector.
const PRIMARY_MAX_AMOUNT: int = 210
const MIST_MAX_AMOUNT: int = 120
const JET_MAX_AMOUNT: int = 150

static var _primary_mesh_normal: SphereMesh
static var _primary_mesh_sever: SphereMesh
static var _mist_mesh: SphereMesh
static var _jet_mesh: SphereMesh

var max_lifetime: float = 0.95
var active: bool = false

var _managed_release: Callable
var _expiry_timer: Timer
var _primary: GPUParticles3D
var _mist: GPUParticles3D
var _jet: GPUParticles3D
var _primary_process: ParticleProcessMaterial
var _mist_process: ParticleProcessMaterial
var _jet_process: ParticleProcessMaterial


func _ready() -> void:
	_ensure_emitters()
	if _managed_release.is_null():
		add_to_group(&"blood_fx")
	visible = false


func prepare_for_pool(release_callback: Callable) -> void:
	_managed_release = release_callback
	remove_from_group(&"blood_fx")
	_ensure_emitters()
	deactivate_to_pool()


func setup(world_position: Vector3, direction: Vector3, intensity: float = 1.0, sever: bool = false) -> void:
	activate(world_position, direction, intensity, sever)
	if _managed_release.is_null():
		_ensure_expiry_timer()
		_expiry_timer.start(max_lifetime)


func activate(world_position: Vector3, direction: Vector3, intensity: float = 1.0, sever: bool = false) -> void:
	_ensure_emitters()
	global_position = world_position
	var spray_direction := direction
	if spray_direction.length_squared() < 0.0001:
		spray_direction = Vector3.UP
	spray_direction = (spray_direction.normalized() + Vector3.UP * 0.08).normalized()
	global_basis = _basis_y_along(spray_direction)

	var strength := clampf(intensity, 0.60, 3.20)
	_configure_primary(strength, sever)
	_configure_mist(strength, sever)
	_configure_jet(strength, sever)
	max_lifetime = 1.05 if sever else 0.72
	active = true
	visible = true
	_primary.visible = true
	_mist.visible = true
	_jet.visible = sever
	_primary.restart()
	_primary.emitting = true
	_mist.restart()
	_mist.emitting = true
	if sever:
		_jet.restart()
		_jet.emitting = true
	else:
		_jet.emitting = false


func deactivate_to_pool() -> void:
	active = false
	visible = false
	if _expiry_timer != null:
		_expiry_timer.stop()
	_deactivate_particles(_primary)
	_deactivate_particles(_mist)
	_deactivate_particles(_jet)


func expire_now() -> void:
	if not _managed_release.is_null() and _managed_release.is_valid():
		_managed_release.call(self)
		return
	deactivate_to_pool()
	queue_free()


func _deactivate_particles(particles: GPUParticles3D) -> void:
	if particles == null:
		return
	particles.emitting = false
	particles.visible = false


func _ensure_emitters() -> void:
	if _primary != null:
		return
	_primary = _create_particles("BloodPrimarySpray", PRIMARY_MAX_AMOUNT)
	_primary_process = ParticleProcessMaterial.new()
	_primary.process_material = _primary_process
	add_child(_primary)

	_mist = _create_particles("BloodDenseMist", MIST_MAX_AMOUNT)
	_mist_process = ParticleProcessMaterial.new()
	_mist.process_material = _mist_process
	add_child(_mist)

	_jet = _create_particles("BloodArterialJet", JET_MAX_AMOUNT)
	_jet_process = ParticleProcessMaterial.new()
	_jet.process_material = _jet_process
	add_child(_jet)


func _create_particles(node_name: String, maximum_amount: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = maximum_amount
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	return particles


func _configure_primary(strength: float, sever: bool) -> void:
	var desired_amount := clampi(int(58.0 + strength * 28.0 + (72.0 if sever else 0.0)), 64, PRIMARY_MAX_AMOUNT)
	_primary.amount_ratio = float(desired_amount) / float(PRIMARY_MAX_AMOUNT)
	_primary.lifetime = 0.78 if sever else 0.56
	_primary.randomness = 0.62
	_primary.draw_pass_1 = _get_primary_mesh(sever)
	var process := _primary_process
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.070 if sever else 0.045
	process.direction = Vector3.UP
	process.spread = 28.0 if sever else 22.0
	process.initial_velocity_min = 4.8 * strength
	process.initial_velocity_max = 8.7 * strength + (2.6 if sever else 0.0)
	process.gravity = Vector3(0.0, -13.5, 0.0)
	process.damping_min = 0.15
	process.damping_max = 0.95
	process.scale_min = 0.70
	process.scale_max = 1.85
	process.color = Color(0.48, 0.001, 0.004, 0.99)


func _configure_mist(strength: float, sever: bool) -> void:
	var desired_amount := clampi(int(30.0 + strength * 17.0 + (44.0 if sever else 0.0)), 36, MIST_MAX_AMOUNT)
	_mist.amount_ratio = float(desired_amount) / float(MIST_MAX_AMOUNT)
	_mist.lifetime = 0.42 if sever else 0.31
	_mist.randomness = 0.84
	_mist.draw_pass_1 = _get_mist_mesh()
	var process := _mist_process
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12 if sever else 0.075
	process.direction = Vector3.UP
	process.spread = 58.0 if sever else 48.0
	process.initial_velocity_min = 2.0 * strength
	process.initial_velocity_max = 4.5 * strength + (1.7 if sever else 0.0)
	process.gravity = Vector3(0.0, -7.5, 0.0)
	process.damping_min = 1.0
	process.damping_max = 3.0
	process.scale_min = 0.75
	process.scale_max = 1.80
	process.color = Color(0.35, 0.0, 0.003, 0.78)


func _configure_jet(strength: float, sever: bool) -> void:
	_jet.amount_ratio = float(clampi(int(72.0 + strength * 26.0), 82, JET_MAX_AMOUNT)) / float(JET_MAX_AMOUNT)
	_jet.lifetime = 0.88
	_jet.explosiveness = 0.92
	_jet.randomness = 0.46
	_jet.draw_pass_1 = _get_jet_mesh()
	var process := _jet_process
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.035
	process.direction = Vector3.UP
	process.spread = 13.0
	process.initial_velocity_min = 7.0 * strength
	process.initial_velocity_max = 11.0 * strength
	process.gravity = Vector3(0.0, -14.0, 0.0)
	process.damping_min = 0.05
	process.damping_max = 0.55
	process.scale_min = 0.85
	process.scale_max = 2.1
	process.color = Color(0.50, 0.001, 0.003, 1.0)
	if not sever:
		_jet.emitting = false


func _ensure_expiry_timer() -> void:
	if _expiry_timer != null:
		return
	_expiry_timer = Timer.new()
	_expiry_timer.name = "ExpiryTimer"
	_expiry_timer.one_shot = true
	_expiry_timer.timeout.connect(expire_now)
	add_child(_expiry_timer)


func _get_primary_mesh(sever: bool) -> SphereMesh:
	if sever:
		if _primary_mesh_sever == null:
			_primary_mesh_sever = _create_drop_mesh(0.021, 0.060, Color(0.52, 0.002, 0.005, 0.99), false)
		return _primary_mesh_sever
	if _primary_mesh_normal == null:
		_primary_mesh_normal = _create_drop_mesh(0.017, 0.046, Color(0.52, 0.002, 0.005, 0.99), false)
	return _primary_mesh_normal


func _get_mist_mesh() -> SphereMesh:
	if _mist_mesh == null:
		_mist_mesh = _create_drop_mesh(0.014, 0.028, Color(0.43, 0.0, 0.004, 0.80), true)
	return _mist_mesh


func _get_jet_mesh() -> SphereMesh:
	if _jet_mesh == null:
		_jet_mesh = _create_drop_mesh(0.020, 0.070, Color(0.55, 0.001, 0.003, 1.0), false)
	return _jet_mesh


func _create_drop_mesh(radius: float, height: float, color: Color, unshaded: bool) -> SphereMesh:
	var drop := SphereMesh.new()
	drop.radius = radius
	drop.height = height
	drop.radial_segments = 5 if radius >= 0.017 else 4
	drop.rings = 3 if radius >= 0.017 else 2
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.0
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = material
	return drop


func _basis_y_along(direction: Vector3) -> Basis:
	var y_axis := direction.normalized()
	var helper := Vector3.RIGHT
	if absf(y_axis.dot(helper)) > 0.92:
		helper = Vector3.FORWARD
	var z_axis := helper.cross(y_axis).normalized()
	var x_axis := y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)
