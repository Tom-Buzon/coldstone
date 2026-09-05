extends Node
## Owns a temporary camera and overlay; never mutates the player's camera rig.
var queue: Array[Dictionary] = []
var camera: Camera3D
var previous: WeakRef
var overlay: CanvasLayer
var time_left := 0.0
var paused_by_us := false
var actor_ref: WeakRef
var lod_reference: WeakRef

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func present(actor: Node3D, title: String) -> void:
	if not is_instance_valid(actor): return
	queue.append({"actor":weakref(actor),"title":title})
	set_process(true)

func _process(delta: float) -> void:
	if camera == null:
		if queue.is_empty(): set_process(false); return
		if get_tree().paused: return
		var request: Dictionary = queue.pop_front()
		var actor: Node3D = request.actor.get_ref()
		if not is_instance_valid(actor) or actor.dead: return
		actor_ref = request.actor
		var current := get_viewport().get_camera_3d()
		if current == null: return
		previous = weakref(current)
		camera = Camera3D.new()
		add_child(camera)
		var height := maxf(2.0,float(actor.get_meta("boss_presentation_height",actor.scale.y*2.0)))
		var center := actor.global_position + Vector3.UP*height*0.5
		var direction := (current.global_position-center).normalized()
		if direction.length_squared()<0.1: direction = Vector3(0,0.3,1).normalized()
		var desired := center + direction*maxf(6.0,height*2.0) + Vector3.UP*1.0
		var query := PhysicsRayQueryParameters3D.create(center,desired,1)
		query.exclude = [actor.get_rid()] if actor is CollisionObject3D else []
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		camera.global_position = hit.position-direction*0.3 if not hit.is_empty() else desired
		camera.look_at(center)
		camera.fov = 48
		camera.make_current()
		# The actor may be far from the player: sample a real pose at cinematic LOD
		# before freezing gameplay, then animate only this presentation subject.
		if actor.performance_lod != null:
			lod_reference = weakref(actor.performance_lod.reference) if is_instance_valid(actor.performance_lod.reference) else null
			actor.performance_lod.reference = camera
			actor.performance_lod.refresh(true)
		if is_instance_valid(actor.far_impostor_batch): actor.far_impostor_batch.flush_pending()
		if actor.animation != null:
			actor.animation.sample(0.2)

		_make_overlay(String(request.title),true)
		time_left = 2.0
		paused_by_us = true
		get_tree().paused = true
	else:
		time_left -= delta
		var actor: Node = actor_ref.get_ref()
		if time_left <= 0 or not is_instance_valid(actor) or actor.dead: _restore()
		elif actor.animation != null: actor.animation.sample(delta)

func _make_overlay(title: String, cinematic: bool) -> void:
	if is_instance_valid(overlay): overlay.queue_free()
	overlay = CanvasLayer.new()
	overlay.layer = 90
	add_child(overlay)
	if cinematic:
		for bottom: bool in [false,true]:
			var bar := ColorRect.new()
			bar.color = Color.BLACK
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.add_child(bar)
			bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
			bar.offset_top = -64 if bottom else 0
			bar.offset_bottom = 0 if bottom else 64
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",28)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	overlay.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 18 if cinematic else 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func message(title: String) -> void:
	_make_overlay(title,false)
	var shown := overlay
	get_tree().create_timer(4.0,false).timeout.connect(func() -> void:
		if is_instance_valid(shown): shown.queue_free())

func _restore() -> void:
	if actor_ref != null:
		var actor: Node = actor_ref.get_ref()
		if is_instance_valid(actor) and actor.performance_lod != null:
			actor.performance_lod.reference = lod_reference.get_ref() if lod_reference != null else null
			actor.performance_lod.refresh(true)
	actor_ref = null
	lod_reference = null
	if is_instance_valid(camera): camera.queue_free()
	camera = null
	if previous != null and is_instance_valid(previous.get_ref()): previous.get_ref().make_current()
	if is_instance_valid(overlay): overlay.queue_free()
	if paused_by_us and is_inside_tree(): get_tree().paused = false
	paused_by_us = false

func _exit_tree() -> void:
	_restore()
