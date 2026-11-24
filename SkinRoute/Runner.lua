local addonName, SR = ...

local FROM = "SkinRoute"

function SR:InitRunner()
    TomTom.RegisterCallback(self, "WaypointRemoved", function(event, uid)
        SR:OnWaypointRemoved(uid)
    end)
end

local function removeUID(uid)
    if type(uid) ~= "table" then return end
    SR.removing = true
    TomTom:RemoveWaypoint(uid)
    SR.removing = false
end

local function zoneLabel(row)
    return ("zone (%.0f, %.0f)"):format(row.zone.x, row.zone.y)
end

local function announce(row)
    local s = SR.shown
    local index = 0
    for i, r in ipairs(s.rows) do
        if r == row then index = i end
    end
    SR:Print("Go to " .. SR.DescribeRow(index, zoneLabel(row), row, s.ctx, s.anyPrice))
end

local function target(g, row)
    local radius = SR.db.arrival
    local callbacks = TomTom:DefaultCallbacks({cleardistance = 0, arrivaldistance = radius})
    local ping = callbacks.distance[radius]
    callbacks.distance[radius] = function(event, uid, ...)
        if ping then ping(event, uid, ...) end
        if SR.guide == g and uid == g.current then SR:Arrive() end
    end
    g.row = row
    g.visited[row.zone.id] = true
    g.arrived = false
    g.current = TomTom:SetCustomWaypoint(g.mapID, row.zone.x / 100, row.zone.y / 100, {
        title = ("%s %s"):format(g.region, zoneLabel(row)),
        from = FROM,
        silent = true,
        crazy = true,
        cleardistance = 0,
        arrivaldistance = radius,
        callbacks = callbacks,
    })
    announce(row)
    SR:UpdateUI()
end

local function nextRow(g)
    local s = SR.shown
    if not s or s.region ~= g.region then return end
    for _, row in ipairs(s.rows) do
        if not g.visited[row.zone.id] and row.eval.status ~= "locked" then return row end
    end
end

function SR:StartGuide()
    local s = self.shown
    if not s or #s.rows == 0 then
        return self:Say("No zone to go to: /sr zones first, or change the items, level, skill or band.")
    end
    local first
    for _, row in ipairs(s.rows) do
        if row.eval.status ~= "locked" then first = row break end
    end
    if not first then
        local skill = self:PlayerSkill()
        return self:Say(("No zone you can skin%s: every zone needs more skinning."):format(skill and (" with skinning " .. skill) or ""))
    end
    self:StopGuide(true)
    local g = {region = s.region, mapID = s.mapID, visited = {}}
    self.guide = g
    self:StatsStart()
    target(g, first)
end

function SR:Arrive()
    local g = self.guide
    if not g or g.arrived then return end
    g.arrived = true
    removeUID(g.current)
    g.current = nil
    self:Print(("Arrived at the %s. /sr skip for the next zone, /sr stop to end."):format(zoneLabel(g.row)))
    self:UpdateUI()
end

function SR:SkipZone()
    local g = self.guide
    if not g then return self:Print("No active guide. /sr go") end
    removeUID(g.current)
    g.current = nil
    local row = nextRow(g)
    if not row then
        self:Print("No more zone to go to.")
        self.guide = nil
        self:StatsStop()
        self:UpdateUI()
        return
    end
    target(g, row)
end

function SR:StopGuide(silent)
    local g = self.guide
    if not g then
        if not silent then self:Print("No active guide.") end
        return
    end
    self.guide = nil
    removeUID(g.current)
    self:StatsStop()
    if not silent then self:Print("Guide stopped.") end
    self:UpdateUI()
end

function SR:OnWaypointRemoved(uid)
    local g = self.guide
    if not g or self.removing then return end

    self.extCount = (self.extCount or 0) + 1
    if uid == g.current then
        g.current = nil
        self.extCurrentRemoved = true
    end
    if self.extCount == 1 then
        C_Timer.After(0, function()
            local bulk, hit = self.extCount > 1, self.extCurrentRemoved
            self.extCount, self.extCurrentRemoved = 0, false
            if self.guide ~= g or not hit then return end
            if bulk then
                self:StopGuide()
            else
                self:SkipZone()
            end
        end)
    end
end
