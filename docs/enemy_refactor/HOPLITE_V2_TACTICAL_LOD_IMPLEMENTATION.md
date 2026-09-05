# Hoplite V2 — commandement tactique et imposteurs lointains

## État implémenté

La phalange V2 possède maintenant trois niveaux de responsabilité strictement séparés :

1. `EnemyV2BattleLayoutRuntime` attribue des secteurs à des **troupes entières**. Il ne connaît aucun soldat et ne déplace aucun nœud.
2. `HopliteV2TroopRuntime` décide à cadence limitée pour une phalange, maintient ses slots, sa cohésion, ses permissions d'attaque et sa réaction locale.
3. `HopliteEnemyActorV2` exécute le déplacement vers un slot et le combat déjà autorisé. Il ne choisit jamais sa place stratégique.

Ce découpage est la base à réutiliser pour les archers, unités spéciales et bataillons légers. Ces familles pourront fournir leur propre profil sans réintroduire de réflexion stratégique par soldat.

## Admission d'une nouvelle phalange

Une phalange qui arrive après la formation initiale suit le cycle suivant :

`support → extérieur → orbite → assemblage → admission → contact`

- Le cercle extérieur est à `15 m` du joueur.
- La troupe rejoint d'abord ce cercle sur son angle courant, donc elle dégage la zone occupée.
- Elle parcourt ensuite le cercle par petites consignes angulaires vers un secteur réservé.
- Elle avance radialement jusqu'au cercle d'assemblage à `7,35 m`.
- Elle n'est admise qu'après `300 ms` de stabilité et au moins `62 %` de cohésion.
- Une seule nouvelle phalange est en admission à la fois.
- Les phalanges déjà admises gardent leurs secteurs tant que la nouvelle venue n'est pas prête. À l'admission, le nouvel anneau est choisi en minimisant le déplacement angulaire des groupes existants.

Le cercle de contact est maintenant à `5 m`. Avec la profondeur du premier rang, les lances restent à portée, mais le joueur conserve davantage de lisibilité et d'espace qu'avec l'ancien rayon de `4,2 m`.

Cette route est analytique et volontairement adaptée à la carte ouverte actuelle. Un obstacle topologique complexe nécessitera plus tard **un chemin NavMesh par troupe**, jamais un agent par soldat. Le chemin grossier devra alimenter l'ancre de groupe sans remplacer ses slots locaux.

## Intrusion dans les rangs

À chaque décision de troupe, la phalange calcule une boîte orientée à partir de ses colonnes et rangs. Si le joueur entre dans cette boîte :

- toute la troupe devient engagée ;
- l'ordre stratégique de déplacement de l'ancre est temporairement suspendu ;
- les colonnes conservent leur côté et s'ouvrent en deux ailes ;
- les ailes forment une petite tenaille autour du joueur sans échanger leurs membres ni tracer de chemin au travers de lui ;
- seules les unités déjà à portée peuvent recevoir un bail d'attaque ; le plafond d'attaques concurrentes du profil reste actif ;
- la réaction persiste `1,8 s` après la dernière intrusion, puis la troupe reforme ses slots normaux.

Un soldat en attaque, récupération ou étourdissement suffit également à marquer sa troupe entière comme engagée. Cette règle empêche l'armée de déplacer une formation dont un membre combat encore.

## Budget de calcul

| Niveau | Unité de calcul | Cadence / borne |
|---|---|---|
| Armée | groupe de troupe | reconstruction au plus toutes les `350 ms` par cible |
| Phalange proche | groupe | `8 Hz` |
| Phalange lointaine | groupe | `2 Hz` |
| Déplacement LOD0 | soldat visible proche | cadence image ou physique nécessaire |
| Déplacement LOD1 | soldat | `30 Hz` |
| Déplacement LOD2 | soldat | `12 Hz` |
| Déplacement LOD3 | soldat | `4 Hz` |
| Imposteurs | un lot MultiMesh | `4 Hz`, une reconstruction compacte par lot |

Le probe d'échelle représente `1 008` soldats par `42` groupes : quatre groupes de contact et trente-huit supports. La reconstruction stratégique mesurée reste de l'ordre de la milliseconde sur la machine de développement. Ce résultat valide le coût du **commandement**, pas la capacité finale de rendu, de physique ou d'animation de 1 000 squelettes proches.

## LOD imposteur

Au-delà du `cull_distance` configuré dans les réglages du jeu, un hoplite contrôlé par le runtime de troupe quitte ses trois meshes skinnés et rejoint `HopliteV2ImpostorBatch` :

- un seul `MultiMeshInstance3D` partagé par le runtime ;
- une carte de `4 × 256 × 320` pixels issue du vrai modèle, de la lance, du bouclier et de la pose de garde ;
- quatre phases temporelles décalées par `INSTANCE_CUSTOM`, pour éviter une armée complètement figée ;
- aucun squelette, lecteur d'animation, collider, ombre ni GI **exécuté ou rendu** par l'imposteur ;
- positions actualisées à `4 Hz` ; capacité agrandie par puissances de deux afin d'éviter les réallocations répétées ;
- texture compressée VRAM avec mipmaps.

L'atlas est reproductible avec :

`tools/enemy_v2/generate_hoplite_v2_impostor_atlas.gd`

La première version est frontale et réservée aux très grandes distances. Si les silhouettes latérales deviennent visibles, l'évolution correcte est un atlas directionnel (4 ou 8 vues) dans le même batch, pas le retour des squelettes lointains.

Pour assurer un retour 3D sans pic de réinstanciation, le squelette et ses ressources restent actuellement en mémoire derrière l'imposteur. L'`AnimationPlayer` est inactif et le composant LOD individuel est arrêté ; le batch effectue lui-même les tests de réveil à `4 Hz`. Une disparition complète des nœuds de squelette demanderait une phase ultérieure data-oriented avec désinstanciation/réhydratation des acteurs, utile surtout si la mémoire — et non le temps CPU/GPU — devient le goulot.

## Régressions couvertes

- anneaux à 1, 2, 3 et 4 phalanges ;
- libération d'un ancien secteur et admission différée de son remplaçant ;
- route extérieure et orbite sans passage par le centre ;
- détection d'intrusion et création des deux ailes ;
- demi-tour sur place sans échange gauche/droite ;
- 150 soldats canoniques de `champsdebataille_v2_150` malgré les groupes de test supplémentaires ajoutés dans la Forge ;
- batch d'imposteurs, atlas, capacité et retrait au retour en 3D ;
- comparaison rendue entre le modèle 3D et l'imposteur pour la taille et le contact au sol.
