# Forge — végétation superposable, extension du terrain et catalogue visuel

## Décisions

### Végétation

Trois modèles ont été considérés : un type unique par cellule (format actuel), une liste de coups de pinceau, ou sept cartes de densité fixes. Les cartes fixes sont retenues : elles permettent de superposer herbe et fleurs, restent déterministes, se rééchantillonnent sans ambiguïté et donnent directement un canal à chaque `MultiMeshInstance3D`.

`foliage_layers` contient `résolution × résolution × 7` valeurs. Les anciennes cartes `foliage_density` + `foliage_types` sont migrées automatiquement. La gomme agit uniquement sur le type équipé afin de ne pas détruire les autres espèces.

### Dimensions du terrain

Modifier largeur ou profondeur conserve le repère local et le relief de l'ancienne emprise. Les nouveaux points situés hors de l'ancien rectangle sont générés avec le même seed et les mêmes paramètres procéduraux, puis raccordés au bord existant. Réduire recadre autour du centre. Les objets du chapitre gardent leurs coordonnées monde.

### Catalogue

Les aperçus sont pré-calculés en PNG pour éviter de charger 68 scènes glTF dans l'interface. Une petite miniature apparaît dans chaque ligne du catalogue. Cliquer la ligne équipe le pinceau et remplace temporairement l'inspecteur par une grande fiche de l'asset ; placer ou sélectionner un objet rétablit les propriétés de la scène.

## Responsabilités

```text
HopliteWorldTerrain
├── migration et stockage des 7 couches
├── peinture/effacement d'un canal
└── extension/coupe en coordonnées physiques

HopliteWorldTerrainFoliage
├── échantillonnage indépendant de chaque couche
├── budget global partagé
└── un MultiMesh par type réellement utilisé

HopliteWorldEditor
├── Bibliothèque : outils et miniatures
└── Propriétés
    ├── terrain sélectionné : données persistantes uniquement
    └── asset équipé : grande prévisualisation et réglages de pose
```

## Tâches

- [x] Ajouter `foliage_layers`, sa migration et ses tests de superposition.
  Skills: `procedural-generation`, `godot-debugging`
- [x] Distribuer chaque couche dans un MultiMesh indépendant sous budget global.
  Skills: `3d-essentials`, `godot-optimization`
- [x] Étendre/recadrer les cartes du terrain sans étirer l'ancienne emprise.
  Skills: `procedural-generation`
- [x] Générer et intégrer les miniatures du catalogue.
  Skills: `assets-pipeline`, `godot-ui`
- [x] Simplifier les propriétés Terrain et ajouter la fiche d'asset équipée.
  Skills: `godot-ui`
- [x] Mettre à jour l'aide, valider headless et revoir le code.
  Skills: `godot-testing`, `godot-code-review`
