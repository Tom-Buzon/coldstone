# Runtime performance and non-destructive terrain

## Design

The existing global settings panel remains the single owner of player-facing
performance preferences. It persists values in
`user://hoplite_global_settings_v1.cfg` and mirrors hot runtime values through
`ProjectSettings`, matching the existing enemy LOD and crowd-management flow.

Terrain painting keeps one persistent weight channel per material in the terrain
document. Painting updates only the selected channel inside the brush footprint;
it never replaces the palette or clears weights elsewhere. Rendering splat maps,
the height mesh, and the physics height map are separate update paths.

## Tasks

- [ ] Extend enemy LOD profiles with full-rate contact radius, physics cadence,
  animation cadence, shadow range, and diagnostic refresh settings.
  Skills: `godot-optimization`, `physics-system`, `godot-ui`, `save-load`.
- [ ] Apply those settings to enemy and player hot paths without changing active
  attack/defence precision.
  Skills: `godot-optimization`, `physics-system`.
- [ ] Add distance-tiered fauna physics settings to the existing fauna tab.
  Skills: `godot-optimization`, `godot-ui`, `save-load`.
- [ ] Stage Forge enemy-group construction with a configurable per-frame budget.
  Skills: `godot-optimization`.
- [ ] Split terrain visual, material and collision updates; reuse splat textures;
  preserve all previously painted material channels and rebuild collision at the
  end of sculpt strokes.
  Skills: `godot-optimization`, `assets-pipeline`, `save-load`.
- [ ] Reuse player combat-query objects and throttle diagnostic string building.
  Skills: `godot-optimization`, `physics-system`.
- [ ] Apply safe import defaults to large runtime 3D textures and static models.
  Skills: `assets-pipeline`, `godot-optimization`.
- [ ] Add regression probes, run headless validation and review the finished
  changes.
  Skills: `godot-debugging`, `godot-code-review`.
