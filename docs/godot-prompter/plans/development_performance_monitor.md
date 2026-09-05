# Moniteur de performance de développement

## Objectif

Ajouter un panneau discret en haut à droite qui rend visibles les principaux
signaux de santé du runtime et qui peut être activé depuis
`Paramètres > Affichage > Éléments visuels`. L'état reste mémorisé dans les
réglages globaux existants.

## Architecture retenue

Le moniteur est un `PanelContainer` autonome construit par le
`HopliteAudioSettings` déjà présent dans tous les mondes jouables. Cette option
évite un nouvel Autoload et garantit que l'affichage suit le joueur entre le
laboratoire, les batailles, la campagne et les mondes Forge.

```text
HopliteAudioSettings (CanvasLayer, layer 100)
├── DevelopmentMonitor (PanelContainer, ancré en haut à droite)
│   └── Content (VBoxContainer)
│       ├── Header (HBoxContainer)
│       │   ├── StatusDot (Label)
│       │   ├── Title (Label)
│       │   └── Fps (Label)
│       └── Metrics (Label)
└── GlobalSettingsRoot (Control, plein écran, masqué hors menu)
    └── ... > AFFICHAGE > ELEMENTS VISUELS
        └── CheckButton MONITEUR DE PERFORMANCE (DEVELOPPEMENT)
```

## Responsabilités

| Élément | Responsabilité |
|---|---|
| `HopliteDevelopmentMonitor` | Échantillonner `Performance`, formater les valeurs et signaler les seuils FPS/orphelins. |
| `HopliteAudioSettings` | Posséder l'option utilisateur, créer le panneau, appliquer et sauvegarder son état. |
| `ConfigFile` global | Persister `display/development_monitor` entre les sessions. |

## Signaux et flux de données

Le `CheckButton.toggled(bool)` appelle `_on_visual_toggled`, qui met à jour
`visual_settings`, sauvegarde le `ConfigFile`, puis appelle
`DevelopmentMonitor.set_enabled(bool)`. Quand il est actif, le moniteur lit les
compteurs `Performance` toutes les 0,5 seconde; désactivé, son `_process` est
coupé et le panneau est masqué.

## Métriques

- FPS, temps de frame estimé et pic sur la fenêtre d'échantillonnage.
- Temps CPU de process et de physique.
- Appels de rendu, objets et primitives rendus.
- Nœuds vivants et nœuds orphelins.
- Mémoire statique et mémoire vidéo déclarée par le renderer.

## Validation

- Vérifier la construction, l'ancrage, l'absence d'interception souris et le
  rafraîchissement du texte en headless.
- Vérifier que l'option existe dans le menu global et que son état est appliqué
  au panneau.
- Lancer le probe des réglages globaux et les contrôles de parsing Godot.

Compétences : `godot-ui`, `hud-system`, `responsive-ui`, `save-load`, puis
`godot-code-review` pour la validation finale.
