"""Generate a cosy, game-ready Greek architecture and decoration collection.

Assets generated (each with authored LOD0/LOD1/LOD2 and simple collision when
useful): Doric, Ionic and Corinthian columns, amphora cluster, olive planter,
courtyard bench, tripod brazier, mosaic roundel and courtyard fountain.

The collection uses shared flat PBR materials, metric scale and Godot-friendly
GLB exports. It removes only its own ``GEN_CosyGreekCollection`` collection.

Run from Blender's Text Editor or with:
    blender --background --python build_cosy_greek_collection.py

Outputs are written beside this script in ``cosy_greek_collection_output``.
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


# -----------------------------------------------------------------------------
# Editable collection contract
# -----------------------------------------------------------------------------

SEED = 240927
MIN_BLENDER = (4, 3, 0)
EXPORT_GLB = True
SAVE_BLEND = True
RENDER_PREVIEW = True

ROOT_COLLECTION = "GEN_CosyGreekCollection"
MATERIAL_PREFIX = "MAT_CosyGreek_"
OUTPUT_FOLDER_NAME = "cosy_greek_collection_output"
MAX_MATERIALS_PER_ASSET = 4
REQUIRE_CLOSED_MESH = True


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    family: str
    identity: str
    collision_description: str
    forge_collision_enabled: bool
    forge_collision_shape: str
    budgets: tuple[int, int, int, int]
    builder: Callable[[int, bpy.types.Collection, dict[str, bpy.types.Material]], bpy.types.Object]
    collision_builder: Callable[[bpy.types.Collection, dict[str, bpy.types.Material]], bpy.types.Object | None]


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
    for material in list(bpy.data.materials):
        if material.name.startswith(MATERIAL_PREFIX) and material.users == 0:
            bpy.data.materials.remove(material)


def new_collection(
    name: str, parent: bpy.types.Collection | None = None
) -> bpy.types.Collection:
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


def apply_modifiers(obj: bpy.types.Object) -> None:
    activate(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


# -----------------------------------------------------------------------------
# Shared PBR palette
# -----------------------------------------------------------------------------

def srgb_to_linear(component: float) -> float:
    if component <= 0.04045:
        return component / 12.92
    return ((component + 0.055) / 1.055) ** 2.4


def hex_to_linear_rgba(value: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    value = value.lstrip("#")
    if len(value) != 6:
        raise ValueError(f"Expected RRGGBB, got {value!r}")
    channels = [int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)]
    return tuple(srgb_to_linear(channel) for channel in channels) + (alpha,)


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
    hex_color: str,
    metallic: float,
    roughness: float,
    emission_hex: str | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    name = f"{MATERIAL_PREFIX}{suffix}"
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
    if bpy.app.version < (5, 0, 0):
        material.use_nodes = True
    color = hex_to_linear_rgba(hex_color)
    material.diffuse_color = color
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError(f"{name}: Principled BSDF node is missing")
    set_input_if_present(principled, ("Base Color",), color)
    set_input_if_present(principled, ("Metallic",), metallic)
    set_input_if_present(principled, ("Roughness",), roughness)
    set_input_if_present(principled, ("Specular IOR Level", "Specular"), 0.35)
    if emission_hex is not None:
        emission = hex_to_linear_rgba(emission_hex)
        set_input_if_present(principled, ("Emission Color", "Emission"), emission)
        set_input_if_present(principled, ("Emission Strength",), emission_strength)
    return material


def build_palette() -> dict[str, bpy.types.Material]:
    return {
        "limestone": make_material("Limestone", "D8C7A3", 0.0, 0.78),
        "marble": make_material("WarmMarble", "E7DDC8", 0.0, 0.48),
        "marble_dark": make_material("VeinedMarble", "9E9487", 0.0, 0.62),
        "terracotta": make_material("Terracotta", "A94F2B", 0.0, 0.76),
        "terracotta_light": make_material("SunTerracotta", "D97846", 0.0, 0.68),
        "bronze": make_material("AgedBronze", "8B5A25", 0.78, 0.34),
        "blue": make_material("AegeanBlue", "245D76", 0.0, 0.58),
        "olive_leaf": make_material("OliveLeaf", "52633A", 0.0, 0.82),
        "olive_dark": make_material("OliveDark", "2F3C24", 0.0, 0.88),
        "wood": make_material("OliveWood", "6E4324", 0.0, 0.83),
        "fabric": make_material("SaffronFabric", "C98232", 0.0, 0.92),
        "coal": make_material("WarmCoal", "211713", 0.0, 0.92, "E85D1C", 2.5),
        "water": make_material("CourtyardWater", "287E91", 0.08, 0.18),
        "collision": make_material("Collision", "FF331C", 0.0, 0.95),
        "preview_floor": make_material("PreviewFloor", "20242C", 0.08, 0.46),
    }


# -----------------------------------------------------------------------------
# Geometry helpers
# -----------------------------------------------------------------------------

def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.append(material)


def set_smooth(obj: bpy.types.Object, smooth: bool = True) -> None:
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = smooth


def set_smooth_sides(obj: bpy.types.Object) -> None:
    """Smooth low-sided walls while keeping n-gon caps visually crisp."""
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = len(polygon.vertices) <= 4


def add_bevel(
    obj: bpy.types.Object, width: float, segments: int = 1, angle_degrees: float = 28.0
) -> None:
    if width <= 0.0:
        return
    bevel = obj.modifiers.new(name="Bevel", type="BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(angle_degrees)
    if hasattr(bevel, "affect"):
        bevel.affect = "EDGES"
    apply_modifiers(obj)


def add_box(
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.0,
    bevel_segments: int = 1,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    obj.rotation_euler = rotation
    move_to_collection(obj, collection)
    assign_material(obj, material)
    apply_transform(obj)
    add_bevel(obj, bevel, bevel_segments)
    return obj


def add_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 16,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        end_fill_type="NGON",
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    assign_material(obj, material)
    set_smooth_sides(obj)
    apply_transform(obj)
    add_bevel(obj, bevel, 1)
    return obj


def add_cone(
    name: str,
    radius_bottom: float,
    radius_top: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 16,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        end_fill_type="NGON",
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    assign_material(obj, material)
    set_smooth_sides(obj)
    apply_transform(obj)
    add_bevel(obj, bevel, 1)
    return obj


def add_torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    major_segments: int = 16,
    minor_segments: int = 5,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
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
    assign_material(obj, material)
    set_smooth(obj)
    apply_transform(obj)
    return obj


def add_ico(
    name: str,
    radius: float,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    subdivisions: int = 1,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=subdivisions, radius=radius, location=location, rotation=rotation
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    move_to_collection(obj, collection)
    assign_material(obj, material)
    set_smooth(obj)
    apply_transform(obj)
    return obj


def create_mesh_object(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    collection: bpy.types.Collection,
    material: bpy.types.Material,
    smooth: bool = False,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=False)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    assign_material(obj, material)
    set_smooth(obj, smooth)
    return obj


def create_revolved_profile(
    name: str,
    profile: list[tuple[float, float]],
    segments: int,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    location_xy: tuple[float, float] = (0.0, 0.0),
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    for z, radius in profile:
        for index in range(segments):
            angle = math.tau * index / segments
            vertices.append(
                (
                    location_xy[0] + radius * math.cos(angle),
                    location_xy[1] + radius * math.sin(angle),
                    z,
                )
            )
    faces: list[tuple[int, ...]] = []
    rings = len(profile)
    faces.append(tuple(reversed(range(segments))))
    top_start = (rings - 1) * segments
    faces.append(tuple(top_start + index for index in range(segments)))
    for ring in range(rings - 1):
        lower = ring * segments
        upper = (ring + 1) * segments
        for index in range(segments):
            nxt = (index + 1) % segments
            faces.append((lower + index, lower + nxt, upper + nxt, upper + index))
    obj = create_mesh_object(name, vertices, faces, collection, material)
    set_smooth_sides(obj)
    return obj


def create_fluted_shaft(
    name: str,
    z_bottom: float,
    z_top: float,
    radius_bottom: float,
    radius_top: float,
    flutes: int,
    groove_depth: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    ring_count: int,
) -> bpy.types.Object:
    radial_segments = max(8, flutes * 2 if flutes > 0 else 10)
    vertices: list[tuple[float, float, float]] = []
    for ring in range(ring_count):
        ratio = ring / max(1, ring_count - 1)
        z = z_bottom + (z_top - z_bottom) * ratio
        radius = radius_bottom + (radius_top - radius_bottom) * ratio
        radius *= 1.0 + math.sin(ratio * math.pi) * 0.018
        for index in range(radial_segments):
            angle = math.tau * index / radial_segments
            local_radius = radius
            if flutes > 0 and index % 2 == 1:
                local_radius *= 1.0 - groove_depth
            vertices.append((local_radius * math.cos(angle), local_radius * math.sin(angle), z))
    faces: list[tuple[int, ...]] = [tuple(reversed(range(radial_segments)))]
    top_start = (ring_count - 1) * radial_segments
    faces.append(tuple(top_start + index for index in range(radial_segments)))
    for ring in range(ring_count - 1):
        lower = ring * radial_segments
        upper = (ring + 1) * radial_segments
        for index in range(radial_segments):
            nxt = (index + 1) % radial_segments
            faces.append((lower + index, lower + nxt, upper + nxt, upper + index))
    obj = create_mesh_object(name, vertices, faces, collection, material)
    set_smooth_sides(obj)
    return obj


def create_annular_cylinder(
    name: str,
    inner_radius: float,
    outer_radius: float,
    z_bottom: float,
    z_top: float,
    segments: int,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    for z in (z_bottom, z_top):
        for radius in (inner_radius, outer_radius):
            for index in range(segments):
                angle = math.tau * index / segments
                vertices.append((radius * math.cos(angle), radius * math.sin(angle), z))
    ib = 0
    ob = segments
    it = segments * 2
    ot = segments * 3
    faces: list[tuple[int, ...]] = []
    for index in range(segments):
        nxt = (index + 1) % segments
        faces.extend(
            [
                (ob + index, ob + nxt, ot + nxt, ot + index),
                (ib + nxt, ib + index, it + index, it + nxt),
                (ot + index, ot + nxt, it + nxt, it + index),
                (ob + nxt, ob + index, ib + index, ib + nxt),
            ]
        )
    return create_mesh_object(name, vertices, faces, collection, material, smooth=False)


def normalize_part_slots(
    parts: list[bpy.types.Object], materials: list[bpy.types.Material]
) -> None:
    slot_by_name = {material.name: index for index, material in enumerate(materials)}
    for part in parts:
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
    if not parts:
        raise RuntimeError(f"{final_name}: no mesh parts to join")
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
    remapped = [old_to_new.get(poly.material_index, 0) for poly in result.data.polygons]
    result.data.materials.clear()
    for material in unique:
        result.data.materials.append(material)
    for polygon, material_index in zip(result.data.polygons, remapped):
        polygon.material_index = material_index
    apply_transform(result)
    return result


def finalize_asset(
    parts: list[bpy.types.Object],
    asset_id: str,
    lod: int,
    materials: list[bpy.types.Material],
    family: str,
) -> bpy.types.Object:
    result = join_parts(parts, f"{asset_id}_LOD{lod}", materials)
    result["asset_id"] = asset_id
    result["asset_family"] = family
    result["lod"] = lod
    result["unit_scale_meters"] = 1.0
    result["forward_blender"] = "-Y"
    result["forward_godot"] = "-Z"
    return result


# -----------------------------------------------------------------------------
# Three Greek column orders
# -----------------------------------------------------------------------------

def build_doric_column(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    stone = mats["limestone"]
    accent = mats["marble_dark"]
    segments = (20, 14, 8)[lod]
    flutes = (16, 10, 0)[lod]
    rings = (6, 4, 2)[lod]
    bevel = (0.025, 0.018, 0.0)[lod]
    parts = [
        add_box("DoricPlinth", (1.08, 1.08, 0.16), (0.0, 0.0, 0.08), accent, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
        add_cylinder("DoricFoot", 0.48, 0.18, (0.0, 0.0, 0.25), stone, collection, segments, bevel=bevel),
        create_fluted_shaft("DoricShaft", 0.34, 3.35, 0.41, 0.34, flutes, 0.075, stone, collection, rings),
        add_cylinder("DoricNeck", 0.36, 0.13, (0.0, 0.0, 3.405), accent, collection, segments),
        add_cone("DoricEchinus", 0.50, 0.35, 0.28, (0.0, 0.0, 3.61), stone, collection, segments, bevel),
        add_box("DoricAbacus", (1.03, 1.03, 0.20), (0.0, 0.0, 3.83), stone, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
    ]
    if lod == 0:
        parts.append(add_box("DoricBlueDedication", (0.72, 1.045, 0.055), (0.0, 0.0, 3.83), mats["blue"], collection, bevel=0.008))
        materials = [stone, accent, mats["blue"]]
    else:
        materials = [stone, accent]
    return finalize_asset(parts, "column_doric_weathered", lod, materials, "greek_columns")


def build_ionic_column(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    marble = mats["marble"]
    blue = mats["blue"]
    segments = (24, 16, 8)[lod]
    flutes = (20, 12, 0)[lod]
    rings = (6, 4, 2)[lod]
    bevel = (0.022, 0.014, 0.0)[lod]
    parts = [
        add_box("IonicPlinth", (1.18, 1.18, 0.15), (0.0, 0.0, 0.075), marble, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
        add_cylinder("IonicBaseWide", 0.53, 0.17, (0.0, 0.0, 0.235), marble, collection, segments, bevel=bevel),
        add_torus("IonicBaseTorus", 0.41, 0.075, (0.0, 0.0, 0.38), blue, collection, segments, 5 if lod == 0 else 3),
        create_fluted_shaft("IonicShaft", 0.42, 3.72, 0.38, 0.31, flutes, 0.065, marble, collection, rings),
        add_box("IonicCushion", (1.05, 0.72, 0.20), (0.0, 0.0, 3.83), blue, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
        add_box("IonicAbacus", (1.24, 0.88, 0.16), (0.0, 0.0, 4.23), marble, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
    ]
    if lod < 2:
        major_segments = 18 if lod == 0 else 12
        minor_segments = 6 if lod == 0 else 4
        for x in (-0.39, 0.39):
            parts.append(
                add_torus(
                    "IonicVolute",
                    0.19,
                    0.055,
                    (x, -0.01, 4.02),
                    marble,
                    collection,
                    major_segments,
                    minor_segments,
                    (math.radians(90.0), 0.0, 0.0),
                )
            )
            if lod == 0:
                parts.append(add_cylinder("IonicRosette", 0.07, 0.78, (x, 0.0, 4.02), blue, collection, 12, (math.radians(90.0), 0.0, 0.0)))
    return finalize_asset(parts, "column_ionic_aegean", lod, [marble, blue], "greek_columns")


def build_corinthian_column(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    marble = mats["marble"]
    leaf_mat = mats["olive_leaf"]
    bronze = mats["bronze"]
    segments = (24, 16, 8)[lod]
    flutes = (20, 12, 0)[lod]
    rings = (7, 4, 2)[lod]
    bevel = (0.022, 0.014, 0.0)[lod]
    parts = [
        add_box("CorinthianPlinth", (1.24, 1.24, 0.16), (0.0, 0.0, 0.08), marble, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
        add_cylinder("CorinthianBase", 0.56, 0.22, (0.0, 0.0, 0.27), marble, collection, segments, bevel=bevel),
        add_torus("CorinthianBaseRing", 0.43, 0.07, (0.0, 0.0, 0.43), bronze, collection, segments, 5 if lod == 0 else 3),
        create_fluted_shaft("CorinthianShaft", 0.47, 4.05, 0.39, 0.31, flutes, 0.06, marble, collection, rings),
        add_cone("CorinthianBell", 0.52, 0.34, 0.55, (0.0, 0.0, 4.30), marble, collection, segments, bevel),
        add_box("CorinthianAbacus", (1.28, 1.28, 0.17), (0.0, 0.0, 4.65), marble, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
    ]
    if lod < 2:
        leaf_count = 12 if lod == 0 else 6
        for index in range(leaf_count):
            angle = math.tau * index / leaf_count
            radius = 0.41
            parts.append(
                add_ico(
                    "AcanthusLeaf",
                    1.0,
                    (radius * math.cos(angle), radius * math.sin(angle), 4.29),
                    (0.095, 0.045, 0.28) if lod == 0 else (0.12, 0.05, 0.24),
                    leaf_mat,
                    collection,
                    1,
                    (0.0, math.radians(15.0), angle),
                )
            )
        if lod == 0:
            for angle in (math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75):
                parts.append(
                    add_torus(
                        "CorinthianCornerCurl",
                        0.11,
                        0.035,
                        (0.43 * math.cos(angle), 0.43 * math.sin(angle), 4.52),
                        bronze,
                        collection,
                        12,
                        4,
                        (math.radians(90.0), 0.0, angle),
                    )
                )
    return finalize_asset(parts, "column_corinthian_garden", lod, [marble, leaf_mat, bronze], "greek_columns")


# -----------------------------------------------------------------------------
# Cosy courtyard decorations
# -----------------------------------------------------------------------------

def amphora_parts(
    prefix: str,
    x: float,
    y: float,
    scale: float,
    lod: int,
    collection: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
) -> list[bpy.types.Object]:
    segments = (18, 12, 8)[lod]
    z = 0.0
    profile = [
        (z + 0.03 * scale, 0.14 * scale),
        (z + 0.10 * scale, 0.22 * scale),
        (z + 0.30 * scale, 0.31 * scale),
        (z + 0.58 * scale, 0.27 * scale),
        (z + 0.75 * scale, 0.15 * scale),
        (z + 0.90 * scale, 0.12 * scale),
        (z + 0.96 * scale, 0.15 * scale),
    ]
    parts = [create_revolved_profile(f"{prefix}Body", profile, segments, mats["terracotta"], collection, (x, y))]
    parts.append(add_torus(f"{prefix}Rim", 0.14 * scale, 0.025 * scale, (x, y, 0.96 * scale), mats["terracotta_light"], collection, segments, 4 if lod == 0 else 3))
    if lod < 2:
        handle_segments = 14 if lod == 0 else 10
        for side in (-1.0, 1.0):
            parts.append(
                add_torus(
                    f"{prefix}Handle",
                    0.14 * scale,
                    0.025 * scale,
                    (x + side * 0.17 * scale, y, 0.77 * scale),
                    mats["terracotta_light"],
                    collection,
                    handle_segments,
                    4,
                    (math.radians(90.0), 0.0, 0.0),
                )
            )
    return parts


def build_amphora_cluster(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    parts = amphora_parts("TallAmphora", -0.28, 0.02, 1.0, lod, collection, mats)
    parts.extend(amphora_parts("SmallAmphora", 0.30, 0.12, 0.72, lod, collection, mats))
    if lod < 2:
        parts.append(add_cylinder("OfferingCup", 0.17, 0.08, (0.22, -0.28, 0.04), mats["blue"], collection, 14 if lod == 0 else 10, bevel=0.015))
    return finalize_asset(parts, "decor_amphora_cluster", lod, [mats["terracotta"], mats["terracotta_light"], mats["blue"]], "cosy_decor")


def build_olive_planter(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    segments = (18, 12, 8)[lod]
    profile = [(0.02, 0.30), (0.08, 0.38), (0.45, 0.33), (0.60, 0.42), (0.68, 0.45)]
    parts = [
        create_revolved_profile("OlivePlanterPot", profile, segments, mats["terracotta"], collection),
        add_torus("OlivePlanterRim", 0.42, 0.045, (0.0, 0.0, 0.67), mats["terracotta_light"], collection, segments, 4 if lod == 0 else 3),
        add_cylinder("OliveTrunk", 0.09, 1.15, (0.0, 0.0, 1.12), mats["wood"], collection, 10 if lod < 2 else 7),
    ]
    if lod < 2:
        for angle in (-0.55, 0.48, 1.9):
            parts.append(add_cylinder("OliveBranch", 0.045, 0.72, (0.10 * math.cos(angle), 0.10 * math.sin(angle), 1.63), mats["wood"], collection, 8, (math.radians(22.0) * math.sin(angle), math.radians(24.0) * math.cos(angle), angle)))
    cluster_count = (12, 6, 3)[lod]
    rng = random.Random(SEED + 31 + lod)
    for index in range(cluster_count):
        angle = math.tau * index / cluster_count + rng.uniform(-0.18, 0.18)
        radius = rng.uniform(0.18, 0.48) if lod < 2 else 0.25
        height = rng.uniform(1.55, 2.15) if lod < 2 else 1.72 + index * 0.16
        parts.append(
            add_ico(
                "OliveLeafCluster",
                1.0,
                (radius * math.cos(angle), radius * math.sin(angle), height),
                (0.32, 0.18, 0.16) if lod == 0 else (0.38, 0.22, 0.20),
                mats["olive_leaf"],
                collection,
                1,
                (rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), angle),
            )
        )
    return finalize_asset(parts, "decor_olive_planter", lod, [mats["terracotta"], mats["terracotta_light"], mats["wood"], mats["olive_leaf"]], "cosy_decor")


def build_courtyard_bench(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    bevel = (0.035, 0.02, 0.0)[lod]
    stone = mats["marble"]
    parts = [
        add_box("BenchSeat", (2.15, 0.68, 0.18), (0.0, 0.0, 0.72), stone, collection, bevel=bevel, bevel_segments=2 if lod == 0 else 1),
        add_box("BenchLegLeft", (0.24, 0.58, 0.68), (-0.78, 0.0, 0.34), mats["marble_dark"], collection, bevel=bevel),
        add_box("BenchLegRight", (0.24, 0.58, 0.68), (0.78, 0.0, 0.34), mats["marble_dark"], collection, bevel=bevel),
    ]
    if lod < 2:
        parts.append(add_box("BenchCushion", (1.78, 0.58, 0.11), (0.0, -0.015, 0.865), mats["fabric"], collection, bevel=0.05 if lod == 0 else 0.025, bevel_segments=2 if lod == 0 else 1))
        parts.append(add_box("BenchBack", (1.92, 0.13, 0.64), (0.0, 0.28, 1.12), stone, collection, rotation=(math.radians(-8.0), 0.0, 0.0), bevel=bevel, bevel_segments=2 if lod == 0 else 1))
    if lod == 0:
        for x in (-0.90, 0.90):
            parts.append(add_torus("BenchArmScroll", 0.16, 0.04, (x, 0.0, 0.94), mats["bronze"], collection, 14, 5, (math.radians(90.0), 0.0, 0.0)))
    return finalize_asset(parts, "decor_courtyard_bench", lod, [stone, mats["marble_dark"], mats["fabric"], mats["bronze"]], "cosy_decor")


def build_tripod_brazier(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    segments = (20, 14, 8)[lod]
    profile = [(0.82, 0.20), (0.90, 0.42), (1.02, 0.52), (1.14, 0.48), (1.20, 0.38)]
    parts = [create_revolved_profile("BrazierBowl", profile, segments, mats["bronze"], collection)]
    if lod < 2:
        parts.append(add_torus("BrazierRim", 0.48, 0.045, (0.0, 0.0, 1.17), mats["bronze"], collection, segments, 5 if lod == 0 else 3))
        for index in range(3):
            angle = math.tau * index / 3.0
            x = 0.30 * math.cos(angle)
            y = 0.30 * math.sin(angle)
            parts.append(add_cylinder("BrazierLeg", 0.045, 0.82, (x, y, 0.43), mats["bronze"], collection, 8, (math.radians(8.0) * math.sin(angle), -math.radians(8.0) * math.cos(angle), angle)))
            parts.append(add_ico("BrazierFoot", 1.0, (0.38 * math.cos(angle), 0.38 * math.sin(angle), 0.05), (0.10, 0.08, 0.06), mats["bronze"], collection, 1))
    else:
        parts.append(add_cylinder("BrazierStand", 0.11, 0.80, (0.0, 0.0, 0.42), mats["bronze"], collection, 8))
    coal_count = (7, 4, 1)[lod]
    for index in range(coal_count):
        angle = math.tau * index / max(1, coal_count)
        radius = 0.24 if coal_count > 1 else 0.0
        parts.append(add_ico("BrazierCoal", 1.0, (radius * math.cos(angle), radius * math.sin(angle), 1.14), (0.10, 0.08, 0.06), mats["coal"], collection, 1))
    return finalize_asset(parts, "decor_tripod_brazier", lod, [mats["bronze"], mats["coal"]], "cosy_decor")


def build_mosaic_roundel(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    segments = (32, 18, 10)[lod]
    parts = [
        add_cylinder("MosaicBase", 1.20, 0.035, (0.0, 0.0, 0.0175), mats["marble"], collection, segments),
        create_annular_cylinder("MosaicBlueRing", 0.72, 0.96, 0.036, 0.052, segments, mats["blue"], collection),
        create_annular_cylinder("MosaicTerracottaRing", 0.46, 0.68, 0.036, 0.054, segments, mats["terracotta"], collection),
        add_cylinder("MosaicCenter", 0.40, 0.020, (0.0, 0.0, 0.045), mats["marble_dark"], collection, segments),
    ]
    if lod == 0:
        for index in range(16):
            angle = math.tau * index / 16.0
            material = mats["terracotta"] if index % 2 else mats["marble"]
            parts.append(add_box("MosaicTile", (0.15, 0.32, 0.018), (1.075 * math.cos(angle), 1.075 * math.sin(angle), 0.052), material, collection, rotation=(0.0, 0.0, angle)))
    return finalize_asset(parts, "decor_mosaic_roundel", lod, [mats["marble"], mats["blue"], mats["terracotta"], mats["marble_dark"]], "cosy_decor")


def build_courtyard_fountain(
    lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]
) -> bpy.types.Object:
    segments = (24, 16, 8)[lod]
    bevel = (0.025, 0.015, 0.0)[lod]
    parts = [
        create_annular_cylinder("FountainBasin", 0.78, 1.22, 0.0, 0.42, segments, mats["limestone"], collection),
        add_cylinder("FountainWater", 0.77, 0.025, (0.0, 0.0, 0.33), mats["water"], collection, segments),
        add_cylinder("FountainPedestal", 0.20, 1.12, (0.0, 0.0, 0.88), mats["marble"], collection, segments, bevel=bevel),
    ]
    bowl_profile = [(1.32, 0.16), (1.36, 0.48), (1.48, 0.55), (1.56, 0.43)]
    parts.append(create_revolved_profile("FountainUpperBowl", bowl_profile, segments, mats["marble"], collection))
    if lod < 2:
        parts.append(add_torus("FountainBowlRim", 0.50, 0.045, (0.0, 0.0, 1.52), mats["bronze"], collection, segments, 5 if lod == 0 else 3))
        parts.append(add_cylinder("FountainSpout", 0.065, 0.46, (0.0, 0.0, 1.77), mats["bronze"], collection, 10))
        parts.append(add_ico("FountainFinial", 1.0, (0.0, 0.0, 2.04), (0.15, 0.15, 0.22), mats["bronze"], collection, 1))
    return finalize_asset(parts, "decor_courtyard_fountain", lod, [mats["limestone"], mats["marble"], mats["water"], mats["bronze"]], "cosy_decor")


# -----------------------------------------------------------------------------
# Collision proxies
# -----------------------------------------------------------------------------

def collision_column(
    collection: bpy.types.Collection, mats: dict[str, bpy.types.Material], height: float, radius: float, name: str
) -> bpy.types.Object:
    obj = add_cylinder(name, radius, height, (0.0, 0.0, height * 0.5), mats["collision"], collection, 10)
    obj["collision_kind"] = "coarse_cylinder"
    return obj


def collision_doric(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_column(collection, mats, 3.94, 0.54, "column_doric_weathered-col")


def collision_ionic(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_column(collection, mats, 4.31, 0.62, "column_ionic_aegean-col")


def collision_corinthian(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return collision_column(collection, mats, 4.74, 0.64, "column_corinthian_garden-col")


def collision_amphora(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    parts = [
        add_cylinder("TallAmphoraCollision", 0.32, 0.96, (-0.28, 0.02, 0.48), mats["collision"], collection, 8),
        add_cylinder("SmallAmphoraCollision", 0.24, 0.70, (0.30, 0.12, 0.35), mats["collision"], collection, 8),
    ]
    return join_parts(parts, "decor_amphora_cluster-col", [mats["collision"]])


def collision_planter(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return add_cylinder("decor_olive_planter-col", 0.46, 0.72, (0.0, 0.0, 0.36), mats["collision"], collection, 10)


def collision_bench(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return add_box("decor_courtyard_bench-col", (2.20, 0.72, 1.44), (0.0, 0.0, 0.72), mats["collision"], collection)


def collision_brazier(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return add_cylinder("decor_tripod_brazier-col", 0.54, 1.22, (0.0, 0.0, 0.61), mats["collision"], collection, 10)


def collision_none(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    return None


def collision_fountain(collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    return add_cylinder("decor_courtyard_fountain-col", 1.24, 1.58, (0.0, 0.0, 0.79), mats["collision"], collection, 12)


# -----------------------------------------------------------------------------
# Validation and package output
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


def validate_mesh(
    obj: bpy.types.Object,
    label: str,
    triangle_budget: int,
) -> dict[str, object]:
    if obj.type != "MESH":
        raise RuntimeError(f"{label}: expected MESH, got {obj.type}")
    if obj.location.length > 1e-6:
        raise RuntimeError(f"{label}: object location must be zero, got {tuple(obj.location)}")
    if any(abs(value - 1.0) > 1e-6 for value in obj.scale):
        raise RuntimeError(f"{label}: unapplied scale {tuple(obj.scale)}")
    if any(abs(value) > 1e-6 for value in obj.rotation_euler):
        raise RuntimeError(f"{label}: unapplied rotation {tuple(obj.rotation_euler)}")
    if len(obj.data.materials) > MAX_MATERIALS_PER_ASSET:
        raise RuntimeError(f"{label}: too many materials ({len(obj.data.materials)})")
    triangles = triangle_count(obj)
    if triangles > triangle_budget:
        raise RuntimeError(f"{label}: {triangles} tris exceeds budget {triangle_budget}")
    non_manifold = non_manifold_edge_count(obj)
    if REQUIRE_CLOSED_MESH and non_manifold:
        raise RuntimeError(f"{label}: {non_manifold} non-manifold/boundary edges")
    evidence = {
        "triangles": triangles,
        "materials": len(obj.data.materials),
        "dimensions_m": [round(float(value), 4) for value in obj.dimensions],
        "non_manifold_edges": non_manifold,
        "uv_layers": len(obj.data.uv_layers),
    }
    print(f"[COSY GREEK] {label}: PASS {evidence}")
    return evidence


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


def write_manifest(
    spec: AssetSpec,
    evidence: dict[str, dict[str, object]],
    asset_dir: Path,
) -> Path:
    manifest = {
        "asset": spec.asset_id,
        "status": "PASS",
        "quality": "V2_HERO",
        "family": spec.family,
        "units": "meters",
        "dimensions_m": evidence["LOD0"]["dimensions_m"],
        "forward_blender": "-Y",
        "forward_godot": "-Z",
        "triangles_lod0": evidence["LOD0"]["triangles"],
        "triangles_lod1": evidence["LOD1"]["triangles"],
        "triangles_lod2": evidence["LOD2"]["triangles"],
        "collision": spec.collision_description,
        "forge_collision_enabled": spec.forge_collision_enabled,
        "forge_collision_shape": spec.forge_collision_shape,
        "origin": "center of base",
        "identity": spec.identity,
        "material_strategy": "shared flat PBR palette",
        "textures_packed": True,
        "seed": SEED,
    }
    if "collision" in evidence:
        manifest["triangles_collision"] = evidence["collision"]["triangles"]
    path = asset_dir / "asset_manifest.json"
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return path


# -----------------------------------------------------------------------------
# Combined collection preview
# -----------------------------------------------------------------------------

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
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    collection.objects.link(light)
    light.location = location
    point_at(light, target)


def setup_preview(
    lod0_objects: list[bpy.types.Object],
    collection: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUTPUT_DIR / "cosy_greek_collection_preview.png")
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
    background.inputs["Color"].default_value = hex_to_linear_rgba("111923")
    background.inputs["Strength"].default_value = 0.18
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = -0.35

    positions = [
        (-4.1, 2.4, 0.0),
        (0.0, 2.4, 0.0),
        (4.1, 2.4, 0.0),
        (-4.2, -1.4, 0.0),
        (-2.1, -1.4, 0.0),
        (0.4, -1.4, 0.0),
        (2.8, -1.4, 0.0),
        (4.8, -1.3, 0.0),
        (1.5, -4.3, 0.0),
    ]
    for obj, position in zip(lod0_objects, positions):
        display = obj.copy()
        display.data = obj.data
        display.name = f"PREVIEW_{obj.name}"
        collection.objects.link(display)
        display.location = position
        display.rotation_euler.z = math.radians(10.0 if position[0] <= 0.0 else -10.0)

    floor = add_box(
        "PREVIEW_CourtyardFloor",
        (15.5, 12.5, 0.08),
        (0.0, 0.0, -0.055),
        mats["preview_floor"],
        collection,
        bevel=0.025,
    )
    floor.hide_select = True

    target = (0.0, 0.2, 2.1)
    add_area_light("LGT_SkyKey", (-7.0, -8.0, 11.0), 1450.0, (0.72, 0.84, 1.0), 5.0, target, collection)
    add_area_light("LGT_SunsetRim", (7.5, 3.0, 7.0), 1850.0, (1.0, 0.32, 0.08), 4.0, target, collection)
    add_area_light("LGT_CourtyardFill", (0.0, -2.0, 4.0), 620.0, (0.34, 0.48, 1.0), 5.5, target, collection)

    camera_data = bpy.data.cameras.new("CAM_CosyGreekCollection")
    camera = bpy.data.objects.new("CAM_CosyGreekCollection", camera_data)
    collection.objects.link(camera)
    camera.location = (12.8, -18.5, 10.2)
    camera_data.lens = 52.0
    point_at(camera, target)
    scene.camera = camera


def render_preview_isolated(collection: bpy.types.Collection) -> None:
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


def render_asset_thumbnails(
    lod0_objects: list[bpy.types.Object],
    collection: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
) -> None:
    """Render one square, Forge-ready thumbnail per public LOD0 asset."""
    scene = bpy.context.scene
    thumbnail_dir = OUTPUT_DIR / "thumbnails"
    thumbnail_dir.mkdir(parents=True, exist_ok=True)
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100

    floor = add_box(
        "THUMB_CourtyardFloor",
        (8.0, 8.0, 0.08),
        (0.0, 0.0, -0.055),
        mats["preview_floor"],
        collection,
        bevel=0.025,
    )
    floor.hide_select = True
    add_area_light("THUMB_Key", (-4.5, -5.5, 7.5), 1050.0, (0.72, 0.84, 1.0), 4.0, (0.0, 0.0, 1.4), collection)
    add_area_light("THUMB_Rim", (5.0, 2.5, 6.0), 1350.0, (1.0, 0.34, 0.10), 3.5, (0.0, 0.0, 1.4), collection)
    add_area_light("THUMB_Fill", (0.0, -2.0, 3.5), 430.0, (0.35, 0.52, 1.0), 4.0, (0.0, 0.0, 1.2), collection)

    camera_data = bpy.data.cameras.new("CAM_CosyGreekThumbnail")
    camera = bpy.data.objects.new("CAM_CosyGreekThumbnail", camera_data)
    collection.objects.link(camera)
    camera_data.lens = 55.0
    scene.camera = camera

    for source in lod0_objects:
        display = source.copy()
        display.data = source.data
        display.name = f"THUMB_{source.name}"
        collection.objects.link(display)
        display.rotation_euler.z = math.radians(-18.0)

        width = max(float(source.dimensions.x), float(source.dimensions.y), 0.25)
        height = max(float(source.dimensions.z), 0.12)
        framing_extent = max(width, height)
        distance = max(2.4, framing_extent * 1.72)
        target = (0.0, 0.0, height * 0.48)
        camera.location = (distance * 0.78, -distance * 1.08, target[2] + distance * 0.54)
        point_at(camera, target)

        asset_id = str(source.get("asset_id", source.name.removesuffix("_LOD0")))
        scene.render.filepath = str(thumbnail_dir / f"{asset_id}.png")
        render_preview_isolated(collection)
        bpy.data.objects.remove(display, do_unlink=True)


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def asset_specs() -> list[AssetSpec]:
    return [
        AssetSpec("column_doric_weathered", "greek_columns", "sturdy fluted Doric column with broad echinus, weathered warm stone and a restrained Aegean dedication band", "single coarse cylinder covering shaft and capital", True, "cylinder", (3500, 1800, 500, 80), build_doric_column, collision_doric),
        AssetSpec("column_ionic_aegean", "greek_columns", "slender Ionic column with readable twin volutes, layered circular base and blue Aegean capital accents", "single coarse cylinder covering shaft and volutes", True, "cylinder", (5000, 2400, 600, 80), build_ionic_column, collision_ionic),
        AssetSpec("column_corinthian_garden", "greek_columns", "garden Corinthian column with simplified acanthus crown, bronze curls and elegant tapered shaft", "single coarse cylinder covering shaft and leaf capital", True, "cylinder", (6500, 2800, 700, 80), build_corinthian_column, collision_corinthian),
        AssetSpec("decor_amphora_cluster", "cosy_decor", "asymmetric pair of sun-warmed amphorae with loop handles and a small Aegean offering cup", "two simple cylinder proxies matching the amphora bodies", False, "cylinder", (2800, 1300, 500, 80), build_amphora_cluster, collision_amphora),
        AssetSpec("decor_olive_planter", "cosy_decor", "terracotta courtyard planter holding a compact windswept olive tree with clustered silver-green foliage", "planter-only cylinder so the light canopy never blocks movement", False, "cylinder", (2600, 1300, 500, 40), build_olive_planter, collision_planter),
        AssetSpec("decor_courtyard_bench", "cosy_decor", "low marble courtyard bench with warm saffron cushion, sloped back and small bronze scroll arms", "single crowd-safe box covering the bench", True, "box", (2200, 900, 200, 20), build_courtyard_bench, collision_bench),
        AssetSpec("decor_tripod_brazier", "cosy_decor", "aged-bronze tripod brazier with broad ceremonial bowl and gently emissive coals", "single coarse cylinder covering legs and bowl", True, "cylinder", (2600, 1200, 400, 40), build_tripod_brazier, collision_brazier),
        AssetSpec("decor_mosaic_roundel", "cosy_decor", "flush courtyard mosaic roundel with concentric marble, terracotta and Aegean-blue geometry", "none; flush decorative ground element", False, "box", (3000, 1200, 500, 0), build_mosaic_roundel, collision_none),
        AssetSpec("decor_courtyard_fountain", "cosy_decor", "small welcoming courtyard fountain with annular limestone basin, warm bronze trim, still water and bronze finial", "single coarse cylinder; fountain is treated as a solid obstacle", True, "cylinder", (3200, 1600, 600, 80), build_courtyard_fountain, collision_fountain),
    ]


def main() -> None:
    if bpy.app.version < MIN_BLENDER:
        raise RuntimeError(f"Blender {MIN_BLENDER} or newer required; found {bpy.app.version}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    clear_previous_generation()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene.unit_settings.scale_length = 1.0
    mats = build_palette()

    root = new_collection(ROOT_COLLECTION)
    exports_root = new_collection("EXPORTS", root)
    collisions_root = new_collection("COLLISIONS", root)
    preview_collection = new_collection("PREVIEW_ONLY", root)

    all_lod0: list[bpy.types.Object] = []
    library_summary: list[dict[str, object]] = []
    for spec in asset_specs():
        asset_dir = OUTPUT_DIR / spec.family / spec.asset_id
        asset_dir.mkdir(parents=True, exist_ok=True)
        asset_collection = new_collection(f"EXPORT_{spec.asset_id}", exports_root)
        collision_collection = new_collection(f"COLLISION_{spec.asset_id}", collisions_root)
        evidence: dict[str, dict[str, object]] = {}
        objects: list[bpy.types.Object] = []
        for lod in range(3):
            obj = spec.builder(lod, asset_collection, mats)
            objects.append(obj)
            evidence[f"LOD{lod}"] = validate_mesh(obj, f"{spec.asset_id}/LOD{lod}", spec.budgets[lod])
            if EXPORT_GLB:
                export_object(obj, asset_dir / f"{spec.asset_id}_LOD{lod}.glb")
        collision = spec.collision_builder(collision_collection, mats)
        if collision is not None:
            evidence["collision"] = validate_mesh(collision, f"{spec.asset_id}/collision", spec.budgets[3])
            if EXPORT_GLB:
                export_object(collision, asset_dir / f"{spec.asset_id}_collision.glb")
        manifest_path = write_manifest(spec, evidence, asset_dir)
        all_lod0.append(objects[0])
        library_summary.append(
            {
                "asset": spec.asset_id,
                "family": spec.family,
                "triangles_lod0": evidence["LOD0"]["triangles"],
                "materials": evidence["LOD0"]["materials"],
                "manifest": str(manifest_path.relative_to(OUTPUT_DIR)),
            }
        )

    summary_path = OUTPUT_DIR / "library_manifest.json"
    summary_path.write_text(
        json.dumps(
            {
                "collection": "cosy_greek_collection",
                "status": "PASS",
                "asset_count": len(library_summary),
                "seed": SEED,
                "assets": library_summary,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    if RENDER_PREVIEW:
        setup_preview(all_lod0, preview_collection, mats)
        render_preview_isolated(preview_collection)
        thumbnail_collection = new_collection("THUMBNAIL_ONLY", root)
        render_asset_thumbnails(all_lod0, thumbnail_collection, mats)
    if SAVE_BLEND:
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / "cosy_greek_collection.blend"))

    print(f"[COSY GREEK] Blender: {bpy.app.version_string}")
    print(f"[COSY GREEK] Seed: {SEED}")
    print(f"[COSY GREEK] Assets: {len(library_summary)}")
    print(f"[COSY GREEK] Library manifest: {summary_path}")
    print(f"[COSY GREEK] PASS: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
