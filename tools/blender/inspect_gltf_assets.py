"""Print concise glTF/GLB scene metrics without saving or modifying an asset."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions):
        for item in list(block):
            block.remove(item)


def inspect(path: Path) -> None:
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(path))
    corners: list[Vector] = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        corners.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if corners:
        minimum = Vector((min(value.x for value in corners), min(value.y for value in corners), min(value.z for value in corners)))
        maximum = Vector((max(value.x for value in corners), max(value.y for value in corners), max(value.z for value in corners)))
        print(f"ASSET {path.name}")
        print(f"  bounds_min {tuple(round(value, 5) for value in minimum)}")
        print(f"  bounds_max {tuple(round(value, 5) for value in maximum)}")
        print(f"  dimensions {tuple(round(value, 5) for value in maximum - minimum)}")
    for armature in (obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"):
        print(f"  armature {armature.name} bones={len(armature.data.bones)}")
        useful = [
            bone.name
            for bone in armature.data.bones
            if any(token in bone.name.lower() for token in ("root", "spine", "neck", "head", "jaw", "tail", "hip", "pelvis", "leg", "knee", "ankle", "wing"))
        ]
        print("  useful_bones " + " | ".join(useful))
        if len(useful) <= 1:
            for bone in armature.data.bones:
                parent_name = bone.parent.name if bone.parent else "-"
                head = tuple(round(value, 4) for value in bone.head_local)
                tail = tuple(round(value, 4) for value in bone.tail_local)
                print(f"  bone {bone.name} parent={parent_name} head={head} tail={tail}")
    print("  actions " + " | ".join(action.name for action in bpy.data.actions))


if __name__ == "__main__":
    arguments = [Path(value).resolve() for value in sys.argv[sys.argv.index("--") + 1 :]]
    for asset_path in arguments:
        inspect(asset_path)
