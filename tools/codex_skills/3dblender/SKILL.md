---
name: 3dblender
description: Generate standalone Blender Python scripts for visually strong, topology-conscious, game-ready 3D assets, including low-poly props, modular environments, weapons, LODs, collisions, previews, and Godot-ready glTF packages. Use when the deliverable is bpy code or a procedural Blender asset; do not use for hand-modeling instructions alone or for Godot runtime code.
---

# 3D Blender

Create Blender Python scripts that make assets worth shipping, not merely recognizable primitive assemblies. Optimize for silhouette, controlled topology, material economy, reliable reruns, and engine-ready output.

## Start from the asset contract

Before writing geometry, determine the asset archetype, real dimensions, viewing distance, repetition count, target platform/engine, visual style, required articulation, collision behavior, and whether textures are available. Infer conservative defaults when the brief is sufficient; ask only when a missing choice would materially change topology or the output package.

Read [references/asset-archetypes.md](references/asset-archetypes.md) to select the geometry, LOD, collision, pivot, and material strategy. When the target is Godot or the current Hoplite project, also read [references/godot-hoplite-contract.md](references/godot-hoplite-contract.md).

## Design the asset before coding it

Define these in a short comment near the script configuration:

- primary silhouette and proportions;
- two or three identity features visible at gameplay distance;
- repeated details that should be geometry, texture, vertex color, or omitted;
- triangle and material budgets as targets, not permission to fill them;
- pivot, forward axis, attachment points, and collision intent;
- LOD degradation order: remove microdetail first, preserve silhouette and gameplay openings last.

Use a 60/30/10 visual hierarchy: dominant mass, secondary forms, restrained accents. Spend polygons on curved silhouettes, joints, and profile changes. Do not spend them on unseen backs, coplanar ornaments, or uniformly dense subdivisions.

## Generate a standalone script

Use [assets/static_game_asset_template.py](assets/static_game_asset_template.py) as the plumbing baseline for ordinary static assets, then replace its calibration-crate construction with task-specific art. Read [references/blender-python-patterns.md](references/blender-python-patterns.md) when adapting mesh construction, materials, instances, validation, or export.

The delivered script must normally:

- run from Blender's Text Editor and from `blender --background --python`;
- declare editable art and output parameters near the top;
- use meters, a deterministic seed, stable names, and no external Python packages or add-ons;
- delete only its own generated root collection on rerun unless the user explicitly requests a full scene reset;
- separate asset, collision, and preview collections so preview objects never enter the game export;
- prefer direct data API, `Mesh.from_pydata`, or `bmesh`; use `bpy.ops` only with explicit selection, active object, and mode;
- create PBR materials through Principled BSDF and probe renamed sockets by capability;
- apply scale and rotation, set a meaningful origin, convert export-time curves/text to meshes, and produce deterministic normals;
- print dimensions, triangle counts, material counts, topology warnings, output paths, and PASS/FAIL;
- write GLB, preview, blend source, and manifest only when those outputs fit the request.

If the user only wants code, provide one self-contained `.py` script plus concise run/output notes. Do not require them to assemble fragments manually.

## Game-ready invariants

- A static render is not proof of a game asset. Validate evaluated triangle count, transforms, materials, topology, UV requirements, pivot, axes, naming, and exported contents.
- Keep material slots low and share materials between repeated assets. Joining meshes does not reduce draw calls if surfaces still use many materials.
- Use bevels deliberately: scale-aware width, usually one to three segments, and only where highlights improve form readability.
- Avoid Subdivision Surface on export meshes unless the brief explicitly justifies it and the evaluated budget is checked.
- Curves are useful construction tools but must be converted or confirmed exportable. Control bevel resolution and sampled points.
- Repeated details should share mesh data or be instanced during construction. Realize or join only when the target export/runtime requires it.
- Do not triangulate early unless a modifier or deformation needs fixed diagonals. Count triangles before export and triangulate deterministically at the end when the target requires exact topology.
- Texture-backed assets need intentional seams, non-overlapping packed UVs, texel-density awareness, and mip-safe padding. Flat palette assets may omit UVs only when the engine/material path truly does not need them.
- Collision is authored from gameplay intent, never copied blindly from render geometry.

## Quality gate

Before delivering, syntax-check the Python file. When Blender is available and the user allows execution, run it in background mode in an isolated output directory and inspect the printed validation summary and preview. Otherwise state that Blender execution remains for the user.

Reject the result and revise when any of these occur:

- the asset reads as stacked default primitives without a coherent silhouette;
- tiny bevels or dense cylinders consume geometry without changing gameplay readability;
- LODs collapse openings, contacts, or proportions required by gameplay;
- collision fills a deliberate gap, uses concave geometry on a moving body, or depends on object scale;
- the export contains lights, cameras, preview floor, hidden helpers, or duplicate materials;
- rerunning the script creates `.001` names or accumulates stale objects/materials;
- the script reports no measurable triangle/material/dimension evidence.

## Provenance

The reusable scene, palette, collection, instance, camera, and lighting ideas were informed by CGArtPython's MIT-licensed `blender_plus_python` examples. They are adapted here for deterministic real-time assets; the tutorial repository's render-loop defaults, destructive cleanup, dense curve sampling, and lack of UV/export/topology validation are not treated as game-ready defaults.
