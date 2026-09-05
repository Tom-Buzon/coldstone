extends Node3D

var configured_points: Array[Vector3] = []
var configured_phase := -1
var configured_engage_distance := 0.0
var configured_speed := 0.0


func configure_demo_patrol(points: Array[Vector3], phase: int = 0, engage_distance: float = 6.5, patrol_speed: float = 0.0) -> void:
	configured_points = points.duplicate()
	configured_phase = phase
	configured_engage_distance = engage_distance
	configured_speed = patrol_speed
