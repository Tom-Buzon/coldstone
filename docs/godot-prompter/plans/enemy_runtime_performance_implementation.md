# Enemy runtime performance implementation

## Goal

Reduce repeated calls, group scans, temporary allocations and native navigation queries without changing enemy psychology, target priority, attack doctrine, phalanx organization, movement ownership or combat timing.

## Invariants

- The `CharacterBody3D` enemy remains the sole owner of `velocity` and `move_and_slide()`.
- Tactical decisions keep their current staggered cadence.
- Target precedence, strict tie order, claim scoring and retaliation remain unchanged.
- Phalanx slots, readiness, vacancy promotion, about-face, expulsion arcs and sorties remain unchanged.
- NavMesh path advancement still calls `get_next_path_position()` on active physics ticks.
- The mass-battle threshold remains 28.
- No morale, perception, command dependency or other psychological behavior is added in this slice.

## Ordered work

- [x] Capture the targeted probe and callback-performance baseline.\
  Skills: `godot-optimization`, `godot-testing`.
- [x] Cache NavigationServer map/layer readiness per navigation component with bounded refresh and squared-distance thresholds.\
  Skills: `ai-navigation`, `gdscript-advanced`, `godot-testing`.
- [x] Build crowd-owned faction/phalanx snapshots at the existing 20 Hz spatial cadence and let enemies reuse them without per-think SceneTree scans.\
  Skills: `component-system`, `gdscript-advanced`, `godot-optimization`, `godot-testing`.
- [x] Reuse per-enemy neighbor buffers and cache local pressure by spatial-grid revision.\
  Skills: `godot-optimization`, `gdscript-advanced`, `godot-testing`.
- [x] Remove phalanx membership string construction and compute proximity metadata once per cohort build.\
  Skills: `ai-navigation`, `component-system`, `gdscript-advanced`, `godot-testing`.
- [x] Cache shared LOD settings with bounded live refresh, cadence phalanx equipment pose with animation LOD, and make severed-bone enforcement dirty/sample driven.\
  Skills: `godot-optimization`, `gdscript-advanced`, `godot-testing`.
- [x] Cache the archer's current-ground sample without weakening edge lookahead. Derived injury flags were deliberately left uncached because external tools and probes can mutate zone state directly.\
  Skills: `ai-navigation`, `godot-optimization`, `gdscript-advanced`, `godot-testing`.
- [x] Run syntax/import checks, targeted probes, mixed stress, callback benchmark and Godot code review.\
  Skills: `godot-code-review`, `godot-optimization`, `godot-testing`.

## Deferred until separate behavioral proof

- One shared NavMesh path per phalanx cohort: high potential, but it can change corridor traversal and obstacle behavior.
- Coarse distant anatomy hitboxes and full simulation sleep: they can miss long-range impacts or battle events.
- Projectile/VFX pooling: requires explicit reset contracts for every transient type.
- A registry-authoritative targeting migration: the current registry is not injected into every route and strict candidate parity is not yet proven.
