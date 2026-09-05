# Enemy gore and cohort runtime scaling

## Invariants

- Dismemberment remains immediate from the gameplay point of view: hitboxes are disabled and the living mesh branch is hidden on the hit frame.
- The detached package fragment keeps the authored skinned meshes, the sampled pose, the matching gore cap, the same collision dimensions, impulse and lifetime.
- Blood keeps the existing primary spray, dense mist and sever-only arterial jet. Optimisation comes from reuse, not a lower visible preset.
- Cohort changes must preserve the existing phalanx slot, breach, veteran, attack-token and recovery contracts.

## Architecture

The current scene owns one `HopliteGoreDirector`. Enemies send compact blood and fragment requests to it. The director owns prewarmed blood emitters, prebuilt Spartan fragment bodies and their deadlines. It performs O(1) active-budget eviction and recycles nodes rather than instantiating/freeing them during combat.

The crowd director remains the authoritative cohort brain. Its published phalanx assignments receive a stable revision/expiry contract so soldiers can reuse an order without rerunning the full individual tactical question chain. Individual actors retain collision response, injury, defense and attack execution.

## Tasks

- [x] **Benchmark sever bursts (1/4/8 simultaneous)** — Measure synchronous sever cost, following-frame peaks, nodes, resources and active physics bodies.\
  Skills: `godot-prompter:godot-optimization`, `godot-prompter:godot-testing`
- [x] **Central gore director and blood pool** — Build/rearm existing three-layer visual presets with no group scan, per-burst timer or runtime particle/material allocation.\
  Skills: `godot-prompter:component-system`, `godot-prompter:particles-vfx`, `godot-prompter:gdscript-advanced`
- [x] **Prebuilt package fragment pool** — Prepare skinned package fragments outside the hit path, cache direct bone-index copies and recycle rigid debris after the same visible lifetime.\
  Skills: `godot-prompter:physics-system`, `godot-prompter:godot-optimization`, `godot-prompter:gdscript-advanced`
- [x] **Persistent cohort orders** — Reuse the director's cohort assignments at 12 Hz, reduce formation-soldier thought cadence, and apply safe mass-battle physics tiers outside urgent local events.\
  Skills: `godot-prompter:ai-navigation`, `godot-prompter:state-machine`, `godot-prompter:component-system`, `godot-prompter:godot-optimization`
- [x] **Regression and performance validation** — Run anatomy, dismemberment, transient, phalanx, behavior, navigation and mixed-stress probes plus before/after benchmarks.\
  Skills: `godot-prompter:godot-debugging`, `godot-prompter:godot-testing`, `godot-prompter:godot-code-review`

## Measured outcome

- The sever benchmark verifies 1, 4 and 8 simultaneous authored fragments, with two primary sprays, two dense mists and one arterial jet per sever.
- No fragment grows on the measured hit path when the matching living population has registered its package.
- The original single baseline run measured 6.267 / 7.798 / 12.965 ms of synchronous work for 1 / 4 / 8 severs. Three post-review runs have medians of 2.188 / 2.571 / 4.302 ms. These wall measurements are diagnostic rather than a cross-machine regression gate; the structural no-allocation assertions are deterministic.
- A 56-unit phalanx benchmark over 120 physics ticks records 649 tactical goal evaluations (about 324/s for the whole cohort), with 510 low-priority physics steps deferred and all attack/guard/contact steps kept at full cadence.

## Review result

- No runtime group scan, `PackedScene.instantiate()`, new particle node, new `ParticleProcessMaterial`, or new timer occurs on a warmed sever path.
- Fragment pose copying performs bone-name lookup only on the first preparation of each pooled fragment, then reuses direct indices.
- Retired pooled fragments restore their authored shadow modes when reused.
