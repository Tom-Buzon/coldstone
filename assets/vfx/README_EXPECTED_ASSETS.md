# Banque VFX de combat à fournir

La couche de feedback accepte déjà les événements `impact_flesh`,
`impact_metal`, `impact_shield`, `impact_wood` et `impact_stone`. En attendant
les ressources définitives, le bouclier utilise 12–18 étincelles, une micro
lumière et un disque d'impact procéduraux ; le sang directionnel existant reste produit par
`scripts/gore/blood_burst.gd`.

Ressources à créer ou trouver :

- `spark_shield_small` : 5–10 étincelles, 100–300 ms, directionnelles ;
- `spark_metal_light` et `spark_metal_heavy` : densités distinctes ;
- `dust_stone_small` : poussière très courte, sans flash global ;
- `splinter_wood_small` : éclats courts orientés par la normale ;
- `blood_spray_light`, `blood_spray_heavy` : sprays directionnels ;
- `blood_sever_burst` : burst initial de démembrement ;
- `blade_trail_light`, `blade_trail_heavy`, `blade_trail_spiral` : profils de
  largeur/durée distincts ;
- `heavy_charge_max` : effet stable indiquant clairement la charge maximale ;
- `parry_flash` : accent métal de 30–60 ms, très local ;
- decals optionnels `blood`, `blade_scratch_metal`, `stone_chip`.

Les futurs assets devront être affectés aux cues, mais leur absence n'empêche
ni les dégâts, ni le démembrement, ni le lancement du jeu.
