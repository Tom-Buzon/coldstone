extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var error := change_scene_to_file("res://world_editor.tscn")
	if error != OK:
		push_error("WORLD_EDITOR_FLOW_FAILED scene=%d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var editor := current_scene
	if editor == null or not editor.has_method("_start_test"):
		push_error("WORLD_EDITOR_FLOW_FAILED editor unavailable")
		quit(1)
		return
	var document: HopliteWorldDocument = editor.get("document") as HopliteWorldDocument
	var original_count: int = document.entities().size()
	editor.call("_select_brush", "SOL TEST", "surface", {"shape": "floor", "size": [4.0, 0.35, 4.0], "material": "pavers"})
	editor.call("_place_brush_at", Vector3(22.0, 0.175, 22.0))
	await process_frame
	if document.entities().size() != original_count + 1:
		push_error("WORLD_EDITOR_FLOW_FAILED surface brush did not add exactly one entity")
		quit(1)
		return
	editor.call("_set_tool_mode", "select")
	editor.call("_update_selection_marker")
	await process_frame
	if (editor.get("gizmo_handles") as Array).size() != 6:
		push_error("WORLD_EDITOR_FLOW_FAILED selected surface does not expose six resize handles")
		quit(1)
		return
	var surface_id := String(editor.get("selected_id"))
	var screen_center := root.get_visible_rect().size * 0.5
	var terrain_entity: Dictionary = {}
	for raw: Variant in document.entities():
		var candidate := raw as Dictionary
		if String(candidate.get("type", "")) == "terrain":
			terrain_entity = candidate
			break
	if terrain_entity.is_empty():
		editor.call("_create_terrain_preset", "flat", "Probe", "mediterranean_grass", 0.0)
		await process_frame
		terrain_entity = document.find_entity(String(editor.get("selected_id")))
	if terrain_entity.is_empty() or String(terrain_entity.get("type", "")) != "terrain":
		push_error("WORLD_EDITOR_FLOW_FAILED terrain creation unavailable for edge-resize test")
		quit(1)
		return
	var terrain_properties := terrain_entity.get("properties", {}) as Dictionary
	var terrain_base_material := String(terrain_properties.get("material", ""))
	var weights_before_base_change := (terrain_properties.get("material_weights", []) as Array).duplicate()
	editor.call("_set_terrain_base_material", terrain_entity, "sandstone_floor")
	await process_frame
	if String(terrain_properties.get("material", "")) != "sandstone_floor" or terrain_properties.get("material_weights", []) != weights_before_base_change:
		push_error("WORLD_EDITOR_FLOW_FAILED global terrain texture did not preserve local paint weights")
		quit(1)
		return
	terrain_base_material = "sandstone_floor"
	editor.set("selected_id", "")
	editor.call("_set_tool_mode", "select")
	var library_category := editor.get("library_category") as OptionButton
	library_category.select(2)
	editor.call("_refresh_library")
	editor.call("_select_material", "rough_stone")
	await process_frame
	if library_category.selected != 2 or String(editor.get("selected_id")) != String(terrain_entity.get("id", "")) or String(editor.get("tool_mode")) != "terrain" or String(editor.get("terrain_tool")) != "paint":
		push_error("WORLD_EDITOR_FLOW_FAILED choosing a texture did not keep the texture tab open with the terrain paint brush equipped")
		quit(1)
		return
	editor.call("_apply_terrain_stamp", terrain_entity, Vector3.ZERO)
	await process_frame
	if String(terrain_properties.get("material", "")) != terrain_base_material or not (terrain_properties.get("material_weights", []) as Array).any(func(value: Variant) -> bool: return float(value) > 0.0):
		push_error("WORLD_EDITOR_FLOW_FAILED automatic texture brush replaced the base instead of painting a local layer")
		quit(1)
		return
	var terrain_width_before := float(terrain_properties.get("width", 64.0))
	var terrain_position_before := HopliteWorldDocument.vector3(terrain_entity.get("position", []))
	var terrain_height_before := HopliteWorldTerrain.height_at(terrain_properties, 0.0, 0.0)
	editor.set("selected_id", String(terrain_entity.get("id", "")))
	editor.call("_set_tool_mode", "select")
	editor.call("_update_selection_marker")
	await process_frame
	var terrain_handles := editor.get("gizmo_handles") as Array
	if terrain_handles.size() != 4 or not terrain_handles.all(func(handle: Node) -> bool: return bool(handle.get_meta("gizmo_terrain_edge", false)) and int(handle.get_meta("gizmo_axis", 1)) in [0, 2]):
		push_error("WORLD_EDITOR_FLOW_FAILED selected terrain does not expose four X/Z edge handles")
		quit(1)
		return
	var positive_x_handle: Node = null
	for handle: Node in terrain_handles:
		if int(handle.get_meta("gizmo_axis", -1)) == 0 and float(handle.get_meta("gizmo_sign", 0.0)) > 0.0:
			positive_x_handle = handle
			break
	if positive_x_handle == null:
		push_error("WORLD_EDITOR_FLOW_FAILED positive X terrain handle unavailable")
		quit(1)
		return
	editor.call("_begin_resize", positive_x_handle, screen_center)
	editor.set("resize_start_scalar", float(editor.get("resize_start_scalar")) - 8.0)
	editor.call("_update_resize", screen_center)
	editor.call("_finish_resize")
	await process_frame
	if not is_equal_approx(float(terrain_properties.get("width", 0.0)), terrain_width_before + 8.0) or not is_equal_approx(HopliteWorldDocument.vector3(terrain_entity.get("position", [])).x, terrain_position_before.x + 4.0):
		push_error("WORLD_EDITOR_FLOW_FAILED positive X terrain handle did not extend only the selected side")
		quit(1)
		return
	if absf(HopliteWorldTerrain.height_at(terrain_properties, -4.0, 0.0) - terrain_height_before) > 0.20:
		push_error("WORLD_EDITOR_FLOW_FAILED terrain edge drag shifted the existing world relief")
		quit(1)
		return
	var slope_normal := Vector3(0.28, 0.92, -0.18).normalized()
	var slope_rotation := editor.call("_rotation_aligned_to_normal", slope_normal, 25.0) as Vector3
	var slope_basis := Basis.from_euler(Vector3(deg_to_rad(slope_rotation.x), deg_to_rad(slope_rotation.y), deg_to_rad(slope_rotation.z)))
	if slope_basis.y.dot(slope_normal) < 0.999:
		push_error("WORLD_EDITOR_FLOW_FAILED slope alignment did not match the terrain normal")
		quit(1)
		return
	editor.set("selected_id", surface_id)
	editor.call("_update_selection_marker")
	var moved_surface := document.find_entity(surface_id)
	editor.call("_begin_move", moved_surface, screen_center, "horizontal")
	var plane_point := editor.call("_screen_plane_point", screen_center, 0.175) as Vector3
	editor.set("move_drag_start_world", plane_point - Vector3(2.0, 0.0, 3.0))
	editor.call("_update_move", screen_center)
	editor.call("_finish_move")
	await process_frame
	var surface_position := HopliteWorldDocument.vector3(moved_surface.get("position", []))
	if not is_equal_approx(surface_position.x, 24.0) or not is_equal_approx(surface_position.z, 25.0):
		push_error("WORLD_EDITOR_FLOW_FAILED Ctrl-style horizontal move did not stay on the plane")
		quit(1)
		return
	editor.set("last_mouse_position", screen_center)
	editor.call("_begin_rotation", 1)
	editor.call("_update_rotation", screen_center + Vector2(100.0, 0.0))
	var horizontal_rotation := HopliteWorldDocument.vector3(moved_surface.get("rotation", []))
	var rotation_indicator := editor.get("rotation_indicator") as MeshInstance3D
	if not is_equal_approx(horizontal_rotation.y, 45.0) or not rotation_indicator.visible:
		push_error("WORLD_EDITOR_FLOW_FAILED R did not start horizontal Y rotation with a visible axis ring")
		quit(1)
		return
	editor.call("_finish_rotation", true)
	await process_frame
	editor.set("last_mouse_position", screen_center)
	editor.call("_begin_rotation", 0)
	editor.call("_update_rotation", screen_center - Vector2(0.0, 100.0))
	var vertical_rotation := HopliteWorldDocument.vector3(moved_surface.get("rotation", []))
	if not is_equal_approx(vertical_rotation.x, 45.0):
		push_error("WORLD_EDITOR_FLOW_FAILED Shift+R did not tilt on local X")
		quit(1)
		return
	editor.call("_finish_rotation", false)
	await process_frame
	var cancelled_rotation := HopliteWorldDocument.vector3(moved_surface.get("rotation", []))
	if not is_equal_approx(cancelled_rotation.x, 0.0) or rotation_indicator.visible:
		push_error("WORLD_EDITOR_FLOW_FAILED cancelled vertical rotation was not restored cleanly")
		quit(1)
		return
	var count_before_prop := document.entities().size()
	editor.call("_select_brush", "CAISSES TEST", "prop", {"asset_id": "crates"})
	editor.call("_place_brush_at", Vector3(8.0, 1.0, 8.0))
	await process_frame
	if document.entities().size() != count_before_prop + 1:
		push_error("WORLD_EDITOR_FLOW_FAILED object brush did not add exactly one entity")
		quit(1)
		return
	var prop_id := String(editor.get("selected_id"))
	var prop_entity := document.find_entity(prop_id)
	editor.call("_set_tool_mode", "select")
	editor.call("_update_selection_marker")
	await process_frame
	var prop_handles := editor.get("gizmo_handles") as Array
	if prop_handles.size() != 1 or not (prop_handles[0] as Node).has_meta("gizmo_uniform"):
		push_error("WORLD_EDITOR_FLOW_FAILED selected prop does not expose one uniform-scale handle")
		quit(1)
		return
	var runtime: HopliteWorldRuntime = editor.get("runtime") as HopliteWorldRuntime
	var demo_portal := document.find_by_name("Descendre dans les cryptes")
	var demo_portal_node := runtime.nodes_by_id.get(String(demo_portal.get("id", ""))) as Area3D
	if demo_portal_node == null:
		push_error("WORLD_EDITOR_FLOW_FAILED chapter portal is missing from the editor preview")
		quit(1)
		return
	var editor_camera_for_portal := editor.get("editor_camera") as Camera3D
	var previous_camera_transform := editor_camera_for_portal.global_transform
	editor_camera_for_portal.global_position = demo_portal_node.global_position + Vector3(0.0, 0.0, 6.0)
	editor_camera_for_portal.look_at(demo_portal_node.global_position, Vector3.UP)
	await physics_frame
	var portal_hit := editor.call("_ray_hit", screen_center, 16) as Dictionary
	editor_camera_for_portal.global_transform = previous_camera_transform
	if String(editor.call("_entity_id_from_hit", portal_hit)) != String(demo_portal.get("id", "")):
		push_error("WORLD_EDITOR_FLOW_FAILED chapter portal cannot be selected through its visible volume")
		quit(1)
		return
	var prop_node := runtime.nodes_by_id.get(prop_id) as Node3D
	if prop_node == null or not prop_node.has_meta("editor_local_bounds"):
		push_error("WORLD_EDITOR_FLOW_FAILED prop selection does not use measured visual bounds")
		quit(1)
		return
	editor.call("_set_uniform_entity_scale", prop_entity, 1.75)
	await process_frame
	await process_frame
	var prop_scale := HopliteWorldDocument.vector3(prop_entity.get("scale", []), Vector3.ONE)
	if not prop_scale.is_equal_approx(Vector3.ONE * 1.75):
		push_error("WORLD_EDITOR_FLOW_FAILED prop scale is not uniform")
		quit(1)
		return
	var prop_bottom_offset := float(editor.call("_entity_bottom_offset", prop_entity))
	var pre_move_support := editor.call("_find_support_floor", prop_entity, Vector2(8.0, 8.0), 1.0) as Dictionary
	var prop_visual_size := editor.call("_entity_visual_size", prop_entity) as Vector3
	editor.call("_begin_move", prop_entity, screen_center, "vertical")
	editor.call("_update_move", screen_center)
	var ground_marker := editor.get("ground_snap_marker") as MeshInstance3D
	var grounded_position := HopliteWorldDocument.vector3(prop_entity.get("position", []))
	if not ground_marker.visible or not is_equal_approx(grounded_position.y + prop_bottom_offset, 0.175):
		push_error("WORLD_EDITOR_FLOW_FAILED vertical move did not align and highlight the support floor marker=%s y=%.4f bottom_offset=%.4f bottom=%.4f visual_y=%.4f support=%s" % [ground_marker.visible, grounded_position.y, prop_bottom_offset, grounded_position.y + prop_bottom_offset, prop_visual_size.y, str(pre_move_support)])
		quit(1)
		return
	editor.call("_finish_move")
	await process_frame
	if ground_marker.visible:
		push_error("WORLD_EDITOR_FLOW_FAILED floor alignment highlight remained after mouse release")
		quit(1)
		return
	editor.call("_set_ghost_mode", true)
	await process_frame
	var editor_camera := editor.get("editor_camera") as Camera3D
	if not bool(editor.get("ghost_mode")) or not editor_camera.position.is_zero_approx():
		push_error("WORLD_EDITOR_FLOW_FAILED ghost mode did not switch to first-person camera")
		quit(1)
		return
	editor.call("_set_ghost_mode", false)
	await process_frame
	editor.call("_toggle_left_panel")
	editor.call("_toggle_right_panel")
	if (editor.get("left_panel") as Control).visible or (editor.get("right_panel") as Control).visible:
		push_error("WORLD_EDITOR_FLOW_FAILED editor panels did not collapse independently")
		quit(1)
		return
	editor.call("_toggle_left_panel")
	editor.call("_toggle_right_panel")
	editor.call("_delete_selected")
	await process_frame
	if document.entities().size() != count_before_prop:
		push_error("WORLD_EDITOR_FLOW_FAILED eraser/delete path did not remove the selected object")
		quit(1)
		return
	var stroke_start_index := document.entities().size()
	editor.set("surface_brush_shape", "block")
	editor.set("surface_brush_size", Vector3(3.0, 2.0, 5.0))
	editor.call("_equip_custom_surface_brush")
	var custom_brush_size := HopliteWorldDocument.vector3((editor.get("brush_properties") as Dictionary).get("size", []), Vector3.ONE)
	if String((editor.get("brush_properties") as Dictionary).get("shape", "")) != "block" or not custom_brush_size.is_equal_approx(Vector3(3.0, 2.0, 5.0)):
		push_error("WORLD_EDITOR_FLOW_FAILED custom surface dimensions were not applied to the brush")
		quit(1)
		return
	editor.call("_select_brush", "MUR TRACE TEST", "surface", {"shape": "wall", "size": [1.0, 1.0, 0.25], "material": "fortress"})
	editor.call("_begin_brush_stroke", Vector3(35.0, 0.5, 35.0))
	editor.call("_paint_brush_stroke_to", Vector3(38.0, 0.5, 41.0), true)
	editor.call("_finish_brush_stroke")
	await process_frame
	var stroke_entities := document.entities().slice(stroke_start_index)
	if stroke_entities.size() < 6:
		push_error("WORLD_EDITOR_FLOW_FAILED held brush did not create a continuous stroke")
		quit(1)
		return
	for raw: Variant in stroke_entities:
		var stroke_entity := raw as Dictionary
		var stroke_position := HopliteWorldDocument.vector3(stroke_entity.get("position", []))
		var stroke_rotation := HopliteWorldDocument.vector3(stroke_entity.get("rotation", []))
		if not is_equal_approx(stroke_position.x, 35.0) or not is_equal_approx(stroke_rotation.y, 90.0):
			push_error("WORLD_EDITOR_FLOW_FAILED Shift did not constrain and orient the wall stroke")
			quit(1)
			return
	var guard_group := document.find_by_name("Garde de l'agora")
	if guard_group.is_empty():
		push_error("WORLD_EDITOR_FLOW_FAILED example enemy troop unavailable")
		quit(1)
		return
	var guard_properties := guard_group.get("properties", {}) as Dictionary
	guard_properties["behavior"] = "patrol"
	var patrol_before := int(editor.call("_patrol_point_count", String(guard_properties.get("route_id", ""))))
	editor.call("_begin_patrol_mapping", guard_group)
	var added_patrol_id := String(editor.call("_add_patrol_point_at", Vector3(4.0, 0.08, 4.0)))
	if added_patrol_id.is_empty() or int(editor.call("_patrol_point_count", String(guard_properties.get("route_id", "")))) != patrol_before + 1:
		push_error("WORLD_EDITOR_FLOW_FAILED map patrol authoring did not append an ordered point")
		quit(1)
		return
	editor.call("_finish_capture_mode")
	guard_properties["behavior"] = "protect"
	editor.set("capture_mode", "protect")
	editor.set("capture_source_id", String(guard_group.get("id", "")))
	var protected_prop := document.find_by_name("Brasero gauche")
	if not bool(editor.call("_assign_captured_reference", protected_prop)) or String(guard_properties.get("protect_target", "")) != String(protected_prop.get("id", "")):
		push_error("WORLD_EDITOR_FLOW_FAILED protect behavior did not capture a clicked object")
		quit(1)
		return
	var formations := ["line", "column", "square", "circle", "wedge", "phalanx", "arc", "scattered"]
	for formation in formations:
		if (runtime.call("_formation_positions", 9, formation, 1.5) as Array).size() != 9:
			push_error("WORLD_EDITOR_FLOW_FAILED formation unavailable: %s" % formation)
			quit(1)
			return
	var previous_selection := String(editor.get("selected_id"))
	var capture_source := HopliteWorldDocument.entity("enemy_group", "Source selection test", Vector3(20.0, 0.1, 20.0), {"group_id": "source_selection_test", "archetype": "nathenian1", "count": 1, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "line", "spawn_condition": "start", "spawn_dead_group": ""})
	var capture_source_id := document.add_entity(capture_source)
	capture_source = document.find_entity(capture_source_id)
	editor.call("_rebuild_preview")
	editor.set("selected_id", String(guard_group.get("id", "")))
	editor.call("_focus_selected")
	await process_frame
	await physics_frame
	editor.call("_begin_reference_capture", capture_source, "spawn_dead")
	var capture_screen_center := root.get_visible_rect().size * 0.5
	editor.call("_capture_reference_at", capture_screen_center)
	var capture_source_properties := capture_source.get("properties", {}) as Dictionary
	if String(capture_source_properties.get("spawn_dead_group", "")) != String(guard_properties.get("group_id", "")):
		push_error("WORLD_EDITOR_FLOW_FAILED clicking the visible troop did not select it as a death condition")
		quit(1)
		return
	editor.set("selected_id", previous_selection)
	editor.call("_rebuild_preview")
	var trigger := HopliteWorldDocument.entity("trigger", "Zone test spawn", Vector3(34.0, 1.5, 34.0), {"size": [5.0, 3.0, 5.0], "condition": "player_enter", "action": "none", "once": true})
	var trigger_id := document.add_entity(trigger)
	var deferred_group := HopliteWorldDocument.entity("enemy_group", "Renfort test", Vector3(36.0, 0.1, 36.0), {"group_id": "renfort_test", "archetype": "nathenian1", "count": 2, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "wedge", "spawn_condition": "trigger", "spawn_trigger": trigger_id})
	document.add_entity(deferred_group)
	var timer_group := HopliteWorldDocument.entity("enemy_group", "Timer test", Vector3(38.0, 0.1, 36.0), {"group_id": "timer_test", "archetype": "nathenian1", "count": 1, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "arc", "spawn_condition": "timer", "spawn_delay": 0.1})
	document.add_entity(timer_group)
	var death_narrative_trigger := HopliteWorldDocument.entity("trigger", "Narration globale apres mort", Vector3(-200.0, 1.5, -200.0), {"size": [2.0, 2.0, 2.0], "condition": "group_dead", "condition_group": "source_selection_test", "action": "narrative", "narrative_mode": "direct", "action_speaker": "Test", "action_text": "Mort globale OK", "action_duration": 4.0, "once": true})
	document.add_entity(death_narrative_trigger)
	var stop_waves_trigger := HopliteWorldDocument.entity("trigger", "Arret vagues test", Vector3(-220.0, 1.5, -220.0), {"size": [2.0, 2.0, 2.0], "condition": "player_enter", "action": "none", "once": true})
	var stop_waves_trigger_id := document.add_entity(stop_waves_trigger)
	var lone_spear := HopliteWorldDocument.entity("enemy_group", "Lancier isole test", Vector3(3.0, 0.1, 12.0), {"group_id": "lone_spear_test", "archetype": "ngeneral", "count": 1, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "line", "spawn_condition": "start", "deployment_mode": "all"})
	document.add_entity(lone_spear)
	var reserve_group := HopliteWorldDocument.entity("enemy_group", "Reserve test", Vector3(33.0, 0.1, 36.0), {"group_id": "reserve_test", "archetype": "nathenian1", "count": 9, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "line", "spawn_condition": "start", "deployment_mode": "reserve", "initial_active": 4, "reinforce_threshold": 3, "reinforce_amount": 2})
	var reserve_group_id := document.add_entity(reserve_group)
	var waves_group := HopliteWorldDocument.entity("enemy_group", "Vagues test", Vector3(37.0, 0.1, 37.0), {"group_id": "waves_test", "archetype": "nathenian1", "count": 6, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "column", "spawn_condition": "start", "deployment_mode": "waves", "wave_size": 2, "wave_interval": 10.0, "deployment_stop_trigger": stop_waves_trigger_id})
	var waves_group_id := document.add_entity(waves_group)
	var death_stop_waves := HopliteWorldDocument.entity("enemy_group", "Vagues stop mort test", Vector3(40.0, 0.1, 40.0), {"group_id": "death_stop_waves_test", "archetype": "nathenian1", "count": 6, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "column", "spawn_condition": "start", "deployment_mode": "waves", "wave_size": 2, "wave_interval": 10.0, "deployment_stop_mode": "unit_death", "deployment_stop_group": "reserve_test"})
	var death_stop_waves_id := document.add_entity(death_stop_waves)
	var scaled_enemy_group := HopliteWorldDocument.entity("enemy_group", "Geant cadavre test", Vector3(45.0, 0.1, 45.0), {"group_id": "scaled_enemy_test", "archetype": "ngeneral", "count": 1, "rank": "normal", "size_multiplier": 2.0, "match_perfect_hitbox": true, "behavior": "normal", "formation": "line", "spawn_condition": "start", "deployment_mode": "all"})
	document.add_entity(scaled_enemy_group)
	var selected_test_group := HopliteWorldDocument.entity("enemy_group", "Selection test F6", Vector3(-40.0, 0.1, -40.0), {"group_id": "selected_test_f6", "archetype": "nathenian1", "count": 1, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "line", "spawn_condition": "start", "deployment_mode": "all"})
	var selected_test_group_id := document.add_entity(selected_test_group)
	var distant_test_group := HopliteWorldDocument.entity("enemy_group", "Groupe lointain test F6", Vector3(40.0, 0.1, -40.0), {"group_id": "distant_test_f6", "archetype": "nathenian1", "count": 1, "rank": "normal", "size_multiplier": 1.0, "behavior": "normal", "formation": "line", "spawn_condition": "start", "deployment_mode": "all"})
	document.add_entity(distant_test_group)
	var mixed_phalanx_properties := {"archetype": "ngeneral", "count": 15, "composition": [{"archetype": "ngeneral", "count": 11}, {"archetype": "ngeneral_veteran", "count": 4}]}
	if StringName(runtime.call("_enemy_archetype_for_index", mixed_phalanx_properties, 10)) != &"ngeneral" or StringName(runtime.call("_enemy_archetype_for_index", mixed_phalanx_properties, 11)) != &"ngeneral_veteran":
		push_error("WORLD_EDITOR_FLOW_FAILED mixed phalanx composition did not preserve 11 spearmen and 4 veterans")
		quit(1)
		return
	# Regression: the legacy local radius and the last selection must not filter
	# encounters from the authoritative F6 gameplay test.
	(document.data.get("settings", {}) as Dictionary)["test_radius"] = 4.0
	editor.set("selected_id", selected_test_group_id)
	editor.call("_rebuild_preview")
	editor.call("_start_test")
	await create_timer(0.3).timeout
	if not bool(editor.get("test_mode")):
		push_error("WORLD_EDITOR_FLOW_FAILED test mode did not start")
		quit(1)
		return
	var event_runtime := editor.get("event_runtime") as HopliteWorldEventRuntime
	if runtime.living_count("renfort_test") != 0 or runtime.living_count("timer_test") != 1:
		push_error("WORLD_EDITOR_FLOW_FAILED deferred/timer spawn conditions were not respected")
		quit(1)
		return
	if runtime.crowd_director == null or runtime.living_count("lone_spear_test") != 1:
		push_error("WORLD_EDITOR_FLOW_FAILED lone spearman has no tactical director or did not spawn")
		quit(1)
		return
	if runtime.living_count("selected_test_f6") != 1 or runtime.living_count("distant_test_f6") != 1:
		push_error("WORLD_EDITOR_FLOW_FAILED F6 filtered enemies using the last selection or legacy test radius")
		quit(1)
		return
	var lone_spear_enemy := (runtime.enemies_by_group.get("lone_spear_test", []) as Array)[0] as Node3D
	var spear_assignment := runtime.crowd_director.phalanx_assignment(lone_spear_enemy, runtime.player, 5, 1.08, 1.18, 2.42)
	if spear_assignment.is_empty():
		push_error("WORLD_EDITOR_FLOW_FAILED lone spearman remained without a phalanx/combat assignment")
		quit(1)
		return
	var lone_combat_goal := lone_spear_enemy.call("_phalanx_combat_goal", 2.0) as Dictionary
	if String(lone_spear_enemy.get("ai_state")) != "phalanx_duel" or not bool(lone_combat_goal.get("attack_player", false)):
		push_error("WORLD_EDITOR_FLOW_FAILED lone spearman did not enter functional duel behavior")
		quit(1)
		return
	var scaled_enemies := runtime.enemies_by_group.get("scaled_enemy_test", []) as Array
	if scaled_enemies.size() != 1 or not is_equal_approx((scaled_enemies[0] as Node3D).scale.x, 2.0):
		push_error("WORLD_EDITOR_FLOW_FAILED enemy scale was not applied before runtime initialization")
		quit(1)
		return
	var scaled_enemy := scaled_enemies[0] as Node3D
	if not bool(scaled_enemy.get("match_perfect_hitbox")) or (scaled_enemy.get("matched_walkable_surfaces") as Array).size() != 2:
		push_error("WORLD_EDITOR_FLOW_FAILED Forge perfect-hitbox option did not reach runtime enemy surfaces")
		quit(1)
		return
	scaled_enemy.call("_die", false)
	var scaled_visual := scaled_enemy.get("visual_root") as Node3D
	for corpse_sample in range(24):
		await create_timer(0.055).timeout
		if scaled_visual == null or not scaled_visual.visible or not is_finite(scaled_visual.position.y) or absf(scaled_visual.position.y) > 3.0:
			push_error("WORLD_EDITOR_FLOW_FAILED scaled corpse became hidden or its grounding diverged")
			quit(1)
			return
	if runtime.living_count("reserve_test") != 4 or runtime.living_count("waves_test") != 2 or runtime.living_count("death_stop_waves_test") != 2:
		push_error("WORLD_EDITOR_FLOW_FAILED initial reserve/wave deployment counts are incorrect")
		quit(1)
		return
	event_runtime.call("_fire", document.find_entity(stop_waves_trigger_id))
	event_runtime.call("_tick_deployment", waves_group_id)
	var waves_state := event_runtime.deployment_states.get(waves_group_id, {}) as Dictionary
	if not bool(waves_state.get("stopped", false)) or runtime.living_count("waves_test") != 2:
		push_error("WORLD_EDITOR_FLOW_FAILED selected stop event did not halt periodic waves")
		quit(1)
		return
	var reserve_enemies := runtime.enemies_by_group.get("reserve_test", []) as Array
	for reserve_index in range(2):
		var reserve_enemy := reserve_enemies[reserve_index] as Node
		reserve_enemy.set("dead", true)
		reserve_enemy.emit_signal("died", reserve_enemy)
	await process_frame
	var death_stop_state := event_runtime.deployment_states.get(death_stop_waves_id, {}) as Dictionary
	if not bool(death_stop_state.get("stopped", false)) or runtime.living_count("death_stop_waves_test") != 2:
		push_error("WORLD_EDITOR_FLOW_FAILED first death in selected troop did not halt periodic waves")
		quit(1)
		return
	var reserve_state := event_runtime.deployment_states.get(reserve_group_id, {}) as Dictionary
	if int(reserve_state.get("deployed", 0)) != 6 or runtime.living_count("reserve_test") != 4:
		push_error("WORLD_EDITOR_FLOW_FAILED reserve did not add 2 soldiers below threshold 3")
		quit(1)
		return
	event_runtime.call("_on_player_entered_trigger", trigger_id)
	await process_frame
	if runtime.living_count("renfort_test") != 2:
		push_error("WORLD_EDITOR_FLOW_FAILED crossing a named trigger did not spawn its troop")
		quit(1)
		return
	var observed_enemies := runtime.enemies_by_group.get("source_selection_test", []) as Array
	if observed_enemies.size() != 1:
		push_error("WORLD_EDITOR_FLOW_FAILED observed troop unavailable for global death event")
		quit(1)
		return
	var observed_enemy := observed_enemies[0] as Node
	observed_enemy.emit_signal("died", observed_enemy)
	await process_frame
	var narrative_panel := editor.get("narrative_panel") as Control
	var narrative_text := editor.get("narrative_text") as Label
	if not narrative_panel.visible or narrative_text.text != "Mort globale OK":
		push_error("WORLD_EDITOR_FLOW_FAILED a troop death did not display global narration away from its box")
		quit(1)
		return
	editor.call("_stop_test")
	await process_frame
	if bool(editor.get("test_mode")):
		push_error("WORLD_EDITOR_FLOW_FAILED test mode did not stop")
		quit(1)
		return
	print("WORLD_EDITOR_FLOW_OK")
	quit(0)
