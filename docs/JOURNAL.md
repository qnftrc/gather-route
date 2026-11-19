# Journal de pilotage

Registre chronologique des décisions, constats, risques et prochaines actions. À compléter à chaque séance. Le détail du besoin est dans [BESOINS.md](BESOINS.md), l'état des fonctionnalités dans [FONCTIONNALITES.md](FONCTIONNALITES.md).

## Prochaines actions
1. **Lancer `/hr verify calibrate`** : phase A, la souris **sur un point jaune d'herbe proche du centre de la minimap** (3 s) ; phase B, la souris dans le monde, hors de toute fenêtre, immobile (5 s). L'add-on essaie sept méthodes sur ce point et sur une position témoin et retient la première qui voit le point sans voir le témoin. Coller les lignes du chat (une par méthode). Si une méthode est retenue, relancer `/hr verify scan` puis laisser la vérification automatique tourner en mode `report`. Si aucune ne marche, la vérification automatique est impossible sur ce build (R25).
2. Tester en jeu l'add-on déjà livré : `/hr debug`, UI, flèche, tracés carte et minimap, avec `/console scriptErrors 1`.
3. Décider du sort de la mémoire de récolte (survit-elle d'un trajet à l'autre ?).

## Journal

### 2026-11-19 — Construction de l'add-on HerbRoute (v1.0.0)
- Entrées analysées : TomTom v4.4.1, planner HTML, JSON de waypoints (45 régions, 29 herbes, 13 256 points).
- Plan présenté et validé, avec deux ajouts demandés : aperçu du tracé sur la carte et la minimap, et moyen de supprimer la route à tout moment.
- Add-on séparé écrit : données, résolution des régions, algorithme, pilotage TomTom, tracés, interface.
- Vérifications hors jeu : algorithme Lua identique au planner sur 4 cas (dont 702 et 742 points) ; logique testée sur faux environnement WoW/TomTom.
- Aucun client WoW disponible : interface et tracés jamais exécutés en jeu.
- Dépôt `qnftrc/gather-route` (vide) rattaché en écriture ; add-on et scripts poussés sur `main`. Documentation de contexte ajoutée (`README.md`, `CLAUDE.md`, `tools/README.md`).

### 2026-11-19 — Cadrage : points actifs, minimap, retracé
- Capture de la minimap : le point jaune « Goldthorn / Up to Snuff » vient du pistage « Trouver les herbes ».
- Constat : les points du pistage sont dessinés par le moteur et ne sont pas lisibles directement par un add-on (témoignages sur GatherMate2).
- Recherche : NodeRadar (issue #2, PR #9) décrit une lecture indirecte via `Minimap:UpdateMouseoverAtPoint` et `C_TooltipInfo.GetMinimapMouseover`. Elle a exigé le curseur sur la minimap, puis fonctionné avec le curseur logiciel. Des mises à jour de Forever (builds 70862 puis 70938) auraient restreint cette lecture : récit d'un seul auteur, à valider.
- Limites réseau de la session : `www.curseforge.com` et `warcraft.wiki.gg` inaccessibles ; GitHub accessible.
- Add-on Lueur (capture des réglages) : introuvable en ligne, raison du plafond de 15 yd inconnue. Hypothèse non vérifiée : plafond du système d'interaction du client.
- Besoin simplifié formulé (B6) : garder la route d'origine, vérifier chaque point sur la minimap, retirer les waypoints sans correspondance.

### 2026-11-19 — `/hr probe` écrit (F20)
- Feu vert donné ; fenêtre à copier-coller incluse (le choix n'avait pas été tranché explicitement).
- Contenu : environnement, fonctions présentes, balayage dans deux conventions de coordonnées (écran/curseur et unités d'interface), avec et sans curseur logiciel, détection des valeurs secrètes, étalonnage de la zone qui répond, distance entre un point lu et le point de la base le plus proche (rotation désactivée), test du zoom et des points hors disque.
- Effets de bord limités : curseur logiciel remis à faux, zoom restauré, base jamais touchée.
- Vérifié hors jeu sur un faux minimap (lecture seulement avec curseur logiciel et convention écran, écart mesuré 0,4 yd, cas sans lecture, valeurs secrètes, fonction absente, zoom). Cela confirme aussi la cohérence de la projection inverse avec celle de `Overlay.lua`, sur le faux monde seulement.
- Pas implémenté : `/hr probe blink` (déplacement furtif de la minimap, F30), volontairement laissé à plus tard.

### 2026-11-19 — Premier rapport de `/hr probe` (build 70959)
- Client : version 1.60.1, build 70959, toc 16001, langue enUS. Minimap 198x198 unités, zoom 0, rayon de vue 233,3 yd, rotation désactivée. Curseur hors de la minimap.
- Pistages actifs : Find Herbs, Flight Master, Innkeeper, Account Completed Quests, Track Quest POIs. Aucune fonction manquante.
- Balayages (687 interrogations chacun, 0,6 ms sans curseur logiciel, 1,2 ms avec) : **0 réponse** en `cursor/hard`, `cursor/soft`, `ui/hard`, `ui/soft`. Aucune erreur renvoyée par les appels. Verdict de la sonde : aucune lecture.
- Interprétation prudente : les fonctions existent et s'exécutent, mais rien n'est lu dans ces conditions. Compatible avec une restriction de lecture introduite par les builds récents (70862 puis 70938, d'après NodeRadar), avec un besoin du vrai curseur sur la minimap, avec une latence d'une image entre `UpdateMouseoverAtPoint` et la lecture, ou avec une autre convention de coordonnées. À confirmer qu'un point jaune d'herbe était visible pendant l'essai.
- Limite de la sonde v1 : elle ne distingue pas « aucune donnée » de « données dans une autre forme » (le texte est lu seulement dans `lines[1].leftText`), et ne teste ni la lecture avec la souris réellement posée sur un point, ni le décalage d'une image.
- Correction de contexte : le client n'est pas annoncé en 12.1.x (voir `CLAUDE.md`).

### 2026-11-19 — Second rapport de `/hr probe` : souris sur un point jaune
- Conditions : souris posée sur un point jaune d'herbe (l'infobulle native affiche « Wild Steelbloom »). Zoom 1, rayon de vue 200 yd. Le drapeau `MouseIsOver(Minimap)` a renvoyé faux malgré le curseur sur la minimap : il n'est pas fiable (v2a le complète par un calcul géométrique).
- Résultat brut : les 4 balayages (687 interrogations) ont renvoyé **687 réponses sur 687**, toutes avec un texte **secret**. Le premier rapport (souris hors minimap) donnait 0 sur 687.
- Interprétation : 100 % de réponses quel que soit le point demandé signifie que la donnée lue ne dépend pas du point interrogé : c'est le survol **réel** de la souris. Le verdict « lecture réussie » de la sonde v1 était donc un faux positif, et les « 175 points trouvés », la « zone de réponse de 50 yd » et l'absence de correspondance avec la base n'ont pas de sens.
- Acquis : la présence d'un point sous le vrai curseur est lisible par l'add-on ; son nom est une valeur secrète. Non acquis : un sondage par position (`UpdateMouseoverAtPoint` ne semble pas déplacer le survol).
- Le joueur accepte les noms secrets : l'herbe attendue est celle du waypoint, la présence suffit (décision D10, avec ses limites).
- Correction de la sonde (v2a, livrée) : détection de l'écho du survol réel (verdict dédié), lecture de base sans appel de sondage, structure des données, présence comptée même sans texte, lecture une image plus tard, position du curseur par calcul géométrique. Test hors jeu complété (cas d'écho, valeurs secrètes).
- Correction du journal : la ligne R1 de la première séance n'avait pas été mise à jour par erreur de script ; c'est fait.

### 2026-11-19 — `/hr probe blink` écrit (F35, sonde v2b)
- Principe : avec le vrai curseur immobile sur un point jaune, la minimap est déplacée de 40 unités (4 directions compatibles avec un curseur qui reste dans le disque), la lecture est relevée 1 et 3 images plus tard, puis la minimap est remise en place et la lecture de retour relevée. Deux variantes par déplacement : simple, et avec `UpdateMouseoverAtPoint` à la position du curseur.
- Verdict : la lecture « suit » la minimap si elle disparaît à chaque déplacement et revient au retour ; « inchangée » si elle reste présente (le survol n'est pas rafraîchi sans mouvement réel de la souris) ; sinon non concluant (autre point sous le curseur, lecture instable).
- Garde-fous : abandon en combat, bouton de souris enfoncé, souris déplacée de plus de 3 pixels, curseur hors du disque, absence de donnée au départ ; ancrages et alpha de la minimap toujours restaurés ; délai de sécurité de 30 s.
- Option `blink hidden` : minimap rendue invisible (alpha 0) pendant les déplacements, pour limiter l'effet visuel ; à comparer avec la version visible.
- Vérifié hors jeu sur un moteur simulé (quatre comportements et six cas d'abandon). Le comportement réel du moteur est inconnu.
- Risques : effet visible sur la minimap pendant l'essai (quelques dixièmes de seconde), clic intercepté si un bouton est pressé (d'où la garde), conflit avec un autre add-on de minimap (position réancrée).

### 2026-11-19 — Résultat de `/hr probe blink` et recherche sur NodeRadar
- Rapport en jeu : contrôle présent, puis lecture **présente et inchangée** (1 image, 3 images, retour) pour les 4 déplacements, avec et sans `UpdateMouseoverAtPoint`. Verdict de la sonde : le survol n'est pas rafraîchi sans mouvement réel de la souris. Minimap restaurée.
- Ce test n'est pas équivalent à la méthode documentée par NodeRadar : il part d'un curseur **déjà sur la minimap** (même cadre survolé avant et après le déplacement). NodeRadar part d'un curseur **au repos dans le monde** et amène la minimap dessous, ce qui change le cadre survolé. Le test n'est donc pas concluant pour cette méthode (voir ci-dessous).
- Source : [docs/FOREVER-PROBE.md](https://github.com/Spotnick2/NodeRadar/blob/main/docs/FOREVER-PROBE.md) et [README](https://github.com/Spotnick2/NodeRadar) de NodeRadar. Constats rapportés par son auteur : build 70862, `UpdateMouseoverAtPoint` n'a plus d'effet (« Minimap is off limits », API à supprimer) ; build 70888, avec le vrai curseur sur un nœud la lecture renvoie le nœud sous le curseur et non le point demandé (**exactement notre écho**) ; build 70938, le texte devient secret mais « une lecture vide reste simple », donc on peut savoir **si** quelque chose est sous le point, pas quoi. NodeRadar arrête son balayage à partir de 70938 faute de noms.
- Conséquence : la vérification par **présence** (D10) est précisément le cas que NodeRadar n'exploite pas ; elle est plausible mais non démontrée sur le build 70959.
- Méthode de NodeRadar (README) : curseur au repos sur le monde, minimap déplacée sous le curseur quelques images, lecture, remise en place ; pas en combat, pas de bouton enfoncé, pas pendant un lancer de sort ni une fenêtre de butin, pas sur une créature ou un joueur, pas sur un bouton de la minimap, pas avec une infobulle, un menu ou une fenêtre ouverts ; un autre add-on ancré à la minimap arrête le balayage.
- Zone de réponse rapportée : environ 25 sur 25 unités autour du point (16 px à l'écran sur le build 70888). Elle est grande devant l'erreur de nos coordonnées : un sondage au centre pourrait suffire, la croix de 17 positions est à réévaluer après mesure.
- Idée notée, non retenue pour l'instant : identifier un point d'herbe par différence en coupant puis rétablissant le pistage (round 3 de NodeRadar), mais le rétablissement lance un sort de pistage avec temps de recharge sur la barre d'actions.
- Écrit : `/hr probe blink world` (F36), qui reproduit la méthode : phase A, la souris sur un point jaune (décalage mémorisé) ; phase B, la souris au repos dans le monde, la minimap est déplacée pour amener le point sous le curseur (cas « touché ») ou à côté (contrôles), lecture à 1, 3 et 6 images, remise en place. Verdict : sondage de présence faisable, ou non. Tests hors jeu sur moteur simulé (cinq comportements, cinq abandons).

### 2026-11-19 — Nettoyage des sondes devenues inutiles
- Demande du joueur : retirer les sondes qui ne servent plus.
- Retiré : balayages de la minimap (conventions de coordonnées, curseur logiciel, +1 image), étalonnage et écart à la base, `/hr probe zoom`, `/hr probe blink` (curseur déjà sur la minimap), `/hr probe world`. Raison : le sondage par position n'a pas d'effet (écho du survol réel), et ces sondes dépendaient d'une lecture positionnelle.
- Conservé : `/hr probe` et `/hr probe minimap` (environnement, fonctions, lecture du survol réel), `/hr probe blink world [hidden]`, `/hr probe copy`. Les anciens noms de sous-commandes affichent l'aide.
- `Probe.lua` passe d'environ 850 à environ 390 lignes ; les tests hors jeu sont réécrits pour le jeu de sondes réduit. Anciennes versions dans l'historique Git (avant nettoyage : `30c4969`).
- Les prochaines actions ne changent pas : lancer `/hr probe blink world` et `/hr probe minimap` sur sol vide.

### 2026-11-19 — Rapports `blink world` (13:05) et `probe minimap` (13:06)
- `blink world` (version du zip précédant le nettoyage) : phase A, point sous le curseur à (-12,7 ; -57,4) unités du centre. Phase B, curseur dans le monde : **contrôle** (minimap en place) absent à +1, +3 et +6 images ; **touché** (point amené sous le curseur) présent ; **trois contrôles** décalés de 40 unités **présents aussi** ; retour (minimap remise en place) absent partout. Verdict de la sonde : la lecture est présente où que la minimap se trouve sous le curseur, non liée au point.
- Ce qui est acquis : le moteur **rafraîchit** le survol quand la minimap passe sous un curseur immobile ou s'en va (présent sous le curseur, absent au retour) : le mécanisme de NodeRadar fonctionne sur le build 70959 pour la **présence**.
- Ce qui ne l'est pas : la présence est-elle liée à un point jaune ? Trois décalages de 40 unités tous présents. Deux explications : (a) la présence est générique dès que le curseur est sur la minimap ; (b) la zone de réponse d'un point est grande (environ 25 unités selon NodeRadar) et la minimap est dense en points (zoom 1, rayon 200 yd, pistage d'herbes, plus quêtes, maîtres de vol et aubergistes actifs), donc les trois positions tombaient chacune sur un autre point. Non départagé.
- `probe minimap` (13:06, **ancienne version** : les balayages y figuraient encore, le zip allégé n'était donc pas installé) : curseur dans le disque, `MouseIsOver(Minimap)` faux, lecture de base **présente**. Forme des données : `dataInstanceID:number, lines:table, type:number | lines[1]: leftColor:secret, leftText:secret, type:number`. Les balayages ont de nouveau donné 100 % de réponses (écho). On ne sait pas où était la souris (point jaune ou sol vide) : à préciser.
- Champs **lisibles** : `type`, `dataInstanceID` et `lines[1].type` sont des nombres ; seuls le texte et la couleur sont secrets. Leur valeur n'a pas été relevée : peuvent-ils distinguer les types de points ou identifier un objet ? À journaliser.
- Piste : cartographier la présence par `blink` sur une grille (pas voisin de la zone de réponse), en relevant aussi `type` et `dataInstanceID`, pour mesurer la fraction de positions « présentes » (générique ou liée aux points) et la résolution réelle. Pas encore écrit.
- Précaution de lecture : avec une zone d'environ 25 unités, la résolution dépend du zoom (environ 50 yd au zoom 1, environ 17 yd au zoom le plus fort, d'après le rayon de vue et la largeur de la minimap, estimation). La présence ne prouve donc qu'un point dans une zone, pas à l'emplacement exact du candidat ; elle ne permettrait de retirer que des candidats sans aucun point alentour.

### 2026-11-19 — Sol vide de la minimap : des données sont présentes
- Réponse du joueur : pendant `/hr probe minimap`, la souris était sur un **sol vide** de la minimap. La lecture de base était pourtant **présente**.
- Conclusion : la présence de données est très probablement **générique** (dès que le curseur est sur la minimap), pas liée à un point jaune. Elle ne permet donc pas, seule, de vérifier qu'un nœud existe. C'est cohérent avec `blink world` (4 positions sur 4 présentes) et avec le premier rapport (rien quand le curseur est hors de la minimap).
- Réserves : la zone de réponse d'un point est grande (environ 25 unités d'après NodeRadar) et la minimap est dense au zoom 1 ; un sol « vide » à l'œil peut encore être dans la zone d'un point. Plusieurs pistages actifs (maîtres de vol, aubergistes, quêtes) ajoutent des points. Non totalement exclu, mais la piste « présence seule » est **remise en cause** (D10 et F34).
- Ce qui peut encore la sauver : les champs numériques lisibles `type`, `dataInstanceID` et `lines[1].type` pourraient différer entre un point et le sol, ou entre types de points. Leur valeur n'avait pas été relevée.
- Écrit (sonde) : la lecture de base affiche maintenant les **valeurs** des champs numériques ; `blink world` ajoute la signature à chaque lecture ; nouvelle commande `/hr probe watch` (15 s, la souris déplacée à la main sur sol vide, points d'herbe, puis hors de la minimap) qui journalise chaque changement de `type`/`line1type` avec la position du curseur. Tests hors jeu sur moteur simulé.
- Tests à faire en jeu : (1) `/hr probe watch` avec seul « Trouver les herbes » actif ; (2) `/hr probe minimap` avec **tous les pistages désactivés** : si des données sont présentes, la présence est générique de façon certaine.
- Si `type` ne distingue rien : abandon de la vérification par la minimap, repli sur la mémoire de récolte (F32).

### 2026-11-19 — Tableau récapitulatif
- Demande du joueur : un tableau des choix de conception et des tests à faire par fonctionnalité. Écrit dans [RECAPITULATIF.md](RECAPITULATIF.md) à partir de ce journal, du suivi des fonctionnalités et du besoin (aucune décision nouvelle).
- Rappel qui en ressort : aucune fonctionnalité de l'add-on de route n'a été testée en jeu (`/hr debug`, route, tracés, interface) ; seules les sondes l'ont été. Un ordre de test est proposé en fin de document.

### 2026-11-19 — Isolement du pistage pendant une route (F21, besoin B8)
- Demande du joueur : à chaque nouvelle route, désactiver tous les pistages actifs sauf « Trouver les herbes », puis rétablir la configuration d'origine à l'arrêt de la route.
- Conception : nouveau module `Tracking.lua`. Au lancement, la liste des pistages actifs est sauvegardée (`HerbRouteDB.trackingSnapshot`, par identifiant de sort quand il existe, sinon par nom), les autres sont coupés, « Trouver les herbes » est activé seulement s'il ne l'est pas déjà (il n'est jamais touché sinon, pour éviter de relancer le sort). Restauration : coupure d'abord de ce qui ne faisait pas partie de la configuration d'origine, puis activation de ce qui en faisait partie.
- Restauration déclenchée par : bouton Stop, `/hr stop`, fin de route, réinitialisation groupée, démarrage d'une nouvelle route **sans** restauration intermédiaire (la configuration sauvegardée reste celle d'origine), et au chargement du jeu (2 s après l'entrée dans le monde) si un instantané existe encore, ce qui couvre un `/reload` ou un plantage en cours de route.
- Combat : si le lancement ou l'arrêt tombe en combat, l'action est mise en attente et exécutée à la sortie de combat (`PLAYER_REGEN_ENABLED`).
- Réglage `isolateTracking` (activé par défaut), commande `/hr tracking [on|off|status|restore]` et case dans la fenêtre ; le désactiver rétablit immédiatement la configuration, l'activer pendant une route l'isole immédiatement. Le nom « Trouver les herbes » est lu par l'identifiant de sort 2383 (nom localisé), avec repli sur le nom anglais : réduit R6 pour cette fonction.
- Si « Trouver les herbes » n'est pas disponible (pas de herboristerie) : message, aucun pistage modifié.
- Testé hors jeu sur une API de pistage simulée (dont le format ancien de `GetTrackingInfo`, l'échange entre pistages à sort, le combat, la reprise au chargement, les commandes).
- Risques : activer ou rétablir un pistage à sort peut lancer un temps de recharge sur la barre d'actions (observé par NodeRadar) ; un seul pistage à sort est actif à la fois, donc rétablir « Trouver les minerais » remplace « Trouver les herbes » ; un pistage modifié à la main pendant la route sera écrasé à la restauration. Signature de `SetTracking` non confirmée sur ce client.

### 2026-11-19 — Rapport `watch` (13:43) : la présence se lit dans les lignes d'infobulle
- Rapport : seul « Trouver les herbes » actif, zoom 0, rayon 233,3 yd, 76 échantillons, 10 changements. Toujours `type=21` ; `dataInstanceID` croît de 111965 à 113393 (compteur, pas une identité) ; `line1type` alterne entre `0` et `?` ; `none` au milieu de la minimap à t=9,6 s et hors de la minimap.
- Constat : `line1type=0` apparaît à trois positions voisines, (-19,-35), (-23,-42) et (-9,-38), c'est-à-dire dans un carré d'une vingtaine d'unités, ce qui correspond à la zone de réponse d'environ 25 unités d'un seul point jaune ; `?` partout ailleurs (-36,15), (-3,-48), (1,-37), (1,33), (-35,-43).
- Hypothèse (forte, à confirmer) : `?` = données **sans ligne** (survol vide, la minimap renvoie une table même sur un sol vide), `0` = **au moins une ligne** (un point sous le curseur). C'est exactement ce que dit NodeRadar : « une lecture vide reste simple (nil ou aucune ligne), on sait donc s'il y a quelque chose sous le point ».
- Correction de ma définition : jusqu'ici la sonde appelait « présent » toute donnée non nulle, ce qui est vrai partout dans la minimap : c'est ce qui donnait 4 sur 4 dans `blink world` et « données sur sol vide » (le sol annoncé vide l'était peut-être seulement à l'œil, ou la forme `lines[1]` vue alors indique un point dans la zone). La présence utile est **au moins une ligne**.
- Conséquence : la vérification par présence (D10) est **rétablie avec cette définition** ; R13 devient « résolu en principe ». Le verdict du premier `blink world` n'est pas exploitable (il comptait n'importe quelle donnée) : à refaire.
- Écrit : `lineCount`, présence = au moins une ligne dans toute la sonde ; `watch` journalise `lines=N` et distingue « none » (aucune donnée) de « empty » (données sans ligne) ; la lecture de base annonce « data with N line(s) » ou « data without lines » ; `blink world` utilise la nouvelle présence. Fonction `baseline` devenue inutile retirée. Tests hors jeu adaptés (le moteur simulé renvoie maintenant des données vides sur un sol vide, comme le vrai).

### 2026-11-19 — Rapports `watch` (13:51) et `blink world` (13:52) : **la détection positionnelle fonctionne**
- `watch` : `lines=1 line1type=0` à (-37,-51) ; « empty » (`lines=0`, `line1type=?`) à (-39,13) et (-14,-64) ; « none » hors de la minimap. Les lignes n'existent donc que sur un point, et la donnée vide est bien distincte.
- `blink world` : phase A, point sous le curseur à (-36,7 ; -58,0), le même point que dans `watch` (écart de 7 unités). Phase B, curseur au repos dans le monde : **contrôle** minimap en place, aucune donnée ; **touché** (point amené sous le curseur) : `lines=1` dès **+1 image**, maintenu à +3 et +6 ; **deux contrôles à 40 unités** : `lines=0` à +1, +3 et +6 ; retour de la minimap : aucune donnée. Minimap et transparence restaurées. Verdict de la sonde : détection d'un point possible, vérification positionnelle faisable.
- Acquis (build 70959) : on peut savoir **si un point d'herbe se trouve à un endroit donné** de la minimap, en déplaçant la minimap sous un curseur au repos dans le monde et en lisant s'il y a au moins une ligne d'infobulle, sans lire le nom (secret). Latence : 1 image.
- Conséquences sur la conception : le sondage par `UpdateMouseoverAtPoint` (D5 : croix de 17 positions) est caduc ; **un seul sondage par candidat** suffit (zone de réponse d'une vingtaine d'unités, large devant l'erreur de nos coordonnées) ; chaque sondage coûte environ 4 images (déplacement, lecture à +1, retour, repos) ; la précision dépend du zoom ; F37 (cartographie par grille) devient inutile.
- Contraintes d'usage rapportées par NodeRadar : le curseur doit **rester immobile dans le monde**, sans bouton enfoncé, hors combat, hors lancer de sort, hors fenêtre de butin, pas sur une créature, un joueur, un bouton de minimap, ni avec une infobulle ou un menu ouvert ; un autre add-on ancré à la minimap perturbe le balayage. Pendant le jeu normal (souris tenue pour la caméra) les passes seraient donc souvent en attente : la vérification serait **opportuniste**, pas continue.
- Proposition : `/hr verify`, d'abord en **un coup** déclenché à la main (route active, souris au repos) : sonder en blink tous les candidats de la route dans le disque, rapport « avec ligne / sans ligne » en simulation, puis retrait optionnel des waypoints sans ligne (`TomTom:RemoveWaypoint`, base intacte). L'automatisation (déclenchement à l'entrée dans le disque, D6) viendrait ensuite. Non écrit, en attente de feu vert.

### 2026-11-19 — Rapports `blink world` cachée (13:55) et visible (13:56) ; le déplacement gêne
- **Variante `hidden` (alpha 0)** sur un point en (37,9 ; 33,9) : contrôle sans donnée, **touché** `lines=1` dès +1 image maintenu à +3 et +6, **deux contrôles** à 40 unités `lines=0`. Verdict : détection faisable. **La lecture ne dépend donc pas de la visibilité de la minimap.**
- **Variante visible** sur un autre point en (55,2 ; 49,9) : même résultat (touché `lines=1` à +1 image, contrôles `lines=0`). Le résultat est reproductible sur deux points différents, deux jours de position différente de la souris.
- Retour du joueur : **le déplacement de la minimap est gênant**. Non précisé : la version cachée l'est-elle autant ? (question posée).
- Cause probable : la minimap est en haut à droite et la souris au repos loin à gauche, donc les décalages sont énormes (-812, -91) et (-802, -296) unités : la minimap traverse l'écran pendant l'essai. L'essai garde aussi la minimap déplacée pendant environ 6 images et fait un retour de 3 images, alors qu'une lecture à +1 image suffit.
- Pistes pour réduire la gêne : (a) lecture à +1 image seulement puis retour immédiat (environ 2 images par sondage au lieu de 13) ; (b) minimap cachée pendant les sondages ; (c) **vérification ciblée** : ne sonder que le prochain waypoint (1 à 2 sondages par point) au lieu de tous les candidats du disque ; (d) déclenchement **manuel** (`/hr verify`) ; (e) souris au repos près de la minimap (décalages courts) ; (f) test `blink chain` : si la lecture se rafraîchit en passant directement d'une position à l'autre sans quitter la minimap, un seul va-et-vient suffit pour toute une passe (non testé : le test `blink` d'origine comptait n'importe quelle donnée, donc invalide).

### 2026-11-19 — Choix du joueur et vérification ciblée du prochain waypoint écrite (F39)
- Réponses du joueur : usage **ciblé sur le prochain waypoint** (automatique, mode Suivi) ; la variante cachée n'est **pas** moins gênante, donc on réduit la durée et le nombre de déplacements plutôt que de cacher la minimap.
- Implémentation : nouveau `Verify.lua` ; helpers partagés extraits dans `MinimapUtil.lua` (lecture du survol, curseur, déplacement de la minimap) et réutilisés par `Probe.lua`.
- **Un sondage = 2 déplacements de la minimap** (placer, relire à +1 image, remettre) puis 2 images de repos, soit environ 4 images au total dont une seule avec la minimap déplacée, contre une quinzaine pour la sonde de test. Les sondes ne tournent que si toutes les conditions sont réunies.
- Déclenchement : le point courant de la route (le prochain waypoint) est sondé quand il entre dans 85 % du rayon de vue de la minimap. Résultat : « ligne » = confirmé ; « vide » (la minimap est sous le curseur mais sans ligne) ; « aucun » = inconclusif (retry, abandon après 4). Un point est déclaré **absent après 2 sondages vides d'affilée** espacés de 1,5 s ; un point confirmé est **recontrôlé une fois à moins de 35 yd** (nœud pris entre-temps).
- Modes (`/hr verify off|report|remove|status`, case dans la fenêtre) : **`report` par défaut** (message dans le chat, point conservé), `remove` retire le point : waypoint TomTom retiré, passage au point suivant, base intacte (D8). Garde-fou : **aucun retrait tant qu'aucun point n'a été confirmé dans la session** (sinon une projection fausse viderait toute la route).
- Garde-fous de sondage : pistage « Trouver les herbes » actif, pas de combat, pas mort ni en vol, aucun bouton de souris, pas de lancer de sort, minimap visible, curseur **hors de la minimap** et sur le monde (pas sur l'interface), aucune unité sous le curseur, aucune infobulle ni fenêtre de butin, curseur immobile depuis 0,5 s, même position de curseur avant et après le sondage. La raison d'attente est consultable (`/hr verify`).
- Autres changements : `Runner.lua` (`DropPoint`, `removed`, avancement qui saute les points retirés), `Overlay.lua` (tracés qui ignorent les points retirés ; exporte la projection), `Tracking.lua` (`HerbTrackingActive`), commande `/hr verify`, compteur « removed » dans la fenêtre.
- Tests hors jeu sur un moteur de minimap simulé : report et remove, premier point confirmé, point vide retiré avec passage au suivant (waypoint TomTom suivant affiché, base de points inchangée), aucun retrait sans point confirmé, node pris après confirmation, 8 garde-fous, moteur inconclusif, off et commandes. Un artefact de test (pins qui fuyaient entre deux séries) corrigé.
- **Non testé en jeu** : la projection sur la minimap de la base de points, la fiabilité de la détection sur des points de la base (erreur de coordonnées), l'effet visuel réel d'un déplacement d'une image, la fréquence réelle des passes avec une souris souvent en mouvement.

### 2026-11-19 — Premier essai en jeu de la vérification : 4 sondes inconclusives
- Capture du joueur : mode `remove`, route Stranglethorn Vale (126 points), pistage isolé (« 4 other(s) switched off »). `/hr verify` : **4 sondes, 0 confirmée, 0 vide, 0 retirée**, raison « probing », affiché deux fois. Le joueur signale que le point sans blip n'est pas retiré.
- Analyse : le compteur « vide » n'augmente qu'à la décision d'absence (2 sondes vides) ; 4 sondes sans aucun résultat « ligne » ni « vide » signifie que **les 4 ont été inconclusives** (aucune donnée, souris bougée, minimap non déplacée…). Le code **abandonnait le point en silence** après 4 sondes inconclusives (bug d'ergonomie) : le point restait donc gardé, comme prévu pour un résultat inconclusif, mais sans explication.
- Hypothèses sur la cause : (a) la lecture du survol n'est pas rafraîchie après une utilisation de la souris pour la caméra (README de NodeRadar : « après avoir dirigé avec la souris, le balayage attend que la souris bouge à nouveau »), alors que notre détection de repos ne regardait que la position du curseur ; (b) la minimap ne suit pas le déplacement (autre add-on ou client) ; (c) autre écart avec `blink world`, qui avait fonctionné après un vrai mouvement de souris. Aucune n'est confirmée : le rapport ne donne pas la cause.
- Corrections : (1) plus d'abandon : réessais espacés (jusqu'à 10 s) et message au 3e échec avec la cause ; (2) **garde « bouger la souris une fois »** après tout appui sur un bouton (le sondage attend un vrai mouvement) ; (3) contrôle que la minimap a **réellement bougé** à la lecture ; (4) seconde lecture à +2 images si la première ne renvoie aucune donnée ; (5) `/hr verify` affiche le nombre de sondes inconclusives et leurs causes ; (6) nouvelle commande **`/hr verify probe`** : une sonde détaillée sur le point courant après 3 s (curseur, centre de la minimap, décalage, lectures à +1 et +2 images avec signature, retour à la position d'origine). État de repos réinitialisé à chaque route.
- Tests hors jeu ajoutés : abandon supprimé, causes enregistrées, minimap figée (cause « did not move »), reprise après mouvement de souris, `/hr verify probe`.

### 2026-11-19 — Rapports `/hr verify` et `/hr verify probe` : minimap déplacée, curseur dessus, mais aucune donnée
- `/hr verify` : « point 1/126 is inconclusive (no hover data…) », 4 sondes, 0 confirmée, 0 vide, 4 inconclusives, cause unique « no hover data ».
- `/hr verify probe` (point 1/126) : décalage projeté (-5 ; 23) unités, dans le disque ; curseur (861 ; 385) px ; centre de la minimap (1579,1 ; 909,5) ; décalage appliqué (-380,0 ; -397,8). À +1 et +2 images : **`moved=true`** (la minimap a bien suivi), **`cursor on minimap=true`** (le curseur est dans le disque), `lines=false`, **`data=false`** (aucune donnée du tout) ; résultat inconclusif ; la minimap est bien revenue (`back home: true`).
- Ce que cela écarte : un décalage qui n'a pas eu lieu, un curseur hors du disque, un retour manquant. La **projection (R21) reste non vérifiée** : aucune lecture n'a été obtenue, donc on ne sait pas si le point tombe sur un point jaune.
- Ce que cela montre : dans la même géométrie, `blink world` avait obtenu des données à +1 image (ligne ou lecture vide) ; ici le moteur ne renvoie **rien**. La différence est dans l'état du survol du moteur. Hypothèse principale : le survol de la minimap n'est recalculé qu'à un **vrai mouvement de souris** (les essais de `blink world` suivaient un déplacement manuel du curseur dans le monde, une souris parfaitement immobile ne produit pas d'événement). Non démontré.
- Écrit : `/hr verify probe` teste maintenant quatre variantes dans l'ordre jusqu'à obtenir des données : simple ; avec `UpdateMouseoverAtPoint` appelé au curseur réel ; curseur logiciel + `UpdateMouseoverAtPoint` ; attente jusqu'à 6 images. Il demande de bouger la souris pendant le décompte et indique si le mouvement a été vu. Lectures détaillées par image (déplacement, curseur sur la minimap, lignes, données, signature).
- Si une variante marche, la vérification automatique l'adoptera ; sinon la vérification ne pourra tourner qu'après un mouvement de souris (garde déjà en place pour les boutons) ou devra rester manuelle.

### 2026-11-19 — Rapports `/hr verify probe` (variantes) et `blink world` : le curseur logiciel débloque la lecture
- `/hr verify probe`, souris bougée pendant le décompte (« yes »), point 1/126 (Goldthorn, 51 yd, décalage projeté (16 ; 25) unités, dans le disque) : **simple** : aucune donnée à +1 et +2 images ; **`UpdateMouseoverAtPoint` seul** : aucune donnée ; **curseur logiciel + `UpdateMouseoverAtPoint`** : **données présentes dès +1 image** (`type=21`, `lines=0`, donc « empty »). La minimap a suivi et est revenue dans tous les cas.
- Conclusion : le **curseur logiciel** (`Minimap:SetUsingSoftCursor(true)`) avec `UpdateMouseoverAtPoint` au curseur réel est ce qui fait renvoyer des données au moteur sur le build 70959, même après un mouvement de souris ; c'est cohérent avec les notes de NodeRadar (« le curseur logiciel fait que le point compte »). Le mouvement de souris n'était donc pas la cause. La vérification automatique adopte cette variante (décision D13).
- Résultat du sondage du point 1/126 : **vide**. Deux explications possibles : aucun nœud de Goldthorn à cet endroit, ou une projection erronée (R21). Non tranché par un seul point.
- `blink world` (14:34, version sans curseur logiciel, qui fonctionne comme avant) : point sous le curseur à (38,6 ; 60,6) ; touché `lines=1` ; contrôle à +40 en x **`lines=1` aussi** (un autre point jaune voisin) ; contrôle à -40 en y `lines=0`. L'ancien verdict « non lié au point » était **faux** : un contrôle vide prouve que la lecture dépend de la position. Verdict corrigé : détection positionnelle confirmée, avec mention des contrôles qui ont aussi des lignes (points voisins).
- Écart non expliqué : `blink world` sans curseur logiciel obtient des données, alors que la sonde automatique simple n'en obtenait pas. Différences connues : `blink world` commence par une étape témoin et lit trois fois. À ne pas élucider si la variante adoptée suffit.
- Écrit : variante curseur logiciel + `UpdateMouseoverAtPoint` adoptée pour la vérification automatique (curseur logiciel remis à faux après chaque sonde) ; `/hr verify probe` l'essaie en premier ; nouveau **`/hr verify scan`** : balayage de toute la minimap (pas de 16 unités), carte ASCII des points jaunes et des points projetés dans la fenêtre à copier, comparaison de la projection avec ses symétries.
- Limite du scan : avec des herbes denses (40 candidats dans le disque), presque n'importe quelle position tombe près d'un point jaune ; seule une symétrie nettement meilleure est signalée. La carte ASCII est le vrai juge.
- Tests hors jeu : adoption de la variante (un moteur qui exige curseur logiciel + mise à jour), verdict avec point voisin, balayage et carte.

### 2026-11-19 — Rapport `/hr verify scan` : 92 cases, aucun point jaune ; la variante « curseur logiciel » était une fausse piste
- Rapport : 92 cases sondées avec la variante curseur logiciel + `UpdateMouseoverAtPoint`, **0 avec ligne, 92 vides, 0 inconclusives** ; « no blip found ». La carte ASCII montre le disque entièrement vide (`.`) et quelques points projetés (`o`). Le joueur est dans une zone où la minimap affiche des points jaunes (même secteur que les essais précédents).
- Conclusion : cette variante fait renvoyer des **données** (lecture vide) quelle que soit la position, mais elle ne lit **pas** la position sous le curseur : même un vrai point jaune donne « vide ». Le résultat « vide » du point 1/126 dans le rapport précédent ne prouvait donc rien. **La décision D13 (adopter le curseur logiciel) est révoquée.**
- Leçon de méthode : une méthode de sondage ne se valide que sur un **point connu** (`blink world` : point sous la souris, puis amené sous le curseur au repos), pas sur le seul fait d'obtenir des données.
- Écart toujours inexpliqué : `blink world` (sans curseur logiciel) détecte un point connu, alors que la sonde automatique simple n'obtenait aucune donnée. Différences : `blink world` commence par une étape témoin (placement sans décalage, pause) et rappelle `SetAlpha` à chaque retour, et lit à +1, +3 et +6 images. Pistes à tester : échauffement, `SetAlpha`.
- Écrit : **`/hr verify calibrate`** (D14). Phase A : le joueur pointe un point jaune, le décalage est mémorisé. Phase B : souris dans le monde ; pour sept méthodes (simple, échauffement, `SetAlpha`, échauffement + `SetAlpha`, mise à jour, curseur logiciel + mise à jour, échauffement + `SetAlpha` + attente de 6 images), l'add-on sonde le point connu et une position témoin à 40 unités. La première méthode qui renvoie une ligne sur le point et pas sur le témoin est **mémorisée avec le numéro de build** (`HerbRouteDB.recipe`). Si seul le point voisin répond, on retient la première qui voit le point.
- **La vérification automatique, `/hr verify probe` et `/hr verify scan` exigent cette calibration** : sans méthode mémorisée, ou si le build du client a changé, la raison d'attente est « run /hr verify calibrate once ». `/hr verify` affiche la méthode retenue.
- Si aucune méthode ne détecte le point : « Calibration failed », la vérification reste désactivée (R25) et la mémoire de récolte redevient le repli.
- Tests hors jeu : calibration sur quatre moteurs simulés (méthode simple, `SetAlpha` requis, curseur logiciel requis, aucune méthode), échec propre, absence de point en phase A, refus de sonder sans calibration ou avec un autre build, usage de la méthode mémorisée.

## Décisions
| Réf. | Décision | Date | Statut |
|---|---|---|---|
| D1 | Add-on séparé, dépendant de TomTom, API publique uniquement | 2026-11-19 | Appliquée |
| D2 | Algorithme repris à l'identique du planner HTML | 2026-11-19 | Appliquée |
| D3 | Deux modes : Suivi (un waypoint à la fois) et Tout afficher | 2026-11-19 | Appliquée |
| D4 | Tracés carte et minimap dessinés par l'add-on | 2026-11-19 | Appliquée (non testée en jeu) |
| D5 | ~~Sondage de la minimap aux seuls emplacements connus, avec croix de 17 positions~~ → **un seul sondage par candidat, par déplacement de la minimap sous le curseur** (`UpdateMouseoverAtPoint` sans effet) | 2026-11-19 | **Révisée** après `blink world` |
| D6 | Vérification déclenchée à l'entrée du **prochain waypoint** dans le disque de la minimap (85 % du rayon), 2 sondages vides d'affilée pour déclarer l'absence, un dernier contrôle à moins de 35 yd | 2026-11-19 | **Appliquée** (F39, non testée en jeu) |
| D7 | La route d'origine est conservée ; on retire des points au lieu de la recalculer | 2026-11-19 | Cadrée |
| D8 | **Base intacte** : `HerbRoute_Data` n'est jamais modifiée ; seuls les waypoints TomTom du trajet en cours sont retirés | 2026-11-19 | Contrainte |
| D9 | Pas de recalage de la base à partir des écarts mesurés | 2026-11-19 | Contrainte |
| D10 | Vérification par **présence** d'un point : le nom (secret) n'est pas nécessaire, l'herbe attendue étant celle du waypoint. **Présence = au moins une ligne d'infobulle** (une donnée vide n'est pas une présence). Limite : un autre type de nœud au même endroit compterait comme présent | 2026-11-19 | **Rétablie et redéfinie** après le rapport `watch` ; à confirmer par `blink world` (R13) |
| D11 | Pendant une route, seul « Trouver les herbes » reste actif ; la configuration d'origine est sauvegardée et rétablie à l'arrêt, au chargement ou après combat. Option désactivable | 2026-11-19 | Appliquée (non testée en jeu) |
| D12 | Vérification **ciblée** sur le prochain waypoint (choix du joueur), automatique en mode Suivi, **`report` par défaut**, retrait seulement en mode `remove` et seulement après au moins un point confirmé dans la session ; la minimap n'est pas cachée (la variante cachée n'est pas moins gênante) | 2026-11-19 | Appliquée (non testée en jeu) |
| D13 | ~~Adopter la variante curseur logiciel + `UpdateMouseoverAtPoint`~~ | 2026-11-19 | **Révoquée** : elle renvoie des données sans lire la position (scan : 92 cases vides) |
| D14 | La méthode de sondage est **calibrée en jeu** sur un point jaune connu (`/hr verify calibrate`), mémorisée avec le numéro de build ; sans calibration valide la vérification ne sonde pas | 2026-11-19 | Appliquée (non testée en jeu) |

## Risques et questions ouvertes
| Réf. | Sujet | État |
|---|---|---|
| R1 | La lecture de la minimap fonctionne-t-elle sur le client du joueur ? | Partiel : on lit la présence d'un point sous le **vrai** curseur, le nom est secret ; le sondage par position n'est pas démontré (R12) |
| R2 | Faux négatifs : un nœud existant non détecté serait retiré à tort | Atténué par K échecs, garde-fous, restauration |
| R3 | Taille de la zone qui réagit autour d'un point jaune, donc pas de la croix | À mesurer en jeu |
| R4 | Erreur réelle de nos coordonnées par rapport aux nœuds | À mesurer en jeu |
| R5 | Durées de réapparition des herbes sur Forever | Inconnu |
| R6 | Langue du client : noms de régions et d'infobulles en anglais supposés | Hypothèse |
| R7 | Noms de modèles d'interface et API de carte supposés présents sur ce client | Non vérifié |
| R8 | Délai d'apparition d'un point jaune après son entrée dans le disque (estimé 1,5 s) | À mesurer |
| R9 | Coût d'une passe de 17 interrogations par candidat | À mesurer |
| R10 | Tracé minimap (rotation, zoom) jamais vu en jeu | Non testé |
| R11 | Noms d'infobulle secrets : pas de contrôle du type d'herbe, faux positifs possibles entre nœuds voisins | Accepté (D10) |
| R12 | Sondage par position | **Résolu** : le déplacement de la minimap sous un curseur au repos dans le monde fonctionne (`blink world`, `lines=1` à +1 image, contrôles à `lines=0`) |
| R13 | La présence est-elle liée à un point jaune ? | **Résolu en principe** : la donnée existe partout dans la minimap, mais seules les positions sur un point ont des lignes (`watch`) ; à confirmer en jeu avec les positions des points |
| R14 | Le build 70959 (postérieur à 70938, dernier build documenté par NodeRadar) peut restreindre davantage | Ouvert |
| R15 | Activer ou rétablir un pistage à sort peut lancer un temps de recharge sur la barre d'actions (NodeRadar) | À observer en jeu |
| R16 | Signatures de `C_Minimap.GetTrackingInfo` et `SetTracking` supposées (formats table et ancien) | À confirmer par le test en jeu de F21 |
| R17 | Le curseur doit rester immobile dans le monde (pas de bouton, pas de combat, pas sur une créature ni une fenêtre) : la vérification ne peut tourner que par moments | Contrainte d'usage, à mesurer en jeu |
| R18 | Effet visible du déplacement de la minimap | **Confirmé gênant par le joueur** ; la variante cachée donne la même lecture (non jugée) ; à réduire (lecture à +1 image, vérification ciblée, déclenchement manuel) |
| R19 | Résolution dépendante du zoom : zone d'environ 20 unités, soit de l'ordre de 50 yd au zoom 0 et 17 yd au zoom le plus fort (estimation) | À mesurer à plusieurs zooms |
| R20 | Un autre add-on ancré à la minimap (ou son habillage) peut perturber le déplacement | À observer en jeu |
| R21 | La projection d'un point de la base sur la minimap (formule du tracé minimap) n'a jamais été vérifiée en jeu : si elle est fausse, tous les sondages tombent à côté | Garde-fou : aucun retrait avant un premier point confirmé ; à valider en jeu |
| R22 | Faux négatif : un nœud existant non détecté (erreur de nos coordonnées, zone de réponse) provoquerait un retrait à tort | Atténué par 2 sondages, mode `report` par défaut, base intacte ; à mesurer en jeu |
| R23 | Les passes exigent une souris immobile dans le monde, et un vrai mouvement après avoir dirigé à la souris : avec la souris tenue pour la caméra, elles seront souvent en attente | Garde « bouger la souris une fois » ajoutée ; raison visible par `/hr verify` ; à mesurer |
| R24 | La vérification n'obtenait aucune donnée de survol, puis une variante renvoyait des lectures sans valeur | **Rouvert** : seule `blink world` a détecté un point connu ; la méthode est maintenant choisie par calibration sur un point connu |
| R25 | Aucune des sept méthodes ne détecte un point connu en jeu : la vérification serait impossible sur ce build | Ouvert, test = `/hr verify calibrate` |

## Commits
| Commit | Contenu |
|---|---|
| `0dac733` | Add-on HerbRoute et scripts de données et de test |
| `5da3722` | README, CLAUDE.md, tools/README |
| `c6f1824` | Document d'expression de besoin |
| `934f3ef` | Besoin B6 : vérification et suppression de points |
| `4ec07a8` | Déclenchement à l'entrée dans le disque |
| `0d8991c` | Contrainte « base intacte » |
| `999f8c8` | Journal de pilotage et suivi des fonctionnalités |
| `d3f85b0` | Règle de travail : consulter et mettre à jour les documents |
| `9519f0b` | `/hr probe` (sonde v1) |
| `62ba128` | Premier rapport de la sonde, correction du contexte client |
| `2d56bce` | Sonde v2a : écho du survol réel, présence sans texte |
| `bd2b558` | `/hr probe blink` |
| `30c4969` | `/hr probe blink world`, résultat de `blink`, constats NodeRadar |
