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

-- All mode: every point is a pin, TomTom clears each one on arrival.
local function showAll(r)
    local radius = HR.db.radius
    r.uids, r.idxOf, r.done = {}, {}, {}
    for i = 1, #r.points do
        local uid = addPoint(r, i, {
            crazy = i == 1,
            cleardistance = radius,
            arrivaldistance = radius,
        })
        r.uids[i] = uid
        r.idxOf[uid] = i
    end
end

local function finish(self)
    self:Print("Route finished.")
    self:StopRoute(true)
end

function HR:Advance()
    local r = self.route
    if not r or r.mode ~= "follow" then return end
    if r.current then removeUID(r.current) end
    r.current = nil
    r.index = r.index + 1
    while r.removed[r.index] do r.index = r.index + 1 end
    if r.index > #r.points then return finish(self) end
    showCurrent(r)
    self:RouteChanged()
end

local function pointArrowAll(r)
    for i = r.index, #r.points do
        if not r.done[i] then
            r.index = i
            TomTom:SetCrazyArrow(r.uids[i], HR.db.radius, title(r, i))
            return true
        end
    end
end

function HR:SkipPoint()
    local r = self.route
    if not r then return self:Print("No active route.") end
    if r.mode == "follow" then
        self:Advance()
    else
        r.done[r.index] = true
        removeUID(r.uids[r.index])
        if not pointArrowAll(r) then return finish(self) end
        self:RouteChanged()
    end
end

local VISITED_TOL = 1.0
local VISITED_CAP = 3000

-- Points the player really harvested (validated by the loot message, see Harvest.lua) are
-- remembered, apart from the data files, so that a new route does not bring them back for a while.
function HR:RememberVisited(region, x, y)
    self.db.visited = self.db.visited or {}
    local list = self.db.visited[region]
    if not list then list = {} self.db.visited[region] = list end
    list[#list + 1] = {x = x, y = y, t = time()}
    while #list > VISITED_CAP do table.remove(list, 1) end
end

function HR:FilterVisited(region, points)
    local list = self.db.visited and self.db.visited[region]
    if not list or #list == 0 then return points, 0 end
    local minutes = self.db.visitedMinutes
    if minutes == nil then minutes = 60 end
    local limit = minutes > 0 and time() - minutes * 60 or nil
    local fresh, grid = {}, {}
    for _, v in ipairs(list) do
        if not limit or v.t >= limit then
            fresh[#fresh + 1] = v
            local key = math.floor(v.x / VISITED_TOL) * 1000 + math.floor(v.y / VISITED_TOL)
            grid[key] = grid[key] or {}
            grid[key][#grid[key] + 1] = v
        end
    end
    self.db.visited[region] = fresh
    local kept, skipped = {}, 0
    local r2 = (VISITED_TOL + 1e-9) ^ 2
    for _, p in ipairs(points) do
        local kx, ky = math.floor(p.x / VISITED_TOL), math.floor(p.y / VISITED_TOL)
        local seen = false
        for dx = -1, 1 do
            for dy = -1, 1 do
                for _, v in ipairs(grid[(kx + dx) * 1000 + (ky + dy)] or {}) do
                    local ex, ey = p.x - v.x, p.y - v.y
                    if ex * ex + ey * ey <= r2 then seen = true break end
                end
                if seen then break end
            end
            if seen then break end
        end
        if seen then skipped = skipped + 1 else kept[#kept + 1] = p end
    end
    return kept, skipped
end

-- Inserts a new point where it lengthens the remaining route the least. The current point
-- stays where it is; state kept by point index (removed, verification) is shifted.
function HR:InsertPoint(r, p)
    local order = {}
    for i = r.index, #r.points do
        if not r.removed[i] then order[#order + 1] = i end
    end
    local bestPos, bestCost
    for k = 1, #order do
        local a = r.points[order[k]]
        local b = order[k + 1] and r.points[order[k + 1]]
        local cost = HR.Math.distance(a, p) + (b and (HR.Math.distance(p, b) - HR.Math.distance(a, b)) or 0)
        if not bestCost or cost < bestCost then
            bestCost = cost
            bestPos = (order[k + 1] or (#r.points + 1))
        end
    end
    bestPos = bestPos or (#r.points + 1)
    table.insert(r.points, bestPos, p)
    local removed = {}
    for k, v in pairs(r.removed) do removed[k >= bestPos and k + 1 or k] = v end
    r.removed = removed
    if r.vstate then
        local vstate = {}
        for k, v in pairs(r.vstate) do vstate[k >= bestPos and k + 1 or k] = v end
        r.vstate = vstate
    end
    r.world = nil
    r.rev = (r.rev or 0) + 1
    return bestPos
end

-- Adds a node the player found: stored in HerbRouteDB.discovered (never in the data files)
-- and inserted into the running route. Returns false when it is already known.
function HR:StoreNode(category, region, x, y, item)
    self.db.discovered = self.db.discovered or {}
    local byRegion = self.db.discovered[category] or {}
    self.db.discovered[category] = byRegion
    local list = byRegion[region] or {}
    byRegion[region] = list
    for _, d in ipairs(list) do
        if (d.x - x) ^ 2 + (d.y - y) ^ 2 <= 0.5 ^ 2 then return false end
    end
    list[#list + 1] = {x = x, y = y, item = item, t = time()}
    self.dataRev = (self.dataRev or 0) + 1
    return true
end

function HR:AddNode(r, x, y, item)
    if not self:StoreNode(r.category or "herbs", r.region, x, y, item) then return false end
    local pos = self:InsertPoint(r, {x = x, y = y, herb = item or HR.SEEN_ITEM, new = true})
    if r.vstate then r.vstate[pos] = {misses = 0, none = 0, nextAt = 0, confirmed = true} end
    self:ScheduleReroute()
    self:RouteChanged()
    return true
end

function HR:AddHere(arg)
    local r = self.route
    if not r or r.mode ~= "follow" then return self:Print("Start a route in follow mode first.") end
    local m, x, y = self:GetPlayerPosition()
    if not m or m ~= r.mapID then return self:Print("Your position is not on the route's map.") end
    x, y = math.floor(x * 10 + 0.5) / 10, math.floor(y * 10 + 0.5) / 10
    local item = HR.SEEN_ITEM
    arg = (arg or ""):match("^%s*(.-)%s*$")
    if arg ~= "" then
        local wanted = HR.normalize(arg)
        for _, name in ipairs(self:GetHerbs(r.region, r.category)) do
            if HR.normalize(name) == wanted then item = name break end
        end
        if item == HR.SEEN_ITEM then
            for _, name in ipairs(self:GetHerbs(r.region, r.category)) do
                if HR.normalize(name):find(wanted, 1, true) then item = name break end
            end
        end
    end
    if self:AddNode(r, x, y, item) then
        self:Print(("Added a node at %.1f, %.1f (%s)."):format(x, y, item))
    else
        self:Print("A node was already added there.")
    end
end

local REROUTE_DELAY = 1.5

-- Reorders the route from the player's real position (nearest neighbour then 2-opt, as for a
-- new route). The current point is reordered with the points ahead, so the next target can
-- change; when the player's position is not on the route's map, the current point is the
-- start and stays the target. The database is never touched; the verification state of each
-- point follows it to its new place.
function HR:Reroute()
    local r = self.route
    if not r or r.mode ~= "follow" or self.rerouting then return end
    local index, rev = r.index, r.rev or 0
    local cur = r.points[index]
    local m, px, py = self:GetPlayerPosition()
    local fromPlayer = m ~= nil and m == r.mapID
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
    r.removed[i] = true
    r.rev = (r.rev or 0) + 1
    r.removedCount = (r.removedCount or 0) + 1
    self:ScheduleReroute()
    if r.mode == "follow" then
        if i == r.index then self:Advance() end
    else
        r.done[i] = true
        removeUID(r.uids[i])
    end
    self:RouteChanged()
end

function HR:OnWaypointRemoved(uid)
    local r = self.route
    if not r or self.removing then return end

    if r.mode == "follow" then
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
                    self:Advance()
                end
            end)
        end
    else
        local i = r.idxOf[uid]
        if not i then return end
        r.done[i] = true
        C_Timer.After(0, function()
            if self.route ~= r then return end
            if not pointArrowAll(r) then return finish(self) end
            self:RouteChanged()
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
    if r.mode == "follow" then
        removeUID(r.current)
    else
        for i, uid in ipairs(r.uids) do
            if not r.done[i] then removeUID(uid) end
        end
    end
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
        mode = self.db.mode,
        removed = {},
    }
    self.route = r
    self:IsolateTracking(r.category)
    if r.mode == "follow" then showCurrent(r) else showAll(r) end
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
    if self.db.skipVisited == true then
        local skipped
        points, skipped = self:FilterVisited(region, points)
        if skipped > 0 then
            self:Print(("%d point(s) skipped: already visited recently (/hr visited)."):format(skipped))
        end
        if #points == 0 then return self:Print("Every point was visited recently: /hr visited clear to start again.") end
    end

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
