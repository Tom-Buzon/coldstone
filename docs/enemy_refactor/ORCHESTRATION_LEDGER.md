# Enemy refactor — orchestration ledger

Updated: 2026-08-26

La clôture autoritaire est désormais **22/22 DONE**. Chaque ID possède une fiche distincte sous `docs/enemy_refactor/units/`, un probe comportemental exact, une preuve anatomique 12 zones/10 sections, une planche finale de treize états, une présence Lab/Forge avec actions distribuées et un teardown contrôlé. Le tableau détaillé historique plus bas conserve l'état initial de l'orchestration à des fins de traçabilité; il ne représente plus le verdict courant.

| Roster final | IDs | Fonctionnel | Visuel | Anatomie | Teardown | Statut |
|---|---:|---|---|---|---|---|
| Legacy | 9 | exact par ID | 13 états + Lab/Forge actifs | 12/12, 10 sections | PASS | DONE 9/9 |
| Remplacement | 13 | exact par ID | 13 états + Lab/Forge actifs | 12/12, 10 sections | PASS | DONE 13/13 |
| **Total** | **22** | **PASS** | **PASS** | **PASS** | **PASS** | **DONE 22/22** |

## Ledger final par identité

| ID | Agent/audit | Tests post-revue | Visuel | Démembrement | Perf avant/après | Revue | Statut |
|---|---|---|---|---|---|---|---|
| swordsman | A/C/D/E/F/G | PASS | 13 états | 12/12, 10 sections | globale représentative | corrigée | DONE |
| guardian | A/C/D/E/F/G | PASS | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| spearman | A/C/D/E/F/G | PASS | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| flanker | A/C/D/E/F/G | PASS | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| brute | A/C/D/E/F/G | PASS | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| captain | A/C/D/E/F/G | PASS + knight3 | 13 états + knight3 | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| warlord | A/C/D/E/F/G | PASS + phase 2 exacte | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| boss_colossus | A/C/D/E/F/G | PASS LARGE_BODY | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| boss_bronze | A/C/D/E/F/G | PASS + knight3 | 13 états + knight3 | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| nathenian1 | A/C/D/E/F/G | PASS fallback attaque | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| nsbire1 | A/C/D/E/F/G | PASS fallback attaque | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| nsbire2 | A/C/D/E/F/G | PASS archer | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| nathenian2 | A/C/D/E/F/G | PASS + phase 2 | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| nathenian2_soldier | A/C/D/E/F/G | PASS alias troop | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| bronze_colossus | A/C/D/E/F/G | PASS phase + LARGE_BODY | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| ncenturion | A/C/D/E/F/G | PASS | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| ngeneral | A/C/D/E/F/G | PASS NavMesh/cohorte | 13 états | 12/12, 10 sections | matrice 15/28/36 | corrigée | DONE |
| ngeneral_veteran | A/C/D/E/F/G | PASS cohorte | 13 états | 12/12, 10 sections | N/A — baseline propre non capturée | corrigée | DONE |
| giant_novice | A/C/D/E/F/G | PASS LARGE_BODY | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| giant_standard | A/C/D/E/F/G | PASS LARGE_BODY | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| giant_veteran | A/C/D/E/F/G | PASS phase + LARGE_BODY | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |
| nfull_armor | A/C/D/E/F/G | PASS phases 2/3 | 13 états | 12/12, 10 sections | N/A baseline propre | corrigée | DONE |

## Ledger initial conservé

| ID | Personnage | Famille | Agent | Audit | Tests rouges | Implémentation | Visuel | Démembrement | Perf | Revue | Statut |
|---|---|---|---|---|---|---|---|---|---|---|---|
| swordsman | Swordsman | legacy_standard | A/C/D/E/F/G | en cours | commun phalange/crowd à qualifier | non | non | non | baseline globale | non | AUDITING |
| guardian | Guardian | legacy_standard_shield | A/C/D/E/F/G | en cours | crowd à qualifier | non | non | non | baseline globale | non | AUDITING |
| spearman | Spearman | legacy_phalanx | A/C/D/E/F/G | en cours | roster + crowd rouges | non | non | non | baseline globale | non | AUDITING |
| flanker | Flanker | legacy_standard | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| brute | Brute | legacy_heavy | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| captain | Captain | legacy_elite | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| warlord | Warlord | legacy_boss | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| boss_colossus | Enemy Colossus | legacy_boss | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| boss_bronze | Bronze Boss | legacy_elite | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| nathenian1 | Nathenian I | nathenian | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | preuves historiques seulement | non | baseline globale | non | AUDITING |
| nsbire1 | Levee Civique | nsbire | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| nsbire2 | Archer Leger | nsbire_archer | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| nathenian2 | Briseur de Ligne | nathenian_heavy | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| nathenian2_soldier | Fantassin Lourd Athenien | nathenian_heavy | A/C/D/E/F/G | en cours | alias à valider individuellement | non | non | non | baseline globale | non | AUDITING |
| bronze_colossus | Bronze Colossus | bronze_colossus | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| ncenturion | Taxiarque | ncenturion | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |
| ngeneral | Lancier Hoplite | hoplite_ngeneral | A/C/D/E/F/G | en cours | roster + crowd rouges | historique v3, à revalider | captures historiques | historique zone shader, à étendre | baseline globale | non | AUDITING |
| ngeneral_veteran | Lancier Veteran | hoplite_ngeneral | A/C/D/E/F/G | en cours | roster + crowd rouges | historique v3, à revalider | captures historiques | historique zone shader, à étendre | baseline globale | non | AUDITING |
| giant_novice | Geant Novice | giant_geant1 | A/C/D/E/F/G | en cours | collider tête rouge partagé | non | non | non | baseline globale | non | AUDITING |
| giant_standard | Geant Standard | giant_geant1 | A/C/D/E/F/G | en cours | collider tête rouge partagé | non | non | non | baseline globale | non | AUDITING |
| giant_veteran | Geant Veteran | giant_geant1 | A/C/D/E/F/G | en cours | collider tête rouge partagé | non | non | non | baseline globale | non | AUDITING |
| nfull_armor | Stratege Cuirasse | nfull_armor | A/C/D/E/F/G | en cours | aucun rouge propre identifié | non | non | non | baseline globale | non | AUDITING |

## Blocages initiaux et preuves de clôture

- Fresh logs: `.tmp_tools/enemy_refactor/mission_baseline_*.log`.
- Known environment noise: Windows root certificate store error.
- Forge files are pre-modified user work and remain protected until a scoped integration route is proven.
- Clôture : aucun blocage unitaire actif; les preuves rendues et par-zone sont complètes pour 22/22. Les réserves restantes sont consignées dans les fiches comme limites non bloquantes et dans le rapport final.
