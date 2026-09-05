# Migration des personnages vers une bibliothèque d'animations partagée

Ce document est la passation issue de la migration des hoplites standard et vétérans. Il décrit l'architecture finale, les essais qui ont fonctionné, les erreurs qui ont produit des poses en T ou des personnages figés, et la procédure conseillée pour migrer les autres familles de personnages.

## 1. Résultat obtenu sur les hoplites

Le squelette visuel de `ngeneral` est devenu le squelette canonique des hoplites. Les deux variantes utilisent maintenant :

- un seul `Skeleton3D` principal par soldat ;
- un `AnimationPlayer` propre à l'instance ;
- un `AnimationTree` propre à l'instance ;
- une référence vers la même bibliothèque de clips ;
- aucun personnage UAL1, UAL2 ou FBX donneur instancié à l'exécution.

Les clips sont partagés, mais chaque soldat garde son propre temps de lecture et son propre état d'animation. Deux hoplites peuvent donc courir, bloquer ou attaquer à des moments différents.

Fichiers principaux :

- squelette canonique : `assets/characters/3dgen_demo/ngeneral-1787351044165.glb` ;
- bibliothèque actuelle : `assets/animations/hoplite_animation_library_v3.res` ;
- générateur : `tools/build_hoplite_animation_library.gd` ;
- pilote d'exécution : `scripts/animation/shared_hoplite_animation_driver.gd` ;
- activation par type d'ennemi : `scripts/enemy/athenian_enemy.gd`.

La bibliothèque `v3` contient la locomotion retargetée et les actions compatibles avec ce squelette. Le journal doit afficher une ligne de la forme :

```text
[HOPLITE SHARED ANIMATION] READY library_v=3
```

Cette ligne est importante : elle prouve que le jeu utilise bien la nouvelle ressource et non une ancienne version encore en cache.

## 2. Architecture finale

```text
hoplite_animation_library_v3.res
├── Idle / Jog / Sprint / morts et réactions UAL1
└── actions du haut du corps provenant de UAL2
       │
       ├── Hoplite standard → AnimationPlayer + AnimationTree → squelette ngeneral
       └── Hoplite vétéran  → AnimationPlayer + AnimationTree → squelette ngeneral
```

Le `AnimationTree` mélange :

- la locomotion du corps entier dans un `BlendSpace` ;
- une action en surcouche avec un `Blend2` ;
- un filtre d'os sur cette surcouche, limité à la colonne, la tête, les épaules et les bras.

Le filtre est indispensable. Sans lui, un clip d'action qui ne possède que des pistes du haut du corps peut remettre les jambes dans leur pose neutre et donner l'impression que les pieds ne bougent plus.

Les actions sémantiques des hoplites utilisent actuellement ces clips UAL2 :

```text
spear_thrust       -> ual2_shield_one_shot
spear_thrust_low   -> ual2_sword_block
shield_bash        -> ual2_shield_one_shot
block_idle         -> ual2_idle_shield
block_impact       -> ual2_sword_block
```

Ce sont des remplacements visuellement corrects, pas encore les animations Mixamo/FBX exactes d'origine. Ce choix a supprimé les poses en T et rendu le système fiable. Les clips exacts pourront être réintroduits plus tard, uniquement après un vrai bake de retargeting validé visuellement.

## 3. Ce qui a fonctionné

### Choisir le squelette canonique avant toute conversion

Il faut commencer par le personnage réellement affiché dans le jeu, puis relever :

- le nombre exact d'os ;
- les noms et la hiérarchie des os ;
- les poses de repos ;
- le `Skin` utilisé par chaque mesh ;
- les points d'attache des armes, boucliers et membres détachables.

Deux personnages qui se ressemblent ne sont pas nécessairement compatibles. Une bibliothèque ne doit être partagée entre plusieurs variantes que si leur topologie de squelette, leur pose de repos et leurs `Skin` sont réellement compatibles.

### Retargeter les clips une seule fois

La locomotion UAL1 a été jouée sur son donneur, échantillonnée, puis enregistrée sur le squelette canonique. Lors de la génération, il a fallu :

1. mettre le lecteur source en mode manuel ;
2. faire un `seek` à l'instant voulu ;
3. appeler `advance(0.0)` ;
4. forcer la mise à jour du squelette source ;
5. seulement ensuite lire les poses et écrire les clés sur le squelette canonique.

Ce bake hors exécution est la source du gain principal : le travail de conversion n'est plus répété pour chaque soldat.

### Laisser chaque instance piloter sa propre lecture

La ressource d'animation est partagée, mais pas le `AnimationPlayer` ni le `AnimationTree`. Le pilote avance son arbre dans son propre `_physics_process`. Ainsi, un soldat statique, dormant ou temporairement ignoré par le budget IA continue de s'animer.

### Versionner les bibliothèques générées

Pendant le développement, réutiliser le même chemin `.res` a provoqué des doutes sur le cache Godot. La solution a été de produire `v2`, puis `v3`, et d'afficher la version chargée dans les logs.

Pour une modification structurelle, utiliser un nouveau nom de ressource ou un numéro de version, puis vérifier le marqueur dans le journal.

### Valider le résultat visuel sans équipement

Les boucliers et les lances masquaient les bras et pouvaient faire croire que le corps était animé. Les sondes finales cachent l'équipement et placent la caméra près du corps.

Les validations utiles sont :

- aucune pose en T en attente, en course, en garde ou en attaque ;
- les pieds et les tibias changent réellement entre deux images de course ;
- les bras changent réellement pendant une action ;
- la locomotion des jambes continue pendant une garde ou une attaque du haut du corps ;
- le mesh suit le squelette, pas seulement les armes ;
- le comportement reste correct en solo, en phalange, dans le Lab et dans la Forge.

Sondes disponibles :

- `tools/hoplite_animation_rig_audit.gd` ;
- `tools/hoplite_visual_pose_probe.gd` ;
- `tools/hoplite_combat_lab_visual_probe.gd` ;
- `tools/hoplite_merged_skin_visual_probe.gd` ;
- `tools/hoplite_phalanx_optimization_probe.gd`.

Les tests finaux des hoplites ont notamment mesuré un mouvement des tibias pendant la locomotion, y compris sous la garde, ainsi qu'un mouvement du haut du corps pendant l'attaque. La capture de référence est `docs/enemy_refactor/hoplite_visual_pose_probe.png`.

## 4. Ce qui n'a pas fonctionné

### Se fier uniquement aux valeurs des os

Une animation peut contenir des clés qui changent tout en affichant une pose en T. C'est exactement ce qui est arrivé avec certains clips Mixamo : les métriques indiquaient un mouvement, mais le mesh restait visuellement dans sa pose de référence.

Une variation de quaternion ou un compteur de pistes ne constitue donc pas une preuve suffisante. Toute migration doit comporter une preuve rendue, équipement caché, à plusieurs instants du clip.

### Baker directement la chaîne de retargeting Mixamo native

`external_animation_bank.gd` utilise un `RetargetModifier3D` natif et un squelette proxy. Le premier générateur faisait avancer le `AnimationPlayer`, puis lisait immédiatement le proxy ou la cible. Or le modificateur natif n'avait pas nécessairement été évalué entre ces deux opérations.

Conséquence : les clips d'action générés contenaient un haut du corps en pose en T, même lorsque certaines clés semblaient évoluer.

Les tentatives d'appel direct à `_process_modification` ou `_process_modification_with_delta` n'ont pas fourni une méthode hors ligne fiable. Ces fonctions internes ne doivent pas être considérées comme une API publique de bake.

La solution retenue pour les hoplites a été d'abandonner ces clips générés et d'utiliser des actions UAL2 déjà compatibles.

Pour conserver exactement une animation Mixamo sur un futur personnage, il faudra soit :

- employer le pipeline de retargeting à l'import de Godot et sauvegarder le résultat ;
- construire un outil de bake qui laisse réellement s'écouler les frames de la scène et démontre visuellement que le proxy a été évalué ;
- retargeter le clip dans un outil DCC, puis réimporter le résultat sur le squelette canonique.

Il ne faut jamais supprimer les donneurs avant d'avoir prouvé visuellement le clip converti.

### Superposer une action sans filtre d'os

Les clips UAL2 d'action ne possèdent pas toutes les pistes des jambes. Sans filtre sur le `Blend2`, leur valeur neutre écrasait la locomotion du bas du corps. Le personnage n'était plus en T, mais ses pieds restaient presque immobiles pendant le déplacement.

La correction est un masque explicite du haut du corps. Pour un coup qui nécessite les hanches ou les jambes, créer un masque différent ou jouer l'action en corps entier ; ne pas élargir silencieusement le masque commun.

### Désactiver complètement le `AnimationTree` à distance

Une première optimisation coupait l'arbre pour les soldats lointains. Certains soldats dormants ne recalculaient jamais leur LOD et restaient alors figés définitivement.

Une future optimisation de distance doit réduire la fréquence d'évaluation ou garantir un réveil explicite. Elle ne doit pas désactiver définitivement l'arbre sur la seule base d'un état qui ne sera plus rafraîchi.

### Copier le chemin du squelette avant de parenter le mesh fusionné

Le mesh corporel fusionné pouvait garder un chemin apparemment valide mais être mal relié au squelette, surtout avec le renderer Compatibility. Le chemin `merged_body.skeleton` est maintenant assigné après `skeleton.add_child(merged_body)`.

### Tester derrière les boucliers ou dans une scène trop complexe

Une vue distante de phalange ne permet pas de distinguer un corps animé d'armes animées autour d'un corps figé. De plus, certains tests lancés dans le monde complet produisaient des erreurs sans rapport avec l'animation, venant notamment du joueur ou de `current_scene`.

Commencer par une scène minimale avec un seul ennemi. Le test du monde complet vient ensuite.

## 5. Procédure recommandée pour le prochain personnage

### Étape A — Faire l'inventaire de la famille

Créer une fiche comprenant :

- scènes standard, vétéran et variantes ;
- modèle visuel réellement utilisé ;
- squelette envisagé comme canonique ;
- nombre, noms, hiérarchie et repos des os ;
- nombre de meshes skinnés et `Skin` associés ;
- lecteurs et arbres d'animation déjà présents ;
- donneurs UAL, GLB ou FBX instanciés ;
- liste des clips réellement demandés par le gameplay ;
- attaches d'équipement ;
- zones de dégâts et de démembrement ;
- cas particuliers : quatre pattes, ailes, cape, monture, etc.

Ne pas inclure automatiquement deux variantes dans la même famille. Le vétéran hoplite a pu partager le rig de `ngeneral`, mais ce point doit être redémontré pour chaque autre groupe.

### Étape B — Auditer le rig

Construire une petite sonde qui affiche :

- identité du squelette canonique ;
- compte et liste des os ;
- correspondances exactes et normalisées avec chaque source ;
- os absents ou ambigus ;
- chemins `root_node` des `AnimationPlayer` ;
- pistes d'animation qui ne résolvent aucun nœud ;
- compatibilité du `Skin` de chaque mesh avec le squelette choisi.

Arrêter la migration si des os essentiels n'ont pas de correspondance. Une correspondance approximative non documentée finira généralement en pose incorrecte.

### Étape C — Prouver une seule locomotion

Avant de migrer toutes les animations :

1. convertir seulement `Idle` et `Jog` ;
2. créer une bibliothèque versionnée propre à cette famille ;
3. la jouer sur un exemplaire du personnage canonique ;
4. cacher armes et accessoires ;
5. comparer au moins deux instants de chaque clip ;
6. vérifier le mesh rendu, les mains, les pieds, le bassin et la tête.

Si cette étape échoue, ne pas continuer avec les actions.

### Étape D — Ajouter les actions par catégorie

Classer chaque action avant de l'intégrer :

- corps entier : mort, chute, esquive, saut ;
- haut du corps : garde légère, tir, frappe compatible avec la marche ;
- masque spécialisé : attaque utilisant le bassin, recharge, coup accroupi.

Privilégier une source déjà compatible avec le squelette canonique ou un clip retargeté lors de l'import. Pour chaque nouveau clip, produire une preuve visuelle avant de remplacer son ancien donneur.

### Étape E — Construire le pilote partagé

Le pilote doit :

- installer la bibliothèque partagée dans un `AnimationPlayer` local ;
- construire ou charger un `AnimationTree` local ;
- posséder sa propre vitesse et son propre état d'action ;
- avancer indépendamment du budget de décision de l'IA ;
- appliquer des filtres d'os explicites aux surcouches ;
- journaliser la version de la bibliothèque et l'identité du rig canonique ;
- retomber proprement sur une animation sûre si une clé sémantique manque.

Ne router vers ce pilote que les types déjà migrés. Garder les autres personnages sur l'ancien système jusqu'à leur validation complète.

### Étape F — Retirer les donneurs

Après validation visuelle seulement :

- retirer UAL1/UAL2 et les FBX donneurs de la scène d'exécution ;
- retirer les wall-runs et clips jamais utilisés par cette famille ;
- dédupliquer les chemins qui chargeaient le même FBX ;
- vérifier qu'il ne reste qu'un squelette visuel principal et un lecteur/arbre local ;
- comparer le nombre de nœuds, squelettes, lecteurs et pistes avant/après.

### Étape G — Fusionner les meshes sans perdre le démembrement

Cette optimisation est séparée de la migration des animations. La faire après que le rig unique fonctionne.

Pour les hoplites, les dix morceaux corporels ont été fusionnés dans un `ArrayMesh` skinné. L'appartenance anatomique est conservée dans les couleurs de sommets et interprétée par le shader. Le système peut donc encore masquer une zone, créer sa coupe et afficher le membre détaché.

Pour un autre personnage :

- confirmer que les meshes partagent un `Skin` compatible ;
- préserver dans le mesh fusionné un identifiant de zone anatomique ;
- conserver les matériaux et les données nécessaires aux coupes ;
- tester chaque membre détachable ;
- garder une solution segmentée si la fusion détruit le skinning, les matériaux ou le démembrement.

Le démembrement est une contrainte obligatoire, pas une option à supprimer pour gagner quelques draw calls.

## 6. Matrice minimale de validation

Chaque famille doit être testée dans les situations suivantes :

| Cas | Ce qu'il faut vérifier |
| --- | --- |
| Personnage seul | Idle, marche/course, rotation, attaque, impact, mort |
| Sans équipement | Absence de pose en T, mouvement réel des mains et des pieds |
| Avec équipement | Attaches correctes, bouclier/arme alignés aux mains |
| Formation/groupe | Temps de lecture indépendants, aucune animation figée |
| Combat en mouvement | Jambes actives sous la garde et les actions autorisées |
| Soldat dormant | Animation toujours vivante ou réveil LOD garanti |
| Proche et lointain | Aucun gel définitif lors du changement de distance |
| Standard et vétéran | Même qualité visuelle, rig réellement compatible |
| Renderer Compatibility | Skinning, mesh fusionné et ombres corrects |
| Démembrement | Chaque zone disparaît correctement et le membre détaché reste valide |
| Lab et Forge | Même comportement dans les deux parcours d'instanciation |

## 7. Définition de « terminé »

Un personnage n'est considéré comme migré que si :

- il ne possède plus de donneur invisible à l'exécution ;
- un seul squelette principal pilote le corps et l'équipement ;
- les clips sont partagés mais la lecture reste indépendante par instance ;
- aucune pose en T ou pose figée n'apparaît dans les scènes réelles ;
- la locomotion continue sous les actions partielles ;
- le LOD ou le sommeil IA ne peut pas figer définitivement l'arbre ;
- les actions sémantiques utilisées par le gameplay ont toutes un clip valide ;
- le résultat a été validé visuellement sans armes ni bouclier ;
- le démembrement a été testé zone par zone ;
- la nouvelle version de la bibliothèque est visible dans les logs ;
- les anciennes ressources ne sont supprimées qu'après cette validation.

## 8. Optimisations voisines à ne pas confondre

La bibliothèque partagée règle principalement la duplication des personnages donneurs, des squelettes et des lecteurs d'animations. Les autres gains restent des chantiers distincts :

- cache de formation calculé une fois par groupe ;
- sommeil des hitboxes anatomiques hors combat ;
- politique d'ombres plus agressive pour les soldats secondaires ;
- fusion des meshes corporels ;
- réduction de fréquence des systèmes non visuels à distance.

Ils peuvent être reproduits sur les autres ennemis, mais doivent chacun conserver leurs propres tests de non-régression. En particulier, ni la fusion des meshes ni la réduction des hitboxes ne doit casser le démembrement.
