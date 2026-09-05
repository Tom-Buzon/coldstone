# Lobby Forge et hub de portails

## Objectif

Faire de `user://hoplite_worlds/lobbyy.hoplite.json` le monde d'accueil du jeu sans dupliquer son decor dans une scene Godot. Les transforms des portails restent donc editables et sauvegardables depuis la Forge.

## Scene tree cible

```text
HopliteWorldLobby (Node3D)
├── LobbyRuntime (HopliteWorldRuntime)
│   ├── EditableWorld
│   └── WorldTestPlayer
├── LobbyPortalHub (HopliteWorldPortalHub)
│   ├── interactions Forge et Campagne (sur les props auteurs)
│   └── district dynamique Stand + mondes sauvegardes
└── LobbyUI (CanvasLayer)

UALNativeCombatLab (Node3D)
└── LobbyReturnPortal (HopliteWorldPortalHub)
```

## Responsabilites et donnees

- Le fichier `lobbyy.hoplite.json` possede le decor, le spawn joueur et cinq props balises par `portal_role` : un `world_editor`, trois `official_campaign` et un `saved_worlds_anchor`.
- Dans l'inspecteur Forge, chaque portail de campagne peut etre deplace puis reaffecte a `grand_siege`, `procedural_campaign` ou `last_flame`. Son libelle reste personnalisable.
- La prop `saved_worlds_anchor` est elle aussi deplacable dans la Forge. Ses colonnes et espacements configurent le district genere : le Stand occupe la premiere place, puis viennent les mondes crees dans la Forge.
- `HopliteWorldLobby` charge toujours ce fichier depuis `user://`, puis construit le runtime Forge normal. Si le fichier manque ou est invalide, il revient proprement au stand de tir.
- `HopliteWorldPortalHub` lit les transforms des props balises dans le document. Les interactions suivent ainsi les deplacements faits plus tard dans la Forge.
- L'ancre `saved_worlds_anchor` donne l'origine, l'orientation et l'espacement du district. Le premier portail mene au stand de tir, les suivants aux mondes sauvegardes, en excluant `lobbyy` pour eviter une boucle.
- Le stand de tir conserve son catalogue Forge/mondes existant avec les meshes specialisees, exclut `lobbyy` de la liste generique et ajoute un portail dedie vers le lobby avec la mesh `portal_saved_world`.

## Flux

```text
Demarrage -> lobby.tscn -> charge lobbyy -> construit WorldRuntime
                                  |
                                  +-> role world_editor -> world_editor.tscn
                                  +-> 3 roles official_campaign -> campagne affectee
                                  +-> saved_worlds_anchor[0] -> combat_lab.tscn
                                  +-> saved_worlds_anchor[n] -> world_play.tscn + hoplite_world_path

combat_lab.tscn -> portail retour -> lobby.tscn
```

## Taches et competences

- [x] Charger le lobby sauvegarde et gerer le repli vers le stand.
  Skills: `save-load`, `gdscript-patterns`, `scene-organization`
- [x] Rendre le hub de portails configurable et attacher des `Area3D` aux props auteurs.
  Skills: `physics-system`, `3d-essentials`, `gdscript-patterns`
- [x] Baliser les deux portails existants, ajouter deux portails de campagne et l'ancre des mondes dans `lobbyy` avec sauvegarde atomique.
  Skills: `save-load`
- [x] Ajouter les probes de flux et effectuer la revue Godot finale.
  Skills: `godot-testing`, `godot-debugging`, `godot-code-review`
