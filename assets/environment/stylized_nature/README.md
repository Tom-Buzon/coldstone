# Stylized Nature MegaKit — sélection Forge

Ces fichiers proviennent du **Stylized Nature MegaKit [Standard]** de Quaternius.
Le fichier `LICENSE_Quaternius_CC0.txt` fourni dans l'archive déclare les modèles sous
**CC0 1.0 Universal**.

La Forge n'importe volontairement qu'une sélection légère :

- `Grass_Common_Short` et `Grass_Wispy_Tall` pour les masses d'herbe ;
- `Clover_1` et `Fern_1` pour casser la répétition ;
- `Rock_Medium_1` conservé pour une future variante minérale.

Les modèles sont chargés comme scènes glTF puis leur premier `Mesh` est réutilisé par
`MultiMeshInstance3D`. Les instances n'ont pas de collision et ne projettent pas
d'ombre afin de préserver les performances dans les zones denses.
