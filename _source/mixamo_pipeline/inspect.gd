extends SceneTree

const FILES := [
    "res://output/knight2.glb",
    "res://output/smallsbir1.glb",
    "res://input/Axe Standing Melee Attack Downward.fbx",
    "res://output/axe_standing_melee_attack_downward.glb",
    "res://input/Running To Turn.fbx",
    "res://input/Bow Standing Aim Walk Back.fbx",
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for path: String in FILES:
        var packed := load(path) as PackedScene
        if packed == null:
            push_error("Could not inspect " + path)
            continue
        var root := packed.instantiate()
        print("[INSPECT ROOT] ", path)
        _print_tree(root, "")
        root.free()
    quit()

func _print_tree(node: Node, indent: String) -> void:
    print(indent, node.name, " <", node.get_class(), ">")
    if node is Skeleton3D:
        var skeleton := node as Skeleton3D
        var names: PackedStringArray = []
        for index: int in range(skeleton.get_bone_count()):
            names.append(skeleton.get_bone_name(index))
        print(indent, "  bones=", names)
    elif node is AnimationPlayer:
        var player := node as AnimationPlayer
        for animation_name: StringName in player.get_animation_list():
            var animation := player.get_animation(animation_name)
            print(indent, "  animation=", animation_name, " length=", animation.length, " tracks=", animation.get_track_count())
            for track_index: int in range(animation.get_track_count()):
                var track_path := String(animation.track_get_path(track_index)).to_lower()
                if track_path.ends_with(":mixamorig_hips") and animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
                    var samples: PackedFloat32Array = []
                    for sample_index: int in range(10):
                        var sample_time: float = animation.length * float(sample_index) / 9.0
                        var rotation := animation.rotation_track_interpolate(track_index, sample_time)
                        samples.append(rad_to_deg(rotation.get_euler().y))
                    print(indent, "    hips_y_degrees=", samples)
            for track_index: int in range(mini(animation.get_track_count(), 8)):
                print(indent, "    ", track_index, " ", animation.track_get_path(track_index), " type=", animation.track_get_type(track_index))
    for child: Node in node.get_children():
        _print_tree(child, indent + "  ")
