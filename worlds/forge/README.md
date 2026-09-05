# Cartes Forge versionnées

`champsdebataille_v2_commandement_414.hoplite.json` contient le déploiement combiné de 414 unités validé le 5 septembre 2026.

La Forge utilise des copies de travail dans `user://hoplite_worlds/`. Sur Windows, pour ce projet : `%APPDATA%/Godot/app_userdata/Project Hoplite - UAL Native Combat Lab/hoplite_worlds/`. Copier la carte dans ce dossier puis la recharger dans la Forge. Sauvegarder une éventuelle copie locale avant de la remplacer.

Pour régénérer une copie révisable depuis la carte versionnée :

```powershell
python tools/enemy_v2/author_combined_arms_world.py --source worlds/forge/champsdebataille_v2_commandement_414.hoplite.json
```

Le générateur écrit dans `.tmp_tools/`, sans remplacer la carte jouée. Les nouvelles sauvegardes faites dans la Forge ne sont pas automatiquement reportées dans Git : recopier volontairement la version souhaitée ici avant le prochain commit.
