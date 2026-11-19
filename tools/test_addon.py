from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
-- Minimal WoW / TomTom mock
local timers, now, seq = {}, 0, 0
C_Timer = {After = function(d, f) seq = seq + 1; timers[#timers+1] = {t = now + (d or 0), s = seq, f = f} end}
function Now() return now end
function RunTimers()
  local n = 0
  while #timers > 0 do
    local bi = 1
    for i = 2, #timers do
      local a, b = timers[i], timers[bi]
      if a.t < b.t or (a.t == b.t and a.s < b.s) then bi = i end
    end
    local x = table.remove(timers, bi)
    now = math.max(now, x.t); x.f(); n = n + 1
  end
  return n
end
wipe = function(t) for k in pairs(t) do t[k]=nil end end
tinsert = table.insert; UISpecialFrames = {}
SlashCmdList = {}
printed = {}
print = function(...) printed[#printed+1] = table.concat({...}, " ") end
local function widget()
  local w = {}
  return setmetatable(w, {
    __index = function(t, k) local c = widget(); rawset(t, k, c); return c end,
    __call = function(self) return self end,
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
for _, f in ipairs({"Data/HerbData","Core","Resolver","RouteMath","Runner","Overlay","Probe","UI"}) do
  local fh = assert(io.open("HerbRoute/"..f..".lua")); local src = fh:read("a"); fh:close()
  assert(load(src, f))("HerbRoute", ns)
end
HR = ns
''')
lua.execute(r'''
local ev = CreateFrame()  -- the addon frame is a mock: fire its init by hand
HerbRouteDB = nil
HR.db = {region=nil, herbs={}, mode="follow", radius=15, showMap=true, showMinimap=true, overrides={}}
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
playerMap = 999; SlashCmdList.HERBROUTE("fadeleaf"); HR.route = nil
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
local bl, mode = {20, 10}, "hover"
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
  return (bx - cu) ^ 2 + (by - cv) ^ 2 <= 100
end
C_TooltipInfo = {GetMinimapMouseover = function()
  local hit = {lines = {{leftText = "Wild Steelbloom"}}}
  if mode == "none" then return nil end
  if mode == "stale" then return hit end
  if mode == "dead" then return Now() < t0 + 4 and hit or nil end
  return geometry() and hit or nil
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
assert(t:find("Baseline read (no probe call): data present", 1, true), t)
assert(t:find("structure: lines:table | lines[1]: leftText:string", 1, true), t)
assert(t:find("RESULT: data under the real mouse hover (cursor inside the minimap disc)", 1, true), t)

local savedCur = curx
curx = 5000
t = run("probe")
assert(t:find("RESULT: no data under the cursor (cursor outside", 1, true), t)
curx = savedCur

issecretvalue = function() return true end
t = run("probe")
assert(t:find("structure: <secret value>", 1, true) and t:find("NOTE: text fields are secret values", 1, true), t)
issecretvalue = nil

local saved = C_TooltipInfo.GetMinimapMouseover
C_TooltipInfo.GetMinimapMouseover = nil
assert(run("probe"):find("function missing", 1, true))
C_TooltipInfo.GetMinimapMouseover = saved

assert(run("probe minimap"):find("RESULT: data under the real mouse hover", 1, true))
curx = 5000
assert(run("probe minimap"):find("RESULT: no data under the cursor", 1, true))
assert(table.concat(printed, "\n"):find("The cursor is not inside the minimap", 1, true))
curx = savedCur

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
assert(w:find("RESULT: presence of a blip can be sampled by moving the minimap under a resting cursor (answer after 1 frame)", 1, true), w)
assert(w:find("  hit (", 1, true) and w:find("  control (0,0): +1 frame absent", 1, true), w)
assert(bw("hover", "blink world hidden"):find("(hidden)", 1, true))
assert(bw("stale"):find("RESULT: data is present even with the minimap in place", 1, true))
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
