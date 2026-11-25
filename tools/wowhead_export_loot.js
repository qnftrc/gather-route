// À coller dans la console du navigateur, sur une page https://www.wowhead.com/forever/... (même site que les pages lues).
// Lit le butin normal (onglet Drops, mesures [drops observés, dépeçages]) d'une liste fixe de créatures : les ajouts de Forever absents de
// CMaNGOS, celles que Forever a rendues dépecables, et un échantillon de contrôle. Liste produite par tools/gen_loot_targets.py.
// Une seule passe de MAX_MINUTES minutes au plus, état gardé dans localStorage (clé lootExportV1) : relancer le script pour continuer.
// Garde-fous : confirmation avec estimation, arrêt manuel (window.__lootStop = true), refus du site, réseau, format inattendu, durée, nombre de pages.
// Le fichier wowhead_loot_forever.json n'est téléchargé que si tout est lu et validé ; window.__lootDump() télécharge l'état courant.
(async () => {
  const g = typeof window !== "undefined" ? window : globalThis;
  const T = g.__lootTest || {};
  const MAX_MINUTES = 20;
  const MAX_PAGES = 200;
  const PAUSE = T.pause || [4000, 5500];
  const TIMEOUT = 25000;
  const KEY = "lootExportV1";
  const FORCE_DOWNLOAD = false;
  const REFUSED = [403, 405, 429];
  // [id, nom, groupe] : forever = absente de CMaNGOS, modified = rendue dépecable par Forever, sample = contrôle
  const TARGETS = /*TARGETS*/[
    [244525, "Hyjal Bear", "forever"],
    [244530, "Tainted Hyjal Bear", "forever"],
    [248041, "Hyjal Stag", "forever"],
    [248042, "Tainted Hyjal Stag", "forever"],
    [249224, "Child of Tortolla", "forever"],
    [249230, "Defiling Hound", "forever"],
    [249474, "Rustleaf Fox", "forever"],
    [249490, "Wildbreath Chimaerok", "forever"],
    [249491, "Mountain Squallclimber", "forever"],
    [249493, "Nightsaber Guardian", "forever"],
    [249974, "Battlescarred Steelbeak", "forever"],
    [250868, "Vuldren", "forever"],
    [250873, "Juvenile Vuldren", "forever"],
    [250874, "Vuldren Alpha", "forever"],
    [250926, "Scrawny Ursera", "forever"],
    [250927, "Shadowgale Ursera", "forever"],
    [250928, "Highlands Ursera", "forever"],
    [250937, "Ursera Scavenger", "forever"],
    [251245, "Prideclaw", "forever"],
    [251261, "Hippogryph Matriarch", "forever"],
    [251284, "Hippogryph Protector", "forever"],
    [251291, "Hippogryph Youth", "forever"],
    [251661, "Galestrider", "forever"],
    [251707, "Ornery Galestrider", "forever"],
    [253282, "Shriekling Fledgling", "forever"],
    [253283, "Shriekling Matriarch", "forever"],
    [255174, "Blind Screecher", "forever"],
    [255851, "Mature Paletusk", "forever"],
    [255901, "Sand Crawler", "forever"],
    [256092, "Shadowgale Shriekling", "forever"],
    [256807, "Shore Crawler", "forever"],
    [256809, "Predatory Hyjal Stag", "forever"],
    [257017, "Twilight Worg", "forever"],
    [258331, "Young Paletusk", "forever"],
    [258522, "Sootfur", "forever"],
    [259046, "Freshwater Crocolisk", "forever"],
    [259054, "Wildplains Patriarch", "forever"],
    [259055, "Wildplains Huntress", "forever"],
    [259263, "Coyote Prowler", "forever"],
    [259267, "Plains Coyote", "forever"],
    [259269, "High Plains Buzzard", "forever"],
    [260157, "Elder Snow Leopard", "forever"],
    [260235, "Trapclaw", "forever"],
    [260244, "Monstrous Threshadon", "forever"],
    [260809, "Highland Tortoise", "forever"],
    [262037, "Roosting Duskbat", "forever"],
    [262473, "Cinderscale Whelp", "forever"],
    [262477, "Cinderscale Warrior", "forever"],
    [263307, "Glade Viper", "forever"],
    [263343, "Low Plains Buzzard", "forever"],
    [263348, "Roving Tallstrider", "forever"],
    [263681, "Bear", "forever"],
    [266862, "Juvenile Paletusk", "forever"],
    [268530, "Bloodtalon Matriarch", "forever"],
    [268558, "Chakuyak", "forever"],
    [268831, "Plains Prowler", "forever"],
    [269057, "Mirrorscale", "forever"],
    [269075, "Snow Leopard Prowler", "forever"],
    [269254, "Famished Blackworg", "forever"],
    [270310, "Farholde Steed", "forever"],
    [270693, "Daggerfang", "forever"],
    [271334, "Maddened Rotclaw", "forever"],
    [271486, "Wendigo Shaman", "forever"],
    [271530, "Elder Wendigo", "forever"],
    [271587, "Frosthowl", "forever"],
    [271707, "Juvenile Cloudrunner", "forever"],
    [271710, "Cloudrunner Matriarch", "forever"],
    [271712, "Cloudrunner", "forever"],
    [277645, "Gray Fox", "forever"],
    [277730, "Rabid Forest Wolf", "forever"],
    [277881, "Bloodwing Bat", "forever"],
    [277882, "Foothills Duskbat", "forever"],
    [69, "Timber Wolf", "modified"],
    [299, "Young Wolf", "modified"],
    [704, "Ragged Timber Wolf", "modified"],
    [705, "Ragged Young Wolf", "modified"],
    [1508, "Young Scavenger", "modified"],
    [1509, "Ragged Scavenger", "modified"],
    [1511, "Enraged Silverback Gorilla", "modified"],
    [1514, "Mokk the Savage", "modified"],
    [1516, "Konda", "modified"],
    [2031, "Young Nightsaber", "modified"],
    [3102, "Felstalker", "modified"],
    [3257, "Ishamuhale", "modified"],
    [3619, "Ghost Saber", "modified"],
    [4342, "Drywallow Vicejaw", "modified"],
    [4355, "Bloodfen Scytheclaw", "modified"],
    [4396, "Mudrock Tortoise", "modified"],
    [4398, "Mudrock Burrower", "modified"],
    [4399, "Mudrock Borer", "modified"],
    [4400, "Mudrock Snapjaw", "modified"],
    [4504, "Frostmaw", "modified"],
    [4660, "Maraudine Bonepaw", "modified"],
    [4724, "Sandstrider", "modified"],
    [4725, "Crazed Sandstrider", "modified"],
    [6071, "Legion Hound", "modified"],
    [7803, "Scorpid Duneburrower", "modified"],
    [7848, "Lurking Feral Scar", "modified"],
    [9683, "Lar'korwi Mate", "modified"],
    [9684, "Lar'korwi", "modified"],
    [12940, "Vorsha the Lasher", "modified"],
    [113, "Stonetusk Boar", "sample"],
    [454, "Young Goretusk", "sample"],
    [685, "Stranglethorn Raptor", "sample"],
    [742, "Green Wyrmkin", "sample"],
    [834, "Coyote", "sample"],
    [1016, "Highland Lashtail", "sample"],
    [1069, "Crimson Whelp", "sample"],
    [1133, "Starving Winter Wolf", "sample"],
    [1191, "Mangy Mountain Boar", "sample"],
    [1513, "Mangy Duskbat", "sample"],
    [1693, "Loch Crocolisk", "sample"],
    [1816, "Diseased Grizzly", "sample"],
    [2042, "Nightsaber", "sample"],
    [2185, "Darkshore Thresher", "sample"],
    [2351, "Gray Bear", "sample"],
    [2522, "Jaguero Stalker", "sample"],
    [2728, "Feral Crag Coyote", "sample"],
    [2926, "Silvermane Stalker", "sample"],
    [2973, "Kodo Bull", "sample"],
    [3124, "Scorpid Worker", "sample"],
    [3235, "Greater Barrens Kodo", "sample"],
    [3246, "Fleeting Plainstrider", "sample"],
    [3424, "Thunderhawk Cloudscraper", "sample"],
    [3774, "Felslayer", "sample"],
    [3824, "Ghostpaw Howler", "sample"],
    [4019, "Great Courser", "sample"],
    [4124, "Needles Cougar", "sample"],
    [4150, "Saltstone Gazer", "sample"],
    [4334, "Firemane Flamecaller", "sample"],
    [4548, "Steelsnap", "sample"],
    [4700, "Aged Kodo", "sample"],
    [5278, "Sprite Darter", "sample"],
    [5304, "Frayfeather Stagwing", "sample"],
    [5426, "Blisterpaw Hyena", "sample"],
    [6167, "Chimaera Matriarch", "sample"],
    [6380, "Thunderhead Consort", "sample"],
    [7048, "Scalding Broodling", "sample"],
    [7443, "Shardtooth Mauler", "sample"],
    [8597, "Plaguehound", "sample"],
    [8957, "Angerclaw Grizzly", "sample"]
  ]/*END*/;
  g.__lootStop = false;
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const pause = () => sleep(PAUSE[0] + Math.random() * (PAUSE[1] - PAUSE[0]));

  let state = {v: 1, mode: null, npcs: {}};
  try {
    const s = JSON.parse(localStorage.getItem(KEY) || "null");
    if (s && s.v === 1) state = s;
  } catch (e) {}
  let saveFailed = false;
  const save = () => {
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { saveFailed = true; console.warn("Sauvegarde locale impossible : " + e); }
  };

  const download = (name, obj) => {
    const blob = new Blob([JSON.stringify(obj)], {type: "application/json"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = name;
    a.click();
  };
  g.__lootDump = () => download("wowhead_loot_partial.json", state);

  const slug = name => String(name || "").toLowerCase().replace(/['’]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  const t0 = Date.now();
  let sent = 0, refusals = 0, lastRefusal = 0, netFails = 0, badTitle = 0, noListview = 0, probed = false;
  const dead = () => refusals >= 2 || (refusals >= 1 && !state.mode);

  async function once(path) {
    sent++;
    const ctl = typeof AbortController === "function" ? new AbortController() : null;
    const timer = ctl ? setTimeout(() => ctl.abort(), TIMEOUT) : null;
    try {
      const res = await fetch(path, {credentials: "same-origin", signal: ctl ? ctl.signal : undefined});
      return {status: res.status, html: REFUSED.indexOf(res.status) >= 0 ? "" : await res.text()};
    } catch (e) {
      return {status: 0, html: ""};
    } finally {
      if (timer) clearTimeout(timer);
    }
  }

  async function page(id, name) {
    const s = slug(name);
    const urls = {slug: s ? `/forever/npc=${id}/${s}` : null, plain: `/forever/npc=${id}`};
    const order = state.mode ? [state.mode] : ["slug", "plain"];
    let last = {status: 0, html: ""};
    for (let i = 0; i < order.length; i++) {
      if (!urls[order[i]]) continue;
      last = await once(urls[order[i]]);
      if (last.status === 200) {
        if (!state.mode) { state.mode = order[i]; save(); }
        refusals = 0;
        return {status: 200, html: last.html, refused: false};
      }
      if (REFUSED.indexOf(last.status) < 0) { refusals = 0; return {status: last.status, html: last.html, refused: false}; }
      if (i < order.length - 1) await pause();
    }
    refusals++;
    lastRefusal = last.status;
    return {status: last.status, html: "", refused: true};
  }

  function closing(html, start) {
    const open = html[start], close = open === "{" ? "}" : "]";
    let depth = 0, inStr = false, quote = "", esc = false;
    for (let i = start; i < html.length; i++) {
      const c = html[i];
      if (inStr) {
        if (esc) esc = false;
        else if (c === "\\") esc = true;
        else if (c === quote) inStr = false;
        continue;
      }
      if (c === '"' || c === "'") { inStr = true; quote = c; }
      else if (c === open) depth++;
      else if (c === close && --depth === 0) return i;
    }
    return -1;
  }

  function literal(text) {
    try { return new Function("return (" + text + ")")(); } catch (e) { return null; }
  }

  function listviews(html) {
    const found = [];
    let from = 0;
    for (;;) {
      const at = html.indexOf("new Listview(", from);
      if (at < 0) break;
      from = at + 13;
      const start = html.indexOf("{", at);
      if (start < 0) break;
      const end = closing(html, start);
      if (end < 0) break;
      const body = html.slice(start, end + 1);
      const id = (body.match(/\bid:\s*['"]([^'"]+)['"]/) || [, ""])[1];
      const template = (body.match(/\btemplate:\s*['"]([^'"]+)['"]/) || [, ""])[1];
      const d = body.search(/\bdata:\s*\[/);
      let rows = null;
      if (d >= 0) {
        const arr = body.indexOf("[", d);
        const arrEnd = closing(body, arr);
        if (arrEnd > 0) rows = literal(body.slice(arr, arrEnd + 1));
      }
      found.push({id, template, rows: Array.isArray(rows) ? rows : []});
      from = end;
    }
    return found;
  }

  const title = html => (html.match(/<title>([^<]*)<\/title>/) || [, "?"])[1];
  const slimDrop = r => ({id: r.id, name: r.name, quality: r.quality === undefined ? null : r.quality, count: r.count === undefined ? null : r.count,
    outof: r.outof === undefined ? null : r.outof, stack: Array.isArray(r.stack) ? r.stack : null, pctstack: r.pctstack === undefined ? null : r.pctstack});
  const pending = () => TARGETS.filter(t => !state.npcs[t[0]]);
  const etaMin = pages => Math.round(pages * 5.3 / 60);

  function validate() {
    const errors = [], warnings = [];
    let failed = 0, withDrops = 0, rows = 0, noCounts = 0;
    for (const t of TARGETS) {
      const n = state.npcs[t[0]];
      if (!n) { errors.push(`créature non lue : ${t[0]} ${t[1]}`); continue; }
      if (n.http !== 200) { failed++; continue; }
      if (n.drops.length) { withDrops++; rows += n.drops.length; }
      for (const d of n.drops) if (typeof d.count !== "number" || typeof d.outof !== "number") noCounts++;
    }
    if (!TARGETS.length) errors.push("aucune créature cible");
    if (failed > TARGETS.length * 0.1) errors.push(`${failed} page(s) en échec sur ${TARGETS.length} (plus de 10 %)`);
    else if (failed) warnings.push(`${failed} page(s) en échec`);
    if (rows === 0) errors.push("aucun objet dans les onglets Drops");
    if (noCounts > rows * 0.2) errors.push(`${noCounts} ligne(s) sans mesure sur ${rows} : format modifié ?`);
    else if (noCounts) warnings.push(`${noCounts} ligne(s) sans mesure (count/outof)`);
    return {errors, warnings, rows, withDrops, failed};
  }

  if (!pending().length && TARGETS.length) {
    console.log("Tout est déjà lu : validation seule.");
  } else {
    const pages = pending().length;
    const ask = `Il reste ${pages} page(s) à lire, soit ${etaMin(pages)} min environ. Cette passe s'arrête après ${MAX_MINUTES} min ou ${MAX_PAGES} pages. Pour l'arrêter : window.__lootStop = true dans la console. Continuer ?`;
    if (typeof confirm === "function" && !confirm(ask)) { console.log("Annulé, aucune requête envoyée."); return; }
  }

  let stopReason = "";
  const guard = () => g.__lootStop ? "arrêt manuel"
    : (Date.now() - t0 > MAX_MINUTES * 60000 ? `durée maximale de ${MAX_MINUTES} min atteinte`
    : (sent >= MAX_PAGES ? `${MAX_PAGES} pages atteintes` : (saveFailed ? "stockage local impossible" : "")));

  async function outcome(res) {
    if (res.refused) {
      if (dead()) stopReason = `accès refusé (HTTP ${lastRefusal})`;
      return "retry";
    }
    if (res.status === 0) {
      if (++netFails >= 3) stopReason = "erreurs réseau répétées";
      return "retry";
    }
    netFails = 0;
    return "ok";
  }

  let done = 0;
  const todo = pending();
  for (const [id, name, group] of todo) {
    stopReason = stopReason || guard();
    if (stopReason) break;
    const res = await page(id, name);
    if ((await outcome(res)) === "retry") { if (stopReason) break; await pause(); continue; }
    let drops = [], ids = [];
    const t = title(res.html);
    if (res.status === 200) {
      const lvs = listviews(res.html);
      ids = lvs.map(l => l.id + ":" + l.template);
      for (const l of lvs) {
        if (l.template !== "item" || !/^drops?$/i.test(l.id)) continue;
        for (const r of l.rows) if (r && r.id) drops.push(slimDrop(r));
      }
      const ok = t.toLowerCase().indexOf(String(name).toLowerCase()) >= 0;
      badTitle = ok ? 0 : badTitle + 1;
      noListview = lvs.length ? 0 : noListview + 1;
      if (!probed) { probed = true; console.log(`Première page (${name}) : onglets ${ids.join(", ") || "aucun"} ; ${drops.length} objet(s) dans Drops.`); }
    }
    state.npcs[id] = {group, name, title: t, http: res.status, listviews: ids, drops};
    save();
    done++;
    if (badTitle >= 3) stopReason = "titres de créatures inattendus (3 de suite) : identifiants ou site différents ?";
    else if (noListview >= 5) stopReason = "aucun onglet trouvé sur 5 pages de suite : format de page modifié ?";
    if (done % 10 === 0) console.log(`${done} / ${todo.length} lues, environ ${etaMin(todo.length - done)} min restantes`);
    if (stopReason) break;
    await pause();
  }

  const left = pending().length;
  if (stopReason) console.warn(`Arrêt : ${stopReason}.`);
  if (left > 0) {
    console.log(`Reste ${left} page(s) (environ ${etaMin(left)} min). ${stopReason && /refus|réseau/.test(stopReason) ? "Attendre avant de relancer." : "Relancer le script pour continuer."}`);
    return;
  }

  const v = validate();
  const perGroup = {};
  for (const n of Object.values(state.npcs)) {
    const p = perGroup[n.group] = perGroup[n.group] || {group: n.group, creatures: 0, withDrops: 0, rows: 0};
    p.creatures++;
    if (n.drops.length) { p.withDrops++; p.rows += n.drops.length; }
  }
  console.table(Object.values(perGroup));
  console.log(`Validation : ${v.rows} ligne(s) de butin, ${v.withDrops} créature(s) avec butin, ${v.failed} page(s) en échec.`);
  v.warnings.slice(0, 15).forEach(w => console.warn("Avertissement : " + w));
  v.errors.slice(0, 15).forEach(e => console.error("Erreur : " + e));
  if (v.errors.length && !FORCE_DOWNLOAD) {
    console.error(`${v.errors.length} erreur(s) : pas de fichier final. window.__lootDump() télécharge l'état pour diagnostic.`);
    return;
  }
  const out = {
    source: "Wowhead Forever creature drops", version: 1, exportedAt: Date.now(), mode: state.mode, npcs: state.npcs,
    stats: {creatures: TARGETS.length, withDrops: v.withDrops, rows: v.rows, failed: v.failed}, warnings: v.warnings
  };
  if (T.capture) { T.capture(out); return; }
  download("wowhead_loot_forever.json", out);
  console.log("Fichier final téléchargé : wowhead_loot_forever.json");
})();
