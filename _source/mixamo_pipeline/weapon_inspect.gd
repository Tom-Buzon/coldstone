extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var directory := DirAccess.open("res://output")
    if directory == null:
        quit(1)
        return
    var files := directory.get_files()
    files.sort()
    for file_name: String in files:
        if not file_name.ends_with(".glb"):
            continue
        var packed := load("res://output/" + file_name) as PackedScene
        if packed == null:
            continue
        var root := packed.instantiate()
        get_root().add_child(root)
        var skeleton := _find_skeleton(root)
        var meshes: PackedStringArray = []
        _collect_mesh_names(root, meshes)
        var bounds := _collect_bounds(root)
        print("[MODEL] ", file_name, " meshes=", meshes, " bounds=", bounds)
        if skeleton != null:
            var hand_index := skeleton.find_bone("mixamorig_RightHand")
            var finger_index := skeleton.find_bone("mixamorig_RightHandMiddle1")
            if hand_index >= 0 and finger_index >= 0:
                var hand_rest := skeleton.get_bone_global_rest(hand_index)
                var finger_rest := skeleton.get_bone_global_rest(finger_index)
                var local_finger: Vector3 = hand_rest.affine_inverse() * finger_rest.origin
                print("  right_hand_to_middle_local=", local_finger.normalized())
            var feet: Dictionary = {}
            for bone_name: String in ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]:
                var bone_index := skeleton.find_bone(bone_name)
                if bone_index >= 0:
                    feet[bone_name] = (skeleton.global_transform * skeleton.get_bone_global_rest(bone_index)).origin
            print("  feet=", feet)
        root.free()
    quit()

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child: Node in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _collect_mesh_names(node: Node, output: PackedStringArray) -> void:
    if node is MeshInstance3D:
        output.append(String(node.name))
    for child: Node in node.get_children():
        _collect_mesh_names(child, output)

func _collect_bounds(root: Node) -> AABB:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(root, meshes)
    var result := AABB()
    var initialized := false
    for mesh: MeshInstance3D in meshes:
        var local_bounds := mesh.get_aabb()
        for x: int in 2:
            for y: int in 2:
                for z: int in 2:
                    var corner := local_bounds.position + Vector3(
                        local_bounds.size.x * float(x),
                        local_bounds.size.y * float(y),
                        local_bounds.size.z * float(z)
                    )
                    var point := mesh.global_transform * corner
                    if not initialized:
                        result = AABB(point, Vector3.ZERO)
                        initialized = true
                    else:
                        result = result.expand(point)
    return result

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child: Node in node.get_children():
        _collect_meshes(child, output)
