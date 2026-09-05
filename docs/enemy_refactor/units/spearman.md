# Audit final — `spearman`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable, build officiel `5b4e0cb0f`**\
**Portée : état courant du worktree; fichiers runtime centraux examinés en lecture seule.**

## Synthèse

`spearman` est un fantassin de portée historique, armé d'une dory et d'un aspis, construit par la factory canonique. Son profil est cohérent avec un combattant léger de deuxième cercle : 115 PV, vitesse 4,25 m/s, dégâts 19, portée mécanique 2,62 m, bande tactique 1,55–2,42 m, défense au bouclier normalisée et attaque statique `poke`.

L'identité documentaire `legacy_phalanx` décrit sa famille et son équipement, pas son comportement runtime. Le profil porte `behavior = reach`; l'unité ne rejoint donc pas `phalanx_unit`, n'utilise ni les slots de cohorte ni `FORMATION_LOCAL`, et navigue en `DIRECT_STEERING`. Les véritables profils de phalange restent `ngeneral` et `ngeneral_veteran`.

Les contrats fonctionnels, anatomiques, d'équipement, de construction et de teardown passent. Les réserves restantes sont qualitatives : clips d'attaque Mixamo non spécifiques à la lance et légère mise à l'échelle du `CharacterBody3D`.

## Construction et identité

- Source de vérité : `scripts/enemy/enemy_archetypes.gd:208-231`; ID canonique présent dans l'ordre des 22 profils (`:90-93`).
- Profil exact :

| Champ | Valeur |
|---|---:|
| `display_name` | `SPEARMAN` |
| `skin` / échelle | `spearman` / `1.03` |
| PV / vitesse | `115.0` / `4.25` |
| dégâts / portée / aggro | `19.0` / `2.62` / `22.0` |
| arme / échelle | `spear` / `1.0` |
| bouclier / échelle | `true` / `0.92` |
| comportement / style | `reach` / `poke` |
| windup / recovery | `0.31` / `0.32` |
| cooldown | `1.04–1.34` |
| vitesse d'animation | `1.08` |
| bande préférée | `1.55–2.42` |

- Le bouclier sans champ `defense` explicite est normalisé en `shield` avec fenêtre, cooldown, multiplicateurs, garde et réaction (`enemy_archetypes.gd:57-72`). Le probe roster confirme `spear+shield`, action `static` et navigation `DIRECT_STEERING`.
- Toute création runtime passe par `HopliteEnemyFactory.spawn_request()` : une instance de `HopliteAthenianEnemy`, métadonnée `procedural_archetype`, reçoit les options du `EnemySpawnRequest` puis est ajoutée au parent (`scripts/enemy/enemy_factory.gd:47-88`). Le probe de route interdit les constructions directes hors factory.
- Dans `_ready()`, le profil est appliqué avant collision, rendu et IA; viennent ensuite capsule, mannequin, volumes physiques, navigation et groupes (`scripts/enemy/athenian_enemy.gd:313-358`).

## Combat

- `behavior = reach` calcule un anneau d'engagement puis recule sous 1,55 m, avance au-delà de 2,42 m et tient la position dans la bande (`athenian_enemy.gd:797-835`). Une attaque est refusée sous `preferred_min * 0.74`, soit environ 1,15 m (`:3770-3783`).
- Le profil n'a pas de `combat_pattern`; il utilise donc le contrat statique : windup 0,31 s, résolution de mêlée à 2,62 m (+ marge générique), recovery 0,32 s, cooldown aléatoire 1,04–1,34 s. Le full-roster probe valide explicitement `action=static`.
- `attack_style = poke` choisit le slot `light2`, documenté dans le code comme substitution jusqu'à une poussée de lance dédiée (`athenian_enemy.gd:1688-1697`). Sur un visuel Mixamo, l'attaque tombe ensuite dans le pool direct `vertical_sword`, `sword_slash`, `zombie_attack` (`scripts/enemy/mixamo_catalog.gd:76-85`).
- La défense à l'aspis est réelle : fenêtre réactive, ralentissement à 42 %, hitbox activée seulement pendant la garde, réduction de dégâts/section et garde cassable (`athenian_enemy.gd:1350-1435`, `:3317-3382`). La perte du bras/avant-bras gauche lâche le bouclier; le côté droit lâche la dory (`:3501-3508`).
- L'attaque passe par le scheduler partagé de permissions, ce qui borne les assauts simultanés. `spearman` ne reçoit toutefois pas la limite de deux attaques propre aux vraies unités de phalange (`athenian_enemy.gd:1906-1941`).

## Navigation et phalange

- Mode exact : `DIRECT_STEERING`. `_is_phalanx_unit()` ne reconnaît que `phalanx` et `phalanx_veteran`; `reach` n'est donc pas un mode de phalange (`athenian_enemy.gd:925-929`). La factory de navigation choisit `DIRECT_STEERING` par défaut et réserve `FORMATION_LOCAL` aux deux comportements de phalange (`:674-691`).
- Le composant fournit destination, arrivée à 0,28 m, détection d'immobilité, esquive latérale de récupération et signal d'échec après épuisement. En mode direct il ne crée pas de `NavigationAgent3D`; il suit le vecteur aplati vers la cible et laisse `CharacterBody3D.move_and_slide()` résoudre le monde (`scripts/ai/enemy_navigation_component.gd:49-151`, `:184-220`). Il n'y a donc ni recherche de chemin navmesh ni RVO pour cet archétype.
- En foule, le directeur d'engagement attribue un anneau persistant et la séparation locale évite la convergence sur l'origine de la cible (`athenian_enemy.gd:808-820`, `:639-671`). La récupération de blocage est assurée par le composant.
- `legacy_phalanx` dans `docs/enemy_refactor/roster_manifest.json:10` et dans le full-roster probe est une classification historique. La dory/aspis est partagée avec la phalange, mais `spearman` ne reçoit pas : slots/cohorte, garde permanente de formation, orientation de rang, limite d'attaque par paire, couche 64 de mur de boucliers ou bonus de vétéran.
- Le système de phalange lui-même a été vérifié séparément : assemblage, avance collective et équipement passent dans `enemy_roster_audit.gd` et `phalanx_equipment_probe.gd`. Cela ne change pas le mode exact de `spearman`.

## Rig, modèles et donneurs

- Route hostile standard : aucun `package_candidate`; `_load_mannequin()` sélectionne directement un GLB Mixamo dans le pool `smallsbir2` / `sorcer1`, tous deux normalisés à `0.76 * 1.18`, avec offset sol `-0.055` (`mixamo_catalog.gd:9-50`, `:90-100`; `athenian_enemy.gd:2825-2879`).
- Le full-roster probe qualifie le rig `direct_mixamo`; squelette, `AnimationPlayer`, main droite et main gauche sont tous résolus. Le roster audit a sélectionné `sorcer1.glb` sur son échantillon déterministe.
- Donneurs externes : **0**. Il n'y a ni `external_animation_keys`, ni bridge UAL1/UAL2, ni `native_animation_driver` pour ce profil direct Mixamo. `install_personality()` ajoute au `AnimationPlayer` du modèle une bibliothèque issue du cache statique de clips (`mixamo_catalog.gd:88-139`).
- Route alliée spartiate : `_apply_archetype_profile()` change couleur/skin/faction, et `_load_mannequin()` saute le catalogue Mixamo quand `faction == spartan`; elle conserve la base UAL1 légère. Les helpers Battle imposent `mass_battle_mode`, donc pas de driver lourd par allié (`athenian_enemy.gd:441-445`, `:2835-2879`; `scripts/battle/battle_01.gd:370-384`).
- La capture de six états instancie six acteurs distincts; la variation de silhouette entre colonnes est donc compatible avec le pool de deux modèles et ne constitue pas un changement de rig en cours de vie.

## Dory, aspis et rendu

- `spearman` figure explicitement dans `IMPORTED_PHALANX_GEAR_ARCHETYPES` (`athenian_enemy.gd:25-29`). `_make_spear()` instancie `res://assets/weapons/dory_spear.glb` et exige `SM_Dory_Spear`; `_make_shield()` fait de même avec `aspis_shield.glb` / `SM_Aspis_Shield` (`:4374-4377`, `:4521-4563`).
- Attaches validées : dory sur la main droite, aspis sur la main gauche, échelles profilées 1,0 et 0,92; l'aspis porte `PhysicalShieldHitbox`. Le probe équipement vérifie également une dory couvrant au moins `y < -0.88` à `y > 1.78` et un aspis de plus de 0,90 m sur X/Y.
- Imports glTF : tangentes, LOD générés, shadow meshes et suppression des tracks immuables sont actifs dans les deux `.glb.import`. Les fichiers source pèsent environ 59,4 KiB (dory) et 141,1 KiB (aspis); ils sont préchargés une fois dans le contrôleur.
- En `mass_battle_mode`, les ombres du visuel sont coupées au chargement. Le LOD runtime règle `lod_bias`, coupe ombres/particules à distance et applique un cull à 90 m par défaut (`athenian_enemy.gd:1479-1588`, `:2872-2875`).
- Le fallback legacy du skin `spearman` ajoute linothorax, casque pilos et jupe cuir (`athenian_enemy.gd:3957-3968`). Sur la route hostile Mixamo effectivement validée, le vêtement du GLB source reste visible et la dory/aspis importée assure la lecture de rôle.

## Anatomie — 12 zones

Toutes les zones sont présentes dans `anatomy_defs`, `zone_state` et `anatomy.zone_runtime`, sans os manquant :

| Zone | Forme | Multiplicateur dégâts | Seuil section | Conséquence |
|---|---|---:|---:|---|
| `head` | sphère | 1,70 | 64 | sectionnable, fatal |
| `neck` | capsule | 1,85 | 56 | sectionne `head`, fatal |
| `torso` | capsule | 1,00 | 9999 | non sectionnable |
| `pelvis` | capsule | 0,95 | 9999 | non sectionnable |
| `upper_arm_l` | capsule | 0,78 | 78 | sectionnable, fait perdre l'aspis |
| `forearm_l` | capsule | 0,75 | 60 | sectionnable, fait perdre l'aspis |
| `upper_arm_r` | capsule | 0,78 | 78 | sectionnable, fait perdre la dory |
| `forearm_r` | capsule | 0,75 | 60 | sectionnable, fait perdre la dory |
| `thigh_l` | capsule | 0,88 | 94 | sectionnable, neutralise aussi le tibia lié |
| `shin_l` | capsule | 0,84 | 72 | sectionnable |
| `thigh_r` | capsule | 0,88 | 94 | sectionnable, neutralise aussi le tibia lié |
| `shin_r` | capsule | 0,84 | 72 | sectionnable |

Source : `scripts/enemy/anatomy_profile.gd:8-77`. Le probe exact confirme `zones=12 severed=10`; les deux non-sectionnables sont bien torse et bassin. Le cou redirige vers la tête, ce qui explique 10 zones d'entrée sectionnables mais neuf états de membre distincts. Chaque section produit une preuve détachée/équipement, enregistre les dégâts localisés et respecte la fatalité attendue.

## Physique

- Corps : `CharacterBody3D`, couche 4, masque monde + joueur quand l'IA est active; aucune collision ennemi-ennemi, volontairement remplacée par la séparation de foule (`athenian_enemy.gd:321-326`). Capsule primitive de rayon 0,39 et hauteur 1,82 (`:2470-2482`).
- Anatomie : `Area3D`, couche 8, masque 0, `monitoring=false`, `monitorable=true`; douze sphères/capsules suivent les os. Les dimensions sont recalculées à partir de l'échelle monde au lieu de scaler les `Shape3D` (`scripts/enemy/anatomy_hitbox.gd:14-34`, `:92-148`).
- Aspis : `Area3D` avec `CylinderShape3D` de rayon 0,48 et épaisseur 0,13, couche 8 seulement pendant la garde. Comme `spearman` n'est pas une unité de phalange runtime, la couche expérimentale 64 de wall-run n'est jamais ajoutée (`scripts/enemy/shield_hitbox.gd:12-46`).
- Débris : armes, boucliers et membres deviennent des `RigidBody3D` sur couche 16 / masque monde 1, peuvent dormir, puis perdent collision et ombres après 4 s avant libération à 12–14 s (`scripts/gore/transient_rigid_debris_lifecycle.gd:34-60`).
- Réserve de revue : `scale = Vector3.ONE * 1.03` est appliqué au `CharacterBody3D`. Il est uniforme et faible, et les volumes anatomiques compensent explicitement l'échelle, mais le guide physique recommande de dimensionner la capsule directement plutôt que scaler un corps physique. Aucun défaut n'a été observé dans les probes; c'est une dette structurelle non bloquante.

## Performance structurelle

- Points favorables : factory unique; profils/resources mis en cache; bibliothèque Mixamo en cache statique; deux modèles seulement dans le pool de masse; GLB dory/aspis préchargés; pas de driver/bridge/donneur externe par `spearman`; ennemis sans collision mutuelle; cadence de réflexion 0,055/0,10/0,18 s en masse; anatomie endormie hors combat; LOD animation/rendu/particules; débris temporaires et cadavres retirés du process.
- Coût structurel restant : chaque unité conserve un squelette/`AnimationPlayer`, 12 `CollisionShape3D` anatomiques, un composant de navigation, deux équipements importés et une hitbox de bouclier. À 56 unités actives, c'est le nombre de nœuds/volumes plutôt que les donneurs d'animation qui domine.
- Benchmark reproductible exécuté avec `--counts=1,56 --mode=both --warmup=30 --frames=60 --archetype=spearman --registry=on` : **PASS**, teardown structurel propre, 0 référence ennemie vivante et 0 orphelin après chaque scénario. Pour 56 actifs : 1 799 nœuds, 4 395 objets, 56 objets physiques actifs, ~168,4 MB de mémoire statique pendant le scénario, spawn ~1 285 ms, tick physique p95 ~20,72 ms / max ~27,19 ms. Ces mesures headless courtes sont diagnostiques, pas un seuil de régression ni un profil GPU.

## Preuve visuelle

Capture inspectée : `docs/enemy_refactor/visual_evidence/spearman.png`.

- `IDLE NU` et `JOG NU` cachent volontairement l'équipement dans le générateur de preuve; ils valident silhouette, sol et locomotion, pas l'absence d'arme.
- `ATTAQUE` montre une dory longue bien attachée mais levée presque verticalement : l'action est lisible, toutefois moins crédible qu'une poussée horizontale de hoplite.
- `IMPACT` rend clairement l'aspis bronze et la réaction du corps; la plaque reste solidaire de la main.
- `MORT` montre corps au sol et dory détachée; `SECTION` montre perte du bras droit, sang et dory relâchée. Les états sont distincts et ne montrent ni membre resté rigidement attaché ni équipement flottant durablement.
- Quelques particules rouges apparaissent hors de la plateforme/cadre; c'est une composition de preuve chargée, pas un défaut de contrat de l'unité.

## Routes vérifiées

- Manifest : Battles 01/02 et alliés spartiates (`roster_manifest.json:10`).
- Battle 01 : gardes de capitaines, ligne avant, trois rencontres urbaines, garde finale et quatre alliés spartiates (`scripts/battle/battle_01.gd:326-368`, `:402-478`).
- Battle 02 : cohortes de masse, front principal, quatre files alliées et renforts (`scripts/battle/battle_02.gd:158-193`, `:332-346`). Battle 02 hérite de Battle 01, donc des helpers factory communs.
- Les routes hostiles et alliées convergent toutes sur `EnemyFactory.spawn_request()`; `enemy_factory_route_probe` et `battle_enemy_spawn_probe` passent, notamment l'identité/faction/mode de masse de l'allié `spearman`.
- `spearman` n'appartient pas au catalogue procédural de remplacement (`ROSTER_IDS`) et n'est pas une entrée Forge/Combat Lab principale; aucune route procédurale implicite n'est revendiquée.

## Tests exécutés

| Test | Résultat | Preuve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=spearman` | PASS | `zones=12 severed=10`; log `C:\Users\suean\AppData\Local\Temp\hoplite_spearman_dismemberment_final.log` |
| `enemy_full_roster_validation_probe.gd` | PASS | `22/22`; ligne `spearman`: `direct_mixamo`, `12/12`, `spear+shield`, `static`, `DIRECT_STEERING`; log `C:\Users\suean\AppData\Local\Temp\hoplite_enemy_full_roster_validation_final.log` |
| `phalanx_equipment_probe.gd` | PASS | dory/aspis importés, mains correctes, dimensions et hitbox; log `C:\Users\suean\AppData\Local\Temp\hoplite_spearman_phalanx_equipment_final.log` |
| `enemy_roster_audit.gd` | PASS | 22 profils cohérents + phalange assemblée/avance; log `C:\Users\suean\AppData\Local\Temp\hoplite_enemy_roster_audit_final.log` |
| `enemy_factory_route_probe.gd` | PASS | construction runtime exclusivement canonique; log `C:\Users\suean\AppData\Local\Temp\hoplite_enemy_factory_route_final.log` |
| `battle_enemy_spawn_probe.gd` | PASS | contrat hostile + allié `spearman`; log `C:\Users\suean\AppData\Local\Temp\hoplite_battle_enemy_spawn_final.log` |
| `enemy_performance_benchmark.gd` ciblé | PASS | 1/56, idle/active, registry on, teardown propre; log `C:\Users\suean\AppData\Local\Temp\hoplite_spearman_performance_structural_final.log` |

Tous les runs émettent sous Windows headless `Failed to read the root certificate store`; les processus sortent néanmoins avec code 0 et ce message n'affecte aucun test local d'ennemi.

## Limites et risques résiduels

1. **Sémantique de famille ambiguë** — `legacy_phalanx` peut laisser croire que `spearman` participe aux cohortes. Le contrat runtime/testé est `reach` + `DIRECT_STEERING`. Une migration vers la vraie phalange serait un changement de gameplay, pas une correction documentaire locale.
2. **Animation de lance non dédiée** — le fallback `light2` et les clips Mixamo d'épée/zombie ne garantissent ni ligne de poussée horizontale, ni synchronisation visuelle parfaite avec les 0,31 s de windup. La capture montre cette faiblesse sans invalider le hit mécanique.
3. **Variabilité visuelle** — deux corps Mixamo sont choisis par instance. La planche de six acteurs n'est pas une séquence d'un seul corps et peut exagérer l'incohérence de silhouette.
4. **Navigation sans navmesh** — le steering direct avec récupération latérale ne contourne pas intelligemment de grands obstacles; les Battles actuelles et le probe de route valident le contrat existant, pas un pathfinding général.
5. **Échelle du corps physique** — mise à l'échelle uniforme 1,03 au niveau racine; faible risque actuel, mais contraire à la préférence de dimensionnement direct des shapes.
6. **Benchmark court/headless** — les chiffres CPU/mémoire sont un échantillon structurel; ils ne remplacent ni profilage graphique en jeu ni seuil de performance homologué.

## Verdict

**DONE.** L'archétype exact `spearman` est constructible par toutes ses routes déclarées, conserve son identité, son profil de portée, son rig animé, sa dory/aspis physique, ses 12 zones anatomiques, ses pertes d'équipement et son teardown. Les sept validations exécutées sortent en code 0, la preuve visuelle couvre six états, et aucun blocage fonctionnel n'est observé.

Le verdict ne transforme pas `spearman` en hoplite de cohorte : sa classification `legacy_phalanx` reste historique/équipementière, tandis que son contrat effectif demeure `reach` + `DIRECT_STEERING`. L'authenticité de la poussée de lance et le pathfinding navmesh sont des améliorations futures non bloquantes.
