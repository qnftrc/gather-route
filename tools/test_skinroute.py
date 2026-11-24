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
failEvent = nil
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
    local o = {kind = kind, shown = false, scripts = {}, hooks = {}, children = {}, events = {}}
    function o:RegisterEvent(e)
        if failEvent == e then error('unknown event ' .. e) end
        self.events[e] = true
    end
    function o:UnregisterEvent() end
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:HookScript(name, fn) self.hooks[name] = fn end
    function o:Show()
        if not self.shown then
            self.shown = true
            if self.scripts.OnShow then self.scripts.OnShow(self) end
        end
    end
    function o:Hide()
        if self.shown then
            self.shown = false
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
    end
    function o:SetShown(b) if b then self:Show() else self:Hide() end end
    function o:IsShown() return self.shown end
    function o:SetEnabled(b) self.enabled = b ~= false end
    function o:IsEnabled() return self.enabled ~= false end
    function o:SetChecked(b) self.checked = b and true or false end
    function o:GetChecked() return rawget(self, "checked") and true or false end
    function o:SetSize(w, h) self.w, self.h = w, h end
    function o:SetHeight(h) self.height = h end
    function o:GetText() return rawget(self, "text") or "" end
    function o:SetFocus() self.focused = true end
    function o:SetValue(v)
        self.value = v
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
    end
    function o:GetFontString()
        local fs = rawget(self, "fontString")
        if not fs then
            fs = newObject("fontstring")
            self.fontString = fs
        end
        return fs
    end
    function o:SetScrollChild(c) self.scrollChild = c end
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
    return setmetatable(o, {__index = function(_, k)
        if k == "Low" or k == "High" or k == "Text" or k == "TitleText" then return nil end
        return function() end
    end})
end
CreateFrame = function(kind, name, parent)
    local o = newObject(kind)
    o.parent = parent
    frames[#frames + 1] = o
    if type(name) == "string" then _G[name] = o end
    return o
end
UIParent = newObject("UIParent")
UIParent.shown = true
tinsert = table.insert
UISpecialFrames = {}
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
waypoints, tomtomCallbacks, pinged = {}, {}, 0
function TomTom:DefaultCallbacks(o)
    local c = {minimap = {}, world = {}, distance = {}}
    c.distance[o.arrivaldistance] = function() pinged = pinged + 1 end
    return c
end
function TomTom:SetCustomWaypoint(m, x, y, o)
    local uid = {map = m, x = x, y = y, opts = o}
    waypoints[#waypoints + 1] = uid
    return uid
end
function TomTom:RemoveWaypoint(uid)
    for i, u in ipairs(waypoints) do if u == uid then table.remove(waypoints, i) break end end
    for _, f in ipairs(tomtomCallbacks) do f("WaypointRemoved", uid) end
end
TomTom.RegisterCallback = function(owner, ev, f) tomtomCallbacks[#tomtomCallbacks + 1] = f end
function Arrive(uid) uid.opts.callbacks.distance[uid.opts.arrivaldistance]("distance", uid, uid.opts.arrivaldistance, 5, 20) end
hbdAvailable = true
HBD = {}
function HBD:GetWorldCoordinatesFromZone(x, y, map) return x * 2000, y * 1000, 1 end
LibStub = function(name) if name == "HereBeDragons-2.0" and hbdAvailable then return HBD end end
function Said() local s = table.concat(printed, "\n"); printed = {}; return s end
function Slash(msg) SlashCmdList.SKINROUTE(msg) return Said() end
'''

LOAD = r'''
SR = {}
for _, f in ipairs({"Core", "Resolver", "Rules", "Skill", "Zones", "Runner", "Overlay", "UI", "Probe"}) do
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
function UI() return SkinRouteFrame end
function Type(edit, text) edit:SetText(text) edit.scripts.OnEditFocusLost(edit) end
function Click(w) w.scripts.OnClick(w) end
function RowTexts(pool)
    local out = {}
    for _, r in ipairs(pool) do if r.shown then out[#out + 1] = r.text.text end end
    return table.concat(out, "\n")
end
function EventFrame(ev)
    for _, f in ipairs(frames) do if f.events and f.events[ev] then return f end end
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
    out = lines(lua, 'return Slash("help")')
    assert "/sr regions" in out and "/sr level" in out and "/sr - open the window" in out
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
    assert "not readable: no limit applied" in lines(lua, 'return Slash("skill auto")')
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
    assert "UI-GoldIcon" in texts and "71" in texts and "Lv 21-22" in texts and "Lv 30-31" in texts and "needs skinning 155" in texts, texts
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


def guide_env(skill=300, level=30):
    lua = zone_env()
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level %d")' % level)
    lines(lua, 'return Slash("skill %d")' % skill)
    lines(lua, 'return Slash("price medium leather: 3420")')
    return lua


def go(lua):
    return lines(lua, 'local s = Slash("go test valley") RunTimers() return s .. Said()')


def check_guide():
    lua = guide_env()
    out = go(lua)
    assert "Go to 1. zone (20, 20)" in out, out
    assert lua.eval("#waypoints") == 1
    wp = lua.eval("waypoints[1]")
    assert wp.map == 77 and abs(wp.x - 0.2) < 0.01 and abs(wp.y - 0.2) < 0.01
    assert lua.eval("waypoints[1].opts['from']") == "SkinRoute"
    assert lua.eval("waypoints[1].opts.crazy") is True and lua.eval("waypoints[1].opts.silent") is True
    assert lua.eval("waypoints[1].opts.arrivaldistance") == 233 and lua.eval("waypoints[1].opts.cleardistance") == 0
    assert "Test Valley zone (20, 20)" in lua.eval("waypoints[1].opts.title")

    lua.execute("Arrive(waypoints[1])")
    assert lua.eval("#waypoints") == 0 and lua.eval("SR.guide.arrived") is True and lua.eval("pinged") == 1
    assert lines(lua, "return Said()") == "", "arrival message follows the chat setting"
    lua.execute("RunTimers()")
    assert lua.eval("#waypoints") == 0 and lua.eval("SR.guide ~= nil") is True, "our own removal must not skip"
    lua.execute("SR:Arrive()")
    assert lua.eval("#waypoints") == 0

    out = lines(lua, 'return Slash("skip")')
    assert "Go to 2. zone (80, 80)" in out, out
    assert lua.eval("#waypoints") == 1 and abs(lua.eval("waypoints[1].x") - 0.8) < 0.01
    out = lines(lua, 'return Slash("skip")')
    assert "No more zone to go to" in out and lua.eval("#waypoints") == 0 and lua.eval("SR.guide") is None
    assert "No active guide" in lines(lua, 'return Slash("skip")')
    assert "No active guide" in lines(lua, 'return Slash("stop")')

    go(lua)
    lua.execute("TomTom:RemoveWaypoint(waypoints[1]); RunTimers()")
    assert lua.eval("#waypoints") == 1 and abs(lua.eval("waypoints[1].x") - 0.8) < 0.01, "removing the current waypoint skips it"
    go(lua)
    assert lua.eval("#waypoints") == 1 and abs(lua.eval("waypoints[1].x") - 0.2) < 0.01, "go again restarts"
    lua.execute("local dummy = TomTom:SetCustomWaypoint(1, 0.5, 0.5, {}); TomTom:RemoveWaypoint(SR.guide.current); TomTom:RemoveWaypoint(dummy); RunTimers()")
    assert lua.eval("SR.guide") is None and lua.eval("#waypoints") == 0, "a bulk removal stops the guide"

    go(lua)
    assert "Guide stopped" in lines(lua, 'return Slash("stop")')
    assert lua.eval("#waypoints") == 0 and lua.eval("SR.shown ~= nil") is True

    go(lua)
    lines(lua, 'return Slash("level 24")')
    assert lua.eval("#SR.shown.rows") == 1
    assert "No more zone" in lines(lua, 'return Slash("skip")')

    lines(lua, 'return Slash("level 30")')
    assert "Arrival distance: 100" in lines(lua, 'return Slash("arrival 100")')
    go(lua)
    assert lua.eval("waypoints[1].opts.arrivaldistance") == 100
    assert "Usage: /sr arrival" in lines(lua, 'return Slash("arrival 5")')
    assert "Arrival distance: 100" in lines(lua, 'return Slash("arrival")')

    lines(lua, 'return Slash("chat on")')
    go(lua)
    lua.execute("Arrive(waypoints[1])")
    assert "Arrived at the zone (20, 20)" in lines(lua, "return Said()")


def check_guide_limits():
    lua = guide_env(skill=100)
    out = go(lua)
    assert "No zone you can skin with skinning 100" in out and lua.eval("#waypoints") == 0 and lua.eval("SR.guide") is None, out

    lua = zone_env()
    assert "Select items first" in lines(lua, 'return Slash("go test valley")')
    lines(lua, 'return Slash("items medium leather")')
    assert "Unknown region" in lines(lua, 'return Slash("go nowhere")')
    lua.execute("playerMap = 500")
    assert "no data" in lines(lua, 'return Slash("go")')
    assert "No zone to go to" in lines(lua, "SR:StartGuide() return Said()")
    lua.execute("playerMap = 77")
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    out = lines(lua, 'local s = Slash("go") RunTimers() return s .. Said()')
    assert "Go to 1. zone (20, 20)" in out, out


def rows_of(lua, pool):
    out = lines(lua, "return RowTexts(UI().%s)" % pool)
    return out.split("\n") if out else []


def check_ui_region_view():
    lua = guide_env()
    assert lines(lua, 'return Slash("")') == ""
    assert lua.eval("UI().shown") is True and lua.eval("UI().height") == 472
    assert lua.eval("UI().status.text") == "No active guide"
    assert lua.eval("UI().viewButton.text") == "View: Region" and lua.eval("UI().regionButton.text") == "Test Valley"
    assert lua.eval("UI().listTitle.text") == "Leathers (1 selected)"
    rows = rows_of(lua, "rows")
    assert len(rows) == 3, rows
    assert "Heavy Leather" in rows[0] and "(6)" in rows[0] and "|cffffd100Lv 30-31|r" in rows[0], rows[0]
    assert "Light Leather" in rows[1] and "(10)" in rows[1] and "|cff9d9d9dLv 21-22|r" in rows[1], rows[1]
    assert "Medium Leather" in rows[2] and "(16)" in rows[2] and "|cff40c040Lv 21-31|r" in rows[2], rows[2]
    assert lua.eval("UI().rows[3].checked") is True and lua.eval("UI().rows[2].checked") is False

    lua.execute("local r = UI().rows[2]; r:SetChecked(true); Click(r)")
    assert lua.eval("#SR.db.items") == 2 and lua.eval("UI().listTitle.text") == "Leathers (2 selected)"
    lua.execute("local r = UI().rows[2]; r:SetChecked(false); Click(r)")
    assert lua.eval("#SR.db.items") == 1
    lua.execute("Click(UI().noneButton)")
    assert lua.eval("#SR.db.items") == 0 and lua.eval("UI().listTitle.text") == "Leathers (0 selected)"
    assert lua.eval("UI().rows[3].checked") is False
    lua.execute("Click(UI().allButton)")
    assert lua.eval("#SR.db.items") == 3

    lua.execute("Click(UI().noneButton); local r = UI().rows[3]; r:SetChecked(true); Click(r); Type(UI().skillEdit, '140')")
    assert lua.eval("SR.db.skill") == 140 and lua.eval("UI().skillNote.text") == "simulated (not readable)"
    rows = rows_of(lua, "rows")
    assert "Light Leather" in rows[0] and "Medium Leather" in rows[1] and "63%" in rows[1], rows
    assert "|cff808080Heavy Leather|r" in rows[2] and "needs skinning 155" in rows[2], rows[2]
    lua.execute("Type(UI().skillEdit, '')")
    assert lua.eval("SR.db.skill") is None and lua.eval("UI().skillNote.text") == "not readable: no limit"

    lua.execute("Type(UI().levelEdit, '24')")
    assert lua.eval("SR.db.level") == 24 and lua.eval("UI().levelNote.text") == "simulated (you are 21)"
    rows = rows_of(lua, "rows")
    assert "Heavy Leather" in rows[2] and "out of level range" in rows[2] and "(6)" in rows[2], rows[2]
    lua.execute("Type(UI().levelEdit, '21')")
    assert lua.eval("SR.db.level") is None and lua.eval("UI().levelNote.text") == "your level"
    lua.execute("Type(UI().levelEdit, 'abc')")
    assert lua.eval("SR.db.level") is None
    lua.execute("Type(UI().levelEdit, '99')")
    assert lua.eval("SR.db.level") == 80
    lua.execute("Click(UI().viewButton)")
    assert lua.eval("UI().viewMenu.shown") is True
    lua.execute("SR:SetBrowseMode('region')")
    assert lua.eval("UI().viewMenu.shown") is False
    assert lines(lua, 'return Slash("")') == "" and lua.eval("UI().shown") is False


def check_ui_item_view():
    lua = guide_env()
    lines(lua, 'return Slash("")')
    lua.execute("SR:SetBrowseMode('item')")
    assert lua.eval("SR.db.browse") == "item" and lua.eval("UI().viewButton.text") == "View: Item"
    assert lua.eval("UI().regionLabel.text") == "Leather" and lua.eval("UI().regionButton.text") == "Medium Leather"
    assert lua.eval("UI().listTitle.text") == "Regions, most mobs first (1)"
    rows = rows_of(lua, "rows")
    assert len(rows) == 1 and "Test Valley" in rows[0] and "(16)" in rows[0], rows
    assert lua.eval("UI().rows[1].checked") is True
    assert lua.eval("UI().noneButton.shown") is False and lua.eval("UI().allButton.shown") is False

    lua.execute("Click(UI().regionButton)")
    assert lua.eval("UI().itemPopup.shown") is True and lua.eval("UI().regionPopup.shown") is False
    pop = rows_of(lua, "itemPopupRows")
    assert "Heavy Leather" in pop[0] and "(6)" in pop[0] and "(12)" in pop[1] and "(16)" in pop[2], pop
    lua.execute("local r = UI().itemPopupRows[2]; r:SetChecked(true); Click(r)")
    assert lua.eval("UI().regionButton.text") == "Light Leather, Medium Leather" and lua.eval("#SR.db.items") == 2
    lua.execute("UI().itemSearch:SetText('hv'); UI().itemSearch.scripts.OnTextChanged()")
    assert lua.eval("UI().itemMatches") == 1 and lua.eval("UI().itemNone.shown") is False
    lua.execute("UI().itemSearch:SetText('zzz'); UI().itemSearch.scripts.OnTextChanged()")
    assert lua.eval("UI().itemMatches") == 0 and lua.eval("UI().itemNone.shown") is True
    lua.execute("UI().itemSearch:SetText(''); UI().itemSearch.scripts.OnTextChanged()")
    assert lua.eval("UI().itemMatches") == 3

    lua.execute("SR.db.items = {}; SR:RefreshZones(); SR:SetBrowseMode('item')")
    assert lua.eval("UI().listTitle.text") == "Select leathers to list the regions" and lua.eval("UI().regionButton.text") == "Select leathers"
    lua.execute("SR.db.items = {2319, 2318, 4234}; SR:SetBrowseMode('item')")
    assert lua.eval("UI().regionButton.text") == "Heavy Leather, Light Leather (+1)"


def check_ui_value_view():
    lua = guide_env()
    lines(lua, 'return Slash("")')
    lua.execute("SR:SetBrowseMode('value')")
    assert lua.eval("UI().viewButton.text") == "View: Value" and lua.eval("UI().height") == 482
    assert lua.eval("UI().regionButton.shown") is False and lua.eval("UI().valSearch.shown") is True
    assert lua.eval("UI().listScroll.shown") is False and lua.eval("UI().listTitle.shown") is False
    assert lua.eval("UI().valTitle1.text") == "Leathers by value (3)"
    items = rows_of(lua, "valItemRows")
    assert "Medium Leather" in items[0] and "UI-SilverIcon" in items[0] and "UI-GoldIcon" not in items[0], items
    assert "no price" in items[1] and "no price" in items[2]
    assert lua.eval("UI().valTitle2.text") == "Most valuable zones (1)"
    zones = rows_of(lua, "valZoneRows")
    assert "Test Valley" in zones[0] and "UI-GoldIcon" in zones[0], zones
    lines(lua, 'return Slash("skill 140")')
    lua.execute("UI().valSearch:SetText('medium'); UI().valSearch.scripts.OnTextChanged()")
    assert lua.eval("UI().valTitle1.text") == "Leathers by value (1)"
    lua.execute("UI().valSearch:SetText(''); UI().valSearch.scripts.OnTextChanged()")
    zones = rows_of(lua, "valZoneRows")
    assert "63%" in zones[0], zones
    lua.execute("local r = UI().valItemRows[2]; r:SetChecked(true); Click(r)")
    assert lua.eval("#SR.db.items") == 2
    lua.execute("Click(UI().valZoneRows[1])")
    assert lua.eval("UI().region") == "Test Valley" and lua.eval("UI().valZoneRows[1].checked") is True
    lines(lua, 'return Slash("skill 100")')
    lua.execute("SR:SetBrowseMode('value')")
    zones = rows_of(lua, "valZoneRows")
    assert "|cff808080Test Valley|r" in zones[0] and "needs skinning 110" in zones[0], zones


def check_ui_options():
    lua = guide_env()
    lines(lua, 'return Slash("")')
    assert lua.eval("UI().optionsButton.text") == "Options +"
    assert lua.eval("UI().showMap.shown") is False
    lua.execute("Click(UI().optionsButton)")
    assert lua.eval("SR.db.optionsShown") is True and lua.eval("UI().height") == 610 and lua.eval("UI().optionsButton.text") == "Options -"
    assert all(lua.eval("UI().optionWidgets[%d].shown" % i) is True for i in range(1, lua.eval("#UI().optionWidgets") + 1))
    lua.execute("SR:SetBrowseMode('value')")
    assert lua.eval("UI().height") == 620
    lua.execute("SR:SetBrowseMode('region')")
    assert lua.eval("UI().showMap.checked") is True and lua.eval("UI().chat.checked") is False and lua.eval("UI().band.checked") is True

    lua.execute("UI().showMap:SetChecked(false); Click(UI().showMap)")
    assert lua.eval("SR.db.showMap") is False
    lua.execute("UI().chat:SetChecked(true); Click(UI().chat)")
    assert lua.eval("SR.db.chat") is True
    lua.execute("UI().band:SetChecked(false); Click(UI().band)")
    assert lua.eval("SR.db.bandOnly") is False
    lua.execute("UI().band:SetChecked(true); Click(UI().band)")
    assert lua.eval("SR.db.bandOnly") is True

    lua.execute("Type(UI().lowEdit, '-10'); Type(UI().highEdit, '+5')")
    assert lua.eval("SR.db.bandLow") == -10 and lua.eval("SR.db.bandHigh") == 5
    assert lua.eval("UI().lowEdit.text") == "-10" and lua.eval("UI().highEdit.text") == "+5"
    lua.execute("Type(UI().highEdit, '-20')")
    assert lua.eval("SR.db.bandLow") == -20 and lua.eval("SR.db.bandHigh") == -10
    lua.execute("Type(UI().lowEdit, 'x')")
    assert lua.eval("SR.db.bandLow") == -20 and lua.eval("UI().lowEdit.text") == "-20"

    lines(lua, 'local s = Slash("zones test valley") RunTimers() return s')
    lua.execute("Type(UI().radiusEdit, '300'); RunTimers()")
    assert lua.eval("SR.db.zoneRadius") == 300 and lua.eval("SR.shown.set.radius") == 300
    lua.execute("Type(UI().radiusEdit, '5')")
    assert lua.eval("SR.db.zoneRadius") == 50 and lua.eval("UI().radiusEdit.text") == "50"
    lua.execute("UI().slider.scripts.OnValueChanged(UI().slider, 120)")
    assert lua.eval("SR.db.arrival") == 120 and lua.eval("UI().arrivalText.text") == "Arrival distance: 120 yd"
    lua.execute("UI():Hide(); UI():Show()")
    assert lua.eval("UI().slider.value") == 120
    lua.execute("Click(UI().optionsButton)")
    assert lua.eval("UI().height") == 472 and lua.eval("UI().showMap.shown") is False


def check_ui_buttons():
    lua = guide_env()
    lines(lua, 'return Slash("")')
    lua.execute("SR.db.items = {}")
    lua.execute("Click(UI().generate)")
    assert "Select at least one leather." in lines(lua, "return Said()")
    assert lua.eval("UI().skip.enabled") is False and lua.eval("UI().stop.enabled") is False
    lua.execute("SR.db.items = {2319}")
    lua.execute("Click(UI().generate); RunTimers()")
    assert lua.eval("#waypoints") == 1 and lua.eval("UI().status.text") == "Test Valley: zone 1 / 2"
    assert lua.eval("UI().skip.enabled") is True and lua.eval("UI().stop.enabled") is True
    lua.execute("Arrive(waypoints[1])")
    assert lua.eval("UI().status.text") == "Test Valley: zone 1 / 2 (arrived)"
    lua.execute("Click(UI().skip)")
    assert lua.eval("UI().status.text") == "Test Valley: zone 2 / 2" and lua.eval("UI().skip.enabled") is True
    lua.execute("Click(UI().skip)")
    assert lua.eval("UI().status.text") == "No active guide" and lua.eval("UI().skip.enabled") is False
    lua.execute("Click(UI().generate); RunTimers(); Click(UI().stop)")
    assert lua.eval("SR.guide") is None and lua.eval("#waypoints") == 0 and lua.eval("UI().status.text") == "No active guide"
    lua.execute("SR.computing = true; SR:UpdateUI()")
    assert lua.eval("UI().status.text") == "Computing zones..." and lua.eval("UI().generate.enabled") is False
    lua.execute("SR.computing = false; SR:UpdateUI()")
    assert lua.eval("UI().generate.enabled") is True

    lines(lua, 'return Slash("level auto")')
    lua.execute("level = 25; local f = EventFrame('PLAYER_LEVEL_UP'); f.scripts.OnEvent(f, 'PLAYER_LEVEL_UP')")
    assert lua.eval("UI().levelEdit.text") == "25"

    lua = env(data=None)
    assert "SkinData.lua is missing" in lines(lua, "return Said()")
    lua.execute("SR:UpdateUI()")
    assert lines(lua, 'return Slash("")') == ""
    assert lua.eval("UI().regionButton.text") == "No region" and lua.eval("UI().listTitle.text") == "Leathers (0 selected)"
    lua.execute("Click(UI().generate)")
    assert "Select at least one leather." in lines(lua, "return Said()")


def check_ui_region_popup():
    lua = env()
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    lines(lua, 'return Slash("")')
    assert lua.eval("UI().region") == "Hillsbrad Foothills"
    lua.execute("Click(UI().regionButton)")
    assert lua.eval("UI().regionPopup.shown") is True and lua.eval("UI().itemPopup.shown") is False
    names = [lua.eval("UI().regionPopupRows[%d].text" % i) for i in range(1, 4)]
    assert names == ["Elwynn Forest", "Hillsbrad Foothills", "Un'Goro Crater"], names
    lua.execute("UI().regionSearch:SetText('zz'); UI().regionSearch.scripts.OnTextChanged()")
    assert lua.eval("UI().regionNone.shown") is True
    lua.execute("UI().regionSearch:SetText('ung'); UI().regionSearch.scripts.OnTextChanged()")
    assert lua.eval("#UI().regionMatches") == 1 and lua.eval("UI().regionMatches[1]") == "Un'Goro Crater"
    lua.execute("UI().regionSearch:SetText(''); UI().regionSearch.scripts.OnTextChanged()")
    lua.execute("Click(UI().regionPopupRows[1])")
    assert lua.eval("UI().region") == "Elwynn Forest" and lua.eval("UI().regionButton.text") == "Elwynn Forest"
    assert lua.eval("UI().regionPopup.shown") is False and lua.eval("SR.db.region") == "Elwynn Forest"
    rows = rows_of(lua, "rows")
    assert len(rows) == 2 and "Light Leather" in rows[0] and "Medium Leather" in rows[1], rows
    lua.execute("Click(UI().regionButton); UI().regionSearch:SetText('un'); UI().regionSearch.scripts.OnTextChanged(); UI().regionSearch.scripts.OnEnterPressed()")
    assert lua.eval("UI().region") == "Un'Goro Crater"
    rows = rows_of(lua, "rows")
    assert len(rows) == 1 and "|cff808080Heavy Leather|r" in rows[0] and "(2)" in rows[0] and "out of level range" in rows[0], rows
    assert lua.eval("UI().listTitle.text") == "Leathers (1 selected)"


def check_real_ui(path):
    lua = env(data=open(path, encoding="utf8").read())
    lua.execute("TomTom.NameToMapId['Hillsbrad Foothills'] = 25; SR.mapsBuilt = false")
    lines(lua, 'return Slash("items medium leather, heavy leather")')
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    lines(lua, 'return Slash("")')
    report = []
    for mode in ("region", "item", "value"):
        lua.execute("SR:SetBrowseMode('%s')" % mode)
        pool = "valZoneRows" if mode == "value" else "rows"
        rows = rows_of(lua, pool)
        assert rows, mode
        report.append("%s: %d row(s), first: %s" % (mode, len(rows), re.sub(r"\|c[0-9a-f]{8}|\|r|\|T[^|]*\|t", "", rows[0])))
    lua.execute("Click(UI().optionsButton)")
    return "\n".join(report)


SKILLS_MOCK = r"""
SKILLS = {
    {"Professions", 1, 1, 0, 0},
    {"Dépeçage", nil, nil, 125, 150},
    {"Mining", nil, nil, 1, 75},
    {"Languages", 1, nil, 0, 0},
}
GetNumSkillLines = function() return #SKILLS end
GetSkillLineInfo = function(i) local s = SKILLS[i] return s[1], s[2], s[3], s[4], 0, 0, s[5] end
"""


PROFESSIONS_MOCK = r"""
GetProfessions = function() return 3, 4, nil, nil, nil, nil end
GetProfessionInfo = function(i)
    if i == 3 then return "Alchemy", "icon", 300, 300, 1, 146, 171, 0 end
    return "Dépeçage", "icon", 125, 150, 1, 147, 393, 5
end
"""


def probe_env(extra="", data=FIXTURE, skills=True, professions=True):
    lua = env(data=data)
    lua.execute("GetBuildInfo = function() return '1.60.1', '71037', 'Nov 24 2026', 16001 end; GetLocale = function() return 'frFR' end; date = os.date")
    if skills:
        lua.execute(SKILLS_MOCK)
    if professions:
        lua.execute(PROFESSIONS_MOCK)
    lua.execute(extra)
    return lua


def probe(lua, arg=""):
    out = lines(lua, 'return Slash("probe %s")' % arg)
    return re.sub(r"\|cff33ff99SkinRoute\|r: ", "", out)


def check_probe():
    lua = probe_env()
    out = probe(lua)
    for expected in (
        'locale "frFR"', 'build "71037"', 'UnitLevel("player") -> 21',
        "SkinRoute data: 3 regions, 4 creatures, 3 items",
        "HereBeDragons-2.0: present", "player map 25", "map 25: 2000 x 1000 yd",
        "regions resolved 2/3", 'current region: "Hillsbrad Foothills"', "unresolved: Un'Goro Crater",
        "templates created: BasicFrameTemplateWithInset", "UIPanelScrollFrameTemplate", "BackdropTemplate",
        "GetNumSkillLines -> 4", 'headers: "Professions", "Languages" [collapsed]',
        'skills: "Dépeçage" 125/150, "Mining" 1/75', "1 header(s) collapsed",
        "Skinning line 2 raw:", "RESULT: Skinning 130 (rank 125 +5) of 150 via GetProfessionInfo, skill line 393",
        "the classic API would give 125/150 (not used by the addon)", 'GetProfessionInfo(3) -> "Alchemy", "icon", 300, 300, 1, 146, 171, 0',
        "global functions with Skill in the name", "GetSkillLineInfo", "Probe done:",
    ):
        assert expected in out, (expected, out)
    assert "templates FAILED" not in out
    assert lua.eval("#SR.db.probe.lines") > 10 and lua.eval("SR.db.probe.date") != ""

    out = probe(probe_env(skills=False, professions=False))
    assert "GetNumSkillLines / GetSkillLineInfo: not available" in out and "GetProfessions: not available" in out, out
    assert "RESULT: GetProfessions / GetProfessionInfo not usable" in out

    out = probe(probe_env(extra="GetProfessionInfo = function(i) return 'Alchemy', 'icon', 300, 300, 1, 146, 171, 0 end"))
    assert "RESULT: Skinning is not among your professions (not learned)" in out and "the classic API would give" in out, out

    out = probe(probe_env(skills=False, professions=False, extra="GetProfessions = function() return 3, nil, nil, nil, nil, nil end; "
                          "GetProfessionInfo = function(i) return 'Skinning', 'icon', 200, 300 end"))
    assert 'GetProfessions() -> 3, nil, nil, nil, nil, nil' in out and 'GetProfessionInfo(3) -> "Skinning", "icon", 200, 300' in out, out
    assert "RESULT: Skinning 200 (rank 200) of 300 via GetProfessionInfo, skill line nil" in out

    out = probe(probe_env(extra="issecretvalue = function(v) return v == 125 end"))
    assert "SECRET value" in out and "RESULT: Skinning 130" not in out, out

    out = probe(probe_env(extra="GetSkillLineInfo = function(i) error('boom') end"))
    assert "GetNumSkillLines -> 4" in out and "GetSkillLineInfo(1): ERROR" in out and "boom" in out, out
    assert "RESULT: Skinning 130" in out

    out = probe(probe_env(extra="local original = CreateFrame; CreateFrame = function(kind, name, parent, template) "
                          "if template == 'OptionsSliderTemplate' then error('no such template') end return original(kind, name, parent, template) end"))
    assert "templates FAILED: OptionsSliderTemplate" in out and "no such template" in out, out
    created = re.search(r"templates created: (.*)", out).group(1)
    assert "OptionsSliderTemplate" not in created and "InputBoxTemplate" in created

    out = probe(probe_env(extra="hbdAvailable = false"))
    assert "HereBeDragons-2.0: MISSING" in out and "map 25:" not in out

    out = probe(probe_env(extra="playerMap = nil"))
    assert "player map nil" in out and "RESULT: Skinning 130" in out

    out = probe(probe_env(extra="GetBuildInfo = nil; GetLocale = nil"))
    assert "client nil build nil" in out and "RESULT:" in out

    out = probe(probe_env(extra="TomTom.GetCurrentPlayerPosition = function() error('tomtom broke') end"))
    assert "env: SECTION ERROR" in out and "tomtom broke" in out and "RESULT: Skinning 130" in out, out

    lua = probe_env()
    out = probe(lua, "skill")
    assert "RESULT: Skinning 130" in out and "HereBeDragons" not in out and "templates created" not in out
    out = probe(lua, "env")
    assert "HereBeDragons-2.0: present" in out and "RESULT" not in out and "templates created" not in out
    out = probe(lua, "ui")
    assert "templates created" in out and "HereBeDragons" not in out
    assert "Usage: /sr probe" in probe(lua, "nonsense")

    out = probe(probe_env(data=None))
    assert "DATA FILE MISSING" in out and "RESULT: Skinning 130" in out


PROF_API = r"""
GetProfessions = function() return table.unpack(PIDX, 1, 6) end
GetProfessionInfo = function(i) return table.unpack(PROFS[i], 1, 8) end
"""
ALCHEMY = '{"Alchemy", "i", 300, 300, 1, 1, 171, 0}'
HERBALISM = '{"Herbalism", "i", 300, 300, 1, 1, 182, 0}'
SKINNING = '{"Dépeçage", "i", 125, 150, 1, 1, 393, 5}'


def prof_env(profs, idx="{1, 2, 3}", extra="", data=FIXTURE, pre=""):
    lua = env(data=data, pre=pre)
    lua.execute("PROFS = {%s}; PIDX = %s" % (", ".join(profs), idx))
    lua.execute(PROF_API)
    lua.execute(extra)
    return lua


def check_skill_reading():
    lua = prof_env([ALCHEMY, SKINNING, HERBALISM])
    info = lua.eval("SR:ReadSkill()")
    assert info.status == "ok" and info.rank == 125 and info.modifier == 5 and info.value == 130 and info.max == 150 and info.line == 393
    assert lua.eval("SR.SkillText(SR:ReadSkill())") == "your skill (Skinning 125+5/150)"
    assert lua.eval("SR.SkillShort(SR:ReadSkill())") == "Skinning 125+5/150" and lua.eval("SR.SkillHave(SR:ReadSkill())") == "you have 130"

    lua = prof_env(['{"Skinning", "i", 200, 300, 1, 1, 999, 0}'], idx="{1}")
    info = lua.eval("SR:ReadSkill()")
    assert info.status == "ok" and info.value == 200 and info.line == 999
    assert lua.eval("SR.SkillShort(SR:ReadSkill())") == "Skinning 200/300"
    lua = prof_env(['{"Dépeçage", "i", 100, 150}'], idx="{1}")
    info = lua.eval("SR:ReadSkill()")
    assert info.status == "ok" and info.value == 100 and info.modifier == 0 and info.line is None
    lua = prof_env(['{"Whatever", "i", 50, 300, 1, 1, 393, 0}'], idx="{1}")
    assert lua.eval("SR:ReadSkill().status") == "ok" and lua.eval("SR:ReadSkill().value") == 50

    lua = prof_env([ALCHEMY, HERBALISM], idx="{1, 2}")
    assert lua.eval("SR:ReadSkill().status") == "not learned"
    assert "Skinning not learned: no limit applied" in lua.eval("SR.SkillText(SR:ReadSkill())")
    assert lua.eval("SR.SkillShort(SR:ReadSkill())") == "not learned: no limit" and lua.eval("SR.SkillHave(SR:ReadSkill())") == "not learned"

    lua = env()
    assert lua.eval("SR:ReadSkill().status") == "unavailable"
    assert lua.eval("SR.SkillShort(SR:ReadSkill())") == "not readable: no limit" and lua.eval("SR.SkillHave(SR:ReadSkill())") == "not readable"
    lua = prof_env([ALCHEMY], idx="{1}", extra="GetProfessions = function() error('x') end")
    assert lua.eval("SR:ReadSkill().status") == "unavailable"
    lua = prof_env([ALCHEMY], idx="{1}", extra="GetProfessionInfo = function() error('x') end")
    assert lua.eval("SR:ReadSkill().status") == "unavailable"

    lua = prof_env([ALCHEMY, SKINNING], idx="{1, 2}", extra="issecretvalue = function(v) return v == 125 end")
    assert lua.eval("SR:ReadSkill().status") == "secret"
    assert "secret value" in lua.eval("SR.SkillText(SR:ReadSkill())") and lua.eval("SR.SkillShort(SR:ReadSkill())") == "secret: no limit"
    lua = prof_env([ALCHEMY, SKINNING], idx="{1, 2}", extra="issecretvalue = function(v) return v == 1 end")
    assert lua.eval("SR:ReadSkill().status") == "ok", "a secret index must not hide a readable skinning line"
    lua = prof_env([ALCHEMY, HERBALISM], idx="{1, 2}", extra="issecretvalue = function(v) return v == 1 end")
    assert lua.eval("SR:ReadSkill().status") == "secret"
    lua = prof_env(['{"Whatever", "i", 50, 300, 1, 1, 400, 0}'], idx="{1}", extra="issecretvalue = function(v) return v == 'Whatever' end")
    assert lua.eval("SR:ReadSkill().status") == "not learned"


def check_player_skill():
    lua = prof_env([ALCHEMY, SKINNING], idx="{1, 2}", data=ZONE_FIXTURE)
    lua.execute("TomTom.NameToMapId['Test Valley'] = 77; SR.mapsBuilt = false")
    real = lua.eval("(SR:PlayerSkill())")
    assert real == 130 and lua.eval("(select(2, SR:PlayerSkill()))") is False and lua.eval("select(3, SR:PlayerSkill()).status") == "ok"
    lua.execute("SR.db.skill = 200")
    assert lua.eval("(SR:PlayerSkill())") == 200 and lua.eval("(select(2, SR:PlayerSkill()))") is True
    lua.execute("SR.db.skill = nil")

    assert "Skinning skill: 130 (read from the game)." in lines(lua, 'return Slash("skill")')
    assert "Skinning skill: 200 (simulated, /sr skill auto to go back)." in lines(lua, 'return Slash("skill 200")')
    assert "Skinning skill: 130 (read from the game)." in lines(lua, 'return Slash("skill auto")')

    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 30")')
    ctxe = lua.eval("SR:EvaluateRegion('Test Valley', SR:Context()).status")
    assert ctxe == "partial", "the real skill 130 opens the bears (110) but not the lions (155)"
    out = lines(lua, 'return Slash("regions")')
    assert "skinning 130, " in out and "(simulated)" not in out.split("\n")[0].replace("Level 30 (simulated)", ""), out
    lines(lua, 'return Slash("skill 200")')
    assert "skinning 200 (simulated)" in lines(lua, 'return Slash("regions")')
    assert lua.eval("SR:EvaluateRegion('Test Valley', SR:Context()).status") == "ok"

    lua = prof_env([ALCHEMY], idx="{1}", data=ZONE_FIXTURE)
    assert lua.eval("(SR:PlayerSkill())") is None
    assert "Skinning not learned: no limit applied" in lines(lua, 'return Slash("skill")')
    lines(lua, 'return Slash("items medium leather")')
    out = lines(lua, 'return Slash("regions")')
    assert "Skinning not learned: no limit applied" in out and "skinning Skinning" not in out, out
    lines(lua, 'return Slash("skill 100")')
    assert "skinning 100 (simulated)" in lines(lua, 'return Slash("regions")')


def check_ui_skill():
    lua = prof_env([ALCHEMY, SKINNING], idx="{1, 2}", data=ZONE_FIXTURE)
    lua.execute("TomTom.NameToMapId['Test Valley'] = 77; SR.mapsBuilt = false")
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 30")')
    lines(lua, 'return Slash("")')
    assert lua.eval("UI().skillEdit.text") == "130" and lua.eval("UI().skillNote.text") == "Skinning 125+5/150"
    assert lua.eval("UI().skillButton:IsEnabled()") is True
    rows = rows_of(lua, "rows")
    assert "Medium Leather" in rows[1] and "63%" in rows[1] and "needs skinning 155" in rows[2], rows
    lua.execute("Type(UI().skillEdit, '130')")
    assert lua.eval("SR.db.skill") is None and lua.eval("UI().skillNote.text") == "Skinning 125+5/150"
    lua.execute("Type(UI().skillEdit, '200')")
    assert lua.eval("SR.db.skill") == 200 and lua.eval("UI().skillNote.text") == "simulated (you have 130)"
    rows = rows_of(lua, "rows")
    assert not any("63%" in r or "needs skinning" in r for r in rows), rows
    lua.execute("Click(UI().skillButton)")
    assert lua.eval("SR.db.skill") is None and lua.eval("UI().skillEdit.text") == "130"
    lua.execute("Type(UI().skillEdit, '')")
    assert lua.eval("SR.db.skill") is None and lua.eval("UI().skillEdit.text") == "130"

    lua.execute("PROFS[2][3] = 140; local f = EventFrame('SKILL_LINES_CHANGED'); f.scripts.OnEvent(f, 'SKILL_LINES_CHANGED')")
    assert lua.eval("UI().skillEdit.text") == "145" and lua.eval("UI().skillNote.text") == "Skinning 140+5/150"
    lua.execute("PROFS[2][3] = 150; local f = EventFrame('CHAT_MSG_SKILL'); f.scripts.OnEvent(f, 'CHAT_MSG_SKILL')")
    assert lua.eval("UI().skillEdit.text") == "155"
    rows = rows_of(lua, "rows")
    assert not any("63%" in r or "needs skinning" in r for r in rows), "155 skins the lions too"

    lua = prof_env([ALCHEMY], idx="{1}", data=ZONE_FIXTURE)
    lines(lua, 'return Slash("")')
    assert lua.eval("UI().skillEdit.text") == "" and lua.eval("UI().skillNote.text") == "not learned: no limit"
    lua.execute("Type(UI().skillEdit, '120')")
    assert lua.eval("SR.db.skill") == 120 and lua.eval("UI().skillNote.text") == "simulated (not learned)"

    lua = prof_env([ALCHEMY, SKINNING], idx="{1, 2}", data=ZONE_FIXTURE, pre="failEvent = 'SKILL_LINES_CHANGED'")
    lua.execute("local f = EventFrame('PLAYER_LEVEL_UP'); f.scripts.OnEvent(f, 'PLAYER_LEVEL_UP')")
    assert lua.eval("EventFrame('SKILL_LINES_CHANGED')") is None and lua.eval("EventFrame('CHAT_MSG_SKILL') ~= nil") is True
    lines(lua, 'return Slash("")')
    assert lua.eval("UI().skillEdit.text") == "130"


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
    check_guide()
    check_guide_limits()
    check_ui_region_view()
    check_ui_item_view()
    check_ui_value_view()
    check_ui_options()
    check_ui_buttons()
    check_ui_region_popup()
    check_probe()
    check_skill_reading()
    check_player_skill()
    check_ui_skill()
    check_missing_data()
    check_lua51_constructs()
    real = os.environ.get("SKINROUTE_DATA")
    if real:
        print(check_real_data(real))
        print(check_real_zones(real))
        print(check_real_ui(real))
    print("SKINROUTE TESTS OK")


if __name__ == "__main__":
    main()
