const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const src = fs.readFileSync(path.join(__dirname, "wowhead_export_loot.js"), "utf8");

function page(name, rows, tabs) {
  const lv = rows === null ? "" : `new Listview({template: 'item', id: 'drops', name: 'Drops', data: [${rows.map(r =>
    `{id:${r[0]},name:"${r[1]}",quality:${r[2]},count:${r[3]},outof:${r[4]}}`).join(",")}]});`;
  const other = (tabs || []).map(t => `new Listview({template: 'item', id: '${t}', data: []});`).join("");
  return `<html><head><title>${name} - NPC - Wowhead</title></head><body><script>${other}${lv}</script></body></html>`;
}

async function run(targets, responses, opts) {
  opts = opts || {};
  const store = opts.store || {};
  const logs = [], errs = [];
  let captured = null, sentUrls = [];
  const sandbox = {
    console: {log: m => logs.push(String(m)), warn: m => logs.push("WARN " + m), error: m => errs.push(String(m)), table: () => {}},
    localStorage: {getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = v; }},
    confirm: () => opts.confirm !== false,
    fetch: async url => {
      sentUrls.push(url);
      const r = responses(url, sentUrls.length);
      return {status: r.status, text: async () => r.html || ""};
    },
    setTimeout, clearTimeout, AbortController, Blob, URL,
    document: {createElement: () => ({click() {}})},
    __lootTest: {pause: [0, 1], capture: o => { captured = o; }},
  };
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  const code = src.replace(/\/\*TARGETS\*\/.*?\/\*END\*\//s, "/*TARGETS*/" + JSON.stringify(targets) + "/*END*/");
  if (opts.beforeRun) opts.beforeRun(sandbox);
  await vm.runInNewContext(code, sandbox);
  return {logs, errs, captured, sentUrls, store, sandbox};
}

(async () => {
  const targets = [[100, "Hyjal Bear", "forever"], [101, "Old Wolf", "modified"], [102, "Plain Boar", "sample"]];
  const pages = {
    100: page("Hyjal Bear", [[2589, "Linen Cloth", 1, 30, 100], [7005, "Skinning Knife", 1, 5, 100]]),
    101: page("Old Wolf", [[1000, "Gray Fang", 0, 50, 100]]),
    102: page("Plain Boar", null, ["skinning"]),
  };
  const ok = id => ({status: 200, html: pages[id]});
  const idOf = url => Number(url.match(/npc=(\d+)/)[1]);

  let r = await run(targets, url => ok(idOf(url)));
  assert(r.captured, "final file produced");
  assert.strictEqual(r.captured.stats.creatures, 3);
  assert.strictEqual(r.captured.stats.withDrops, 2);
  assert.strictEqual(r.captured.stats.rows, 3);
  assert.strictEqual(JSON.stringify(r.captured.npcs[100].drops[0]), JSON.stringify({id: 2589, name: "Linen Cloth", quality: 1, count: 30, outof: 100, stack: null, pctstack: null}));
  assert.strictEqual(r.captured.npcs[102].drops.length, 0);
  assert.strictEqual(JSON.stringify(r.captured.npcs[102].listviews), JSON.stringify(["skinning:item"]));
  assert(r.sentUrls[0].startsWith("/forever/npc=100/hyjal-bear"), r.sentUrls[0]);
  assert(r.logs.some(l => l.includes("Première page")), "probe line");
  assert.strictEqual(r.errs.length, 0, r.errs.join("|"));

  r = await run(targets, () => ({status: 405}));
  assert(!r.captured && r.logs.some(l => l.includes("accès refusé")), r.logs.join("|"));
  assert(r.sentUrls.length <= 6, "stops early on refusals: " + r.sentUrls.length);

  r = await run(targets, url => ok(idOf(url)), {confirm: false});
  assert(!r.captured && r.sentUrls.length === 0, "no request when declined");

  const five = [1, 2, 3, 4, 5, 6].map(i => [200 + i, "Thing " + i, "sample"]);
  r = await run(five, url => ({status: 200, html: `<title>Thing ${idOf(url) - 200} - NPC</title><p>no tabs</p>`}));
  assert(!r.captured && r.logs.some(l => l.includes("aucun onglet")), r.logs.join("|"));

  r = await run(five, url => ({status: 200, html: page("Something else", [])}));
  assert(!r.captured && r.logs.some(l => l.includes("titres de créatures inattendus")), r.logs.join("|"));

  const store = {};
  r = await run(targets, url => {
    const res = ok(idOf(url));
    if (idOf(url) === 100) setTimeout(() => { r.sandbox.__lootStop = true; }, 0);
    return res;
  }, {store, beforeRun: sb => { r = {sandbox: sb}; }});
  assert(!r.captured, "manual stop gives no file");
  const saved = JSON.parse(store.lootExportV1);
  assert(saved.npcs[100] && !saved.npcs[101], "state kept after the stop");
  r = await run(targets, url => { assert.notStrictEqual(idOf(url), 100, "page 100 is not read again"); return ok(idOf(url)); }, {store});
  assert(r.captured && r.captured.stats.rows === 3, "resumes and finishes");

  console.log("LOOT EXPORT TESTS OK");
})().catch(e => { console.error(e); process.exit(1); });
