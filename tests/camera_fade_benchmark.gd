extends SceneTree

const FaderScript = preload("res://scripts/camera/camera_occlusion_fader.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var fader := FaderScript.new()
	world.add_child(fader)
	fader.enabled = true
	for index: int in 128:
		var visual := MeshInstance3D.new()
		visual.mesh = BoxMesh.new()
		world.add_child(visual)
		fader._mark_occluded(visual)
	fader._process(1.0)
	var samples: Array[float] = []
	for sample: int in 5:
		var started := Time.get_ticks_usec()
		for frame: int in 1000:
			fader._process(1.0 / 60.0)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples.sort()
	print("128 settled fades, median CPU usec/frame: ", samples[2])
	world.free()
	quit()
