extends RigidBody3D
class_name HopliteV2DroppedShield

## Short-lived physical aspis debris. It uses ordinary rigid-body motion for
## the readable fall, then corrects the rare numerical rim-balance case inside
## the physics integration callback.

const FORCE_FLAT_AFTER_SECONDS := 1.25

var elapsed_seconds := 0.0
var ground_reference_y := NAN
var disc_thickness := 0.04


func configure_ground(height: float, thickness: float) -> void:
	ground_reference_y = height
	disc_thickness = maxf(0.02, thickness)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	elapsed_seconds += state.step
	var disc_normal := state.transform.basis.z.normalized()
	var flatness := absf(disc_normal.dot(Vector3.UP))
	var desired_normal := Vector3.UP if disc_normal.dot(Vector3.UP) >= 0.0 else Vector3.DOWN
	if elapsed_seconds < FORCE_FLAT_AFTER_SECONDS and flatness < 0.94:
		var tipping_axis := disc_normal.cross(desired_normal)
		if tipping_axis.length_squared() > 0.0001:
			var wanted_velocity := tipping_axis.normalized() * 5.0
			state.angular_velocity = state.angular_velocity.lerp(wanted_velocity, clampf(state.step * 8.0, 0.0, 1.0))
		return
	if elapsed_seconds < FORCE_FLAT_AFTER_SECONDS or flatness >= 0.90:
		return
	# The rigid body has had time to visibly topple. If the solver still balances
	# it on its rim (or a broad helper plane), finish at the actual foot height.
	var flat_transform := state.transform
	var axis_x := flat_transform.basis.x - desired_normal * flat_transform.basis.x.dot(desired_normal)
	if axis_x.length_squared() < 0.001:
		axis_x = Vector3.RIGHT
	axis_x = axis_x.normalized()
	var axis_y := desired_normal.cross(axis_x).normalized()
	flat_transform.basis = Basis(axis_x, axis_y, desired_normal).orthonormalized()
	if is_finite(ground_reference_y):
		flat_transform.origin.y = ground_reference_y + disc_thickness * 0.5 + 0.01
	state.transform = flat_transform
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	state.sleeping = true
