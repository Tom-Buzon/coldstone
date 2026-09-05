"""Generate a varied, game-ready battlefield dressing collection for Hoplite.

Assets: two cloth banners, a bronze command standard, a cheval-de-frise,
spear/shield rack, signal brazier, weapon debris, and a fallen-hoplite memorial.
Each ships with LOD0/LOD1/LOD2, a coarse collision proxy, a manifest, a square
Forge thumbnail, a combined preview, and a reproducible Blender source.

Run with Blender's Text Editor or:
    blender --background --python build_battlefield_dressing.py
"""

from __future__ import annotations

import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import bmesh
import bpy
from mathutils import Vector


# Dominant silhouettes: tall readable standards, low defensive obstacles, and
# grounded story clutter. Identity features survive normal gameplay distance;
# small emblems, rope bindings, coals, and debris disappear before silhouettes.
# All origins sit at the center of the base, Blender forward is -Y, and authored
# collisions remain primitive/convex-friendly for Godot/Jolt.
SEED = 260828
MIN_BLENDER = (4, 3, 0)
ROOT_COLLECTION = "GEN_BattlefieldDressing"
MATERIAL_PREFIX = "MAT_Battlefield_"
OUTPUT_FOLDER_NAME = "battlefield_dressing_output"
MAX_MATERIALS = 4


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    identity: str
    builder: Callable[[int, bpy.types.Collection, dict[str, bpy.types.Material]], bpy.types.Object]
    collision_builder: Callable[[bpy.types.Collection, dict[str, bpy.types.Material]], bpy.types.Object]
    collision_description: str
    forge_collision_enabled: bool
    forge_collision_shape: str
    budgets: tuple[int, int, int, int]


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
    for material in list(bpy.data.materials):
        if material.name.startswith(MATERIAL_PREFIX) and material.users == 0:
            bpy.data.materials.remove(material)


def new_collection(name: str, parent: bpy.types.Collection | None = None) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def activate(obj: bpy.types.Object) -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_transform(obj: bpy.types.Object) -> None:
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def hex_rgba(value: str) -> tuple[float, float, float, float]:
    value = value.lstrip("#")
    rgb = [int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)]
    return tuple(srgb_to_linear(channel) for channel in rgb) + (1.0,)


def set_input(node: bpy.types.Node, names: tuple[str, ...], value: object) -> None:
    for name in names:
        socket = node.inputs.get(name)
        if socket is not None:
            socket.default_value = value
            return


def make_material(
    suffix: str,
    color: str,
    metallic: float,
    roughness: float,
    emission: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name=f"{MATERIAL_PREFIX}{suffix}")
    if bpy.app.version < (5, 0, 0):
        material.use_nodes = True
    rgba = hex_rgba(color)
    material.diffuse_color = rgba
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError(f"{material.name}: missing Principled BSDF")
    set_input(principled, ("Base Color",), rgba)
    set_input(principled, ("Metallic",), metallic)
    set_input(principled, ("Roughness",), roughness)
    set_input(principled, ("Specular IOR Level", "Specular"), 0.35)
    if emission is not None:
        set_input(principled, ("Emission Color", "Emission"), hex_rgba(emission))
        set_input(principled, ("Emission Strength",), emission_strength)
    return material


def build_palette() -> dict[str, bpy.types.Material]:
    return {
        "wood": make_material("WeatheredWood", "4E2E1D", 0.0, 0.82),
        "wood_light": make_material("SplitWood", "7A4B2A", 0.0, 0.76),
        "iron": make_material("BlackIron", "20262C", 0.78, 0.34),
        "bronze": make_material("WarBronze", "9A6126", 0.78, 0.31),
        "crimson": make_material("CrimsonCloth", "8F1826", 0.0, 0.82),
        "aegean": make_material("AegeanCloth", "174E73", 0.0, 0.79),
        "black": make_material("SootCloth", "211A20", 0.0, 0.91),
        "ivory": make_material("DustIvory", "D8C8A7", 0.0, 0.72),
        "leather": make_material("Oxhide", "6F3826", 0.0, 0.86),
        "stone": make_material("BattleStone", "5D5A55", 0.0, 0.88),
        "coal": make_material("SignalCoal", "231310", 0.0, 0.92, "F15B24", 3.5),
        "ember": make_material("SignalFlame", "6A1A0C", 0.0, 0.45, "FF9B2F", 4.8),
        "collision": make_material("Collision", "FF2D1C", 0.0, 0.96),
        "preview_floor": make_material("PreviewFloor", "171A20", 0.04, 0.55),
    }


def assign(obj: bpy.types.Object, material: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.append(material)
    return obj


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 1) -> None:
    if width <= 0.0:
        return
    bevel = obj.modifiers.new("EdgeHighlight", "BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(24.0)
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=bevel.name)


def add_box(
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    move_to_collection(obj, collection)
    apply_transform(obj)
    apply_bevel(obj, bevel, 2 if bevel >= 0.025 else 1)
    return assign(obj, material)


def add_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 10,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    apply_transform(obj)
    apply_bevel(obj, bevel)
    return assign(obj, material)


def add_cone(
    name: str,
    bottom: float,
    top: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 8,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=bottom, radius2=top, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    apply_transform(obj)
    return assign(obj, material)


def add_ico(
    name: str,
    radius: float,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    subdivisions: int = 1,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    move_to_collection(obj, collection)
    apply_transform(obj)
    return assign(obj, material)


def add_torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    major_segments: int = 14,
    minor_segments: int = 5,
    rotation: tuple[float, float, float] = (math.pi / 2.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    apply_transform(obj)
    return assign(obj, material)


def add_cylinder_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 10,
) -> bpy.types.Object:
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length, location=(start_v + end_v) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    move_to_collection(obj, collection)
    apply_transform(obj)
    return assign(obj, material)


def create_mesh(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=False)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return assign(obj, material)


def extrude_xz_polygon(
    name: str,
    outline: list[tuple[float, float]],
    depth: float,
    y: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    half = depth * 0.5
    count = len(outline)
    vertices = [(x, y - half, z) for x, z in outline] + [(x, y + half, z) for x, z in outline]
    faces: list[tuple[int, ...]] = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    return create_mesh(name, vertices, faces, material, collection)


def add_spear(
    prefix: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    shaft: bpy.types.Material,
    metal: bpy.types.Material,
    collection: bpy.types.Collection,
    lod: int,
) -> list[bpy.types.Object]:
    start_v, end_v = Vector(start), Vector(end)
    direction = (end_v - start_v).normalized()
    shaft_end = end_v - direction * 0.28
    parts = [add_cylinder_between(f"{prefix}Shaft", start, tuple(shaft_end), 0.035 if lod < 2 else 0.045, shaft, collection, (10, 8, 6)[lod])]
    tip_center = end_v - direction * 0.12
    bpy.ops.mesh.primitive_cone_add(vertices=(8, 6, 5)[lod], radius1=0.105, radius2=0.0, depth=0.34, location=tip_center)
    tip = bpy.context.object
    tip.name = f"{prefix}Spearhead"
    tip.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    move_to_collection(tip, collection)
    apply_transform(tip)
    parts.append(assign(tip, metal))
    return parts


def normalize_slots(parts: list[bpy.types.Object], materials: list[bpy.types.Material]) -> None:
    indices = {material.name: index for index, material in enumerate(materials)}
    for part in parts:
        intended = part.data.materials[0]
        intended_index = indices[intended.name]
        part.data.materials.clear()
        for material in materials:
            part.data.materials.append(material)
        for polygon in part.data.polygons:
            polygon.material_index = intended_index


def join_parts(parts: list[bpy.types.Object], name: str, materials: list[bpy.types.Material]) -> bpy.types.Object:
    if not parts:
        raise RuntimeError(f"{name}: no mesh parts")
    if len(parts) == 1:
        result = parts[0]
        result.name = name
        result.data.name = f"{name}_Mesh"
        apply_transform(result)
        return result
    normalize_slots(parts, materials)
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    result.data.name = f"{name}_Mesh"
    apply_transform(result)
    return result


def finish(parts: list[bpy.types.Object], asset_id: str, lod: int, materials: list[bpy.types.Material]) -> bpy.types.Object:
    result = join_parts(parts, f"{asset_id}_LOD{lod}", materials)
    result["asset_id"] = asset_id
    result["asset_family"] = "battlefield"
    result["lod"] = lod
    result["unit_scale_meters"] = 1.0
    result["forward_blender"] = "-Y"
    result["forward_godot"] = "-Z"
    return result


def banner_base(
    lod: int,
    collection: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    cloth_key: str,
    outline: list[tuple[float, float]],
    asset_id: str,
    emblem: str,
) -> bpy.types.Object:
    wood, bronze, cloth, ivory = mats["wood"], mats["bronze"], mats[cloth_key], mats["ivory"]
    parts: list[bpy.types.Object] = [
        add_cylinder("BannerPole", 0.075, 4.15, (0.0, 0.0, 2.075), wood, collection, (12, 9, 6)[lod]),
        add_cylinder("BannerCrossbar", 0.055, 2.12, (0.0, 0.0, 3.64), bronze, collection, (10, 8, 6)[lod], rotation=(0.0, math.pi / 2.0, 0.0)),
        add_cone("BannerFinial", 0.15, 0.0, 0.42, (0.0, 0.0, 4.36), bronze, collection, (9, 7, 5)[lod]),
        add_cylinder("BannerFoot", 0.24, 0.12, (0.0, 0.0, 0.06), bronze, collection, (12, 9, 6)[lod]),
        extrude_xz_polygon("BannerCloth", outline, 0.055 if lod < 2 else 0.075, -0.02, cloth, collection),
    ]
    if lod < 2:
        y = -0.065
        if emblem == "lambda":
            parts.append(add_box("LambdaLeft", (0.12, 0.065, 0.95), (-0.25, y, 2.72), ivory, collection, rotation=(0.0, math.radians(24.0), 0.0), bevel=0.012))
            parts.append(add_box("LambdaRight", (0.12, 0.065, 0.95), (0.25, y, 2.72), ivory, collection, rotation=(0.0, math.radians(-24.0), 0.0), bevel=0.012))
        else:
            segments = 14 if lod == 0 else 10
            parts.append(add_torus("OwlEyeLeft", 0.21, 0.055, (-0.32, y, 2.88), ivory, collection, segments, 5))
            parts.append(add_torus("OwlEyeRight", 0.21, 0.055, (0.32, y, 2.88), ivory, collection, segments, 5))
            parts.append(add_box("OwlBrow", (0.82, 0.065, 0.11), (0.0, y, 3.12), bronze, collection, rotation=(0.0, 0.0, math.radians(-5.0)), bevel=0.01))
            parts.append(add_cone("OwlBeak", 0.15, 0.0, 0.36, (0.0, y, 2.55), bronze, collection, 6, rotation=(math.pi, 0.0, 0.0)))
    if lod == 0:
        for x in (-0.83, 0.83):
            parts.append(add_box("BannerEdge", (0.055, 0.068, 1.90), (x, -0.055, 2.68), bronze, collection, bevel=0.008))
        for x in (-0.78, -0.26, 0.26, 0.78):
            parts.append(add_torus("BannerTie", 0.075, 0.018, (x, 0.0, 3.58), bronze, collection, 10, 4, rotation=(0.0, math.pi / 2.0, 0.0)))
    return finish(parts, asset_id, lod, [wood, bronze, cloth, ivory])


def build_crimson_banner(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    outline = [(-0.86, 3.58), (0.86, 3.58), (0.82, 1.72), (0.46, 1.92), (0.0, 1.60), (-0.46, 1.90), (-0.82, 1.72)]
    return banner_base(lod, collection, mats, "crimson", outline, "battle_banner_crimson_lambda", "lambda")


def build_aegean_banner(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    outline = [(-0.86, 3.58), (0.86, 3.58), (0.82, 2.02), (0.55, 1.68), (0.20, 1.92), (0.0, 1.54), (-0.24, 1.94), (-0.58, 1.70), (-0.82, 2.04)]
    return banner_base(lod, collection, mats, "aegean", outline, "battle_banner_aegean_owl", "owl")


def build_bronze_standard(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    wood, bronze, crimson, iron = mats["wood"], mats["bronze"], mats["crimson"], mats["iron"]
    parts: list[bpy.types.Object] = [
        add_cylinder("StandardPole", 0.075, 3.95, (0.0, 0.0, 1.975), wood, collection, (12, 9, 6)[lod]),
        add_cylinder("StandardFoot", 0.25, 0.12, (0.0, 0.0, 0.06), iron, collection, (12, 9, 6)[lod]),
        add_torus("StandardSunRing", 0.42, 0.085, (0.0, -0.03, 3.95), bronze, collection, (20, 14, 10)[lod], (6, 5, 4)[lod]),
        add_ico("StandardHelmCore", 0.26, (0.0, -0.05, 3.95), (0.86, 0.46, 1.05), bronze, collection, 1),
        add_cone("StandardTopSpear", 0.14, 0.0, 0.55, (0.0, 0.0, 4.67), bronze, collection, (8, 6, 5)[lod]),
    ]
    ray_count = (12, 6, 0)[lod]
    for index in range(ray_count):
        angle = math.tau * index / ray_count
        parts.append(add_box("SunRay", (0.30, 0.09, 0.075), (0.58 * math.cos(angle), -0.04, 3.95 + 0.58 * math.sin(angle)), bronze, collection, rotation=(0.0, -angle, 0.0), bevel=0.01))
    if lod < 2:
        parts.append(extrude_xz_polygon("LeftRibbon", [(-0.66, 3.48), (-0.18, 3.48), (-0.22, 2.72), (-0.44, 2.88), (-0.64, 2.66)], 0.045, -0.02, crimson, collection))
        parts.append(extrude_xz_polygon("RightRibbon", [(0.18, 3.48), (0.66, 3.48), (0.64, 2.66), (0.44, 2.88), (0.22, 2.72)], 0.045, -0.02, crimson, collection))
    return finish(parts, "battle_standard_bronze_sun", lod, [wood, bronze, crimson, iron])


def build_barricade(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    wood, light, iron = mats["wood"], mats["wood_light"], mats["iron"]
    parts: list[bpy.types.Object] = [
        add_cylinder_between("BarricadeBeam", (-1.75, 0.0, 0.72), (1.75, 0.0, 0.72), 0.14, wood, collection, (12, 9, 6)[lod]),
        add_cylinder_between("BarricadeLowerBeam", (-1.48, 0.0, 0.32), (1.48, 0.0, 0.32), 0.10, light, collection, (10, 8, 6)[lod]),
    ]
    for side in (-1.0, 1.0):
        parts.append(add_cylinder_between("BarricadeFoot", (side * 1.28, -0.62, 0.08), (side * 1.28, 0.62, 0.08), 0.105, wood, collection, (10, 8, 6)[lod]))
        parts.append(add_cylinder_between("BarricadeBrace", (side * 1.28, -0.52, 0.08), (side * 1.28, 0.0, 0.78), 0.085, light, collection, (10, 8, 6)[lod]))
    spike_x = (-1.42, -0.72, 0.0, 0.72, 1.42) if lod == 0 else (-1.20, 0.0, 1.20) if lod == 1 else (-1.0, 1.0)
    for index, x in enumerate(spike_x):
        slant = -0.24 if index % 2 == 0 else 0.24
        parts.extend(add_spear("BarricadeSpike", (x + slant, 0.0, 0.10), (x - slant, 0.0, 1.72), light, iron, collection, lod))
    if lod == 0:
        for x in (-1.30, 0.0, 1.30):
            parts.append(add_torus("BarricadeRope", 0.17, 0.035, (x, 0.0, 0.72), mats["leather"], collection, 10, 4, rotation=(0.0, math.pi / 2.0, 0.0)))
        materials = [wood, light, iron, mats["leather"]]
    else:
        materials = [wood, light, iron]
    return finish(parts, "battle_spiked_field_barricade", lod, materials)


def build_spear_shield_rack(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    wood, bronze, leather, crimson = mats["wood"], mats["bronze"], mats["leather"], mats["crimson"]
    parts: list[bpy.types.Object] = []
    spear_count = (4, 3, 2)[lod]
    for index in range(spear_count):
        x = (index - (spear_count - 1) * 0.5) * 0.28
        lean = (index - (spear_count - 1) * 0.5) * 0.10
        parts.extend(add_spear("RackSpear", (x, 0.15, 0.08), (x + lean, -0.02, 2.82 - abs(lean)), wood, bronze, collection, lod))
    parts.append(add_cylinder("RackShield", 0.68, 0.12, (-0.52, -0.22, 0.72), leather, collection, (20, 14, 10)[lod], rotation=(math.pi / 2.0, 0.0, math.radians(-9.0))))
    parts.append(add_cylinder("RackShieldRim", 0.58, 0.135, (-0.52, -0.23, 0.72), bronze, collection, (20, 14, 10)[lod], rotation=(math.pi / 2.0, 0.0, math.radians(-9.0))))
    parts.append(add_cylinder("RackShieldFace", 0.50, 0.145, (-0.52, -0.24, 0.72), crimson, collection, (20, 14, 10)[lod], rotation=(math.pi / 2.0, 0.0, math.radians(-9.0))))
    parts.append(add_ico("RackShieldBoss", 0.19, (-0.52, -0.34, 0.72), (1.0, 0.48, 1.0), bronze, collection, 1))
    if lod == 0:
        parts.append(add_cylinder_between("RackTie", (-0.58, -0.02, 1.82), (0.58, -0.02, 1.82), 0.045, leather, collection, 8))
    return finish(parts, "battle_spear_shield_rack", lod, [wood, bronze, leather, crimson])


def build_signal_brazier(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    bronze, iron, coal, ember = mats["bronze"], mats["iron"], mats["coal"], mats["ember"]
    parts: list[bpy.types.Object] = [
        add_cone("BrazierBowl", 0.72, 0.54, 0.34, (0.0, 0.0, 1.30), bronze, collection, (18, 12, 8)[lod]),
        add_torus("BrazierRim", 0.64, 0.075, (0.0, 0.0, 1.46), bronze, collection, (20, 14, 10)[lod], (6, 5, 4)[lod], rotation=(0.0, 0.0, 0.0)),
        add_cylinder("BrazierCoalBed", 0.53, 0.10, (0.0, 0.0, 1.45), coal, collection, (16, 12, 8)[lod]),
    ]
    for angle in (0.0, math.tau / 3.0, math.tau * 2.0 / 3.0):
        x, y = 0.52 * math.cos(angle), 0.52 * math.sin(angle)
        parts.append(add_cylinder_between("BrazierLeg", (x * 1.24, y * 1.24, 0.06), (x, y, 1.20), 0.065, iron, collection, (10, 8, 6)[lod]))
    flame_count = (5, 3, 1)[lod]
    for index in range(flame_count):
        angle = math.tau * index / max(1, flame_count)
        x, y = 0.20 * math.cos(angle), 0.20 * math.sin(angle)
        parts.append(add_cone("SignalFlame", 0.18 if index else 0.24, 0.015, 0.68 if index else 0.90, (x, y, 1.80 if index else 1.92), ember, collection, (8, 6, 5)[lod], rotation=(0.0, math.radians(8.0 * math.sin(angle)), math.radians(7.0 * math.cos(angle)))))
    return finish(parts, "battle_signal_brazier", lod, [bronze, iron, coal, ember])


def build_weapon_debris(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    wood, bronze, iron, leather = mats["wood"], mats["bronze"], mats["iron"], mats["leather"]
    parts: list[bpy.types.Object] = []
    parts.extend(add_spear("DebrisLongSpear", (-1.35, 0.25, 0.08), (0.75, -0.30, 0.14), wood, bronze, collection, lod))
    if lod < 2:
        parts.extend(add_spear("DebrisBrokenSpear", (-0.35, -0.55, 0.09), (0.75, 0.46, 0.18), wood, bronze, collection, lod))
        parts.append(extrude_xz_polygon("DebrisSwordBlade", [(-0.08, 0.04), (0.08, 0.04), (0.055, 0.82), (0.0, 1.02), (-0.055, 0.82)], 0.055, -0.08, iron, collection))
        parts[-1].rotation_euler = (0.0, math.radians(76.0), math.radians(72.0))
        apply_transform(parts[-1])
    parts.append(add_cylinder("DebrisShield", 0.52, 0.09, (0.65, 0.42, 0.13), leather, collection, (18, 12, 8)[lod], rotation=(math.radians(8.0), math.radians(12.0), math.radians(18.0))))
    parts.append(add_cylinder("DebrisBoss", 0.16, 0.115, (0.63, 0.40, 0.19), bronze, collection, (12, 9, 6)[lod], rotation=(math.radians(8.0), math.radians(12.0), math.radians(18.0))))
    return finish(parts, "battle_weapon_debris", lod, [wood, bronze, iron, leather])


def build_fallen_memorial(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    stone, bronze, crimson, wood = mats["stone"], mats["bronze"], mats["crimson"], mats["wood"]
    parts: list[bpy.types.Object] = [
        add_ico("MemorialStoneLarge", 0.46, (-0.18, 0.02, 0.29), (1.2, 0.95, 0.70), stone, collection, 1),
        add_ico("MemorialStoneSmall", 0.34, (0.32, 0.08, 0.20), (1.0, 0.85, 0.65), stone, collection, 1),
    ]
    parts.extend(add_spear("MemorialSpear", (-0.20, 0.05, 0.18), (0.18, 0.0, 3.26), wood, bronze, collection, lod))
    parts.append(add_cylinder("MemorialShield", 0.58, 0.11, (-0.42, -0.24, 0.72), crimson, collection, (20, 14, 10)[lod], rotation=(math.pi / 2.0, math.radians(-8.0), math.radians(-12.0))))
    parts.append(add_cylinder("MemorialShieldRim", 0.50, 0.13, (-0.42, -0.26, 0.72), bronze, collection, (20, 14, 10)[lod], rotation=(math.pi / 2.0, math.radians(-8.0), math.radians(-12.0))))
    parts.append(add_ico("MemorialHelmet", 0.34, (0.38, -0.28, 0.60), (0.88, 0.65, 1.0), bronze, collection, 2 if lod == 0 else 1))
    parts.append(add_box("MemorialHelmetNasal", (0.10, 0.16, 0.44), (0.38, -0.52, 0.46), bronze, collection, bevel=0.015))
    if lod < 2:
        parts.append(add_box("MemorialCrest", (0.12, 0.44, 0.55), (0.38, -0.22, 0.96), crimson, collection, rotation=(0.0, math.radians(-8.0), 0.0), bevel=0.018))
    return finish(parts, "battle_fallen_hoplite_memorial", lod, [stone, bronze, crimson, wood])


def collision_cylinder(asset_id: str, radius: float, height: float, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return join_parts([add_cylinder("CollisionProxy", radius, height, (0.0, 0.0, height * 0.5), mats["collision"], collection, 8)], f"{asset_id}-col", [mats["collision"]])


def collision_box(asset_id: str, size: tuple[float, float, float], collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return join_parts([add_box("CollisionProxy", size, (0.0, 0.0, size[2] * 0.5), mats["collision"], collection)], f"{asset_id}-col", [mats["collision"]])


def col_crimson(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_cylinder("battle_banner_crimson_lambda", 0.24, 4.45, c, m)


def col_aegean(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_cylinder("battle_banner_aegean_owl", 0.24, 4.45, c, m)


def col_standard(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_cylinder("battle_standard_bronze_sun", 0.25, 4.95, c, m)


def col_barricade(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_box("battle_spiked_field_barricade", (3.55, 1.30, 1.48), c, m)


def col_rack(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_box("battle_spear_shield_rack", (1.65, 0.70, 2.80), c, m)


def col_brazier(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_cylinder("battle_signal_brazier", 0.76, 1.50, c, m)


def col_debris(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_box("battle_weapon_debris", (2.75, 1.35, 0.22), c, m)


def col_memorial(c: bpy.types.Collection, m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_cylinder("battle_fallen_hoplite_memorial", 0.78, 1.25, c, m)


def triangle_count(obj: bpy.types.Object) -> int:
    return sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons)


def non_manifold_edge_count(obj: bpy.types.Object) -> int:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    count = sum(1 for edge in bm.edges if not edge.is_manifold)
    bm.free()
    return count


def validate(obj: bpy.types.Object, label: str, budget: int) -> dict[str, object]:
    if obj.type != "MESH":
        raise RuntimeError(f"{label}: expected MESH")
    if obj.location.length > 0.0001 or any(abs(float(v)) > 0.0001 for v in obj.rotation_euler) or any(abs(float(v) - 1.0) > 0.0001 for v in obj.scale):
        raise RuntimeError(f"{label}: transforms are not applied")
    triangles = triangle_count(obj)
    if triangles > budget:
        raise RuntimeError(f"{label}: {triangles} tris exceeds {budget}")
    if len(obj.data.materials) > MAX_MATERIALS:
        raise RuntimeError(f"{label}: {len(obj.data.materials)} materials exceeds {MAX_MATERIALS}")
    non_manifold = non_manifold_edge_count(obj)
    if non_manifold:
        raise RuntimeError(f"{label}: {non_manifold} non-manifold/boundary edges")
    evidence = {
        "triangles": triangles,
        "materials": len(obj.data.materials),
        "dimensions_m": [round(float(v), 4) for v in obj.dimensions],
        "non_manifold_edges": non_manifold,
        "uv_layers": len(obj.data.uv_layers),
    }
    print(f"[BATTLEFIELD] {label}: PASS {evidence}")
    return evidence


def export_object(obj: bpy.types.Object, path: Path) -> None:
    activate(obj)
    result = bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_materials="EXPORT",
        export_cameras=False, export_lights=False, export_animations=False,
        export_extras=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"GLB export failed: {path}")


def write_manifest(spec: AssetSpec, evidence: dict[str, dict[str, object]], asset_dir: Path) -> Path:
    manifest = {
        "asset": spec.asset_id,
        "status": "PASS",
        "quality": "V2_HERO",
        "family": "battlefield",
        "units": "meters",
        "dimensions_m": evidence["LOD0"]["dimensions_m"],
        "forward_blender": "-Y",
        "forward_godot": "-Z",
        "triangles_lod0": evidence["LOD0"]["triangles"],
        "triangles_lod1": evidence["LOD1"]["triangles"],
        "triangles_lod2": evidence["LOD2"]["triangles"],
        "triangles_collision": evidence["collision"]["triangles"],
        "collision": spec.collision_description,
        "forge_collision_enabled": spec.forge_collision_enabled,
        "forge_collision_shape": spec.forge_collision_shape,
        "origin": "center of base",
        "identity": spec.identity,
        "material_strategy": "shared flat PBR battlefield palette",
        "textures_packed": True,
        "seed": SEED,
    }
    path = asset_dir / "asset_manifest.json"
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return path


def point_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_area_light(name: str, location: tuple[float, float, float], energy: float, color: tuple[float, float, float], size: float, target: tuple[float, float, float], collection: bpy.types.Collection) -> None:
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    collection.objects.link(light)
    light.location = location
    point_at(light, target)


def configure_render() -> None:
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        pass
    scene.render.image_settings.file_format = "PNG"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    if bpy.app.version < (5, 0, 0):
        scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = hex_rgba("0B0D12")
    background.inputs["Strength"].default_value = 0.16
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = -0.25


def render_isolated(collection: bpy.types.Collection) -> None:
    scene = bpy.context.scene
    visible = set(collection.all_objects)
    previous = {obj: obj.hide_render for obj in scene.objects}
    try:
        for obj in scene.objects:
            obj.hide_render = obj not in visible
        bpy.ops.render.render(write_still=True)
    finally:
        for obj, hidden in previous.items():
            if obj.name in bpy.data.objects:
                obj.hide_render = hidden


def setup_combined_preview(sources: list[bpy.types.Object], collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 930
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUTPUT_DIR / "battlefield_dressing_preview.png")
    positions = [(-5.8, 2.0, 0.0), (-2.0, 2.0, 0.0), (2.0, 2.0, 0.0), (5.8, 2.0, 0.0), (-5.5, -2.2, 0.0), (-1.9, -2.2, 0.0), (1.8, -2.2, 0.0), (5.3, -2.2, 0.0)]
    for source, position in zip(sources, positions):
        display = source.copy()
        display.data = source.data
        display.name = f"PREVIEW_{source.name}"
        display.location = position
        display.rotation_euler.z = math.radians(-8.0 if position[0] > 0 else 8.0)
        collection.objects.link(display)
    add_box("PreviewFloor", (16.5, 10.0, 0.10), (0.0, 0.0, -0.07), mats["preview_floor"], collection, bevel=0.04)
    target = (0.0, 0.0, 2.0)
    add_area_light("PreviewKey", (-7.0, -8.0, 10.0), 1650.0, (0.68, 0.80, 1.0), 5.0, target, collection)
    add_area_light("PreviewRim", (7.0, 2.5, 8.0), 1900.0, (1.0, 0.30, 0.12), 4.5, target, collection)
    add_area_light("PreviewFill", (0.0, -3.0, 4.0), 520.0, (0.38, 0.50, 1.0), 5.0, target, collection)
    camera_data = bpy.data.cameras.new("CAM_BattlefieldCollection")
    camera = bpy.data.objects.new("CAM_BattlefieldCollection", camera_data)
    collection.objects.link(camera)
    camera.location = (13.0, -20.5, 9.0)
    camera_data.lens = 52.0
    point_at(camera, target)
    scene.camera = camera


def render_thumbnails(sources: list[bpy.types.Object], collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    scene = bpy.context.scene
    thumbnail_dir = OUTPUT_DIR / "thumbnails"
    thumbnail_dir.mkdir(parents=True, exist_ok=True)
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    add_box("ThumbnailFloor", (8.0, 8.0, 0.08), (0.0, 0.0, -0.05), mats["preview_floor"], collection, bevel=0.03)
    add_area_light("ThumbnailKey", (-4.5, -5.5, 7.5), 1100.0, (0.72, 0.84, 1.0), 4.0, (0.0, 0.0, 1.5), collection)
    add_area_light("ThumbnailRim", (4.8, 2.0, 6.0), 1350.0, (1.0, 0.34, 0.10), 3.5, (0.0, 0.0, 1.5), collection)
    camera_data = bpy.data.cameras.new("CAM_BattlefieldThumbnail")
    camera = bpy.data.objects.new("CAM_BattlefieldThumbnail", camera_data)
    collection.objects.link(camera)
    camera_data.lens = 56.0
    scene.camera = camera
    for source in sources:
        display = source.copy()
        display.data = source.data
        display.rotation_euler.z = math.radians(-12.0)
        collection.objects.link(display)
        extent = max(float(source.dimensions.x), float(source.dimensions.y), float(source.dimensions.z), 0.4)
        distance = max(2.8, extent * 1.72)
        target_z = float(source.dimensions.z) * 0.46
        camera.location = (distance * 0.72, -distance * 1.06, target_z + distance * 0.48)
        point_at(camera, (0.0, 0.0, target_z))
        scene.render.filepath = str(thumbnail_dir / f"{source['asset_id']}.png")
        render_isolated(collection)
        bpy.data.objects.remove(display, do_unlink=True)


def asset_specs() -> list[AssetSpec]:
    return [
        AssetSpec("battle_banner_crimson_lambda", "tall crimson hoplite banner with bronze crossbar, swallowtail cloth and ivory lambda", build_crimson_banner, col_crimson, "slender cylinder around the planted pole; disabled in Forge to preserve crowd flow", False, "cylinder", (3200, 1800, 700, 80)),
        AssetSpec("battle_banner_aegean_owl", "Aegean-blue forked banner with geometric owl eyes and bronze brow", build_aegean_banner, col_aegean, "slender cylinder around the planted pole; disabled in Forge to preserve crowd flow", False, "cylinder", (3400, 1900, 700, 80)),
        AssetSpec("battle_standard_bronze_sun", "ceremonial bronze sun standard with helmet core, spear finial and paired crimson ribbons", build_bronze_standard, col_standard, "slender cylinder around the planted pole; disabled in Forge to preserve crowd flow", False, "cylinder", (3000, 1600, 600, 80)),
        AssetSpec("battle_spiked_field_barricade", "weathered cheval-de-frise with crossed spear stakes, A-frame feet and rope bindings", build_barricade, col_barricade, "single crowd-safe box covering the defensive obstacle", True, "box", (3600, 1900, 800, 20)),
        AssetSpec("battle_spear_shield_rack", "compact field rack of bronze-tipped spears behind a battered crimson aspis", build_spear_shield_rack, col_rack, "single coarse box covering shield and spear bundle", True, "box", (3200, 1800, 700, 20)),
        AssetSpec("battle_signal_brazier", "high bronze signal brazier on black-iron tripod with hot coals and stylized flame", build_signal_brazier, col_brazier, "single cylinder covering the tripod and hot bowl", True, "cylinder", (3000, 1600, 600, 40)),
        AssetSpec("battle_weapon_debris", "ground-hugging story cluster of broken spears, fallen sword and battered shield", build_weapon_debris, col_debris, "thin ground box; disabled in Forge so debris never snags navigation", False, "box", (2600, 1300, 500, 20)),
        AssetSpec("battle_fallen_hoplite_memorial", "poignant battlefield cairn with planted spear, aspis and crested bronze helmet", build_fallen_memorial, col_memorial, "low cylinder around the cairn and shield while leaving the spear non-blocking", True, "cylinder", (3400, 1800, 700, 40)),
    ]


def main() -> None:
    if bpy.app.version < MIN_BLENDER:
        raise RuntimeError(f"Blender {MIN_BLENDER} or newer required; found {bpy.app.version}")
    random.seed(SEED)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    clear_previous_generation()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene.unit_settings.scale_length = 1.0
    configure_render()
    mats = build_palette()
    root = new_collection(ROOT_COLLECTION)
    exports_root = new_collection("EXPORTS", root)
    collisions_root = new_collection("COLLISIONS", root)
    preview_collection = new_collection("PREVIEW_ONLY", root)
    lod0_objects: list[bpy.types.Object] = []
    summary: list[dict[str, object]] = []
    for spec in asset_specs():
        asset_dir = OUTPUT_DIR / "battlefield" / spec.asset_id
        asset_dir.mkdir(parents=True, exist_ok=True)
        export_collection = new_collection(f"EXPORT_{spec.asset_id}", exports_root)
        collision_collection = new_collection(f"COLLISION_{spec.asset_id}", collisions_root)
        evidence: dict[str, dict[str, object]] = {}
        objects: list[bpy.types.Object] = []
        for lod in range(3):
            obj = spec.builder(lod, export_collection, mats)
            objects.append(obj)
            evidence[f"LOD{lod}"] = validate(obj, f"{spec.asset_id}/LOD{lod}", spec.budgets[lod])
            export_object(obj, asset_dir / f"{spec.asset_id}_LOD{lod}.glb")
        collision = spec.collision_builder(collision_collection, mats)
        evidence["collision"] = validate(collision, f"{spec.asset_id}/collision", spec.budgets[3])
        export_object(collision, asset_dir / f"{spec.asset_id}_collision.glb")
        manifest_path = write_manifest(spec, evidence, asset_dir)
        lod0_objects.append(objects[0])
        summary.append({"asset": spec.asset_id, "triangles_lod0": evidence["LOD0"]["triangles"], "materials": evidence["LOD0"]["materials"], "manifest": str(manifest_path.relative_to(OUTPUT_DIR))})
    summary_path = OUTPUT_DIR / "library_manifest.json"
    summary_path.write_text(json.dumps({"collection": "battlefield_dressing", "status": "PASS", "asset_count": len(summary), "seed": SEED, "assets": summary}, indent=2), encoding="utf-8")
    setup_combined_preview(lod0_objects, preview_collection, mats)
    render_isolated(preview_collection)
    thumbnails = new_collection("THUMBNAILS", root)
    render_thumbnails(lod0_objects, thumbnails, mats)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / "battlefield_dressing.blend"))
    print(f"[BATTLEFIELD] Blender: {bpy.app.version_string}")
    print(f"[BATTLEFIELD] Assets: {len(summary)}")
    print(f"[BATTLEFIELD] Library manifest: {summary_path}")
    print(f"[BATTLEFIELD] PASS: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
