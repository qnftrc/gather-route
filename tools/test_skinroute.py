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
failEvent, failUnitEvent = nil, nil
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
    function o:RegisterUnitEvent(e, unit)
        if failUnitEvent == e then error('unknown event ' .. e) end
        self.events[e] = unit
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
    function o:GetPoint() return 'CENTER', nil, 'CENTER', 10, 20 end
    function o:StartMoving() self.moving = true end
    function o:StopMovingOrSizing() self.moving = false end
    function o:CreateLine() local c = newObject("line") self.children[#self.children + 1] = c return c end
    function o:CreateFontString() local c = newObject("fontstring") self.children[#self.children + 1] = c return c end
    function o:SetFont(f, size) self.font, self.fontPx = f, size end
    function o:SetTexture(p) self.path = p end
    function o:CreateMaskTexture() local c = newObject("mask") self.children[#self.children + 1] = c return c end
    function o:AddMaskTexture(m) self.mask = m end
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
GameTooltip = newObject("tooltip")
shift = false
IsShiftKeyDown = function() return shift end
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
for _, f in ipairs({"Core", "Locale", "Resolver", "Rules", "Skill", "Prices", "Stats", "Zones", "Runner", "Overlay", "UI", "SkipButton", "Probe"}) do
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
    if "SkinRouteDB" not in pre:
        pre = "SkinRouteDB = {zoneRadius = 233, radiusVersion = 1}\n" + pre
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


LOOT_FIXTURE = r'''
SkinRoute_Loot = {
  items = {[5001] = {"Gray Fang", 0, 30}, [5002] = {"Linen Cloth", 1, 13}, [5003] = {"Green Cape", 2, 200}},
  creatures = {
    [1] = {g = 20, d = {[5001] = {50, 1, 1}, [5002] = {30, 1, 2}, [5003] = {5, 1, 1}}},
    [2] = {g = 0, d = {[5003] = {10, 1, 1}}},
  },
}
'''


def zone_env(pre="", loot=False):
    lua = env(data=ZONE_FIXTURE + (LOOT_FIXTURE if loot else ""), pre=pre)
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
    assert lua.eval("Shown('line')") == 48 + 32 and lua.eval("Shown('fontstring')") == 6
    texts = lines(lua, "return ShownTexts()")
    assert "UI-GoldIcon" in texts and "71" in texts and "Lv 21-22" in texts and "Lv 30-31" in texts and "needs skinning 155" in texts, texts
    assert "10 mobs" in texts and "6 mobs" in texts, texts
    gray, yellow = lua.eval("LineAt(1).color"), lua.eval("LineAt(49).color")
    assert abs(gray[1] - 0.62) < 1e-6 and abs(yellow[2] - 0.82) < 1e-6 and yellow[1] == 1, (gray, yellow)
    first = lua.eval("LineAt(1)")
    assert first.thickness == 3

    lines(lua, 'return Slash("level 24")')
    assert lua.eval("Shown('line')") == 48 and lua.eval("Shown('fontstring')") == 3
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


def check_fill():
    lua = guide_env()
    lines(lua, 'return Slash("zones test valley")')
    lua.execute("RunTimers()")
    lua.execute("mapOpen = true; mapShown = 77; SR:UpdateOverlay()")
    assert lua.eval("Shown('texture')") == 0, "fill is off by default"
    assert "No mask chosen" in lines(lua, 'return Slash("fill on")')
    assert "Usage" in lines(lua, 'return Slash("fill 9")')
    out = lines(lua, 'return Slash("fill test")')
    assert "Fill test" in out, out
    assert lua.eval("Shown('texture')") == 4
    paths = lua.eval("(function() local t = {} for _, c in ipairs(MapFrame().children) do if c.kind == 'mask' then t[#t + 1] = c.path end end return table.concat(t, '|') end)()")
    assert "TempPortraitAlphaMask" in paths and paths.count("|") == 3, paths
    lua.execute("now = now + 31; RunTimers()")
    assert lua.eval("Shown('texture')") == 0
    out = lines(lua, 'return Slash("fill 1")')
    assert "Zone fill: on" in out and "TempPortraitAlphaMask" in out, out
    n = lua.eval("#SR.shown.rows")
    assert lua.eval("Shown('texture')") == n and n > 0
    tex = lua.eval("(function() for _, c in ipairs(MapFrame().children) do if c.kind == 'texture' and c.shown then return c end end end)()")
    assert tex.color[1] == 1 and tex.color[2] == 1 and tex.color[3] == 1 and abs(tex.color[4] - 0.18) < 1e-6
    assert tex.mask.path.endswith("TempPortraitAlphaMask")
    lines(lua, 'return Slash("fill off")')
    assert lua.eval("Shown('texture')") == 0
    lines(lua, 'return Slash("fill path Interface\\\\Foo\\\\Bar")')
    assert lua.eval("SR.db.fillMask") == "Interface\\Foo\\Bar" and lua.eval("SR.db.fill") is True


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


def guide_env(skill=300, level=30, loot=False):
    lua = zone_env(loot=loot)
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


def check_profit():
    lua = guide_env()
    kt = lambda d: lua.eval("SR.Rules.killTime(%s, 25, 10, 1.10)" % d)
    assert abs(kt(0) - 25) < 1e-9
    assert abs(kt(-8) - (10 + 15 * 1.1 ** -8)) < 1e-9 and abs(kt(5) - (10 + 15 * 1.1 ** 5)) < 1e-9
    assert kt(25) == kt(10) and kt(-25) == kt(-10)
    c = lua.eval("SR:Context()")
    assert c.killBase == 25 and c.killFixed == 10 and abs(c.killSlope - 1.1) < 1e-9
    e = lua.eval("SR:EvaluateRegion('Test Valley', SR:Context())")
    assert e.seconds > 0 and e.perHour > 0 and abs(e.perHour - e.value / e.seconds * 3600) < 1e-6
    assert 10 < e.avgSeconds < 60
    assert "Time per mob: 25 s" in lines(lua, 'return Slash("time")')
    assert "Usage" in lines(lua, 'return Slash("time abc")')
    assert "1-300" in lines(lua, 'return Slash("time 30 40")')
    assert "Time per mob: 30 s" in lines(lua, 'return Slash("time 30 12 1.2")')
    assert lua.eval("SR.db.killBase") == 30 and lua.eval("SR.db.killFixed") == 12
    lines(lua, 'return Slash("time 25 10 1.1")')
    lua.execute("SR:SetBrowseMode('profit')")
    assert lua.eval("UI().viewButton.text") == "View: Profit" and lua.eval("SR.db.browse") == "profit"
    assert "gold per hour" in lua.eval("UI().listTitle.text")
    rows = rows_of(lua, "rows")
    assert rows and rows[0].startswith("Test Valley") and rows[0].endswith("/h"), rows
    assert lua.eval("UI().rows[1].sub.text") == "-> Medium Leather", lua.eval("UI().rows[1].sub.text")
    assert lua.eval("UI().regionButton.text") == "Best leathers for each region (automatic)"
    assert lua.eval("UI().regionButton.enabled") is False and lua.eval("UI().noneButton.shown") is False
    assert lua.eval("UI().regionLabel.text") == "Auto"
    assert lua.eval("UI().w") == 442 and lua.eval("UI().listScroll.w") == 382 and lua.eval("UI().regionButton.w") == 410
    items_before = lua.eval("#SR.db.items")
    out = lines(lua, 'Click(UI().generate) RunTimers() return Said()')
    assert lua.eval("SR.shown ~= nil") is True and lua.eval("#SR.shown.rows") > 0
    assert lua.eval("SR.auto.ids[1]") == 2319 and lua.eval("#SR.auto.ids") == 1
    assert lua.eval("#SR.db.items") == items_before, "profit choices stay separate from the selection"
    lua.execute("SR:SetBrowseMode('region')")
    assert lua.eval("SR:Context().items[2319]") is True
    lua.execute("SR:SetBrowseMode('item')")
    assert lua.eval("UI().regionButton.enabled") is True


def check_loot():
    lua = guide_env(loot=True)
    lua.execute("SR.db.ahPrices[5002] = {c = 100, at = 1}; SR.db.ahPrices[5003] = {c = 1000, at = 1}")
    assert lua.eval("SR:LootPrice(5001)") == 30, "gray: vendor price"
    assert lua.eval("SR:LootPrice(5002)") == 100 and lua.eval("SR:LootPrice(5003)") == 1000, "white and green: AH when above vendor"
    lua.execute("SR.db.ahPrices[5003] = {c = 50, at = 1}")
    assert lua.eval("SR:LootPrice(5003)") == 200, "vendor when above the AH price"
    lua.execute("SR.db.ahPrices[5003] = {c = 1000, at = 1}; SR.db.ahPrices[5001] = {c = 9999, at = 1}")
    assert lua.eval("SR:LootPrice(5001)") == 30, "gray never uses the AH"
    lua.execute("SR.db.prices[5001] = 77")
    assert lua.eval("SR:LootPrice(5001)") == 77, "manual price first"
    lua.execute("SR.db.prices[5001] = nil")
    per = lua.eval("SR.Rules.lootValue(1, {lootData = SR.Loot.creatures, lootPrice = function(id) return SR:LootPrice(id) end})")
    assert abs(per - 130) < 1e-6, per
    assert lua.eval("SR:LootAvailable()") is True and lua.eval("SR:LootEnabled()") is True, "loot counts in every view"
    lua.execute("SR:SetBrowseMode('profit')")
    assert lua.eval("SR:LootEnabled()") is True
    on = lua.eval("SR:AutoPlan('Test Valley')")
    assert on.lootPerHour > 0 and on.skinPerHour > 0 and abs(on.perHour - on.skinPerHour - on.lootPerHour) < 1e-6
    assert on.eval.lootValue > 0 and abs(on.eval.value - on.eval.skinValue - on.eval.lootValue) < 1e-6
    assert "off" in lines(lua, 'return Slash("loot off")')
    off = lua.eval("SR:AutoPlan('Test Valley')")
    assert off.lootPerHour == 0 and abs(off.perHour - off.skinPerHour) < 1e-6
    assert abs(off.skinPerHour - on.skinPerHour) < 1e-6
    assert "Usage" in lines(lua, 'return Slash("loot maybe")')
    assert "on" in lines(lua, 'return Slash("loot on")')
    assert "Mob loot: on" in lines(lua, 'return Slash("loot")')


def check_loot_ui():
    lua = guide_env(loot=True)
    lua.execute("SR.db.ahPrices[5002] = {c = 100, at = 1}; SR.db.ahPrices[5003] = {c = 1000, at = 1}; SR:SetBrowseMode('profit')")
    assert lua.eval("UI().lootCheck.shown") is True
    assert lua.eval("UI().height") == 472 + 36 and lua.eval("UI().listScroll.h") == 216
    row = lua.eval("UI().rows[1]")
    assert "Leather" in row.sub.text and "Loot" in row.sub.text, row.sub.text
    assert row.sub2.text.startswith("-> "), row.sub2.text
    lua.execute("Click(UI().generate) RunTimers()")
    assert lua.eval("SR.shown.rows[1].eval.lootValue") > 0
    lua.execute("UI().lootCheck:SetChecked(false); Click(UI().lootCheck)")
    assert lua.eval("SR.db.loot") is False and lua.eval("UI().height") == 472
    assert lua.eval("UI().rows[1].sub.text").startswith("-> ") and lua.eval("UI().rows[1].sub2.text") == ""
    lua.execute("SR:SetBrowseMode('region')")
    assert lua.eval("UI().lootCheck.shown") is False
    plain = guide_env()
    plain.execute("SR:SetBrowseMode('profit')")
    assert plain.eval("UI().lootCheck.shown") is False and plain.eval("UI().height") == 472


BIG_FIXTURE = r'''
SkinRoute_Data = {
  items = {[2319] = "Medium Leather"},
  creatures = {
    [1] = {n = "Gray Bear", l = {21, 22}, s = "c", d = {[2319] = {50, 1, 1}}},
    [2] = {n = "Old Wolf", l = {22, 22}, s = "c", d = {[2319] = {30, 1, 1}}},
    [3] = {n = "Big Devil", l = {23, 23}, s = "c", e = 1, d = {[2319] = {100, 1, 2}}},
  },
  zones = {
    ["Test Valley"] = {
      [1] = {19, 19, 20, 19, 21, 19, 19, 20, 20, 20, 21, 20, 19, 21, 20, 21, 21, 21, 20, 22, 19, 22, 21, 22, 22, 22, 22, 21, 22, 20, 22, 19, 18, 19, 18, 20, 18, 21, 18, 22, 19, 23, 20, 23, 21, 23, 22, 23, 17, 20, 17, 21, 17, 22, 23, 20, 23, 21, 23, 22, 24, 21, 24, 22, 16, 21, 16, 22, 25, 21, 25, 22, 26, 21, 26, 22},
      [2] = {20, 20, 20, 21, 21, 20, 21, 21, 22, 22},
      [3] = {20, 20, 21, 20, 20, 21},
    },
  },
}
'''


def big_env():
    lua = env(data=BIG_FIXTURE)
    lua.execute("TomTom.NameToMapId['Test Valley'] = 77; SR.mapsBuilt = false")
    for c in ("items medium leather", "level 24", "skill 300", "price medium leather: 3420"):
        lines(lua, 'return Slash("%s")' % c)
    return lua


def check_radius_default():
    lua = env(pre="SkinRouteDB = {zoneRadius = 233}")
    assert lua.eval("SR.db.zoneRadius") == 350 and lua.eval("SR.db.radiusVersion") == 1, "an older setting is moved to 350 once"
    lines(lua, 'return Slash("radius 233")')
    assert lua.eval("SR.db.zoneRadius") == 233
    lua = env(pre="SkinRouteDB = {}")
    assert lua.eval("SR.db.zoneRadius") == 350
    lua = env(pre="SkinRouteDB = {zoneRadius = 233, radiusVersion = 1}")
    assert lua.eval("SR.db.zoneRadius") == 233, "a later choice is kept"


def check_elites():
    lua = big_env()
    assert abs(lua.eval("SR.Rules.killTime(0, 25, 10, 1.1, 3)") - 55) < 1e-9
    assert abs(lua.eval("SR.Rules.killTime(0, 25, 10, 1.1)") - 25) < 1e-9
    assert lua.eval("SR.db.elites") is False and lua.eval("SR.db.eliteFactor") == 3
    off = lua.eval("SR:EvaluateRegion('Test Valley', SR:Context())")
    expected = lua.eval("(#SkinRoute_Data.zones['Test Valley'][1] + #SkinRoute_Data.zones['Test Valley'][2]) / 2")
    assert off.total == expected, (off.total, expected)
    lines(lua, 'local s = Slash("zones test valley") RunTimers() return s .. Said()')
    pts_off = lua.eval("SR.shown.set.points")
    assert pts_off == expected
    names_off = lua.eval("SR:ZoneCreatures(SR.shown.rows[1].zone.entries, SR:Context(), 5)")
    assert all(not names_off[i].elite for i in range(1, 4) if names_off[i]), "no elite while the box is off"
    assert "Elite mobs: included" in lines(lua, 'return Slash("elites on")')
    lua.execute("RunTimers()")
    pts_on = lua.eval("SR.shown.set.points")
    assert pts_on == pts_off + 3, (pts_off, pts_on)
    top = lua.eval("SR:ZoneCreatures(SR.shown.rows[1].zone.entries, SR:Context(), 5)")
    elite_names = [top[i].name for i in range(1, 4) if top[i] and top[i].elite]
    assert elite_names == ["Big Devil"], elite_names
    on = lua.eval("SR:EvaluateRegion('Test Valley', SR:Context())")
    assert on.total == off.total + 3
    base = lua.eval("SR.Rules.killTime(1, 25, 10, 1.1)")
    elite = lua.eval("SR.Rules.killTime(1, 25, 10, 1.1, 3)")
    assert elite > base
    assert "Usage" in lines(lua, 'return Slash("elites factor 99")')
    assert "x5" in lines(lua, 'return Slash("elites factor 5")') and lua.eval("SR.db.eliteFactor") == 5
    assert "left out" in lines(lua, 'return Slash("elites off")')
    lines(lua, 'return Slash("")')
    lua.execute("Click(UI().optionsButton)")
    assert lua.eval("UI().elites.shown") is True and lua.eval("UI().elites.checked") is not None
    lua.execute("UI().elites:SetChecked(true); Click(UI().elites); RunTimers()")
    assert lua.eval("SR.db.elites") is True and lua.eval("SR.shown.set.points") == pts_on
    lua.execute("UI().elites:SetChecked(false); Click(UI().elites); RunTimers()")
    assert lua.eval("SR.db.elites") is False and lua.eval("SR.shown.set.points") == pts_off


def check_best_circles():
    lua = big_env()
    lua.execute("""
    local function row(id, perHour, skinnable, wx, wy, status)
        return {zone = {id = id, wx = wx, wy = wy}, eval = {status = status or "ok", perHour = perHour, dropsHour = perHour, skinnable = skinnable}}
    end
    local rows = {row(1, 100, 40, 0, 0), row(2, 90, 50, 100, 0), row(3, 80, 60, 800, 0), row(4, 200, 20, 900, 0), row(5, 300, 99, 2000, 0, "locked")}
    BEST = SR:PickBest({rows = rows, set = {radius = 350}, anyPrice = true})
    ROWS = rows
    """)
    assert lua.eval("BEST[1].zone.id") == 1 and lua.eval("BEST[2].zone.id") == 3, "the second best does not overlap the first"
    assert lua.eval("#BEST") == 2
    lua.execute("BEST = SR:PickBest({rows = {ROWS[4], ROWS[5]}, set = {radius = 350}, anyPrice = true})")
    assert lua.eval("#BEST") == 0, "under 35 mobs or locked: nothing"
    lua.execute("BEST = SR:PickBest({rows = {ROWS[1], ROWS[2]}, set = {radius = 350}, anyPrice = true})")
    assert lua.eval("#BEST") == 1 and lua.eval("BEST[1].zone.id") == 1, "only one place when the other one overlaps"

    lines(lua, 'local s = Slash("zones test valley") RunTimers() return s')
    assert lua.eval("SR.shown.best[1] ~= nil") is True and lua.eval("SR.shown.best[1].eval.skinnable") >= 35
    lua.execute("mapOpen = true; mapShown = 77; SR:UpdateOverlay()")
    color = lua.eval("LineAt(1).color")
    assert abs(color[1] - 1) < 1e-6 and abs(color[2] - 0.24) < 1e-6 and abs(color[3] - 0.95) < 1e-6, color
    texts = lines(lua, "return ShownTexts()")
    assert "/h" in texts and "Gray Bear" in texts and "Old Wolf" in texts and "mobs" in texts and "Big Devil" not in texts, texts
    lines(lua, 'return Slash("elites on")')
    lua.execute("RunTimers(); SR:UpdateOverlay()")
    assert "Big Devil (E)" in lines(lua, "return ShownTexts()")
    lines(lua, 'return Slash("elites off")')
    lua.execute("RunTimers()")
    lines(lua, 'local s = Slash("go test valley") RunTimers() return s')
    first = lua.eval("SR.guide.row.zone.id")
    assert first == lua.eval("SR.shown.best[1].zone.id"), "the guide starts with the best place"


def check_auto_plan():
    lua = zone_env()
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 300")')
    lines(lua, 'return Slash("price light leather: 500")')
    lines(lua, 'return Slash("price medium leather: 3000")')
    lines(lua, 'return Slash("price heavy leather: 100")')
    plan = lua.eval("SR:AutoPlan('Test Valley')")
    ids = [lua.eval("SR:AutoPlan('Test Valley').ids[%d]" % i) for i in (1, 2, 3)]
    assert ids[0] == 2319, ids
    assert plan.perHour > 0 and plan.usable is True
    lines(lua, 'return Slash("keep 100")')
    only = lua.eval("#SR:AutoPlan('Test Valley').ids")
    lines(lua, 'return Slash("keep 1")')
    wide = lua.eval("#SR:AutoPlan('Test Valley').ids")
    assert wide >= only
    assert abs(lua.eval("SR.db.autoKeep") - 1) < 1e-9
    assert "Usage" in lines(lua, 'return Slash("keep 0")')
    lines(lua, 'return Slash("skill 10")')
    locked = lua.eval("SR:AutoPlan('Test Valley')")
    assert locked.perHour == 0 and locked.usable is False
    assert lua.eval("#SR:AutoPlan('Test Valley').ids") >= 1
    lua.execute("SR:SetBrowseMode('profit')")
    rows = rows_of(lua, "rows")
    assert rows and "needs skinning" in rows[0] and "/h" not in rows[0], rows


def check_auto_no_price():
    lua = zone_env()
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 300")')
    lua.execute("SR.ItemPrice = function() return nil end; SR:SetBrowseMode('profit')")
    assert lua.eval("SR:AnyPrice()") is False
    assert "scan the auction house" in lua.eval("UI().regionButton.text")
    assert "items per hour" in lua.eval("UI().listTitle.text")
    rows = rows_of(lua, "rows")
    assert rows and "items/h" in rows[0], rows


def check_label_font_scales():
    lua = guide_env()
    lines(lua, 'return Slash("zones test valley")')
    lua.execute("RunTimers(); mapOpen = true; mapShown = 77; SR:UpdateOverlay()")
    size = lua.eval("(function() for _, c in ipairs(MapFrame().children) do if c.kind == 'fontstring' and c.shown and c.fontPx then return c.fontPx end end end)()")
    assert size is not None and 6 <= size <= 16, size
    texts = ShownTextsOf(lua)
    assert (":%d:%d:" % (size, size)) in texts, (size, texts)


def ShownTextsOf(lua):
    return lua.eval("ShownTexts()")


def check_prices_end_of_line():
    lua = guide_env()
    lines(lua, 'return Slash("")')
    rows = rows_of(lua, "rows")
    medium = [r for r in rows if "Medium Leather" in r][0]
    assert medium.endswith(lua.eval("SR.Money(3420)")), medium
    assert not rows[0].endswith(lua.eval("SR.Money(3420)"))
    assert "no price" in rows[0], rows[0]


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
    assert lua.eval("SR.db.optionsShown") is True and lua.eval("UI().height") == 692 and lua.eval("UI().optionsButton.text") == "Options -"
    assert all(lua.eval("UI().optionWidgets[%d].shown" % i) is True for i in range(1, lua.eval("#UI().optionWidgets") + 1))
    lua.execute("SR:SetBrowseMode('value')")
    assert lua.eval("UI().height") == 702
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


PRICE_MOCK = r"""
date = os.date; time = os.time
VENDOR = {[2318] = 15, [2319] = 50, [4234] = 150}
GetItemInfo = function(id) return "Item" .. id, nil, nil, nil, nil, nil, nil, nil, nil, nil, VENDOR[id] end
AH = {[2319] = 3420}
dbUpdate = nil
Auctionator = {API = {v1 = {
    GetAuctionPriceByItemID = function(caller, id) return AH[id] end,
    RegisterForDBUpdate = function(caller, fn) dbUpdate = fn end,
}}}
"""


def price_env(extra="", pre="", data=ZONE_FIXTURE):
    lua = env(data=data, pre=PRICE_MOCK + "\n" + pre)
    lua.execute("TomTom.NameToMapId['Test Valley'] = 77; SR.mapsBuilt = false")
    lua.execute(extra)
    return lua


def check_prices():
    lua = env(data=ZONE_FIXTURE)
    lua.execute("date = os.date; time = os.time")
    assert lua.eval("(SR:ItemPrice(2319))") is None and lua.eval("SR:ReadPrices()") == 0
    assert "vendor only" in lua.eval("SR.PriceLine()")

    lua = price_env(pre="Auctionator = nil")
    price, source = lua.eval("SR:ItemPrice(2319)")
    assert (price, source) == (50, "vendor")
    assert lua.eval("(SR:ItemPrice(9999))") is None

    lua = price_env()
    assert lua.eval("SR:ReadPrices()") == 1, "InitPrices already read it"
    price, source, at = lua.eval("SR:ItemPrice(2319)")
    assert (price, source) == (3420, "ah") and at > 0
    assert lua.eval("select(2, SR:ItemPrice(2318))") == "vendor"
    assert "Auctionator scan of" in lua.eval("SR.PriceLine()")
    lua.execute("SR.db.prices[2319] = 5000")
    assert tuple(lua.eval("SR:ItemPrice(2319)"))[:2] == (5000, "manual")
    out = lines(lua, 'return Slash("price medium leather: off")')
    assert "Medium Leather: 34s 20c (ah)" in out, out
    assert "Medium Leather: 1s 0c (manual)" not in out
    out = lines(lua, 'return Slash("price medium leather: 777")')
    assert "Medium Leather: 7s 77c (manual)" in out, out
    lines(lua, 'return Slash("price medium leather: off")')
    assert "Usage: /sr price" in lines(lua, 'return Slash("price : 5")')

    lua.execute("AH[2319] = 'x'; AH[2318] = 0; AH[4234] = -5")
    assert lua.eval("SR:ReadPrices()") == 0 and lua.eval("(SR:ItemPrice(2319))") == 3420, "bad values keep the memory"
    lua.execute("issecretvalue = function(v) return v == 999 end; AH[2319] = 999")
    assert lua.eval("SR:ReadPrices()") == 0 and lua.eval("(SR:ItemPrice(2319))") == 3420
    lua.execute("issecretvalue = nil; AH[2319] = 4000; local f = EventFrame('AUCTION_HOUSE_CLOSED'); f.scripts.OnEvent(f, 'AUCTION_HOUSE_CLOSED')")
    assert lua.eval("(SR:ItemPrice(2319))") == 4000
    lua.execute("AH[2319] = 4500; dbUpdate()")
    assert lua.eval("(SR:ItemPrice(2319))") == 4500
    lua.execute("Auctionator.API.v1.GetAuctionPriceByItemID = function() error('boom') end")
    assert lua.eval("SR:ReadPrices()") == 0 and lua.eval("(SR:ItemPrice(2319))") == 4500

    lua = price_env()
    out = lines(lua, 'return Slash("prices")')
    assert "Auctionator found, API v1 price function present" in out and "Medium Leather (2319) from Auctionator: 34s 20c" in out, out
    assert "1 of 3 item(s) priced and remembered" in out and "Auctionator scan of" in out, out
    lua = price_env(pre="Auctionator = nil")
    assert "Auctionator not found" in lines(lua, 'return Slash("prices")')
    lua = price_env(pre="AH = {}")
    assert "none (no scan yet?)" in lines(lua, 'return Slash("prices")')

    lua = price_env(pre="Auctionator = nil; VENDOR = {[2319] = 50}")
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 30")')
    lines(lua, 'return Slash("skill 300")')
    out = lines(lua, 'return Slash("regions")')
    assert "~" not in out and "items" not in out.split("\n")[1], out
    assert lua.eval("select(3, SR:RankRegions(SR:Context()))") is True, "vendor prices count as prices"

    lua = price_env()
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("")')
    lua.execute("SR:SetBrowseMode('value')")
    items = rows_of(lua, "valItemRows")
    assert "Medium Leather" in items[0] and "UI-SilverIcon" in items[0] and "AH" in items[0], items
    assert "vendor" in items[1] and "vendor" in items[2], items
    assert "Auctionator scan of" in lua.eval("UI().valInfo.text")
    lua.execute("SR.db.prices[2318] = 99; SR:RefreshZones()")
    items = rows_of(lua, "valItemRows")
    assert any("manual" in i and "Light Leather" in i for i in items), items
    lua.execute("VENDOR = {}; SR.db.prices = {}; SR.db.ahPrices = {}; SR:RefreshZones()")
    items = rows_of(lua, "valItemRows")
    assert all("no price" in i for i in items), items


LOOT_MOCK = r"""
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
BAGS = {}
GetItemCount = function(id) return BAGS[id] or 0 end
function Link(id, name) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r" end
function Loot(text) local f = EventFrame("CHAT_MSG_LOOT"); f.scripts.OnEvent(f, "CHAT_MSG_LOOT", text) end
function Cast(event, spell, unit) SR.CastEvent(event, unit or "player", "guid", spell) end
"""


def SK(lua):
    names = lines(lua, "return SR.StatsText().names").split("\n")
    out = []
    for n in names[1:]:
        if n == "":
            break
        out.append(n)
    return "\n".join(out)


def stats_env():
    lua = price_env(LOOT_MOCK)
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 30")')
    lines(lua, 'return Slash("skill 300")')
    lines(lua, 'return Slash("price medium leather: 3420")')
    return lua


def check_stats():
    lua = stats_env()
    lines(lua, 'return Slash("stats")')
    win = "SkinRouteStatsFrame"
    assert lua.eval(win + ".shown") is True and lua.eval(win + ".duration.text") == "Guide time: 0:00:00, 0 skinned, 0 kills"
    assert lua.eval(win + ".rows[1].name.text") == "No guide yet."
    assert lua.eval(win + ".total.text") == "Total: 0" + "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t"
    lines(lua, 'return Slash("stats")')
    assert lua.eval(win + ".shown") is False and lua.eval("SR.db.statsWindow.shown") is False

    lines(lua, 'local s = Slash("go test valley") RunTimers() return s')
    lua.execute("Loot('You receive loot: ' .. Link(2319, 'Medium Leather') .. 'x2.')")
    assert SK(lua) == "Nothing skinned yet."

    lua.execute("Cast('UNIT_SPELLCAST_START', 8613)")
    lua.execute("Loot('You receive loot: ' .. Link(2319, 'Medium Leather') .. 'x2.')")
    lua.execute("Loot('You receive loot: ' .. Link(2318, 'Light Leather') .. '.')")
    lua.execute("Loot('Bob receives loot: ' .. Link(2319, 'Medium Leather') .. '.')")
    lua.execute("Cast('UNIT_SPELLCAST_SUCCEEDED', 8613)")
    lua.execute("Cast('UNIT_SPELLCAST_START', 9999, 'party1'); Cast('UNIT_SPELLCAST_SUCCEEDED', 8613, 'party1')")
    names = SK(lua).split("\n")
    assert names == ["Medium Leather x2", "Light Leather x1"], names
    text = lua.eval("SR.StatsText()")
    assert text.duration == "Guide time: 0:00:00, 1 skinned, 0 kills", text.duration
    assert "68|TInterface\\MoneyFrame\\UI-SilverIcon" in text.total and "unpriced" not in text.total, text.total
    lua.execute("VENDOR[2318] = nil")
    assert "(1 unpriced)" in lua.eval("SR.StatsText().total") and "no price" in lua.eval("SR.StatsText().values")
    lua.execute("VENDOR[2318] = 15")
    lua.execute("now = now + 9; RunTimers()")
    lua.execute("Loot('You receive loot: ' .. Link(4234, 'Heavy Leather') .. '.')")
    assert "Heavy Leather" not in SK(lua), "loot after the window does not count"

    lua.execute("now = now + 3600")
    text = lua.eval("SR.StatsText()")
    assert text.duration.startswith("Guide time: 1:00:09") and "/h" in text.perHour and "..." not in text.perHour

    lua.execute("Cast('UNIT_SPELLCAST_START', 4321)")
    lua.execute("Loot('You receive loot: ' .. Link(4234, 'Heavy Leather') .. '.')")
    assert "Heavy Leather" not in SK(lua), "not a skinning spell"
    lua.execute("C_Spell = {GetSpellName = function(id) if id == 7777 then return 'Dépeçage' end end}")
    lua.execute("Cast('UNIT_SPELLCAST_START', 7777)")
    lua.execute("Loot('You receive loot: ' .. Link(4234, 'Heavy Leather') .. '.')")
    assert "Heavy Leather x1" in SK(lua), "a skinning spell is recognised by its name"
    lua.execute("Cast('UNIT_SPELLCAST_FAILED', 7777); now = now + 9; RunTimers()")

    lines(lua, 'return Slash("stats")')
    assert lua.eval(win + ".rows[2].name.text") == "Medium Leather x2" and "UI-SilverIcon" in lua.eval(win + ".rows[2].value.text")
    lua.execute("Click(" + win + ".resetButton)")
    assert SK(lua) == "Nothing skinned yet." and lua.eval("SR.StatsText().duration") == "Guide time: 0:00:00, 0 skinned, 0 kills"
    lua.execute("BAGS[2318] = 3; Cast('UNIT_SPELLCAST_START', 8613)")
    lua.execute("BAGS[2318] = 5; issecretvalue = function(v) return v == 'SECRET' end; Loot('SECRET')")
    lua.execute("Cast('UNIT_SPELLCAST_SUCCEEDED', 8613); now = now + 9; RunTimers()")
    assert SK(lua) == "Light Leather x2", "the bags settle a window with unreadable loot"
    lines(lua, 'return Slash("stats")')
    lua.execute("local f = SkinRouteStatsFrame; f.scripts.OnHide(f)")

    lines(lua, 'return Slash("stop")')
    assert "(stopped)" in lua.eval("SR.StatsText().duration")
    lua.execute("Cast('UNIT_SPELLCAST_START', 8613); Loot('You receive loot: ' .. Link(4234, 'Heavy Leather') .. '.')")
    assert "Heavy Leather" not in SK(lua), "a stopped session counts nothing"
    lua.execute("SR.StatsReset()")
    assert "(stopped)" in lua.eval("SR.StatsText().duration")
    lines(lua, 'return Slash("stats reset")')

    lua = price_env(LOOT_MOCK, pre="SkinRouteDB = {statsWindow = {shown = true}}")
    assert lua.eval("SkinRouteStatsFrame.shown") is True, "the stats window reopens when it was open"
    lines(lua, 'return Slash("items medium leather")')
    lines(lua, 'return Slash("level 30")')
    lines(lua, 'return Slash("skill 300")')
    lines(lua, 'return Slash("go test valley")')
    lines(lua, 'return Slash("skip")')
    lines(lua, 'return Slash("skip")')
    assert "(stopped)" in lua.eval("SR.StatsText().duration"), "the guide ended with no more zone"
    lines(lua, 'return Slash("")')
    lua.execute("Click(UI().statsButton)")
    assert lua.eval("SkinRouteStatsFrame.shown") is False
    lua.execute("Click(UI().statsButton)")
    assert lua.eval("SkinRouteStatsFrame.shown") is True
    lua.execute("Click(UI().statsButton); RunTimers()")


def check_stats_kills():
    lua = stats_env()
    lua.execute("""
    YOU_LOOT_MONEY = "You loot %s."
    GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
    SR.Loot = {items = {[5001] = {"Gray Fang", 0, 30}, [5002] = {"Linen Cloth", 1, 13}, [5003] = {"Green Cape", 2, 200}}, creatures = {}}
    SR.db.ahPrices[5002] = {c = 100, at = 1}
    SR.db.ahPrices[5003] = {c = 1000, at = 1}
    function LinkQ(id, name, color) return "|cff" .. color .. "|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r" end
    function Ev(event, text) local f = EventFrame("CHAT_MSG_LOOT"); f.scripts.OnEvent(f, event, text) end
    function Open(guid) GetLootSourceInfo = function() return guid end; Ev("LOOT_OPENED") end
    function KillLoot(text) Ev("CHAT_MSG_LOOT", "You receive loot: " .. text .. ".") end
    """)
    lines(lua, 'local s = Slash("go test valley") RunTimers() return s')
    lua.execute("Ev('CHAT_MSG_MONEY', 'You loot 5 Gold')")
    assert lua.eval("(SR.StatsTotal())") == 0, "no loot window: nothing counts"

    lua.execute("Open('Creature-0-1-2-3-4-5')")
    lua.execute("Ev('CHAT_MSG_MONEY', 'You loot 1 Gold, 87 Silver, 3 Copper.')")
    lua.execute("Ev('CHAT_MSG_MONEY', 'Bob loots 9 Gold.')")
    lua.execute("KillLoot(LinkQ(5001, 'Gray Fang', '9d9d9d') .. 'x3')")
    lua.execute("KillLoot(LinkQ(5002, 'Linen Cloth', 'ffffff') .. 'x2')")
    lua.execute("KillLoot(LinkQ(5003, 'Green Cape', '1eff00'))")
    lua.execute("KillLoot(LinkQ(6000, 'Blue Sword', '0070dd'))")
    lua.execute("Ev('LOOT_CLOSED')")
    lua.execute("Open('Creature-0-1-2-3-4-5'); Ev('LOOT_CLOSED')")
    assert lua.eval("SR.StatsText().duration") == "Guide time: 0:00:00, 0 skinned, 1 kills", lua.eval("SR.StatsText().duration")
    names = lines(lua, "return SR.StatsText().names").split("\n")
    assert "Kills (mob loot)" in names[names.index("") + 1], names
    kills = names[names.index("") + 2:]
    assert kills == ["Gold coins", "Green Cape x1", "Linen Cloth x2", "Gray items x3 (vendor)"] or sorted(kills) == sorted(["Gold coins", "Green Cape x1", "Linen Cloth x2", "Gray items x3 (vendor)"]), kills
    assert all("Blue Sword" not in n for n in names), "blue items are left out"
    expected = 18703 + 200 + 1000 + 90
    assert lua.eval("(SR.StatsTotal())") == expected, lua.eval("(SR.StatsTotal())")
    lua.execute("SR.db.ahPrices[5003] = {c = 50, at = 1}")
    assert lua.eval("(SR.StatsTotal())") == 18703 + 200 + 200 + 90, "vendor price when above the AH price"
    lua.execute("SR.db.ahPrices[5003] = {c = 1000, at = 1}")

    lua.execute("now = now + 3; KillLoot(LinkQ(5002, 'Linen Cloth', 'ffffff'))")
    assert lua.eval("(SR.StatsTotal())") == expected, "after the grace the window is closed"
    lua.execute("Open('GameObject-0-1-2-3-4-5'); KillLoot(LinkQ(5002, 'Linen Cloth', 'ffffff')); Ev('LOOT_CLOSED')")
    assert lua.eval("(SR.StatsTotal())") == expected, "gathering loot is not a kill"
    lua.execute("Open('Creature-0-9-9-9-9-9'); KillLoot(LinkQ(5002, 'Linen Cloth', 'ffffff')); Ev('LOOT_CLOSED')")
    assert lua.eval("SR.StatsText().duration").endswith("2 kills") and lua.eval("(SR.StatsTotal())") == expected + 100

    lua.execute("Cast('UNIT_SPELLCAST_START', 8613); Open('Creature-0-9-9-9-9-9')")
    lua.execute("Ev('CHAT_MSG_LOOT', 'You receive loot: ' .. Link(2319, 'Medium Leather') .. 'x2.')")
    lua.execute("Cast('UNIT_SPELLCAST_SUCCEEDED', 8613); Ev('LOOT_CLOSED')")
    assert SK(lua) == "Medium Leather x2", "inside a skinning cast the loot is skinning"
    lua.execute("Open('Creature-0-8-8-8-8-8'); KillLoot(LinkQ(5001, 'Gray Fang', '9d9d9d'))")
    assert "Gray items x4 (vendor)" in lines(lua, "return SR.StatsText().names"), "the skinning window was closed by the loot window"

    win = "SkinRouteStatsFrame"
    lines(lua, 'return Slash("stats")')
    assert lua.eval(win + ".lootCheck.checked") is not None
    lua.execute(win + ".lootCheck:SetChecked(false); Click(" + win + ".lootCheck)")
    assert lua.eval("SR.db.statsWindow.countLoot") is False
    assert "Kills" not in lines(lua, "return SR.StatsText().names") and "kills" not in lua.eval("SR.StatsText().duration")
    before = lua.eval("(SR.StatsTotal())")
    lua.execute("Open('Creature-0-7-7-7-7-7'); KillLoot(LinkQ(5003, 'Green Cape', '1eff00'))")
    assert lua.eval("(SR.StatsTotal())") == before, "nothing is counted while the box is off"
    lua.execute(win + ".lootCheck:SetChecked(true); Click(" + win + ".lootCheck)")
    assert lua.eval("SR.db.statsWindow.countLoot") is True

    lines(lua, 'return Slash("stop")')
    lua.execute("Open('Creature-0-6-6-6-6-6'); KillLoot(LinkQ(5003, 'Green Cape', '1eff00'))")
    assert "Green Cape x2" not in lines(lua, "return SR.StatsText().names"), "a stopped session counts nothing"


def check_stats_events():
    lua = stats_env()
    assert lua.eval("#SR.castEvents") == 7
    lua = price_env(LOOT_MOCK, pre="failUnitEvent = 'UNIT_SPELLCAST_CHANNEL_START'")
    assert lua.eval("#SR.castEvents") == 6
    lines(lua, 'return Slash("items medium leather")')
    lua.execute("SR:StatsStart(); Cast('UNIT_SPELLCAST_START', 8613); Loot('You receive loot: ' .. Link(2319, 'Medium Leather') .. '.')")
    assert SK(lua) == "Medium Leather x1"


def check_toc_and_bindings():
    import xml.etree.ElementTree as ET
    folder = os.path.join(ROOT, "SkinRoute")
    toc = [l.strip().replace("\\", "/") for l in open(os.path.join(folder, "SkinRoute.toc"), encoding="utf8") if l.strip() and not l.startswith("#")]
    on_disk = {f for f in os.listdir(folder) if f.endswith(".lua")}
    assert on_disk == {f for f in toc if f.endswith(".lua") and "/" not in f}, (on_disk ^ set(toc))
    assert toc[0] == "Data/SkinData.lua" and toc.index("Core.lua") < toc.index("Locale.lua") < toc.index("Resolver.lua")
    assert "Bindings.xml" not in toc, "Bindings.xml is loaded by the client without being listed"
    lua = env()
    bindings = ET.parse(os.path.join(folder, "Bindings.xml")).getroot().findall("Binding")
    assert [b.get("name") for b in bindings] == ["SKINROUTE_SKIP", "SKINROUTE_STOP", "SKINROUTE_WINDOW", "SKINROUTE_STATS"]
    assert bindings[0].get("header") == "SKINROUTE" and all(b.get("header") is None for b in bindings[1:])
    assert lua.eval("BINDING_HEADER_SKINROUTE") == "SkinRoute"
    for b in bindings:
        call = re.fullmatch(r"\s*SkinRoute:(\w+)\(\)\s*", b.text)
        assert call and lua.eval("type(SkinRoute.%s)" % call.group(1)) == "function", b.text
        assert isinstance(lua.eval("BINDING_NAME_" + b.get("name")), str)


def check_skip_button():
    lua = guide_env()
    lines(lua, 'return Slash("button")')
    assert lua.eval("SkinRouteSkipButton.shown") is True and lua.eval("SkinRouteSkipButton.text") == "Skip"
    assert lua.eval("SR.db.skipButton.shown") is True
    assert lua.eval("SkinRouteSkipButton.px") == 0 and lua.eval("SkinRouteSkipButton.py") == -200
    lines(lua, 'local s = Slash("go test valley") RunTimers() return s')
    assert abs(lua.eval("waypoints[1].x") - 0.2) < 0.01
    lua.execute("Click(SkinRouteSkipButton)")
    assert abs(lua.eval("waypoints[1].x") - 0.8) < 0.01, "the button skips to the next zone"
    lua.execute("local b = SkinRouteSkipButton; b.scripts.OnEnter(b); b.scripts.OnLeave(b)")

    lua.execute("local b = SkinRouteSkipButton; shift = false; b.scripts.OnDragStart(b)")
    assert lua.eval("SkinRouteSkipButton.moving") is not True
    lua.execute("local b = SkinRouteSkipButton; shift = true; b.scripts.OnDragStart(b); b.scripts.OnDragStop(b)")
    assert lua.eval("SkinRouteSkipButton.moving") is False
    pos = lua.eval("SR.db.skipButton.pos")
    assert [pos[1], pos[2], pos[3], pos[4]] == ["CENTER", "CENTER", 10, 20]
    lines(lua, 'return Slash("button")')
    assert lua.eval("SkinRouteSkipButton.shown") is False and lua.eval("SR.db.skipButton.shown") is False

    lua = guide_env()
    lua = env(data=ZONE_FIXTURE, pre="SkinRouteDB = {skipButton = {shown = true, pos = {'TOP', 'TOP', 5, -6}}}")
    assert lua.eval("SkinRouteSkipButton.shown") is True and lua.eval("SkinRouteSkipButton.px") == 5 and lua.eval("SkinRouteSkipButton.py") == -6
    lua = env(data=ZONE_FIXTURE)
    assert lua.eval("SkinRouteSkipButton") is None, "the button is built on demand"
    assert "/sr button" in lines(lua, 'return Slash("help")')


FR_PRE = r"""
GetLocale = function() return "frFR" end
TomTom.NameToMapId = {["Contreforts de Hautebrande"] = 25, ["Forêt d'Elwynn"] = 37}
FRN = {[2318] = "Cuir léger", [2319] = "Cuir intermédiaire", [4234] = "Cuir lourd"}
GetItemInfo = function(id) return FRN[id], nil, nil, nil, nil, nil, nil, nil, nil, nil, 50 end
"""


def check_french():
    lua = env(pre=FR_PRE)
    assert lua.eval("SR.RegionLabel('Hillsbrad Foothills')") == "Contreforts de Hautebrande"
    assert lua.eval("SR.RegionLabel(\"Un'Goro Crater\")") == "Cratère d'Un'Goro" and lua.eval("SR.RegionLabel('Test Valley')") == "Test Valley"
    names = lua.eval("SR.RegionNames('Hillsbrad Foothills')")
    assert [names[1], names[2]] == ["Hillsbrad Foothills", "Contreforts de Hautebrande"]
    assert lua.eval("SR.RegionNames('Test Valley')")[2] is None
    assert lua.eval("SR:FindRegion('hautebrande')") == "Hillsbrad Foothills" and lua.eval("SR:FindRegion('hillsbrad')") == "Hillsbrad Foothills"
    assert lua.eval("SR:FindRegion(\"foret d'elwynn\")") == "Elwynn Forest" and lua.eval("SR:FindRegion('cratere')") == "Un'Goro Crater"
    lua.execute("SR:BuildMaps()")
    assert lua.eval("SR:GetRegionMapID('Hillsbrad Foothills')") == 25 and lua.eval("SR:GetRegionMapID('Elwynn Forest')") == 37
    assert lua.eval("(SR:GetCurrentRegion())") == "Hillsbrad Foothills"

    assert lua.eval("SR:ItemLabel(2319)") == "Cuir intermédiaire"
    names = lua.eval("SR:ItemNames(2319)")
    assert [names[1], names[2]] == ["Medium Leather", "Cuir intermédiaire"]
    assert lua.eval("SR:FindItems({'cuir interm'})[1]") == 2319 and lua.eval("SR:FindItems({'medium leather'})[1]") == 2319
    assert lua.eval("#SR:FindItems({'cuir'})") == 3
    assert "Items: Cuir intermédiaire" in lines(lua, 'return Slash("items cuir interm")')
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    out = lines(lua, 'return Slash("regions")')
    assert "Contreforts de Hautebrande" in out and "Hillsbrad Foothills" not in out and "Cuir intermédiaire" in out, out
    assert "Contreforts de Hautebrande: ok" in lines(lua, 'return Slash("region hautebrande")')
    assert "Cuir intermédiaire: " in lines(lua, 'return Slash("price cuir interm: 100")')

    lines(lua, 'return Slash("")')
    assert lua.eval("UI().regionButton.text") == "Contreforts de Hautebrande"
    rows = rows_of(lua, "rows")
    assert any("Cuir intermédiaire" in r for r in rows) and not any("Medium Leather" in r for r in rows), rows
    lua.execute("Click(UI().regionButton)")
    texts = [lua.eval("UI().regionPopupRows[%d].text" % i) for i in range(1, 4)]
    assert texts == ["Forêt d'Elwynn", "Contreforts de Hautebrande", "Cratère d'Un'Goro"], texts
    lua.execute("UI().regionSearch:SetText('haute'); UI().regionSearch.scripts.OnTextChanged()")
    assert lua.eval("#UI().regionMatches") == 1
    lua.execute("UI().regionSearch:SetText('hillsbrad'); UI().regionSearch.scripts.OnTextChanged()")
    assert lua.eval("#UI().regionMatches") == 1, "the English name still finds the region"
    lua.execute("SR:SetBrowseMode('item')")
    assert lua.eval("UI().regionButton.text") == "Cuir intermédiaire" and "Contreforts de Hautebrande" in rows_of(lua, "rows")[0]
    lua.execute("SR:SetBrowseMode('value')")
    assert "Cuir intermédiaire" in rows_of(lua, "valItemRows")[0] and "Contreforts de Hautebrande" in rows_of(lua, "valZoneRows")[0]
    lua.execute("UI().valSearch:SetText('cuir lourd'); UI().valSearch.scripts.OnTextChanged()")
    assert lua.eval("UI().valTitle1.text") == "Leathers by value (1)"
    lua.execute("UI().valSearch:SetText('heavy'); UI().valSearch.scripts.OnTextChanged()")
    assert lua.eval("UI().valTitle1.text") == "Leathers by value (1)"
    lua.execute("SR:SetBrowseMode('region'); Click(UI().regionButton); UI().itemSearch:SetText('')")
    lua.execute("SR:SetBrowseMode('item'); Click(UI().regionButton)")
    assert any("Cuir lourd" in r for r in rows_of(lua, "itemPopupRows"))

    lua.execute("issecretvalue = function(v) return v == 'Cuir intermédiaire' end")
    assert lua.eval("SR:ItemLabel(2319)") == "Medium Leather", "a secret name falls back to the data name"
    lua.execute("issecretvalue = nil; FRN[2319] = nil")
    assert lua.eval("SR:ItemLabel(2319)") == "Medium Leather", "an item the client has not cached yet"
    assert lua.eval("SR:ItemLabel(424242)") == "424242"

    en = env()
    assert en.eval("SR.RegionLabel('Hillsbrad Foothills')") == "Hillsbrad Foothills" and en.eval("SR:ItemLabel(2319)") == "Medium Leather"
    assert en.eval("#SR.RegionNames('Hillsbrad Foothills')") == 2, "French names are accepted as input on any client"
    assert en.eval("SR:FindRegion('hautebrande')") == "Hillsbrad Foothills" and en.eval("#SR:ItemNames(2319)") == 1


def check_french_guide():
    lua = env(data=ZONE_FIXTURE, pre=FR_PRE + "\nTomTom.NameToMapId['Test Valley'] = 77")
    lines(lua, 'return Slash("items cuir interm")')
    lines(lua, 'return Slash("level 30")')
    lines(lua, 'return Slash("skill 300")')
    out = lines(lua, 'local s = Slash("go test valley") RunTimers() return s .. Said()')
    assert "Test Valley: 2 zone(s)" in out and "Go to 1." in out, out
    lua = env(pre=FR_PRE)
    lines(lua, 'return Slash("items cuir interm")')
    lines(lua, 'return Slash("level 24")')
    lines(lua, 'return Slash("skill 140")')
    out = lines(lua, 'local s = Slash("zones hautebrande") RunTimers() return s .. Said()')
    assert "not resolved" not in out and "Contreforts de Hautebrande:" in out, out
    lua.execute("TomTom.NameToMapId = {}; SR.mapsBuilt = false")
    assert "Contreforts de Hautebrande is not resolved to a map" in lines(lua, 'return Slash("zones hautebrande")')


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
    check_fill()
    check_label_font_scales()
    check_profit()
    check_radius_default()
    check_elites()
    check_best_circles()
    check_auto_plan()
    check_loot()
    check_loot_ui()
    check_auto_no_price()
    check_prices_end_of_line()
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
    check_prices()
    check_stats()
    check_stats_events()
    check_stats_kills()
    check_toc_and_bindings()
    check_skip_button()
    check_french()
    check_french_guide()
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
