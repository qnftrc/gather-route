const fs = require('fs');
const lines = fs.readFileSync(process.argv[2], 'utf8').split('\n');
const grab = n => lines[n - 1];
const code = [3, 17, 18, 20, 21].map(grab).join('\n') + '\nmodule.exports={REGIONS,nearest,improve,pathLength};';
const m = { exports: {} };
new Function('module', code)(m);
const { REGIONS, nearest, improve, pathLength } = m.exports;
const cases = JSON.parse(process.argv[3]);
const out = [];
for (const c of cases) {
  const pts = [];
  for (const h of c.herbs) for (const p of REGIONS[c.region].herbs[h].waypoints) pts.push({ x: p.x, y: p.y, herb: h });
  const route = improve(nearest(pts, c.start), c.start);
  out.push({ n: pts.length, len: pathLength(route, c.start), first: route.slice(0, 5).map(p => [p.x, p.y]), last: route.slice(-3).map(p => [p.x, p.y]), sig: route.map(p => p.x + ',' + p.y).join(';').length });
}
console.log(JSON.stringify(out));
