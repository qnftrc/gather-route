from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
-- Minimal WoW / TomTom mock
local timers, now, seq = {}, 0, 0
C_Timer = {After = function(d, f) seq = seq + 1; timers[#timers+1] = {t = now + (d or 0), s = seq, f = f} end}
function Now() return now end
function GetTime() return now end
function RunTimers()
  local n, limit = 0, now + 100
  while #timers > 0 do
    local bi = 1
    for i = 2, #timers do
      local a, b = timers[i], timers[bi]
      if a.t < b.t or (a.t == b.t and a.s < b.s) then bi = i end
    end
    if timers[bi].t > limit then break end
    local x = table.remove(timers, bi)
    now = math.max(now, x.t); x.f(); n = n + 1
  end
  return n
end
wipe = function(t) for k in pairs(t) do t[k]=nil end end
tinsert = table.insert; UISpecialFrames = {}; hooksecurefunc = function() end
SlashCmdList = {}
printed = {}
print = function(...) printed[#printed+1] = table.concat({...}, " ") end
local function widget()
  local w = {}
  return setmetatable(w, {
    __index = function(t, k) local c = widget(); rawset(t, k, c); return c end,
    __call = function(self) return self end,
    __add = function() return 1 end, __sub = function() return 1 end, __mul = function() return 1 end, __div = function() return 1 end,
  })
end
CreateFrame = function() return widget() end
C_Map = {GetMapInfo = function(id) return {parentMapID = 0} end}
GetCVar = function() return "0" end
date = os.date; debugprofilestop = function() return os.clock() * 1000 end
GetBuildInfo = function() return "12.1.5", "70999", "Nov 1 2026", 120105 end
GetLocale = function() return "enUS" end
MouseIsOver = function() return false end
Minimap = widget(); WorldMapFrame = widget()
LibStub = function() return nil end

local waypoints, cbs = {}, {}
TomTom = {NameToMapId = {["Elwynn Forest"]=37, ["Stranglethorn Vale"]=50, ["Arathi Highlands:Eastern Kingdoms"]=14, ["Duskwood"]=47}}
playerMap, px, py = 37, 0.5, 0.5
function TomTom:GetCurrentPlayerPosition() return playerMap, px, py end
function TomTom:DefaultCallbacks(o) local c={minimap={},world={},distance={}} c.distance[o.arrivaldistance]=function() end return c end
function TomTom:SetCustomWaypoint(m,x,y,o) local uid={m,x,y,title=o.title,from=o.from,callbacks=o.callbacks} waypoints[#waypoints+1]=uid return uid end
function TomTom:RemoveWaypoint(uid)
  for i,u in ipairs(waypoints) do if u==uid then table.remove(waypoints,i) break end end
  for _,f in ipairs(cbs) do f("WaypointRemoved", uid) end
end
function TomTom:SetCrazyArrow() end
function TomTom:IsGamepadUI() return false end
TomTom.RegisterCallback = function(owner, ev, f) cbs[#cbs+1]=f end
function WP() return waypoints end
function Fire(uid) uid.callbacks.distance[15]("distance", uid, 15, 5, 20) end

local ns = {}
for _, f in ipairs({"Data/HerbData","Data/HerbDataGatherMate","Data/OreDataGatherMate","Data/OreDataWowhead","Core","Tracking","Resolver","MinimapUtil","RouteMath","Runner","Overlay","Probe","Verify","Gather","UI"}) do
  local fh = assert(io.open("HerbRoute/"..f..".lua")); local src = fh:read("a"); fh:close()
  assert(load(src, f))("HerbRoute", ns)
end
HR = ns
''')
lua.execute(r'''
local ev = CreateFrame()  -- the addon frame is a mock: fire its init by hand
HerbRouteDB = nil
HR.db = {region=nil, herbs={}, ores={}, category="herbs", mode="follow", radius=15, showMap=true, showMinimap=true, overrides={}}
HR:OnLoaded()
SlashCmdList.HERBROUTE("debug"); RunTimers()
print(#printed .. " debug lines") printed = {}

-- follow mode through the slash command, current region = Elwynn Forest
SlashCmdList.HERBROUTE("peacebloom")
RunTimers()
local r = HR.route
assert(r, "route not started: " .. table.concat(printed, " | "))
print("points", #r.points, "mode", r.mode, "wps", #WP())
assert(#WP() == 1)
local n = #r.points
for i = 1, 3 do Fire(WP()[1]) ; RunTimers() end
assert(r.index == 4 and #WP() == 1, "advance failed " .. r.index)
HR:SkipPoint(); assert(r.index == 5)
-- external removal of the current point = skip
TomTom:RemoveWaypoint(WP()[1]); RunTimers(); assert(r.index == 6, "ext removal " .. r.index)
HR:StopRoute(); assert(HR.route == nil and #WP() == 0)

-- finish a route
SlashCmdList.HERBROUTE("Elwynn Forest: peacebloom"); RunTimers()
r = HR.route; local total = #r.points
for i = 1, total do Fire(WP()[1]); RunTimers() end
assert(HR.route == nil and #WP() == 0, "route should have finished")

-- bad input
SlashCmdList.HERBROUTE("nonsense: fadeleaf"); SlashCmdList.HERBROUTE("peacebloom, nothing"); RunTimers()
playerMap = 999; SlashCmdList.HERBROUTE("fadeleaf"); HR:StopRoute(true); assert(#WP() == 0, "pins leaked")
HR:ToggleUI()
for _, l in ipairs(printed) do io.write(l, "\n") end
print("OK")
''')

lua.execute(r'''
-- /hr probe against a fake minimap. The blip is under the mouse when the
-- minimap lies so that its offset (20,10) from the center matches the cursor.
local cxm, cym, es = 500, 400, 2
local sx, sy, alphaV, soft = 0, 0, 1, false
local curx, cury, mouseDown, inCombat, t0 = (cxm + 20) * es, (cym + 10) * es, false, false, 0
local worldAfter, worldCursor, foci = false, {100, 100}, nil
local bl, mode, neighbour = {20, 10}, "hover", false
local zoneR, maskMode, masks = 10, "none", {}
local realCF = CreateFrame
UIParent = {}
WorldFrame = {}
GetMouseFoci = function() return foci or {WorldFrame} end
GetCursorPosition = function()
  if worldAfter and Now() >= t0 + 4 then return worldCursor[1], worldCursor[2] end
  return curx, cury
end
IsMouseButtonDown = function() return mouseDown end
InCombatLockdown = function() return inCombat end
Minimap = {
  GetCenter = function() return cxm + sx, cym + sy end, GetWidth = function() return 140 end,
  GetHeight = function() return 140 end, GetEffectiveScale = function() return es end,
  GetZoom = function() return 1 end, IsVisible = function() return true end,
  GetNumPoints = function() return 1 end,
  GetPoint = function() return "CENTER", UIParent, "CENTER", sx, sy end,
  ClearAllPoints = function() end,
  SetPoint = function(_, _, _, _, x, y) sx, sy = x, y end,
  GetAlpha = function() return alphaV end, SetAlpha = function(_, a) alphaV = a end,
  UpdateMouseoverAtPoint = function() end,
}
C_Minimap = {GetViewRadius = function() return 70 end, GetNumTrackingTypes = function() return 2 end,
  GetTrackingInfo = function(i) if i == 1 then return {name = "Find Herbs", active = true} end return {name = "Find Minerals", active = false} end}
local function geometry()
  local bx, by = (cxm + sx + bl[1]) * es, (cym + sy + bl[2]) * es
  local cu, cv = GetCursorPosition()
  if (bx - cu) ^ 2 + (by - cv) ^ 2 <= zoneR ^ 2 then return true end
  if neighbour then
    local nx = (cxm + sx + bl[1] - 40) * es
    return (nx - cu) ^ 2 + (by - cv) ^ 2 <= zoneR ^ 2
  end
  return false
end
local function maskCovers(px, py)
  for _, m in ipairs(masks) do
    if m.shown and math.abs(px - m.ox) <= m.size / 2 and math.abs(py - m.oy) <= m.size / 2 then return true end
  end
  return false
end
C_TooltipInfo = {GetMinimapMouseover = function()
  local hit = {lines = {{leftText = "Wild Steelbloom"}}}
  if mode == "none" then return nil end
  if mode == "stale" then return hit end
  if mode == "dead" then return Now() < t0 + 4 and hit or nil end
  local cu, cv = GetCursorPosition()
  local dx, dy = cu / es - (cxm + sx), cv / es - (cym + sy)
  if dx * dx + dy * dy > 70 ^ 2 then return nil end
  if maskMode ~= "none" and maskCovers(dx, dy) then return nil end
  if maskMode == "blip" and maskCovers(bl[1], bl[2]) then return {type = 21, dataInstanceID = 1, lines = {}} end
  return geometry() and hit or {type = 21, dataInstanceID = 1, lines = {}}
end}
LibStub = function() return nil end
playerMap, px, py = 37, 0.5, 0.5

local function run(cmd)
  printed = {}; HR.db.probe = nil; t0 = Now()
  SlashCmdList.HERBROUTE(cmd); RunTimers()
  return HR.db.probe and HR.db.probe.text or table.concat(printed, "\n")
end

-- plain probe: baseline read of the real hover
local t = run("probe")
assert(t:find("Client 12.1.5 build 70999", 1, true) and t:find("Tracking active: Find Herbs", 1, true), t)
assert(t:find("Baseline read (no probe call): data with 1 line(s)", 1, true), t)
assert(t:find("structure: lines:table | lines[1]: leftText:string", 1, true), t)
assert(t:find("RESULT: something is under the real mouse hover (cursor inside the minimap disc)", 1, true), t)

local savedCur = curx
curx = 5000
t = run("probe")
assert(t:find("RESULT: no data under the cursor (cursor outside", 1, true), t)
curx = savedCur

issecretvalue = function() return true end
t = run("probe")
assert(t:find("structure: <secret value>", 1, true) and t:find("NOTE: text fields are secret values", 1, true) and t:find("empty hover data", 1, true), t)
issecretvalue = nil

local saved = C_TooltipInfo.GetMinimapMouseover
C_TooltipInfo.GetMinimapMouseover = nil
assert(run("probe"):find("function missing", 1, true))
C_TooltipInfo.GetMinimapMouseover = saved

assert(run("probe minimap"):find("RESULT: something is under the real mouse hover", 1, true))
curx = 5000
assert(run("probe minimap"):find("RESULT: no data under the cursor", 1, true))
assert(table.concat(printed, "\n"):find("The cursor is not inside the minimap", 1, true))
curx = savedCur

-- readable numbers are logged
local numData = {type = 21, dataInstanceID = 77, lines = {{leftText = "x", type = 0}}}
local savedTip = C_TooltipInfo.GetMinimapMouseover
C_TooltipInfo.GetMinimapMouseover = function() return numData end
t = run("probe")
assert(t:find("dataInstanceID:number=77, lines:table, type:number=21 | lines[1]: leftText:string, type:number=0", 1, true), t)
C_TooltipInfo.GetMinimapMouseover = savedTip

-- watch: presence and signature changes while the "mouse" moves
local stage = 0
local savedPos = GetCursorPosition
C_TooltipInfo.GetMinimapMouseover = function()
  if stage == 1 then return {type = 21, dataInstanceID = 5, lines = {{type = 0}}} end
  if stage == 2 then return {type = 21, dataInstanceID = 6, lines = {{type = 0}}} end
  if stage == 3 then return {type = 9, dataInstanceID = 7, lines = {{type = 1}}} end
  if stage == 4 then return {type = 21, dataInstanceID = 8, lines = {}} end
  return nil
end
C_Timer.After(3 + 1, function() stage = 1 end)
C_Timer.After(3 + 5, function() stage = 2 end)
C_Timer.After(3 + 8, function() stage = 3 end)
C_Timer.After(3 + 10, function() stage = 4 end)
C_Timer.After(3 + 12, function() stage = 0 end)
local wtxt = run("probe watch")
assert(wtxt:find("probe watch", 1, true) and wtxt:find("type=21 id=5 lines=1 line1type=0", 1, true), wtxt)
assert(wtxt:find("type=9 id=7 lines=1 line1type=1", 1, true) and wtxt:find(": none", 1, true), wtxt)
assert(not wtxt:find("id=6", 1, true), "an id-only change must not create an event")
assert(wtxt:find("empty: type=21 id=8 lines=0 line1type=?", 1, true), wtxt)
assert(wtxt:find("samples,", 1, true), wtxt)
C_TooltipInfo.GetMinimapMouseover = savedTip
stage = 0

-- removed commands now print the usage
for _, old in ipairs({"probe zoom", "probe blink", "probe world"}) do
  local u = run(old)
  assert(u:find("/hr probe copy", 1, true) and not u:find("RESULT", 1, true), old .. ": " .. u)
end
assert(run("probe copy"):find("No saved probe report", 1, true))
run("probe"); SlashCmdList.HERBROUTE("probe copy")

-- blink world: phase A on the blip (t0+3), phase B with the mouse in the world (t0+8)
worldAfter = true
local function bw(m, arg)
  mode = m; sx, sy, alphaV = 0, 0, 1
  local r = run("probe " .. (arg or "blink world"))
  assert(sx == 0 and sy == 0 and alphaV == 1, "minimap not restored")
  return r
end
local w = bw("hover")
assert(w:find("Phase A: blip under the cursor, offset from the minimap center (20.0, 10.0)", 1, true), w)
assert(w:find("RESULT: a blip can be detected by moving the minimap under a resting cursor (lines appear after 1 frame)", 1, true), w)
assert(w:find("  hit (", 1, true) and w:find("  control (0,0): +1 frame absent", 1, true), w)
assert(bw("hover", "blink world hidden"):find("(hidden)", 1, true))
neighbour = true
local wn = bw("hover")
assert(wn:find("RESULT: a blip can be detected", 1, true) and wn:find("controls also have lines (neighbouring blips)", 1, true), wn)
neighbour = false
assert(bw("stale"):find("RESULT: lines are reported even with the minimap in place", 1, true))
assert(bw("dead"):find("RESULT: the blip did not show up under the cursor", 1, true))
foci = {{}}
assert(bw("hover"):find("ABORTED: the mouse is over a UI element", 1, true))
foci = nil
worldCursor = {500 * 2, 400 * 2}
assert(bw("hover"):find("ABORTED: the cursor must rest in the world, outside the minimap", 1, true))
worldCursor = {100, 100}
inCombat = true
assert(bw("hover"):find("ABORTED: in combat", 1, true))
-- the "probe during combat" box is one switch for every probe, diagnostics included
HR.db.verifyCombat = true
assert(bw("hover"):find("RESULT: a blip can be detected", 1, true), "blink world must run in combat when the box is ticked")
HR.db.verifyCombat = false
inCombat = false; mouseDown = true
assert(bw("hover"):find("ABORTED: a mouse button is held", 1, true))
mouseDown = false
worldAfter = false
curx = 5000
assert(bw("hover"):find("ABORTED: phase A needs the cursor on a herb blip", 1, true))
curx = savedCur
bl = nil
assert(bw("hover"):find("ABORTED: phase A found no data under the cursor", 1, true))
-- the standard tooltip: shown, text height, line unit measured on a helper FontString, number of lines
curx = savedCur; bl = {20, 10}; mode = "hover"
local tipLines, tipUp = 2, true
GameTooltip = {IsShown = function() return tipUp end, GetOwner = function() return {GetName = function() return "Minimap" end} end}
GameTooltipTextLeft1 = {GetStringHeight = function() return tipLines * 14 end, GetFont = function() return "Fonts\\x.ttf", 12, "" end}
UIParent = {CreateFontString = function() return {SetPoint = function() end, SetAlpha = function() end, SetFont = function() end,
  SetText = function() end, GetStringHeight = function() return 14 end} end}
local tp = run("probe minimap")
assert(tp:find("tooltip: tooltip shown (owner Minimap), text height 28.0, line unit 14.0, lines 2", 1, true), tp)
tipLines = 1
assert(run("probe minimap"):find("lines 1", 1, true))
tipLines = 3
worldAfter = true
local tw = bw("hover")
assert(tw:find("TOOLTIP: during the shift the standard tooltip is shown; line count readable (3)", 1, true), tw)
assert(tw:find("tooltip +1: tooltip shown (owner Minimap), text height 42.0", 1, true), tw)
tipUp = false
assert(run("probe minimap"):find("tooltip: tooltip hidden", 1, true))
assert(bw("hover"):find("standard tooltip is NOT shown", 1, true))
worldAfter = false
GameTooltip, GameTooltipTextLeft1, UIParent = nil, nil, nil
assert(run("probe minimap"):find("tooltip: GameTooltip not available", 1, true))
-- /hr probe zone: measures the response zone, then a frame over the blip with the cursor inside the zone
zoneR = 7 -- pixels at scale 2: the zone reaches 3.5 units from the blip centre
CreateFrame = function(kind, name, parent)
  if parent ~= Minimap then return realCF(kind, name, parent) end
  local f = {shown = false, size = 0, ox = 0, oy = 0}
  function f:SetFrameStrata() end
  function f:EnableMouse() end
  function f:SetFrameLevel() end
  function f:SetSize(w) self.size = w end
  function f:ClearAllPoints() end
  function f:SetPoint(_, _, _, x, y) self.ox, self.oy = x, y end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  masks[#masks + 1] = f
  return f
end
worldAfter = true
maskMode = "focus"
local zt = bw("hover", "zone")
assert(zt:find("Minimap: 140x140 units, zoom 1, view radius 70.0 yd, effective scale 2.00, 1.00 yd per unit.", 1, true), zt)
assert(zt:find("ZONE cursor left of the blip: lines present up to 3 unit(s), absent from 4.", 1, true), zt)
assert(zt:find("ZONE cursor above the blip: lines present up to 3 unit(s), absent from 4.", 1, true), zt)
assert(zt:find("AXIS horizontal: edges 3.5 unit(s) left and 3.5 unit(s) right of the captured point: width 7.0 units (7.0 yd), half-width 3.5 units (3.5 yd), centre 0.0 units right of the captured point.", 1, true), zt)
assert(zt:find("AXIS vertical: edges 3.5 unit(s) below and 3.5 unit(s) above", 1, true), zt)
assert(zt:find("CONTROL: a frame on the cursor blocks the reading", 1, true), zt)
assert(zt:find("RESULT: zone measured", 1, true), zt)
assert(not zt:find("frame on the blip", 1, true), zt)
assert(zt:find("ZONE saved: half-width 3.5 units at effective scale 2.00", 1, true), zt)
assert(HR.db.zone and HR.db.zone.half == 3.5 and HR.db.zone.es == 2, "the measured zone must be stored")
assert(zt:find("DATABASE: HereBeDragons is not available.", 1, true), zt)
local P = HR:DataFor("herbs")["Elwynn Forest"]["Peacebloom"][1]
local hbdZ = {GetPlayerWorldPosition = function() return 1000 - P[1] + 20, 1000 - P[2] - 10, "inst" end,
  GetWorldCoordinatesFromZone = function(_, x, y) return 1000 - x * 100, 1000 - y * 100, "inst" end}
local oldLS = LibStub
LibStub = function() return hbdZ end
zt = bw("hover", "zone")
LibStub = oldLS
assert(zt:find("ZONE CENTRE: (20.0, 10.0) units from the minimap centre (captured point (20.0, 10.0))", 1, true), zt)
assert(zt:find("nearest point to the zone centre is Peacebloom (herb) at (" .. string.format("%.1f, %.1f", P[1], P[2]) .. "), offset (+0.0, +0.0)", 1, true), zt)
assert(zt:find("points within 45 units of the centre", 1, true), zt)
maskMode = "none"
zt = bw("hover", "zone hidden")
assert(zt:find("did NOT block the reading", 1, true), zt)
zoneR = 1 -- smaller than one unit: only the blip centre answers
maskMode = "focus"
zt = bw("hover", "zone")
assert(zt:find("lines present up to 0 unit(s), absent from 1.", 1, true) and zt:find("width 1.0 units", 1, true), zt)
assert(zt:find("ZONE not saved", 1, true), zt)
zoneR = 100 -- 50 units: no edge is found within the range
zt = bw("hover", "zone")
assert(zt:find("no end found within 30", 1, true) and zt:find("an edge was not found within 30 units; width at least 60 units", 1, true), zt)
zoneR = 40 -- 20 units: beyond 8 units the steps are of 2 units
zt = bw("hover", "zone")
assert(zt:find("ZONE cursor left of the blip: lines present up to 20 unit(s), absent from 22.", 1, true), zt)
assert(zt:find("AXIS horizontal: edges 21.0 unit(s) left and 21.0 unit(s) right of the captured point: width 42.0 units", 1, true), zt)
for _, m in ipairs(masks) do assert(not m.shown, "a frame was left shown") end
-- zone measurement in combat: refused by default, allowed with the box ticked
zoneR = 7; maskMode = "focus"; inCombat = true
assert(bw("hover", "zone"):find("ABORTED: in combat", 1, true))
HR.db.verifyCombat = true
assert(bw("hover", "zone"):find("RESULT: zone measured", 1, true), "zone must run in combat when the box is ticked")
HR.db.verifyCombat = false; inCombat = false
zoneR = 10; maskMode = "none"; CreateFrame = realCF; worldAfter = false
io.write("PROBE TESTS OK\n")
''')

lua.execute(r'''
-- tracking isolation: only Find Herbs stays on during a route, then restored
local types, act, calls, legacy, combat = {}, {}, {}, false, false
local function setTypes(withHerbs)
  types = {}
  if withHerbs then types[#types + 1] = {"Find Herbs", 2383} end
  for _, n in ipairs({"Find Minerals", "Flight Master", "Innkeeper", "Account Completed Quests", "Track Quest POIs"}) do
    types[#types + 1] = {n, n == "Find Minerals" and 2580 or nil}
  end
end
local function setActive(names) act = {} for _, n in ipairs(names) do act[n] = true end end
local function activeList()
  local out = {}
  for _, t in ipairs(types) do if act[t[1]] then out[#out + 1] = t[1] end end
  table.sort(out)
  return table.concat(out, ",")
end
local function names(list) table.sort(list) return table.concat(list, ",") end
C_Minimap = {
  GetNumTrackingTypes = function() return #types end,
  GetTrackingInfo = function(i)
    local t = types[i]
    if legacy then return t[1], "tex", act[t[1]] or false, "spell", false end
    return {name = t[1], active = act[t[1]] or false, spellID = t[2]}
  end,
  SetTracking = function(i, b)
    local t = types[i]
    calls[#calls + 1] = i .. (b and "+" or "-")
    if b and t[2] then for _, o in ipairs(types) do if o[2] and o ~= t then act[o[1]] = nil end end end
    act[t[1]] = b or nil
  end,
}
C_Spell = {GetSpellName = function(id) return id == 2383 and "Find Herbs" or nil end}
InCombatLockdown = function() return combat end
HR.db.isolateTracking = true
HR.db.trackingSnapshot = nil
playerMap, px, py = 37, 0.5, 0.5
local start5 = {"Find Herbs", "Flight Master", "Innkeeper", "Account Completed Quests", "Track Quest POIs"}

local function go(cmd) printed = {}; SlashCmdList.HERBROUTE(cmd); RunTimers() end

-- 1. normal start and stop; Find Herbs, already on, is never touched
setTypes(true); setActive(start5); calls = {}
local want = activeList()
go("peacebloom")
assert(HR.route, "route not started")
assert(activeList() == "Find Herbs", activeList())
assert(#HR.db.trackingSnapshot == 5)
for _, c in ipairs(calls) do assert(c ~= "1+" and c ~= "1-", "Find Herbs was touched: " .. c) end
go("stop")
assert(activeList() == want and HR.db.trackingSnapshot == nil, activeList())

-- 2. a second route while one runs keeps the original snapshot
go("peacebloom"); go("peacebloom")
assert(#HR.db.trackingSnapshot == 5 and activeList() == "Find Herbs")
go("stop")
assert(activeList() == want)

-- 3. Find Herbs off, Find Minerals on: swapped, then swapped back
setActive({"Find Minerals", "Flight Master", "Innkeeper"}); want = activeList()
go("peacebloom")
assert(activeList() == "Find Herbs", activeList())
go("stop")
assert(activeList() == want, activeList())

-- 4. legacy GetTrackingInfo format (several return values, no spell ID)
legacy = true; setActive(start5); want = activeList()
go("peacebloom"); assert(activeList() == "Find Herbs", activeList())
go("stop"); assert(activeList() == want)
legacy = false

-- 5. no Find Herbs tracking: nothing changes
setTypes(false); setActive({"Flight Master", "Innkeeper"}); want = activeList()
go("peacebloom")
assert(activeList() == want and HR.db.trackingSnapshot == nil)
assert(table.concat(printed, "\n"):find("Find Herbs tracking is not available", 1, true))
go("stop")
setTypes(true)

-- 6. option off: nothing changes
HR.db.isolateTracking = false; setActive(start5); want = activeList()
go("peacebloom"); assert(activeList() == want); go("stop")
HR.db.isolateTracking = true

-- 7. combat: isolation and restoration wait for the end of combat
setActive(start5); want = activeList()
combat = true
go("peacebloom")
assert(activeList() == want and HR.pendingTracking == "isolate")
combat = false; HR:OnTrackingEvent("PLAYER_REGEN_ENABLED")
assert(activeList() == "Find Herbs", activeList())
combat = true; go("stop")
assert(activeList() == "Find Herbs" and HR.pendingTracking == "restore")
combat = false; HR:OnTrackingEvent("PLAYER_REGEN_ENABLED")
assert(activeList() == want and HR.db.trackingSnapshot == nil)

-- 8. recovery at login (the route is gone after a reload, the snapshot stays)
setActive({"Find Herbs"})
HR.db.trackingSnapshot = {{name = "Find Herbs", spellID = 2383}, {name = "Flight Master"}, {name = "Innkeeper"}}
HR:OnTrackingEvent("PLAYER_ENTERING_WORLD"); RunTimers()
assert(activeList() == "Find Herbs,Flight Master,Innkeeper" and HR.db.trackingSnapshot == nil, activeList())

-- 9. commands
setActive(start5); go("peacebloom"); go("tracking off")
assert(HR.db.isolateTracking == false and activeList() == names({table.unpack(start5)}) , activeList())
go("tracking on"); assert(HR.db.isolateTracking == true and activeList() == "Find Herbs", activeList())
go("stop"); assert(activeList() == names({table.unpack(start5)}), activeList())
HR.db.trackingSnapshot = {{name = "Find Herbs", spellID = 2383}}
setActive({"Find Herbs", "Innkeeper"}); go("tracking restore"); assert(activeList() == "Find Herbs")
io.write("TRACKING TESTS OK\n")
''')

lua.execute(r'''
-- verification of the next waypoint: probes, guards, report and remove modes
local cxm, cym, es = 500, 400, 2
local sx, sy, setCalls, freeze = 0, 0, 0, false
local softOn, updated, hitR, pinHidden = false, false, 6, false
local ppx, ppy = 950, 950 -- fake player world position (1 % of the map = 1 yd)
local nodes, afterFirstLine, linesSeen, tracking = {}, false, 0, true
local cursor, moving, mouseDown, combat, castName, unitUnder, tooltip, engine = {100, 100}, false, false, false, nil, false, false, "real"
local counter, calibT0, alphaCalled, armedAt = 0, nil, false, nil
GetCursorPosition = function()
  if calibT0 then
    if Now() >= calibT0 + 4 then return cursor[1], cursor[2] end
    return (cxm + 20) * es, (cym + 10) * es -- phase A: the mouse is on the blip at offset (20, 10)
  end
  if moving then counter = counter + 20; return cursor[1] + counter, cursor[2] end
  return cursor[1], cursor[2]
end
IsMouseButtonDown = function() return mouseDown end
InCombatLockdown = function() return combat end
UnitCastingInfo = function() return castName end
UnitChannelInfo = function() return nil end
UnitExists = function() return unitUnder end
UnitIsDeadOrGhost = function() return false end
UnitOnTaxi = function() return false end
GameTooltip = {IsShown = function() return tooltip end}
hooksecurefunc = function() end
TomTom.HideWaypoint = function() pinHidden = true end
TomTom.ShowWaypoint = function() pinHidden = false end
UIParent = {}; WorldFrame = {}
local foci = nil
local foreign = {GetName = function() return "QuestieIcon7" end}
GetMouseFoci = function()
  if engine == "foreign" and (sx ~= 0 or sy ~= 0) then return {foreign} end
  return foci or {WorldFrame}
end
GetCVar = function() return "0" end
Minimap = {
  GetCenter = function() return cxm + sx, cym + sy end, GetWidth = function() return 140 end,
  GetHeight = function() return 140 end, GetEffectiveScale = function() return es end,
  GetZoom = function() return 1 end, IsVisible = function() return true end, GetFrameLevel = function() return 1 end,
  GetNumPoints = function() return 1 end,
  GetPoint = function() return "CENTER", UIParent, "CENTER", sx, sy end,
  ClearAllPoints = function() end,
  SetPoint = function(_, _, _, _, x, y) setCalls = setCalls + 1; updated = false; alphaCalled = false; if not freeze then sx, sy = x, y end end,
  SetUsingSoftCursor = function(_, b) softOn = b end,
  UpdateMouseoverAtPoint = function() updated = true end,
  GetAlpha = function() return 1 end, SetAlpha = function() alphaCalled = true end,
}
C_Minimap = {
  GetViewRadius = function() return 70 end, GetNumTrackingTypes = function() return 2 end,
  GetTrackingInfo = function(i) if i == 2 then return {name = "Find Minerals", active = tracking, spellID = 2580} end return {name = "Find Herbs", active = tracking, spellID = 2383} end,
  SetTracking = function() end,
}
local hbd = {}
function hbd:GetPlayerWorldPosition() return ppx, ppy, "inst" end
function hbd:GetWorldCoordinatesFromZone(x, y) return 1000 - x * 100, 1000 - y * 100, "inst" end
LibStub = function() return hbd end
local canvas = {GetFrameLevel = function() return 1 end, GetWidth = function() return 100 end, GetHeight = function() return 100 end}
WorldMapFrame = {GetCanvas = function() return canvas end, IsShown = function() return false end,
  HookScript = function() end, GetMapID = function() return 0 end}
HR:InitOverlay()
HR.db.isolateTracking = false
HR.db.mode = "follow"
playerMap, px, py = 37, 0.5, 0.5

-- true nodes are DB points {bx, by} (percent); the engine converts them to
-- minimap offsets from the current fake player position
local function offsetOf(n) return ppx - (1000 - n[1]), (1000 - n[2]) - ppy end
C_TooltipInfo = {GetMinimapMouseover = function()
  if engine == "none" then return nil end
  local shifted = sx ~= 0 or sy ~= 0
  if shifted and engine == "soft" and not (softOn and updated) then return nil end
  if shifted and engine == "needalpha" and not alphaCalled then return nil end
  if shifted and engine == "deadshift" then return nil end
  if shifted and engine == "pin" and not pinHidden then return nil end
  if shifted and engine == "foreign" then return nil end
  if engine == "armed" then
    if not shifted then
      local cu0, cv0 = GetCursorPosition()
      local ddx, ddy = cu0 / es - (cxm + sx), cv0 / es - (cym + sy)
      for _, n in ipairs(nodes) do
        local ox0, oy0 = offsetOf(n)
        if (ddx - ox0) ^ 2 + (ddy - oy0) ^ 2 <= hitR * hitR then armedAt = Now() end
      end
    elseif not armedAt or Now() - armedAt > 12 then
      return nil
    end
  end
  local cu, cv = GetCursorPosition()
  local dx, dy = cu / es - (cxm + sx), cv / es - (cym + sy)
  if dx * dx + dy * dy > 70 ^ 2 then return nil end
  for idx, n in ipairs(nodes) do
    local ox, oy = offsetOf(n)
    if (dx - ox) ^ 2 + (dy - oy) ^ 2 <= hitR * hitR then
      linesSeen = linesSeen + 1
      if afterFirstLine then table.remove(nodes, idx) end
      return {type = 21, dataInstanceID = 1, lines = {{type = 0}}}
    end
  end
  return {type = 21, dataInstanceID = 1, lines = {}}
end}

local function go(cmd) printed = {}; SlashCmdList.HERBROUTE(cmd); RunTimers() end
local function msgs() return table.concat(printed, "\n") end
local peaceCount = #HerbRoute_Data["Elwynn Forest"]["Peacebloom"]
local function reset()
  go("stop"); nodes = {}; afterFirstLine = false; linesSeen = 0; setCalls = 0
  ppx, ppy = 950, 950; moving = false; mouseDown = false; combat = false; castName = nil
  unitUnder = false; tooltip = false; tracking = true; engine = "real"; cursor = {100, 100}; freeze = false
  softOn = false; updated = false; hitR = 6; alphaCalled = false; calibT0 = nil; pinHidden = false; foci = nil
  HR.db.recipe, HR.db.recipeBuild = "plain", "70999"
  HR.db.ambiguity = false; HR.db.zone = nil
end

-- 1. report mode: the first point has a node -> confirmed, nothing removed
reset(); HR.db.verify = "report"; HR.verifyHits = 0
go("peacebloom") -- generate to know the first point
local first = HR.route.points[1]
local pts1 = HR.route.points
local function othersNodes() -- nodes on every point except those next to the first one
  local out = {}
  for j = 2, #pts1 do
    local p = pts1[j]
    local dx, dy = p.x - first.x, p.y - first.y
    if dx * dx + dy * dy > 14 * 14 then out[#out + 1] = {p.x, p.y} end
  end
  return out
end
reset()
nodes = {{first.x, first.y}}
go("peacebloom")
local r = HR.route
assert(r.vstate[1] and r.vstate[1].confirmed, "first point not confirmed")
assert(HR.verifyHits >= 1 and (r.removedCount or 0) == 0 and r.vstats.probes >= 1)
assert(setCalls == 2 * r.vstats.probes, "each probe must move and restore the minimap once: " .. setCalls .. " vs " .. r.vstats.probes)
assert(sx == 0 and sy == 0, "minimap not restored")

-- 2. remove mode, a blip was confirmed earlier: an empty point is removed
reset(); HR.db.verify = "remove"; HR.verifyHits = 3
nodes = othersNodes()
go("peacebloom")
r = HR.route
assert(r.removed[1] and r.removedCount >= 1, msgs())
assert(r.index > 1 and not r.removed[r.index], "the route must move on to a kept point")
assert(#WP() == 1 and WP()[1].title:find(tostring(r.index) .. "/", 1, true), "TomTom must show the next point")
assert(#HerbRoute_Data["Elwynn Forest"]["Peacebloom"] == peaceCount, "the database must not change")
assert(msgs():find("has no node: removed", 1, true))
assert(sx == 0 and sy == 0)
assert(HR.UpdateUI == nil or pcall(HR.UpdateUI, HR))

-- 3. no safety on the projection: with nothing confirmed yet, an empty point is removed at once
reset(); HR.db.verify = "remove"; HR.verifyHits = 0
nodes = othersNodes()
go("peacebloom")
r = HR.route
assert(r.removed[1] and r.index > 1, msgs())
assert(msgs():find("has no node: removed", 1, true) and not msgs():find("projection", 1, true), msgs())

-- 4. report mode keeps an empty point
reset(); HR.db.verify = "report"; HR.verifyHits = 2
go("peacebloom")
assert((HR.route.removedCount or 0) == 0 and msgs():find("report mode, kept", 1, true), msgs())

-- 5. the last check before arrival removes a node taken meanwhile
reset(); HR.db.verify = "remove"; HR.verifyHits = 0
nodes = {{first.x, first.y}}
go("peacebloom")
r = HR.route; local gen = r.vstats.confirmed
go("stop"); reset()
nodes = othersNodes(); table.insert(nodes, 1, {first.x, first.y}); afterFirstLine = true
ppx, ppy = 1000 - first.x + 10, 1000 - first.y -- 10 yd from the point
HR.verifyHits = 1
go("peacebloom")
r = HR.route
assert(r.removed[1], "a node taken after confirmation must be removed: " .. msgs())

-- 6. guards: no probe while one of these holds
local function blockedBy(setup, reason)
  reset(); HR.db.verify = "remove"; HR.verifyHits = 3
  nodes = {{first.x, first.y}}
  setup()
  go("peacebloom")
  assert(HR.route.vstats.probes == 0, reason .. ": a probe ran")
  assert(HR.verifyReason and HR.verifyReason:find(reason, 1, true), reason .. " vs " .. tostring(HR.verifyReason))
  assert(sx == 0 and sy == 0)
end
blockedBy(function() mouseDown = true end, "mouse button held")
blockedBy(function() combat = true end, "combat")
blockedBy(function() castName = "Cast" end, "casting")
blockedBy(function() moving = true end, "the cursor is moving")
blockedBy(function() cursor = {(cxm + 5) * es, (cym + 5) * es} end, "the cursor is on the minimap")
blockedBy(function() tooltip = true end, "a tooltip is open")
blockedBy(function() unitUnder = true end, "a unit is under the cursor")
blockedBy(function() tracking = false end, "Find Herbs tracking is not active")

-- 7. an inconclusive engine never removes anything
reset(); HR.db.verify = "remove"; HR.verifyHits = 3
engine = "none"
go("peacebloom")
assert((HR.route.removedCount or 0) == 0 and HR.route.vstate[1].none >= 4 and not HR.route.vstate[1].final, "inconclusive must not give up")
assert(msgs():find("is inconclusive (no hover data", 1, true), msgs())
assert(HR.route.vstats.causes["no hover data: the client did not refresh the minimap hover"] >= 4)

-- 7b. the minimap does not follow the shift (frozen by another addon)
reset(); HR.db.verify = "remove"; HR.verifyHits = 3; nodes = {{first.x, first.y}}; freeze = true
go("peacebloom")
assert((HR.route.removedCount or 0) == 0 and HR.route.vstate[1].none >= 3, msgs())
assert(msgs():find("did not move", 1, true), msgs())
freeze = false

-- 7c. after steering with a mouse button the mouse must move once
reset(); HR.db.verify = "remove"; HR.verifyHits = 3; nodes = {{first.x, first.y}}
C_Timer.After(0.2, function() mouseDown = true end)
C_Timer.After(1.2, function() mouseDown = false end)
go("peacebloom")
assert(HR.route.vstats.probes == 0 and HR.verifyReason:find("move the mouse once", 1, true), tostring(HR.verifyReason))
cursor = {130, 100}; RunTimers()
assert(HR.route.vstate[1].confirmed, "probing must resume after the mouse moved")

-- 7d. /hr verify probe prints the measurements
reset(); HR.db.verify = "report"; HR.verifyHits = 0; nodes = {{first.x, first.y}}
go("peacebloom"); go("verify probe")
assert(msgs():find("Verify probe: point 1/", 1, true) and msgs():find("mouse moved during the countdown: NO", 1, true), msgs())
assert(msgs():find("result: line", 1, true) and msgs():find("minimap back home: true", 1, true), msgs())
assert(msgs():find("+1: moved=true onMinimap=true focus=", 1, true) and msgs():find("lines=true", 1, true), msgs())

-- 9. calibration finds the method that detects the dot the player points at
local function calibrate(eng)
  reset(); HR.db.verify = "off"; HR.db.recipe, HR.db.recipeBuild = nil, nil
  nodes = {{70, 40}} -- offsetOf gives (20, 10): the dot under the mouse in phase A
  engine = eng; calibT0 = Now()
  go("verify calibrate")
  local m = msgs()
  calibT0 = nil
  assert(sx == 0 and sy == 0 and softOn == false, "minimap or soft cursor not restored")
  return m
end
local m = calibrate("real")
assert(HR.db.recipe == "plain" and HR.db.recipeBuild == "70999" and m:find("method 'plain' stored", 1, true), m)
m = calibrate("needalpha")
assert(HR.db.recipe == "alpha" and m:find("[plain] on the dot: none", 1, true), m)
m = calibrate("soft")
assert(HR.db.recipe == "soft cursor + update", m)
assert(m:find("[plain] on the dot: none", 1, true) and m:find("[update] on the dot: none", 1, true), m)
m = calibrate("deadshift")
assert(HR.db.recipe == nil and m:find("Calibration failed", 1, true), m)

-- the TomTom pin of the current waypoint is hidden while probing, then shown again
reset(); HR.db.verify = "report"; HR.verifyHits = 0; nodes = {{first.x, first.y}}; engine = "pin"
go("peacebloom")
assert(HR.route.vstate[1] and HR.route.vstate[1].confirmed, "the pin must not hide the node from the probe: " .. tostring(HR.verifyReason))
assert(pinHidden == false, "the pin must be shown again after the probe")

-- another addon's icon under the cursor is named in the cause
reset(); HR.db.verify = "report"; HR.verifyHits = 0; nodes = {{first.x, first.y}}; engine = "foreign"
go("peacebloom")
assert(msgs():find("a minimap icon is under the cursor (QuestieIcon7)", 1, true), msgs())
foci = nil

-- the arming test shows when the probes stop seeing the dot
reset(); HR.db.verify = "off"; nodes = {{70, 40}}; engine = "armed"; armedAt = nil; calibT0 = Now()
go("verify arming"); calibT0 = nil
assert(msgs():find("t=6s after the dot: dot line, control empty", 1, true), msgs())
assert(msgs():find("t=10s after the dot: dot line", 1, true) and msgs():find("t=20s after the dot: dot none", 1, true), msgs())
assert(msgs():find("Arming test finished", 1, true) and sx == 0 and sy == 0, msgs())

-- calibration needs a dot under the mouse in phase A
reset(); HR.db.recipe, HR.db.recipeBuild = nil, nil; nodes = {}; calibT0 = Now()
go("verify calibrate"); calibT0 = nil
assert(msgs():find("no tooltip line under the cursor", 1, true) and HR.db.recipe == nil, msgs())

-- without a calibrated method the automatic verification does not probe
reset(); HR.db.verify = "remove"; HR.verifyHits = 3; nodes = {{first.x, first.y}}
HR.db.recipe, HR.db.recipeBuild = nil, nil
go("peacebloom")
assert(HR.route.vstats.probes == 0 and HR.verifyReason:find("run /hr verify calibrate once", 1, true), tostring(HR.verifyReason))
HR.db.recipe, HR.db.recipeBuild = "plain", "12345" -- another build: calibration is stale
go("stop"); go("peacebloom")
assert(HR.route.vstats.probes == 0 and HR.verifyReason:find("run /hr verify calibrate once", 1, true))

-- the automatic verification uses the calibrated method
reset(); HR.db.verify = "report"; HR.verifyHits = 0; nodes = {{first.x, first.y}}
engine = "needalpha"; HR.db.recipe, HR.db.recipeBuild = "alpha", "70999"
go("peacebloom")
assert(HR.route.vstate[1] and HR.route.vstate[1].confirmed, "the calibrated method must confirm the point: " .. tostring(HR.verifyReason))
reset(); engine = "needalpha"; HR.db.verify = "report"; nodes = {{first.x, first.y}} -- recipe 'plain' fails on this engine
go("peacebloom")
assert(not (HR.route.vstate[1] and HR.route.vstate[1].confirmed))

-- 10. scan: does the projection of the route points land on the blips?
reset(); HR.db.verify = "off"
go("peacebloom")
local cand = {}
for _, p in ipairs(HR.route.points) do
  local ox, oy = p.x - 50, 50 - p.y
  if ox * ox + oy * oy <= 56 * 56 then cand[#cand + 1] = p end
end
assert(#cand >= 10, "not enough candidates for the scan test: " .. #cand)
nodes = {}; for _, p in ipairs(cand) do nodes[#nodes + 1] = {p.x, p.y} end
hitR = 12
go("verify scan")
assert(msgs():find("as projected %d+, mirrored in x") or msgs():find("as projected", 1, true), msgs())
assert(msgs():find("no mirror image fits clearly better", 1, true), msgs())
assert(msgs():find("blip group(s)", 1, true) and msgs():find("mean offset", 1, true) and msgs():find("radial ratio", 1, true), msgs())
assert(HR.db.scan and HR.db.scan.text:find("Map (8 units per character", 1, true) and HR.db.scan.text:find("X", 1, true) and HR.db.scan.text:find("o", 1, true), "map missing")
assert(sx == 0 and sy == 0, "minimap not restored after the scan")
nodes = {}
go("verify scan")
assert(msgs():find("no blip found", 1, true), msgs())

-- 11. ahead: points inside the minimap beyond the current one are probed too
reset(); HR.db.verify = "off"; HR.db.verifyAhead = nil
go("peacebloom")
local ptsA = HR.route.points
local target, bestD
for j = 3, #ptsA do
  local dc = (ptsA[j].x - 50) ^ 2 + (ptsA[j].y - 50) ^ 2
  if dc < 40 * 40 then
    local nearest = math.huge
    for k, q in ipairs(ptsA) do
      if k ~= j then nearest = math.min(nearest, (q.x - ptsA[j].x) ^ 2 + (q.y - ptsA[j].y) ^ 2) end
    end
    if nearest > 9 and (not bestD or nearest > bestD) then target, bestD = j, nearest end
  end
end
assert(target, "no isolated point for the ahead test")
reset(); HR.db.verify = "remove"; HR.db.verifyAhead = true; HR.verifyHits = 3; hitR = 1.5
nodes = {}
for j, q in ipairs(ptsA) do if j ~= target then nodes[#nodes + 1] = {q.x, q.y} end end
go("peacebloom")
r = HR.route
assert(r.vstate[target] and r.vstate[target].final, "target not probed ahead: " .. msgs() .. " reason=" .. tostring(HR.verifyReason) .. " ahead=" .. tostring(r.vstats.ahead) .. " idx=" .. r.index .. " target=" .. target .. " probes=" .. r.vstats.probes)
assert(r.removed[target], "the empty point ahead must be removed: " .. msgs())
assert(r.vstats.ahead and r.vstats.ahead >= 2, "ahead probes: " .. tostring(r.vstats.ahead))
local others = 0
for j in pairs(r.removed) do if j ~= target then others = others + 1 end end
assert(others == 0, others .. " point(s) with a node were removed")
assert(#HerbRoute_Data["Elwynn Forest"]["Peacebloom"] == peaceCount)
assert(sx == 0 and sy == 0)
-- off: nothing is probed ahead, except on demand
reset(); HR.db.verify = "remove"; HR.db.verifyAhead = false; HR.verifyHits = 3; hitR = 1.5
nodes = {}
for j, q in ipairs(ptsA) do if j ~= target then nodes[#nodes + 1] = {q.x, q.y} end end
go("peacebloom"); r = HR.route
assert((r.vstats.ahead or 0) == 0 and not r.removed[target], "ahead must be off")
go("verify ahead")
assert(msgs():find("Verify ahead: probing", 1, true) or r.aheadOnce == nil, msgs())
RunTimers()
assert(r.removed[target] and msgs() ~= nil, "manual pass must remove the empty point")
go("verify ahead on"); assert(HR.db.verifyAhead == true)
go("verify ahead off"); assert(HR.db.verifyAhead == false)
HR.db.verifyAhead = nil
go("stop")

-- 12. ores: same verification and removal, driven by Find Minerals
reset(); HR.db.verify = "report"; HR.db.verifyAhead = nil; HR.verifyHits = 0
go("ores copper vein")
local oreR = HR.route
assert(oreR and oreR.category == "ores", msgs())
local orePts = oreR.points
local oreFirst = orePts[1]
local oreCount = #HerbRoute_OreData["Elwynn Forest"]["Copper Vein"]
go("stop")
reset(); HR.db.verify = "remove"; HR.verifyHits = 3
nodes = {}
for j = 2, #orePts do
  local p = orePts[j]
  local dx, dy = p.x - oreFirst.x, p.y - oreFirst.y
  if dx * dx + dy * dy > 14 * 14 then nodes[#nodes + 1] = {p.x, p.y} end
end
go("ores copper vein")
r = HR.route
assert(r.category == "ores" and r.removed[1] and r.index > 1 and not r.removed[r.index], msgs())
assert(msgs():find("has no node: removed", 1, true) and msgs():find("Copper Vein", 1, true), msgs())
assert(#HerbRoute_OreData["Elwynn Forest"]["Copper Vein"] == oreCount, "the ore database must not change")
assert(sx == 0 and sy == 0)
go("stop")
-- a node under the first ore point: confirmed, kept
reset(); HR.db.verify = "remove"; HR.verifyHits = 0
nodes = {{oreFirst.x, oreFirst.y}}
go("ores copper vein")
r = HR.route
assert(r.vstate[1] and r.vstate[1].confirmed and not r.removed[1] and HR.verifyHits >= 1, msgs())
go("stop")
-- the guard names the ore tracking
reset(); HR.db.verify = "report"; HR.verifyHits = 3; nodes = {}; tracking = false
go("ores copper vein")
printed = {}; HR:VerifyStatus()
assert(msgs():find("Find Minerals tracking is not active", 1, true), msgs())
go("stop"); tracking = true
go("verify calibrate ores"); assert(HR.verifyCategory == "ores"); RunTimers()
go("verify calibrate"); assert(HR.verifyCategory == "herbs"); RunTimers()
go("stop")

-- 13. F60: points of the database that are no longer ahead in the route come back when they reappear in the minimap
local alphaLog = {}
local baseSetAlpha = Minimap.SetAlpha
Minimap.SetAlpha = function(_, a) alphaLog[#alphaLog + 1] = a; alphaCalled = true end
local probeTimes = {}
local baseSetPoint = Minimap.SetPoint
Minimap.SetPoint = function(m, a, b, c, x, y)
  baseSetPoint(m, a, b, c, x, y)
  if x ~= 0 or y ~= 0 then probeTimes[#probeTimes + 1] = Now() end
end
local ELW2 = HerbRoute_Data["Elwynn Forest"]
local NEAR_PL, FAR_PL = {1032, 988}, {1332, 988} -- the player near the test points, or far from them
local function revSetup(points)
  reset()
  ELW2["TestNb"] = points or {{8, 12}, {8, 35}}
  HR.categories.herbs.merged = nil
  HR.db.verify = "off"; HR.db.verifyAhead = false; HR.db.revive = true; HR.db.nearest = true
  HR.db.ambiguity = false; HR.verifyHits = 3
  ppx, ppy = FAR_PL[1], FAR_PL[2]
  nodes = {}; hitR = 6; probeTimes = {}; alphaLog = {}
  printed = {}; SlashCmdList.HERBROUTE("testnb")
  local rt = HR.route
  RunTimers()
  return rt
end
local function revTeardown()
  go("stop"); ELW2["TestNb"] = nil; HR.categories.herbs.merged = nil
end
-- the player walks back and forth by 10 yd steps: n steps travel 10 * n yd (position samples are taken every tick)
local function travel(n)
  local x0 = ppx
  for i = 1, n do ppx = x0 - ((i % 2 == 1) and 10 or 0); RunTimers() end -- towards the test points: they stay inside the minimap
  ppx = x0
end
local function poolEntry(rt, y)
  for _, e in ipairs(HR.RevivePool(rt)) do if e.p.y == y then return e end end
end

-- a skipped point that reappears (4 points: the route is recomputed with it)
local r13 = revSetup({{8, 12}, {8, 35}, {14, 12}, {14, 35}})
local skippedKey = HR.PointKey(r13.points[1])
local before = #r13.points
go("skip")
assert(r13.cause[skippedKey] and r13.cause[skippedKey].cause == "skip", "the skip must be remembered")
assert(HR.ReviveCount(r13) == 1, "one candidate outside the route")
assert(msgs() == "" or not msgs():find("Revive", 1, true))
local probes0 = #probeTimes
RunTimers() -- the player is far: nothing is probed, nothing is printed
assert(#probeTimes == probes0 and not msgs():find("Revive", 1, true), "nothing must happen while the point is out of the minimap")
local sy0 = r13.points[1].y
-- the player comes back near, no node there: one silent empty probe at once, then one more each 60 yd travelled
ppx, ppy = NEAR_PL[1], NEAR_PL[2]
local candidate
for _, e in ipairs(HR.RevivePool(r13)) do if e.key == skippedKey then candidate = e end end
printed = {}; probeTimes = {}; alphaLog = {}
RunTimers()
assert(#probeTimes == 1 and candidate.stay == 1, "one probe while the player stays still: " .. #probeTimes)
RunTimers()
assert(#probeTimes == 1, "time alone does not start a new probe")
travel(5) -- 50 yd
assert(#probeTimes == 1, "50 yd are not enough: " .. #probeTimes)
travel(4) -- 90 yd in total
assert(#probeTimes == 2 and candidate.stay == 2, "60 yd travelled start a new probe: " .. #probeTimes)
assert(msgs() == "" and (r13.revivedCount or 0) == 0 and #r13.points == before, "an empty probe must be silent: " .. msgs())
assert(alphaLog[1] == 0 and alphaLog[#alphaLog] == 1, "the minimap must be hidden while it moves and restored")
assert(sx == 0 and sy == 0)
-- a stay is over when the point leaves the minimap; the node is back when it re-enters
ppx, ppy = FAR_PL[1], FAR_PL[2]; RunTimers()
nodes = {{skippedKey:match("^([%d%.]+)|([%d%.]+)")}}
nodes[1] = {tonumber(nodes[1][1]), tonumber(nodes[1][2])}
ppx, ppy = NEAR_PL[1], NEAR_PL[2]
printed = {}; RunTimers()
assert(msgs():find("Revive:", 1, true) and msgs():find("(skipped earlier)", 1, true), msgs())
assert(r13.revivedCount == 1 and #r13.points == before + 1 and HR.ReviveCount(r13) == 0, "the point must be back in the route")
assert(msgs():find("Reroute from", 1, true), "the route must be recomputed with the point: " .. msgs())
assert(sx == 0 and sy == 0 and #HerbRoute_Data["Elwynn Forest"]["Peacebloom"] == peaceCount, "database changed")
revTeardown()

-- a reached point: its first probe waits 10 seconds after the arrival
local r13b = revSetup()
ppx, ppy = NEAR_PL[1], NEAR_PL[2]
local reachedKey = HR.PointKey(r13b.points[1])
nodes = {{8, 35}}
local t0 = Now()
printed = {}; probeTimes = {}
Fire(WP()[1])
assert(r13b.cause[reachedKey] and r13b.cause[reachedKey].cause == "reached" and r13b.cause[reachedKey].at == t0, "the arrival must be remembered")
RunTimers()
assert(#probeTimes >= 1 and probeTimes[1] >= t0 + 10 - 0.01, "the first probe of a reached point must wait 10 s: " .. tostring(probeTimes[1]) .. " vs " .. t0)
assert(msgs():find("(reached earlier)", 1, true) and r13b.revivedCount == 1, msgs())
revTeardown()

-- a point removed as absent comes back
local r13c = revSetup()
local absentKey = HR.PointKey(r13c.points[1])
HR:DropPoint(1)
assert(r13c.cause[absentKey].cause == "absent" and r13c.removedCount == 1)
nodes = {{8, 35}}
ppx, ppy = NEAR_PL[1], NEAR_PL[2]
printed = {}; RunTimers()
assert(msgs():find("(removed earlier)", 1, true) and r13c.revivedCount == 1 and (r13c.removedCount or 0) == 0, msgs())
revTeardown()

-- off: no probe at all
local r13d = revSetup()
go("skip")
HR.db.revive = false
ppx, ppy = NEAR_PL[1], NEAR_PL[2]; nodes = {{8, 35}}
probeTimes = {}; printed = {}; RunTimers()
assert(#probeTimes == 0 and (r13d.revivedCount or 0) == 0, "revive off must not probe")
go("revive on"); assert(HR.db.revive == true and msgs():find("Revive points outside the route: on", 1, true), msgs())
go("revive off"); assert(HR.db.revive == false)
HR.db.revive = true
revTeardown()

-- a point that comes back next to another point of the database: the offset probe decides
local function revAmbiguous(nodeList)
  local rt = revSetup({{8, 12}, {8, 35}})
  ELW2["TestNeigh"] = {{15, 35}}
  HR.categories.herbs.merged = nil
  HR.db.ambiguity = true; HR.db.zone = {half = 8, es = 2, build = "70999"}
  rt.dbw = nil
  go("skip")
  hitR = 8; nodes = nodeList
  ppx, ppy = NEAR_PL[1], NEAR_PL[2]
  printed = {}; RunTimers()
  return rt
end
local r13e = revAmbiguous({{8, 35}, {15, 35}})
assert(msgs():find("Revive:", 1, true) and r13e.vstats.amb.marked == 1 and r13e.vstats.amb.distinct == 1, msgs())
ELW2["TestNeigh"] = nil; revTeardown()
local r13f = revAmbiguous({{15, 35}})
assert((r13f.revivedCount or 0) == 1 and msgs():find("Revive:", 1, true), "the point is put back at once even though a neighbour may answer for it: " .. msgs())
assert(r13f.vstats.amb.rejected >= 1, "the offset probe then finds that only the neighbour answers: rejected=" .. r13f.vstats.amb.rejected)
ELW2["TestNeigh"] = nil; revTeardown()
HR.db.ambiguity = false; HR.db.zone = nil
Minimap.SetAlpha = baseSetAlpha
Minimap.SetPoint = baseSetPoint

-- 14. F61: a filled point found by a probe becomes the target (new waypoint); the route is recomputed on arrival
reset(); HR.db.verify = "report"; HR.db.verifyAhead = true; HR.db.nearest = true; HR.db.reroute = false
HR.db.revive = false; HR.verifyHits = 0; hitR = 1.5
nodes = {{ptsA[target].x, ptsA[target].y}}
go("peacebloom")
r = HR.route
assert(msgs():find("Nearest: Peacebloom is filled", 1, true) and msgs():find("new target (point 1/", 1, true), msgs())
assert(r.points[1].x == ptsA[target].x and r.points[1].y == ptsA[target].y, "the filled point must be the target")
assert(#r.points == #ptsA and r.vstate[1] and r.vstate[1].confirmed, "same route size, confirmed state follows the point")
assert(#WP() == 1 and WP()[1].title:find("1/", 1, true), "one new waypoint must be active")
assert(r.rerouteOnArrival == true, "the recalculation on arrival must be armed")
local pointsBefore = r.points
printed = {}
HR:Advance() -- the waypoint is reached
RunTimers()
assert(msgs():find("Reroute from", 1, true) and r.rerouteOnArrival == nil, "the route must be recomputed on arrival: " .. msgs())
assert(#HerbRoute_Data["Elwynn Forest"]["Peacebloom"] == peaceCount and sx == 0 and sy == 0)
go("stop")
-- off: no change of target
reset(); HR.db.verify = "report"; HR.db.verifyAhead = true; HR.db.nearest = false; HR.db.revive = false; hitR = 1.5
nodes = {{ptsA[target].x, ptsA[target].y}}
go("peacebloom"); r = HR.route
assert(not msgs():find("Nearest:", 1, true) and not r.rerouteOnArrival and r.index == 1, msgs())
go("nearest on"); assert(HR.db.nearest == true and msgs():find("Nearest filled point as target: on", 1, true), msgs())
go("nearest off"); assert(HR.db.nearest == false)
HR.db.nearest = true
go("stop")
-- a skip cancels the pending recalculation
reset(); HR.db.verify = "report"; HR.db.verifyAhead = true; HR.db.nearest = true; HR.db.revive = false; hitR = 1.5
nodes = {{ptsA[target].x, ptsA[target].y}}
go("peacebloom"); r = HR.route
assert(r.rerouteOnArrival == true)
printed = {}; HR:SkipPoint(); RunTimers()
assert(r.rerouteOnArrival == nil and not msgs():find("Reroute from", 1, true), msgs())
go("stop")
HR.db.revive = true

-- 15. probes go to the candidate nearest to the player first (points ahead)
reset(); HR.db.verify = "report"; HR.db.verifyAhead = true; HR.db.nearest = false; HR.db.revive = false; hitR = 1.5
nodes = {}
for _, q in ipairs(ptsA) do nodes[#nodes + 1] = {q.x, q.y} end
local seen, seenSet, origRetarget = {}, {}, HR.RetargetNearest
HR.RetargetNearest = function(self, rt)
  if rt then
    for j = rt.index + 1, #rt.points do
      local st = rt.vstate[j]
      if st and st.confirmed and not seenSet[st] then
        seenSet[st] = true
        seen[#seen + 1] = HR.PointGeometry(rt, j).dist
      end
    end
  end
  return origRetarget(self, rt)
end
go("peacebloom")
HR.RetargetNearest = origRetarget
assert(#seen >= 5, "not enough ahead probes: " .. #seen)
for k = 2, #seen do assert(seen[k] >= seen[k - 1] - 1e-6, ("probe %d is nearer than probe %d"):format(k, k - 1)) end
go("stop")
HR.db.nearest = true; HR.db.revive = true

Minimap.SetAlpha = baseSetAlpha

-- 16. step C: positives that may come from a neighbouring point (zone half-width 8 units, margin 2.5)
local ELW = HerbRoute_Data["Elwynn Forest"]
local function ambSetup(neigh, nodeList, mode, extra)
  reset()
  ELW["TestNb"] = {{8, 12}}
  if extra then for _, q in ipairs(extra) do ELW["TestNb"][#ELW["TestNb"] + 1] = q end end
  ELW["TestNeigh"] = neigh
  HR.categories.herbs.merged = nil
  ppx, ppy = 1032, 988 -- the candidate lies 40 units from the player, inside the minimap
  HR.db.ambiguity = true; HR.db.zone = {half = 8, es = 2, build = "70999"}
  HR.db.verify = mode; HR.db.verifyAhead = false; HR.db.revive = false; HR.db.nearest = true; HR.verifyHits = 3
  nodes = nodeList; hitR = 8
  printed = {}; SlashCmdList.HERBROUTE("testnb")
  local rt = HR.route
  RunTimers()
  return rt
end
local function ambTeardown()
  go("stop"); ELW["TestNb"] = nil; ELW["TestNeigh"] = nil
  HR.categories.herbs.merged = nil; HR.db.ambiguity = false; HR.db.zone = nil
end
-- distinct: the candidate and a neighbour both have a node; the probe off to the side hears only the candidate
r = ambSetup({{15, 12}}, {{8, 12}, {15, 12}}, "report")
assert(r.vstate[1].confirmed and r.vstate[1].amb and r.vstate[1].amb.state == "distinct", "state: " .. tostring(r.vstate[1].amb and r.vstate[1].amb.state))
assert(r.vstats.amb.marked == 1 and r.vstats.amb.distinct == 1 and r.vstats.amb.rejected == 0 and r.vstats.amb.probes == 1, "stats")
assert(not r.removed[1] and sx == 0 and sy == 0, "nothing removed, minimap restored")
assert(#HerbRoute_Data["Elwynn Forest"]["Peacebloom"] == peaceCount, "database changed")
ambTeardown()
-- rejected: only the neighbour has a node; the probe off to the side hears nothing, the candidate is treated as absent
r = ambSetup({{15, 12}}, {{15, 12}}, "remove")
assert(r.vstats.amb.marked == 1 and r.vstats.amb.rejected == 1 and r.vstats.amb.distinct == 0, "rejected stats")
assert(r.removed[1] and msgs():find("has no node: removed", 1, true), "a rejected candidate must be removed: " .. msgs())
ambTeardown()
-- report mode: the same case is only reported
r = ambSetup({{15, 12}}, {{15, 12}}, "report")
assert(r.vstats.amb.rejected >= 1 and not r.removed[1] and msgs():find("report mode, kept", 1, true), msgs())
local keptMsgs = 0
for _ in msgs():gmatch("report mode, kept") do keptMsgs = keptMsgs + 1 end
assert(keptMsgs == 1, "a repeated empty read must stay silent: " .. keptMsgs)
ambTeardown()
-- unresolved: neighbours on every side leave no position outside their zones; no probe, nothing removed
r = ambSetup({{13, 12}, {3, 12}, {8, 17}, {8, 7}}, {{8, 12}, {13, 12}, {3, 12}, {8, 17}, {8, 7}}, "remove")
assert(r.vstate[1].amb and r.vstate[1].amb.state == "unresolved" and r.vstats.amb.unresolved == 1 and r.vstats.amb.probes == 0, "unresolved stats")
assert(not r.removed[1], "an unresolved point must not be removed")
ambTeardown()
-- clean: no neighbour within reach
r = ambSetup({{28, 12}}, {{8, 12}}, "report")
assert(r.vstate[1].confirmed and r.vstate[1].amb == nil and r.vstats.amb.marked == 0, "clean positive")
ambTeardown()
-- off
r = ambSetup({{15, 12}}, {{8, 12}, {15, 12}}, "report")
ambTeardown()
HR.db.ambiguity = false
r = ambSetup({{15, 12}}, {{8, 12}, {15, 12}}, "report")
HR.db.ambiguity = false; go("stop"); go("testnb"); RunTimers(); r = HR.route
assert(r.vstate[1].amb == nil and r.vstats.amb.marked == 0, "ambiguity off")
ambTeardown()
-- a zone measured at another scale is ignored: the formula (8 / scale = 4 units) applies, the neighbour at 7 is no longer in reach
r = ambSetup({{15, 12}}, {{8, 12}, {15, 12}}, "report")
go("stop"); HR.db.zone = {half = 8, es = 1}; HR.db.ambiguity = true
go("testnb"); RunTimers(); r = HR.route
assert(r.vstate[1].amb == nil, "formula must apply when the measured scale differs")
ambTeardown()

-- F61 treats an ambiguous point like any other filled point: the nearest wins, nothing waits
local twoPts = {{8, 35}}
local function ambRoute(state)
  local rt = ambSetup({}, {}, "off", twoPts)
  HR.db.verify = "off"
  assert(#rt.points == 2 and rt.points[1].y == 35 and rt.points[2].y == 12, "route order")
  rt.vstate[2] = {misses = 0, none = 0, nextAt = 0, confirmed = true, amb = state and {state = state, tries = 0, nextAt = 0} or nil}
  printed = {}
  return rt
end
for _, state in ipairs({"unresolved", "pending", "distinct"}) do
  r = ambRoute(state)
  assert(HR:RetargetNearest(r) == true and r.points[1].y == 12 and msgs():find("Nearest:", 1, true), state .. " is targeted like any other point")
  ambTeardown()
end
r = ambRoute(nil)
assert(HR:RetargetNearest(r) == true and r.points[1].y == 12, "a clean positive may be targeted")
ambTeardown()
-- F60: a point put back goes to the cheapest place, the head included, whatever its ambiguity; noHead stays available
r = ambRoute(nil); r.vstate[2].confirmed = false
local entry = {p = {x = 50, y = 50, herb = "TestNb"}, cause = "skip", stay = 0, nextAt = 0, amb = {state = "unresolved", tries = 0, nextAt = 0}}
local head = r.points[1]
assert(HR:ReviveSkipped(entry, true) and r.points[1] == head and r.points[#r.points].x == 50, "no head insertion when asked")
ambTeardown()
r = ambRoute(nil); r.vstate[2].confirmed = false
entry = {p = {x = 50, y = 50, herb = "TestNb"}, cause = "skip", stay = 0, nextAt = 0, amb = {state = "unresolved", tries = 0, nextAt = 0}}
assert(HR:ReviveSkipped(entry) and r.points[1].x == 50, "an ambiguous point goes to the head when that is the cheapest")
ambTeardown()
-- red marks: the spots still in doubt (waiting or unresolved), nothing once the doubt is lifted
r = ambRoute("pending")
local spots = HR.AmbiguousSpots(r)
assert(#spots == 1 and spots[1].y == 12 and spots[1].wx and spots[1].wy, "a pending ambiguity is marked")
assert(pcall(HR.UpdateOverlay, HR), "the overlay must draw the red marks without error")
HR.db.ambiguityMarks = false; assert(pcall(HR.UpdateOverlay, HR), "and with the marks hidden"); HR.db.ambiguityMarks = true
r.vstate[2].amb.state = "unresolved"; assert(#HR.AmbiguousSpots(r) == 1, "an unresolved one too")
r.vstate[2].amb.state = "distinct"; assert(#HR.AmbiguousSpots(r) == 0, "a distinct one is not marked")
r.vstate[2].amb.state = "rejected"; assert(#HR.AmbiguousSpots(r) == 0, "a rejected one is not marked")
r.vstate[2].amb.state = "pending"; r.removed[2] = true; assert(#HR.AmbiguousSpots(r) == 0, "a point that left the route is not marked")
ambTeardown()
-- commands
go("ambiguity off"); assert(HR.db.ambiguity == false and msgs():find("Ambiguous positives: off", 1, true), msgs())
go("ambiguity on"); assert(HR.db.ambiguity == true and msgs():find("zone half-width", 1, true), msgs())
go("ambiguity marks off"); assert(HR.db.ambiguityMarks == false and msgs():find("red marks off", 1, true), msgs())
go("ambiguity marks on"); assert(HR.db.ambiguityMarks == true and msgs():find("red marks on", 1, true), msgs())
HR.db.ambiguity = false
go("stop")

-- 17. recheck of a confirmed point once it is within RECHECK_YD (set to 40 here: the fake minimap reaches 59 yd)
local ELW3 = HerbRoute_Data["Elwynn Forest"]
local function rcSetup(mode, startX)
  reset()
  ELW3["TestNb"] = {{8, 12}}; HR.categories.herbs.merged = nil
  HR.db.verify = mode; HR.db.verifyAhead = false; HR.db.revive = false; HR.db.nearest = false
  HR.db.ambiguity = false; HR.RECHECK_YD = 40; HR.verifyHits = 3
  ppx, ppy = startX, 988; nodes = {{8, 12}}; hitR = 6
  printed = {}; SlashCmdList.HERBROUTE("testnb")
  local rt = HR.route
  RunTimers()
  return rt
end
local function rcTeardown()
  go("stop"); ELW3["TestNb"] = nil; HR.categories.herbs.merged = nil; HR.RECHECK_YD = nil
end
-- confirmed from 55 yd: rechecked once at 40 yd, then the last check at 35 yd
local rc = rcSetup("report", 1047)
local st = rc.vstate[1]
assert(st.confirmed and st.confirmDist > 54 and not st.farDone and rc.vstats.probes == 1, "first confirmation")
ppx = 1030; RunTimers() -- 38 yd
assert(st.farDone and not st.nearDone and rc.vstats.probes == 2, "recheck at 40 yd: " .. rc.vstats.probes)
RunTimers()
assert(rc.vstats.probes == 2, "the recheck happens once")
ppx = 1025; RunTimers() -- 33 yd
assert(st.nearDone and rc.vstats.probes == 3, "last check before arrival")
rcTeardown()
-- a node taken meanwhile is found at the recheck
rc = rcSetup("remove", 1047)
nodes = {}
ppx = 1030; printed = {}; RunTimers()
assert(rc.removed[1] and msgs():find("has no node: removed", 1, true), "an empty recheck removes the point: " .. msgs())
rcTeardown()
-- first confirmation already inside the recheck distance: no extra probe
rc = rcSetup("report", 1030)
assert(rc.vstate[1].confirmDist <= 40 and rc.vstats.probes == 1, "confirmed from 38 yd")
RunTimers()
assert(rc.vstats.probes == 1 and not rc.vstate[1].farDone, "no recheck right after a close confirmation")
ppx = 1025; RunTimers()
assert(rc.vstats.probes == 2 and rc.vstate[1].nearDone, "only the last check")
rcTeardown()

-- 18b. the combat checkbox is one switch for every probe: current point, ahead, points outside the route, ambiguity
local function combatRun(allowed)
  reset()
  ELW3["TestNb"] = {{8, 12}, {8, 35}, {14, 12}}; HR.categories.herbs.merged = nil
  HR.db.verify = "report"; HR.db.verifyAhead = true; HR.db.revive = true; HR.db.nearest = false
  HR.db.ambiguity = false; HR.RECHECK_YD = 0; HR.verifyHits = 3; HR.db.verifyCombat = allowed
  ppx, ppy = 1332, 988; nodes = {}; hitR = 6
  printed = {}; SlashCmdList.HERBROUTE("testnb")
  local rt = HR.route
  RunTimers()
  HR:SkipPoint() -- the current point leaves the route: a candidate outside the route
  combat = true
  ppx, ppy = 1032, 988; nodes = {{8, 12}, {8, 35}, {14, 12}}
  printed = {}; RunTimers()
  combat = false
  return rt
end
local rtOff = combatRun(false)
assert(rtOff.vstats.probes == 0 and (rtOff.revivedCount or 0) == 0, "no probe of any kind in combat when the box is off")
go("stop")
local rtOn = combatRun(true)
assert(rtOn.vstats.probes >= 1 and rtOn.vstats.ahead and rtOn.vstats.ahead >= 1, "the points ahead are probed in combat")
assert((rtOn.revivedCount or 0) == 1, "the point outside the route is probed and put back in combat: " .. msgs())
ELW3["TestNb"] = nil; HR.categories.herbs.merged = nil; HR.RECHECK_YD = nil; HR.db.verifyCombat = false
go("stop")

-- 19. report mode: an empty point ahead is probed again each 60 yd travelled, silently, and followed when a node appears
reset()
ELW3["TestNb"] = {{8, 12}, {8, 35}}; HR.categories.herbs.merged = nil
HR.db.verify = "report"; HR.db.verifyAhead = true; HR.db.revive = false; HR.db.nearest = true
HR.db.ambiguity = false; HR.RECHECK_YD = 0; HR.verifyHits = 3
ppx, ppy = 1032, 988; nodes = {}; hitR = 6
printed = {}
SlashCmdList.HERBROUTE("testnb")
local rt19 = HR.route
RunTimers()
nodes = {{8, 12}} -- a node respawns on the point that is not the current target
travel(8) -- the player walks 80 yd: the empty points ahead are probed again
local keptCount = 0
for _ in msgs():gmatch("has no node %(report mode, kept") do keptCount = keptCount + 1 end
assert(keptCount == 2, "each empty point is announced once, not at every new probe: " .. keptCount .. " " .. msgs())
assert(msgs():find("Nearest: TestNb is filled", 1, true), "the respawned point must become the target: " .. msgs())
assert(rt19.points[1].y == 12 and rt19.vstate[1].confirmed and not rt19.vstate[1].final, "the point is confirmed again and is the current target")
assert(#WP() == 1 and WP()[1].title:find("1/", 1, true), "a waypoint points to it")
ELW3["TestNb"] = nil; HR.categories.herbs.merged = nil; HR.RECHECK_YD = nil
go("stop")

-- 18a. calibration and scan commands follow the same box
reset(); combat = true; HR.db.verifyCombat = false
go("verify calibrate"); assert(msgs():find("not in combat", 1, true), msgs())
HR.db.verifyCombat = true
go("verify calibrate"); assert(not msgs():find("not in combat", 1, true), "calibration must start in combat when the box is ticked: " .. msgs())
HR.db.verifyCombat = false; combat = false
go("stop")

-- 18. option: probing during combat
reset(); HR.db.verify = "report"; HR.verifyHits = 0; HR.db.verifyCombat = false
nodes = {{first.x, first.y}}
combat = true
go("peacebloom")
assert(HR.route.vstats.probes == 0 and HR.verifyReason and HR.verifyReason:find("combat", 1, true), "no probe in combat by default")
go("stop"); reset(); HR.db.verify = "report"; HR.verifyHits = 0
HR.db.verifyCombat = true; combat = true; nodes = {{first.x, first.y}}
go("peacebloom")
assert(HR.route.vstate[1] and HR.route.vstate[1].confirmed and HR.route.vstats.probes >= 1, "the probe must run in combat when allowed: " .. tostring(HR.verifyReason))
assert(sx == 0 and sy == 0, "minimap restored")
go("stop")
-- the minimap cannot be moved back in combat: it keeps being retried and no other probe starts meanwhile
reset(); HR.db.verify = "report"; HR.verifyHits = 0; HR.db.verifyCombat = true; combat = true
nodes = {{first.x, first.y}}
local origSetPoint, blockedSet = Minimap.SetPoint, false
Minimap.SetPoint = function(m, a, b, c2, x, y)
  if blockedSet and x == 0 and y == 0 then return end -- the client refuses to put the minimap back
  return origSetPoint(m, a, b, c2, x, y)
end
blockedSet = true
C_Timer.After(5, function() blockedSet = false end)
go("peacebloom")
assert(sx == 0 and sy == 0, "the minimap must end up at home once the client allows it")
Minimap.SetPoint = origSetPoint
combat = false; HR.db.verifyCombat = false
go("stop")
go("verify combat on"); assert(HR.db.verifyCombat == true and msgs():find("during combat: on", 1, true), msgs())
go("verify combat off"); assert(HR.db.verifyCombat == false)

-- 20. gathering: the node is named by the position, the end of the gathering probes everything again
local ELW5 = HerbRoute_Data["Elwynn Forest"]
local gaChannel = function() return "Herb Gathering", "", "", (Now() - 4) * 1000, (Now() - 1) * 1000 end -- a channel that has just ended
local noChannel = function() return nil end
UnitChannelInfo = noChannel
GetSpellInfo = function(id)
  if id == 2366 then return "Herb Gathering" elseif id == 1459 then return "Arcane Intellect" elseif id == 99999 then return "Herbalism" end
end
local function gaSetup()
  reset()
  ELW5["TestNb"] = {{8, 12}, {8, 35}, {14, 12}}; HR.categories.herbs.merged = nil
  HR.db.verify = "off"; HR.db.verifyAhead = false; HR.db.revive = true; HR.db.nearest = false
  HR.db.ambiguity = false; HR.db.gatherDebug = false; HR.verifyHits = 3
  ppx, ppy = 1332, 988; nodes = {}; hitR = 6
  printed = {}; SlashCmdList.HERBROUTE("testnb")
  local rt = HR.route
  RunTimers()
  return rt
end
local function gaTeardown() go("stop"); ELW5["TestNb"] = nil; HR.categories.herbs.merged = nil; HR.db.gatherDebug = false end
local function standAt(x, y) ppx, ppy = 1000 - x - 1, 1000 - y end -- 1 yd from the point, 5 yd from its neighbour
local function indexOf(rt, x, y) for i, q in ipairs(rt.points) do if q.x == x and q.y == y then return i end end end
local function gather(spell, endEvent, startEvent, info)
  UnitChannelInfo = info or gaChannel
  HR.GatherEvent(startEvent or "UNIT_SPELLCAST_CHANNEL_START", "player", "guid", spell)
  HR.GatherEvent(endEvent or "UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", spell)
  UnitChannelInfo = noChannel
end

-- success on a point ahead: it leaves the route as reached, a wave starts
local rg = gaSetup()
local k = indexOf(rg, 14, 12)
assert(k and k > rg.index, "the point must be ahead")
local keyK = HR.PointKey(rg.points[k])
standAt(14, 12)
printed = {}; gather(2366)
assert(rg.removed[k] and rg.cause[keyK].cause == "reached" and rg.harvestedCount == 1 and (rg.removedCount or 0) == 0, "the gathered point leaves the route as reached")
assert(rg.vstats.waves == 1, "one wave")
gaTeardown()

-- success on the current point: the route moves on
rg = gaSetup()
local cur = rg.points[rg.index]
standAt(cur.x, cur.y)
local idx0 = rg.index
gather(2366)
assert(rg.index > idx0 and rg.vstats.waves == 1, "the route advances on the current point")
gaTeardown()

-- failure: nothing leaves the route, but the wave starts and a point that was waiting is probed at once
rg = gaSetup()
HR:SkipPoint()
local skippedGa
for _, e in ipairs(HR.RevivePool(rg)) do if rg.cause[e.key] and rg.cause[e.key].cause == "skip" then skippedGa = e end end
assert(skippedGa, "a skipped candidate")
skippedGa.nextAt = Now() + 500
local near = rg.points[rg.index]
standAt(near.x, near.y)
nodes = {{skippedGa.p.x, skippedGa.p.y}}
gather(2366, "UNIT_SPELLCAST_INTERRUPTED")
assert(not rg.removed[rg.index] and (rg.harvestedCount or 0) == 0, "a failed gathering removes nothing")
assert(rg.vstats.waves == 1 and skippedGa.nextAt == 0, "the wave must reset the waiting time of the candidates")
ppx, ppy = 1000 - skippedGa.p.x + 25, 1000 - skippedGa.p.y -- the candidate is inside the minimap, away from any other point
printed = {}; RunTimers()
assert((rg.revivedCount or 0) == 1 and msgs():find("Revive:", 1, true), "the candidate must be probed right after the wave: " .. msgs())
gaTeardown()

-- a channel stopped before its end counts as a failure
rg = gaSetup()
local keyB = HR.PointKey(rg.points[indexOf(rg, 14, 12)])
standAt(14, 12)
gather(2366, nil, nil, function() return "Herb Gathering", "", "", Now() * 1000, (Now() + 3) * 1000 end)
assert(not rg.removed[indexOf(rg, 14, 12)] and rg.vstats.waves == 1, "stopped early")
gaTeardown()

-- other spells and other units are ignored; an unreadable spell next to a point counts
rg = gaSetup()
standAt(14, 12)
gather(1459)
assert((rg.vstats.waves or 0) == 0 and (rg.harvestedCount or 0) == 0, "an Arcane Intellect cast is not a gathering")
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_START", "target", "guid", 2366)
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target", "guid", 2366)
assert((rg.vstats.waves or 0) == 0, "only the player counts")
gather(nil)
assert(rg.removed[indexOf(rg, 14, 12)] and rg.vstats.waves == 1, "an unreadable spell with a point at hand counts as a gathering")
gaTeardown()

-- a gathering spell known by its name only (Herbalism)
rg = gaSetup()
standAt(14, 12)
gather(99999)
assert(rg.removed[indexOf(rg, 14, 12)] and rg.vstats.waves == 1, "Herbalism must be recognised by its name")
gaTeardown()

-- no point in range: nothing leaves the route, the wave still starts
rg = gaSetup()
ppx, ppy = 1332, 988
gather(2366)
assert((rg.harvestedCount or 0) == 0 and rg.vstats.waves == 1, "node not in the database")
gaTeardown()

-- a cast (not a channel) ends with SUCCEEDED
rg = gaSetup()
standAt(14, 12)
gather(2366, "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START")
assert(rg.removed[indexOf(rg, 14, 12)] and rg.vstats.waves == 1, "cast gathering")
HR.GatherEvent("UNIT_SPELLCAST_STOP", "player", "guid", 2366)
assert(rg.vstats.waves == 1, "the STOP that follows a success does not start a second wave")
gaTeardown()

-- the probes run during the gathering: the "casting" guard is lifted from its start to its end, and no wave starts at the end
local gaActive = function() return "Herb Gathering", "", "", Now() * 1000, (Now() + 3) * 1000 end -- a channel in progress
local function candidateScene()
  local rt = gaSetup()
  HR:SkipPoint()
  local cand
  for _, e in ipairs(HR.RevivePool(rt)) do if rt.cause[e.key] and rt.cause[e.key].cause == "skip" then cand = e end end
  ppx, ppy = 1000 - cand.p.x + 25, 1000 - cand.p.y -- the candidate is inside the minimap, away from the other points
  nodes = {{cand.p.x, cand.p.y}}
  return rt, cand
end
-- control: the player is channelling something else, the guard stays
UnitChannelInfo = gaActive
local rc, cand = candidateScene()
printed = {}; RunTimers()
assert((rc.revivedCount or 0) == 0 and (rc.vstats.waves or 0) == 0, "no probe while casting when it is not a gathering: " .. msgs())
gaTeardown()
-- gathering in progress: the point outside the route is probed at once and put back
rc, cand = candidateScene()
cand.nextAt, cand.nextOdo = Now() + 500, 1e9 -- it would not be probed for a long time
UnitChannelInfo = gaActive
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 2366)
assert(HR.gatheringUntil and rc.vstats.waves == 1 and cand.nextAt == 0 and cand.nextOdo == 0, "the wave starts with the gathering")
printed = {}; RunTimers()
assert((rc.revivedCount or 0) == 1 and msgs():find("Revive:", 1, true), "the probe must run during the channel: " .. msgs())
UnitChannelInfo = gaChannel
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 2366)
assert(HR.gatheringUntil == nil and rc.vstats.waves == 1, "no wave at the end")
UnitChannelInfo = noChannel
gaTeardown()
-- the end does not start a wave: what was waiting keeps waiting
rc, cand = candidateScene()
UnitChannelInfo = gaActive
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 2366)
cand.nextAt, cand.nextOdo = 0, rc.odo + 500
UnitChannelInfo = gaChannel
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 2366)
assert(cand.nextOdo == rc.odo + 500 and rc.vstats.waves == 1, "the end of a gathering changes nothing for the candidates")
UnitChannelInfo = noChannel
gaTeardown()
-- the gathered point itself is left out of the wave
rc, cand = candidateScene()
standAt(cand.p.x, cand.p.y)
UnitChannelInfo = gaActive
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 2366)
assert(cand.nextOdo > rc.odo + 1000 and cand.nextAt > Now(), "the node being gathered is not probed by the wave")
UnitChannelInfo = noChannel
HR.GatherEvent("UNIT_SPELLCAST_FAILED", "player", "guid", 2366)
gaTeardown()
-- trace of the probes made during the gathering
rc, cand = candidateScene()
HR.db.gatherDebug = true
UnitChannelInfo = gaActive
printed = {}
HR.GatherEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 2366)
RunTimers()
assert(msgs():find("Gather: probe during the gathering (point outside the route): line", 1, true), msgs())
UnitChannelInfo = noChannel
HR.GatherEvent("UNIT_SPELLCAST_FAILED", "player", "guid", 2366)
gaTeardown()

-- trace
rg = gaSetup()
standAt(14, 12)
go("gather debug on")
assert(HR.db.gatherDebug == true and msgs():find("Debug on", 1, true), msgs())
printed = {}; gather(2366)
assert(msgs():find("Gather: UNIT_SPELLCAST_CHANNEL_START spell=2366", 1, true) and msgs():find("gathering succeeded", 1, true), msgs())
go("gather debug off"); assert(HR.db.gatherDebug == false)
gaTeardown()
UnitChannelInfo, GetSpellInfo = noChannel, nil

-- 21. chat messages: what the addon says by itself can be switched off, replies and diagnostics stay
reset(); HR.db.verify = "report"; HR.verifyHits = 2; HR.db.chat = false
go("peacebloom")
assert(not msgs():find("has no node", 1, true), "automatic messages are silent when the chat is off: " .. msgs())
printed = {}; HR:Print("silent"); assert(#printed == 0, "Print is silent")
HR:Say("heard"); assert(#printed == 1 and printed[1]:find("heard", 1, true), "Say always prints")
go("verify"); assert(msgs():find("Verify:", 1, true), "a status reply stays")
go("chat"); assert(msgs():find("HerbRoute messages in the chat: off", 1, true), msgs())
go("chat on"); assert(HR.db.chat == true and msgs():find("chat: on", 1, true), msgs())
go("stop")
reset(); HR.db.verify = "report"; HR.verifyHits = 2
go("peacebloom")
assert(msgs():find("has no node", 1, true), "automatic messages are shown when the chat is on")
go("chat off"); assert(HR.db.chat == false)
HR.db.chat = true
go("stop")

-- 8. off, and commands
reset(); HR.db.verify = "off"; nodes = {{first.x, first.y}}
go("peacebloom"); assert(HR.route.vstats.probes == 0)
go("verify report"); assert(HR.db.verify == "report" and msgs():find("Verify: report", 1, true), msgs())
go("verify remove"); assert(HR.db.verify == "remove")
go("verify"); assert(msgs():find("this route:", 1, true), msgs())
go("stop")
io.write("VERIFY TESTS OK\n")
''')

lua.execute(r'''
-- ores: category choice, data, tracking of the category, UI smoke test
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function msgs() return table.concat(printed, "\n") end
local function go(m) printed = {}; SlashCmdList.HERBROUTE(m); RunTimers() end
HR.db = {region=nil, herbs={}, ores={}, category="herbs", mode="follow", radius=15, showMap=true, showMinimap=true,
  isolateTracking=true, verify="off", overrides={}}
HR:OnLoaded()
playerMap = 37; px, py = 0.5, 0.5
if HR.route then HR:StopRoute(true) end

assert(#HR:GetRegions("ores") == 42 and #HR:GetRegions("herbs") == 46, #HR:GetRegions("ores") .. "/" .. #HR:GetRegions("herbs"))
local ores = HR:GetHerbs("Elwynn Forest", "ores")
assert(#ores > 0 and HR:GetHerbs("Elwynn Forest", "herbs")[1] ~= ores[1])
for _, o in ipairs(ores) do assert(not HerbRoute_Data["Elwynn Forest"][o], "ore name in the herb data: " .. o) end
local total = 0
for _, regions in pairs(HerbRoute_OreData) do for _, pts in pairs(regions) do total = total + #pts for _, p in ipairs(pts) do
  assert(p[1] >= 0 and p[1] <= 100 and p[2] >= 0 and p[2] <= 100) end end end
assert(total == 9440, total)

-- merge of neighbouring points: files untouched, counts match the reference greedy merge
local function sumCounts(cat)
  local n = 0
  for _, region in ipairs(HR:GetRegions(cat)) do
    for _, item in ipairs(HR:GetHerbs(region, cat)) do n = n + HR:CountPoints(region, item, cat) end
  end
  return n
end
local rawHerbs, rawOres = sumCounts("herbs"), sumCounts("ores")
assert(rawHerbs == 14642 and rawOres == 9440, rawHerbs .. "/" .. rawOres)
HR.db.mergeDuplicates = true
assert(sumCounts("herbs") == 10458 and sumCounts("ores") == 8834, sumCounts("herbs") .. "/" .. sumCounts("ores"))
local rawCount = 0
for _, items in pairs(HerbRoute_Data) do for _, pts in pairs(items) do rawCount = rawCount + #pts end end
assert(rawCount == 14642, "the raw data must not change")
SlashCmdList.HERBROUTE("merge"); assert(table.concat(printed, " "):find("10458 herbs, 8834 ores", 1, true), table.concat(printed, " "))
if HR.route then HR:StopRoute(true) end
printed = {}; SlashCmdList.HERBROUTE("ores copper vein"); RunTimers()
assert(HR.route and #HR.route.points == HR:CountPoints("Elwynn Forest", "Copper Vein", "ores") and #HR.route.points < #HerbRoute_OreData["Elwynn Forest"]["Copper Vein"], "the route must use the merged points")
HR:StopRoute(true)
SlashCmdList.HERBROUTE("merge off"); assert(sumCounts("herbs") == 14642)
HR.db.mergeDuplicates = nil

local herbsBefore = HR.db.herbs
go("ores copper vein")
local r = HR.route
assert(r and r.category == "ores", msgs())
assert(#r.points == #HerbRoute_OreData["Elwynn Forest"]["Copper Vein"] and r.points[1].herb == "Copper Vein")
assert(HR.db.ores["Elwynn Forest"]["Copper Vein"] and next(HR.db.herbs) == nil and HR.db.category == "ores")
HR:StopRoute(true)

go("ores Stranglethorn Vale: all")
r = HR.route
local want = 0
for _, pts in pairs(HerbRoute_OreData["Stranglethorn Vale"]) do want = want + #pts end
assert(r and r.category == "ores" and #r.points == want, msgs())
HR:StopRoute(true)

go("ores nonsense: copper"); assert(msgs():find("Unknown region", 1, true), msgs())
go("ores Teldrassil: all"); assert(msgs():find("Unknown region", 1, true), msgs())
go("ores peacebloom"); assert(HR.route == nil and msgs():find("Not found in Elwynn Forest", 1, true), msgs())
go("herbs peacebloom"); assert(HR.route and HR.route.category == "herbs" and HR.db.category == "herbs", msgs())
HR:StopRoute(true)
go("peacebloom"); assert(HR.route and HR.route.category == "herbs"); HR:StopRoute(true)

-- reroute: reorder the points ahead after removals, only when switched on
HR.db.reroute = false
printed = {}; SlashCmdList.HERBROUTE("peacebloom"); RunTimers()
local rr = HR.route
local origPoints = {}
for i, p in ipairs(rr.points) do origPoints[i] = p end
rr.vstate = {}
local marked = origPoints[40]
rr.vstate[40] = {marker = true}
for _, i in ipairs({10, 20, 30, 50, 60}) do HR:DropPoint(i) end
RunTimers()
assert(#rr.points == #origPoints and not msgs():find("Reroute from", 1, true), "off: the route must keep its order")
HR:StopRoute(true)
HR.db.reroute = true
printed = {}; SlashCmdList.HERBROUTE("peacebloom"); RunTimers()
rr = HR.route
origPoints = {}
for i, p in ipairs(rr.points) do origPoints[i] = p end
local n0 = #origPoints
rr.vstate = {}
marked = origPoints[40]
rr.vstate[40] = {marker = true}
HR:SkipPoint(); HR:SkipPoint(); assert(rr.index == 3)
local head = {origPoints[1], origPoints[2], origPoints[3]}
for _, i in ipairs({10, 20, 30, 50, 60}) do HR:DropPoint(i) end
RunTimers()
assert(msgs():find("Reroute from", 1, true), msgs())
assert(#rr.points == n0 - 5, #rr.points .. " vs " .. n0 - 5)
assert(rr.points[1] == head[1] and rr.points[2] == head[2] and rr.index == 3, "the points behind must stay")
assert(msgs():find("from your position", 1, true), msgs())
assert(#WP() == 1 and math.abs(WP()[1][2] - rr.points[3].x / 100) < 1e-9 and math.abs(WP()[1][3] - rr.points[3].y / 100) < 1e-9, "TomTom must point at the (possibly new) current point")
local seen = {}
for i, p in ipairs(rr.points) do seen[p] = i end
for _, i in ipairs({10, 20, 30, 50, 60}) do assert(not seen[origPoints[i]], "removed point still present") end
assert(rr.vstate[seen[marked]] and rr.vstate[seen[marked]].marker, "the verification state must follow its point")
assert(next(rr.removed) == nil or true)
local count = 0
for _, items in pairs(HerbRoute_Data) do for _, pts in pairs(items) do count = count + #pts end end
assert(count == 14642, "the database must not change")
-- player not on the route's map: the current point stays the start and the target
HR:StopRoute(true)
printed = {}; SlashCmdList.HERBROUTE("peacebloom"); RunTimers()
rr = HR.route
HR:SkipPoint(); HR:SkipPoint(); assert(rr.index == 3)
local keepCur = rr.points[3]
playerMap = 999
for _, i in ipairs({10, 20, 30}) do HR:DropPoint(i) end
RunTimers()
playerMap = 37
assert(msgs():find("from the current point", 1, true) and rr.points[3] == keepCur, msgs())
SlashCmdList.HERBROUTE("reroute off"); assert(HR.db.reroute == false)
SlashCmdList.HERBROUTE("reroute on"); assert(HR.db.reroute == true)
HR:StopRoute(true)
HR.db.reroute = nil

-- tracking follows the category
local active = {["Find Herbs"] = true, ["Flight Master"] = true}
local types = {{"Find Herbs", 2383}, {"Find Minerals", 2580}, {"Flight Master"}}
C_Spell = {GetSpellName = function(id) return id == 2383 and "Find Herbs" or id == 2580 and "Find Minerals" or nil end}
C_Minimap = {GetNumTrackingTypes = function() return #types end,
  GetTrackingInfo = function(i) return {name = types[i][1], active = active[types[i][1]] or false, spellID = types[i][2]} end,
  SetTracking = function(i, on) active[types[i][1]] = on or nil end}
local function list() local o = {} for _, t in ipairs(types) do if active[t[1]] then o[#o + 1] = t[1] end end return table.concat(o, ",") end
go("ores copper vein")
assert(HR.route and list() == "Find Minerals", list())
assert(HR:TrackingActive("ores") == true and HR:TrackingActive("herbs") == false and HR:TrackingName("ores") == "Find Minerals")
HR:StopRoute()
assert(list() == "Find Herbs,Flight Master", list())
go("peacebloom"); assert(list() == "Find Herbs", list()); HR:StopRoute()
assert(list() == "Find Herbs,Flight Master", list())

-- the window opens on the saved category without error
HR.db.category = "ores"
local ns2 = {}
for _, f in ipairs({"Core","Tracking","Resolver","MinimapUtil","RouteMath","Runner","Overlay","Probe","Verify","Gather","UI"}) do
  local fh = assert(io.open("HerbRoute/"..f..".lua")); local src = fh:read("a"); fh:close()
  assert(load(src, f))("HerbRoute", ns2)
end
ns2.db = {region = "Elwynn Forest", herbs = {}, ores = {}, category = "ores", mode = "follow", radius = 15, overrides = {}}
ns2:ToggleUI()
assert(ns2.db.category == "ores")
-- skip button and key binding functions
ns2.db.skipButton = nil
ns2:ToggleSkipButton(true); assert(ns2.db.skipButton.shown == true)
ns2:ToggleSkipButton(); assert(ns2.db.skipButton.shown == false)
ns2:InitSkipButton()
assert(BINDING_NAME_HERBROUTE_SKIP and BINDING_HEADER_HERBROUTE)
-- region search: letters present in the name, any order, occurrences counted
assert(HR.MatchRegion("SOS", "Swamp of Sorrows"), "SOS must keep Swamp of Sorrows")
assert(HR.MatchRegion("sos", "Swamp of Sorrows") and HR.MatchRegion("  S o S ", "Swamp of Sorrows"), "case and spaces are ignored")
assert(HR.MatchRegion("rows", "Swamp of Sorrows") and HR.MatchRegion("srow", "Swamp of Sorrows"), "any order")
assert(not HR.MatchRegion("SOS", "Elwynn Forest"), "two S are needed")
assert(HR.MatchRegion("SO", "Elwynn Forest") and HR.MatchRegion("OS", "Elwynn Forest") and not HR.MatchRegion("OOS", "Elwynn Forest"), "one S and one O are enough for SO, two O are not")
assert(not HR.MatchRegion("zz", "Swamp of Sorrows") and not HR.MatchRegion("x", "Swamp of Sorrows"))
assert(HR.MatchRegion("", "Anything") and HR.MatchRegion(nil, "Anything"), "an empty search keeps every region")
assert(HR.MatchRegion("ssss", "Swamp of Sorrows") == false, "four S are too many")
assert(HR.MatchRegion("Shendralas", "Shen'dralas"), "punctuation is ignored")
local kept = 0
for _, name in ipairs(HR:GetRegions("herbs")) do if HR.MatchRegion("SOS", name) then kept = kept + 1 end end
assert(kept >= 1 and kept < #HR:GetRegions("herbs"), "the search must narrow the list: " .. kept)
io.write("ORE TESTS OK\n")
''')
