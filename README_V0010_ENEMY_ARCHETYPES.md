# PROJECT HOPLITE — V0.0.10 Enemy Archetypes

This patch turns the five live Athenian guards into a mixed squad while keeping one shared anatomy/dismemberment/AI controller.

## Archetypes

- SWORDSMAN — blue, baseline aggressive fighter, sword + shield.
- GUARDIAN — cyan/blue, 105% scale, more HP, larger shield, slower and more committed to the captain/intercept line.
- SPEARMAN — green, 103% scale, procedural dory spear + shield, keeps a longer combat band and backs away when crowded.
- FLANKER — purple, 96% scale, low HP, fast, no shield, tries to reach a lateral position around the Spartan before attacking.
- BRUTE — orange/red, 112% scale, high HP, slow, no shield, heavy attacks only.
- CAPTAIN — yellow, 120% scale, high HP/damage, mixed heavy attacks, remains the squad leader/miniboss.

## Weapons

The sword remains the existing procedural proxy. A lightweight procedural spear proxy has been added so reach/spacing can be validated immediately without new external assets.

Weapon visuals are deliberately separated from archetype behavior. Later a real imported sword/spear/javelin/bow scene can replace the proxy without rewriting anatomy or AI.

## Squad rule preserved

Any AI close enough to a living captain still prioritizes defending him. Archetype behavior changes how it defends (hold line, reach spacing, flank, brute pressure), not whether the captain-defense rule exists.

## Injury system preserved

- one leg lost -> slow/limp
- both legs lost -> crawl
- right arm lost -> weapon drops and attacks are disabled
- left arm lost -> shield drops when present
- death -> Death01 path from V0.0.8+

## Debug

Normal HUD stays clean. Press I for the full lab overlay. Enemy labels now include archetype, weapon and behavior.
