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

-- Drops a point from the running route (never from the database).
function HR:DropPoint(i)
    local r = self.route
    if not r or r.removed[i] then return end
    r.removed[i] = true
    r.removedCount = (r.removedCount or 0) + 1
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
        for _, p in ipairs(self.categories[category].data[region][herb] or {}) do
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
