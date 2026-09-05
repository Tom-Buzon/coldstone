"""Read-only Blender audit for the Hoplite V2 atlas contract.

Run with:
  blender --background --factory-startup --python audit_hoplite_atlas.py -- <gltf>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy


def argument_path() -> Path:
    separator = sys.argv.index("--") if "--" in sys.argv else -1
    if separator < 0 or separator + 1 >= len(sys.argv):
        raise RuntimeError("Expected a glTF path after --")
    return Path(sys.argv[separator + 1]).resolve()


def image_descriptor(node: bpy.types.ShaderNodeTexImage | None) -> dict[str, object] | None:
    if node is None or node.image is None:
        return None
    image = node.image
    return {
        "name": image.name,
        "size": list(image.size),
        "colorspace": image.colorspace_settings.name,
        "source": image.source,
    }


def upstream_image(socket: bpy.types.NodeSocket | None) -> bpy.types.ShaderNodeTexImage | None:
    if socket is None or not socket.is_linked:
        return None
    pending = [link.from_node for link in socket.links]
    visited: set[int] = set()
    while pending:
        node = pending.pop(0)
        pointer = node.as_pointer()
        if pointer in visited:
            continue
        visited.add(pointer)
        if isinstance(node, bpy.types.ShaderNodeTexImage):
            return node
        for input_socket in node.inputs:
            pending.extend(link.from_node for link in input_socket.links)
    return None


def principled_node(material: bpy.types.Material) -> bpy.types.ShaderNodeBsdfPrincipled | None:
    if material.node_tree is None:
        return None
    for node in material.node_tree.nodes:
        if isinstance(node, bpy.types.ShaderNodeBsdfPrincipled):
            return node
    return None


def socket(node: bpy.types.Node | None, *names: str) -> bpy.types.NodeSocket | None:
    if node is None:
        return None
    for name in names:
        result = node.inputs.get(name)
        if result is not None:
            return result
    return None


def uv_ranges(mesh: bpy.types.Mesh) -> dict[str, dict[str, list[float]]]:
    result: dict[str, dict[str, list[float]]] = {}
    for layer in mesh.uv_layers:
        minimum = [float("inf"), float("inf")]
        maximum = [float("-inf"), float("-inf")]
        for datum in layer.data:
            minimum[0] = min(minimum[0], datum.uv.x)
            minimum[1] = min(minimum[1], datum.uv.y)
            maximum[0] = max(maximum[0], datum.uv.x)
            maximum[1] = max(maximum[1], datum.uv.y)
        result[layer.name] = {"minimum": minimum, "maximum": maximum}
    return result


def main() -> None:
    source = argument_path()
    if not source.is_file():
        raise FileNotFoundError(source)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    body = next((obj for obj in meshes if obj.name == "SPARTAN_character_body"), None)
    if body is None:
        raise RuntimeError("SPARTAN_character_body was not imported")

    materials: list[dict[str, object]] = []
    for index, material in enumerate(body.data.materials):
        if material is None:
            materials.append({"slot": index, "name": None})
            continue
        shader = principled_node(material)
        base_socket = socket(shader, "Base Color")
        roughness_socket = socket(shader, "Roughness")
        metallic_socket = socket(shader, "Metallic")
        normal_socket = socket(shader, "Normal")
        materials.append(
            {
                "slot": index,
                "name": material.name,
                "surface_faces": sum(1 for polygon in body.data.polygons if polygon.material_index == index),
                "surface_triangles": sum(len(polygon.vertices) - 2 for polygon in body.data.polygons if polygon.material_index == index),
                "surface_render_method": getattr(material, "surface_render_method", "DITHERED" if material.blend_method != "OPAQUE" else "OPAQUE"),
                "alpha_threshold": getattr(material, "alpha_threshold", material.alpha_threshold if hasattr(material, "alpha_threshold") else 0.5),
                "base_color": list(base_socket.default_value) if base_socket is not None else None,
                "roughness": roughness_socket.default_value if roughness_socket is not None else None,
                "metallic": metallic_socket.default_value if metallic_socket is not None else None,
                "base_image": image_descriptor(upstream_image(base_socket)),
                "roughness_image": image_descriptor(upstream_image(roughness_socket)),
                "metallic_image": image_descriptor(upstream_image(metallic_socket)),
                "normal_image": image_descriptor(upstream_image(normal_socket)),
                "image_vector_sources": {
                    node.name: [link.from_node.bl_idname for link in node.inputs["Vector"].links]
                    for node in material.node_tree.nodes
                    if isinstance(node, bpy.types.ShaderNodeTexImage)
                } if material.node_tree is not None else {},
            }
        )

    report = {
        "source": str(source),
        "body": body.name,
        "vertices": len(body.data.vertices),
        "polygons": len(body.data.polygons),
        "triangles": sum(len(polygon.vertices) - 2 for polygon in body.data.polygons),
        "armature_modifiers": [modifier.object.name for modifier in body.modifiers if modifier.type == "ARMATURE" and modifier.object],
        "vertex_groups": len(body.vertex_groups),
        "uv_layers": uv_ranges(body.data),
        "attributes": [{"name": attribute.name, "domain": attribute.domain, "data_type": attribute.data_type} for attribute in body.data.attributes],
        "materials": materials,
        "scene_meshes": [obj.name for obj in meshes],
        "actions": len(bpy.data.actions),
    }
    print("HOPLITE_ATLAS_AUDIT " + json.dumps(report, separators=(",", ":")))


if __name__ == "__main__":
    main()
