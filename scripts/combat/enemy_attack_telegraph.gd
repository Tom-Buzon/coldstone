extends Node3D
class_name HopliteEnemyAttackTelegraph

## Shared world-space warning used by every enemy generation. Combat controllers
## decide when an attack starts; this node only owns the readable visual cue.

const ATTACK_OUTLINE_GROUP := &"enemy_attack_outline_subject"

var label: Label3D
var duration: float = 0.0
var elapsed: float = 0.0
var active: bool = false


func configure(height: float = 2.35) -> void:
	position = Vector3(0.0, height, 0.0)
	label = Label3D.new()
	label.name = "AttackWarning"
	label.text = "!"
	label.font_size = 96
	label.outline_size = 18
	label.modulate = Color(1.0, 0.12, 0.04, 1.0)
	label.outline_modulate = Color(0.12, 0.0, 0.0, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006
	label.visible = false
	add_child(label)
	set_process(false)


func begin(windup_seconds: float) -> void:
	duration = maxf(windup_seconds, 0.05)
	elapsed = 0.0
	active = true
	if label != null:
		label.visible = true
	_set_outline_active(true)
	set_process(true)


func clear() -> void:
	active = false
	_set_outline_active(false)
	if label != null:
		label.visible = false
	set_process(false)


func shutdown() -> void:
	clear()


func _exit_tree() -> void:
	_set_outline_active(false)


func _set_outline_active(value: bool) -> void:
	var subject := get_parent() as Node3D
	if subject == null:
		return
	if value and subject.is_in_group(&"enemy"):
		subject.add_to_group(ATTACK_OUTLINE_GROUP)
	else:
		subject.remove_from_group(ATTACK_OUTLINE_GROUP)


func _process(delta: float) -> void:
	if not active or label == null:
		return
	elapsed += delta
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var pulse := 1.0 + sin(progress * PI * 5.0) * 0.10
	label.scale = Vector3.ONE * lerpf(0.78, 1.28, progress) * pulse
	label.modulate.a = 1.0 - maxf(0.0, progress - 0.82) / 0.18
	if elapsed >= duration:
		clear()
