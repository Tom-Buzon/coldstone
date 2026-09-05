# Archers and infantry in the V2 army

The Forge laboratory IDs `enemy_v2_archer` and `enemy_v2_infantry` resolve to
`archer_v2` and `infantry_v2`. Their shared definitions declare `unit_role` as
`archer` or `infantry`. They use the existing 23-bone hoplite body, its three
mesh LODs, anatomy, health and fragment components. Production V1 identities
are unchanged; these are preliminary role implementations with placeholder
hoplite skins.

See [the current composition contract](V2_COMPOSITION_AND_ARMIES.md) for weapons, optional abilities, factions and army commanders.

## Runtime responsibilities

- `enemy_actor_v2.gd` selects a combat component through
  `_create_combat_component()` and the definition’s `weapon_script`. Bow and sword scripts live under `weapons/`; the old filenames are compatibility adapters. Its public army interface is unchanged.
- `enemy_v2_role_combat.gd` reuses V2 lifecycle, capsule and guard infrastructure;
  the archer and infantry components own their decisions and attacks. No legacy
  enemy controller or live animation donor is instantiated.
- Infantry performs a short sortie up to 5.5 m from its assigned position,
  limited to 1.4 seconds before giving up. Sword reach is 2.1 m. The strike
  direction locks at commitment, with a 0.52–0.55 second warning and a vulnerable
  recovery. The smaller shield uses a weaker guard profile.
- Archers fire at 9–34 m, remain stationary during a one-second draw, and lock
  their aim before release. One retreat lasts at most 1.2 seconds / 4 m, followed
  by a six-second delay before another retreat. Army orders still own their
  larger-scale position.
- `archer_v2_projectile.gd` advances a real ballistic arrow, sweeps against the
  world and the target, and never homes. Shared geometry, a 2.4-second lifetime
  and a global cap of 40 arrows bound its cost. World visibility checks are
  staggered; the army's `is_fire_lane_clear` rejects allied formation footprints
  before commitment and again before release.
- `is_attack_committed()` and `attack_budget_seconds()` expose the threat lease
  contract. Archer commitment includes a surviving arrow in flight.
- Losing either archer arm disables the bow. Losing the infantry weapon arm
  disables sword attacks; losing its shield arm disables blocking.

## Animation and distant rendering

`build_enemy_v2_role_animation_library.gd` bakes the existing Mixamo sword and
bow clips offline into `enemy_v2_roles.res`. Then `build_composed_animation_packs.gd` produces separate common/bow/sword packs; the runtime composes only the required packs. Each role clip has 23 tracks;
archer legs use the neutral pose instead of the donor's backward walk.
The bow is attached to the left hand and calibrated against that baked pose.

The impostor root retains the existing hoplite renderer and lazily creates at
most two additional MultiMesh batches for archer and infantry atlases. Each
batch refreshes at 4 Hz, without adding per-actor far processing. Archer atlas
framing reserves room for the bow while preserving body scale and foot height.

Regenerate with `generate_hoplite_v2_impostor_atlas.gd -- --role=archer_v2` or
`--role=infantry_v2`, using a rendering-capable Godot process, then import the PNGs.

## Verification

Passing Godot 4.7 probes:

- `enemy_v2_roles_probe.gd`: body/LOD/anatomy contracts, projectile hit and dodge,
  bounded withdrawal, sword direction lock, functional arm severing.
- `enemy_v2_roles_impostor_probe.gd`: distinct role atlases, exactly three
  shared batches, aggregate counts and waking back into 3D.
- Historical `hoplite_v2_foundation_probe.gd` and `hoplite_v2_impostor_probe.gd`.

`enemy_v2_roles_visual_probe.gd` captures the aim, guard and cut poses for visual
review. Final animation polish and the future individual unit reimports remain
separate asset work; their runtime role contracts now exist in V2.
