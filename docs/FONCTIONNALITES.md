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
| F20 | `/hr probe` : diagnostic de la lecture de la minimap. v1 livrée, puis **v2a livrée** : détection de l'écho du survol réel, lecture de base, structure des données, présence comptée sans texte, lecture à +1 image, position du curseur par géométrie. Rapport dans le chat, `HerbRouteDB` et une fenêtre à copier | **Livré** (testé hors jeu sur faux minimap ; 2 rapports en jeu : présence lisible sous le vrai curseur, nom secret, sondage par position non démontré) | Test en jeu | `Probe.lua` |
| F21 | Activation automatique du pistage « Trouver les herbes » | Cadré | F20 | `Probe.lua` ou `Verify.lua` |
| F22 | Sondage aux points connus avec croix de 17 positions, arrêt à la première réponse, dédoublonnage | Cadré | F20 | `Probe.lua` |
| F23 | Déclenchement à l'entrée d'un point dans le disque (seuil 85 % du rayon), 2 à 3 interrogations par point | Cadré | F22 | `Verify.lua` |
| F24 | Retrait des waypoints sans correspondance (`TomTom:RemoveWaypoint`) et de l'état du trajet en cours ; **la base n'est jamais modifiée** | Cadré | F23 | `Runner.lua`, `Verify.lua` |
| F25 | Restauration de la route d'origine (`/hr restore`) | Cadré | F24 | `Runner.lua`, `Core.lua` |
| F26 | Garde-fous : pistage actif, minimap visible, bonne carte, hors combat, lecture jugée fonctionnelle | Cadré | F23 | `Verify.lua` |
| F27 | Interface : case « Vérifier avec la minimap », compteurs (conservés, confirmés, retirés) | Cadré | F24 | `UI.lua` |
| F28 | Tracés : ignorer les points retirés, couleur des points confirmés | Cadré | F24 | `Overlay.lua` |
| F29 | Faux minimap dans les tests pour valider états, retraits et garde-fous | Cadré | F23 | `tools/test_addon.py` |
| F34 | Vérification par **présence** d'un point (noms secrets acceptés, faux positifs possibles entre nœuds voisins) | Cadré (D10) | F35 | `Verify.lua` |
| F35 | Sondage positionnel : déplacement furtif de la minimap sous le curseur au repos (`/hr probe blink`), avec garde-fous (souris au repos, aucun bouton enfoncé, restauration) | Cadré, **prochaine étape**, accord à obtenir | Test en jeu | `Probe.lua` |

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
