// À coller dans la console du navigateur, sur une page https://www.wowhead.com/forever/... (même site que les pages lues).
// Étape 1 : pour chaque cuir, lit l'onglet des créatures dépecables. Étape 2 : pour chaque créature, lit g_mapperData.
// Télécharge wowhead_skinning_mapperdata.json. Les identifiants viennent de la mémoire : vérifiez la colonne "titre" affichée dans la console.
(async () => {
  const ITEMS = {
    "Ruined Leather Scraps": 2934, "Light Hide": 783, "Light Leather": 2318, "Medium Hide": 4232,
    "Medium Leather": 2319, "Heavy Hide": 4235, "Heavy Leather": 4234, "Thick Hide": 8169,
    "Thick Leather": 4304, "Rugged Hide": 8171, "Rugged Leather": 8170, "Scorpid Scale": 8154,
    "Devilsaur Leather": 15417, "Chimera Leather": 15423
  };
  const DELAY = 1500;
  const out = {source: "Wowhead Forever skinning", partial: false, items: {}, npcs: {}};
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const blocked = {n: 0};

  async function grab(path) {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const res = await fetch(path, {credentials: "same-origin"});
        if (res.status === 403 || res.status === 429) {
          blocked.n++;
          await sleep(DELAY * 4);
          continue;
        }
        blocked.n = 0;
        return {status: res.status, html: await res.text()};
      } catch (e) {
        await sleep(DELAY);
      }
    }
    return {status: 0, html: ""};
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
  const rows = [];

  for (const [name, id] of Object.entries(ITEMS)) {
    const res = await grab(`/forever/item=${id}`);
    const lvs = listviews(res.html);
    const skin = lvs.filter(l => l.template === "npc" && /skin/i.test(l.id));
    const npcs = [];
    for (const l of skin) for (const r of l.rows) if (r && r.id) npcs.push(r);
    out.items[name] = {id, title: title(res.html), http: res.status, listviews: lvs.map(l => l.template + ":" + l.id + ":" + l.rows.length), npcs};
    rows.push({objet: name, id, titre: title(res.html).slice(0, 40), http: res.status, listviews: lvs.length, creatures: npcs.length});
    if (blocked.n >= 2) { out.partial = true; break; }
    await sleep(DELAY);
  }
  console.table(rows);

  const ids = [];
  const seen = new Set();
  for (const item of Object.values(out.items)) for (const r of item.npcs) if (!seen.has(r.id)) { seen.add(r.id); ids.push(r.id); }
  console.log(`Créatures à lire : ${ids.length}`);

  const npcRows = [];
  if (!out.partial) {
    let done = 0;
    for (const id of ids) {
      const res = await grab(`/forever/npc=${id}`);
      const data = mapperData(res.html);
      out.npcs[id] = {title: title(res.html), http: res.status, data};
      done++;
      if (done % 25 === 0) console.log(`${done} / ${ids.length}`);
      if (blocked.n >= 2) { out.partial = true; break; }
      await sleep(DELAY);
    }
    for (const [id, n] of Object.entries(out.npcs)) {
      const points = n.data ? Object.values(n.data).reduce((a, z) => a + z.reduce((b, e) => b + e.coords.length, 0), 0) : 0;
      npcRows.push({id, titre: n.title.slice(0, 40), http: n.http, zones: n.data ? Object.keys(n.data).length : 0, points});
    }
    console.table(npcRows.slice(0, 40));
  }
  console.log(`Créatures lues : ${Object.keys(out.npcs).length} / ${ids.length}${out.partial ? " (partiel, accès refusé)" : ""}`);

  const blob = new Blob([JSON.stringify(out)], {type: "application/json"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "wowhead_skinning_mapperdata.json";
  a.click();
})();
