# V0.0.15 — Suno SFX folder

The combat audio system now reads user-authored SFX from:

`res://audio/sfxSuno/`

## Files already expected / active

- `sword.mp3` — player/enemy sword swing variation
- `sword2.mp3` — player/enemy sword swing variation
- `warriorJump.mp3` — Spartan jump and double-jump
- `warriorDash.mp3` — Spartan dash
- `warriorSlide.mp3` — Spartan slide
- `enemyDead.mp3` — regular enemy / captain death
- `bossDead.mp3` — final warlord death

## Future files already wired

Drop these exact filenames into the same folder later; no code change will be required:

- `fleshHit1.mp3`
- `fleshHit2.mp3`
- `fleshHit3.mp3`
- `enemyHurt1.mp3`
- `enemyHurt2.mp3`
- `enemyHurt3.mp3`
- `warriorHurt.mp3`
- `dismemberment.mp3`
- `decapitation.mp3`
- `spearThrust.mp3`
- `comboMilestone.mp3`
- `hitConfirm1.mp3`, `hitConfirm2.mp3` — petit clic UI de confirmation d'impact

Si ces deux fichiers manquent, un clic très discret est synthétisé en mémoire :
le hitmarker sonore reste donc fonctionnel sans ressource externe.

## Banque d'immersion physique — fichiers optionnels déjà branchés

Tous les fichiers ci-dessous sont facultatifs. Un fichier absent est ignoré et
la catégorie reste silencieuse ; le jeu ne plante pas.

### Mouvement réel de la lame

- `whooshLight1.mp3`, `whooshLight2.mp3`, `whooshLight3.mp3`
- `whooshHeavy1.mp3`, `whooshHeavy2.mp3`, `whooshHeavy3.mp3`
- `whooshSpiral1.mp3`, `whooshSpiral2.mp3`, `whooshSpiral3.mp3`

Le whoosh n'est plus déclenché au clic : il part quand la vitesse mesurée de la
vraie lame dépasse le seuil du profil. En attendant ces fichiers, `sword.mp3` et
`sword2.mp3` servent de fallback sûr.

### Impacts en couches

- Attaque commune : `impactTransient1.mp3`, `impactTransient2.mp3`, `impactTransient3.mp3`
- Chair/corps : `fleshBody1.mp3`, `fleshBody2.mp3`, `fleshBody3.mp3`
- Os : `boneCrack1.mp3`, `boneCrack2.mp3`
- Métal : `metalClang1.mp3`, `metalClang2.mp3`, `metalClang3.mp3`
- Résonance métal : `metalResonance1.mp3`, `metalResonance2.mp3`
- Poids du bouclier : `shieldThump1.mp3`, `shieldThump2.mp3`
- Parade parfaite : `parry1.mp3`, `parry2.mp3`
- Charge Heavy maximale : `heavyChargeMax.mp3`
- Bois : `woodImpact1.mp3`, `woodImpact2.mp3`
- Pierre : `stoneImpact1.mp3`, `stoneImpact2.mp3`

Priorité de production conseillée : whooshes, impact transient, flesh body,
metal clang, shield thump, puis résonances/os/parade/environnement.

The old `audio/sfx/` placeholder pack is no longer referenced by combat_audio.gd.
