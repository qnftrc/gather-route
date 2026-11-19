# Suivi des fonctionnalités

Légende des statuts :
- **Livré** : code écrit et poussé.
- **Cadré** : décrit dans [BESOINS.md](BESOINS.md), pas encore codé.
- **Idée** : pistes non retenues pour l'instant.
- **Hors périmètre** : écarté pour la version courante.

Colonnes de vérification : « Hors jeu » = testé par script ou faux environnement ; « En jeu » = testé dans le client WoW (aucune fonctionnalité ne l'est encore).

## Livré (HerbRoute v1.0.0)
| Réf. | Fonctionnalité | Statut | Hors jeu | En jeu | Fichiers |
|---|---|---|---|---|---|
| F1 | Base des points embarquée (45 régions, 29 herbes, 13 256 points) | Livré | Oui (comptage) | Non | `Data/HerbData.lua`, `tools/gen_data.py` |
| F2 | Région vers mapID via `TomTom.NameToMapId`, surcharge `/hr setmap` | Livré | Oui (faux TomTom) | Non | `Resolver.lua`, `Core.lua` |
| F3 | Détection de la position et de la région courantes | Livré | Oui (faux TomTom) | Non | `Resolver.lua` |
| F4 | Route optimisée (plus proche voisin puis 2-opt), identique au planner | Livré | Oui (4 cas identiques) | Non | `RouteMath.lua` |
| F5 | Génération sans gel du client (coroutine) | Livré | Oui | Non | `Runner.lua` |
| F6 | Mode Suivi (un waypoint à la fois, avancement automatique) | Livré | Oui | Non | `Runner.lua` |
| F7 | Mode Tout afficher (tous les points en pins) | Livré | Oui | Non | `Runner.lua` |
| F8 | Skip, Stop, retrait externe d'un waypoint | Livré | Oui | Non | `Runner.lua` |
| F9 | Commandes `/hr`, `/herbroute` (route, stop, skip, debug, setmap) | Livré | Oui | Non | `Core.lua` |
| F10 | Fenêtre : région, herbes, départ, mode, rayon, boutons | Livré | Non (rendu non testable) | Non | `UI.lua` |
| F11 | Tracé de la route sur la carte du monde | Livré | Non | Non | `Overlay.lua` |
| F12 | Tracé de la route sur la minimap (rayon, rotation, découpe au disque) | Livré | Non | Non | `Overlay.lua` |
| F13 | Réglages mémorisés (`HerbRouteDB`) | Livré | Partiel | Non | `Core.lua`, `UI.lua` |
| F14 | Documentation et zip d'installation | Livré | n/a | n/a | `README.md`, `CLAUDE.md`, `tools/README.md` |

## Cadré (vérification des points sur la minimap)
| Réf. | Fonctionnalité | Statut | Dépend de | Fichiers prévus |
|---|---|---|---|---|
| F20 | `/hr probe` et `/hr probe minimap` : environnement, pistages actifs, fonctions présentes, lecture du survol réel (présence, forme des données avec **valeurs des champs numériques**, valeurs secrètes), rapport dans le chat, `HerbRouteDB` et une fenêtre à copier. Réduite le 2026-11-19 (voir « Retiré ») | **Livré** (testé hors jeu sur faux minimap ; 2 rapports en jeu : présence lisible sous le vrai curseur, nom secret, sondage par position sans effet) | Test en jeu (contrôle sol vide à faire) | `Probe.lua` |
| F21 | **Isolement du pistage pendant une route** : au lancement, seul « Trouver les herbes » reste actif (configuration d'origine sauvegardée dans `HerbRouteDB`), restauration à l'arrêt (bouton, `/hr stop`, fin de route, réinitialisation groupée), après un `/reload` ou une reconnexion, et après un combat si l'action tombait en combat ; commande `/hr tracking`, case dans la fenêtre | **Livré** (testé hors jeu sur API de pistage simulée, **à lancer en jeu**) | Test en jeu | `Tracking.lua`, `Runner.lua`, `Core.lua`, `UI.lua` |
| F22 | Sondage d'un candidat par `blink` : un sondage (minimap amenée sous le curseur au repos dans le monde, lecture à +1 image, retour) | **Livré** dans `Verify.lua` (via F39), testé hors jeu ; non testé en jeu | F36 | `Verify.lua`, `MinimapUtil.lua` |
| F23 | Déclenchement à l'entrée du prochain waypoint dans le disque (85 % du rayon), 2 sondages vides pour l'absence, dernier contrôle à moins de 35 yd | **Livré** pour le prochain waypoint (F39), testé hors jeu | F22 | `Verify.lua` |
| F24 | Retrait des waypoints sans correspondance (`TomTom:RemoveWaypoint`) et de l'état du trajet en cours ; **la base n'est jamais modifiée** | **Livré** (`DropPoint`, mode `remove`), testé hors jeu | F23 | `Runner.lua`, `Verify.lua` |
| F25 | Restauration de la route d'origine (`/hr restore`) | Cadré | F24 | `Runner.lua`, `Core.lua` |
| F26 | Garde-fous : pistage actif, minimap visible, bonne carte, hors combat, souris au repos dans le monde, aucun retrait avant un premier point confirmé | **Livré** (liste dans le journal), testé hors jeu | F23 | `Verify.lua` |
| F27 | Interface : case « Verify the next point on the minimap », compteur « removed » ; compteurs confirmés non affichés | **Partiel** (case et compteur de retraits livrés) | F24 | `UI.lua` |
| F28 | Tracés : ignorer les points retirés | **Livré** ; couleur des points confirmés non faite | F24 | `Overlay.lua` |
| F29 | Faux minimap dans les tests pour valider états, retraits et garde-fous | Cadré | F23 | `tools/test_addon.py` |
| F34 | Vérification par **présence** d'un point (noms secrets acceptés) ; présence = au moins une ligne d'infobulle | Cadré, **validée en principe en jeu** (`blink world` : point = ligne, contrôles = aucune) | F36 | `Verify.lua` |
| F39 | **Vérification ciblée du prochain waypoint** (mode Suivi) : modes `off`, `report` (défaut) et `remove`, commande `/hr verify`, case dans la fenêtre ; garde « bouger la souris une fois » après avoir dirigé à la souris | **Livré**, testé hors jeu ; **premier essai en jeu : 4 sondes inconclusives**, corrigé (plus d'abandon silencieux, causes, garde) et diagnostic ajouté ; à retester en jeu | F22 | `Verify.lua`, `MinimapUtil.lua`, `Runner.lua`, `Overlay.lua`, `Tracking.lua`, `Core.lua`, `UI.lua` |
| F45 | `/hr verify probe` : sonde détaillée sur le point courant avec quatre variantes (curseur logiciel + mise à jour d'abord) | **Livré et utile en jeu** : seule la variante curseur logiciel + `UpdateMouseoverAtPoint` renvoie des données | F39 | `Verify.lua` |
| F46 | `/hr verify scan` : balayage de la minimap (pas de 16 unités) avec la variante qui marche, carte ASCII des points jaunes et des points projetés de la route dans la fenêtre à copier, comparaison avec les symétries | **Livré** (testé hors jeu sur moteur simulé), **à lancer en jeu** pour valider la projection (R21) | F39 | `Verify.lua` |
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
| R-5 | `/hr probe world` | Plus de différence avec `/hr probe` (lecture du survol réel) |

Les anciennes versions restent dans l'historique Git (dernier commit avant nettoyage : `30c4969`).
