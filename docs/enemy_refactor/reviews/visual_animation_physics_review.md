# Contre-revue finale — rig, animation, visuel, physique et anatomie

**Verdict : DONE**

## Post-revue autoritaire — état courant du 26 août 2026

**Verdict final : DONE**

Cette section remplace le diagnostic d'état de la revue initiale ci-dessous. Les anciens P1 sur l'impact, la matrice à six états et le TTL des cadavres, ainsi que les P2 sur le faux positif sang/fragment et le masquage des équipements authorés, ont été corrigés. Le dernier blocker sur la preuve `boss_bronze__knight3` est maintenant levé.

### Dernier blocker levé — override `boss_bronze` factuel et vérifié

Le correctif sépare correctement intention explicite et route canonique :

- `scripts/enemy/athenian_enemy.gd:2932-2942` valide d'abord un `mixamo_model_override` appartenant au pool ; un override valide devient autoritaire avant le package ;
- un override cross-pool produit un dictionnaire vide, émet un warning et conserve la route package `bossbronze.glb` ;
- `tools/enemy_unit_visual_evidence.gd:76-82` refuse désormais de poursuivre et donc de sauvegarder si une instance ne vérifie pas simultanément `uses_mixamo_visual` et `mixamo_model_id == variant_override` ;
- la route standard sans override reste `package_retarget` et son comportement complet reste vert.

Runs frais indépendants :

```text
enemy_mixamo_variant_matrix_probe.gd -- --id=boss_bronze
PASS id=boss_bronze variants=3 zones=36

enemy_unit_behavior_probe.gd -- --id=boss_bronze
PASS id=boss_bronze far/close, attacks, interruption, target-loss, sleep/wake, cleanup
```

La matrice force `knight2`, `knight1` et `knight3`, exige pour chacun le rig direct demandé, le squelette, les animations, l'anatomie 12/12 et les 12 zones, puis vérifie aussi qu'un override cross-pool rejeté retombe sur le package canonique. Le log de ce dernier cas contient bien le rejet de `smallsbir1`, suivi de `[SPARTAN PACKAGE] Loaded ... bossbronze.glb`.

Le garde du générateur a également été contre-testé avec `--variant=smallsbir1` : sortie attendue `1`, treize erreurs explicites `requested variant ... direct=false`, et aucun fichier `boss_bronze__smallsbir1.png` créé. Il n'est donc plus possible d'étiqueter silencieusement un package avec un suffixe Mixamo non honoré.

`docs/enemy_refactor/visual_evidence/boss_bronze__knight3.png`, régénéré le 26 août 2026 à 06:19:51, a été ouvert en résolution originale. Il montre sans ambiguïté la silhouette argent/or de Knight3 et ses équipements authorés sur la planche 13 états, distincte du package noir/bronze de `boss_bronze.png`. La revendication de preuve `knight3` est désormais factuelle.

### Anciens blockers désormais levés

| Ancien finding | Preuve actuelle | Statut |
|---|---|---|
| Impact shared/package non déterministe | `_play_hit_reaction()` essaie Mixamo, puis `begin_block()` + `play_block_impact()`, puis un recoil visuel borné ; le helper exige un retour `true`. Les 24 planches inspectées montrent une pose d'impact distincte. | LEVÉ |
| Planche limitée à six états | Les 22 PNG canoniques contiennent 13 états : `IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`. Aucun T-pose manifeste observé. | LEVÉ |
| Équipements authorés non masqués en « NU » | `_hide_equipment()` masque désormais aussi `authored_weapon_visual` et `authored_shield_visual`; `captain__knight3.png` a été inspecté. | LEVÉ |
| Lab/Forge au repos uniquement | `index % 6` distribue locomotion, garde, impact, attaque, section et mort ; impact, section et mort portent des assertions. Les deux PNG 1600×900 actualisés montrent ces états sur 22/22. | LEVÉ |
| Faux positif sang dans la matrice de section | Le probe recherche maintenant exactement `SpartanDetached_<zone>` ou `Detached_<zone>`, puis exige collider capsule/sphère et `TransientDebrisLifecycle`. | LEVÉ |
| Cadavres sans TTL général | `corpse_lifetime=12.0`, `_schedule_corpse_release()` et `_release_expired_corpse()` sont dans le contrôleur commun. Le run masse libère 36/36 `WeakRef`. | LEVÉ |

### Probes relancés pour cette post-revue

| Probe | Résultat frais |
|---|---|
| `enemy_corpse_mass_ttl_probe.gd` | PASS — 36/36 cadavres retirés et libérés |
| `enemy_transient_lifecycle_probe.gd` | PASS — ressources partagées, TTL borné, corpse release, collisions/ombres retirées |
| `enemy_animation_lod_probe.gd` | PASS — cadences shared/native/direct et réveil réversible |
| `enemy_shield_world_radius_probe.gd` | PASS — rayon de requête conforme à l'échelle physique héritée |
| `enemy_large_body_contract_probe.gd` | PASS — `boss_colossus`, `LARGE_BODY`, récupération bornée, collider primitif, cleanup |
| `enemy_unit_dismemberment_probe.gd -- --id=<ID>` | PASS sur 22/22 — chaque run rapporte `zones=12 severed=10` avec fragment exact, primitive et lifecycle |
| `enemy_mixamo_variant_matrix_probe.gd -- --id=captain` | PASS — 3 variantes, 36 zones |
| `enemy_mixamo_variant_matrix_probe.gd -- --id=boss_bronze` | PASS — 3 variantes, 36 zones, rejet cross-pool conservant le package |
| `enemy_unit_behavior_probe.gd -- --id=boss_bronze` | PASS — route standard package, far/close, attaques, interruption, perte cible, sleep/wake, cleanup |
| Générateur visuel avec `--variant=smallsbir1` invalide | ÉCHEC ATTENDU — sortie 1, aucune sauvegarde suffixée |

Le scan statique de `scripts/enemy`, `scripts/gore` et `scripts/animation` ne trouve aucune `ConcavePolygonShape3D` dynamique. Les shapes concernées restent des capsules, sphères, boîtes, cylindres ou hulls convexes. Les 22 planches canoniques, `captain__knight3`, `boss_bronze__knight3`, Lab et Forge ont toutes été ouvertes en résolution originale pendant cette post-revue.

Un rerun supplémentaire de la capture `boss_bronze__knight3` a atteint `stage=render` puis n'a pas terminé pendant la concurrence de nombreux processus Godot sur le même workspace ; il a été interrompu manuellement. Ce run de harness n'est pas utilisé comme preuve PASS. La matrice autoritaire, le garde de refus, le run package standard et l'artefact généré avec succès à 06:19:51 fournissent les preuves indépendantes nécessaires. Le bruit Windows `Failed to read the root certificate store` reste environnemental et n'affecte aucun résultat fonctionnel.

**Conclusion autoritaire : DONE. Aucun P0-P3 bloquant ou majeur reproductible ne subsiste sur l'axe rig/animation/visuel/physique/anatomie.**

## Revue initiale historique — remplacée par la post-revue ci-dessus

La refonte est techniquement avancée : les trois routes d'animation sont présentes, le LOD d'animation est réversible dans les trois cas, les 22 identités construisent un squelette et une anatomie 12/12, les dix zones sectionnables passent pour chaque identité, les géants conservent des collisions primitives, le rayon de bouclier est correct en espace monde et les débris ont un cycle de vie borné. Aucun donneur ou asset source requis n'a été supprimé.

La mission ne peut toutefois pas être déclarée terminée. La planche « IMPACT » ne déclenche pas réellement l'impact pour les routes `shared_library` et `package_retarget`, plusieurs états visuels explicitement requis ne sont pas capturés, et les cadavres n'ont pas de politique TTL générale hors du directeur procédural. Ces écarts touchent directement les critères d'acceptation « preuve visuelle avant validation » et « stabilité après beaucoup de morts ».

## Findings

### P1 — La colonne « IMPACT » est un faux positif pour les routes `shared_library` et `package_retarget`

**Preuve.** `tools/enemy_unit_visual_evidence.gd:215-226` appelle `play_block_impact()` sans commencer une garde et ignore sa valeur de retour. Or :

- `scripts/animation/shared_hoplite_animation_driver.gd:190-199` renvoie `false` quand `block_active == false` ;
- `scripts/animation/native_animation_driver.gd:381-389` applique la même condition ;
- le fallback `scripts/enemy/athenian_enemy.gd:2206-2217` ne joue une réaction que pour `uses_mixamo_visual` ;
- le hit injecté ensuite ne garantit rien : `scripts/enemy/athenian_enemy.gd:3370-3371` déclenche cette réaction uniquement sur contact chair et selon un tirage `randf() > poise`.

Les personnages package/shared peuvent donc rester en pose neutre sous une étiquette « IMPACT ». Cela est visible sur plusieurs PNG (notamment `nsbire1`, `nsbire2`, `ngeneral` et plusieurs géants) et invalide la preuve d'animation d'impact.

**Correctif attendu.** Faire entrer explicitement le driver en garde avant `play_block_impact()`, vérifier `true`, avancer le driver jusqu'à une pose non neutre et échouer la capture si le clip n'a pas démarré. Pour l'impact chair, exposer une commande déterministe de réaction par route au lieu de dépendre du RNG. Régénérer les 22 PNG et vérifier visuellement le résultat.

### P1 — La matrice visuelle requise est incomplète ; Lab et Forge ne prouvent que le spawn au repos

**Preuve.** La planche unitaire ne comporte que six colonnes (`tools/enemy_unit_visual_evidence.gd:14`) : `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Il manque au minimum :

- sprint quand disponible ;
- rotation en locomotion ;
- garde ;
- locomotion sous action partielle/upper-body ;
- transition proche → lointain → sommeil → réveil, avec reprise visuelle du mouvement.

Chaque colonne est en outre une instance différente (`tools/enemy_unit_visual_evidence.gd:47-61`), sans `mixamo_model_override` déterministe. La planche ne constitue donc ni une séquence temporelle, ni une couverture garantie de chaque variante de modèle.

La capture Lab charge bien `combat_lab.tscn`, mais place les unités dans une annexe artificielle à `y = 42` et les instancie directement via `EnemyFactory` (`tools/enemy_lab_forge_full_roster_visual_probe.gd:35-63`). La capture Forge passe bien par `HopliteWorldRuntime`, puis désactive la participation IA (`:65-112`). Dans les deux contextes, la validation ne joue que l'idle et avance de 0,20 s (`:114-136`). Ces captures prouvent la présence des 22 unités et leur squelette/anatomie, pas le combat réel, les déplacements, les LOD ni le démembrement dans ces routes.

**Correctif attendu.** Produire une matrice déterministe par identité et variante avec les états manquants, plus une courte séquence ou des captures datées démontrant les transitions LOD/sommeil/réveil sur une même instance. Dans Lab et Forge, exécuter au moins locomotion, garde/impact, attaque, section et mort via leurs routes réelles, avec assertions sur l'état d'animation et non uniquement sur la présence d'un squelette.

### P1 — Les cadavres peuvent s'accumuler sans limite hors de la campagne procédurale

**Preuve.** La mort programme `_retire_corpse_runtime()` (`scripts/enemy/athenian_enemy.gd:3646-3649`), qui coupe particules, ombres et `_process`, mais ne libère jamais le nœud (`:3653-3664`). `HopliteWorldRuntime._on_enemy_died()` ne fait que réémettre le signal (`scripts/world_editor/world_runtime.gd:1057-1058`). Seul `HopliteProceduralWaveDirector` applique actuellement un TTL de 4,5 s (`scripts/campaign/procedural_wave_director.gd:21` et `:354-366`).

Le probe `enemy_transient_lifecycle_probe` vérifie la mise à la retraite du cadavre, pas sa libération finale. Un document Forge, Combat Lab ou autre propriétaire qui ne connecte pas une politique de nettoyage peut donc conserver indéfiniment nœuds, meshes et ressources après des morts répétées.

**Correctif attendu.** Définir un propriétaire unique et général du TTL des cadavres (configurable si certaines scènes veulent les conserver), puis ajouter un probe de masse qui tue un grand nombre d'unités dans `HopliteWorldRuntime`, attend le TTL et vérifie par `WeakRef` et compte de nœuds que tous les cadavres sont libérés. Conserver le retrait immédiat des collisions, traitements et ombres.

### P2 — Le probe 12/10 peut confondre une gerbe de sang avec un membre détaché

**Preuve.** `tools/enemy_unit_dismemberment_probe.gd:63-85` considère que le membre existe dès que le nombre d'enfants du monde augmente. Or une section génère aussi un effet sanguin ; l'assertion peut donc réussir même si la création du fragment anatomique échoue. Les équipements sont contrôlés séparément, mais pas l'identité, le mesh, le collider primitif et le TTL du fragment exact pour chacune des dix zones de chacune des 22 identités.

Le probe de cycle de vie couvre utilement un fragment package de géant et le proxy générique, mais il ne ferme pas cette matrice complète.

**Correctif attendu.** Rechercher explicitement le fragment correspondant à `sever_target` (groupe/métadonnée/nom stable), vérifier son mesh ou proxy attendu, son `CollisionShape3D` primitif, son TTL et sa libération. La gerbe de sang doit être comptée séparément.

### P2 — « NU » ne masque pas les équipements authorés et la variante `knight3` n'est pas prouvée visuellement

**Preuve.** `_hide_equipment()` ne masque que `sword_root` et `shield_root` (`tools/enemy_unit_visual_evidence.gd:247-251`). Pour `knight3`, les meshes visibles sont référencés séparément par `authored_weapon_visual` et `authored_shield_visual` (`scripts/enemy/athenian_enemy.gd:3994-3995`) ; les anchors procéduraux peuvent être vides. Une capture forcée de cette variante resterait donc équipée malgré l'étiquette « NU ».

Le probe structurel `enemy_authored_equipment_probe` valide correctement anchors, masquage lors de la section et remplacements détachés, mais la planche actuelle ne force pas chaque variante de modèle. Elle ne constitue pas une preuve visuelle de `knight3` et de ses attaches.

**Correctif attendu.** Masquer également les deux références authorées dans le helper de capture et forcer chaque modèle via `mixamo_model_override`. Ajouter une vue équipée et une vue après section du bras pour `knight3`, avec arme/bouclier attachés puis détachés au bon endroit.

### P3 — Les captures Lab/Forge sont trop peu lisibles pour une validation anatomique fine

Les 22 unités sont visibles, mais les sujets et labels sont petits dans Lab ; Forge est fortement délavé et peu contrasté. Ces images conviennent comme preuve de roster, pas pour juger pieds/mains, équipement, intersections, membres masqués ou T-pose subtile.

**Correctif attendu.** Conserver la vue d'ensemble et ajouter des crops haute résolution par rangée ou par famille, avec éclairage neutre, labels lisibles et silhouettes non superposées.

## Contrats vérifiés avec succès

Les probes suivants ont été relancés indépendamment sous Godot `4.7.stable` en renderer Compatibility :

| Domaine | Résultat |
|---|---|
| LOD réversible `shared_library`, `package_retarget`, `direct_mixamo` | `enemy_animation_lod_probe` PASS |
| Squelettes/rigs canoniques et sources | `hoplite_animation_rig_audit` exit 0 |
| Mort létale après section | `enemy_anatomy_regression_probe` PASS |
| TTL des débris, ressources partagées, arrêt collisions/ombres | `enemy_transient_lifecycle_probe` PASS |
| Rayon du bouclier en espace monde | `enemy_shield_world_radius_probe` PASS |
| Anchors et détachement des équipements authorés `knight3` | `enemy_authored_equipment_probe` PASS |
| Géants : contrat `LARGE_BODY`, collision primitive, récupération | `enemy_large_body_contract_probe` PASS |
| Roster complet, routes, anatomie, actions, navigation, teardown | `enemy_full_roster_validation_probe` PASS (22/22) |
| Anatomie/section | 22/22 identités PASS, chacune `zones=12 severed=10` |
| Variantes Mixamo échantillonnées | guardian 2/2, captain 3/3, warlord 4/4 PASS |

Inspection statique complémentaire :

- `shared_library` utilise un squelette canonique et une bibliothèque locale partagée ;
- `package_retarget` garde les squelettes visibles et donneurs nécessaires au retarget ;
- `direct_mixamo` joue directement sur l'`AnimationPlayer` du modèle ;
- les transitions LOD 0/1/2/3 sont réactivables et une reprise force un sample ;
- aucune `ConcavePolygonShape3D` dynamique n'a été trouvée dans le runtime concerné ;
- les colliders principaux, de bouclier, d'équipement et de débris sont primitifs/convexes ;
- les 12 zones anatomiques existent, dont 10 sectionnables ;
- les 22 PNG unitaires et les deux vues Lab/Forge existent et sont non vides ; aucun T-pose manifeste n'a été observé ;
- les assets donneurs `UAL1_Standard.glb`, `UAL2_Standard.glb` et la bibliothèque partagée v3 sont toujours présents ; aucune suppression de donneur n'apparaît dans le diff audité.

## Condition de passage à PASS

Le verdict pourra passer à **PASS** après :

1. correction et régénération de la preuve d'impact pour les trois routes ;
2. couverture visuelle déterministe des états manquants, des variantes et du cycle proche/loin/sommeil/réveil ;
3. exercice réel de combat/section/mort dans Lab et Forge ;
4. politique générale de TTL des cadavres avec preuve de libération en masse ;
5. durcissement du probe de démembrement pour identifier le fragment exact, distinct du sang.

Verdict historique du premier passage, désormais remplacé par la post-revue autoritaire : **BLOCKED à cette date antérieure**.
