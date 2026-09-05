# Spartan Animation Workbench

Ce dossier relie l'inventaire réel de Spartan, Blender et le runtime actuel,
sans obliger à migrer tous les ennemis en une seule fois.

## Les trois commandes

Depuis la racine du projet :

1. `ANIMATIONS_1_REGENERER_MANIFESTE.bat` rescane les personnages 3DGen, les
   actions demandées par leurs profils et tous les packs installés.
2. `ANIMATIONS_2_OUVRIR_BLENDER.bat` refait d'abord ce scan, puis ouvre Blender.
   Le panneau est dans la vue 3D : touche `N`, onglet **Spartan Anim**.
3. `ANIMATIONS_3_PUBLIER_JEU.bat` rescane et valide chaque affectation avant de
   mettre à jour le fichier lu par le jeu. Une erreur conserve la dernière
   publication valide.

## Ajouter un pack

Déposer un `.fbx`, `.glb`, `.gltf` ou `.blend` sous :

`assets/animations/source_packs/<nom_du_pack>/`

Ce dossier est rescanné à chaque lancement. Une nouvelle source y est considérée
Mixamo-compatible par défaut. Les anciens emplacements UAL1, UAL2, Mixamo et la
bibliothèque Spartan restent également inventoriés pendant la migration.

## Travail dans Blender

- Le panneau **Runtime Monitoring** est la vue de contrôle globale. Il montre,
  pour chaque personnage et famille d'arme, le fichier et le clip réellement
  lus par Godot. Il peut être filtré par personnage, arme, état, provenance ou
  texte. Le bouton **Ouvrir dans l'éditeur** rejoint directement l'affectation.
- Le code couleur distingue le bake partagé, UAL1, UAL2, Mixamo, les packs
  personnalisés, les fallbacks, les actions futures et les déclarations
  inaccessibles. Une modification locale est marquée **NON PUBLIÉE** jusqu'à
  l'exécution de `ANIMATIONS_3_PUBLIER_JEU.bat`.
- La liste des personnages commence par **RIG COMMUN (UAL)** puis par un profil
  virtuel pour chaque famille d'arme. Les vrais personnages suivent ensuite.
- La sélection détermine automatiquement la portée de l'affectation : il n'y a
  plus de menu de portée ambigu à modifier.
- Par défaut, la liste d'édition masque les actions futures ou inaccessibles.
  L'option dédiée permet de les réafficher pour préparer EnemyV2.
- Sélectionner une action choisit automatiquement son clip actuel dans l'étape
  3. La lecture automatique ne démarre que si Blender peut reproduire fidèlement
  le runtime. Pour une animation composée (par exemple le bake partagé hoplite
  plus couche haute), le donneur brut reste prévisualisable manuellement mais
  est explicitement signalé comme approximation.
- Pour essayer une autre source, sélectionner simplement un autre clip puis
  utiliser **Prévisualiser** ou **Assigner ce clip**.
- **Assigner ce clip** enregistre le choix dans
  `data/workbench_overrides.json`. Une sauvegarde JSON datée est également
  conservée sous `data/backups/`.
- **Éditer la preview actuelle** crée une copie indépendante, enlève les pistes
  de doigts et sauvegarde immédiatement un projet `.blend` éditable.
- Le diagnostic indique si la source contient réellement des frames immobiles
  au début. **Retirer la pause initiale** ne modifie que la copie éditable ; si
  aucune pause n'est détectée, le freeze doit plutôt être recherché dans le
  blend ou le correctif runtime.
- **Créer une animation vide** reste disponible pour une animation neuve.
- **Sauvegarder le travail** écrit sous `tools/animation_workbench/projects/`.
  **Reprendre le travail sauvegardé** recharge ce `.blend` dans le Workbench.
  Une autosauvegarde est effectuée toutes les 60 secondes et avant de changer
  d'action ou de personnage.
- **Exporter l'action créée** écrit un GLB et ses métadonnées sous
  `assets/animations/source_packs/custom/`, puis actualise automatiquement le
  JSON d'affectation. Il faut ensuite lancer la publication jeu.

La résolution est toujours déterministe : **personnage > famille d'arme > rig
commun**. Une affectation plus précise remplace la valeur générale uniquement
pour ses cibles ; elle ne détruit pas l'affectation inférieure.

Les affectations correspondant à une clé du runtime actuel sont utilisables
immédiatement après publication. Les rotations, départs, arrêts et autres actions
du futur contrat EnemyV2 sont conservés dans `publish_report.json` comme
`pending_bake` : elles ne remplacent pas silencieusement une animation actuelle.

## Fichiers produits

- `data/animation_workbench_manifest.json` : inventaire généré, à ne pas éditer.
- `data/workbench_overrides.json` : décisions éditables depuis Blender.
- `data/backups/` : sauvegardes datées du JSON d'affectation.
- `data/publish_report.json` : résultat et erreurs de la dernière publication.
- `projects/` : sources `.blend` permettant de reprendre une animation.
- `assets/animations/generated/runtime_bindings.json` : données validées lues
  par le système d'animation transitoire du jeu.

Les portées partagées sont développées en listes explicites lors de la
publication : un pack d'arme n'affecte que sa famille, le rig commun fournit le
fallback de tous les profils 3DGen, puis les exceptions par personnage gagnent
en dernier.

Le manifeste recharge aussi la dernière publication
`runtime_bindings.json`. Ainsi, le monitoring affiche la valeur effectivement
résolue par `ExternalAnimationBank`, pas seulement la proposition présente dans
le fichier d'édition Blender.
