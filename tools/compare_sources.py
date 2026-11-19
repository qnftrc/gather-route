"""Compares the HerbRoute source databases with GatherMate2 (Forever), point by point.

Herbs: Data/HerbData.lua (Wowhead export, untouched) against GatherMate HerbalismData.
Ores: the Wowhead export (JSON from tools/wowhead_export_ores.js) against GatherMate MiningData.
Two points match when they are within --tol percent of the map (same region, same item).
For each (region, item): counts on both sides, how many points of each side have a match on the
other side, and the points found on one side only. Read-only; writes only the report.

usage:
  python3 -I tools/compare_sources.py <GatherMate2 folder> <GatherMate2_Data/Forever folder> <wowhead ores json> [--report docs/COMPARAISON_BASES.md]
"""
import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from merge_gathermate import Grid, decode, herb_names, sandbox_table  # noqa: E402
from merge_wowhead_ores import zone_table  # noqa: E402


def gm_points(db, ids, zones):
    out = collections.defaultdict(lambda: collections.defaultdict(list))
    unknown = collections.Counter()
    for zone in db.keys():
        region = zones.get(int(zone))
        for coord, node in db[zone].items():
            name = ids.get(int(node))
            x, y = decode(int(coord))
            if region is None:
                unknown[int(zone)] += 1
            elif name is None:
                unknown["id %s" % int(node)] += 1
            else:
                out[region][name].append((round(x, 2), round(y, 2)))
    return out, unknown


def compare(a, b, tol):
    """a, b: region -> item -> points. Returns rows (region, item, na, nb, a_in_b, b_in_a)."""
    rows = []
    for region in sorted(set(a) | set(b)):
        for item in sorted(set(a.get(region, {})) | set(b.get(region, {}))):
            pa, pb = a.get(region, {}).get(item, []), b.get(region, {}).get(item, [])
            ga, gb = Grid(pa, tol), Grid(pb, tol)
            rows.append((region, item, len(pa), len(pb), sum(1 for p in pa if gb.near(p, tol)), sum(1 for p in pb if ga.near(p, tol))))
    return rows


def pct(n, d):
    return "%.1f %%" % (100.0 * n / d) if d else "n/a"


def summarize(rows, label_a, label_b):
    by_item = collections.defaultdict(lambda: [0, 0, 0, 0])
    by_region = collections.defaultdict(lambda: [0, 0, 0, 0])
    for region, item, na, nb, ab, ba in rows:
        for acc in (by_item[item], by_region[region]):
            acc[0] += na; acc[1] += nb; acc[2] += ab; acc[3] += ba
    tot = [sum(v[i] for v in by_item.values()) for i in range(4)]
    lines = []
    for title, table in (("Par type", by_item), ("Par région", by_region)):
        out = "### %s\n\n| %s | %s | couverts par %s | %s | couverts par %s | seuls %s | seuls %s |\n|---|---|---|---|---|---|---|\n" % (
            title, "Nom", "Points " + label_a, label_b, "Points " + label_b, label_a, label_a, label_b)
        for key in sorted(table):
            na, nb, ab, ba = table[key]
            out += "| %s | %d | %d (%s) | %d | %d (%s) | %d | %d |\n" % (key, na, ab, pct(ab, na), nb, ba, pct(ba, nb), na - ab, nb - ba)
        out += "| **Total** | %d | %d (%s) | %d | %d (%s) | %d | %d |\n" % (tot[0], tot[2], pct(tot[2], tot[0]), tot[1], tot[3], pct(tot[3], tot[1]), tot[0] - tot[2], tot[1] - tot[3])
        lines.append(out)
    return "\n".join(lines), tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gm_addon")
    ap.add_argument("gm_data")
    ap.add_argument("wowhead_ores")
    ap.add_argument("--herbs", default="HerbRoute/Data/HerbData.lua")
    ap.add_argument("--zone-map", default="docs/DONNEES_GATHERMATE.md")
    ap.add_argument("--tol", type=float, default=0.5)
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    zones = zone_table(args.zone_map)
    zones[2482] = "Mount Hyjal"
    constants = args.gm_addon.rstrip("/") + "/Constants.lua"
    gm = args.gm_data.rstrip("/")

    report = ["# Comparaison des bases HerbRoute et GatherMate (Forever)\n",
              "Généré par `tools/compare_sources.py`. Deux points se correspondent à moins de %.2f %% de la carte, même région, même type. Lecture seule. « Wowhead » = base d'origine des herbes (`HerbData.lua`, inchangée) et export Wowhead des minerais ; « GatherMate » = `GatherMate2_Data/Forever`.\n" % args.tol]
    results = {}
    for cat, label, gm_file, gm_table, block in (("herbes", "herbes", "HerbalismData.lua", "GatherMateData2HerbDB", "Herb Gathering"),
                                                  ("minerais", "minerais", "MiningData.lua", "GatherMateData2MineDB", "Mining")):
        ids = herb_names(constants, block)
        db = sandbox_table(gm + "/" + gm_file, gm_table)
        gmp, unknown = gm_points(db, ids, zones)
        if cat == "herbes":
            base = sandbox_table(args.herbs, "HerbRoute_Data")
            wh = {r: {h: [(float(p[1]), float(p[2])) for p in base[r][h].values()] for h in base[r].keys()} for r in base.keys()}
        else:
            ores = json.load(open(args.wowhead_ores, encoding="utf-8"))["ores"]
            wh = collections.defaultdict(lambda: collections.defaultdict(list))
            for ore, entry in ores.items():
                data = entry.get("data") or {}
                for items in data.values():
                    if not isinstance(items, list):
                        continue
                    for item in items:
                        if isinstance(item, dict) and zones.get(item.get("uiMapId")):
                            wh[zones[item["uiMapId"]]][ore].extend((round(float(x), 1), round(float(y), 1)) for x, y in item["coords"])
        rows = compare(wh, gmp, args.tol)
        text, tot = summarize(rows, "Wowhead", "GatherMate")
        results[cat] = tot
        only_wh = sorted({i for r in wh for i in wh[r]} - {i for r in gmp for i in gmp[r]})
        only_gm = sorted({i for r in gmp for i in gmp[r]} - {i for r in wh for i in wh[r]})
        report.append("## %s\n\nTypes présents d'un seul côté : Wowhead seul : %s ; GatherMate seul : %s.%s\n\n%s" % (
            cat.capitalize(), ", ".join(only_wh) or "aucun", ", ".join(only_gm) or "aucun",
            (" Éléments GatherMate non rattachés : %s." % dict(unknown)) if unknown else "", text))
        print(cat, "Wowhead %d, GatherMate %d, Wowhead couverts %d, GatherMate couverts %d" % (tot[0], tot[1], tot[2], tot[3]))
    if args.report:
        open(args.report, "w", encoding="utf-8").write("\n".join(report))


if __name__ == "__main__":
    main()
