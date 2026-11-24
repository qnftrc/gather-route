#!/usr/bin/env python3
import os
import re
import sys

from lupa import LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

FIXTURE = r'''
SkinRoute_Data = {
  items = {[2318] = "Light Leather", [2319] = "Medium Leather", [4234] = "Heavy Leather"},
  creatures = {
    [1] = {n = "Gray Bear", l = {21, 22}, s = "c", d = {[2318] = {40, 1, 2}, [2319] = {50, 1, 1}}},
    [2] = {n = "Mountain Lion", l = {30, 31}, s = "c", d = {[2319] = {73, 1, 1}, [4234] = {20, 1, 1}}},
    [3] = {n = "Rat", l = {1, 1}, s = "c", d = {[2318] = {10, 1, 1}}},
    [4] = {n = "Gryphon", l = {40, 40}, s = "c", d = {[4234] = {78, 1, 1}}},
  },
  zones = {
    ["Hillsbrad Foothills"] = {
      [1] = {1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10},
      [2] = {1, 1, 2, 2, 3, 3, 4, 4, 5, 5},
      [3] = {1, 1, 2, 2, 3, 3},
      [4] = {50, 50},
    },
    ["Elwynn Forest"] = {[3] = {1, 1, 2, 2, 3, 3, 4, 4}, [1] = {9, 9, 8, 8}},
    ["Un'Goro Crater"] = {[4] = {1, 1, 2, 2}},
  },
}
'''

MOCK = r'''
printed = {}
print = function(...) printed[#printed + 1] = table.concat({...}, " ") end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
SlashCmdList = {}
level = 21
UnitLevel = function() return level end
frames = {}
CreateFrame = function()
    local f = {scripts = {}}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    frames[#frames + 1] = f
    return f
end
playerMap, px, py = 25, 0.4, 0.6
mapParents = {[99] = 25}
C_Map = {GetMapInfo = function(id) return {parentMapID = mapParents[id] or 0} end}
TomTom = {NameToMapId = {["Hillsbrad Foothills"] = 25, ["Elwynn Forest"] = 37}}
function TomTom:GetCurrentPlayerPosition() return playerMap, px, py end
function Said() local s = table.concat(printed, "\n"); printed = {}; return s end
function Slash(msg) SlashCmdList.SKINROUTE(msg) return Said() end
'''

LOAD = r'''
SR = {}
for _, f in ipairs({"Core", "Resolver", "Rules"}) do
    local fh = assert(io.open(ROOT .. "/SkinRoute/" .. f .. ".lua"))
    local src = fh:read("a")
    fh:close()
    assert(load(src, f))("SkinRoute", SR)
end
frames[1].scripts.OnEvent(frames[1], "ADDON_LOADED", "SkinRoute")
'''


def env(data=FIXTURE):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = ROOT
    lua.execute(MOCK)
    if data:
        lua.execute(data)
    lua.execute(LOAD)
    return lua


def lines(lua, code):
    return str(lua.eval("(function() " + code + " end)()"))


def check_rules():
    lua = env()
    lua.execute(r'''
    local R = SR.Rules
    for level = 1, 70 do
        for skill = 0, 300 do
            assert(R.canSkin(skill, level) == (skill >= R.minSkill(level)), "rule mismatch at level " .. level .. " skill " .. skill)
        end
    end
    assert(R.minSkill(5) == 0 and R.minSkill(10) == 0 and R.minSkill(11) == 10 and R.minSkill(15) == 50 and R.minSkill(19) == 90)
    assert(R.minSkill(20) == 100 and R.minSkill(30) == 150 and R.minSkill(32) == 160)
    local c = {l = {21, 22}}
    assert(R.inBand(c, 24, -8, 2) and R.inBand(c, 30, -8, 2) and not R.inBand(c, 31, -8, 2) and R.inBand(c, 19, 0, 2) and not R.inBand(c, 19, 4, 6))
    assert(R.difficulty(29, 24) == "red" and R.difficulty(28, 24) == "orange" and R.difficulty(27, 24) == "orange")
    assert(R.difficulty(26, 24) == "yellow" and R.difficulty(22, 24) == "yellow" and R.difficulty(21, 24) == "green")
    assert(R.difficulty(17, 24) == "green" and R.difficulty(16, 24) == "gray")
    ''')


def ctx(lua, level, skill, items, prices=None, band=True):
    lua.globals().CTX_ITEMS = lua.table_from(items)
    lua.globals().CTX_LEVEL = level
    lua.globals().CTX_SKILL = skill
    lua.globals().CTX_BAND = band
    lua.execute(r'''
    local set = {}
    for _, id in ipairs(CTX_ITEMS) do set[id] = true end
    TESTCTX = {level = CTX_LEVEL, skill = CTX_SKILL, lo = -8, hi = 2, bandOnly = CTX_BAND, items = set,
        price = function(id) return TESTPRICES and TESTPRICES[id] end}
    ''')


def check_evaluate():
    lua = env()
    lua.execute("TESTPRICES = {[2319] = 3420}")
    ctx(lua, 24, 140, [2319])
    lua.execute(r'''
    local h = SR:EvaluateRegion("Hillsbrad Foothills", TESTCTX)
    assert(h.status == "ok" and h.total == 15 and h.inBand == 10 and h.skinnable == 10 and h.percent == 100, h.status)
    assert(math.abs(h.drops - 5) < 1e-9 and math.abs(h.value - 17100) < 1e-6 and h.lmin == 21 and h.lmax == 22 and h.minNeeded == 110)
    local e = SR:EvaluateRegion("Elwynn Forest", TESTCTX)
    assert(e.status == "ok" and e.skinnable == 2 and math.abs(e.value - 3420) < 1e-6)
    assert(SR:EvaluateRegion("Un'Goro Crater", TESTCTX).status == "empty")
    ''')
    ctx(lua, 24, 100, [2319])
    lua.execute(r'''
    local h = SR:EvaluateRegion("Hillsbrad Foothills", TESTCTX)
    assert(h.status == "locked" and h.skinnable == 0 and h.minNeeded == 110 and h.value == 0, h.status)
    ''')
    ctx(lua, 30, 120, [2319])
    lua.execute(r'''
    local h = SR:EvaluateRegion("Hillsbrad Foothills", TESTCTX)
    assert(h.status == "partial" and h.inBand == 15 and h.skinnable == 10, h.status)
    assert(math.abs(h.percent - 100 * 10 / 15) < 1e-9 and math.abs(h.value - 17100) < 1e-6 and h.lmin == 21 and h.lmax == 31)
    ''')
    ctx(lua, 10, 300, [2319], band=False)
    lua.execute(r'''
    local h = SR:EvaluateRegion("Hillsbrad Foothills", TESTCTX)
    assert(h.status == "ok" and h.inBand == 15 and math.abs(h.value - (17100 + 5 * 0.73 * 3420)) < 1e-6)
    assert(math.abs(h.avgLevel - (10 * 21.5 + 5 * 30.5) / 15) < 1e-9)
    ''')
    ctx(lua, 40, 300, [2319])
    lua.execute(r'''
    local h = SR:EvaluateRegion("Hillsbrad Foothills", TESTCTX)
    assert(h.status == "out" and h.lmin == 21 and h.lmax == 31 and h.skinnable == 0, h.status)
    ''')
    ctx(lua, 24, None, [2319])
    lua.execute(r'''
    local h = SR:EvaluateRegion("Hillsbrad Foothills", TESTCTX)
    assert(h.status == "ok" and h.skinnable == 10, "unknown skill must not limit")
    ''')


def check_ranking():
    lua = env()
    lua.execute("TESTPRICES = {[2319] = 3420}")
    ctx(lua, 24, 140, [2319])
    lua.execute(r'''
    local ranked, hidden, anyPrice = SR:RankRegions(TESTCTX)
    assert(#ranked == 2 and hidden == 1 and anyPrice == true)
    assert(ranked[1].region == "Hillsbrad Foothills" and ranked[2].region == "Elwynn Forest")
    ''')
    ctx(lua, 24, 100, [2319])
    lua.execute(r'''
    local ranked = SR:RankRegions(TESTCTX)
    assert(#ranked == 2 and ranked[1].region == "Elwynn Forest" and ranked[2].region == "Hillsbrad Foothills" and ranked[1].eval.status == "locked")
    ''')
    lua.execute("TESTPRICES = nil")
    ctx(lua, 24, 300, [2318])
    lua.execute(r'''
    local ranked, hidden, anyPrice = SR:RankRegions(TESTCTX)
    assert(anyPrice == false and ranked[1].region == "Hillsbrad Foothills" and math.abs(ranked[1].eval.drops - 6) < 1e-9)
    assert(math.abs(ranked[2].eval.drops - 1.2) < 1e-9)
    ''')
    ctx(lua, 24, 140, [2319])
    lua.execute(r'''
    TESTPRICES = {[2319] = 3420}
    local open = SR:RankRegions(TESTCTX)
    local mixed = {}
    for _, row in ipairs(open) do mixed[#mixed + 1] = row.region end
    assert(table.concat(mixed, ",") == "Hillsbrad Foothills,Elwynn Forest")
    ''')


def check_slash():
    lua = env()
    out = lines(lua, 'return Slash("")')
    assert "/sr regions" in out and "/sr level" in out
    assert "Select items first" in lines(lua, 'return Slash("regions")')
    assert "Items: Medium Leather" in lines(lua, 'return Slash("items medium leather")')
    assert lua.eval("#SR.db.items") == 1
    out = lines(lua, 'return Slash("items leather")')
    assert lua.eval("#SR.db.items") == 3 and "Heavy Leather" in out and "Light Leather" in out
    assert "Not found: nothing" in lines(lua, 'return Slash("items nothing")')
    lines(lua, 'return Slash("items medium leather")')
    assert "Level: 24 (simulated" in lines(lua, 'return Slash("level 24")')
    assert "Skinning skill: 140 (simulated" in lines(lua, 'return Slash("skill 140")')
    assert "1g 71s 0c" not in lines(lua, 'return Slash("price")')
    assert "Medium Leather: 34s 20c" in lines(lua, 'return Slash("price medium leather: 3420")')
    out = lines(lua, 'return Slash("regions")')
    assert "Level 24 (simulated)" in out and "skinning 140 (simulated)" in out and "mobs from level 16 to 26" in out, out
    rows = [l for l in out.split("\n") if re.match(r"^\S*SkinRoute\S*: \d\.", l)]
    assert len(rows) == 2 and "1. Hillsbrad Foothills" in rows[0] and "2. Elwynn Forest" in rows[1], out
    assert "|cff40c040Lv 21-22|r" in rows[0] and "1g 71s 0c" in rows[0] and "10 mobs" in rows[0], rows[0]
    assert "needs skinning 150" in lines(lua, 'return Slash("need 30")')
    out = lines(lua, 'return Slash("skill 100")')
    out = lines(lua, 'return Slash("regions")')
    assert "needs skinning 110" in out and "|cffff8040" in out, out
    assert "unknown" in lines(lua, 'return Slash("skill auto")')
    out = lines(lua, 'return Slash("band 5 -3")')
    assert "from level -3 to +5" in out, out
    assert "off" in lines(lua, 'return Slash("band off")')
    assert "Usage: /sr band" in lines(lua, 'return Slash("band abc")')
    assert "Hillsbrad Foothills: " in lines(lua, 'return Slash("region hills")')
    assert "Several regions match" in lines(lua, 'return Slash("region o")')
    assert "Unknown region" in lines(lua, 'return Slash("region zzz")')
    assert "Usage: /sr level" in lines(lua, 'return Slash("level abc")')
    assert "off" in lines(lua, 'return Slash("chat")')
    lua.execute('SR:Print("silent")')
    assert lines(lua, "return Said()") == ""
    assert "on" in lines(lua, 'return Slash("chat on")')
    lua.execute('SR:Print("loud")')
    assert "loud" in lines(lua, "return Said()")
    assert "Unknown command" in lines(lua, 'return Slash("frobnicate")')


def check_resolver():
    lua = env()
    lua.execute("SR:BuildMaps()")
    assert lua.eval("SR:GetRegionMapID('Hillsbrad Foothills')") == 25
    assert lua.eval("SR:GetRegionMapID(\"Un'Goro Crater\")") is None
    assert lua.eval("#SR.unresolved") == 1
    assert lua.eval("(SR:GetCurrentRegion())") == "Hillsbrad Foothills"
    lua.execute("playerMap = 99")
    assert lua.eval("(SR:GetCurrentRegion())") == "Hillsbrad Foothills"
    lua.execute("playerMap = 500")
    assert lua.eval("(SR:GetCurrentRegion())") is None
    out = lines(lua, 'return Slash("debug")')
    assert "2/3 regions resolved" in out and "Unresolved: Un'Goro Crater" in out, out
    assert "-> map 78" in lines(lua, "return Slash(\"setmap un'goro: 78\")")
    assert lua.eval("SR:GetRegionMapID(\"Un'Goro Crater\")") == 78
    assert lua.eval("SR.db.overrides[\"Un'Goro Crater\"]") == 78
    assert lua.eval("SR:FindRegion('elwynn')") == "Elwynn Forest"
    assert lua.eval("SR:FindRegion('ungoro')") == "Un'Goro Crater"


def check_missing_data():
    lua = env(data=None)
    assert lua.eval("SR.dataMissing") is True and lua.eval("#SR.regionNames") == 0
    assert "Select items first" in lines(lua, 'return Slash("regions")')
    assert "Not found: leather" in lines(lua, 'return Slash("items leather")')


def check_lua51_constructs():
    forbidden = [(r"\bgoto\b", "goto"), (r"//", "//"), (r"<<|>>", "shift"), (r"\s&\s", "bit and"), (r"\s\|\s", "bit or"), (r"::", "label")]
    folder = os.path.join(ROOT, "SkinRoute")
    for name in os.listdir(folder):
        if not name.endswith(".lua"):
            continue
        text = open(os.path.join(folder, name), encoding="utf8").read()
        text = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
        for pattern, label in forbidden:
            assert not re.search(pattern, text), "%s: %s is not Lua 5.1" % (name, label)


def check_real_data(path):
    lua = env(data=open(path, encoding="utf8").read())
    out = lines(lua, 'return Slash("items medium leather, heavy leather")')
    assert "Medium Leather" in out and "Heavy Leather" in out, out
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    out = lines(lua, 'return Slash("regions 5")')
    assert "1. " in out, out
    return out


def main():
    check_rules()
    check_evaluate()
    check_ranking()
    check_slash()
    check_resolver()
    check_missing_data()
    check_lua51_constructs()
    real = os.environ.get("SKINROUTE_DATA")
    if real:
        print(check_real_data(real))
    print("SKINROUTE TESTS OK")


if __name__ == "__main__":
    main()
