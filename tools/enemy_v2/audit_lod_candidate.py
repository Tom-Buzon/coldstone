"""Read-only Blender audit for a prospective character LOD."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


def _args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--report", required=True)
    return parser.parse_args(raw)


def _triangles(mesh: bpy.types.Mesh) -> int:
    return sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)


def _uv_inventory(mesh: bpy.types.Mesh) -> list[dict]:
    result: list[dict] = []
    for layer in mesh.uv_layers:
        values = [item.uv for item in layer.data]
        unique_x = sorted({round(float(value.x), 6) for value in values})
        result.append(
            {
                "name": layer.name,
                "loops": len(values),
                "x_min": min((float(value.x) for value in values), default=0.0),
                "x_max": max((float(value.x) for value in values), default=0.0),
                "unique_x_count": len(unique_x),
                "unique_x_sample": unique_x[:32],
                "non_integer_x_loops": sum(
                    1 for value in values if abs(float(value.x) - round(float(value.x))) > 0.0001
                ),
            }
        )
    return result


def main() -> None:
    args = _args()
    source = Path(args.input).resolve()
    report = Path(args.report).resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    result = {
        "schema_version": 1,
        "source": str(source),
        "source_bytes": source.stat().st_size,
        "objects": sorted(obj.name for obj in bpy.context.scene.objects),
        "armatures": [
            {"name": armature.name, "bones": [bone.name for bone in armature.data.bones]}
            for armature in armatures
        ],
        "meshes": [
            {
                "name": obj.name,
                "vertices": len(obj.data.vertices),
                "triangles": _triangles(obj.data),
                "dimensions": [round(float(value), 6) for value in obj.dimensions],
                "scale": [round(float(value), 6) for value in obj.scale],
                "rotation_euler": [round(float(value), 6) for value in obj.rotation_euler],
                "uv_layers": [layer.name for layer in obj.data.uv_layers],
                "uv_inventory": _uv_inventory(obj.data),
                "active_uv": obj.data.uv_layers.active.name if obj.data.uv_layers.active else None,
                "color_attributes": [attribute.name for attribute in obj.data.color_attributes],
                "material_slots": [slot.material.name if slot.material else None for slot in obj.material_slots],
                "vertex_groups": [group.name for group in obj.vertex_groups],
                "armature_modifiers": [
                    modifier.object.name if modifier.object else None
                    for modifier in obj.modifiers
                    if modifier.type == "ARMATURE"
                ],
            }
            for obj in meshes
        ],
        "materials": sorted(material.name for material in bpy.data.materials),
        "images": [
            {
                "name": image.name,
                "filepath": image.filepath,
                "size": list(image.size),
                "packed": bool(image.packed_file),
            }
            for image in bpy.data.images
        ],
        "actions": sorted(action.name for action in bpy.data.actions),
    }
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("LOD_CANDIDATE_AUDIT", json.dumps(result, ensure_ascii=True, sort_keys=True))


if __name__ == "__main__":
    main()
