extends Node
class_name HopliteEnemyActionCpuMarkerBegin

var tick_started_usec: int = 0


func _physics_process(_delta: float) -> void:
	tick_started_usec = Time.get_ticks_usec()
