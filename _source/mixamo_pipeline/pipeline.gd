extends SceneTree

const INPUT_DIR := "res://input"
const OUTPUT_DIR := "res://output"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    var directory := DirAccess.open(INPUT_DIR)
    if directory == null:
        push_error("[MIXAMO PIPELINE] Missing input directory")
        quit(1)
        return

    var files: PackedStringArray = directory.get_files()
    files.sort()
    var failures: int = 0
    for file_name: String in files:
        if file_name.get_extension().to_lower() != "fbx":
            continue
        if not _convert_file(file_name):
            failures += 1
    print("[MIXAMO PIPELINE] completed files=", files.size(), " failures=", failures)
    quit(1 if failures > 0 else 0)

func _convert_file(file_name: String) -> bool:
    var source_path := INPUT_DIR.path_join(file_name)
    var packed := load(source_path) as PackedScene
    if packed == null:
        push_error("[MIXAMO PIPELINE] Could not load " + source_path)
        return false
    var root := packed.instantiate()
    var stats := _scene_stats(root)
    print("[MIXAMO ASSET] ", file_name, " | skeletons=", stats.skeletons, " bones=", stats.bones, " meshes=", stats.meshes, " vertices=", stats.vertices, " animations=", stats.animations)

    var document := GLTFDocument.new()
    document.image_format = "JPEG"
    document.fallback_image_format = "PNG"
    document.lossy_quality = 0.78
    var state := GLTFState.new()
    var append_error := document.append_from_scene(root, state)
    if append_error != OK:
        push_error("[MIXAMO PIPELINE] append_from_scene failed for %s: %s" % [file_name, error_string(append_error)])
        root.free()
        return false
    var output_name := _safe_name(file_name.get_basename()) + ".glb"
    var output_path := OUTPUT_DIR.path_join(output_name)
    var write_error := document.write_to_filesystem(state, ProjectSettings.globalize_path(output_path))
    root.free()
    if write_error != OK:
        push_error("[MIXAMO PIPELINE] write failed for %s: %s" % [file_name, error_string(write_error)])
        return false
    var output_size := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(output_path)).size()
    print("[MIXAMO OUTPUT] ", output_name, " bytes=", output_size)
    return true

func _scene_stats(root: Node) -> Dictionary:
    var result := {"skeletons": 0, "bones": 0, "meshes": 0, "vertices": 0, "animations": []}
    _collect_stats(root, result)
    return result

func _collect_stats(node: Node, result: Dictionary) -> void:
    if node is Skeleton3D:
        result.skeletons = int(result.skeletons) + 1
        result.bones = int(result.bones) + (node as Skeleton3D).get_bone_count()
    elif node is MeshInstance3D:
        var mesh := (node as MeshInstance3D).mesh
        if mesh != null:
            result.meshes = int(result.meshes) + 1
            for surface_index: int in range(mesh.get_surface_count()):
                var arrays := mesh.surface_get_arrays(surface_index)
                if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
                    result.vertices = int(result.vertices) + (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
    elif node is AnimationPlayer:
        for animation_name: StringName in (node as AnimationPlayer).get_animation_list():
            var animation := (node as AnimationPlayer).get_animation(animation_name)
            (result.animations as Array).append("%s(%.2fs)" % [animation_name, animation.length if animation != null else 0.0])
    for child: Node in node.get_children():
        _collect_stats(child, result)

func _safe_name(raw_name: String) -> String:
    var result := raw_name.to_lower()
    for character: String in [" ", ".", "-", "/", "\\"]:
        result = result.replace(character, "_")
    while "__" in result:
        result = result.replace("__", "_")
    return result.trim_suffix("_")
