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
| B8 | Pendant une route, ne garder actif que « Trouver les herbes » parmi les pistages ; rétablir la configuration d'origine à l'arrêt de la route | Demande du joueur |
| B9 | Limiter la gêne visuelle du déplacement de la minimap pendant la vérification | Retour du joueur après `blink world` |
| B10 | Alimenter la base avec les données de GatherMate (Forever) sans toucher aux données présentes : vérifier la concordance, garder les doublons (les nôtres), ajouter les points qui n'existent que dans GatherMate | Demande du joueur (archive `AddOns.rar`) |

| B11 | Même enrichissement pour les **minerais** de GatherMate, même format, même déclinaison par zone puis par catégorie : une option pour choisir entre herbes et minerais, puis par type d'herbe ou de minerai ; tout le reste inchangé | Demande du joueur |

| B12 | Sonder automatiquement, en plus du manuel, tous les futurs waypoints qui entrent dans les 85 % du rayon de vue de la minimap | Réponse du joueur |
| B13 | ~~Tenir compte du relief~~ : **annulé par le joueur** (2026-11-19), la distance à vol d'oiseau est conservée | Demande du joueur, puis annulation |
| B14 | Récupérer les positions des gisements de minerais de Wowhead Forever par la même méthode que pour les herbes (export depuis le navigateur), à ajouter à la base sans toucher à l'existant | Demande du joueur |
| B15 | Appliquer aux minerais le même retrait de waypoints qu'aux herbes | Demande du joueur |
| B16 | Un bouton « skip » dans l'interface, associable à une touche | Demande du joueur |
| B17 | Fusionner les doublons des bases à une unité de coordonnée près, sans toucher aux fichiers de données | Demande du joueur |
| B18 | Ajuster la route en temps réel d'après la minimap : réordonner les points restants après des retraits, sous forme d'une fonction activable et désactivable à volonté | Demande du joueur |
| B19 | Détecter les points **déjà skippés** (Skip, touche, ou retirés par la vérification comme absents) qui réapparaissent dans le cadre de la minimap, herbes et minerais ; les **réinsérer dans la route avec un nouveau waypoint et un message** ; rien détecté = ni action ni message ; minimap déplacée en mode `hidden` | Demande du joueur (livré : F60, D26) |
| B20 | **Reroutage vers le point rempli le plus proche** : quand une sonde de la minimap trouve un nœud, le point rempli le plus proche de ma position (parmi ceux confirmés et dans la minimap) devient la nouvelle cible (nouveau waypoint, réintégré dans la route) ; une fois ce waypoint atteint, la route est recalculée depuis ma position. **Aucun seuil de distance** : l'objectif est de maximiser les chances de récolter, pas de minimiser la distance | Demande du joueur (livré : F61, D27) |
| B21 | **Sonder par proximité** : les candidats à sonder (points en avance dans la minimap et points skippés qui reviennent) sont sondés du plus proche au plus éloigné de ma position, pour que le reciblage de F61 trouve plus tôt le nœud rempli le plus proche ; le point courant reste sondé en premier | Demande du joueur (livré : F62, D28) |
| B22 | **Gestion des faux positifs** : un positif de la minimap peut venir d'un point voisin de la base dont la zone de réponse couvre le curseur. Marquer ces positifs ambigus, les lever par un sondage décalé caché, traiter un rejeté comme absent, ne jamais cibler (F61) ni réinsérer en tête (F60) un point non résolu **(révisé par D40 : un ambigu est traité comme un point rempli ordinaire)** | Demande du joueur (livré : F63, D29) |
| B23 | ~~**Zoom d'arbitrage** : zoomer la minimap de 0 vers 5 pour distinguer un positif ambigu~~ | **Annulé par le joueur** (le joueur serait déjà trop près de la plante) ; F64 abandonnée |
| B24 | **Mesurer la zone de réponse d'un blip** (taille, forme, centre par rapport au point de la base) pour régler le traitement des ambigus : `/hr probe zone` | Demande du joueur (livré : F65, D32) |
| B25 | **Surveiller les points qui ont pu réapparaître** : tous les points de la base des types de la route qui ne sont pas devant moi dans la route (atteints, skippés, retirés, perdus) sont sondés quand ils sont dans la minimap, le plus proche d'abord, avec 10 s d'attente après l'arrivée, et resondés à chaque **60 yd parcourus** (au lieu d'un rythme en secondes) ; les points en avance trouvés vides le sont aussi ; un point qui répond est réinséré et la route recalculée depuis ma position | Demande du joueur (livré : F60, D33, D34) |
| B26 | **Recontrôle à 110 yd** : un point confirmé depuis plus de 110 yd est resondé une fois à 110 yd, toujours actif, en plus du contrôle à 35 yd | Demande du joueur (livré : F66, D35) |
| B27 | **Sonder en combat** : une case autorise toutes les sondes (route, diagnostics, calibration, balayage) en combat | Demande du joueur (livré : F67, D36) |
| B28 | **Cueillette** : reconnaître le début et la fin d'une cueillette ; au début, resonder tous les points qui ont pu réapparaître, pendant la canalisation (la vague part aussi après une cueillette ratée, plus de vague à la fin) ; le point cueilli sort de la route | Demande du joueur (livré : F68, D37) |
| B29 | **Messages dans le chat** : une case pour activer ou couper les messages que l'add-on écrit de lui-même | Demande du joueur (livré : F69, D38) |
| B30 | **Recherche de région par lettres** : un champ dans la liste des régions, lettres présentes dans le nom dans n'importe quel ordre, occurrences comptées | Demande du joueur (livré : F70, D39) |
| B31 | **Voir les points ambigus** : un point jugé ambigu (positif de la minimap peut-être dû à un voisin) est traité comme n'importe quel point rempli (le plus proche gagne) ; les spots ambigus en attente ou non résolus sont marqués d'une **croix rouge** sur la minimap et la carte du monde, sur la route par défaut | Demande du joueur (livré : F71, D40, D41) |
| B32 | **Réinsertion toujours en tête** : un point qui répond est réinséré en tête de route avec un nouveau waypoint ; si un autre point rempli est plus proche de ma position, c'est lui qui prend la tête ; le reste de la route est recalculé à partir du point de tête | Demande du joueur (livré : F60, F61, D42) |
| B33 | **Fenêtre de stats** : un cadre secondaire que j'affiche ou masque (`/hr stats`, bouton), avec la durée de ma route en direct, ce que j'ai récolté (uniquement ce qui provient d'une cueillette) et une estimation en or d'après la valeur des objets ; les prix de l'hôtel des ventes (Auctionator) des herbes et des minerais sont gardés en mémoire après un scan | Demande du joueur (livré : F72, D43 à D46) |

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

### 3 quater Sol vide : présence générique probable
- `/hr probe minimap` avec la souris sur un **sol vide** de la minimap : lecture de base **présente**. Avec le curseur hors de la minimap : aucune donnée. La présence dépend donc surtout de la position du curseur sur la minimap, pas d'un point jaune.
- Conséquence : la vérification par **présence** (B7, D10, F34) est remise en cause. Elle ne redevient possible que si un champ numérique lisible (`type`, `dataInstanceID`, `lines[1].type`) distingue un point du sol. Test : `/hr probe watch`, puis `/hr probe minimap` avec tous les pistages désactivés.
- Repli si rien ne distingue : abandon de la vérification par la minimap, mémoire de récolte (4.4) seule. La base reste intacte dans tous les cas.

### 3 quinquies Rapport `watch` : la présence se lit dans les lignes
- Sur le build 70959, la minimap renvoie des données pour **tout** curseur placé dessus ; seules les positions sur un point jaune renvoient **au moins une ligne** d'infobulle (`line1type=0`), les autres des données sans ligne (`?`). Hors de la minimap : aucune donnée. `type` reste 21, `dataInstanceID` est un compteur.
- La vérification par **présence** (B7, D10, F34) est rétablie avec cette définition : présence = au moins une ligne. À confirmer par un nouveau `blink world`.
- Résolution : la zone de réponse d'un point est d'une vingtaine d'unités (carré d'environ 20 à 25 unités) ; au zoom 0 (rayon 233 yd) cela représente de l'ordre de 50 yd, au zoom le plus fort de l'ordre de 17 yd (estimation). La vérification ne peut retirer que des candidats sans aucun point à proximité.

### 3 sexies Validation en jeu : la détection positionnelle fonctionne
- `watch` (13:51) et `blink world` (13:52) : la minimap renvoie une ligne d'infobulle seulement pour un point d'herbe sous le curseur ; amener un point sous un curseur au repos dans le monde en déplaçant la minimap suffit (lecture à +1 image) ; les positions à 40 unités n'ont aucune ligne.
- Conséquences : **un sondage par candidat** (la croix de 17 positions est abandonnée, D5 révisée) ; chaque sondage coûte environ 4 images ; la précision dépend du zoom ; la vérification est **opportuniste** (curseur immobile dans le monde, hors combat, aucun bouton enfoncé, aucune fenêtre).
- Proposition de première version : `/hr verify` déclenché à la main (simulation d'abord, retrait optionnel via `TomTom:RemoveWaypoint`, base intacte), puis automatisation.

### 3 septies Gêne visuelle du déplacement (B9)
- `blink world` visible et caché : même lecture, reproductible sur deux points. Le joueur juge le déplacement de la minimap gênant.
- Leviers : lecture à +1 image seulement (environ 2 images par sondage), minimap cachée, vérification **ciblée** du prochain waypoint (F39), déclenchement manuel, souris au repos près de la minimap, test `blink chain` (F44).
- Choix d'usage à trancher avec le joueur : manuel (`/hr verify`), ciblé en mode Suivi, ou passe complète automatique.

### 3 octies Choix du joueur : vérification ciblée (livrée)
- Choix (B9) : vérification **ciblée sur le prochain waypoint**, automatique en mode Suivi ; la variante cachée n'est pas moins gênante.
- Livrée dans `Verify.lua` (F39) : un sondage par candidat, environ 4 images dont une avec la minimap déplacée, uniquement quand la souris repose dans le monde et que les garde-fous sont réunis ; mode `report` par défaut, retrait en `remove` après un premier point confirmé. Détail et risques dans le journal (R21 à R23).

### 3 nonies Enrichissement par GatherMate (B10, livré)
- Résultat chiffré : 14 605 points GatherMate, 12 761 doublons de la base (à moins de 0,5 %), 458 doublons entre eux, **1 386 ajouts** (dont 199 pour Felwood, région nouvelle). Détail par région dans [DONNEES_GATHERMATE.md](DONNEES_GATHERMATE.md).
- Ajout seulement, dans `Data/HerbDataGatherMate.lua` ; `Data/HerbData.lua` inchangé. Voir la décision D17 du journal.

### 3 decies Minerais GatherMate (B11, livré)
- 11 011 points GatherMate (Forever), 41 zones, 18 minerais ; **8 920 points** gardés après fusion des positions à moins de 0,5 % (2 091 fusionnés). Détail par région dans [DONNEES_GATHERMATE_MINERAIS.md](DONNEES_GATHERMATE_MINERAIS.md).
- Fichier `Data/OreDataGatherMate.lua` (`HerbRoute_OreData[région][minerai]`), à part des herbes. Choix de la catégorie dans la fenêtre (cases Herbs / Ores) et par `/hr ores`. Voir la décision D18 du journal.

### 3 undecies Minerais Wowhead (B14, livré)
- Export du joueur (`wowhead_ores_mapperdata.json`) : 13 gisements, 12 avec positions (10 651 points rattachés), **520 points ajoutés** après écart des doublons à 0,5 % (10 071 déjà dans la base, 60 fusionnés entre eux). Détail par minerai dans [DONNEES_WOWHEAD_MINERAIS.md](DONNEES_WOWHEAD_MINERAIS.md). Fichier `Data/OreDataWowhead.lua`.

## 4. Conception envisagée

### 4.1 Sondes de validation (`/hr probe`) — première étape (écrites, jouées en partie)
Jeu de sondes **réduit** le 2026-11-19, après les deux premiers rapports en jeu :
- `/hr probe` et `/hr probe minimap` : client, minimap, pistages actifs, fonctions présentes, lecture du survol réel (présence et forme des données). Sert aussi au contrôle « sol vide » (R13).
- `/hr probe blink world [hidden]` : méthode de NodeRadar (curseur au repos dans le monde, minimap déplacée dessous). Seule piste de sondage positionnel restante.
- Retirées car sans objet : balayages de la minimap dans plusieurs conventions de coordonnées, avec curseur logiciel et à +1 image (le sondage par position n'a pas d'effet, écho du survol réel confirmé) ; étalonnage de la zone de réponse et écart à la base (dépendaient de réponses positionnelles) ; test du zoom et des points hors disque (dépendait d'une configuration qui lit) ; `blink` avec le curseur déjà sur la minimap (non concluant, remplacé par `blink world`).
Selon les résultats, on retient la vérification par présence (4.2, 4.3 bis) ou la mémoire de récolte seule (4.4).

### 4.2 Interroger la minimap aux candidats connus
- Candidats = points de notre base dans le disque de la minimap, pour les herbes sélectionnées. La position sur la minimap vient de la projection de `Overlay.lua` (rayon de vue, rotation, facteur 0,9).
- ~~Motif par candidat : centre puis 2 pas dans chacune des 8 directions, soit 17 interrogations.~~ **Révisé** : un seul sondage par candidat, par déplacement de la minimap sous le curseur (voir 3 sexies). Ancien texte : centre puis 2 pas dans chacune des 8 directions, soit 17 interrogations. Pas défini en yards (par exemple 3 puis 6) et converti en pixels selon le zoom. *À réévaluer : la zone de réponse rapportée (environ 25 unités) est grande devant l'erreur de nos coordonnées, un sondage au centre pourrait suffire.*
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
**Livré (F21, D11)** : l'isolement du pistage est implémenté (`Tracking.lua`). Au lancement, la configuration est sauvegardée, seul « Trouver les herbes » reste actif ; l'arrêt, la fin de route, un `/reload` ou une reconnexion rétablissent la configuration. Commande `/hr tracking`, case dans la fenêtre. Voir le journal pour les risques (temps de recharge, pistage à sort unique).
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

## 7. SkinRoute : besoin du dépeçage (2026-11-24)

### 7.1 Besoin de départ
Un add-on séparé, sur le modèle d'HerbRoute mais **par zone** : le joueur veut savoir où dépecer pour gagner de l'or, sans route à suivre bête par bête. Une zone vaut environ une minimap au zoom 0 (cercle de 233 yd). Mono-région. L'add-on **guide seulement vers la zone** ; aucune vérification sur la minimap.

### 7.2 Besoins exprimés (par le joueur)
- Même interface qu'HerbRoute, avec trois vues : par **région**, par **item**, par **valeur** selon le scan d'Auctionator ; symboles de pièces d'or, d'argent et de cuivre du jeu.
- Niveau du personnage **détecté ou simulé** ; niveau de **Dépeçage** réel ou simulé ; zones et cuirs verrouillés **grisés et visibles** avec « needs skinning N » ; pourcentage de bêtes dépeçables, en nombre de bêtes.
- Bande de niveau −8/+2 par défaut, **réglable**.
- Cercles sur la carte du monde : contour coloré selon la difficulté face au niveau, même épaisseur partout, sans numéros de zone, étiquettes valeur, niveaux et pourcentage ; **fond blanc transparent** ; **polices qui tiennent dans les cercles** ; **nombre de bêtes** (« X mobs »).
- Données : export Wowhead par script (avec garde-fous), complété par une base de créatures libre ; nettoyage des données (objets de quête, villes, champ de bataille, cartes de continents).
- **Prix en fin de ligne** dans toutes les vues.
- **Vue Profit** : classement des régions par or par heure d'après le scan d'Auctionator ; temps par bête de 25 s à niveau égal, **décroissant selon l'écart de niveau** (courbe continue, pente 1,10) ; pas de commission d'HV, pas de plafond de réapparition ; **choix automatique des cuirs** sous la ligne de la région, séparés de la sélection manuelle ; alerte « scan the auction house » si aucun prix n'est connu.
- Fenêtre élargie pour que rien ne dépasse (442 px), prix, stats, touches, bouton Skip, français.

### 7.3 Faits établis
- Seul Wowhead donne les positions des créatures par zone ; ses fetchs automatiques sont refusés (405), l'export se fait donc dans le navigateur du joueur.
- CMaNGOS classic-db fournit rang, butin de dépeçage et niveaux ; pfQuest fournit les positions en pourcentage. Un point CMaNGOS = un spawn.
- La carte, le cercle de 233 yd, le fond blanc et la fenêtre fonctionnent sur le client du joueur (captures).

### 7.4 Questions ouvertes
1. Lecture du niveau de Dépeçage sur un personnage qui a le métier.
2. Règles de dépeçage et butins réels sur Forever.
3. Réglage du temps par bête et du seuil de 70 % d'après la pratique ; durées de réapparition.
4. Noms français des régions.
5. Licence : publication éventuelle du fichier de données généré.

### 7.6 Vie des mobs (2026-11-27)
- Mesurer en jeu la vie des créatures (`UnitHealthMax`), car Forever a augmenté la vie des niveaux élevés sans publier de pourcentage. Ordre voulu : A (mesure et comparaison avec CMaNGOS) puis B (vie dans le temps par bête), mesure **automatique au ciblage**, **probe d'abord** (`/sr hp probe`).

### 7.5 Butin des bêtes (2026-11-25)
- Compter aussi ce que les bêtes lâchent : objets gris (prix du marchand), blancs et verts (plus haut du prix d'HV et du prix du marchand), or ; **bleus et violets écartés**. Activé par défaut dans la vue Profit, case pour le décocher, **cuir et butin séparés** à l'affichage.
- Récupérer le butin des créatures ajoutées par Forever (absentes de CMaNGOS) par un script Wowhead limité à ces créatures et à un échantillon de contrôle.
- La fenêtre de stats doit compter aussi le butin des cadavres, séparé du dépeçage.
