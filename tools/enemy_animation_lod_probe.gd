extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _probe_shared_hoplite_sampling()
	await _probe_native_tree_pause_and_wake()
	await _probe_direct_mixamo_sampling_and_wake()
	if failures.is_empty():
		print("ENEMY_ANIMATION_LOD_PROBE PASS: shared/native/direct sampling cadence and reversible wake")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _probe_shared_hoplite_sampling() -> void:
	var enemy := _spawn(&"ngeneral", Vector3.ZERO)
	await process_frame
	var driver: Node = enemy.ai_animation_driver
	_expect(driver != null and driver.has_method("set_simulation_lod"), "shared hoplite driver exposes no simulation LOD authority")
	if driver != null and driver.has_method("set_simulation_lod"):
		driver.call("set_simulation_lod", 2)
		var before := int(driver.get("simulation_sample_count"))
		for _step: int in range(12):
			driver.call("_physics_process", 1.0 / 60.0)
		var sampled := int(driver.get("simulation_sample_count")) - before
		_expect(sampled >= 2 and sampled <= 3, "LOD2 did not evaluate the shared tree near 12 Hz")
		driver.call("set_simulation_lod", 3)
		before = int(driver.get("simulation_sample_count"))
		for _step: int in range(12):
			driver.call("_physics_process", 1.0 / 60.0)
		_expect(int(driver.get("simulation_sample_count")) == before, "LOD3 continued evaluating the shared tree")
		driver.call("set_simulation_lod", 0)
		driver.call("force_simulation_sample")
		_expect(int(driver.get("simulation_sample_count")) > before and bool(driver.animation_tree.active), "shared tree did not wake reversibly")
	enemy.queue_free()
	await process_frame

func _probe_native_tree_pause_and_wake() -> void:
	# Generic package troops intentionally use their single lightweight UAL1
	# player without a retarget driver. The centurion is a miniboss with selective
	# attack clips, so it exercises the heavy native retarget driver route.
	var enemy := _spawn(&"ncenturion", Vector3(3.0, 0.0, 0.0))
	await process_frame
	var driver: Node = enemy.ai_animation_driver
	_expect(driver != null and driver.has_method("set_simulation_lod"), "native driver exposes no simulation LOD authority")
	if driver != null and driver.has_method("set_simulation_lod"):
		driver.call("set_simulation_lod", 3)
		_expect(not bool(driver.animation_tree.active), "native AnimationTree stayed active at LOD3")
		driver.call("set_simulation_lod", 0)
		driver.call("force_simulation_sample")
		_expect(bool(driver.animation_tree.active), "native AnimationTree did not wake after LOD3")
	enemy.queue_free()
	await process_frame

func _probe_direct_mixamo_sampling_and_wake() -> void:
	var enemy := _spawn(&"guardian", Vector3(6.0, 0.0, 0.0))
	await process_frame
	enemy.set_process(false)
	# Isolate the sampling clock. Otherwise the first manual `_process()` can also
	# run the distance policy and legitimately replace the forced LOD2 with LOD3
	# when this probe has no battle camera; whether that happened depended on how
	# many idle frames elapsed during resource loading.
	enemy.performance_lod_timer = 999.0
	var player: AnimationPlayer = enemy.animation_player
	_expect(player != null and enemy.ai_animation_driver == null, "guardian did not exercise the direct Mixamo AnimationPlayer route")
	if player != null and enemy.ai_animation_driver == null:
		enemy._apply_render_lod(2, true, 90.0)
		_expect(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "direct Mixamo player stayed autonomous at LOD2")
		var before := enemy.direct_animation_sample_count
		for _step: int in range(4):
			enemy._process(1.0 / 60.0)
		_expect(enemy.direct_animation_sample_count == before, "direct Mixamo LOD2 sampled faster than 12 Hz")
		enemy._process(1.0 / 60.0)
		_expect(enemy.direct_animation_sample_count == before + 1, "direct Mixamo LOD2 did not sample at 12 Hz")
		enemy._apply_render_lod(3, true, 90.0)
		before = enemy.direct_animation_sample_count
		for _step: int in range(12):
			enemy._process(1.0 / 60.0)
		_expect(enemy.direct_animation_sample_count == before, "direct Mixamo LOD3 continued sampling")
		enemy._apply_render_lod(0, true, 90.0)
		_expect(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE, "direct Mixamo player did not restore autonomous idle processing")
		_expect(enemy.direct_animation_sample_count > before, "direct Mixamo player did not force a wake sample")
	enemy.queue_free()
	await process_frame

func _spawn(archetype: StringName, at: Vector3) -> HopliteAthenianEnemy:
	var enemy := Enemy.new() as HopliteAthenianEnemy
	enemy.archetype_id = archetype
	enemy.ai_enabled = true
	enemy.position = at
	root.add_child(enemy)
	return enemy

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
