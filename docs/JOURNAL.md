# Journal de pilotage

Registre chronologique des décisions, constats, risques et prochaines actions. À compléter à chaque séance. Le détail du besoin est dans [BESOINS.md](BESOINS.md), l'état des fonctionnalités dans [FONCTIONNALITES.md](FONCTIONNALITES.md).

## Prochaines actions
1. **Lancer `/hr probe blink world`** en jeu (phase A : souris sur un point jaune ; phase B : souris dans le monde, immobile, hors de toute fenêtre), puis `/hr probe blink world hidden` si l'effet visible gêne, et renvoyer les rapports. Faire aussi `/hr probe minimap` avec la souris sur un sol **vide** de la minimap pour savoir si la présence dépend d'un point jaune (R13).
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

### 2026-11-19 — `/hr probe` écrit (F20)
- Feu vert donné ; fenêtre à copier-coller incluse (le choix n'avait pas été tranché explicitement).
- Contenu : environnement, fonctions présentes, balayage dans deux conventions de coordonnées (écran/curseur et unités d'interface), avec et sans curseur logiciel, détection des valeurs secrètes, étalonnage de la zone qui répond, distance entre un point lu et le point de la base le plus proche (rotation désactivée), test du zoom et des points hors disque.
- Effets de bord limités : curseur logiciel remis à faux, zoom restauré, base jamais touchée.
- Vérifié hors jeu sur un faux minimap (lecture seulement avec curseur logiciel et convention écran, écart mesuré 0,4 yd, cas sans lecture, valeurs secrètes, fonction absente, zoom). Cela confirme aussi la cohérence de la projection inverse avec celle de `Overlay.lua`, sur le faux monde seulement.
- Pas implémenté : `/hr probe blink` (déplacement furtif de la minimap, F30), volontairement laissé à plus tard.

### 2026-11-19 — Premier rapport de `/hr probe` (build 70959)
- Client : version 1.60.1, build 70959, toc 16001, langue enUS. Minimap 198x198 unités, zoom 0, rayon de vue 233,3 yd, rotation désactivée. Curseur hors de la minimap.
- Pistages actifs : Find Herbs, Flight Master, Innkeeper, Account Completed Quests, Track Quest POIs. Aucune fonction manquante.
- Balayages (687 interrogations chacun, 0,6 ms sans curseur logiciel, 1,2 ms avec) : **0 réponse** en `cursor/hard`, `cursor/soft`, `ui/hard`, `ui/soft`. Aucune erreur renvoyée par les appels. Verdict de la sonde : aucune lecture.
- Interprétation prudente : les fonctions existent et s'exécutent, mais rien n'est lu dans ces conditions. Compatible avec une restriction de lecture introduite par les builds récents (70862 puis 70938, d'après NodeRadar), avec un besoin du vrai curseur sur la minimap, avec une latence d'une image entre `UpdateMouseoverAtPoint` et la lecture, ou avec une autre convention de coordonnées. À confirmer qu'un point jaune d'herbe était visible pendant l'essai.
- Limite de la sonde v1 : elle ne distingue pas « aucune donnée » de « données dans une autre forme » (le texte est lu seulement dans `lines[1].leftText`), et ne teste ni la lecture avec la souris réellement posée sur un point, ni le décalage d'une image.
- Correction de contexte : le client n'est pas annoncé en 12.1.x (voir `CLAUDE.md`).

### 2026-11-19 — Second rapport de `/hr probe` : souris sur un point jaune
- Conditions : souris posée sur un point jaune d'herbe (l'infobulle native affiche « Wild Steelbloom »). Zoom 1, rayon de vue 200 yd. Le drapeau `MouseIsOver(Minimap)` a renvoyé faux malgré le curseur sur la minimap : il n'est pas fiable (v2a le complète par un calcul géométrique).
- Résultat brut : les 4 balayages (687 interrogations) ont renvoyé **687 réponses sur 687**, toutes avec un texte **secret**. Le premier rapport (souris hors minimap) donnait 0 sur 687.
- Interprétation : 100 % de réponses quel que soit le point demandé signifie que la donnée lue ne dépend pas du point interrogé : c'est le survol **réel** de la souris. Le verdict « lecture réussie » de la sonde v1 était donc un faux positif, et les « 175 points trouvés », la « zone de réponse de 50 yd » et l'absence de correspondance avec la base n'ont pas de sens.
- Acquis : la présence d'un point sous le vrai curseur est lisible par l'add-on ; son nom est une valeur secrète. Non acquis : un sondage par position (`UpdateMouseoverAtPoint` ne semble pas déplacer le survol).
- Le joueur accepte les noms secrets : l'herbe attendue est celle du waypoint, la présence suffit (décision D10, avec ses limites).
- Correction de la sonde (v2a, livrée) : détection de l'écho du survol réel (verdict dédié), lecture de base sans appel de sondage, structure des données, présence comptée même sans texte, lecture une image plus tard, position du curseur par calcul géométrique. Test hors jeu complété (cas d'écho, valeurs secrètes).
- Correction du journal : la ligne R1 de la première séance n'avait pas été mise à jour par erreur de script ; c'est fait.

### 2026-11-19 — `/hr probe blink` écrit (F35, sonde v2b)
- Principe : avec le vrai curseur immobile sur un point jaune, la minimap est déplacée de 40 unités (4 directions compatibles avec un curseur qui reste dans le disque), la lecture est relevée 1 et 3 images plus tard, puis la minimap est remise en place et la lecture de retour relevée. Deux variantes par déplacement : simple, et avec `UpdateMouseoverAtPoint` à la position du curseur.
- Verdict : la lecture « suit » la minimap si elle disparaît à chaque déplacement et revient au retour ; « inchangée » si elle reste présente (le survol n'est pas rafraîchi sans mouvement réel de la souris) ; sinon non concluant (autre point sous le curseur, lecture instable).
- Garde-fous : abandon en combat, bouton de souris enfoncé, souris déplacée de plus de 3 pixels, curseur hors du disque, absence de donnée au départ ; ancrages et alpha de la minimap toujours restaurés ; délai de sécurité de 30 s.
- Option `blink hidden` : minimap rendue invisible (alpha 0) pendant les déplacements, pour limiter l'effet visuel ; à comparer avec la version visible.
- Vérifié hors jeu sur un moteur simulé (quatre comportements et six cas d'abandon). Le comportement réel du moteur est inconnu.
- Risques : effet visible sur la minimap pendant l'essai (quelques dixièmes de seconde), clic intercepté si un bouton est pressé (d'où la garde), conflit avec un autre add-on de minimap (position réancrée).

### 2026-11-19 — Résultat de `/hr probe blink` et recherche sur NodeRadar
- Rapport en jeu : contrôle présent, puis lecture **présente et inchangée** (1 image, 3 images, retour) pour les 4 déplacements, avec et sans `UpdateMouseoverAtPoint`. Verdict de la sonde : le survol n'est pas rafraîchi sans mouvement réel de la souris. Minimap restaurée.
- Ce test n'est pas équivalent à la méthode documentée par NodeRadar : il part d'un curseur **déjà sur la minimap** (même cadre survolé avant et après le déplacement). NodeRadar part d'un curseur **au repos dans le monde** et amène la minimap dessous, ce qui change le cadre survolé. Le test n'est donc pas concluant pour cette méthode (voir ci-dessous).
- Source : [docs/FOREVER-PROBE.md](https://github.com/Spotnick2/NodeRadar/blob/main/docs/FOREVER-PROBE.md) et [README](https://github.com/Spotnick2/NodeRadar) de NodeRadar. Constats rapportés par son auteur : build 70862, `UpdateMouseoverAtPoint` n'a plus d'effet (« Minimap is off limits », API à supprimer) ; build 70888, avec le vrai curseur sur un nœud la lecture renvoie le nœud sous le curseur et non le point demandé (**exactement notre écho**) ; build 70938, le texte devient secret mais « une lecture vide reste simple », donc on peut savoir **si** quelque chose est sous le point, pas quoi. NodeRadar arrête son balayage à partir de 70938 faute de noms.
- Conséquence : la vérification par **présence** (D10) est précisément le cas que NodeRadar n'exploite pas ; elle est plausible mais non démontrée sur le build 70959.
- Méthode de NodeRadar (README) : curseur au repos sur le monde, minimap déplacée sous le curseur quelques images, lecture, remise en place ; pas en combat, pas de bouton enfoncé, pas pendant un lancer de sort ni une fenêtre de butin, pas sur une créature ou un joueur, pas sur un bouton de la minimap, pas avec une infobulle, un menu ou une fenêtre ouverts ; un autre add-on ancré à la minimap arrête le balayage.
- Zone de réponse rapportée : environ 25 sur 25 unités autour du point (16 px à l'écran sur le build 70888). Elle est grande devant l'erreur de nos coordonnées : un sondage au centre pourrait suffire, la croix de 17 positions est à réévaluer après mesure.
- Idée notée, non retenue pour l'instant : identifier un point d'herbe par différence en coupant puis rétablissant le pistage (round 3 de NodeRadar), mais le rétablissement lance un sort de pistage avec temps de recharge sur la barre d'actions.
- Écrit : `/hr probe blink world` (F36), qui reproduit la méthode : phase A, la souris sur un point jaune (décalage mémorisé) ; phase B, la souris au repos dans le monde, la minimap est déplacée pour amener le point sous le curseur (cas « touché ») ou à côté (contrôles), lecture à 1, 3 et 6 images, remise en place. Verdict : sondage de présence faisable, ou non. Tests hors jeu sur moteur simulé (cinq comportements, cinq abandons).

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
| D10 | Vérification par **présence** d'un point : le nom (secret) n'est pas nécessaire, l'herbe attendue étant celle du waypoint. Limite : un autre type de nœud au même endroit compterait comme présent | 2026-11-19 | Retenue (sous réserve d'un sondage positionnel fonctionnel) |

## Risques et questions ouvertes
| Réf. | Sujet | État |
|---|---|---|
| R1 | La lecture de la minimap fonctionne-t-elle sur le client du joueur ? | Partiel : on lit la présence d'un point sous le **vrai** curseur, le nom est secret ; le sondage par position n'est pas démontré (R12) |
| R2 | Faux négatifs : un nœud existant non détecté serait retiré à tort | Atténué par K échecs, garde-fous, restauration |
| R3 | Taille de la zone qui réagit autour d'un point jaune, donc pas de la croix | À mesurer en jeu |
| R4 | Erreur réelle de nos coordonnées par rapport aux nœuds | À mesurer en jeu |
| R5 | Durées de réapparition des herbes sur Forever | Inconnu |
| R6 | Langue du client : noms de régions et d'infobulles en anglais supposés | Hypothèse |
| R7 | Noms de modèles d'interface et API de carte supposés présents sur ce client | Non vérifié |
| R8 | Délai d'apparition d'un point jaune après son entrée dans le disque (estimé 1,5 s) | À mesurer |
| R9 | Coût d'une passe de 17 interrogations par candidat | À mesurer |
| R10 | Tracé minimap (rotation, zoom) jamais vu en jeu | Non testé |
| R11 | Noms d'infobulle secrets : pas de contrôle du type d'herbe, faux positifs possibles entre nœuds voisins | Accepté (D10) |
| R12 | `UpdateMouseoverAtPoint` n'a pas d'effet positionnel (confirmé par la documentation de NodeRadar : sans effet dès le build 70862). Seule piste connue : déplacer la minimap sous un curseur au repos dans le monde | Ouvert, test = `/hr probe blink world` |
| R13 | La présence de données est-elle liée à un point jaune sous le curseur, ou à la seule présence du curseur sur la minimap ? Jamais testé sur un sol vide | Ouvert, test = `/hr probe minimap` sur sol vide |
| R14 | Le build 70959 (postérieur à 70938, dernier build documenté par NodeRadar) peut restreindre davantage | Ouvert |

## Commits
| Commit | Contenu |
|---|---|
| `0dac733` | Add-on HerbRoute et scripts de données et de test |
| `5da3722` | README, CLAUDE.md, tools/README |
| `c6f1824` | Document d'expression de besoin |
| `934f3ef` | Besoin B6 : vérification et suppression de points |
| `4ec07a8` | Déclenchement à l'entrée dans le disque |
| `0d8991c` | Contrainte « base intacte » |
| `999f8c8` | Journal de pilotage et suivi des fonctionnalités |
| `d3f85b0` | Règle de travail : consulter et mettre à jour les documents |
| `9519f0b` | `/hr probe` (sonde v1) |
| `62ba128` | Premier rapport de la sonde, correction du contexte client |
