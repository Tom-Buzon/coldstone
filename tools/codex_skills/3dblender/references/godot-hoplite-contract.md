# Godot and Hoplite asset contract

Read this reference when the output targets Godot, especially the Hoplite repository.

## Godot-wide defaults

- Prefer binary glTF (`.glb`). It preserves meshes, PBR materials, skeletons, animations, extras, and hierarchy more reliably than legacy OBJ/FBX paths.
- Author in Blender meters. Blender is Z-up and normally faces -Y; glTF conversion yields Godot Y-up with the intended forward direction at -Z when `export_yup=True`.
- Cameras and lights face -Z in Godot. Do not bake compensating 90-degree transforms into the final asset; validate the imported orientation.
- Export normals and UVs. Export tangents when normal maps require them or let Godot generate tangents on import.
- Keep material count low and names stable. Godot batching/MultiMesh benefits from shared mesh and material resources; per-instance unique materials defeat that benefit.
- Godot can generate LODs on import, but explicit LOD meshes are appropriate when openings, modular borders, silhouette, or gameplay contacts require authored control.

## Collision choices

- Static scenery may use a coarse concave/trimesh proxy when primitives cannot preserve required openings.
- Moving `RigidBody3D`, `CharacterBody3D`, debris, and destructible chunks must use primitive or modest convex collision. Never use concave collision for moving bodies.
- Do not scale physics bodies or collision shapes at runtime. Export at correct meter size and keep transforms at identity.
- A visual stair commonly uses a ramp proxy. Doorways, arches, bridge gaps, broken walls, and mantle gaps must remain open in collision.
- Generic Godot import supports authoring suffixes such as `-col`, `-convcol`, `-rigid`, `-navmesh`, and `-occluder`. Follow the repository's stronger local convention when one exists.

## Hoplite package layout

The current project library uses:

```text
assets/blenderAseet/<family>/<asset>/
|-- <asset>_LOD0.glb
|-- <asset>_LOD1.glb
|-- <asset>_LOD2.glb              optional when not useful
|-- <asset>_collision.glb
|-- <asset>_occluder.glb          only for suitable large opaque modules
|-- <asset>_<technical-part>.glb  articulated/destructible variants
`-- asset_manifest.json
```

Only `LOD0` is exposed as the main Forge object. Technical variants containing `LOD1`, `LOD2`, `collision`, `occluder`, `intact`, `fractured`, or movable-part names remain separate.

Hoplite invariants:

- one Blender unit equals one meter;
- Godot up is +Y and forward is -Z;
- use stable snake_case asset IDs and filenames;
- keep identical pivot, origin, orientation, and bounds intent across LODs;
- preview collections, lights, cameras, and floors never enter GLBs;
- sources `.blend` and production renders remain outside the runtime asset folder unless the user explicitly chooses otherwise;
- textures embedded in GLB are acceptable, but material/image duplication across LODs should be avoided;
- include custom glTF extras for gameplay-relevant sockets, axes, reach, module size, or variant identity.

## Hoplite manifest

Write an `asset_manifest.json` next to the exports. Include only fields supported by the asset:

```json
{
  "asset": "asset_id",
  "status": "PASS",
  "quality": "V2_HERO",
  "units": "meters",
  "dimensions_m": [1.0, 2.0, 0.5],
  "forward_blender": "-Y",
  "forward_godot": "-Z",
  "triangles_lod0": 1200,
  "triangles_lod1": 480,
  "triangles_lod2": 120,
  "collision": "two box proxies preserving the central opening",
  "origin": "center of base",
  "identity": "short sentence naming the readable visual identity",
  "textures_packed": true
}
```

Use actual measured values. Do not mark `PASS` until the generator's validation succeeds.

## Archetype-specific Hoplite needs

- **Crowd equipment:** few materials, low triangles, shared palette, explicit grip/socket metadata, no unique texture per soldier.
- **World-editor repeated props:** one surface when possible, LODs, stable ground pivot, no collision for dense foliage, MultiMesh-compatible resource sharing.
- **Traversal architecture:** exact walkable widths/heights, authored simple collision, preserved gaps, base/connector pivot, optional coarse occluder.
- **Weapons:** grip root at origin or documented offset, reach/contact segment in extras, blade/shaft forward axis documented, visual mesh separate from hit logic.
- **Destructibles:** intact and fractured variants, limited closed chunks, one primitive/convex collider per active chunk, collision and LOD not exposed as main library entries.
- **Characters:** reuse the project's expected skeleton/animation contract; do not invent a new rig for an asset expected to consume UAL animation.

## Import-side checks

After the user exports and places files in Godot:

- verify every GLB imports and instantiates as a `Node3D` with at least one `MeshInstance3D`;
- confirm LOD0 count/catalog visibility and that technical files stay hidden from the Forge;
- inspect axes, scale, materials, UVs, normals, skeleton/animation names, and attachment transforms;
- enable mipmaps and VRAM compression for 3D textures;
- verify generated/import LOD behavior at gameplay distances;
- test collision against traversal, crowd navigation, and moving-body constraints rather than relying on the Blender preview.
