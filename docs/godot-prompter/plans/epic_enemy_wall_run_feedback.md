# Epic enemy wall-run feedback

## Goal

Make wall-runs on giants and raised phalanx shields read as deliberate, high-adrenaline actions in every playable world. The feedback must remain stable when a contact lasts only a few frames and must compose with the existing perfect-response and execution slow motion.

## Design

The player remains the authority for wall-run contact and surface classification. Its existing `HopliteCombatFeedback` child becomes the single owner of wall-run camera composition, slow motion, and the global traversal callout.

```text
Player (CharacterBody3D)
├── CameraYaw / CameraPitch / SpringArm3D / Camera3D
└── CombatFeedback (Node, PROCESS_MODE_ALWAYS)
    └── EpicTraversalHUD (CanvasLayer)
        ├── Tint + edge accents
        └── GIANT RUN / SHIELD RUN callout
```

Data flow:

```text
wall contact -> Player classifies world / giant_enemy / phalanx_shields
             -> CombatFeedback.set_wall_run_state(...)
             -> real-time envelopes compose time scale + camera + HUD
             -> contact loss requests release; minimum presentation tail protects short runs
```

No world scene owns this feature. `CombatFeedback` is constructed by `Player`, so Forge worlds, campaign worlds, combat labs, and future worlds receive the same behavior automatically.

## Tasks

- [x] **Centralize wall-run camera composition in `CombatFeedback`.** Preserve the existing subtle world-wall accent and add distinct giant/shield profiles that compose with combat feedback.
  Skills: `camera-system`, `3d-essentials`, `gdscript-patterns`
- [x] **Add interruption-safe real-time slow motion.** Use a continuous envelope with a minimum readable presentation and no awaited sequence or stacked tween.
  Skills: `tween-animation`, `gdscript-patterns`
- [x] **Add a global traversal HUD callout.** Show unmistakable `GIANT RUN` and `SHIELD RUN` treatments with different colors and subtitles.
  Skills: `hud-system`, `gdscript-patterns`
- [x] **Connect player wall-run state and cover the regression probe.** Validate ordinary wall-run recovery, both epic variants, short-contact tails, and full time-scale restoration.
  Skills: `godot-code-review`, `godot-debugging`

## Revision 2 — player-focused camera

- [x] **Reduce the slow-motion strength.** Keep the action readable without making traversal feel suspended.
  Skills: `tween-animation`, `gdscript-patterns`
- [x] **Move the real camera rig toward the player's feet.** Smoothly lower the orbit pivot and shorten the collision-aware `SpringArm3D` while the epic envelope is active.
  Skills: `camera-system`, `math-essentials`
- [x] **Blend horizontal, diagonal, and vertical framing.** Drive FOV, pitch, yaw, roll, pivot height, and camera distance from smoothed orientation weights so mid-run transitions cannot snap.
  Skills: `camera-system`, `math-essentials`, `gdscript-patterns`
- [x] **Extend the wall-run probe.** Validate reduced slow motion, progressive foot focus, zoom-in, orientation-specific framing, smooth orientation changes, and restoration.
  Skills: `godot-code-review`, `godot-debugging`

## Revision 3 — movement-relative chase framing

- [x] **Orbit behind the wall-run travel direction.** Smoothly align the camera rig forward with the horizontal travel tangent, placing the SpringArm camera on the opposite side of movement.
  Skills: `camera-system`, `math-essentials`
- [x] **Aim back up from the foot-level pivot.** Increase the orientation-specific pitch compensation so the whole player remains framed while the camera sits low and close.
  Skills: `camera-system`, `math-essentials`
- [x] **Protect the cinematic framing from look-input jitter.** Attenuate manual look while the guided epic camera is active without corrupting the saved pitch intent.
  Skills: `camera-system`, `input-handling`, `gdscript-patterns`
- [x] **Validate rightward travel and direction changes.** Assert camera-behind geometry, player-facing view direction, smooth yaw transitions, and pitch compensation.
  Skills: `godot-code-review`, `godot-debugging`

## Revision 4 — tunable easing and giant low-angle profile

- [x] **Replace the abrupt epic envelope with an ease-in-out curve.** Keep the real-time, interruption-safe state machine while exposing a per-run transition duration.
  Skills: `tween-animation`, `math-essentials`, `gdscript-patterns`
- [x] **Separate shield and giant framing.** Reduce shield FOV/distance zoom and place the giant camera below the player with an upward-looking angle.
  Skills: `camera-system`, `math-essentials`
- [x] **Expose persistent tuning in the global Camera settings tab.** Add live sliders for height, distance, pitch, FOV zoom, world speed and transition duration for each run type.
  Skills: `godot-ui`, `save-load`, `gdscript-patterns`
- [x] **Validate defaults, live settings, easing and restoration.** Extend the wall-run and global-settings probes, then rerun combat camera regressions.
  Skills: `godot-debugging`, `godot-code-review`

## Revision 5 — promote playtest tuning to defaults

- [x] **Promote the saved Shield/Giant Run values.** Copy the active Godot `ConfigFile` values into both player definitions and runtime feedback fallbacks.
  Skills: `save-load`, `gdscript-patterns`
- [x] **Extend the normal camera range to 1 metre.** Keep the saved 3.5 m framing as the reset default while synchronizing runtime and menu bounds.
  Skills: `camera-system`, `godot-ui`
- [x] **Validate the new bounds and defaults.** Cover minimum-distance clamping, reset behavior and every promoted traversal value.
  Skills: `godot-debugging`, `godot-code-review`
