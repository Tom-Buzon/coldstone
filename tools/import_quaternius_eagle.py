"""Export the legacy Quaternius eagle Blender source as a Godot-ready GLB.

Usage:
    blender Eagle.blend --background --python tools/import_quaternius_eagle.py -- output.glb
    blender --background --python tools/import_quaternius_eagle.py -- Eagle.fbx output.glb
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy


def _arguments() -> tuple[Path | None, Path]:
    if "--" not in sys.argv:
        raise SystemExit("Missing output path after --")
    arguments = sys.argv[sys.argv.index("--") + 1 :]
    if len(arguments) == 1:
        return None, Path(arguments[0]).resolve()
    if len(arguments) == 2:
        return Path(arguments[0]).resolve(), Path(arguments[1]).resolve()
    raise SystemExit("Expected output.glb, or input.fbx output.glb")


def main() -> None:
    source, output = _arguments()
    output.parent.mkdir(parents=True, exist_ok=True)
    if source is not None:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
        bpy.ops.wm.fbx_import(filepath=str(source))
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_yup=True,
    )
    print(f"Exported Quaternius eagle to {output}")


if __name__ == "__main__":
    main()
