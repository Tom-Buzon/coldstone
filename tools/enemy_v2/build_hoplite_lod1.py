"""Reconstruct a textured, rigged Hoplite LOD from an untextured remesh.

The candidate geometry is never modified in place. Appearance is baked from
the canonical 23-bone body into one atlas, skin weights are transferred by
nearest-surface interpolation, and the result is validated before export.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils.bvhtree import BVHTree


SCRIPT_VERSION = "1.0.0"
SOURCE_BODY_NAME = "SPARTAN_character_body"
TARGET_BODY_NAME = "SPARTAN_character_body_LOD1"
EXPECTED_BONES = 23
MAX_TRIANGLES = 16_000
MAX_INFLUENCES = 4


def _args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Canonical textured 23-bone body .gltf/.glb")
    parser.add_argument("--candidate", required=True, help="Untextured low-poly candidate .glb")
    parser.add_argument("--output", required=True, help="Output .gltf")
    parser.add_argument("--atlas", required=True, help="Output atlas .png")
    parser.add_argument("--report", required=True)
    parser.add_argument("--atlas-size", type=int, default=2048)
    return parser.parse_args(raw)


def _import(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [obj for obj in bpy.context.scene.objects if obj not in before]


def _only(objects: list[bpy.types.Object], kind: str) -> list[bpy.types.Object]:
    return [obj for obj in objects if obj.type == kind]


def _triangles(obj: bpy.types.Object) -> int:
    return sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons)


def _activate(obj: bpy.types.Object, selected: list[bpy.types.Object] | None = None) -> None:
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for item in selected or [obj]:
        item.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _prepare_candidate(obj: bpy.types.Object) -> None:
    obj.name = TARGET_BODY_NAME
    obj.data.name = TARGET_BODY_NAME + "_mesh"
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.validate(verbose=False)
    mesh.update(calc_edges=True)


def _unwrap_candidate(obj: bpy.types.Object) -> None:
    mesh = obj.data
    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])
    mesh.uv_layers.new(name="LOD1_Atlas")
    _activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02, area_weight=0.25)
    bpy.ops.object.mode_set(mode="OBJECT")


def _atlas_material(atlas_path: Path, size: int) -> tuple[bpy.types.Material, bpy.types.Image]:
    atlas_path.parent.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.new("Hoplite_LOD1_Atlas", width=size, height=size, alpha=False, float_buffer=False)
    image.filepath_raw = str(atlas_path)
    image.file_format = "PNG"
    image.generated_color = (0.04, 0.04, 0.04, 1.0)

    material = bpy.data.materials.new("Hoplite_LOD1_Atlas")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    nodes.active = texture
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    if "Metallic" in shader.inputs:
        shader.inputs["Metallic"].default_value = 0.15
    if "Roughness" in shader.inputs:
        shader.inputs["Roughness"].default_value = 0.58
    return material, image


def _bake_albedo(source: bpy.types.Object, target: bpy.types.Object, material: bpy.types.Material, image: bpy.types.Image) -> None:
    target.data.materials.clear()
    target.data.materials.append(material)
    _activate(target, [source, target])
    # Texture baking is a Cycles-only operation in the Blender 5.2 LTS build
    # used by the project. Keep it on CPU so the batch pipeline works without
    # requiring a particular GPU backend.
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.device = "CPU"
    bpy.context.scene.render.bake.use_pass_direct = False
    bpy.context.scene.render.bake.use_pass_indirect = False
    bpy.context.scene.render.bake.use_pass_color = True
    bpy.context.scene.render.bake.margin = 8
    bpy.ops.object.bake(
        type="DIFFUSE",
        pass_filter={"COLOR"},
        use_selected_to_active=True,
        cage_extrusion=0.04,
        max_ray_distance=0.12,
    )
    image.save()


def _transfer_weights(source: bpy.types.Object, target: bpy.types.Object, armature: bpy.types.Object) -> None:
    allowed = {bone.name for bone in armature.data.bones}
    target_groups = {
        group.name: target.vertex_groups.new(name=group.name)
        for group in source.vertex_groups
        if group.name in allowed
    }

    source.data.calc_loop_triangles()
    triangles = [tuple(triangle.vertices) for triangle in source.data.loop_triangles]
    coordinates = [vertex.co.copy() for vertex in source.data.vertices]
    bvh = BVHTree.FromPolygons(coordinates, triangles, all_triangles=True)
    if bvh is None:
        raise RuntimeError("Could not build the source surface BVH for skin-weight transfer")

    source_weights: list[dict[str, float]] = []
    source_group_names = {group.index: group.name for group in source.vertex_groups}
    for vertex in source.data.vertices:
        source_weights.append(
            {
                source_group_names[membership.group]: membership.weight
                for membership in vertex.groups
                if source_group_names.get(membership.group) in target_groups and membership.weight > 0.000001
            }
        )

    target_to_source = source.matrix_world.inverted() @ target.matrix_world
    for target_vertex in target.data.vertices:
        point = target_to_source @ target_vertex.co
        hit, _normal, triangle_index, _distance = bvh.find_nearest(point)
        if hit is None or triangle_index is None:
            continue
        indices = triangles[triangle_index]
        a, b, c = (coordinates[index] for index in indices)
        v0, v1, v2 = b - a, c - a, hit - a
        d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
        d20, d21 = v2.dot(v0), v2.dot(v1)
        denominator = d00 * d11 - d01 * d01
        if abs(denominator) < 1e-12:
            barycentric = (1.0, 0.0, 0.0)
        else:
            second = (d11 * d20 - d01 * d21) / denominator
            third = (d00 * d21 - d01 * d20) / denominator
            barycentric = (1.0 - second - third, second, third)
        interpolated: dict[str, float] = {}
        for source_index, factor in zip(indices, barycentric):
            for group_name, weight in source_weights[source_index].items():
                interpolated[group_name] = interpolated.get(group_name, 0.0) + weight * factor
        for group_name, weight in interpolated.items():
            if weight > 0.000001:
                target_groups[group_name].add([target_vertex.index], weight, "REPLACE")

    _activate(target)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=MAX_INFLUENCES)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    target.parent = armature
    target.matrix_parent_inverse = armature.matrix_world.inverted()
    modifier = target.modifiers.new("SPARTAN_Armature", "ARMATURE")
    modifier.object = armature
    modifier.use_deform_preserve_volume = False


def _weight_validation(obj: bpy.types.Object, allowed_bones: set[str]) -> dict:
    unknown_groups = sorted(group.name for group in obj.vertex_groups if group.name not in allowed_bones)
    maximum = 0
    unweighted = 0
    for vertex in obj.data.vertices:
        positive = sum(1 for membership in vertex.groups if membership.weight > 0.000001)
        maximum = max(maximum, positive)
        if positive == 0:
            unweighted += 1
    return {
        "vertex_groups": sorted(group.name for group in obj.vertex_groups),
        "unknown_groups": unknown_groups,
        "maximum_influences": maximum,
        "unweighted_vertices": unweighted,
    }


def _export(output: Path, atlas_path: Path, armature: bpy.types.Object, target: bpy.types.Object) -> None:
    if output.suffix.lower() != ".gltf":
        raise RuntimeError("LOD output must be .gltf so the atlas remains an external shared resource")
    output.parent.mkdir(parents=True, exist_ok=True)
    keep: set[bpy.types.Object] = {armature, target}
    parent = armature.parent
    while parent is not None:
        keep.add(parent)
        parent = parent.parent
    _activate(target, list(keep))
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLTF_SEPARATE",
        export_keep_originals=True,
        export_texture_dir="textures",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_extras=True,
        export_yup=True,
    )
    document = json.loads(output.read_text(encoding="utf-8"))
    images = document.get("images", [])
    if len(images) != 1:
        raise RuntimeError(f"Expected one exported atlas image, found {len(images)}")
    images[0]["uri"] = Path(os.path.relpath(atlas_path, output.parent)).as_posix()
    output.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    for generated_copy in output.parent.glob(f"{output.stem}_*"):
        if generated_copy.is_file() and generated_copy not in {output, output.with_suffix(".bin"), atlas_path}:
            if generated_copy.suffix.lower() in {".png", ".jpg", ".jpeg"}:
                generated_copy.unlink()


def _write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    args = _args()
    source_path = Path(args.source).resolve()
    candidate_path = Path(args.candidate).resolve()
    output_path = Path(args.output).resolve()
    atlas_path = Path(args.atlas).resolve()
    report_path = Path(args.report).resolve()
    if not source_path.is_file() or not candidate_path.is_file():
        raise RuntimeError("Source or candidate LOD is missing")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    source_objects = _import(source_path)
    armatures = _only(source_objects, "ARMATURE")
    source_bodies = [obj for obj in _only(source_objects, "MESH") if obj.name == SOURCE_BODY_NAME]
    if len(armatures) != 1 or len(source_bodies) != 1:
        raise RuntimeError("Canonical source must contain one armature and SPARTAN_character_body")
    armature = armatures[0]
    source_body = source_bodies[0]
    if len(armature.data.bones) != EXPECTED_BONES:
        raise RuntimeError(f"Canonical source has {len(armature.data.bones)} bones; expected {EXPECTED_BONES}")

    candidate_objects = _import(candidate_path)
    candidates = _only(candidate_objects, "MESH")
    if len(candidates) != 1 or _only(candidate_objects, "ARMATURE"):
        raise RuntimeError("LOD candidate must contain exactly one unrigged mesh")
    target = candidates[0]
    _prepare_candidate(target)
    _unwrap_candidate(target)
    material, atlas = _atlas_material(atlas_path, args.atlas_size)
    _bake_albedo(source_body, target, material, atlas)
    _transfer_weights(source_body, target, armature)

    weight_report = _weight_validation(target, {bone.name for bone in armature.data.bones})
    errors: list[str] = []
    if _triangles(target) > MAX_TRIANGLES:
        errors.append(f"Triangle budget exceeded: {_triangles(target)} > {MAX_TRIANGLES}")
    if len(target.data.materials) != 1:
        errors.append("LOD must have exactly one material surface")
    if len(target.data.uv_layers) != 1:
        errors.append("LOD must have exactly one UV atlas")
    if weight_report["unknown_groups"]:
        errors.append(f"Unknown vertex groups: {weight_report['unknown_groups']}")
    if weight_report["unweighted_vertices"]:
        errors.append(f"Unweighted vertices: {weight_report['unweighted_vertices']}")
    if weight_report["maximum_influences"] > MAX_INFLUENCES:
        errors.append(f"Maximum influences is {weight_report['maximum_influences']}")

    report = {
        "schema_version": 1,
        "generator": "build_hoplite_lod1",
        "generator_version": SCRIPT_VERSION,
        "status": "PASS" if not errors else "FAIL",
        "source": str(source_path),
        "candidate": str(candidate_path),
        "candidate_bytes": candidate_path.stat().st_size,
        "output": str(output_path),
        "atlas": str(atlas_path),
        "atlas_size": args.atlas_size,
        "triangles": _triangles(target),
        "vertices": len(target.data.vertices),
        "materials": len(target.data.materials),
        "uv_layers": [layer.name for layer in target.data.uv_layers],
        "bones": len(armature.data.bones),
        "weights": weight_report,
        "errors": errors,
    }
    if errors:
        _write_json(report_path, report)
        raise RuntimeError("LOD validation failed: " + "; ".join(errors))
    _export(output_path, atlas_path, armature, target)
    report["output_bytes"] = output_path.stat().st_size + output_path.with_suffix(".bin").stat().st_size
    report["atlas_bytes"] = atlas_path.stat().st_size
    _write_json(report_path, report)
    print("HOPLITE_LOD1_BUILD", json.dumps(report, ensure_ascii=True, sort_keys=True))


if __name__ == "__main__":
    main()
