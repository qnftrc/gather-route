#!/usr/bin/env python3
import argparse
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import merge_skinning
from lupa import LuaRuntime

SAMPLE = 40
MIN_SAMPLE_DROPS = 3


def targets(skin_path, loot_path, sql_path, sample=SAMPLE):
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(open(skin_path, encoding="utf8").read())
    L.execute(open(loot_path, encoding="utf8").read())
    rows = L.eval("(function() local o = {} for cid, c in pairs(SkinRoute_Data.creatures) do local n = 0 for _ in pairs((SkinRoute_Loot.creatures[cid] or {d = {}}).d) do n = n + 1 end o[#o + 1] = {cid, c.n, c.s, n} end return o end)()")
    sql = merge_skinning.read_text(sql_path)
    cols = merge_skinning.table_columns(sql, "creature_template")
    known = {int(dict(zip(cols, r))["Entry"]) for r in merge_skinning.table_rows(sql, "creature_template")}
    forever, modified, pool = [], [], []
    for r in rows.values():
        cid, name, src, drops = int(r[1]), r[2], r[3], int(r[4])
        if src == "w":
            (modified if cid in known else forever).append([cid, name, "modified" if cid in known else "forever"])
        elif drops >= MIN_SAMPLE_DROPS:
            pool.append((cid, name))
    pool.sort()
    step = max(1, len(pool) // sample)
    picked = [[cid, name, "sample"] for cid, name in pool[::step][:sample]]
    out = sorted(forever) + sorted(modified) + picked
    return out, collections.Counter(t[2] for t in out)


def js_literal(items):
    return "[\n" + ",\n".join("    [%d, %s, %s]" % (cid, js_str(name), js_str(group)) for cid, name, group in items) + "\n  ]"


def js_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main(argv=None):
    ap = argparse.ArgumentParser(description="Write the list of creatures to read into tools/wowhead_export_loot.js")
    ap.add_argument("--skin", required=True, help="SkinRoute/Data/SkinData.lua")
    ap.add_argument("--loot", required=True, help="SkinRoute/Data/LootData.lua")
    ap.add_argument("--cmangos", required=True, help="CMaNGOS classic-db SQL dump")
    ap.add_argument("--js", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "wowhead_export_loot.js"))
    ap.add_argument("--sample", type=int, default=SAMPLE)
    args = ap.parse_args(argv)
    items, counts = targets(args.skin, args.loot, args.cmangos, args.sample)
    text = open(args.js, encoding="utf8").read()
    new, n = re.subn(r"/\*TARGETS\*/.*?/\*END\*/", lambda m: "/*TARGETS*/" + js_literal(items) + "/*END*/", text, flags=re.S)
    if n != 1:
        raise SystemExit("marker /*TARGETS*/ ... /*END*/ not found exactly once in " + args.js)
    with open(args.js, "w", encoding="utf8", newline="\n") as f:
        f.write(new)
    print("targets: %d (%s)" % (len(items), ", ".join("%s %d" % kv for kv in sorted(counts.items()))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
