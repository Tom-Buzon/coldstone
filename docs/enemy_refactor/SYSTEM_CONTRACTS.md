# Enemy system contracts

Status: discovery draft. Existing runtime behavior remains authoritative until a row is characterized and frozen.

## Global invariants

- GDScript-only implementation for this refactor.
- One canonical combatant architecture for enemies and allied NPC combatants.
- One owner per combatant for `velocity`, physical rotation, and `move_and_slide()`.
- Archetype differences come from typed data, strategies, or specialized components.
- Compatibility adapters are temporary and must record a removal condition.
- Existing public signals, callable methods, exported properties, group names, scene paths, resource paths, and NodePaths remain compatible during migration.

## Candidate canonical ownership model

This is a hypothesis to validate against the inventory, not an implementation commitment.

| Responsibility | Intended owner | Inputs | Outputs/contracts to preserve |
|---|---|---|---|
| Entity composition | Common combatant root | Archetype resource, faction, spawn context | Existing scene/public entity surface |
| Archetype data | Typed `Resource` | Authored configuration | Stable immutable/default data per archetype |
| State transitions | Explicit state machine | Perception, combat, health, tactical intents | Observable state/animation/combat behavior |
| Perception/targeting | Shared targeting component/service | World candidates, faction rules, tactical claims | Current target semantics and signals |
| Locomotion/navigation | Single motion owner | Movement/formation/navigation intents | `velocity`, rotation, `move_and_slide()` |
| Combat/defense | Common interfaces with strategies | Attack/defense intents, equipment, stats | Light/heavy/special/projectile, guard/parry/break/armor |
| Crowd/formations | Shared coordinator | Group membership, roles, claims | Phalanx and tactical role behavior |
| Animation | Common animation adapter | Semantic animation intents | Existing clips, reactions, timing callbacks |
| Health/anatomy | Common health/anatomy interface | Hit data, localized damage | Death, gore, body-part and quest/progression events |
| Creation/registry | Single factory and combatant registry | Spawn request/context | All narrative/procedural/lab/test spawn contracts |

## Current runtime topology

- `HopliteAthenianEnemy extends CharacterBody3D` is the sole enemy/allied-NPC combatant root (`scripts/enemy/athenian_enemy.gd`).
- The same class serves hostile Athenians and Spartan allies through pre-ready `faction` configuration.
- `HopliteEnemyFactory.spawn_request()` is the single runtime construction point. Battles 01–03, the lab, and the procedural campaign use it directly; the concurrently edited Forge runtime still reaches it through the dictionary-compatible `spawn()` adapter.
- `HopliteCombatantRegistry` is a scene-scoped ordered, non-owning instance-ID service with an explicit opt-in factory path. After D-017's isolated cost gate, only `combat_lab` owns one controlled instance; existing SceneTree groups and domain ledgers remain authoritative and no gameplay system queries the registry.
- `HopliteEnemyArchetypes` exposes dictionary profiles rather than typed resources. `all_ids()` currently exposes 22 IDs.
- No `NavigationAgent3D`, `NavigationRegion3D`, or `NavigationServer3D` path exists. Locomotion is steering/separation plus archer-specific ground scans.
- `mass_battle_mode` is an animation-cost strategy on the same controller, not a second AI implementation.

## Factory contract

`HopliteEnemyFactory.spawn_request(parent, request)` accepts the typed ephemeral `HopliteEnemySpawnRequest` and owns the sole `EnemyScript.new()` call. Configuration must happen before `parent.add_child(enemy)` because `_ready()` builds identity groups, collision, visuals, anatomy, and AI runtime. A request may explicitly inject a same-SceneTree `HopliteCombatantRegistry`; the factory registers only after `add_child()` and never discovers a service implicitly. Only `main.gd` laboratory requests currently set this field; Battle, procedural, Forge and all other runtime requests leave it null.

`HopliteEnemyFactory.spawn(parent, archetype, position, target, options)` is the temporary dictionary compatibility adapter. It recognizes `name`, `ai_enabled`, `mass_battle_mode`, `faction`, `ai_target`, `battle_player`, `guard_index`, `scale_multiplier`, `match_perfect_hitbox`, `giant_traversal_mode`, both giant capsule multipliers, `giant_walkable_tops`, `commander`, `is_miniboss`, and `package_path`, preserves explicit-null override semantics, and translates them to the typed request. It can be retired only after the Forge runtime and supported tools have migrated and old Forge/save adapters no longer call it.

`name` is a required non-empty `String` when supplied: Godot rejects an empty node name and the legacy `String(...)` conversion rejects `null`. Nullable override semantics therefore apply to the two target fields, not to `name`.

The `target` argument populates both `ai_player` and `battle_player` by default. The new optional overrides preserve allied legacy behavior: `battle_player = player`, `ai_player = null` before `_ready()`. `is_miniboss = true` may promote a troop for authored legacy encounters; `false` does not demote a profile-ranked miniboss/boss because `_apply_archetype_profile()` preserves rank authority.

## Entity signals

| Signal | Runtime consumers that make it public |
|---|---|
| `died(enemy)` | Battles 01–03 counters/quests, procedural waves, world runtime, lab feedback |
| `zone_severed(enemy, zone)` | Lab/battle feedback and gore presentation |
| `localized_hit(enemy, zone, damage, sever_damage)` | Lab/battle presentation and contact feedback |
| `attack_started(enemy, weapon_kind)` | Player threat response, lab/battle audio/feedback |
| `combat_phase_changed(enemy, phase)` | Procedural boss phase and campaign UI/progression |

## Public methods consumed at runtime

| Domain | Methods |
|---|---|
| Combat | `receive_ai_hit`, `receive_spiral_smash`, `can_receive_hit_from`, `get_combat_aim_point`, `is_dead_for_combat`, `is_combat_zone_severed` |
| AI/scenes | `alert_ai`, `configure_demo_patrol`, `configure_training_activation`, `hold_battlefield_position` |
| Formation/giants/debug | `is_phalanx_unit`, `is_wall_run_giant`, `set_combat_debug_visible` |

## Public fields of fact

Although the controller has no exported configuration, callers write these fields directly before `_ready()` and they therefore remain compatibility contracts until adapters replace them:

- identity/spawn: `archetype_id`, `faction`, `ai_enabled`, `ai_player`, `battle_player`, `ai_miniboss`, `ai_guard_index`, `mass_battle_mode`, `external_scale_multiplier`, `character_package_path`;
- giant traversal: `match_perfect_hitbox`, `giant_traversal_mode`, capsule multipliers, `giant_walkable_tops`;
- observable state/customization: `dead`, `health`, `max_health`, `combat_phase`, `formation_columns`, and Battle 01 boss stat overrides.

## Groups and metadata

| Contract | Values |
|---|---|
| Faction groups | `ally`, `spartan_ally`, `enemy`, `athenian` |
| Combat groups | `damageable`, `combatant`, `combatant_ai`, `ally_ai`, `enemy_ai` |
| Tactical/rank groups | `phalanx_unit`, `enemy_miniboss`, `enemy_epic`, `crowd_director` |
| Traversal groups | `wall_run_phalanx_shield`, `giant_wall_run_surface`, `enemy_walkable_surface` |
| Target/formation metadata | `hoplite_ai_claims`, `formation_group` |
| Giant/anatomy metadata | `giant_owner`, `matched_model_mesh`, `matched_physical_zone`, `damage_zone` |
| Spawn/world metadata | `procedural_archetype`, `campaign_legion_id`, `campaign_legion_anchor`, `campaign_entry_surge`, `world_entity_id`, `world_group_id`, `training_group` |

## Target and tactical-ownership lifecycle

- `battle_player` is the stable human reference; `ai_player` is the immediate combat target. Default, explicit-null and distinct non-null overrides are separate spawn contracts.
- Athenians prioritize valid retaliation, then a local human, then `spartan_ally`; Spartans scan `enemy`. Candidate scoring preserves group order, flat distance, claim penalty and current-target stability.
- `_set_combat_target()` remains the sole target-claim owner. Target switch, death, hold-position and D-013 live tree exit release the prior `hoplite_ai_claims` value; live tree exit also releases any crowd attack permission.
- SceneTree groups remain compatibility discovery indexes. The procedural `active_enemies` and Forge `enemies_by_group` dictionaries remain domain ledgers, not aliases for a future global registry.
- A future scene-scoped registry may index registration/liveness but must not own claims, movement, attack permission, retaliation or encounter progression. See `TARGETING_REGISTRY_DESIGN.md`.

## Movement ownership

`athenian_enemy.gd` is currently the sole combatant owner of `velocity`, physical facing, and its one `move_and_slide()` wrapper. `HopliteBattleCrowdDirector` returns positions/intentions and never moves bodies. Procedural staging temporarily writes `velocity`, `global_position`, and `scale`; this exception must be encapsulated before locomotion extraction. Enemy projectiles own their own independent velocity and are not combatant locomotion.

## Characterized animation, pose and giant contracts

- Fourteen specialized profiles must build a skeleton/AnimationPlayer, retain a non-empty combat pattern, start their authored pattern opener and keep mechanical duration within `0.10 s` of the playing clip. Direct Mixamo and selective-retarget drivers are both supported strategies, not parallel enemy architectures.
- Giant packages remain unarmed, keep the internal world-floor collider while exposing no animated convex body to the player, and provide a collision-layer-256 smooth traversal cylinder plus a convex collider extracted from the real head mesh. `HeadFloor` is the only assisted top stabilizer and `is_wall_run_giant()` remains true.
- The thirteen pose-integrity fixtures must retain a valid positive standing height after package grounding; visual retargeting or package changes may not collapse them into a rest/T-pose or below-floor placement.
- Assisted giants must settle on the floor, accept torso traversal from every horizontal direction without floor-like limb facets, preserve the body/head seam, and update the traversal cylinder/head collider when leg severing moves them into crawl. Crawl anatomy must still resolve a damage zone and reduce health.
- Player wall-run light/heavy releases, charge through attachment/jump, shield/corner handling and layered movement clips remain compatible with giant and world traversal. Combat attack sampling must preserve clip motion, aim assist, shield recoil/feedback/animation and ordinary-versus-cinematic hit behavior.

These are characterization contracts, not new owners. Evidence is in `enemy_animation_probe`, `pose_integrity_probe`, `giant_traversal_probe`, `wall_run_probe` and `combat_attack_probe`.

## Existing specialized strategies to preserve

- Animation: UAL2/retarget driver, lightweight Mixamo, and Spartan package/pose bridge.
- Defense: shield, parry, armor, dodge, guard stamina/break.
- Tactics: engagement rings, attack permissions, phalanx assignments, formation metadata, local target claims.
- Health/anatomy/gore: health on the entity with `HopliteAnatomyHitbox`, `HopliteShieldHitbox`, localized `HopliteHitEvent`, severing, detached limbs, and blood effects.
- Giants: specialized colliders, walkable surfaces, injury/crawl, and player wall-run contracts.

## Known compatibility adapters/legacy contracts

| Contract | Why retained | Removal condition |
|---|---|---|
| `is_miniboss` mapping a default swordsman to captain | Old scene/setup compatibility | No scripts, scenes, resources, saves, or tools depend on it |
| `sword_root` / `sword_dropped` naming for any weapon | Lab and probe compatibility | All consumers use weapon-neutral API |
| Crowd `engagement_position()` fallback | Duck-typed compatibility | Every supported director provides canonical assignment API |
| Direct field configuration in world/procedural staging | Existing scene contracts | Typed spawn/runtime control interfaces cover every write |
| Dictionary `HopliteEnemyFactory.spawn(...)` | Forge and compatibility probes still pass option maps | Forge/runtime callers construct typed requests and save/schema compatibility is covered |
| `HopliteEnemyArchetypeData.legacy_profile()` | Controller, campaign, Forge and tools still consume normalized dictionaries | Every dictionary consumer has migrated to typed fields and all 22 archetypes remain covered |

Probe-only calls to private `_...` methods are characterization coupling. They need a future diagnostic adapter before those internals can move, but they are not automatically promoted to gameplay API.
