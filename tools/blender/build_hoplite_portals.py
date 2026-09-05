"""Generate three monumental, game-ready Hoplite portals.

The set contains one portal for the world editor, one for player-authored
worlds, and one ominous portal for official campaigns.  Every asset is a
single draw-friendly mesh per LOD, keeps the same playable opening, ships an
authored frame-only collision mesh, and exports Godot-ready GLB files.

Run from Blender's Text Editor or with:
    blender --background --python build_hoplite_portals.py
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


SEED = 260827
MIN_BLENDER = (4, 3, 0)
ROOT_COLLECTION = "GEN_HoplitePortals"
MATERIAL_PREFIX = "MAT_HoplitePortal_"
OUTPUT_FOLDER_NAME = "hoplite_portals_output"
MAX_MATERIALS_PER_ASSET = 4


@dataclass(frozen=True)
class PortalSpec:
    asset_id: str
    role: str
    identity: str
    builder: Callable[[int, bpy.types.Collection, dict[str, bpy.types.Material]], bpy.types.Object]
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


def srgb_to_linear(component: float) -> float:
    if component <= 0.04045:
        return component / 12.92
    return ((component + 0.055) / 1.055) ** 2.4


def hex_to_linear_rgba(value: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    value = value.lstrip("#")
    channels = [int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)]
    return tuple(srgb_to_linear(channel) for channel in channels) + (alpha,)


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
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError(f"{material.name}: missing Principled BSDF")
    rgba = hex_to_linear_rgba(color)
    material.diffuse_color = rgba
    set_input(principled, ("Base Color",), rgba)
    set_input(principled, ("Metallic",), metallic)
    set_input(principled, ("Roughness",), roughness)
    set_input(principled, ("Specular IOR Level", "Specular"), 0.38)
    if emission is not None:
        set_input(principled, ("Emission Color", "Emission"), hex_to_linear_rgba(emission))
        set_input(principled, ("Emission Strength",), emission_strength)
    return material


def build_palette() -> dict[str, bpy.types.Material]:
    return {
        "forge_stone": make_material("ForgeIvory", "D5C7A9", 0.0, 0.52),
        "forge_bronze": make_material("ForgeBronze", "9A6428", 0.82, 0.28),
        "forge_dark": make_material("ForgeCharcoal", "24282D", 0.55, 0.38),
        "forge_energy": make_material("ForgeEnergy", "123C44", 0.12, 0.22, "32F0DC", 5.0),
        "world_stone": make_material("WorldSlate", "40505B", 0.08, 0.68),
        "world_bronze": make_material("WorldAmber", "A76B25", 0.72, 0.33),
        "world_dark": make_material("WorldInk", "17232C", 0.28, 0.44),
        "world_energy": make_material("WorldEnergy", "102C50", 0.08, 0.20, "40AFFF", 4.7),
        "campaign_stone": make_material("CampaignObsidian", "17141C", 0.18, 0.38),
        "campaign_metal": make_material("CampaignBlackBronze", "3A2528", 0.82, 0.30),
        "campaign_bone": make_material("CampaignAsh", "938879", 0.0, 0.74),
        "campaign_energy": make_material("CampaignEnergy", "250B27", 0.10, 0.22, "CB184F", 5.5),
        "collision": make_material("Collision", "FF2A1F", 0.0, 0.94),
        "preview_floor": make_material("PreviewFloor", "11151D", 0.05, 0.48),
    }


def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.append(material)


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 1) -> None:
    if width <= 0.0:
        return
    modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(25.0)
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


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
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    move_to_collection(obj, collection)
    apply_transform(obj)
    apply_bevel(obj, bevel, bevel_segments)
    return assign_and_return(obj, material)


def assign_and_return(obj: bpy.types.Object, material: bpy.types.Material) -> bpy.types.Object:
    assign_material(obj, material)
    return obj


def add_cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 12,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    apply_transform(obj)
    apply_bevel(obj, bevel)
    return assign_and_return(obj, material)


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
    return assign_and_return(obj, material)


def add_ico(
    name: str,
    radius: float,
    scale: tuple[float, float, float],
    location: tuple[float, float, float],
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
    return assign_and_return(obj, material)


def add_torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    location: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    major_segments: int = 16,
    minor_segments: int = 6,
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
    return assign_and_return(obj, material)


def create_mesh_object(
    name: str,
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return assign_and_return(obj, material)


def extrude_xz_polygon(
    name: str,
    outline: list[tuple[float, float]],
    depth: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    y_offset: float = 0.0,
) -> bpy.types.Object:
    half = depth * 0.5
    count = len(outline)
    vertices = [(x, y_offset - half, z) for x, z in outline] + [(x, y_offset + half, z) for x, z in outline]
    faces: list[tuple[int, ...]] = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    return create_mesh_object(name, vertices, faces, material, collection)


def create_arch_ring(
    name: str,
    inner_radius: float,
    thickness: float,
    spring_z: float,
    depth: float,
    segments: int,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    outer_radius = inner_radius + thickness
    for index in range(segments):
        a0 = math.pi * index / segments
        a1 = math.pi * (index + 1) / segments
        points = [
            (inner_radius * math.cos(a0), spring_z + inner_radius * math.sin(a0)),
            (outer_radius * math.cos(a0), spring_z + outer_radius * math.sin(a0)),
            (outer_radius * math.cos(a1), spring_z + outer_radius * math.sin(a1)),
            (inner_radius * math.cos(a1), spring_z + inner_radius * math.sin(a1)),
        ]
        base = len(vertices)
        vertices.extend([(x, -depth * 0.5, z) for x, z in points])
        vertices.extend([(x, depth * 0.5, z) for x, z in points])
        faces.extend([
            (base + 3, base + 2, base + 1, base),
            (base + 4, base + 5, base + 6, base + 7),
            (base, base + 1, base + 5, base + 4),
            (base + 1, base + 2, base + 6, base + 5),
            (base + 2, base + 3, base + 7, base + 6),
            (base + 3, base, base + 4, base + 7),
        ])
    return create_mesh_object(name, vertices, faces, material, collection)


def add_beam_between(
    name: str,
    start: tuple[float, float],
    end: tuple[float, float],
    depth: float,
    width: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    bevel: float = 0.0,
) -> bpy.types.Object:
    x0, z0 = start
    x1, z1 = end
    dx = x1 - x0
    dz = z1 - z0
    length = math.hypot(dx, dz)
    angle = -math.atan2(dz, dx)
    return add_box(
        name,
        (length, depth, width),
        ((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5),
        material,
        collection,
        rotation=(0.0, angle, 0.0),
        bevel=bevel,
    )


def normalize_part_slots(parts: list[bpy.types.Object], materials: list[bpy.types.Material]) -> None:
    slot_by_name = {material.name: index for index, material in enumerate(materials)}
    for part in parts:
        intended = part.data.materials[0]
        intended_index = slot_by_name[intended.name]
        part.data.materials.clear()
        for material in materials:
            part.data.materials.append(material)
        for polygon in part.data.polygons:
            polygon.material_index = intended_index


def join_parts(parts: list[bpy.types.Object], name: str, materials: list[bpy.types.Material]) -> bpy.types.Object:
    if not parts:
        raise RuntimeError(f"{name}: no parts")
    normalize_part_slots(parts, materials)
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


def finish_portal(
    parts: list[bpy.types.Object],
    asset_id: str,
    role: str,
    lod: int,
    materials: list[bpy.types.Material],
) -> bpy.types.Object:
    result = join_parts(parts, f"{asset_id}_LOD{lod}", materials)
    result["asset_id"] = asset_id
    result["asset_family"] = "portals"
    result["portal_role"] = role
    result["lod"] = lod
    result["opening_width_m"] = 3.4
    result["opening_height_m"] = 3.25
    result["unit_scale_meters"] = 1.0
    result["forward_blender"] = "-Y"
    result["forward_godot"] = "-Z"
    return result


def build_forge_portal(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    stone, bronze, dark, energy = mats["forge_stone"], mats["forge_bronze"], mats["forge_dark"], mats["forge_energy"]
    bevel = (0.055, 0.035, 0.015)[lod]
    parts: list[bpy.types.Object] = []
    parts.append(extrude_xz_polygon("ForgeEnergy", [(-1.64, 0.14), (1.64, 0.14), (1.64, 3.15), (1.42, 3.75), (0.84, 4.18), (0.0, 4.34), (-0.84, 4.18), (-1.42, 3.75), (-1.64, 3.15)], 0.10, energy, collection, 0.15))
    for side in (-1.0, 1.0):
        x = side * 2.02
        parts.extend([
            add_box("ForgeFoot", (1.18, 1.12, 0.24), (x, 0.0, 0.12), dark, collection, bevel=bevel),
            add_box("ForgePlinth", (0.96, 0.94, 0.30), (x, 0.0, 0.39), bronze, collection, bevel=bevel),
            add_cone("ForgePylon", 0.48, 0.38, 3.20, (x, 0.0, 2.12), stone, collection, 8 if lod < 2 else 4, rotation=(0.0, 0.0, math.pi / 8.0)),
            add_box("ForgeCapital", (1.08, 1.0, 0.28), (x, 0.0, 3.77), bronze, collection, bevel=bevel),
        ])
        if lod < 2:
            parts.append(add_box("ForgeInset", (0.12, 0.96, 2.25), (side * 1.985, -0.02, 2.18), energy, collection, bevel=0.018))
    parts.append(create_arch_ring("ForgeArch", 1.68, 0.52, 3.05, 0.98, (12, 8, 5)[lod], stone, collection))
    parts.append(create_arch_ring("ForgeBronzeArch", 1.63, 0.12, 3.05, 1.03, (14, 10, 6)[lod], bronze, collection))
    parts.append(add_box("ForgeCrownBlock", (1.22, 0.88, 0.54), (0.0, 0.0, 5.06), dark, collection, rotation=(0.0, 0.0, math.radians(45.0)), bevel=bevel))
    # Keep the heroic crown height stable in every LOD so distance switching
    # never produces a visible silhouette pop.
    parts.append(add_box("ForgeCrownFinial", (0.12, 0.48, 0.96), (0.0, 0.0, 5.37), bronze, collection, bevel=0.012 if lod < 2 else 0.0))
    parts.append(add_ico("ForgeCrownGem", 0.30, (1.0, 0.55, 1.0), (0.0, -0.48, 5.06), energy, collection, 2 if lod == 0 else 1))
    if lod < 2:
        parts.append(add_torus("ForgeMechanism", 0.47, 0.095, (0.0, -0.43, 5.06), bronze, collection, 20 if lod == 0 else 12, 6 if lod == 0 else 4))
        spoke_count = 8 if lod == 0 else 4
        for index in range(spoke_count):
            angle = math.tau * index / spoke_count
            parts.append(add_box("ForgeRay", (0.42, 0.10, 0.10), (0.58 * math.cos(angle), -0.47, 5.06 + 0.58 * math.sin(angle)), bronze, collection, rotation=(0.0, -angle, 0.0), bevel=0.015))
    if lod == 0:
        for side in (-1.0, 1.0):
            for level in (1.02, 1.74, 2.46):
                parts.append(add_box("ForgeRivet", (0.18, 1.03, 0.18), (side * 2.02, 0.0, level), bronze, collection, rotation=(0.0, 0.0, math.radians(45.0)), bevel=0.012))
    return finish_portal(parts, "portal_world_forge", "world_editor", lod, [stone, bronze, dark, energy])


def build_saved_world_portal(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    stone, bronze, dark, energy = mats["world_stone"], mats["world_bronze"], mats["world_dark"], mats["world_energy"]
    bevel = (0.045, 0.025, 0.01)[lod]
    parts: list[bpy.types.Object] = []
    parts.append(extrude_xz_polygon("WorldEnergy", [(-1.63, 0.14), (1.63, 0.14), (1.63, 3.20), (1.05, 3.92), (0.0, 4.32), (-1.05, 3.92), (-1.63, 3.20)], 0.10, energy, collection, 0.17))
    for side in (-1.0, 1.0):
        x = side * 2.03
        lean = side * math.radians(2.5)
        parts.extend([
            add_box("WorldFoot", (1.30, 1.18, 0.24), (x, 0.0, 0.12), dark, collection, rotation=(0.0, lean, 0.0), bevel=bevel),
            add_box("WorldMonolith", (0.70, 0.86, 3.50), (x, 0.0, 1.98), stone, collection, rotation=(0.0, lean, side * math.radians(1.8)), bevel=bevel),
            add_box("WorldGlyphLine", (0.10, 0.91, 2.50), (side * 1.985, -0.02, 2.02), energy, collection, rotation=(0.0, lean, 0.0), bevel=0.012),
            add_box("WorldAmberCap", (0.92, 0.96, 0.22), (side * 1.96, 0.0, 3.75), bronze, collection, rotation=(0.0, lean, side * math.radians(4.0)), bevel=bevel),
        ])
    arch_points = [(-1.72, 3.45), (-1.04, 4.14), (0.0, 4.55), (1.04, 4.14), (1.72, 3.45)]
    for index in range(len(arch_points) - 1):
        parts.append(add_beam_between("WorldArchiveArch", arch_points[index], arch_points[index + 1], 0.94, 0.48, stone, collection, bevel))
    inner_points = [(-1.62, 3.34), (-1.00, 3.92), (0.0, 4.30), (1.00, 3.92), (1.62, 3.34)]
    for index in range(len(inner_points) - 1):
        parts.append(add_beam_between("WorldAmberRoute", inner_points[index], inner_points[index + 1], 1.0, 0.10, bronze, collection, 0.012))
    parts.append(add_torus("WorldCompass", 0.43, 0.075, (0.0, -0.51, 4.82), bronze, collection, 18 if lod == 0 else 12, 5 if lod < 2 else 4))
    parts.append(add_ico("WorldCompassCore", 0.24, (1.0, 0.5, 1.0), (0.0, -0.52, 4.82), energy, collection, 1))
    if lod < 2:
        tablet_count = 6 if lod == 0 else 3
        for index in range(tablet_count):
            side = -1.0 if index % 2 == 0 else 1.0
            tier = index // 2
            x = side * (2.67 + 0.12 * tier)
            z = 1.0 + tier * 1.02
            parts.append(add_box("WorldMemoryTablet", (0.50, 0.20, 0.68), (x, 0.10, z), stone, collection, rotation=(0.0, side * math.radians(13.0), side * math.radians(7.0)), bevel=0.04))
            parts.append(add_box("WorldMemoryMark", (0.26, 0.215, 0.08), (x, -0.01, z), bronze, collection, rotation=(0.0, side * math.radians(13.0), side * math.radians(7.0)), bevel=0.01))
    if lod == 0:
        for angle in (0.0, math.pi / 2.0, math.pi, math.pi * 1.5):
            parts.append(add_box("WorldCompassNeedle", (0.38, 0.10, 0.075), (0.27 * math.cos(angle), -0.56, 4.82 + 0.27 * math.sin(angle)), bronze, collection, rotation=(0.0, -angle, 0.0), bevel=0.01))
    return finish_portal(parts, "portal_saved_world", "saved_world", lod, [stone, bronze, dark, energy])


def build_campaign_portal(lod: int, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    stone, metal, ash, energy = mats["campaign_stone"], mats["campaign_metal"], mats["campaign_bone"], mats["campaign_energy"]
    bevel = (0.045, 0.025, 0.01)[lod]
    parts: list[bpy.types.Object] = []
    parts.append(extrude_xz_polygon("CampaignVoid", [(-1.62, 0.12), (1.62, 0.12), (1.62, 3.20), (0.0, 4.70), (-1.62, 3.20)], 0.12, energy, collection, 0.18))
    for side in (-1.0, 1.0):
        x = side * 2.08
        lean = side * math.radians(3.0)
        parts.extend([
            add_box("CampaignFoot", (1.42, 1.28, 0.30), (x, 0.0, 0.15), metal, collection, bevel=bevel),
            add_box("CampaignTombPillar", (0.82, 1.02, 3.85), (x, 0.0, 2.08), stone, collection, rotation=(0.0, lean, 0.0), bevel=bevel),
            add_box("CampaignRib", (0.13, 1.08, 2.92), (side * 2.005, -0.01, 2.14), metal, collection, rotation=(0.0, lean, 0.0), bevel=0.014),
            add_cone("CampaignGroundSpike", 0.25, 0.02, 1.18, (side * 2.78, 0.0, 0.73), metal, collection, 7 if lod < 2 else 5, rotation=(0.0, side * math.radians(18.0), 0.0)),
        ])
    parts.append(add_beam_between("CampaignLeftArch", (-1.78, 3.48), (0.0, 5.15), 1.08, 0.62, stone, collection, bevel))
    parts.append(add_beam_between("CampaignRightArch", (0.0, 5.15), (1.78, 3.48), 1.08, 0.62, stone, collection, bevel))
    parts.append(add_beam_between("CampaignLeftVein", (-1.64, 3.34), (0.0, 4.90), 1.14, 0.12, energy, collection, 0.012))
    parts.append(add_beam_between("CampaignRightVein", (0.0, 4.90), (1.64, 3.34), 1.14, 0.12, energy, collection, 0.012))
    parts.append(add_ico("CampaignHelm", 0.48, (0.82, 0.55, 1.08), (0.0, -0.55, 5.42), ash, collection, 2 if lod == 0 else 1))
    parts.append(add_box("CampaignHelmNasal", (0.13, 0.24, 0.62), (0.0, -0.76, 5.18), metal, collection, bevel=0.02))
    parts.append(add_box("CampaignEyeLeft", (0.20, 0.10, 0.10), (-0.20, -0.81, 5.42), energy, collection, rotation=(0.0, 0.0, math.radians(-10.0)), bevel=0.01))
    parts.append(add_box("CampaignEyeRight", (0.20, 0.10, 0.10), (0.20, -0.81, 5.42), energy, collection, rotation=(0.0, 0.0, math.radians(10.0)), bevel=0.01))
    if lod < 2:
        parts.append(add_cone("CampaignHornLeft", 0.22, 0.01, 1.05, (-0.56, -0.38, 5.73), metal, collection, 7, rotation=(0.0, math.radians(-52.0), 0.0)))
        parts.append(add_cone("CampaignHornRight", 0.22, 0.01, 1.05, (0.56, -0.38, 5.73), metal, collection, 7, rotation=(0.0, math.radians(52.0), 0.0)))
        spike_count = 6 if lod == 0 else 4
        for index in range(spike_count):
            side = -1.0 if index % 2 == 0 else 1.0
            tier = index // 2
            parts.append(add_cone("CampaignArchSpike", 0.16, 0.01, 0.72, (side * (1.70 - tier * 0.42), 0.06, 4.02 + tier * 0.45), metal, collection, 6, rotation=(0.0, side * math.radians(38.0), 0.0)))
    if lod == 0:
        for side in (-1.0, 1.0):
            for z in (1.15, 1.95, 2.75):
                parts.append(add_torus("CampaignChain", 0.16, 0.035, (side * 2.50, -0.10, z), metal, collection, 10, 4, rotation=(math.pi / 2.0, side * math.radians(18.0), 0.0)))
    return finish_portal(parts, "portal_official_campaign", "official_campaign", lod, [stone, metal, ash, energy])


def build_collision(asset_id: str, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    parts = [
        add_box("CollisionLeft", (0.90, 1.15, 4.05), (-2.15, 0.0, 2.025), mats["collision"], collection),
        add_box("CollisionRight", (0.90, 1.15, 4.05), (2.15, 0.0, 2.025), mats["collision"], collection),
        add_box("CollisionTop", (4.30, 1.15, 0.82), (0.0, 0.0, 4.48), mats["collision"], collection),
    ]
    result = join_parts(parts, f"{asset_id}-col", [mats["collision"]])
    result["asset_id"] = asset_id
    result["collision_role"] = "frame_only_open_passage"
    return result


def triangle_count(obj: bpy.types.Object) -> int:
    return sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons)


def non_manifold_edge_count(obj: bpy.types.Object) -> int:
    mesh = obj.data.copy()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    result = sum(1 for edge in bm.edges if not edge.is_manifold)
    bm.free()
    bpy.data.meshes.remove(mesh)
    return result


def validate_mesh(obj: bpy.types.Object, label: str, triangle_budget: int) -> dict[str, object]:
    if obj.type != "MESH":
        raise RuntimeError(f"{label}: expected mesh")
    if any(abs(float(value)) > 0.0001 for value in obj.location):
        raise RuntimeError(f"{label}: unapplied location")
    if any(abs(float(value) - 1.0) > 0.0001 for value in obj.scale):
        raise RuntimeError(f"{label}: unapplied scale")
    triangles = triangle_count(obj)
    if triangles > triangle_budget:
        raise RuntimeError(f"{label}: {triangles} tris exceeds {triangle_budget}")
    if len(obj.data.materials) > MAX_MATERIALS_PER_ASSET:
        raise RuntimeError(f"{label}: too many materials")
    non_manifold = non_manifold_edge_count(obj)
    if non_manifold:
        raise RuntimeError(f"{label}: {non_manifold} non-manifold edges")
    evidence = {
        "triangles": triangles,
        "materials": len(obj.data.materials),
        "dimensions_m": [round(float(value), 4) for value in obj.dimensions],
        "non_manifold_edges": non_manifold,
        "uv_layers": len(obj.data.uv_layers),
    }
    print(f"[HOPLITE PORTALS] {label}: PASS {evidence}")
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


def write_manifest(spec: PortalSpec, evidence: dict[str, dict[str, object]], asset_dir: Path) -> Path:
    manifest = {
        "asset": spec.asset_id,
        "status": "PASS",
        "quality": "V2_HERO",
        "family": "portals",
        "portal_role": spec.role,
        "units": "meters",
        "dimensions_m": evidence["LOD0"]["dimensions_m"],
        "opening_m": [3.4, 3.25],
        "forward_blender": "-Y",
        "forward_godot": "-Z",
        "triangles_lod0": evidence["LOD0"]["triangles"],
        "triangles_lod1": evidence["LOD1"]["triangles"],
        "triangles_lod2": evidence["LOD2"]["triangles"],
        "triangles_collision": evidence["collision"]["triangles"],
        "collision": "three closed box components covering both jambs and upper frame while preserving the playable opening",
        "forge_collision_enabled": False,
        "forge_collision_shape": "box",
        "origin": "center of base",
        "identity": spec.identity,
        "material_strategy": "four shared flat PBR materials including one emissive energy material",
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
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    if bpy.app.version < (5, 0, 0):
        scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = hex_to_linear_rgba("080A10")
    background.inputs["Strength"].default_value = 0.12
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


def setup_preview_assets(sources: list[bpy.types.Object], collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUTPUT_DIR / "hoplite_portals_preview.png")
    for source, x in zip(sources, (-6.2, 0.0, 6.2)):
        display = source.copy()
        display.data = source.data
        collection.objects.link(display)
        display.location.x = x
        display.rotation_euler.z = math.radians(4.0 if x < 0 else -4.0 if x > 0 else 0.0)
    add_box("PreviewFloor", (22.0, 8.0, 0.10), (0.0, 0.5, -0.07), mats["preview_floor"], collection, bevel=0.04)
    target = (0.0, 0.0, 2.8)
    add_area_light("PreviewKey", (-8.0, -8.0, 11.0), 1800.0, (0.64, 0.78, 1.0), 5.5, target, collection)
    add_area_light("PreviewRim", (8.0, 2.0, 9.0), 2200.0, (1.0, 0.22, 0.10), 4.5, target, collection)
    add_area_light("PreviewFill", (0.0, -3.0, 5.0), 650.0, (0.30, 0.50, 1.0), 6.0, target, collection)
    camera_data = bpy.data.cameras.new("CAM_HoplitePortals")
    camera = bpy.data.objects.new("CAM_HoplitePortals", camera_data)
    collection.objects.link(camera)
    camera.location = (13.5, -23.5, 10.8)
    camera_data.lens = 53.0
    point_at(camera, target)
    scene.camera = camera


def render_thumbnails(sources: list[bpy.types.Object], collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    scene = bpy.context.scene
    thumbnail_dir = OUTPUT_DIR / "thumbnails"
    thumbnail_dir.mkdir(parents=True, exist_ok=True)
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    add_box("ThumbnailFloor", (9.0, 8.0, 0.10), (0.0, 0.4, -0.07), mats["preview_floor"], collection, bevel=0.04)
    target = (0.0, 0.0, 2.6)
    add_area_light("ThumbnailKey", (-4.5, -6.0, 8.5), 1250.0, (0.68, 0.82, 1.0), 4.0, target, collection)
    add_area_light("ThumbnailRim", (5.0, 2.0, 7.0), 1550.0, (1.0, 0.28, 0.12), 3.5, target, collection)
    camera_data = bpy.data.cameras.new("CAM_HoplitePortalThumbnail")
    camera = bpy.data.objects.new("CAM_HoplitePortalThumbnail", camera_data)
    collection.objects.link(camera)
    camera_data.lens = 58.0
    scene.camera = camera
    for source in sources:
        display = source.copy()
        display.data = source.data
        collection.objects.link(display)
        display.rotation_euler.z = math.radians(-6.0)
        extent = max(float(source.dimensions.x), float(source.dimensions.z))
        distance = extent * 1.65
        camera.location = (distance * 0.62, -distance * 1.02, 2.7 + distance * 0.38)
        point_at(camera, (0.0, 0.0, float(source.dimensions.z) * 0.47))
        scene.render.filepath = str(thumbnail_dir / f"{source['asset_id']}.png")
        render_isolated(collection)
        bpy.data.objects.remove(display, do_unlink=True)


def asset_specs() -> list[PortalSpec]:
    return [
        PortalSpec("portal_world_forge", "world_editor", "triumphant sunlit forge portal with ivory pylons, bronze mechanism and turquoise creative energy", build_forge_portal, (5000, 2600, 900, 80)),
        PortalSpec("portal_saved_world", "saved_world", "mystical cartographer portal with slate monoliths, floating memory tablets, amber routes and blue archive energy", build_saved_world_portal, (5000, 2600, 900, 80)),
        PortalSpec("portal_official_campaign", "official_campaign", "lugubrious obsidian necropolis gate with blackened ribs, ritual spikes, horned helm and crimson-violet void", build_campaign_portal, (5500, 2800, 900, 80)),
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
    previews = new_collection("PREVIEW", root)
    lod0_objects: list[bpy.types.Object] = []
    summary: list[dict[str, object]] = []
    for spec in asset_specs():
        asset_dir = OUTPUT_DIR / "portals" / spec.asset_id
        asset_dir.mkdir(parents=True, exist_ok=True)
        export_collection = new_collection(f"EXPORT_{spec.asset_id}", exports_root)
        collision_collection = new_collection(f"COLLISION_{spec.asset_id}", collisions_root)
        evidence: dict[str, dict[str, object]] = {}
        objects: list[bpy.types.Object] = []
        for lod in range(3):
            obj = spec.builder(lod, export_collection, mats)
            objects.append(obj)
            evidence[f"LOD{lod}"] = validate_mesh(obj, f"{spec.asset_id}/LOD{lod}", spec.budgets[lod])
            export_object(obj, asset_dir / f"{spec.asset_id}_LOD{lod}.glb")
        collision = build_collision(spec.asset_id, collision_collection, mats)
        evidence["collision"] = validate_mesh(collision, f"{spec.asset_id}/collision", spec.budgets[3])
        export_object(collision, asset_dir / f"{spec.asset_id}_collision.glb")
        manifest_path = write_manifest(spec, evidence, asset_dir)
        lod0_objects.append(objects[0])
        summary.append({"asset": spec.asset_id, "role": spec.role, "triangles_lod0": evidence["LOD0"]["triangles"], "manifest": str(manifest_path.relative_to(OUTPUT_DIR))})
    library_manifest = OUTPUT_DIR / "library_manifest.json"
    library_manifest.write_text(json.dumps({"collection": "hoplite_portals", "status": "PASS", "asset_count": 3, "seed": SEED, "assets": summary}, indent=2), encoding="utf-8")
    setup_preview_assets(lod0_objects, previews, mats)
    render_isolated(previews)
    thumbnails = new_collection("THUMBNAILS", root)
    render_thumbnails(lod0_objects, thumbnails, mats)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / "hoplite_portals.blend"))
    print(f"[HOPLITE PORTALS] Blender: {bpy.app.version_string}")
    print(f"[HOPLITE PORTALS] Assets: {len(summary)}")
    print(f"[HOPLITE PORTALS] PASS: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
