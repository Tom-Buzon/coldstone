# HOPLITE V0.0.2 — Localized Damage / Dismemberment Prototype

Extract this archive at the **Godot project root** (the folder containing `project.godot`).

It adds/replaces:

- `scripts/player.gd` — sword sweep hit detection + localized HitEvent generation.
- `scripts/main.gd` — spawns five blue UAL1 Athenians in the combat pad.
- `scripts/combat/hit_event.gd` — common hit payload (damage, sever power, direction, velocity context).
- `scripts/enemy/anatomy_profile.gd` — reusable humanoid zones and thresholds.
- `scripts/enemy/anatomy_hitbox.gd` — bone-following hitboxes on collision layer 8.
- `scripts/enemy/athenian_enemy.gd` — blue mannequin target, local health/sever state, weapon/shield drops.
- `scripts/gore/detached_limb_proxy.gd` — temporary physical limb proxy.

## What this validates

The important reusable part is already separated from the visual model:

`Sword sweep -> exact anatomy shape -> HitEvent -> zone damage/sever accumulator -> sever event`

The UAL1 mannequin is a single skinned mesh, so V0.0.2 uses a **prototype sever visual**: it forces the relevant bone chain almost to zero scale and ejects a simplified physical blue limb/head. This is only to validate gameplay and localization. A future pre-cut gore mesh can replace this visual step without changing the HitEvent/anatomy architecture.

## Test

- Light attacks: moderate damage / low sever power.
- Charged heavy: high sever power; easiest way to test neck/limb severing.
- Dash attacks: movement bonus to damage/sever.
- Slide light/contact: extra sever bonus while sliding.
- Right arm/forearm sever: sword drops.
- Left arm/forearm sever: shield drops.
- Head/neck sever: fatal.

Enable **Debug -> Visible Collision Shapes** in Godot to inspect the anatomy hitboxes.

## Collision layers used

- 1: world
- 2: player body
- 4 (bit value): enemy body
- 8 (bit value): anatomy Areas queried by the sword
- 16 (bit value): detached physics props

No runtime assets are included. The prototype reuses:

`res://assets/runtime/ual1/UAL1_Standard.glb`
