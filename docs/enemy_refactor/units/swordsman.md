# Audit final — `swordsman`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

Date de contrôle : 2026-08-26\
Périmètre : archétype canonique exact `swordsman`, fichiers centraux inspectés en lecture seule.\
Verdict : **DONE** — construction, identité, rig, anatomie 12/12, équipement, action statique, navigation, démembrement et teardown disposent de preuves vertes. Les limites de mesure et deux défauts de la planche visuelle sont documentés ci-dessous et ne contredisent pas les contrats runtime testés.

## Identité et construction

- Identifiant canonique : `swordsman`; nom affiché : `SWORDSMAN`; famille de migration : `legacy_standard`; rôle de manifeste : `troop`.
- Profil source : `scripts/enemy/enemy_archetypes.gd`. Le profil est copié profondément à chaque lecture; le cache typé est porté par `HopliteEnemyArchetypes.data()`.
- Point de construction unique : `HopliteEnemyFactory.spawn()` / `spawn_request()`, qui construit un `HopliteAthenianEnemy`, applique l'identité, la position, les cibles, la faction, le mode de foule et les options, puis ajoute le nœud au parent.
- `_ready()` applique le profil avant collider, visuel et navigation; l'ordre observé est profil → capsule → mannequin/rig → anatomie/équipement → colliders optionnels → navigation → groupes/signaux.
- Groupes attendus pour l'ennemi hostile : `enemy`, `athenian`, `damageable`, `combatant`; avec IA : `combatant_ai`, `enemy_ai`.
- Risque de compatibilité conservé : un `swordsman` créé avec `is_miniboss=true` est remappé en `captain` dans `_ready()`. Les helpers Battles 01/02 passent explicitement `false` aux soldats ordinaires; le probe factory-options couvre par ailleurs ce comportement historique.
- Preuves de route : `ENEMY_FACTORY_ROUTE_PROBE PASS: all runtime enemy construction routes through the canonical factory` et `BATTLE_ENEMY_SPAWN_PROBE PASS: hostile and Spartan helper contracts preserved`.

## Profil de jeu et combat

| Contrat | Valeur effective |
|---|---:|
| Santé | `105.0` |
| Vitesse | `4.9` |
| Dégâts | `14.0` |
| Portée de profil | `1.72` |
| Aggro | `20.0` |
| Arme | `sword`, échelle `1.0` |
| Bouclier | oui, échelle `1.0` |
| Comportement | `aggressive` |
| Style d'attaque | `light_mix` |
| Wind-up / recovery | `0.24 s` / `0.25 s` |
| Cooldown | `0.86–1.12 s` |
| Vitesse d'animation d'attaque | `1.16` |
| Bande préférée | `0.0–1.65 m` |

- Le profil n'énumère pas de `combat_pattern`; le roster le qualifie donc `action=static`. L'attaque conserve néanmoins le scheduler partagé : permission d'attaque, wind-up, résolution par distance/arc, recovery et cooldown.
- Pour une attaque mêlée sans étape spéciale, la résolution ajoute `0.48 m` à la portée de profil, vérifie l'arc frontal (`dot >= 0.10`) puis appelle `receive_enemy_hit()` ou `receive_ai_hit()` avec `14.0` dégâts avant multiplicateurs éventuels.
- Le bouclier visible est aussi mécanique : le profil est normalisé en `defense=shield`, avec chance `0.30`, durée `0.68 s`, cooldown `1.55 s`, dégâts `×0.20`, section `×0.12`, garde `78`, régénération `18/s` après `1.30 s`. Le hitbox de bouclier est attaché à la main gauche et n'est actif que pendant la garde.
- Le bras droit sectionné libère l'épée; le bras gauche libère le bouclier. La perte des membres est aussi reflétée dans l'état de blessure, la vitesse et la capacité d'attaque.
- Preuves transverses disponibles : `ENEMY_ACTION_STATE_PROBE PASS` (priorité garde/recovery/wind-up/parade/tactique) et `ENEMY_COMBAT_PROBE PASS` (garde, guard-break, parade, patterns élite).

## Navigation et routes

- Le mode attendu et observé est `DIRECT_STEERING`. `swordsman` n'est ni phalange ni grand corps; aucun `NavigationAgent3D` n'est créé pour ce mode.
- À chaque décision tactique, le contrôleur transmet la destination au composant, échantillonne un intent horizontal, ajoute la séparation de foule, accélère vers la vitesse désirée puis appelle `move_and_slide()`.
- Détection de blocage : suivi du progrès, tentative latérale alternée, récupération `0.48 s`, vitesse `×0.72`, trois tentatives par défaut. Le composant commun est vert : `ENEMY_NAVIGATION_COMPONENT_PROBE PASS: intent, formation, fallback and recovery`.
- Le réglage de progression minimale est unifié sous `minimum_progress_speed`; le contrôleur et le composant consomment la même valeur. Le probe de récupération passe avec la configuration réellement transmise.
- Limite de conception : `DIRECT_STEERING` ne calcule pas de chemin NavMesh; les obstacles complexes relèvent du steering, de `move_and_slide()` et de la récupération. Le roster valide ce mode comme contrat voulu, pas une capacité de pathfinding.
- Routes primaires du manifeste : `battle_01`, `battle_02`. Battle 01 place des swordsmen dans les groupes de capitaines, la ligne avancée, trois rencontres urbaines et les renforts spartiates. Battle 02 étend Battle 01, réutilise ses helpers factory et emploie `swordsman` dans la bataille extérieure, les formations alliées, deux quartiers et les renforts. Les soldats de masse utilisent `mass_battle_mode=true`.

## Rig, donneurs et animations

- Type runtime observé : `direct_mixamo`. Le pool normal contient `smallsbir1`, `smallsbir3`, `smallsbir6`; le pool de masse est volontairement limité à `smallsbir1`.
- Sélection : index borné issu de `guard_index`, `get_instance_id()` et la taille du pool. Cela donne de la variété, mais l'apparence exacte hors mode masse n'est pas reproductible par seed métier seule.
- Échelles visuelles normalisées : `smallsbir1=0.8968`, `smallsbir3=0.9912`, `smallsbir6=1.003`; offset sol `-0.055`. Le `CharacterBody3D` reste à l'échelle `1.0` pour cet archétype.
- Inspection GLB brute :

| Modèle | Taille | Skins / joints | Meshes | Animations embarquées |
|---|---:|---|---:|---|
| `smallsbir1.glb` | `2,036,892` octets | `1 / 99` | `1` (`Vampire2`) | `mixamo_com` |
| `smallsbir3.glb` | `11,758,856` octets | `3 / 65,6,5` | `3` (corps, cheveux, barbe) | `Take 001`, `mixamo_com` |
| `smallsbir6.glb` | `11,945,820` octets | `1 / 65` | `1` (`Ch052`) | `Take 001`, `mixamo_com` |

- Le loader exige un `Skeleton3D` et un `AnimationPlayer`, résout les deux os de main, installe une bibliothèque `mixamo` puis attache épée et bouclier au squelette. Le roster prouve squelette non vide, AnimationPlayer non vide et mains gauche/droite résolues.
- Clips installés : idle `mixamo/axe_block_idle`, locomotion `mixamo/run`, réaction `mixamo/hit_react`, taunt `mixamo/battlecry`, attaques `mixamo/zombie_attack`, `mixamo/mutant_punch`, `mixamo/sword_slash`.
- Idle et run sont forcés en boucle; réaction, taunt et attaques restent one-shot. Les pistes de translation dont le chemin contient `hips` sont supprimées afin que le `CharacterBody3D` reste l'autorité de déplacement.
- Le combat n'utilise pas de piste Call Method ni `animation_finished`; le scheduler temporel reste l'autorité et normalise la vitesse du clip sur wind-up+recovery. C'est cohérent avec le contrôleur existant, mais un changement de clip doit être revérifié contre la fenêtre de dégâts.

## Meshes, matériaux et pipeline d'assets

- Import des trois GLB : importer `scene`, tangentes assurées, LOD générés, shadow meshes générés, skins nommées, animations à `30 FPS`, pistes immuables supprimées, compression mesh non forcée à off.
- Les images sont embarquées dans les GLB. Les sidecars de scène ne publient pas une mesure indépendante de VRAM, de compression finale des textures ou de mipmaps; ces métriques restent hors preuve de cet audit.
- Hors mode masse, le pool peut charger deux variantes d'environ `11.8–11.9 MB` chacune; en foule, la restriction à `smallsbir1` (~`2.04 MB`) évite ce cumul de textures haute résolution.
- Épée et aspis sont procéduraux pour ces modèles : primitives `BoxMesh`/`CylinderMesh`/`SphereMesh` et matériaux bronze/acier. Le bouclier possède un boss central lisible et un `Area3D` de contact mécanique.
- Les imports sont des GLB natifs, les caches `.godot/imported` ne sont jamais la source éditée, et les sidecars `.glb.import` sont présents.

## Anatomie — 12 zones

Toutes les zones ci-dessous sont présentes dans les définitions, l'état runtime et le mapping squelette. Le roster rapporte `anatomy=12/12` sans os manquant.

| Zone | Forme / rayon | Dégâts | Section | Seuil | Conséquence |
|---|---|---:|---:|---:|---|
| `head` | sphère `0.25` | `×1.70` | `×1.00` | `64` | sectionnable, fatale |
| `neck` | capsule `0.15` | `×1.85` | `×1.35` | `56` | sectionne `head`, fatale |
| `torso` | capsule `0.34` | `×1.00` | `×0.35` | `9999` | non sectionnable |
| `pelvis` | capsule `0.30` | `×0.95` | `×0.30` | `9999` | non sectionnable |
| `upper_arm_l` | capsule `0.16` | `×0.78` | `×1.00` | `78` | sectionnable; désactive l'avant-bras, lâche le bouclier |
| `forearm_l` | capsule `0.14` | `×0.75` | `×1.10` | `60` | sectionnable; lâche le bouclier |
| `upper_arm_r` | capsule `0.16` | `×0.78` | `×1.00` | `78` | sectionnable; désactive l'avant-bras, lâche l'épée |
| `forearm_r` | capsule `0.14` | `×0.75` | `×1.10` | `60` | sectionnable; lâche l'épée |
| `thigh_l` | capsule `0.21` | `×0.88` | `×0.82` | `94` | sectionnable; désactive le tibia |
| `shin_l` | capsule `0.18` | `×0.84` | `×1.05` | `72` | sectionnable |
| `thigh_r` | capsule `0.21` | `×0.88` | `×0.82` | `94` | sectionnable; désactive le tibia |
| `shin_r` | capsule `0.18` | `×0.84` | `×1.05` | `72` | sectionnable |

- `AnatomyHitbox` est un `Area3D` sur le masque brut `8`, monitorable mais non monitoring. Chaque zone porte une primitive et suit ses os en `_physics_process()`; la géométrie debug est créée seulement à la demande.
- Une section met à jour `zone_state`, désactive les zones descendantes, réduit la chaîne d'os à `0.001`, génère sang + proxy détaché, traite la perte d'équipement et tue sur tête/cou.
- Preuve dédiée fraîche : `ENEMY_UNIT_DISMEMBERMENT_PROBE PASS id=swordsman zones=12 severed=10`. Le probe crée une instance propre par zone, impose un sever damage de `100000`, vérifie dommage local, état sectionné/non sectionné, fatalité, apparition d'un proxy et chute de l'équipement approprié.

## Physique et cycle de vie

- Corps : `CharacterBody3D`, couche brute `4`, masque `1|2` avec IA (`1` sans IA). Capsule primitive, rayon `0.39`, hauteur `1.82`, centre Y `0.91`; aucune mise à l'échelle du corps pour `swordsman`.
- Les ennemis ne se collisionnent pas entre eux; la séparation de foule remplace ces paires coûteuses. Monde et joueur restent dans le masque.
- L'anatomie emploie uniquement sphères/capsules. Les dimensions sont recalculées explicitement en mètres monde quand les transforms de zones sont écrits en coordonnées monde.
- À la mort : couches/masques et colliders sont désactivés, anatomie arrêtée, physique/process IA coupé, équipement lâché. Le système joue `Death01` s'il existe; sinon il fige le clip et applique un collapse tween déterministe. Il ne s'agit pas d'un ragdoll de squelette.
- Épée, bouclier et membres détachés deviennent des `RigidBody3D` avec impulsion. Le lifecycle commun les laisse physiques `4 s`, retire collisions/ombres puis les libère après `12 s` au total.
- Dette non bloquante au regard du skill physique : les couches 3D ne sont pas nommées dans `project.godot`, et certaines formes d'équipement sont orientées/offsettées par leur nœud `CollisionShape3D`; cela perd l'optimisation réservée aux formes non transformées, sans échec fonctionnel observé.
- L'interpolation physique n'est pas explicitement activée dans `project.godot`; aucun test de cet audit ne revendique donc une preuve de lissage interpolé.

## Performance structurelle disponible

- Optimisations actives : pool de modèle réduit en masse, cache global des `Animation` Mixamo, racine du personnage autoritaire pour le root motion, séparation sans collisions ennemi/ennemi, fréquence tactique adaptative, anatomie désactivée hors combat, cadence anatomique LOD, LOD de rendu/culling, ombres secondaires coupées, debug meshes/labels paresseux, retraite du runtime de cadavre et lifecycle borné des débris.
- Baseline reproductible `swordsman`, headless, Godot `4.7.stable.official.5b4e0cb0f`, seed `13371`, mode masse, 120 warm-up + 120 ticks :

| Scénario | Spawn médian | Snapshot structurel | Tick p95 médian | Teardown |
|---|---:|---|---:|---|
| 12 idle | `348.708 ms` | `378` nœuds, `2,226` objets | `20.705 ms` | PASS |
| 12 active | `345.411 ms` | `378` nœuds, `2,227` objets, `12` corps actifs | `20.696 ms` | PASS |
| 56 idle | `755.942 ms` | `1,742` nœuds, `4,646` objets | `20.701 ms` | PASS |
| 56 active | `754.117 ms` | `1,742` nœuds, `4,647` objets, `56` corps actifs | `20.717 ms` | PASS |

- Les quatre scénarios reviennent à zéro combatant et zéro référence ennemie vivante, avec zéro orphelin au snapshot.
- Limites : cette baseline est structurelle/headless et non un gain avant/après; elle ne mesure ni draw calls, ni VRAM, ni FPS d'une bataille rendue, ni coût répété de 12 sections par unité. Le document de performance classe encore ces mesures comme pendantes.

## Inspection visuelle

Preuve inspectée : `docs/enemy_refactor/visual_evidence/swordsman.png`, `1351×760`; log `ENEMY_UNIT_VISUAL_EVIDENCE PASS`.

- `IDLE NU` et `JOG NU` : deux silhouettes sans équipement sont visibles et distinctes, ce qui permet de lire le corps et la pose; le jog est plus incliné/dynamique.
- `ATTAQUE` : posture basse et offensive, épée en avant; la silhouette est lisible mais le bouclier/arme se superposent fortement au torse.
- `IMPACT` : réaction protégée par l'aspis, clairement différenciée de l'attaque.
- `MORT` : corps au sol, épée/bouclier relâchés; la mort n'est pas restée debout.
- `SECTION` : membre droit supprimé et équipement dissocié, avec acteur toujours debout pour une section non fatale.
- Défauts de capture non bloquants : des particules rouges persistent entre les colonnes Jog/Attaque, et de petits artefacts colorés sont coupés au bord droit. La planche prouve les états, mais n'est pas une capture marketing propre.
- Limite du harness visuel : pour les colonnes nues, il demande d'abord les noms génériques `Idle` / `Jog_Fwd` ou `Walk`, alors que le runtime direct Mixamo utilise normalement `mixamo/axe_block_idle` / `mixamo/run`. La planche est une preuve de silhouette/pose, tandis que le log roster et l'installation de la bibliothèque sont les preuves autoritaires des clips runtime.

## Tests et preuves exactes

Commande dédiée exécutée avec log absolu :

```powershell
& 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\Users\suean\Downloads\hoplite_ual_native_lab_v2' --script res://tools/enemy_unit_dismemberment_probe.gd --log-file 'C:\Users\suean\Downloads\hoplite_ual_native_lab_v2\.tmp_tools\enemy_refactor\logs\dismember_swordsman.log' -- --id=swordsman
```

Résultat frais : exit `0`; `ENEMY_UNIT_DISMEMBERMENT_PROBE PASS id=swordsman zones=12 severed=10`.

Résultat commun consulté :

```text
ROSTER_VALIDATE id=swordsman family=legacy_standard rig=direct_mixamo anatomy=12/12 equipment=sword+shield action=static navigation=DIRECT_STEERING
ENEMY_FULL_ROSTER_VALIDATION_PROBE PASS: 22/22 identities, rigs, anatomy, equipment, actions, navigation modes and teardown
```

Autres preuves consultées :

- `ENEMY_UNIT_VISUAL_EVIDENCE PASS id=swordsman output=res://docs/enemy_refactor/visual_evidence/swordsman.png size=(1351, 760)`
- `ENEMY_ACTION_STATE_PROBE PASS: guard, recovery, wind-up, parry and tactical priority preserved`
- `ENEMY_COMBAT_PROBE PASS: guard, break, parry and elite patterns`
- `ENEMY_NAVIGATION_COMPONENT_PROBE PASS: intent, formation, fallback and recovery`
- `ENEMY_FACTORY_ROUTE_PROBE PASS: all runtime enemy construction routes through the canonical factory`
- `BATTLE_ENEMY_SPAWN_PROBE PASS: hostile and Spartan helper contracts preserved`

Tous les logs Godot headless affichent aussi `ERROR: Failed to read the root certificate store.` sur Windows. Le moteur continue, les probes terminent avec exit `0`, et aucun test concerné n'effectue d'accès TLS; cette ligne est donc une limite d'environnement, pas un échec du `swordsman`.

## Limites finales et décision

- Pas de test unitaire propre au `swordsman` qui mesure directement la baisse de santé de la cible après la résolution d'une attaque statique; l'état/scheduler est couvert par le probe d'action et la pose par la planche visuelle, tandis que le roster ne vérifie ici que la justification statique (`damage > 0`, delivery valide).
- Pas de test rendu automatisé de clipping arme/bouclier sur les trois variantes du pool ni de métrique VRAM/draw calls.
- Pas de stress test dédié à des démembrements répétés; le probe unitaire couvre exhaustivement les 12 zones une fois chacune et valide le teardown par instance.
- La navigation directe est conforme au roster mais ne doit pas être présentée comme navigation NavMesh.

**Décision : DONE.** Aucun défaut observé ne casse le contrat demandé de l'archétype. Les preuves autoritaires sont vertes, les 12 zones sont toutes mappées, les dix zones sectionnables produisent leur conséquence, et les deux zones centrales restent non sectionnables. Les réserves ci-dessus sont des améliorations de couverture, de capture et de configuration commune, pas des bloqueurs fonctionnels de `swordsman`.

### Clôture transversale post-audit

Les limites de couverture formulées pendant l'audit initial ont depuis été fermées par les probes centraux : `enemy_unit_behavior_probe --id=swordsman` vérifie la résolution réelle de l'attaque, l'interruption au désarmement, la perte de cible et le cycle sleep/wake ; `enemy_mixamo_variant_matrix_probe --id=swordsman` valide les trois modèles du pool et leurs 36 zones cumulées ; `enemy_animation_lod_probe` valide le chemin direct Mixamo à 30/12/0 Hz et son réveil. La navigation directe reste le contrat déclaré de cette unité et possède désormais une récupération anti-blocage commune bornée.
