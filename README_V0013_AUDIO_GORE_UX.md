# PROJECT HOPLITE — V0.0.13 Audio + Gore UX

This patch is built on top of V0.0.12 Crowd Performance.

## Audio folders

```text
audio/
├── sfx/
└── track/
```

`audio/track/` is treated as a playlist directory. Add future `.mp3`, `.ogg` or `.wav` tracks there and the battle audio controller will automatically discover them. The first supplied track is:

- `audio/track/carnage_arena.mp3`

The music controller plays one track and automatically selects another when it finishes. With only one track it simply starts it again.

## SFX

The patch works immediately offline using small procedural fallback WAVs bundled in `audio/sfx/`.

Included categories:

- sword swing variants
- flesh hit variants
- gore splats
- decapitation
- enemy death
- player hurt
- combo tick
- kill confirmation

`SETUP_AUDIO.bat` is optional. It replaces the fallback files with a hand-picked CC0 set from Spring Spring's **Various Sound Effects** pack on OpenGameArt. See `audio/sfx/SOURCES.md`.

## Combat audio behavior

- player sword attacks trigger swing SFX
- nearby enemy attacks trigger quieter swing SFX
- localized hits trigger flesh impact SFX
- severed limbs trigger gore SFX
- head sever triggers a dedicated decapitation layer
- kills trigger death + confirmation layers
- player damage triggers a hurt impact
- small pitch variation prevents repeated hits from sounding identical
- short per-category throttles stop a 24-enemy crowd from producing an unusable wall of duplicate sounds in the same frame

## G — Gore HUD

The gore HUD is OFF by default and completely independent from `I` diagnostics.

Press `G` to show/hide:

- central hit marker
- damage + anatomy-zone hit readout
- hit combo counter
- escalating combo grade: HIT / VIOLENT / BRUTAL / SAVAGE / CARNAGE / BLOODSTORM
- recent combat feed
- DISMEMBERMENT callout
- DECAPITATION callout
- KILL / CAPTAIN DOWN / WARLORD SLAIN callouts
- damage-taken entries

The combo window is currently 2.35 seconds between successful localized hits.

## Debug separation

- `I` = technical diagnostics / anatomy / blade sweep / FPS
- `G` = player-facing gore/combo feedback

The normal HUD still contains only the Spartan health bar when both are disabled.
