# Sources d'animation Spartan

Déposer ici les nouveaux fichiers d'animation que le Spartan Animation
Workbench doit découvrir automatiquement.

Formats reconnus : `.fbx`, `.glb`, `.gltf` et `.blend`.

Par défaut, toute nouvelle source placée dans ce dossier est considérée comme
un rig humanoïde compatible Mixamo. Les sources historiques restent à leur
emplacement actuel pour ne casser aucun chemin `res://`, mais elles sont aussi
scannées lors de chaque génération du manifeste :

- `assets/runtime/ual1`
- `assets/runtime/ual2`
- `assets/runtime/mixamo/animations`
- `assets/animations/sources`

## Organisation conseillée

```text
source_packs/
|-- spear/
|   |-- spear_thrust.fbx
|   `-- spear_turn_guard.fbx
|-- bow/
|-- hammer/
`-- custom/
```

Un fichier peut contenir un ou plusieurs clips. Après ajout :

1. lancer `ANIMATIONS_1_REGENERER_MANIFESTE.bat` ;
2. ouvrir `ANIMATIONS_2_OUVRIR_BLENDER.bat` ;
3. assigner et valider le clip ;
4. lancer `ANIMATIONS_3_PUBLIER_JEU.bat`.

Les fichiers `.blend` sont des sources de travail. Pour une publication runtime
fiable et portable, exporter également l'action validée en GLB depuis le
Workbench.
