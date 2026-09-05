"""Render the source and atlased Hoplite bodies under identical neutral lights.

Run from the project root:
  blender --background --factory-startup --python \
    tools/enemy_v2/render_hoplite_atlas_comparison.py
"""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/lods/hoplite_body_lod0_22k.gltf"
ATLAS = PROJECT_ROOT / "assets/characters/enemy_v2/hoplite/atlased/lods/hoplite_body_lod0_22k_atlas.gltf"
OUTPUT = PROJECT_ROOT / "docs/enemy_refactor/hoplite_v2_atlas_blender_comparison.png"
BODY_NAME = "SPARTAN_character_body"


def import_variant(path: Path, offset_x: float, label: str) -> bpy.types.Object:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = set(bpy.data.objects) - before
    body = next((obj for obj in imported if obj.name.startswith(BODY_NAME) and obj.type == "MESH"), None)
    if body is None:
        raise RuntimeError(f"{BODY_NAME} missing from {path}")
    roots = [obj for obj in imported if obj.parent not in imported]
    for root in roots:
        root.location.x += offset_x
    for obj in imported:
        if obj.type == "ARMATURE":
            obj.data.pose_position = "REST"
    marker = bpy.data.objects.new(label, None)
    marker.empty_display_type = "PLAIN_AXES"
    marker.location = (offset_x, 0.0, 2.25)
    bpy.context.scene.collection.objects.link(marker)
    return body


def point_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_area(name: str, location: tuple[float, float, float], energy: float, size: float) -> None:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    light.location = location
    bpy.context.scene.collection.objects.link(light)
    point_at(light, Vector((0.0, 0.0, 1.1)))


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import_variant(SOURCE, -0.72, "SOURCE")
    import_variant(ATLAS, 0.72, "ATLAS")

    world = bpy.data.worlds.new("NeutralWorld")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.055, 0.065, 0.08, 1.0)
    background.inputs["Strength"].default_value = 0.65
    bpy.context.scene.world = world
    add_area("Key", (-3.5, -4.0, 5.0), 850.0, 4.0)
    add_area("Fill", (4.0, -2.0, 2.8), 520.0, 3.0)
    add_area("Rim", (0.0, 3.5, 4.0), 700.0, 3.0)

    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 70.0
    camera = bpy.data.objects.new("Camera", camera_data)
    camera.location = (0.0, -5.2, 1.18)
    point_at(camera, Vector((0.0, 0.0, 1.08)))
    bpy.context.scene.collection.objects.link(camera)
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(OUTPUT)
    scene.view_settings.look = "AgX - Medium High Contrast"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"HOPLITE_ATLAS_COMPARISON PASS output={OUTPUT}")


if __name__ == "__main__":
    main()
