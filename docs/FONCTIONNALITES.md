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
| F21 | Activation automatique du pistage « Trouver les herbes » | Cadré | F20 | `Probe.lua` ou `Verify.lua` |
| F22 | Sondage aux points connus avec croix de 17 positions, arrêt à la première réponse, dédoublonnage | Cadré | F20 | `Probe.lua` |
| F23 | Déclenchement à l'entrée d'un point dans le disque (seuil 85 % du rayon), 2 à 3 interrogations par point | Cadré | F22 | `Verify.lua` |
| F24 | Retrait des waypoints sans correspondance (`TomTom:RemoveWaypoint`) et de l'état du trajet en cours ; **la base n'est jamais modifiée** | Cadré | F23 | `Runner.lua`, `Verify.lua` |
| F25 | Restauration de la route d'origine (`/hr restore`) | Cadré | F24 | `Runner.lua`, `Core.lua` |
| F26 | Garde-fous : pistage actif, minimap visible, bonne carte, hors combat, lecture jugée fonctionnelle | Cadré | F23 | `Verify.lua` |
| F27 | Interface : case « Vérifier avec la minimap », compteurs (conservés, confirmés, retirés) | Cadré | F24 | `UI.lua` |
| F28 | Tracés : ignorer les points retirés, couleur des points confirmés | Cadré | F24 | `Overlay.lua` |
| F29 | Faux minimap dans les tests pour valider états, retraits et garde-fous | Cadré | F23 | `tools/test_addon.py` |
| F34 | Vérification par **présence** d'un point (noms secrets acceptés) | **À risque** : présence probablement générique (sol vide présent), dépend de `type`/`dataInstanceID` (F38) | F38 | `Verify.lua` |
| F35 | ~~Déplacement de la minimap sous un curseur déjà sur la minimap (`/hr probe blink`)~~ | **Retiré** : non concluant en jeu, remplacé par F36 | n/a | n/a |
| F36 | Sondage positionnel par la méthode de NodeRadar (`/hr probe blink world`, `blink world hidden`) | **Livré**, lancé en jeu : le moteur rafraîchit bien le survol (présent sous le curseur, absent au retour) mais 4 positions sur 4 sont présentes : non départagé entre présence générique et zone de réponse large | Test en jeu | `Probe.lua` |
| F37 | Cartographie de la présence par `blink` sur une grille (relevé de `type`, `dataInstanceID`) | Cadré, **conditionnel** : seulement si F38 montre que la présence ou la signature varie avec les points | F38 | `Probe.lua` |
| F38 | `/hr probe watch` : 15 s, journal des changements de `type`/`line1type` et de présence avec la position du curseur, pendant que la souris est déplacée à la main (sol vide, points d'herbe, hors minimap) | **Livré** (testé hors jeu sur moteur simulé, **à lancer en jeu**) | Test en jeu | `Probe.lua` |

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