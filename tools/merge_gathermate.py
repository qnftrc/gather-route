"""Adds GatherMate2 (Forever) herb nodes to the HerbRoute database, additively.

The existing database (HerbRoute/Data/HerbData.lua) is only read, never changed.
A GatherMate point is a duplicate, and is dropped, when a point of the same herb
lies within --tol percent of the map in the same region; every other point is
written, once, to a separate file (HerbRoute/Data/HerbDataGatherMate.lua) that
appends it to HerbRoute_Data when the addon loads.

usage:
  python3 -I tools/merge_gathermate.py <GatherMate2 folder> <GatherMate2_Data/Forever folder> \
      [--tol 0.5] [--zone 1448=Felwood] [--out HerbRoute/Data/HerbDataGatherMate.lua]

GatherMate zone IDs are map IDs; each is matched to one of our regions by the
overlap of the two point sets (it must reach --min-overlap of the zone's points).
Zones with no overlap need an explicit --zone ID=Region name.
"""
import argparse
import collections
import math
import re
import sys
from lupa import LuaRuntime


def sandbox_table(path, name):
    lua = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    src = open(path, encoding="utf-8").read()
    run = lua.eval('function(src, name) local env = {} local f, e = load(src, "data", "t", env) if not f then error(e) end f() return env[name] end')
    return run(src, name)


def decode(coord):
    # GatherMate2 EncodeLoc: x * 1e4 * 1e6 + y * 1e4 * 100 (+ a small level suffix)
    return (coord // 1000000) / 10000 * 100, ((coord % 1000000) // 100) / 10000 * 100


class Grid:
    """Nearest-neighbour test within a radius, using a hash grid."""

    def __init__(self, points, cell):
        self.cell = cell
        self.cells = collections.defaultdict(list)
        for p in points:
            self.add(p)

    def key(self, p):
        return int(p[0] // self.cell), int(p[1] // self.cell)

    def add(self, p):
        self.cells[self.key(p)].append(p)

    def near(self, p, radius):
        kx, ky = self.key(p)
        r2 = (radius + 1e-9) ** 2
        for i in (-1, 0, 1):
            for j in (-1, 0, 1):
                for q in self.cells.get((kx + i, ky + j), ()):
                    if (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 <= r2:
                        return True
        return False


def herb_names(constants_path):
    txt = open(constants_path, encoding="utf-8", errors="replace").read()
    a = txt.index('["Herb Gathering"] = {')
    b = txt.index('["Treasure"] = {', a)
    block = txt[a:b]
    ids = {}
    for m in re.finditer(r'\["([^"]+)"\]\s*=\s*\{\s*id\s*=\s*(\d+)', block):
        ids[int(m.group(2))] = m.group(1)
    for m in re.finditer(r'\["([^"]+)"\]\s*=\s*(\d+)\s*,', block):
        ids.setdefault(int(m.group(2)), m.group(1))
    return ids


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gm_addon")
    ap.add_argument("gm_data")
    ap.add_argument("--base", default="HerbRoute/Data/HerbData.lua")
    ap.add_argument("--out", default="HerbRoute/Data/HerbDataGatherMate.lua")
    ap.add_argument("--tol", type=float, default=0.5)
    ap.add_argument("--min-overlap", type=float, default=0.3)
    ap.add_argument("--zone", action="append", default=[])
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    ids = herb_names(args.gm_addon.rstrip("/") + "/Constants.lua")
    gm_db = sandbox_table(args.gm_data.rstrip("/") + "/HerbalismData.lua", "GatherMateData2HerbDB")
    base = sandbox_table(args.base, "HerbRoute_Data")

    ours = {}
    for region in base.keys():
        ours[region] = {}
        for herb in base[region].keys():
            ours[region][herb] = [(float(p[1]), float(p[2])) for p in base[region][herb].values()]

    gm = {}
    for zone in gm_db.keys():
        by_herb = collections.defaultdict(list)
        for coord, node in gm_db[zone].items():
            herb = ids.get(int(node))
            if herb is None:
                print("unknown herb id", node, "in zone", zone, file=sys.stderr)
                continue
            x, y = decode(int(coord))
            by_herb[herb].append((round(x, 2), round(y, 2)))  # compare the values that get written
        gm[int(zone)] = by_herb

    explicit = {}
    for item in args.zone:
        zid, name = item.split("=", 1)
        explicit[int(zid)] = name

    # zone -> region by overlap
    grids = {r: {h: Grid(pts, args.tol) for h, pts in herbs.items()} for r, herbs in ours.items()}
    mapping, overlaps = {}, {}
    for zone, by_herb in sorted(gm.items()):
        total = sum(len(p) for p in by_herb.values())
        best, best_n = None, 0
        for region, herbs in grids.items():
            n = 0
            for herb, pts in by_herb.items():
                g = herbs.get(herb)
                if g:
                    n += sum(1 for p in pts if g.near(p, args.tol))
            if n > best_n:
                best, best_n = region, n
        overlaps[zone] = (best, best_n, total)
        if zone in explicit:
            mapping[zone] = explicit[zone]
        elif best and best_n >= args.min_overlap * total:
            mapping[zone] = best
        else:
            print(f"zone {zone}: no region matches ({best_n}/{total} points); use --zone {zone}=<region name>", file=sys.stderr)

    additions = collections.defaultdict(lambda: collections.defaultdict(list))
    stats = collections.defaultdict(lambda: [0, 0, 0, 0])  # region -> total, duplicates, added, merged among themselves
    for zone, region in sorted(mapping.items(), key=lambda kv: kv[1]):
        for herb, pts in sorted(gm[zone].items()):
            existing = grids.get(region, {}).get(herb)
            accepted = Grid([], args.tol)
            for p in sorted(pts):
                stats[region][0] += 1
                if existing and existing.near(p, args.tol):
                    stats[region][1] += 1
                elif accepted.near(p, args.tol):
                    stats[region][3] += 1
                else:
                    accepted.add(p)
                    additions[region][herb].append(p)
                    stats[region][2] += 1

    lines = [
        "-- Generated by tools/merge_gathermate.py from GatherMate2_Data (Forever). Do not edit.",
        "-- Source: GatherMate2 by kagaro, xinhuan and nevcairiel (GNU GPL v2 or later).",
        "-- Additive only: these points are appended to HerbRoute_Data; the points of",
        "-- Data/HerbData.lua are untouched. A GatherMate point within %.2f%% of an existing" % args.tol,
        "-- point of the same herb and region was treated as a duplicate and left out.",
        "local added = {",
    ]
    for region in sorted(additions):
        lines.append('["%s"] = {' % region.replace('"', '\\"'))
        for herb in sorted(additions[region]):
            pts = ",".join("{%s,%s}" % (("%.2f" % x).rstrip("0").rstrip("."), ("%.2f" % y).rstrip("0").rstrip("."))
                           for x, y in additions[region][herb])
            lines.append('["%s"]={%s},' % (herb.replace('"', '\\"'), pts))
        lines.append("},")
    lines += [
        "}",
        "for region, herbs in pairs(added) do",
        "    HerbRoute_Data[region] = HerbRoute_Data[region] or {}",
        "    for herb, points in pairs(herbs) do",
        "        local list = HerbRoute_Data[region][herb] or {}",
        "        for _, p in ipairs(points) do list[#list + 1] = p end",
        "        HerbRoute_Data[region][herb] = list",
        "    end",
        "end",
    ]
    open(args.out, "w", encoding="utf-8").write("\n".join(lines) + "\n")

    total = [sum(s[i] for s in stats.values()) for i in range(4)]
    print("zones mapped: %d / %d" % (len(mapping), len(gm)))
    print("GatherMate points: %d, duplicates of existing: %d, duplicates among themselves: %d, added: %d" % (
        total[0], total[1], total[3], total[2]))
    rows = ["| Région | GatherMate | Doublons de la base | Fusionnés entre eux | Ajoutés |", "|---|---|---|---|---|"]
    for region in sorted(stats):
        s = stats[region]
        rows.append("| %s%s | %d | %d | %d | %d |" % (region, "" if region in ours else " (nouvelle)", s[0], s[1], s[3], s[2]))
    rows.append("| **Total** | %d | %d | %d | %d |" % tuple(total))
    print("\n".join(rows))
    if args.report:
        zrows = ["| Zone GatherMate | Région | Recouvrement |", "|---|---|---|"]
        for zone in sorted(gm):
            best, n, tot = overlaps[zone]
            zrows.append("| %d | %s | %d / %d |" % (zone, mapping.get(zone, "non rattachée"), n, tot))
        open(args.report, "w", encoding="utf-8").write(
            "# Données GatherMate fusionnées\n\nGénéré par `tools/merge_gathermate.py`. Tolérance de doublon : %.2f %% de la carte.\n\n%s\n\n## Correspondance des zones\n\n%s\n"
            % (args.tol, "\n".join(rows), "\n".join(zrows)))


if __name__ == "__main__":
    main()
