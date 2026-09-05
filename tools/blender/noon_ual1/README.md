# Noon sur le squelette UAL1

Ce dossier contient un pipeline Blender de **pré-rig automatique**, conçu pour
obtenir rapidement un brouillon corrigible à la main. Il conserve les 53 os et
les 46 animations de `UAL1_Standard.glb` sans renommer ni déplacer le squelette.

## Générer le fichier Blender

Depuis la racine du projet, dans PowerShell :

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --python ".\tools\blender\noon_ual1\rig_noon_to_ual1.py"
```

Le script cherche par défaut le modèle ici :

```text
C:\Users\suean\Downloads\p-0r_noon.glb
```

Pour utiliser une autre copie :

```powershell
$env:HOPLITE_NOON_GLB = "D:\mes-modeles\noon.glb"
```

Le résultat principal est `output/noon_ual1_autorig_draft.blend`. Le script ne
modifie jamais les GLB sources.

## Voir les animations

1. Ouvrir le `.blend` généré.
2. Sélectionner `UAL1_Rig` dans l'Outliner.
3. Passer une zone en **Dope Sheet**, puis choisir **Action Editor**.
4. Choisir une action, par exemple `Idle_Loop`, `Walk_Loop`, `Sword_Attack` ou
   `Death01`.
5. Appuyer sur Espace pour lire l'animation.

Pour revenir à la pose de correction, cliquer sur le `X` à côté du nom de
l'action dans l'Action Editor. Ne pas modifier les noms, la hiérarchie ou la
pose de repos des os UAL1 si l'objectif reste la compatibilité directe.

## Corriger le brouillon

Les deux objets utiles sont `Noon_Body` et `Noon_Clothing`.

- Corriger la silhouette en **Edit Mode**, sans action active. Cette méthode
  change la géométrie tout en conservant le squelette canonique.
- Corriger les déformations en **Weight Paint**. Vérifier surtout épaules,
  aisselles, coudes, poignets, doigts, hanches et haut des cuisses.
- Tester plusieurs poses extrêmes, pas seulement `Idle_Loop`.
- Le mannequin UAL1 original est conservé, masqué, sous le nom
  `UAL1_WeightReference`. Il peut être réaffiché comme référence.

## Vêtement et tissu

Le vêtement reste d'abord un mesh skinné normal. Les deux grands panneaux sont
marqués dans le groupe `Cloth_Dynamic_Candidate`; leur partie haute est marquée
dans `Cloth_Pin_Top`.

Trois niveaux sont possibles :

1. **Mesh skinné** : le moins coûteux et le plus robuste. Le tissu se déforme
   avec le bassin et les jambes, mais ne flotte pas librement.
2. **Os secondaires ou animation baked** : bon compromis pour un boss unique.
   Garder ces os dans un accessoire séparé si les 53 os UAL1 doivent rester
   strictement identiques.
3. **SoftBody3D Godot** : séparer uniquement les panneaux longs en un objet
   distinct, épingler le haut, puis simuler cette petite pièce. Ne pas simuler
   toute la tenue, sinon le capuchon et le corsage deviennent mous et le coût
   physique augmente inutilement.

Le panneau est volontairement attaché au bassin dans ce brouillon afin de ne
pas s'écarter entre les jambes pendant les animations. Il faudra choisir ensuite
entre peinture manuelle, os secondaires ou simulation.

## Licence source

Le modèle Noon téléchargé indique une licence **CC BY 4.0**. Conserver le nom de
l'auteur et la source d'origine dans les crédits du jeu et dans le suivi des
assets avant toute distribution.
