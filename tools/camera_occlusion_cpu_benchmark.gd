extends SceneTree

const FaderScript = preload("res://scripts/camera/camera_occlusion_fader.gd")
const SAMPLE_COUNT := 120


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for visual_count: int in [100, 1000, 5000]:
		var result := await _measure_visual_scan(visual_count)
		print(
			"[CAMERA OCCLUSION BENCH] visuals=%d registered=%d candidates=%d cells=%d register_ms=%.4f avg_scan_ms=%.4f"
			% [
				visual_count,
				int(result[&"registered"]),
				int(result[&"candidates"]),
				int(result[&"cells"]),
				float(result[&"registration_ms"]),
				float(result[&"average_ms"]),
			]
		)
	quit(0)


func _measure_visual_scan(visual_count: int) -> Dictionary:
	var world := Node3D.new()
	world.name = "CameraOcclusionBenchmark%d" % visual_count
	root.add_child(world)
	current_scene = world
	var target := Node3D.new()
	world.add_child(target)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.0, 4.0)
	world.add_child(camera)
	var fader := FaderScript.new() as HopliteCameraOcclusionFader
	world.add_child(fader)
	fader.configure(camera, target, null)

	var shared_mesh := BoxMesh.new()
	shared_mesh.size = Vector3(0.4, 0.8, 0.4)
	for index: int in visual_count:
		var visual := MeshInstance3D.new()
		visual.mesh = shared_mesh
		visual.position = Vector3(8.0 + float(index % 100) * 0.6, float((index / 100) % 20), -float(index / 2000) * 2.0)
		world.add_child(visual)
	var registration_started_usec := Time.get_ticks_usec()
	fader.call("_flush_pending_visual_registrations")
	var registration_ms := float(Time.get_ticks_usec() - registration_started_usec) / 1000.0
	await process_frame
	for _warmup: int in 8:
		fader.call("_scan_occluders")
	var started_usec := Time.get_ticks_usec()
	for _sample: int in SAMPLE_COUNT:
		fader.call("_scan_occluders")
	var average_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0 / float(SAMPLE_COUNT)
	var result := {
		&"average_ms": average_ms,
		&"registration_ms": registration_ms,
		&"registered": fader.get_registered_visual_count(),
		&"candidates": fader.get_last_visual_candidate_count(),
		&"cells": fader.get_last_spatial_cell_count(),
	}
	current_scene = null
	world.queue_free()
	await process_frame
	return result
