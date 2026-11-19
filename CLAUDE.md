# CLAUDE.md — contexte du projet gather-route

## Objectif
Le joueur utilise TomTom (add-on WoW) sur le serveur « Forever » (le client signale la version 1.60.1, build 70959, toc 16001 d'après `/hr probe` ; contenu type vanilla, données Wowhead Forever. La mention « 12.1.x » vient du TOC de TomTom et d'un commentaire de son code, pas du client). Avant, il passait par un planner HTML hors-jeu : saisie manuelle région / X / Y / herbes, copie des `/way x, y`, collage via `/ttpaste`. Le but : tout faire en jeu, avec position et région détectées automatiquement, et une route optimisée pilotée par TomTom.

Réponse apportée : un add-on **séparé**, `HerbRoute/`, qui dépend de TomTom et n'utilise que son API publique documentée (README de TomTom, section « Supported Addon API »). Jamais `TomTom.private`.

## Entrées d'origine (non versionnées ici)
- `TomTom.zip` : TomTom v4.4.1-release (Interface 120105, 120007, 120100, 11509, 16001, 20506, 38002, 40402, 50504). Sert de référence d'API.
- `WoW_Forever_Herb_Planner.html` : le planner. Ligne 3 = les données (`REGIONS`) ; l'algorithme = `nearest` (plus proche voisin depuis la position), `improve` (inversion de segments type 2-opt, fenêtre bornée : 5 passes max, 2 si n>700, 1 si n>1800 ; fenêtre 60 si n>700 sinon min(n,220)), `pathLength`. Sortie : lignes `/way x, y`.
- `AddOns.rar` (GatherMate2 + GatherMate2_Data, dossier `Forever`) : source de `Data/HerbDataGatherMate.lua`, non versionnée.
- `wowhead_forever_herbes_regions_waypoints.json` : `regions -> région -> herbs -> herbe -> waypoints[{x,y}]`. 45 régions, 29 herbes, 13 256 points, coordonnées en pourcentage (0-100), doublons conservés volontairement. Noms de zones en anglais.

## Décisions de conception (validées avec l'utilisateur)
- Add-on séparé (pas de modification de TomTom), `## Dependencies: TomTom`, même ligne `## Interface:` que TomTom.
- Algorithme : port 1:1 du JS, sans changement de comportement (distance euclidienne en % sans correction d'aspect).
- Deux modes : **Suivi** (un waypoint à la fois, callback `distance[rayon]` qui retire le point atteint et active le suivant, pattern du README de TomTom ; `SetCustomWaypoint`, `crazy=true`) et **Tout afficher** (tous les points en pins, `persistent=false`).
- Région -> mapID : on réutilise `TomTom.NameToMapId` (correspondance normalisée, repli par préfixe pour les noms dupliqués `Nom:Parent`) ; surcharge manuelle `/hr setmap <région>: <mapID>` stockée dans `HerbRouteDB.overrides`. Aucun mapID en dur, car non vérifiable hors jeu (zones custom : Riverglades, Shen'dralas, Zephras Isle).
- Position de départ : celle du joueur si présent dans la région choisie, sinon centre de carte (50, 50) ; champs X/Y modifiables dans l'UI (drapeau `dirty`).
- Tracé sur la carte du monde et la minimap dessiné par l'add-on (`Overlay.lua`), car TomTom ne dessine que des pins. Projection minimap calquée sur HereBeDragons-Pins-2.0 (rayon de vue, rotation, disque à 0,9). Overlay carte désactivé en mode manette (`TomTom:IsGamepadUI()`), TomTom documentant un taint.
- Suppression de la route : bouton Stop, `/hr stop`. Retirer le point courant via TomTom = passer au suivant ; suppression groupée (plusieurs retraits dans la même frame) = arrêt. Limite connue : `/way reset all` avec la route comme seul waypoint est vu comme un retrait unique (donc « skip »).
- Hors périmètre v1 : routes multi-régions, localisation FR de l'UI (l'UI est en anglais), aperçu dans la fenêtre de l'add-on.

## Structure
```
HerbRoute/
  HerbRoute.toc      Dependencies: TomTom ; SavedVariables: HerbRouteDB
  Data/HerbData.lua  GÉNÉRÉ (tools/gen_data.py), ne pas éditer à la main ; jamais modifié (D8)
  Data/HerbDataGatherMate.lua  GÉNÉRÉ (tools/merge_gathermate.py) : points GatherMate ajoutés en fin de liste, base d'origine intacte (D17)
  Data/OreDataGatherMate.lua  GÉNÉRÉ (tools/merge_gathermate.py --category ores) : `HerbRoute_OreData[région][minerai]`, catégorie séparée (D18)
  Data/OreDataWowhead.lua  GÉNÉRÉ (tools/merge_wowhead_ores.py) : points de minerais Wowhead ajoutés en fin de liste, `OreDataGatherMate.lua` intact (D17/D18)
  Bindings.xml       raccourcis clavier (Skip, Stop, fenêtre), chargé automatiquement hors table des matières
  (Resolver.lua : `DataFor` fusionne les voisins à 1 % au chargement, D21, sans modifier les fichiers)
  Core.lua           init, SavedVariables, slash /herbroute et /hr
  Tracking.lua       isolement du pistage pendant une route (sauvegarde et rétablissement)
  Resolver.lua       région <-> mapID, position et région courantes
  RouteMath.lua      distance / nearest / improve / pathLength / solve
  Runner.lua         génération (coroutine + C_Timer) et pilotage TomTom
  Overlay.lua        tracé carte du monde + minimap
  MinimapUtil.lua    helpers partagés : lecture du survol de la minimap, curseur, déplacement de la minimap
  Probe.lua          /hr probe : diagnostic de la lecture de la minimap
  Verify.lua         vérification du prochain waypoint sur la minimap (/hr verify)
  UI.lua             fenêtre (région, herbes, départ, mode, rayon, boutons)
tools/               génération des données et tests (voir tools/README.md)
```
Ordre de chargement (toc) : Data (HerbData, HerbDataGatherMate, OreDataGatherMate puis OreDataWowhead), Core, Tracking, Resolver, MinimapUtil, RouteMath, Runner, Overlay, Probe, Verify, UI. Le namespace partagé est la table `HR` (2e valeur de `...`), exposée aussi en global `HerbRoute`.

## Vérification
Voir `tools/README.md`. Résumé : `tools/test_math.py` compare `RouteMath.lua` au JS du planner (4 cas, identiques) ; `tools/test_addon.py` exécute Core/Resolver/Runner/Overlay/UI sur un faux environnement WoW/TomTom (lupa).

## État et risques
- **Jamais lancé dans WoW** : aucun client disponible lors du développement. À tester en jeu : `/hr debug` (régions résolues ?), UI, avancement de la flèche, tracé minimap (rotation/zoom), `/console scriptErrors 1`.
- Hypothèse : client en anglais (les clés de région sont anglaises). Sinon `/hr setmap`.
- Noms de templates UI utilisés (`BasicFrameTemplateWithInset`, `UICheckButtonTemplate`, `UIPanelButtonTemplate`, `InputBoxTemplate`, `OptionsSliderTemplate`, `UIPanelScrollFrameTemplate`) supposés présents sur ce client.
- `WorldMapFrame:GetCanvas()` et `hooksecurefunc(WorldMapFrame, "OnMapChanged", ...)` supposés disponibles (le second est gardé).
- Le runtime WoW est Lua 5.1 ; les tests tournent sur Lua 5.5 via lupa. Éviter les constructions propres à 5.2+ (goto, opérateurs bit à bit, entiers 64 bits) et ne pas modifier la variable d'une boucle `for`.

## Évolutions
La vérification du prochain waypoint sur la minimap (F39) est **implémentée** (`Verify.lua`) et validée hors jeu ; le besoin et les décisions sont dans `docs/BESOINS.md`. Elle repose sur la détection par lignes d'infobulle validée en jeu par `/hr probe` (`blink world`) ; la projection d'un point de la base sur la minimap reste à vérifier en jeu. Le suivi courant est dans `docs/JOURNAL.md` (décisions, risques, prochaines actions) et `docs/FONCTIONNALITES.md` (état de chaque fonctionnalité) : les mettre à jour à chaque séance. Contrainte : la base `HerbRoute_Data` n'est jamais modifiée, seuls les waypoints TomTom du trajet en cours sont retirés.

## Règle de travail (demandée par le joueur)
Avant de répondre à une question sur le projet ou de modifier quoi que ce soit, **relire** `docs/BESOINS.md`, `docs/JOURNAL.md` et `docs/FONCTIONNALITES.md`, puis vérifier que la réponse ou le changement ne contredit ni une décision (D1 à D17, dont « base d'origine intacte, ajouts seulement »), ni une demande déjà formulée. En cas de contradiction, la signaler au joueur avant d'agir. À la fin d'un échange qui fait avancer le sujet, mettre à jour les trois fichiers (besoin, journal, statut des fonctionnalités), puis committer et pousser.

## Conventions
- Pas de commentaires sauf contrainte non évidente. Pas de dépendance Ace.
- Messages d'UI et de chat en anglais ; documentation en français.
- Ne jamais committer les entrées d'origine volumineuses (JSON 1 Mo, HTML 300 Ko) ; `HerbData.lua` en est la forme embarquée.
