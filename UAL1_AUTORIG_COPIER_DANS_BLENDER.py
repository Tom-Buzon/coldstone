"""Assistant de remplacement d'un rig humanoide par le rig UAL1.

Ce fichier est autonome : copie-colle-le dans Blender > Scripting > New,
puis clique sur Run Script. Le panneau apparait dans Vue 3D > N > UAL1 Rig.

Nouveau processus (sans transfert de poids par proximite) :

1. Le personnage est deja importe avec son rig et ses bons poids.
2. Le script importe le mannequin, le rig et les 46 actions UAL1 dans la scene.
3. Un controle unique permet d'aligner globalement le personnage sur UAL1.
4. Les proportions UAL1 peuvent etre adaptees automatiquement aux articulations
   identifiees de l'ancien rig, sans recopier son eventuelle A-pose.
5. L'ancien rig est ensuite pose pour approcher la T-pose UAL1 personnalisee.
6. A la validation, la pose visible est figee, les groupes de poids de l'ancien
   rig sont remappes vers les 53 os UAL1, puis l'ancien rig est supprime.

Pour un mesh sans rig, il peut aussi creer un metarig Rigify Basic temporaire,
le pre-ajuster, calculer des poids automatiques, puis reprendre le meme flux.
Rigify est active pour la session mais aucun package externe n'est requis.

Le script reconnait directement les noms UAL1, Mixamo et les principaux noms
humanoides Unreal/generiques. Teste avec Blender 5.2 LTS; l'API utilisee reste
compatible Blender 4.2+ lorsque Rigify y est disponible.
"""

from __future__ import annotations

import json
from pathlib import Path
import re
from statistics import median
from typing import Iterable

import bpy
from bpy.props import BoolProperty, EnumProperty, StringProperty
from mathutils import Matrix, Vector


# -----------------------------------------------------------------------------
# Configuration et contrat UAL1
# -----------------------------------------------------------------------------

TOOL_COLLECTION = "UAL1_AUTORIG_GUIDE"
SCRIPT_VERSION = "2026-08-30.2"
FIT_ROOT_NAME = "UAL1_PERSONNAGE_A_AJUSTER"
RIG_NAME = "UAL1_Rig"
REFERENCE_NAME = "UAL1_Gabarit"
ARMATURE_MODIFIER_NAME = "UAL1_Armature"

GENERATED_TAG = "ual1_autorig_generated"
FINAL_RIG_TAG = "ual1_autorig_final_rig"
CHARACTER_TAG = "ual1_autorig_character"
OLD_RIG_TAG = "ual1_autorig_old_rig"
PROPORTIONS_FITTED_TAG = "ual1_autorig_proportions_fitted"
ORIGINAL_REST_PROP = "ual1_autorig_original_rest"
TEMP_RIGIFY_TAG = "ual1_autorig_temp_rigify"
TEMP_RIGIFY_NAME = "UAL1_Rigify_Basic_Temp"

MAX_WEIGHTS = 4
WEIGHT_CLEAN_LIMIT = 0.001

RIGID_ATTACHMENT_ITEMS = (
    ("spine", "Bassin / ceinture", "Equipement porte a la taille; devient DEF-hips dans UAL1"),
    ("spine.001", "Ventre", "Equipement fixe au bas du torse"),
    ("spine.003", "Poitrine", "Plastron ou equipement fixe a la poitrine"),
    ("spine.006", "Tete", "Casque, cimier ou accessoire de tete"),
    ("upper_arm.L", "Bras gauche", "Protection rigide du bras gauche"),
    ("forearm.L", "Avant-bras gauche", "Brassard gauche"),
    ("hand.L", "Main gauche", "Objet tenu dans la main gauche"),
    ("upper_arm.R", "Bras droit", "Protection rigide du bras droit"),
    ("forearm.R", "Avant-bras droit", "Brassard droit"),
    ("hand.R", "Main droite", "Objet tenu dans la main droite"),
    ("thigh.L", "Cuisse gauche", "Protection rigide de la cuisse gauche"),
    ("shin.L", "Tibia gauche", "Protection rigide du tibia gauche"),
    ("foot.L", "Pied gauche", "Chaussure ou accessoire du pied gauche"),
    ("thigh.R", "Cuisse droite", "Protection rigide de la cuisse droite"),
    ("shin.R", "Tibia droit", "Protection rigide du tibia droit"),
    ("foot.R", "Pied droit", "Chaussure ou accessoire du pied droit"),
)

UAL_BONES = {
    "root",
    "DEF-hips",
    "DEF-spine.001",
    "DEF-spine.002",
    "DEF-spine.003",
    "DEF-neck",
    "DEF-head",
    "DEF-shoulder.L",
    "DEF-upper_arm.L",
    "DEF-forearm.L",
    "DEF-hand.L",
    "DEF-f_index.01.L",
    "DEF-f_index.02.L",
    "DEF-f_index.03.L",
    "DEF-f_middle.01.L",
    "DEF-f_middle.02.L",
    "DEF-f_middle.03.L",
    "DEF-f_pinky.01.L",
    "DEF-f_pinky.02.L",
    "DEF-f_pinky.03.L",
    "DEF-f_ring.01.L",
    "DEF-f_ring.02.L",
    "DEF-f_ring.03.L",
    "DEF-thumb.01.L",
    "DEF-thumb.02.L",
    "DEF-thumb.03.L",
    "DEF-shoulder.R",
    "DEF-upper_arm.R",
    "DEF-forearm.R",
    "DEF-hand.R",
    "DEF-f_index.01.R",
    "DEF-f_index.02.R",
    "DEF-f_index.03.R",
    "DEF-f_middle.01.R",
    "DEF-f_middle.02.R",
    "DEF-f_middle.03.R",
    "DEF-f_pinky.01.R",
    "DEF-f_pinky.02.R",
    "DEF-f_pinky.03.R",
    "DEF-f_ring.01.R",
    "DEF-f_ring.02.R",
    "DEF-f_ring.03.R",
    "DEF-thumb.01.R",
    "DEF-thumb.02.R",
    "DEF-thumb.03.R",
    "DEF-thigh.L",
    "DEF-shin.L",
    "DEF-foot.L",
    "DEF-toe.L",
    "DEF-thigh.R",
    "DEF-shin.R",
    "DEF-foot.R",
    "DEF-toe.R",
}

CRITICAL_UAL_BONES = {
    "DEF-hips",
    "DEF-spine.001",
    "DEF-head",
    "DEF-upper_arm.L",
    "DEF-forearm.L",
    "DEF-hand.L",
    "DEF-upper_arm.R",
    "DEF-forearm.R",
    "DEF-hand.R",
    "DEF-thigh.L",
    "DEF-shin.L",
    "DEF-foot.L",
    "DEF-thigh.R",
    "DEF-shin.R",
    "DEF-foot.R",
}


def default_ual1_path() -> str:
    """Trouve UAL1 dans Hoplite sans dependre du dossier de lancement."""
    candidates: list[Path] = []
    roots = [Path.cwd()]
    if bpy.data.filepath:
        roots.append(Path(bpy.data.filepath).resolve().parent)
    for root in roots:
        candidates.extend(
            parent / "assets" / "runtime" / "ual1" / "UAL1_Standard.glb"
            for parent in (root, *root.parents)
        )
    candidates.append(
        Path.home()
        / "Downloads"
        / "hoplite_ual_native_lab_v2"
        / "assets"
        / "runtime"
        / "ual1"
        / "UAL1_Standard.glb"
    )
    return str(next((path for path in candidates if path.is_file()), candidates[-1]))


# -----------------------------------------------------------------------------
# Helpers Blender
# -----------------------------------------------------------------------------


def ensure_object_mode() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def select_only(obj: bpy.types.Object) -> None:
    ensure_object_mode()
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def set_visible(obj: bpy.types.Object, visible: bool) -> None:
    obj.hide_render = not visible
    obj.hide_viewport = not visible
    obj.hide_set(not visible)


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def object_has_ancestor(obj: bpy.types.Object, ancestor: bpy.types.Object) -> bool:
    current = obj.parent
    while current is not None:
        if current == ancestor:
            return True
        current = current.parent
    return False


def keep_world_parent(obj: bpy.types.Object, parent: bpy.types.Object | None) -> None:
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def evaluated_world_bounds(objects: Iterable[bpy.types.Object]) -> tuple[Vector, Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points: list[Vector] = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        points.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    if not points:
        raise RuntimeError("Impossible de calculer les dimensions du personnage")
    return (
        Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))),
        Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points))),
    )


def selected_character_meshes() -> list[bpy.types.Object]:
    return [
        obj
        for obj in bpy.context.selected_objects
        if obj.type == "MESH" and not obj.get(GENERATED_TAG, False)
    ]


def remembered_character_meshes() -> list[bpy.types.Object]:
    return [
        obj
        for obj in bpy.data.objects
        if obj.type == "MESH" and obj.get(CHARACTER_TAG, False)
    ]


def remember_character(meshes: list[bpy.types.Object]) -> None:
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj[CHARACTER_TAG] = obj in meshes


def armatures_for_meshes(meshes: list[bpy.types.Object]) -> list[bpy.types.Object]:
    result: set[bpy.types.Object] = set()
    for mesh in meshes:
        current = mesh.parent
        while current is not None:
            if current.type == "ARMATURE" and not current.get(GENERATED_TAG, False):
                result.add(current)
            current = current.parent
        for modifier in mesh.modifiers:
            if (
                modifier.type == "ARMATURE"
                and modifier.object is not None
                and not modifier.object.get(GENERATED_TAG, False)
            ):
                result.add(modifier.object)
    return sorted(result, key=lambda obj: obj.name)


def all_skinned_meshes_for_rig(rig: bpy.types.Object) -> list[bpy.types.Object]:
    """Etend une selection partielle a tous les meshes controles par ce rig."""
    return sorted(
        (
            obj
            for obj in bpy.data.objects
            if obj.type == "MESH"
            and not obj.get(GENERATED_TAG, False)
            and any(
                modifier.type == "ARMATURE" and modifier.object == rig
                for modifier in obj.modifiers
            )
        ),
        key=lambda obj: obj.name,
    )


def old_rig() -> bpy.types.Object | None:
    return next(
        (
            obj
            for obj in bpy.data.objects
            if obj.type == "ARMATURE" and obj.get(OLD_RIG_TAG, False)
        ),
        None,
    )


def ual_rig() -> bpy.types.Object | None:
    return next(
        (
            obj
            for obj in bpy.data.objects
            if obj.type == "ARMATURE"
            and (obj.get(GENERATED_TAG, False) or obj.get(FINAL_RIG_TAG, False))
            and obj.name.startswith(RIG_NAME)
        ),
        None,
    )


def ual_reference() -> bpy.types.Object | None:
    return next(
        (
            obj
            for obj in bpy.data.objects
            if obj.type == "MESH"
            and obj.get(GENERATED_TAG, False)
            and obj.name.startswith(REFERENCE_NAME)
        ),
        None,
    )


def fit_root() -> bpy.types.Object | None:
    return bpy.data.objects.get(FIT_ROOT_NAME)


def temporary_rigify() -> bpy.types.Object | None:
    return next(
        (
            obj
            for obj in bpy.data.objects
            if obj.type == "ARMATURE" and obj.get(TEMP_RIGIFY_TAG, False)
        ),
        None,
    )


def reset_pose(rig: bpy.types.Object) -> None:
    rig.data.pose_position = "POSE"
    if rig.animation_data is not None:
        rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        pose_bone.matrix_basis = Matrix.Identity(4)


def remember_ual_rest_geometry(rig: bpy.types.Object) -> None:
    """Memorise la T-pose UAL d'origine pour rendre le fitting rejouable."""
    select_only(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    geometry = {
        bone.name: {
            "head": list(bone.head),
            "tail": list(bone.tail),
            "roll": bone.roll,
        }
        for bone in rig.data.edit_bones
    }
    bpy.ops.object.mode_set(mode="OBJECT")
    rig[ORIGINAL_REST_PROP] = json.dumps(geometry, separators=(",", ":"))


def original_ual_rest_geometry(rig: bpy.types.Object) -> dict[str, dict[str, object]]:
    encoded = rig.get(ORIGINAL_REST_PROP, "")
    if not encoded:
        raise RuntimeError("T-pose UAL d'origine introuvable; reimporte le gabarit")
    geometry = json.loads(encoded)
    missing = sorted(UAL_BONES - set(geometry))
    if missing:
        raise RuntimeError(f"T-pose UAL incomplete; os absents : {', '.join(missing)}")
    return geometry


def restore_ual_rest_geometry(rig: bpy.types.Object) -> None:
    """Restaure exactement la geometrie d'os importee, actions intactes."""
    geometry = original_ual_rest_geometry(rig)
    ensure_object_mode()
    reset_pose(rig)
    select_only(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, values in geometry.items():
        bone = rig.data.edit_bones.get(name)
        if bone is None:
            continue
        bone.head = Vector(values["head"])
        bone.tail = Vector(values["tail"])
        bone.roll = float(values["roll"])
    bpy.ops.object.mode_set(mode="OBJECT")
    rig[PROPORTIONS_FITTED_TAG] = False
    bpy.context.view_layer.update()


def mesh_statistics(meshes: list[bpy.types.Object]) -> tuple[int, int]:
    vertices = sum(len(obj.data.vertices) for obj in meshes)
    triangles = sum(
        max(0, len(poly.vertices) - 2)
        for obj in meshes
        for poly in obj.data.polygons
    )
    return vertices, triangles


# -----------------------------------------------------------------------------
# Mode optionnel : creation d'un rig temporaire pour un mesh sans armature
# -----------------------------------------------------------------------------


def enable_rigify_for_session() -> None:
    """Active le Rigify fourni avec Blender sans sauvegarder les preferences."""
    if "rigify" not in bpy.context.preferences.addons:
        result = bpy.ops.preferences.addon_enable(module="rigify")
        if "FINISHED" not in result:
            raise RuntimeError("Impossible d'activer Rigify dans cette installation Blender")
    if not hasattr(bpy.ops.object, "armature_basic_human_metarig_add"):
        raise RuntimeError(
            "Rigify Basic Human est absent. Active Rigify dans Preferences > Add-ons."
        )


def fit_metarig_overall_to_meshes(
    rig: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> float:
    """Ajuste automatiquement hauteur, sol et centre; les articulations restent manuelles."""
    bpy.context.view_layer.update()
    model_min, model_max = evaluated_world_bounds(meshes)
    points = [
        rig.matrix_world @ point
        for bone in rig.data.bones
        for point in (bone.head_local, bone.tail_local)
    ]
    rig_min = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    rig_max = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    model_height = model_max.z - model_min.z
    rig_height = rig_max.z - rig_min.z
    if model_height <= 1e-6 or rig_height <= 1e-6:
        raise RuntimeError("Hauteur nulle pendant le pre-ajustement Rigify")

    scale = model_height / rig_height
    rig.scale = Vector((scale, scale, scale))
    bpy.context.view_layer.update()

    points = [
        rig.matrix_world @ point
        for bone in rig.data.bones
        for point in (bone.head_local, bone.tail_local)
    ]
    scaled_min = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    scaled_max = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    model_center = (model_min + model_max) * 0.5
    scaled_center = (scaled_min + scaled_max) * 0.5
    rig.location += Vector(
        (
            model_center.x - scaled_center.x,
            model_center.y - scaled_center.y,
            model_min.z - scaled_min.z,
        )
    )
    bpy.context.view_layer.update()

    select_only(rig)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return scale


def create_temporary_basic_rigify(meshes: list[bpy.types.Object]) -> tuple[bpy.types.Object, float]:
    enable_rigify_for_session()
    ensure_object_mode()
    cursor_location = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = Vector((0.0, 0.0, 0.0))
    try:
        result = bpy.ops.object.armature_basic_human_metarig_add()
    finally:
        bpy.context.scene.cursor.location = cursor_location
    if "FINISHED" not in result or bpy.context.object is None:
        raise RuntimeError("Creation du metarig Rigify Basic impossible")

    rig = bpy.context.object
    rig.name = TEMP_RIGIFY_NAME
    rig.data.name = f"{TEMP_RIGIFY_NAME}_Data"
    rig[TEMP_RIGIFY_TAG] = True
    rig.show_in_front = True
    rig.data.display_type = "OCTAHEDRAL"
    rig.data.show_names = True
    rig.data.use_mirror_x = True
    rig.color = (0.25, 1.0, 0.25, 1.0)
    scale = fit_metarig_overall_to_meshes(rig, meshes)
    remember_character(meshes)
    return rig, scale


def fill_unweighted_by_bone_proximity(
    mesh: bpy.types.Object,
    rig: bpy.types.Object,
) -> int:
    """Pondere les sommets oublies par Bone Heat sans toucher aux autres."""
    candidates: list[tuple[str, Vector, Vector, float]] = []
    lengths: list[float] = []
    for bone in rig.data.bones:
        if not bone.use_deform or mapped_target_for_source(rig, bone.name) is None:
            continue
        head = rig.matrix_world @ bone.head_local
        tail = rig.matrix_world @ bone.tail_local
        segment = tail - head
        length_squared = segment.length_squared
        if length_squared <= 1e-12:
            continue
        candidates.append((bone.name, head, segment, length_squared))
        lengths.append(length_squared ** 0.5)
    if not candidates:
        raise RuntimeError("Le Rigify temporaire ne contient aucun os deformant utilisable")

    groups = {
        name: mesh.vertex_groups.get(name) or mesh.vertex_groups.new(name=name)
        for name, _head, _segment, _length_squared in candidates
    }
    deform_indices = {group.index for group in groups.values()}
    missing = [
        vertex
        for vertex in mesh.data.vertices
        if sum(
            assignment.weight
            for assignment in vertex.groups
            if assignment.group in deform_indices
        )
        <= 1e-6
    ]
    if not missing:
        return 0

    # Quatre segments proches, avec une chute rapide, donnent une base souple
    # mais evitent de melanger le bras gauche avec le torse ou le bras droit.
    epsilon = max(median(lengths) * 0.025, 1e-6)
    for vertex in missing:
        point = mesh.matrix_world @ vertex.co
        distances: list[tuple[float, str]] = []
        for name, head, segment, length_squared in candidates:
            factor = max(0.0, min(1.0, (point - head).dot(segment) / length_squared))
            distance = (point - (head + segment * factor)).length
            distances.append((distance, name))
        nearest = sorted(distances, key=lambda item: item[0])[:MAX_WEIGHTS]
        scores = [(1.0 / ((distance + epsilon) ** 3), name) for distance, name in nearest]
        score_sum = sum(score for score, _name in scores)
        for score, name in scores:
            groups[name].add([vertex.index], score / score_sum, "REPLACE")
    return len(missing)


def assign_vertices_rigidly(
    mesh: bpy.types.Object,
    rig: bpy.types.Object,
    vertex_indices: list[int],
    bone_name: str,
) -> None:
    """Remplace les poids de rig des sommets par un attachement 100 % rigide."""
    if bone_name not in rig.data.bones:
        raise RuntimeError(f"Os temporaire introuvable : {bone_name}")
    bone_names = {bone.name for bone in rig.data.bones}
    for group in list(mesh.vertex_groups):
        if group.name in bone_names:
            group.remove(vertex_indices)
    target = mesh.vertex_groups.get(bone_name) or mesh.vertex_groups.new(name=bone_name)
    target.add(vertex_indices, 1.0, "REPLACE")


def bind_meshes_with_automatic_weights(
    rig: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> tuple[int, int, int]:
    """Skinne sur le metarig; complete les echecs Bone Heat par proximite."""
    ensure_object_mode()
    reset_pose(rig)
    existing = armatures_for_meshes(meshes)
    if existing and existing != [rig]:
        raise RuntimeError("Un des meshes possede deja une autre armature")

    # Les imports glTF/FBX placent souvent les meshes sous des Empty avec une
    # conversion d'axe ou d'unites. ARMATURE_AUTO remplace ce parent : sans
    # sauvegarde explicite, le mesh peut devenir geant et pivoter de 90 degres.
    world_matrices = {mesh: mesh.matrix_world.copy() for mesh in meshes}
    bone_names = {bone.name for bone in rig.data.bones}
    for mesh in meshes:
        # Rend le bouton relancable apres un echec silencieux de Bone Heat.
        for modifier in list(mesh.modifiers):
            if modifier.type == "ARMATURE" and modifier.object == rig:
                mesh.modifiers.remove(modifier)
        if mesh.parent == rig:
            mesh.parent = None
            mesh.matrix_world = world_matrices[mesh]
        for group in [group for group in mesh.vertex_groups if group.name in bone_names]:
            mesh.vertex_groups.remove(group)

    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes:
        mesh.hide_set(False)
        mesh.hide_viewport = False
        mesh.select_set(True)
    rig.hide_set(False)
    rig.hide_viewport = False
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    result = bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    if "FINISHED" not in result:
        raise RuntimeError(
            "Echec des poids automatiques (Bone Heat). Verifie le mesh ou essaie par pieces."
        )

    for mesh, world_matrix in world_matrices.items():
        mesh.matrix_world = world_matrix
    bpy.context.view_layer.update()

    max_transform_error = max(
        abs(mesh.matrix_world[row][column] - world_matrix[row][column])
        for mesh, world_matrix in world_matrices.items()
        for row in range(4)
        for column in range(4)
    )
    if max_transform_error > 1e-5:
        raise RuntimeError(
            f"La transformation mondiale du mesh n'a pas pu etre preservee ({max_transform_error:.6g})"
        )

    # Blender peut renvoyer FINISHED tout en affichant seulement dans la console
    # "Bone Heat Weighting: failed...". Dans ce cas les groupes existent mais
    # restent vides. On ne laisse plus ce faux succes passer inapercu.
    fallback_vertices = 0
    for mesh in meshes:
        fallback_vertices += fill_unweighted_by_bone_proximity(mesh, rig)

    rig[OLD_RIG_TAG] = True
    total_unweighted = sum(count_unweighted(mesh, rig) for mesh in meshes)
    if total_unweighted:
        raise RuntimeError(
            f"Impossible de ponderer {total_unweighted} sommet(s), meme avec le secours par proximite"
        )
    for mesh in meshes:
        mesh.select_set(True)
    print(
        "[UAL1 Rig] AUTO_WEIGHTS",
        {
            "meshes": len(meshes),
            "unweighted_vertices": total_unweighted,
            "proximity_fallback_vertices": fallback_vertices,
            "world_transform_error": max_transform_error,
        },
    )
    return len(meshes), total_unweighted, fallback_vertices


# -----------------------------------------------------------------------------
# Import et phase d'ajustement
# -----------------------------------------------------------------------------


def import_ual1(path: Path) -> tuple[bpy.types.Object, bpy.types.Object, int]:
    before_objects = set(bpy.data.objects)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = [obj for obj in bpy.data.objects if obj not in before_objects]
    actions = [action for action in bpy.data.actions if action not in before_actions]

    rigs = [obj for obj in imported if obj.type == "ARMATURE"]
    references = [
        obj
        for obj in imported
        if obj.type == "MESH" and len(obj.vertex_groups) >= 40
    ]
    if len(rigs) != 1 or not references:
        raise RuntimeError("UAL1 invalide : rig ou mannequin introuvable dans le GLB")

    rig = rigs[0]
    reference = max(references, key=lambda obj: len(obj.data.vertices))
    imported_bones = {bone.name for bone in rig.data.bones}
    if imported_bones != UAL_BONES:
        missing = sorted(UAL_BONES - imported_bones)
        raise RuntimeError(f"Le squelette importe n'est pas UAL1 Standard; os absents: {missing}")

    rig.name = RIG_NAME
    rig.data.name = f"{RIG_NAME}_Data"
    reference.name = REFERENCE_NAME

    collection = bpy.data.collections.new(TOOL_COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    for obj in imported:
        obj[GENERATED_TAG] = True
        move_to_collection(obj, collection)

    for action in actions:
        action[GENERATED_TAG] = True
        action.use_fake_user = True

    reset_pose(rig)
    remember_ual_rest_geometry(rig)
    rig.show_in_front = True
    rig.data.display_type = "STICK"
    reference.display_type = "WIRE"
    reference.color = (0.10, 0.75, 1.0, 1.0)
    reference.show_in_front = True
    set_visible(reference, True)
    for obj in imported:
        if obj not in (rig, reference):
            set_visible(obj, False)
    return rig, reference, len(actions)


def create_fit_control(
    meshes: list[bpy.types.Object],
    rig: bpy.types.Object,
) -> bpy.types.Object:
    collection = bpy.data.collections.get(TOOL_COLLECTION)
    if collection is None:
        raise RuntimeError("Collection de travail UAL1 introuvable")

    control = bpy.data.objects.new(FIT_ROOT_NAME, None)
    collection.objects.link(control)
    control.empty_display_type = "CIRCLE"
    control.empty_display_size = 0.30
    control.show_in_front = True
    control.color = (1.0, 0.35, 0.05, 1.0)
    control[GENERATED_TAG] = True

    keep_world_parent(rig, control)
    for mesh in meshes:
        if not object_has_ancestor(mesh, rig):
            keep_world_parent(mesh, control)
    return control


def align_fit_control(
    control: bpy.types.Object,
    meshes: list[bpy.types.Object],
    reference: bpy.types.Object,
) -> float:
    bpy.context.view_layer.update()
    model_min, model_max = evaluated_world_bounds(meshes)
    ref_min, ref_max = evaluated_world_bounds([reference])
    model_height = model_max.z - model_min.z
    ref_height = ref_max.z - ref_min.z
    if model_height <= 1e-6:
        raise RuntimeError("La hauteur du personnage est nulle")

    scale = ref_height / model_height
    model_center = (model_min + model_max) * 0.5
    ref_center = (ref_min + ref_max) * 0.5
    translation = Vector(
        (
            ref_center.x - model_center.x * scale,
            ref_center.y - model_center.y * scale,
            ref_min.z - model_min.z * scale,
        )
    )
    control.matrix_world = Matrix.Translation(translation) @ Matrix.Scale(scale, 4) @ control.matrix_world
    bpy.context.view_layer.update()
    return scale


# -----------------------------------------------------------------------------
# Remappage de l'ancien rig vers les os UAL1
# -----------------------------------------------------------------------------


def compact_bone_name(name: str) -> str:
    return "".join(character for character in name.lower() if character.isalnum())


def mixamo_aliases() -> dict[str, str]:
    aliases = {
        "hips": "DEF-hips",
        "spine": "DEF-spine.001",
        "spine1": "DEF-spine.002",
        "spine2": "DEF-spine.003",
        "neck": "DEF-neck",
        "head": "DEF-head",
        "headtopend": "DEF-head",
        "lefteye": "DEF-head",
        "righteye": "DEF-head",
    }
    for word, suffix in (("left", "L"), ("right", "R")):
        aliases.update(
            {
                f"{word}shoulder": f"DEF-shoulder.{suffix}",
                f"{word}arm": f"DEF-upper_arm.{suffix}",
                f"{word}forearm": f"DEF-forearm.{suffix}",
                f"{word}hand": f"DEF-hand.{suffix}",
                f"{word}upleg": f"DEF-thigh.{suffix}",
                f"{word}leg": f"DEF-shin.{suffix}",
                f"{word}foot": f"DEF-foot.{suffix}",
                f"{word}toebase": f"DEF-toe.{suffix}",
                f"{word}toeend": f"DEF-toe.{suffix}",
            }
        )
        for source_finger, target_finger in (
            ("index", "f_index"),
            ("middle", "f_middle"),
            ("ring", "f_ring"),
            ("pinky", "f_pinky"),
            ("thumb", "thumb"),
        ):
            for index in range(1, 5):
                target_index = min(index, 3)
                aliases[f"{word}hand{source_finger}{index}"] = (
                    f"DEF-{target_finger}.{target_index:02d}.{suffix}"
                )
    return aliases


MIXAMO_ALIASES = mixamo_aliases()


def generic_aliases() -> dict[str, str]:
    aliases = {
        "root": "root",
        "hips": "DEF-hips",
        "hip": "DEF-hips",
        "pelvis": "DEF-hips",
        "spine": "DEF-spine.001",
        "spine1": "DEF-spine.001",
        "spine01": "DEF-spine.001",
        "spine2": "DEF-spine.002",
        "spine02": "DEF-spine.002",
        "spine3": "DEF-spine.003",
        "spine03": "DEF-spine.003",
        "chest": "DEF-spine.003",
        "upperchest": "DEF-spine.003",
        "neck": "DEF-neck",
        "neck1": "DEF-neck",
        "neck01": "DEF-neck",
        "head": "DEF-head",
        "headtop": "DEF-head",
        "headtopend": "DEF-head",
        "lefteye": "DEF-head",
        "righteye": "DEF-head",
    }
    for long_side, short_side, suffix in (("left", "l", "L"), ("right", "r", "R")):
        entries = {
            "shoulder": f"DEF-shoulder.{suffix}",
            "clavicle": f"DEF-shoulder.{suffix}",
            "arm": f"DEF-upper_arm.{suffix}",
            "upperarm": f"DEF-upper_arm.{suffix}",
            "forearm": f"DEF-forearm.{suffix}",
            "lowerarm": f"DEF-forearm.{suffix}",
            "hand": f"DEF-hand.{suffix}",
            "upleg": f"DEF-thigh.{suffix}",
            "upperleg": f"DEF-thigh.{suffix}",
            "thigh": f"DEF-thigh.{suffix}",
            "leg": f"DEF-shin.{suffix}",
            "lowerleg": f"DEF-shin.{suffix}",
            "calf": f"DEF-shin.{suffix}",
            "shin": f"DEF-shin.{suffix}",
            "foot": f"DEF-foot.{suffix}",
            "toe": f"DEF-toe.{suffix}",
            "toebase": f"DEF-toe.{suffix}",
            "ball": f"DEF-toe.{suffix}",
        }
        for stem, target in entries.items():
            aliases[f"{long_side}{stem}"] = target
            aliases[f"{stem}{short_side}"] = target
            aliases[f"{short_side}{stem}"] = target

        for source_finger, target_finger in (
            ("index", "f_index"),
            ("middle", "f_middle"),
            ("ring", "f_ring"),
            ("pinky", "f_pinky"),
            ("little", "f_pinky"),
            ("thumb", "thumb"),
        ):
            for index in range(1, 5):
                target_index = min(index, 3)
                target = f"DEF-{target_finger}.{target_index:02d}.{suffix}"
                for alias in (
                    f"{long_side}hand{source_finger}{index}",
                    f"{long_side}{source_finger}{index}",
                    f"{source_finger}{index:02d}{short_side}",
                    f"{source_finger}{index}{short_side}",
                    f"{short_side}{source_finger}{index}",
                ):
                    aliases[alias] = target
    return aliases


GENERIC_ALIASES = generic_aliases()


EXACT_GLTF197_SIGNATURE = {
    "GLTF_created_0_rootJoint",
    "root ground_197",
    "root hips_196",
    "pelvis_50",
    "spine lower _195",
    "spine middle_194",
    "spine upper_193",
    "spine upperer_190",
    "head neck upperer_137",
    "arm left shoulder 1_164",
    "arm right shoulder 1_189",
    "leg left thigh_33",
    "leg right thigh_49",
}


FIT_CHAINS = (
    ("DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head"),
    ("DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L"),
    ("DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"),
    ("DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-toe.L"),
    ("DEF-thigh.R", "DEF-shin.R", "DEF-foot.R", "DEF-toe.R"),
)

for _fit_side in ("L", "R"):
    for _fit_finger in ("f_index", "f_middle", "f_ring", "f_pinky", "thumb"):
        FIT_CHAINS += (
            tuple(f"DEF-{_fit_finger}.{index:02d}.{_fit_side}" for index in range(1, 4)),
        )


def exact_gltf197_fit_sources(rig: bpy.types.Object) -> dict[str, str]:
    """Choisit les vrais pivots deformants, sans les os de controle intermediaires."""
    names = {bone.name for bone in rig.data.bones}
    if not EXACT_GLTF197_SIGNATURE.issubset(names):
        return {}

    result = {
        "DEF-hips": "pelvis_50",
        "DEF-spine.001": "spine lower _195",
        "DEF-spine.002": "spine middle_194",
        "DEF-spine.003": "spine upper_193",
        "DEF-neck": "head neck lower_139",
        "DEF-head": "head neck upperer_137",
        "DEF-shoulder.L": "arm left shoulder 1_164",
        "DEF-upper_arm.L": "arm left shoulder 2_163",
        "DEF-forearm.L": "arm left elbow_162",
        "DEF-hand.L": "arm left wrist_161",
        "DEF-shoulder.R": "arm right shoulder 1_189",
        "DEF-upper_arm.R": "arm right shoulder 2_188",
        "DEF-forearm.R": "arm right elbow_187",
        "DEF-hand.R": "arm right wrist_186",
        "DEF-thigh.L": "leg left thigh_33",
        "DEF-shin.L": "leg left knee_32",
        "DEF-foot.L": "leg left ankle_31",
        "DEF-toe.L": "leg left toes_30",
        "DEF-thigh.R": "leg right thigh_49",
        "DEF-shin.R": "leg right knee_48",
        "DEF-foot.R": "leg right ankle_47",
        "DEF-toe.R": "leg right toes_46",
    }
    finger_names = {
        "1": "thumb",
        "2": "f_index",
        "3": "f_middle",
        "4": "f_ring",
        "5": "f_pinky",
    }
    phalanges = {"a": 1, "b": 2, "c": 3}
    for source_name in names:
        match = re.fullmatch(r"arm (left|right) finger ([1-5])([abc])_\d+", source_name.lower())
        if match is None:
            continue
        side_word, finger_number, letter = match.groups()
        side = "L" if side_word == "left" else "R"
        target = f"DEF-{finger_names[finger_number]}.{phalanges[letter]:02d}.{side}"
        result[target] = source_name
    return {target: source for target, source in result.items() if source in names}


def exact_gltf197_alias(source_name: str) -> str | None:
    """Mapping exact du personnage GLTF_created_0 a 197 os fourni par l'utilisateur."""
    core = {
        "GLTF_created_0_rootJoint": "root",
        "root ground_197": "root",
        "root hips_196": "DEF-hips",
        "pelvis_50": "DEF-hips",
        "spine lower _195": "DEF-spine.001",
        "spine middle_194": "DEF-spine.002",
        "spine upper_193": "DEF-spine.003",
        "spine upperer_190": "DEF-spine.003",
        "head neck lower_139": "DEF-neck",
        "head neck upper_138": "DEF-neck",
        "head neck upperer_137": "DEF-head",
        "breast left_191": "DEF-spine.003",
        "breast right_192": "DEF-spine.003",
        "leg left thigh_33": "DEF-thigh.L",
        "leg left thigh ctrl_18": "DEF-thigh.L",
        "leg left knee_32": "DEF-shin.L",
        "leg left ankle_31": "DEF-foot.L",
        "leg left toes ctrl_19": "DEF-toe.L",
        "leg left toes_30": "DEF-toe.L",
        "leg right thigh_49": "DEF-thigh.R",
        "leg right thigh ctrl_34": "DEF-thigh.R",
        "leg right knee_48": "DEF-shin.R",
        "leg right ankle_47": "DEF-foot.R",
        "leg right toes ctrl_35": "DEF-toe.R",
        "leg right toes_46": "DEF-toe.R",
        "arm left shoulder 1_164": "DEF-shoulder.L",
        "arm left shoulder 2_163": "DEF-upper_arm.L",
        "arm left shoulder ctrl_140": "DEF-upper_arm.L",
        "arm left elbow_162": "DEF-forearm.L",
        "arm left elbow ctrl_141": "DEF-forearm.L",
        "arm left wrist_161": "DEF-hand.L",
        "arm right shoulder 1_189": "DEF-shoulder.R",
        "arm right shoulder 2_188": "DEF-upper_arm.R",
        "arm right shoulder ctrl_165": "DEF-upper_arm.R",
        "arm right elbow_187": "DEF-forearm.R",
        "arm right elbow ctrl_166": "DEF-forearm.R",
        "arm right wrist_186": "DEF-hand.R",
    }
    if source_name in core:
        return core[source_name]

    lowered = source_name.lower()
    if lowered.startswith(("head ", "hair ")):
        return "DEF-head"
    if lowered.startswith(("vagina", "rectum")):
        return "DEF-hips"

    toe_match = re.fullmatch(r"leg (left|right) toe [1-5][ab]_\d+", lowered)
    if toe_match is not None:
        return f"DEF-toe.{('L' if toe_match.group(1) == 'left' else 'R')}"

    palm_match = re.fullmatch(r"unused palm (?:index|middle|ring|pinky)\.([lr])_\d+", lowered)
    if palm_match is not None:
        return f"DEF-hand.{palm_match.group(1).upper()}"

    finger_match = re.fullmatch(
        r"arm (left|right) finger ([1-5])([abc])_\d+",
        lowered,
    )
    if finger_match is None:
        return None
    side_word, finger_number_text, phalanx_letter = finger_match.groups()
    side = "L" if side_word == "left" else "R"
    finger_name = {
        "1": "thumb",
        "2": "f_index",
        "3": "f_middle",
        "4": "f_ring",
        "5": "f_pinky",
    }[finger_number_text]
    phalanx = {"a": 1, "b": 2, "c": 3}[phalanx_letter]
    return f"DEF-{finger_name}.{phalanx:02d}.{side}"


def auto_rig_pro_alias(source_name: str) -> str | None:
    """Reconnait les noms natifs d'Auto-Rig Pro."""
    lowered = source_name.lower().strip()
    side: str | None = None
    side_match = re.search(r"(?:[._-])(l|r)$", lowered)
    if side_match is not None:
        side = side_match.group(1).upper()
        lowered = lowered[: side_match.start()]
    else:
        center_match = re.search(r"(?:[._-])x$", lowered)
        if center_match is not None:
            lowered = lowered[: center_match.start()]

    if lowered.endswith("_ref") or lowered.endswith(".ref"):
        return None
    for prefix in ("c_", "cc_", "def_", "org_", "mch_"):
        if lowered.startswith(prefix):
            lowered = lowered[len(prefix) :]
            break
    stem = compact_bone_name(lowered)

    if side is None:
        center = {
            "rootmaster": "root",
            "pos": "root",
            "traj": "root",
            # Dans le rig ARP export, root.x est le bassin deformant.
            "root": "DEF-hips",
            "hips": "DEF-hips",
            "pelvis": "DEF-hips",
            "spine": "DEF-spine.001",
            "spine01": "DEF-spine.001",
            "spine1": "DEF-spine.001",
            "spine02": "DEF-spine.002",
            "spine2": "DEF-spine.002",
            "spine03": "DEF-spine.003",
            "spine3": "DEF-spine.003",
            "chest": "DEF-spine.003",
            "neck": "DEF-neck",
            "head": "DEF-head",
            "headbend": "DEF-head",
        }
        return center.get(stem)

    sided = {
        "pelvis": "DEF-hips",
        "shoulder": f"DEF-shoulder.{side}",
        "clavicle": f"DEF-shoulder.{side}",
        "arm": f"DEF-upper_arm.{side}",
        "armfk": f"DEF-upper_arm.{side}",
        "armstretch": f"DEF-upper_arm.{side}",
        "armtwist": f"DEF-upper_arm.{side}",
        "upperarm": f"DEF-upper_arm.{side}",
        "forearm": f"DEF-forearm.{side}",
        "forearmfk": f"DEF-forearm.{side}",
        "forearmstretch": f"DEF-forearm.{side}",
        "forearmtwist": f"DEF-forearm.{side}",
        "lowerarm": f"DEF-forearm.{side}",
        "hand": f"DEF-hand.{side}",
        "handfk": f"DEF-hand.{side}",
        "thigh": f"DEF-thigh.{side}",
        "thighfk": f"DEF-thigh.{side}",
        "thighstretch": f"DEF-thigh.{side}",
        "thightwist": f"DEF-thigh.{side}",
        "leg": f"DEF-shin.{side}",
        "legfk": f"DEF-shin.{side}",
        "legstretch": f"DEF-shin.{side}",
        "legtwist": f"DEF-shin.{side}",
        "calf": f"DEF-shin.{side}",
        "shin": f"DEF-shin.{side}",
        "foot": f"DEF-foot.{side}",
        "footfk": f"DEF-foot.{side}",
        "toe": f"DEF-toe.{side}",
        "toes": f"DEF-toe.{side}",
        "toes01": f"DEF-toe.{side}",
        "toebase": f"DEF-toe.{side}",
    }
    if stem in sided:
        return sided[stem]

    finger_match = re.fullmatch(
        r"(?:hand)?(thumb|index|middle|ring|pinky|little|findex|fmiddle|fring|fpinky)0?([1-4])",
        stem,
    )
    if finger_match is None:
        return None
    finger, source_index_text = finger_match.groups()
    finger = {
        "index": "f_index",
        "findex": "f_index",
        "middle": "f_middle",
        "fmiddle": "f_middle",
        "ring": "f_ring",
        "fring": "f_ring",
        "pinky": "f_pinky",
        "fpinky": "f_pinky",
        "little": "f_pinky",
        "thumb": "thumb",
    }[finger]
    target_index = min(int(source_index_text), 3)
    return f"DEF-{finger}.{target_index:02d}.{side}"


def guess_ual_bone(source_name: str) -> str | None:
    if source_name in UAL_BONES:
        return source_name

    exact_target = exact_gltf197_alias(source_name)
    if exact_target is not None:
        return exact_target

    auto_rig_pro_target = auto_rig_pro_alias(source_name)
    if auto_rig_pro_target is not None:
        return auto_rig_pro_target

    compact = compact_bone_name(source_name)
    for prefix in ("mixamorig", "mixamo"):
        if compact.startswith(prefix):
            return MIXAMO_ALIASES.get(compact[len(prefix) :])

    for prefix in ("armature", "skeleton", "bip001", "bip01", "bip"):
        if compact.startswith(prefix):
            compact = compact[len(prefix) :]
            break
    return GENERIC_ALIASES.get(compact)


TEMP_BASIC_ALIASES = {
    "spine": "DEF-hips",
    "spine.001": "DEF-spine.001",
    "spine.002": "DEF-spine.002",
    "spine.003": "DEF-spine.003",
    "spine.004": "DEF-neck",
    "spine.005": "DEF-neck",
    "spine.006": "DEF-head",
    "breast.L": "DEF-spine.003",
    "breast.R": "DEF-spine.003",
    "pelvis.L": "DEF-hips",
    "pelvis.R": "DEF-hips",
    "heel.02.L": "DEF-foot.L",
    "heel.02.R": "DEF-foot.R",
}


def mapped_target_for_source(rig: bpy.types.Object, source_name: str) -> str | None:
    if rig.get(TEMP_RIGIFY_TAG, False):
        return TEMP_BASIC_ALIASES.get(source_name) or guess_ual_bone(source_name)
    return guess_ual_bone(source_name)


def used_vertex_group_names(meshes: list[bpy.types.Object]) -> set[str]:
    used: set[str] = set()
    for mesh in meshes:
        names_by_index = {group.index: group.name for group in mesh.vertex_groups}
        used_indices = {
            assignment.group
            for vertex in mesh.data.vertices
            for assignment in vertex.groups
            if assignment.weight > 1e-6
        }
        used.update(names_by_index[index] for index in used_indices if index in names_by_index)
    return used


def build_bone_mapping(
    rig: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> tuple[dict[str, str], list[str]]:
    """Mappe les groupes ponderes et ignore les controleurs sans poids."""
    used_names = used_vertex_group_names(meshes)
    bones_by_name = {bone.name: bone for bone in rig.data.bones}
    direct = {
        bone.name: target
        for bone in rig.data.bones
        if (target := mapped_target_for_source(rig, bone.name)) is not None
    }
    mapping: dict[str, str] = {}
    unmapped: list[str] = []
    for source_name in sorted(used_names):
        target = direct.get(source_name) or mapped_target_for_source(rig, source_name)
        bone = bones_by_name.get(source_name)
        parent = bone.parent if bone is not None else None
        while target is None and parent is not None:
            target = direct.get(parent.name)
            parent = parent.parent
        if target is None:
            unmapped.append(source_name)
        else:
            mapping[source_name] = target
    return mapping, unmapped


def build_fit_source_mapping(
    rig: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> dict[str, str]:
    """Choisit un os-pivot unique par os UAL pour mesurer les proportions."""
    exact = exact_gltf197_fit_sources(rig)
    if exact:
        return exact

    if rig.get(TEMP_RIGIFY_TAG, False):
        preferred = {
            "DEF-hips": "spine",
            "DEF-spine.001": "spine.001",
            "DEF-spine.002": "spine.002",
            "DEF-spine.003": "spine.003",
            "DEF-neck": "spine.004",
            "DEF-head": "spine.006",
            "DEF-shoulder.L": "shoulder.L",
            "DEF-upper_arm.L": "upper_arm.L",
            "DEF-forearm.L": "forearm.L",
            "DEF-hand.L": "hand.L",
            "DEF-shoulder.R": "shoulder.R",
            "DEF-upper_arm.R": "upper_arm.R",
            "DEF-forearm.R": "forearm.R",
            "DEF-hand.R": "hand.R",
            "DEF-thigh.L": "thigh.L",
            "DEF-shin.L": "shin.L",
            "DEF-foot.L": "foot.L",
            "DEF-toe.L": "toe.L",
            "DEF-thigh.R": "thigh.R",
            "DEF-shin.R": "shin.R",
            "DEF-foot.R": "foot.R",
            "DEF-toe.R": "toe.R",
        }
        names = {bone.name for bone in rig.data.bones}
        return {target: source for target, source in preferred.items() if source in names}

    used_names = used_vertex_group_names(meshes)
    candidates: dict[str, list[bpy.types.Bone]] = {}
    for bone in rig.data.bones:
        target = mapped_target_for_source(rig, bone.name)
        if target is not None:
            candidates.setdefault(target, []).append(bone)

    result: dict[str, str] = {}
    for target, bones in candidates.items():
        def score(bone: bpy.types.Bone) -> tuple[float, str]:
            lowered = bone.name.lower()
            value = 1000.0 if bone.name == target else 0.0
            value += 200.0 if bone.name in used_names else 0.0
            value -= 150.0 if any(word in lowered for word in ("ctrl", "control", "ik", "pole")) else 0.0
            value -= 80.0 if any(word in lowered for word in ("twist", "helper", "mch", "org")) else 0.0
            value += min(float(bone.length), 10.0)
            return value, bone.name

        result[target] = max(bones, key=score).name
    return result


def _original_bone_vectors(
    geometry: dict[str, dict[str, object]],
    bone_name: str,
) -> tuple[Vector, Vector, Vector, float]:
    values = geometry[bone_name]
    head = Vector(values["head"])
    tail = Vector(values["tail"])
    delta = tail - head
    length = delta.length
    if length <= 1e-8:
        raise RuntimeError(f"Os UAL de longueur nulle : {bone_name}")
    return head, tail, delta / length, length


def fit_ual_proportions_to_source(
    source_rig: bpy.types.Object,
    target_rig: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> dict[str, object]:
    """Adapte pivots/longueurs UAL en gardant ses directions et sa T-pose.

    Les distances viennent du rig source, quelle que soit son A/T-pose. Les
    directions et rolls restent ceux de la T-pose UAL d'origine afin que les
    rotations locales des 46 actions gardent le meme sens.
    """
    source_map = build_fit_source_mapping(source_rig, meshes)
    required = CRITICAL_UAL_BONES | {
        "DEF-shoulder.L",
        "DEF-shoulder.R",
        "DEF-neck",
    }
    missing = sorted(required - set(source_map))
    if missing:
        raise RuntimeError(
            "Ajustement des proportions impossible; pivots sans source : "
            + ", ".join(missing)
        )

    geometry = original_ual_rest_geometry(target_rig)
    ensure_object_mode()
    reset_pose(target_rig)
    bpy.context.view_layer.update()

    source_to_target = target_rig.matrix_world.inverted() @ source_rig.matrix_world
    source_heads: dict[str, Vector] = {}
    source_tails: dict[str, Vector] = {}
    for target_name, source_name in source_map.items():
        pose_bone = source_rig.pose.bones.get(source_name)
        if pose_bone is None:
            continue
        source_heads[target_name] = source_to_target @ pose_bone.head
        source_tails[target_name] = source_to_target @ pose_bone.tail

    fitted: dict[str, tuple[Vector, Vector]] = {}
    ratios: list[float] = []

    def measured_length(current: str, following: str | None) -> float | None:
        head = source_heads.get(current)
        if head is None:
            return None
        endpoint = source_heads.get(following) if following is not None else source_tails.get(current)
        if endpoint is None:
            return None
        value = (endpoint - head).length
        if value <= 1e-6:
            return None
        return value

    def safe_length(name: str, measured: float | None, fallback_scale: float = 1.0) -> float:
        _, _, _, original_length = _original_bone_vectors(geometry, name)
        if measured is None:
            return original_length * fallback_scale
        ratio = measured / original_length
        if ratio < 0.25 or ratio > 4.0:
            return original_length * fallback_scale
        ratios.append(ratio)
        return measured

    # Bassin : le pivot vient du personnage, mais l'axe reste celui de UAL.
    hips_head = source_heads["DEF-hips"]
    _, _, hips_direction, hips_original_length = _original_bone_vectors(geometry, "DEF-hips")
    fitted["DEF-hips"] = (hips_head, hips_head + hips_direction * hips_original_length)

    # Torse, bras et jambes : longueurs mesurees, directions UAL conservees.
    for chain in FIT_CHAINS[:5]:
        first = chain[0]
        if first not in source_heads:
            continue
        current_head = source_heads[first]
        chain_ratios: list[float] = []
        for index, name in enumerate(chain):
            if name not in source_map:
                break
            following = chain[index + 1] if index + 1 < len(chain) else None
            _, _, direction, original_length = _original_bone_vectors(geometry, name)
            measured = measured_length(name, following)
            fallback = median(chain_ratios) if chain_ratios else 1.0
            length = safe_length(name, measured, fallback)
            ratio = length / original_length
            chain_ratios.append(ratio)
            fitted[name] = (current_head, current_head + direction * length)
            current_head = fitted[name][1]

    # Clavicules : leur pivot et leur largeur sont mesures independamment.
    for side in ("L", "R"):
        shoulder = f"DEF-shoulder.{side}"
        upper_arm = f"DEF-upper_arm.{side}"
        if shoulder not in source_heads or upper_arm not in source_heads:
            continue
        head = source_heads[shoulder]
        _, _, direction, _ = _original_bone_vectors(geometry, shoulder)
        length = safe_length(shoulder, (source_heads[upper_arm] - head).length)
        fitted[shoulder] = (head, head + direction * length)

    # Les doigts gardent l'eventail et les axes UAL, mais adoptent la taille de
    # la main source. Cela fonctionne meme si le bras source est encore en A.
    for side in ("L", "R"):
        hand = f"DEF-hand.{side}"
        if hand not in fitted:
            continue
        finger_chains = [chain for chain in FIT_CHAINS[5:] if chain[0].endswith(f".{side}")]
        finger_ratios: list[float] = []
        for chain in finger_chains:
            for index, name in enumerate(chain):
                if name not in source_map:
                    continue
                following = chain[index + 1] if index + 1 < len(chain) else None
                measured = measured_length(name, following)
                _, _, _, original_length = _original_bone_vectors(geometry, name)
                if measured is not None and 0.25 <= measured / original_length <= 4.0:
                    finger_ratios.append(measured / original_length)
        hand_scale = median(finger_ratios) if finger_ratios else 1.0
        hand_head = fitted[hand][0]
        original_hand_head, _, hand_direction, hand_length = _original_bone_vectors(geometry, hand)
        fitted[hand] = (hand_head, hand_head + hand_direction * hand_length * hand_scale)

        for chain in finger_chains:
            first = chain[0]
            if first not in source_map:
                continue
            original_first_head, _, _, _ = _original_bone_vectors(geometry, first)
            current_head = hand_head + (original_first_head - original_hand_head) * hand_scale
            for index, name in enumerate(chain):
                if name not in source_map:
                    break
                following = chain[index + 1] if index + 1 < len(chain) else None
                _, _, direction, _ = _original_bone_vectors(geometry, name)
                length = safe_length(name, measured_length(name, following), hand_scale)
                fitted[name] = (current_head, current_head + direction * length)
                current_head = fitted[name][1]

    select_only(target_rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail) in fitted.items():
        bone = target_rig.data.edit_bones.get(name)
        if bone is None:
            continue
        bone.head = head
        bone.tail = tail
        bone.roll = float(geometry[name]["roll"])
    bpy.ops.object.mode_set(mode="OBJECT")
    target_rig[PROPORTIONS_FITTED_TAG] = True
    bpy.context.view_layer.update()

    action_count = sum(1 for action in bpy.data.actions if action.get(GENERATED_TAG, False))
    result = {
        "source_pivots": len(source_map),
        "fitted_ual_bones": len(fitted),
        "median_scale": round(median(ratios), 5) if ratios else 1.0,
        "actions_preserved": action_count,
        "preset": "EXACT_GLTF197" if exact_gltf197_fit_sources(source_rig) else "GENERIC",
    }
    print("[UAL1 Rig] PROPORTION_FIT", result)
    return result


def validate_mapping(mapping: dict[str, str], unmapped: list[str]) -> None:
    mapped_targets = set(mapping.values())
    missing_critical = sorted(CRITICAL_UAL_BONES - mapped_targets)
    if missing_critical:
        source_hint = ", ".join(unmapped[:18]) or "aucun groupe pondere reconnu"
        raise RuntimeError(
            "Rig non reconnu automatiquement. Os UAL1 critiques sans source : "
            + ", ".join(missing_critical)
            + ". Groupes ponderes non reconnus : "
            + source_hint
        )


def validate_weight_coverage(
    meshes: list[bpy.types.Object],
    mapping: dict[str, str],
) -> None:
    failures: list[str] = []
    for mesh in meshes:
        mapped_indices = {
            group.index for group in mesh.vertex_groups if group.name in mapping
        }
        uncovered = sum(
            1
            for vertex in mesh.data.vertices
            if sum(
                assignment.weight
                for assignment in vertex.groups
                if assignment.group in mapped_indices
            )
            <= 1e-6
        )
        if uncovered:
            failures.append(f"{mesh.name}: {uncovered}")
    if failures:
        raise RuntimeError(
            "Transfert bloque avant suppression : sommets sans poids remappable ("
            + "; ".join(failures)
            + ")"
        )


def remap_vertex_groups(
    mesh: bpy.types.Object,
    mapping: dict[str, str],
    old_bone_names: set[str],
) -> tuple[int, int]:
    """Fusionne les poids existants dans les groupes UAL1 correspondants."""
    index_to_target = {
        group.index: mapping[group.name]
        for group in mesh.vertex_groups
        if group.name in mapping
    }

    accumulated: dict[str, dict[int, float]] = {}
    for vertex in mesh.data.vertices:
        for assignment in vertex.groups:
            target = index_to_target.get(assignment.group)
            if target is None:
                continue
            target_weights = accumulated.setdefault(target, {})
            target_weights[vertex.index] = target_weights.get(vertex.index, 0.0) + assignment.weight

    removable = [
        group
        for group in mesh.vertex_groups
        if group.name in old_bone_names or group.name in UAL_BONES
    ]
    for group in removable:
        mesh.vertex_groups.remove(group)

    assignments = 0
    for target, weights in accumulated.items():
        target_group = mesh.vertex_groups.new(name=target)
        for vertex_index, weight in weights.items():
            target_group.add([vertex_index], min(1.0, weight), "REPLACE")
            assignments += 1

    select_only(mesh)
    bpy.ops.object.vertex_group_clean(
        group_select_mode="ALL",
        limit=WEIGHT_CLEAN_LIMIT,
        keep_single=True,
    )
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=MAX_WEIGHTS)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    return len(accumulated), assignments


def apply_old_armature(mesh: bpy.types.Object, rig: bpy.types.Object) -> int:
    modifiers = [
        modifier
        for modifier in mesh.modifiers
        if modifier.type == "ARMATURE" and modifier.object == rig
    ]
    if not modifiers:
        raise RuntimeError(f"{mesh.name} n'a aucun modificateur lie a {rig.name}")
    if mesh.data.shape_keys is not None:
        raise RuntimeError(
            f"{mesh.name} contient des Shape Keys. Fais-en une copie sans Shape Keys avant ce transfert."
        )

    select_only(mesh)
    for modifier in modifiers:
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return len(modifiers)


def apply_object_rotation_scale(mesh: bpy.types.Object) -> None:
    select_only(mesh)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def bind_to_ual(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    world = mesh.matrix_world.copy()
    mesh.parent = rig
    mesh.matrix_world = world
    modifier = mesh.modifiers.new(ARMATURE_MODIFIER_NAME, "ARMATURE")
    modifier.object = rig
    modifier.use_deform_preserve_volume = True


def count_unweighted(mesh: bpy.types.Object, rig: bpy.types.Object) -> int:
    deform_indices = {
        group.index
        for group in mesh.vertex_groups
        if group.name in rig.data.bones and rig.data.bones[group.name].use_deform
    }
    return sum(
        1
        for vertex in mesh.data.vertices
        if sum(
            assignment.weight
            for assignment in vertex.groups
            if assignment.group in deform_indices
        )
        <= 1e-6
    )


def remove_old_rig_permanently(rig: bpy.types.Object) -> str:
    name = rig.name
    armature_data = rig.data
    bpy.data.objects.remove(rig, do_unlink=True)
    if armature_data.users == 0:
        bpy.data.armatures.remove(armature_data)
    return name


def remove_guide_objects_keep_rig(rig: bpy.types.Object) -> None:
    keep_world_parent(rig, None)
    for obj in list(bpy.data.objects):
        if obj != rig and obj.get(GENERATED_TAG, False):
            bpy.data.objects.remove(obj, do_unlink=True)
    collection = bpy.data.collections.get(TOOL_COLLECTION)
    if collection is not None:
        collection.name = "UAL1_RIG_FINAL"
        if rig.name not in collection.objects:
            move_to_collection(rig, collection)
    rig[GENERATED_TAG] = False
    rig[FINAL_RIG_TAG] = True


# -----------------------------------------------------------------------------
# Operateurs et interface
# -----------------------------------------------------------------------------


class UAL1_OT_create_temp_rigify(bpy.types.Operator):
    bl_idname = "ual1.create_temp_rigify"
    bl_label = "Creer Rigify Basic temporaire"
    bl_description = "Cree et pre-ajuste un metarig humain pour un modele sans armature"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        if temporary_rigify() is not None:
            self.report({"ERROR"}, "Un Rigify temporaire existe deja dans cette scene")
            return {"CANCELLED"}
        if ual_rig() is not None or fit_root() is not None:
            self.report({"ERROR"}, "Termine ou annule la preparation UAL en cours")
            return {"CANCELLED"}

        meshes = selected_character_meshes()
        if not meshes:
            self.report({"ERROR"}, "Selectionne le corps et tous les vetements du modele")
            return {"CANCELLED"}
        rigs = armatures_for_meshes(meshes)
        if rigs:
            self.report({"ERROR"}, "La selection possede deja une armature; utilise directement l'etape 1")
            return {"CANCELLED"}

        try:
            rig, scale = create_temporary_basic_rigify(meshes)
            select_only(rig)
            bpy.ops.object.mode_set(mode="EDIT")
            context.scene.ual1_autorig_status = (
                f"RIGIFY TEMPORAIRE : hauteur pre-ajustee x{scale:.4f}. "
                "Place maintenant les articulations dans le mesh."
            )
            self.report({"INFO"}, "Rigify Basic cree; corrige ses os en Edit Mode")
            return {"FINISHED"}
        except Exception as error:
            context.scene.ual1_autorig_status = f"ERREUR : {error}"
            self.report({"ERROR"}, str(error))
            raise


class UAL1_OT_edit_temp_rigify(bpy.types.Operator):
    bl_idname = "ual1.edit_temp_rigify"
    bl_label = "Ajuster les articulations"
    bl_description = "Repasse le Rigify temporaire en Edit Mode"

    def execute(self, context):
        rig = temporary_rigify()
        if rig is None:
            self.report({"ERROR"}, "Cree d'abord le Rigify Basic temporaire")
            return {"CANCELLED"}
        select_only(rig)
        bpy.ops.object.mode_set(mode="EDIT")
        context.scene.ual1_autorig_status = (
            "EDIT MODE RIGIFY : place bassin, genoux, chevilles, epaules, coudes et poignets"
        )
        return {"FINISHED"}


class UAL1_OT_bind_temp_rigify(bpy.types.Operator):
    bl_idname = "ual1.bind_temp_rigify"
    bl_label = "Creer les poids automatiques"
    bl_description = "Essaie Bone Heat puis complete les sommets oublies par proximite"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        rig = temporary_rigify()
        meshes = remembered_character_meshes()
        if rig is None or not meshes:
            self.report({"ERROR"}, "Rigify temporaire ou selection de meshes introuvable")
            return {"CANCELLED"}
        try:
            mesh_count, unweighted, fallback = bind_meshes_with_automatic_weights(rig, meshes)
            if fallback:
                context.scene.ual1_autorig_status = (
                    f"SKIN TEMPORAIRE : {mesh_count} mesh(es), secours par proximite pour "
                    f"{fallback} sommet(s). Teste puis corrige les accessoires rigides si necessaire."
                )
                self.report(
                    {"WARNING"},
                    f"Bone Heat incomplet : poids de secours crees pour {fallback} sommets. "
                    "Verifie les articulations et les accessoires rigides.",
                )
            else:
                context.scene.ual1_autorig_status = (
                    f"SKIN TEMPORAIRE : {mesh_count} mesh(es), {unweighted} sommet(s) sans poids. "
                    "Selectionne un mesh puis lance l'etape 1."
                )
                self.report({"INFO"}, "Poids automatiques termines; passe a l'etape 1")
            return {"FINISHED"}
        except Exception as error:
            context.scene.ual1_autorig_status = f"ERREUR : {error}"
            self.report({"ERROR"}, str(error))
            raise


class UAL1_OT_prepare_rigid_fix(bpy.types.Operator):
    bl_idname = "ual1.prepare_rigid_fix"
    bl_label = "Corriger des pieces rigides"
    bl_description = "Remet la pose de repos et ouvre le mesh en Edit Mode pour selectionner l'armure"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        rig = temporary_rigify()
        meshes = remembered_character_meshes()
        if rig is None or not meshes:
            self.report({"ERROR"}, "Cree d'abord le Rigify temporaire et ses poids")
            return {"CANCELLED"}
        mesh = context.object if context.object in meshes else meshes[0]
        ensure_object_mode()
        reset_pose(rig)
        select_only(mesh)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        context.scene.ual1_autorig_status = (
            "CORRECTION RIGIDE : survole une piece et presse L, choisis son os, puis attache-la"
        )
        self.report({"INFO"}, "Edit Mode : survole chaque piece d'armure et presse L")
        return {"FINISHED"}


class UAL1_OT_assign_selected_rigid(bpy.types.Operator):
    bl_idname = "ual1.assign_selected_rigid"
    bl_label = "Attacher la selection a cet os"
    bl_description = "Donne 100 % du poids a l'os choisi pour les sommets selectionnes"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        rig = temporary_rigify()
        mesh = context.edit_object
        if rig is None or mesh is None or mesh.type != "MESH":
            self.report({"ERROR"}, "Utilise d'abord Corriger des pieces rigides")
            return {"CANCELLED"}

        bone_name = context.scene.ual1_rigid_bone
        bpy.ops.object.mode_set(mode="OBJECT")
        selected = [vertex.index for vertex in mesh.data.vertices if vertex.select]
        if not selected:
            select_only(mesh)
            bpy.ops.object.mode_set(mode="EDIT")
            self.report({"ERROR"}, "Aucun sommet selectionne; survole une piece et presse L")
            return {"CANCELLED"}
        try:
            assign_vertices_rigidly(mesh, rig, selected, bone_name)
        finally:
            select_only(mesh)
            bpy.ops.object.mode_set(mode="EDIT")

        label = dict((identifier, name) for identifier, name, _description in RIGID_ATTACHMENT_ITEMS)[
            bone_name
        ]
        context.scene.ual1_autorig_status = (
            f"CORRECTION RIGIDE : {len(selected)} sommets attaches a {label}. Teste en Pose Mode."
        )
        self.report({"INFO"}, f"{len(selected)} sommets attaches a {label}")
        return {"FINISHED"}


class UAL1_OT_prepare(bpy.types.Operator):
    bl_idname = "ual1.prepare"
    bl_label = "1 - Importer le gabarit UAL1"
    bl_description = "Importe UAL1 et cree le controle d'ajustement sans modifier les poids"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        if ual_rig() is not None or fit_root() is not None:
            self.report({"ERROR"}, "Un transfert UAL1 est deja prepare ou termine dans cette scene")
            return {"CANCELLED"}

        meshes = selected_character_meshes()
        if not meshes:
            self.report({"ERROR"}, "Selectionne tous les meshes skinnes du personnage")
            return {"CANCELLED"}

        rigs = armatures_for_meshes(meshes)
        if len(rigs) != 1:
            self.report(
                {"ERROR"},
                f"Il faut exactement un ancien rig pour la selection; trouve(s) : {len(rigs)}",
            )
            return {"CANCELLED"}

        rig = rigs[0]
        meshes = all_skinned_meshes_for_rig(rig)
        if not meshes:
            self.report({"ERROR"}, f"Aucun mesh skinne trouve pour {rig.name}")
            return {"CANCELLED"}

        path = Path(bpy.path.abspath(context.scene.ual1_autorig_path))
        if not path.is_file():
            self.report({"ERROR"}, f"UAL1_Standard.glb introuvable : {path}")
            return {"CANCELLED"}

        try:
            ensure_object_mode()
            remember_character(meshes)
            rig[OLD_RIG_TAG] = True
            reset_pose(rig)
            context.scene.frame_set(0)
            new_rig, reference, action_count = import_ual1(path)
            control = create_fit_control(meshes, rig)
            exact_preset = EXACT_GLTF197_SIGNATURE.issubset(
                {bone.name for bone in rig.data.bones}
            )
            scale = 1.0
            if context.scene.ual1_auto_align:
                scale = align_fit_control(control, meshes, reference)
            select_only(control)
            context.scene.ual1_autorig_status = (
                f"AJUSTEMENT : {len(meshes)} mesh(es), ancien rig {rig.name}, "
                f"{action_count} animations; echelle auto {scale:.4f}; "
                f"preset {'EXACT GLTF197' if exact_preset else 'generique'}"
            )
            print(
                "[UAL1 Rig] PREPARED",
                {
                    "meshes": [mesh.name for mesh in meshes],
                    "old_rig": rig.name,
                    "new_rig": new_rig.name,
                    "actions": action_count,
                    "auto_scale": round(scale, 6),
                    "mapping_preset": "EXACT_GLTF197" if exact_preset else "GENERIC",
                },
            )
            self.report({"INFO"}, "Gabarit pret : ajuste le controle orange sur le mannequin bleu")
            return {"FINISHED"}
        except Exception as error:
            context.scene.ual1_autorig_status = f"ERREUR : {error}"
            self.report({"ERROR"}, str(error))
            raise


class UAL1_OT_select_fit_control(bpy.types.Operator):
    bl_idname = "ual1.select_fit_control"
    bl_label = "Selectionner le controle orange"

    def execute(self, context):
        control = fit_root()
        if control is None:
            self.report({"ERROR"}, "Lance d'abord l'etape 1")
            return {"CANCELLED"}
        select_only(control)
        return {"FINISHED"}


class UAL1_OT_auto_align(bpy.types.Operator):
    bl_idname = "ual1.auto_align"
    bl_label = "Recaler hauteur + sol"
    bl_description = "Recentre et remet a l'echelle le personnage sur le mannequin"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        control = fit_root()
        reference = ual_reference()
        meshes = remembered_character_meshes()
        if control is None or reference is None or not meshes:
            self.report({"ERROR"}, "Preparation UAL1 incomplete")
            return {"CANCELLED"}
        scale = align_fit_control(control, meshes, reference)
        select_only(control)
        context.scene.ual1_autorig_status = f"Recalage applique : facteur {scale:.5f}"
        return {"FINISHED"}


class UAL1_OT_fit_proportions(bpy.types.Operator):
    bl_idname = "ual1.fit_proportions"
    bl_label = "Adapter automatiquement UAL aux os"
    bl_description = (
        "Mesure les pivots et longueurs de l'ancien rig puis personnalise la T-pose UAL"
    )
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        source = old_rig()
        target = ual_rig()
        meshes = remembered_character_meshes()
        if source is None or target is None or not meshes:
            self.report({"ERROR"}, "Preparation UAL1 incomplete")
            return {"CANCELLED"}
        try:
            result = fit_ual_proportions_to_source(source, target, meshes)
            reference = ual_reference()
            if reference is not None:
                set_visible(reference, False)
            select_only(target)
            context.scene.ual1_autorig_status = (
                f"UAL PERSONNALISE : {result['fitted_ual_bones']} os ajustes, "
                f"{result['actions_preserved']} animations conservees. "
                "Pose maintenant l'ancien rig sur ce squelette."
            )
            self.report({"INFO"}, "Proportions UAL ajustees; les actions sont conservees")
            return {"FINISHED"}
        except Exception as error:
            context.scene.ual1_autorig_status = f"ERREUR : {error}"
            self.report({"ERROR"}, str(error))
            raise


class UAL1_OT_edit_ual_rig(bpy.types.Operator):
    bl_idname = "ual1.edit_ual_rig"
    bl_label = "Finir UAL a la main"
    bl_description = "Selectionne UAL et passe en Edit Mode pour corriger ses pivots"

    def execute(self, context):
        rig = ual_rig()
        if rig is None:
            self.report({"ERROR"}, "Rig UAL1 introuvable")
            return {"CANCELLED"}
        select_only(rig)
        bpy.ops.object.mode_set(mode="EDIT")
        context.scene.ual1_autorig_status = (
            "EDIT MODE UAL : ajuste les pivots/longueurs; evite de changer les axes ou la hierarchie"
        )
        return {"FINISHED"}


class UAL1_OT_restore_ual_rig(bpy.types.Operator):
    bl_idname = "ual1.restore_ual_rig"
    bl_label = "Retablir UAL original"
    bl_description = "Annule le fitting et restaure exactement la T-pose UAL importee"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        rig = ual_rig()
        if rig is None:
            self.report({"ERROR"}, "Rig UAL1 introuvable")
            return {"CANCELLED"}
        restore_ual_rest_geometry(rig)
        select_only(rig)
        context.scene.ual1_autorig_status = "T-pose et proportions UAL originales restaurees"
        return {"FINISHED"}


class UAL1_OT_pose_old_rig(bpy.types.Operator):
    bl_idname = "ual1.pose_old_rig"
    bl_label = "Poser l'ancien rig"
    bl_description = "Selectionne l'ancien rig et passe en Pose Mode pour matcher la T-pose"

    def execute(self, context):
        rig = old_rig()
        if rig is None:
            self.report({"ERROR"}, "Ancien rig introuvable")
            return {"CANCELLED"}
        select_only(rig)
        bpy.ops.object.mode_set(mode="POSE")
        context.scene.ual1_autorig_status = (
            "POSE MODE : ajuste uniquement l'ancien rig pour faire coincider le personnage au gabarit"
        )
        return {"FINISHED"}


class UAL1_OT_toggle_reference(bpy.types.Operator):
    bl_idname = "ual1.toggle_reference"
    bl_label = "Afficher / cacher le gabarit"

    def execute(self, context):
        reference = ual_reference()
        if reference is None:
            return {"CANCELLED"}
        visible = reference.hide_get() or reference.hide_viewport
        set_visible(reference, visible)
        return {"FINISHED"}


class UAL1_OT_finalize(bpy.types.Operator):
    bl_idname = "ual1.finalize"
    bl_label = "5 - Transferer vers UAL1"
    bl_description = "Fige la pose, conserve/remappe les poids, supprime l'ancien rig et lie UAL1"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        meshes = remembered_character_meshes()
        previous_rig = old_rig()
        new_rig = ual_rig()
        control = fit_root()
        if not meshes or previous_rig is None or new_rig is None or control is None:
            self.report({"ERROR"}, "L'etape d'ajustement n'est pas complete")
            return {"CANCELLED"}

        mapping, unmapped = build_bone_mapping(previous_rig, meshes)
        try:
            print(
                "[UAL1 Rig] MAPPING_CHECK",
                {
                    "exact_gltf197_preset": EXACT_GLTF197_SIGNATURE.issubset(
                        {bone.name for bone in previous_rig.data.bones}
                    ),
                    "weighted_groups_mapped": mapping,
                    "weighted_groups_unmapped": unmapped,
                },
            )
            validate_mapping(mapping, unmapped)
            validate_weight_coverage(meshes, mapping)
            for mesh in meshes:
                if not any(
                    modifier.type == "ARMATURE" and modifier.object == previous_rig
                    for modifier in mesh.modifiers
                ):
                    raise RuntimeError(f"{mesh.name} n'est pas skinne par {previous_rig.name}")
                if mesh.data.shape_keys is not None:
                    raise RuntimeError(f"{mesh.name} a des Shape Keys non prises en charge")

            ensure_object_mode()
            old_bone_names = {bone.name for bone in previous_rig.data.bones}
            total_assignments = 0
            for mesh in meshes:
                apply_old_armature(mesh, previous_rig)
                keep_world_parent(mesh, None)
                apply_object_rotation_scale(mesh)
                _, assignments = remap_vertex_groups(mesh, mapping, old_bone_names)
                total_assignments += assignments

            deleted_name = remove_old_rig_permanently(previous_rig)
            for mesh in meshes:
                bind_to_ual(mesh, new_rig)

            remove_guide_objects_keep_rig(new_rig)
            reset_pose(new_rig)
            total_unweighted = sum(count_unweighted(mesh, new_rig) for mesh in meshes)
            vertices, triangles = mesh_statistics(meshes)
            action_count = sum(1 for action in bpy.data.actions if action.get(GENERATED_TAG, False))
            context.scene.ual1_action_name = "Idle_Loop" if bpy.data.actions.get("Idle_Loop") else ""
            context.scene.ual1_autorig_status = (
                f"TERMINE : ancien rig {deleted_name} supprime, 53 os UAL1, "
                f"{action_count} animations, {total_unweighted} sommet(s) sans poids"
            )
            select_only(new_rig)
            print(
                "[UAL1 Rig] PASS",
                {
                    "old_rig_deleted": deleted_name,
                    "new_rig": new_rig.name,
                    "mapped_bones": len(mapping),
                    "unmapped_old_bones": unmapped,
                    "weight_assignments": total_assignments,
                    "meshes": [mesh.name for mesh in meshes],
                    "vertices": vertices,
                    "triangles": triangles,
                    "actions": action_count,
                    "unweighted_vertices": total_unweighted,
                },
            )
            if total_unweighted:
                self.report({"WARNING"}, context.scene.ual1_autorig_status)
            else:
                self.report({"INFO"}, context.scene.ual1_autorig_status)
            return {"FINISHED"}
        except Exception as error:
            context.scene.ual1_autorig_status = f"ERREUR : {error}"
            self.report({"ERROR"}, str(error))
            raise


class UAL1_OT_apply_action(bpy.types.Operator):
    bl_idname = "ual1.apply_action"
    bl_label = "Afficher l'animation"

    def execute(self, context):
        rig = ual_rig()
        action = bpy.data.actions.get(context.scene.ual1_action_name)
        if rig is None or action is None:
            self.report({"ERROR"}, "Rig UAL1 ou animation introuvable")
            return {"CANCELLED"}
        ensure_object_mode()
        if rig.animation_data is None:
            rig.animation_data_create()
        rig.animation_data.action = action
        start, end = action.frame_range
        context.scene.frame_start = int(start)
        context.scene.frame_end = int(end)
        context.scene.frame_set(int(start))
        select_only(rig)
        context.scene.ual1_autorig_status = f"Animation active : {action.name}"
        return {"FINISHED"}


class UAL1_OT_rest_pose(bpy.types.Operator):
    bl_idname = "ual1.rest_pose"
    bl_label = "Pose de repos"

    def execute(self, context):
        rig = ual_rig()
        if rig is None:
            return {"CANCELLED"}
        ensure_object_mode()
        reset_pose(rig)
        context.scene.frame_set(0)
        select_only(rig)
        context.scene.ual1_autorig_status = "Pose de repos UAL1 active"
        return {"FINISHED"}


class UAL1_OT_toggle_playback(bpy.types.Operator):
    bl_idname = "ual1.toggle_playback"
    bl_label = "Lecture / pause"

    def execute(self, context):
        if context.screen is not None:
            bpy.ops.screen.animation_play()
        return {"FINISHED"}


class UAL1_PT_panel(bpy.types.Panel):
    bl_label = "UAL1 Rig Transfer"
    bl_idname = "UAL1_PT_rig_transfer"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "UAL1 Rig"

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        prepared = fit_root() is not None and old_rig() is not None
        current_ual_rig = ual_rig()
        final = current_ual_rig is not None and current_ual_rig.get(FINAL_RIG_TAG, False)
        temp_rig = temporary_rigify()

        layout.label(text=f"Version {SCRIPT_VERSION}", icon="FILE_SCRIPT")

        box = layout.box()
        box.enabled = not prepared and not final
        box.label(text="0 - Option : modele sans rig")
        box.label(text="Selectionne corps + vetements")
        box.operator("ual1.create_temp_rigify", icon="OUTLINER_OB_ARMATURE")
        row = box.row(align=True)
        row.enabled = temp_rig is not None
        row.operator("ual1.edit_temp_rigify", icon="EDITMODE_HLT")
        row.operator("ual1.bind_temp_rigify", icon="MOD_ARMATURE")
        box.label(text="Le pre-ajustement auto doit etre verifie", icon="INFO")
        rigid = box.column(align=True)
        rigid.enabled = temp_rig is not None
        rigid.separator()
        rigid.label(text="Accessoires qui suivent le mauvais os", icon="BONE_DATA")
        rigid.operator("ual1.prepare_rigid_fix", icon="EDITMODE_HLT")
        rigid.prop(scene, "ual1_rigid_bone", text="Attacher a")
        rigid.operator("ual1.assign_selected_rigid", icon="GROUP_BONE")
        rigid.label(text="Edit Mode : survole la piece puis L", icon="INFO")

        box = layout.box()
        box.label(text="1 - Selection : corps + vetements")
        box.prop(scene, "ual1_autorig_path", text="Fichier UAL1")
        box.prop(scene, "ual1_auto_align")
        box.operator("ual1.prepare", icon="IMPORT")

        box = layout.box()
        box.enabled = prepared
        box.label(text="2 - Alignement global")
        box.operator("ual1.select_fit_control", icon="EMPTY_AXIS")
        box.label(text="G/S/R : taille, position, rotation")
        box.operator("ual1.auto_align", icon="CON_LOCLIKE")

        box = layout.box()
        box.enabled = prepared
        box.label(text="3 - Adapter les proportions UAL")
        box.operator("ual1.fit_proportions", icon="ARMATURE_DATA")
        row = box.row(align=True)
        row.operator("ual1.edit_ual_rig", icon="EDITMODE_HLT")
        row.operator("ual1.restore_ual_rig", icon="LOOP_BACK")
        box.label(text="Largeurs/longueurs oui; hierarchie non", icon="INFO")

        box = layout.box()
        box.enabled = prepared
        box.label(text="4 - Mettre le personnage en T-pose")
        box.operator("ual1.pose_old_rig", icon="POSE_HLT")
        box.operator("ual1.toggle_reference", icon="HIDE_OFF")
        box.label(text="Tourne seulement l'ancien rig en Pose Mode", icon="INFO")
        box.label(text="Ne modifie pas les sommets du mesh", icon="ERROR")

        box = layout.box()
        box.enabled = prepared
        box.label(text="5 - Validation definitive")
        box.label(text="Sauvegarde une copie du .blend avant", icon="ERROR")
        box.operator("ual1.finalize", icon="ARMATURE_DATA")
        box.label(text="L'ancien rig sera supprime")

        box = layout.box()
        box.enabled = final
        box.label(text="6 - Tester les 46 animations")
        box.prop_search(scene, "ual1_action_name", bpy.data, "actions", text="Action")
        row = box.row(align=True)
        row.operator("ual1.apply_action", icon="ACTION")
        row.operator("ual1.rest_pose", icon="LOOP_BACK")
        box.operator("ual1.toggle_playback", icon="PLAY")

        if scene.ual1_autorig_status:
            status = layout.box()
            status.label(text=scene.ual1_autorig_status)


CLASSES = (
    UAL1_OT_create_temp_rigify,
    UAL1_OT_edit_temp_rigify,
    UAL1_OT_bind_temp_rigify,
    UAL1_OT_prepare_rigid_fix,
    UAL1_OT_assign_selected_rigid,
    UAL1_OT_prepare,
    UAL1_OT_select_fit_control,
    UAL1_OT_auto_align,
    UAL1_OT_fit_proportions,
    UAL1_OT_edit_ual_rig,
    UAL1_OT_restore_ual_rig,
    UAL1_OT_pose_old_rig,
    UAL1_OT_toggle_reference,
    UAL1_OT_finalize,
    UAL1_OT_apply_action,
    UAL1_OT_rest_pose,
    UAL1_OT_toggle_playback,
    UAL1_PT_panel,
)


def unregister() -> None:
    for cls in reversed(CLASSES):
        # Lors d'un nouveau collage/execution, les noms Python pointent deja
        # vers les nouvelles classes. Recuperer la classe enregistree dans
        # bpy.types evite d'empiler deux versions du meme panneau.
        registered_cls = getattr(bpy.types, cls.__name__, None)
        if registered_cls is None:
            registered_cls = getattr(bpy.types, getattr(cls, "bl_idname", ""), None)
        if registered_cls is None:
            continue
        try:
            bpy.utils.unregister_class(registered_cls)
        except RuntimeError:
            pass
    for name in (
        "ual1_autorig_path",
        "ual1_auto_align",
        "ual1_action_name",
        "ual1_autorig_status",
        "ual1_rigid_bone",
    ):
        if hasattr(bpy.types.Scene, name):
            delattr(bpy.types.Scene, name)


def register() -> None:
    unregister()
    for cls in CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.ual1_autorig_path = StringProperty(
        name="UAL1 Standard GLB",
        subtype="FILE_PATH",
        default=default_ual1_path(),
    )
    bpy.types.Scene.ual1_auto_align = BoolProperty(
        name="Aligner automatiquement hauteur + sol",
        default=True,
    )
    bpy.types.Scene.ual1_rigid_bone = EnumProperty(
        name="Os pour accessoire rigide",
        items=RIGID_ATTACHMENT_ITEMS,
        default="spine",
    )
    bpy.types.Scene.ual1_action_name = StringProperty(name="Animation")
    bpy.types.Scene.ual1_autorig_status = StringProperty(name="Etat")
    print(f"[UAL1 Rig] Outil {SCRIPT_VERSION} charge. Vue 3D > N > UAL1 Rig")


register()
