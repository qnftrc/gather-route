# Journal de pilotage

Registre chronologique des décisions, constats, risques et prochaines actions. À compléter à chaque séance. Le détail du besoin est dans [BESOINS.md](BESOINS.md), l'état des fonctionnalités dans [FONCTIONNALITES.md](FONCTIONNALITES.md).

## Prochaines actions
1. Écrire `/hr probe` (validation de la lecture de la minimap en jeu) — en attente de feu vert.
2. Tester en jeu l'add-on déjà livré : `/hr debug`, UI, flèche, tracés carte et minimap, avec `/console scriptErrors 1`.
3. Décider du sort de la mémoire de récolte (survit-elle d'un trajet à l'autre ?).

## Journal

### 2026-11-19 — Construction de l'add-on HerbRoute (v1.0.0)
- Entrées analysées : TomTom v4.4.1, planner HTML, JSON de waypoints (45 régions, 29 herbes, 13 256 points).
- Plan présenté et validé, avec deux ajouts demandés : aperçu du tracé sur la carte et la minimap, et moyen de supprimer la route à tout moment.
- Add-on séparé écrit : données, résolution des régions, algorithme, pilotage TomTom, tracés, interface.
- Vérifications hors jeu : algorithme Lua identique au planner sur 4 cas (dont 702 et 742 points) ; logique testée sur faux environnement WoW/TomTom.
- Aucun client WoW disponible : interface et tracés jamais exécutés en jeu.
- Dépôt `qnftrc/gather-route` (vide) rattaché en écriture ; add-on et scripts poussés sur `main`. Documentation de contexte ajoutée (`README.md`, `CLAUDE.md`, `tools/README.md`).

### 2026-11-19 — Cadrage : points actifs, minimap, retracé
- Capture de la minimap : le point jaune « Goldthorn / Up to Snuff » vient du pistage « Trouver les herbes ».
- Constat : les points du pistage sont dessinés par le moteur et ne sont pas lisibles directement par un add-on (témoignages sur GatherMate2).
- Recherche : NodeRadar (issue #2, PR #9) décrit une lecture indirecte via `Minimap:UpdateMouseoverAtPoint` et `C_TooltipInfo.GetMinimapMouseover`. Elle a exigé le curseur sur la minimap, puis fonctionné avec le curseur logiciel. Des mises à jour de Forever (builds 70862 puis 70938) auraient restreint cette lecture : récit d'un seul auteur, à valider.
- Limites réseau de la session : `www.curseforge.com` et `warcraft.wiki.gg` inaccessibles ; GitHub accessible.
- Add-on Lueur (capture des réglages) : introuvable en ligne, raison du plafond de 15 yd inconnue. Hypothèse non vérifiée : plafond du système d'interaction du client.
- Besoin simplifié formulé (B6) : garder la route d'origine, vérifier chaque point sur la minimap, retirer les waypoints sans correspondance.

## Décisions
| Réf. | Décision | Date | Statut |
|---|---|---|---|
| D1 | Add-on séparé, dépendant de TomTom, API publique uniquement | 2026-11-19 | Appliquée |
| D2 | Algorithme repris à l'identique du planner HTML | 2026-11-19 | Appliquée |
| D3 | Deux modes : Suivi (un waypoint à la fois) et Tout afficher | 2026-11-19 | Appliquée |
| D4 | Tracés carte et minimap dessinés par l'add-on | 2026-11-19 | Appliquée (non testée en jeu) |
| D5 | Sondage de la minimap aux seuls emplacements connus, avec croix de 17 positions | 2026-11-19 | Cadrée |
| D6 | Vérification déclenchée à l'entrée d'un point dans le disque de la minimap, 2 à 3 interrogations par point | 2026-11-19 | Cadrée |
| D7 | La route d'origine est conservée ; on retire des points au lieu de la recalculer | 2026-11-19 | Cadrée |
| D8 | **Base intacte** : `HerbRoute_Data` n'est jamais modifiée ; seuls les waypoints TomTom du trajet en cours sont retirés | 2026-11-19 | Contrainte |
| D9 | Pas de recalage de la base à partir des écarts mesurés | 2026-11-19 | Contrainte |

## Risques et questions ouvertes
| Réf. | Sujet | État |
|---|---|---|
| R1 | La lecture de la minimap fonctionne-t-elle sur le client du joueur (build, curseur, curseur logiciel) ? | Ouvert, test = `/hr probe` |
| R2 | Faux négatifs : un nœud existant non détecté serait retiré à tort | Atténué par K échecs, garde-fous, restauration |
| R3 | Taille de la zone qui réagit autour d'un point jaune, donc pas de la croix | À mesurer en jeu |
| R4 | Erreur réelle de nos coordonnées par rapport aux nœuds | À mesurer en jeu |
| R5 | Durées de réapparition des herbes sur Forever | Inconnu |
| R6 | Langue du client : noms de régions et d'infobulles en anglais supposés | Hypothèse |
| R7 | Noms de modèles d'interface et API de carte supposés présents sur ce client | Non vérifié |
| R8 | Délai d'apparition d'un point jaune après son entrée dans le disque (estimé 1,5 s) | À mesurer |
| R9 | Coût d'une passe de 17 interrogations par candidat | À mesurer |
| R10 | Tracé minimap (rotation, zoom) jamais vu en jeu | Non testé |

## Commits
| Commit | Contenu |
|---|---|
| `0dac733` | Add-on HerbRoute et scripts de données et de test |
| `5da3722` | README, CLAUDE.md, tools/README |
| `c6f1824` | Document d'expression de besoin |
| `934f3ef` | Besoin B6 : vérification et suppression de points |
| `4ec07a8` | Déclenchement à l'entrée dans le disque |
| `0d8991c` | Contrainte « base intacte » |
