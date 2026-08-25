# PROJECT HOPLITE — V0.0.12 CROWD PERFORMANCE

This patch targets the first battlefield stress test without reducing enemy count or gore.

## Main fixes

- Anatomy debug meshes are now lazy. With diagnostics OFF, no per-zone MeshInstance3D debug visuals are created.
- Anatomy debug geometry is no longer rebuilt every physics frame.
- Distance-based anatomy tracking LOD:
  - <= 6.5 m: full physics-rate bone tracking
  - 6.5–13 m: reduced update rate
  - > 13 m: low-frequency tracking
- AI tactical goal/separation calculations are cached and throttled; movement still integrates every physics frame.
- Mass soldiers skip separation calculations while far from the player.
- AI CharacterBody3D instances no longer physically collide with each other; crowd spacing is handled by steering separation instead.
- Mass-battle fodder no longer casts dynamic shadows.
- Enemy floating debug labels are created only when I diagnostics are enabled.
- Dead enemies disable their anatomy physics processing/collision immediately.
- Blood keeps the same particle density, but its particle draw meshes/materials are shared instead of rebuilt for every hit.
- I diagnostics now display current FPS in Battle 01.

## Expected effect

The previous anatomy implementation rebuilt roughly 12 debug meshes per enemy per physics frame even while hidden. With 24 enemies at 60 Hz that could mean ~17,000 mesh/material rebuild operations per second. V0.0.12 removes that path entirely while diagnostics are OFF.

## Test

1. Enter Battle 01 with I OFF and note overall smoothness.
2. Enable I and read FPS.
3. Fight in the 24-enemy outer battle, especially when the full crowd converges.
4. Try multiple hits/dismemberments to confirm gore remains dense.
5. Check head/neck precision at close range: anatomy tracking is still full-rate inside 6.5 m.

If performance is still insufficient after this pass, the next level is an engagement/animation LOD system: only nearby enemies run full animation/combat logic while distant soldiers use a cheaper crowd simulation until they enter the combat bubble.
