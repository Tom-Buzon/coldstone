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
- Shift — dash / roll
- F3 — cycle sword orientation
- F4 — shield on/off

### Animation browser

- PageUp / PageDown — select UAL2 combat clip
- Enter — preview selected clip
- 1 — assign current clip to Light 1
- 2 — assign current clip to Light 2
- 3 — assign current clip to Light 3
- 4 — assign current clip to Heavy
- 5 — assign current clip to 360

Assignments are saved to `user://hoplite_ual_slots.cfg`.

## Goal

Validate that authored UAL2 sword/combat animations can produce large, readable arm/shoulder/torso movement while UAL1 locomotion continues on the legs.
