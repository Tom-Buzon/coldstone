# Mapping exact — `1_samus_aran_biker.glb` vers UAL1

## Utilisation pour le fitting des proportions

Le même preset sert désormais à deux opérations distinctes :

- fusionner les groupes de poids lors du transfert final ;
- choisir un **pivot de mesure unique** pour chacun des os UAL ajustables.

Les os `ctrl` restent utiles au cumul des poids, mais ne servent pas de pivots
de mesure. Par exemple, la longueur du bras UAL est mesurée entre la tête de
`arm left shoulder 2_163` et la tête de `arm left elbow_162`. Cela récupère la
vraie distance épaule–coude même lorsque le rig source divise visuellement le
membre avec un contrôleur intermédiaire.

Le fitting conserve les directions et le roll de la T-pose UAL. Une source en
A-pose peut donc être mesurée avant d'être remise en T-pose.

Source analysée directement :

- fichier : `C:\Users\suean\Downloads\1_samus_aran_biker.glb` ;
- armature : `GLTF_created_0` ;
- 197 os au total ;
- 28 meshes skinnés ;
- 194 groupes de poids réellement utilisés ;
- cible : `UAL1_Rig`, 53 os et 46 animations.

Le script détecte cette signature avant d'utiliser ses règles génériques.

## Racine, bassin et colonne

| Source exacte | Destination UAL1 |
|---|---|
| `GLTF_created_0_rootJoint` | `root` |
| `root ground_197` | `root` |
| `root hips_196` | `DEF-hips` |
| `pelvis_50` | `DEF-hips` |
| `spine lower _195` | `DEF-spine.001` |
| `spine middle_194` | `DEF-spine.002` |
| `spine upper_193` | `DEF-spine.003` |
| `spine upperer_190` | `DEF-spine.003` |
| `breast left_191`, `breast right_192` | `DEF-spine.003` |

Tous les groupes commençant par `vagina` ou `rectum` sont fusionnés vers
`DEF-hips` : UAL1 n'a pas d'os anatomiques équivalents.

## Cou et tête

| Source exacte | Destination UAL1 |
|---|---|
| `head neck lower_139` | `DEF-neck` |
| `head neck upper_138` | `DEF-neck` |
| `head neck upperer_137` | `DEF-head` |

Les 87 groupes du visage, des yeux, de la mâchoire, des dents, de la langue et
des cheveux sont fusionnés vers `DEF-head`. Le visage et la queue de cheval
restent donc rigides avec la tête ; ils ne disposent plus de leur animation
secondaire indépendante.

## Bras gauche

| Source exacte | Destination UAL1 |
|---|---|
| `arm left shoulder 1_164` | `DEF-shoulder.L` |
| `arm left shoulder 2_163` | `DEF-upper_arm.L` |
| `arm left shoulder ctrl_140` | `DEF-upper_arm.L` |
| `arm left elbow_162` | `DEF-forearm.L` |
| `arm left elbow ctrl_141` | `DEF-forearm.L` |
| `arm left wrist_161` | `DEF-hand.L` |

## Bras droit

| Source exacte | Destination UAL1 |
|---|---|
| `arm right shoulder 1_189` | `DEF-shoulder.R` |
| `arm right shoulder 2_188` | `DEF-upper_arm.R` |
| `arm right shoulder ctrl_165` | `DEF-upper_arm.R` |
| `arm right elbow_187` | `DEF-forearm.R` |
| `arm right elbow ctrl_166` | `DEF-forearm.R` |
| `arm right wrist_186` | `DEF-hand.R` |

## Doigts

La même règle est appliquée à gauche et à droite :

| Famille source | Destination UAL1 |
|---|---|
| `finger 1a/1b/1c` | `thumb.01/.02/.03` |
| `finger 2a/2b/2c` | `f_index.01/.02/.03` |
| `finger 3a/3b/3c` | `f_middle.01/.02/.03` |
| `finger 4a/4b/4c` | `f_ring.01/.02/.03` |
| `finger 5a/5b/5c` | `f_pinky.01/.02/.03` |
| `unused palm index/middle/ring/pinky` | `DEF-hand.L/R` |

## Jambes

| Source exacte | Destination UAL1 |
|---|---|
| `leg left thigh_33`, `leg left thigh ctrl_18` | `DEF-thigh.L` |
| `leg left knee_32` | `DEF-shin.L` |
| `leg left ankle_31` | `DEF-foot.L` |
| `leg left toes ctrl_19`, `leg left toes_30` | `DEF-toe.L` |
| tous les `leg left toe 1a` à `5b` | `DEF-toe.L` |
| `leg right thigh_49`, `leg right thigh ctrl_34` | `DEF-thigh.R` |
| `leg right knee_48` | `DEF-shin.R` |
| `leg right ankle_47` | `DEF-foot.R` |
| `leg right toes ctrl_35`, `leg right toes_46` | `DEF-toe.R` |
| tous les `leg right toe 1a` à `5b` | `DEF-toe.R` |

## Validation obtenue

Le mapping a été exécuté en mémoire sur les données du personnage :

- preset exact détecté ;
- 194 groupes sur 194 reconnus ;
- 151 059 affectations de poids transférées ;
- 98 993 sommets et 171 304 triangles traités ;
- 28 meshes liés à `UAL1_Rig` ;
- 0 sommet sans poids ;
- ancien rig `GLTF_created_0` supprimé ;
- 46 animations UAL1 conservées.

Ce mapping ne dispense pas de faire correspondre la pose de repos : le GLB
neuf est en A-pose, tandis que UAL1 est en T-pose. Il faut lever les bras avec
l'ancien rig avant de valider le transfert. Il ne faut pas déplacer les sommets
du mesh en Edit Mode.
