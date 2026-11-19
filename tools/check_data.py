"""Checks that HerbDataGatherMate.lua only adds to HerbData.lua.

usage: python3 -I tools/check_data.py
Loads both files in a sandboxed Lua, as the addon does, and verifies that every
original point is still there at the same index, that nothing was removed, and
that no added point is within the tolerance of an existing point or of another
added point of the same herb and region.
"""
import math
import sys
from lupa import LuaRuntime

TOL = 0.5


def load(*paths):
    lua = LuaRuntime(register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    run = lua.eval('''function(sources)
        local env = {ipairs = ipairs, pairs = pairs}
        for _, src in ipairs(sources) do
            local f, e = load(src, "data", "t", env)
            if not f then error(e) end
            f()
        end
        return env.HerbRoute_Data
    end''')
    return run(lua.table_from([open(p, encoding="utf-8").read() for p in paths]))


def as_dict(db):
    return {r: {h: [(float(p[1]), float(p[2])) for p in pts.values()] for h, pts in herbs.items()} for r, herbs in db.items()}


base = as_dict(load("HerbRoute/Data/HerbData.lua"))
merged = as_dict(load("HerbRoute/Data/HerbData.lua", "HerbRoute/Data/HerbDataGatherMate.lua"))

errors = []
n_base = sum(len(p) for h in base.values() for p in h.values())
n_merged = sum(len(p) for h in merged.values() for p in h.values())
for region, herbs in base.items():
    for herb, pts in herbs.items():
        m = merged.get(region, {}).get(herb)
        if m is None or m[:len(pts)] != pts:
            errors.append("original points changed: %s / %s" % (region, herb))
added = 0
for region, herbs in merged.items():
    for herb, pts in herbs.items():
        old = base.get(region, {}).get(herb, [])
        new = pts[len(old):]
        added += len(new)
        for i, p in enumerate(new):
            for q in old + new[:i]:
                if math.hypot(p[0] - q[0], p[1] - q[1]) <= TOL:
                    errors.append("added point within tolerance: %s / %s %s" % (region, herb, p))
                    break
print("original points: %d, merged: %d, added: %d, new regions: %s" % (
    n_base, n_merged, added, sorted(set(merged) - set(base))))
if errors:
    print("\n".join(errors[:20]))
    sys.exit(1)
print("OK: the original database is untouched and additions are all distinct")
