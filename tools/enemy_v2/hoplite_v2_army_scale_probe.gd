extends SceneTree

const LayoutRuntime = preload("res://scripts/enemy_v2/enemy_v2_battle_layout_runtime.gd")

const GROUP_COUNT := 42
const SOLDIERS_PER_GROUP := 24

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Node3D.new()
	world.add_child(target)
	var layout := LayoutRuntime.new() as EnemyV2BattleLayoutRuntime
	for index: int in range(GROUP_COUNT):
		var angle := float(index) * TAU / float(GROUP_COUNT)
		var ring := index % 4
		var radius := 8.0 + float(ring) * 7.0
		var anchor := Vector3(cos(angle), 0.0, sin(angle)) * radius
		layout.register_group(StringName("scale_%02d" % index), target, anchor, {}, &"hoplite_phalanx", SOLDIERS_PER_GROUP)
	var started_usec := Time.get_ticks_usec()
	var frontline := 0
	var approach := 0
	var support := 0
	var reserve := 0
	for index: int in range(GROUP_COUNT):
		var order := layout.assignment(StringName("scale_%02d" % index))
		match StringName(order.get("role", &"")):
			&"frontline": frontline += 1
			&"approach": approach += 1
			&"support": support += 1
			&"reserve": reserve += 1
	var build_usec := Time.get_ticks_usec() - started_usec
	_expect(layout.records.size() == GROUP_COUNT, "the army layout lost a troop record")
	_expect(frontline <= LayoutRuntime.MAX_CONTACT_PHALANXES, "the contact ring exceeded four whole phalanxes")
	_expect(approach <= 1, "more than one newcomer was allowed to reorganize the structure at once")
	_expect(frontline + approach + support + reserve == GROUP_COUNT, "a large-army phalanx received no bounded strategic role")
	_expect(build_usec < 500000, "the 1008-soldier strategic rebuild exceeded the broad 500 ms safety ceiling")
	world.free()
	if failures.is_empty():
		print(
			"HOPLITE_V2_ARMY_SCALE_PROBE PASS soldiers=", GROUP_COUNT * SOLDIERS_PER_GROUP,
			" group_records=", GROUP_COUNT,
			" frontline=", frontline,
			" approach=", approach,
			" support=", support,
			" reserve=", reserve,
			" build_usec=", build_usec
		)
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 ARMY SCALE] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
