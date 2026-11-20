local addonName, HR = ...

local FROM = "HerbRoute"

function HR:InitRunner()
    TomTom.RegisterCallback(self, "WaypointRemoved", function(event, uid)
        HR:OnWaypointRemoved(uid)
    end)
end

function HR:RouteChanged()
    if self.UpdateUI then self:UpdateUI() end
    if self.UpdateOverlay then self:UpdateOverlay() end
end

function HR:IsRouteActive()
    return self.route ~= nil
end

-- Returns the point index of the route, and the total.
function HR:GetProgress()
    local r = self.route
    if not r then return 0, 0 end
    return r.index, #r.points
end

local function removeUID(uid)
    if type(uid) ~= "table" then return end
    HR.removing = true
    TomTom:RemoveWaypoint(uid)
    HR.removing = false
end

local function title(r, i)
    return ("%s %d/%d"):format(r.points[i].herb, i, #r.points)
end

local function addPoint(r, i, opts)
    local p = r.points[i]
    opts.title = title(r, i)
    opts.from = FROM
    opts.silent = true
    return TomTom:SetCustomWaypoint(r.mapID, p.x / 100, p.y / 100, opts)
end

-- Follow mode: one active waypoint at a time. Reaching it activates the next.
local function showCurrent(r)
    local radius = HR.db.radius
    local callbacks = TomTom:DefaultCallbacks({cleardistance = 0, arrivaldistance = radius})
    local ping = callbacks.distance[radius]
    callbacks.distance[radius] = function(event, uid, ...)
        if ping then ping(event, uid, ...) end
        if HR.route == r and uid == r.current then HR:Advance() end
    end
    r.current = addPoint(r, r.index, {
        crazy = true,
        cleardistance = 0,
        arrivaldistance = radius,
        callbacks = callbacks,
    })
end

local function finish(self)
    self:Print("Route finished.")
    self:StopRoute(true)
end

function HR.PointKey(p)
    return p.x .. "|" .. p.y .. "|" .. p.herb
end

-- How a point left the route in progress (skip, absent, reached), and when. The
-- points of the database that are no longer ahead in the route are the
-- candidates of the revival (Verify.lua); this only adds the cause and the time.
local function noteCause(r, p, cause)
    r.cause = r.cause or {}
    r.cause[HR.PointKey(p)] = {cause = cause, at = GetTime()}
end

function HR:Advance(skipped)
    local r = self.route
    if not r or r.mode ~= "follow" then return end
    local cur = r.points[r.index]
    if cur then
        if skipped then
            noteCause(r, cur, "skip")
        elseif not r.removed[r.index] then
            noteCause(r, cur, "reached")
        end
    end
    local replan = r.rerouteOnArrival and not skipped
    r.rerouteOnArrival = nil
    if r.current then removeUID(r.current) end
    r.current = nil
    r.index = r.index + 1
    while r.removed[r.index] do r.index = r.index + 1 end
    if r.index > #r.points then return finish(self) end
    showCurrent(r)
    self:RouteChanged()
    if replan then self:Reroute() end
end

function HR:SkipPoint()
    local r = self.route
    if not r then return self:Print("No active route.") end
    self:Advance(true)
end

local REROUTE_DELAY = 1.5

-- Reorders the route from the player's real position (nearest neighbour then 2-opt, as for a
-- new route). The current point is reordered with the points ahead, so the next target can
-- change; when the player's position is not on the route's map, the current point is the
-- start and stays the target. The database is never touched; the verification state of each
-- point follows it to its new place.
function HR:Reroute(fromCurrent)
    local r = self.route
    if not r or r.mode ~= "follow" or self.rerouting then return end
    local index, rev = r.index, r.rev or 0
    local cur = r.points[index]
    local m, px, py = self:GetPlayerPosition()
    local fromPlayer = not fromCurrent and m ~= nil and m == r.mapID
    local first = fromPlayer and index or index + 1
    local tail = {}
    for i = first, #r.points do
        if not r.removed[i] then tail[#tail + 1] = r.points[i] end
    end
    if #tail < 3 then return end
    local start = fromPlayer and {x = px, y = py} or {x = cur.x, y = cur.y}
    local before = HR.Math.pathLength(tail, start)
    self.rerouting = true
    local co = coroutine.create(function()
        local copy = {}
        for i, p in ipairs(tail) do copy[i] = p end
        return HR.Math.solve(copy, start, coroutine.yield)
    end)
    local function step()
        if self.route ~= r then self.rerouting = false return end
        local ok, result = coroutine.resume(co)
        if not ok then
            self.rerouting = false
            return self:Print("Reroute error: " .. tostring(result))
        end
        if coroutine.status(co) ~= "dead" then return C_Timer.After(0, step) end
        self.rerouting = false
        if r.index ~= index or (r.rev or 0) ~= rev then
            return self:ScheduleReroute()
        end
        local old = {}
        for i = first, #r.points do old[r.points[i]] = i end
        local points, vstate = {}, {}
        for i = 1, first - 1 do
            points[i] = r.points[i]
            vstate[i] = r.vstate and r.vstate[i]
        end
        for _, p in ipairs(result) do
            points[#points + 1] = p
            vstate[#points] = r.vstate and r.vstate[old[p]]
        end
        local removed = {}
        for i = 1, first - 1 do if r.removed[i] then removed[i] = true end end
        r.points, r.removed = points, removed
        if r.vstate then r.vstate = vstate end
        r.world = nil
        r.rev = rev + 1
        local after = HR.Math.pathLength(result, start)
        self:Print(("Reroute from %s: %d point(s) reordered, distance %.1f -> %.1f."):format(
            fromPlayer and "your position" or "the current point", #result, before, after))
        if fromPlayer and r.points[index] ~= cur then
            if r.current then removeUID(r.current) end
            r.current = nil
            showCurrent(r)
        end
        self:RouteChanged()
    end
    step()
end

function HR:ScheduleReroute()
    local r = self.route
    if not r or r.mode ~= "follow" or self.db.reroute ~= true then return end
    r.rerouteToken = (r.rerouteToken or 0) + 1
    local token = r.rerouteToken
    C_Timer.After(REROUTE_DELAY, function()
        if self.route == r and r.rerouteToken == token and self.db.reroute == true then self:Reroute() end
    end)
end

-- Drops a point from the running route (never from the database).
function HR:DropPoint(i)
    local r = self.route
    if not r or r.removed[i] then return end
    if r.points[i] then noteCause(r, r.points[i], "absent") end
    r.removed[i] = true
    r.rev = (r.rev or 0) + 1
    r.removedCount = (r.removedCount or 0) + 1
    self:ScheduleReroute()
    if i == r.index then self:Advance() end
    self:RouteChanged()
end

-- The gathering of a point ahead in the route ends: it leaves the route as reached.
function HR:HarvestPoint(i)
    local r = self.route
    if not r or r.removed[i] or not r.points[i] then return end
    noteCause(r, r.points[i], "reached")
    r.removed[i] = true
    r.rev = (r.rev or 0) + 1
    r.harvestedCount = (r.harvestedCount or 0) + 1
    self:ScheduleReroute()
    if i == r.index then self:Advance() end
    self:RouteChanged()
end

function HR:MarkReached(p)
    local r = self.route
    if r and p then noteCause(r, p, "reached") end
end

local function shiftFrom(t, pos)
    local out = {}
    for j, v in pairs(t) do out[j >= pos and j + 1 or j] = v end
    return out
end

-- Puts a point that is back (reached, skipped or removed earlier) at the head of
-- the route, as the new target. The nearest-point rule then applies: if another
-- filled point is nearer to the player, that one takes the head. The rest of the
-- route is recomputed from the head. The database is never touched.
function HR:ReviveSkipped(entry)
    local r = self.route
    if not r or r.mode ~= "follow" then return false end
    local p = entry.p
    local np = {}
    for k, v in pairs(p) do np[k] = v end
    local pos = r.index
    table.insert(r.points, pos, np)
    r.removed = shiftFrom(r.removed, pos)
    if r.vstate then
        r.vstate = shiftFrom(r.vstate, pos)
        r.vstate[pos] = {misses = 0, none = 0, nextAt = 0, confirmed = true, farDone = true, amb = entry.amb}
    end
    r.world = nil
    r.rev = (r.rev or 0) + 1
    if entry.cause == "absent" and (r.removedCount or 0) > 0 then r.removedCount = r.removedCount - 1 end
    r.revivedCount = (r.revivedCount or 0) + 1
    if entry.key and r.cause then r.cause[entry.key] = nil end
    if r.current then removeUID(r.current) end
    r.current = nil
    showCurrent(r)
    local from = {skip = "skipped", absent = "removed", reached = "reached"}
    self:Print(("Revive: %s is back inside the minimap (%s earlier): back at the head of the route, next target (%d points)."):format(
        np.herb, from[entry.cause] or "passed", #r.points))
    self:RouteChanged()
    self:RetargetNearest(r)
    self:Reroute(true)
    return true
end

local function moveToIndex(r, from, to)
    local p = table.remove(r.points, from)
    table.insert(r.points, to, p)
    local function remap(t)
        local out = {}
        for j, v in pairs(t) do
            local nj = j
            if j == from then nj = to elseif j >= to and j < from then nj = j + 1 end
            out[nj] = v
        end
        return out
    end
    r.removed = remap(r.removed)
    if r.vstate then r.vstate = remap(r.vstate) end
end

-- After a probe found a node: among the filled points (confirmed by the
-- minimap) that are inside the minimap, the one nearest to the player becomes
-- the target, with a new TomTom waypoint. The route is recomputed from the
-- player's position once that waypoint is reached. No distance threshold.
function HR:RetargetNearest(r)
    r = r or self.route
    if not r or r.mode ~= "follow" or self.db.nearest == false or not self.PointGeometry or not r.vstate then return false end
    local cands = {}
    for j = r.index, #r.points do
        local st = r.vstate[j]
        if st and st.confirmed and not r.removed[j] then
            local g = self.PointGeometry(r, j)
            if g and g.inside then cands[#cands + 1] = {j = j, d = g.dist, st = st} end
        end
    end
    table.sort(cands, function(a, b)
        if a.d ~= b.d then return a.d < b.d end
        return a.j < b.j
    end)
    -- An ambiguous point counts like any other filled point: the nearest wins.
    local bestJ, bestD = cands[1] and cands[1].j, cands[1] and cands[1].d
    if not bestJ or bestJ == r.index then return false end
    moveToIndex(r, bestJ, r.index)
    r.world = nil
    r.rev = (r.rev or 0) + 1
    if r.current then removeUID(r.current) end
    r.current = nil
    showCurrent(r)
    r.rerouteOnArrival = true
    self:Print(("Nearest: %s is filled, %d yd away: new target (point %d/%d)."):format(
        r.points[r.index].herb, math.floor(bestD + 0.5), r.index, #r.points))
    self:RouteChanged()
    return true
end

function HR:OnWaypointRemoved(uid)
    local r = self.route
    if not r or self.removing then return end

    -- Someone else removed a waypoint (menu, /way reset...).
    -- Several removals in the same frame mean a bulk reset: stop.
    -- A single removal of the current point means "skip it".
    self.extCount = (self.extCount or 0) + 1
    if uid == r.current then
        r.current = nil
        self.extCurrentRemoved = true
    end
    if self.extCount == 1 then
        C_Timer.After(0, function()
            local bulk, hit = self.extCount > 1, self.extCurrentRemoved
            self.extCount, self.extCurrentRemoved = 0, false
            if self.route ~= r or not hit then return end
            if bulk then
                self:StopRoute()
            else
                self:Advance(true)
            end
        end)
    end
end

function HR:StopRoute(silent, keepTracking)
    local r = self.route
    if not r then
        if not keepTracking then self:RestoreTracking() end
        if not silent then self:Print("No active route.") end
        return
    end
    self.route = nil
    removeUID(r.current)
    if not keepTracking then self:RestoreTracking() end
    if not silent then self:Print("Route stopped.") end
    self:RouteChanged()
end

function HR:StartRoute(region, mapID, points, start, length, category)
    self:StopRoute(true, true)
    local r = {
        region = region,
        category = category or "herbs",
        mapID = mapID,
        points = points,
        start = start,
        length = length,
        index = 1,
        mode = "follow",
        removed = {},
    }
    r.herbSet = {}
    for _, p in ipairs(points) do r.herbSet[p.herb] = true end
    self.route = r
    self:IsolateTracking(r.category)
    showCurrent(r)
    self:StartVerify()
    self:Print(("%s: %d points, map distance %.1f."):format(region, #points, length))
    self:RouteChanged()
end

-- Computes the route (in slices, to keep the client responsive) and starts it.
-- `start` is {x=, y=} in percent; it defaults to the player's position when
-- the player is in the region, else the map center.
function HR:GenerateRoute(region, herbs, start, category)
    category = category or "herbs"
    local mapID = self:GetRegionMapID(region)
    if not mapID then
        return self:Print(region .. " is not resolved to a map. Try /hr debug.")
    end

    local points = {}
    for _, herb in ipairs(herbs) do
        for _, p in ipairs(self:DataFor(category)[region][herb] or {}) do
            points[#points + 1] = {x = p[1], y = p[2], herb = herb}
        end
    end
    if #points == 0 then return self:Print("No point to visit.") end

    if not start then
        local m, x, y = self:GetPlayerPosition()
        if m == mapID then start = {x = x, y = y} else start = {x = 50, y = 50} end
    end

    self.db.region = region
    self.db.category = category
    local saved = category == "ores" and "ores" or "herbs"
    self.db[saved][region] = {}
    for _, herb in ipairs(herbs) do self.db[saved][region][herb] = true end

    self.genToken = (self.genToken or 0) + 1
    local token = self.genToken
    self.generating = true
    self:RouteChanged()

    local co = coroutine.create(function()
        return HR.Math.solve(points, start, coroutine.yield)
    end)
    local function step()
        if token ~= HR.genToken then return end
        local ok, route = coroutine.resume(co)
        if not ok then
            HR.generating = false
            HR:RouteChanged()
            return HR:Print("Error: " .. tostring(route))
        end
        if coroutine.status(co) == "dead" then
            HR.generating = false
            HR:StartRoute(region, mapID, route, start, HR.Math.pathLength(route, start), category)
        else
            C_Timer.After(0, step)
        end
    end
    step()
end
