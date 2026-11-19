"""Lists near-duplicate points of the HerbRoute databases, by category, region and type (read-only).

Points of the same region and type within a tolerance (percent of the map) are grouped; "en trop" counts
the points beyond one per group. The data files are loaded in the addon's order.

usage:
  python3 -I tools/report_duplicates.py [--report docs/DOUBLONS.md]
"""
import argparse
import collections
from lupa import LuaRuntime

TOLS = (0.1, 0.5, 1.0)


def load(files, var):
    lua = LuaRuntime(register_eval=False, register_builtins=False)
    lua.execute("".join(open("HerbRoute/Data/" + f, encoding="utf-8").read() + "\n" for f in files))
    return lua.eval(var)


def excess(pts, tol):
    cell = tol
    grid = collections.defaultdict(list)
    for i, p in enumerate(pts):
        grid[(int(p[0] // cell), int(p[1] // cell))].append(i)
    parent = list(range(len(pts)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for i, p in enumerate(pts):
        kx, ky = int(p[0] // cell), int(p[1] // cell)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for j in grid.get((kx + dx, ky + dy), ()):
                    if j > i and (p[0] - pts[j][0]) ** 2 + (p[1] - pts[j][1]) ** 2 <= (tol + 1e-9) ** 2:
                        parent[find(i)] = find(j)
    return len(pts) - len({find(i) for i in range(len(pts))})


def rows_of(data, category):
    rows = []
    for region in data.keys():
        for item in data[region].keys():
            pts = [(float(p[1]), float(p[2])) for p in data[region][item].values()]
            rows.append((category, region, item, len(pts)) + tuple(excess(pts, t) for t in TOLS))
    return rows


def table(rows, header):
    out = ["| %s |" % " | ".join(header), "|%s|" % "|".join("---" for _ in header)]
    for r in rows:
        out.append("| %s |" % " | ".join(str(c) for c in r))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    herbs = rows_of(load(["HerbData.lua", "HerbDataGatherMate.lua"], "HerbRoute_Data"), "Herbes")
    ores = rows_of(load(["OreDataGatherMate.lua", "OreDataWowhead.lua"], "HerbRoute_OreData"), "Minerais")
    doc = ["# Doublons des bases de points\n",
           "Généré par `tools/report_duplicates.py` (lecture seule) sur la base chargée par l'add-on (herbes : `HerbData.lua` puis `HerbDataGatherMate.lua` ; minerais : `OreDataGatherMate.lua` puis `OreDataWowhead.lua`). Une unité = 1 % de la carte. Deux points du même type et de la même région à moins de N unités forment un groupe ; **en trop** = points au-delà d'un par groupe. Les doublons à 0,1 et 0,5 des herbes viennent surtout de la base d'origine Wowhead, conservée telle quelle (décision D8).\n"]
    for rows, label in ((herbs, "Herbes"), (ores, "Minerais")):
        tot = [sum(r[i] for r in rows) for i in range(3, 7)]
        doc.append("## %s : total\n\nPoints %d ; en trop : %d à 0,1, %d à 0,5, %d à 1,0 (%.1f %%).\n" % (label, tot[0], tot[1], tot[2], tot[3], 100.0 * tot[3] / tot[0]))
        for key, idx, title in ((2, "type", "par type"), (1, "région", "par région")):
            agg = collections.defaultdict(lambda: [0, 0, 0, 0])
            for r in rows:
                a = agg[r[key]]
                for i in range(4):
                    a[i] += r[3 + i]
            lst = sorted(agg.items(), key=lambda kv: -kv[1][3])
            doc.append("### %s %s\n\n%s\n" % (label, title, table([(k, *v) for k, v in lst], [idx.capitalize(), "Points", "En trop 0,1", "En trop 0,5", "En trop 1,0"])))
        detail = sorted((r for r in rows if r[6] > 0), key=lambda r: (-r[6], r[1], r[2]))
        doc.append("### %s : détail région et type (au moins un doublon à 1,0)\n\n%s\n" % (
            label, table([r[1:] for r in detail], ["Région", "Type", "Points", "En trop 0,1", "En trop 0,5", "En trop 1,0"])))
    text = "\n".join(doc)
    if args.report:
        open(args.report, "w", encoding="utf-8").write(text)
    else:
        print(text)


if __name__ == "__main__":
    main()
