# Hoplite lancer arm, about-face and shield fix

## Goal

Correct the visible spear thrust, the phalanx 180-degree turn and the imported
aspis orientation without adding runtime animation donors or extra skeletons.

## Architecture

- Import `lancier_attack_animation_test.glb` as a build-time source only.
- Copy only its canonical right-arm tracks into the shared hoplite animation
  library. The source rig has the same 53 named bones as `ngeneral`, so no
  runtime retargeter is required.
- Layer that right-arm clip over the existing upper-body action branch only for
  `spear_thrust` and `spear_thrust_low`. Shield/block actions retain their
  current animation. Normal strikes and phalanx sorties already use those two
  public spear actions, so they share the correction automatically.
- Preserve the phalanx lateral line during an about-face. Reverse the formation
  facing and remap rows in place instead of rotating all slot positions around
  the cohort anchor. Each character then turns on its own occupied position.
- Correct the imported aspis at its equipment root, leaving procedural shields
  and non-phalanx units unchanged.

## Runtime constraints

- One visible `Skeleton3D`, one `AnimationPlayer` and one `AnimationTree` per
  hoplite remain the complete runtime animation graph.
- The Blender GLB is never instantiated by a soldier. Only the baked shared
  `.res` animation library is loaded.
- The about-face is an event-driven slot remap, not a per-frame reassignment or
  pathfinding operation.

## Validation

- Shared-library probe: verify the right-arm clip contains only approved bones,
  includes the forearm position track and changes the hand pose.
- Forge animation/behaviour probes: verify regular attacks and sorties still
  route through the shared driver and complete normally.
- Crowd probe: move the target directly behind a multi-row cohort and verify
  world slot positions remain stable while facing and row roles reverse.
- Equipment probe: verify imported dory/aspis attachment, scale, hitbox and the
  corrected aspis visual transform; verify non-phalanx shields are untouched.

## Follow-up: lateral identity during a slow flank

The first about-face correction covered a sudden 180-degree target change. A
slow player flank could still remain below the angular threshold on every frame,
allowing the complete line basis to rotate and eventually exchange its left and
right soldiers.

- Once a solo straight phalanx is formed, freeze its undirected lateral axis.
- Choose between the two opposite normals of that same line when the target
  changes side; remap depth ranks in place, but never rotate lateral columns.
- Keep the existing solo penetration/expulsion response when the player crosses
  through the guarded width. The axis lock applies to an external flank and to
  the stable line before/after that response.
- Add a slow 180-degree orbit regression. It must verify pairwise world-space
  column ordering on every intermediate sample, not only the final destination.
