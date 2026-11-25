#!/usr/bin/env python3
import io
import json
import os
import sys
import tempfile
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import merge_skinning
from lupa import LuaRuntime

SQL = """
CREATE TABLE `creature_template` (
  `Entry` mediumint unsigned NOT NULL DEFAULT '0',
  `Name` char(100) NOT NULL DEFAULT '',
  `MinLevel` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxLevel` tinyint unsigned NOT NULL DEFAULT '1',
  `Rank` tinyint unsigned NOT NULL DEFAULT '0',
  `SkinningLootId` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`Entry`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
INSERT INTO `creature_template` VALUES (100,'Gray Bear',21,22,0,100),(101,'Elite Bear',30,31,1,101),(102,'Rock',5,5,0,0),(103,'O\\'Brien''s Boar',7,8,0,103),(104,'Lonely Wolf',9,9,0,104),(105,'Group Beast',12,12,0,105),(106,'Capital Rat',3,3,0,106);
CREATE TABLE `skinning_loot_template` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `item` mediumint unsigned NOT NULL DEFAULT '0',
  `ChanceOrQuestChance` float NOT NULL DEFAULT '100',
  `groupid` tinyint unsigned NOT NULL DEFAULT '0',
  `mincountOrRef` mediumint NOT NULL DEFAULT '1',
  `maxcount` tinyint unsigned NOT NULL DEFAULT '1',
  `condition_id` mediumint unsigned NOT NULL DEFAULT '0',
  `comments` varchar(300) DEFAULT '',
  PRIMARY KEY (`entry`,`item`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
INSERT INTO `skinning_loot_template` VALUES (100,2318,40,1,1,2,0,'Light Leather'),(100,2934,60,1,1,1,0,'Ruined Leather Scraps'),(101,2318,100,1,1,1,0,'Light Leather'),(103,2318,100,0,1,1,0,'Light Leather'),(104,2318,100,1,1,1,0,'Light Leather'),(105,2318,30,1,1,1,0,'Light Leather'),(105,2934,0,1,1,1,0,'Ruined Leather Scraps'),(105,783,0,1,1,1,0,'Light Hide'),(100,9999,10,1,1,1,0,'Quest Skin'),(105,9998,-100,1,1,1,0,'Quest Neg'),(106,2318,100,0,1,1,0,'Light Leather');
INSERT INTO `item_template` VALUES (2318,7,0,'Light Leather',1,0),(2934,7,0,'Ruined Leather Scraps',1,0),(783,7,0,'Light Hide',1,0),(9999,12,0,'Quest Skin',1,0);
"""

UNITS = """pfDB["units"]["data"] = {
  [100] = {
    ["coords"] = {
      [1] = { 46.2, 9.3, 267, 300 },
      [2] = { 50, 60, 14, 25 },
    },
    ["lvl"] = "21-22",
  },
  [101] = {
    ["coords"] = {
      [1] = { 10, 10, 267, 300 },
    },
    ["lvl"] = "30-31",
  },
  [103] = {
    ["coords"] = {
      [1] = { 10, 20, 490, 300 },
      [2] = { 5, 5, 1637, 300 },
    },
    ["lvl"] = "7-8",
  },
  [106] = {
    ["coords"] = {
      [1] = { 30, 30, 1637, 300 },
      [2] = { 31, 31, 1637, 300 },
    },
    ["lvl"] = "3",
  },
  [105] = {
    ["coords"] = {
      [1] = { 150, 20, 12, 300 },
      [2] = { 5, 5.5, 12, 30 },
    },
    ["lvl"] = "12",
  },
}
"""

ZONES = """pfDB["zones"]["enUS"] = {
  [12] = "Elwynn Forest",
  [14] = "Durotar",
  [267] = "Hillsbrad Foothills",
  [490] = "Un\\'Goro Crater",
  [1637] = "Orgrimmar",
}
"""

LEGACY = {
    "items": {"Light Leather": {"id": 2318, "npcs": [
        {"id": 200, "name": "Wowhead Bat", "minlevel": 24, "maxlevel": 26, "classification": 0, "count": 60, "outof": 100},
        {"id": 201, "name": "Rare One", "minlevel": 25, "maxlevel": 25, "classification": 4, "count": 50, "outof": 100},
        {"id": 100, "name": "Gray Bear", "minlevel": 21, "maxlevel": 22, "classification": 0, "count": 40, "outof": 100},
        {"id": 202, "name": "Odd Shape", "minlevel": 10, "maxlevel": 11, "classification": 0, "count": 50, "outof": 100},
    ]}},
    "npcs": {
        "200": {"data": {"267": [{"coords": [[10.5, 20.1], [11, 21]], "uiMapName": "Hillsbrad Foothills"}]}},
        "201": {"data": {"267": [{"coords": [[1, 1]], "uiMapName": "Hillsbrad Foothills"}]}},
        "202": {"data": {"267": {"coords": [[7, 8]], "uiMapName": "Hillsbrad Foothills"}, "5": "oops", "6": None}},
        "100": {"data": {"267": [{"coords": [[9, 9]], "uiMapName": "Hillsbrad Foothills"}],
                         "999": [{"coords": [[33, 44]], "uiMapName": "Riverglades"}]}},
    },
}

V3 = {
    "version": 3,
    "items": {"Light Leather": {"id": 2318, "drops": {"200": [60, 100], "100": [40, 100], "202": [50, 100]}}},
    "creatures": {"200": {"name": "Wowhead Bat", "minlevel": 24, "maxlevel": 26},
                  "100": {"name": "Gray Bear", "minlevel": 21, "maxlevel": 22},
                  "202": {"name": "Odd Shape", "minlevel": 10, "maxlevel": 11}},
    "npcs": LEGACY["npcs"],
}


def build(tmp, wowhead=None, ranks="0", extra=None):
    paths = {}
    paths["sql"] = os.path.join(tmp, "db.sql")
    with open(paths["sql"], "w", encoding="utf8") as f:
        f.write(SQL)
    pf = os.path.join(tmp, "pf")
    os.makedirs(os.path.join(pf, "enUS"), exist_ok=True)
    with open(os.path.join(pf, "units.lua"), "w", encoding="utf8") as f:
        f.write(UNITS)
    with open(os.path.join(pf, "enUS", "zones.lua"), "w", encoding="utf8") as f:
        f.write(ZONES)
    out = os.path.join(tmp, "out.lua")
    argv = ["--cmangos", paths["sql"], "--pfquest", pf, "--out", out, "--ranks", ranks] + (extra or [])
    if wowhead is not None:
        w = os.path.join(tmp, "wh.json")
        with open(w, "w", encoding="utf8") as f:
            json.dump(wowhead, f)
        argv += ["--wowhead", w]
    buf = io.StringIO()
    with redirect_stdout(buf):
        merge_skinning.main(argv)
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(open(out, encoding="utf8").read())
    return L.eval("SkinRoute_Data"), buf.getvalue()


LOOT_SQL = """
CREATE TABLE `creature_template` (
  `Entry` mediumint unsigned NOT NULL DEFAULT '0',
  `Name` char(100) NOT NULL DEFAULT '',
  `MinLootGold` mediumint unsigned NOT NULL DEFAULT '0',
  `MaxLootGold` mediumint unsigned NOT NULL DEFAULT '0',
  `LootId` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`Entry`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
INSERT INTO `creature_template` VALUES (200,'Looter',100,300,200),(201,'Empty',0,0,0),(202,'Gold Only',50,50,201),(203,'Unlisted',9,9,203);
CREATE TABLE `creature_loot_template` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `item` mediumint unsigned NOT NULL DEFAULT '0',
  `ChanceOrQuestChance` float NOT NULL DEFAULT '100',
  `groupid` tinyint unsigned NOT NULL DEFAULT '0',
  `mincountOrRef` mediumint NOT NULL DEFAULT '1',
  `maxcount` tinyint unsigned NOT NULL DEFAULT '1',
  `condition_id` mediumint unsigned NOT NULL DEFAULT '0',
  `comments` varchar(300) DEFAULT '',
  PRIMARY KEY (`entry`,`item`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
INSERT INTO `creature_loot_template` VALUES (200,1000,40,0,1,2,0,''),(200,1001,10,0,1,1,0,''),(200,1002,20,0,1,1,0,''),(200,1003,100,0,1,1,0,''),(200,500,20,0,-50,2,0,''),(200,1006,0,1,1,1,0,''),(200,1007,0,1,1,1,0,''),(200,1008,0.1,0,1,1,0,'');
CREATE TABLE `reference_loot_template` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `item` mediumint unsigned NOT NULL DEFAULT '0',
  `ChanceOrQuestChance` float NOT NULL DEFAULT '100',
  `groupid` tinyint unsigned NOT NULL DEFAULT '0',
  `mincountOrRef` mediumint NOT NULL DEFAULT '1',
  `maxcount` tinyint unsigned NOT NULL DEFAULT '1',
  `condition_id` mediumint unsigned NOT NULL DEFAULT '0',
  `comments` varchar(300) DEFAULT '',
  PRIMARY KEY (`entry`,`item`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
INSERT INTO `reference_loot_template` VALUES (50,1004,100,0,1,1,0,''),(50,1005,50,0,1,1,0,'');
CREATE TABLE `item_template` (
  `entry` mediumint unsigned NOT NULL DEFAULT '0',
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  `subclass` tinyint unsigned NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL DEFAULT '',
  `Quality` tinyint unsigned NOT NULL DEFAULT '0',
  `SellPrice` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
INSERT INTO `item_template` VALUES (1000,15,0,'Gray Junk',0,25),(1001,7,0,'White Cloth',1,40),(1002,2,0,'Blue Sword',3,900),(1003,12,0,'Quest Thing',1,0),(1004,4,0,'Green Boots',2,500),(1005,4,0,'Green Cape',2,300),(1006,7,0,'Green Mote A',2,10),(1007,7,0,'Green Mote B',2,12),(1008,15,0,'Rare Gray',0,5);
"""


def check_loot(tmp):
    path = os.path.join(tmp, "loot.sql")
    with open(path, "w", encoding="utf8") as f:
        f.write(LOOT_SQL)
    creatures, items, rejected, info = merge_skinning.load_cmangos_loot(path, {200, 201, 202})
    assert sorted(creatures) == [200, 202], sorted(creatures)
    c = creatures[200]
    assert c["gold"] == 200
    d = c["drops"]
    assert d[1000] == (40, 1, 2) and d[1001][0] == 10
    assert 1002 not in d and 1003 not in d and 1008 not in d, d
    assert abs(d[1004][0] - 40) < 1e-6 and abs(d[1005][0] - 20) < 1e-6, d
    assert abs(d[1006][0] - 50) < 1e-6 and abs(d[1007][0] - 50) < 1e-6
    assert creatures[202]["drops"] == {} and creatures[202]["gold"] == 50
    assert items[1004] == ("Green Boots", 2, 500) and 1002 not in items and 1003 not in items
    assert rejected["quality 3"] == 1 and rejected["quest"] == 1, rejected
    out = os.path.join(tmp, "loot.lua")
    merge_skinning.write_loot_lua(out, items, creatures)
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(open(out, encoding="utf8").read())
    assert L.eval("SkinRoute_Loot.items[1000][2]") == 0 and L.eval("SkinRoute_Loot.items[1000][3]") == 25
    assert L.eval("SkinRoute_Loot.creatures[200].g") == 200 and L.eval("SkinRoute_Loot.creatures[200].d[1004][1]") == 40
    assert L.eval("SkinRoute_Loot.creatures[203]") is None
    wh = os.path.join(tmp, "wh_loot.json")
    with open(wh, "w", encoding="utf8") as f:
        json.dump({"npcs": {
            "200": {"drops": [
                {"id": 1001, "name": "White Cloth", "quality": 1, "count": 20, "outof": 100, "stack": [1, 3]},
                {"id": 1002, "name": "Blue Sword", "quality": 3, "count": 50, "outof": 100, "stack": [1, 1]},
                {"id": 1003, "name": "Quest Thing", "quality": 1, "count": 90, "outof": 100, "stack": [1, 1]},
                {"id": 2000, "name": "Forever Trinket", "quality": 2, "count": 5, "outof": 200, "stack": [1, 1]},
                {"id": 2001, "name": "Few Samples", "quality": 1, "count": 3, "outof": 10, "stack": [1, 1]},
                {"id": 2002, "name": "Rare Drop", "quality": 1, "count": 1, "outof": 1000, "stack": [1, 1]},
            ]},
            "555": {"drops": [{"id": 1000, "name": "Gray Junk", "quality": 0, "count": 400, "outof": 500, "stack": None}]},
            "777": {"drops": []},
        }}, f)
    replaced, added, skipped = merge_skinning.apply_wowhead_loot(wh, creatures, items, info, {200, 555})
    assert replaced == 2 and skipped == 1 and added == 1, (replaced, added, skipped)
    d200 = creatures[200]["drops"]
    assert sorted(d200) == [1001, 2000], d200
    assert d200[1001] == (20.0, 1, 3) and abs(d200[2000][0] - 2.5) < 1e-9
    assert creatures[200]["gold"] == 200 and creatures[200]["src"] == "w", "gold stays from CMaNGOS"
    assert creatures[555]["gold"] == 0 and creatures[555]["drops"][1000] == (80.0, 1, 1)
    assert items[2000] == ("Forever Trinket", 2, 0) and items[1001][2] == 40
    assert 777 not in creatures
    out2 = os.path.join(tmp, "loot2.lua")
    merge_skinning.write_loot_lua(out2, items, creatures)
    L2 = LuaRuntime(unpack_returned_tuples=True)
    L2.execute(open(out2, encoding="utf8").read())
    assert L2.eval("SkinRoute_Loot.creatures[200].s") == "w" and L2.eval("SkinRoute_Loot.creatures[202].s") == "c"
    rows = {1: (1, 1)}
    refs = {7: [(1, 100.0, 0, 1, 1)]}
    got = merge_skinning.corpse_drops([(5, 100.0, 0, -7, 9)], refs)
    assert got[1][0] == 100.0, got


def keys(t):
    return sorted(list(t.keys()))


def flat(t):
    return list(t.values())


def check_base(tmp):
    d, report = build(tmp)
    assert keys(d.creatures) == [100, 103, 105], keys(d.creatures)
    bear = d.creatures[100]
    assert bear.n == "Gray Bear" and bear.l[1] == 21 and bear.l[2] == 22 and bear.s == "c"
    assert bear.d[2318][1] == 40 and bear.d[2318][2] == 1 and bear.d[2318][3] == 2
    assert bear.d[2934][1] == 60
    assert d.creatures[103].n == "O'Brien's Boar"
    group = d.creatures[105].d
    assert abs(group[2318][1] - 30) < 0.01 and abs(group[2934][1] - 35) < 0.01 and abs(group[783][1] - 35) < 0.01
    assert keys(d.zones) == ["Durotar", "Elwynn Forest", "Hillsbrad Foothills", "Un'Goro Crater"], keys(d.zones)
    assert flat(d.zones["Hillsbrad Foothills"][100]) == [46.2, 9.3]
    assert flat(d.zones["Elwynn Forest"][105]) == [5, 5.5]
    assert 104 not in keys(d.creatures) and 101 not in keys(d.creatures) and 102 not in keys(d.creatures)
    assert d["items"][2318] == "Light Leather" and d["items"][783] == "Light Hide"
    assert "no points: 2" in report and "ranks filtered out: 1" in report and "bad pfQuest coords: 1" in report, report
    assert "quest loot removed: 2 row(s), 1 quest item(s)" in report and "skipped zones: 3 point(s) in 1 zone(s)" in report, report
    assert 9999 not in keys(bear.d) and 9998 not in keys(group) and 9999 not in keys(d["items"]) and 9998 not in keys(d["items"])
    assert "Orgrimmar" not in keys(d.zones) and 106 not in keys(d.creatures) and 103 in keys(d.creatures)


def check_skip_zone(tmp):
    d, report = build(tmp, extra=["--skip-zone", "elwynn forest"])
    assert "Elwynn Forest" not in keys(d.zones) and 105 not in keys(d.creatures), keys(d.zones)
    assert "skipped zones: 4 point(s) in 2 zone(s)" in report, report
    assert 100 in keys(d.creatures)


def check_ranks(tmp):
    d, _ = build(tmp, ranks="0,1")
    assert 101 in keys(d.creatures) and d.creatures[101].l[1] == 30
    assert d.creatures[101].e == 1 and d.creatures[100].e is None, "elites are flagged, normal creatures are not"


def check_wowhead(tmp, data):
    d, report = build(tmp, wowhead=data)
    assert 200 in keys(d.creatures) and d.creatures[200].s == "w", keys(d.creatures)
    assert d.creatures[200].d[2318][1] == 60
    assert flat(d.zones["Hillsbrad Foothills"][200]) == [10.5, 20.1, 11, 21]
    assert flat(d.zones["Hillsbrad Foothills"][202]) == [7, 8]
    assert 201 not in keys(d.creatures)
    bear = d.creatures[100]
    assert bear.s == "cw" and bear.d[2318][1] == 40
    assert flat(d.zones["Hillsbrad Foothills"][100]) == [46.2, 9.3], "pfQuest points must not be duplicated"
    assert flat(d.zones["Riverglades"][100]) == [33, 44]
    assert "2 creature(s) added, 1 zone(s) filled in" in report, report


def main():
    for name, fn in [("base", lambda t: check_base(t)), ("ranks", lambda t: check_ranks(t)), ("skip zone", lambda t: check_skip_zone(t)),
                     ("loot", lambda t: check_loot(t)), ("wowhead legacy", lambda t: check_wowhead(t, LEGACY)), ("wowhead v3", lambda t: check_wowhead(t, V3))]:
        with tempfile.TemporaryDirectory() as tmp:
            fn(tmp)
    print("MERGE SKINNING TESTS OK")


if __name__ == "__main__":
    main()
