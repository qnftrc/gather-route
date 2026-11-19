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
for _, f in ipairs({"Data/HerbData","Data/HerbDataGatherMate","Data/OreDataGatherMate","Data/OreDataWowhead","Core","Tracking","Resolver","MinimapUtil","RouteMath","Runner","Overlay","Probe","Verify","UI"}) do
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

-- all mode
HR.db.mode = "all"
SlashCmdList.HERBROUTE("stranglethorn vale: fadeleaf"); RunTimers()
assert(HR.route and #WP() == #HR.route.points, "all mode pins")
HR:SkipPoint(); assert(#WP() == #HR.route.points - 1)
HR:StopRoute(); assert(#WP() == 0)

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
  if (bx - cu) ^ 2 + (by - cv) ^ 2 <= 100 then return true end
  if neighbour then
    local nx = (cxm + sx + bl[1] - 40) * es
    return (nx - cu) ^ 2 + (by - cv) ^ 2 <= 100
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
inCombat = false; mouseDown = true
assert(bw("hover"):find("ABORTED: a mouse button is held", 1, true))
mouseDown = false
worldAfter = false
curx = 5000
assert(bw("hover"):find("ABORTED: phase A needs the cursor on a herb blip", 1, true))
curx = savedCur
bl = nil
assert(bw("hover"):find("ABORTED: phase A found no data under the cursor", 1, true))
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
for _, f in ipairs({"Core","Tracking","Resolver","MinimapUtil","RouteMath","Runner","Overlay","Probe","Verify","UI"}) do
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
io.write("ORE TESTS OK\n")
''')
