# Enemy V2 — collective traffic contract

Implemented for the persistent-front army. No dependency on the legacy enemy actor.

## Ownership and progress

- `request_route(group_id, start, goal, focus, width, priority=0, depth=-1, forward=Vector3.ZERO, formation_height=2.0)` returns a path only when the next 18 m can be reserved. A failed replacement keeps the previous reservation intact. The caller must keep the previous order on failure and must not release before requesting a replacement.
- `configure_world(node_in_world)` enables collision-layer-1 ground, obstacle and clearance checks. This uses a weak reference and the world's existing navigation map, with no per-soldier NavigationAgent.
- `can_follow_route(group_id)` must gate movement along an order. `get_route_status` returns `moving`, `waiting_corridor`, `yielding`, `arrived` or `idle`.
- `update_footprint` also reports progress. The horizon advances at most once per 220 ms and releases cells behind the formation. If extension conflicts, the formation waits and retains only still-useful cells. It can resume automatically when the conflict clears.
- Mere heartbeat cannot renew a stuck formation. After 3.6 s without forward progress its future corridor is released; its real footprint remains occupied. It yields 0.7–1.05 s before reacquiring. Failed route requests back off to at most one attempt per roughly 2.2 s, with stable per-group staggering.
- Up to eight corridors in a 30 m local neighborhood and 32 across the map can coexist. Rear movements cannot consume the entire admission budget of an unrelated front. After at least 1.8 s of waiting, priority rises with wait age; a lease older than 4 s can be handed off atomically after the replacement has passed all terrain and footprint checks. Actual occupied bodies are never preempted. Failed replacement leaves the other lease intact. Conflicting near-term corridors are exclusive; distant path crossings outside the horizon do not block one another.

## Formation execution

- `occupancy.constrain_motion(group_id, current, proposed, from_forward, to_forward)` checks local neighboring oriented boxes, including intermediate rotation. A step returns either `proposed` or `current`.
- `occupancy.rotation_is_clear(group_id, center, from_forward, to_forward)` gates rotation independently.
- `occupancy.resolve_overlap(group_id, current, max_step)` provides a bounded separating-axis escape for initially overlapping groups, without entering another neighbor.
- `occupancy.overlap_count()` counts actual oriented-footprint intersections. `nearby_group_ids(center,radius)` queries the spatial hash; no unsafe fixed-count truncation is used.

Reservations use oriented swept boxes and sampled corner rotations, rasterized into conservative cells for corridor ownership. Footprint conflicts use those cells only as broad phase, followed by exact swept boxes and rotation samples, so stationary parallel wings can share a grid cell when their physical boxes are clear.

## Terrain and limits

The scheduler attempts direct paths first, then the existing navmesh path, two local parallel lanes and exterior fallback arcs. Terrain queries are skipped for already occupied corridor candidates; a clear direct route needs no navmesh query. Width, depth, initial/corner rotations and body height are checked against static geometry. Ground support and slope are sampled across the formation width at 1.5 m intervals. Sampled HeightMapShape3D bodies remain in support/slope rays but are excluded from flat volume sweeps: individual soldiers follow relief, so the uphill wing must not be interpreted as a wall. Other static geometry stays solid. Giant callers should pass their actual world body height as the final argument.

Terrain queries are bounded at 320 per request, with a small ground-sample cache. The scheduler starts at most two route solves per physics frame; after 2 ms of cumulative solve work it starts no further solve that frame. This is an admission budget, not interruption of an in-progress atomic solve: a single solve can exceed 2 ms. Deferred callers retry through the existing command cadence. Direct clear routes avoid blocker rasterization; extra conflict discovery is performed only for an aged conflicting lease. Paths longer than 240 m are rejected rather than issuing unbounded work. This is a bounded local planner: very complex bottlenecks may require moving the strategic objective or an authored rally lane. It deliberately does not pretend that a point navmesh path guarantees passage for a whole formation. Live execution still relies on actor physics for fine terrain contact.

## Validation

Godot 4.7 headless:

- `tools/enemy_v2/enemy_v2_formation_traffic_probe.gd`: PASS. Failed replacement preservation, distant versus near crossing, horizon release/extension conflict and recovery, stalled lease and delayed retry, oriented wings, intermediate 180-degree rotation, bounded overlap escape, six simultaneous independent fronts, local/global capacity fairness with progressing lease holders, atomic fair handoff failure, physical wall, missing floor, infantry versus giant overhead clearance.
- `tools/enemy_v2/hoplite_v2_tactical_stability_probe.gd`: PASS.
- `tools/enemy_v2/hoplite_v2_battle_layout_probe.gd`: PASS.

Use `--log-file .godot/<probe>.log` inside the sandbox. The host emits a certificate-store error on startup; the probes themselves exit 0. Rendering/performance of the mixed army remains an integration-level check, not a result inferred from these service probes.

Integration diagnostics are available as `traffic.diagnostics` (latest actual request by group, start/goal, accepted, rejection list with blocker/position, queries and cost in microseconds) and `traffic.rejection_counts`. `tools/enemy_v2/enemy_v2_traffic_map_probe.gd` runs the actual Forge 414 map and prints these alongside movement. A 300-frame run after the updated placement produced 14 groups moving, all four fronts and both giants in motion, zero footprint conflicts, p95 17.51 ms and p99 17.94 ms at a 60 FPS cap in headless mode. These timings include frame pacing and are not GPU or uncapped performance measurements. Typical actual route requests measured 0.3–1 ms, with the largest observed in that run 1.85 ms at the 320-query ceiling. Remaining blocked deployment positions and role goals are visible in the diagnostics for the map/army director to resolve.


Final fairness regression: eight progressing local leases do not starve a distant ninth group, an aged local request eventually obtains an atomic handoff, a failed handoff preserves the previous owner, and a third same-frame route solve resumes on the following frame. The final mixed-map integration and isolated benchmark are run by the parent task after placement, role and traffic changes are all combined.
