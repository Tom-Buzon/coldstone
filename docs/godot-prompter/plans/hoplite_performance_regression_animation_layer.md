# Hoplite performance regression — animation layer

## Goal

Restore the Forge performance obtained before the lancer-arm change while
preserving the authored Blender spear motion, the single canonical skeleton,
the phalanx behaviour, movement speed and dismemberment.

## Measured diagnosis

- The v4 runtime adds four per-instance `AnimationNode` resources
  (`LancerRightArm`, seek, speed and blend) to every hoplite.
- The branch is connected to the output and is therefore evaluated with every
  animation sample, including idle samples where its blend is zero.
- At 28 active `ngeneral` units, the current structural benchmark contains
  4,559 objects versus 4,443 in the last v3 measurement: +116 objects, which
  matches the four added animation resources per unit plus harness variance.
- The source GLB remains outside the runtime import graph (`.gdignore`), so the
  regression is not caused by an extra visible mesh or donor skeleton.

## Repair

1. Bake `spear_thrust` and `spear_thrust_low` as composite clips in the shared
   library: UAL2 torso/left-arm pose plus Blender right-arm tracks.
2. Keep one runtime action branch per hoplite and select the already-composed
   clip. Do not create a second permanent blend branch.
3. Retain the extracted right-arm clip in the build artifact for source audit,
   but do not evaluate it as an independent runtime layer.
4. Update probes to require distinct composite clips and to reject a lingering
   `LancerRightArm` runtime node.

## Validation

- Rebuild the shared library from animation-only source data.
- Compare the same 15/28/36 `ngeneral` benchmark before and after.
- Run shared-rig, Forge animation, Forge behaviour, phalanx coordination,
  animation LOD and crowd cadence probes.
- Confirm one skeleton, one player and one tree per hoplite, with no donor rig.
