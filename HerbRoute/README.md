# HerbRoute

Add-on séparé qui s'appuie sur TomTom (dépendance obligatoire). Il génère une route optimisée
(plus proche voisin + amélioration 2-opt, identique au planner HTML) pour les herbes choisies
dans une région, puis la pilote avec les waypoints et la flèche de TomTom.

## Installation
Copier le dossier `HerbRoute` dans `Interface/AddOns/` à côté de `TomTom`, puis `/reload`.

## Utilisation
- `/hr` ouvre la fenêtre : région (pré-sélectionnée selon votre position), herbes, position de départ
  (prise automatiquement sur votre personnage, modifiable), mode, distance d'arrivée.
- `/hr <herbe>[, <herbe>]` : route dans la région actuelle (`all` pour toutes les herbes).
- `/hr <région>: <herbe>[, <herbe>]` : route dans une autre région (départ au centre de la carte).
- `/hr stop` : supprime la route (waypoints, flèche, tracé). `/hr skip` : passe le point courant.
- `/hr probe` : diagnostic de la lecture de la minimap (rapport dans le chat et dans une fenêtre à copier). Variantes : `world` ou `minimap` (lancement après 3 s, le temps de placer la souris), `zoom` (teste chaque niveau de zoom, restauré ensuite), `blink` (essai volontaire : souris posée **sans bouger** sur un point jaune, au centre de la minimap, la minimap est déplacée brièvement sous le curseur puis remise en place ; `blink hidden` la rend invisible pendant l'essai), `copy` (rouvre le dernier rapport). À lancer près d'une herbe, « Trouver les herbes » actif.
- `/hr debug` : affiche les régions résolues vers un mapID. Pour une région non résolue :
  `/hr setmap <région>: <mapID>`.

## Modes
- Suivi : un seul waypoint à la fois, le suivant s'active quand vous arrivez (distance réglable).
- Tout afficher : tous les points en pins TomTom.

Le tracé est dessiné sur la carte du monde et sur la minimap (désactivable dans la fenêtre).
Rien n'est sauvegardé entre deux sessions, hors réglages.
