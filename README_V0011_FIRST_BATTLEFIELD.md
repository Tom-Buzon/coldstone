# PROJECT HOPLITE — V0.0.11 FIRST BATTLEFIELD

This patch keeps the existing combat lab as the tutorial and adds a separate playable Battle 01.
The historical inspiration is intentionally not named in this prototype so the scenario remains unspoiled.

## Entering the battle

A red `BATTLE 01` portal is added near the far end of the tutorial map. Walk through it to load `battle_01.tscn`.
A blue portal behind the Battle 01 spawn returns to `combat_lab.tscn`.

## Battle structure

### Phase 1 — outer wall assault
- Large open approach to a fortified city wall.
- 24 enemies active together.
- 3 captain/miniboss squads plus a loose forward line.
- Gate remains closed until the exterior force is cleared.
- Regular exterior soldiers use `mass_battle_mode`: full anatomy, gore, severing and AI remain active, but they use lightweight UAL1 animation instead of one complete UAL2 donor stack per fodder soldier.

### Phase 2 — city skirmishes
Three sequential urban ambush arenas.
- Offset gates force a zig-zag route through the city.
- Tall buildings create dead ends and visual enclosure.
- Low walls, terraces and crates are within the existing parkour range and provide shortcuts/high ground.
- Each zone contains a captain and a mixed squad. Urban captains get +18% HP, +12% damage and +5% uniform scale over the outer-wall captains.
- The next gate opens only when the current ambush is cleared, preventing the direct-chase prototype AI from dragging every city encounter into one giant pile.

### Phase 3 — final citadel
- Clean enclosed courtyard.
- Only the final `WARLORD` and six close guards spawn there.
- Warlord is a new archetype: 134% scale, 980 HP, heavier damage/reach.
- Clearing the entire final guard spawns a `BATTLE COMPLETE` portal back to training.

## HUD / diagnostics
- Normal play remains clean: only Spartan HP is displayed.
- `I` enables the same complete diagnostic mode as the tutorial: player logs, anatomy hitboxes, sword sweep and enemy state labels.
- Battle diagnostics additionally show alive counts for the current phases.

## Files
- `battle_01.tscn` — new battle scene.
- `scripts/battle/battle_01.gd` — battlefield geometry, encounter triggers, gates and spawning.
- `scripts/main.gd` — tutorial portal to Battle 01.
- `scripts/enemy/enemy_archetypes.gd` — adds `warlord`.
- `scripts/enemy/athenian_enemy.gd` — adds optional lightweight `mass_battle_mode` animation path.

## Performance intent
Battle 01 is intentionally a stress test. The exterior starts with 24 enemies, but only the 3 captains use the full UAL2 retarget/donor animation architecture. The other 21 still retain exact anatomy/gore/AI while using direct UAL1 Idle/Jog/Sword_Attack playback. City encounters are spawned only when entered, and the final encounter does not exist until the citadel is reached.
