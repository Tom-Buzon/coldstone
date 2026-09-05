"""Prepare the canonical Hoplite V2 body for Godot.

The 3DGen source remains untouched. Finger weights are folded into the two hand
bones, all thirty finger phalanges and their animation curves are removed, and
the resulting 23-bone GLB is validated before export.

Run with Blender 4.2+:
  blender --background --factory-startup --python prepare_hoplite_body.py -- \
    --input <character_body.glb> --output <hoplite_body.glb> --report <report.json>
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

import bpy


SCRIPT_VERSION = "1.2.0"
EXPECTED_SOURCE_BONES = 53
EXPECTED_TARGET_BONES = 23
FINGER_BONE_PATTERN = re.compile(r"^DEF-(?:f_(?:index|middle|pinky|ring)|thumb)\.")
BODY_MESH_NAME = "SPARTAN_character_body"
GORE_CAP_PREFIX = "SPARTAN_gore_cap_"
MAX_PROVISIONAL_LOD0_TRIANGLES = 20_000
MAX_PROVISIONAL_BODY_SURFACES = 3
EXPECTED_ZONE_IDS = set(range(10))


def _arguments() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--output")
    parser.add_argument("--report")
    parser.add_argument(
        "--shared-textures-dir",
        help="For .gltf output, rewrite every image URI to this already-published shared texture directory",
    )
    parser.add_argument(
        "--material-source",
        help="Optional canonical textured glTF used to restore export-safe materials by slot name",
    )
    parser.add_argument("--audit-only", action="store_true")
    return parser.parse_args(raw)


def _finger_bone(name: str) -> bool:
    return bool(FINGER_BONE_PATTERN.match(name))


def _atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def _scene_inventory(source: Path) -> tuple[bpy.types.Object, list[bpy.types.Object], dict]:
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected exactly one armature, found {len(armatures)}")
    if not meshes:
        raise RuntimeError("No mesh was imported")
    armature = armatures[0]
    bone_names = [bone.name for bone in armature.data.bones]
    finger_bones = [name for name in bone_names if _finger_bone(name)]
    skinned = [
        mesh
        for mesh in meshes
        if any(modifier.type == "ARMATURE" and modifier.object == armature for modifier in mesh.modifiers)
        or any(group.name in bone_names for group in mesh.vertex_groups)
    ]
    body = next((mesh for mesh in skinned if mesh.name == BODY_MESH_NAME), None)
    if body is None:
        raise RuntimeError(f"Missing canonical body mesh: {BODY_MESH_NAME}")
    body_triangles = sum(max(0, len(polygon.vertices) - 2) for polygon in body.data.polygons)
    packed_images = sum(1 for image in bpy.data.images if image.packed_file)
    crowd_warnings: list[str] = []
    if body_triangles > MAX_PROVISIONAL_LOD0_TRIANGLES:
        crowd_warnings.append(
            f"Body has {body_triangles} triangles; provisional LOD0 budget is "
            f"{MAX_PROVISIONAL_LOD0_TRIANGLES}"
        )
    if len(body.material_slots) > MAX_PROVISIONAL_BODY_SURFACES:
        crowd_warnings.append(
            f"Body has {len(body.material_slots)} material surfaces; provisional budget is "
            f"{MAX_PROVISIONAL_BODY_SURFACES}"
        )
    inventory = {
        "source": str(source),
        "source_bytes": source.stat().st_size,
        "armature": armature.name,
        "bone_count": len(bone_names),
        "finger_bones": finger_bones,
        "mesh_count": len(meshes),
        "skinned_mesh_count": len(skinned),
        "meshes": [
            {
                "name": mesh.name,
                "vertices": len(mesh.data.vertices),
                "triangles": sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.data.polygons),
                "material_slots": len(mesh.material_slots),
                "vertex_groups": len(mesh.vertex_groups),
            }
            for mesh in meshes
        ],
        "materials": sorted(material.name for material in bpy.data.materials),
        "images": [
            {"name": image.name, "size": list(image.size), "packed": bool(image.packed_file)}
            for image in bpy.data.images
        ],
        "actions": sorted(action.name for action in bpy.data.actions),
        "crowd_budget": {
            "body_triangles": body_triangles,
            "body_material_surfaces": len(body.material_slots),
            "blender_image_datablocks": packed_images,
            "migration_ready": not crowd_warnings,
            "warnings": crowd_warnings,
        },
    }
    return armature, skinned, inventory


def _fold_finger_weights(mesh: bpy.types.Object, finger_names: list[str]) -> dict:
    hand_groups = {
        ".L": mesh.vertex_groups.get("DEF-hand.L") or mesh.vertex_groups.new(name="DEF-hand.L"),
        ".R": mesh.vertex_groups.get("DEF-hand.R") or mesh.vertex_groups.new(name="DEF-hand.R"),
    }
    folded_vertices: set[int] = set()
    folded_weight = 0.0
    removed_groups = 0
    for finger_name in finger_names:
        group = mesh.vertex_groups.get(finger_name)
        if group is None:
            continue
        side = ".L" if finger_name.endswith(".L") else ".R"
        assignments: list[tuple[int, float]] = []
        group_index = group.index
        for vertex in mesh.data.vertices:
            membership = next((item for item in vertex.groups if item.group == group_index), None)
            if membership is not None and membership.weight > 0.0:
                assignments.append((vertex.index, membership.weight))
        for vertex_index, weight in assignments:
            hand_groups[side].add([vertex_index], weight, "ADD")
            folded_vertices.add(vertex_index)
            folded_weight += weight
        mesh.vertex_groups.remove(group)
        removed_groups += 1
    return {
        "mesh": mesh.name,
        "removed_groups": removed_groups,
        "folded_vertices": len(folded_vertices),
        "folded_weight": round(folded_weight, 6),
    }


def _remove_finger_curves(finger_names: list[str]) -> int:
    removed = 0
    tokens = tuple(f'pose.bones["{name}"]' for name in finger_names)
    for action in bpy.data.actions:
        for slot in getattr(action, "slots", []):
            channelbag = action.layers[0].strips[0].channelbag(slot, ensure=False) if action.layers and action.layers[0].strips else None
            if channelbag is None:
                continue
            for fcurve in list(channelbag.fcurves):
                if any(token in fcurve.data_path for token in tokens):
                    channelbag.fcurves.remove(fcurve)
                    removed += 1
    return removed


def _remove_finger_bones(armature: bpy.types.Object, finger_names: list[str]) -> None:
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name in finger_names:
        bone = armature.data.edit_bones.get(name)
        if bone is not None:
            armature.data.edit_bones.remove(bone)
    bpy.ops.object.mode_set(mode="OBJECT")


def _restore_canonical_materials(material_source: Path, target_meshes: list[bpy.types.Object]) -> dict:
    if not material_source.is_file():
        raise RuntimeError(f"Canonical material source is missing: {material_source}")
    target_names = {
        slot.material.name
        for mesh in target_meshes
        for slot in mesh.material_slots
        if slot.material is not None
    }
    before_objects = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(material_source))
    donor_objects = [obj for obj in bpy.context.scene.objects if obj not in before_objects]
    donor_meshes = [obj for obj in donor_objects if obj.type == "MESH"]
    donors: dict[str, bpy.types.Material] = {}
    for mesh in donor_meshes:
        for slot in mesh.material_slots:
            material = slot.material
            if material is None:
                continue
            canonical_name = next(
                (name for name in target_names if material.name == name or material.name.startswith(name + ".")),
                None,
            )
            if canonical_name is not None:
                donors[canonical_name] = material

    missing = sorted(target_names - donors.keys())
    if missing:
        raise RuntimeError(f"Canonical material source does not provide: {missing}")
    assignments = 0
    for mesh in target_meshes:
        for slot in mesh.material_slots:
            if slot.material is not None:
                slot.material = donors[slot.material.name]
                assignments += 1
    for obj in donor_objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    return {
        "source": str(material_source),
        "materials": sorted(donors),
        "slot_assignments": assignments,
    }


def _validate_result(armature: bpy.types.Object, skinned: list[bpy.types.Object]) -> dict:
    bone_names = [bone.name for bone in armature.data.bones]
    remaining_fingers = [name for name in bone_names if _finger_bone(name)]
    remaining_groups: list[str] = []
    maximum_influences = 0
    unweighted_vertices = 0
    for mesh in skinned:
        remaining_groups.extend(group.name for group in mesh.vertex_groups if _finger_bone(group.name))
        for vertex in mesh.data.vertices:
            positive = sum(1 for group in vertex.groups if group.weight > 0.000001)
            maximum_influences = max(maximum_influences, positive)
            if positive == 0:
                unweighted_vertices += 1
    errors: list[str] = []
    body = next((mesh for mesh in skinned if mesh.name == BODY_MESH_NAME), None)
    zone_validation = {
        "uv_layer": None,
        "zone_ids": [],
        "invalid_loops": 0,
    }
    if body is None or len(body.data.uv_layers) < 3:
        errors.append("Body must preserve TEXCOORD_2 for persistent anatomy zones")
    else:
        zone_layer = body.data.uv_layers[2]
        zone_ids: set[int] = set()
        invalid_loops = 0
        for item in zone_layer.data:
            raw_zone = float(item.uv.x)
            rounded_zone = round(raw_zone)
            if abs(raw_zone - rounded_zone) > 0.0001 or rounded_zone not in EXPECTED_ZONE_IDS:
                invalid_loops += 1
            else:
                zone_ids.add(rounded_zone)
        zone_validation = {
            "uv_layer": zone_layer.name,
            "zone_ids": sorted(zone_ids),
            "invalid_loops": invalid_loops,
        }
        if invalid_loops:
            errors.append(f"TEXCOORD_2 contains {invalid_loops} invalid anatomy-zone loops")
        if zone_ids != EXPECTED_ZONE_IDS:
            errors.append(f"TEXCOORD_2 anatomy zones are incomplete: {sorted(zone_ids)}")
    if len(bone_names) != EXPECTED_TARGET_BONES:
        errors.append(f"Expected {EXPECTED_TARGET_BONES} bones after cleanup, found {len(bone_names)}")
    if remaining_fingers:
        errors.append(f"Finger bones remain: {remaining_fingers}")
    if remaining_groups:
        errors.append(f"Finger vertex groups remain: {remaining_groups}")
    if unweighted_vertices:
        errors.append(f"{unweighted_vertices} skinned vertices have no weight")
    return {
        "status": "PASS" if not errors else "FAIL",
        "bone_count": len(bone_names),
        "bone_names": bone_names,
        "remaining_finger_bones": remaining_fingers,
        "remaining_finger_groups": remaining_groups,
        "maximum_influences": maximum_influences,
        "unweighted_vertices": unweighted_vertices,
        "anatomy_zones": zone_validation,
        "errors": errors,
    }


def _localize_separate_textures(output: Path, shared_textures_dir: Path) -> list[str]:
    document = json.loads(output.read_text(encoding="utf-8"))
    localized: list[str] = []
    for image in document.get("images", []):
        source_uri = str(image.get("uri", ""))
        file_name = Path(source_uri).name
        target = shared_textures_dir / file_name
        if not target.is_file():
            raise RuntimeError(f"Shared texture is missing: {target}")
        image["uri"] = Path(os.path.relpath(target, output.parent)).as_posix()
        localized.append(image["uri"])
    output.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    # Blender may still emit unused copies beside the .gltf even with
    # export_keep_originals. They are generated by this run, are not referenced
    # after URI localization, and would defeat the shared-texture contract.
    for generated_copy in output.parent.glob(f"{output.stem}_Image_*"):
        if generated_copy.is_file():
            generated_copy.unlink()
    return sorted(localized)


def _export(
    output: Path,
    armature: bpy.types.Object,
    skinned: list[bpy.types.Object],
    shared_textures_dir: Path | None,
) -> tuple[list[str], list[str]]:
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    body = next((mesh for mesh in skinned if mesh.name == BODY_MESH_NAME), None)
    if body is None:
        raise RuntimeError(f"Missing canonical body mesh: {BODY_MESH_NAME}")
    export_objects: set[bpy.types.Object] = {armature, body}
    export_objects.update(
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj.name.startswith(GORE_CAP_PREFIX)
    )
    for obj in tuple(export_objects):
        parent = obj.parent
        while parent is not None:
            export_objects.add(parent)
            parent = parent.parent
    for obj in export_objects:
        obj.select_set(True)
    separate = output.suffix.lower() == ".gltf"
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLTF_SEPARATE" if separate else "GLB",
        export_keep_originals=separate,
        export_texture_dir="textures",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_extras=True,
        export_yup=True,
    )
    localized_textures: list[str] = []
    if separate:
        if shared_textures_dir is None:
            raise RuntimeError("--shared-textures-dir is required for .gltf output")
        localized_textures = _localize_separate_textures(output, shared_textures_dir)
    return sorted(obj.name for obj in export_objects), localized_textures


def main() -> None:
    args = _arguments()
    source = Path(args.input).resolve()
    if not source.is_file():
        raise RuntimeError(f"Input GLB does not exist: {source}")
    output = Path(args.output).resolve() if args.output else None
    report_path = Path(args.report).resolve() if args.report else None
    shared_textures_dir = Path(args.shared_textures_dir).resolve() if args.shared_textures_dir else None
    material_source = Path(args.material_source).resolve() if args.material_source else None
    if not args.audit_only and output is None:
        raise RuntimeError("--output is required unless --audit-only is used")
    if output is not None and output == source:
        raise RuntimeError("Refusing to overwrite the 3DGen source")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    armature, skinned, source_inventory = _scene_inventory(source)
    if source_inventory["bone_count"] != EXPECTED_SOURCE_BONES:
        raise RuntimeError(f"Expected {EXPECTED_SOURCE_BONES} source bones, found {source_inventory['bone_count']}")
    finger_names = list(source_inventory["finger_bones"])
    if len(finger_names) != EXPECTED_SOURCE_BONES - EXPECTED_TARGET_BONES:
        raise RuntimeError(f"Expected 30 finger bones, found {len(finger_names)}")

    result = {
        "schema_version": 1,
        "generator": "prepare_hoplite_body",
        "generator_version": SCRIPT_VERSION,
        "blender_version": bpy.app.version_string,
        "source": source_inventory,
        "target_rig_id": "spartan_enemy_v2_23",
        "removed_bones": finger_names,
        "weight_folding": [],
    }
    if args.audit_only:
        result["status"] = "AUDIT_ONLY"
    else:
        result["weight_folding"] = [_fold_finger_weights(mesh, finger_names) for mesh in skinned]
        result["removed_animation_curves"] = _remove_finger_curves(finger_names)
        _remove_finger_bones(armature, finger_names)
        if material_source is not None:
            result["material_rebinding"] = _restore_canonical_materials(material_source, skinned)
        validation = _validate_result(armature, skinned)
        result["validation"] = validation
        result["status"] = validation["status"]
        if validation["status"] != "PASS":
            if report_path:
                _atomic_json(report_path, result)
            raise RuntimeError("Hoplite V2 validation failed: " + "; ".join(validation["errors"]))
        result["exported_objects"], result["shared_texture_uris"] = _export(
            output,
            armature,
            skinned,
            shared_textures_dir,
        )
        result["output"] = str(output)
        result["output_bytes"] = output.stat().st_size

    if report_path:
        _atomic_json(report_path, result)
    print("[HOPLITE V2 BODY]", json.dumps(result, ensure_ascii=True, sort_keys=True))


if __name__ == "__main__":
    main()
