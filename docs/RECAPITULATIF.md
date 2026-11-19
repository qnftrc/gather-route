# Récapitulatif : choix de conception et tests à faire

Synthèse de [FONCTIONNALITES.md](FONCTIONNALITES.md), [JOURNAL.md](JOURNAL.md) (décisions D1 à D10, risques R1 à R14) et [BESOINS.md](BESOINS.md). En cas de divergence, ces trois fichiers font foi.

Rappel : **aucune fonctionnalité de l'add-on de route n'a encore été testée en jeu**. Seules les sondes `/hr probe` l'ont été (elles prouvent que l'add-on se charge). « Hors jeu » = test par script ou faux environnement, déjà fait.

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
| F7 | Mode Tout afficher | Tous les points en pins TomTom, `persistent=false`, nettoyés à l'arrivée | Oui (mock) | Performance avec ~700 pins sur carte et minimap, ordre de la flèche |
| F8 | Skip, Stop, retrait externe | Retrait du point courant par TomTom = point suivant ; plusieurs retraits dans la même image = arrêt | Oui (mock) | Clic droit sur un pin, `/way reset all` (avec la route seule, vu comme un « skip »), `/hr stop`, `/hr skip` |
| F9 | Commandes `/hr` | Région optionnelle avant « : », herbes séparées par des virgules, `all` | Oui (mock) | `/hr Fadeleaf`, `/hr Stranglethorn Vale: Goldthorn`, `/hr stop`, noms inconnus |
| F10 | Fenêtre | Cadres natifs, liste de régions maison, départ pré-rempli (champ modifiable) | Non (rendu non testable) | Ouverture, listes, cases, boutons, curseur de rayon, erreurs Lua (`/console scriptErrors 1`) |
| F11 | Tracé carte du monde | Lignes de l'add-on (TomTom ne trace que des pins), tronçon courant vert, suivants dorés, précédent grisé ; désactivé en mode manette | Non |  Affichage sur la bonne carte, zoom, ouverture et fermeture de la carte |
| F12 | Tracé minimap | Projection calquée sur HereBeDragons-Pins (rayon de vue, rotation, disque à 0,9), 40 points d'avance, découpe au disque (D4) | Non | Rotation, zoom, bord du disque, conflit avec d'autres add-ons de minimap |
| F13 | Réglages mémorisés | `HerbRouteDB` (région, herbes, mode, rayon, cases) | Partiel | Persistance après `/reload` |

## 2. Sondes de diagnostic (`/hr probe`)
| Réf. | Fonctionnalité | Choix de conception | État | Tests à faire en jeu |
|---|---|---|---|---|
| F20 | `/hr probe`, `/hr probe minimap` : environnement, pistages, fonctions, lecture du survol réel avec **valeurs des champs numériques** | Aucun effet durable, `pcall` partout, rapport dans le chat, `HerbRouteDB` et une fenêtre à copier ; jeu de sondes réduit le 2026-11-19 | Livré, 2 rapports en jeu | `/hr probe minimap` avec **tous les pistages désactivés** (présence générique de façon certaine ?), puis sur point jaune et sur sol vide pour comparer `type` et `line1type` |
| F36 | `/hr probe blink world [hidden]` | Méthode de NodeRadar ; verdict sur la présence = au moins une ligne | **Validé en jeu** sur 2 points, visible et caché ; déplacement jugé gênant | Autres zooms ; test `blink chain` (F44) |
| F38 | `/hr probe watch` | 15 s, journalise présence (lignes) et signature | **Validé en jeu** : lignes uniquement sur un point | Terminé |
| F35 | Ancien `blink` (curseur déjà sur la minimap) | Retiré : non concluant | Retiré | Aucun |

## 3. Vérification des points par la minimap (cadrée, **conditionnelle**)
Tout ce bloc dépend du résultat de F38 et du contrôle « tous pistages désactivés » : la présence de données est très probablement générique (données présentes sur sol vide).

| Réf. | Fonctionnalité | Choix de conception | État | Tests à prévoir |
|---|---|---|---|---|
| F21 | Isolement du pistage pendant une route (D11) | Seul « Trouver les herbes » reste actif, configuration d'origine sauvegardée dans `HerbRouteDB` et rétablie à l'arrêt, au chargement, après combat ; « Trouver les herbes » jamais touché s'il est déjà actif (évite un temps de recharge) | **Livré**, testé hors jeu sur API simulée | En jeu : `/hr` puis vérifier les pistages du menu de la minimap ; `/hr stop` : configuration identique ; `/reload` pendant une route : rétablie ; barre d'actions sans temps de recharge parasite ; `/hr tracking off/on` |
| F22 | Sondage d'un candidat (D5 révisée) | Un sondage par `blink`, intégré à F39 | **Livré** (dans F39) | Précision selon le zoom (R19), flicker (R18), conditions d'usage (R17) |
| F23 | Déclenchement à l'entrée dans le disque (D6) | Test de distance léger toutes les 0,25 à 0,5 s, 2 à 3 interrogations par point (à l'entrée, +1,5 s, avant 30 yd) | Cadré | Délai d'apparition d'un point (R8), coût par passe (R9) |
| F24 | Retrait des waypoints sans correspondance | `TomTom:RemoveWaypoint` + état du trajet en cours seulement ; **base intacte** (D8) ; K échecs consécutifs avant retrait (D7) | Cadré | Faux négatifs (R2), reprise après `/hr restore` |
| F25 | `/hr restore` | Remet la route d'origine conservée | Cadré | Aller-retour complet après plusieurs retraits |
| F26 | Garde-fous | Aucun retrait sans pistage actif, minimap visible, bonne carte, hors combat, lecture jugée fonctionnelle | Cadré | Cas : pistage coupé, carte différente, combat |
| F27 | Interface | Case « Vérifier avec la minimap », compteurs conservés, confirmés, retirés | Cadré | Rendu et mise à jour |
| F28 | Tracés | Ignorer les points retirés, couleur des confirmés | Cadré | Rendu carte et minimap |
| F29 | Faux minimap dans les tests | Étendre `tools/test_addon.py` | Cadré | États, retraits, garde-fous |
| F34 | Vérification par **présence** (D10) | Noms secrets acceptés ; présence = au moins une ligne d'infobulle | **Validée en principe en jeu** | Confirmer sur des points de la base (voir F22) |
| F39 | Vérification ciblée du prochain waypoint (D12) | Un sondage = minimap déplacée une image sous un curseur au repos ; absence après 1 sondage vide ; dernier contrôle à 35 yd ; `report` par défaut ; garde « bouger la souris une fois » ; pin TomTom masqué pendant les sondes (D15) ; vérification de la projection sur 12 points voisins avant le premier retrait (D16) ; pas d'abandon, réessais espacés | **Livré**, 1er essai en jeu : 4 sondes inconclusives, corrigé | En jeu : `/hr verify` (causes), `/hr verify probe` (projection, déplacement, lectures) ; ensuite messages `report` conformes à la minimap, puis `/hr verify remove` |
| F49 | Vérification en avance (D19) | Prochain point non décidé dans 85 % du rayon, toute la route (plus de limite de 60), automatique par défaut ; mêmes règles que le point courant | Retrait d'un point vide en avance, aucun retrait des points à nœud, arrêt/reprise, commande | En jeu : `/hr verify ahead`, gêne visuelle des déplacements (R18), faux « présent » en zone dense |
| F45 | `/hr verify probe` | Une sonde détaillée avec la méthode calibrée | Livré, testé hors jeu | Après calibration |
| F46 | `/hr verify scan` | Balayage avec la méthode calibrée ; carte ASCII ; symétries | Livré ; 1er essai : 0 point (méthode curseur logiciel invalide) | Relancer après `/hr verify calibrate` |
| F47 | `/hr verify calibrate` (D14) | Sept méthodes essayées sur un point jaune connu et un témoin ; la première qui voit le point et pas le témoin est mémorisée avec le build | **Validé en jeu** : « plain » retenue ; le curseur logiciel est invalide | Refaire si le build change |
| F48 | `/hr verify arming` | Sondages du point connu à 6 à 60 s après un survol réel, souris immobile | Livré, testé hors jeu | À lancer en jeu : la lecture disparaît-elle avec le temps (R26) ? |
| F37 | ~~Cartographie par grille~~ | Abandonné : un sondage par candidat suffit | Abandonné | Aucun |

**Repli si rien ne distingue un point du sol** : abandon de la vérification par la minimap, mémoire de récolte (F32).

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
3. Tracés carte et minimap : F11, F12. Mode Tout afficher : F7. Stop, skip, retrait : F8. Persistance : F13.
4. Sondes : `/hr probe watch` (F38), puis `/hr probe minimap` avec tous les pistages désactivés (F20). Coller les rapports.
5. Selon les résultats : vérification par la minimap (bloc 3) ou mémoire de récolte (F32).
