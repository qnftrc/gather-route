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
- `/hr ores <minerai>[, <minerai>]` et `/hr ores <région>: <minerai>|all` : mêmes routes pour les minerais (données GatherMate). Dans la fenêtre, les cases **Herbs** / **Ores** choisissent la catégorie, puis la région, puis les types. Pendant une route de minerais, seul « Trouver les minéraux » reste actif.
- `/hr stop` : supprime la route (waypoints, flèche, tracé). `/hr skip` : passe le point courant.
- `/hr probe` : diagnostic de la lecture de la minimap (rapport dans le chat et dans une fenêtre à copier) : client, minimap, pistages actifs, fonctions présentes, lecture du survol réel de la souris. `/hr probe minimap` : même chose après 3 s, le temps de poser la souris sur la minimap. `/hr probe watch` (15 s : journal des changements de la lecture pendant que vous déplacez la souris sur sol vide, points d'herbe, puis hors de la minimap). `/hr probe blink world` (variante `hidden`) : méthode de NodeRadar, phase A la souris sur un point jaune, phase B la souris au repos dans le monde, hors de toute fenêtre, pendant que la minimap est déplacée sous le curseur puis remise en place. `/hr probe copy` rouvre le dernier rapport. À lancer près d'une herbe, « Trouver les herbes » actif.
- `/hr tracking [on|off|status|restore]` : pendant une route, seul le pistage « Trouver les herbes » reste actif ; votre configuration est sauvegardée et rétablie à l'arrêt de la route (aussi après `/reload` ou reconnexion, et après un combat si l'action tombait en combat). Activé par défaut, aussi réglable dans la fenêtre.
- `/hr verify [off|report|remove|status]` : vérification du **prochain waypoint** sur la minimap (mode Suivi). Quand le point entre dans le disque de la minimap et que votre souris repose **immobile dans le monde** (hors fenêtre, aucun bouton, hors combat), la minimap est déplacée une image sous le curseur pour savoir si un point d'herbe s'y trouve (le nom reste secret : la présence d'une ligne d'infobulle suffit). Sans nœud après un sondage (données sans ligne ; l'absence de données ne compte pas) : `report` (défaut) l'indique dans le chat et garde le point, `remove` le retire de la route et passe au suivant. Aucun retrait tant qu'aucun nœud n'a été vu dans la session : au premier point vide, l'add-on sonde jusqu'à 12 points voisins pour en trouver un et confirmer ainsi la projection ; sans aucun nœud trouvé, rien n'est retiré. La base de points n'est jamais modifiée. `/hr verify` sans argument donne l'état, la raison d'attente et les causes des sondes inconclusives. Après avoir dirigé le personnage à la souris, **bougez la souris une fois** : la lecture n'est rafraîchie qu'à ce prix. `/hr verify calibrate` (**à faire une fois par version du jeu**) : phase A, la souris sur un point jaune d'herbe proche du centre de la minimap ; phase B, la souris dans le monde, immobile. Sept méthodes de sondage sont essayées sur ce point et sur une position témoin ; la première qui voit le point est mémorisée avec le numéro de build. Sans calibration valide la vérification ne sonde pas. `/hr verify arming` : test de diagnostic d'une minute (souris sur un point jaune, puis immobile dans le monde) qui mesure combien de temps la lecture reste possible après un survol réel. `/hr verify probe` (après 3 s, **bougez la souris pendant le décompte puis laissez-la immobile**) sonde le point courant avec la méthode calibrée et affiche les lectures détaillées. `/hr verify scan` balaie toute la minimap (environ 10 s, la minimap saute à l'écran, souris immobile) et affiche dans une fenêtre une carte ASCII des points jaunes (`X`) et des points projetés de la route (`o`) pour vérifier la projection. Case correspondante dans la fenêtre.
- `/hr debug` : affiche les régions résolues vers un mapID. Pour une région non résolue :
  `/hr setmap <région>: <mapID>`.

## Modes
- Suivi : un seul waypoint à la fois, le suivant s'active quand vous arrivez (distance réglable).
- Tout afficher : tous les points en pins TomTom.

Le tracé est dessiné sur la carte du monde et sur la minimap (désactivable dans la fenêtre).
Rien n'est sauvegardé entre deux sessions, hors réglages.
