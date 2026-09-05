# Échange d’équipement et atelier de réglage des armes

## Architecture retenue

- Les fichiers `.tres` restent les valeurs de référence, donc les réglages utilisateur ne détruisent jamais les données d’origine.
- `HopliteWeaponTuning` charge et sauvegarde des overrides par `item_id` dans le `ConfigFile` global.
- Le joueur résout ces valeurs lors de chaque reconstruction d’arme et les applique en direct depuis le menu.
- Un pickup consommé recrée l’ancien équipement au même emplacement avant de disparaître.
- L’onglet **ARMES** sélectionne une arme et expose taille, pose en main, segment de contact, rayon et puissance.

## Plan d’implémentation

- [ ] Rapprocher le bouclier de la main.
  Skills: `godot-prompter:3d-essentials`, `godot-prompter:math-essentials`
- [ ] Ajouter les overrides persistants par arme.
  Skills: `godot-prompter:resource-pattern`, `godot-prompter:save-load`
- [ ] Construire l’onglet ARMES dans Paramètres.
  Skills: `godot-prompter:godot-ui`, `godot-prompter:input-handling`
- [ ] Recréer l’ancien équipement comme pickup au sol lors d’un échange.
  Skills: `godot-prompter:physics-system`, `godot-prompter:component-system`
- [ ] Valider les contacts, les dégâts, les échanges, la persistance et l’UI.
  Skills: `godot-prompter:godot-testing`, `godot-prompter:godot-debugging`, `godot-prompter:godot-code-review`
