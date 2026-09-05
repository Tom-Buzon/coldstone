# Crowd engagement coordination foundation

## Approved gameplay contract

- Individual enemies share one target-centric engagement coordinator.
- Melee slots fill by physical arrival, not archetype or update order.
- Rings rotate in alternating directions; bosses/minibosses occupy a static inner pocket.
- A lone phalanx advances as a straight shield line. Penetrating it triggers its temporary expulsion crescent.
- Two primary phalanx cohorts connect curved sectors over a configurable partial enclosure.
- Three primary cohorts complete the enclosure; later cohorts form support rings.
- Individual melee units fill the contact-sector gaps left by phalanxes.
- Phalanx members never reserve individual crowd slots.

## Runtime ownership

```text
HopliteBattleCrowdDirector (Node, one per battle)
├── HopliteCrowdEngagementCoordinator (RefCounted)
│   └── arrival records, role lanes, rings, boss pocket
├── phalanx cohort state
│   └── stable internal slots, battle-sector assignment, breach response
└── attack scheduler and spatial cache

HopliteAthenianEnemy (temporary compatibility facade)
└── participant descriptor -> director -> navigation intent
```

The new services own no skeleton, animation, physics body or movement. Later unit-controller extraction can keep the same participant and assignment contracts.

## Tasks and required GodotPrompter skills

- [ ] Add shared crowd tuning data and the global settings tab.
  Skills: `component-system`, `godot-ui`, `resource-pattern`.
- [ ] Route individual engagement through the target-centric coordinator.
  Skills: `ai-navigation`, `math-essentials`, `component-system`.
- [ ] Remove phalanx ghost reservations and publish role descriptors.
  Skills: `state-machine`, `component-system`.
- [ ] Coordinate multi-cohort phalanx sectors while preserving the solo straight-line/breach lifecycle.
  Skills: `ai-navigation`, `math-essentials`, `state-machine`.
- [ ] Add deterministic probes and Forge regressions.
  Skills: `godot-testing`, `godot-debugging`.
- [ ] Profile and review the implementation.
  Skills: `godot-optimization`, `godot-code-review`.
