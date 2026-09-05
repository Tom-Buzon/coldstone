"""Compare source and atlas base-colour sampling at matching polygon centres."""

from __future__ import annotations

from array import array
from collections import defaultdict
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod0_22k.gltf"
ATLAS = PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod0_22k_atlas.gltf"
REPORT = PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/atlased/hoplite_body_atlas.report.json"
BODY_NAME = "SPARTAN_character_body"


def import_body(path: Path) -> bpy.types.Object:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return bpy.data.objects[BODY_NAME]


def image_for_material(material: bpy.types.Material) -> bpy.types.Image | None:
    shader = next((node for node in material.node_tree.nodes if node.bl_idname == "ShaderNodeBsdfPrincipled"), None)
    if shader is None or not shader.inputs["Base Color"].is_linked:
        return None
    node = shader.inputs["Base Color"].links[0].from_node
    return node.image if node.bl_idname == "ShaderNodeTexImage" else None


def image_data(image: bpy.types.Image) -> tuple[int, int, array]:
    width, height = image.size
    data = array("f", [0.0]) * (width * height * 4)
    image.pixels.foreach_get(data)
    return width, height, data


def sample(data: tuple[int, int, array], u: float, v: float, repeat: bool) -> tuple[float, float, float]:
    if repeat:
        u %= 1.0
        v %= 1.0
    else:
        u = max(0.0, min(1.0 - 1.0e-7, u))
        v = max(0.0, min(1.0 - 1.0e-7, v))
    width, height, values = data
    x = min(width - 1, int(u * width))
    y = min(height - 1, int(v * height))
    offset = (y * width + x) * 4
    return tuple(values[offset + channel] for channel in range(3))


def polygon_uv(body: bpy.types.Object, layer_name: str, polygon: bpy.types.MeshPolygon) -> tuple[float, float]:
    layer = body.data.uv_layers[layer_name]
    count = len(polygon.loop_indices)
    return (
        sum(layer.data[index].uv.x for index in polygon.loop_indices) / count,
        sum(layer.data[index].uv.y for index in polygon.loop_indices) / count,
    )


def main() -> None:
    source = import_body(SOURCE)
    source_materials = list(source.data.materials)
    source_images = {material.name: image_for_material(material) for material in source_materials}
    source_image_data = {
        name: image_data(image) if image is not None else None
        for name, image in source_images.items()
    }
    source_polygons: list[tuple[str, tuple[float, float, float] | None]] = []
    for polygon in source.data.polygons:
        material = source_materials[polygon.material_index]
        data = source_image_data[material.name]
        colour = sample(data, *polygon_uv(source, "UVMap", polygon), repeat=True) if data is not None else None
        source_polygons.append((material.name, colour))

    atlas = import_body(ATLAS)
    atlas_image = image_for_material(atlas.data.materials[0])
    if atlas_image is None:
        raise RuntimeError("Atlas base-colour image missing")
    atlas_image_data = image_data(atlas_image)
    if len(atlas.data.polygons) != len(source_polygons):
        raise RuntimeError("Source and atlas polygon counts differ")

    import json

    layout = json.loads(REPORT.read_text(encoding="utf-8"))["material_layout"]
    totals: dict[str, list[float]] = defaultdict(lambda: [0.0, 0.0, 0.0, 0.0])
    transform_totals: dict[str, list[float]] = defaultdict(lambda: [0.0, 0.0])
    for polygon, (source_material_name, expected) in zip(atlas.data.polygons, source_polygons):
        if expected is None:
            continue
        atlas_uv = polygon_uv(atlas, "UVMap.001", polygon)
        actual = sample(atlas_image_data, *atlas_uv, repeat=False)
        difference = sum(abs(a - b) for a, b in zip(expected, actual)) / 3.0
        bucket = totals[source_material_name]
        bucket[0] += difference
        bucket[1] = max(bucket[1], difference)
        bucket[2] += 1.0
        if difference > 0.08:
            bucket[3] += 1.0
        entry = layout[source_material_name]
        offset_u, offset_v = entry["offset"]
        scale_u, scale_v = entry["scale"]
        local_u = (atlas_uv[0] - offset_u) / scale_u
        local_v = (atlas_uv[1] - offset_v) / scale_v
        candidates = {
            "identity": atlas_uv,
            "flip_u_cell": (offset_u + (1.0 - local_u) * scale_u, atlas_uv[1]),
            "flip_v_cell": (atlas_uv[0], offset_v + (1.0 - local_v) * scale_v),
            "flip_uv_cell": (offset_u + (1.0 - local_u) * scale_u, offset_v + (1.0 - local_v) * scale_v),
        }
        for transform, candidate_uv in candidates.items():
            colour = sample(atlas_image_data, *candidate_uv, repeat=False)
            value = sum(abs(a - b) for a, b in zip(expected, colour)) / 3.0
            transform_totals[transform][0] += value
            transform_totals[transform][1] += 1.0
    for name, (total, maximum, count, mismatched) in totals.items():
        print(
            "ATLAS_COLOUR",
            name,
            f"mean={total / max(count, 1.0):.5f}",
            f"max={maximum:.5f}",
            f"mismatch={int(mismatched)}/{int(count)}",
        )
    for transform, (total, count) in transform_totals.items():
        print("ATLAS_TRANSFORM", transform, f"mean={total / max(count, 1.0):.5f}")


if __name__ == "__main__":
    main()
