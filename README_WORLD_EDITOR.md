# Forge de mondes Hoplite

Le laboratoire reste la scene principale. Un portail **Forge de mondes** permet d'entrer dans `world_editor.tscn` comme dans un niveau.

## Ce que l'on peut poser et parametrer

- terrains sculptables et redimensionnables par chapitre, avec maillage `ArrayMesh`, collision `HeightMapShape3D`, generation reproductible `FastNoiseLite`, peinture locale multi-materiaux et vegetation `MultiMesh` ;
- sols, murs et blocs, avec dimensions et materiaux de la bibliotheque PBR ;
- tous les modeles GLB/GLTF trouves dans les huit dossiers de la bibliotheque automatique ;
- lumieres omni/spot, couleur, intensite, portee et ombres ;
- troupes ennemies posees comme un bloc de spawn, avec archetype, effectif, taille, rang normal/miniboss et huit formations (ligne, colonne, carre, cercle, coin, phalange, arc et dispersee). Trois unites **Geant — novice / standard / veteran** sont disponibles directement dans la categorie Personnages, a taille 1 par defaut et avec des kits Mutant distincts. Leur traversal est actif par defaut en mode **Assiste** : l'anatomie reste exacte pour les coups et la decapitation, un cylindre lisse et reglable stabilise le wallrun du sol jusqu'aux epaules, puis une enveloppe convexe extraite du vrai mesh de tete suit le crane. Un appui optionnel peut stabiliser le joueur exactement au sommet de cette tete. Le mode **Exact** conserve tous les volumes convexes animes du modele pour diagnostic ;
- preset `PHALANGE 15` compose de 11 lanciers hoplites et 4 lanciers veterans places sur les flancs des deux premieres lignes ;
- comportements normal, attente, patrouille ou protection d'un objet/groupe ;
- routes de patrouille tracees directement sur la carte et cibles a proteger choisies par un clic dans la scene ;
- depart joueur, narration, zones d'atmosphere et declencheurs d'evenements ;
- portes animees en bois, fer, pierre ou bronze, avec ouverture verticale, coulissante a gauche/droite ou pivotante comme une vraie porte ;
- chapitres separes et passages de teleportation vers un point d'arrivee nomme.

## Mode Terrain

La categorie **Terrain — Creer & sculpter** ajoute un heightfield natif a un chapitre. Cinq bases sont fournies : plaine, collines, cretes, vallee et cote. Elles utilisent un seed sauvegarde dans le monde, donc un meme seed avec les memes parametres redonne exactement le meme relief. Dans **Proprietes**, `Largeur X` et `Profondeur Z` permettent maintenant de choisir une taille de 8 a 512 metres sans modifier l'echelle verticale. La resolution reste independante : elle controle la finesse du relief, pas sa taille.

Le terrain visible et sa collision sont reconstruits depuis le meme tableau de hauteurs : il n'existe pas de decalage entre le sol affiche dans la Forge et le sol utilise par le joueur, l'IA ou les objets en mode test. Les outils sont :

- **Monter** pour elever le relief ;
- **Creuser** pour l'abaisser ;
- **Lisser** pour supprimer les cassures et rendre une pente praticable ;
- **Aplanir** pour rapprocher la zone de la hauteur du premier clic ;
- `Maj` pendant Monter ou Creuser pour inverser temporairement l'operation.

Le rayon et la force du pinceau sont reglables dans la bibliotheque et dans le dock Proprietes. Un clic-glisse complet cree une seule entree d'historique : `Ctrl+Z` annule donc le trait entier. Changer la resolution reechantillonne le relief, la peinture et la vegetation existants au lieu de les effacer.

### Peinture locale des textures

Selectionnez le terrain, ouvrez **Textures & materiaux**, puis choisissez une texture. La Forge active automatiquement **Peindre la texture** : le clic-glisse melange cette texture uniquement sous le pinceau. **Retrouver la base** efface progressivement les couches locales. Un terrain conserve une texture de base et jusqu'a trois couches locales simultanees ; si une quatrieme nouvelle texture est utilisee, la couche globale la moins employee est recyclee.

La nouvelle texture `mediterranean_grass` est un sol herbeux olive et sec genere pour l'ambiance mediterraneenne du jeu. Elle est distincte de l'atlas transparent utilise par les meshes d'herbe.

### Vegetation MultiMesh

**Peindre l'herbe** et **Retirer l'herbe** modifient une carte de densite locale. Les brins courts, herbes hautes, trefles et fougeres sont distribues de facon reproductible avec le seed de vegetation et regroupes en quelques `MultiMeshInstance3D`. Ils n'ont volontairement ni collision ni ombre individuelle. Le preset et la quantite sont reglables dans **Proprietes > Vegetation MultiMesh** ; `none` desactive totalement la vegetation.

Les meshes proviennent d'une selection du *Stylized Nature MegaKit [Standard]* de Quaternius, dont la licence incluse est CC0 1.0. Le projet conserve le texte de licence dans `assets/environment/stylized_nature/LICENSE_Quaternius_CC0.txt`.

![Apercu du melange local et de la vegetation MultiMesh](docs/world_editor/terrain_layers_preview.png)

Les resolutions 17, 33, 65 et 129 correspondent respectivement a 16, 32, 64 et 128 metres, car `HeightMapShape3D` espace nativement les points d'un metre. Le reglage 65 x 65 est recommande pour l'edition courante. Une resolution plus elevee augmente la taille du JSON et le cout de reconstruction.

Un heightfield ne peut pas representer une grotte, un surplomb ou deux hauteurs au meme X/Z. Pour ces formes, combiner le terrain avec les Surfaces et les Objets 3D. Les surfaces restent aussi adaptees aux sols architecturaux parfaitement plans, murs, escaliers provisoires et blocs.

La categorie **Textures & materiaux** affiche les textures sources sous forme de vignettes. Sur une surface, choisir une texture l'applique a la selection et au pinceau ; sur un terrain, ce choix equipe le pinceau de peinture locale. La texture de base du terrain reste modifiable dans son inspecteur. Les objets et les surfaces peuvent etre places directement sur le relief, et l'aimantation verticale reconnait egalement la hauteur du terrain.

L'espacement et la distance d'activation sont calcules automatiquement depuis le profil du personnage. Une troupe peut apparaitre au lancement, lorsque le joueur traverse un declencheur choisi sur la carte, apres la mort d'une autre troupe ou apres un timer.

Chaque troupe possede aussi un mode de deploiement :

- `Toute la troupe d'un coup` conserve le fonctionnement classique ;
- `Vagues periodiques` envoie X soldats toutes les X secondes, jusqu'au total maximum, jusqu'a l'evenement d'arret selectionne, ou jusqu'a la premiere mort d'une unite d'une troupe choisie (la troupe de vagues elle-meme peut etre choisie) ;
- `Reserve progressive` separe le total theorique, l'effectif initial, le seuil actif et la taille du lot de renfort. Par exemple 30 / 10 / 7 / 3 affiche 10 soldats, puis en ajoute 3 des qu'il en reste moins de 7, sans jamais depasser 30 soldats deployes au total.

Les mondes de la Forge chargent le meme directeur tactique que le stand de tir. Un lancier hoplite isole passe automatiquement en duel et engage le joueur lorsqu'il entre dans sa distance d'agression, tandis que plusieurs lanciers se structurent en phalange.

Le template **Declencheur** est une hitbox vide, visible uniquement dans la Forge. Il peut rester sans action et servir de zone nommee a un spawn, ou appliquer directement un effet : ouvrir une porte choisie sur la carte, generer/retirer une troupe, retirer tous les ennemis, afficher un message narratif, changer la musique ou appliquer une atmosphere. Les conditions d'event couvrent aussi la mort totale d'un groupe et un pourcentage de pertes. Les templates omni et projecteur se trouvent dans la categorie **Lumieres**.

Une condition de mort est un **evenement global** : la position et la taille de sa box sont ignorees, et le joueur n'a pas besoin de la traverser. Pour afficher un texte, choisir l'action `Afficher une narration`, puis `Message ecrit ici`. Le template `Texte reutilisable` ne se declenche jamais seul ; il sert de contenu partage et doit etre relie depuis cette meme action en choisissant `Element de narration reutilisable`.

## Utilisation

- l'edition est unifiee : surfaces, objets, personnages et elements logiques se selectionnent et se modifient directement, sans mode intermediaire. `Tab` alterne simplement entre les onglets Bibliotheque et Scene ;
- dans **Terrain**, creer ou selectionner le terrain du chapitre, choisir Monter, Creuser, Lisser ou Aplanir, puis maintenir le clic gauche dans la vue. `Maj` inverse Monter/Creuser ;
- **Selection (1)** choisit un element. Une surface selectionnee expose six poignees : rouge pour X, verte pour la hauteur et bleue pour Z. Un decor expose une seule poignee doree : elle change uniquement son echelle globale afin de toujours conserver ses proportions ;
- en mode Selection, `Ctrl + clic-glisse` deplace directement l'objet ou la surface sur le plan horizontal. `Maj + clic-glisse` le suit verticalement sans crans. Le sol attire progressivement le point bas de l'element avant le contact, devient vert a l'alignement, puis retrouve sa couleur au relachement ;
- avec un element selectionne, `R` lance sa rotation horizontale autour de Y et `Maj+R` son inclinaison verticale autour de l'axe local X. Bouger la souris regle l'angle, maintenir `Ctrl` l'aimante par pas de 15 degres, clic gauche ou Entree valide, clic droit ou Echap annule. Un anneau et un bandeau nomment toujours l'axe actif ;
- la zone de selection des decors est calculee sur leur geometrie visible et placee autour du modele, et non sous celui-ci. Les objets nouvellement poses sont ancres sur le dessus du sol vise ;
- **Pinceau (2)** : choisir une forme, une texture, un objet ou un personnage dans la bibliotheque, puis cliquer dans la vue. Garder le clic gauche enfonce peint en continu. Maintenir `Maj` pendant le trace force une ligne droite ;
- dans **Personnages**, choisir `TROUPE ENNEMIE`, la poser comme n'importe quel objet, puis la selectionner. L'inspecteur adapte immediatement ses commandes au comportement : `Tracer / completer la patrouille` ajoute les points dans l'ordre par clics au sol ; `Choisir l'objet ou la troupe` capture directement la cible a proteger ;
- dans **Condition de spawn**, les boutons Carte capturent un declencheur ou une troupe sans saisir d'identifiant. La zone cliquable couvre toute la formation. Pour une condition de mort, le nom resolu et la reference enregistree sont affiches sous le champ ; ce champ accepte aussi manuellement le nom visible, l'ID du groupe ou l'identifiant interne. Entree, clic droit ou Echap termine/annule une capture ;
- la categorie **Surfaces** contient un constructeur personnalise : choisir Sol, Mur ou Bloc, regler directement X/Y/Z, puis equiper ce pinceau. Les formats 4x4, 4x3 et 2x2x2 restent disponibles comme prereglages ;
- la categorie **Portes & chapitres** propose les quatre styles de porte et les cinq mouvements. Dans un declencheur, choisir l'action `Ouvrir une porte`, puis cliquer directement la porte cible sur la carte ;
- la barre **Chapitre** ouvre un chapitre sans melanger ses objets aux autres et le bouton `+` en cree un vide. Poser un `Point d'arrivee`, lui donner un identifiant, puis poser un `Passage de chapitre` qui vise ce chapitre et cet identifiant ;
- **Taille de la carte** etend la grille de 120 x 120 jusqu'a 1000 x 1000 metres. Les chapitres permettent de construire au-dela sans garder tout le monde en memoire en meme temps ;
- **Gomme (3)** : l'element survole devient rouge et un clic le retire. `Ctrl+Z` reste disponible en cas d'erreur ;
- le pas de grille est reglable entre 0,5 m et 4 m. Placements et redimensionnements y sont aimantes ;
- clic droit + souris : orbiter librement jusque sous l'horizon ; molette : zoom et dezoom etendus ; clic milieu : deplacer la vue ; `F` cadre la selection ;
- ZQSD/WASD : deplacer le centre de la vue ; Suppr : supprimer ; Ctrl+D : dupliquer ;
- `G` ou **Edit fantome** : passe en vue subjective volante sans quitter l'edition. ZQSD/WASD avance et strafe, Espace/E monte, C descend, Maj accelere et le clic droit oriente la vue. La selection, le pinceau, la gomme et l'inspecteur restent utilisables ;
- Ctrl+Z / Ctrl+Y : annuler / retablir ; Ctrl+S : sauvegarder ;
- F6 ou **Tester** : reconstruit tout le chapitre actif et lance le vrai joueur, la vraie IA et les evenements. La selection et la camera ne filtrent jamais les rencontres. Les troupes configurees `Au lancement` apparaissent immediatement ; les conditions zone, mort de groupe et timer restent differees. Echap revient a l'edition.

Les mondes sont sauvegardes dans `user://hoplite_worlds/*.hoplite.json` par remplacement securise, avec l'ancienne version conservee en `.bak`. Chaque sauvegarde cree automatiquement un portail nomme a cote de celui de la Forge dans le laboratoire. Entrer dans ce portail lance le premier chapitre avec le vrai joueur, la vraie IA et les events ; Echap ramene au laboratoire. Lorsqu'un passage change de chapitre, l'ancien runtime est entierement detruit (joueur, ennemis, collisions, timers, Tweens, directeur tactique et events), deux images sont laissees au moteur pour liberer les ressources, puis seul le chapitre de destination est reconstruit. Le compteur en bas additionne aussi les groupes generes plus tard par evenement et avertit a partir de 300 ennemis par chapitre par defaut.

L'interface reprend maintenant l'organisation d'un logiciel 3D professionnel : barre d'application et de commandes, palette d'outils verticale permanente, navigateur de **Contenu** avec les onglets **Bibliotheque** et **Scene**, dock **Proprietes**, indicateur de vue et barre d'etat. Les boutons `CONTENU` et `PROPRIETES` de la barre superieure, ainsi que les croix des docks, permettent de masquer ou de rouvrir independamment les deux panneaux pour liberer la vue 3D.

Le bouton **AIDE** ou `F1` ouvre un centre de documentation integre organise comme un wiki. Il contient une recherche plein texte, un parcours guide en sept etapes, des articles sur chaque famille de fonctionnalites et une reference des commandes. La page **Raccourcis personnalisables** permet de remplacer les touches principales et secondaires, bloque les conflits et repercute immediatement les nouveaux libelles dans l'interface. Les preferences sont sauvegardees dans `user://hoplite_worlds/editor_shortcuts.json` et peuvent etre reinitialisees individuellement ou globalement.

## Format

Le document JSON est versionne (`version: 4`) et separe les chapitres, les entites, leurs transformations et leurs proprietes. Les hauteurs, dimensions, poids de materiaux et densite de vegetation des terrains sont conserves dans les proprietes de l'entite `terrain`, ce qui les rend compatibles avec sauvegarde, chargement, duplication et historique. Les anciens mondes sont normalises automatiquement. Les fichiers principaux sont :

- `scripts/world_editor/world_document.gd` : schema, validation, sauvegarde et garde-fous ;
- `scripts/world_editor/world_terrain.gd` : generation, maillage, collision, sculpture et echantillonnage du relief ;
- `scripts/world_editor/world_terrain_foliage.gd` : distribution deterministe et rendu MultiMesh de la vegetation ;
- `scripts/environment/terrain_layer_blend.gdshader` : melange triplanaire de la base et des trois couches peintes ;
- `scripts/world_editor/world_runtime.gd` : construction 3D du chapitre et apercu d'edition ;
- `scripts/world_editor/world_event_runtime.gd` : conditions et actions d'evenements ;
- `scripts/world_editor/world_editor_grid.gd` : grille 3D et axes Blender ;
- `scripts/world_editor/world_editor.gd` : interface, inspecteur, selection et historique.

Validation headless du terrain :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script tools/world_terrain_probe.gd
```
