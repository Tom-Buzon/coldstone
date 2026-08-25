# PROJECT HOPLITE — V0.0.14 Audio Mix / Settings / Gore HUD Polish

## What changed

### 1. Quieter combat mix
- Master default: 82%
- Music default: 64%
- SFX default: 42%
- Player swings reduced slightly.
- Enemy swings reduced heavily and now attenuate by distance using a cheap non-3D mix.
- Hits, gore, kills, combo ticks and player hurt were rebalanced downward.
- Audio settings are saved to `user://hoplite_audio.cfg`.

### 2. ² settings menu
Press the French AZERTY `²` key to open/close Settings.
The menu pauses the battlefield while remaining interactive.

Controls:
- Track selector: immediately switches the background track.
- Master volume.
- Music volume.
- SFX volume.
- Close button or `²` again.

The track selector is populated dynamically from `res://audio/track/`, so future `.mp3`, `.ogg` and `.wav` tracks are automatically listed after Godot imports them.

### 3. Gore HUD visual pass
`G` still toggles Gore HUD independently from `I` diagnostics.

Changes:
- Combo/grade moved to top-center.
- Hit feedback moved under the combo at top-center.
- Removed combo background panel.
- `DECAPITATION` / `DISMEMBERMENT` are now huge center-screen callouts.
- Boss/captain kill callouts also use larger typography.
- Combat history remains bottom-right, but smaller and without any background panel.

## Files changed / added
- `scripts/audio/combat_audio.gd`
- `scripts/ui/audio_settings.gd` (new)
- `scripts/ui/gore_hud.gd`
- `scripts/battle/battle_01.gd`

The patch also keeps the V0.0.13 audio assets/scripts so it can be extracted directly over the project root.
