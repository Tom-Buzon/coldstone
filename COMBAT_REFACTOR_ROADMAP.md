# Refonte du combat joueur

État de référence : 22 août 2026.

## Invariant de gameplay

Le combat reste un système hybride en deux étages :

1. L'assistance choisit une cible probable et améliore légèrement l'alignement.
2. Seul le balayage physique de la vraie lame peut produire un impact, des
   dégâts localisés et un démembrement.

L'assistance ne doit jamais créer un dégât abstrait dans un cône. Le membre
touché reste celui dont le collider anatomique rencontre réellement la lame.

## Audit : garder, remplacer, retirer

### À garder

- Le balayage continu de toute la lame entre la frame précédente et la frame
  courante (`sword_base` + `sword_tip`) avec un rayon de gameplay de 12 cm.
- L'échantillonnage du mouvement pour éviter le tunneling à haute vitesse.
- La sélection du collider anatomique le plus proche du segment de lame.
- La position, la direction, la vitesse de lame et la zone anatomique conservées
  dans `HitEvent`.
- Le combo logique en trois étapes `Light 1 -> Light 2 -> Light 3`.
- Les contextes `idle`, `run`, `dash`, `air` et `slide`.
- La charge continue de Heavy, son multiplicateur de dégâts et son retour visuel.
- La garde frontale directionnelle. Elle ne protège pas le dos.
- La superposition haut du corps / bas du corps utilisée pendant la glissade.
- Les diagnostics de lame et la prévisualisation en lecture seule des clips.

### À remplacer progressivement

- Le classement heuristique des clips par leur nom par une table explicite de
  profils d'attaque validés visuellement.
- Affiner les valeurs de la cible persistante, de la rotation progressive de
  150 ms et du lunge maintenant implémentés, clip par clip.
- Les fenêtres de contact génériques par des timings `startup/active/recovery`
  propres à chaque clip.
- Les derniers fallbacks UAL partagés par des clips distincts et reconnaissables
  quand une animation externe validée devient disponible.
- La simple garde binaire par une défense comprenant garde, parade/contre et
  réaction de guard break, avec timings séparés.

### Retiré lors de cette étape

- La sélection aléatoire des variantes de combat et de parkour.
- Le fichier persistant de laboratoire qui remplaçait silencieusement Light 1 et
  Light 2 par `Melee_Hook`.
- Les touches `1-5` qui assignaient un clip de prévisualisation au gameplay.

Le vieux fichier `user://hoplite_ual_native_slots_v24.cfg` peut encore exister
sur la machine, mais le jeu ne le lit plus.

## Contrat d'une future attaque

Chaque variante devra être une donnée explicite comprenant au minimum :

- identifiant, famille (`light1`, `light2`, `light3`, `heavy`, etc.) et contexte ;
- source du clip, nom du clip et mode haut du corps/corps entier ;
- direction lisible de la lame ;
- startup, fenêtre active, recovery et ouverture du buffer de combo ;
- dégâts, sever damage, stagger et éventuel guard damage ;
- angle maximal d'assistance, vitesse de rotation et distance de lunge ;
- zone préférée pour l'assistance seulement (`torso`, `head`, `legs`) ;
- vitesse d'animation et poids bassin/jambes.

La zone préférée ne remplace jamais la collision anatomique réelle.

## Matrice des attaques

| Action | Base actuelle | Candidat déjà présent | Décision / besoin |
|---|---|---|---|
| Light 1 immobile, droite vers gauche | Sword & Shield `slash` | pack complet | Mappage explicite actif ; valider visuellement le sens droite vers gauche. `Sword_Regular_A` reste le fallback sûr. |
| Light 2 immobile, gauche vers droite | Sword & Shield `slash (3)` | pack complet | Mappage explicite actif ; valider visuellement le sens opposé à Light 1. `Sword_Regular_B` reste le fallback sûr. |
| Light 3 finisher diagonal/vertical | Sword & Shield `attack (3)` | `verticalSwordAttack`, `Axe Standing Melee Attack Downward` | Finisher externe actif ; comparer visuellement les trois candidats avant verrouillage artistique. |
| Light en course | Sword & Shield `slash`, `slash (3)` et `attack (3)`, superposés à la course | pack complet | Mappage explicite actif ; validation artistique finale du sens A/B encore utile. |
| Light après dash | Sword & Shield `slash (4)` | pack complet | Corps entier, accéléré et découpé ; remplace `Sword_Dash_RM`. |
| Light aérien descendant | Mixamo `Great Sword Jump Attack` | présent | Intégré comme corps entier, accéléré et sans root motion. |
| Light pendant glissade | `Great Sword Slide Attackleft/right` | présents | Deux clips distincts intégrés, corps entier, déplacement mécanique toujours collisionné. |
| Heavy chargée | charge UAL stable + release Sword & Shield selon puissance | pack complet | `attack (4)` rapide, `attack (2)` normale et `attack` maximale ; course en corps entier. |
| Heavy au maximum | même clip + lame pulsante, cue/FOV/vibration au cap | aucun impact maximal dédié | Le maximum est maintenant très lisible. Chercher une release maximale plus lourde si l'actuelle reste trop proche d'une charge moyenne. |
| Spirale haute | `Great Sword High Spin Attack` | présent | Intégrée à environ 0,63 s ; la rotation procédurale a été retirée pour éviter le double spin. |
| Spirale basse | `Great Sword Slash` | `Standing Melee Attack 360 Low` rejetée | Intégrée à environ 0,52 s. La mesure d'orientation donne seulement 10 % de frames lame haute contre plus de la moitié pour l'ancien candidat. |
| Garde | Sword & Shield `block idle` + `impact` | pack complet | Garde stable et réaction visible à chaque blocage réel. |
| Parade / contre | garde sans fenêtre de parade | aucun clip confirmé | Il manque une parade très courte et un contre stable, idéalement deux clips séparés. |
| Guard break | aucun système joueur dédié | aucun clip confirmé | Animation caractéristique manquante, plus réaction de garde brisée. |
| Launcher | absent | aucun clip confirmé | Animation ascendante manquante si cette attaque est retenue dans le moveset. |

## Retarget Mixamo validé

L'ancien transfert local Mixamo → UAL1 a été retiré : il associait correctement
les noms gauche/droite, mais ne corrigeait pas les axes de repos en espace modèle.
C'était la cause des bras tordus et des spirales qui enroulaient le corps.

Le pipeline actif est désormais :

`FBX Mixamo → BoneMap SkeletonProfileHumanoid → RetargetModifier3D Godot → proxy UAL1 → blend joueur`.

- le BoneMap UAL1 couvre ses 53 os et le BoneMap Mixamo les 52 os humanoïdes
  communs (Mixamo ne possède pas le `Root` UAL1), doigts compris ;
- les pistes d'animation sont renommées vers les 56 noms du profil humanoïde ;
- `RetargetModifier3D` ne transfère que les rotations ;
- positions, échelles et root motion restent sous le contrôle du gameplay ;
- le proxy est un Skeleton3D léger, sans mesh ni AnimationPlayer ;
- la banque de 18 donneurs n'est créée que pour le joueur, jamais pour les IA.

`tools/retarget_mapping_audit.gd` valide 53/53 correspondances, les côtés et les
chaînes de parents. `tools/pose_integrity_probe.gd` échantillonne 90 poses sur
les 18 clips et contrôle les huit modèles ennemis : zéro déformation et zéro
ennemi couché. `tools/retarget_visual_capture.gd` rend Light 1, Light 2, Heavy,
spirale haute et spirale basse avec l'épée attachée pour vérifier la silhouette
et l'orientation réelle de la lame.

Les deux anciennes sondes qui validaient seulement « des os ont bougé » ont été
supprimées : elles pouvaient déclarer PASS sur une pose visuellement cassée.

## Ordre d'implémentation

1. [fait] Stabiliser la table Light A/B/C et mesurer les trajectoires réelles de lame.
2. [en cours] Créer les profils de timings et d'assistance, sans changer le système de dégâts.
3. [fait, à régler] Ajouter la cible persistante, la rotation startup progressive et le lunge.
4. [fait] Intégrer les donneurs Mixamo validés dans le pilote runtime.
5. [fait] Compléter les contextes run/dash/air/slide avec des clips directionnels.
6. [fait] Remplacer les spirales procédurales par deux animations dédiées.
7. [fait, à régler visuellement] Séparer charge, release normale et release maximale de Heavy.
8. Ajouter parade/contre, guard break et éventuellement launcher.
9. Régler les fenêtres de lame et les dégâts à partir des clips définitifs.
10. Faire les tests de lisibilité, tunneling, foule et démembrement.

## Mesure automatique Heavy / spirales

La sonde `tools/combat_attack_probe.gd` exécute les animations sur le véritable
joueur armé et mesure la trajectoire locale de la pointe de l'épée :

- Heavy course : Sword & Shield `attack (2)`, durée 0,77 s, trajectoire de pointe
  autour de 21,8 m et amplitude verticale autour de 2,93 m ;
- spirale haute : `Great Sword High Spin Attack`, durée 0,63 s et trajectoire
  autour de 26,6 m ;
- spirale basse : `Great Sword Slash`, durée 0,52 s et trajectoire autour de
  24,7 m ;
- glissade gauche/droite : deux clips distincts de 0,76 s, trajectoires autour
  de 17,9 m et 20,3 m.

Ce test prouve que chaque animation dédiée déplace réellement la lame. Il ne
remplace pas la validation artistique en jeu du cadrage, du sens et du rythme.

## Feedback sensoriel implémenté

- `HitEvent` contient maintenant matériau, type de contact, partie du corps et
  position relative du contact sur la lame ;
- le même événement accepté déclenche caméra directionnelle, vibration,
  cue audio et cue VFX ;
- aucun Light, Heavy, impact chair ou blocage ordinaire ne ralentit le temps ;
- la garde réussie produit réaction animée, kick, vibration, 12–18 étincelles,
  micro lumière et disque d'impact ;
- les défenses ennemies remontent `shield`, `parry` ou `armor` dans le HitEvent :
  métal/étincelles/rebond remplacent alors chair/sang ;
- seule une décapitation confirmée, une mort tête extrêmement violente ou un
  démembrement Heavy/spirale/Light 3 suffisamment puissant lance une
  cinématique rare : 0,34× pendant environ 0,48 s, déplacement latéral,
  rotation/FOV smooth et cooldown de 5,5 s ;
- le FOV anticipe légèrement Heavy/spirale puis respire à l'impact ;
- les sons manquants sont toujours ignorés sans erreur.
