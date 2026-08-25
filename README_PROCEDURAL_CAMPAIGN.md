# Campagne procédurale — Dernier Hoplite

Le catalogue visuel, les échelles, collisions, LOD, textures et règles d'assemblage sont documentés dans [docs/environment_asset_catalog/README.md](docs/environment_asset_catalog/README.md).

La campagne est accessible depuis le second portail du laboratoire :
`DERNIER HOPLITE — CAMPAGNE PROCEDURALE`.

## Structure

- Acte I — prise des murailles : quatre légions typées de 10 unités, la dernière avec le Colosse.
- Acte II — prise de la ville : quatre légions typées de 10 unités, la dernière avec le Duelliste de l'agora.
- Acte III — prise du donjon : quatre légions échelonnées, la dernière avec NFullArmor.
- NFullArmor possède trois phases de combat, de nouveaux patterns, une barre dédiée et des renforts de phase.

Chaque campagne reçoit une graine affichée dans le HUD. Les positions des bâtiments,
accessoires, points d'apparition et compositions sont reproductibles à partir de cette graine.
Chaque acte choisit aussi l'une de trois macro-variantes clairement nommées dans le HUD :
disposition du siège, position de l'agora/quartiers et structure de la crypte.
Deux légions complètes sont préchargées sous l'écran de chargement : la carte n'apparaît jamais
vide. Dès que l'une tombe à trois survivants, une troisième légion arrive progressivement, deux
unités toutes les 0,32 s. Dans le donjon, ce seuil déclenche aussi une ruée de 20 sbires depuis les
deux côtés de l'entrée : une paire par seconde pendant 10 secondes. Lorsque la troisième légion
est à son tour décimée, une quatrième légion entre avec le
miniboss ou NFullArmor. Chaque type reçoit une formation et un point distinct, adapté à sa portée,
éloigné du joueur et si possible hors caméra. La mort de l'élite termine immédiatement l'acte ;
les survivants sont retirés sans obliger le joueur à les rechercher.

Les miniboss et NFullArmor entrent par une courte chute animée accompagnée d'un sceau lumineux.
Le donjon dispose de douze torches murales en plus des braseros, et le magistrat regarde désormais
vers la nef et le joueur.

Les quatre limites de chaque terrain possèdent une barrière physique invisible. Le directeur
de foule replace aussi automatiquement un adversaire tombé sous le sol ou sorti des limites,
et retire du compteur toute instance supprimée anormalement afin de ne jamais bloquer le chargement suivant.

Le mode de test est actuellement immortel : à 0 PV, la vie est restaurée et 2,5 secondes
d'invulnérabilité permettent de repartir. Le HUD affiche explicitement `MODE TEST IMMORTEL`.
Le joueur apparaît au-dessus d'un sol physique déjà synchronisé. Une surveillance de sécurité
le replace également au point d'entrée s'il passe sous la carte ou sort des limites jouables.

## Contrôles de mise au point

- `O` — ouvre l'atelier d'atmosphère et met le combat en pause. Les curseurs contrôlent soleil,
  hauteur solaire, ambiance, exposition, braseros, scintillement, fumée et brouillard.
- Trois presets de direction artistique sont inclus : **Champ de bataille** (`#FFB46A` / `#52647A`),
  **Forteresse** (`#D79557` / `#39465A`) et **Donjon du boss** (`#C94B32` / `#202737`).
- La base visuelle des trois actes utilise une ambiance bleutée faible, un soleil orangé bas,
  le tonemapping ACES et un brouillard ocre léger.
- `P` — remplace le mannequin par `perso-1787423482233.glb`; un second appui restaure le modèle
  UAL d'origine. Le rig, les animations de combat, l'épée et le bouclier restent actifs.

## Fichiers principaux

- `procedural_campaign.tscn` — scène du mode.
- `scripts/campaign/procedural_campaign.gd` — progression, HUD, transitions et feedback.
- `scripts/campaign/procedural_map_generator.gd` — génération des trois familles de cartes.
- `scripts/campaign/procedural_wave_director.gd` — vagues, budgets de foule, miniboss et boss.
- `scripts/campaign/campaign_loading_screen.gd` — chargement inter-actes.
- `scripts/campaign/atmosphere_control_panel.gd` — atelier d'atmosphère et presets.
- `scripts/campaign/campaign_brazier_light.gd` — lumière vacillante des braseros.
- `tools/procedural_campaign_probe.gd` — validation headless des cartes, vagues et phases.
- `tools/player_visual_toggle_probe.gd` — validation base → 3DGen → base.
- `tools/environment_catalog_check.gd` — détection des nouveaux assets/textures non catalogués.

## Réglages rapides

- Taille des vagues et compositions : `_plan_for_zone()` dans le directeur de vagues.
- Plafond de foule : `MAX_CONCURRENT` dans le directeur de vagues.
- Variations de cartes : fonctions `_generate_walls()`, `_generate_city()` et `_generate_dungeon()`.
- Phases de NFullArmor : profil `nfull_armor` dans `scripts/enemy/enemy_archetypes.gd`.

Test automatisé :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/procedural_campaign_probe.gd
```
