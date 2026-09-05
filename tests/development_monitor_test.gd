extends SceneTree

const MonitorScript = preload("res://scripts/ui/development_monitor.gd")
const SettingsScript = preload("res://scripts/ui/audio_settings.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var monitor := MonitorScript.new() as HopliteDevelopmentMonitor
	root.add_child(monitor)
	await process_frame
	monitor.set_enabled(true)
	await process_frame
	_require(monitor.visible and monitor.is_processing(), "enabled monitor must be visible and processing")
	_require(is_equal_approx(monitor.anchor_left, 1.0) and is_equal_approx(monitor.anchor_top, 0.0), "monitor must stay anchored to the top-right corner")
	_require(monitor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "monitor must never intercept gameplay input")
	_require(monitor.metrics_label != null and monitor.metrics_label.text.contains("P95") and monitor.metrics_label.text.contains("MEM"), "monitor must expose frame percentiles and memory metrics")
	_require(monitor.performance_snapshot().has("frame_p99_ms"), "monitor must expose a reusable performance snapshot")
	monitor.set_enabled(false)
	_require(not monitor.visible and not monitor.is_processing(), "disabled monitor must have no per-frame cost")
	monitor.queue_free()

	var settings := SettingsScript.new() as HopliteAudioSettings
	root.add_child(settings)
	await process_frame
	_require(settings.visual_settings.has(&"development_monitor"), "global display settings must own the monitor preference")
	_require(settings.display_toggles.has(&"development_monitor"), "display tab must expose the monitor toggle")
	_require(settings.development_monitor != null, "global settings must create the monitor")
	if settings.development_monitor != null:
		_require(settings.development_monitor.is_enabled() == bool(settings.visual_settings[&"development_monitor"]), "saved display preference must be applied to the monitor")
	settings.queue_free()

	if failures.is_empty():
		print("PASS: development performance monitor")
		quit(0)
		return
	for failure: String in failures:
		push_error("[DEVELOPMENT MONITOR] " + failure)
	quit(1)


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
