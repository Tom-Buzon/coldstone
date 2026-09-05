extends Node
class_name HopliteEnemyActionCpuMarkerEnd

const BeginMarker = preload("res://tools/enemy_action_cpu_marker_begin.gd")

signal sampling_completed

var begin_marker: BeginMarker
var samples_usec := PackedInt64Array()
var warmup_frames: int = 0
var sample_frames: int = 0
var object_count_at_sample_start: int = -1
var object_count_at_sample_end: int = -1
var _warmup_index: int = 0
var _sample_index: int = 0


func configure(
	marker: BeginMarker,
	warmup_count: int,
	sample_count: int
) -> void:
	begin_marker = marker
	warmup_frames = warmup_count
	sample_frames = sample_count
	samples_usec.resize(sample_frames)


func _physics_process(_delta: float) -> void:
	if begin_marker == null or begin_marker.tick_started_usec <= 0:
		return
	if _warmup_index < warmup_frames:
		_warmup_index += 1
		return
	if _sample_index >= sample_frames:
		return
	samples_usec[_sample_index] = Time.get_ticks_usec() - begin_marker.tick_started_usec
	if _sample_index == 0:
		object_count_at_sample_start = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_sample_index += 1
	if _sample_index == sample_frames:
		object_count_at_sample_end = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		set_physics_process(false)
		sampling_completed.emit()
