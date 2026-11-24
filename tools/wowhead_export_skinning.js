// À coller dans la console du navigateur, sur une page https://www.wowhead.com/forever/... (même site que les pages lues).
// Exporte toutes les zones : cuirs, créatures dépecables normales (rares, élites, boss et créatures à étiquette exclus), points d'apparition.
// Passes de MAX_MINUTES minutes au plus, état gardé dans localStorage (clé skinExportV3) : relancer le script pour continuer.
// Garde-fous : confirmation avec estimation, arrêt manuel (window.__skinStop = true), refus du site, réseau, format inattendu, durée, nombre de pages.
// Le fichier wowhead_skinning_all_zones.json n'est téléchargé que si tout est lu et validé ; window.__skinDump() télécharge l'état courant pour un diagnostic.
(async () => {
  const MAX_MINUTES = 20;
  const MAX_PAGES = 300;
  const PAUSE = [4000, 5500];
  const TIMEOUT = 25000;
  const KEY = "skinExportV3";
  const FORCE_DOWNLOAD = false;
  const CORE = {
    "Ruined Leather Scraps": 2934, "Light Hide": 783, "Light Leather": 2318, "Medium Hide": 4232,
    "Medium Leather": 2319, "Heavy Hide": 4235, "Heavy Leather": 4234, "Thick Hide": 8169,
    "Thick Leather": 4304, "Rugged Hide": 8171, "Rugged Leather": 8170, "Scorpid Scale": 8154,
    "Devilsaur Leather": 15417, "Chimera Leather": 15423
  };
  const EXTRA = {
    "Raptor Hide": 4461, "Turtle Scale": 8167, "Green Dragonscale": 15412, "Red Dragonscale": 15414,
    "Blue Dragonscale": 15415, "Black Dragonscale": 15416
  };
  const REFUSED = [403, 405, 429];
  const g = typeof window !== "undefined" ? window : globalThis;
  g.__skinStop = false;
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const pause = () => sleep(PAUSE[0] + Math.random() * (PAUSE[1] - PAUSE[0]));

  let state = {v: 3, mode: null, items: {}, creatures: {}, npcs: {}, excluded: {}};
  try {
    const s = JSON.parse(localStorage.getItem(KEY) || "null");
    if (s && s.v === 3) state = s;
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
  g.__skinDump = () => download("wowhead_skinning_partial.json", state);

  const slug = name => String(name || "").toLowerCase().replace(/['’]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  const t0 = Date.now();
  let sent = 0, refusals = 0, lastRefusal = 0, netFails = 0, emptyNpc = 0, emptyItem = 0, badTitle = 0;
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

  async function page(kind, id, name) {
    const s = slug(name);
    const urls = {slug: s ? `/forever/${kind}=${id}/${s}` : null, plain: `/forever/${kind}=${id}`};
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

  function mapperData(html) {
    const at = html.indexOf("g_mapperData");
    if (at < 0) return null;
    const start = html.indexOf("{", html.indexOf("=", at));
    if (start < 0) return null;
    const end = closing(html, start);
    return end > 0 ? literal(html.slice(start, end + 1)) : null;
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
  const excludeReason = r => r.classification ? "classification " + r.classification : (r.boss ? "boss" : (r.tag ? "tag" : ""));
  const slim = r => ({name: r.name, minlevel: r.minlevel, maxlevel: r.maxlevel, location: Array.isArray(r.location) ? r.location : [],
    family: r.family === undefined ? null : r.family, type: r.type, classicEra: !!r.classicEra});
  const countPoints = data => data ? Object.values(data).reduce((a, z) => a + z.reduce((b, e) => b + ((e && e.coords) ? e.coords.length : 0), 0), 0) : 0;

  const itemList = Object.entries(CORE).map(([n, id]) => [n, id, true]).concat(Object.entries(EXTRA).map(([n, id]) => [n, id, false]));
  const pendingItems = () => itemList.filter(it => !state.items[it[0]]);
  const pendingNpcs = () => Object.keys(state.creatures).filter(id => !state.npcs[id]);
  const etaMin = pages => Math.round(pages * 5.3 / 60);

  function validate() {
    const errors = [], warnings = [];
    for (const [name, id, core] of itemList) {
      const it = state.items[name];
      if (!it) { errors.push(`objet non lu : ${name}`); continue; }
      if (!it.valid) { (core ? errors : warnings).push(`objet au titre inattendu (${name}, id ${id}) : ${it.title}`); continue; }
      if (!it.rows) (core ? errors : warnings).push(`aucune créature pour ${name}`);
      else if (!Object.keys(it.drops).length) warnings.push(`${name} : toutes les créatures sont exclues (rares, élites, boss)`);
    }
    const ids = Object.keys(state.creatures);
    let noData = 0, points = 0, badCoords = 0, badInfo = 0;
    for (const id of ids) {
      const c = state.creatures[id], n = state.npcs[id];
      if (!c || typeof c.name !== "string" || typeof c.minlevel !== "number" || typeof c.maxlevel !== "number") badInfo++;
      if (!n) { errors.push(`créature non lue : ${id} ${c ? c.name : ""}`); continue; }
      const p = countPoints(n.data);
      if (n.http !== 200 || p === 0) { noData++; continue; }
      points += p;
      for (const z of Object.values(n.data)) for (const e of z) for (const xy of e.coords) {
        if (!Array.isArray(xy) || xy.length < 2 || !(xy[0] >= 0 && xy[0] <= 100 && xy[1] >= 0 && xy[1] <= 100)) badCoords++;
      }
    }
    if (!ids.length) errors.push("aucune créature");
    if (points === 0) errors.push("aucun point d'apparition");
    if (badInfo) errors.push(`${badInfo} créature(s) sans nom ou sans niveau numérique`);
    if (badCoords > points * 0.01) errors.push(`${badCoords} coordonnée(s) hors de 0-100`);
    else if (badCoords) warnings.push(`${badCoords} coordonnée(s) hors de 0-100`);
    if (noData > ids.length * 0.1) errors.push(`${noData} créature(s) sans point sur ${ids.length} (plus de 10 %)`);
    else if (noData) warnings.push(`${noData} créature(s) sans point d'apparition`);
    return {errors, warnings, creatures: ids.length, points, noData};
  }

  if (!pendingItems().length && !pendingNpcs().length && Object.keys(state.creatures).length) {
    console.log("Tout est déjà lu : validation seule.");
  } else {
    const pages = pendingItems().length ? pendingItems().length + 600 : pendingNpcs().length;
    const ask = `Il reste ${pendingItems().length ? "environ " : ""}${pages} page(s) à lire, soit ${etaMin(pages)} min environ. Cette passe s'arrête après ${MAX_MINUTES} min ou ${MAX_PAGES} pages. Pour l'arrêter : window.__skinStop = true dans la console. Continuer ?`;
    if (typeof confirm === "function" && !confirm(ask)) { console.log("Annulé, aucune requête envoyée."); return; }
  }

  let stopReason = "";
  const guard = () => g.__skinStop ? "arrêt manuel"
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

  for (const [name, id, core] of pendingItems()) {
    stopReason = stopReason || guard();
    if (stopReason) break;
    const res = await page("item", id, name);
    if ((await outcome(res)) === "retry") { if (stopReason) break; await pause(); continue; }
    if (res.status !== 200) { console.warn(`${name} : HTTP ${res.status}`); await pause(); continue; }
    const t = title(res.html);
    const valid = t.toLowerCase().indexOf(name.toLowerCase()) >= 0;
    const drops = {};
    let rows = 0;
    if (valid) {
      for (const l of listviews(res.html)) {
        if (l.template !== "npc" || !/skin/i.test(l.id)) continue;
        for (const r of l.rows) {
          if (!r || !r.id) continue;
          rows++;
          const why = excludeReason(r);
          if (why) { state.excluded[r.id] = why; continue; }
          state.creatures[r.id] = slim(r);
          drops[r.id] = [r.count, r.outof];
        }
      }
    }
    state.items[name] = {id, title: t, valid, rows, drops};
    save();
    console.log(`${name} : ${valid ? rows + " créatures" : "TITRE INATTENDU (" + t + ")"}`);
    badTitle = valid ? 0 : badTitle + 1;
    emptyItem = (valid && rows === 0) ? emptyItem + 1 : 0;
    if (badTitle >= 3) stopReason = "titres d'objets inattendus (3 de suite) : identifiants ou site différents ?";
    else if (emptyItem >= 3) stopReason = "aucune créature trouvée sur 3 objets de suite : format de page modifié ?";
    if (stopReason) break;
    await pause();
  }

  if (!stopReason && !pendingItems().length) {
    const todo = pendingNpcs().sort((a, b) => state.creatures[a].minlevel - state.creatures[b].minlevel);
    const total = todo.length;
    console.log(`Créatures retenues : ${Object.keys(state.creatures).length} (exclues : ${Object.keys(state.excluded).length}), à lire : ${total}.`);
    let done = 0;
    for (const id of todo) {
      stopReason = stopReason || guard();
      if (stopReason) break;
      const res = await page("npc", id, state.creatures[id].name);
      if ((await outcome(res)) === "retry") { if (stopReason) break; await pause(); continue; }
      const data = res.status === 200 ? mapperData(res.html) : null;
      state.npcs[id] = {title: title(res.html), http: res.status, data};
      save();
      done++;
      emptyNpc = countPoints(data) === 0 ? emptyNpc + 1 : 0;
      if (emptyNpc >= 12) stopReason = "12 créatures de suite sans point d'apparition : format de page modifié ?";
      if (done % 10 === 0) console.log(`${done} / ${total} lues, environ ${etaMin(total - done)} min restantes`);
      if (stopReason) break;
      await pause();
    }
  }

  const left = pendingItems().length + pendingNpcs().length;
  if (stopReason) console.warn(`Arrêt : ${stopReason}.`);
  if (left > 0) {
    console.log(`Reste ${left} page(s) (environ ${etaMin(left)} min). ${stopReason && /refus|réseau/.test(stopReason) ? "Attendre avant de relancer." : "Relancer le script pour continuer."}`);
    return;
  }

  const v = validate();
  const perMap = {};
  for (const [id, n] of Object.entries(state.npcs)) for (const z of Object.values(n.data || {})) for (const e of z) {
    const key = e.uiMapName || String(e.uiMapId);
    perMap[key] = perMap[key] || {zone: key, creatures: 0, points: 0};
    perMap[key].creatures++;
    perMap[key].points += (e.coords || []).length;
  }
  console.table(Object.values(perMap).sort((a, b) => b.points - a.points).slice(0, 60));
  console.log(`Validation : ${v.creatures} créatures, ${v.points} points, ${v.noData} sans point, ${Object.keys(state.excluded).length} exclues.`);
  v.warnings.slice(0, 15).forEach(w => console.warn("Avertissement : " + w));
  v.errors.slice(0, 15).forEach(e => console.error("Erreur : " + e));
  if (v.errors.length && !FORCE_DOWNLOAD) {
    console.error(`${v.errors.length} erreur(s) : pas de fichier final. window.__skinDump() télécharge l'état pour diagnostic.`);
    return;
  }
  const items = {};
  for (const [n, it] of Object.entries(state.items)) if (it.valid) items[n] = {id: it.id, title: it.title, drops: it.drops};
  download("wowhead_skinning_all_zones.json", {
    source: "Wowhead Forever skinning", version: 3, exportedAt: Date.now(), mode: state.mode,
    items, creatures: state.creatures, npcs: state.npcs, excluded: state.excluded,
    stats: {creatures: v.creatures, points: v.points, noData: v.noData, excluded: Object.keys(state.excluded).length}, warnings: v.warnings
  });
  console.log("Fichier final téléchargé : wowhead_skinning_all_zones.json");
})();
