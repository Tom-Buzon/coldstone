"""Inspect every mesh in the externally supplied elemental sword collection."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def bounds(points: list[Vector]) -> tuple[Vector, Vector]:
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return minimum, maximum


def main() -> None:
    source = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = sorted((obj for obj in bpy.context.scene.objects if obj.type == "MESH"), key=lambda obj: obj.name)
    print(f"[ELEMENTAL INSPECT] source={source} meshes={len(meshes)}")
    for obj in meshes:
        local_points = [Vector(corner) for corner in obj.bound_box]
        world_points = [obj.matrix_world @ point for point in local_points]
        local_min, local_max = bounds(local_points)
        world_min, world_max = bounds(world_points)
        triangles = sum(max(0, len(face.vertices) - 2) for face in obj.data.polygons)
        material_names = [material.name for material in obj.data.materials if material is not None]
        print(f"OBJECT {obj.name}")
        print(f"  mesh={obj.data.name} parent={obj.parent.name if obj.parent else '-'}")
        print(f"  location={tuple(round(value, 5) for value in obj.location)} rotation={tuple(round(value, 5) for value in obj.rotation_euler)} scale={tuple(round(value, 5) for value in obj.scale)}")
        print(f"  local_min={tuple(round(value, 5) for value in local_min)} local_max={tuple(round(value, 5) for value in local_max)} local_dims={tuple(round(value, 5) for value in local_max - local_min)}")
        print(f"  world_min={tuple(round(value, 5) for value in world_min)} world_max={tuple(round(value, 5) for value in world_max)} world_dims={tuple(round(value, 5) for value in world_max - world_min)}")
        print(f"  triangles={triangles} vertices={len(obj.data.vertices)} materials={material_names}")
        vertices = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
        z_min = min(vertex.z for vertex in vertices)
        z_max = max(vertex.z for vertex in vertices)
        bin_count = 16
        for bin_index in range(bin_count):
            low = z_min + (z_max - z_min) * bin_index / bin_count
            high = z_min + (z_max - z_min) * (bin_index + 1) / bin_count
            sample = [vertex for vertex in vertices if low <= vertex.z <= high]
            if not sample:
                continue
            x_span = max(vertex.x for vertex in sample) - min(vertex.x for vertex in sample)
            y_span = max(vertex.y for vertex in sample) - min(vertex.y for vertex in sample)
            print(f"  slice={bin_index:02d} z={low:.2f}:{high:.2f} x_span={x_span:.2f} y_span={y_span:.2f} points={len(sample)}")


if __name__ == "__main__":
    main()
