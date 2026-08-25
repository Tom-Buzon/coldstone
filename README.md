# IMPORTANT — dossiers surveillés par la bibliothèque automatique

Au prochain démarrage, la salle **Bibliothèque des assets** parcourt récursivement les dossiers suivants :

```text
assets/characters/3dgen_demo/       personnages
assets/environment/                 décors importés
assets/weapons/                     armes (dossier futur accepté)
assets/items/                       objets (dossier futur accepté)
assets/props/                       éléments de décor (dossier futur accepté)
_source/environment_props_raw/      décors GLB bruts
_source/weapons_raw/                armes brutes (dossier futur accepté)
_source/items_raw/                  objets bruts (dossier futur accepté)
```

- Formats exposés automatiquement : `.glb` et `.gltf`.
- Un dossier de cette liste peut ne pas encore exister : il sera simplement ignoré jusqu'à sa création.
- Les fichiers contenant `collision`, `collider`, `proxy`, `LOD1`, `LOD2`, etc. ne deviennent pas des expositions séparées.
- `LOD0` est accepté comme modèle principal.
- Les suffixes numériques d'export, par exemple `Nsbire2-1787348495833.glb`, sont retirés pour détecter les doublons.
- Lorsqu'un même élément existe dans plusieurs dossiers, le premier dossier de la liste ci-dessus est prioritaire.
- Les textures et fichiers techniques ne sont pas exposés comme des objets indépendants.
- Le chargement est progressif et les GLB bruts sont mis en cache afin d'éviter un import massif ou un blocage au démarrage.

# Project Hoplite — UAL Native Combat Lab V2

This is a clean standalone Godot 4.7 project.

## Why this version exists

The visible player is the mannequin embedded in **Universal Animation Library 1**. UAL1 therefore drives locomotion on its own native rig — no retargeting.

**Universal Animation Library 2** is loaded only as an authored combat-animation donor. Its bone tracks are copied onto the matching Universal skeleton of the visible UAL1 mannequin. This removes the old Superhero/glTF texture problem and removes the different-rig retargeting problem.

## Install

1. Close Godot.
2. Run `SETUP_ASSETS.bat`.
3. Run `VERIFY_ASSETS.bat`.
4. Open `project.godot`.
5. Wait for both GLBs to finish importing.
6. Run the project.

## Controls

- AZERTY ZQSD / QWERTY WASD — movement
- Mouse — TPS camera
- Left click / J — Light 1 → Light 2 → Light 3
- Hold + release right click / K — Heavy
- A on AZERTY physical layout / middle mouse — 360
- Space x2 — double jump
- Jump toward a wall while holding movement — automatic wall run (up to 10 m)
- Hold along the wall — horizontal run; angle toward it — diagonal run; head-on — short vertical run
- Space during a wall run — wall jump plus a protected, jump-strength mode-specific outward repulsion
- Two wall runs maximum per airborne sequence, and only a deliberate wall jump arms the second
- Automatic detachment blocks a new wall run until landing, but steering toward that wall returns after the 60 ms release guard
- Horizontal/diagonal automatic detachment uses the mirrored Front Twist Flip aerial exit
- Horizontal automatic detachment preserves the running momentum but applies only 10% of the additional release kick; vertical release input is filtered for only 60 ms, then a double jump can steer back toward the wall even if forward stayed held
- Light attacks and heavy charge/release remain available during wall runs; an existing heavy charge survives wall attachment and wall jumps
- Light attacks and heavy charge/release remain available during wall runs; an existing heavy charge survives wall attachment and wall jumps
- Horizontal runs follow connected interior corners up to 100°, never exterior 270° corners
- Experimental enemy wall running — enemies at least 1.55× normal scale and lines of 3+ raised phalanx shields can become continuous wall surfaces; their horizontal/diagonal release repulsion is 80% lower than world walls; set `experimental_enemy_wall_run_enabled = false` in `scripts/player.gd` for a one-switch rollback
- A reachable world lip during a vertical/diagonal run — mantle takes priority automatically; enemy and shield surfaces can never trigger mantle
- Wall running adds a subtle FOV, roll and camera-bob accent that eases out after release
- Shift — dash / roll
- F3 — cycle sword orientation
- F4 — shield on/off
- P — toggle base / 3DGen player model
- O — atmosphere workshop in the procedural campaign

### Animation browser

- PageUp / PageDown — select UAL2 combat clip
- Enter — preview selected clip
- Preview is read-only: gameplay clips are deterministic and experimental
  assignments are no longer persisted in `user://`.

## Goal

Validate that authored UAL2 sword/combat animations can produce large, readable arm/shoulder/torso movement while UAL1 locomotion continues on the legs.
