"""Build Hoplite's original mythic sword and shield for Godot 4.x.

The generator owns only data prefixed with ``GEN_HeroArsenal`` and is safe to
rerun in an existing Blender file. It exports two static GLBs, a Blender source,
a combined preview, and a measured JSON manifest.

Art contract:
- Aegis Fang: long tapered blade, dark central spine, bronze crescent guard,
  restrained cyan runes. Grip pivot at the world origin; blade is Blender +Z.
- Titan Aegis: tall tapered shield, layered bronze/obsidian plates, omega boss,
  restrained cyan runes. Grip pivot at the world origin; face is Blender -Y.
- 3,000-8,000 triangles per hero prop, at most four shared materials each.
- Godot conversion: Blender +Z -> Godot +Y, Blender -Y -> Godot -Z.

Run:
    blender --background --python tools/blender/hero_arsenal/build_hero_arsenal.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


PREFIX = "GEN_HeroArsenal"
SCENE_NAME = f"{PREFIX}_Scene"
ROOT_COLLECTION_NAME = f"{PREFIX}_Root"
SEED = 2408

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
OUTPUT_DIR = SCRIPT_DIR / "output"
BLEND_PATH = OUTPUT_DIR / "hero_arsenal.blend"
PREVIEW_PATH = OUTPUT_DIR / "hero_arsenal_preview.png"
MANIFEST_PATH = OUTPUT_DIR / "asset_manifest.json"
SWORD_GLB_PATH = PROJECT_ROOT / "assets" / "weapons" / "aegis_fang.glb"
SHIELD_GLB_PATH = PROJECT_ROOT / "assets" / "weapons" / "titan_aegis.glb"

SWORD_NAME = "SM_Aegis_Fang"
SHIELD_NAME = "SM_Titan_Aegis"
SWORD_BLADE_BASE_Z = 0.16
SWORD_BLADE_TIP_Z = 1.45
SWORD_POMMEL_BOTTOM_Z = -0.37


def remove_collection_tree(collection: bpy.types.Collection) -> None:
    for child in list(collection.children):
        remove_collection_tree(child)
    for obj in list(collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(collection)


def clear_previous_generation() -> None:
    scene = bpy.data.scenes.get(SCENE_NAME)
    if scene is not None:
        bpy.data.scenes.remove(scene)
    root = bpy.data.collections.get(ROOT_COLLECTION_NAME)
    if root is not None:
        remove_collection_tree(root)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials,
                       bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.name.startswith(PREFIX) and datablock.users == 0:
                datablocks.remove(datablock)


def make_scene() -> tuple[bpy.types.Scene, bpy.types.Collection]:
    scene = bpy.data.scenes.new(SCENE_NAME)
    root = bpy.data.collections.new(ROOT_COLLECTION_NAME)
    scene.collection.children.link(root)
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.length_unit = "METERS"
    scene.unit_settings.scale_length = 1.0
    return scene, root


def child_collection(name: str, parent: bpy.types.Collection) -> bpy.types.Collection:
    collection = bpy.data.collections.new(f"{PREFIX}_{name}")
    parent.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def material(name: str, color: tuple[float, float, float, float],
             metallic: float, roughness: float,
             emission: tuple[float, float, float, float] | None = None,
             emission_strength: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(f"{PREFIX}_{name}")
    mat.use_nodes = True
    mat.diffuse_color = color
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        strength_input = bsdf.inputs.get("Emission Strength")
        if emission_input is not None:
            emission_input.default_value = emission
        if strength_input is not None:
            strength_input.default_value = emission_strength
    return mat


def mesh_object(name: str, vertices: list[tuple[float, float, float]],
                faces: list[tuple[int, ...]], collection: bpy.types.Collection,
                mat: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{PREFIX}_{name}_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate(verbose=False)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(f"{PREFIX}_{name}", mesh)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def prism_xz(name: str, points: list[tuple[float, float]], depth: float,
             y_center: float, collection: bpy.types.Collection,
             mat: bpy.types.Material) -> bpy.types.Object:
    half = depth * 0.5
    count = len(points)
    vertices = [(x, y_center - half, z) for x, z in points]
    vertices.extend((x, y_center + half, z) for x, z in points)
    faces: list[tuple[int, ...]] = [tuple(reversed(range(count)))]
    faces.append(tuple(range(count, count * 2)))
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    return mesh_object(name, vertices, faces, collection, mat)


def select_only(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    # Blender can retain selection state on objects from another scene. The
    # glTF exporter otherwise includes the default Cube even though the active
    # generated scene does not contain it.
    for other in bpy.data.objects:
        if other == obj:
            continue
        try:
            other.select_set(False)
        except RuntimeError:
            pass
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_transform(obj: bpy.types.Object) -> None:
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def bevel(obj: bpy.types.Object, width: float, segments: int = 2,
          angle_degrees: float = 25.0) -> None:
    apply_transform(obj)
    modifier = obj.modifiers.new("HeroBevel", "BEVEL")
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(angle_degrees)
    modifier.width = width
    modifier.segments = segments
    modifier.affect = "EDGES"


def apply_modifiers(obj: bpy.types.Object) -> None:
    select_only(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def cylinder(name: str, radius: float, depth: float,
             location: tuple[float, float, float], collection: bpy.types.Collection,
             mat: bpy.types.Material, vertices: int = 24,
             rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
             scale: tuple[float, float, float] = (1.0, 1.0, 1.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = f"{PREFIX}_{name}"
    obj.data.name = f"{PREFIX}_{name}_Mesh"
    obj.scale = scale
    move_to_collection(obj, collection)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def ico(name: str, location: tuple[float, float, float],
        scale: tuple[float, float, float], collection: bpy.types.Collection,
        mat: bpy.types.Material, subdivisions: int = 2) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0,
                                         location=location)
    obj = bpy.context.object
    obj.name = f"{PREFIX}_{name}"
    obj.data.name = f"{PREFIX}_{name}_Mesh"
    obj.scale = scale
    move_to_collection(obj, collection)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def torus(name: str, major_radius: float, minor_radius: float, z: float,
          collection: bpy.types.Collection, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius,
                                    major_segments=24, minor_segments=6,
                                    location=(0.0, 0.0, z))
    obj = bpy.context.object
    obj.name = f"{PREFIX}_{name}"
    obj.data.name = f"{PREFIX}_{name}_Mesh"
    move_to_collection(obj, collection)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def join_parts(parts: list[bpy.types.Object], final_name: str,
               materials: list[bpy.types.Material]) -> bpy.types.Object:
    slot_by_name = {mat.name: index for index, mat in enumerate(materials)}
    for part in parts:
        if part.type != "MESH":
            continue
        apply_modifiers(part)
        intended = part.data.materials[0]
        part.data.materials.clear()
        for mat in materials:
            part.data.materials.append(mat)
        intended_index = slot_by_name[intended.name]
        for polygon in part.data.polygons:
            polygon.material_index = intended_index

    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = final_name
    result.data.name = f"{final_name}_Mesh"
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    select_only(result)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    apply_transform(result)
    return result


def create_blade(collection: bpy.types.Collection, steel: bpy.types.Material) -> bpy.types.Object:
    rings = [
        (SWORD_BLADE_BASE_Z, 0.082, 0.032),
        (0.26, 0.118, 0.038),
        (0.46, 0.142, 0.042),
        (0.76, 0.132, 0.042),
        (1.04, 0.112, 0.035),
        (1.27, 0.084, 0.028),
        (1.39, 0.048, 0.018),
    ]
    vertices: list[tuple[float, float, float]] = []
    for z, width, thickness in rings:
        vertices.extend([(-width * 0.5, 0.0, z), (0.0, -thickness * 0.5, z),
                         (width * 0.5, 0.0, z), (0.0, thickness * 0.5, z)])
    tip = len(vertices)
    vertices.append((0.0, 0.0, SWORD_BLADE_TIP_Z))
    faces: list[tuple[int, ...]] = [(3, 2, 1, 0)]
    for ring in range(len(rings) - 1):
        low = ring * 4
        high = (ring + 1) * 4
        for side in range(4):
            nxt = (side + 1) % 4
            faces.append((low + side, low + nxt, high + nxt, high + side))
    final = (len(rings) - 1) * 4
    for side in range(4):
        faces.append((final + side, final + (side + 1) % 4, tip))
    blade = mesh_object("SwordBlade", vertices, faces, collection, steel)
    bevel(blade, 0.0018, 2, 18.0)
    return blade


def build_sword(collection: bpy.types.Collection) -> bpy.types.Object:
    steel = material("MAT_Aegisfang_Steel", (0.29, 0.37, 0.46, 1.0), 0.96, 0.18)
    obsidian = material("MAT_Aegisfang_Obsidian", (0.018, 0.026, 0.050, 1.0), 0.58, 0.22)
    bronze = material("MAT_Aegisfang_Bronze", (0.47, 0.20, 0.055, 1.0), 0.88, 0.25)
    rune = material("MAT_Aegisfang_Rune", (0.015, 0.28, 0.46, 1.0), 0.42, 0.16,
                    (0.02, 0.62, 1.0, 1.0), 4.0)
    mats = [steel, obsidian, bronze, rune]
    parts: list[bpy.types.Object] = [create_blade(collection, steel)]

    spine_outline = [(-0.016, 0.18), (-0.023, 0.50), (-0.020, 0.89),
                     (-0.013, 1.23), (0.0, 1.38), (0.013, 1.23),
                     (0.020, 0.89), (0.023, 0.50), (0.016, 0.18)]
    for side in (-1.0, 1.0):
        parts.append(prism_xz(f"SwordSpine_{side:+.0f}", spine_outline, 0.006,
                              side * 0.020, collection, obsidian))

    guard_outline = [(-0.27, 0.105), (-0.23, 0.18), (-0.14, 0.20),
                     (-0.07, 0.155), (0.0, 0.135), (0.07, 0.155),
                     (0.14, 0.20), (0.23, 0.18), (0.27, 0.105),
                     (0.21, 0.070), (0.11, 0.082), (0.0, 0.105),
                     (-0.11, 0.082), (-0.21, 0.070)]
    guard = prism_xz("SwordCrescentGuard", guard_outline, 0.070, 0.0, collection, bronze)
    bevel(guard, 0.007, 3, 20.0)
    parts.append(guard)
    parts.append(ico("SwordGuardHeart", (0.0, -0.040, 0.115), (0.050, 0.025, 0.060),
                     collection, obsidian, 2))

    grip = cylinder("SwordGrip", 0.040, 0.32, (0.0, 0.0, -0.075), collection,
                    obsidian, 24, scale=(1.0, 0.82, 1.0))
    bevel(grip, 0.003, 2)
    parts.append(grip)
    for index in range(7):
        parts.append(torus(f"SwordGripRing_{index}", 0.0405, 0.0045,
                           -0.205 + index * 0.043, collection, bronze))
    pommel = ico("SwordPommel", (0.0, 0.0, -0.305), (0.078, 0.050, 0.075),
                 collection, bronze, 2)
    bevel(pommel, 0.002, 2)
    parts.append(pommel)
    parts.append(prism_xz("SwordPommelRune",
                          [(0.0, -0.350), (-0.020, -0.315), (0.0, -0.280), (0.020, -0.315)],
                          0.007, -0.052, collection, rune))

    rune_shapes = [
        [(-0.006, 0.43), (-0.020, 0.47), (0.0, 0.51), (0.020, 0.47), (0.006, 0.43)],
        [(-0.005, 0.71), (-0.018, 0.75), (0.0, 0.80), (0.018, 0.75), (0.005, 0.71)],
        [(-0.004, 0.99), (-0.014, 1.025), (0.0, 1.065), (0.014, 1.025), (0.004, 0.99)],
    ]
    for side in (-1.0, 1.0):
        for index, shape in enumerate(rune_shapes):
            parts.append(prism_xz(f"SwordRune_{side:+.0f}_{index}", shape, 0.005,
                                  side * 0.024, collection, rune))

    sword = join_parts(parts, SWORD_NAME, mats)
    sword["asset_type"] = "weapon"
    sword["weapon_kind"] = "long_sword"
    sword["weapon_name"] = "Aegis Fang"
    sword["blade_base_godot_y"] = SWORD_BLADE_BASE_Z
    sword["blade_tip_godot_y"] = SWORD_BLADE_TIP_Z
    sword["grip_origin"] = "world_origin"
    sword["forward_godot"] = "-Z"
    return sword


def build_shield(collection: bpy.types.Collection) -> bpy.types.Object:
    bronze = material("MAT_TitanAegis_Bronze", (0.46, 0.17, 0.038, 1.0), 0.90, 0.27)
    obsidian = material("MAT_TitanAegis_Obsidian", (0.020, 0.030, 0.055, 1.0), 0.60, 0.23)
    crimson = material("MAT_TitanAegis_Crimson", (0.31, 0.018, 0.022, 1.0), 0.20, 0.36)
    rune = material("MAT_TitanAegis_Rune", (0.015, 0.30, 0.48, 1.0), 0.40, 0.15,
                    (0.02, 0.65, 1.0, 1.0), 4.5)
    mats = [bronze, obsidian, crimson, rune]
    parts: list[bpy.types.Object] = []

    outer = [(-0.30, -0.54), (-0.43, -0.35), (-0.45, 0.18), (-0.36, 0.47),
             (-0.17, 0.56), (0.0, 0.53), (0.17, 0.56), (0.36, 0.47),
             (0.45, 0.18), (0.43, -0.35), (0.30, -0.54), (0.0, -0.59)]
    rim = prism_xz("ShieldOuterRim", outer, 0.095, 0.0, collection, bronze)
    bevel(rim, 0.016, 3, 24.0)
    parts.append(rim)
    inner = [(x * 0.88, z * 0.88 + 0.01) for x, z in outer]
    plate = prism_xz("ShieldInnerPlate", inner, 0.030, -0.060, collection, obsidian)
    bevel(plate, 0.012, 2, 25.0)
    parts.append(plate)

    # Four cardinal crimson panels establish a readable 60/30/10 hierarchy.
    panels = [
        [(-0.31, 0.08), (-0.11, 0.37), (0.0, 0.40), (0.0, 0.09)],
        [(0.0, 0.09), (0.0, 0.40), (0.11, 0.37), (0.31, 0.08)],
        [(-0.30, 0.01), (-0.09, -0.37), (0.0, -0.46), (0.0, -0.08)],
        [(0.0, -0.08), (0.0, -0.46), (0.09, -0.37), (0.30, 0.01)],
    ]
    for index, points in enumerate(panels):
        panel = prism_xz(f"ShieldCrimsonPanel_{index}", points, 0.010, -0.079,
                         collection, crimson)
        bevel(panel, 0.005, 2, 28.0)
        parts.append(panel)

    # A shallow metallic boss and angular omega symbol form the identity feature.
    boss = ico("ShieldBoss", (0.0, -0.120, 0.0), (0.17, 0.072, 0.17),
               collection, bronze, 3)
    parts.append(boss)
    omega_left = [(-0.25, 0.19), (-0.19, 0.30), (-0.08, 0.35),
                  (-0.055, 0.29), (-0.14, 0.23), (-0.16, 0.10)]
    omega_right = [(-x, z) for x, z in reversed(omega_left)]
    for index, points in enumerate((omega_left, omega_right)):
        symbol = prism_xz(f"ShieldOmega_{index}", points, 0.014, -0.105,
                          collection, bronze)
        bevel(symbol, 0.006, 2, 24.0)
        parts.append(symbol)

    # Cyan chevrons stay sparse and frame the boss at gameplay distance.
    chevrons = [
        [(-0.24, 0.42), (-0.13, 0.47), (-0.06, 0.41), (-0.15, 0.43)],
        [(0.06, 0.41), (0.13, 0.47), (0.24, 0.42), (0.15, 0.43)],
        [(-0.22, -0.39), (-0.11, -0.47), (-0.055, -0.40), (-0.15, -0.43)],
        [(0.055, -0.40), (0.11, -0.47), (0.22, -0.39), (0.15, -0.43)],
    ]
    for index, points in enumerate(chevrons):
        parts.append(prism_xz(f"ShieldRune_{index}", points, 0.007, -0.108,
                              collection, rune))

    # Rear grip and arm brace are visible in inspection views but remain one mesh.
    grip = cylinder("ShieldGrip", 0.028, 0.30, (0.0, 0.115, 0.0), collection,
                    obsidian, 20, rotation=(0.0, math.pi * 0.5, 0.0),
                    scale=(1.0, 1.0, 0.88))
    parts.append(grip)
    for x in (-0.23, 0.23):
        brace = cylinder(f"ShieldBrace_{x:+.0f}", 0.020, 0.25, (x, 0.092, 0.0),
                         collection, bronze, 16, rotation=(math.pi * 0.5, 0.0, 0.0),
                         scale=(1.0, 1.0, 0.82))
        parts.append(brace)

    shield = join_parts(parts, SHIELD_NAME, mats)
    shield["asset_type"] = "equipment"
    shield["equipment_kind"] = "shield"
    shield["equipment_name"] = "Titan Aegis"
    shield["grip_origin"] = "world_origin"
    shield["face_forward_godot"] = "-Z"
    return shield


def triangle_count(obj: bpy.types.Object) -> int:
    return sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons)


def validate(obj: bpy.types.Object, expected_name: str, max_tris: int,
             max_materials: int) -> dict[str, object]:
    if obj.name != expected_name or obj.type != "MESH":
        raise RuntimeError(f"Invalid final object: {obj.name} ({obj.type})")
    if obj.location.length > 1e-6 or obj.scale != Vector((1.0, 1.0, 1.0)):
        raise RuntimeError(f"{obj.name} does not have an identity grip transform")
    triangles = triangle_count(obj)
    if triangles > max_tris:
        raise RuntimeError(f"{obj.name} has {triangles} triangles; budget is {max_tris}")
    if len(obj.data.materials) > max_materials:
        raise RuntimeError(f"{obj.name} has too many materials")
    dimensions = [round(value, 4) for value in obj.dimensions]
    print(f"[HERO ARSENAL] {obj.name}: {triangles} tris, {len(obj.data.materials)} materials, {dimensions} m")
    return {"object": obj.name, "dimensions_m_blender_xyz": dimensions,
            "triangles": triangles, "materials": len(obj.data.materials)}


def export_glb(obj: bpy.types.Object, path: Path) -> None:
    select_only(obj)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              use_active_scene=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False,
                              export_animations=False, export_extras=True)


def point_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_preview(scene: bpy.types.Scene, collection: bpy.types.Collection,
                  sword: bpy.types.Object, shield: bpy.types.Object) -> None:
    sword.hide_render = True
    shield.hide_render = True
    sword_preview = sword.copy()
    sword_preview.data = sword.data
    collection.objects.link(sword_preview)
    sword_preview.name = f"{PREFIX}_PreviewSword"
    sword_preview.hide_render = False
    sword_preview.location = (-0.48, 0.0, 0.38)
    sword_preview.rotation_euler = (math.radians(-4.0), 0.0, math.radians(-12.0))
    shield_preview = shield.copy()
    shield_preview.data = shield.data
    collection.objects.link(shield_preview)
    shield_preview.name = f"{PREFIX}_PreviewShield"
    shield_preview.hide_render = False
    shield_preview.location = (0.48, 0.05, 0.62)
    shield_preview.rotation_euler = (math.radians(2.0), 0.0, math.radians(5.0))

    floor_mat = material("MAT_PreviewFloor", (0.012, 0.018, 0.030, 1.0), 0.25, 0.30)
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = f"{PREFIX}_PreviewFloor"
    move_to_collection(floor, collection)
    floor.data.materials.append(floor_mat)

    for name, location, energy, color, size in (
        ("Key", (-2.2, -2.4, 2.8), 720.0, (0.62, 0.82, 1.0), 1.5),
        ("WarmRim", (2.1, 0.8, 2.1), 900.0, (1.0, 0.28, 0.06), 1.1),
        ("Fill", (0.0, -1.0, 0.8), 260.0, (0.18, 0.45, 1.0), 1.4),
    ):
        light_data = bpy.data.lights.new(f"{PREFIX}_LGT_{name}", "AREA")
        light_data.energy = energy
        light_data.color = color
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(f"{PREFIX}_LGT_{name}", light_data)
        collection.objects.link(light)
        light.location = location
        point_at(light, (0.0, 0.0, 0.75))

    camera_data = bpy.data.cameras.new(f"{PREFIX}_PreviewCamera")
    camera = bpy.data.objects.new(f"{PREFIX}_PreviewCamera", camera_data)
    collection.objects.link(camera)
    camera.location = (2.25, -4.1, 1.65)
    camera_data.lens = 62.0
    point_at(camera, (0.0, 0.0, 0.80))
    scene.camera = camera

    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new(f"{PREFIX}_World")
        scene.world.use_nodes = True
    scene.world.color = (0.004, 0.007, 0.016)
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.004, 0.007, 0.018, 1.0)
    background.inputs["Strength"].default_value = 0.18
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass


def main() -> None:
    print(f"[HERO ARSENAL] Blender {bpy.app.version_string}; deterministic seed {SEED}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    SWORD_GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    clear_previous_generation()
    scene, root = make_scene()
    asset_collection = child_collection("Assets", root)
    preview_collection = child_collection("Preview", root)
    sword = build_sword(asset_collection)
    shield = build_shield(asset_collection)
    sword_report = validate(sword, SWORD_NAME, 8000, 4)
    shield_report = validate(shield, SHIELD_NAME, 8000, 4)
    export_glb(sword, SWORD_GLB_PATH)
    export_glb(shield, SHIELD_GLB_PATH)

    manifest = {
        "asset": "player_hero_arsenal",
        "status": "PASS",
        "quality": "V2_HERO",
        "units": "meters",
        "forward_blender": "-Y",
        "forward_godot": "-Z",
        "identity": "long runic sword and tapered titan shield with bronze, obsidian, crimson and cyan accents",
        "sword": sword_report,
        "shield": shield_report,
        "sword_contact_segment_godot_y": [SWORD_BLADE_BASE_Z, SWORD_BLADE_TIP_Z],
        "collision": "visual equipment only; player combat uses authored swept blade markers and directional shield block",
        "textures_packed": False,
        "materials_embedded": True,
        "outputs": [
            SWORD_GLB_PATH.relative_to(PROJECT_ROOT).as_posix(),
            SHIELD_GLB_PATH.relative_to(PROJECT_ROOT).as_posix(),
        ],
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    setup_preview(scene, preview_collection, sword, shield)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    print(f"[HERO ARSENAL] Sword GLB: {SWORD_GLB_PATH}")
    print(f"[HERO ARSENAL] Shield GLB: {SHIELD_GLB_PATH}")
    print(f"[HERO ARSENAL] Preview: {PREVIEW_PATH}")
    print("[HERO ARSENAL] PASS")


if __name__ == "__main__":
    main()
