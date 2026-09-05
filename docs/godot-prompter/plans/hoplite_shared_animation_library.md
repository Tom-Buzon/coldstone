# Bibliotheque d'animations partagee des hoplites

> Retour d'experience et procedure de migration pour les autres personnages :
> `docs/enemy_refactor/ANIMATION_LIBRARY_MIGRATION_GUIDE.md`.

## Perimetre

Cette migration concerne uniquement les archetypes `ngeneral` (hoplite standard) et
`ngeneral_veteran`. Les autres ennemis et le joueur conservent temporairement leur
pipeline de donneurs actuel.

## Decision d'architecture

Le squelette du modele
`res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb` est le rig canonique.
Les clips UAL1 de locomotion et les actions UAL2 compatibles sont convertis une
seule fois vers les pistes de ce rig, puis sauvegardes dans une
`AnimationLibrary` partagee. Le bake hors ligne des actions Mixamo a ete ecarte :
le `RetargetModifier3D` natif n'etait pas evalue de facon fiable pendant
l'echantillonnage et produisait visuellement une pose en T.

Deux approches ont ete ecartees :

- un cache statique de scenes donneuses reduirait les chargements, mais conserverait
  des squelettes caches et le retargeting par `SkeletonModifier3D` a chaque image ;
- une bibliotheque aux noms de bones UAL generiques exigerait encore un retargeting
  par instance, ce qui ne supprime pas le cout structurel vise.

La bibliotheque canonique est en lecture seule et partagee. Chaque hoplite possede
son propre `AnimationPlayer`, son propre `AnimationTree` et ses propres temps de
lecture. Les animations d'attaque/garde sont superposees dans l'arbre local afin de
conserver le haut du corps sans donneur ni pont de pose.

```text
Hoplite (CharacterBody3D)
└── VisualRoot
    └── ngeneral visible
        ├── Skeleton3D canonique
        └── AnimationPlayer local
            └── hoplite_animation_library_v3.res (partagee, lecture seule)
└── HopliteAnimationDriver
    └── AnimationTree local (locomotion + combat/garde)
```

## Flux de donnees

1. Le generateur charge le rig canonique et les sources UAL compatibles hors jeu.
2. Il convertit les rotations dans l'espace de repos `ngeneral`, retire les pistes
   de translation/echelle des bones et sauvegarde les clips nommes.
3. Au spawn d'un hoplite, le pilote attache la bibliotheque au lecteur local et
   construit son `AnimationTree` local.
4. L'IA pilote la locomotion, les attaques et la garde comme avant ; seuls la source
   des clips et le mecanisme de superposition changent.

## Refonte phalange complete

- [x] **Auditer les rigs et pistes source/cible.**
  Skills : `using-godot-prompter`, `godot-brainstorming`, `animation-system`,
  `assets-pipeline`.
- [x] **Ajouter le generateur deterministe de l'AnimationLibrary canonique.**
  Skills : `animation-system`, `assets-pipeline`, `resource-pattern`.
- [x] **Ajouter le lecteur sans donneurs et router seulement les deux hoplites.**
  Skills : `animation-system`, `resource-pattern`.
- [x] **Retirer le wall-run des ennemis et dedupliquer les chemins FBX identiques.**
- [x] **Fusionner les dix zones corporelles en une surface skinned masquable.**
  Le shader encode les zones par couleur de sommet. La coupe masque une branche et
  conserve les gore caps et les fragments physiques. L'`ArrayMesh` fusionne est
  construit une fois, partage par toutes les unites et conserve les index LOD.
- [x] **Mettre en cache une affectation complete par cohorte et frame physique.**
- [x] **Endormir le suivi anatomique hors combat et reduire sa cadence active.**
- [x] **Couper plus tot les ombres des rangs secondaires et des extremites.**
- [x] **Caracteriser la parite : clips, instances independantes, absence de donneurs,
  validite des pistes et poses.**
  Skills : `godot-debugging`.
- [x] **Executer tous les probes, analyser les erreurs Godot et relire les changements.**
  Skills : `godot-debugging`, `godot-code-review`.

## Contrats de validation

- aucun descendant des hoplites ne porte un nom `Donor`, `UAL1` ou `UAL2` ;
- les deux archetypes disposent des clips de locomotion, thrust haut/bas, bash,
  garde et impact ;
- deux hoplites peuvent lire deux clips et deux positions temporelles differentes ;
- toutes les pistes de bone ciblent un bone existant du rig canonique ;
- l'evaluation physique de l'`AnimationTree` applique effectivement une pose non-T,
  y compris quand la boucle d'IA est dormante ; cette validation porte sur le mesh
  rendu sans equipement, et pas seulement sur les valeurs numeriques des bones ;
- les jambes continuent leur locomotion lorsqu'une action du haut du corps est
  superposee ;
- le corps vivant et chaque fragment detache gardent une seule surface corporelle ;
- quinze soldats d'une meme cohorte ne declenchent qu'une construction de formation
  par frame physique ;
- les hitboxes cessent de suivre les bones hors combat et se reveillent au contact ;
- les autres archetypes gardent leur comportement actuel.
