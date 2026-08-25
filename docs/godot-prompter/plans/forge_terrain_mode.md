# Forge terrain mode — implementation plan

## Decision

Use a native Godot heightfield per chapter rather than a third-party terrain addon. The terrain is stored as a regular Forge entity, rendered with an `ArrayMesh`, collided with through `HeightMapShape3D`, generated reproducibly with `FastNoiseLite`, and textured with the existing triplanar PBR material library.

This keeps saved worlds portable, preserves the Forge undo/redo and test workflows, and avoids an editor-only dependency that would not exist in exported builds.

## Scene tree

```text
EditableWorld (Node3D)
└── Terrain_<id> (StaticBody3D)
    ├── TerrainMesh (MeshInstance3D / ArrayMesh)
    └── TerrainCollision (CollisionShape3D / HeightMapShape3D)

HopliteWorldForge (Node3D)
├── WorldRuntime (HopliteWorldRuntime)
├── TerrainBrushMarker (MeshInstance3D)
└── CanvasLayer
    ├── Content / Library / Terrain
    ├── Properties / Terrain
    └── HelpCenter
```

## Data flow

1. A terrain preset creates a `terrain` entity containing resolution, generator parameters, seed, material, and serialized heights.
2. `HopliteWorldTerrain` normalizes or generates the height array and builds both render mesh and collision from the same samples.
3. A sculpt stroke pushes one undo snapshot, edits nearby samples, and rebuilds only the selected terrain body for live feedback.
4. Saving writes the height array into the versioned Forge JSON; loading normalizes legacy or incomplete terrain data.
5. Preview and playable test use the same builder, so authored geometry and collision cannot drift.

## Ordered tasks

- [ ] Add `HopliteWorldTerrain`: normalization, seeded presets, ArrayMesh, HeightMapShape3D, sculpt and height sampling.
  Skills: `3d-essentials`, `physics-system`, `procedural-generation`, `gdscript-patterns`, `scene-organization`
- [ ] Extend world document versioning, validation and runtime construction for the new terrain entity.
  Skills: `gdscript-patterns`, `physics-system`
- [ ] Add the Terrain category, material previews, sculpt controls, cursor, inspector actions, placement support and undo integration.
  Skills: `godot-ui`, `assets-pipeline`, `3d-essentials`
- [ ] Update the integrated help center and `README_WORLD_EDITOR.md`.
  Skills: `godot-ui`
- [ ] Add a terrain probe and run parse/runtime checks; review the completed Godot changes.
  Skills: `godot-testing`, `godot-debugging`, `godot-code-review`
