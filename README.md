# gather-route

Itinéraires de récolte d'herbes pour **WoW Forever**, pilotés par **TomTom**.

Le dépôt contient l'add-on **HerbRoute** : on choisit une région et des herbes, l'add-on calcule une route optimisée à partir de la position du personnage et la fait suivre par la flèche et les waypoints de TomTom, avec un tracé sur la carte du monde et la minimap.

## Origine
Ce projet remplace un planner HTML hors-jeu (saisie manuelle de la région, de X/Y et des herbes, puis copier-coller de lignes `/way`). Les données proviennent de Wowhead Forever : 45 régions, 29 herbes, 13 256 points. L'algorithme du planner (plus proche voisin puis amélioration 2-opt) est repris à l'identique.

## Installation
1. Installer TomTom.
2. Copier le dossier `HerbRoute/` dans `Interface/AddOns/`, à côté de `TomTom/`.
3. `/reload` en jeu.

## Utilisation rapide
- `/hr` ouvre la fenêtre (région pré-sélectionnée selon la position, herbes, départ, mode, distance d'arrivée).
- `/hr Fadeleaf, Briarthorn` : route dans la région actuelle.
- `/hr Stranglethorn Vale: Goldthorn` : route dans une autre région.
- `/hr stop` supprime la route, `/hr skip` passe le point courant, `/hr debug` liste les régions résolues.

Détails : [HerbRoute/README.md](HerbRoute/README.md).

## Contenu du dépôt
| Chemin | Rôle |
|---|---|
| `HerbRoute/` | L'add-on (à copier dans `Interface/AddOns/`) |
| `tools/` | Génération des données et tests hors-jeu ([tools/README.md](tools/README.md)) |
| `CLAUDE.md` | Contexte, décisions, risques et conventions du projet |
| `docs/BESOINS.md` | Expression de besoin en cours : points actifs, minimap, retracé en direct |
| `docs/JOURNAL.md` | Journal de pilotage : décisions, risques, prochaines actions |
| `docs/FONCTIONNALITES.md` | Suivi des fonctionnalités et de leur état de vérification |
| `docs/RECAPITULATIF.md` | Tableau des choix de conception et des tests à faire, par fonctionnalité |

## État
Logique et algorithme vérifiés hors-jeu (identiques au planner HTML, tests sur environnement simulé). L'interface et le tracé minimap n'ont pas encore été testés dans le client : voir la section « État et risques » de `CLAUDE.md`.
