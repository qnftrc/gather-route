# tools

Scripts hors-jeu. À lancer depuis la racine du dépôt. Les fichiers d'origine (JSON de waypoints, planner HTML) ne sont pas versionnés : passer leurs chemins en arguments.

## gen_data.py — régénérer les données
```bash
python3 -I tools/gen_data.py wowhead_forever_herbes_regions_waypoints.json HerbRoute/Data/HerbData.lua
```
Produit `HerbRoute_Data[région][herbe] = {{x,y}, ...}` (pourcentages). Affiche `regions 45 herbs 29 points 13256` : ces nombres doivent rester identiques à ceux du JSON.

## test_math.py — fidélité de l'algorithme
```bash
python3 -I tools/test_math.py WoW_Forever_Herb_Planner.html wowhead_forever_herbes_regions_waypoints.json
```
Exécute le JS du planner (`ref_route.js`, via Node) et `HerbRoute/RouteMath.lua` (via lupa) sur les mêmes points, et compare nombre de points, longueur de route et premiers points. Doit finir par `ALL SAME`.

## test_addon.py — logique de l'add-on
```bash
python3 -I tools/test_addon.py
```
Charge tous les fichiers Lua dans un faux environnement WoW/TomTom : résolution des régions, génération, avancement, skip, suppression externe, fin de route, mode pins, entrées invalides, puis `/hr probe` sur un faux minimap : lecture de base du survol réel, valeurs secrètes, fonction absente, commandes retirées (affichage de l'aide), et `blink world` (cas touché et contrôles, lecture figée, lecture disparue, abandons en combat, bouton enfoncé, souris sur une fenêtre, curseur hors du monde, restauration de la minimap). Aucune erreur Lua ne doit apparaître. Ne teste pas le rendu réel (UI, lignes carte/minimap) ni le comportement du vrai moteur.

## Prérequis
`pip install lupa` (Lua embarqué, version 5.5 ; WoW exécute du Lua 5.1), Python 3 et Node.js.
