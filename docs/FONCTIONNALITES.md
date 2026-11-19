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
| F60 | Réinsertion des points skippés ou retirés qui réapparaissent sur la minimap (`/hr revive`) | Livré |
| F61 | Cible = point rempli le plus proche après une sonde positive, recalcul à l'arrivée (`/hr nearest`) | Livré |
| F62 | Sondage par proximité : un seul groupe de candidats, le plus proche d'abord | Livré |

**B5. Diagnostiquer** (activité archivée de la story map, code conservé)
| Réf. | Fonctionnalité | État |
|---|---|---|
| F20, F36, F38 | `/hr probe`, `blink world`, `watch` | Livré et validé en jeu |
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
| F60 | **Réinsertion des points skippés ou retirés qui réapparaissent** (B19, D26) : mémoire de la route en cours (Skip, touche, retrait externe, point absent), sonde `hidden` quand le point entre dans 85 % du rayon, réinsertion au moindre coût avec nouveau waypoint et message, rien si rien détecté ; `/hr revive [on|off]` (activée par défaut), case dans la fenêtre ; herbes et minerais | **Livré**, testé hors jeu (faux minimap) ; non testé en jeu | Hors jeu : oui | Non | `Runner.lua`, `Verify.lua`, `Core.lua`, `UI.lua`, `tools/test_addon.py` |
| F61 | **Reroutage vers le point rempli le plus proche** (B20, D27) : après une sonde positive (point courant, en avance ou skippé qui revient), le point confirmé le plus proche de la position du joueur dans la minimap devient la cible (point déplacé en tête de route, nouveau waypoint TomTom, message « Nearest: … »), sans seuil de distance ; à l'arrivée, un seul recalcul de la route depuis la position (comme `/hr reroute now`, indépendant de cette option) ; un skip annule le recalcul ; `/hr nearest [on|off]` (activée par défaut), case dans la fenêtre | **Livré**, testé hors jeu (faux minimap) ; non testé en jeu | Hors jeu : oui | Non | `Runner.lua`, `Verify.lua`, `Core.lua`, `UI.lua`, `tools/test_addon.py` |
| F62 | **Sondage par proximité** (B21, D28) : les points en avance dans la minimap (F49) et les points skippés qui reviennent (F60) forment un seul groupe, sondé du plus proche au plus éloigné de la position du joueur ; le point courant reste sondé en premier ; un point sans conclusion n'en bloque plus d'autres | **Livré**, testé hors jeu (ordre des distances) ; non testé en jeu | Hors jeu : oui | Non | `Verify.lua`, `tools/test_addon.py` |

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

Les anciennes versions restent dans l'historique Git (dernier commit avant nettoyage : `30c4969`).
