"""Spartan Animation Workbench.

La scène Blender est une session d'édition, jamais une source runtime. Le script
charge le manifeste généré par Godot, importe uniquement les collections qu'il
possède, retargete les previews vers le rig visible et écrit les décisions dans
un JSON séparé. Il peut être lancé par Blender UI ou en mode background avec
``--self-test``.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import shutil
import sys
import tempfile
import unicodedata
from pathlib import Path

import bpy
from bpy.props import BoolProperty, CollectionProperty, EnumProperty, FloatProperty, FloatVectorProperty, IntProperty, StringProperty
from bpy.types import Operator, Panel, PropertyGroup, UIList
from mathutils import Matrix


SCRIPT_VERSION = "0.3.0"
OWNED_TAG = "hoplite_animation_workbench_owned"
SOURCE_TAG = "hoplite_animation_workbench_source"
PREVIEW_ACTION_TAG = "hoplite_animation_workbench_preview"
EDITABLE_ACTION_TAG = "hoplite_animation_workbench_editable"
PROJECTS_ROOT_RELATIVE = Path("tools") / "animation_workbench" / "projects"
SCOPE_PRIORITY = {"rig_common": 10, "rig_family": 10, "weapon_pack": 20, "archetype": 30}

PROJECT_ROOT = Path.cwd()
MANIFEST_PATH = PROJECT_ROOT / "tools" / "animation_workbench" / "data" / "animation_workbench_manifest.json"
OVERRIDES_PATH = PROJECT_ROOT / "tools" / "animation_workbench" / "data" / "workbench_overrides.json"
MANIFEST: dict = {}
OVERRIDES: dict = {"schema_version": 1, "bindings": []}
UI_SYNC_GUARD = False
AUTO_PREVIEW_REQUEST = 0
AUTOSAVE_TIMER_REGISTERED = False


def _parse_args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--project-root")
    parser.add_argument("--manifest")
    parser.add_argument("--overrides")
    parser.add_argument("--self-test", action="store_true")
    args, _unknown = parser.parse_known_args(raw)
    return args


def _load_json(path: Path, default: dict | None = None) -> dict:
    if not path.is_file():
        return dict(default or {})
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise RuntimeError(f"JSON object expected: {path}")
    return data


def _atomic_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    temporary.replace(path)


def _resolve_project_path(value: str) -> Path:
    if value.startswith("res://"):
        return (PROJECT_ROOT / value.removeprefix("res://")).resolve()
    return Path(value).expanduser().resolve()


def _ui_text(value: object) -> str:
    """Return stable ASCII for Blender labels without changing manifest IDs."""
    text = str(value or "")
    replacements = {
        "\u2013": "-",
        "\u2014": "-",
        "\u2022": "|",
        "\u2192": "->",
        "\u26a0": "[!]",
        "\u00b0": " deg",
    }
    for source, replacement in replacements.items():
        text = text.replace(source, replacement)
    return unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")


def _hex_color(value: str) -> tuple[float, float, float, float]:
    text = str(value or "#EC4899").lstrip("#")
    if len(text) != 6:
        text = "EC4899"
    try:
        return tuple(int(text[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)
    except ValueError:
        return (0.925, 0.282, 0.600, 1.0)


def _archetypes() -> list[dict]:
    return list(MANIFEST.get("archetypes") or [])


def _sources() -> list[dict]:
    return list(MANIFEST.get("sources") or [])


def _monitoring() -> dict:
    return dict(MANIFEST.get("monitoring") or {})


def _monitor_character_items(_self, _context):
    values = [("ALL", "Tous les personnages", "", "GROUP", 0)]
    profiles = [item for item in _archetypes() if not item.get("virtual")]
    for index, item in enumerate(profiles, start=1):
        values.append((
            str(item.get("archetype_id") or "unknown"),
            _ui_text(item.get("display_name") or item.get("archetype_id")),
            str(item.get("model_path") or ""),
            "OUTLINER_OB_ARMATURE",
            index,
        ))
    return values


def _monitor_weapon_items(_self, _context):
    values = [("ALL", "Toutes les armes", "", "MOD_ARMATURE", 0)]
    weapons = list(_monitoring().get("weapons") or [])
    for index, item in enumerate(weapons, start=1):
        weapon = str(item.get("weapon_family") or "unarmed")
        values.append((weapon, _ui_text(weapon).upper(), "", "MOD_ARMATURE", index))
    return values


def _monitor_provenance_items(_self, _context):
    values = [("ALL", "Toutes les provenances", "", "COLOR", 0)]
    for index, item in enumerate(_monitoring().get("provenance_legend") or [], start=1):
        values.append((
            str(item.get("id") or "unknown"),
            _ui_text(item.get("label") or item.get("id")),
            str(item.get("color") or ""),
            "COLOR",
            index,
        ))
    return values


def _monitor_truth_items(_self, _context):
    return [
        ("ALL", "Tous les etats", "", "FILTER", 0),
        ("runtime_exact", "Runtime exact", "Source jouee telle quelle", "CHECKMARK", 1),
        ("runtime_layered", "Runtime compose", "Animation combinee avec une couche runtime", "MODIFIER", 2),
        ("runtime_fallback", "Fallback runtime", "Animation de secours reellement jouee", "QUESTION", 3),
        ("runtime_unreachable", "Inaccessible", "Declare mais jamais atteint par le code", "CANCEL", 4),
        ("future_missing", "A produire", "Action absente du runtime actuel", "ERROR", 5),
    ]


def _monitor_row_matches(scene, item) -> bool:
    scope = scene.hoplite_monitor_scope
    if scope == "CHARACTER" and scene.hoplite_monitor_character != "ALL" and item.archetype_id != scene.hoplite_monitor_character:
        return False
    if scope == "WEAPON" and scene.hoplite_monitor_weapon != "ALL" and item.weapon_family != scene.hoplite_monitor_weapon:
        return False
    if scope == "ISSUES" and item.runtime_reachable:
        return False
    if scene.hoplite_monitor_provenance != "ALL" and item.provenance != scene.hoplite_monitor_provenance:
        return False
    if scene.hoplite_monitor_truth != "ALL" and item.runtime_truth != scene.hoplite_monitor_truth:
        return False
    query = scene.hoplite_monitor_search.strip().lower()
    haystack = " ".join((item.character_name, item.weapon_family, item.action_label, item.runtime_source_clip, item.provenance_label)).lower()
    return not query or all(term in haystack for term in query.split())


def _selected_archetype(scene) -> dict | None:
    wanted = scene.hoplite_archetype
    return next((item for item in _archetypes() if item.get("archetype_id") == wanted), None)


def _selected_action(scene) -> "HOPLITE_ActionItem | None":
    if not scene.hoplite_actions:
        return None
    index = max(0, min(scene.hoplite_action_index, len(scene.hoplite_actions) - 1))
    return scene.hoplite_actions[index]


def _selected_clip(scene) -> "HOPLITE_ClipItem | None":
    if not scene.hoplite_clips:
        return None
    index = max(0, min(scene.hoplite_clip_index, len(scene.hoplite_clips) - 1))
    return scene.hoplite_clips[index]


def _profile_scope(profile: dict) -> tuple[str, str]:
    scope = str(profile.get("assignment_scope") or "archetype")
    scope_id = str(profile.get("scope_id") or profile.get("archetype_id") or "")
    return scope, scope_id


def _binding_for(profile: dict, action_id: str) -> dict | None:
    profile_id = str(profile.get("archetype_id") or "")
    profile_scope, profile_scope_id = _profile_scope(profile)
    candidates = []
    for binding in OVERRIDES.get("bindings") or []:
        if binding.get("action_id") != action_id or not binding.get("enabled", True):
            continue
        scope = str(binding.get("scope") or "archetype")
        scope_id = str(binding.get("scope_id") or "")
        source_profile_id = str(binding.get("archetype_id") or "")
        if profile.get("virtual"):
            if scope == profile_scope and (scope_id or profile_scope_id) == profile_scope_id:
                candidates.append(binding)
            continue
        if scope == "archetype" and (scope_id or source_profile_id) == profile_id:
            candidates.append(binding)
        elif scope == "weapon_pack":
            expected = scope_id or str(next((item.get("weapon_family") for item in _archetypes() if item.get("archetype_id") == source_profile_id), ""))
            if expected == str(profile.get("weapon_family") or ""):
                candidates.append(binding)
        elif scope == "rig_common":
            candidates.append(binding)
        elif scope == "rig_family":
            expected = scope_id or str(next((item.get("rig_family") for item in _archetypes() if item.get("archetype_id") == source_profile_id), ""))
            if expected == str(profile.get("rig_family") or ""):
                candidates.append(binding)
    return max(candidates, key=lambda item: SCOPE_PRIORITY.get(str(item.get("scope")), 0), default=None)


def _scope_label(scope: str, scope_id: str) -> str:
    if scope == "archetype":
        return f"Personnage : {scope_id} (priorité 3)"
    if scope == "weapon_pack":
        return f"Arme : {scope_id} (priorité 2)"
    return "Rig commun (priorité 1)"


def _save_overrides(create_backup: bool = True) -> None:
    if create_backup and OVERRIDES_PATH.is_file():
        backups = OVERRIDES_PATH.parent / "backups"
        backups.mkdir(parents=True, exist_ok=True)
        timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        shutil.copy2(OVERRIDES_PATH, backups / f"workbench_overrides_{timestamp}.json")
    _atomic_json(OVERRIDES_PATH, OVERRIDES)


def _upsert_binding(profile: dict, action_item, source_path: str, source_clip: str) -> tuple[str, str]:
    global OVERRIDES
    scope, scope_id = _profile_scope(profile)
    binding = {
        "archetype_id": profile["archetype_id"],
        "action_id": action_item.action_id,
        "source_path": source_path,
        "source_clip": source_clip,
        "scope": scope,
        "scope_id": scope_id,
        "enabled": True,
    }
    bindings = list(OVERRIDES.get("bindings") or [])
    replaced = False
    for index, existing in enumerate(bindings):
        existing_scope = str(existing.get("scope") or "archetype")
        existing_scope_id = str(existing.get("scope_id") or existing.get("archetype_id") or "")
        if existing_scope == scope and existing_scope_id == scope_id and existing.get("action_id") == action_item.action_id:
            bindings[index] = binding
            replaced = True
            break
    if not replaced:
        bindings.append(binding)
    OVERRIDES = {"schema_version": 1, "bindings": bindings}
    _save_overrides(create_backup=True)
    action_item.override_active = True
    action_item.binding_scope = scope
    action_item.source_path = source_path
    action_item.source_clip = source_clip
    return scope, scope_id


def _archetype_items(_self, _context):
    values = []
    for index, item in enumerate(_archetypes()):
        warning = " [origine incoherente]" if item.get("origin_mismatch") else ""
        label = f"{_ui_text(item.get('display_name', item.get('archetype_id')))}{warning}"
        values.append((item.get("archetype_id", "unknown"), label, item.get("model_path", ""), "ARMATURE_DATA", index))
    return values or [("none", "Aucun personnage", "Regenerer le manifeste", "ERROR", 0)]


def _populate_actions(scene) -> None:
    global UI_SYNC_GUARD
    UI_SYNC_GUARD = True
    scene.hoplite_actions.clear()
    archetype = _selected_archetype(scene)
    if not archetype:
        UI_SYNC_GUARD = False
        return
    for raw in archetype.get("actions") or []:
        item = scene.hoplite_actions.add()
        item.action_id = str(raw.get("action_id") or "")
        item.label = _ui_text(raw.get("label") or item.action_id)
        item.status = str(raw.get("status") or "unknown")
        item.category = str(raw.get("category") or "type")
        item.phase = str(raw.get("phase") or "base")
        item.layer = str(raw.get("layer") or "full_body")
        item.runtime_key = str(raw.get("runtime_key") or "")
        item.source_path = str(raw.get("source_path") or "")
        item.source_clip = str(raw.get("source_clip") or "")
        item.default_scope = str(raw.get("scope") or "archetype")
        item.runtime_supported = bool(raw.get("runtime_binding_supported"))
        item.runtime_reachable = bool(raw.get("runtime_reachable"))
        item.runtime_truth = str(raw.get("runtime_truth") or "unknown")
        item.runtime_truth_label = _ui_text(raw.get("runtime_truth_label") or item.runtime_truth)
        item.runtime_modes = ", ".join(str(value) for value in raw.get("runtime_modes") or [])
        item.runtime_driver = str(raw.get("runtime_driver") or "none")
        item.runtime_source_path = str(raw.get("runtime_source_path") or "")
        item.runtime_source_clip = str(raw.get("runtime_source_clip") or "")
        item.preview_source_path = str(raw.get("preview_source_path") or item.source_path)
        item.preview_source_clip = str(raw.get("preview_source_clip") or item.source_clip)
        item.preview_fidelity = str(raw.get("preview_fidelity") or "unknown")
        item.provenance = str(raw.get("provenance") or "unknown")
        item.provenance_label = _ui_text(raw.get("provenance_label") or item.provenance)
        item.provenance_color = _hex_color(str(raw.get("provenance_color") or "#EC4899"))
        item.weapon_family = str(raw.get("weapon_family") or archetype.get("weapon_family") or "unarmed")
        item.full_body = bool(raw.get("full_body", True))
        item.hips_weight = float(raw.get("hips_weight", 1.0))
        item.start_fraction = float(raw.get("start_fraction", 0.0))
        item.runtime_reason = _ui_text(raw.get("runtime_reason") or "")
        item.source_path = item.preview_source_path or item.source_path
        item.source_clip = item.preview_source_clip or item.source_clip
        override = _binding_for(archetype, item.action_id)
        if override:
            item.source_path = str(override.get("source_path") or item.source_path)
            item.source_clip = str(override.get("source_clip") or item.source_clip)
            item.override_active = bool(override.get("enabled", True))
            item.binding_scope = str(override.get("scope") or "archetype")
    scene.hoplite_action_index = min(scene.hoplite_action_index, max(0, len(scene.hoplite_actions) - 1))
    UI_SYNC_GUARD = False


def _populate_monitor(scene) -> None:
    scene.hoplite_monitor_rows.clear()
    scene.hoplite_provenance_legend.clear()
    for raw in _monitoring().get("provenance_legend") or []:
        legend = scene.hoplite_provenance_legend.add()
        legend.provenance = str(raw.get("id") or "unknown")
        legend.label = _ui_text(raw.get("label") or legend.provenance)
        legend.color = _hex_color(str(raw.get("color") or "#EC4899"))
    for raw in _monitoring().get("rows") or []:
        item = scene.hoplite_monitor_rows.add()
        item.archetype_id = str(raw.get("archetype_id") or "")
        item.character_name = _ui_text(raw.get("character_name") or item.archetype_id)
        item.weapon_family = _ui_text(raw.get("weapon_family") or "unarmed")
        item.action_id = str(raw.get("action_id") or "")
        item.action_label = _ui_text(raw.get("label") or item.action_id)
        item.runtime_key = str(raw.get("runtime_key") or "")
        item.runtime_source_path = str(raw.get("runtime_source_path") or "")
        item.runtime_source_clip = str(raw.get("runtime_source_clip") or "")
        item.preview_source_path = str(raw.get("preview_source_path") or raw.get("source_path") or "")
        item.preview_source_clip = str(raw.get("preview_source_clip") or raw.get("source_clip") or "")
        item.runtime_truth = str(raw.get("runtime_truth") or "unknown")
        item.runtime_truth_label = _ui_text(raw.get("runtime_truth_label") or item.runtime_truth)
        item.runtime_reachable = bool(raw.get("runtime_reachable"))
        item.runtime_modes = ", ".join(str(value) for value in raw.get("runtime_modes") or [])
        item.runtime_driver = str(raw.get("runtime_driver") or "none")
        item.provenance = str(raw.get("provenance") or "unknown")
        item.provenance_label = _ui_text(raw.get("provenance_label") or item.provenance)
        item.provenance_color = _hex_color(str(raw.get("provenance_color") or "#EC4899"))
        item.preview_fidelity = str(raw.get("preview_fidelity") or "unknown")
        item.full_body = bool(raw.get("full_body", True))
        item.hips_weight = float(raw.get("hips_weight", 1.0))
        item.start_fraction = float(raw.get("start_fraction", 0.0))
        item.runtime_reason = _ui_text(raw.get("runtime_reason") or "")
        profile = next((profile for profile in _archetypes() if profile.get("archetype_id") == item.archetype_id), None)
        override = _binding_for(profile, item.action_id) if profile else None
        if override:
            item.pending_override = True
            item.pending_source_path = str(override.get("source_path") or "")
            item.pending_source_clip = str(override.get("source_clip") or "")
    scene.hoplite_monitor_index = min(scene.hoplite_monitor_index, max(0, len(scene.hoplite_monitor_rows) - 1))


def _populate_clips(scene) -> None:
    scene.hoplite_clips.clear()
    for source in _sources():
        clips = source.get("clips") or []
        for raw_clip in clips:
            item = scene.hoplite_clips.add()
            item.source_id = str(source.get("id") or "")
            item.source_path = str(source.get("path") or "")
            item.file_label = _ui_text(source.get("display_name") or Path(item.source_path).stem)
            item.clip_name = str(raw_clip.get("name") or "")
            item.pack_id = _ui_text(source.get("pack_id") or "")
            item.compatibility = _ui_text(source.get("compatibility") or "mixamo")
            item.length = float(raw_clip.get("length") or 0.0)
            item.tracks = int(raw_clip.get("tracks") or 0)
            item.display_name = f"{item.pack_id}  |  {item.file_label}  |  {_ui_text(item.clip_name)}"
    scene.hoplite_clip_index = min(scene.hoplite_clip_index, max(0, len(scene.hoplite_clips) - 1))


def _on_archetype_changed(_self, context) -> None:
    if context and context.scene:
        _populate_actions(context.scene)
        _sync_selected_action(context.scene, load_character=True)


def _on_action_changed(_self, context) -> None:
    if UI_SYNC_GUARD or not context or not context.scene:
        return
    _sync_selected_action(context.scene, load_character=False)


def _find_clip_index(scene, source_path: str, clip_name: str) -> int:
    exact_file = -1
    for index, clip in enumerate(scene.hoplite_clips):
        if clip.source_path != source_path:
            continue
        if exact_file < 0:
            exact_file = index
        if not clip_name or clip.clip_name == clip_name:
            return index
    return exact_file


def _sync_selected_action(scene, load_character: bool) -> None:
    global UI_SYNC_GUARD
    action = _selected_action(scene)
    profile = _selected_archetype(scene)
    if action is None or profile is None:
        return
    if not action.source_path:
        scene.hoplite_status = f"{action.label} n'a encore aucune animation — choisir un clip dans l'étape 3"
        return
    clip_index = _find_clip_index(scene, action.source_path, action.source_clip)
    if clip_index < 0:
        scene.hoplite_status = f"Source actuelle introuvable dans le manifeste : {action.source_path}"
        return
    UI_SYNC_GUARD = True
    scene.hoplite_clip_filter = ""
    scene.hoplite_clip_index = clip_index
    UI_SYNC_GUARD = False
    faithful_preview = action.preview_fidelity in {"exact_source", "baked_equivalent"}
    if not action.runtime_reachable:
        scene.hoplite_status = f"{action.label} n'est pas atteignable dans le runtime actuel : {action.runtime_reason}"
    elif not faithful_preview:
        scene.hoplite_status = f"Runtime reel selectionne; preview brute non lancee ({action.preview_fidelity})."
    elif scene.hoplite_auto_preview:
        _schedule_auto_preview(load_character or scene.hoplite_loaded_profile != str(profile.get("archetype_id") or ""))


def _schedule_auto_preview(load_character: bool) -> None:
    global AUTO_PREVIEW_REQUEST
    AUTO_PREVIEW_REQUEST += 1
    request_id = AUTO_PREVIEW_REQUEST

    def execute_preview():
        if request_id != AUTO_PREVIEW_REQUEST or bpy.app.background:
            return None
        scene = bpy.context.scene
        profile = _selected_archetype(scene)
        if profile is None:
            return None
        if _active_editable_action(scene) is not None and bpy.data.is_dirty:
            _save_workbench_project(scene, update_status=False)
        if load_character or scene.hoplite_loaded_profile != str(profile.get("archetype_id") or ""):
            if "CANCELLED" in bpy.ops.hoplite_anim.load_character():
                return None
        bpy.ops.hoplite_anim.preview_clip()
        return None

    bpy.app.timers.register(execute_preview, first_interval=0.15)


def _playback_override() -> tuple[object, object, object] | None:
    """Find a valid UI context for screen.animation_play, including from timers."""
    if bpy.app.background:
        return None
    preferred_areas = ("VIEW_3D", "DOPESHEET_EDITOR", "TIMELINE")
    for window in bpy.context.window_manager.windows:
        screen = window.screen
        for area_type in preferred_areas:
            area = next((candidate for candidate in screen.areas if candidate.type == area_type), None)
            if area is None:
                continue
            region = next((candidate for candidate in area.regions if candidate.type == "WINDOW"), None)
            if region is not None:
                return window, area, region
    return None


def _set_timeline_playing(should_play: bool) -> bool:
    override = _playback_override()
    if override is None:
        return False
    window, area, region = override
    screen = window.screen
    if bool(screen.is_animation_playing) == should_play:
        return True
    with bpy.context.temp_override(window=window, screen=screen, area=area, region=region):
        return "FINISHED" in bpy.ops.screen.animation_play()


def _toggle_timeline_playback() -> bool:
    override = _playback_override()
    if override is None:
        return False
    window, _area, _region = override
    return _set_timeline_playing(not bool(window.screen.is_animation_playing))


def _clear_owned_objects(source_only: bool = False) -> None:
    for obj in list(bpy.data.objects):
        if not obj.get(OWNED_TAG):
            continue
        if source_only and not obj.get(SOURCE_TAG):
            continue
        bpy.data.objects.remove(obj, do_unlink=True)


def _clear_preview_actions() -> None:
    for action in list(bpy.data.actions):
        if action.get(PREVIEW_ACTION_TAG):
            bpy.data.actions.remove(action)


def _import_asset(path: Path, source: bool) -> tuple[list, list]:
    if not path.is_file():
        raise RuntimeError(f"Fichier introuvable : {path}")
    before_objects = set(bpy.data.objects)
    before_actions = set(bpy.data.actions)
    extension = path.suffix.lower()
    if extension in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif extension == ".fbx":
        if hasattr(bpy.ops.wm, "fbx_import"):
            bpy.ops.wm.fbx_import(filepath=str(path))
        elif hasattr(bpy.ops.import_scene, "fbx"):
            bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=False)
        else:
            raise RuntimeError("Import FBX indisponible dans cette installation Blender")
    elif extension == ".blend":
        with bpy.data.libraries.load(str(path), link=False) as (available, requested):
            requested.objects = list(available.objects)
            requested.actions = list(available.actions)
        for obj in requested.objects:
            if obj is not None and not obj.users_collection:
                bpy.context.scene.collection.objects.link(obj)
    else:
        raise RuntimeError(f"Format non supporté : {extension}")
    new_objects = [obj for obj in bpy.data.objects if obj not in before_objects]
    new_actions = [action for action in bpy.data.actions if action not in before_actions]
    for obj in new_objects:
        obj[OWNED_TAG] = True
        obj[SOURCE_TAG] = bool(source)
        if source:
            obj.hide_set(True)
            obj.hide_render = True
    return new_objects, new_actions


def _find_armature(objects: list, preferred_name: str = ""):
    armatures = [obj for obj in objects if obj.type == "ARMATURE"]
    if preferred_name:
        exact = next((obj for obj in armatures if obj.name == preferred_name), None)
        if exact:
            return exact
    return max(armatures, key=lambda obj: len(obj.data.bones), default=None)


def _target_armature(scene):
    return bpy.data.objects.get(scene.hoplite_target_armature)


def _semantic_bone(name: str) -> str:
    raw = name.split(":")[-1].lower().replace("mixamorig", "")
    side = ""
    if "left" in raw or re.search(r"(?:^|[._-])l(?:$|[._-])", raw):
        side = "l"
    elif "right" in raw or re.search(r"(?:^|[._-])r(?:$|[._-])", raw):
        side = "r"
    token = raw.replace("left", "").replace("right", "")
    token = re.sub(r"^def[-_]", "", token)
    token = re.sub(r"[._\-\s]", "", token)
    if any(part in token for part in ("thumb", "index", "middle", "ring", "pinky", "little")):
        return ""
    ordered = (
        ("upperchest", ("spine003", "upperchest", "spine2")),
        ("chest", ("spine002", "chest", "spine1")),
        ("spine", ("spine001", "spine")),
        ("shoulder", ("shoulder", "clavicle")),
        ("upper_arm", ("upperarm", "arm")),
        ("forearm", ("forearm", "lowerarm")),
        ("hand", ("hand",)),
        ("thigh", ("thigh", "upleg", "upperleg")),
        ("shin", ("shin", "calf", "lowerleg", "leg")),
        ("foot", ("foot", "ankle")),
        ("toe", ("toe", "ball")),
        ("hips", ("hips", "pelvis")),
        ("neck", ("neck",)),
        ("head", ("head",)),
        ("root", ("root",)),
    )
    for role, patterns in ordered:
        if any(pattern in token for pattern in patterns):
            return f"{role}:{side}" if side and role not in {"root", "hips", "spine", "chest", "upperchest", "neck", "head"} else role
    return ""


def _bone_mapping(source_armature, target_armature) -> dict:
    source_pose = source_armature.pose.bones
    semantic_sources: dict[str, object] = {}
    for bone in source_pose:
        key = _semantic_bone(bone.name)
        if key and key not in semantic_sources:
            semantic_sources[key] = bone
    mapping = {}
    for target in target_armature.pose.bones:
        source = source_pose.get(target.name)
        if source is None:
            source = semantic_sources.get(_semantic_bone(target.name))
        if source is not None:
            mapping[target.name] = source.name
    return mapping


def _rest_fingerprint(armature) -> tuple:
    rows = []
    for bone in armature.data.bones:
        parent = bone.parent.name if bone.parent else ""
        values = tuple(round(value, 6) for row in bone.matrix_local for value in row)
        rows.append((bone.name, parent, values))
    return tuple(rows)


def _choose_imported_action(actions: list, requested_name: str):
    if not actions:
        return None
    exact = next((action for action in actions if action.name == requested_name), None)
    if exact:
        return exact
    lowered = requested_name.lower()
    partial = next((action for action in actions if lowered and lowered in action.name.lower()), None)
    return partial or max(actions, key=lambda action: action.frame_range[1] - action.frame_range[0])


def _retarget_action(source_armature, target_armature, source_action, output_name: str):
    mapping = _bone_mapping(source_armature, target_armature)
    if len(mapping) < 12:
        raise RuntimeError(f"Mapping humanoïde insuffisant : {len(mapping)} os reconnus")
    source_armature.animation_data_create().action = source_action
    target_armature.animation_data_create()
    _clear_preview_actions()
    target_action = bpy.data.actions.new(output_name)
    target_action[PREVIEW_ACTION_TAG] = True
    target_action["hoplite_mapping_count"] = len(mapping)
    target_action["hoplite_source_action"] = source_action.name
    target_armature.animation_data.action = target_action

    scene = bpy.context.scene
    start = int(math.floor(source_action.frame_range[0]))
    end = int(math.ceil(source_action.frame_range[1]))
    scene.frame_start = start
    scene.frame_end = max(start + 1, end)
    target_world_inverse = target_armature.matrix_world.inverted_safe()
    target_bones = list(target_armature.pose.bones)
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for pose_bone in target_bones:
            source_name = mapping.get(pose_bone.name)
            if not source_name:
                continue
            source_pose_bone = source_armature.pose.bones.get(source_name)
            if source_pose_bone is None:
                continue
            source_pose_world = source_armature.matrix_world @ source_pose_bone.matrix
            source_rest_world = source_armature.matrix_world @ source_pose_bone.bone.matrix_local
            source_delta = source_pose_world @ source_rest_world.inverted_safe()
            target_rest_world = target_armature.matrix_world @ pose_bone.bone.matrix_local
            current_world = target_armature.matrix_world @ pose_bone.matrix
            desired_rotation = source_delta.to_quaternion() @ target_rest_world.to_quaternion()
            desired_world = Matrix.LocRotScale(current_world.translation, desired_rotation, (1.0, 1.0, 1.0))
            pose_bone.matrix = target_world_inverse @ desired_world
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=pose_bone.name)
        bpy.context.view_layer.update()
    scene.frame_set(start)
    return target_action, len(mapping)


def _initial_hold_frames(action, threshold: float = 0.0002) -> int:
    if action is None or not hasattr(action, "fcurves"):
        return 0
    start = int(math.floor(action.frame_range[0]))
    end = int(math.ceil(action.frame_range[1]))
    if end <= start:
        return 0
    curves = [curve for curve in action.fcurves if curve.keyframe_points]
    if not curves:
        return 0
    initial_values = [curve.evaluate(start) for curve in curves]
    for frame in range(start + 1, end + 1):
        if any(abs(curve.evaluate(frame) - initial_values[index]) > threshold for index, curve in enumerate(curves)):
            return max(0, frame - start - 1)
    return max(0, end - start)


def _is_finger_curve(data_path: str) -> bool:
    lowered = data_path.lower()
    return any(token in lowered for token in ("def-f_", "def-thumb", "thumb", "index", "middle", "ring", "pinky", "little"))


def _strip_finger_curves(action) -> int:
    if action is None or not hasattr(action, "fcurves"):
        return 0
    removed = 0
    for curve in list(action.fcurves):
        if _is_finger_curve(curve.data_path):
            action.fcurves.remove(curve)
            removed += 1
    return removed


def _safe_slug(value: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9_-]+", "_", value.strip()).strip("_").lower()
    return slug or "unnamed"


def _editable_action_name(profile: dict, action_item) -> str:
    scope, scope_id = _profile_scope(profile)
    return "HOPLITE_EDIT__{}__{}__{}".format(_safe_slug(scope), _safe_slug(scope_id), _safe_slug(action_item.action_id))


def _project_path(profile: dict, action_item) -> Path:
    scope, scope_id = _profile_scope(profile)
    return _project_path_from_values(scope, scope_id, action_item.action_id)


def _project_path_from_values(scope: str, scope_id: str, action_id: str) -> Path:
    return PROJECT_ROOT / PROJECTS_ROOT_RELATIVE / _safe_slug(scope) / _safe_slug(scope_id) / f"{_safe_slug(action_id)}.blend"


def _active_editable_action(scene):
    target = _target_armature(scene)
    action = target.animation_data.action if target and target.animation_data else None
    return action if action is not None and action.get(EDITABLE_ACTION_TAG) else None


def _save_workbench_project(scene, update_status: bool = True, save_copy: bool = False) -> Path:
    profile = _selected_archetype(scene)
    action_item = _selected_action(scene)
    action = _active_editable_action(scene)
    if profile is None or action_item is None or action is None:
        raise RuntimeError("Créer ou reprendre une animation éditable avant de sauvegarder")
    scope = str(action.get("hoplite_scope") or _profile_scope(profile)[0])
    scope_id = str(action.get("hoplite_scope_id") or _profile_scope(profile)[1])
    action_id = str(action.get("hoplite_action_id") or action_item.action_id)
    destination = _project_path_from_values(scope, scope_id, action_id)
    destination.parent.mkdir(parents=True, exist_ok=True)
    _clear_owned_objects(source_only=True)
    _clear_preview_actions()
    scene.hoplite_project_path = str(destination)
    bpy.ops.wm.save_as_mainfile(filepath=str(destination), check_existing=False, copy=save_copy)
    if update_status:
        scene.hoplite_status = f"Projet sauvegardé : {destination.relative_to(PROJECT_ROOT)}"
    return destination


def _autosave_tick():
    if bpy.app.background:
        return None
    try:
        scene = bpy.context.scene
        if scene and scene.hoplite_autosave and bpy.data.is_dirty and _active_editable_action(scene) is not None:
            _save_workbench_project(scene, update_status=False)
    except Exception as error:  # noqa: BLE001
        print(f"[SPARTAN ANIMATION WORKBENCH] autosave skipped: {error}")
    return 60.0


class HOPLITE_ActionItem(PropertyGroup):
    action_id: StringProperty()
    label: StringProperty()
    status: StringProperty()
    category: StringProperty()
    phase: StringProperty()
    layer: StringProperty()
    runtime_key: StringProperty()
    source_path: StringProperty()
    source_clip: StringProperty()
    default_scope: StringProperty()
    binding_scope: StringProperty()
    runtime_supported: BoolProperty(default=False)
    runtime_reachable: BoolProperty(default=False)
    runtime_truth: StringProperty()
    runtime_truth_label: StringProperty()
    runtime_modes: StringProperty()
    runtime_driver: StringProperty()
    runtime_source_path: StringProperty()
    runtime_source_clip: StringProperty()
    preview_source_path: StringProperty()
    preview_source_clip: StringProperty()
    preview_fidelity: StringProperty()
    provenance: StringProperty()
    provenance_label: StringProperty()
    provenance_color: FloatVectorProperty(size=4, subtype="COLOR_GAMMA", min=0.0, max=1.0, default=(0.925, 0.282, 0.600, 1.0))
    weapon_family: StringProperty()
    full_body: BoolProperty(default=True)
    hips_weight: FloatProperty(default=1.0)
    start_fraction: FloatProperty(default=0.0)
    runtime_reason: StringProperty()
    override_active: BoolProperty(default=False)


class HOPLITE_MonitorRow(PropertyGroup):
    archetype_id: StringProperty()
    character_name: StringProperty()
    weapon_family: StringProperty()
    action_id: StringProperty()
    action_label: StringProperty()
    runtime_key: StringProperty()
    runtime_source_path: StringProperty()
    runtime_source_clip: StringProperty()
    preview_source_path: StringProperty()
    preview_source_clip: StringProperty()
    runtime_truth: StringProperty()
    runtime_truth_label: StringProperty()
    runtime_reachable: BoolProperty(default=False)
    runtime_modes: StringProperty()
    runtime_driver: StringProperty()
    provenance: StringProperty()
    provenance_label: StringProperty()
    provenance_color: FloatVectorProperty(size=4, subtype="COLOR_GAMMA", min=0.0, max=1.0, default=(0.925, 0.282, 0.600, 1.0))
    preview_fidelity: StringProperty()
    full_body: BoolProperty(default=True)
    hips_weight: FloatProperty(default=1.0)
    start_fraction: FloatProperty(default=0.0)
    runtime_reason: StringProperty()
    pending_override: BoolProperty(default=False)
    pending_source_path: StringProperty()
    pending_source_clip: StringProperty()


class HOPLITE_ProvenanceLegendItem(PropertyGroup):
    provenance: StringProperty()
    label: StringProperty()
    color: FloatVectorProperty(size=4, subtype="COLOR_GAMMA", min=0.0, max=1.0, default=(0.925, 0.282, 0.600, 1.0))


class HOPLITE_ClipItem(PropertyGroup):
    source_id: StringProperty()
    source_path: StringProperty()
    file_label: StringProperty()
    clip_name: StringProperty()
    pack_id: StringProperty()
    compatibility: StringProperty()
    display_name: StringProperty()
    length: FloatProperty()
    tracks: IntProperty()


class HOPLITE_UL_actions(UIList):
    def filter_items(self, context, data, propname):
        if context.scene.hoplite_show_non_runtime:
            return [], []
        items = getattr(data, propname)
        return [self.bitflag_filter_item if item.runtime_reachable else 0 for item in items], []

    def draw_item(self, _context, layout, _data, item, _icon, _active_data, _active_propname, _index):
        icons = {"runtime_exact": "CHECKMARK", "runtime_layered": "MODIFIER", "runtime_fallback": "QUESTION", "runtime_unreachable": "CANCEL", "future_missing": "ERROR"}
        row = layout.row(align=True)
        swatch = row.row(align=True)
        swatch.enabled = False
        swatch.prop(item, "provenance_color", text="")
        row.label(text=item.label, icon=icons.get(item.runtime_truth, "DOT"))
        row.label(text=item.runtime_source_clip or "-")
        if item.override_active:
            row.label(text="non publie", icon="GREASEPENCIL")


class HOPLITE_UL_monitor(UIList):
    def filter_items(self, context, data, propname):
        items = getattr(data, propname)
        return [self.bitflag_filter_item if _monitor_row_matches(context.scene, item) else 0 for item in items], []

    def draw_item(self, _context, layout, _data, item, _icon, _active_data, _active_propname, _index):
        icons = {"runtime_exact": "CHECKMARK", "runtime_layered": "MODIFIER", "runtime_fallback": "QUESTION", "runtime_unreachable": "CANCEL", "future_missing": "ERROR"}
        row = layout.row(align=True)
        swatch = row.row(align=True)
        swatch.enabled = False
        swatch.prop(item, "provenance_color", text="")
        row.label(text=f"{item.character_name} | {item.weapon_family}")
        row.label(text=f"{item.action_label} -> {item.runtime_source_clip or '-'}", icon=icons.get(item.runtime_truth, "DOT"))


class HOPLITE_UL_provenance_legend(UIList):
    def draw_item(self, _context, layout, _data, item, _icon, _active_data, _active_propname, _index):
        row = layout.row(align=True)
        swatch = row.row(align=True)
        swatch.enabled = False
        swatch.prop(item, "color", text="")
        row.label(text=item.label)


class HOPLITE_UL_clips(UIList):
    def filter_items(self, context, data, propname):
        items = getattr(data, propname)
        query = context.scene.hoplite_clip_filter.strip().lower()
        if not query:
            return [], []
        flags = []
        for item in items:
            haystack = f"{item.display_name} {item.compatibility}".lower()
            flags.append(self.bitflag_filter_item if all(term in haystack for term in query.split()) else 0)
        return flags, []

    def draw_item(self, _context, layout, _data, item, _icon, _active_data, _active_propname, _index):
        row = layout.row(align=True)
        row.label(text=item.display_name, icon="ACTION")
        row.label(text=f"{item.length:.2f}s")
        row.label(text=item.compatibility)


class HOPLITE_OT_refresh(Operator):
    bl_idname = "hoplite_anim.refresh"
    bl_label = "Recharger le manifeste"

    def execute(self, context):
        global MANIFEST, OVERRIDES
        try:
            MANIFEST = _load_json(MANIFEST_PATH)
            OVERRIDES = _load_json(OVERRIDES_PATH, {"schema_version": 1, "bindings": []})
            _populate_actions(context.scene)
            _populate_clips(context.scene)
            _populate_monitor(context.scene)
            _sync_selected_action(context.scene, load_character=False)
            context.scene.hoplite_status = "Manifeste rechargé"
            return {"FINISHED"}
        except Exception as error:  # noqa: BLE001
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}


class HOPLITE_OT_load_character(Operator):
    bl_idname = "hoplite_anim.load_character"
    bl_label = "Charger ce personnage"

    def execute(self, context):
        scene = context.scene
        archetype = _selected_archetype(scene)
        if not archetype:
            return {"CANCELLED"}
        try:
            if _active_editable_action(scene) is not None and bpy.data.is_dirty:
                _save_workbench_project(scene, update_status=False)
            _clear_owned_objects(source_only=False)
            _clear_preview_actions()
            objects, _actions = _import_asset(_resolve_project_path(archetype["model_path"]), source=False)
            armature = _find_armature(objects)
            if armature is None:
                raise RuntimeError("Aucune armature trouvée dans le modèle")
            scene.hoplite_target_armature = armature.name
            scene.hoplite_loaded_profile = str(archetype.get("archetype_id") or "")
            scene.hoplite_status = f"{archetype['display_name']} chargé — {len(armature.data.bones)} os"
            for obj in objects:
                obj.select_set(obj == armature)
            context.view_layer.objects.active = armature
            return {"FINISHED"}
        except Exception as error:  # noqa: BLE001
            scene.hoplite_status = f"ERREUR : {error}"
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}


class HOPLITE_OT_preview_clip(Operator):
    bl_idname = "hoplite_anim.preview_clip"
    bl_label = "Prévisualiser le clip sélectionné"

    def execute(self, context):
        scene = context.scene
        target = _target_armature(scene)
        clip = _selected_clip(scene)
        action_item = _selected_action(scene)
        if target is None or clip is None or action_item is None:
            self.report({"ERROR"}, "Charger un personnage puis sélectionner une action et un clip")
            return {"CANCELLED"}
        try:
            _set_timeline_playing(False)
            _clear_owned_objects(source_only=True)
            before_actions = set(bpy.data.actions)
            objects, imported_actions = _import_asset(_resolve_project_path(clip.source_path), source=True)
            source_armature = _find_armature(objects)
            imported_actions = [action for action in bpy.data.actions if action not in before_actions] or imported_actions
            source_action = _choose_imported_action(imported_actions, clip.clip_name)
            if source_armature is None or source_action is None:
                raise RuntimeError("La source ne contient pas d'armature/action exploitable dans Blender")
            if _rest_fingerprint(source_armature) == _rest_fingerprint(target):
                _clear_preview_actions()
                preview = source_action.copy()
                preview.name = f"WB_PREVIEW__{action_item.action_id}"
                preview[PREVIEW_ACTION_TAG] = True
                target.animation_data_create().action = preview
                mapping_count = len(target.data.bones)
            else:
                preview, mapping_count = _retarget_action(
                    source_armature,
                    target,
                    source_action,
                    f"WB_PREVIEW__{action_item.action_id}",
                )
            scene.frame_start = int(preview.frame_range[0])
            scene.frame_end = max(scene.frame_start + 1, int(math.ceil(preview.frame_range[1])))
            scene.frame_set(scene.frame_start)
            hold_frames = _initial_hold_frames(preview)
            scene.hoplite_detected_hold_frames = hold_frames
            hold_note = f" | pause initiale detectee : {hold_frames} frame(s)" if hold_frames else " | aucun gel initial detecte dans la source"
            playback_started = _set_timeline_playing(True)
            playback_note = " | lecture lancee" if playback_started else " | preview chargee (lecture manuelle requise)"
            fidelity_note = ""
            if action_item.preview_fidelity not in {"exact_source", "baked_equivalent"}:
                fidelity_note = f" | ATTENTION : approximation ({action_item.preview_fidelity}), pas le rendu runtime compose"
            scene.hoplite_status = f"Preview prete : {clip.file_label} / {clip.clip_name} - {mapping_count} os{hold_note}{playback_note}{fidelity_note}"
            return {"FINISHED"}
        except Exception as error:  # noqa: BLE001
            scene.hoplite_status = f"PREVIEW BLOQUÉE : {error}"
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}


class HOPLITE_OT_toggle_playback(Operator):
    bl_idname = "hoplite_anim.toggle_playback"
    bl_label = "Lecture / pause"

    def execute(self, context):
        if not _toggle_timeline_playback():
            context.scene.hoplite_status = "Lecture impossible : aucun editeur Blender compatible n'est ouvert"
            self.report({"ERROR"}, context.scene.hoplite_status)
            return {"CANCELLED"}
        return {"FINISHED"}


class HOPLITE_OT_assign_clip(Operator):
    bl_idname = "hoplite_anim.assign_clip"
    bl_label = "Assigner ce clip"

    def execute(self, context):
        scene = context.scene
        archetype = _selected_archetype(scene)
        action = _selected_action(scene)
        clip = _selected_clip(scene)
        if not archetype or action is None or clip is None:
            return {"CANCELLED"}
        scope, scope_id = _upsert_binding(archetype, action, clip.source_path, clip.clip_name)
        channel = "runtime actuel" if action.runtime_supported else "file de bake EnemyV2"
        scene.hoplite_status = f"Affectation sauvegardée automatiquement — {_scope_label(scope, scope_id)} • {channel}"
        return {"FINISHED"}


class HOPLITE_OT_edit_preview(Operator):
    bl_idname = "hoplite_anim.edit_preview"
    bl_label = "Éditer la preview actuelle"

    def execute(self, context):
        scene = context.scene
        target = _target_armature(scene)
        profile = _selected_archetype(scene)
        action_item = _selected_action(scene)
        current = target.animation_data.action if target and target.animation_data else None
        if target is None or profile is None or action_item is None or current is None:
            self.report({"ERROR"}, "Prévisualiser une animation avant de l'éditer")
            return {"CANCELLED"}
        action_name = _editable_action_name(profile, action_item)
        editable = bpy.data.actions.get(action_name)
        if editable is None:
            editable = current.copy()
            editable.name = action_name
        editable.use_fake_user = True
        editable[EDITABLE_ACTION_TAG] = True
        editable["hoplite_scope"], editable["hoplite_scope_id"] = _profile_scope(profile)
        editable["hoplite_archetype_id"] = profile["archetype_id"]
        editable["hoplite_action_id"] = action_item.action_id
        if PREVIEW_ACTION_TAG in editable:
            del editable[PREVIEW_ACTION_TAG]
        removed_finger_curves = _strip_finger_curves(editable)
        target.animation_data_create().action = editable
        _clear_owned_objects(source_only=True)
        _clear_preview_actions()
        scene.frame_start = int(math.floor(editable.frame_range[0]))
        scene.frame_end = max(scene.frame_start + 1, int(math.ceil(editable.frame_range[1])))
        scene.frame_set(scene.frame_start)
        target.hide_set(False)
        target.select_set(True)
        context.view_layer.objects.active = target
        if bpy.data.workspaces.get("Animation") and context.window:
            context.window.workspace = bpy.data.workspaces["Animation"]
        if target.mode != "POSE":
            bpy.ops.object.mode_set(mode="POSE")
        destination = _save_workbench_project(scene, update_status=False)
        scene.hoplite_status = f"Copie éditable sauvegardée : {destination.relative_to(PROJECT_ROOT)} • {removed_finger_curves} piste(s) de doigts retirée(s)"
        return {"FINISHED"}


class HOPLITE_OT_create_action(Operator):
    bl_idname = "hoplite_anim.create_action"
    bl_label = "Créer une animation vide"

    def execute(self, context):
        scene = context.scene
        target = _target_armature(scene)
        archetype = _selected_archetype(scene)
        action_item = _selected_action(scene)
        if target is None or not archetype or action_item is None:
            self.report({"ERROR"}, "Charger un personnage et sélectionner une action")
            return {"CANCELLED"}
        action_name = _editable_action_name(archetype, action_item)
        if bpy.data.actions.get(action_name) is not None:
            self.report({"ERROR"}, "Une version éditable existe déjà : utiliser Reprendre le travail sauvegardé")
            return {"CANCELLED"}
        action = bpy.data.actions.new(action_name)
        action.use_fake_user = True
        action[EDITABLE_ACTION_TAG] = True
        action["hoplite_scope"], action["hoplite_scope_id"] = _profile_scope(archetype)
        action["hoplite_archetype_id"] = archetype["archetype_id"]
        action["hoplite_action_id"] = action_item.action_id
        target.animation_data_create().action = action
        for pose_bone in target.pose.bones:
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.location = (0.0, 0.0, 0.0)
            pose_bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
            pose_bone.scale = (1.0, 1.0, 1.0)
        scene.frame_start = 1
        scene.frame_end = 30
        scene.frame_set(1)
        target.hide_set(False)
        target.select_set(True)
        context.view_layer.objects.active = target
        if bpy.data.workspaces.get("Animation"):
            context.window.workspace = bpy.data.workspaces["Animation"]
        bpy.ops.object.mode_set(mode="POSE")
        destination = _save_workbench_project(scene, update_status=False)
        scene.hoplite_status = f"Action vide créée et sauvegardée : {destination.relative_to(PROJECT_ROOT)}"
        return {"FINISHED"}


class HOPLITE_OT_trim_initial_hold(Operator):
    bl_idname = "hoplite_anim.trim_initial_hold"
    bl_label = "Retirer la pause initiale"

    def execute(self, context):
        scene = context.scene
        action = _active_editable_action(scene)
        if action is None:
            self.report({"ERROR"}, "Passer d'abord par Éditer la preview actuelle")
            return {"CANCELLED"}
        frames = scene.hoplite_trim_frames or _initial_hold_frames(action)
        if frames <= 0:
            scene.hoplite_status = "Aucune pause initiale mesurable dans l'Action — le freeze vient probablement du blend/runtime"
            return {"CANCELLED"}
        for curve in action.fcurves:
            for key in curve.keyframe_points:
                key.co.x -= frames
                key.handle_left.x -= frames
                key.handle_right.x -= frames
            curve.update()
        action["hoplite_trimmed_start_frames"] = int(action.get("hoplite_trimmed_start_frames", 0)) + frames
        scene.frame_start = int(math.floor(action.frame_range[0]))
        scene.frame_end = max(scene.frame_start + 1, int(math.ceil(action.frame_range[1])))
        scene.frame_set(scene.frame_start)
        _save_workbench_project(scene, update_status=False)
        scene.hoplite_status = f"{frames} frame(s) retirée(s) au début — projet sauvegardé (Ctrl+Z reste disponible)"
        return {"FINISHED"}


class HOPLITE_OT_save_project(Operator):
    bl_idname = "hoplite_anim.save_project"
    bl_label = "Sauvegarder le travail (.blend)"

    def execute(self, context):
        try:
            _save_workbench_project(context.scene)
            return {"FINISHED"}
        except Exception as error:  # noqa: BLE001
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}


class HOPLITE_OT_open_project(Operator):
    bl_idname = "hoplite_anim.open_project"
    bl_label = "Reprendre le travail sauvegardé"

    def execute(self, context):
        scene = context.scene
        profile = _selected_archetype(scene)
        action_item = _selected_action(scene)
        if profile is None or action_item is None:
            return {"CANCELLED"}
        path = _project_path(profile, action_item)
        if not path.is_file():
            self.report({"ERROR"}, f"Aucun projet sauvegardé pour cette action : {path}")
            return {"CANCELLED"}
        try:
            if _active_editable_action(scene) is not None and bpy.data.is_dirty:
                _save_workbench_project(scene, update_status=False)
            _clear_owned_objects(source_only=False)
            _clear_preview_actions()
            objects, actions = _import_asset(path, source=False)
            target = _find_armature([obj for obj in objects if not obj.get(SOURCE_TAG)])
            editable = next((action for action in actions if action.get(EDITABLE_ACTION_TAG) and action.get("hoplite_action_id") == action_item.action_id), None)
            if target is None or editable is None:
                raise RuntimeError("Le projet ne contient plus son armature ou son Action éditable")
            target.animation_data_create().action = editable
            scene.hoplite_target_armature = target.name
            scene.hoplite_loaded_profile = str(profile.get("archetype_id") or "")
            scene.hoplite_project_path = str(path)
            scene.frame_start = int(math.floor(editable.frame_range[0]))
            scene.frame_end = max(scene.frame_start + 1, int(math.ceil(editable.frame_range[1])))
            scene.frame_set(scene.frame_start)
            target.hide_set(False)
            target.select_set(True)
            context.view_layer.objects.active = target
            if bpy.data.workspaces.get("Animation") and context.window:
                context.window.workspace = bpy.data.workspaces["Animation"]
            scene.hoplite_status = f"Projet repris : {path.relative_to(PROJECT_ROOT)}"
            return {"FINISHED"}
        except Exception as error:  # noqa: BLE001
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}


class HOPLITE_OT_save_json(Operator):
    bl_idname = "hoplite_anim.save_json"
    bl_label = "Sauvegarder les affectations JSON"

    def execute(self, context):
        _save_overrides(create_backup=True)
        context.scene.hoplite_status = f"JSON sauvegardé : {OVERRIDES_PATH.relative_to(PROJECT_ROOT)}"
        return {"FINISHED"}


class HOPLITE_OT_export_action(Operator):
    bl_idname = "hoplite_anim.export_action"
    bl_label = "Exporter l'action créée en GLB"

    def execute(self, context):
        scene = context.scene
        target = _target_armature(scene)
        archetype = _selected_archetype(scene)
        action_item = _selected_action(scene)
        action = _active_editable_action(scene)
        if target is None or action is None or not archetype or action_item is None:
            self.report({"ERROR"}, "Créer ou reprendre une Action éditable avant l'export")
            return {"CANCELLED"}
        scope, scope_id = _profile_scope(archetype)
        destination_dir = PROJECT_ROOT / "assets" / "animations" / "source_packs" / "custom" / _safe_slug(scope) / _safe_slug(scope_id)
        destination_dir.mkdir(parents=True, exist_ok=True)
        destination = destination_dir / f"{_safe_slug(action_item.action_id)}.glb"
        _save_workbench_project(scene, update_status=False)
        previous_mode = target.mode
        if previous_mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.select_all(action="DESELECT")
        target.hide_set(False)
        target.select_set(True)
        context.view_layer.objects.active = target
        try:
            bpy.ops.export_scene.gltf(
                filepath=str(destination),
                export_format="GLB",
                use_selection=True,
                export_animations=True,
                export_skins=True,
                export_yup=True,
            )
        except TypeError:
            bpy.ops.export_scene.gltf(
                filepath=str(destination),
                export_format="GLB",
                use_selection=True,
                export_animations=True,
                export_yup=True,
            )
        metadata = {
            "schema_version": 1,
            "action_id": action_item.action_id,
            "archetype_id": archetype["archetype_id"],
            "scope": scope,
            "scope_id": scope_id,
            "source_action": action.name,
            "rig_bones": len(target.data.bones),
            "root_motion": "in_place",
            "finger_tracks": False,
        }
        _atomic_json(destination.with_suffix(".animation.json"), metadata)
        runtime_source = "res://" + destination.relative_to(PROJECT_ROOT).as_posix()
        _upsert_binding(archetype, action_item, runtime_source, action.name)
        scene.hoplite_status = f"GLB + JSON exportés et affectation sauvegardée : {destination.relative_to(PROJECT_ROOT)}"
        return {"FINISHED"}


class HOPLITE_OT_monitor_focus(Operator):
    bl_idname = "hoplite_anim.monitor_focus"
    bl_label = "Ouvrir dans l'editeur"

    def execute(self, context):
        scene = context.scene
        if not scene.hoplite_monitor_rows:
            return {"CANCELLED"}
        index = max(0, min(scene.hoplite_monitor_index, len(scene.hoplite_monitor_rows) - 1))
        monitor = scene.hoplite_monitor_rows[index]
        scene.hoplite_archetype = monitor.archetype_id
        action_index = next((i for i, action in enumerate(scene.hoplite_actions) if action.action_id == monitor.action_id), -1)
        if action_index < 0:
            self.report({"ERROR"}, "Action absente du profil editeur")
            return {"CANCELLED"}
        scene.hoplite_action_index = action_index
        scene.hoplite_status = f"Monitoring -> {monitor.character_name} / {monitor.action_label} ({monitor.runtime_truth_label})"
        return {"FINISHED"}


class HOPLITE_PT_monitoring(Panel):
    bl_label = "Runtime Monitoring"
    bl_idname = "HOPLITE_PT_animation_monitoring"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Spartan Anim"
    bl_order = 0

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        summary = _monitoring().get("summary") or {}
        counts = summary.get("runtime_truth_counts") or {}

        header = layout.box()
        header.label(text="Verite du runtime Godot", icon="VIEWZOOM")
        header.label(text=f"{summary.get('monitoring_row_count', 0)} usages | {summary.get('weapon_family_count', 0)} familles d'armes")
        header.label(text=f"Exact {counts.get('runtime_exact', 0)} | Compose {counts.get('runtime_layered', 0)} | Fallback {counts.get('runtime_fallback', 0)}")
        header.label(text=f"Inaccessibles {counts.get('runtime_unreachable', 0)} | A produire {counts.get('future_missing', 0)}")

        filters = layout.box()
        filters.label(text="Filtres", icon="FILTER")
        filters.prop(scene, "hoplite_monitor_scope", expand=True)
        if scene.hoplite_monitor_scope == "CHARACTER":
            filters.prop(scene, "hoplite_monitor_character", text="Personnage")
        elif scene.hoplite_monitor_scope == "WEAPON":
            filters.prop(scene, "hoplite_monitor_weapon", text="Arme")
        filters.prop(scene, "hoplite_monitor_truth", text="Etat")
        filters.prop(scene, "hoplite_monitor_provenance", text="Provenance")
        filters.prop(scene, "hoplite_monitor_search", text="Recherche")

        layout.template_list("HOPLITE_UL_monitor", "", scene, "hoplite_monitor_rows", scene, "hoplite_monitor_index", rows=14)
        if scene.hoplite_monitor_rows:
            index = max(0, min(scene.hoplite_monitor_index, len(scene.hoplite_monitor_rows) - 1))
            item = scene.hoplite_monitor_rows[index]
            details = layout.box()
            details.label(text=f"{item.character_name} | {item.weapon_family}", icon="OUTLINER_OB_ARMATURE")
            details.label(text=f"{item.action_label} : {item.runtime_truth_label}")
            color = details.row(align=True)
            swatch = color.row(align=True)
            swatch.enabled = False
            swatch.prop(item, "provenance_color", text="")
            color.label(text=f"Provenance : {item.provenance_label}")
            details.label(text=f"Runtime : {item.runtime_source_path or '-'}")
            details.label(text=f"Clip joue : {item.runtime_source_clip or '-'}")
            details.label(text=f"Pilote : {item.runtime_driver} | modes : {item.runtime_modes or '-'}")
            if not item.full_body:
                details.label(text=f"Composition : couche haute | hips {item.hips_weight:.2f} | depart {item.start_fraction:.2f}", icon="MODIFIER")
            details.label(text=f"Preview : {item.preview_fidelity}")
            if item.runtime_reason:
                details.label(text=item.runtime_reason, icon="INFO")
            if item.pending_override:
                details.label(text=f"Modification NON PUBLIEE : {item.pending_source_clip}", icon="GREASEPENCIL")
            details.operator("hoplite_anim.monitor_focus", icon="EDITMODE_HLT")

        legend = layout.box()
        legend.label(text="Code couleur des provenances", icon="COLOR")
        legend.template_list("HOPLITE_UL_provenance_legend", "", scene, "hoplite_provenance_legend", scene, "hoplite_provenance_legend_index", rows=4)


class HOPLITE_PT_workbench(Panel):
    bl_label = "Spartan Animation Workbench"
    bl_idname = "HOPLITE_PT_animation_workbench"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Spartan Anim"
    bl_order = 1

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        summary = MANIFEST.get("summary") or {}
        header = layout.box()
        header.label(text=f"Workbench {SCRIPT_VERSION}", icon="ARMATURE_DATA")
        header.label(text=f"{summary.get('archetype_count', 0)} ennemis • {summary.get('virtual_profile_count', 0)} profils communs")
        header.label(text=f"{summary.get('source_count', 0)} sources • {summary.get('clip_count', 0)} clips")
        header.operator("hoplite_anim.refresh", icon="FILE_REFRESH")

        box = layout.box()
        box.label(text="1 — Personnage", icon="OUTLINER_OB_ARMATURE")
        box.prop(scene, "hoplite_archetype", text="Type")
        archetype = _selected_archetype(scene)
        if archetype:
            box.label(text=f"Rig : {archetype.get('rig_family')} ({archetype.get('rig', {}).get('bone_count', 0)} os)")
            box.label(text=f"Arme : {archetype.get('weapon_family')} • rôle : {archetype.get('role')}")
            scope, scope_id = _profile_scope(archetype)
            box.label(text=f"Affectation : {_scope_label(scope, scope_id)}", icon="LINKED")
            if archetype.get("virtual"):
                box.label(text=f"Profil animation virtuel • {len(archetype.get('target_archetypes') or [])} cible(s)", icon="INFO")
            if archetype.get("origin_mismatch"):
                box.label(text="Origine déclarée incohérente avec le modèle résolu", icon="ERROR")
        box.operator("hoplite_anim.load_character", icon="IMPORT")

        box = layout.box()
        box.label(text="2 - Runtime reel du personnage", icon="ACTION")
        box.prop(scene, "hoplite_show_non_runtime", text="Afficher aussi les actions absentes/inaccessibles")
        box.template_list("HOPLITE_UL_actions", "", scene, "hoplite_actions", scene, "hoplite_action_index", rows=8)
        action = _selected_action(scene)
        if action:
            details = box.column(align=True)
            details.label(text=f"Etat runtime : {action.runtime_truth_label}")
            details.label(text=f"Modes : {action.runtime_modes or '-'} | pilote : {action.runtime_driver}")
            details.label(text=f"Cle runtime : {action.runtime_key or 'aucune'}")
            details.label(text=f"Source REELLE : {action.runtime_source_path or '-'}")
            details.label(text=f"Clip JOUE : {action.runtime_source_clip or '-'}")
            details.label(text=f"Provenance : {action.provenance_label}")
            if not action.full_body:
                details.label(text=f"Composition runtime : couche haute | hips {action.hips_weight:.2f} | depart {action.start_fraction:.2f}", icon="MODIFIER")
            if action.runtime_reason:
                details.label(text=action.runtime_reason, icon="INFO")
            details.label(text=f"Fidelite preview Blender : {action.preview_fidelity}")
            if action.override_active:
                details.label(text=f"Modification en attente, NON PUBLIEE : {action.binding_scope}", icon="DECORATE_KEYFRAME")

        box = layout.box()
        box.label(text="3 — Tous les packs installés", icon="ASSET_MANAGER")
        box.prop(scene, "hoplite_auto_preview", text="Preview auto seulement si fidele au runtime")
        box.prop(scene, "hoplite_clip_filter", text="Filtre")
        box.template_list("HOPLITE_UL_clips", "", scene, "hoplite_clips", scene, "hoplite_clip_index", rows=10)
        clip = _selected_clip(scene)
        if clip:
            box.label(text=f"{clip.pack_id} • {clip.compatibility} • {clip.tracks} pistes")
        row = box.row(align=True)
        row.operator("hoplite_anim.preview_clip", icon="PLAY")
        row.operator("hoplite_anim.toggle_playback", icon="PAUSE")

        box = layout.box()
        box.label(text="4 — Affectation", icon="LINKED")
        if archetype:
            scope, scope_id = _profile_scope(archetype)
            box.label(text=_scope_label(scope, scope_id), icon="LOCKED")
            box.label(text="Priorité : personnage > arme > rig commun")
        box.operator("hoplite_anim.assign_clip", icon="CHECKMARK")
        box.operator("hoplite_anim.save_json", icon="FILE_TICK")
        box.label(text="Le JSON est aussi sauvegardé automatiquement à chaque affectation")
        if action and not action.runtime_supported:
            box.label(text="Cette action sera mise en file pour le bake EnemyV2", icon="INFO")

        box = layout.box()
        box.label(text="5 — Édition et sauvegarde Blender", icon="GREASEPENCIL")
        box.operator("hoplite_anim.edit_preview", icon="DUPLICATE")
        box.operator("hoplite_anim.create_action", icon="ADD")
        row = box.row(align=True)
        row.prop(scene, "hoplite_trim_frames", text="Frames à retirer")
        row.operator("hoplite_anim.trim_initial_hold", text="Retirer pause", icon="X")
        if scene.hoplite_detected_hold_frames:
            box.label(text=f"Diagnostic preview : {scene.hoplite_detected_hold_frames} frame(s) immobile(s) au début", icon="TIME")
        row = box.row(align=True)
        row.operator("hoplite_anim.save_project", icon="FILE_BLEND")
        resume = row.row(align=True)
        project_exists = bool(archetype and action and _project_path(archetype, action).is_file())
        resume.enabled = project_exists
        resume.operator("hoplite_anim.open_project", icon="RECOVER_LAST")
        box.prop(scene, "hoplite_autosave", text="Autosauvegarde du .blend toutes les 60 secondes")
        box.operator("hoplite_anim.export_action", icon="EXPORT")
        box.label(text="Le .blend reste éditable; le GLB et le JSON servent au jeu", icon="FILE_FOLDER")

        if scene.hoplite_status:
            status = layout.box()
            status.label(text=scene.hoplite_status, icon="INFO")


CLASSES = (
    HOPLITE_ActionItem,
    HOPLITE_MonitorRow,
    HOPLITE_ProvenanceLegendItem,
    HOPLITE_ClipItem,
    HOPLITE_UL_actions,
    HOPLITE_UL_monitor,
    HOPLITE_UL_provenance_legend,
    HOPLITE_UL_clips,
    HOPLITE_OT_refresh,
    HOPLITE_OT_load_character,
    HOPLITE_OT_preview_clip,
    HOPLITE_OT_toggle_playback,
    HOPLITE_OT_assign_clip,
    HOPLITE_OT_edit_preview,
    HOPLITE_OT_create_action,
    HOPLITE_OT_trim_initial_hold,
    HOPLITE_OT_save_project,
    HOPLITE_OT_open_project,
    HOPLITE_OT_save_json,
    HOPLITE_OT_export_action,
    HOPLITE_OT_monitor_focus,
    HOPLITE_PT_monitoring,
    HOPLITE_PT_workbench,
)


def register() -> None:
    global AUTOSAVE_TIMER_REGISTERED
    for cls in CLASSES:
        existing = getattr(bpy.types, cls.__name__, None)
        if existing is not None:
            try:
                bpy.utils.unregister_class(existing)
            except RuntimeError:
                pass
        bpy.utils.register_class(cls)
    bpy.types.Scene.hoplite_archetype = EnumProperty(name="Personnage", items=_archetype_items, update=_on_archetype_changed)
    bpy.types.Scene.hoplite_actions = CollectionProperty(type=HOPLITE_ActionItem)
    bpy.types.Scene.hoplite_action_index = IntProperty(default=0, update=_on_action_changed)
    bpy.types.Scene.hoplite_show_non_runtime = BoolProperty(name="Afficher les actions non runtime", default=False)
    bpy.types.Scene.hoplite_clips = CollectionProperty(type=HOPLITE_ClipItem)
    bpy.types.Scene.hoplite_clip_index = IntProperty(default=0)
    bpy.types.Scene.hoplite_clip_filter = StringProperty(name="Filtrer les clips")
    bpy.types.Scene.hoplite_auto_preview = BoolProperty(name="Preview automatique", default=True)
    bpy.types.Scene.hoplite_autosave = BoolProperty(name="Autosauvegarde", default=True)
    bpy.types.Scene.hoplite_trim_frames = IntProperty(name="Frames à retirer", default=0, min=0, max=300)
    bpy.types.Scene.hoplite_detected_hold_frames = IntProperty(default=0, min=0)
    bpy.types.Scene.hoplite_target_armature = StringProperty()
    bpy.types.Scene.hoplite_loaded_profile = StringProperty()
    bpy.types.Scene.hoplite_project_path = StringProperty()
    bpy.types.Scene.hoplite_status = StringProperty()
    bpy.types.Scene.hoplite_monitor_rows = CollectionProperty(type=HOPLITE_MonitorRow)
    bpy.types.Scene.hoplite_monitor_index = IntProperty(default=0)
    bpy.types.Scene.hoplite_provenance_legend = CollectionProperty(type=HOPLITE_ProvenanceLegendItem)
    bpy.types.Scene.hoplite_provenance_legend_index = IntProperty(default=0)
    bpy.types.Scene.hoplite_monitor_scope = EnumProperty(
        name="Vue",
        items=(("ALL", "Global", ""), ("CHARACTER", "Personnage", ""), ("WEAPON", "Arme", ""), ("ISSUES", "Problemes", "")),
        default="ALL",
    )
    bpy.types.Scene.hoplite_monitor_character = EnumProperty(name="Personnage", items=_monitor_character_items)
    bpy.types.Scene.hoplite_monitor_weapon = EnumProperty(name="Arme", items=_monitor_weapon_items)
    bpy.types.Scene.hoplite_monitor_provenance = EnumProperty(name="Provenance", items=_monitor_provenance_items)
    bpy.types.Scene.hoplite_monitor_truth = EnumProperty(name="Etat runtime", items=_monitor_truth_items)
    bpy.types.Scene.hoplite_monitor_search = StringProperty(name="Recherche")
    if not bpy.app.background and not AUTOSAVE_TIMER_REGISTERED:
        bpy.app.timers.register(_autosave_tick, first_interval=60.0, persistent=True)
        AUTOSAVE_TIMER_REGISTERED = True


def _configure_scene() -> None:
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    _populate_actions(scene)
    _populate_clips(scene)
    _populate_monitor(scene)
    _sync_selected_action(scene, load_character=False)
    scene.hoplite_status = "Prêt — charger un personnage puis choisir une action et un clip"
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_distance = 4.5


def _run_self_test() -> dict:
    global PROJECTS_ROOT_RELATIVE, OVERRIDES_PATH
    scene = bpy.context.scene
    if _ui_text("GEANT — 45° ⚠") != "GEANT - 45 deg [!]":
        raise RuntimeError("La normalisation des libelles Blender est invalide")
    if _playback_override() is not None or _set_timeline_playing(True):
        raise RuntimeError("La lecture UI ne doit pas etre lancee en mode background")
    if len(scene.hoplite_monitor_rows) != int((_monitoring().get("summary") or {}).get("monitoring_row_count", -1)):
        raise RuntimeError("Le dashboard ne contient pas toutes les lignes du manifeste runtime")
    hoplite_runtime = next(
        (item for item in scene.hoplite_monitor_rows if item.archetype_id == "ngeneral" and item.action_id == "hoplite_high_thrust"),
        None,
    )
    if (
        hoplite_runtime is None
        or hoplite_runtime.runtime_truth != "runtime_layered"
        or hoplite_runtime.provenance != "shared_bake"
        or not hoplite_runtime.runtime_source_path.endswith("hoplite_animation_library_v4.res")
        or hoplite_runtime.preview_fidelity != "approximate_raw_donor_instead_of_shared_bake"
    ):
        raise RuntimeError("Le dashboard ne restitue pas fidèlement le runtime compose du hoplite")
    weapon_ids = {str(item.get("weapon_family") or "") for item in _monitoring().get("weapons") or []}
    if len(weapon_ids) != 8 or "spear" not in weapon_ids or "bow" not in weapon_ids:
        raise RuntimeError("Le monitoring des familles d'armes est incomplet")
    scene.hoplite_archetype = "__weapon__spear"
    if len(scene.hoplite_actions) < 12:
        raise RuntimeError("Le profil virtuel lance ne contient pas les actions communes et d'arme")
    previewable_index = next((index for index, item in enumerate(scene.hoplite_actions) if item.source_path), -1)
    if previewable_index < 0:
        raise RuntimeError("Le profil virtuel lance ne fournit aucune source prévisualisable")
    scene.hoplite_action_index = previewable_index
    selected_action = _selected_action(scene)
    selected_clip = _selected_clip(scene)
    if selected_action is None or selected_clip is None or selected_action.source_path != selected_clip.source_path or selected_action.source_clip != selected_clip.clip_name:
        raise RuntimeError("La sélection action → clip n'est pas synchronisée")
    archetype = next((item for item in _archetypes() if item.get("archetype_id") == "ngeneral"), None)
    source = next(
        (
            item
            for item in _sources()
            if item.get("compatibility") == "mixamo"
            and item.get("extension") == "fbx"
            and item.get("clips")
        ),
        None,
    )
    if archetype is None or source is None:
        raise RuntimeError("Le manifeste ne fournit pas les fixtures ngeneral/Mixamo du self-test")
    target_objects, _target_actions = _import_asset(_resolve_project_path(archetype["model_path"]), source=False)
    target = _find_armature(target_objects)
    if target is None:
        raise RuntimeError("Le modèle 3DGen de référence ne contient aucune armature")
    source_objects, source_actions = _import_asset(_resolve_project_path(source["path"]), source=True)
    donor = _find_armature(source_objects)
    if donor is None or not source_actions:
        raise RuntimeError("Le pack Mixamo de référence ne contient pas une armature et une Action")
    mapping_count = len(_bone_mapping(donor, target))
    if mapping_count < 12:
        raise RuntimeError(f"Mapping 3DGen/Mixamo insuffisant dans Blender : {mapping_count} os")
    source_action = _choose_imported_action(source_actions, str(source["clips"][0].get("name") or ""))
    preview_action, preview_mapping_count = _retarget_action(
        donor,
        target,
        source_action,
        "HOPLITE_SELF_TEST_PREVIEW",
    )
    if preview_action is None or preview_mapping_count != mapping_count:
        raise RuntimeError("La génération de la preview retargetée a échoué")
    target_bone_count = len(target.data.bones)
    source_bone_count = len(donor.data.bones)
    preview_frame_count = int(preview_action.frame_range[1] - preview_action.frame_range[0] + 1)
    preview_hold_frames = _initial_hold_frames(preview_action)
    target.animation_data_create().action = preview_action
    scene.hoplite_target_armature = target.name
    profile = _selected_archetype(scene)
    action_item = _selected_action(scene)
    editable = preview_action.copy()
    editable.name = _editable_action_name(profile, action_item)
    editable[EDITABLE_ACTION_TAG] = True
    editable["hoplite_action_id"] = action_item.action_id
    if PREVIEW_ACTION_TAG in editable:
        del editable[PREVIEW_ACTION_TAG]
    target.animation_data.action = editable
    original_projects_root = PROJECTS_ROOT_RELATIVE
    original_overrides_path = OVERRIDES_PATH
    with tempfile.TemporaryDirectory(prefix="hoplite_animation_workbench_") as temporary:
        PROJECTS_ROOT_RELATIVE = Path(temporary) / "projects"
        OVERRIDES_PATH = Path(temporary) / "workbench_overrides.json"
        _save_overrides(create_backup=False)
        saved_project = _save_workbench_project(scene, update_status=False, save_copy=True)
        if not saved_project.is_file() or not OVERRIDES_PATH.is_file():
            raise RuntimeError("La persistance .blend/JSON du Workbench a échoué")
        with bpy.data.libraries.load(str(saved_project), link=False) as (available, _requested):
            if editable.name not in available.actions:
                raise RuntimeError("L'Action éditable est absente du projet .blend sauvegardé")
        _clear_owned_objects(source_only=False)
        reopened_objects, reopened_actions = _import_asset(saved_project, source=False)
        reopened_target = _find_armature(reopened_objects)
        reopened_action = next((item for item in reopened_actions if item.get(EDITABLE_ACTION_TAG)), None)
        if reopened_target is None or reopened_action is None:
            raise RuntimeError("Le projet .blend ne peut pas être repris par le Workbench")
    PROJECTS_ROOT_RELATIVE = original_projects_root
    OVERRIDES_PATH = original_overrides_path
    result = {
        "target_bones": target_bone_count,
        "source_bones": source_bone_count,
        "mapping_count": mapping_count,
        "source_actions": len(source_actions),
        "preview_frames": preview_frame_count,
        "virtual_spear_actions": len(scene.hoplite_actions),
        "action_clip_sync": True,
        "ascii_ui_labels": True,
        "background_playback_guard": True,
        "initial_hold_frames": preview_hold_frames,
        "blend_json_persistence": True,
        "runtime_monitor_rows": len(scene.hoplite_monitor_rows),
        "runtime_hoplite_truth": hoplite_runtime.runtime_truth,
        "runtime_weapon_families": len(weapon_ids),
    }
    _clear_owned_objects()
    return result


def main() -> None:
    global PROJECT_ROOT, MANIFEST_PATH, OVERRIDES_PATH, MANIFEST, OVERRIDES
    args = _parse_args()
    if args.project_root:
        PROJECT_ROOT = Path(args.project_root).resolve()
    if args.manifest:
        MANIFEST_PATH = Path(args.manifest).resolve()
    else:
        MANIFEST_PATH = PROJECT_ROOT / "tools" / "animation_workbench" / "data" / "animation_workbench_manifest.json"
    if args.overrides:
        OVERRIDES_PATH = Path(args.overrides).resolve()
    else:
        OVERRIDES_PATH = PROJECT_ROOT / "tools" / "animation_workbench" / "data" / "workbench_overrides.json"
    MANIFEST = _load_json(MANIFEST_PATH)
    OVERRIDES = _load_json(OVERRIDES_PATH, {"schema_version": 1, "bindings": []})
    if int(MANIFEST.get("schema_version") or 0) != 1:
        raise RuntimeError(f"Manifeste incompatible : {MANIFEST_PATH}")
    if bpy.app.version < (4, 2, 0):
        raise RuntimeError("Spartan Animation Workbench nécessite Blender 4.2+")
    register()
    _configure_scene()
    summary = MANIFEST.get("summary") or {}
    self_test_result = _run_self_test() if args.self_test else {}
    print(
        "[SPARTAN ANIMATION WORKBENCH] PASS",
        {"version": SCRIPT_VERSION, "blender": bpy.app.version_string, **summary, **self_test_result},
    )
    if args.self_test:
        bpy.ops.wm.quit_blender()


if __name__ == "__main__":
    main()
