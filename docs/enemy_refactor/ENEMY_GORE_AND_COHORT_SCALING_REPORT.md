# Enemy gore and cohort scaling report

## Result

The expensive presentation work has moved out of the damage frame without changing the intended dismemberment presentation. Logical severing is still immediate. The visible detached object is still the authored Spartan package branch sampled in the living actor's current 53-bone pose, with its matching gore cap, primitive collision, impulse, four-second physical phase and fourteen-second visible lifetime.

Blood still uses the existing composition:

- every flesh hit: primary directional spray plus dense mist;
- every sever: a second stronger primary spray plus dense mist;
- every sever: one additional narrow arterial jet.

The pool changes *when resources are built*, not what is shown.

## Runtime architecture

`HopliteGoreDirector` is scene-scoped and normally created with the battle crowd director. It owns:

- 24 prebuilt blood bursts, each containing the three reusable GPU emitters and persistent process materials;
- package-specific detached-fragment pools sized from the number of living registered actors, capped at eight per package and 24 globally during prewarming;
- compact active arrays with absolute retire/expiry times;
- O(1) oldest-blood recycling when the visual budget is full.

An enemy now sends a blood or fragment request. The hit path only rearms existing resources, copies the current pose through cached bone indices, changes the body-zone visibility mask, configures the primitive collision and applies the impulse.

The previous path instantiated a complete character package, rebound it, prepared/merged its body, searched bone names, created two or three particle nodes and their materials, scanned the `blood_fx` group and created timers during the hit.

## Cohort and per-tick work

The crowd director remains the authoritative formation brain. Its existing shared assignment cache now defaults to 12 Hz rather than 20 Hz. Mass-battle phalanx soldiers resample the published order at:

- 10 Hz near the player;
- 6.25 Hz at medium distance;
- 4 Hz at long distance.

Movement, collision avoidance and combat execution are still individual. Outside urgent states, mass-battle actors at render LOD 1/2/3 execute full physics work every 2nd/3rd/5th physics callback and accumulate skipped delta. The optimisation is disabled for attacks, attack recovery, defense windows, defense reactions, guard breaks, parry counters and close contact. Thus the player-facing timing remains full-rate where it matters.

## Measurements

The dedicated headless sever benchmark runs 1, 4 and 8 simultaneous forearm cuts and records synchronous work plus the following 30 frames.

| Simultaneous severs | Original single baseline | Post-change median (3 runs) | Authored fragments | Blood layers | Runtime fragment growth |
|---:|---:|---:|---:|---:|---:|
| 1 | 6.267 ms | 2.188 ms | 1 | 2 spray + 2 mist + 1 jet | 0 |
| 4 | 7.798 ms | 2.571 ms | 4 | 8 spray + 8 mist + 4 jets | 0 |
| 8 | 12.965 ms | 4.302 ms | 8 | 16 spray + 16 mist + 8 jets | 0 |

Wall-clock numbers vary with headless scheduling and are diagnostic, not a portable performance guarantee. The structural assertion that warmed cuts perform no fragment-pool growth is deterministic.

For 56 active `ngeneral` phalanx soldiers over 120 physics ticks, the benchmark recorded:

- 649 full tactical goal evaluations, approximately 324 per second for the entire formation;
- 6,210 full physics steps;
- 510 deferred low-priority steps;
- no structural cleanup leak.

## Validation

Passing probes cover sever spikes, transient lifecycles, all severable anatomy zones, faction targeting, attack scheduling, crowd tactics, multi-cohort coordination, phalanx optimisation, cohort recovery, navigation, animation LOD, archer height behavior, authored equipment, unit behavior and a 22-family/36-unit mixed stress scene.

The headless runner still reports the known Windows sandbox warning about reading the system root certificate store. It does not affect project execution or probe results.
