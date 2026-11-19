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
for _, f in ipairs({"Data/HerbData","Core","Resolver","RouteMath","Runner","Overlay","UI"}) do
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
