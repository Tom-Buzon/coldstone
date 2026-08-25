# PROJECT HOPLITE — V0.0.15 SUNO SFX

## Goal
Replace the temporary SFX pack with the user's `audio/sfxSuno/` sounds and extend movement feedback.

## Active Suno mapping

- sword / sword2 -> sword swings
- warriorJump -> jump / double-jump
- warriorDash -> dash
- warriorSlide -> slide
- enemyDead -> normal enemy and captain deaths
- bossDead -> final Warlord death

## Mix changes

- SFX default bus lowered from 42% to 34%.
- Existing saved V0.0.14 settings migrate once to at most 34% SFX.
- Enemy sword swings: -27 dB at point blank, falling toward -40 dB by ~9 m.
- Player sword swings remain deliberately louder than enemy swings.
- No old placeholder SFX are used as fallbacks.

## Movement audio

`player.gd` now emits a generic `movement_sfx_requested(kind)` signal for jump, dash and slide. Battle 01 listens to the signal and routes it through `HopliteCombatAudio`.

## Future sounds

Several future filenames are already wired. See `audio/sfxSuno/README_EXPECTED_FILES.md`.

## Runtime validation

Godot is not installed in the patch-generation environment, so engine parser/runtime validation could not be executed here.
