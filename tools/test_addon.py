from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
-- Minimal WoW / TomTom mock
local timers = {}
C_Timer = {After = function(_, f) timers[#timers+1] = f end}
function RunTimers() local n=0 while #timers>0 do local t=table.remove(timers,1) t() n=n+1 end return n end
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
-- /hr probe against a fake minimap: blips answer only with the soft cursor,
-- in the "cursor" convention (screen pixels = units * effective scale).
local cxm, cym, es = 500, 400, 2
local soft, last, zoom = false, nil, 3
local blips, mode = {}, "ok"
Minimap = {
  GetCenter = function() return cxm, cym end, GetWidth = function() return 140 end,
  GetHeight = function() return 140 end, GetEffectiveScale = function() return es end,
  GetZoom = function() return zoom end, SetZoom = function(_, z) zoom = z end,
  GetZoomLevels = function() return 3 end, IsVisible = function() return true end,
  UpdateMouseoverAtPoint = function(_, x, y) last = {x, y} end,
  SetUsingSoftCursor = function(_, b) soft = b end,
}
C_Minimap = {GetViewRadius = function() return 70 end, GetNumTrackingTypes = function() return 2 end,
  GetTrackingInfo = function(i) if i == 1 then return {name = "Find Herbs", active = true} end return {name = "Find Minerals", active = false} end}
C_TooltipInfo = {GetMinimapMouseover = function()
  if mode == "echo" then return {lines = {{leftText = "Wild Steelbloom"}}} end
  if mode == "none" or not soft or not last then return nil end
  for _, b in ipairs(blips) do
    if (last[1] - b[1]) ^ 2 + (last[2] - b[2]) ^ 2 <= 100 then return {lines = {{leftText = b[3]}}} end
  end
end}
local hbd = {}
function hbd:GetPlayerWorldPosition() return 950, 950, "inst" end
function hbd:GetWorldCoordinatesFromZone(x, y) return 1000 - x * 100, 1000 - y * 100, "inst" end
LibStub = function() return hbd end
playerMap, px, py = 37, 0.5, 0.5

-- a Peacebloom point near the middle of the map (1% = 1 yd in this fake world), and the blip on it
local best, bd
for _, p in ipairs(HerbRoute_Data["Elwynn Forest"]["Peacebloom"]) do
  local d = (p[1] - 50) ^ 2 + (p[2] - 50) ^ 2
  if not bd or d < bd then best, bd = p, d end
end
local dx, dy = 950 - (1000 - best[1]), (1000 - best[2]) - 950
assert(dx * dx + dy * dy < 55 * 55, "test point too far from the center")
blips[1] = {(cxm + dx) * es, (cym + dy) * es, "Peacebloom"}

local function run(cmd)
  printed = {}; HR.db.probe = nil
  SlashCmdList.HERBROUTE(cmd); RunTimers()
  return HR.db.probe and HR.db.probe.text or table.concat(printed, "\n")
end

local t = run("probe")
assert(t:find("RESULT: answers that depend on the probed point with cursor/soft", 1, true), t)
assert(t:find("Baseline read (no probe call): no data", 1, true) and t:find("structure: nil", 1, true), t)
assert(not t:match("RESULT:[^\n]*ui/"), "ui convention should not read")
assert(t:find("Answer area around 'Peacebloom'", 1, true), t)
local err = t:match("%(1 herb blips%): min ([%d.]+)")
assert(err and tonumber(err) < 4, "database error too large: " .. tostring(err))
assert(soft == false, "soft cursor not restored")
io.write("probe ok: ", t:match("Distance blip[^\n]*"), "\n")

mode = "none"
assert(run("probe"):find("RESULT: no answer in any configuration", 1, true))
mode = "echo"
local e = run("probe")
assert(e:find("every probe answered", 1, true) and e:find("it is the real mouse hover", 1, true), e)
assert(e:find("Baseline read (no probe call): data present", 1, true), e)
assert(e:find("structure: lines:table | lines[1]: leftText:string", 1, true), e)
assert(not e:find("Blips found", 1, true), "echo must not be treated as blips")
issecretvalue = function() return true end
local es2 = run("probe")
assert(es2:find("it is the real mouse hover", 1, true) and es2:find("WARNING: tooltip text is a secret value", 1, true), es2)
issecretvalue = nil
mode = "ok"

issecretvalue = function() return true end
assert(run("probe"):find("WARNING: tooltip text is a secret value", 1, true))
issecretvalue = nil

local ok = run("probe world")
assert(ok:find("RESULT: answers that depend", 1, true), ok)

local z = run("probe zoom")
assert(z:find("Zoom restored to 3", 1, true) and zoom == 3 and soft == false, z)
assert(z:find("beyond the disc edge", 1, true))

SlashCmdList.HERBROUTE("probe copy")

local saved = Minimap.UpdateMouseoverAtPoint
Minimap.UpdateMouseoverAtPoint = nil
assert(run("probe"):find("cannot be read", 1, true))
Minimap.UpdateMouseoverAtPoint = saved

HR.Probe.best = nil
assert(run("probe zoom"):find("Run /hr probe first", 1, true))
io.write("PROBE TESTS OK\n")
''')
