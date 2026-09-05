"""Standalone Blender template for a small Godot-ready static asset package.

The example builds a calibration crate so the file runs as-is. Replace only the
art-construction functions for a real asset; retain the collection hygiene,
validation, preview, manifest, and export plumbing.

Runs from Blender's Text Editor or with:
    blender --background --python static_game_asset_template.py

The script removes only its own ``GEN_calibration_crate`` collection.
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


# -----------------------------------------------------------------------------
# Editable contract
# -----------------------------------------------------------------------------

ASSET_ID = "calibration_crate"
SEED = 1729
MIN_BLENDER = (4, 3, 0)

EXPORT_GLB = True
SAVE_BLEND = True
RENDER_PREVIEW = True

MAX_TRIS = {"LOD0": 900, "LOD1": 180, "LOD2": 20, "collision": 20}
MAX_MATERIALS = 2
REQUIRE_CLOSED_MESH = True

ROOT_COLLECTION = f"GEN_{ASSET_ID}"
OUTPUT_FOLDER_NAME = f"{ASSET_ID}_output"


# -----------------------------------------------------------------------------
# Paths and generated-scene hygiene
# -----------------------------------------------------------------------------

def script_directory() -> Path:
    if "__file__" in globals():
        return Path(__file__).resolve().parent
    text = getattr(getattr(bpy.context, "space_data", None), "text", None)
    if text is not None and text.filepath:
        return Path(text.filepath).resolve().parent
    if bpy.data.filepath:
        return Path(bpy.data.filepath).resolve().parent
    return Path.home() / "blender_generated_assets"


OUTPUT_DIR = script_directory() / OUTPUT_FOLDER_NAME


def collection_tree(root: bpy.types.Collection) -> list[bpy.types.Collection]:
    result: list[bpy.types.Collection] = []
    for child in list(root.children):
        result.extend(collection_tree(child))
    result.append(root)
    return result


def clear_previous_generation() -> None:
    root = bpy.data.collections.get(ROOT_COLLECTION)
    if root is not None:
        for obj in list(root.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        for collection in collection_tree(root):
            bpy.data.collections.remove(collection)

    material_prefix = f"MAT_{ASSET_ID}_"
    for material in list(bpy.data.materials):
        if material.name.startswith(material_prefix) and material.users == 0:
            bpy.data.materials.remove(material)


def new_collection(
    name: str, parent: bpy.types.Collection | None = None
) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(collection)
    return collection


def move_to_collection(
    obj: bpy.types.Object, collection: bpy.types.Collection
) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def activate(obj: bpy.types.Object) -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


# -----------------------------------------------------------------------------
# Materials and mesh helpers
# -----------------------------------------------------------------------------

def set_input_if_present(
    node: bpy.types.Node, names: tuple[str, ...], value: object
) -> bool:
    for name in names:
        socket = node.inputs.get(name)
        if socket is not None:
            socket.default_value = value
            return True
    return False


def make_material(
    suffix: str,
    base_color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
) -> bpy.types.Material:
    name = f"MAT_{ASSET_ID}_{suffix}"
    material = bpy.data.materials.new(name=name)
    # Blender 5.x creates shader node trees by default and deprecates this flag.
    if bpy.app.version < (5, 0, 0):
        material.use_nodes = True
    material.diffuse_color = base_color
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError(f"{name}: Principled BSDF node is missing")
    set_input_if_present(principled, ("Base Color",), base_color)
    set_input_if_present(principled, ("Metallic",), metallic)
    set_input_if_present(principled, ("Roughness",), roughness)
    set_input_if_present(principled, ("Specular IOR Level", "Specular"), 0.35)
    return material


def add_box(
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    bevel_width: float = 0.0,
    bevel_segments: int = 1,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    move_to_collection(obj, collection)
    obj.data.materials.append(material)
    apply_transform(obj)
    if bevel_width > 0.0:
        bevel = obj.modifiers.new(name="Bevel", type="BEVEL")
        bevel.width = bevel_width
        bevel.segments = bevel_segments
        bevel.limit_method = "ANGLE"
        bevel.angle_limit = math.radians(25.0)
        if hasattr(bevel, "affect"):
            bevel.affect = "EDGES"
        apply_modifiers(obj)
    return obj


def create_mesh_object(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=False)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def apply_transform(obj: bpy.types.Object) -> None:
    activate(obj)
    # Bake placement as well as rotation/scale so every exported variant keeps
    # the package pivot at world origin (the center of the crate's base).
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def apply_modifiers(obj: bpy.types.Object) -> None:
    activate(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def normalize_part_slots(
    parts: list[bpy.types.Object], materials: list[bpy.types.Material]
) -> None:
    slot_by_name = {material.name: index for index, material in enumerate(materials)}
    for part in parts:
        if part.type != "MESH" or not part.data.materials:
            continue
        intended = part.data.materials[0]
        intended_index = slot_by_name[intended.name]
        part.data.materials.clear()
        for material in materials:
            part.data.materials.append(material)
        for polygon in part.data.polygons:
            polygon.material_index = intended_index


def join_parts(
    parts: list[bpy.types.Object],
    final_name: str,
    materials: list[bpy.types.Material],
) -> bpy.types.Object:
    normalize_part_slots(parts, materials)
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = final_name
    result.data.name = f"{final_name}_Mesh"

    old_slots = list(result.data.materials)
    unique: list[bpy.types.Material] = []
    index_by_name: dict[str, int] = {}
    old_to_new: dict[int, int] = {}
    for old_index, material in enumerate(old_slots):
        if material.name not in index_by_name:
            index_by_name[material.name] = len(unique)
            unique.append(material)
        old_to_new[old_index] = index_by_name[material.name]
    polygon_slots = [old_to_new.get(poly.material_index, 0) for poly in result.data.polygons]
    result.data.materials.clear()
    for material in unique:
        result.data.materials.append(material)
    for polygon, new_index in zip(result.data.polygons, polygon_slots):
        polygon.material_index = new_index
    apply_transform(result)
    return result


# -----------------------------------------------------------------------------
# Example art construction: replace for a real asset
# -----------------------------------------------------------------------------

def build_lod0(
    collection: bpy.types.Collection,
    wood: bpy.types.Material,
    iron: bpy.types.Material,
) -> bpy.types.Object:
    parts = [
        add_box("CrateBody", (1.0, 0.78, 0.72), (0.0, 0.0, 0.36), wood, collection, 0.018, 2),
        add_box("TopBand", (1.06, 0.84, 0.075), (0.0, 0.0, 0.695), iron, collection, 0.012, 2),
        add_box("BottomBand", (1.06, 0.84, 0.075), (0.0, 0.0, 0.045), iron, collection, 0.012, 2),
    ]
    for x in (-0.47, 0.47):
        for y in (-0.36, 0.36):
            parts.append(
                add_box(
                    "CornerPost",
                    (0.10, 0.10, 0.64),
                    (x, y, 0.36),
                    iron,
                    collection,
                    0.01,
                    2,
                )
            )
    result = join_parts(parts, f"{ASSET_ID}_LOD0", [wood, iron])
    result["asset_type"] = "static_prop"
    result["unit_scale_meters"] = 1.0
    result["forward_godot_axis"] = "-Z"
    return result


def build_simple_lod(
    level: str,
    collection: bpy.types.Collection,
    material: bpy.types.Material,
    bevel_width: float,
) -> bpy.types.Object:
    obj = add_box(
        f"{ASSET_ID}_{level}",
        (1.0, 0.78, 0.72),
        (0.0, 0.0, 0.36),
        material,
        collection,
        bevel_width,
        1,
    )
    obj["asset_type"] = "static_prop"
    obj["lod"] = level
    return obj


def build_collision(
    collection: bpy.types.Collection, material: bpy.types.Material
) -> bpy.types.Object:
    collision = add_box(
        f"{ASSET_ID}_collision",
        (1.0, 0.78, 0.72),
        (0.0, 0.0, 0.36),
        material,
        collection,
    )
    collision.display_type = "WIRE"
    collision["collision_kind"] = "box"
    return collision


# -----------------------------------------------------------------------------
# Validation, export, manifest, and preview
# -----------------------------------------------------------------------------

def triangle_count(obj: bpy.types.Object) -> int:
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


def non_manifold_edge_count(obj: bpy.types.Object) -> int:
    mesh = bmesh.new()
    try:
        mesh.from_mesh(obj.data)
        return sum(1 for edge in mesh.edges if not edge.is_manifold)
    finally:
        mesh.free()


def validate_mesh(obj: bpy.types.Object, variant: str) -> dict[str, object]:
    if obj.type != "MESH":
        raise RuntimeError(f"{variant}: expected MESH, got {obj.type}")
    if any(abs(value - 1.0) > 1e-6 for value in obj.scale):
        raise RuntimeError(f"{variant}: unapplied scale {tuple(obj.scale)}")
    if any(abs(value) > 1e-6 for value in obj.rotation_euler):
        raise RuntimeError(f"{variant}: unapplied rotation {tuple(obj.rotation_euler)}")
    if obj.location.length > 1e-6:
        raise RuntimeError(f"{variant}: origin/object location must be zero")
    if len(obj.data.materials) > MAX_MATERIALS:
        raise RuntimeError(f"{variant}: too many materials ({len(obj.data.materials)})")

    triangles = triangle_count(obj)
    if triangles > MAX_TRIS[variant]:
        raise RuntimeError(f"{variant}: {triangles} tris exceeds {MAX_TRIS[variant]}")
    non_manifold = non_manifold_edge_count(obj)
    if REQUIRE_CLOSED_MESH and non_manifold:
        raise RuntimeError(f"{variant}: {non_manifold} non-manifold/boundary edges")

    data = {
        "triangles": triangles,
        "materials": len(obj.data.materials),
        "dimensions_m": [round(float(value), 4) for value in obj.dimensions],
        "non_manifold_edges": non_manifold,
    }
    print(f"[3DBLENDER] {variant}: PASS {data}")
    return data


def export_object(obj: bpy.types.Object, path: Path) -> None:
    activate(obj)
    result = bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"GLB export failed: {path}")


def point_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_area_light(
    name: str,
    location: tuple[float, float, float],
    energy: float,
    color: tuple[float, float, float],
    size: float,
    target: tuple[float, float, float],
    collection: bpy.types.Collection,
) -> None:
    light_data = bpy.data.lights.new(name=name, type="AREA")
    light_data.energy = energy
    light_data.color = color
    light_data.shape = "DISK"
    light_data.size = size
    light = bpy.data.objects.new(name, light_data)
    collection.objects.link(light)
    light.location = location
    point_at(light, target)


def setup_preview(
    asset: bpy.types.Object,
    collection: bpy.types.Collection,
    floor_material: bpy.types.Material,
) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = 700
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUTPUT_DIR / f"{ASSET_ID}_preview.png")
    scene.render.film_transparent = False
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        pass

    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    if bpy.app.version < (5, 0, 0):
        scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.008, 0.012, 0.025, 1.0)
    background.inputs["Strength"].default_value = 0.2
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    display = asset.copy()
    display.data = asset.data
    display.name = f"PREVIEW_{ASSET_ID}"
    collection.objects.link(display)

    floor = add_box(
        "PREVIEW_Floor",
        (4.0, 4.0, 0.04),
        (0.0, 0.0, -0.025),
        floor_material,
        collection,
        0.01,
        1,
    )
    floor.hide_select = True

    target = (0.0, 0.0, 0.36)
    add_area_light("LGT_Key", (-2.1, -2.5, 2.8), 480.0, (0.75, 0.86, 1.0), 1.4, target, collection)
    add_area_light("LGT_Rim", (1.8, 1.2, 2.1), 620.0, (1.0, 0.38, 0.12), 1.1, target, collection)
    add_area_light("LGT_Fill", (0.2, -0.8, 0.4), 140.0, (0.35, 0.46, 1.0), 1.6, target, collection)

    camera_data = bpy.data.cameras.new("CAM_Preview")
    camera = bpy.data.objects.new("CAM_Preview", camera_data)
    collection.objects.link(camera)
    camera.location = (2.0, -2.8, 1.8)
    camera_data.lens = 52.0
    point_at(camera, target)
    scene.camera = camera


def render_preview_isolated(collection: bpy.types.Collection) -> None:
    """Render only preview objects without mutating the user's scene state."""
    scene = bpy.context.scene
    preview_objects = set(collection.all_objects)
    previous_visibility = {obj: obj.hide_render for obj in scene.objects}
    try:
        for obj in scene.objects:
            obj.hide_render = obj not in preview_objects
        bpy.ops.render.render(write_still=True)
    finally:
        for obj, was_hidden in previous_visibility.items():
            if obj.name in bpy.data.objects:
                obj.hide_render = was_hidden


def write_manifest(results: dict[str, dict[str, object]]) -> Path:
    manifest = {
        "asset": ASSET_ID,
        "status": "PASS",
        "quality": "GAME_READY_TEMPLATE",
        "units": "meters",
        "dimensions_m": results["LOD0"]["dimensions_m"],
        "forward_blender": "-Y",
        "forward_godot": "-Z",
        "triangles_lod0": results["LOD0"]["triangles"],
        "triangles_lod1": results["LOD1"]["triangles"],
        "triangles_lod2": results["LOD2"]["triangles"],
        "collision": "single box proxy",
        "origin": "center of base",
        "identity": "compact reinforced calibration crate",
        "textures_packed": True,
        "seed": SEED,
    }
    path = OUTPUT_DIR / "asset_manifest.json"
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return path


def main() -> None:
    if bpy.app.version < MIN_BLENDER:
        raise RuntimeError(
            f"Blender {MIN_BLENDER} or newer required; found {bpy.app.version}"
        )
    random.Random(SEED)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    clear_previous_generation()

    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene.unit_settings.scale_length = 1.0

    root = new_collection(ROOT_COLLECTION)
    lod0_collection = new_collection("EXPORT_LOD0", root)
    lod1_collection = new_collection("EXPORT_LOD1", root)
    lod2_collection = new_collection("EXPORT_LOD2", root)
    collision_collection = new_collection("EXPORT_COLLISION", root)
    preview_collection = new_collection("PREVIEW_ONLY", root)

    wood = make_material("Wood", (0.22, 0.075, 0.025, 1.0), 0.0, 0.72)
    iron = make_material("Iron", (0.09, 0.11, 0.14, 1.0), 0.82, 0.30)
    collision_material = make_material("Collision", (0.9, 0.05, 0.02, 1.0), 0.0, 0.9)

    lod0 = build_lod0(lod0_collection, wood, iron)
    lod1 = build_simple_lod("LOD1", lod1_collection, wood, 0.014)
    lod2 = build_simple_lod("LOD2", lod2_collection, wood, 0.0)
    collision = build_collision(collision_collection, collision_material)

    results = {
        "LOD0": validate_mesh(lod0, "LOD0"),
        "LOD1": validate_mesh(lod1, "LOD1"),
        "LOD2": validate_mesh(lod2, "LOD2"),
        "collision": validate_mesh(collision, "collision"),
    }

    if EXPORT_GLB:
        export_object(lod0, OUTPUT_DIR / f"{ASSET_ID}_LOD0.glb")
        export_object(lod1, OUTPUT_DIR / f"{ASSET_ID}_LOD1.glb")
        export_object(lod2, OUTPUT_DIR / f"{ASSET_ID}_LOD2.glb")
        export_object(collision, OUTPUT_DIR / f"{ASSET_ID}_collision.glb")

    manifest_path = write_manifest(results)
    if RENDER_PREVIEW:
        floor_material = make_material("PreviewFloor", (0.018, 0.024, 0.038, 1.0), 0.08, 0.38)
        setup_preview(lod0, preview_collection, floor_material)
        render_preview_isolated(preview_collection)
    if SAVE_BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / f"{ASSET_ID}.blend"))

    print(f"[3DBLENDER] Blender: {bpy.app.version_string}")
    print(f"[3DBLENDER] Seed: {SEED}")
    print(f"[3DBLENDER] Manifest: {manifest_path}")
    print(f"[3DBLENDER] PASS: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
