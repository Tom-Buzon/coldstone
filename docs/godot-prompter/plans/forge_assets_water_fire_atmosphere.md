# Forge — assets, matériaux, eau, feu, ciel et atmosphère

## Intention

Étendre la Forge avec un catalogue PBR réellement navigable, des effets eau/feu sobres et un réglage global du ciel sans multiplier les environnements ou les draw calls inutiles.

## Architecture retenue

- `material_catalog.gd` devient la source unique des identifiants, libellés, catégories et cartes PBR. Une catégorie aide à retrouver un matériau mais ne limite jamais son usage.
- Le terrain continue à peindre quatre couches dans un seul matériau. Les surfaces utilisent le même catalogue.
- Les fleurs, herbes et petits sous-bois sont retirés des props unitaires et restent disponibles dans le pinceau végétation, où chaque variété produit un `MultiMeshInstance3D`.
- L'eau est une entité horizontale basée sur un plan subdivisé et un shader transparent sans réfraction écran.
- Le feu est une entité `GPUParticles3D` dont la quantité est plafonnée, le rendu est billboard, sans ombre, avec lumière optionnelle.
- Un seul `WorldEnvironment` et un seul soleil existent par chapitre. Le nouvel onglet `CIEL & ATMOSPHÈRE` édite les données globales du document et choisit soit un ciel procédural, soit un panorama HDR 1K mis en cache par Godot.
- Les couleurs utilisent `ColorPickerButton`, tout en sauvegardant une chaîne HTML compatible avec les anciens mondes.

## Données et migration

- Version de document suivante : 9.
- Les anciennes clés d'atmosphère sont conservées et complétées par des valeurs par défaut.
- Les nouveaux types `water` et `fire` ont des valeurs bornées à la normalisation.
- Les assets Poly Haven sont conservés sous `assets/environment/` avec un manifeste de provenance et les empreintes fournies par l'API officielle.

## Validation

- Import/parse headless Godot 4.7.
- Probe de construction d'un document contenant terrain, eau, feu et panorama.
- Vérification que la végétation de terrain ne crée que des `MultiMeshInstance3D`.
- Revue Godot et contrôle du diff.
