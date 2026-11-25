# tools

Scripts hors-jeu. À lancer depuis la racine du dépôt. Les fichiers d'origine (JSON de waypoints, planner HTML) ne sont pas versionnés : passer leurs chemins en arguments.

## gen_data.py — régénérer les données
```bash
python3 -I tools/gen_data.py wowhead_forever_herbes_regions_waypoints.json HerbRoute/Data/HerbData.lua
```
Produit `HerbRoute_Data[région][herbe] = {{x,y}, ...}` (pourcentages). Affiche `regions 45 herbs 29 points 13256` : ces nombres doivent rester identiques à ceux du JSON.

## merge_gathermate.py et check_data.py — enrichir la base par ajout
```bash
python3 -I tools/merge_gathermate.py <dossier GatherMate2> <dossier GatherMate2_Data/Forever> --zone 1448=Felwood --report docs/DONNEES_GATHERMATE.md
python3 -I tools/check_data.py
```
Le premier lit `HerbData.lua` sans le modifier, rattache chaque zone GatherMate à une région par recouvrement (les zones sans recouvrement demandent `--zone ID=Région`), écarte les points à moins de `--tol` % (0,5 par défaut) d'un point existant de la même herbe, fusionne les doublons internes et écrit `HerbRoute/Data/HerbDataGatherMate.lua`. Le second vérifie que les points d'origine sont inchangés à leur indice et que les ajouts sont distincts.

Pour les minerais : `python3 -I tools/merge_gathermate.py <GatherMate2> <GatherMate2_Data/Forever> --category ores --zone-map docs/DONNEES_GATHERMATE.md --report docs/DONNEES_GATHERMATE_MINERAIS.md` écrit `HerbRoute/Data/OreDataGatherMate.lua` (`HerbRoute_OreData[région][minerai]`). Il n'y a pas de base d'origine à comparer : seules les positions à moins de `--tol` % d'un même minerai sont fusionnées ; le rattachement des zones aux régions vient du rapport des herbes (`--zone-map`).

## Minerais Wowhead : wowhead_export_ores.js et merge_wowhead_ores.py
`tools/wowhead_export_ores.js` se colle dans la console du navigateur, sur une page `wowhead.com/forever/...` (le site bloque les accès automatiques, la lecture se fait donc chez le joueur). Pour chaque gisement de sa liste (identifiants à vérifier d'après le titre affiché), il lit `g_mapperData` et télécharge `wowhead_ores_mapperdata.json`.
```bash
python3 -I tools/merge_wowhead_ores.py wowhead_ores_mapperdata.json --report docs/DONNEES_WOWHEAD_MINERAIS.md
```
L'outil rattache chaque `uiMapId` à une région par le tableau de `docs/DONNEES_GATHERMATE.md`, écarte les points à moins de `--tol` % d'un point existant du même minerai et de la même région (`OreDataGatherMate.lua` est seulement lu), et écrit `HerbRoute/Data/OreDataWowhead.lua` (ajout seul) ; une zone absente du tableau se nomme par `--zone 2482="Mount Hyjal"`. Déjà fait pour l'export du joueur ; sinon ajouter `Data\OreDataWowhead.lua` à la table des matières après `OreDataGatherMate.lua` et à la liste de chargement de `tools/test_addon.py`.

## test_math.py — fidélité de l'algorithme
```bash
python3 -I tools/test_math.py WoW_Forever_Herb_Planner.html wowhead_forever_herbes_regions_waypoints.json
```
Exécute le JS du planner (`ref_route.js`, via Node) et `HerbRoute/RouteMath.lua` (via lupa) sur les mêmes points, et compare nombre de points, longueur de route et premiers points. Doit finir par `ALL SAME`.

## test_addon.py — logique de l'add-on
```bash
python3 -I tools/test_addon.py
```
Charge tous les fichiers Lua dans un faux environnement WoW/TomTom : résolution des régions, génération, avancement, skip, suppression externe, fin de route, mode pins, entrées invalides, puis `/hr probe` sur un faux minimap : lecture de base du survol réel, valeurs secrètes, fonction absente, commandes retirées (affichage de l'aide), et `watch` (changements de signature), valeurs numériques journalisées, et `blink world` (cas touché et contrôles, lecture figée, lecture disparue, abandons en combat, bouton enfoncé, souris sur une fenêtre, curseur hors du monde, restauration de la minimap). Le pistage est testé sur une API simulée : isolement, restauration, échange entre pistages à sort, ancien format de `GetTrackingInfo`, combat, reprise au chargement, commandes. La vérification du prochain waypoint est testée sur un faux minimap dont le moteur renvoie des lignes d'infobulle seulement sous un nœud (modes `report` et `remove`, premier point confirmé, point retiré et route qui avance, base inchangée, dernier contrôle avant arrivée, garde-fous, moteur inconclusif, commandes). Aucune erreur Lua ne doit apparaître. Ne teste pas le rendu réel (UI, lignes carte/minimap) ni le comportement du vrai moteur.

## SkinRoute : données et tests
`tools/wowhead_export_skinning.js` se colle dans la console du navigateur sur une page `wowhead.com/forever/...` (confirmation avec durée estimée, arrêt sur refus ou page inattendue, validation avant le téléchargement de `wowhead_skinning_all_zones.json`). Ensuite, avec les dossiers classic-db (SQL) et pfQuest (`db/units.lua`, `enUS/zones.lua`) :
```bash
python3 -I tools/merge_skinning.py --cmangos <classic-db> --pfquest <pfQuest> --wowhead wowhead_skinning_all_zones.json --out SkinRoute/Data/SkinData.lua
python3 -I tools/test_merge_skinning.py
python3 -I tools/test_skinroute.py
```
Avec `--loot-out SkinRoute/Data/LootData.lua`, il écrit aussi le butin des bêtes (qualités 0 à 2, or moyen, listes partagées résolues), également non versionné. `merge_skinning.py` exclut les créatures rares, boss et marquées ; avec `--ranks 0,1` les élites sont gardées et marquées `e = 1` (SkinRoute les ignore sauf si la case « Include elite mobs » est cochée ; `--ranks 0` par défaut les écarte), écarte les objets de quête et les zones inutiles (`--skip-zone`, villes, champ de bataille, continents) et écrit `SkinRoute_Data` (objets, créatures, points par zone). Le fichier généré n'est **pas versionné** (licences classic-db et pfQuest). `test_skinroute.py` charge SkinRoute dans un faux environnement WoW/TomTom ; avec `SKINROUTE_DATA=SkinRoute/Data/SkinData.lua` il ajoute des essais sur les vraies données. Il finit par `SKINROUTE TESTS OK`.

## SkinRoute : butin des créatures de Forever (Wowhead)
`tools/wowhead_export_loot.js` se colle dans la console du navigateur sur une page `wowhead.com/forever/...`. Il lit l'onglet Drops (mesures `[drops observés, dépeçages]`) de 141 créatures : 72 ajouts de Forever absents de CMaNGOS, 29 créatures que Forever a rendues dépecables, 40 créatures de contrôle (butin CMaNGOS à comparer). Une passe d'environ 13 minutes, mêmes garde-fous que l'export du dépeçage (confirmation avec durée, arrêt manuel `window.__lootStop = true`, refus du site, réseau, titres ou onglets inattendus, état dans `localStorage`, reprise en relançant), fichier final `wowhead_loot_forever.json` seulement si la validation passe (`window.__lootDump()` pour un diagnostic). La liste est produite par :
```bash
python3 -I tools/gen_loot_targets.py --skin SkinRoute/Data/SkinData.lua --loot SkinRoute/Data/LootData.lua --cmangos <classic-db>.sql
node tools/test_loot_export.js
```
Le fichier obtenu s'importe avec `python3 -I tools/merge_skinning.py ... --loot-out SkinRoute/Data/LootData.lua --wowhead-loot wowhead_loot_forever.json` : pour ces créatures, les taux mesurés (au moins 30 observations par ligne) remplacent ceux de CMaNGOS. `test_loot_export.js` exécute le script dans Node avec un faux navigateur (pages simulées : fichier final, refus 405, annulation, pages sans onglet, titres inattendus, arrêt puis reprise). Il ne dit rien du vrai format des pages Wowhead : la première page lue affiche ses onglets dans la console.

## Prérequis
`pip install lupa` (Lua embarqué, version 5.5 ; WoW exécute du Lua 5.1), Python 3 et Node.js.
