# Registre de la soundbank combat

Ce registre décrit le branchement de `audio/soundbank`. Les variantes indiquées dans une même banque sont choisies aléatoirement, sans répétition immédiate. Elles ne sont jamais mélangées avec une autre fonction.

| Déclencheur de jeu | Banque interne | Sons utilisés | Règle |
|---|---|---|---|
| Light 1 au sol, à l'arrêt, en course ou en dash | `sword_light_1` | `swordLight1.mp3` | Joué au passage rapide de la lame de Light 1. |
| Light 2 ou Light 3 au sol, en course ou en dash | `sword_light` | `swordSimpleLight.mp3` | Joué au passage rapide de la lame. |
| Light aérienne | `sword_light_air` | `swordLightWhileJumping.mp3` | Remplace la banque light au passage rapide de la lame en l'air. N'altère pas la trajectoire. |
| Heavy aérienne ou spirale aérienne | `sword_attack_air` | `swordFromTheAir.mp3` | Joué au passage rapide de la lame en contexte aérien. |
| Heavy au sol | `sword_heavy` | `audio/sfxSuno/sword.mp3`, `audio/sfxSuno/sword2.mp3` | Retour aux deux sons d'épée génériques précédents, tirés au hasard. La lourde aérienne reste séparée. |
| Spirale au sol | `sword_spiral_ground` | `swordHeavy1.mp3` | Conserve l'ancien son lourd pour Spiral Up et Spiral Down au sol. |
| Attaque pendant une slide | `sword_slide` | `swordFromSliding.mp3`, `swordFromSliding2.mp3` | Une des deux variantes est tirée au hasard. |
| Contre-attaque parfaite, avec ou sans dash | `sword_counter` | `swordCounterAttack.mp3` | Joué sur le passage de lame du contre. |
| Impact au sol de Spiral Down | `sword_ground_smash` | `swordFallingOnTheGround.mp3` | Joué à l'atterrissage du smash, pas au début de la chute. |
| Épée contre armure | `sword_armor_impact` | `swordHitArmor.mp3` | Réservé au contact `armor`; aucun son de bouclier n'est ajouté. |
| Épée contre bouclier ou garde brisée | `sword_shield_impact` | `swordHitAShield.mp3`, `swordHitAShield2.mp3`, `swordHitAShield3.mp3` | Une des trois variantes est tirée au hasard. Sert aussi de repli sonore pour une parade si aucune banque de parade dédiée n'existe. |
| Décapitation | `sever_head` | `DecapitaionAndDemembrement.mp3`, `decapitationOrDemembrement2.mp3` | Une des deux variantes est tirée au hasard lorsque la tête est réellement sectionnée. |
| Démembrement hors tête | `sever_limb` | `demembrement.mp3`, `DecapitaionAndDemembrement.mp3`, `decapitationOrDemembrement2.mp3` | Une des trois variantes est tirée au hasard lorsque le membre est réellement sectionné. |
| Dégainer l'épée | `weapon_draw` | `creatorshome-draw-a-sword-327726.mp3` | Son chargé et enregistré, mais volontairement en attente : le jeu ne possède pas encore d'événement de dégainage/rengainage fiable. |

## Routage technique

- Les sons de mouvement de lame se déclenchent sur la vitesse réelle de la lame, pas simplement à l'appui du bouton.
- Les sons de contact utilisent le résultat confirmé du combat : `flesh`, `armor`, `shield`, `parry` ou `guard_break`.
- Le choix aléatoire reste local à la banque du déclencheur et exclut le son joué juste avant lorsque plusieurs variantes sont disponibles.
- Les anciennes banques `audio/sfxSuno` restent utilisées comme repli pour les catégories auxquelles aucun nouveau son ne correspond, notamment chair, mouvements du joueur, cris et morts.
