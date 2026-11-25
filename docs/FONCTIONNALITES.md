# Suivi des fonctionnalités

Légende des statuts :
- **Livré** : code écrit et poussé.
- **Cadré** : décrit dans [BESOINS.md](BESOINS.md), pas encore codé.
- **Idée** : pistes non retenues pour l'instant.
- **Hors périmètre** : écarté pour la version courante.

Colonnes de vérification : « Hors jeu » = testé par script ou faux environnement ; « En jeu » = testé dans le client WoW (aucune fonctionnalité ne l'est encore).

## Répartition par famille

Deux familles : ce qui **construit la base de données** (points d'herbes et de minerais, avant et au chargement) et ce qui **permet de créer et de suivre la route** (au moment de jouer). Les tableaux détaillés plus bas restent classés par statut ; chaque référence F appartient à une seule famille, sauf F14 (transversale).

### A. Construire la base de données
| Réf. | Fonctionnalité | Où | État |
|---|---|---|---|
| F1 | Base d'herbes embarquée (45 régions, 29 herbes, 13 256 points), jamais modifiée (D8) | `Data/HerbData.lua`, `tools/gen_data.py` | Livré |
| F15 | Ajouts GatherMate pour les herbes (+1 386 points, région Felwood), ajout seulement (D17) | `Data/HerbDataGatherMate.lua`, `tools/merge_gathermate.py`, `tools/check_data.py` | Livré |
| F59 | Base de minerais GatherMate (8 920 points, 41 régions, 18 minerais), catégorie à part (D18) | `Data/OreDataGatherMate.lua`, `tools/merge_gathermate.py --category ores` | Livré |
| F51 | Minerais Wowhead par export du navigateur (520 points ajoutés) | `Data/OreDataWowhead.lua`, `tools/wowhead_export_ores.js`, `tools/merge_wowhead_ores.py` | Livré |
| F54 | Fusion des points voisins à 1 unité au chargement (`/hr merge`), fichiers intacts (D21) | `Resolver.lua` (`DataFor`) | Livré |
| — | Outils de contrôle : comparaison avec GatherMate, rapport des doublons | `tools/compare_sources.py`, `tools/report_duplicates.py`, `docs/COMPARAISON_BASES.md`, `docs/DOUBLONS.md` | Livré |

### B. Créer et suivre la route
**B1. Préparer et générer**
| Réf. | Fonctionnalité | État |
|---|---|---|
| F2 | Région vers carte TomTom, surcharge `/hr setmap` | Livré |
| F3 | Région et position courantes | Livré |
| F4 | Route optimisée (plus proche voisin puis 2-opt, identique au planner) | Livré |
| F5 | Génération sans gel du client | Livré |

**B2. Suivre**
| Réf. | Fonctionnalité | État |
|---|---|---|
| F6 | Mode Suivi : un waypoint à la fois (seul mode depuis le 2026-11-19, F7 retiré) | Livré |
| F8 | Skip, Stop, retrait externe | Livré |
| F53 | Touches clavier et bouton Skip | Livré |

**B3. Interface**
| Réf. | Fonctionnalité | État |
|---|---|---|
| F9 | Commandes `/hr`, `/herbroute` | Livré |
| F10 | Fenêtre : région, types, départ, rayon, boutons | Livré |
| F13 | Réglages mémorisés (`HerbRouteDB`) | Livré |
| F16 | Choix herbes ou minerais, puis région, puis type (cases dans la fenêtre, `/hr ores …`, pistage de la catégorie) | Livré |
| F69 | Case « messages dans le chat » (`/hr chat`) | Livré |
| F70 | Recherche de région par lettres dans la liste | Livré |
| F72 | Fenêtre de stats (`/hr stats`) : durée de la route, butin des cueillettes, estimation en or, prix d'Auctionator mémorisés | Livré |
| F11 | Tracé sur la carte du monde | Livré, **validé en jeu** |
| F12 | Tracé sur la minimap | Livré |

**B4. Vérifier et ajuster avec la minimap**
| Réf. | Fonctionnalité | État |
|---|---|---|
| F21 | Isolement du pistage pendant une route | Livré |
| F22, F23, F24, F26, F27, F28, F34, F39 | Vérification du point courant, modes `report` et `remove` | Livré |
| F49 | Vérification en avance sur toute la route | Livré |
| F52 | Retrait des minerais | Livré, calibration validée |
| F47 | Calibration de la méthode de sondage | Livré et validé en jeu |
| F55 | Réordonnancement après retraits (`/hr reroute`) | Livré |
| F60 | Surveillance et réinsertion des points de la base hors route qui réapparaissent sur la minimap (`/hr revive`) | Livré |
| F61 | Cible = point rempli le plus proche après une sonde positive, recalcul à l'arrivée (`/hr nearest`) | Livré |
| F62 | Sondage par proximité : un seul groupe de candidats, le plus proche d'abord | Livré |
| F63 | Gestion des faux positifs : positifs ambigus, sondage décalé, rejeté traité comme absent (`/hr ambiguity`) | Livré |
| F66 | Recontrôle d'un point confirmé à 110 yd | Livré |
| F67 | Case « sonder en combat » (toutes les sondes) | Livré |
| F68 | Cueillette : événements, vague de ressondage au début (`/hr gather`) | Livré, observé en jeu |
| F71 | Croix rouges sur les spots ambigus en attente ou non résolus (`/hr ambiguity marks`) | Livré |

**B5. Diagnostiquer** (activité archivée de la story map, code conservé)
| Réf. | Fonctionnalité | État |
|---|---|---|
| F20, F36, F38 | `/hr probe`, `blink world`, `watch` | Livré et validé en jeu |
| F65 | `/hr probe zone` : mesure de la zone de réponse d'un blip (taille, centre, point de la base le plus proche) | Livré et validé en jeu |
| F45, F46, F48 | `/hr verify probe`, `scan`, `arming` | Livré |

**Transversal** : F14 documentation et zip d'installation.

## Livré (HerbRoute v1.0.0)
| Réf. | Fonctionnalité | Statut | Hors jeu | En jeu | Fichiers |
|---|---|---|---|---|---|
| F1 | Base des points embarquée (45 régions, 29 herbes, 13 256 points) | Livré | Oui (comptage) | Non | `Data/HerbData.lua`, `tools/gen_data.py` |
| F2 | Région vers mapID via `TomTom.NameToMapId`, surcharge `/hr setmap` | Livré | Oui (faux TomTom) | Non | `Resolver.lua`, `Core.lua` |
| F3 | Détection de la position et de la région courantes | Livré | Oui (faux TomTom) | Non | `Resolver.lua` |
| F4 | Route optimisée (plus proche voisin puis 2-opt), identique au planner | Livré | Oui (4 cas identiques) | Non | `RouteMath.lua` |
| F5 | Génération sans gel du client (coroutine) | Livré | Oui | Non | `Runner.lua` |
| F6 | Mode Suivi (un waypoint à la fois, avancement automatique) ; seul mode depuis le 2026-11-19 | Livré | Oui | Non | `Runner.lua` |
| F8 | Skip, Stop, retrait externe d'un waypoint | Livré | Oui | Non | `Runner.lua` |
| F9 | Commandes `/hr`, `/herbroute` (route, stop, skip, debug, setmap) | Livré | Oui | Non | `Core.lua` |
| F10 | Fenêtre : région, types, départ, rayon, boutons | Livré | Non (rendu non testable) | Non | `UI.lua` |
| F11 | Tracé de la route sur la carte du monde (rendu robuste le 2026-11-19 : création à la demande, indépendant de HereBeDragons, ID de carte tolérant, cadre en strate `HIGH`) | **Livré et validé en jeu** (le joueur confirme que le correctif fonctionne) | Non | Non | `Overlay.lua` |
| F12 | Tracé de la route sur la minimap (rayon, rotation, découpe au disque ; tous les points restants de la route depuis le 2026-11-19, plus de limite de 40) | Livré | Non | Non | `Overlay.lua` |
| F13 | Réglages mémorisés (`HerbRouteDB`) | Livré | Partiel | Non | `Core.lua`, `UI.lua` |
| F14 | Documentation et zip d'installation | Livré | n/a | n/a | `README.md`, `CLAUDE.md`, `tools/README.md` |
| F15 | Enrichissement de la base par GatherMate (Forever) : fichier `Data/HerbDataGatherMate.lua` (+1 386 points, région Felwood), base d'origine intacte, outils `tools/merge_gathermate.py` et `tools/check_data.py` | **Livré** (vérifié hors jeu : points d'origine inchangés, ajouts distincts, tests de l'add-on) ; non testé en jeu | Hors jeu : oui | Non | `Data/HerbDataGatherMate.lua`, `tools/` |
| F16 | **Choix herbes ou minerais**, puis région, puis type : cases dans la fenêtre, `/hr ores …`, pistage de la catégorie (Trouver les minéraux), sélections mémorisées séparément | **Livré** (testé hors jeu ; fenêtre sur faux widgets) ; non testé en jeu | Hors jeu : oui | Non | `Resolver.lua`, `Runner.lua`, `Tracking.lua`, `Core.lua`, `UI.lua` |
| F59 | **Base de minerais GatherMate** : `Data/OreDataGatherMate.lua` (8 920 points, 41 régions, 18 minerais), `HerbRoute_OreData[région][minerai]`, catégorie à part (D18), outil `tools/merge_gathermate.py --category ores` | **Livré** (vérifié hors jeu) ; non testé en jeu | Hors jeu : oui | Non | `Data/OreDataGatherMate.lua`, `tools/merge_gathermate.py` |
| F49 | **Vérification en avance** : sonde les points suivants (**toute la route**, voir D19) situés dans 85 % du rayon de vue ; automatique par défaut, `/hr verify ahead [on|off]`, passe manuelle `/hr verify ahead` | **Livré** (testé hors jeu) ; non testé en jeu | Hors jeu : oui | Non | `Verify.lua`, `Core.lua` |
| F51 | **Minerais Wowhead** : script de console `tools/wowhead_export_ores.js` (lit `g_mapperData` de chaque gisement) et `tools/merge_wowhead_ores.py` (rattachement par `uiMapId`, doublons à 0,5 %, fichier séparé `OreDataWowhead.lua`) | **Livré** : export du joueur importé (10 651 points Wowhead, 520 ajoutés, 12 minerais, indurium sans données de carte), `Data/OreDataWowhead.lua` chargé après `OreDataGatherMate.lua` ; testé hors jeu, non testé en jeu | Hors jeu : oui (outil) | Non | `tools/` |
| F52 | **Retrait des minerais** : même vérification et même retrait que pour les herbes (pistage « Trouver les minéraux », `/hr verify calibrate ores`, `arming ores`) | **Livré**, testé hors jeu sur une route de minerais ; **calibration sur un point de minerai validée en jeu** (méthode « plain »), retrait en route non testé | Hors jeu : oui | Non | `Verify.lua`, `Core.lua`, `tools/test_addon.py` |
| F53 | **Skip associable à une touche** : raccourcis clavier `Bindings.xml` (Skip, Stop, fenêtre) dans Options > Raccourcis clavier > AddOns, et bouton Skip optionnel (`/hr button`, déplaçable par Maj + glisser) | **Livré**, testé hors jeu (fonctions, sans rendu) ; non testé en jeu | Hors jeu : partiel | Non | `Bindings.xml`, `Core.lua`, `UI.lua` |
| F54 | **Fusion des voisins à 1 unité** au chargement (herbes 14 642 → 10 458, minerais 9 440 → 8 834), `/hr merge [on|off]`, activée par défaut, fichiers de données intacts | **Livré**, testé hors jeu ; non testé en jeu | Hors jeu : oui | Non | `Resolver.lua`, `Runner.lua`, `Core.lua` |
| F55 | **Réordonnancement de la route après retraits** (`/hr reroute [on|off|now]`, case dans la fenêtre, désactivé par défaut) : plus proche voisin puis 2-opt depuis la position réelle du joueur sur les points restants (point courant compris), repli sur le point courant, état de vérification conservé, base intacte | **Livré**, testé hors jeu ; non testé en jeu | Hors jeu : oui | Non | `Runner.lua`, `Core.lua`, `UI.lua` |
| F60 | **Surveillance et réinsertion des points de la base hors route** (B19, B25, D26, D33, D34) : les candidats sont les points de la base des types de la route qui ne sont pas en avance dans la route (atteints, skippés, retirés comme absents, perdus), dans la minimap (85 % du rayon) ; la cause et l'heure de sortie sont gardées pour la route en cours seulement ; 10 s d'attente après l'arrivée ; premier sondage dès l'entrée dans le disque, puis un nouveau sondage à chaque **60 yd parcourus** (odomètre du personnage) ; les points en avance trouvés vides (point courant compris, mode `report`) sont resondés de la même façon, en silence ; ordre : ambiguïté en attente, points jamais sondés, puis resondages, le plus proche d'abord ; sonde minimap cachée ; un point qui répond est réinséré **en tête de route** avec un nouveau waypoint, ambigu ou non (D40, D42) ; la règle du plus proche s'applique ensuite, puis le reste de la route est recalculé depuis le point de tête ; `/hr revive [on|off]` (activée par défaut), case dans la fenêtre | **Livré**, testé hors jeu (faux minimap) ; sondes pendant une cueillette observées en jeu, le reste non testé en jeu | Hors jeu : oui | Partiel | `Runner.lua`, `Verify.lua`, `Core.lua`, `UI.lua`, `tools/test_addon.py` |
| F66 | **Recontrôle d'un point confirmé à 110 yd** (B26, D35) : un point confirmé depuis plus de 110 yd est resondé une fois à 110 yd, toujours actif (sans réglage), en plus du contrôle à 35 yd avant l'arrivée ; impossible aux zooms 4 et 5 ; sauté si la confirmation a eu lieu à moins de 110 yd ou pour un point réinséré ; un point vide est traité comme absent | **Livré**, testé hors jeu ; non testé en jeu | Hors jeu : oui | Non | `Verify.lua`, `Runner.lua`, `tools/test_addon.py` |
| F67 | **Sonder en combat** (B27, D36) : case « Probe the minimap during combat » et `/hr verify combat [on|off]`, désactivée par défaut ; elle lève la garde de combat pour **toutes** les sondes (route, `/hr probe …`, calibration, balayage) par `MM.combatBlocked()` ; si le client refuse de remettre la minimap, nouvelles tentatives chaque seconde et aucune autre sonde avant | **Livré**, testé hors jeu ; la lecture en combat n'est pas testée en jeu | Hors jeu : oui | Non | `MinimapUtil.lua`, `Verify.lua`, `Probe.lua`, `UI.lua`, `Core.lua` |
| F68 | **Cueillette** (B28, D37) : écoute des événements de lancer de sort du joueur ; sort reconnu par identifiant ou par nom (gathering, herbalism, mining), repli par la position ; le nœud est le point de la base le plus proche à moins de 12 yd de la position au début (le personnage est immobile) ; **au début** : vague de ressondage de tous les points qui ont pu réapparaître, **pendant la canalisation** (garde « lancer de sort » levée pour une cueillette reconnue, garde « bouger la souris une fois » conservée), nœud cueilli exclu ; **à la fin** : plus de vague, le point cueilli est retiré de la route comme atteint si la cueillette réussit (avancement si c'est le point courant) ; trace `/hr gather debug on` | **Livré**, testé hors jeu ; **observé en jeu** : sort 11993 « Herbalism », événements reçus, cueillette reconnue, nœud retrouvé, deux sondes faites pendant la cueillette (réponse « empty ») | Hors jeu : oui | Partiel | `Gather.lua`, `Verify.lua`, `Runner.lua`, `Core.lua`, `tools/test_addon.py` |
| F69 | **Messages dans le chat** (B29, D38) : case « Show HerbRoute messages in the chat » et `/hr chat [on|off]` ; `HR:Print` (messages automatiques) est silencieux case décochée, `HR:Say` (réponses aux commandes, diagnostics, trace de cueillette) s'affiche toujours | **Livré**, testé hors jeu ; rendu non testé en jeu | Hors jeu : oui | Non | `Core.lua`, `UI.lua`, `Probe.lua`, `Verify.lua`, `Gather.lua` |
| F70 | **Recherche de région par lettres** (B30, D39) : un champ dans la liste déroulante des régions ; toutes les lettres tapées doivent être présentes dans le nom, dans n'importe quel ordre, occurrences comptées, majuscules et ponctuation ignorées ; Entrée choisit la première région, « No match » si rien | **Livré**, testé hors jeu (règle de correspondance) ; rendu non testé en jeu | Hors jeu : partiel | Non | `UI.lua`, `tools/test_addon.py` |
| F71 | **Croix rouges sur les spots ambigus** (B31, D41) : chaque spot ambigu en attente du sondage décalé ou non résolu est marqué d'une croix rouge (deux lignes diagonales, sans capter la souris) sur la minimap et la carte du monde ; `/hr ambiguity marks [on\|off]`, activée par défaut | **Livré**, testé hors jeu ; rendu non vu en jeu | Hors jeu : oui | Non | `Overlay.lua`, `Verify.lua`, `Core.lua`, `tools/test_addon.py` |
| F72 | **Fenêtre de stats** (B33, D43 à D46) : cadre déplaçable de 210 × 210, `/hr stats` et bouton « Stats » de la fenêtre principale ; durée de la route en direct (figée à l'arrêt) ; butin compté uniquement pendant une cueillette (début reconnu jusqu'à 8 s après la fin) par les messages de butin, avec repli par le nombre d'objets dans les sacs ; or estimé (total et par heure) avec le prix de l'hôtel des ventes lu dans Auctionator et mémorisé dans `HerbRouteDB.prices`, sinon le prix marchand (étoile) ; une ligne par objet, 8 lignes visibles et barre déroulante, icônes de pièces ; `/hr stats reset`, `/hr stats probe` | **Livré**, testé hors jeu sur les 40 objets ; **observé en jeu** : fenêtre, durée, total et prix ; l'affichage d'une seule ligne a été corrigé (une ligne par objet), non revu en jeu ; interface d'Auctionator non vérifiée | Hors jeu : oui | Partiel | `Stats.lua`, `Gather.lua`, `Runner.lua`, `Core.lua`, `UI.lua`, `tools/test_addon.py` |
| F61 | **Reroutage vers le point rempli le plus proche** (B20, D27) : après une sonde positive (point courant, en avance ou skippé qui revient), le point confirmé le plus proche de la position du joueur dans la minimap devient la cible (point déplacé en tête de route, nouveau waypoint TomTom, message « Nearest: … »), sans seuil de distance ; à l'arrivée, un seul recalcul de la route depuis la position (comme `/hr reroute now`, indépendant de cette option) ; un skip annule le recalcul ; `/hr nearest [on|off]` (activée par défaut), case dans la fenêtre | **Livré**, testé hors jeu (faux minimap) ; non testé en jeu | Hors jeu : oui | Non | `Runner.lua`, `Verify.lua`, `Core.lua`, `UI.lua`, `tools/test_addon.py` |
| F62 | **Sondage par proximité** (B21, D28) : les points en avance dans la minimap (F49) et les points skippés qui reviennent (F60) forment un seul groupe, sondé du plus proche au plus éloigné de la position du joueur ; le point courant reste sondé en premier ; un point sans conclusion n'en bloque plus d'autres | **Livré**, testé hors jeu (ordre des distances) ; non testé en jeu | Hors jeu : oui | Non | `Verify.lua`, `tools/test_addon.py` |
| F63 | **Gestion des faux positifs** (B22, D29) : un positif est **ambigu** si un autre point de la base de la catégorie de la route (tous types) est à moins de H + 2,5 unités du candidat (H = 8 / échelle effective, ou la valeur mesurée) ; un ambigu est **traité comme un point rempli ordinaire** (D40) : ciblé et réinséré comme les autres ; **un sondage décalé caché** continue en arrière-plan : ligne = distinct, aucune ligne = rejeté **traité comme absent** (retiré en `remove`), trois essais sans conclusion = non résolu ; les spots en attente ou non résolus sont marqués d'une croix rouge (F71) ; `/hr ambiguity [on|off]` (activée par défaut), compteurs dans `/hr verify` | **Livré**, testé hors jeu (faux minimap) ; non testé en jeu | Hors jeu : oui | Non | `Verify.lua`, `Runner.lua`, `Core.lua`, `Probe.lua`, `tools/test_addon.py` |
| F65 | **`/hr probe zone [hidden]`** (B24, D32) : mesure la zone de réponse d'un blip en déplaçant la minimap sous un curseur au repos (décalages de 1 à 8 unités puis de 2 unités jusqu'à 30, quatre directions), largeur, demi-zone et centre de chaque axe, point de la base le plus proche du centre et voisins à moins de 45 unités ; contrôle par un cadre sur le curseur ; enregistre automatiquement la demi-zone et l'échelle effective dans `HerbRouteDB.zone` | **Livré et validé en jeu** (zone d'environ 22 unités, centrée sur le point de la base, herbes) ; minerais non mesurés | Hors jeu : oui | Oui | `Probe.lua`, `Verify.lua`, `tools/test_addon.py` |

## Cadré (vérification des points sur la minimap)
| Réf. | Fonctionnalité | Statut | Dépend de | Fichiers prévus |
|---|---|---|---|---|
| F20 | `/hr probe` et `/hr probe minimap` : environnement, pistages actifs, fonctions présentes, lecture du survol réel (présence, forme des données avec **valeurs des champs numériques**, valeurs secrètes), rapport dans le chat, `HerbRouteDB` et une fenêtre à copier. Réduite le 2026-11-19 (voir « Retiré ») | **Livré** (testé hors jeu sur faux minimap ; 2 rapports en jeu : présence lisible sous le vrai curseur, nom secret, sondage par position sans effet) | Test en jeu (contrôle sol vide à faire) | `Probe.lua` |
| F21 | **Isolement du pistage pendant une route** : au lancement, seul « Trouver les herbes » reste actif (configuration d'origine sauvegardée dans `HerbRouteDB`), restauration à l'arrêt (bouton, `/hr stop`, fin de route, réinitialisation groupée), après un `/reload` ou une reconnexion, et après un combat si l'action tombait en combat ; commande `/hr tracking`, case dans la fenêtre | **Livré** (testé hors jeu sur API de pistage simulée, **à lancer en jeu**) | Test en jeu | `Tracking.lua`, `Runner.lua`, `Core.lua`, `UI.lua` |
| F22 | Sondage d'un candidat par `blink` : un sondage (minimap amenée sous le curseur au repos dans le monde, lecture à +1 image, retour) | **Livré** dans `Verify.lua` (via F39), testé hors jeu ; non testé en jeu | F36 | `Verify.lua`, `MinimapUtil.lua` |
| F23 | Déclenchement à l'entrée du prochain waypoint dans le disque (85 % du rayon), 1 sondage vide pour l'absence, dernier contrôle à moins de 35 yd | **Livré** pour le prochain waypoint (F39), testé hors jeu | F22 | `Verify.lua` |
| F24 | Retrait des waypoints sans correspondance (`TomTom:RemoveWaypoint`) et de l'état du trajet en cours ; **la base n'est jamais modifiée** | **Livré** (`DropPoint`, mode `remove`), testé hors jeu | F23 | `Runner.lua`, `Verify.lua` |
| F25 | Restauration de la route d'origine (`/hr restore`) | Cadré | F24 | `Runner.lua`, `Core.lua` |
| F26 | Garde-fous : pistage actif, minimap visible, bonne carte, hors combat, souris au repos dans le monde ; la garde « aucun retrait avant un premier point confirmé » a été supprimée (D20) | **Livré** (liste dans le journal), testé hors jeu | F23 | `Verify.lua` |
| F27 | Interface : case « Verify the next point on the minimap », compteur « removed » ; compteurs confirmés non affichés | **Partiel** (case et compteur de retraits livrés) | F24 | `UI.lua` |
| F28 | Tracés : ignorer les points retirés | **Livré** ; couleur des points confirmés non faite | F24 | `Overlay.lua` |
| F29 | Faux minimap dans les tests pour valider états, retraits et garde-fous | Cadré | F23 | `tools/test_addon.py` |
| F34 | Vérification par **présence** d'un point (noms secrets acceptés) ; présence = au moins une ligne d'infobulle | Cadré, **validée en principe en jeu** (`blink world` : point = ligne, contrôles = aucune) | F36 | `Verify.lua` |
| F39 | **Vérification ciblée du prochain waypoint** (mode Suivi) : modes `off`, `report` (défaut) et `remove`, commande `/hr verify`, case dans la fenêtre ; garde « bouger la souris une fois » après avoir dirigé à la souris ; **pin TomTom masqué pendant les sondes (D15) ; ~~vérification de la projection sur 12 points voisins (D16)~~ **supprimée à la demande du joueur (D20)** | **Livré**, testé hors jeu ; **premier essai en jeu : 4 sondes inconclusives**, corrigé (plus d'abandon silencieux, causes, garde) et diagnostic ajouté ; à retester en jeu | F22 | `Verify.lua`, `MinimapUtil.lua`, `Runner.lua`, `Overlay.lua`, `Tracking.lua`, `Core.lua`, `UI.lua` |
| F45 | `/hr verify probe` : une sonde détaillée sur le point courant avec la méthode calibrée (simple si non calibrée) | **Livré**, testé hors jeu | F47 | `Verify.lua` |
| F46 | `/hr verify scan` : balayage de la minimap avec la méthode calibrée, carte ASCII des points jaunes (`X`) et des points projetés (`o`) dans la fenêtre à copier, symétries comparées | **Livré et validé en jeu** : l'essai avec la variante curseur logiciel était invalide ; depuis la calibration (`plain`), les scans voient les points jaunes, regroupent les cases en nœuds et mesurent décalages et échelle : **projection juste (3 unités d'écart, échelle 1,01)** | F47 | `Verify.lua` |
| F47 | `/hr verify calibrate` : choisit en jeu, sur un point jaune pointé par le joueur et une position témoin, la méthode de sondage parmi sept, la mémorise avec le numéro de build ; sans calibration valide la vérification ne sonde pas | **Livré et validé en jeu** : six méthodes sur sept voient le point, « plain » mémorisée (build 70959), « curseur logiciel + mise à jour » invalide | F39 | `Verify.lua` |
| F48 | `/hr verify arming` : sonde le point connu et un témoin à 6, 10, 15, 20, 30, 45 et 60 s après un survol réel, souris immobile, pour mesurer combien de temps la lecture reste possible (R26) | **Livré** (testé hors jeu), **à lancer en jeu** | F47 | `Verify.lua` |
| F44 | Test `blink chain` : déplacer la minimap directement d'une position à l'autre sous le curseur, sans la remettre, pour savoir si la lecture se rafraîchit | Idée | F36 | `Probe.lua` |
| F35 | ~~Déplacement de la minimap sous un curseur déjà sur la minimap (`/hr probe blink`)~~ | **Retiré** : non concluant en jeu, remplacé par F36 | n/a | n/a |
| F36 | Sondage positionnel par la méthode de NodeRadar (`/hr probe blink world`, `blink world hidden`) ; verdict sur la présence = au moins une ligne | **Livré et validé en jeu** sur deux points, en version visible et cachée : touché = ligne à +1 image, contrôles à 40 unités = aucune ; **déplacement jugé gênant** par le joueur ; verdict corrigé (un contrôle vide suffit, les points voisins sont signalés) ; autres zooms non testés | Test en jeu (zooms) | `Probe.lua` |
| F37 | ~~Cartographie de la présence par `blink` sur une grille~~ | **Abandonné** : inutile, un sondage par candidat suffit | n/a | n/a |
| F38 | `/hr probe watch` : 15 s, journal des changements de présence (lignes) et de signature | **Livré et validé en jeu** : lignes uniquement sur un point (carré d'une vingtaine d'unités), « empty » au sol, « none » hors minimap | Terminé | `Probe.lua` |

## Idées et options
| Réf. | Fonctionnalité | Statut | Remarque |
|---|---|---|---|
| F30 | Contournements de lecture : curseur logiciel, déplacement furtif de la minimap (`/hr probe blink`) | Idée, **devient F35** (seule piste de sondage positionnel connue) | Selon le résultat de F20 ; le déplacement furtif touche à la position de la minimap |
| F31 | Dézoom temporaire de la minimap pendant la passe | Idée | Élargit le champ de détection mais change l'affichage |
| F32 | Mémoire de récolte (états pris et vide, événement de récolte, bouton « rien ici ») | Idée, optionnelle | Séparée de la base ; durée de vie entre trajets à décider |
| F33 | Recalcul complet de la route après changements d'état | Idée, désactivé par défaut | Remplacé par le simple retrait de points (D7) |

## Hors périmètre
| Réf. | Fonctionnalité | Remarque |
|---|---|---|
| F40 | Routes multi-régions | |
| F41 | Interface en français et client non anglais | Hypothèse actuelle : client en anglais |
| F42 | Aperçu du tracé dans la fenêtre de l'add-on | Le tracé est sur la carte et la minimap |
| F43 | Recalage de la base à partir des écarts mesurés | Interdit par la contrainte D8 |


## Retiré (nettoyage du 2026-11-19)
| Réf. | Sonde retirée | Raison |
|---|---|---|
| R-1 | Balayages de la minimap (conventions curseur et unités d'interface, curseur logiciel, lecture à +1 image) | `UpdateMouseoverAtPoint` sans effet positionnel : 100 % de réponses partout, écho du survol réel |
| R-2 | Étalonnage de la zone de réponse et écart à la base | Dépendaient de réponses positionnelles ; la zone (environ 25 unités) est rapportée par NodeRadar |
| R-3 | `/hr probe zoom` (zoom et points hors disque) | Dépendait d'une configuration qui lit par position |
| R-4 | `/hr probe blink` (curseur déjà sur la minimap) | Non concluant, remplacé par `blink world` |
| R-6 | Mode « Tout afficher » (F7) : tous les points en pins TomTom | Retiré à la demande du joueur (2026-11-19) : le mode Suivi est le seul mode |
| R-5 | `/hr probe world` | Plus de différence avec `/hr probe` (lecture du survol réel) |
| R-7 | F64 : zoom d'arbitrage de 0 vers 5 pour distinguer un positif ambigu | Abandonné à la demande du joueur (2026-11-20), remplacé par le sondage décalé (F63) |

Les anciennes versions restent dans l'historique Git (dernier commit avant nettoyage : `30c4969`).

## SkinRoute (add-on de zones pour le dépeçage, v0.10.2)
Références **S**. « Hors jeu » = faux environnement WoW/TomTom (`tools/test_skinroute.py`) ; « En jeu » = vu par le joueur (captures ou essai).

### S-A. Données
| Réf. | Fonctionnalité | Où | Hors jeu | En jeu |
|---|---|---|---|---|
| S1 | Export Wowhead par la console (garde-fous, état, validation) | `tools/wowhead_export_skinning.js` | — | Exécuté par le joueur (607 créatures) |
| S2 | Fusion CMaNGOS + pfQuest + Wowhead, nettoyage, sortie Lua | `tools/merge_skinning.py`, `tools/test_merge_skinning.py` | Oui | Données chargées |
| S3 | Données générées (651 créatures, 44 zones, 29 objets, 22 529 points), **non versionnées** | `SkinRoute/Data/SkinData.lua` | Fumée sur vraies données | Oui |

### S-B. Calcul
| Réf. | Fonctionnalité | Où | Hors jeu | En jeu |
|---|---|---|---|---|
| S4 | Règles : dépeçable, bande de niveau, difficulté, statuts, valeur, pourcentage | `Rules.lua` | Oui | Affichage vu |
| S5 | Région vers carte, région courante, surcharge `/sr setmap` | `Resolver.lua` | Oui | Validé |
| S6 | Niveau et Dépeçage réels ou simulés | `Core.lua`, `Skill.lua` | Oui | Simulé vu ; lecture réelle **non vue** |
| S7 | Prix : manuel, Auctionator, marchand ; `/sr price`, `/sr prices` | `Prices.lua` | Oui | Prix affichés ; source **non vérifiée** |
| S8 | Couverture en zones de 233 yd, tranches de calcul | `Zones.lua` | Oui | Validé |
| S9 | Vue Profit : or par heure, temps par bête (10 s + 15 s × 1,10^écart), `/sr time` | `Rules.lua`, `Core.lua` | Oui | Affichée |
| S10 | Choix automatique des cuirs par région (seuil de 70 %, `/sr keep`), séparé de la sélection | `Rules.lua`, `Zones.lua`, `UI.lua` | Oui | Affiché |

### S-C. Interface et carte
| Réf. | Fonctionnalité | Où | Hors jeu | En jeu |
|---|---|---|---|---|
| S11 | Fenêtre de 442 px : vues Region, Item, Value, Profit, popups à recherche par lettres, Options | `UI.lua` | Oui | Vue Profit et Options vues |
| S12 | Prix en fin de ligne (Region, Item), alerte sans prix (Profit) | `UI.lua` | Oui | Prix vus |
| S13 | Cercles sur la carte du monde : contour par difficulté, pointillés si verrouillée, étiquettes, `/sr map` | `Overlay.lua` | Oui | Validé |
| S14 | Fond blanc transparent par masque (`/sr fill`, case « Fill ») | `Overlay.lua` | Oui | Fond vu ; choix du masque noté dans le journal |
| S15 | Police proportionnelle au cercle ; nombre de bêtes (`N mobs`, `X/Y mobs`) | `Overlay.lua` | Oui | Police vue ; nombre de bêtes **à voir** |
| S16 | Guide TomTom par zone : go, skip, stop | `Runner.lua` | Oui | Validé (Barrens) |
| S17 | Fenêtre de stats (`/sr stats`) | `Stats.lua` | Oui | **Non vue** |
| S18 | Touches et bouton Skip (`Bindings.xml`, `/sr button`) | `SkipButton.lua` | Oui | **Non vus** |
| S19 | Français : régions et objets | `Locale.lua` | Oui | **Non vu** |
| S20 | Diagnostic `/sr probe`, `/sr debug` | `Probe.lua`, `Resolver.lua` | Oui | Probe joué |

### S-D. Butin des bêtes (v0.11.0)
| Réf. | Fonctionnalité | Où | Hors jeu | En jeu |
|---|---|---|---|---|
| S21 | Extraction du butin CMaNGOS (références, groupes, or) : `--loot-out` | `tools/merge_skinning.py`, `tools/test_merge_skinning.py` | Oui | — |
| S22 | Prix du butin : gris marchand, blanc et vert au plus haut de l'HV et du marchand | `Prices.lua` | Oui | **Non vu** |
| S23 | Butin dans la valeur et le gain par heure, case « Mob loot », `/sr loot`, cuir et butin séparés | `Rules.lua`, `UI.lua`, `Core.lua` | Oui | **Non vu** |
| S24 | Butin des créatures de Forever : script Wowhead lu par le joueur (141 créatures, 12 035 lignes), importé par `--wowhead-loot` | `tools/wowhead_export_loot.js`, `tools/gen_loot_targets.py`, `tools/test_loot_export.js`, `tools/merge_skinning.py` | Oui | Lecture réelle faite ; calcul **non vu en jeu** |
| S25 | Butin des cadavres dans la fenêtre de stats (sections Skinning et Kills, or des pièces, case) | `Stats.lua` | Oui | **Non vu** |

### S-E. Meilleurs endroits, élites, rayon (v0.13.0)
| Réf. | Fonctionnalité | Où | Hors jeu | En jeu |
|---|---|---|---|---|
| S26 | Deux cercles magenta (meilleurs endroits) avec or par heure et trois créatures nommées, guide qui y va en premier | `Rules.lua`, `Zones.lua`, `Overlay.lua`, `Runner.lua` | Oui | **Non vu** |
| S27 | Option élites (case, `/sr elites`), temps de combat ×3, données `e = 1` (750 créatures) | `Rules.lua`, `UI.lua`, `Core.lua`, `tools/merge_skinning.py` | Oui | **Non vu** |
| S28 | Rayon 350 yd forcé une fois, butin dans toutes les vues, cases dans les Options | `Core.lua`, `Resolver.lua`, `UI.lua` | Oui | **Non vu** |
| S29 | Vue Profit : gain par heure de la meilleure zone de chaque région, calcul des zones des 44 régions en arrière-plan, plus de règle des 70 % | `Rules.lua`, `Zones.lua`, `UI.lua` | Oui | **Non vu** |

### Idées et écarts
- Plafond de réapparition et temps de recherche : écartés par le joueur (2026-11-24).
- Commission d'HV : écartée par le joueur.
- Position de départ : retirée de la fenêtre (non utile à un guide par zone).
