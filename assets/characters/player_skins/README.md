# Joueurs jouables UAL1 — dossier surveillé

Ce dossier est scanné automatiquement à chaque lancement du jeu/F5. Tout
fichier `.glb` ou `.gltf` compatible est ajouté à **Paramètres > Affichage >
Skin**. Les sous-dossiers sont également parcourus.

Un modèle compatible doit contenir :

- exactement un `Skeleton3D` et 53 os UAL ;
- tous les noms d'os UAL (un suffixe glTF sur l'unique racine est toléré) ;
- les 46 animations UAL ;
- au moins un `MeshInstance3D`.

Un modèle refusé est ignoré proprement et la raison apparaît dans la console.

- `noonT1.glb` — Noon adapté au rig UAL1.
- `samusWoopsy.glb` — Samus adaptée au rig UAL1.

Le mannequin `res://assets/runtime/ual1/UAL1_Standard.glb` reste l'apparence par
défaut. Le choix est exposé dans **Paramètres > Affichage** et sauvegardé dans
`user://hoplite_global_settings_v1.cfg`.

## Objets, vêtements et futures armures

Chaque mesh du personnage apparaît automatiquement dans **Pièces du
personnage** et peut être affiché/masqué. Le choix est sauvegardé séparément
pour chaque skin.

Dans Blender :

- supprimer avant export les helpers, doublons et objets qui ne serviront
  jamais en jeu ; les masquer dans le viewport ne garantit pas leur exclusion
  du glTF ;
- conserver en objets séparés les vêtements/armures que le joueur doit pouvoir
  équiper, avec des noms explicites (`Casque`, `Plastron`, `Cape`, etc.) ;
- pondérer ces pièces au squelette UAL comme le corps ;
- ne pas modifier le nom, la hiérarchie ni le roll des os UAL.

Samus exporte actuellement sa racine sous le nom `root_2`. Le runtime reconnaît
désormais l'unique os parent comme racine, ce qui conserve la bonne orientation
des attaques spirales et des wall runs.
