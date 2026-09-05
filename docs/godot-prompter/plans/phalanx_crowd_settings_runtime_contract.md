# Phalanx crowd-settings runtime contract

## Goal

Make `Settings > Gestion de la foule` the authoritative and understandable place
for phalanx movement, formation geometry, coordination and simulation cadence.
Every visible control must affect a current runtime consumer immediately.

## Audit result and chosen design

Three approaches were considered:

1. Keep movement constants in enemy profiles and only rename the existing slider.
   Rejected: the visible value would still not control soldier catch-up or braking.
2. Let every soldier read `ProjectSettings` in its physics callback. Rejected: it
   duplicates lookups in a hot path and spreads ownership across actors.
3. Keep the crowd director as the settings owner. Chosen: it resolves the global
   phalanx geometry and publishes a compact movement contract with each already
   cached assignment. Soldiers cache that contract and update their lightweight
   navigation component only when tactical assignments refresh.

The audit found that the old phalanx keys still had code consumers, but several
labels and scopes were misleading: advance speed controlled only the cohort anchor,
arrival braking was hard-coded and invisible, geometry lived in archetype profiles,
and the about-face threshold was bypassed by a hard-coded formed-line threshold.
Those mismatches are removed instead of leaving nominal controls in the menu.

## Public controls

- **Movement:** anchor speed, soldier catch-up multiplier, braking distance and
  minimum braking speed.
- **Formation:** columns, lateral spacing, rank spacing, assembly readiness and
  explicit turning/about-face behavior.
- **Coordination:** number/range of coordinated cohorts, coverage and support arcs.
- **Intrusion response:** solo expulsion geometry and duration.
- **Sorties:** striker count, attack radius and phase durations.
- **Simulation cadence:** spatial/contact/layout/assignment refresh rates, clearly
  marked as CPU-versus-reactivity controls rather than movement speed.

## Tasks

- [x] Add the movement and formation controls to the shared definitions and raise
  the default advance speed.
  Skills: `godot-prompter:ai-navigation`, `godot-prompter:godot-ui`.
- [x] Resolve geometry in the director and publish movement/braking fields through
  cached assignments; consume them without per-frame settings lookups.
  Skills: `godot-prompter:ai-navigation`, `godot-prompter:godot-optimization`.
- [x] Make the about-face slider control the formed-line threshold and migrate only
  unchanged legacy defaults.
  Skills: `godot-prompter:godot-debugging`.
- [x] Validate UI coverage, live propagation, phalanx invariants, Forge behavior,
  parsing and CPU cost.
  Skills: `godot-prompter:godot-code-review`, `godot-prompter:godot-optimization`.
