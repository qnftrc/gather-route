#!/usr/bin/env python3
import argparse
import collections
import gzip
import json
import os
import re
import sys


DEFAULT_SKIP_ZONES = ["Orgrimmar", "Stormwind City", "Ironforge", "Darnassus", "Undercity", "Thunder Bluff",
                      "Alterac Valley", "Kalimdor", "Eastern Kingdoms"]
QUEST_CLASS = "12"


def read_text(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf8", errors="replace") as f:
        return f.read()


def table_columns(sql, table):
    m = re.search(r"CREATE TABLE `%s` \((.*?)\) ENGINE" % re.escape(table), sql, re.S)
    if not m:
        raise SystemExit("table `%s` not found in the SQL file" % table)
    return re.findall(r"^\s+`(\w+)`", m.group(1), re.M)


def table_rows(sql, table):
    for m in re.finditer(r"^INSERT INTO `%s` VALUES (.*);$" % re.escape(table), sql, re.M):
        s = m.group(1)
        i, n = 0, len(s)
        while i < n:
            if s[i] != "(":
                i += 1
                continue
            i += 1
            row, cur, quoted = [], [], False
            while True:
                c = s[i]
                if quoted:
                    if c == "\\":
                        cur.append(s[i + 1])
                        i += 2
                        continue
                    if c == "'":
                        if s[i + 1:i + 2] == "'":
                            cur.append("'")
                            i += 2
                            continue
                        quoted = False
                        i += 1
                        continue
                    cur.append(c)
                    i += 1
                    continue
                if c == "'":
                    quoted = True
                elif c == ",":
                    row.append("".join(cur))
                    cur = []
                elif c == ")":
                    row.append("".join(cur))
                    i += 1
                    break
                else:
                    cur.append(c)
                i += 1
            yield row


def quest_item_ids(sql, items):
    found = set()
    for m in re.finditer(r"^INSERT INTO `item_template` VALUES (.*);$", sql, re.M):
        for t in re.finditer(r"\((\d+),(\d+),\d+,'", m.group(1)):
            if t.group(2) == QUEST_CLASS and int(t.group(1)) in items:
                found.add(int(t.group(1)))
    return found


def load_cmangos(path, ranks):
    sql = read_text(path)
    cols = table_columns(sql, "creature_template")
    creatures, ranked_out = {}, set()
    for row in table_rows(sql, "creature_template"):
        d = dict(zip(cols, row))
        if int(d["SkinningLootId"]) <= 0:
            continue
        entry = int(d["Entry"])
        if int(d["Rank"]) not in ranks:
            ranked_out.add(entry)
            continue
        creatures[entry] = {"name": d["Name"], "l1": int(d["MinLevel"]), "l2": int(d["MaxLevel"]), "loot": int(d["SkinningLootId"]), "elite": int(d["Rank"]) == 1}
    lcols = table_columns(sql, "skinning_loot_template")
    loot = collections.defaultdict(list)
    names = {}
    for row in table_rows(sql, "skinning_loot_template"):
        d = dict(zip(lcols, row))
        item = int(d["item"])
        loot[int(d["entry"])].append((item, float(d["ChanceOrQuestChance"]), int(d["groupid"]), int(d["mincountOrRef"]), int(d["maxcount"])))
        if d.get("comments") and item not in names:
            names[item] = d["comments"]
    return creatures, ranked_out, loot, names, quest_item_ids(sql, {r[0] for rows in loot.values() for r in rows})


def effective_drops(rows, skip_items=()):
    out = {}
    groups = collections.defaultdict(list)
    for item, chance, group, mn, mx in rows:
        if mn < 0 or chance < 0 or item in skip_items:
            continue
        if group == 0:
            out[item] = (chance, mn, max(mx, mn))
        else:
            groups[group].append((item, chance, mn, max(mx, mn)))
    for members in groups.values():
        explicit = sum(c for _, c, _, _ in members if c > 0)
        zeros = [m for m in members if m[1] <= 0]
        share = max(0.0, 100.0 - explicit) / len(zeros) if zeros else 0.0
        for item, chance, mn, mx in members:
            out[item] = (chance if chance > 0 else share, mn, mx)
    return out


LOOT_QUALITIES = (0, 1, 2)
LOOT_MIN_CHANCE = 0.5


def corpse_drops(rows, refs, skip_items=()):
    out = dict(effective_drops(rows, skip_items))
    for item, chance, group, mn, mx in rows:
        if mn >= 0 or chance <= 0:
            continue
        rolls = max(1, mx)
        for it, (p, a, b) in effective_drops(refs.get(-mn, []), skip_items).items():
            add = min(100.0, rolls * chance / 100.0 * p)
            old = out.get(it)
            out[it] = (min(100.0, old[0] + add), min(old[1], a), max(old[2], b)) if old else (add, a, b)
    return out


def load_cmangos_loot(path, creature_ids):
    sql = read_text(path)
    ccols = table_columns(sql, "creature_template")
    loot_id, gold = {}, {}
    for row in table_rows(sql, "creature_template"):
        d = dict(zip(ccols, row))
        entry = int(d["Entry"])
        if entry in creature_ids:
            loot_id[entry] = int(d["LootId"])
            gold[entry] = (int(d["MinLootGold"]) + int(d["MaxLootGold"])) / 2.0

    def read_loot(table):
        cols = table_columns(sql, table)
        out = collections.defaultdict(list)
        for row in table_rows(sql, table):
            d = dict(zip(cols, row))
            out[int(d["entry"])].append((int(d["item"]), float(d["ChanceOrQuestChance"]), int(d["groupid"]), int(d["mincountOrRef"]), int(d["maxcount"])))
        return out

    direct, refs = read_loot("creature_loot_template"), read_loot("reference_loot_template")
    icols = table_columns(sql, "item_template")
    kept, rejected, quest = {}, collections.Counter(), set()
    for row in table_rows(sql, "item_template"):
        d = dict(zip(icols, row))
        quality = int(d["Quality"])
        if int(d["class"]) == int(QUEST_CLASS):
            rejected["quest"] += 1
            quest.add(int(d["entry"]))
        elif quality not in LOOT_QUALITIES:
            rejected["quality %d" % quality] += 1
        else:
            kept[int(d["entry"])] = (d["name"], quality, int(d["SellPrice"]))
    creatures = {}
    for cid, lid in loot_id.items():
        rows = direct.get(lid, [])
        drops = {}
        for item, (p, mn, mx) in corpse_drops(rows, refs).items():
            if item in kept and p >= LOOT_MIN_CHANCE:
                drops[item] = (p, mn, mx)
        if drops or gold[cid] > 0:
            creatures[cid] = {"gold": gold[cid], "drops": drops}
    used = {item for c in creatures.values() for item in c["drops"]}
    return creatures, {i: kept[i] for i in used}, rejected, {"quest": quest, "kept": kept, "gold": gold}


WOWHEAD_LOOT_MIN_OBS = 30


def apply_wowhead_loot(path, creatures, items, info, wanted):
    data = json.load(open(path, encoding="utf8"))
    npcs = data.get("npcs", {})
    replaced = added_items = skipped_rows = 0
    for cid_text, n in npcs.items():
        cid = int(cid_text)
        if cid not in wanted:
            continue
        drops = {}
        for r in n.get("drops", []):
            count, outof, q = r.get("count"), r.get("outof"), r.get("quality")
            if not isinstance(count, (int, float)) or not isinstance(outof, (int, float)) or outof < WOWHEAD_LOOT_MIN_OBS:
                skipped_rows += 1
                continue
            p = 100.0 * count / outof
            if q not in LOOT_QUALITIES or p < LOOT_MIN_CHANCE or r["id"] in info["quest"]:
                continue
            stack = r.get("stack")
            mn, mx = (int(stack[0]), int(stack[1])) if isinstance(stack, list) and len(stack) >= 2 and stack[0] else (1, 1)
            drops[int(r["id"])] = (min(100.0, p), mn, max(mn, mx))
            if r["id"] not in items:
                meta = info["kept"].get(int(r["id"]))
                items[int(r["id"])] = meta if meta else (r.get("name") or str(r["id"]), q, 0)
                added_items += 1
        creatures[cid] = {"gold": info["gold"].get(cid, 0), "drops": drops, "src": "w"}
        replaced += 1
    return replaced, added_items, skipped_rows


def write_loot_lua(path, items, creatures):
    lines = ["SkinRoute_Loot = {", "  items = {"]
    for item in sorted(items):
        name, quality, sell = items[item]
        lines.append("    [%d] = {%s, %d, %d}," % (item, lua_str(name), quality, sell))
    lines += ["  },", "  creatures = {"]
    for cid in sorted(creatures):
        c = creatures[cid]
        drops = ", ".join("[%d] = {%s, %d, %d}" % (item, num(p), mn, mx) for item, (p, mn, mx) in sorted(c["drops"].items()))
        lines.append("    [%d] = {g = %s, s = %s, d = {%s}}," % (cid, num(c["gold"]), lua_str(c.get("src", "c")), drops))
    lines += ["  },", "}", ""]
    with open(path, "w", encoding="utf8", newline="\n") as f:
        f.write("\n".join(lines))


def load_zone_names(pfquest_dir):
    path = os.path.join(pfquest_dir, "enUS", "zones.lua")
    names = {}
    for m in re.finditer(r'\[(\d+)\] = "((?:[^"\\]|\\.)*)"', read_text(path)):
        names[int(m.group(1))] = re.sub(r"\\(.)", r"\1", m.group(2))
    return names


def load_pfquest_points(pfquest_dir, wanted, zone_names):
    text = read_text(os.path.join(pfquest_dir, "units.lua"))
    points = {}
    bad = 0
    for m in re.finditer(r"^  \[(\d+)\] = \{\n(.*?)^  \},", text, re.M | re.S):
        cid = int(m.group(1))
        if cid not in wanted:
            continue
        zones = collections.defaultdict(list)
        for x, y, z, _ in re.findall(r"\{ (-?[\d.]+), (-?[\d.]+), (\d+), (-?\d+) \}", m.group(2)):
            x, y = float(x), float(y)
            if not (0 <= x <= 100 and 0 <= y <= 100):
                bad += 1
                continue
            zones[zone_names.get(int(z), "Zone %s" % z)].append((x, y))
        if zones:
            points[cid] = dict(zones)
    return points, bad


def load_wowhead(path, zone_names):
    with open(path, encoding="utf8") as f:
        d = json.load(f)
    item_ids, drops, creatures = {}, collections.defaultdict(dict), {}
    if d.get("version") == 3:
        for name, it in d["items"].items():
            item_ids[name] = it["id"]
            for npc, pair in it["drops"].items():
                if pair[1]:
                    drops[name][int(npc)] = pair[0] / pair[1] * 100.0
        for npc, c in d["creatures"].items():
            creatures[int(npc)] = {"name": c["name"], "l1": c["minlevel"], "l2": c["maxlevel"]}
    else:
        for name, it in d["items"].items():
            item_ids[name] = it["id"]
            for r in it.get("npcs", []):
                if r.get("classification") or r.get("boss") or r.get("tag"):
                    continue
                if r.get("outof"):
                    drops[name][r["id"]] = r["count"] / r["outof"] * 100.0
                creatures[r["id"]] = {"name": r["name"], "l1": r["minlevel"], "l2": r["maxlevel"]}
    points = {}
    for npc, n in d["npcs"].items():
        zones = collections.defaultdict(list)
        for z, entries in (n.get("data") or {}).items():
            if isinstance(entries, dict):
                entries = [entries]
            elif not isinstance(entries, list):
                continue
            for e in entries:
                if not isinstance(e, dict):
                    continue
                zname = e.get("uiMapName") or zone_names.get(int(z), "Zone %s" % z)
                for xy in e.get("coords", []):
                    if isinstance(xy, list) and len(xy) >= 2 and 0 <= xy[0] <= 100 and 0 <= xy[1] <= 100:
                        zones[zname].append((xy[0], xy[1]))
        if zones:
            points[int(npc)] = dict(zones)
    return item_ids, drops, creatures, points


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def num(v):
    s = ("%.1f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def write_lua(path, items, creatures, zones):
    lines = ["SkinRoute_Data = {", "  items = {"]
    for item in sorted(items):
        lines.append("    [%d] = %s," % (item, lua_str(items[item])))
    lines += ["  },", "  creatures = {"]
    for cid in sorted(creatures):
        c = creatures[cid]
        drops = ", ".join("[%d] = {%s, %d, %d}" % (item, num(p), mn, mx) for item, (p, mn, mx) in sorted(c["drops"].items()))
        lines.append("    [%d] = {n = %s, l = {%d, %d}, s = %s,%s d = {%s}}," % (cid, lua_str(c["name"]), c["l1"], c["l2"], lua_str(c["src"]), " e = 1," if c.get("elite") else "", drops))
    lines += ["  },", "  zones = {"]
    for zone in sorted(zones):
        lines.append("    [%s] = {" % lua_str(zone))
        for cid in sorted(zones[zone]):
            flat = ", ".join("%s, %s" % (num(x), num(y)) for x, y in zones[zone][cid])
            lines.append("      [%d] = {%s}," % (cid, flat))
        lines.append("    },")
    lines += ["  },", "}", ""]
    with open(path, "w", encoding="utf8", newline="\n") as f:
        f.write("\n".join(lines))


def main(argv=None):
    ap = argparse.ArgumentParser(description="Build the SkinRoute creature data from CMaNGOS, pfQuest and an optional Wowhead export.")
    ap.add_argument("--cmangos", required=True, help="CMaNGOS classic-db SQL dump (.sql or .sql.gz)")
    ap.add_argument("--pfquest", required=True, help="pfQuest db directory (units.lua, enUS/zones.lua)")
    ap.add_argument("--wowhead", help="Wowhead skinning export (wowhead_skinning_all_zones.json or the earlier partial format)")
    ap.add_argument("--out", required=True, help="Lua file to write")
    ap.add_argument("--wowhead-loot", help="Wowhead creature drops export (wowhead_loot_forever.json): replaces the loot of the creatures it lists, with measured rates")
    ap.add_argument("--loot-out", help="Lua file for the corpse loot of the kept creatures (gray, white and green items, gold), read from the CMaNGOS dump")
    ap.add_argument("--skip-zone", action="append", default=[], help="zone name to leave out, repeatable (added to the default list of capitals, battleground and continent maps)")
    ap.add_argument("--ranks", default="0", help="creature ranks kept, comma separated (0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare); elites (1) are written with e = 1 so that SkinRoute can leave them out unless asked")
    args = ap.parse_args(argv)
    ranks = {int(r) for r in args.ranks.split(",")}

    creatures, ranked_out, loot, loot_names, quest_items = load_cmangos(args.cmangos, ranks)
    skip_zones = {z.lower() for z in DEFAULT_SKIP_ZONES + args.skip_zone}
    zone_names = load_zone_names(args.pfquest)
    points, bad = load_pfquest_points(args.pfquest, set(creatures), zone_names)

    items = dict(loot_names)
    final, zones, src_count = {}, collections.defaultdict(dict), collections.Counter()
    no_loot = quest_rows = 0
    for cid, c in creatures.items():
        rows = loot.get(c["loot"], [])
        quest_rows += sum(1 for r in rows if r[0] in quest_items or r[1] < 0)
        d = effective_drops(rows, quest_items)
        if not d:
            no_loot += 1
            continue
        final[cid] = {"name": c["name"], "l1": c["l1"], "l2": c["l2"], "src": "c", "drops": d, "elite": c["elite"]}

    wh_added = wh_zones = 0
    if args.wowhead:
        item_ids, wdrops, wcreatures, wpoints = load_wowhead(args.wowhead, zone_names)
        for name, item in item_ids.items():
            items.setdefault(item, name)
        for cid, info in wcreatures.items():
            if cid in ranked_out:
                continue
            pts = wpoints.get(cid, {})
            if cid in final:
                have = points.get(cid, {})
                extra = {z: p for z, p in pts.items() if z not in have}
                if extra:
                    points.setdefault(cid, {}).update(extra)
                    final[cid]["src"] = "cw"
                    wh_zones += len(extra)
                continue
            d = {}
            for name, per in wdrops.items():
                if cid in per:
                    d[item_ids[name]] = (per[cid], 1, 1)
            if not d or not pts:
                continue
            final[cid] = {"name": info["name"], "l1": info["l1"], "l2": info["l2"], "src": "w", "drops": d}
            points[cid] = pts
            wh_added += 1

    skipped_points, skipped_names = 0, set()
    for cid in list(points):
        kept = {}
        for zone, pts in points[cid].items():
            if zone.lower() in skip_zones:
                skipped_points += len(pts)
                skipped_names.add(zone)
            else:
                kept[zone] = pts
        points[cid] = kept
        if not kept:
            del points[cid]

    no_points = []
    for cid in list(final):
        if cid not in points:
            no_points.append(final[cid]["name"])
            del final[cid]
            continue
        src_count[final[cid]["src"]] += 1
        for zone, pts in points[cid].items():
            zones[zone][cid] = pts
    used_items = {item for c in final.values() for item in c["drops"]}
    items = {i: n for i, n in items.items() if i in used_items}
    write_lua(args.out, items, final, zones)
    if args.loot_out:
        loot, loot_items, rejected, info = load_cmangos_loot(args.cmangos, set(final))
        if args.wowhead_loot:
            replaced, added, skipped = apply_wowhead_loot(args.wowhead_loot, loot, loot_items, info, set(final))
            print("loot: %d creature(s) taken from Wowhead (measured rates), %d item(s) not known to CMaNGOS, %d row(s) under %d observations" % (
                replaced, added, skipped, WOWHEAD_LOOT_MIN_OBS))
        used = {i for c in loot.values() for i in c["drops"]}
        loot_items = {i: m for i, m in loot_items.items() if i in used}
        write_loot_lua(args.loot_out, loot_items, loot)
        print("loot: %d creature(s) with corpse loot of %d, %d item(s) kept (gray, white, green) | left out: %s" % (
            len(loot), len(final), len(loot_items), ", ".join("%s %d" % kv for kv in sorted(rejected.items())) or "none"))
        print("loot: %d creature(s) without any loot table (empty or unknown)" % (len(final) - len(loot)))

    total_points = sum(len(p) for z in zones.values() for p in z.values())
    print("creatures kept: %d (cmangos %d, cmangos + wowhead zones %d, wowhead only %d)" % (
        len(final), src_count["c"], src_count["cw"], src_count["w"]))
    print("ranks filtered out: %d | no loot rows: %d | no points: %d | bad pfQuest coords: %d" % (
        len(ranked_out), no_loot, len(no_points), bad))
    print("wowhead: %d creature(s) added, %d zone(s) filled in" % (wh_added, wh_zones))
    print("quest loot removed: %d row(s), %d quest item(s) | skipped zones: %d point(s) in %d zone(s)" % (
        quest_rows, len(quest_items), skipped_points, len(skipped_names)))
    print("items: %d | zones: %d | points: %d" % (len(items), len(zones), total_points))
    for zone, per in sorted(zones.items(), key=lambda kv: -sum(len(p) for p in kv[1].values()))[:10]:
        print("  %-28s %4d creatures %6d points" % (zone, len(per), sum(len(p) for p in per.values())))
    if no_points:
        print("no points for: %s" % ", ".join(sorted(set(no_points))[:20]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
