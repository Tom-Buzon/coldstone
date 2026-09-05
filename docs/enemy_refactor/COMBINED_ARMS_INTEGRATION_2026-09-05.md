# Armée V2 — intégration du 5 septembre 2026

## Résultat et utilisation

La carte `champsDeBataille_V2_Commandement_414` utilise quatre fronts persistants et 25 groupes : 288 hoplites en 12 phalanges, 72 fantassins, 48 archers, quatre vétérans et deux géants. Les géants sont à l’échelle 3, modifiable dans l’inspecteur Forge. La bibliothèque Forge expose aussi des préréglages archers, fantassins et géant.

Le joueur commence face à plusieurs lignes et à deux silhouettes de géants. Les intervalles entre phalanges servent aux unités mobiles ; le soutien et les réserves occupent la profondeur. Les obstacles qui empiétaient sur le déploiement ont été déplacés vers les flancs, en conservant les objets et le terrain.

Le mode « fronts persistants » s’active par groupe dans la Forge. Les laboratoires historiques conservent leur doctrine antérieure. Les quatre familles passent par le runtime V2 et leurs composants dédiés ; les ennemis de production V1 ne sont pas redirigés globalement pendant la transition.

## Commandement et lisibilité

- Le front garde un repère dans le monde. Il ne pivote pas instantanément à chaque mouvement du joueur. Un déplacement durable hors de sa zone provoque un repositionnement limité et retardé.
- Plusieurs fronts avancent simultanément. Le choix de la première ligne tient compte du trajet, de l’orientation, des pertes et de l’ordre précédent.
- Les pertes rapprochées s’accumulent ; les emplacements ne se referment pas immédiatement. La désorganisation et les brèches subsistent 2,4 secondes. Les voisins réagissent après 700 ms, même si le groupe détruit a disparu.
- Infanterie et géants interceptent avec une prédiction courte et une poursuite bornée. Les géants utilisent d’abord leur axe de déploiement pour éviter de couper les rangs alliés.
- Le budget offensif est commun par cible : coût maximal 6, au plus quatre menaces de mêlée, deux de tir et une lourde, dans trois secteurs simultanés. Ces limites ne réduisent pas le nombre de troupes visibles ou en mouvement. Une flèche déjà partie conserve sa réservation après la mort de l’archer.
- Les formations hétérogènes créées dans la Forge sont divisées en sous-groupes de rôle pour conserver des intentions et permissions cohérentes.

## Mouvement et coût

Les intentions passent par des emprises orientées et des réservations de couloir. L’admission limite les couloirs à huit dans un voisinage de 30 mètres et 32 au total, avec vieillissement des attentes pour éviter une monopolisation. Les nouvelles recherches sont limitées à deux par image ; dès que leur cumul dépasse 2 ms, les suivantes sont reportées (ce seuil ne peut pas interrompre une recherche déjà commencée). Le remplacement d’une route est atomique : un échec ne détruit pas la route utilisable. Les réservations suivent la progression réelle, expirent lors d’un blocage et imposent un délai avant nouvelle tentative. Les collisions de rotation, le terrain, les pentes et les plafonds sont pris en compte. Le terrain Forge alimente les hauteurs des ancres et des emplacements par échantillonnage bilinéaire partagé.

Les décisions restent cadencées par groupe, avec cadence réduite à distance. Les corps hoplites, fantassins et archers partagent leur fondation LOD/anatomie mais possèdent trois atlas d’imposteurs distincts. Les géants gardent leur vrai corps et leur contrôleur physique ; ils n’utilisent pas l’imposteur hoplite. Les projectiles et fragments ont des durées et populations bornées.

## Unités

Les fantassins ont une sortie courte, une frappe à l’épée engagée et une récupération exploitable. Leur petit bouclier protège moins que celui d’une phalange. Les archers ont une portée de 9 à 34 mètres, une visée verrouillée, une flèche balistique et un recul limité. Les lignes de tir alliées sont vérifiées avant préparation et avant départ de la flèche. Les armes deviennent inutilisables lorsque les bras nécessaires sont coupés.

Les géants possèdent trois attaques annoncées, des zones verrouillées et une récupération vulnérable. La frappe au sol peut être évitée en sautant. Une jambe coupée les ralentit ; deux les font s’effondrer. Leur rig, leurs animations et leurs fragments sont distincts des hoplites.

Détails : [archers et fantassins](ENEMY_V2_ROLE_COMPONENTS.md), [géants](GIANT_V2_MINIBOSS_INTEGRATION_2026-09-05.md), [trafic](V2_FORMATION_TRAFFIC_CONTRACT.md).

## Régénération et restauration

`python tools/enemy_v2/author_combined_arms_world.py` produit d’abord `.tmp_tools/champsdebataille_v2_commandement_414.hoplite.json`, sans publication automatique. `--source` et `--output` permettent de choisir les chemins. L’ancien générateur GDScript refuse de remplacer une carte déjà marquée armes combinées.

La sauvegarde de la carte précédente est `champsdebataille_v2_commandement_414_before_combined_arms_20260905.hoplite.json`, à côté de la carte publiée dans le répertoire utilisateur Godot `hoplite_worlds`. Restaurer ce fichier sous le nom original restaure le déploiement antérieur, sans annuler le code V2.

## Limites assumées

Les corps des archers/fantassins sont encore ceux des hoplites ; la refonte individuelle des assets reste séparée. Le mesh du géant reste lourd. Son identification pour la traversée existe, mais son collider est une capsule : l’ancien dispositif complexe de grimpe cylindre/tête/sommet n’a pas été transféré. Les contrôles de tir alliés utilisent des emprises de groupe conservatrices, et non la géométrie de chaque soldat. Le réglage fin du ressenti demande encore des essais humains ; les probes vérifient les contrats et la stabilité, pas le plaisir de jeu.

## Validation

La construction réelle de la carte publiée a aussi été rejouée avec rendu OpenGL : PASS, 13 groupes en mouvement au relevé court, zéro conflit d’emprises. [Vue initiale capturée](combined_arms_initial_view_2026-09-05.png).

Carte publiée et relue par `hoplite_v2_command_lab_probe.gd` : PASS, 414 unités, quatre fronts, géants à l’échelle 3. Copie installée identique au fichier de travail validé (SHA256 `9864AAF7B52198A27D14BE4C8A0C755459DED1974BDD4164A48A1E13F63C0A04`).

- Intégration complète avec traversée, zigzags, retour et approche réelle des miniboss : PASS. 23 groupes ont changé de position, aucune superposition d’emprises au contrôle final, ancres finies pendant les déplacements. Les menaces mêlée/tir/lourde ont toutes été observées ; pic du budget partagé : 6/6.
- Doctrine : fronts indépendants, conservation des brèches après destruction, cumul des pertes, familles présentes seules, mémoire des flèches après décès du tireur et hauteur des lignes de tir : PASS.
- Trafic : emprises/rotations, réservation atomique, expiration, pentes/plafonds, admission locale, vieillissement et limite de nouvelles recherches par image : PASS.
- Rôles, animations, équipements, démembrement, géants aux échelles 2 et 3, imposteurs distincts et retour proche : PASS.
- Forge et régressions : bibliothèque V2, stabilité tactique historique, carte 150 et planification synthétique 1 008 soldats / 42 groupes : PASS. Le test 1 008 vérifie les structures et affectations ; ce n’est pas un benchmark de 1 008 acteurs rendus.

Mesure graphique isolée, Godot 4.7 OpenGL Compatibility, RTX 4060 Laptop GPU, 180 images par scénario, VSync et plafond d’images désactivés : scène complète à **16,513 ms en moyenne**, **20,004 ms au 95e percentile**, environ **3 001 appels de rendu** et **2,0 millions de primitives**. Cinq unités utilisaient le mouvement physique individuel au relevé (dont les deux géants), 409 le mouvement de troupe. Les autres étapes du probe désactivent progressivement des fonctionnalités pour donner des pistes de coût ; l’armée continue d’évoluer entre les étapes, donc leurs différences ne constituent pas une attribution causale exacte.

Données : [mesure de rendu](combined_arms_render_cost_2026-09-05.json). Cet échantillon représente quelques secondes de la vue initiale ; il ne garantit pas 60 FPS pendant une longue mêlée ou une accumulation de démembrements. Les runs headless chronométrés incluent un plafond de 60 FPS et ne sont pas utilisés comme mesure GPU.

Des avertissements de sandbox ont été observés pour le magasin de certificats Windows et l’écriture des préférences/cache Godot ; les probes listés se terminent avec code 0. Aucun échec de script du runtime final n’a été détecté.
