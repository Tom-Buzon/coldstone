# Blender — remplacer le rig d'un personnage par UAL1

Le workflow principal est prévu pour un personnage **déjà riggé et correctement
skinné**. Il conserve ses poids, les remappe vers les 53 os UAL1, puis supprime
l'ancienne armature.

Un second mode prend maintenant en charge un **modèle sans aucun rig**. Le
script crée un métarig Rigify Basic temporaire, le pré-ajuste en hauteur,
calcule des poids automatiques, puis l'utilise comme armature source avant de
le remplacer par UAL1.

Le script a été testé dans Blender 5.2 LTS avec un personnage Mixamo du projet.
Il importe le fichier Hoplite `assets/runtime/ual1/UAL1_Standard.glb`, soit le
rig UAL1 Standard et ses 46 animations.

La version actuelle peut aussi **personnaliser automatiquement les proportions
du squelette UAL1** : largeur d'épaules et de bassin, longueurs des bras,
avant-bras, jambes et phalanges. Les directions et le roll de la T-pose UAL
restent inchangés afin que les animations continuent d'utiliser les mêmes axes.

Pour le personnage `C:\Users\suean\Downloads\1_samus_aran_biker.glb`, le
script possède également un preset exact pour son armature `GLTF_created_0` de
197 os. Il conserve néanmoins les mappings génériques pour les autres modèles.

## Avant de commencer

1. Travaille sur une **copie** de ton fichier `.blend`.
2. Un personnage déjà riggé doit avoir exactement une armature active.
3. S'il n'a pas de rig, sélectionne **tous** ses meshes avant d'utiliser
   l'étape optionnelle Rigify : corps, vêtements, cheveux et pièces d'armure.
4. Les Shape Keys ne sont pas prises en charge pendant ce transfert. Si ton
   mesh en possède, duplique-le et crée une version sans Shape Keys.
5. Le script reconnaît automatiquement les rigs UAL1, Mixamo, Auto-Rig Pro et
   les principaux noms humanoïdes Unreal/génériques. Pour un rig maison très
   différent, il s'arrête avant toute suppression plutôt que de produire un
   mauvais résultat.
6. Les nombreux contrôleurs de visage, cheveux et os secondaires ne sont pas
   reproduits dans UAL1 : les contrôleurs sans poids sont ignorés et les poids
   secondaires rattachés à la tête sont fusionnés vers `DEF-head`.
7. Une A-pose d'origine n'empêche pas la mesure automatique des proportions.
   En revanche, le **mesh visible doit être mis en T-pose avant le transfert
   définitif**.

## Étape 1 — importer ton personnage

1. Ouvre Blender. Pour le preset Samus, pars toujours du fichier neuf
   `C:\Users\suean\Downloads\1_samus_aran_biker.glb`.
2. Fais `File > Import`, puis choisis le format de ton modèle (`glTF 2.0`,
   `FBX`, etc.).
3. Vérifie que le personnage apparaît. Une armature existante est facultative.
4. Si une animation se joue déjà, ce n'est pas grave : le script remet l'ancien
   rig dans sa pose de repos lors de la préparation.
5. Enregistre immédiatement une copie avec `File > Save As`.

## Étape 2 — charger le script

1. Passe dans l'espace de travail `Scripting` en haut de Blender.
2. Dans le `Text Editor`, clique sur `New`.
3. Ouvre le fichier `UAL1_AUTORIG_COPIER_DANS_BLENDER.py` avec un éditeur de
   texte, fais `Ctrl+A`, puis `Ctrl+C`.
4. Reviens dans Blender et colle tout avec `Ctrl+V`.
5. Clique sur `Run Script` ou appuie sur `Alt+P` lorsque la souris est dans le
   Text Editor.
6. Reviens dans la vue 3D, appuie sur `N`, puis ouvre l'onglet `UAL1 Rig`.

Si l'onglet n'apparaît pas, vérifie que toute la console Python a bien été
collée et que `Run Script` a été exécuté.

## Étape 3 — sélectionner correctement le personnage

Dans l'Outliner ou la vue 3D :

1. Pour un personnage déjà riggé, sélectionne au moins **un mesh skinné**. Le
   script retrouve automatiquement tous les meshes contrôlés par son armature.
2. Pour un personnage sans rig, sélectionne dès maintenant **tous ses meshes**.
   Sans armature commune, le script ne peut pas distinguer automatiquement les
   vêtements du décor.
3. Ne sélectionne pas le mannequin UAL1 — il n'est pas encore importé.
4. Tu peux sélectionner l'ancienne armature ou non : le script ne retient que
   les objets de type Mesh et retrouve leur armature via leurs modificateurs.
5. N'inclus pas le sol, les armes indépendantes ou le décor.

Astuce : sélectionne les meshes dans l'Outliner avec `Shift+Clic`. Chaque mesh
retenu doit avoir un modificateur `Armature` pointant vers le même ancien rig.

## Étape 0 optionnelle — préparer un modèle sans rig

Ignore entièrement cette section si ton personnage possède déjà une armature.

Dans `N > UAL1 Rig > 0 - Option : modèle sans rig` :

1. Sélectionne le corps et tous les vêtements qui doivent se déformer.
2. Clique sur `Créer Rigify Basic temporaire`.
3. Rigify est activé pour cette session et un métarig humain de 29 os est créé.
4. Le script ajuste automatiquement sa hauteur, son centre et son contact au
   sol. Il passe ensuite directement en `Edit Mode`.
5. En vue de face et de côté, place précisément les pivots du bassin, des
   épaules, des coudes, des poignets, des genoux et des chevilles dans le mesh.
   La symétrie X est activée.
6. Reviens en `Object Mode`, puis clique sur `Créer les poids automatiques`.
7. Teste tout de suite un bras et une jambe en `Pose Mode`. Si Blender n'a pas
   réussi son calcul Bone Heat, le script le détecte et crée automatiquement des
   poids de secours par proximité. Un avertissement jaune est alors normal :
   contrôle surtout les épaules, les aisselles et les hanches en `Weight Paint`.
8. Si une épée, une plaque ou un pan d'armure suit le mauvais membre, utilise la
   section `Accessoires qui suivent le mauvais os` décrite juste après.
9. Sélectionne ensuite un mesh du personnage et continue avec l'étape 4.

Le pré-ajustement automatique donne une proportion humaine de départ, mais il
ne peut pas déduire avec certitude les articulations à travers des vêtements ou
une silhouette stylisée. La vérification manuelle des pivots est donc
obligatoire avant de créer les poids.

Le Rigify **Basic** ne possède pas de phalanges : les mains sont correctement
attachées, mais les animations UAL des doigts ne déformeront pas chaque doigt.
Pour des doigts animés, il faudra un métarig Rigify Human complet et un placement
manuel de ses phalanges.

### Corriger une épée ou une plaque qui suit le bras

Sur un modèle sans rig, Blender ne possède aucune information sémantique sur les
accessoires. En pose A, une main peut être plus proche d'une épée de ceinture que
le bassin : un calcul automatique peut alors choisir le mauvais os même si les
deux surfaces ne se touchent pas.

1. Dans le panneau, clique sur `Corriger des pièces rigides`. Le rig revient en
   pose de repos et le personnage passe en `Edit Mode`.
2. Place la souris sur une pièce complète, par exemple une lame ou son fourreau,
   puis presse `L` pour sélectionner son îlot lié. Répète `L` sur les autres
   îlots visuels de cet accessoire : les sélections s'additionnent. Si `L`
   sélectionne une zone trop grande, annule et utilise une sélection manuelle en
   mode faces.
3. Dans `Attacher à`, choisis `Bassin / ceinture` pour une arme portée à la
   taille. Choisis plutôt l'avant-bras pour un brassard, la tête pour un casque,
   etc.
4. Clique sur `Attacher la sélection à cet os`.
5. Reviens en `Object Mode`, sélectionne le Rigify, passe en `Pose Mode` et
   reteste le bras.

Après ces corrections, ne relance pas `Créer les poids automatiques` : ce bouton
repart volontairement de zéro et effacerait les attachements corrigés.

Le bouton remplace uniquement les poids de rig des sommets sélectionnés par un
poids rigide de 100 %. Pour les épées et plaques métalliques, c'est préférable à
un dégradé de poids qui plierait ou déchirerait visuellement la pièce. Dans le
transfert final, `Bassin / ceinture` est correctement remappé vers `DEF-hips`.

## Étape 4 — importer le gabarit UAL1

Dans `N > UAL1 Rig` :

1. Vérifie le champ `Fichier UAL1`. Dans ce projet, il doit pointer vers :
   `assets/runtime/ual1/UAL1_Standard.glb`.
2. Laisse `Aligner automatiquement hauteur + sol` activé pour le premier essai.
3. Clique sur `1 - Importer le gabarit UAL1`.

Le script ajoute dans la même scène :

- le mannequin UAL1 bleu en filaire ;
- le futur rig `UAL1_Rig` avec 53 os ;
- les 46 actions du pack UAL1 ;
- un contrôle orange nommé `UAL1_PERSONNAGE_A_AJUSTER`.

À ce stade, **aucun poids n'est encore modifié et l'ancien rig n'est pas
supprimé**.

## Étape 5 — ajuster globalement taille, position et orientation

1. Clique sur `Sélectionner le contrôle orange`.
2. Utilise `S` pour redimensionner uniformément le personnage.
3. Utilise `G` pour le déplacer.
4. Utilise `R` pour corriger son orientation si nécessaire.
5. Utilise les vues orthographiques :
   - `Pavé numérique 1` : face ;
   - `Pavé numérique 3` : côté ;
   - `Pavé numérique 5` : perspective/orthographique.
6. À cette étape, cherche seulement une bonne hauteur, un sol commun et une
   orientation identique. Les épaules, coudes, poignets et doigts seront
   traités par le fitting des os à l'étape suivante.

Le bouton `Recaler hauteur + sol` refait automatiquement le centrage et
l'ajustement en hauteur. Utilise-le avant tes corrections manuelles, pas après.

Important : redimensionne le **contrôle orange**, pas chaque mesh séparément.
Le contrôle déplace ensemble le personnage, ses vêtements et son ancien rig.

## Étape 6 — adapter automatiquement les proportions UAL

Cette étape peut être faite alors que le personnage est encore en A-pose.

1. Clique sur `Adapter automatiquement UAL aux os`.
2. Le script identifie un pivot source pour chaque os UAL disponible.
3. Il mesure les distances épaule–coude, coude–poignet, hanche–genou,
   genou–cheville et les phalanges.
4. Il déplace les pivots principaux et change les longueurs UAL tout en gardant
   les directions de sa T-pose d'origine.
5. Le mannequin bleu est caché après l'opération, car ses proportions fixes ne
   représentent plus le squelette UAL personnalisé. Le rig UAL reste visible.

Avec le preset Samus, 52 des 53 os UAL sont ajustés automatiquement ; `root`
reste volontairement inchangé.

Avant l'export glTF, vérifie aussi qu'aucun objet ou mesh de la scène ne porte
déjà exactement le nom `root`. glTF impose des noms uniques et peut sinon
renommer l'os en `root_2`. Le jeu tolère désormais cet alias, mais conserver
`root` dans le fichier reste la sortie la plus propre.

Avec le Rigify Basic temporaire, 22 os UAL sont ajustés : tronc, tête,
épaules, bras, mains, jambes et pieds. Les 30 os de doigts UAL gardent leurs
proportions standard, puisqu'aucune phalange source n'existe dans ce métarig.

Pour corriger le résultat :

1. Clique sur `Finir UAL à la main`.
2. Blender passe en `Edit Mode` sur le rig UAL.
3. Déplace les pivots ou change les longueurs si nécessaire.
4. Évite de modifier la hiérarchie, les noms et l'orientation/roll des os : les
   actions UAL utilisent ces axes locaux.
5. Reviens en `Object Mode` avec `Tab`.

Le bouton `Rétablir UAL original` annule le fitting et remet exactement les
proportions importées. Tu peux aussi reposer l'ancien rig puis relancer le
fitting : le calcul repart toujours de la T-pose UAL originale, sans dérive.

## Étape 7 — faire correspondre le mesh à la T-pose personnalisée

Si ton personnage est déjà en T-pose comme le rig UAL, passe à l'étape 8.
`1_samus_aran_biker.glb` est en A-pose : ses bras doivent donc être levés avec
l'ancien rig.

S'il est en A-pose ou si ses articulations ne coïncident pas :

1. Clique sur `Poser l'ancien rig`.
2. Blender passe en `Pose Mode` sur l'ancienne armature.
3. Sélectionne les os des bras et tourne-les avec `R` pour placer le mesh dans
   la même T-pose que le squelette UAL personnalisé.
4. Corrige si nécessaire les jambes, les pieds, les mains et les doigts.
5. Observe le personnage, pas seulement les lignes des os : c'est la géométrie
   visible qui sera figée lors du transfert.
6. Reviens en `Object Mode` avec `Ctrl+Tab` quand la pose est correcte.

Ne modifie pas le rig UAL1 et ne renomme aucun os. Toute correction de pose se
fait sur **l'ancien rig**, car ses poids sont encore ceux du personnage.
Ne déplace surtout pas les sommets ou les faces en Edit Mode : cela séparerait
la nouvelle géométrie des pivots de l'ancien squelette.

Tu peux utiliser `Afficher / cacher le gabarit` si tu veux revoir le mannequin
standard, mais après le fitting ce sont les **os UAL personnalisés** qui font
foi, pas la silhouette bleue d'origine.

## Étape 8 — valider et remplacer le rig

1. Fais une dernière sauvegarde avec `File > Save As` sous un nouveau nom.
2. Vérifie encore la T-pose en vue de face et de côté.
3. Clique sur `5 - Transférer vers UAL1`.

Lors de cette validation, le script effectue dans cet ordre :

1. vérification du mapping des os critiques ;
2. application de la déformation actuelle pour figer la pose visible ;
3. conservation et fusion des poids existants vers les groupes `DEF-*` UAL1 ;
4. limitation à quatre influences par sommet et normalisation des poids ;
5. suppression réelle de l'objet et des données de l'ancienne armature ;
6. liaison de tous les meshes à `UAL1_Rig` ;
7. suppression du mannequin/gabarit temporaire.

Un transfert réussi affiche un état similaire à :

`TERMINE : ancien rig knight1 supprime, 53 os UAL1, 46 animations, 0 sommet(s) sans poids`

## Étape 9 — tester les animations

Dans la partie `6 - Tester les 46 animations` :

1. Choisis `Idle_Loop` dans `Action`.
2. Clique sur `Afficher l'animation`.
3. Clique sur `Lecture / pause` ou utilise la barre d'espace.
4. Teste ensuite au minimum :
   - `Walk_Loop` ;
   - `Jog_Fwd_Loop` ;
   - `Sword_Attack` ;
   - `Death01` ;
   - `A_TPose`.
5. Clique sur `Pose de repos` pour revenir à la pose de base.

Inspecte particulièrement les épaules, aisselles, coudes, poignets, hanches,
genoux, doigts et pans de vêtement. Les poids d'origine sont conservés, mais la
différence de proportions entre les deux squelettes peut nécessiter une petite
correction en `Weight Paint`.

## Dépannage

### « Rigify Basic Human est absent »

Ouvre `Edit > Preferences > Add-ons`, recherche `Rigify` et active-le. Blender
5.2 LTS le fournit normalement dans ses add-ons intégrés. Le script l'active
pour la session, mais n'enregistre pas automatiquement tes préférences.

### « Bone Heat Weighting: failed to find solution »

Les poids automatiques échouent parfois sur une géométrie non manifold, des
pièces qui se croisent ou de très petits accessoires séparés. La version actuelle
du script détecte aussi le cas trompeur où Blender renvoie `FINISHED` mais crée
des groupes entièrement vides. Elle complète alors uniquement les sommets sans
poids à partir des quatre os les plus proches. Le personnage devient posable,
mais ce secours géométrique reste une base : corrige au besoin les épaules,
aisselles et hanches en `Weight Paint`. Pour les accessoires rigides qui suivent
le mauvais membre, utilise plutôt l'outil d'attachement décrit ci-dessus.

Si le résultat est encore mauvais sur un vêtement complexe, essaie le corps
seul, puis transfère ses poids vers les vêtements avec Blender `Data Transfer`.

### Le mesh devient géant ou se couche après « Créer les poids »

Ce n'est pas normal. Une ancienne version du script perdait la conversion
d'axes ou d'unités stockée dans le parent glTF/FBX lorsqu'elle reparentait le
mesh au Rigify. Fais `Ctrl+Z`, exécute la dernière version du script, puis
relance `Créer les poids automatiques`. La matrice mondiale de chaque mesh est
maintenant mémorisée, restaurée et contrôlée après le calcul des poids.

Si le panneau affiche deux anciennes séries d'étapes en même temps, relance
également la dernière version : elle désenregistre désormais correctement le
panneau précédent.

### Le Rigify temporaire existe, mais le mesh ne suit pas

Le bouton `Ajuster les articulations` travaille en `Edit Mode` et ne doit pas
déformer le mesh. Clique d'abord sur `Créer les poids automatiques`, puis passe
le Rigify en `Pose Mode` pour vérifier que les bras et jambes suivent. Si une
ancienne exécution a produit des groupes vides, relance la dernière version du
script puis reclique sur le bouton : il nettoie cet essai incomplet avant de
recalculer les poids.

### Les animations des doigts ne bougent pas sur un modèle sans rig

C'est la limite volontaire du Rigify Basic de 29 os : il ne contient aucune
phalange. Les doigts reçoivent les poids de `DEF-hand.L/R` et restent rigides.
Un Rigify Human complet est nécessaire pour animer chaque doigt.

### « Il faut exactement un ancien rig »

La sélection contient des meshes provenant de plusieurs personnages, ou un
mesh n'a aucun modificateur Armature. Sélectionne uniquement les meshes skinnés
par une seule armature.

### « Rig non reconnu automatiquement »

Le rig utilise des noms d'os non standards. Le script s'arrête **avant** de
supprimer l'ancien rig. Il faut ajouter ses noms à la table de mapping du script
ou fournir la liste exacte de ses os. La version actuelle affiche dans la
console uniquement les groupes réellement pondérés qui n'ont pas été reconnus ;
les contrôleurs visuels sans poids ne font plus échouer le transfert.

### « Shape Keys non prises en charge »

Duplique le mesh, puis crée une version sans Shape Keys pour ce transfert. Ne
supprime pas les Shape Keys de ton unique fichier source.

### Le personnage se tord dès qu'une animation démarre

La pose de départ ne correspondait pas assez précisément à la T-pose UAL1.
Recharge la copie sauvegardée, recommence, puis ajuste l'ancien rig en Pose Mode
avant la validation.

### Des sommets restent immobiles

Si le statut annonce des `sommet(s) sans poids`, ouvre `Weight Paint`, attribue
ces sommets à l'os UAL1 voisin, puis normalise les poids.

## Export Godot optionnel

Après validation :

1. sélectionne `UAL1_Rig` et tous les meshes du personnage ;
2. ouvre `File > Export > glTF 2.0` ;
3. choisis le format `glTF Binary (.glb)` ;
4. active `Selected Objects` ;
5. conserve les animations/actions ;
6. exporte à l'échelle 1, en mètres, sans caméra, lumière ni gabarit.

Dans Hoplite, conserve les 53 noms d'os UAL1 sans les renommer.
