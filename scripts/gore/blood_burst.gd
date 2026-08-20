extends Node3D
class_name HopliteBloodBurst

# V0.0.4: intentionally much denser blood without physics droplets.
# All visible blood is GPUParticles3D, so increasing count is far cheaper than
# spawning RigidBody3D droplets. Active bursts are capped to keep worst-case
# group combat bounded.

const MAX_ACTIVE_BURSTS: int = 24

var max_lifetime: float = 0.95

func _ready() -> void:
    add_to_group("blood_fx")

func setup(world_position: Vector3, direction: Vector3, intensity: float = 1.0, sever: bool = false) -> void:
    global_position = world_position

    var spray_direction: Vector3 = direction
    if spray_direction.length() < 0.01:
        spray_direction = Vector3.UP
    spray_direction = (spray_direction.normalized() + Vector3.UP * 0.08).normalized()
    global_basis = _basis_y_along(spray_direction)

    _enforce_fx_budget()

    var strength: float = clampf(intensity, 0.60, 3.20)
    _build_primary_spray(strength, sever)
    _build_dense_mist(strength, sever)
    if sever:
        _build_arterial_jet(strength)

    max_lifetime = 1.05 if sever else 0.72
    get_tree().create_timer(max_lifetime).timeout.connect(queue_free)

func _enforce_fx_budget() -> void:
    if get_tree() == null:
        return
    var bursts: Array[Node] = get_tree().get_nodes_in_group("blood_fx")
    var overflow: int = bursts.size() - MAX_ACTIVE_BURSTS
    if overflow <= 0:
        return
    var removed: int = 0
    for old: Node in bursts:
        if removed >= overflow:
            break
        if old != null and old != self and is_instance_valid(old):
            old.queue_free()
            removed += 1

func _build_primary_spray(strength: float, sever: bool) -> void:
    var particles := GPUParticles3D.new()
    particles.name = "BloodPrimarySpray"
    particles.amount = clampi(
        int(58.0 + strength * 28.0 + (72.0 if sever else 0.0)),
        64,
        210
    )
    particles.lifetime = 0.78 if sever else 0.56
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.randomness = 0.62
    particles.local_coords = false

    var process := ParticleProcessMaterial.new()
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
    particles.process_material = process

    var droplet := SphereMesh.new()
    droplet.radius = 0.021 if sever else 0.017
    droplet.height = 0.060 if sever else 0.046
    droplet.radial_segments = 5
    droplet.rings = 3
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.52, 0.002, 0.005, 0.99)
    mat.roughness = 0.42
    mat.metallic = 0.0
    droplet.material = mat
    particles.draw_pass_1 = droplet

    add_child(particles)
    particles.emitting = true

func _build_dense_mist(strength: float, sever: bool) -> void:
    var particles := GPUParticles3D.new()
    particles.name = "BloodDenseMist"
    particles.amount = clampi(
        int(30.0 + strength * 17.0 + (44.0 if sever else 0.0)),
        36,
        120
    )
    particles.lifetime = 0.42 if sever else 0.31
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.randomness = 0.84
    particles.local_coords = false

    var process := ParticleProcessMaterial.new()
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
    particles.process_material = process

    var mist_drop := SphereMesh.new()
    mist_drop.radius = 0.014
    mist_drop.height = 0.028
    mist_drop.radial_segments = 4
    mist_drop.rings = 2
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.43, 0.0, 0.004, 0.80)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mist_drop.material = mat
    particles.draw_pass_1 = mist_drop

    add_child(particles)
    particles.emitting = true

func _build_arterial_jet(strength: float) -> void:
    # Narrow extra jet only for severing. Still GPU-only; no collision or rigid bodies.
    var particles := GPUParticles3D.new()
    particles.name = "BloodArterialJet"
    particles.amount = clampi(int(72.0 + strength * 26.0), 82, 150)
    particles.lifetime = 0.88
    particles.one_shot = true
    particles.explosiveness = 0.92
    particles.randomness = 0.46
    particles.local_coords = false

    var process := ParticleProcessMaterial.new()
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
    particles.process_material = process

    var jet_drop := SphereMesh.new()
    jet_drop.radius = 0.020
    jet_drop.height = 0.070
    jet_drop.radial_segments = 5
    jet_drop.rings = 3
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.55, 0.001, 0.003, 1.0)
    mat.roughness = 0.38
    jet_drop.material = mat
    particles.draw_pass_1 = jet_drop

    add_child(particles)
    particles.emitting = true

func _basis_y_along(direction: Vector3) -> Basis:
    var y_axis: Vector3 = direction.normalized()
    var helper: Vector3 = Vector3.RIGHT
    if absf(y_axis.dot(helper)) > 0.92:
        helper = Vector3.FORWARD
    var z_axis: Vector3 = helper.cross(y_axis).normalized()
    var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
    return Basis(x_axis, y_axis, z_axis)
