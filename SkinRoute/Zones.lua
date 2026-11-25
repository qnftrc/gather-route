local addonName, SR = ...

local Z = {}
SR.Zones = Z

local floor, ceil = math.floor, math.ceil

local function cellKey(cx, cy)
    return (cx + 32768) * 65536 + (cy + 32768)
end

function Z.compute(points, radius, minCount, maxZones, tick)
    local cell = radius / 2
    local reach = ceil(radius / cell)
    local r2 = radius * radius
    local cells, order = {}, {}
    for i, p in ipairs(points) do
        local cx, cy = floor(p.wx / cell), floor(p.wy / cell)
        local key = cellKey(cx, cy)
        local c = cells[key]
        if not c then
            c = {cx = cx, cy = cy, list = {}}
            cells[key] = c
            order[#order + 1] = c
        end
        c.list[#c.list + 1] = i
    end

    local covered = {}
    local ops, total, slices = 0, 0, 0
    local function breathe()
        if tick and ops >= 3000 then
            ops = 0
            slices = slices + 1
            tick()
        end
    end

    local function inside(x, y, visit)
        local cx, cy = floor(x / cell), floor(y / cell)
        for dx = -reach, reach do
            for dy = -reach, reach do
                local c = cells[cellKey(cx + dx, cy + dy)]
                if c then
                    local list = c.list
                    for k = 1, #list do
                        local i = list[k]
                        if not covered[i] then
                            ops, total = ops + 1, total + 1
                            local ex, ey = points[i].wx - x, points[i].wy - y
                            if ex * ex + ey * ey <= r2 then visit(i) end
                        end
                    end
                end
            end
        end
    end

    local zones = {}
    local left = #points
    for _ = 1, maxZones do
        if left < minCount then break end
        local bestCount, bx, by = 0, nil, nil
        for _, c in ipairs(order) do
            local sx, sy, m = 0, 0, 0
            for k = 1, #c.list do
                local i = c.list[k]
                if not covered[i] then
                    sx, sy, m = sx + points[i].wx, sy + points[i].wy, m + 1
                end
            end
            if m > 0 then
                local mx, my = sx / m, sy / m
                local count = 0
                inside(mx, my, function() count = count + 1 end)
                if count > bestCount then bestCount, bx, by = count, mx, my end
            end
            breathe()
        end
        if bestCount < minCount then break end

        local members, sx, sy = {}, 0, 0
        inside(bx, by, function(i)
            members[#members + 1] = i
            sx, sy = sx + points[i].wx, sy + points[i].wy
        end)
        local cx, cy = sx / #members, sy / #members
        local refined, rx, ry = {}, 0, 0
        inside(cx, cy, function(i)
            refined[#refined + 1] = i
            rx, ry = rx + points[i].wx, ry + points[i].wy
        end)
        if #refined > 0 then members, cx, cy = refined, rx / #refined, ry / #refined end

        local px, py, counts = 0, 0, {}
        for _, i in ipairs(members) do
            covered[i] = true
            px, py = px + points[i].x, py + points[i].y
            counts[points[i].cid] = (counts[points[i].cid] or 0) + 1
        end
        left = left - #members
        local entries = {}
        for cid, n in pairs(counts) do entries[#entries + 1] = {id = cid, n = n} end
        table.sort(entries, function(a, b) return a.id < b.id end)
        zones[#zones + 1] = {id = #zones + 1, wx = cx, wy = cy, x = px / #members, y = py / #members, n = #members, entries = entries}
    end
    Z.lastOps, Z.lastSlices = total, slices
    return zones, left
end

function SR:ComputeZones(region, done, quiet)
    local function fail(message)
        if not quiet then self:Say(message) end
        if quiet then done(nil) end
    end
    local hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    if not hbd then
        return fail("HereBeDragons-2.0 not found (it ships with TomTom): zones cannot be computed.")
    end
    local mapID = self:GetRegionMapID(region)
    if not mapID then
        return fail(SR.RegionLabel(region) .. " is not resolved to a map. Try /sr debug.")
    end
    local radius, minCount, maxZones = self.db.zoneRadius, self.db.zoneMin, self.db.zoneMax
    local elites = self.db.elites == true
    local key = self:ZonesKey(region)
    self.zoneSets = self.zoneSets or {}
    if self.zoneSets[key] then return done(self.zoneSets[key]) end

    local x0, y0 = hbd:GetWorldCoordinatesFromZone(0, 0, mapID)
    local x1, y1 = hbd:GetWorldCoordinatesFromZone(1, 1, mapID)
    if not (x0 and x1) then
        return fail(("The world position of %s is unknown (map %s)."):format(SR.RegionLabel(region), tostring(mapID)))
    end
    local size = {w = math.abs(x1 - x0), h = math.abs(y1 - y0)}

    local cids = {}
    for cid in pairs(self.Data.zones[region] or {}) do cids[#cids + 1] = cid end
    table.sort(cids)
    local points = {}
    for _, cid in ipairs(cids) do
        local flat = self.Data.zones[region][cid]
        local creature = self.Data.creatures[cid]
        if creature and creature.e and not elites then flat = {} end
        for i = 1, #flat - 1, 2 do
            local wx, wy = hbd:GetWorldCoordinatesFromZone(flat[i] / 100, flat[i + 1] / 100, mapID)
            if wx then points[#points + 1] = {wx = wx, wy = wy, x = flat[i], y = flat[i + 1], cid = cid} end
        end
    end
    if #points == 0 then return fail("No point in " .. SR.RegionLabel(region) .. ".") end

    local co = coroutine.create(function()
        return Z.compute(points, radius, minCount, maxZones, coroutine.yield)
    end)
    if not quiet then
        self.computing = true
        self:UpdateUI()
    end
    local function step()
        local ok, zones, left = coroutine.resume(co)
        if not ok then
            if not quiet then
                SR.computing = false
                SR:UpdateUI()
            end
            if quiet then return done(nil) end
            return SR:Say("Error: " .. tostring(zones))
        end
        if coroutine.status(co) == "dead" then
            if not quiet then SR.computing = false end
            local set = {region = region, mapID = mapID, radius = radius, size = size, zones = zones, leftover = left, points = #points}
            SR.zoneSets[key] = set
            done(set)
        else
            C_Timer.After(0, step)
        end
    end
    step()
end

function SR:RefreshZones()
    local s = self.shown
    if s then
        s.ctx = self:Context()
        s.rows, s.hidden, s.anyPrice = self:RankZones(s.set, s.ctx)
        s.best = self:PickBest(s)
        self:UpdateOverlay()
    end
    self:UpdateUI()
    self:RefreshUI()
end

function SR:ShowZones(region, go)
    if self.db.browse ~= "profit" and #self.db.items == 0 then
        return self:Say("Select items first: /sr items <name>[, <name>]")
    end
    self.zoneToken = (self.zoneToken or 0) + 1
    local token = self.zoneToken
    self:ComputeZones(region, function(set)
        if token ~= SR.zoneToken then return end
        SR.shown = {region = region, mapID = set.mapID, set = set}
        SR:RefreshZones()
        SR:ReportZones()
        if go then SR:StartGuide() end
    end)
end

function SR:EnsureAllZones()
    if self.zoneProgress and self.zoneProgress.running then return end
    local queue = {}
    self.zoneFailed = self.zoneFailed or {}
    for _, region in ipairs(self:GetRegions()) do
        local key = self:ZonesKey(region)
        if not (self.zoneSets and self.zoneSets[key]) and not self.zoneFailed[key] then queue[#queue + 1] = region end
    end
    if #queue == 0 then return end
    local progress = {done = 0, total = #queue, running = true}
    self.zoneProgress = progress
    self.zoneSets = self.zoneSets or {}
    local function nextRegion()
        local region = table.remove(queue, 1)
        if not region then
            progress.running = false
            self:RefreshUI()
            self:EnsureAllZones()
            return
        end
        self:ComputeZones(region, function(set)
            if not set then self.zoneFailed[self:ZonesKey(region)] = true end
            progress.done = progress.done + 1
            if progress.done % 8 == 0 then self:RefreshUI() end
            nextRegion()
        end, true)
    end
    nextRegion()
end

function SR:ElitesChanged()
    self.itemTotals = nil
    if self.shown then
        self:ShowZones(self.shown.region)
    else
        self:RefreshZones()
    end
end

function SR:ClearZones()
    self.zoneToken = (self.zoneToken or 0) + 1
    self.shown = nil
    self:UpdateOverlay()
    self:UpdateUI()
end
