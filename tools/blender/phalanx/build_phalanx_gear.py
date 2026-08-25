"""Generate the phalanx dory spear and aspis shield for Godot.

The two assets share a three-material palette (bronze, wood, leather), use no
image textures, and are each joined into one final mesh before GLB export.

PowerShell usage:

    & "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" `
      --background --python ".\\tools\\blender\\phalanx\\build_phalanx_gear.py"

Important: running this script clears the currently open Blender scene.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
OUTPUT_DIR = SCRIPT_DIR / "output"
BLEND_PATH = OUTPUT_DIR / "phalanx_gear.blend"
PREVIEW_PATH = OUTPUT_DIR / "phalanx_gear_preview.png"
SPEAR_GLB_PATH = PROJECT_ROOT / "assets" / "weapons" / "dory_spear.glb"
SHIELD_GLB_PATH = PROJECT_ROOT / "assets" / "weapons" / "aspis_shield.glb"

SPEAR_NAME = "SM_Dory_Spear"
SHIELD_NAME = "SM_Aspis_Shield"


# -----------------------------------------------------------------------------
# Generic Blender helpers
# -----------------------------------------------------------------------------

def reset_scene() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            datablocks.remove(datablock)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def make_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name=name)
    material.diffuse_color = color
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    return material


def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.append(material)


def set_smooth(obj: bpy.types.Object, smooth: bool = True) -> None:
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = smooth


def apply_transform(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def apply_modifiers(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def add_bevel(
    obj: bpy.types.Object,
    width: float,
    segments: int = 2,
    angle_degrees: float = 28.0,
) -> None:
    apply_transform(obj)
    bevel = obj.modifiers.new(name="Bevel", type="BEVEL")
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(angle_degrees)
    bevel.width = width
    bevel.segments = segments
    bevel.affect = "EDGES"


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


def create_tapered_cylinder(
    name: str,
    radius_bottom: float,
    radius_top: float,
    depth: float,
    z: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 20,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        end_fill_type="NGON",
        location=(0.0, 0.0, z),
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    assign_material(obj, material)
    set_smooth(obj)
    return obj


def create_box(
    name: str,
    size: tuple[float, float, float],
    location: tuple[float, float, float],
    rotation: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    move_to_collection(obj, collection)
    assign_material(obj, material)
    add_bevel(obj, width=0.003, segments=2)
    return obj


def normalize_material_slots(
    parts: list[bpy.types.Object], materials: list[bpy.types.Material]
) -> None:
    slots = {material.name: index for index, material in enumerate(materials)}
    for part in parts:
        if part.type != "MESH" or not part.data.materials:
            continue
        intended = part.data.materials[0]
        intended_index = slots[intended.name]
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
    normalize_material_slots(parts, materials)
    for part in parts:
        apply_modifiers(part)

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()

    result = bpy.context.object
    result.name = final_name
    result.data.name = f"{final_name}_Mesh"

    # Joining produces repeated slots on some Blender versions. Preserve the
    # face indices while collapsing them back to the shared palette.
    old_slots = list(result.data.materials)
    unique: list[bpy.types.Material] = []
    unique_indices: dict[str, int] = {}
    slot_map: dict[int, int] = {}
    for old_index, material in enumerate(old_slots):
        if material.name not in unique_indices:
            unique_indices[material.name] = len(unique)
            unique.append(material)
        slot_map[old_index] = unique_indices[material.name]
    remapped = [slot_map.get(poly.material_index, 0) for poly in result.data.polygons]
    result.data.materials.clear()
    for material in unique:
        result.data.materials.append(material)
    for polygon, material_index in zip(result.data.polygons, remapped):
        polygon.material_index = material_index

    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    apply_transform(result)
    return result


# -----------------------------------------------------------------------------
# Dory spear
# -----------------------------------------------------------------------------

def create_spear_head(
    material: bpy.types.Material, collection: bpy.types.Collection
) -> bpy.types.Object:
    # Diamond-section leaf point, from socket to tip.
    rings = [
        (1.485, 0.045, 0.022),
        (1.535, 0.075, 0.026),
        (1.625, 0.105, 0.030),
        (1.705, 0.065, 0.022),
    ]
    vertices: list[tuple[float, float, float]] = []
    for z, width, thickness in rings:
        vertices.extend(
            [
                (-width * 0.5, 0.0, z),
                (0.0, -thickness * 0.5, z),
                (width * 0.5, 0.0, z),
                (0.0, thickness * 0.5, z),
            ]
        )
    tip_index = len(vertices)
    vertices.append((0.0, 0.0, 1.790))

    faces: list[tuple[int, ...]] = [(3, 2, 1, 0)]
    for ring_index in range(len(rings) - 1):
        lower = ring_index * 4
        upper = (ring_index + 1) * 4
        for side in range(4):
            following = (side + 1) % 4
            faces.append(
                (
                    lower + side,
                    lower + following,
                    upper + following,
                    upper + side,
                )
            )
    last_ring = (len(rings) - 1) * 4
    for side in range(4):
        faces.append((last_ring + side, last_ring + (side + 1) % 4, tip_index))

    head = create_mesh_object("DoryHead", vertices, faces, collection)
    assign_material(head, material)
    add_bevel(head, width=0.0015, segments=2, angle_degrees=18.0)
    return head


def create_grip_wrap(
    material: bpy.types.Material, collection: bpy.types.Collection
) -> bpy.types.Object:
    curve_data = bpy.data.curves.new("DoryGripWrap_Curve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = 0.0025
    curve_data.bevel_resolution = 1

    turns = 5.0
    segments = 84
    spline = curve_data.splines.new(type="POLY")
    spline.points.add(segments)
    for index in range(segments + 1):
        ratio = index / segments
        angle = ratio * turns * math.tau
        z = -0.16 + 0.32 * ratio
        spline.points[index].co = (
            0.031 * math.cos(angle),
            0.031 * math.sin(angle),
            z,
            1.0,
        )

    wrap = bpy.data.objects.new("DoryGripWrap", curve_data)
    collection.objects.link(wrap)
    assign_material(wrap, material)
    bpy.context.view_layer.objects.active = wrap
    wrap.select_set(True)
    bpy.ops.object.convert(target="MESH")
    set_smooth(wrap)
    return wrap


def build_spear(
    collection: bpy.types.Collection,
    materials: list[bpy.types.Material],
) -> bpy.types.Object:
    bronze, wood, leather = materials
    parts: list[bpy.types.Object] = []

    shaft = create_tapered_cylinder(
        "DoryShaft", 0.030, 0.026, 2.05, 0.46, wood, collection, vertices=20
    )
    parts.append(shaft)

    # Long bronze socket overlaps both shaft and head so no light gap can appear.
    socket = create_tapered_cylinder(
        "DorySocket", 0.044, 0.036, 0.17, 1.465, bronze, collection, vertices=24
    )
    add_bevel(socket, width=0.002, segments=2)
    parts.extend((socket, create_spear_head(bronze, collection)))

    leather_sleeve = create_tapered_cylinder(
        "DoryGripSleeve", 0.031, 0.031, 0.34, 0.0, leather, collection, vertices=20
    )
    parts.extend((leather_sleeve, create_grip_wrap(leather, collection)))

    # Sauroter counter-spike: the broad socket overlaps the wooden shaft and
    # narrows into a durable bronze point below the hand.
    butt_socket = create_tapered_cylinder(
        "DoryButtSocket", 0.042, 0.033, 0.15, -0.605, bronze, collection, vertices=20
    )
    add_bevel(butt_socket, width=0.002, segments=2)
    butt_point = create_tapered_cylinder(
        "DoryButtPoint", 0.0, 0.041, 0.22, -0.785, bronze, collection, vertices=20
    )
    parts.extend((butt_socket, butt_point))

    spear = join_parts(parts, SPEAR_NAME, materials)
    spear["asset_type"] = "weapon"
    spear["weapon_kind"] = "spear"
    spear["weapon_name"] = "Dory"
    spear["grip_origin_godot_y"] = 0.0
    spear["tip_godot_y"] = 1.79
    spear["unit_scale_meters"] = 1.0
    return spear


# -----------------------------------------------------------------------------
# Aspis shield
# -----------------------------------------------------------------------------

def create_shield_plate(
    material: bpy.types.Material, collection: bpy.types.Collection
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=48,
        radius=0.465,
        depth=0.075,
        end_fill_type="NGON",
        location=(0.0, 0.0, 0.0),
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    plate = bpy.context.object
    plate.name = "AspisPlate"
    move_to_collection(plate, collection)
    assign_material(plate, material)
    add_bevel(plate, width=0.014, segments=3, angle_degrees=22.0)
    return plate


def create_shield_torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    y: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=48,
        minor_segments=8,
        location=(0.0, y, 0.0),
        rotation=(math.radians(90.0), 0.0, 0.0),
    )
    torus = bpy.context.object
    torus.name = name
    move_to_collection(torus, collection)
    assign_material(torus, material)
    set_smooth(torus)
    return torus


def build_shield(
    collection: bpy.types.Collection,
    materials: list[bpy.types.Material],
) -> bpy.types.Object:
    bronze, wood, leather = materials
    parts: list[bpy.types.Object] = [create_shield_plate(wood, collection)]

    # The rim overlaps the plate by more than the bevel width, eliminating the
    # seam seen on early xiphos iterations.
    parts.append(create_shield_torus("AspisRim", 0.440, 0.030, -0.004, bronze, collection))
    parts.append(create_shield_torus("AspisBossRing", 0.135, 0.016, -0.047, bronze, collection))

    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=16,
        radius=1.0,
        location=(0.0, -0.073, 0.0),
    )
    boss = bpy.context.object
    boss.name = "AspisBoss"
    boss.scale = (0.145, 0.070, 0.145)
    move_to_collection(boss, collection)
    assign_material(boss, bronze)
    set_smooth(boss)
    apply_transform(boss)
    parts.append(boss)

    # Rear porpax and hand strap. They share the same leather material as the
    # dory grip and remain simple enough for large phalanx crowds.
    porpax = create_box(
        "AspisPorpax",
        (0.34, 0.025, 0.065),
        (0.0, 0.055, 0.105),
        (0.0, 0.0, 0.0),
        leather,
        collection,
    )
    hand_strap = create_box(
        "AspisHandStrap",
        (0.20, 0.025, 0.052),
        (0.18, 0.056, -0.115),
        (0.0, 0.0, math.radians(-8.0)),
        leather,
        collection,
    )
    parts.extend((porpax, hand_strap))

    # Four low-cost bronze rivets tie the straps visually into the plate.
    for x, z in ((-0.155, 0.105), (0.155, 0.105), (0.095, -0.115), (0.265, -0.115)):
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=12,
            ring_count=6,
            radius=0.015,
            location=(x, 0.073, z),
        )
        rivet = bpy.context.object
        rivet.name = "AspisRivet"
        rivet.scale = (1.0, 0.55, 1.0)
        move_to_collection(rivet, collection)
        assign_material(rivet, bronze)
        set_smooth(rivet)
        apply_transform(rivet)
        parts.append(rivet)

    shield = join_parts(parts, SHIELD_NAME, materials)
    shield["asset_type"] = "shield"
    shield["shield_name"] = "Aspis"
    shield["shield_radius_meters"] = 0.48
    shield["forward_godot_axis"] = "-Z"
    shield["unit_scale_meters"] = 1.0
    return shield


# -----------------------------------------------------------------------------
# Export, preview, and validation
# -----------------------------------------------------------------------------

def triangle_count(obj: bpy.types.Object) -> int:
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


def validate_asset(
    obj: bpy.types.Object,
    expected_name: str,
    max_materials: int,
) -> None:
    if obj.type != "MESH" or obj.name != expected_name:
        raise RuntimeError(f"Invalid final asset: {obj.name} ({obj.type})")
    if obj.location.length > 1e-6:
        raise RuntimeError(f"{obj.name} origin is not at (0, 0, 0)")
    if any(abs(value - 1.0) > 1e-6 for value in obj.scale):
        raise RuntimeError(f"{obj.name} has unapplied scale {tuple(obj.scale)}")
    if len(obj.data.materials) > max_materials:
        raise RuntimeError(f"{obj.name} uses too many materials")

    print(f"[PHALANX] {obj.name}: PASS")
    print(f"[PHALANX] Dimensions (m): {tuple(round(v, 4) for v in obj.dimensions)}")
    print(f"[PHALANX] Triangles: {triangle_count(obj)}")
    print(f"[PHALANX] Materials: {[m.name for m in obj.data.materials]}")


def export_glb(obj: bpy.types.Object, path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
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
    spear: bpy.types.Object,
    shield: bpy.types.Object,
    collection: bpy.types.Collection,
) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        pass

    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.008, 0.012, 0.024, 1.0)
    background.inputs["Strength"].default_value = 0.18
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = -0.55

    # Keep export assets at origin and use linked display copies for composition.
    spear.hide_render = True
    shield.hide_render = True
    spear_display = spear.copy()
    spear_display.data = spear.data
    spear_display.name = "PREVIEW_Dory"
    collection.objects.link(spear_display)
    spear_display.hide_render = False
    spear_display.location = (-0.72, 0.02, 0.08)
    spear_display.rotation_euler.y = math.radians(-8.0)

    shield_display = shield.copy()
    shield_display.data = shield.data
    shield_display.name = "PREVIEW_Aspis"
    collection.objects.link(shield_display)
    shield_display.hide_render = False
    shield_display.location = (0.50, 0.0, 0.33)
    shield_display.rotation_euler.z = math.radians(-5.0)

    floor_material = make_material(
        "MAT_Preview_Floor", (0.018, 0.025, 0.040, 1.0), 0.10, 0.38
    )
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0.0, 0.0, -0.835))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    move_to_collection(floor, collection)
    assign_material(floor, floor_material)

    target = (0.0, 0.0, 0.58)
    add_area_light(
        "LGT_Key", (-1.8, -2.2, 2.4), 520.0, (0.72, 0.84, 1.0), 1.4, target, collection
    )
    add_area_light(
        "LGT_WarmRim", (1.6, 0.8, 1.5), 620.0, (1.0, 0.34, 0.09), 1.0, target, collection
    )
    add_area_light(
        "LGT_Fill", (0.1, -1.1, -0.1), 160.0, (0.30, 0.44, 1.0), 1.2, target, collection
    )

    camera_data = bpy.data.cameras.new("CAM_Phalanx_Gear")
    camera = bpy.data.objects.new("CAM_Phalanx_Gear", camera_data)
    collection.objects.link(camera)
    camera.location = (2.35, -4.4, 1.55)
    camera_data.lens = 49.0
    point_at(camera, target)
    scene.camera = camera


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SPEAR_GLB_PATH.parent.mkdir(parents=True, exist_ok=True)

    reset_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene.unit_settings.scale_length = 1.0

    asset_collection = make_collection("COL_Phalanx_Assets")
    preview_collection = make_collection("COL_Phalanx_Preview")

    # One palette, no bitmaps. Godot imports only three PBR materials across the
    # two assets, with identical names and properties.
    bronze = make_material(
        "MAT_Phalanx_Bronze", (0.34, 0.105, 0.018, 1.0), 0.80, 0.29
    )
    wood = make_material(
        "MAT_Phalanx_Wood", (0.19, 0.058, 0.016, 1.0), 0.0, 0.76
    )
    leather = make_material(
        "MAT_Phalanx_Leather", (0.065, 0.014, 0.008, 1.0), 0.0, 0.78
    )
    materials = [bronze, wood, leather]

    spear = build_spear(asset_collection, materials)
    shield = build_shield(asset_collection, materials)
    validate_asset(spear, SPEAR_NAME, max_materials=3)
    validate_asset(shield, SHIELD_NAME, max_materials=3)
    image_texture_nodes = [
        node
        for material in materials
        if material.use_nodes and material.node_tree
        for node in material.node_tree.nodes
        if node.type == "TEX_IMAGE"
    ]
    if image_texture_nodes:
        raise RuntimeError("Phalanx materials unexpectedly use image textures")

    export_glb(spear, SPEAR_GLB_PATH)
    export_glb(shield, SHIELD_GLB_PATH)
    setup_preview(spear, shield, preview_collection)

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    print("[PHALANX] Validation PASS — 2 assets, 3 shared materials, 0 image textures")
    print(f"[PHALANX] Blend: {BLEND_PATH}")
    print(f"[PHALANX] Preview: {PREVIEW_PATH}")
    print(f"[PHALANX] Spear GLB: {SPEAR_GLB_PATH}")
    print(f"[PHALANX] Shield GLB: {SHIELD_GLB_PATH}")


if __name__ == "__main__":
    main()
