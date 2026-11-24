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

ZONE_FIXTURE = r'''
SkinRoute_Data = {
  items = {[2318] = "Light Leather", [2319] = "Medium Leather", [4234] = "Heavy Leather"},
  creatures = {
    [1] = {n = "Gray Bear", l = {21, 22}, s = "c", d = {[2318] = {40, 1, 2}, [2319] = {50, 1, 1}}},
    [2] = {n = "Mountain Lion", l = {30, 31}, s = "c", d = {[2319] = {73, 1, 1}, [4234] = {20, 1, 1}}},
    [3] = {n = "Rat", l = {1, 1}, s = "c", d = {[2318] = {10, 1, 1}}},
  },
  zones = {
    ["Test Valley"] = {
      [1] = {19, 19, 20, 19, 21, 19, 19, 20, 20, 20, 21, 20, 19, 21, 20, 21, 21, 21, 20, 22},
      [2] = {80, 80, 81, 80, 80, 81, 81, 81, 79, 80, 80, 79},
      [3] = {20, 80, 21, 80},
    },
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
now = 0
GetTime = function() return now end
timers = {}
C_Timer = {After = function(d, f) timers[#timers + 1] = f end}
function RunTimers()
    local n = 0
    while #timers > 0 and n < 100000 do
        local f = table.remove(timers, 1)
        f()
        n = n + 1
    end
    return n
end
hooksecurefunc = function() end
local function newObject(kind)
    local o = {kind = kind, shown = false, scripts = {}, hooks = {}, children = {}}
    function o:RegisterEvent() end
    function o:UnregisterEvent() end
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:HookScript(name, fn) self.hooks[name] = fn end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetColorTexture(r, g, b, a) self.color = {r, g, b, a} end
    function o:SetThickness(t) self.thickness = t end
    function o:SetStartPoint(_, _, x, y) self.sx, self.sy = x, y end
    function o:SetEndPoint(_, _, x, y) self.ex, self.ey = x, y end
    function o:SetText(t) self.text = t end
    function o:SetTextColor(r, g, b) self.textColor = {r, g, b} end
    function o:SetPoint(_, _, _, x, y) self.px, self.py = x, y end
    function o:GetWidth() return 1000 end
    function o:GetHeight() return 667 end
    function o:GetCanvas() return self.canvas end
    function o:CreateLine() local c = newObject("line") self.children[#self.children + 1] = c return c end
    function o:CreateFontString() local c = newObject("fontstring") self.children[#self.children + 1] = c return c end
    function o:CreateTexture() local c = newObject("texture") self.children[#self.children + 1] = c return c end
    return setmetatable(o, {__index = function() return function() end end})
end
CreateFrame = function(kind, name, parent)
    local o = newObject(kind)
    o.parent = parent
    frames[#frames + 1] = o
    return o
end
mapOpen, mapShown = false, 0
WorldMapFrame = newObject("map")
WorldMapFrame.canvas = newObject("canvas")
function WorldMapFrame:IsShown() return mapOpen end
function WorldMapFrame:GetMapID() return mapShown end
playerMap, px, py = 25, 0.4, 0.6
mapParents = {[99] = 25}
mapNames = {[77] = "Test Valley"}
C_Map = {GetMapInfo = function(id) return {parentMapID = mapParents[id] or 0, name = mapNames[id]} end}
TomTom = {NameToMapId = {["Hillsbrad Foothills"] = 25, ["Elwynn Forest"] = 37}}
gamepad = false
function TomTom:GetCurrentPlayerPosition() return playerMap, px, py end
function TomTom:IsGamepadUI() return gamepad end
hbdAvailable = true
HBD = {}
function HBD:GetWorldCoordinatesFromZone(x, y, map) return x * 2000, y * 1000, 1 end
LibStub = function(name) if name == "HereBeDragons-2.0" and hbdAvailable then return HBD end end
function Said() local s = table.concat(printed, "\n"); printed = {}; return s end
function Slash(msg) SlashCmdList.SKINROUTE(msg) return Said() end
'''

LOAD = r'''
SR = {}
for _, f in ipairs({"Core", "Resolver", "Rules", "Zones", "Overlay"}) do
    local fh = assert(io.open(ROOT .. "/SkinRoute/" .. f .. ".lua"))
    local src = fh:read("a")
    fh:close()
    assert(load(src, f))("SkinRoute", SR)
end
frames[1].scripts.OnEvent(frames[1], "ADDON_LOADED", "SkinRoute")
'''


HELPERS = r'''
function MapFrame()
    for _, f in ipairs(frames) do if f.parent == WorldMapFrame.canvas then return f end end
end
function Shown(kind)
    local mf, n = MapFrame(), 0
    if not mf then return 0 end
    for _, c in ipairs(mf.children) do if c.kind == kind and c.shown then n = n + 1 end end
    return n
end
function LineAt(n)
    local k = 0
    for _, c in ipairs(MapFrame().children) do
        if c.kind == "line" then
            k = k + 1
            if k == n then return c end
        end
    end
end
function ShownTexts()
    local out = {}
    for _, c in ipairs(MapFrame().children) do if c.kind == "fontstring" and c.shown then out[#out + 1] = c.text end end
    return table.concat(out, "|")
end
'''


def env(data=FIXTURE, pre=""):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = ROOT
    lua.execute(MOCK)
    lua.execute(pre)
    if data:
        lua.execute(data)
    lua.execute(LOAD)
    lua.execute(HELPERS)
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


def check_zone_compute():
    lua = env()
    lua.execute(r"""
    local Z = SR.Zones
    local function cluster(points, cid, cx, cy, n)
        for k = 1, n do
            points[#points + 1] = {wx = cx + ((k * 37) % 11 - 5) * 10, wy = cy + ((k * 53) % 13 - 6) * 8, x = 0, y = 0, cid = cid}
        end
    end
    local pts = {}
    cluster(pts, 1, 0, 0, 10)
    cluster(pts, 2, 1000, 0, 6)
    cluster(pts, 3, 0, 1000, 3)
    local zones, left = Z.compute(pts, 233, 5, 12, nil)
    assert(#zones == 2 and zones[1].n == 10 and zones[2].n == 6 and left == 3, #zones)
    assert(math.abs(zones[1].wx) < 60 and math.abs(zones[1].wy) < 60 and zones[2].wx > 940 and zones[2].wx < 1060)
    assert(zones[1].id == 1 and zones[2].id == 2 and zones[1].entries[1].id == 1 and zones[1].entries[1].n == 10)
    assert(Z.lastOps > 0)

    local merged, mleft = Z.compute(pts, 1200, 1, 12, nil)
    assert(#merged == 1 and merged[1].n == 19 and mleft == 0, "large radius must merge the clusters")

    local capped, cleft = Z.compute(pts, 233, 1, 1, nil)
    assert(#capped == 1 and cleft == 9, "max zones must cap")

    local line = {}
    for k = 1, 21 do line[k] = {wx = 50 * (k - 1), wy = 0, x = 0, y = 0, cid = 1} end
    local parts, pleft = Z.compute(line, 233, 1, 12, nil)
    local total = 0
    for _, z in ipairs(parts) do assert(z.n <= 10, "a zone cannot span more than its diameter") total = total + z.n end
    assert(#parts >= 3 and #parts <= 4 and total == 21 and pleft == 0, #parts)

    local function sig(zs) local t = {} for _, z in ipairs(zs) do t[#t + 1] = z.n .. ":" .. string.format("%.3f,%.3f", z.wx, z.wy) end return table.concat(t, ";") end
    local again = Z.compute(pts, 233, 5, 12, nil)
    assert(sig(zones) == sig(again), "same input, same zones")

    local rnd, seed = {}, 12345
    local function rand() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end
    for k = 1, 1500 do rnd[k] = {wx = rand() * 2000, wy = rand() * 2000, x = 0, y = 0, cid = k % 7} end
    local ticks = 0
    local rz = Z.compute(rnd, 233, 5, 12, function() ticks = ticks + 1 end)
    assert(ticks > 0 and #rz <= 12, "tick must be called")
    local covered = 0
    for _, z in ipairs(rz) do covered = covered + z.n end
    assert(covered <= 1500)
    """)


def zone_env(pre=""):
    lua = env(data=ZONE_FIXTURE, pre=pre)
    lua.execute("TomTom.NameToMapId['Test Valley'] = 77; SR.mapsBuilt = false")
    return lua


def check_zones_pipeline():
    lua = zone_env()
    assert "Select items first" in lines(lua, 'return Slash("zones test valley")')
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    lines(lua, 'return Slash("price medium leather: 3420")')
    out = lines(lua, 'local s = Slash("zones test valley") RunTimers() return s .. Said()')
    assert "Test Valley: 1 zone(s) of 233 yd from 18 points" in out and "1. (20, 20)" in out and "1g 71s 0c" in out, out
    assert lua.eval("#SR.shown.rows") == 1 and abs(lua.eval("SR.shown.rows[1].zone.x") - 20) < 1
    assert "Zone radius: 233" in lines(lua, 'return Slash("radius")')

    lines(lua, 'return Slash("level 30")')
    assert lua.eval("#SR.shown.rows") == 2
    assert lua.eval("SR.shown.rows[1].eval.status") == "ok" and lua.eval("SR.shown.rows[2].eval.status") == "locked"

    lua.execute("mapOpen = true; mapShown = 77; SR:UpdateOverlay()")
    assert lua.eval("MapFrame().shown") is True
    assert lua.eval("Shown('line')") == 48 + 32 and lua.eval("Shown('fontstring')") == 4
    texts = lines(lua, "return ShownTexts()")
    assert "1g 71s 0c" in texts and "Lv 21-22" in texts and "Lv 30-31" in texts and "needs skinning 155" in texts, texts
    gray, yellow = lua.eval("LineAt(1).color"), lua.eval("LineAt(49).color")
    assert abs(gray[1] - 0.62) < 1e-6 and abs(yellow[2] - 0.82) < 1e-6 and yellow[1] == 1, (gray, yellow)
    first = lua.eval("LineAt(1)")
    assert first.thickness == 3

    lines(lua, 'return Slash("level 24")')
    assert lua.eval("Shown('line')") == 48 and lua.eval("Shown('fontstring')") == 2
    green = lua.eval("LineAt(1).color")
    assert abs(green[2] - 0.75) < 1e-6 and abs(green[1] - 0.25) < 1e-6, green

    lua.execute("mapOpen = false; SR:UpdateOverlay()")
    assert lua.eval("MapFrame().shown") is False
    lua.execute("mapOpen = true; mapShown = 99; SR:UpdateOverlay()")
    assert lua.eval("MapFrame().shown") is False
    lua.execute("mapShown = 77; SR:UpdateOverlay()")
    assert lua.eval("MapFrame().shown") is True
    lua.execute("SR.db.showMap = false; SR:UpdateOverlay()")
    assert lua.eval("MapFrame().shown") is False
    lua.execute("SR.db.showMap = true; SR:UpdateOverlay()")
    assert lua.eval("MapFrame().shown") is True

    assert "Zone radius: 150" in lines(lua, 'local s = Slash("radius 150") RunTimers() return s .. Said()')
    assert lua.eval("SR.shown.set.radius") == 150
    assert "Usage: /sr radius" in lines(lua, 'return Slash("radius 5")')
    assert "Zones removed" in lines(lua, 'return Slash("clear")')
    assert lua.eval("SR.shown") is None and lua.eval("MapFrame().shown") is False

    lua.execute("playerMap = 77")
    out = lines(lua, 'local s = Slash("zones") RunTimers() return s .. Said()')
    assert "Test Valley:" in out, out
    out = lines(lua, 'local s = Slash("level 60") RunTimers() return s .. Said()')
    out = lines(lua, 'return Slash("zones")')
    lua.execute("RunTimers()")


def check_zone_errors():
    lua = zone_env(pre="hbdAvailable = false")
    lines(lua, 'return Slash("items medium leather")')
    assert "HereBeDragons-2.0 not found" in lines(lua, 'return Slash("zones test valley")')
    assert lua.eval("SR.shown") is None

    lua = env(data=ZONE_FIXTURE)
    lines(lua, 'return Slash("items medium leather")')
    assert "not resolved to a map" in lines(lua, 'return Slash("zones test valley")')
    assert "Unknown region" in lines(lua, 'return Slash("zones nowhere")')
    lua.execute("playerMap = 500")
    assert "no data" in lines(lua, 'return Slash("zones")')

    lua = zone_env(pre="gamepad = true")
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'local s = Slash("zones test valley") RunTimers() return s')
    lua.execute("mapOpen = true; mapShown = 77; SR:UpdateOverlay()")
    assert lua.eval("MapFrame()") is None, "no overlay frame in gamepad mode"
    assert lua.eval("SR.shown ~= nil") is True


def check_map_test():
    lua = zone_env()
    lua.execute("playerMap, px, py = 77, 0.2, 0.2")
    lua.execute("mapOpen = true; mapShown = 77")
    out = lines(lua, 'return Slash("map")')
    assert "magenta circle of 233 yd" in out and "Map overlay: frame created" in out, out
    assert lua.eval("Shown('line')") == 48
    magenta = lua.eval("LineAt(1).color")
    assert magenta[1] == 1 and magenta[2] == 0 and magenta[3] == 1
    lua.execute("now = now + 21; RunTimers()")
    assert lua.eval("MapFrame().shown") is False
    lua.execute("playerMap = nil")
    assert "No player position" in lines(lua, 'return Slash("map")')


def check_real_zones(path):
    lua = env(data=open(path, encoding="utf8").read())
    lua.execute("TomTom.NameToMapId['The Barrens'] = 10; TomTom.NameToMapId['Hillsbrad Foothills'] = 25; SR.mapsBuilt = false")
    lines(lua, 'return Slash("items medium leather, heavy leather")')
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    report = []
    for region in ("The Barrens", "Hillsbrad Foothills"):
        out = lines(lua, 'local s = Slash("zones %s") RunTimers() return s .. Said()' % region.lower())
        ops, slices = lua.eval("SR.Zones.lastOps"), lua.eval("SR.Zones.lastSlices")
        points = lua.eval("SR.shown.set.points")
        report.append("%s: %d points, %d distance tests, %d slices\n%s" % (region, points, ops, slices, out))
    return "\n".join(report)


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
    check_zone_compute()
    check_zones_pipeline()
    check_zone_errors()
    check_map_test()
    check_missing_data()
    check_lua51_constructs()
    real = os.environ.get("SKINROUTE_DATA")
    if real:
        print(check_real_data(real))
        print(check_real_zones(real))
    print("SKINROUTE TESTS OK")


if __name__ == "__main__":
    main()
