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

local MM = HR.MM
local rest = {}
local probing = false

local function hbdLib()
    return LibStub and LibStub("HereBeDragons-2.0", true)
end

-- The cursor must rest, and after steering with a mouse button it must move
-- once before the minimap hover is refreshed again.
local function updateRest()
    if not GetCursorPosition then return end
    local x, y = GetCursorPosition()
    if MM.buttonDown() then
        rest.needMove, rest.ax, rest.ay = true, nil, nil
        rest.x, rest.y, rest.since = x, y, nil
        return
    end
    if rest.needMove then
        if rest.ax == nil then rest.ax, rest.ay = x, y end
        if math.abs(x - rest.ax) > 2 or math.abs(y - rest.ay) > 2 then
            rest.needMove = false
            rest.x, rest.y, rest.since = x, y, GetTime()
        end
        return
    end
    if rest.x == nil or math.abs(x - rest.x) > 2 or math.abs(y - rest.y) > 2 then
        rest.x, rest.y, rest.since = x, y, GetTime()
    end
end

-- Why a probe cannot run right now, or nil.
local function blocked(ignoreRest)
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
    if not ignoreRest then
        if rest.needMove then return "move the mouse once after steering with it" end
        if rest.since == nil or GetTime() - rest.since < REST then return "the cursor is moving" end
    end
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

-- One probe. done(result, cause): "line" (a node is there), "empty" (the
-- minimap is under the cursor and shows nothing) or "none" (inconclusive, with
-- the cause). `detail`, when given, receives what was measured.
local function probe(ox, oy, done, detail)
    probing = true
    local pts = MM.savePoints()
    local sx, sy = GetCursorPosition()
    local es = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    local hx, hy = (sx / es - ox) - cx, (sy / es - oy) - cy
    if detail then detail.sx, detail.sy, detail.hx, detail.hy, detail.cx, detail.cy = sx, sy, hx, hy, cx, cy end
    local finished = false
    local function finish(result, cause)
        if finished then return end
        finished = true
        pcall(MM.placeMinimap, pts, 0, 0)
        MM.waitFrames(2, function()
            if detail then
                local ax, ay = Minimap:GetCenter()
                detail.homeOk = ax ~= nil and math.abs(ax - cx) < 1 and math.abs(ay - cy) < 1
            end
            probing = false
            done(result, cause)
        end)
    end
    if hx ~= hx or hy ~= hy or math.abs(hx) > 3000 or math.abs(hy) > 3000 then
        return finish("none", "the shift is out of range")
    end
    C_Timer.After(1, function() finish("none", "timeout") end)
    if not pcall(MM.placeMinimap, pts, hx, hy) then return finish("none", "the minimap could not be moved") end

    local function read(second)
        if finished then return end
        local x, y = GetCursorPosition()
        if math.abs(x - sx) > 3 or math.abs(y - sy) > 3 then return finish("none", "the mouse moved") end
        if InCombatLockdown and InCombatLockdown() then return finish("none", "combat") end
        local ncx, ncy = Minimap:GetCenter()
        local applied = ncx ~= nil and math.abs(ncx - (cx + hx)) < 2 and math.abs(ncy - (cy + hy)) < 2
        local has, sig, anyData = MM.reading()
        if detail then
            detail[second and "read2" or "read1"] = {
                has = has, sig = sig, anyData = anyData, applied = applied, inside = MM.cursorInside(),
            }
        end
        if not applied then return finish("none", "the minimap did not move (another addon or the client re-anchored it)") end
        if has then return finish("line") end
        if anyData then return finish("empty") end
        if not second then
            return C_Timer.After(0, function() read(true) end)
        end
        finish("none", "no hover data: the hover was not refreshed (after steering, move the mouse once)")
    end
    C_Timer.After(0, function() read(false) end)
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
    probe(g.ox, g.oy, function(result, cause)
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
            r.vstats.none = r.vstats.none + 1
            r.vstats.causes[cause] = (r.vstats.causes[cause] or 0) + 1
            HR.lastCause = cause
            st.nextAt = GetTime() + math.min(10, 1 + st.none * 1.5)
            if st.none == 3 then
                HR:Print(("Verify: point %d/%d is inconclusive (%s); retrying when conditions allow. /hr verify probe gives details."):format(
                    i, #r.points, cause))
            end
        end
        HR:RouteChanged()
    end)
end

function HR:StartVerify()
    local r = self.route
    if not r then return end
    for k in pairs(rest) do rest[k] = nil end
    r.vstate = {}
    r.vstats = {probes = 0, confirmed = 0, empty = 0, none = 0, causes = {}}
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
        line = line .. (", this route: %d probe(s), %d confirmed, %d empty, %d inconclusive, %d removed"):format(
            r.vstats.probes, r.vstats.confirmed, r.vstats.empty, r.vstats.none, r.removedCount or 0)
    end
    if r and self.verifyReason and self.db.verify ~= "off" then line = line .. ". " .. self.verifyReason end
    self:Print(line)
    if r and r.vstats then
        for cause, n in pairs(r.vstats.causes) do self:Print(("  inconclusive x%d: %s"):format(n, cause)) end
    end
end

-- /hr verify probe: one probe on the current point, with everything measured.
function HR:VerifyProbeNow()
    local r = self.route
    if not r or r.mode ~= "follow" then return self:Print("Start a route in follow mode first.") end
    self:Print("Verify probe in 3 s: rest the mouse in the world, away from any window.")
    C_Timer.After(3, function()
        if HR.route ~= r or probing then return end
        local i = r.index
        local g = geometry(r, i)
        if not g then return HR:Print("Verify probe: no position data (HereBeDragons or the route overlay is missing).") end
        HR:Print(("Verify probe: point %d/%d (%s), %.0f yd away, projected offset (%.0f, %.0f) units, %s the probe disc."):format(
            i, #r.points, r.points[i].herb, g.dist, g.ox, g.oy, g.inside and "inside" or "outside"))
        local why = blocked(true)
        if why then return HR:Print("Verify probe: not run: " .. why .. ".") end
        local d = {}
        probe(g.ox, g.oy, function(result, cause)
            HR:Print(("  cursor (%.0f, %.0f) px, minimap center (%.1f, %.1f), shift (%.1f, %.1f)"):format(
                d.sx or 0, d.sy or 0, d.cx or 0, d.cy or 0, d.hx or 0, d.hy or 0))
            for _, key in ipairs({"read1", "read2"}) do
                local rd = d[key]
                if rd then
                    HR:Print(("  %s: moved=%s, cursor on minimap=%s, lines=%s, data=%s, %s"):format(
                        key == "read1" and "+1 frame" or "+2 frames", tostring(rd.applied), tostring(rd.inside),
                        tostring(rd.has), tostring(rd.anyData), tostring(rd.sig)))
                end
            end
            HR:Print(("  result: %s%s; minimap back home: %s"):format(result, cause and (" (" .. cause .. ")") or "", tostring(d.homeOk)))
        end, d)
    end)
end
