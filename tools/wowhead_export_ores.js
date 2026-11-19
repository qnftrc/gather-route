// À coller dans la console du navigateur, sur une page https://www.wowhead.com/forever/... (même site que les pages lues).
// Lit g_mapperData de chaque gisement et télécharge wowhead_ores_mapperdata.json.
// Les identifiants viennent de la mémoire : vérifiez la colonne "titre" affichée dans la console.
(async () => {
  const ORES = {
    "Copper Vein": 1731, "Tin Vein": 1732, "Silver Vein": 1733, "Gold Vein": 1734, "Iron Deposit": 1735,
    "Mithril Deposit": 2040, "Truesilver Deposit": 2047, "Small Thorium Vein": 324, "Rich Thorium Vein": 175404,
    "Dark Iron Deposit": 165658, "Lesser Bloodstone Deposit": 2653, "Incendicite Mineral Vein": 1610,
    "Indurium Mineral Vein": 19903
  };
  const out = {source: "Wowhead Forever g_mapperData", ores: {}};
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const rows = [];
  for (const [name, id] of Object.entries(ORES)) {
    try {
      const res = await fetch(`/forever/object=${id}`, {credentials: "same-origin"});
      const html = await res.text();
      const title = (html.match(/<title>([^<]*)<\/title>/) || [, "?"])[1];
      const at = html.indexOf("g_mapperData");
      let data = null;
      if (at >= 0) {
        const start = html.indexOf("{", html.indexOf("=", at));
        let depth = 0, end = -1, inStr = false, esc = false;
        for (let i = start; i < html.length; i++) {
          const c = html[i];
          if (inStr) { if (esc) esc = false; else if (c === "\\") esc = true; else if (c === '"') inStr = false; continue; }
          if (c === '"') inStr = true;
          else if (c === "{") depth++;
          else if (c === "}" && --depth === 0) { end = i; break; }
        }
        if (end > 0) data = new Function("return (" + html.slice(start, end + 1) + ")")();
      }
      out.ores[name] = {id, title, data};
      const n = data ? Object.values(data).reduce((a, z) => a + z.reduce((b, e) => b + e.coords.length, 0), 0) : 0;
      rows.push({ore: name, id, titre: title.slice(0, 40), http: res.status, zones: data ? Object.keys(data).length : 0, points: n});
    } catch (e) {
      rows.push({ore: name, id, titre: "ERREUR " + e, http: 0, zones: 0, points: 0});
    }
    await sleep(1500);
  }
  console.table(rows);
  const blob = new Blob([JSON.stringify(out)], {type: "application/json"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "wowhead_ores_mapperdata.json";
  a.click();
})();
