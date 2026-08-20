# HOPLITE V0.0.3 — Combat Precision / Gore Lab

Extract this archive at the **Godot project root** (the folder containing `project.godot`).

This patch keeps the V0.0.2 localized damage/dismemberment prototype and improves the six validation points before moving to a real pre-cut gore mesh.

## 1. Whole-blade hit detection

The xiphos no longer detects only its tip. `player.gd` now creates a `SwordBladeBase` marker and sweeps a capsule covering the full blade from base to tip. Previous/current blade transforms are temporally sampled so fast animation frames are much less likely to tunnel through anatomy hitboxes.

## 2. Better anatomy-zone resolution

All anatomy shapes touched on a target during the sweep are collected first. The game then chooses the best zone from physical distance plus a small target-priority bias. This prevents the large torso capsule from stealing obvious neck/head/forearm contacts.

The anatomy capsules were also corrected: Godot `CapsuleShape3D.height` includes both hemispheres, so the V0.0.3 capsules add the radius at both ends and actually cover the full bone-to-bone segment.

## 3. Blade-velocity hit gating

Animation progress remains a broad safety window, but damage now also requires real blade motion. This keeps anticipation/recovery poses from dealing damage while preserving fast authored attack frames.

## 4. Soft horizontal aim assist

Light/heavy/spin attacks can correct toward a nearby enemy inside a 34-degree cone and 3.45 m range. Correction is capped to 15 degrees, so this is a soft near-miss assist rather than a hard lock-on. Slide direction is not hijacked.

## 5. F8 combat diagnostics

Press **F8** to toggle:

- colored anatomy volumes following the real bones;
- white full-blade hit capsule;
- orange temporal sweep lines;
- HUD values for blade speed, selected zone and accepted candidates.

Anatomy bone mappings are also printed to the Godot Output when each Athenian is spawned.

## 6. Blood spray

`scripts/gore/blood_burst.gd` adds procedural directional GPU-particle blood bursts with no external texture dependency. Normal hits produce droplets + mist; a sever produces a much larger secondary burst at the cut.

## Group test

The combat pad now contains:

- 5 spaced blue Athenians for precision/localization tests;
- 5 tightly packed blue Athenians for cleave, spin, dash and slide group tests.

## Files added/replaced

- `scripts/player.gd`
- `scripts/main.gd`
- `scripts/enemy/anatomy_profile.gd`
- `scripts/enemy/anatomy_hitbox.gd`
- `scripts/enemy/athenian_enemy.gd`
- `scripts/gore/blood_burst.gd` (new)
- existing `hit_event.gd` and `detached_limb_proxy.gd` are included unchanged so the ZIP is self-contained for the enemy prototype.

No runtime assets are included. It still reuses:

`res://assets/runtime/ual1/UAL1_Standard.glb`
