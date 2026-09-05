"""Create an editable Noon-on-UAL1 rigging draft in Blender.

The source Noon model is an unrigged, loose A-pose GLB.  This script:

1. imports the project's canonical UAL1 Standard armature and actions;
2. imports Noon and applies its hierarchy transforms;
3. scales Noon to the UAL1 mannequin and rotates its disconnected arm/hand
   islands into an approximate T-pose;
4. transfers the UAL1 mannequin weights to the body and clothing;
5. marks the two long garment panels for an optional later cloth pass;
6. saves an editable .blend and renders rest/animation previews.

This is deliberately an authoring draft.  Automatic weight transfer always
needs visual checking around shoulders, armpits, hips, fingers, and garments.

Run from the project root (PowerShell):

    & "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" `
      --background --python ".\\tools\\blender\\noon_ual1\\rig_noon_to_ual1.py"

Override the source without editing this file:

    $env:HOPLITE_NOON_GLB = "D:\\models\\noon.glb"

The script clears the currently open Blender scene.  It never edits either
source GLB and writes only inside this script's ``output`` directory.
"""

from __future__ import annotations

import json
import math
import os
from collections import deque
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


# -----------------------------------------------------------------------------
# Editable configuration
# -----------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
OUTPUT_DIR = SCRIPT_DIR / "output"

UAL1_GLB = PROJECT_ROOT / "assets" / "runtime" / "ual1" / "UAL1_Standard.glb"
DEFAULT_NOON_GLB = PROJECT_ROOT.parent / "p-0r_noon.glb"
NOON_GLB = Path(os.environ.get("HOPLITE_NOON_GLB", DEFAULT_NOON_GLB))

BLEND_PATH = OUTPUT_DIR / "noon_ual1_autorig_draft.blend"
REST_PREVIEW_PATH = OUTPUT_DIR / "noon_ual1_rest_preview.png"
ANIM_PREVIEW_PATH = OUTPUT_DIR / "noon_ual1_animation_preview.png"
REPORT_PATH = OUTPUT_DIR / "noon_ual1_report.json"

GENERATED_COLLECTION = "GEN_NOON_UAL1"
RIG_NAME = "UAL1_Rig"
BODY_NAME = "Noon_Body"
CLOTHING_NAME = "Noon_Clothing"
REFERENCE_NAME = "UAL1_WeightReference"

# A tiny shrink keeps the imported character just inside the UAL1 height.
HEIGHT_FACTOR = 0.997
MAX_WEIGHTS_PER_VERTEX = 4
WEIGHT_CLEAN_THRESHOLD = 0.001

# Long disconnected garment panels discovered in the source mesh are marked
# when they reach below this fraction of the character height.
CLOTH_PANEL_MIN_HEIGHT_FRACTION = 0.45
CLOTH_PANEL_LOW_Z_FRACTION = 0.32
CLOTH_PIN_TOP_FRACTION = 0.69

# Animation used for the second preview.  Falls back to the first available
# action if the imported library names differ in a future UAL1 revision.
PREVIEW_ACTION_CANDIDATES = ("Idle_Loop", "Walk_Loop", "A_TPose")


# -----------------------------------------------------------------------------
# Generic scene helpers
# -----------------------------------------------------------------------------

def log(message: str) -> None:
    print(f"[NOON_UAL1] {message}")


def reset_scene() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for datablocks in (
        bpy.data.armatures,
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)

    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)


def make_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def import_glb(path: Path) -> list[bpy.types.Object]:
    if not path.is_file():
        raise FileNotFoundError(f"Missing GLB: {path}")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    log(f"Imported {path.name}: {len(imported)} objects")
    return imported


def object_world_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def combined_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    if not points:
        raise RuntimeError("Cannot calculate empty bounds")
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def flatten_mesh_transform(obj: bpy.types.Object) -> None:
    """Bake the complete imported hierarchy into mesh coordinates."""
    select_only(obj)
    if obj.parent is not None:
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def select_only(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def set_object_visibility(obj: bpy.types.Object, visible: bool) -> None:
    obj.hide_render = not visible
    obj.hide_set(not visible)
    obj.hide_viewport = not visible


def triangles(obj: bpy.types.Object) -> int:
    return sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)


# -----------------------------------------------------------------------------
# Geometry analysis and approximate A-pose -> T-pose conversion
# -----------------------------------------------------------------------------

def connected_components(mesh: bpy.types.Mesh) -> list[list[int]]:
    adjacency: list[list[int]] = [[] for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        adjacency[a].append(b)
        adjacency[b].append(a)

    remaining = set(range(len(mesh.vertices)))
    components: list[list[int]] = []
    while remaining:
        start = next(iter(remaining))
        remaining.remove(start)
        queue = deque([start])
        component = [start]
        while queue:
            current = queue.popleft()
            for neighbor in adjacency[current]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
                    component.append(neighbor)
        components.append(component)
    return sorted(components, key=len, reverse=True)


def component_bounds(mesh: bpy.types.Mesh, component: list[int]) -> tuple[Vector, Vector]:
    coordinates = [mesh.vertices[index].co for index in component]
    return (
        Vector((min(co.x for co in coordinates), min(co.y for co in coordinates), min(co.z for co in coordinates))),
        Vector((max(co.x for co in coordinates), max(co.y for co in coordinates), max(co.z for co in coordinates))),
    )


def component_center(mesh: bpy.types.Mesh, component: list[int]) -> Vector:
    result = Vector((0.0, 0.0, 0.0))
    for index in component:
        result += mesh.vertices[index].co
    return result / max(1, len(component))


def find_arm_islands(body: bpy.types.Object, side: int, character_height: float) -> tuple[list[int], Vector, Vector]:
    """Return arm+hand indices, inferred shoulder pivot, and hand center.

    Noon stores each arm and hand as separate disconnected components.  The
    dimension tests intentionally use fractions of height, so the method still
    works after the global scaling pass.
    """
    mesh = body.data
    candidate_parts: list[tuple[list[int], Vector, Vector]] = []
    for component in connected_components(mesh):
        minimum, maximum = component_bounds(mesh, component)
        signed_out = maximum.x if side > 0 else -minimum.x
        signed_in = minimum.x if side > 0 else -maximum.x
        if signed_out > character_height * 0.16:
            log(
                f"Arm scan {side:+d}: verts={len(component)} "
                f"x=({minimum.x:.3f},{maximum.x:.3f}) "
                f"z=({minimum.z:.3f},{maximum.z:.3f})"
            )
        if (
            signed_out > character_height * 0.19
            and signed_in > character_height * 0.045
            and maximum.z > character_height * 0.48
            and minimum.z < character_height * 0.90
        ):
            candidate_parts.append((component, minimum, maximum))

    if len(candidate_parts) < 2:
        raise RuntimeError(f"Could not identify both arm islands for side {side:+d}")

    # The outermost component is the hand; the larger proximal component is arm.
    hand_entry = max(
        candidate_parts,
        key=lambda entry: max(abs(entry[1].x), abs(entry[2].x)),
    )
    arm_entry = max(
        (entry for entry in candidate_parts if entry is not hand_entry),
        key=lambda entry: len(entry[0]),
    )
    arm_component = arm_entry[0]
    hand_component = hand_entry[0]

    # Average the innermost 12% of arm vertices to estimate the shoulder joint.
    by_inward = sorted(
        arm_component,
        key=lambda index: side * mesh.vertices[index].co.x,
    )
    pivot_count = max(12, int(len(by_inward) * 0.12))
    pivot = component_center(mesh, by_inward[:pivot_count])
    hand_center = component_center(mesh, hand_component)
    return arm_component + hand_component, pivot, hand_center


def repose_arms_to_t_pose(
    body: bpy.types.Object,
    rig: bpy.types.Object,
    character_height: float,
) -> dict[str, float]:
    rotations: dict[str, float] = {}
    for side, label in ((1, "L"), (-1, "R")):
        indices, pivot, hand_center = find_arm_islands(body, side, character_height)
        direction = hand_center - pivot
        angle = math.atan2(direction.z, direction.x)
        if side < 0:
            # For the negative-X arm, a horizontal target points toward -X.
            angle = math.atan2(direction.z, -direction.x) * -1.0

        rotation = Matrix.Rotation(angle, 4, "Y")
        target_pivot = rig.matrix_world @ rig.data.bones[f"DEF-upper_arm.{label}"].head_local
        pivot_correction = target_pivot - pivot
        for index in indices:
            vertex = body.data.vertices[index]
            vertex.co = pivot + rotation @ (vertex.co - pivot) + pivot_correction

        rotations[label] = math.degrees(angle)
        log(
            f"Reposed arm {label}: {math.degrees(angle):.2f} degrees; "
            f"shoulder correction={tuple(round(value, 3) for value in pivot_correction)}"
        )

    body.data.update()
    return rotations


def align_noon_to_reference(
    body: bpy.types.Object,
    clothing: bpy.types.Object,
    reference: bpy.types.Object,
) -> tuple[float, float]:
    source_min, source_max = combined_bounds([body, clothing])
    ref_min, ref_max = object_world_bounds(reference)
    source_height = source_max.z - source_min.z
    ref_height = ref_max.z - ref_min.z
    scale = (ref_height / source_height) * HEIGHT_FACTOR

    source_center = (source_min + source_max) * 0.5
    ref_center = (ref_min + ref_max) * 0.5
    translation = Vector((
        ref_center.x - source_center.x * scale,
        ref_center.y - source_center.y * scale,
        ref_min.z - source_min.z * scale,
    ))

    for obj in (body, clothing):
        for vertex in obj.data.vertices:
            vertex.co = vertex.co * scale + translation
        obj.data.update()

    return scale, ref_height


# -----------------------------------------------------------------------------
# Weight transfer and garment authoring marks
# -----------------------------------------------------------------------------

def create_matching_groups(target: bpy.types.Object, source: bpy.types.Object) -> None:
    for group in list(target.vertex_groups):
        target.vertex_groups.remove(group)
    for source_group in source.vertex_groups:
        target.vertex_groups.new(name=source_group.name)


def transfer_weights(
    source: bpy.types.Object,
    target: bpy.types.Object,
    rig: bpy.types.Object,
) -> None:
    create_matching_groups(target, source)
    modifier = target.modifiers.new(name="UAL1_WeightTransfer", type="DATA_TRANSFER")
    modifier.object = source
    modifier.use_vert_data = True
    modifier.data_types_verts = {"VGROUP_WEIGHTS"}
    modifier.vert_mapping = "POLYINTERP_NEAREST"
    modifier.layers_vgroup_select_src = "ALL"
    modifier.layers_vgroup_select_dst = "NAME"

    select_only(target)
    bpy.ops.object.modifier_apply(modifier=modifier.name)

    deform_names = {bone.name for bone in rig.data.bones if bone.use_deform}
    for group in list(target.vertex_groups):
        if group.name not in deform_names:
            target.vertex_groups.remove(group)

    select_only(target)
    bpy.ops.object.vertex_group_clean(
        group_select_mode="ALL",
        limit=WEIGHT_CLEAN_THRESHOLD,
        keep_single=True,
    )
    bpy.ops.object.vertex_group_limit_total(
        group_select_mode="ALL",
        limit=MAX_WEIGHTS_PER_VERTEX,
    )
    bpy.ops.object.vertex_group_normalize_all(
        group_select_mode="ALL",
        lock_active=False,
    )


def mark_cloth_candidates(clothing: bpy.types.Object, character_height: float) -> dict[str, int]:
    panel_indices: list[int] = []
    for component in connected_components(clothing.data):
        minimum, maximum = component_bounds(clothing.data, component)
        height = maximum.z - minimum.z
        if (
            height > character_height * CLOTH_PANEL_MIN_HEIGHT_FRACTION
            and minimum.z < character_height * CLOTH_PANEL_LOW_Z_FRACTION
        ):
            panel_indices.extend(component)

    panel_group = clothing.vertex_groups.get("Cloth_Dynamic_Candidate")
    if panel_group is None:
        panel_group = clothing.vertex_groups.new(name="Cloth_Dynamic_Candidate")
    if panel_indices:
        panel_group.add(panel_indices, 1.0, "REPLACE")

    pin_indices = [
        index
        for index in panel_indices
        if clothing.data.vertices[index].co.z > character_height * CLOTH_PIN_TOP_FRACTION
    ]
    pin_group = clothing.vertex_groups.get("Cloth_Pin_Top")
    if pin_group is None:
        pin_group = clothing.vertex_groups.new(name="Cloth_Pin_Top")
    if pin_indices:
        pin_group.add(pin_indices, 1.0, "REPLACE")

    return {"panel_vertices": len(panel_indices), "pin_vertices": len(pin_indices)}


def stabilize_cloth_panels(clothing: bpy.types.Object, rig: bpy.types.Object) -> None:
    """Keep the long apron panels attached to the pelvis in the draft.

    Nearest-surface transfer makes the two sides inherit different thighs.  In
    wide leg poses that turns a continuous apron into a large triangle.  A hip
    attachment is intentionally conservative and provides a stable base for
    either hand painting, cloth bones, or a separate SoftBody3D panel later.
    """
    panel_group = clothing.vertex_groups.get("Cloth_Dynamic_Candidate")
    hips_group = clothing.vertex_groups.get("DEF-hips")
    if panel_group is None or hips_group is None:
        return

    panel_indices = [
        vertex.index
        for vertex in clothing.data.vertices
        if any(group.group == panel_group.index and group.weight > 0.5 for group in vertex.groups)
    ]
    deform_groups = [
        group
        for group in clothing.vertex_groups
        if group.name in rig.data.bones and rig.data.bones[group.name].use_deform
    ]
    for group in deform_groups:
        group.remove(panel_indices)
    hips_group.add(panel_indices, 1.0, "REPLACE")


def bind_to_armature(mesh_object: bpy.types.Object, rig: bpy.types.Object) -> None:
    mesh_object.parent = rig
    mesh_object.matrix_parent_inverse = rig.matrix_world.inverted()
    modifier = mesh_object.modifiers.new(name="UAL1_Armature", type="ARMATURE")
    modifier.object = rig
    modifier.use_deform_preserve_volume = True


def count_unweighted_vertices(obj: bpy.types.Object, rig: bpy.types.Object) -> int:
    deform_indices = {
        group.index
        for group in obj.vertex_groups
        if group.name in rig.data.bones and rig.data.bones[group.name].use_deform
    }
    unweighted = 0
    for vertex in obj.data.vertices:
        total = sum(group.weight for group in vertex.groups if group.group in deform_indices)
        if total <= 1e-6:
            unweighted += 1
    return unweighted


# -----------------------------------------------------------------------------
# Preview and validation
# -----------------------------------------------------------------------------

def add_preview_stage(objects: list[bpy.types.Object], collection: bpy.types.Collection) -> None:
    minimum, maximum = combined_bounds(objects)
    center = (minimum + maximum) * 0.5
    extent = maximum - minimum
    radius = max(extent) * 0.72

    camera_data = bpy.data.cameras.new("NoonPreviewCamera")
    camera = bpy.data.objects.new("NoonPreviewCamera", camera_data)
    collection.objects.link(camera)
    camera.location = center + Vector((0.0, -radius * 3.1, radius * 0.08))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(extent.x, extent.z) * 1.16
    bpy.context.scene.camera = camera

    lights = (
        ("NoonKey", Vector((-radius * 1.7, -radius * 2.0, radius * 2.4)), 1100.0, radius * 2.0),
        ("NoonFill", Vector((radius * 1.8, -radius * 0.7, radius * 1.0)), 650.0, radius * 1.5),
        ("NoonRim", Vector((0.0, radius * 1.8, radius * 2.0)), 850.0, radius * 1.4),
    )
    for name, offset, energy, size in lights:
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        collection.objects.link(light)
        light.location = center + offset
        light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.025, 0.028, 0.035)


def choose_preview_action() -> bpy.types.Action | None:
    for candidate in PREVIEW_ACTION_CANDIDATES:
        action = bpy.data.actions.get(candidate)
        if action is not None:
            return action
    return next(iter(bpy.data.actions), None)


def render_previews(rig: bpy.types.Object) -> str | None:
    scene = bpy.context.scene
    if rig.animation_data is None:
        rig.animation_data_create()

    rig.animation_data.action = None
    scene.frame_set(0)
    scene.render.filepath = str(REST_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    action = choose_preview_action()
    if action is None:
        log("WARNING: no imported UAL1 action available for animation preview")
        return None

    rig.animation_data.action = action
    start, end = action.frame_range
    preview_frame = round(start + (end - start) * 0.35)
    scene.frame_start = int(math.floor(start))
    scene.frame_end = int(math.ceil(end))
    scene.frame_set(preview_frame)
    scene.render.filepath = str(ANIM_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    scene.frame_set(int(start))
    return action.name


def rename_materials(obj: bpy.types.Object, prefix: str) -> None:
    for index, slot in enumerate(obj.material_slots):
        if slot.material is not None:
            slot.material.name = f"{prefix}_{index:02d}_{slot.material.name}"


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    log(f"Blender {bpy.app.version_string}")
    log(f"UAL1 source: {UAL1_GLB}")
    log(f"Noon source: {NOON_GLB}")

    reset_scene()
    generated = make_collection(GENERATED_COLLECTION)

    ual_objects = import_glb(UAL1_GLB)
    rigs = [obj for obj in ual_objects if obj.type == "ARMATURE"]
    if len(rigs) != 1:
        raise RuntimeError(f"Expected one UAL1 armature, found {len(rigs)}")
    rig = rigs[0]
    rig.name = RIG_NAME
    rig.data.name = f"{RIG_NAME}_Data"

    reference_candidates = [
        obj
        for obj in ual_objects
        if obj.type == "MESH" and len(obj.vertex_groups) > 20
    ]
    if not reference_candidates:
        raise RuntimeError("Could not find the skinned UAL1 mannequin")
    for candidate in reference_candidates:
        candidate_min, candidate_max = object_world_bounds(candidate)
        log(
            f"UAL1 mesh candidate {candidate.name}: verts={len(candidate.data.vertices)} "
            f"height={candidate_max.z - candidate_min.z:.3f}"
        )
    reference = next(
        (obj for obj in reference_candidates if obj.name == "Mannequin"),
        max(reference_candidates, key=lambda obj: len(obj.data.vertices)),
    )
    reference.name = REFERENCE_NAME
    for obj in ual_objects:
        move_to_collection(obj, generated)

    noon_objects = import_glb(NOON_GLB)
    noon_meshes = [obj for obj in noon_objects if obj.type == "MESH"]
    if len(noon_meshes) != 2:
        raise RuntimeError(f"Expected two Noon meshes, found {len(noon_meshes)}")

    # Body is the wider mesh.  Clothing is tall, but much narrower.
    noon_meshes.sort(key=lambda obj: object_world_bounds(obj)[1].x - object_world_bounds(obj)[0].x, reverse=True)
    body, clothing = noon_meshes
    body.name = BODY_NAME
    body.data.name = f"{BODY_NAME}_Mesh"
    clothing.name = CLOTHING_NAME
    clothing.data.name = f"{CLOTHING_NAME}_Mesh"

    for obj in (body, clothing):
        pre_min, pre_max = object_world_bounds(obj)
        log(
            f"Before flatten {obj.name}: height={pre_max.z - pre_min.z:.3f}, "
            f"world_scale={tuple(round(value, 5) for value in obj.matrix_world.to_scale())}"
        )
        flatten_mesh_transform(obj)
        post_min, post_max = object_world_bounds(obj)
        log(f"After flatten {obj.name}: height={post_max.z - post_min.z:.3f}")
        move_to_collection(obj, generated)
    for obj in noon_objects:
        if obj not in (body, clothing):
            bpy.data.objects.remove(obj, do_unlink=True)

    scale, reference_height = align_noon_to_reference(body, clothing, reference)
    log(f"Alignment scale={scale:.5f}, reference height={reference_height:.3f} m")
    arm_rotations = repose_arms_to_t_pose(body, rig, reference_height)

    transfer_weights(reference, body, rig)
    transfer_weights(body, clothing, rig)
    cloth_marks = mark_cloth_candidates(clothing, reference_height)
    stabilize_cloth_panels(clothing, rig)
    bind_to_armature(body, rig)
    bind_to_armature(clothing, rig)

    rename_materials(body, "NoonBody")
    rename_materials(clothing, "NoonCloth")
    for obj in (body, clothing):
        for polygon in obj.data.polygons:
            polygon.use_smooth = True

    # The mannequin remains in the .blend as a hidden weight-paint reference.
    set_object_visibility(reference, False)
    reference.display_type = "WIRE"
    for obj in ual_objects:
        if obj not in (rig, reference):
            set_object_visibility(obj, False)

    set_object_visibility(body, True)
    set_object_visibility(clothing, True)
    rig.show_in_front = True
    rig.data.display_type = "STICK"
    rig.display.show_shadows = False

    add_preview_stage([body, clothing], generated)
    preview_action = render_previews(rig)
    for action in bpy.data.actions:
        action.use_fake_user = True

    body_unweighted = count_unweighted_vertices(body, rig)
    clothing_unweighted = count_unweighted_vertices(clothing, rig)
    report = {
        "status": "DRAFT_REQUIRES_MANUAL_WEIGHT_REVIEW",
        "blender": bpy.app.version_string,
        "sources": {"ual1": str(UAL1_GLB), "noon": str(NOON_GLB)},
        "outputs": {
            "blend": str(BLEND_PATH),
            "rest_preview": str(REST_PREVIEW_PATH),
            "animation_preview": str(ANIM_PREVIEW_PATH),
        },
        "alignment": {
            "uniform_scale": scale,
            "reference_height_m": reference_height,
            "arm_rotations_degrees": arm_rotations,
        },
        "rig": {
            "name": rig.name,
            "bones": len(rig.data.bones),
            "actions": len(bpy.data.actions),
            "preview_action": preview_action,
        },
        "meshes": {
            "body": {
                "vertices": len(body.data.vertices),
                "triangles": triangles(body),
                "materials": len(body.material_slots),
                "vertex_groups": len(body.vertex_groups),
                "unweighted_vertices": body_unweighted,
            },
            "clothing": {
                "vertices": len(clothing.data.vertices),
                "triangles": triangles(clothing),
                "materials": len(clothing.material_slots),
                "vertex_groups": len(clothing.vertex_groups),
                "unweighted_vertices": clothing_unweighted,
                **cloth_marks,
            },
        },
        "manual_review": [
            "shoulders and armpits",
            "elbows and wrists",
            "hips and upper legs",
            "finger weights",
            "clothing/body intersections",
            "long garment panels before any SoftBody3D conversion",
        ],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")

    # Save in rest pose so opening the file starts from the useful correction state.
    if rig.animation_data is not None:
        rig.animation_data.action = None
    bpy.context.scene.frame_set(0)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH), compress=True)

    log(f"Body: {triangles(body)} tris, {body_unweighted} unweighted vertices")
    log(f"Clothing: {triangles(clothing)} tris, {clothing_unweighted} unweighted vertices")
    log(f"Cloth marks: {cloth_marks}")
    log(f"Actions: {len(bpy.data.actions)}; preview={preview_action}")
    log(f"Blend: {BLEND_PATH}")
    log(f"Report: {REPORT_PATH}")
    if body_unweighted or clothing_unweighted:
        log("WARNING: unweighted vertices remain; inspect the report")
    log("PASS (authoring draft; manual deformation review is still required)")


if __name__ == "__main__":
    main()
