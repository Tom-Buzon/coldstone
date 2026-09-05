"""Split, normalize, validate and export the supplied elemental sword collection.

Asset contract:
- one sword per GLB, one mesh and one embedded PBR material;
- grip center at the world origin, blade along Blender +Z / Godot +Y;
- front-readable blade width on Blender X / Godot X;
- authored blade contact data written to both glTF extras and the manifest;
- source layout offsets and source scale never enter the runtime exports.

Run:
    blender --background --python build_elemental_swords.py -- path/to/elemental_swords.glb
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
RUNTIME_DIR = PROJECT_ROOT / "assets" / "weapons" / "elemental"
OUTPUT_DIR = SCRIPT_DIR / "output"
PREVIEW_PATH = OUTPUT_DIR / "elemental_swords_preview.png"
BLEND_PATH = OUTPUT_DIR / "elemental_swords_normalized.blend"
MANIFEST_PATH = OUTPUT_DIR / "asset_manifest.json"
ROOT_COLLECTION = "GEN_ElementalSwords"

# grip_z and blade_base_z are measured in the source collection. target_length
# sets the final gameplay size in meters while preserving every sword's shape.
SWORDS = [
    {"token": "BloodSword", "id": "elemental_blood_sword", "mesh": "SM_Elemental_BloodSword", "display": "Épée sanguine", "grip_z": 45.0, "blade_base_z": 140.0, "target_length": 1.68, "radius": 0.14, "material": "MAT_Elemental_Blood"},
    {"token": "ThinSword", "id": "elemental_thin_sword", "mesh": "SM_Elemental_ThinSword", "display": "Rapière élémentaire", "grip_z": 55.0, "blade_base_z": 220.0, "target_length": 1.58, "radius": 0.10, "material": "MAT_Elemental_Thin"},
    {"token": "SunSword", "id": "elemental_sun_sword", "mesh": "SM_Elemental_SunSword", "display": "Épée solaire", "grip_z": 58.0, "blade_base_z": 235.0, "target_length": 1.70, "radius": 0.17, "material": "MAT_Elemental_Sun"},
    {"token": "MeteorSword", "id": "elemental_meteor_sword", "mesh": "SM_Elemental_MeteorSword", "display": "Épée météore", "grip_z": 62.0, "blade_base_z": 230.0, "target_length": 1.78, "radius": 0.22, "material": "MAT_Elemental_Meteor"},
    {"token": "IceSword", "id": "elemental_ice_sword", "mesh": "SM_Elemental_IceSword", "display": "Épée de glace", "grip_z": 62.0, "blade_base_z": 215.0, "target_length": 1.66, "radius": 0.16, "material": "MAT_Elemental_Ice"},
    {"token": "SpaceSword", "id": "elemental_space_sword", "mesh": "SM_Elemental_SpaceSword", "display": "Épée cosmique", "grip_z": 18.0, "blade_base_z": 188.0, "target_length": 1.72, "radius": 0.13, "material": "MAT_Elemental_Space"},
    {"token": "LavaSword", "id": "elemental_lava_sword", "mesh": "SM_Elemental_LavaSword", "display": "Épée de lave", "grip_z": 42.0, "blade_base_z": 205.0, "target_length": 1.78, "radius": 0.20, "material": "MAT_Elemental_Lava"},
]


def remove_collection(name: str) -> None:
    collection = bpy.data.collections.get(name)
    if collection is None:
        return
    for obj in list(collection.all_objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(collection)


def child_collection(name: str, parent: bpy.types.Collection) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    parent.children.link(collection)
    return collection


def mesh_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    points = [vertex.co for vertex in obj.data.vertices]
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return minimum, maximum


def triangle_count(obj: bpy.types.Object) -> int:
    return sum(max(0, len(face.vertices) - 2) for face in obj.data.polygons)


def select_only(obj: bpy.types.Object) -> None:
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def export_glb(obj: bpy.types.Object, output_path: Path) -> None:
    select_only(obj)
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        use_active_scene=True,
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )


def find_source(meshes: list[bpy.types.Object], token: str) -> bpy.types.Object:
    matches = [obj for obj in meshes if token.lower() in (obj.name + " " + obj.data.name + " " + " ".join(material.name for material in obj.data.materials if material)).lower()]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one source mesh for {token}, found {[obj.name for obj in matches]}")
    return matches[0]


def normalized_sword(source: bpy.types.Object, config: dict[str, object], collection: bpy.types.Collection) -> tuple[bpy.types.Object, dict[str, object]]:
    mesh = source.data.copy()
    mesh.transform(source.matrix_world)
    obj = bpy.data.objects.new(str(config["mesh"]), mesh)
    collection.objects.link(obj)

    minimum, maximum = mesh_bounds(obj)
    source_length = maximum.z - minimum.z
    scale = float(config["target_length"]) / source_length
    horizontal_center = Vector(((minimum.x + maximum.x) * 0.5, (minimum.y + maximum.y) * 0.5, float(config["grip_z"])))
    # +90 degrees around Blender Z maps the collection's broad Y profile onto X,
    # matching Hoplite's existing sword convention before the glTF Y-up export.
    for vertex in mesh.vertices:
        local = vertex.co - horizontal_center
        vertex.co = Vector((-local.y, local.x, local.z)) * scale
    mesh.update(calc_edges=True)
    obj.location = Vector((0.0, 0.0, 0.0))
    obj.rotation_euler = Vector((0.0, 0.0, 0.0))
    obj.scale = Vector((1.0, 1.0, 1.0))

    for material_index, material in enumerate(list(mesh.materials)):
        if material is None:
            continue
        localized = material.copy()
        localized.name = str(config["material"])
        mesh.materials[material_index] = localized

    blade_base = (float(config["blade_base_z"]) - float(config["grip_z"])) * scale
    blade_tip = (maximum.z - float(config["grip_z"])) * scale * 0.985
    obj["asset_type"] = "equipment"
    obj["equipment_kind"] = "weapon"
    obj["equipment_id"] = str(config["id"])
    obj["grip_origin"] = "world_origin"
    obj["blade_axis_godot"] = "+Y"
    obj["blade_base_godot_y"] = blade_base
    obj["blade_tip_godot_y"] = blade_tip
    obj["hit_radius_m"] = float(config["radius"])

    final_minimum, final_maximum = mesh_bounds(obj)
    report = {
        "id": config["id"],
        "display_name": config["display"],
        "file": f"{config['id']}.glb",
        "mesh": config["mesh"],
        "material": config["material"],
        "dimensions_m_blender_xyz": [round(value, 5) for value in final_maximum - final_minimum],
        "triangles": triangle_count(obj),
        "materials": len([material for material in mesh.materials if material is not None]),
        "blade_base_y": round(blade_base, 5),
        "blade_tip_y": round(blade_tip, 5),
        "hit_radius": config["radius"],
    }
    if blade_base < 0.08 or blade_tip <= blade_base or blade_tip > float(config["target_length"]) * 1.05:
        raise RuntimeError(f"Invalid blade contact for {config['id']}: {blade_base:.3f}..{blade_tip:.3f}")
    print(f"[ELEMENTAL SWORDS] {config['id']}: {report['triangles']} tris, dims={report['dimensions_m_blender_xyz']}, blade={blade_base:.3f}..{blade_tip:.3f}")
    return obj, report


def point_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_preview(scene: bpy.types.Scene, swords: list[bpy.types.Object], preview_collection: bpy.types.Collection) -> None:
    for source in swords:
        preview = source.copy()
        preview.data = source.data
        preview.name = f"Preview_{source.name}"
        preview.hide_render = False
        preview.hide_viewport = False
        preview_collection.objects.link(preview)
        preview.location = Vector(((len(preview_collection.objects) - 1 - 3) * 0.62, 0.0, 0.32))

    floor_material = bpy.data.materials.new("MAT_ElementalPreviewFloor")
    floor_material.diffuse_color = (0.012, 0.018, 0.030, 1.0)
    floor_material.use_nodes = True
    floor_bsdf = floor_material.node_tree.nodes.get("Principled BSDF")
    floor_bsdf.inputs["Base Color"].default_value = (0.012, 0.018, 0.030, 1.0)
    floor_bsdf.inputs["Roughness"].default_value = 0.82
    bpy.ops.mesh.primitive_plane_add(size=9.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "ElementalPreviewFloor"
    for collection in list(floor.users_collection):
        collection.objects.unlink(floor)
    preview_collection.objects.link(floor)
    floor.data.materials.append(floor_material)

    for name, location, energy, color, size in (
        ("Key", (-3.0, -4.0, 3.2), 1050.0, (0.62, 0.78, 1.0), 2.2),
        ("Warm", (3.0, -1.5, 2.2), 900.0, (1.0, 0.30, 0.08), 1.8),
        ("Rim", (0.0, 2.5, 2.8), 1100.0, (0.20, 0.48, 1.0), 2.0),
    ):
        data = bpy.data.lights.new(f"ElementalPreview{name}", "AREA")
        data.energy = energy
        data.color = color
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(f"ElementalPreview{name}", data)
        preview_collection.objects.link(light)
        light.location = location
        point_at(light, Vector((0.0, 0.0, 0.9)))

    camera_data = bpy.data.cameras.new("ElementalPreviewCamera")
    camera = bpy.data.objects.new("ElementalPreviewCamera", camera_data)
    preview_collection.objects.link(camera)
    camera.location = Vector((0.0, -6.4, 1.35))
    camera_data.lens = 58.0
    point_at(camera, Vector((0.0, 0.0, 0.95)))
    scene.camera = camera
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.world.color = (0.004, 0.006, 0.014)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    if "--" not in sys.argv or not sys.argv[sys.argv.index("--") + 1:]:
        raise RuntimeError("Pass the source elemental_swords.glb after --")
    source_path = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    if not source_path.exists():
        raise FileNotFoundError(source_path)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    remove_collection(ROOT_COLLECTION)
    root = bpy.data.collections.new(ROOT_COLLECTION)
    bpy.context.scene.collection.children.link(root)
    export_collection = child_collection("RuntimeExports", root)
    preview_collection = child_collection("Preview", root)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(source_path))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    source_meshes = [obj for obj in imported if obj.type == "MESH"]
    if len(source_meshes) != len(SWORDS):
        raise RuntimeError(f"Expected {len(SWORDS)} sword meshes, found {len(source_meshes)}")

    swords: list[bpy.types.Object] = []
    reports: list[dict[str, object]] = []
    for config in SWORDS:
        sword, report = normalized_sword(find_source(source_meshes, str(config["token"])), config, export_collection)
        export_glb(sword, RUNTIME_DIR / str(report["file"]))
        swords.append(sword)
        reports.append(report)

    for obj in imported:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    for sword in swords:
        sword.hide_render = True
    render_preview(bpy.context.scene, swords, preview_collection)

    manifest = {
        "source": source_path.name,
        "status": "PASS",
        "units": "meters",
        "origin": "grip center",
        "blade_axis_godot": "+Y",
        "sword_count": len(reports),
        "swords": reports,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    print(f"[ELEMENTAL SWORDS] PASS exports={RUNTIME_DIR} preview={PREVIEW_PATH} manifest={MANIFEST_PATH}")


if __name__ == "__main__":
    main()
