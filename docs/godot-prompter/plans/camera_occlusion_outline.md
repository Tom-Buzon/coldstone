# Camera readability and player silhouette

- Diagnose Enemy V2 occlusion interruptions (godot-debugging, 3d-essentials).
  Preserve the dynamic actor cache on unrelated geometry removal. Regression
  reproduced before the fix and passed afterward. Suppress authored overlays and
  next passes during fading, then restore the original resources.
- Add a combined body/equipment silhouette (shader-basics, 3d-essentials).
  Fader -> outline node -> isolated SubViewport with camera and mesh copies;
  CanvasLayer/TextureRect draws a 3-pixel exterior edge from the combined alpha.
  Share the existing skeleton/skin, copy transforms and blend shapes before draw.
  Hidden equipment and immediate trail/debug meshes are excluded. Cutout alpha
  is preserved. Rendering is disabled when no obstacle is detected.
- Expose the player color and independent outline opacity in Display beside
  existing occlusion settings (godot-ui). ConfigFile persists both;
  apply_outline_settings updates existing faders. Zero opacity disables the edge.
- Validate (godot-code-review, godot-testing): camera_occlusion_fader_test.gd,
  camera_outline_visual_probe.gd (Compatibility renderer), and
  camera_outline_settings_probe.gd (isolated APPDATA for settings writes).

The outline uses the existing protected camera corridor as its trigger and draws
all of the player's silhouette while that corridor is obstructed. Its mask has
no world occluders, so transparent or opaque obstacles cannot cover the edge.

## Close-camera regression
The dynamic actor center-depth test excluded a collider-free actor with its
origin behind the camera, even while its torso surrounded the camera. Extend
the existing dynamic corridor scan with camera/actor-volume overlap before
applying the center-depth rejection. Both real atlas body surfaces now fade.
Validated with the failing-then-passing near-camera regression in
camera_occlusion_fader_test.gd and a Compatibility render in
camera_occlusion_near_actor_probe.gd. Off-axis rear actors still restore normally.

## Interior-facing material correction
The imported atlas materials are double-sided. Temporary fade materials now
use CULL_BACK when the source uses CULL_DISABLED, removing inward-facing walls
while keeping exterior faces alpha-blended. Authored materials are unchanged
and restored after the fade. This applies only while occlusion fading is active.
The Compatibility pixel probe camera_occlusion_backface_probe.gd verifies that
the interior view exactly matches the empty background, the exterior remains
translucent, and the original opaque double-sided wall returns afterward.
Also reran camera_occlusion_fader_test.gd and the real-hoplitе near-camera render.

## Attack-warning silhouettes

- Reuse one shared enemy-warning viewport for every active warning instead of
  allocating one viewport per enemy. Keep it separate from the player viewport
  so both silhouettes can use distinct colors simultaneously. Skills: `shader-basics`,
  `animation-system`, `state-machine`.
- Combat entry points add hostile actors to `enemy_attack_outline_subject` for
  their windup/telegraph phase. Impact, cancellation, recovery, death and scene
  removal clear membership.
- The warning silhouette combines all currently warning enemies, including their
  visible equipment. Its scarlet color is independently configurable in Display;
  outline opacity remains shared with the player silhouette.
- Promote the user's current display values to defaults: turquoise green
  `(0, 0.78622156, 0.5315931)`, outline opacity `0.68`, occluder opacity `0.44`,
  and protection radius `0.10 m`.
