// À coller dans la console du navigateur, sur une page https://www.wowhead.com/forever/... (même site que les pages lues).
// Une zone à la fois (ZONE = identifiant de zone Wowhead), pauses de 4 à 5,5 s, lots de BATCH créatures : relancer le script pour continuer.
// L'état est gardé dans localStorage (clé skinExportV2) ; un fichier wowhead_skinning_mapperdata.json cumulatif est téléchargé à chaque passage.
(async () => {
  const ZONE = 267;
  const BATCH = 40;
  const PAUSE = [4000, 5500];
  const KEY = "skinExportV2";
  const ITEMS = {
    "Ruined Leather Scraps": 2934, "Light Hide": 783, "Light Leather": 2318, "Medium Hide": 4232,
    "Medium Leather": 2319, "Heavy Hide": 4235, "Heavy Leather": 4234, "Thick Hide": 8169,
    "Thick Leather": 4304, "Rugged Hide": 8171, "Rugged Leather": 8170, "Scorpid Scale": 8154,
    "Devilsaur Leather": 15417, "Chimera Leather": 15423
  };
  const REFUSED = [403, 405, 429];
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const pause = () => sleep(PAUSE[0] + Math.random() * (PAUSE[1] - PAUSE[0]));

  let state = {mode: null, items: {}, npcs: {}};
  try {
    const s = JSON.parse(localStorage.getItem(KEY) || "null");
    if (s && s.items && s.npcs) state = s;
  } catch (e) {}
  const save = () => {
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { console.warn("Sauvegarde locale impossible : " + e); }
  };

  const slug = name => String(name || "").toLowerCase().replace(/['’]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  let refusals = 0, lastRefusal = 0;
  const dead = () => refusals >= 2 || (refusals >= 1 && !state.mode);

  async function once(path) {
    try {
      const res = await fetch(path, {credentials: "same-origin"});
      return {status: res.status, html: REFUSED.includes(res.status) ? "" : await res.text()};
    } catch (e) {
      return {status: 0, html: ""};
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
      if (!REFUSED.includes(last.status)) { refusals = 0; return {status: last.status, html: last.html, refused: false}; }
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
  const inZone = r => !Array.isArray(r.location) || r.location.length === 0 || r.location.indexOf(ZONE) >= 0;
  let aborted = false;
  const itemRows = [];

  for (const [name, id] of Object.entries(ITEMS)) {
    let it = state.items[name];
    if (!it) {
      const res = await page("item", id, name);
      if (res.refused) {
        if (dead()) { aborted = true; break; }
        await pause();
        continue;
      }
      if (res.status !== 200) {
        itemRows.push({objet: name, id, titre: "?", http: res.status, creatures: 0, "dans la zone": 0});
        await pause();
        continue;
      }
      const lvs = listviews(res.html);
      const npcs = [];
      for (const l of lvs) if (l.template === "npc" && /skin/i.test(l.id)) for (const r of l.rows) if (r && r.id) npcs.push(r);
      it = state.items[name] = {id, title: title(res.html), http: res.status, listviews: lvs.map(l => l.template + ":" + l.id + ":" + l.rows.length), npcs};
      save();
      await pause();
    }
    itemRows.push({objet: name, id, titre: it.title.slice(0, 40), http: it.http, creatures: it.npcs.length, "dans la zone": it.npcs.filter(inZone).length});
  }
  console.table(itemRows);

  const wanted = [], seen = new Set();
  for (const it of Object.values(state.items)) for (const r of it.npcs) if (inZone(r) && !seen.has(r.id)) { seen.add(r.id); wanted.push(r); }
  const batchRows = [];
  if (!aborted) {
    const todo = wanted.filter(r => !state.npcs[r.id]);
    const batch = todo.slice(0, BATCH);
    console.log(`Zone ${ZONE} : ${wanted.length} créatures, ${wanted.length - todo.length} déjà lues, ${batch.length} dans ce lot.`);
    for (const r of batch) {
      const res = await page("npc", r.id, r.name);
      if (res.refused) {
        if (dead()) { aborted = true; break; }
        await pause();
        continue;
      }
      const data = res.status === 200 ? mapperData(res.html) : null;
      if (res.status === 200) {
        state.npcs[r.id] = {title: title(res.html), http: res.status, data};
        save();
      }
      const points = data ? Object.values(data).reduce((a, z) => a + z.reduce((b, e) => b + e.coords.length, 0), 0) : 0;
      batchRows.push({id: r.id, nom: String(r.name || "").slice(0, 30), http: res.status, zones: data ? Object.keys(data).length : 0, points});
      await pause();
    }
    console.table(batchRows);
  }

  const remaining = wanted.filter(r => !state.npcs[r.id]).length;
  if (aborted) console.error(`Accès refusé (HTTP ${lastRefusal}), arrêt. Aucune autre requête envoyée. Attendre avant de relancer.`);
  else if (remaining > 0) console.log(`Reste ${remaining} créature(s) : relancer le script pour continuer.`);
  else console.log("Zone terminée.");

  if (Object.keys(state.items).length) {
    const out = {source: "Wowhead Forever skinning", zone: ZONE, mode: state.mode, partial: aborted || remaining > 0, items: state.items, npcs: state.npcs};
    const blob = new Blob([JSON.stringify(out)], {type: "application/json"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "wowhead_skinning_mapperdata.json";
    a.click();
  }
})();
