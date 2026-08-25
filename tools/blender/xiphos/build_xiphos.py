"""Generate the main-character xiphos as one game-ready mesh.

The script is deterministic and has no dependency outside Blender. It builds the
sword from several temporary parts, joins them into a single object named
``SM_Xiphos_Main``, saves a Blender source file, renders a preview, and exports a
GLB for Godot.

Command-line usage (PowerShell):

    & "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" `
      --background --python ".\\tools\\blender\\xiphos\\build_xiphos.py"

Important: running this script clears the currently open Blender scene.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


# -----------------------------------------------------------------------------
# Project paths and editable art parameters
# -----------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
OUTPUT_DIR = SCRIPT_DIR / "output"
BLEND_PATH = OUTPUT_DIR / "xiphos_main.blend"
PREVIEW_PATH = OUTPUT_DIR / "xiphos_preview.png"
GLB_PATH = PROJECT_ROOT / "assets" / "weapons" / "xiphos_main.glb"

# Blender uses meters. The blade marker values mirror scripts/player.gd.
BLADE_BASE_Z = 0.12
BLADE_TIP_Z = 1.03
GRIP_TOP_Z = 0.035
GRIP_BOTTOM_Z = -0.225
POMMEL_BOTTOM_Z = -0.335

FINAL_OBJECT_NAME = "SM_Xiphos_Main"


# -----------------------------------------------------------------------------
# Scene helpers
# -----------------------------------------------------------------------------

def reset_scene() -> None:
    """Clear the current file so every run produces the same scene."""
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


def move_to_collection(
    obj: bpy.types.Object, collection: bpy.types.Collection
) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def make_material(
    name: str,
    base_color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name=name)
    material.diffuse_color = base_color

    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = base_color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    return material


def assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.append(material)


def set_smooth(obj: bpy.types.Object, smooth: bool = True) -> None:
    if obj.type != "MESH":
        return
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


def normalize_part_material_slots(
    parts: list[bpy.types.Object],
    materials: list[bpy.types.Material],
) -> None:
    """Give every part the same material-slot layout before Blender joins it.

    Blender 5.2 can keep the slot list while resetting joined polygons to slot
    zero when source meshes each own a different one-slot layout. A shared slot
    table makes the face assignments deterministic across Blender versions.
    """
    slot_by_name = {material.name: index for index, material in enumerate(materials)}
    for part in parts:
        if part.type != "MESH" or not part.data.materials:
            continue
        intended_material = part.data.materials[0]
        intended_index = slot_by_name[intended_material.name]
        part.data.materials.clear()
        for material in materials:
            part.data.materials.append(material)
        for polygon in part.data.polygons:
            polygon.material_index = intended_index


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


def create_prism_from_xz_polygon(
    name: str,
    points: list[tuple[float, float]],
    depth: float,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    """Extrude a polygon drawn in the X/Z plane along the Y axis."""
    half_depth = depth * 0.5
    count = len(points)
    vertices = [(x, -half_depth, z) for x, z in points]
    vertices.extend((x, half_depth, z) for x, z in points)

    # The two caps use opposite winding; the remaining faces wrap the rim.
    faces: list[tuple[int, ...]] = [tuple(reversed(range(count)))]
    faces.append(tuple(range(count, count * 2)))
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))

    return create_mesh_object(name, vertices, faces, collection)


# -----------------------------------------------------------------------------
# Asset construction
# -----------------------------------------------------------------------------

def create_leaf_blade(
    collection: bpy.types.Collection,
    steel: bpy.types.Material,
) -> bpy.types.Object:
    """Create a leaf-shaped xiphos blade with a diamond cross section."""
    # (height, full width, full ridge thickness). The widest section sits above
    # the middle, giving the characteristic leaf-shaped xiphos silhouette.
    rings = [
        (BLADE_BASE_Z, 0.064, 0.020),
        (0.205, 0.073, 0.021),
        (0.390, 0.088, 0.022),
        (0.620, 0.098, 0.023),
        (0.800, 0.082, 0.020),
        (0.945, 0.046, 0.015),
    ]

    vertices: list[tuple[float, float, float]] = []
    for z, width, thickness in rings:
        half_width = width * 0.5
        half_thickness = thickness * 0.5
        vertices.extend(
            [
                (-half_width, 0.0, z),
                (0.0, -half_thickness, z),
                (half_width, 0.0, z),
                (0.0, half_thickness, z),
            ]
        )

    tip_index = len(vertices)
    vertices.append((0.0, 0.0, BLADE_TIP_Z))

    faces: list[tuple[int, ...]] = [(3, 2, 1, 0)]
    for ring_index in range(len(rings) - 1):
        lower = ring_index * 4
        upper = (ring_index + 1) * 4
        for side in range(4):
            next_side = (side + 1) % 4
            faces.append(
                (
                    lower + side,
                    lower + next_side,
                    upper + next_side,
                    upper + side,
                )
            )

    final_ring = (len(rings) - 1) * 4
    for side in range(4):
        faces.append(
            (final_ring + side, final_ring + (side + 1) % 4, tip_index)
        )

    blade = create_mesh_object("Blade", vertices, faces, collection)
    assign_material(blade, steel)
    add_bevel(blade, width=0.0014, segments=2, angle_degrees=18.0)
    return blade


def create_guard(
    collection: bpy.types.Collection,
    bronze: bpy.types.Material,
) -> bpy.types.Object:
    # A shallow omega-like guard: broad enough to read during gameplay without
    # becoming a medieval cruciform crossguard.
    outline = [
        (-0.165, 0.048),
        (-0.158, 0.082),
        (-0.128, 0.108),
        (-0.074, 0.116),
        (-0.032, 0.098),
        (0.0, 0.091),
        (0.032, 0.098),
        (0.074, 0.116),
        (0.128, 0.108),
        (0.158, 0.082),
        (0.165, 0.048),
        (0.130, 0.035),
        (0.074, 0.045),
        (0.030, 0.063),
        (0.0, 0.066),
        (-0.030, 0.063),
        (-0.074, 0.045),
        (-0.130, 0.035),
    ]
    guard = create_prism_from_xz_polygon(
        "Guard", outline, depth=0.042, collection=collection
    )
    assign_material(guard, bronze)
    add_bevel(guard, width=0.006, segments=3, angle_degrees=22.0)
    return guard


def create_cylinder(
    name: str,
    radius: float,
    depth: float,
    z: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    vertices: int = 32,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
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


def create_torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    z: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=32,
        minor_segments=8,
        location=(0.0, 0.0, z),
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    assign_material(obj, material)
    set_smooth(obj)
    return obj


def create_grip_wrap(
    collection: bpy.types.Collection,
    wrap_material: bpy.types.Material,
) -> bpy.types.Object:
    """Create a continuous raised leather helix around the grip."""
    curve_data = bpy.data.curves.new("GripWrap_Curve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = 0.0032
    curve_data.bevel_resolution = 2
    curve_data.resolution_u = 2

    turns = 6.25
    segments = 144
    radius = 0.039
    z_start = GRIP_BOTTOM_Z + 0.016
    z_end = GRIP_TOP_Z - 0.014

    spline = curve_data.splines.new(type="POLY")
    spline.points.add(segments)
    for index in range(segments + 1):
        ratio = index / segments
        angle = ratio * turns * math.tau
        z = z_start + (z_end - z_start) * ratio
        spline.points[index].co = (
            radius * math.cos(angle),
            radius * math.sin(angle),
            z,
            1.0,
        )

    wrap = bpy.data.objects.new("GripWrap", curve_data)
    collection.objects.link(wrap)
    assign_material(wrap, wrap_material)

    bpy.context.view_layer.objects.active = wrap
    wrap.select_set(True)
    bpy.ops.object.convert(target="MESH")
    set_smooth(wrap)
    return wrap


def create_pommel(
    collection: bpy.types.Collection,
    bronze: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=3,
        radius=1.0,
        location=(0.0, 0.0, -0.278),
    )
    pommel = bpy.context.object
    pommel.name = "Pommel"
    pommel.scale = (0.068, 0.042, 0.073)
    move_to_collection(pommel, collection)
    assign_material(pommel, bronze)
    set_smooth(pommel)
    add_bevel(pommel, width=0.0015, segments=2, angle_degrees=30.0)
    return pommel


def build_xiphos(asset_collection: bpy.types.Collection) -> bpy.types.Object:
    steel = make_material(
        "MAT_Xiphos_Steel", (0.42, 0.50, 0.58, 1.0), metallic=0.92, roughness=0.20
    )
    bronze = make_material(
        "MAT_Xiphos_Bronze", (0.38, 0.145, 0.035, 1.0), metallic=0.82, roughness=0.28
    )
    leather = make_material(
        "MAT_Xiphos_Leather", (0.075, 0.022, 0.012, 1.0), metallic=0.0, roughness=0.72
    )
    leather_highlight = make_material(
        "MAT_Xiphos_Wrap", (0.19, 0.055, 0.022, 1.0), metallic=0.0, roughness=0.60
    )

    parts: list[bpy.types.Object] = []
    parts.append(create_leaf_blade(asset_collection, steel))
    parts.append(create_guard(asset_collection, bronze))

    # This hidden structural tang overlaps the blade, guard, and grip. The
    # overlap is intentional: it prevents light leaks or visible gaps even when
    # bevel widths change during later art iterations.
    upper_collar = create_cylinder(
        "BladeGuardTang",
        0.046,
        0.105,
        0.075,
        bronze,
        asset_collection,
        vertices=32,
    )
    upper_collar.scale = (1.0, 0.62, 1.0)
    add_bevel(upper_collar, width=0.003, segments=2)
    parts.append(upper_collar)

    grip = create_cylinder(
        "GripCore",
        radius=0.036,
        depth=GRIP_TOP_Z - GRIP_BOTTOM_Z,
        z=(GRIP_TOP_Z + GRIP_BOTTOM_Z) * 0.5,
        material=leather,
        collection=asset_collection,
        vertices=32,
    )
    grip.scale = (1.0, 0.84, 1.0)
    add_bevel(grip, width=0.0025, segments=2)
    parts.append(grip)
    parts.append(create_grip_wrap(asset_collection, leather_highlight))

    top_ring = create_torus(
        "GripTopRing", 0.037, 0.0055, 0.032, bronze, asset_collection
    )
    bottom_ring = create_torus(
        "GripBottomRing", 0.039, 0.0055, -0.225, bronze, asset_collection
    )
    parts.extend((top_ring, bottom_ring))

    # A short neck penetrates both the grip and the pommel. Besides removing the
    # visible seam, it gives a plausible metal core to the assembled weapon.
    pommel_neck = create_cylinder(
        "PommelNeck",
        0.034,
        0.060,
        -0.233,
        bronze,
        asset_collection,
        vertices=32,
    )
    pommel_neck.scale = (1.0, 0.84, 1.0)
    add_bevel(pommel_neck, width=0.002, segments=2)
    parts.append(pommel_neck)
    parts.append(create_pommel(asset_collection, bronze))

    # Small bronze studs on both sides make the guard read at gameplay distance.
    for side in (-1.0, 1.0):
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=20,
            ring_count=10,
            radius=0.012,
            location=(0.0, side * 0.025, 0.082),
        )
        stud = bpy.context.object
        stud.name = "GuardStud"
        stud.scale = (1.0, 0.45, 1.0)
        move_to_collection(stud, asset_collection)
        assign_material(stud, bronze)
        set_smooth(stud)
        apply_transform(stud)
        parts.append(stud)

    normalize_part_material_slots(
        parts, [steel, bronze, leather, leather_highlight]
    )

    # Bake each temporary modifier before joining so the final object keeps all
    # bevels while still being a single MeshInstance after GLB import.
    for part in parts:
        if part.type == "MESH":
            apply_modifiers(part)

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()

    sword = bpy.context.object
    sword.name = FINAL_OBJECT_NAME
    sword.data.name = f"{FINAL_OBJECT_NAME}_Mesh"

    # Collapse repeated material slots introduced by joining temporary pieces.
    existing_materials = list(sword.data.materials)
    unique_materials: list[bpy.types.Material] = []
    material_map: dict[int, int] = {}
    material_indices: dict[str, int] = {}
    for old_index, material in enumerate(existing_materials):
        key = material.name
        if key not in material_indices:
            material_indices[key] = len(unique_materials)
            unique_materials.append(material)
        material_map[old_index] = material_indices[key]

    remapped_polygon_indices = [
        material_map.get(polygon.material_index, 0)
        for polygon in sword.data.polygons
    ]
    sword.data.materials.clear()
    for material in unique_materials:
        sword.data.materials.append(material)
    for polygon, material_index in zip(
        sword.data.polygons, remapped_polygon_indices
    ):
        polygon.material_index = material_index

    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    apply_transform(sword)

    # These extras survive GLB export and document the gameplay contact segment.
    sword["asset_type"] = "weapon"
    sword["weapon_kind"] = "sword"
    sword["weapon_name"] = "Xiphos"
    sword["blade_base_godot_y"] = BLADE_BASE_Z
    sword["blade_tip_godot_y"] = BLADE_TIP_Z
    sword["unit_scale_meters"] = 1.0
    return sword


# -----------------------------------------------------------------------------
# Presentation, export, and validation
# -----------------------------------------------------------------------------

def point_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_area_light(
    name: str,
    location: tuple[float, float, float],
    energy: float,
    color: tuple[float, float, float],
    size: float,
    target: tuple[float, float, float],
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    light_data = bpy.data.lights.new(name=name, type="AREA")
    light_data.energy = energy
    light_data.color = color
    light_data.shape = "DISK"
    light_data.size = size

    light = bpy.data.objects.new(name, light_data)
    collection.objects.link(light)
    light.location = location
    point_at(light, target)
    return light


def setup_presentation(collection: bpy.types.Collection) -> None:
    scene = bpy.context.scene
    scene.render.resolution_x = 700
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(PREVIEW_PATH)

    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        # Keeps the generator usable if Blender renames the EEVEE identifier.
        pass

    scene.render.image_settings.color_mode = "RGBA"
    scene.world.color = (0.008, 0.012, 0.022)
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.008, 0.012, 0.025, 1.0)
    background.inputs["Strength"].default_value = 0.22

    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = -0.65

    floor_material = make_material(
        "MAT_Preview_Floor", (0.018, 0.025, 0.040, 1.0), metallic=0.15, roughness=0.34
    )
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0.0, 0.0, POMMEL_BOTTOM_Z - 0.008))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    move_to_collection(floor, collection)
    assign_material(floor, floor_material)

    target = (0.0, 0.0, 0.36)
    add_area_light(
        "LGT_Key",
        (-1.25, -1.65, 1.75),
        430.0,
        (0.78, 0.88, 1.0),
        1.15,
        target,
        collection,
    )
    add_area_light(
        "LGT_WarmRim",
        (1.10, 0.75, 1.25),
        520.0,
        (1.0, 0.36, 0.11),
        0.85,
        target,
        collection,
    )
    add_area_light(
        "LGT_Fill",
        (0.10, -0.75, 0.15),
        125.0,
        (0.28, 0.42, 1.0),
        1.0,
        target,
        collection,
    )

    camera_data = bpy.data.cameras.new("CAM_Xiphos_Preview")
    camera = bpy.data.objects.new("CAM_Xiphos_Preview", camera_data)
    collection.objects.link(camera)
    camera.location = (1.34, -2.28, 0.88)
    camera_data.lens = 58.0
    camera_data.sensor_width = 36.0
    point_at(camera, target)
    scene.camera = camera


def triangle_count(obj: bpy.types.Object) -> int:
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


def validate_asset(sword: bpy.types.Object) -> None:
    asset_meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name == FINAL_OBJECT_NAME]
    if len(asset_meshes) != 1:
        raise RuntimeError(f"Expected one final sword mesh, found {len(asset_meshes)}")
    if sword.location.length > 1e-6:
        raise RuntimeError(f"Sword origin is not at the grip pivot: {tuple(sword.location)}")
    if abs(sword.scale.x - 1.0) > 1e-6 or abs(sword.scale.y - 1.0) > 1e-6 or abs(sword.scale.z - 1.0) > 1e-6:
        raise RuntimeError(f"Sword scale is not applied: {tuple(sword.scale)}")
    if sword.dimensions.z < 1.30 or sword.dimensions.z > 1.40:
        raise RuntimeError(f"Unexpected sword height: {sword.dimensions.z:.4f} m")

    print("[XIPHOS] Validation PASS")
    print(f"[XIPHOS] Object: {sword.name}")
    print(f"[XIPHOS] Dimensions (m): {tuple(round(value, 4) for value in sword.dimensions)}")
    print(f"[XIPHOS] Triangles: {triangle_count(sword)}")
    print(f"[XIPHOS] Material slots: {len(sword.data.materials)}")


def export_glb(sword: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    sword.select_set(True)
    bpy.context.view_layer.objects.active = sword
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
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


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)

    reset_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene.unit_settings.scale_length = 1.0

    asset_collection = make_collection("COL_Xiphos_Asset")
    presentation_collection = make_collection("COL_Xiphos_Presentation")

    sword = build_xiphos(asset_collection)
    validate_asset(sword)
    export_glb(sword)
    setup_presentation(presentation_collection)

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.context.scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

    print(f"[XIPHOS] Blend: {BLEND_PATH}")
    print(f"[XIPHOS] Preview: {PREVIEW_PATH}")
    print(f"[XIPHOS] Godot GLB: {GLB_PATH}")


if __name__ == "__main__":
    main()
