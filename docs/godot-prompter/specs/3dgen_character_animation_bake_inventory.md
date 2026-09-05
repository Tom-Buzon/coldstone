# Inventaire des personnages 3DGen et matrice des animations

Date de l'audit : 31 août 2026\
Périmètre réel : `res://assets/characters/3dgen_demo` (le dépôt ne contient pas de dossier `asset/3dgen`).

## Décision recommandée

Le meilleur découpage n'est ni « une bibliothèque complète par classe de soldat », ni « une bibliothèque monolithique par arme ». Le dépôt se prête à un découpage hybride :

1. **un socle commun par famille de rig** pour la locomotion, la mort et les réactions communes ;
2. **des packs par arme** pour les attaques, gardes et poses d'arme réutilisables ;
3. **de petits overrides par type de troupe** uniquement pour les signatures, phases et timings qui changent réellement son comportement.

Treize des quatorze GLB du dossier ont exactement le même squelette `SPARTAN_Skeleton` : 53 joints, mêmes noms, même hiérarchie, même pose de repos et mêmes inverse bind matrices. Ils peuvent donc partager directement un bake canonique. `hopliteClean1.glb` a aussi 53 joints et les mêmes noms d'os utiles, mais une autre pose de repos et d'autres inverse bind matrices ; il doit rester une cible de bake/validation distincte, ou être réexporté sur le rig canonique.

Le gain principal viendra du remplacement des **scènes donneuses instanciées à l'exécution** par des clips déjà bakés sur le squelette visible. Une animation ne crée pas elle-même un squelette inutile ; ce sont les GLB/FBX donneurs, leurs proxies et leurs bridges de retargeting qui le font.

## Légende

| Statut | Sens |
|---|---|
| **Actif** | Le clip ou la clé est réellement sélectionné par le chemin runtime normal. |
| **Fallback** | Utilisé en mode masse, si un clip spécialisé manque, ou si le driver échoue. |
| **Déclaré mais masqué** | Présent dans le profil, mais un `combat_pattern` actif est essayé avant lui. |
| **Inactif actuellement** | Déclaré, mais le chemin runtime ne charge pas la source nécessaire. |
| **Galerie** | Le GLB est instancié comme exposition statique ; ses animations sont arrêtées. |

## 1. Résumé quantitatif

| Mesure | Résultat |
|---|---:|
| GLB dans `assets/characters/3dgen_demo` | 14 |
| GLB instanciés par la bibliothèque automatique d'assets | 14 |
| GLB distincts utilisés par des archétypes de combat | 11 |
| Archétypes de combat résolus vers ces GLB | 15 |
| GLB au rig SPARTAN strictement identique | 13 |
| GLB avec animations embarquées | 1 (`hopliteClean1`, 46 clips) |
| GLB sans animation embarquée | 13 |
| Bibliothèque partagée déjà sans donneur runtime | `ngeneral` et `ngeneral_veteran` |

Les 15 archétypes correspondent aux 13 entrées `ROSTER_IDS`, auxquelles s'ajoutent les routes historiques `boss_bronze` et `boss_colossus`. Ces deux routes sont maintenant classées explicitement dans `HISTORICAL_3DGEN_IDS` : leur provenance correspond donc aux packages `bossbronze.glb` et `bosscolossus.glb` réellement chargés, sans les confondre avec le roster principal de migration.

## 2. Inventaire des 14 personnages du dossier

Tous les modèles ont un skin de 53 joints. Sauf indication contraire, ils ont 28 meshes, 83 nœuds et aucune animation embarquée.

| GLB 3DGen | Taille | Usage réel | Archétype(s) de combat | Rig / animations embarquées | Décision bake |
|---|---:|---|---|---|---|
| `athenian_legionary2_spartan_jointfit.glb` | 4,26 MB | Galerie uniquement | Aucun | SPARTAN identique, 0 clip | Ne pas inclure dans un pack runtime tant qu'aucun archétype ne le référence. |
| `bossbronze.glb` | 13,30 MB | Combat + galerie | `boss_bronze` | SPARTAN identique, 0 clip | Inclure dans le pack lance/élite historique si cette route est conservée. |
| `bosscolossus.glb` | 13,06 MB | Combat + galerie | `bronze_colossus`, `boss_colossus` | SPARTAN identique, 0 clip | Un seul modèle, deux profils et deux sets d'actions distincts. |
| `geant1-1787584159710.glb` | 19,13 MB | Combat + galerie | `giant_novice`, `giant_standard`, `giant_veteran` | SPARTAN identique, 0 clip | Pack commun « géant à mains nues », sous-ensembles par tier. |
| `hopliteClean1.glb` | 7,29 MB | Combat + galerie | `ngeneral_veteran` | Rig UAL1 compatible mais pose de repos différente ; 1 mesh ; 46 clips | Garder une cible de validation distincte. Supprimer les clips embarqués après validation, car le runtime retire leur `AnimationPlayer`. |
| `nathenian1-1787346222233.glb` | 9,62 MB | Combat + galerie | `nathenian1` | SPARTAN identique, 0 clip | Socle commun + pack épée/bouclier. |
| `nathenian2-1787346736278.glb` | 10,06 MB | Combat + galerie | `nathenian2`, `nathenian2_soldier` | SPARTAN identique, 0 clip | Socle commun + pack marteau ; le soldat ne garde pas la phase II. |
| `ncenturion-1787350193317.glb` | 10,15 MB | Combat + galerie | `ncenturion` | SPARTAN identique, 0 clip | Socle commun + pack gladius/bouclier + combo de commandant. |
| `nfullarmor-1787349525988.glb` | 12,54 MB | Combat + galerie | `nfull_armor` | SPARTAN identique, 0 clip | Socle commun + pack grande épée + overrides de boss à trois phases. |
| `ngeneral-1787351044165.glb` | 6,79 MB | Combat + rig canonique + galerie | `ngeneral` | SPARTAN identique, 0 clip | Déjà migré : cible canonique du bake partagé v4. |
| `nsbire1-1787347581582.glb` | 9,99 MB | Combat + galerie | `nsbire1` | SPARTAN identique, 0 clip | Socle commun + futur pack outil agricole. Le visuel actuel emprunte une attaque d'épée. |
| `nsbire2-1787348495833.glb` | 5,18 MB | Combat + galerie | `nsbire2` | SPARTAN identique, 0 clip | Socle commun + pack arc. |
| `oldsbir1-1787330035666.glb` | 6,76 MB | Galerie uniquement | Aucun | SPARTAN identique, 0 clip | Archive/preview ; hors bake runtime. |
| `perso-1787423482233.glb` | 17,91 MB | Galerie ; mention d'un ancien toggle dans le README | Aucun chemin gameplay actuel trouvé | SPARTAN identique, 0 clip | Archive/preview ; hors bake runtime. |

La galerie est créée par `scripts/environment/asset_library_room.gd`, appelée depuis `scripts/main.gd`. Elle scanne tout le dossier et désactive les `AnimationPlayer`/`AnimationTree` des personnages : ces 14 usages ne demandent donc aucun pack animé pour l'exposition statique.

## 3. Matrice principale par archétype

Le nombre de squelettes est une estimation statique du chemin **IA détaillée, hors mode masse** :

- 1 squelette visible ;
- 1 donneur UAL1 pour les packages SPARTAN non migrés ;
- 2 donneurs UAL2 créés par `native_animation_driver.gd` ;
- pour chaque FBX externe unique : 1 squelette donneur + 1 squelette proxy de retargeting.

| Archétype | Modèle | Arme | Comportement attendu | Actions réellement actives | Animations de type / statut | Squelettes actuels estimés (détaillé / masse) |
|---|---|---|---|---|---|---:|
| `nathenian1` | `nathenian1…glb` | Épée + bouclier | Infanterie légère disciplinée : approche prudente, tient sa garde, reste au contact. | `Sword_Attack` UAL1 en fallback direct. | `Shield_OneShot`, `Sword_Regular_A` sont déclarées comme signatures UAL2 mais **inactives actuellement** : aucun driver UAL2 n'est créé pour cette troupe normale. | **2 / 2** |
| `nsbire1` | `nsbire1…glb` | Outil agricole | Levée fragile : harcèle prudemment et fuit quand sa santé baisse. | `Sword_Attack` UAL1 en fallback direct. | `Farm_Harvest`, `TreeChopping` sont déclarées mais **inactives actuellement** pour la même raison. | **2 / 2** |
| `nsbire2` | `nsbire2…glb` | Arc | Archer de soutien : cherche une ligne de tir et de la hauteur, recule au contact. | `archer_draw_release` → `bow_aim`. | Une seule action spécialisée ; en mode masse l'attaque devient une pose `Idle`, pas un tir d'arc animé. | **6 / 2** |
| `nathenian2` | `nathenian2…glb` | Marteau | Miniboss briseur de ligne : coups lents, balayage, poussée et choc de zone en phase II. | `axe_down`, `mutant_punch`, `mutant_swipe`, `axe_combo`. | `hammer_quake` et `hammer_rush` sont spécifiques à la phase II. Signatures UAL2 déclarées mais normalement masquées par le pattern. | **12 / 2** |
| `nathenian2_soldier` | Même GLB | Marteau | Fantassin lourd monophasé : conserve l'identité marteau, sans budget ni phase de miniboss. | Même pack FBX que `nathenian2`. | Pas de `phase_two_pattern` après normalisation du profil. | **12 / 2** |
| `bronze_colossus` | `bosscolossus.glb` | Marteau | Juggernaut de siège : rugit, charge, frappe le sol et balaie ; frénésie en phase II. | `mutant_roar`, `axe_combo`, `axe_down`, `mutant_swipe`. | `colossus_double_quake` et `colossus_frenzy` sont des timings/effets de type, mais réutilisent des clips du pack marteau. | **12 / 2** |
| `ncenturion` | `ncenturion…glb` | Gladius + bouclier | Commandant/taxiarque : garde solide, sonde, bouscule puis conclut par un combo. Il ne commande pas techniquement la phalange. | `light1`, `dash_attack`, `heavy_release`, `block_idle`, `block_impact`. | Pattern `centurion_probe`, `centurion_bash`, `centurion_combo`. Signatures UAL2 normalement masquées. | **14 / 2** |
| `ngeneral` | `ngeneral…glb` | Dory + aspis | Cœur de phalange : rejoint son slot, maintient la ligne et attaque depuis les deux premiers rangs. | Bibliothèque v4 : `spear_thrust`, `spear_thrust_low`, `shield_bash`, `block_idle`, `block_impact`. | Quatre actions de type : thrust torse, haut, bas et poussée de bouclier. Aucun donneur runtime. | **1 / 1** |
| `ngeneral_veteran` | `hopliteClean1.glb` | Dory + aspis | Garde de flanc vétéran : cohésion renforcée, réorganisation et ripostes plus rapides. | Même bibliothèque v4 que `ngeneral`. | Riposte, thrust bas, thrust retardé et poussée de bouclier ; mêmes clips, timings différents. | **1 / 1** |
| `giant_novice` | `geant1…glb` | Mains nues | Géant lent et lisible : punch et swipe simples. | `giant_punch`, `giant_swipe`. | Aucun changement de phase. | **8 / 2** |
| `giant_standard` | Même GLB | Mains nues | Géant plus mobile : punch, swipe large et saut offensif. | `giant_punch`, `giant_swipe`, `giant_jump_attack_alt`. | Le saut est propre au tier standard. | **10 / 2** |
| `giant_veteran` | Même GLB | Mains nues | Géant vétéran agressif : punch, swipe, rugissement, saut-choc ; accélère en phase II. | `giant_punch`, `giant_swipe`, `giant_roar`, `giant_jump_attack`, `giant_flex`. | Rage swipe, rage jump et flex sont des actions de phase/type. | **14 / 2** |
| `nfull_armor` | `nfullarmor…glb` | Grande épée | Boss ancre à trois phases : cleave, sweep, leap, rush, tempête et chocs de zone. | `heavy_release`, `spin_low`, `air_down`, `dash_attack`, `spin_high`, `axe_down`. | Les patterns `iron_*`, `crown_breaker`, `dread_storm`, `throne_quake`, `last_execution` sont spécifiques au boss. | **16 / 2** |
| `boss_bronze` | `bossbronze.glb` | Lance sans bouclier | Miniboss d'allonge : thrust puis large sweep. | `vertical_sword`, `sword_slash`. | **Incohérence visuelle à valider** : les donneurs sont des attaques d'épée, pas de vraies animations de lance. | **8 / 2** |
| `boss_colossus` | `bosscolossus.glb` | Marteau | Ancien colosse : crush puis quake. | `axe_down`, `mutant_punch`. | Profil historique plus simple que `bronze_colossus`, malgré le même modèle. | **8 / 2** |

En mode masse, tous les non-hoplites spécialisés retombent sur le donneur UAL1 seul. Les unités de mêlée jouent `Sword_Attack`; l'archer joue `Idle` pendant la libération du projectile. Ce chemin est moins coûteux, mais il efface presque toute la distinction d'arme et de classe.

## 4. Animations communes

### 4.1 Socle réellement commun aux soldats

| Clé runtime | Source brute | Nom importé Godot | Boucle | Utilisateurs | Remarque bake |
|---|---|---|---|---|---|
| `Idle` | `assets/runtime/ual1/UAL1_Standard.glb` → `Idle_Loop` | `Idle` | Oui | Tous les personnages de combat ; fallback de l'archer en masse | À baker dans `core_spartan`. |
| `Jog_Fwd` | UAL1 → `Jog_Fwd_Loop` | `Jog_Fwd` | Oui | Tous les drivers détaillés et locomotion simple | À baker dans `core_spartan`. |
| `Sprint` | UAL1 → `Sprint_Loop` | `Sprint` | Oui | Blend de locomotion des drivers natif et partagé | À baker dans `core_spartan`; peu ou pas utilisé par le chemin masse simple. |
| `Death01` | UAL1 → `Death01` | `Death01` | Non | Tous les archétypes, y compris les hoplites via la bibliothèque v4 | À baker dans `core_spartan`; garde la pose de cadavre sans driver. |
| `Sword_Idle` | UAL1 → `Sword_Idle` | `Sword_Idle` | Oui | Idle simple des packages non pilotés | Fallback historique, à sortir du core si des idles d'arme corrects sont disponibles. |
| `Sword_Attack` | UAL1 → `Sword_Attack` | `Sword_Attack` | Non | `nathenian1`, `nsbire1` en détaillé ; tous les mêlées non partagés en masse | Fallback temporaire, pas une animation commune sémantiquement correcte. |
| `Punch_Cross` | UAL1 → `Punch_Cross` | `Punch_Cross` | Non | Second fallback si `Sword_Attack` manque | Ne pas prioriser dans le premier bake. |

### 4.2 Clips communs déjà bakés pour les hoplites

La bibliothèque actuelle est `assets/animations/hoplite_animation_library_v4.res`. Le guide historique qui cite encore `v3` est obsolète sur ce point.

| Clé publique | Clip stocké dans v4 | Source offline | Utilisateurs |
|---|---|---|---|
| `Idle` | `Idle` | UAL1 `Idle` | `ngeneral`, `ngeneral_veteran` |
| `Jog_Fwd` | `Jog_Fwd` | UAL1 `Jog_Fwd` | Les deux hoplites |
| `Sprint` | `Sprint` | UAL1 `Sprint` | Les deux hoplites |
| `Death01` | `Death01` | UAL1 `Death01` | Les deux hoplites |
| `block_idle` | `ual2_idle_shield` | UAL2 `Idle_Shield` | Les deux hoplites |
| `shield_bash` | `ual2_shield_one_shot` | UAL2 `Shield_OneShot` | Les deux hoplites |
| `block_impact` | `ual2_sword_block` | UAL2 `Sword_Block` | Les deux hoplites |
| `spear_thrust` | composite | UAL2 `Shield_OneShot` + bras droit de `lancier_attack_animation_test.glb` | Les deux hoplites |
| `spear_thrust_low` | composite | UAL2 `Sword_Block` + bras droit du même GLB lancier | Les deux hoplites |

Le GLB lancier contient un seul clip, `SPARTAN_SkeletonAction`, sur le rig SPARTAN 53 joints. Le builder n'en conserve que les os du bras droit pour composer les thrusts.

## 5. Animations par arme

Cette table donne la correspondance exacte entre les clés sémantiques demandées par les profils et les fichiers réellement chargés par `external_animation_bank.gd`.

| Famille d'arme | Clé runtime | Fichier source exact | Utilisateurs 3DGen | Classification |
|---|---|---|---|---|
| Arc | `bow_aim` | `assets/runtime/mixamo/animations/Bow Standing Aim Walk Back.fbx` | `nsbire2` | Arme |
| Gladius/bouclier | `light1` | `…/sword_and_shield_pack/sword and shield slash (5).fbx` | `ncenturion` | Arme |
| Gladius/bouclier | `dash_attack` | `…/sword_and_shield_pack/sword and shield slash (4).fbx` | `ncenturion`, `nfull_armor` | Arme, réutilisé par type boss |
| Gladius/grande épée | `heavy_release` | `…/sword_and_shield_pack/sword and shield attack (2).fbx` | `ncenturion`, `nfull_armor` | Arme |
| Bouclier | `block_idle` | `…/sword_and_shield_pack/sword and shield block idle.fbx` | `ncenturion` | Arme/défense |
| Bouclier | `block_impact` | `…/sword_and_shield_pack/sword and shield impact.fbx` | `ncenturion` | Arme/défense |
| Marteau lourd | `axe_down` | `…/Axe Standing Melee Attack Downward.fbx` | `nathenian2`, `nathenian2_soldier`, `bronze_colossus`, `boss_colossus`, `nfull_armor` | Arme partagée |
| Marteau lourd | `axe_combo` | `…/Axe Standing Melee Combo Attack Ver. 1.fbx` | `nathenian2`, `nathenian2_soldier`, `bronze_colossus` | Arme partagée |
| Marteau/corps massif | `mutant_punch` | `…/Mutant Punch.fbx` | `nathenian2`, `nathenian2_soldier`, `boss_colossus` | Arme/type hybride |
| Marteau/corps massif | `mutant_swipe` | `…/Mutant Swiping.fbx` | `nathenian2`, `nathenian2_soldier`, `bronze_colossus` | Arme/type hybride |
| Colosse | `mutant_roar` | `…/Mutant Roaring.fbx` | `bronze_colossus` | Type/signature |
| Géant mains nues | `giant_punch` | `…/creature_pack/mutant punch.fbx` | Les 3 géants | Arme/type commun |
| Géant mains nues | `giant_swipe` | `…/creature_pack/mutant swiping.fbx` | Les 3 géants | Arme/type commun |
| Géant mains nues | `giant_jump_attack_alt` | `…/creature_pack/jump attack.fbx` | `giant_standard` | Type/tier |
| Géant mains nues | `giant_roar` | `…/creature_pack/mutant roaring.fbx` | `giant_veteran` | Type/tier |
| Géant mains nues | `giant_jump_attack` | `…/creature_pack/mutant jump attack.fbx` | `giant_veteran` | Type/tier |
| Géant mains nues | `giant_flex` | `…/creature_pack/mutant flexing muscles.fbx` | `giant_veteran` | Type/tier |
| Grande épée | `spin_low` | `…/Standing Melee Attack 360 Low.fbx` | `nfull_armor` | Arme |
| Grande épée | `air_down` | `…/Great Sword Jump Attack.fbx` | `nfull_armor` | Arme |
| Grande épée | `spin_high` | `…/Great Sword High Spin Attack.fbx` | `nfull_armor` | Arme |
| Lance historique | `vertical_sword` | `…/verticalSwordAttack.fbx` | `boss_bronze` | Fallback visuel à remplacer |
| Lance historique | `sword_slash` | `…/Stable Sword Outward Slash.fbx` | `boss_bronze` | Fallback visuel à remplacer |

Pour `ngeneral` et `ngeneral_veteran`, les mêmes clés `block_idle`, `block_impact`, `shield_bash` et `spear_thrust*` ne passent **pas** par ces FBX runtime : elles pointent vers les clips composites déjà présents dans la bibliothèque v4.

## 6. Animations par type de soldat

Les noms ci-dessous sont des **actions gameplay**, pas forcément des clips uniques. Plusieurs actions réutilisent le même clip avec une vitesse, un début de lecture, un pitch, un rayon ou un effet différent. C'est précisément la partie qui doit rester dans un petit manifeste par type au lieu de dupliquer les données d'animation.

| Type | Actions sémantiques propres | Clips/clefs réutilisés | Différence comportementale à conserver |
|---|---|---|---|
| Nathenian léger | Signature `Shield_OneShot` / `Sword_Regular_A` déclarée | UAL2 | La signature doit être activée ou supprimée du profil ; actuellement elle ne se voit pas. |
| Levée civique | Signature `Farm_Harvest` / `TreeChopping` déclarée | UAL2 | Essentielle pour faire lire l'outil agricole ; actuellement remplacée par une attaque d'épée. |
| Archer léger | `archer_draw_release` | `bow_aim` | Le projectile part après le windup ; garder l'upper-body layer pour marcher/reculer en visant. |
| Briseur de ligne | `hammer_overhead`, `hammer_shove`, `hammer_sweep`, puis `hammer_quake`, `hammer_rush` | Pack marteau | Phase II, choc de zone et cadence lente sont de la donnée de type, pas de nouveaux rigs. |
| Fantassin lourd | Les trois actions de base du briseur | Même pack marteau | Aucun pattern de phase II. |
| Bronze Colossus | `colossus_roar`, `charge`, `quake`, `sweep`, puis double quake/frénésie | Pack marteau + roar | Le modèle est partagé avec l'ancien colosse mais le pattern ne l'est pas. |
| Taxiarque | `centurion_probe`, `centurion_bash`, `centurion_combo` | Pack gladius/bouclier | Garde plus forte et enchaînement de commandant. |
| Hoplite | thrust torse/haut/bas + poussée | Pack lance/bouclier v4 | Formation, attaques depuis les rangs et upper-body overlay. |
| Hoplite vétéran | riposte, thrust bas, thrust retardé, poussée | Même pack v4 | Timings plus rapides/irréguliers et rôle de garde de flanc. |
| Géant novice | punch, swipe | Pack géant | Lecture lente, sans phase. |
| Géant standard | punch, swipe, jump | Pack géant | Mobilité verticale ajoutée. |
| Géant vétéran | punch, swipe, roar, jump-crush, flex | Pack géant | Télégraphes et phase de rage. |
| Stratège cuirassé | `iron_*`, puis rush/storm/quake, puis exécution finale | Pack grande épée + `axe_down` | Trois phases ; les effets de choc et vitesses restent dans le manifeste du boss. |
| Boss bronze historique | thrust + sweep | Donneurs d'épée actuels | À remplacer par de vrais clips de lance avant bake définitif. |
| Colosse historique | crush + quake | Sous-ensemble marteau | Profil simple conservé séparément du Bronze Colossus. |

## 7. Dette et anomalies importantes avant bake

| Priorité | Constat | Conséquence | Action proposée |
|---|---|---|---|
| P0 | `nfull_armor` peut atteindre environ 16 `Skeleton3D` par acteur détaillé. | Plus gros multiplicateur de donneurs/proxies du roster. | Baker ses 6 sources sur SPARTAN en premier après le socle commun. |
| P0 | Les personnages spécialisés chargent deux scènes UAL2 même quand leur pattern joue uniquement des FBX externes. | Deux squelettes/players supplémentaires par acteur sans contribution visible courante. | Remplacer le driver par une bibliothèque bakée locale, puis supprimer les donneurs UAL2. |
| P0 | Chaque FBX externe crée un squelette donneur et un squelette proxy. | Deux squelettes par fichier distinct et par acteur. | Retarget/bake offline une fois, partager la ressource résultante. |
| P1 | `nathenian1` et `nsbire1` déclarent des signatures UAL2 mais n'instancient pas de driver UAL2. | Le soldat à outil agricole attaque comme à l'épée ; la signature bouclier n'apparaît pas. | Baker/brancher les signatures voulues, ou retirer les déclarations trompeuses. |
| P1 | L'archer en masse joue `Idle` au tir. | Les grandes volées manquent d'information visuelle. | Inclure un clip arc léger dans le pack masse. |
| P1 | Tous les mêlées non hoplites en masse jouent `Sword_Attack`. | Marteaux, géants et grande épée perdent leur silhouette d'arme. | Prévoir au moins une attaque masse par famille d'arme. |
| P1 | `boss_bronze` utilise des donneurs d'épée pour une lance. | Un bake figerait une approximation connue. | Fournir/valider de vrais thrust/sweep de lance avant bake final. |
| P1 | `hopliteClean1` embarque 46 animations, puis son `AnimationPlayer` importé est supprimé au runtime. | Poids disque/import et temps d'instanciation inutiles. | Réexporter le mesh/rig sans animations une fois la bibliothèque v4 validée sur ce modèle. |
| P2 | Le guide de migration cite encore v3 alors que le driver charge v4. | Risque de modifier ou supprimer la mauvaise ressource. | Mettre à jour le guide lors du chantier de bake. |
| Résolu | `boss_bronze` et `boss_colossus` étaient classés Mixamo alors qu'ils chargent des GLB 3DGen. | Les outils pouvaient les ranger au mauvais endroit. | Routes déplacées dans `HISTORICAL_3DGEN_IDS`; le manifeste conserve malgré tout `declared_asset_origin` et `resolved_asset_origin` pour détecter toute régression. |

## 8. Comparaison des stratégies de bake

| Stratégie | Avantages | Inconvénients | Verdict |
|---|---|---|---|
| Une bibliothèque par classe de soldat | Très simple à prévisualiser ; aucun filtre à calculer. | Duplique locomotion, mort et attaques identiques ; 15 variantes à maintenir. | À éviter comme format maître. Acceptable seulement comme export final généré automatiquement. |
| Une bibliothèque par arme | Bonne mutualisation ; correspond bien aux silhouettes d'attaque. | Les phases, télégraphes et timings ne sont pas des propriétés d'arme ; les géants/titans partagent parfois des clips mais pas les comportements. | Bonne base, insuffisante seule. |
| Une bibliothèque unique pour tout SPARTAN | Un seul catalogue et aucun doublon de clip. | Charge potentiellement trop de clips par acteur ; contrôle de dépendances et validation plus difficiles. | Utile comme bibliothèque source/editor, pas forcément comme ressource runtime unique. |
| **Core par rig + packs d'arme + manifests de type** | Mutualise les données lourdes tout en gardant les comportements lisibles et sélectifs. | Demande un manifeste et un petit outil de génération. | **Recommandé.** |

### Packs proposés

| Pack | Contenu minimum | Consommateurs |
|---|---|---|
| `core_spartan` | `Idle`, `Jog_Fwd`, `Sprint`, `Death01`, réactions retenues | Tous les modèles SPARTAN |
| `weapon_sword_shield` | light, dash, heavy, block idle/impact | Nathenian I, Taxiarque |
| `weapon_spear_shield` | thrust haut/bas, shield bash, block | Hoplites ; futur Boss Bronze corrigé |
| `weapon_bow` | aim/draw/release + variante masse | Archer léger |
| `weapon_hammer` | overhead, shove, swipe, combo/charge | Nathenian II, Bronze Colossus, ancien Colossus |
| `weapon_giant_unarmed` | punch, swipe, jump, roar, flex | Trois tiers de géants |
| `weapon_greatsword` | heavy, spin bas/haut, saut, dash | Stratège cuirassé |
| `weapon_farm_tool` | harvest/chop adaptés au combat | Levée civique |
| `type_overrides/<id>` | Timings, start fraction, layer, phase, effet, rayon, vitesse, alias d'action | Seulement le type concerné |

Un export final par classe peut toujours être généré pour Blender ou Godot, mais il doit être **dérivé** de ces packs, pas devenir la source de vérité.

## 9. Contrat de données conseillé pour le futur viewer Blender

Chaque ligne du catalogue devrait exposer au minimum :

| Champ | Exemple | Usage |
|---|---|---|
| `archetype_id` | `nathenian2_soldier` | Sélection du type de troupe. |
| `display_name` | `Fantassin lourd athénien` | Libellé UI. |
| `model_path` | `assets/characters/3dgen_demo/nathenian2-….glb` | Modèle visible à charger. |
| `rig_family` | `spartan_53_exact` ou `ual1_53_variant` | Choix de la cible de bake. |
| `weapon_family` | `hammer` | Filtre et pack d'animations. |
| `behavior_summary` | `Lourd monophasé, balayage et shove` | Rappel demandé pour l'artiste/animateur. |
| `animation_category` | `common`, `weapon`, `type` | Distinction principale du tableau. |
| `runtime_key` | `axe_down` | Clé attendue par Godot. |
| `source_path` | chemin GLB/FBX | Asset donneur exact. |
| `source_clip` | nom brut/importé | Action Blender/Godot à sélectionner. |
| `layer` | `full_body` ou `upper_body` | Bake complet ou masque d'os. |
| `loop` | booléen | Configuration du clip. |
| `phase` | `base`, `2`, `3`, `fallback_mass` | Filtrage comportemental. |
| `status` | `active`, `fallback`, `masked`, `missing` | Évite de baker aveuglément des déclarations mortes. |
| `validation` | `unverified`, `pose_ok`, `gameplay_ok` | Garde les preuves visuelles séparées de la simple présence de pistes. |

Le viewer doit permettre trois vues : **par personnage**, **par arme**, **par source**. La vue « par source » est indispensable pour repérer qu'un seul FBX est dupliqué entre plusieurs types et pour vérifier qu'un clip baké remplace bien tous ses consommateurs.

## 10. Ordre de migration conseillé

1. Figer et exporter le manifeste `core_spartan` à partir du rig canonique `ngeneral`.
2. Ajouter une preuve visuelle à plusieurs instants pour chaque clip ; un compteur de pistes ne suffit pas à détecter une pose en T.
3. Baker les packs à meilleur rendement : `nfull_armor`, `ncenturion`, `giant_veteran`, puis marteau/arc.
4. Remplacer les donneurs/proxies runtime archétype par archétype et mesurer le nombre de `Skeleton3D`, `AnimationPlayer`, nœuds, mémoire et temps de spawn.
5. Ajouter une attaque masse correcte par famille d'arme avant de retirer les fallbacks UAL1.
6. Corriger/valider les signatures de `nathenian1`, `nsbire1` et la lance de `boss_bronze`.
7. Traiter `hopliteClean1` séparément, puis réexporter ce modèle sans ses 46 animations intégrées si la bibliothèque partagée reste visuellement correcte.
8. Supprimer un donneur source uniquement après comparaison visuelle et test gameplay du clip baké correspondant.

## 11. Fichiers de référence

| Responsabilité | Fichier |
|---|---|
| Profils, comportements, patterns et packages | `scripts/enemy/enemy_archetypes.gd` |
| Sélection runtime et fallbacks masse | `scripts/enemy/athenian_enemy.gd` |
| Driver UAL1/UAL2 et création des deux donneurs UAL2 | `scripts/animation/native_animation_driver.gd` |
| Mapping clé → FBX et création donneur/proxy | `scripts/animation/external_animation_bank.gd` |
| Driver partagé sans donneur des hoplites | `scripts/animation/shared_hoplite_animation_driver.gd` |
| Builder offline de la bibliothèque v4 | `tools/build_hoplite_animation_library.gd` |
| Bibliothèque partagée courante | `assets/animations/hoplite_animation_library_v4.res` |
| Source brute du bras de lancier | `assets/animations/sources/lancier_attack_animation_test.glb` |
| Scan de tous les GLB pour la galerie | `scripts/environment/asset_library_room.gd` |

## Conclusion

Le dépôt possède déjà la preuve de concept correcte avec les deux hoplites : **un seul squelette visible et une bibliothèque partagée bakée**. Comme 13 modèles sur 14 ont un rig SPARTAN strictement identique, ce modèle peut être généralisé sans créer une bibliothèque complète par classe. Le découpage le plus robuste est : **core de rig partagé, clips lourds regroupés par arme, comportement et phases décrits par type**.

La priorité n'est pas de réduire le nombre de clips, mais de supprimer les donneurs/proxies runtime tout en conservant la lisibilité de chaque arme. Le tableau ci-dessus doit donc rester la source de vérité du futur outil Blender et du chantier de bake.
