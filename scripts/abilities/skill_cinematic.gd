extends Node

const Vfx = preload("res://scripts/abilities/skill_vfx.gd")
var thunder_view: Node3D
var runtime: Node
var plunge_camera := false
var anchor_y := 0.0
var recovery := -1.0
var recovery_weight := 0.0
var camera_weight := 0.0
var moment := 0.0
var moment_length := 1.0
var moment_scale := 1.0
var moment_fov := 0.0
var fov_blend := 0.0
var active_color := Color.WHITE
var banner := ""
var banner_time := 0.0
var flash := 0.0
var vfx: Node3D
var overlay: Control
var aura_focus: Node3D
var aura_mode: StringName = &"dash"
var aura_side := 1.0
var aura_camera_blend := 0.0
var aura_camera_delta := 0.016
var aura_beat := 0.0
var aura_roll := 0.0

func configure(value: Node) -> void:
	runtime = value
	thunder_view = preload("res://scripts/abilities/thunder_camera.gd").new()
	add_child(thunder_view)
	thunder_view.configure(runtime)
	vfx = Vfx.new()
	vfx.runtime = runtime
	runtime.player.add_child(vfx)
	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.draw.connect(_draw_overlay)

func announce(kind: StringName, text: String) -> void:
	active_color = Vfx.color_for(kind)
	banner = text
	banner_time = 1.6
	vfx.burst(runtime.player.global_position, active_color, 2.5, false)
	accent(0.30, 0.48, -7.0)

func accent(duration: float, slow: float, zoom: float) -> void:
	moment = duration
	moment_length = duration
	moment_scale = slow
	moment_fov = zoom
	flash = 0.07

func aura_transfer(target: Node3D, mode: StringName, combo: int) -> void:
	aura_focus = target
	aura_mode = mode
	aura_side = 1.0 if combo % 2 == 0 else -1.0
	aura_beat = 0.35
	aura_roll = deg_to_rad(4.0) * aura_side
	vfx.burst(runtime.player.global_position, Vfx.color_for(&"aura"), 0.7, false)

func aura_impact(point: Vector3) -> void:
	accent(0.10, 0.75, 6.0)
	vfx.beam(runtime.player.global_position + Vector3.UP, point + Vector3.UP, Vfx.color_for(&"aura"), 0.20, 0.22)

func begin_plunge() -> void:
	plunge_camera = true
	anchor_y = runtime.player.camera.global_position.y
	recovery = -1.0
	camera_weight = 0.0
	announce(&"plunge", "FRAPPE TELLURIQUE")

func impact(point: Vector3, radius: float) -> void:
	plunge_camera = false
	recovery_weight = camera_weight
	recovery = 0.0
	active_color = Vfx.color_for(&"plunge")
	banner = "FRAPPE TELLURIQUE"
	banner_time = 0.9
	vfx.burst(point, Vfx.color_for(&"plunge"), radius, true)
	accent(0.25, 0.12, 9.0)

func cancel() -> void:
	thunder_view.finish()
	plunge_camera = false
	if camera_weight > 0.0:
		recovery_weight = camera_weight
		recovery = 0.0
	moment = 0.0

func advance(real_delta: float) -> void:
	thunder_view.advance(real_delta)
	aura_camera_delta = real_delta
	aura_beat = maxf(0.0, aura_beat - real_delta)
	aura_roll = lerpf(aura_roll, 0.0, 1.0 - exp(-7.0 * real_delta))
	var aura_active: bool = runtime.ultimate == &"aura" and not runtime.controls.wheel.visible and not plunge_camera
	aura_camera_blend = move_toward(aura_camera_blend, 1.0 if aura_active else 0.0, real_delta / 0.45)
	moment = maxf(0.0, moment - real_delta)
	banner_time = maxf(0.0, banner_time - real_delta)
	flash = maxf(0.0, flash - real_delta)
	if plunge_camera:
		camera_weight = minf(1.0, camera_weight + real_delta * 8.0)
	elif recovery >= 0.0:
		recovery += real_delta
		camera_weight = recovery_weight * (1.0 - smoothstep(0.0, 0.9, recovery))
		if recovery >= 0.9:
			recovery = -1.0
			camera_weight = 0.0
	var slow := minf(0.32 if plunge_camera else 1.0, thunder_view.slow)
	var envelope := smoothstep(0.0, 0.12, moment) if moment > 0.0 else 0.0
	if moment > 0.0: slow = minf(slow, lerpf(1.0, moment_scale, envelope))
	if runtime.controls.wheel.visible: slow = minf(slow, 0.18)
	var feedback: Node = runtime.player.combat_feedback
	if feedback != null:
		feedback.skill_time_scale = slow
		var charge_zoom: float = -9.0 * (1.0 - runtime.cast_remaining / maxf(runtime.value(&"flame_cast") if runtime.ultimate == &"flame" else 0.28, 0.01)) if runtime.cast_remaining > 0 else 0.0
		if runtime.ultimate == &"thunder": charge_zoom = -10.0 * runtime.thunder_charge
		var desired_fov: float = moment_fov * envelope + charge_zoom + (8.0 if runtime.ultimate == &"aura" else (-3.0 if runtime.ultimate == &"ares" else 0.0))
		fov_blend = lerpf(fov_blend, desired_fov, 1.0 - exp(-12.0 * real_delta))
		feedback.skill_fov = fov_blend
		feedback.skill_rotation = Vector3(0, 0, aura_roll * aura_camera_blend)
		if camera_weight > 0.0:
			var camera: Camera3D = runtime.player.camera
			var target: Vector3 = runtime.player.global_position + Vector3.UP * 0.75
			var offset := target - camera.global_position
			var pitch := atan2(offset.y, maxf(Vector2(offset.x, offset.z).length(), 0.1))
			feedback.skill_rotation.x = (pitch - runtime.player.camera_pitch.rotation.x) * camera_weight
	overlay.queue_redraw()

func apply_rig() -> void:
	var player: Node3D = runtime.player
	if aura_camera_blend > 0.001:
		var weight := smoothstep(0.0, 1.0, aura_camera_blend)
		if runtime.ultimate == &"aura" and is_instance_valid(aura_focus) and not runtime.controls.wheel.visible:
			var offset: Vector3 = aura_focus.global_position - player.global_position
			if Vector2(offset.x, offset.z).length() > 0.2:
				var yaw := atan2(-offset.x, -offset.z) + aura_side * deg_to_rad(16.0) * smoothstep(0.0, 0.35, aura_beat)
				player.camera_yaw.rotation.y = rotate_toward(player.camera_yaw.rotation.y, yaw, aura_camera_delta * 4.5 * weight)
		var height := 0.9 if aura_mode == &"slide" else (1.8 if aura_mode == &"jump" else 1.35)
		player.camera_yaw.global_position.y = lerpf(player.camera_yaw.global_position.y, player.global_position.y + height, weight * 0.6)
		player.spring_arm.spring_length = lerpf(player.spring_arm.spring_length, 5.8 if aura_mode == &"jump" else 4.6, weight * (1.0 - exp(-8.0 * aura_camera_delta)))
		var pitch := -0.12 if aura_mode == &"slide" else (-0.42 if aura_mode == &"jump" else -0.23)
		player.camera_pitch.rotation.x = lerp_angle(player.camera_pitch.rotation.x, pitch, weight * (1.0 - exp(-8.0 * aura_camera_delta)))
	if camera_weight <= 0.0: return
	# SpringArm retains collision ownership. Offset the pivot to preserve the
	# camera's world height, while the camera aims down toward the falling hero.
	var height: float = anchor_y + sin(player.camera_pitch.rotation.x) * player.spring_arm.get_hit_length()
	player.camera_yaw.global_position.y = lerpf(player.camera_yaw.global_position.y, height, camera_weight)

func _draw_overlay() -> void:
	var size := overlay.size
	var bars := maxf(1.0 if thunder_view.phase != &"" else camera_weight, smoothstep(0.0, 0.35, banner_time) * 0.7)
	if bars > 0.0:
		overlay.draw_rect(Rect2(0, 0, size.x, 32 * bars), Color(0.005, 0.008, 0.012, 0.9))
		overlay.draw_rect(Rect2(0, size.y - 32 * bars, size.x, 32 * bars), Color(0.005, 0.008, 0.012, 0.9))
	if flash > 0.0: overlay.draw_rect(Rect2(Vector2.ZERO, size), Color(active_color, flash * 1.2))
	if runtime.ultimate == &"aura":
		var center := size * 0.5
		for i: int in 24:
			var angle := i * TAU / 24.0
			var direction := Vector2.from_angle(angle)
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.025 + i * 1.7)
			overlay.draw_line(center + direction * size.y * (0.44 + pulse * 0.06), center + direction * size.y * 0.85, Color(1, 0.78, 0.25, 0.10 + pulse * 0.10), 1.5, true)
	if banner_time > 0.0:
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		var alpha := smoothstep(0.0, 0.4, banner_time)
		overlay.draw_string(font, Vector2((size.x - text_size.x) * 0.5, 85), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(active_color, alpha))

func _exit_tree() -> void:
	if runtime != null and is_instance_valid(runtime.player) and is_instance_valid(runtime.player.combat_feedback):
		runtime.player.combat_feedback.skill_time_scale = 1.0
		runtime.player.combat_feedback.skill_fov = 0.0
		runtime.player.combat_feedback.skill_rotation = Vector3.ZERO
