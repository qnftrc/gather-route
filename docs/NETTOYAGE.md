# Nettoyage du code : résultats de la première relecture et plan

Mis de côté à la demande du joueur (2026-11-24) pour y revenir plus tard. Rien de ce qui suit n'est corrigé. Source : deux relectures indépendantes lancées avec les consignes de `.claude/agents/addon-reviewer.md` (lecture seule), sur le code à l'état du commit `65cfbb0`. Les quatre suites de `tools/test_addon.py` passaient.

Légende : **vérifié** = reproduit ou lu dans le code par Claude après la relecture ; **rapporté** = trouvé par un relecteur, non revérifié ; **à vérifier en jeu** = invérifiable hors jeu.

## Groupe 1 : bugs (un test chacun)
| # | Défaut | Où | Statut |
|---|---|---|---|
| 1 | **Régression du client français (`906a648`)** : `/hr ores copper` ne trouve plus rien. Le repli par sous-chaîne est sauté parce que la liste d'alias vide compte comme « vraie ». Contournement : taper le nom complet (`copper vein`). Correction probable : ne retenir l'alias que s'il est non vide. Aucun test ne couvrait un nom de minerai partiel | `Core.lua`, `findHerbs` | vérifié |
| 2 | Un recalcul de route est perdu quand la route change pendant le calcul et que `/hr reroute` est coupé (réglage par défaut) : `ScheduleReroute` ne fait rien. Touche F61 (recalcul à l'arrivée), D42 (retour d'un point) et `/hr reroute now` | `Runner.lua` (`Reroute`, `ScheduleReroute`) | vérifié |
| 3 | Collision entre `/hr probe blink world`, `/hr probe zone` et la vérification automatique : `probing` est local à `Verify.lua`, la minimap peut rester décalée jusqu'à un `/reload` | `Verify.lua`, `Probe.lua` | lu dans le code, non reproduit |
| 4 | Passer d'une route d'herbes à une route de minerais sans arrêt garde le pistage « Find Herbs » ; la vérification ne sonde alors rien | `Runner.lua` (`StartRoute`), `Tracking.lua` (`IsolateTracking`) | rapporté, reproduit par le relecteur |
| 5 | Stop pendant le calcul n'annule rien : `genToken` n'est pas invalidé par `StopRoute`, la route démarre quand même | `Runner.lua` | rapporté, reproduit (gravité faible) |

## Groupe 2 : robustesse
| # | Défaut | Où | Statut |
|---|---|---|---|
| 6 | La boucle `tick` de vérification s'arrête à la première erreur (pas de `pcall`, relance en dernière instruction) | `Verify.lua` (`StartVerify`) | vérifié |
| 7 | `removeUID` sans `pcall` : une erreur de `TomTom:RemoveWaypoint` laisse `HR.removing` vrai et les retraits externes sont ignorés | `Runner.lua` | rapporté |
| 8 | Fenêtre de stats : masquer puis réafficher en moins d'une seconde crée une boucle de mise à jour de plus | `Stats.lua` | rapporté |
| 9 | `probing` peut rester vrai si `Minimap:GetCenter()` renvoie rien ; gardes manquantes sur `C_TooltipInfo` et sur les lignes d'infobulle secrètes | `Verify.lua`, `Probe.lua`, `MinimapUtil.lua` | rapporté, à vérifier en jeu |

## Groupe 3 : petits nettoyages
- Argument mort : `HR:ReviveSkipped(c.ref, true)` (la fonction n'a qu'un paramètre) ; `HR.lastCause` écrit et jamais lu (**vérifiés**).
- Code mort : `HR.IsolateHerbTracking`, `HR.HerbTrackingActive`, `HR:IsRouteActive`, `showDots` toujours vrai, booléen `MULTIPLE` de `selfPatterns` jamais lu, `MM.signature` exporté sans usage, paramètre `name` de `VerifyOption`.
- Doublons : `viewRadius()` de `Probe.lua` refait `HR.ViewRadius` ; lecture du cadre sous la souris en double dans `MinimapUtil.lua` ; `isSecret` écrite trois fois.
- Faute de frappe : `266 + 2/6` devrait être `266 + 2/3` (`Overlay.lua`, repli sans `GetViewRadius`).
- Tests sans effet : `assert(next(rr.removed) == nil or true)` ; tests des croix rouges qui ne dessinent rien dans le harnais ; test « reroute off » qui ne compare que des longueurs ; `/hr ores` seul est silencieux et n'est pas testé.
- Variable `n` masquée dans `Stats.lua` (`for n, known`).

## Groupe 4 : documents
- Journal, besoins et fonctionnalités s'arrêtent au 2026-11-20 : client français (`906a648`), sélection par objet (`26a6c6d`, `f3d977c`), agent de relecture (`65cfbb0`) et cette relecture manquent.
- F41 et R6 disent encore « hors périmètre / client anglais » (`FONCTIONNALITES.md`, `RECAPITULATIF.md`, `JOURNAL.md`).
- `CLAUDE.md` ne cite pas `Locale.lua` dans la structure et l'ordre de chargement, et dit encore la localisation hors périmètre.

## Groupe 5 : gros chantiers (décision à part)
- Renommer `herb`, `herbs`, `r.herbSet`, `p.herb` en `item(s)` (ils désignent aussi des minerais).
- Découper `Verify.lua` (1 252 lignes) : calibration, balayage et mesure d'armement dans un fichier à part ; découper `build()` de `UI.lua` (184 lignes) et `tools/test_addon.py` (2 014 lignes, un seul script partagé).
- Élaguer les commentaires descriptifs (règle du projet : pas de commentaires sauf contrainte non évidente), surtout `Verify.lua` (88 lignes).
- Un contrôle de variables globales dans les tests (fichiers exécutés sous un environnement strict).

## À vérifier en jeu (non tranché par les relectures)
- `TomTom.HideWaypoint` et `ShowWaypoint` figurent-ils dans la section « Supported Addon API » du README de TomTom ? (`Verify.lua`, appels protégés par `pcall`).
- Le chemin d'image `Interface\AddOns\TomTom\Images\Modern\Waypoints\WaypointDotYellow` est interne à TomTom (`Overlay.lua`).
- Un segment du tracé dont les deux extrémités sont hors du disque de la minimap n'est pas dessiné, même s'il le traverse (`Overlay.lua`).

## Ordre proposé
Groupes 1 à 3 d'abord, un commit par groupe, tests à l'appui, puis groupe 4 sur demande, groupe 5 en décision séparée. L'agent `addon-reviewer` (redémarrer la session pour qu'il soit chargé) refera une relecture après les corrections.
