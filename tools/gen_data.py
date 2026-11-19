import json, sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    data = json.load(f)

def fmt(n):
    s = repr(float(n))
    return s[:-2] if s.endswith(".0") else s

lines = ["-- Generated from wowhead_forever_herbes_regions_waypoints.json. Do not edit.",
         "-- Each point is {x, y} in percent (0-100).",
         "HerbRoute_Data = {"]
total = 0
herbs_seen = set()
for region in sorted(data["regions"]):
    lines.append('["%s"] = {' % region.replace('"', '\\"'))
    for herb in sorted(data["regions"][region]["herbs"]):
        wps = data["regions"][region]["herbs"][herb]["waypoints"]
        herbs_seen.add(herb)
        total += len(wps)
        pts = ",".join("{%s,%s}" % (fmt(p["x"]), fmt(p["y"])) for p in wps)
        lines.append('["%s"]={%s},' % (herb.replace('"', '\\"'), pts))
    lines.append("},")
lines.append("}")
with open(dst, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("regions", len(data["regions"]), "herbs", len(herbs_seen), "points", total)
