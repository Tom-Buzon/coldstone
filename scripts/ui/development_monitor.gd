extends PanelContainer
class_name HopliteDevelopmentMonitor

## Compact runtime health panel for development builds. The panel samples at a
## low frequency so observing performance does not meaningfully affect it.

const SAMPLE_INTERVAL: float = 0.5
const FRAME_HISTORY_SIZE: int = 240
const GOOD_FPS: float = 55.0
const WARNING_FPS: float = 40.0

const COLOR_GOOD := Color(0.38, 0.90, 0.56)
const COLOR_WARNING := Color(1.0, 0.72, 0.26)
const COLOR_BAD := Color(1.0, 0.34, 0.27)

var status_dot: Label
var fps_label: Label
var metrics_label: Label

var _enabled := false
var _peak_frame_time_ms := 0.0
var _last_frame_usec := 0
var _last_sample_usec := 0
var _frame_history: Array[float] = []
var _last_snapshot: Dictionary = {}


func _ready() -> void:
	name = "DevelopmentMonitor"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -322.0
	offset_top = 12.0
	offset_right = -12.0
	offset_bottom = 164.0
	add_theme_stylebox_override("panel", _panel_style())
	_build_ui()
	set_enabled(_enabled)


func _process(_delta: float) -> void:
	var now_usec := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		var frame_time_ms := float(now_usec - _last_frame_usec) / 1000.0
		_peak_frame_time_ms = maxf(_peak_frame_time_ms, frame_time_ms)
		_frame_history.append(frame_time_ms)
		if _frame_history.size() > FRAME_HISTORY_SIZE:
			_frame_history.pop_front()
	_last_frame_usec = now_usec
	if float(now_usec - _last_sample_usec) < SAMPLE_INTERVAL * 1_000_000.0:
		return
	_refresh_metrics()
	_last_sample_usec = now_usec
	_peak_frame_time_ms = 0.0


func set_enabled(value: bool) -> void:
	_enabled = value
	visible = value
	set_process(value)
	if value and is_node_ready():
		var now_usec := Time.get_ticks_usec()
		_last_frame_usec = now_usec
		_last_sample_usec = now_usec
		_peak_frame_time_ms = 0.0
		_frame_history.clear()
		_refresh_metrics()


func is_enabled() -> bool:
	return _enabled


func _build_ui() -> void:
	var content := VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)
	add_child(content)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 6)
	content.add_child(header)

	status_dot = Label.new()
	status_dot.name = "StatusDot"
	status_dot.text = "●"
	status_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_dot.add_theme_font_size_override("font_size", 11)
	header.add_child(status_dot)

	var title := Label.new()
	title.name = "Title"
	title.text = "MONITEUR DEV"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	header.add_child(title)

	fps_label = Label.new()
	fps_label.name = "Fps"
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_font_size_override("font_size", 14)
	header.add_child(fps_label)

	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(separator)

	metrics_label = Label.new()
	metrics_label.name = "Metrics"
	metrics_label.custom_minimum_size = Vector2(286.0, 0.0)
	metrics_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	metrics_label.add_theme_font_size_override("font_size", 12)
	metrics_label.add_theme_color_override("font_color", Color(0.78, 0.81, 0.85))
	metrics_label.add_theme_constant_override("line_spacing", 2)
	metrics_label.tooltip_text = "FPS, percentiles de frame, CPU, physique, rendu, géométrie, nœuds et mémoire."
	content.add_child(metrics_label)


func _refresh_metrics() -> void:
	if fps_label == null or metrics_label == null or status_dot == null:
		return
	var fps := float(Engine.get_frames_per_second())
	var frame_time_ms := 1000.0 / maxf(fps, 1.0)
	var displayed_peak := maxf(_peak_frame_time_ms, frame_time_ms)
	var sorted_frames := _frame_history.duplicate()
	sorted_frames.sort()
	var frame_p50 := _percentile(sorted_frames, 0.50, frame_time_ms)
	var frame_p95 := _percentile(sorted_frames, 0.95, frame_time_ms)
	var frame_p99 := _percentile(sorted_frames, 0.99, frame_time_ms)
	var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var rendered_objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphan_nodes := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var static_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var video_memory := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	_last_snapshot = {
		"captured_at_unix": Time.get_unix_time_from_system(),
		"fps": fps,
		"frame_ms": frame_time_ms,
		"frame_p50_ms": frame_p50,
		"frame_p95_ms": frame_p95,
		"frame_p99_ms": frame_p99,
		"frame_peak_ms": displayed_peak,
		"process_ms": process_ms,
		"physics_ms": physics_ms,
		"draw_calls": draw_calls,
		"rendered_objects": rendered_objects,
		"primitives": primitives,
		"nodes": nodes,
		"orphan_nodes": orphan_nodes,
		"static_memory_bytes": static_memory,
		"video_memory_bytes": video_memory,
	}

	var status_color := _status_color(fps, orphan_nodes)
	status_dot.add_theme_color_override("font_color", status_color)
	fps_label.add_theme_color_override("font_color", status_color)
	fps_label.text = "%d FPS" % int(round(fps))
	metrics_label.text = (
		"FRAME   P50 %5.1f   P95 %5.1f   P99 %5.1f ms\n" % [frame_p50, frame_p95, frame_p99]
		+ "PIC     %5.1f ms\n" % displayed_peak
		+ "CPU     %5.2f ms   PHYS %5.2f ms\n" % [process_ms, physics_ms]
		+ "RENDU   %s appels   %s objets\n" % [_compact_count(draw_calls), _compact_count(rendered_objects)]
		+ "GEOM    %s primitives\n" % _compact_count(primitives)
		+ "SCENE   %s noeuds   %s orphelins\n" % [_compact_count(nodes), _compact_count(orphan_nodes)]
		+ "MEM     %s   VRAM %s" % [_format_bytes(static_memory), _format_bytes(video_memory)]
	)


func performance_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


func save_snapshot(path: String = "user://hoplite_performance_snapshot.json") -> Error:
	if _last_snapshot.is_empty():
		_refresh_metrics()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_last_snapshot, "\t"))
	return OK


func _percentile(sorted_values: Array[float], ratio: float, fallback: float) -> float:
	if sorted_values.is_empty():
		return fallback
	var index := clampi(int(ceil(float(sorted_values.size()) * ratio)) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _status_color(fps: float, orphan_nodes: int) -> Color:
	if fps < WARNING_FPS or orphan_nodes > 0:
		return COLOR_BAD
	if fps < GOOD_FPS:
		return COLOR_WARNING
	return COLOR_GOOD


func _compact_count(value: int) -> String:
	var magnitude := absi(value)
	if magnitude >= 1_000_000:
		return "%.1fM" % (float(value) / 1_000_000.0)
	if magnitude >= 1_000:
		return "%.1fK" % (float(value) / 1_000.0)
	return str(value)


func _format_bytes(value: int) -> String:
	if value <= 0:
		return "n/d"
	var mebibytes := float(value) / (1024.0 * 1024.0)
	if mebibytes >= 1024.0:
		return "%.1f Gio" % (mebibytes / 1024.0)
	return "%.0f Mio" % mebibytes


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.016, 0.024, 0.84)
	style.border_color = Color(0.52, 0.57, 0.64, 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 8.0
	return style
