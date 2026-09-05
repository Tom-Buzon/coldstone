# Phalanx cohesion and equipment synchronization

## Goal

Improve phalanx readability and shield/body synchronization without raising AI,
physics, or animation sampling frequencies.

## Chosen design

Three approaches were considered:

1. Raise animation and formation refresh rates. Rejected because it spends more CPU
   and does not fix competing transform ownership.
2. Interpolate every shield independently each rendered frame. Better visually, but
   adds permanent per-shield work and still leaves the hand and tactical facing in
   competition.
3. Give each concern one owner. Chosen: the cohort owns slots, the actor owns its
   smoothly turning body, and the guarded shield follows the actor root instead of
   receiving alternating hand-bone and world-space transforms. No new runtime node
   or high-frequency query is required.

## Tasks

- [x] Add cohort-aware personal space and arrival damping so slot movement converges
  instead of oscillating.
  Skills: `godot-prompter:ai-navigation`, `godot-prompter:godot-optimization`.
- [x] Synchronize the guarded shield and spear facing with the actor's actual body
  orientation; restore authored hand attachment when guard ends.
  Skills: `godot-prompter:animation-system`, `godot-prompter:godot-optimization`.
- [x] Add regression probes for same-cohort spacing, damped arrival, shield parent
  ownership, and shield/body facing coherence.
  Skills: `godot-prompter:godot-debugging`.
- [x] Run parser, phalanx/crowd/navigation probes, animation LOD probes and CPU
  benchmark; review the final code.
  Skills: `godot-prompter:godot-code-review`, `godot-prompter:godot-optimization`.

## Field feedback follow-up

The first arrival ramp was too wide: a moving formation spent most of its travel
inside the slow zone. Keep arrival damping, but confine it to the final 0.44 m and
retain at least 52% speed so the cohort can catch a moving anchor.

Column identity is a hard invariant. A member's existing row/column descriptor must
survive cohort-state expiry, implicit-key changes and an about-face. Reuse the
director's existing per-member slot history in packed form; on state reconstruction,
restore every compatible occupied descriptor before allocating vacancies. Recover
the sign of the lateral axis from the preserved columns and current member positions.
This adds no node, query, update frequency, or additional per-member dictionary.

- [x] Tighten and raise the formation arrival ramp.
  Skills: `godot-prompter:ai-navigation`, `godot-prompter:godot-optimization`.
- [x] Persist packed slot descriptors through cohort-state reconstruction and recover
  lateral-axis sign without crossing files.
  Skills: `godot-prompter:ai-navigation`.
- [x] Add regression coverage for fast arrival, state recreation and 180-degree turns.
  Skills: `godot-prompter:godot-debugging`, `godot-prompter:godot-code-review`.
