# Expression de besoin — cartes, tracés et points actifs

Document de travail, enrichi au fil des échanges. Statut : **cadrage, rien de ce qui suit n'est implémenté** (sauf mention). Tout dépend de tests en jeu sur le client Forever.

## 1. Besoin de départ
Le tracé actuel (carte du monde et minimap) montre **tous les emplacements possibles** d'une herbe, pas ceux qui sont occupés à l'instant. La route visite donc beaucoup de points vides. Le joueur veut une route qui ne garde que les points **actifs**, et qui se redessine en direct.

## 2. Besoins exprimés
| # | Besoin | Origine |
|---|---|---|
| B1 | Ne garder dans la route que les points actifs | Échange sur le pistage « Trouver les herbes » |
| B2 | Savoir où sont les nœuds en s'appuyant sur le pistage (points jaunes de la minimap) | Capture de la minimap (infobulle « Goldthorn / Up to Snuff ») |
| B3 | Interroger la minimap aux emplacements de notre base, et autour de chacun (croix de 2 pas dans les 8 directions) | Question sur l'imprécision des coordonnées |
| B4 | Retracer la route en direct selon les résultats et la présence des points sur la minimap | Dernière demande |
| B5 | (information) Comprendre la portée maximale de 15 yd de l'add-on Lueur | Capture des réglages de Lueur |
| B6 | **Version simplifiée de B4 (prioritaire)** : garder la route d'origine générée, vérifier sur la minimap que chaque point existe, et retirer de la route (avec `TomTom:RemoveWaypoint`) les points sans correspondance, au fil de l'eau, à une cadence fonction du rayon de la minimap. C'est l'add-on qui interroge la minimap et retire les points lui-même | Dernier résumé du joueur |
| B7 | La vérification peut se faire par **présence** d'un point : le nom lu est secret, mais l'herbe attendue est celle du waypoint, donc le nom n'est pas nécessaire | Second rapport de la sonde |

## 3. Faits établis
- Les points jaunes du pistage sont dessinés par le moteur, pas par des cadres Lua : un add-on ne peut pas les parcourir. Selon un commentaire de la page [GatherMate2](https://www.wowace.com/projects/gathermate2?page=47), les add-ons ne peuvent pas les voir.
- Il existe une lecture indirecte, décrite dans l'[issue #2](https://github.com/Spotnick2/NodeRadar/issues/2) et la [PR #9](https://github.com/Spotnick2/NodeRadar/pull/9) de NodeRadar : `Minimap:UpdateMouseoverAtPoint(x, y)` déplace le survol de la minimap vers un point, puis `C_TooltipInfo.GetMinimapMouseover()` renvoie l'infobulle (le nom de l'herbe). `Minimap:SetUsingSoftCursor(true)` a été ce qui a fait fonctionner la lecture avec le curseur dans le monde. Un balayage complet est mesuré à environ 2 ms. L'API n'y est pas documentée (signatures et valeurs de retour non données).
- D'après la page CurseForge de [NodeRadar](https://www.curseforge.com/wow/addons/node-radar-by-thpi), des mises à jour de Forever (builds 70862 puis 70938, novembre) ont restreint, voire cassé, la lecture de la minimap. C'est le récit d'un seul auteur et les sources divergent : **à valider sur le client du joueur**.
- Cadence utilisée par NodeRadar : une passe toutes les 2 s en mouvement, 6 s à l'arrêt.
- Les points n'existent que dans le rayon de vue de la minimap. Il dépend du zoom : d'environ 67 yd au zoom le plus fort à environ 233 yd au zoom le plus large en extérieur (table de HereBeDragons-Pins-2.0 dans TomTom).
- Repli éprouvé (GatherMate2, GatherRadar, NodeRadar) : enregistrer les nœuds à la récolte, avec l'événement `UNIT_SPELLCAST_SUCCEEDED`.
- B5 : l'add-on Lueur n'a pas été trouvé en ligne et son code n'est pas disponible. 15 yd est le maximum de son curseur. Hypothèse non vérifiée : plafond du système d'interaction du client (`SoftTargetInteractRange`). Test : `/console SoftTargetInteractRange 40` puis `/dump GetCVar("SoftTargetInteractRange")`. La portée de ce mécanisme est bien plus courte que le rayon de la minimap.

### 3 bis Constats du second rapport de la sonde (build 70959)
- Avec la souris posée sur un point jaune, `C_TooltipInfo.GetMinimapMouseover()` renvoie des données dont le **texte est une valeur secrète** (illisible), mais dont la **présence** est lisible. Souris hors de la minimap : aucune donnée.
- Tous les points interrogés par `UpdateMouseoverAtPoint` ont donné une réponse : la lecture reflète le survol réel, pas le point demandé. Le sondage par position n'est donc pas démontré.
- Conséquence : pour sonder la position d'un candidat, il faut que le vrai curseur s'y trouve. Piste : déplacer brièvement la minimap pour amener le candidat sous un curseur au repos (technique décrite pour NodeRadar), avec le risque d'effet visible et de clics interceptés. À tester dans la sonde v2b, en option volontaire.
- Un contrôle par présence ne distingue pas un autre type de nœud au même endroit (faux positifs possibles, accepté).

### 3 ter Ce que documente NodeRadar sur les builds récents
Sources : [docs/FOREVER-PROBE.md](https://github.com/Spotnick2/NodeRadar/blob/main/docs/FOREVER-PROBE.md) et [README](https://github.com/Spotnick2/NodeRadar) (récits d'un auteur, non officiels).
- Build 70862 : `UpdateMouseoverAtPoint` n'a plus d'effet. Build 70888 : avec le vrai curseur sur un nœud, la lecture renvoie ce nœud, pas le point demandé. Build 70938 : le texte d'infobulle est secret, mais « une lecture vide reste simple » : on sait si quelque chose est sous le point, pas quoi. Pas de document sur le build 70959.
- Méthode de NodeRadar : curseur au repos **dans le monde**, minimap déplacée sous le curseur quelques images, lecture, remise en place. Conditions de blocage : combat, bouton enfoncé, lancer de sort, fenêtre de butin, créature ou joueur sous le curseur, bouton de minimap, infobulle ou fenêtre ouverts ; autre add-on ancré à la minimap.
- Zone de réponse d'un nœud : environ 25 sur 25 unités (16 px à l'écran sur 70888).
- Toute la minimap peut répondre pour des objets non-herbes (quêtes, PNJ, joueurs) : sans le nom, un faux positif est possible (D10).

## 4. Conception envisagée

### 4.1 Sondes de validation (`/hr probe`) — première étape (écrites, jouées en partie)
Jeu de sondes **réduit** le 2026-11-19, après les deux premiers rapports en jeu :
- `/hr probe` et `/hr probe minimap` : client, minimap, pistages actifs, fonctions présentes, lecture du survol réel (présence et forme des données). Sert aussi au contrôle « sol vide » (R13).
- `/hr probe blink world [hidden]` : méthode de NodeRadar (curseur au repos dans le monde, minimap déplacée dessous). Seule piste de sondage positionnel restante.
- Retirées car sans objet : balayages de la minimap dans plusieurs conventions de coordonnées, avec curseur logiciel et à +1 image (le sondage par position n'a pas d'effet, écho du survol réel confirmé) ; étalonnage de la zone de réponse et écart à la base (dépendaient de réponses positionnelles) ; test du zoom et des points hors disque (dépendait d'une configuration qui lit) ; `blink` avec le curseur déjà sur la minimap (non concluant, remplacé par `blink world`).
Selon les résultats, on retient la vérification par présence (4.2, 4.3 bis) ou la mémoire de récolte seule (4.4).

### 4.2 Interroger la minimap aux candidats connus
- Candidats = points de notre base dans le disque de la minimap, pour les herbes sélectionnées. La position sur la minimap vient de la projection de `Overlay.lua` (rayon de vue, rotation, facteur 0,9).
- Motif par candidat : centre puis 2 pas dans chacune des 8 directions, soit 17 interrogations. Pas défini en yards (par exemple 3 puis 6) et converti en pixels selon le zoom. *À réévaluer : la zone de réponse rapportée (environ 25 unités) est grande devant l'erreur de nos coordonnées, un sondage au centre pourrait suffire.*
- Arrêt à la première réponse (centre, puis premier anneau, puis second).
- Positions interrogées dédoublonnées sur une grille de pixels (les doublons du JSON sont à 0,1 % les uns des autres).
- Une réponse est rattachée au candidat le plus proche de la position interrogée ; en cas d'égalité, tous les voisins sont marqués actifs.
- Interrogations étalées sur plusieurs images. Cadence : toutes les 2 s en mouvement, plus rarement à l'arrêt, et à chaque changement de tronçon. Seulement si la minimap est visible, le pistage actif et le curseur dans le monde.
- Mesure seulement : l'écart entre le pas qui répond et le centre donne l'erreur de nos coordonnées. Il sert à régler le pas de la croix ; il ne modifie **jamais** la base de données.
- Limites : ne découvre pas de nœud absent de la base ; ne sort pas du disque (dézoomer temporairement élargit le champ mais change l'affichage de la minimap). Les noms d'infobulle sont localisés : hypothèse client en anglais.

### 4.3 Retracé en direct (B4)
États d'un point : *actif* (réponse positive), *vide* (dans le disque, interrogé sans réponse), *inconnu* (hors disque ou non encore interrogé), *pris* (récolté).
- La route est recalculée sur : points actifs ∪ points inconnus, sans les points vides ni pris. Les points inconnus qui entrent dans le disque sont vérifiés, donc la route se resserre toute seule en avançant.
- Le recalcul part de la position du joueur et réutilise `RouteMath.solve` en coroutine.
- Pour éviter les tremblements : le waypoint courant n'est abandonné que s'il devient vide ou est atteint ; seul le reste de la route est recalculé ; recalcul au plus toutes les quelques secondes et seulement si l'ensemble des états a changé.
- Garde-fous contre les faux négatifs : un point n'est déclaré vide qu'après plusieurs passes sans réponse ; sans pistage actif ou sonde fonctionnelle, aucun point n'est marqué vide (on retombe sur la mémoire de récolte) ; un point vide est réinterrogé après un délai.
- Affichage : couleurs par état sur la carte et la minimap (actif, inconnu, vide atténué ou masqué), en plus du tronçon courant.

### 4.3 bis Vérification et suppression de points (B6, remplace le recalcul complet)
La route d'origine est conservée (`r.original`) ; on ne la recalcule pas, on **retire des points**. Le re-calcul complet de 4.3 devient optionnel (désactivé par défaut).
- **Contrainte : base intacte.** `HerbRoute_Data` (la base des points) n'est jamais modifiée ni réduite. Seuls les **waypoints TomTom du trajet en cours** sont retirés (`TomTom:RemoveWaypoint`), plus l'état en mémoire du trajet courant. Chaque nouvelle génération repart de la base complète.
- **Source de vérité** : la liste ordonnée de la route. « Retirer un point » = le marquer retiré dans cette liste, appeler `TomTom:RemoveWaypoint(uid)` si ce point a un waypoint TomTom (tous les points en mode Tout afficher, seulement le point courant en mode Suivi), et rafraîchir les tracés. En mode Suivi, l'avancement saute les points retirés ; les tracés relient les voisins restants.
- **Cycle de vérification** : candidats = points restants, non confirmés, situés dans le disque de la minimap, les plus proches d'abord. Interrogation avec le motif de 4.2. Le nom de l'infobulle doit être celui de l'herbe du point.
  - Réponse : point *confirmé* (conservé, recontrôlé rarement).
  - Pas de réponse : compteur d'échecs +1 ; au K-ième échec consécutif (K = 2 par défaut), le point est retiré.
- **Déclenchement à l'entrée dans le disque (remplace la cadence fixe)** : un test de distance très léger (arithmétique seule, sans appel au moteur, toutes les 0,25 à 0,5 s) compare votre position aux points restants, dont les coordonnées monde sont précalculées. On n'interroge la minimap que lorsqu'un point non vérifié **entre** dans le disque (seuil à 85 % du rayon de vue R, pour éviter les points au bord). Chaque point reçoit au plus 2 à 3 interrogations : à l'entrée, une nouvelle après un court délai (environ 1,5 s, le temps que le point jaune apparaisse) tant qu'il reste dans le disque, et une dernière avant d'arriver à portée de récolte (environ 30 yd) pour détecter un nœud pris entre-temps par un autre joueur. Les points confirmés ne sont pas réinterrogés avant cette dernière vérification. Un changement de zoom, de rotation ou de pistage remet tous les points du disque à vérifier. Les interrogations d'une passe restent étalées sur plusieurs images. La vitesse du joueur n'intervient plus.
- **Garde-fous** : aucun retrait si le pistage de l'herbe n'est pas actif, si la minimap n'est pas visible, si le joueur n'est pas sur la carte de la route, ou si la lecture est jugée non fonctionnelle (aucune réponse sur toute une passe avec plusieurs candidats : message d'avertissement, on ne retire rien). Pas de retrait en combat.
- **Restauration** : `/hr restore` remet la route d'origine ; compteurs (conservés, confirmés, retirés) dans l'UI.
- **Modules** : nouveau `Probe.lua` (primitives de lecture et `/hr probe`), nouveau `Verify.lua` (boucle, états, cadence), modifications de `Runner.lua` (état retiré, `RemovePoint`, avancement), `Overlay.lua` (ignorer les retirés, couleur des confirmés), `UI.lua` (case « Vérifier avec la minimap », compteurs), `Core.lua` (commandes).
- **Tests** : un faux minimap dans `tools/test_addon.py` (blips simulés, tooltips renvoyés par point) pour valider états, retraits, cadence et garde-fous. Le comportement réel reste à valider en jeu.

### 4.4 Mémoire de récolte (repli, indépendant de la minimap)
*Les états pris/vide de cette mémoire sont séparés de la base (`HerbRouteDB`, jamais `HerbRoute_Data`) et optionnels : à confirmer avant de les faire survivre d'un trajet à l'autre, puisque chaque génération repart de la base complète.*
États *pris* / *vide* stockés dans `HerbRouteDB` avec la date. La récolte (`UNIT_SPELLCAST_SUCCEEDED`) marque le point le plus proche comme pris ; le bouton Skip devient « rien ici ». Les points marqués depuis moins de N minutes sont filtrés avant le calcul. N réglable ; durées de réapparition de Forever inconnues, à mesurer.

### 4.5 Pistage automatique
Activer « Trouver les herbes » au lancement d'une route (`C_Minimap.GetNumTrackingTypes`, `GetTrackingInfo`, `SetTracking`, signatures à confirmer en jeu).

## 5. Questions ouvertes
1. Un sondage par position est-il possible ? Constat (build 70959) : la présence d'un point sous le vrai curseur est lisible (nom secret), mais `UpdateMouseoverAtPoint` ne semble pas déplacer le survol (100 % de réponses partout, souris sur un point). À tester : déplacement furtif de la minimap sous le curseur (sonde v2b).
2. Taille de la zone qui réagit autour d'un point jaune, donc pas utile de la croix.
3. Erreur réelle de nos coordonnées par rapport aux nœuds.
4. Durées de réapparition des herbes sur Forever.
5. Langue du client (noms d'infobulle).
6. Une passe de 17 interrogations par candidat est-elle acceptable pour les performances en jeu ?

## 6. Ordre de réalisation proposé
1. `/hr probe` (validation en jeu).
2. États des points, `RemovePoint` et restauration (Runner/Overlay), puis mémoire de récolte (4.4), utile même si la minimap est bloquée.
3. Vérification et suppression (4.3 bis) avec la croix (4.2) et l'activation automatique du pistage (4.5).
4. Optionnel : recalcul complet (4.3) et couleurs supplémentaires sur les tracés.
