# Story map de HerbRoute

Lecture : de gauche à droite, le parcours d'un joueur qui récolte ; de haut en bas, du plus essentiel au plus accessoire. Références F = [FONCTIONNALITES.md](FONCTIONNALITES.md), D = décisions et B = besoins du [JOURNAL.md](JOURNAL.md) et de [BESOINS.md](BESOINS.md). Légende : ✅ validé en jeu · 🟦 livré, testé hors jeu seulement · 💡 idée · ⛔ hors périmètre · ✖ annulé.

## Colonne vertébrale (activités du joueur)
| 1. Choisir sa récolte | 2. Générer la route | 3. Suivre la route | 4. Voir la route | 5. Vérifier les points | 6. Ajuster en route | 7. Entretenir les données |
|---|---|---|---|---|---|---|

## Détail par activité et par tranche

### 1. Choisir sa récolte
| Tranche | Histoires |
|---|---|
| **Essentiel** | 🟦 Région détectée à ma position (F3) · 🟦 Région vers carte TomTom, surcharge `/hr setmap` (F2) · 🟦 Choix des herbes d'une région avec le nombre de points (F10) |
| **Confort** | 🟦 Choix herbes ou minerais, puis région, puis type (F16) · 🟦 Départ X/Y modifiable et « My position » (F10) · 🟦 Réglages mémorisés (F13) · 🟦 Commandes `/hr herbe`, `/hr ores …`, `/hr région: herbe` (F9) |
| **Plus tard** | ⛔ Routes multi-régions (F40) · ⛔ Interface en français (F41) |

### 2. Générer la route
| Tranche | Histoires |
|---|---|
| **Essentiel** | 🟦 Route optimisée, plus proche voisin puis 2-opt, identique au planner (F4) · 🟦 Génération sans gel du client (F5) · 🟦 Base de points d'herbes embarquée (F1) |
| **Confort** | 🟦 Fusion des points voisins à 1 unité, `/hr merge` (F54) · 🟦 Points d'herbes GatherMate ajoutés (F15) |
| **Plus tard** | ✖ Route qui tient compte du relief (B13, annulé) |

### 3. Suivre la route
| Tranche | Histoires |
|---|---|
| **Essentiel** | 🟦 Mode Suivi : un waypoint à la fois, arrivée automatique (F6) · 🟦 Skip, Stop, retrait externe (F8) |
| **Confort** | 🟦 Touches clavier et bouton Skip à l'écran (F53) · 🟦 Distance d'arrivée réglable (F10) |

### 4. Voir la route
| Tranche | Histoires |
|---|---|
| **Essentiel** | ✅ Tracé sur la carte du monde (F11) : validé en jeu après correctif · 🟦 Tracé sur la minimap, tous les points restants (F12) |
| **Confort** | 🟦 Overlay désactivé en mode manette · ✅ Diagnostic `/hr map` du tracé de la carte |

### 5. Vérifier les points avec la minimap
| Tranche | Histoires |
|---|---|
| **Essentiel** | ✅ Lecture d'un point jaune par la minimap, présence = au moins une ligne d'infobulle (F34, F36, F38) · ✅ Calibration de la méthode de sondage, herbes et minerais (F47) · 🟦 Vérification du point courant, modes `report` et `remove` (F39, F22–F24) |
| **Confort** | 🟦 Vérification en avance sur toute la route (F49) · 🟦 Retrait des minerais, même méthode (F52) · 🟦 Pistage isolé pendant la route, rétabli à l'arrêt (F21) · ✅ Projection des points sur la minimap vérifiée : 3 unités d'écart, échelle 1,01 (F46) |
| **Plus tard** | 💡 Dézoom temporaire pendant la passe (F31) |

### 6. Ajuster en route
| Tranche | Histoires |
|---|---|
| **Confort** | 🟦 Réordonnancement des points restants depuis ma position, option `/hr reroute` (F55) · 🟦 Réinsertion des points skippés ou retirés qui réapparaissent dans ma minimap, minimap cachée, `/hr revive` (F60) |
| **Cadré** | 💡 Reroutage vers le point rempli le plus proche de ma position, recalcul de la route à l'arrivée (F61, B20) |
| **Plus tard** | 💡 `/hr restore` : remettre la route d'origine (F25) · 💡 Mémoire de récolte (F32) · 💡 Recalcul complet (F33, remplacé en partie par F55) · ✖ Mémoire des points visités, nouveaux nœuds par balayage, validation par le butin (F56 à F58, annulés) |

### 7. Entretenir les données
| Tranche | Histoires |
|---|---|
| **Essentiel** | 🟦 Base d'origine jamais modifiée, ajouts seulement (D8, D17) · 🟦 Minerais GatherMate, 8 920 points (F59) |
| **Confort** | 🟦 Minerais Wowhead par export du navigateur, 520 points ajoutés (F51) · 🟦 Outils de fusion, de comparaison et de doublons (`tools/`, `docs/COMPARAISON_BASES.md`, `docs/DOUBLONS.md`) |
| **Plus tard** | ⛔ Recalage de la base d'après les écarts mesurés (F43) |

### 8. Diagnostiquer
Archivée : voir [archives/STORY_MAP_DIAGNOSTIC.md](archives/STORY_MAP_DIAGNOSTIC.md).

## Tranches de livraison
| Tranche | Contenu |
|---|---|
| **Validé en jeu** | Lecture et sondage par la minimap (F34, F36, F38), calibration herbes et minerais (F47), projection des points (F46), `/hr probe` (F20), diagnostic `/hr map`, tracé de la carte du monde (F11) |
| **Livré, à tester en jeu** | Génération et suivi de route (F1 à F6, F8), fenêtre (F10), touches et bouton Skip (F53), tracé de la minimap (F12), vérification du point courant et en avance (F39, F49), retrait des minerais (F52), isolement du pistage (F21), `/hr reroute` (F55), `/hr revive` (F60), `/hr merge` (F54), bases de minerais (F16, F51) |
| **Idées** | F25, F29, F31, F32, F33, F44 |
| **Hors périmètre ou annulé** | F40, F41, F42, F43 · relief (B13) · F56, F57, F58 |

## Écarts connus entre la carte et les fichiers
Quelques lignes de `FONCTIONNALITES.md` sont périmées (F26 : sécurité sur la projection supprimée par D20 ; F46 : premier essai invalide, remplacé par les scans valides). Cette story map reflète l'état réel.
