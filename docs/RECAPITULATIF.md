# Récapitulatif : choix de conception et tests à faire

Synthèse de [FONCTIONNALITES.md](FONCTIONNALITES.md), [JOURNAL.md](JOURNAL.md) (décisions D1 à D46, risques R1 à R44) et [BESOINS.md](BESOINS.md) (besoins B1 à B33). En cas de divergence, ces trois fichiers font foi.

Rappel : **validé en jeu** : la lecture de la minimap (`/hr probe`, `blink world`, `watch`), la calibration herbes et minerais (F47), la projection des points sur la minimap (F46), la mesure de la zone de réponse d'un blip (F65, herbes), le tracé de la carte du monde (F11), les événements de cueillette (F68, en partie) et la fenêtre de stats (F72, en partie : durée, total, prix). **Le reste est testé hors jeu seulement.** « Hors jeu » = test par script ou faux environnement, déjà fait (`python3 -I tools/test_addon.py`).

## 1. Add-on de route (livré, v1.0.0)
| Réf. | Fonctionnalité | Choix de conception | Test hors jeu | Tests à faire en jeu |
|---|---|---|---|---|
| F1 | Base des points (45 régions, 29 herbes, 13 256 points) | Générée depuis le JSON, aucun point supprimé ni dédupliqué ; jamais modifiée (D8) | Comptage identique au JSON | Une route passe bien sur un Goldthorn connu de Wild Shore (point de la base à 27,6 / 81,8) |
| F15 | Enrichissement par GatherMate (D17) | Ajout seulement, fichier séparé, tolérance de doublon 0,5 % de la carte, zones rattachées par recouvrement, Felwood nommée à la main | Livré, vérifié hors jeu | En jeu : `/hr debug` (Felwood résolue ?), routes plus longues sans gêne, points ajoutés cohérents avec la minimap |
| F16 | Minerais GatherMate (D18) | Seconde catégorie à part (`HerbRoute_OreData`), 8 920 points après fusion à 0,5 % ; choix catégorie, région, type ; pistage isolé selon la catégorie (sort 2580) ; reste inchangé | Données, routes, commandes, pistage simulé, fenêtre (faux widgets) | Cases Herbs / Ores de la fenêtre, `/hr ores copper vein`, seul « Trouver les minéraux » actif pendant la route puis configuration rétablie, vérification minimap en `report` sur un minerai |
| F2 | Région vers mapID | Réutilise `TomTom.NameToMapId` (correspondance normalisée, repli par préfixe), surcharge `/hr setmap`, aucun mapID en dur | Faux TomTom (4 régions) | `/hr debug` : combien des 45 régions sont résolues, notamment Riverglades, Shen'dralas, Zephras Isle |
| F3 | Position et région courantes | Position via `TomTom:GetCurrentPlayerPosition`, remontée aux cartes parentes | Faux TomTom | Région pré-sélectionnée correcte dans plusieurs zones et sous-zones, comportement en ville ou en grotte |
| F4 | Route optimisée | Port à l'identique du planner HTML (plus proche voisin puis 2-opt à fenêtre, distance en % sans correction d'aspect) (D2) | 4 cas identiques au JS (dont 702 et 742 points) | Comparer une route réelle avec le planner HTML sur la même zone |
| F5 | Génération sans gel | Coroutine découpée par `C_Timer`, annulation par jeton | Oui (mock) | Zone à 700 points : pas de saccade ni de message d'erreur |
| F6 | Mode Suivi | Un seul waypoint à la fois, `SetCustomWaypoint`, rayon d'arrivée 15 yd (réglable), `crazy=true`, pattern du README TomTom (D3) | Avancement, skip, fin de route | La flèche avance bien à l'arrivée, le rayon convient, le ping et les doublons proches se comportent bien |
| F8 | Skip, Stop, retrait externe | Retrait du point courant par TomTom = point suivant ; plusieurs retraits dans la même image = arrêt | Oui (mock) | Clic droit sur un pin, `/way reset all` (avec la route seule, vu comme un « skip »), `/hr stop`, `/hr skip` |
| F9 | Commandes `/hr` | Région optionnelle avant « : », herbes séparées par des virgules, `all` | Oui (mock) | `/hr Fadeleaf`, `/hr Stranglethorn Vale: Goldthorn`, `/hr stop`, noms inconnus |
| F10 | Fenêtre | Cadres natifs, liste de régions maison, départ pré-rempli (champ modifiable) | Non (rendu non testable) | Ouverture, listes, cases, boutons, curseur de rayon, erreurs Lua (`/console scriptErrors 1`) |
| F11 | Tracé carte du monde | Lignes de l'add-on (TomTom ne trace que des pins), tronçon courant vert, suivants dorés, précédent grisé ; désactivé en mode manette | Non |  Affichage sur la bonne carte, zoom, ouverture et fermeture de la carte |
| F12 | Tracé minimap | Projection calquée sur HereBeDragons-Pins (rayon de vue, rotation, disque à 0,9), découpe au disque (D4) | Non | Rotation, zoom, bord du disque, conflit avec d'autres add-ons de minimap |
| F13 | Réglages mémorisés | `HerbRouteDB` (région, herbes, mode, rayon, cases) | Partiel | Persistance après `/reload` |
| F51 | Minerais Wowhead (520 points ajoutés) | Fichier séparé `OreDataWowhead.lua` chargé après celui de GatherMate, base d'origine intacte (D17, D18) | Outil et chargement | Routes de minerais plus fournies, aucun doublon gênant |
| F53 | Skip associable à une touche | `Bindings.xml` (Skip, Stop, fenêtre) et bouton Skip optionnel (`/hr button`, Maj + glisser) | Fonctions, sans rendu | Touche dans Options > Raccourcis clavier > AddOns, bouton déplaçable |
| F54 | Fusion des voisins à 1 unité | Au chargement, `/hr merge [on\|off]`, fichiers de données intacts (D21) | Comptages | Une route sans points doublés |
| F59 | Base de minerais GatherMate (8 920 points) | Catégorie à part `HerbRoute_OreData` (D18) | Données et routes | Voir F16 |
| F69 | Case « messages dans le chat » | `/hr chat [on\|off]` : messages automatiques coupés, réponses aux commandes conservées (D38) | Oui | Case décochée : plus de message de départ ni d'avertissement |
| F70 | Recherche de région par lettres | Champ dans la liste, lettres dans n'importe quel ordre, occurrences comptées (D39) | Règle de correspondance | Saisie de « SOS », touche Entrée, « No match » |
| F72 | Fenêtre de stats (D43 à D46) | 210 × 210, `/hr stats` et bouton ; durée de la route, butin des cueillettes (messages de butin, repli par les sacs), or estimé avec prix d'Auctionator mémorisés sinon prix marchand ; une ligne par objet, 8 lignes visibles et barre déroulante | 40 objets : butin, prix, repli par les sacs | `/hr stats probe` (Auctionator, identifiants), liste complète après plusieurs cueillettes, Reset, position mémorisée |

## 2. Sondes de diagnostic (`/hr probe`)
| Réf. | Fonctionnalité | Choix de conception | État | Tests à faire en jeu |
|---|---|---|---|---|
| F20 | `/hr probe`, `/hr probe minimap` : environnement, pistages, fonctions, lecture du survol réel avec **valeurs des champs numériques** | Aucun effet durable, `pcall` partout, rapport dans le chat, `HerbRouteDB` et une fenêtre à copier ; jeu de sondes réduit le 2026-11-19 | Livré, 2 rapports en jeu | `/hr probe minimap` avec **tous les pistages désactivés** (présence générique de façon certaine ?), puis sur point jaune et sur sol vide pour comparer `type` et `line1type` |
| F36 | `/hr probe blink world [hidden]` | Méthode de NodeRadar ; verdict sur la présence = au moins une ligne | **Validé en jeu** sur 2 points, visible et caché ; déplacement jugé gênant | Autres zooms ; test `blink chain` (F44) |
| F38 | `/hr probe watch` | 15 s, journalise présence (lignes) et signature | **Validé en jeu** : lignes uniquement sur un point | Terminé |
| F35 | Ancien `blink` (curseur déjà sur la minimap) | Retiré : non concluant | Retiré | Aucun |

## 3. Vérification des points par la minimap (livrée)
La lecture par présence est validée en jeu (F34, F36, F38, F47) ; le reste du bloc est testé hors jeu seulement. La présence de données est une ligne d'infobulle, sans nom lisible.

| Réf. | Fonctionnalité | Choix de conception | État | Tests à prévoir |
|---|---|---|---|---|
| F21 | Isolement du pistage pendant une route (D11) | Seul « Trouver les herbes » reste actif, configuration d'origine sauvegardée dans `HerbRouteDB` et rétablie à l'arrêt, au chargement, après combat ; « Trouver les herbes » jamais touché s'il est déjà actif (évite un temps de recharge) | **Livré**, testé hors jeu sur API simulée | En jeu : `/hr` puis vérifier les pistages du menu de la minimap ; `/hr stop` : configuration identique ; `/reload` pendant une route : rétablie ; barre d'actions sans temps de recharge parasite ; `/hr tracking off/on` |
| F22 | Sondage d'un candidat (D5 révisée) | Un sondage par `blink`, intégré à F39 | **Livré** (dans F39) | Précision selon le zoom (R19), flicker (R18), conditions d'usage (R17) |
| F23 | Déclenchement à l'entrée dans le disque (D6) | Test de distance léger toutes les 0,25 à 0,5 s, un sondage vide pour l'absence à l'entrée dans 85 % du rayon, dernier contrôle à moins de 35 yd | **Livré** (via F39), testé hors jeu | Délai d'apparition d'un point (R8), coût par passe (R9) |
| F24 | Retrait des waypoints sans correspondance | `TomTom:RemoveWaypoint` + état du trajet en cours seulement ; **base intacte** (D8) ; un sondage vide suffit (F23) | **Livré** (`DropPoint`, mode `remove`), testé hors jeu | Faux négatifs (R2), reprise après `/hr restore` |
| F25 | `/hr restore` | Remet la route d'origine conservée | Cadré | Aller-retour complet après plusieurs retraits |
| F26 | Garde-fous | Aucun retrait sans pistage actif, minimap visible, bonne carte, hors combat, lecture jugée fonctionnelle | **Livré**, testé hors jeu | Cas : pistage coupé, carte différente, combat |
| F27 | Interface | Case « Vérifier avec la minimap », compteurs conservés, confirmés, retirés | **Partiel** (case et compteur de retraits livrés) | Rendu et mise à jour |
| F28 | Tracés | Ignorer les points retirés, couleur des confirmés | **Livré** ; couleur des confirmés non faite | Rendu carte et minimap |
| F29 | Faux minimap dans les tests | Étendre `tools/test_addon.py` | Cadré | États, retraits, garde-fous |
| F34 | Vérification par **présence** (D10) | Noms secrets acceptés ; présence = au moins une ligne d'infobulle | **Validée en principe en jeu** | Confirmer sur des points de la base (voir F22) |
| F39 | Vérification ciblée du prochain waypoint (D12) | Un sondage = minimap déplacée une image sous un curseur au repos ; absence après 1 sondage vide ; dernier contrôle à 35 yd ; `report` par défaut ; garde « bouger la souris une fois » ; pin TomTom masqué pendant les sondes (D15) ; ~~vérification de la projection sur 12 points voisins (D16)~~ supprimée (D20) ; pas d'abandon, réessais espacés | **Livré**, 1er essai en jeu : 4 sondes inconclusives, corrigé | En jeu : `/hr verify` (causes), `/hr verify probe` (projection, déplacement, lectures) ; ensuite messages `report` conformes à la minimap, puis `/hr verify remove` |
| F49 | Vérification en avance (D19) | Prochain point non décidé dans 85 % du rayon, toute la route (plus de limite de 60), automatique par défaut ; mêmes règles que le point courant | Retrait d'un point vide en avance, aucun retrait des points à nœud, arrêt/reprise, commande | En jeu : `/hr verify ahead`, gêne visuelle des déplacements (R18), faux « présent » en zone dense |
| F45 | `/hr verify probe` | Une sonde détaillée avec la méthode calibrée | Livré, testé hors jeu | Après calibration |
| F46 | `/hr verify scan` | Balayage avec la méthode calibrée ; carte ASCII ; symétries | Livré ; 1er essai : 0 point (méthode curseur logiciel invalide) | Relancer après `/hr verify calibrate` |
| F47 | `/hr verify calibrate` (D14) | Sept méthodes essayées sur un point jaune connu et un témoin ; la première qui voit le point et pas le témoin est mémorisée avec le build | **Validé en jeu** : « plain » retenue ; le curseur logiciel est invalide | Refaire si le build change |
| F48 | `/hr verify arming` | Sondages du point connu à 6 à 60 s après un survol réel, souris immobile | Livré, testé hors jeu | À lancer en jeu : la lecture disparaît-elle avec le temps (R26) ? |
| F52 | Retrait des minerais | Même vérification et même retrait que pour les herbes, pistage « Trouver les minéraux » | Livré, testé hors jeu ; **calibration sur un minerai validée en jeu** | Retrait en route sur un minerai absent |
| F37 | ~~Cartographie par grille~~ | Abandonné : un sondage par candidat suffit | Abandonné | Aucun |

**Repli si rien ne distingue un point du sol** : abandon de la vérification par la minimap, mémoire de récolte (F32).

## 3 bis. Ajuster en route (livré, testé hors jeu)
| Réf. | Fonctionnalité | Choix de conception | État | Tests à faire en jeu |
|---|---|---|---|---|
| F55 | Réordonnancement après retraits (D22) | `/hr reroute [on\|off\|now]`, plus proche voisin puis 2-opt depuis la position du joueur, désactivé par défaut, base intacte | Livré | `/hr reroute now` après quelques retraits |
| F60 | Surveillance et réinsertion des points hors route (D26, D33, D34, D42) | Candidats dérivés de la base (atteints, skippés, retirés), sondage caché à chaque 60 yd parcourus, 10 s après l'arrivée ; un point qui répond est réinséré **en tête de route** avec un nouveau waypoint ; `/hr revive` | Livré | Un point skippé qui revient dans la minimap est ciblé, message « Revive: … » |
| F61 | Cible = point rempli le plus proche (D27) | Après une sonde positive, le plus proche confirmé dans la minimap prend la tête, route recalculée à l'arrivée ; `/hr nearest` | Livré | Changement de cible quand un nœud plus proche répond |
| F62 | Sondage par proximité (D28) | Un seul groupe de candidats, le plus proche d'abord, point courant en premier | Livré | Ordre des sondes, pas de blocage par un point sans conclusion |
| F63 | Faux positifs ambigus (D29, D40) | Un ambigu est traité comme un point rempli ordinaire ; sondage décalé caché en arrière-plan, rejeté traité comme absent ; `/hr ambiguity` | Livré | Cible changée après un rejet, compteurs de `/hr verify` |
| F71 | Croix rouges (D41) | Spots ambigus en attente ou non résolus, minimap et carte du monde ; `/hr ambiguity marks` | Livré | Rendu des croix, recouvrement des points jaunes |
| F65 | Zone de réponse d'un blip (D32) | `/hr probe zone [hidden]` ; environ 22 unités, centrée sur le point de la base (herbes) ; valeur enregistrée dans `HerbRouteDB.zone` | **Validé en jeu** (herbes) | Mesure sur un minerai |
| F66 | Recontrôle à 110 yd (D35) | Un point confirmé depuis plus de 110 yd est resondé une fois, en plus du contrôle à 35 yd | Livré | Un nœud pris par un autre joueur est retiré à 110 yd |
| F67 | Sondes en combat (D36) | Une case lève la garde de combat pour toutes les sondes | Livré | Lecture en combat |
| F68 | Cueillette (D37) | Événements de sort, nœud désigné par la position, vague de ressondage au début, point cueilli retiré de la route ; `/hr gather` | Livré, **observé en jeu** (sort 11993, événements, deux sondes pendant la cueillette) | Point cueilli retiré, vague au début, `/hr gather debug on` |

## 4. Idées et hors périmètre
| Réf. | Fonctionnalité | Choix de conception / raison | Test à prévoir |
|---|---|---|---|
| F32 | Mémoire de récolte (états pris et vide, événement de récolte, bouton « rien ici ») | Séparée de la base (`HerbRouteDB`), optionnelle ; durée de vie entre trajets à décider ; devient le repli principal | Détection d'une récolte par l'événement de sort, durées de réapparition (R5) |
| F31 | Dézoom temporaire de la minimap | Élargit le champ mais change l'affichage | Sans objet tant que la lecture n'est pas positionnelle |
| F33 | Recalcul complet de la route | Désactivé, remplacé par le simple retrait de points (D7) | Aucun |
| F30 | Contournements de lecture | Devenu F36 | Voir F36 |
| F40 | Routes multi-régions | Hors périmètre v1 | Aucun |
| F41 | Interface en français, client non anglais | Hors périmètre ; hypothèse client anglais (R6) | `/hr debug` si la langue du client change |
| F42 | Aperçu du tracé dans la fenêtre | Hors périmètre (le tracé est sur la carte et la minimap) | Aucun |
| F43 | Recalage de la base | Interdit par la contrainte D8 | Aucun |

## 5. Ordre de test conseillé
1. Installer le dernier zip, `/console scriptErrors 1`, `/reload`.
2. `/hr debug`, puis une route simple (`/hr` ou `/hr <herbe>`) : F2, F3, F5, F6, F9, F10.
3. Tracés carte et minimap : F11, F12. Stop, skip, retrait : F8. Persistance : F13.
4. Sondes : `/hr probe watch` (F38), puis `/hr probe minimap` avec tous les pistages désactivés (F20). Coller les rapports.
5. Vérification par la minimap (bloc 3) : `/hr verify`, `/hr verify ahead`.
6. Ajustement en route (bloc 3 bis) : skipper un point puis s'en approcher (F60), `/hr verify` pour les compteurs, croix rouges (F71), `/hr gather debug on` pendant une cueillette (F68).
7. Stats : `/hr stats probe` (Auctionator, identifiants d'objets), puis `/hr stats` pendant une route (F72).
8. Mémoire de récolte (F32) seulement si la vérification par la minimap ne suffit pas.
