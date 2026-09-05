# Stylized Nature MegaKit — bibliothèque Forge

Ces fichiers proviennent du **Stylized Nature MegaKit [Standard]** de Quaternius.
Le fichier `LICENSE_Quaternius_CC0.txt` fourni dans l'archive déclare les modèles sous
**CC0 1.0 Universal**.

La totalité des **68 modèles glTF** du pack est maintenant importée et rangée par
famille afin que la bibliothèque de la Forge reste exploitable :

- `trees/` : 20 arbres et troncs ;
- `shrubs/` : 6 buissons ;
- `ground_cover/` : 18 herbes, fleurs, trèfles, fougères et champignons ;
- `rocks/` : 14 rochers et pierres ;
- `stone_paths/` : 10 chemins et arches en pierre ;
- `textures/` : les 20 textures partagées par les scènes glTF.
- `thumbnails/` : 68 aperçus PNG pré-calculés pour la Forge.

Le pinceau de végétation conserve une couche de densité indépendante par espèce et
construit un `MultiMeshInstance3D` uniquement pour chaque type réellement peint.
Herbes, fleurs et couvre-sols peuvent donc se superposer sans se remplacer. Une
zone ne contenant que de l'herbe courte produit un seul lot de rendu. Les instances
n'ont ni nœud individuel, ni collision, ni ombre, ni contribution GI. Les espèces
plus lourdes (buissons, fougères, fleurs) reçoivent une densité réduite.

Les objets posés individuellement suivent une règle distincte : buissons,
couvre-sols et tous les éléments `stone_paths/` sont non bloquants par défaut,
tandis que les galets `Pebble_*` ont un collider. Les `Rock_Medium_*`
utilisent une enveloppe convexe simplifiée et les catégories rochers/chemins
s'alignent automatiquement sur la normale du terrain. La Forge permet de modifier
ces deux options pour chaque pinceau et chaque objet déjà placé.
