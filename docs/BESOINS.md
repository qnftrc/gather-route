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

## 3. Faits établis
- Les points jaunes du pistage sont dessinés par le moteur, pas par des cadres Lua : un add-on ne peut pas les parcourir. Selon un commentaire de la page [GatherMate2](https://www.wowace.com/projects/gathermate2?page=47), les add-ons ne peuvent pas les voir.
- Il existe une lecture indirecte, décrite dans l'[issue #2](https://github.com/Spotnick2/NodeRadar/issues/2) et la [PR #9](https://github.com/Spotnick2/NodeRadar/pull/9) de NodeRadar : `Minimap:UpdateMouseoverAtPoint(x, y)` déplace le survol de la minimap vers un point, puis `C_TooltipInfo.GetMinimapMouseover()` renvoie l'infobulle (le nom de l'herbe). `Minimap:SetUsingSoftCursor(true)` a été ce qui a fait fonctionner la lecture avec le curseur dans le monde. Un balayage complet est mesuré à environ 2 ms. L'API n'y est pas documentée (signatures et valeurs de retour non données).
- D'après la page CurseForge de [NodeRadar](https://www.curseforge.com/wow/addons/node-radar-by-thpi), des mises à jour de Forever (builds 70862 puis 70938, novembre) ont restreint, voire cassé, la lecture de la minimap. C'est le récit d'un seul auteur et les sources divergent : **à valider sur le client du joueur**.
- Cadence utilisée par NodeRadar : une passe toutes les 2 s en mouvement, 6 s à l'arrêt.
- Les points n'existent que dans le rayon de vue de la minimap. Il dépend du zoom : d'environ 67 yd au zoom le plus fort à environ 233 yd au zoom le plus large en extérieur (table de HereBeDragons-Pins-2.0 dans TomTom).
- Repli éprouvé (GatherMate2, GatherRadar, NodeRadar) : enregistrer les nœuds à la récolte, avec l'événement `UNIT_SPELLCAST_SUCCEEDED`.
- B5 : l'add-on Lueur n'a pas été trouvé en ligne et son code n'est pas disponible. 15 yd est le maximum de son curseur. Hypothèse non vérifiée : plafond du système d'interaction du client (`SoftTargetInteractRange`). Test : `/console SoftTargetInteractRange 40` puis `/dump GetCVar("SoftTargetInteractRange")`. La portée de ce mécanisme est bien plus courte que le rayon de la minimap.

## 4. Conception envisagée

### 4.1 Sonde de validation (`/hr probe`) — première étape
Teste en jeu : existence de `UpdateMouseoverAtPoint` et `GetMinimapMouseover`, nom d'herbe renvoyé quand un point jaune est sous le point interrogé (curseur dans le monde et sur la minimap), durée d'une passe, effet du zoom, points hors disque. Selon le résultat, on retient la lecture de la minimap (4.2), ou la mémoire de récolte seule (4.4).

### 4.2 Interroger la minimap aux candidats connus
- Candidats = points de notre base dans le disque de la minimap, pour les herbes sélectionnées. La position sur la minimap vient de la projection de `Overlay.lua` (rayon de vue, rotation, facteur 0,9).
- Motif par candidat : centre puis 2 pas dans chacune des 8 directions, soit 17 interrogations. Pas défini en yards (par exemple 3 puis 6) et converti en pixels selon le zoom.
- Arrêt à la première réponse (centre, puis premier anneau, puis second).
- Positions interrogées dédoublonnées sur une grille de pixels (les doublons du JSON sont à 0,1 % les uns des autres).
- Une réponse est rattachée au candidat le plus proche de la position interrogée ; en cas d'égalité, tous les voisins sont marqués actifs.
- Interrogations étalées sur plusieurs images. Cadence : toutes les 2 s en mouvement, plus rarement à l'arrêt, et à chaque changement de tronçon. Seulement si la minimap est visible, le pistage actif et le curseur dans le monde.
- Bonus : l'écart entre le pas qui répond et le centre mesure l'erreur de notre coordonnée. Il peut servir à régler le pas ou à recaler la base.
- Limites : ne découvre pas de nœud absent de la base ; ne sort pas du disque (dézoomer temporairement élargit le champ mais change l'affichage de la minimap). Les noms d'infobulle sont localisés : hypothèse client en anglais.

### 4.3 Retracé en direct (B4)
États d'un point : *actif* (réponse positive), *vide* (dans le disque, interrogé sans réponse), *inconnu* (hors disque ou non encore interrogé), *pris* (récolté).
- La route est recalculée sur : points actifs ∪ points inconnus, sans les points vides ni pris. Les points inconnus qui entrent dans le disque sont vérifiés, donc la route se resserre toute seule en avançant.
- Le recalcul part de la position du joueur et réutilise `RouteMath.solve` en coroutine.
- Pour éviter les tremblements : le waypoint courant n'est abandonné que s'il devient vide ou est atteint ; seul le reste de la route est recalculé ; recalcul au plus toutes les quelques secondes et seulement si l'ensemble des états a changé.
- Garde-fous contre les faux négatifs : un point n'est déclaré vide qu'après plusieurs passes sans réponse ; sans pistage actif ou sonde fonctionnelle, aucun point n'est marqué vide (on retombe sur la mémoire de récolte) ; un point vide est réinterrogé après un délai.
- Affichage : couleurs par état sur la carte et la minimap (actif, inconnu, vide atténué ou masqué), en plus du tronçon courant.

### 4.4 Mémoire de récolte (repli, indépendant de la minimap)
États *pris* / *vide* stockés dans `HerbRouteDB` avec la date. La récolte (`UNIT_SPELLCAST_SUCCEEDED`) marque le point le plus proche comme pris ; le bouton Skip devient « rien ici ». Les points marqués depuis moins de N minutes sont filtrés avant le calcul. N réglable ; durées de réapparition de Forever inconnues, à mesurer.

### 4.5 Pistage automatique
Activer « Trouver les herbes » au lancement d'une route (`C_Minimap.GetNumTrackingTypes`, `GetTrackingInfo`, `SetTracking`, signatures à confirmer en jeu).

## 5. Questions ouvertes
1. La lecture de la minimap fonctionne-t-elle sur le client du joueur (build, curseur, soft cursor) ?
2. Taille de la zone qui réagit autour d'un point jaune, donc pas utile de la croix.
3. Erreur réelle de nos coordonnées par rapport aux nœuds.
4. Durées de réapparition des herbes sur Forever.
5. Langue du client (noms d'infobulle).
6. Une passe de 17 interrogations par candidat est-elle acceptable pour les performances en jeu ?

## 6. Ordre de réalisation proposé
1. `/hr probe` (validation).
2. États des points et mémoire de récolte (4.4), utile même si la minimap est bloquée.
3. Interrogation des candidats avec la croix (4.2), activation automatique du pistage (4.5).
4. Retracé en direct (4.3) et couleurs par état sur les tracés.
