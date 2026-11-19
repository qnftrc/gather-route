local addonName, HR = ...

-- Verification of the next waypoint on the minimap (follow mode). When the
-- cursor rests in the world, the minimap is moved for one frame so that the
-- projected position of the point lies under the cursor; at least one tooltip
-- line there means a node is present. A point with no line twice in a row is
-- removed from the route (the herb database is never touched).
HR.verifyHits = 0

local ENTER = 0.85  -- fraction of the view radius inside which a point is probed
local NEAR = 35     -- yards: last check of a confirmed point before arrival
local REST = 0.5    -- seconds the cursor must stay still
local TICK = 0.25
local RETRY = 1.5   -- delay before a second probe of the same point
local MISSES = 2    -- empty probes in a row needed to call a point absent
local MAX_NONE = 4  -- inconclusive probes before giving up on a point

local MM = HR.MM
local rest = {}
local probing = false

local function hbdLib()
    return LibStub and LibStub("HereBeDragons-2.0", true)
end

local function updateRest()
    if not GetCursorPosition then return end
    local x, y = GetCursorPosition()
    if rest.x == nil or math.abs(x - rest.x) > 2 or math.abs(y - rest.y) > 2 then
        rest.x, rest.y, rest.since = x, y, GetTime()
    end
end

-- Why a probe cannot run right now, or nil.
local function blocked()
    if HR:HerbTrackingActive() ~= true then return "Find Herbs tracking is not active" end
    if InCombatLockdown and InCombatLockdown() then return "combat" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "dead" end
    if UnitOnTaxi and UnitOnTaxi("player") then return "flight" end
    if MM.buttonDown() then return "mouse button held" end
    if (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player")) then
        return "casting"
    end
    if not Minimap:IsVisible() then return "minimap hidden" end
    if MM.cursorInside() ~= false then return "the cursor is on the minimap" end
    if not MM.mouseOverWorld() then return "the mouse is over the interface" end
    if UnitExists and UnitExists("mouseover") then return "a unit is under the cursor" end
    if GameTooltip and GameTooltip:IsShown() then return "a tooltip is open" end
    if LootFrame and LootFrame:IsShown() then return "loot window open" end
    if rest.since == nil or GetTime() - rest.since < REST then return "the cursor is moving" end
    return nil
end

-- Distance to the point and its offset on the minimap (units, y up), same
-- projection as the route overlay.
local function geometry(r, i)
    local hbd = hbdLib()
    if not hbd or not HR.ComputeRouteWorld or not HR.ViewRadius then return end
    if not r.world then HR.ComputeRouteWorld(r) end
    local px, py, instance = hbd:GetPlayerWorldPosition()
    if not px or not r.world or instance ~= r.world.instance then return end
    local radius = HR.ViewRadius()
    if not radius then return end
    local dx, dy = px - r.world.x[i], py - r.world.y[i]
    local rx, ry = dx, dy
    if GetCVar("rotateMinimap") == "1" then
        local facing = GetPlayerFacing and GetPlayerFacing()
        if not facing then return end
        local s, c = math.sin(facing), math.cos(facing)
        rx, ry = dx * c - dy * s, dx * s + dy * c
    end
    local fx, fy = rx / radius, ry / radius
    local halfW, halfH = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    return {
        dist = math.sqrt(dx * dx + dy * dy),
        inside = fx * fx + fy * fy <= ENTER * ENTER,
        ox = fx * halfW,
        oy = -fy * halfH,
    }
end

-- One probe: "line" (a node is there), "empty" (the minimap is under the
-- cursor and shows nothing) or "none" (inconclusive).
local function probe(ox, oy, done)
    probing = true
    local pts = MM.savePoints()
    local sx, sy = GetCursorPosition()
    local es = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    local hx, hy = (sx / es - ox) - cx, (sy / es - oy) - cy
    local finished = false
    local function finish(result)
        if finished then return end
        finished = true
        pcall(MM.placeMinimap, pts, 0, 0)
        MM.waitFrames(2, function()
            probing = false
            done(result)
        end)
    end
    if math.abs(hx) > 3000 or math.abs(hy) > 3000 then return finish("none") end
    C_Timer.After(1, function() finish("none") end)
    if not pcall(MM.placeMinimap, pts, hx, hy) then return finish("none") end
    C_Timer.After(0, function()
        if finished then return end
        local x, y = GetCursorPosition()
        local moved = math.abs(x - sx) > 3 or math.abs(y - sy) > 3
        local has, _, anyData = MM.reading()
        local result = "none"
        if not moved and not (InCombatLockdown and InCombatLockdown()) then
            if has then result = "line" elseif anyData then result = "empty" end
        end
        finish(result)
    end)
end

local function decideAbsent(r, i, st)
    local p = r.points[i]
    local label = ("point %d/%d (%s)"):format(i, #r.points, p.herb)
    st.final = true
    r.vstats.empty = r.vstats.empty + 1
    if HR.verifyHits == 0 then
        HR:Print(("Verify: %s shows nothing, but no blip has been confirmed yet: kept."):format(label))
    elseif HR.db.verify == "remove" then
        HR:Print(("Verify: %s has no node: removed."):format(label))
        HR:DropPoint(i)
    else
        HR:Print(("Verify: %s has no node (report mode, kept; /hr verify remove to remove)."):format(label))
    end
end

local function step(r)
    local i = r.index
    local st = r.vstate[i]
    if not st then
        st = {misses = 0, none = 0, nextAt = 0}
        r.vstate[i] = st
    end
    if st.final or GetTime() < st.nextAt then return end

    local g = geometry(r, i)
    if not g then
        HR.verifyReason = "no position data"
        return
    end
    if not st.confirmed then
        if not g.inside then
            HR.verifyReason = "the next point is outside the minimap"
            return
        end
    elseif st.nearDone or g.dist > NEAR then
        HR.verifyReason = "confirmed, waiting for the last check"
        return
    end

    local why = blocked()
    if why then
        HR.verifyReason = "waiting: " .. why
        return
    end
    HR.verifyReason = "probing"
    probe(g.ox, g.oy, function(result)
        if HR.route ~= r or r.index ~= i then return end
        r.vstats.probes = r.vstats.probes + 1
        if result == "line" then
            HR.verifyHits = HR.verifyHits + 1
            st.misses = 0
            if st.confirmed then
                st.nearDone = true
            else
                st.confirmed = true
                r.vstats.confirmed = r.vstats.confirmed + 1
            end
        elseif result == "empty" then
            st.misses = st.misses + 1
            if st.misses >= MISSES then decideAbsent(r, i, st) else st.nextAt = GetTime() + RETRY end
        else
            st.none = st.none + 1
            if st.none >= MAX_NONE then st.final = true else st.nextAt = GetTime() + 1 end
        end
        HR:RouteChanged()
    end)
end

function HR:StartVerify()
    local r = self.route
    if not r then return end
    r.vstate = {}
    r.vstats = {probes = 0, confirmed = 0, empty = 0}
    local function tick()
        if HR.route ~= r then return end
        updateRest()
        if r.mode == "follow" and HR.db.verify ~= "off" and not probing then step(r) end
        C_Timer.After(TICK, tick)
    end
    tick()
end

function HR:VerifyStatus()
    local r = self.route
    local line = ("Verify: %s (%d blip(s) confirmed this session)"):format(self.db.verify, self.verifyHits)
    if r and r.vstats then
        line = line .. (", this route: %d probe(s), %d confirmed, %d empty, %d removed"):format(
            r.vstats.probes, r.vstats.confirmed, r.vstats.empty, r.removedCount or 0)
    end
    if r and self.verifyReason and self.db.verify ~= "off" then line = line .. ". " .. self.verifyReason end
    self:Print(line)
end
