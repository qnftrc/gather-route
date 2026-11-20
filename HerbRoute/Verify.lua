local addonName, HR = ...

-- Verification of the next waypoint on the minimap (follow mode). When the
-- cursor rests in the world, the minimap is moved for a few frames so that the
-- projected position of the point lies under the cursor; at least one tooltip
-- line there means a node is present. A point with no line is
-- removed from the route (the herb database is never touched).
--
-- How to make the client refresh the minimap hover after the minimap moved
-- differs between builds, so /hr verify calibrate tries several methods on a
-- yellow dot the player points at, and stores the one that detects it.
HR.verifyHits = 0

local ENTER = 0.85  -- fraction of the view radius inside which a point is probed
local NEAR = 35     -- yards: last check of a confirmed point before arrival
HR.RECHECK_YD = 110 -- yards: one recheck of a point confirmed from farther away
HR.RESCAN_YD = 60   -- yards travelled between two probes of a point that may have respawned
local function rescanDist() return HR.RESCAN_YD or 60 end
local REST = 0.5    -- seconds the cursor must stay still
local TICK = 0.25
local RETRY = 1.5   -- delay before a second probe of the same point
local MISSES = 1    -- empty probes needed to call a point absent

local MM = HR.MM
local rest = {}
local probing = false

-- Probe methods, simplest first. warmup: a no-op placement and a pause before
-- the real shift; alpha: SetAlpha after each placement; update: also call
-- UpdateMouseoverAtPoint at the real cursor; soft: soft cursor on; frames: how
-- many frames to wait for data.
local VARIANTS = {
    {name = "plain", opts = {}},
    {name = "warmup", opts = {warmup = true}},
    {name = "alpha", opts = {alpha = true}},
    {name = "warmup + alpha", opts = {warmup = true, alpha = true}},
    {name = "update", opts = {update = true}},
    {name = "soft cursor + update", opts = {soft = true, update = true}},
    {name = "warmup + alpha + wait", opts = {warmup = true, alpha = true, frames = 6}},
}

local function currentBuild()
    return tostring((select(2, GetBuildInfo())))
end

-- Options of the calibrated method, or nil when not calibrated for this build.
local function recipeOpts()
    local name = HR.db.recipe
    if not name or HR.db.recipeBuild ~= currentBuild() then return nil end
    for _, v in ipairs(VARIANTS) do
        if v.name == name then return v.opts end
    end
end

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
local function blocked(ignoreRest, noRecipe)
    local category = (HR.route and HR.route.category) or HR.verifyCategory
    if HR:TrackingActive(category) ~= true then return HR:TrackingName(category) .. " tracking is not active" end
    if not noRecipe and not recipeOpts() then
        return "run /hr verify calibrate once (the probe method is not calibrated for this build)"
    end
    if MM.combatBlocked() then return "combat" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "dead" end
    if UnitOnTaxi and UnitOnTaxi("player") then return "flight" end
    if MM.buttonDown() then return "mouse button held" end
    local gathering = HR.gatheringUntil and GetTime() < HR.gatheringUntil
    if not gathering and ((UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player"))) then
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
local function project(hbd, wx, wy, winstance)
    local px, py, instance = hbd:GetPlayerWorldPosition()
    if not px or instance ~= winstance then return end
    local radius = HR.ViewRadius()
    if not radius then return end
    local dx, dy = px - wx, py - wy
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

local function geometry(r, i)
    local hbd = hbdLib()
    if not hbd or not HR.ComputeRouteWorld or not HR.ViewRadius then return end
    if not r.world then HR.ComputeRouteWorld(r) end
    if not r.world then return end
    return project(hbd, r.world.x[i], r.world.y[i], r.world.instance)
end

-- One probe. done(result, cause): "line" (a node is there), "empty" (the
-- minimap is under the cursor and shows nothing) or "none" (inconclusive, with
-- the cause). `detail`, when given, receives what was measured; `opts` is one
-- of the VARIANTS options.
local function probe(ox, oy, done, detail, opts)
    opts = opts or {}
    local maxFrames = opts.frames or 3
    probing = true
    local pts = MM.savePoints()
    local alpha0 = Minimap:GetAlpha()
    local sx, sy = GetCursorPosition()
    local es = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    local hx, hy = (sx / es - ox) - cx, (sy / es - oy) - cy
    if detail then
        detail.sx, detail.sy, detail.hx, detail.hy, detail.cx, detail.cy = sx, sy, hx, hy, cx, cy
        detail.reads = {}
    end
    -- TomTom's minimap pin of the current waypoint is a mouse-enabled button
    -- sitting on the very spot probed: it would take the mouse focus from the
    -- minimap, so it is hidden while the minimap is moved.
    local hiddenUID
    local route = HR.route
    if route and route.mode == "follow" and route.current and TomTom and TomTom.HideWaypoint then
        hiddenUID = route.current
        pcall(TomTom.HideWaypoint, TomTom, hiddenUID, true, false)
    end
    local iconCause
    local finished, soft = false, false
    local function finish(result, cause)
        if finished then return end
        finished = true
        pcall(MM.placeMinimap, pts, 0, 0)
        if opts.alpha or opts.hidden then pcall(Minimap.SetAlpha, Minimap, alpha0) end
        if soft then pcall(Minimap.SetUsingSoftCursor, Minimap, false) end
        if hiddenUID and TomTom.ShowWaypoint then pcall(TomTom.ShowWaypoint, TomTom, hiddenUID) end
        MM.waitFrames(2, function()
            local ax, ay = Minimap:GetCenter()
            local homeOk = ax ~= nil and math.abs(ax - cx) < 1 and math.abs(ay - cy) < 1
            if detail then detail.homeOk = homeOk end
            if homeOk then
                probing = false
            else
                -- The client refused to put the minimap back (for instance in combat):
                -- keep trying, and no other probe starts before it is home again.
                local tries = 0
                local function retry()
                    tries = tries + 1
                    pcall(MM.placeMinimap, pts, 0, 0)
                    pcall(Minimap.SetAlpha, Minimap, alpha0)
                    local bx, by = Minimap:GetCenter()
                    if (bx ~= nil and math.abs(bx - cx) < 1 and math.abs(by - cy) < 1) or tries >= 60 then
                        probing = false
                    else
                        C_Timer.After(1, retry)
                    end
                end
                C_Timer.After(1, retry)
            end
            done(result, cause)
        end)
    end
    if hx ~= hx or hy ~= hy or math.abs(hx) > 3000 or math.abs(hy) > 3000 then
        return finish("none", "the shift is out of range")
    end
    C_Timer.After(3, function() finish("none", "timeout") end)

    local function read(n)
        if finished then return end
        local x, y = GetCursorPosition()
        if math.abs(x - sx) > 3 or math.abs(y - sy) > 3 then return finish("none", "the mouse moved") end
        if MM.combatBlocked() then return finish("none", "combat") end
        local ncx, ncy = Minimap:GetCenter()
        local applied = ncx ~= nil and math.abs(ncx - (cx + hx)) < 2 and math.abs(ncy - (cy + hy)) < 2
        local has, sig, anyData = MM.reading()
        local focus = MM.mouseFocus()
        local focusName = focus and ((focus.GetName and focus:GetName()) or tostring(focus)) or "none"
        if not anyData and focus and focus ~= Minimap and focus ~= WorldFrame then
            iconCause = ("a minimap icon is under the cursor (%s)"):format(focusName)
        end
        if detail then
            detail.reads[#detail.reads + 1] = {
                frame = n, has = has, sig = sig, anyData = anyData, applied = applied, inside = MM.cursorInside(),
                focus = focusName,
            }
        end
        if not applied then return finish("none", "the minimap did not move (another addon or the client re-anchored it)") end
        if has then return finish("line") end
        if anyData then return finish("empty") end
        if n < maxFrames then
            return C_Timer.After(0, function() read(n + 1) end)
        end
        finish("none", iconCause or "no hover data: the client did not refresh the minimap hover")
    end

    local function start()
        if finished then return end
        if not pcall(MM.placeMinimap, pts, hx, hy) then return finish("none", "the minimap could not be moved") end
        if opts.alpha then pcall(Minimap.SetAlpha, Minimap, alpha0) end
        if opts.hidden then pcall(Minimap.SetAlpha, Minimap, 0) end
        if opts.soft and Minimap.SetUsingSoftCursor then
            soft = pcall(Minimap.SetUsingSoftCursor, Minimap, true)
        end
        if opts.update and Minimap.UpdateMouseoverAtPoint then
            pcall(Minimap.UpdateMouseoverAtPoint, Minimap, sx, sy)
        end
        C_Timer.After(0, function() read(1) end)
    end

    if opts.warmup then
        pcall(MM.placeMinimap, pts, 0, 0)
        if opts.alpha then pcall(Minimap.SetAlpha, Minimap, alpha0) end
        MM.waitFrames(4, start)
    else
        start()
    end
end

HR.PointGeometry = geometry

-- Offset on the minimap (units, y up) and distance of a world point, same projection.
function HR.ProjectWorld(wx, wy, winstance)
    local hbd = hbdLib()
    if not hbd or not HR.ViewRadius then return end
    return project(hbd, wx, wy, winstance)
end

-- Ambiguous positives. The response zone of a blip is a square of about 22
-- units, centred on its point (8 / effective scale units of half-width, or the
-- value measured by /hr probe zone). A positive read at a candidate may come
-- from a neighbouring point of the database (any type of the route's category)
-- whose zone covers the cursor. One probe at a position inside the candidate's
-- zone and outside every neighbour's zone tells which one answers.
local AMB_MARGIN = 2.5  -- units kept on each side for the projection error
local AMB_TRIES = 3
local AMB_RETRY = 3
local AMB_STEP = 0.5

local function zoneHalf()
    local ok, es = pcall(Minimap.GetEffectiveScale, Minimap)
    if not ok or type(es) ~= "number" or es <= 0 then return nil end
    local z = HR.db.zone
    if type(z) == "table" and z.half and z.es and math.abs(z.es - es) <= 0.02 * es then return z.half, "measured" end
    return 8 / es, "formula"
end
HR.ZoneHalf = zoneHalf
HR.AMB_MARGIN = AMB_MARGIN

local function dbWorld(r)
    if r.dbw then return r.dbw end
    local hbd = hbdLib()
    if not hbd then return nil end
    local list = {}
    local data = HR:DataFor(r.category)[r.region]
    if data then
        for _, pts in pairs(data) do
            for _, pt in ipairs(pts) do
                local wx, wy, inst = hbd:GetWorldCoordinatesFromZone(pt[1] / 100, pt[2] / 100, r.mapID)
                if wx then list[#list + 1] = {wx = wx, wy = wy, inst = inst} end
            end
        end
    end
    r.dbw = list
    return list
end

-- Neighbours of a candidate (cg = its geometry): offsets in units relative to
-- the candidate of the points that could answer for it or for a probe near it.
local function neighbours(r, cg)
    local H = zoneHalf()
    local hbd = hbdLib()
    if not H or not hbd or not cg then return nil end
    local list = dbWorld(r)
    if not list then return nil end
    local halfW = Minimap:GetWidth() / 2
    local reach = 2 * H + 1
    local near, ambiguous = {}, false
    for _, d in ipairs(list) do
        local g = project(hbd, d.wx, d.wy, d.inst)
        if g and g.ox * g.ox + g.oy * g.oy <= halfW * halfW then
            local dx, dy = g.ox - cg.ox, g.oy - cg.oy
            local adx, ady = math.abs(dx), math.abs(dy)
            local c = math.max(adx, ady)
            if c >= 0.3 and c <= reach then
                near[#near + 1] = {dx, dy}
                if c <= H + AMB_MARGIN then ambiguous = true end
            end
        end
    end
    return {H = H, near = near, ambiguous = ambiguous}
end

-- A probe position (offset from the candidate, units) inside its zone and
-- outside every neighbour's zone, with the largest margin; nil when none.
local function bestOffset(nb)
    local lim = nb.H - AMB_MARGIN
    if lim <= 0 then return nil end
    local n = math.floor(lim / AMB_STEP)
    local bx, by, bm, br
    for ix = -n, n do
        for iy = -n, n do
            local px, py = ix * AMB_STEP, iy * AMB_STEP
            local m = math.huge
            for _, o in ipairs(nb.near) do
                local c = math.max(math.abs(px - o[1]), math.abs(py - o[2])) - (nb.H + AMB_MARGIN)
                if c < m then m = c end
            end
            if m > 0 then
                local rr = px * px + py * py
                if not bm or m > bm + 1e-6 or (math.abs(m - bm) <= 1e-6 and rr < br) then
                    bx, by, bm, br = px, py, m, rr
                end
            end
        end
    end
    return bx, by
end

-- Called for a positive read: nil when no neighbour is in reach (a clean
-- positive), else the ambiguity record (pending, or unresolved when no probe
-- position exists).
local function markAmbiguity(r, cg)
    if HR.db.ambiguity == false or not cg then return nil end
    local nb = neighbours(r, cg)
    if not nb or not nb.ambiguous then return nil end
    local a = {state = "pending", tries = 0, nextAt = 0}
    r.vstats.amb.marked = r.vstats.amb.marked + 1
    if not bestOffset(nb) then
        a.state = "unresolved"
        r.vstats.amb.unresolved = r.vstats.amb.unresolved + 1
    end
    return a
end

-- A point without a node. In remove mode it leaves the route (and becomes a
-- candidate to come back, see pickRevive); in report mode it stays in the route
-- and is probed again each time the character has travelled RESCAN_YD yards,
-- silently, since it may have respawned.
local function decideAbsent(r, i, st)
    local p = r.points[i]
    local again = st.final or st.wasEmpty
    st.final = true
    st.wasEmpty = true
    if HR.db.verify == "remove" then
        r.vstats.empty = r.vstats.empty + 1
        HR:Print(("Verify: %s has no node: removed."):format(("point %d/%d (%s)"):format(i, #r.points, p.herb)))
        HR:DropPoint(i)
    else
        st.nextOdo = (r.odo or 0) + rescanDist()
        if not again then
            r.vstats.empty = r.vstats.empty + 1
            HR:Print(("Verify: point %d/%d (%s) has no node (report mode, kept; /hr verify remove to remove)."):format(i, #r.points, p.herb))
        end
    end
end

local function step(r)
    local i = r.index
    local st = r.vstate[i]
    if not st then
        st = {misses = 0, none = 0, nextAt = 0}
        r.vstate[i] = st
    end
    if st.final and HR.db.verify ~= "report" then return end
    if st.final and (r.odo or 0) < (st.nextOdo or 0) then return end
    if GetTime() < st.nextAt then return end

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
    elseif st.nearDone then
        HR.verifyReason = "confirmed, waiting for the last check"
        return
    else
        local limit = HR.RECHECK_YD or 110
        local far = not st.farDone and st.confirmDist and st.confirmDist > limit
            and g.dist <= limit and g.inside
        if not far and g.dist > NEAR then
            HR.verifyReason = "confirmed, waiting for the last check"
            return
        end
    end

    local gdist = g.dist
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
            st.final = nil
            if st.confirmed then
                st.farDone = true
                if gdist <= NEAR then st.nearDone = true end
            else
                st.confirmed = true
                st.confirmDist = gdist
                r.vstats.confirmed = r.vstats.confirmed + 1
                st.amb = markAmbiguity(r, geometry(r, i))
                if st.amb and st.amb.state == "pending" then st.amb.want = true end
            end
            HR:RetargetNearest(r)
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
    end, nil, recipeOpts())
end

-- Candidates beyond the current point that are inside the minimap and still
-- undecided: the one nearest to the player is returned (with its geometry);
-- `pending` is true while any such point remains, probed now or waiting.
local function pickAhead(r)
    local bestJ, bestG, pending, againJ, againG
    for j = r.index + 1, #r.points do
        local st = r.vstate[j]
        if not st then
            st = {misses = 0, none = 0, nextAt = 0}
            r.vstate[j] = st
        end
        if not r.removed[j] and not st.confirmed then
            local g = geometry(r, j)
            if g and g.inside then
                if not st.final then pending = true end
                if GetTime() >= st.nextAt and (not st.final or (r.odo or 0) >= (st.nextOdo or 0)) then
                    if st.final then
                        if not againG or g.dist < againG.dist then againJ, againG = j, g end
                    elseif not bestG or g.dist < bestG.dist then
                        bestJ, bestG = j, g
                    end
                end
            end
        end
    end
    return bestJ, bestG, pending, againJ, againG
end

-- Trace of the probes made during a gathering (/hr gather debug on).
local function gTrace(kind, result, cause)
    if HR.db.gatherDebug == true and HR.gatheringUntil and GetTime() < HR.gatheringUntil then
        HR:Say(("Gather: probe during the gathering (%s): %s%s"):format(kind, result, cause and (" - " .. cause) or ""))
    end
end

local function runAhead(r, j, g)
    local st, p = r.vstate[j], r.points[j]
    HR.verifyReason = "probing ahead"
    probe(g.ox, g.oy, function(result, cause)
        if HR.route ~= r or r.removed[j] or r.points[j] ~= p then return end
        gTrace("point ahead", result, cause)
        r.vstats.probes = r.vstats.probes + 1
        r.vstats.ahead = (r.vstats.ahead or 0) + 1
        if result == "line" then
            HR.verifyHits = HR.verifyHits + 1
            st.final = nil
            st.confirmed = true
            st.confirmDist = g.dist
            r.vstats.confirmed = r.vstats.confirmed + 1
            st.amb = markAmbiguity(r, geometry(r, j))
            HR:RetargetNearest(r)
        elseif result == "empty" then
            decideAbsent(r, j, st)
        else
            st.none = st.none + 1
            r.vstats.none = r.vstats.none + 1
            r.vstats.causes[cause] = (r.vstats.causes[cause] or 0) + 1
            HR.lastCause = cause
            st.nextAt = GetTime() + math.min(10, 1 + st.none * 1.5)
        end
        HR:RouteChanged()
    end, nil, recipeOpts())
end

local REVIVE_RETRY = 3
local REACHED_DELAY = 10   -- seconds after reaching a point before its first probe

-- The points of the database of the route's types (herbs or ores) that are
-- not ahead in the route are candidates to come back: reached, skipped or
-- removed ones. Each candidate carries its probing state for the route.
local function poolOf(r)
    if r.pool then return r.pool end
    local hbd = hbdLib()
    if not hbd or not r.herbSet then return nil end
    local pool = {}
    local data = HR:DataFor(r.category)[r.region]
    if data then
        for herb in pairs(r.herbSet) do
            for _, pt in ipairs(data[herb] or {}) do
                local wx, wy, inst = hbd:GetWorldCoordinatesFromZone(pt[1] / 100, pt[2] / 100, r.mapID)
                if wx then
                    local p = {x = pt[1], y = pt[2], herb = herb}
                    pool[#pool + 1] = {p = p, key = HR.PointKey(p), wx = wx, wy = wy, inst = inst, stay = 0, nextAt = 0}
                end
            end
        end
    end
    r.pool = pool
    return pool
end

-- Keys of the points still ahead in the route (current one included).
local function liveKeys(r)
    local sig = r.index .. ":" .. (r.rev or 0) .. ":" .. #r.points .. ":" .. (r.removedCount or 0)
    if r.live and r.liveSig == sig then return r.live end
    local live = {}
    for j = r.index, #r.points do
        if not r.removed[j] then live[HR.PointKey(r.points[j])] = true end
    end
    r.live, r.liveSig = live, sig
    return live
end

function HR.RevivePool(r)
    return r and poolOf(r)
end

-- Number of database points of the route's types that are outside the route.
function HR.ReviveCount(r)
    local pool = r and poolOf(r)
    if not pool then return 0 end
    local live, n = liveKeys(r), 0
    for _, e in ipairs(pool) do
        if not live[e.key] then n = n + 1 end
    end
    return n
end

-- Candidates inside the minimap are probed with the minimap hidden while it
-- moves. A node found is put back in the route; nothing found changes nothing
-- and prints nothing.
local function pickRevive(r)
    if HR.db.revive == false then return end
    local hbd = hbdLib()
    if not hbd or not HR.ViewRadius then return end
    local pool = poolOf(r)
    if not pool then return end
    local px, py, pinst = hbd:GetPlayerWorldPosition()
    local radius = HR.ViewRadius()
    if not px or not radius then return end
    local reachSq = (radius * 1.05) ^ 2
    local live = liveKeys(r)
    local now = GetTime()
    local best, bestG
    for _, e in ipairs(pool) do
        if live[e.key] then
            e.inside = false
        elseif e.inst == pinst and (e.wx - px) ^ 2 + (e.wy - py) ^ 2 <= reachSq then
            local g = project(hbd, e.wx, e.wy, e.inst)
            if g and g.inside then
                if not e.inside then e.inside, e.stay, e.nextAt, e.nextOdo = true, 0, 0, 0 end
                local ready = e.nextAt
                local rec = r.cause and r.cause[e.key]
                if rec and rec.cause == "reached" and rec.at + REACHED_DELAY > ready then ready = rec.at + REACHED_DELAY end
                local waiting = e.amb and e.amb.state == "pending"
                if not waiting and now >= ready and (r.odo or 0) >= (e.nextOdo or 0) and (not bestG or g.dist < bestG.dist) then
                    best, bestG = e, g
                end
            else
                e.inside = false
            end
        else
            e.inside = false
        end
    end
    return best, bestG
end

local function runRevive(r, e, g)
    local base = recipeOpts()
    if not base then return end
    local opts = {hidden = true}
    for k, v in pairs(base) do opts[k] = v end
    probe(g.ox, g.oy, function(result, cause)
        if HR.route ~= r then return end
        gTrace("point outside the route", result, cause)
        if result == "line" then
            HR.verifyHits = HR.verifyHits + 1
            local hbd = hbdLib()
            local rec = r.cause and r.cause[e.key]
            e.cause = rec and rec.cause or "passed"
            local a = hbd and e.wx and markAmbiguity(r, project(hbd, e.wx, e.wy, e.inst))
            if not a then
                HR:ReviveSkipped(e)
            elseif a.state == "unresolved" then
                e.amb = a
                HR:ReviveSkipped(e, true)
            else
                a.want = true
                e.amb = a
            end
        elseif result == "empty" then
            e.stay = e.stay + 1
            e.nextOdo = (r.odo or 0) + rescanDist()
        else
            e.nextAt = GetTime() + REVIVE_RETRY
        end
    end, nil, opts)
end

-- Ambiguous positives that a decision depends on (F61 wants to target the
-- point, F60 wants to put it back, or it is the current target): the nearest
-- one is probed at the position found by bestOffset, with the minimap hidden.
local function pickResolve(r)
    if HR.db.ambiguity == false then return end
    local best
    local function consider(kind, ref, a, g)
        if g and g.inside and a.state == "pending" and a.want and a.tries < AMB_TRIES
            and GetTime() >= a.nextAt and (not best or g.dist < best.g.dist) then
            best = {kind = kind, ref = ref, a = a, g = g}
        end
    end
    for j = r.index, #r.points do
        local st = r.vstate[j]
        if st and st.amb and not r.removed[j] then consider("point", j, st.amb, geometry(r, j)) end
    end
    local hbd = hbdLib()
    local pool = hbd and r.pool
    if pool then
        local live = liveKeys(r)
        for _, e in ipairs(pool) do
            if e.amb and not live[e.key] then consider("entry", e, e.amb, project(hbd, e.wx, e.wy, e.inst)) end
        end
    end
    return best
end

local function runResolve(r, c)
    local a = c.a
    local nb = neighbours(r, c.g)
    local px, py
    if nb then px, py = bestOffset(nb) end
    if not px then
        a.state = "unresolved"
        r.vstats.amb.unresolved = r.vstats.amb.unresolved + 1
        if c.kind == "entry" then
            local rec = r.cause and r.cause[c.ref.key]
            c.ref.cause = rec and rec.cause or "passed"
            HR:ReviveSkipped(c.ref, true)
        end
        return
    end
    local base = recipeOpts()
    if not base then return end
    local opts = {hidden = true}
    for k, v in pairs(base) do opts[k] = v end
    local tag = c.kind == "point" and r.points[c.ref] or nil
    r.vstats.amb.probes = r.vstats.amb.probes + 1
    probe(c.g.ox + px, c.g.oy + py, function(result, cause)
        if HR.route ~= r then return end
        if c.kind == "point" and r.points[c.ref] ~= tag then return end
        gTrace("ambiguity", result, cause)
        if result == "line" then
            a.state = "distinct"
            r.vstats.amb.distinct = r.vstats.amb.distinct + 1
            if c.kind == "point" then
                HR:RetargetNearest(r)
            else
                local rec = r.cause and r.cause[c.ref.key]
                c.ref.cause = rec and rec.cause or "passed"
                HR:ReviveSkipped(c.ref)
            end
        elseif result == "empty" then
            a.state = "rejected"
            r.vstats.amb.rejected = r.vstats.amb.rejected + 1
            if c.kind == "point" then
                local st = r.vstate[c.ref]
                st.confirmed = false
                decideAbsent(r, c.ref, st)
                HR:RetargetNearest(r)
            else
                local e = c.ref
                e.amb = nil
                e.stay = e.stay + 1
                e.nextOdo = (r.odo or 0) + rescanDist()
            end
        else
            a.tries = a.tries + 1
            a.nextAt = GetTime() + AMB_RETRY
            if a.tries >= AMB_TRIES then
                a.state = "unresolved"
                r.vstats.amb.unresolved = r.vstats.amb.unresolved + 1
                if c.kind == "entry" then
                    local rec = r.cause and r.cause[c.ref.key]
                    c.ref.cause = rec and rec.cause or "passed"
                    HR:ReviveSkipped(c.ref, true)
                end
            end
        end
        HR:RouteChanged()
    end, nil, opts)
end

-- One pool of candidates (points ahead and points that are back in the minimap):
-- the one nearest to the player is probed first.
local function probeCandidates(r)
    local aj, ag, pending, xj, xg
    if HR.db.verify ~= "off" and (HR.db.verifyAhead or r.aheadOnce) then aj, ag, pending, xj, xg = pickAhead(r) end
    if r.aheadOnce and not aj and not pending then
        r.aheadOnce = nil
        HR:Print(("Verify ahead: done (%d point(s) probed ahead, %d removed so far)."):format(r.vstats.ahead or 0, r.removedCount or 0))
    end
    local re, rg = pickRevive(r)
    local rc = pickResolve(r)
    if not aj and not xj and not re and not rc then return end
    -- Order: a pending ambiguity first, then the points never probed (nearest
    -- first), then the points to probe again (empty ones ahead, candidates
    -- outside the route), nearest first. Probing the same points again never
    -- keeps a new point from being probed.
    local kind
    if rc then
        kind = "resolve"
    elseif aj then
        kind = "ahead"
    else
        local dist = math.huge
        if xj then kind, dist = "again", xg.dist end
        if re and rg.dist < dist then kind = "revive" end
    end
    local why = blocked()
    if why then
        if kind == "ahead" or kind == "again" then HR.verifyReason = "waiting: " .. why end
        return
    end
    if kind == "ahead" then runAhead(r, aj, ag)
    elseif kind == "again" then runAhead(r, xj, xg)
    elseif kind == "revive" then runRevive(r, re, rg)
    else runResolve(r, rc) end
end

-- Distance travelled by the character since the route started (yards).
local function updateOdometer(r)
    local hbd = hbdLib()
    if not hbd then return end
    local x, y, inst = hbd:GetPlayerWorldPosition()
    if not x then return end
    local last = r.lastPos
    if last and last.inst == inst then
        local d = math.sqrt((x - last.x) ^ 2 + (y - last.y) ^ 2)
        if d < 100 then r.odo = r.odo + d end
    end
    r.lastPos = {x = x, y = y, inst = inst}
end

function HR:StartVerify()
    local r = self.route
    if not r then return end
    for k in pairs(rest) do rest[k] = nil end
    r.odo = 0
    r.vstate = {}
    r.vstats = {probes = 0, confirmed = 0, empty = 0, none = 0, causes = {},
        amb = {marked = 0, distinct = 0, rejected = 0, unresolved = 0, probes = 0}}
    local function tick()
        if HR.route ~= r then return end
        updateRest()
        updateOdometer(r)
        if r.mode == "follow" and not probing then
            if HR.db.verify ~= "off" then step(r) end
            if not probing then probeCandidates(r) end
        end
        C_Timer.After(TICK, tick)
    end
    tick()
end

-- When a gathering starts: every point that may have respawned is probed again at
-- once, without waiting for the distance to be travelled; the usual order applies
-- (nearest first).
function HR.StartWave(r)
    if not r or not r.vstate then return end
    local pool = poolOf(r)
    if pool then
        for _, e in ipairs(pool) do e.nextAt, e.nextOdo = 0, 0 end
    end
    for j = r.index, #r.points do
        local st = r.vstate[j]
        if st and st.final and not r.removed[j] then st.nextAt, st.nextOdo = 0, 0 end
    end
    r.vstats.waves = (r.vstats.waves or 0) + 1
end

function HR:VerifyAhead(arg)
    if arg == "on" or arg == "off" then
        self.db.verifyAhead = arg == "on"
        return self:Print("Verify ahead (automatic): " .. arg)
    end
    local r = self.route
    if not r or r.mode ~= "follow" or not r.vstate then return self:Print("Verify ahead: needs a route in follow mode.") end
    if self.db.verify == "off" then return self:Print("Verify is off: /hr verify report first.") end
    r.aheadOnce = true
    self:Print("Verify ahead: probing the points inside the minimap (automatic: " .. (self.db.verifyAhead and "on" or "off") .. ", /hr verify ahead on|off).")
end

function HR:VerifyOption(name, value)
    if value == "on" or value == "off" then self.db.verifyCombat = value == "on" end
    self:Print("Probing the minimap during combat: " .. (self.db.verifyCombat == true and "on" or "off")
        .. " (/hr verify combat on|off). The client may not give the reading in combat, and the minimap may not move back until combat ends.")
end

function HR:VerifyStatus()
    local r = self.route
    local line = ("Verify: %s%s (%d blip(s) confirmed this session), method: %s"):format(
        self.db.verify, (self.db.verifyAhead and " + ahead" or "")
        .. (self.db.verifyCombat == true and " + combat" or ""), self.verifyHits, recipeOpts() and self.db.recipe or "not calibrated (/hr verify calibrate)")
    if r and r.vstats then
        line = line .. (", this route: %d probe(s), %d confirmed, %d empty, %d inconclusive, %d removed"):format(
            r.vstats.probes, r.vstats.confirmed, r.vstats.empty, r.vstats.none, r.removedCount or 0)
    end
    if r and self.verifyReason and self.db.verify ~= "off" then line = line .. ". " .. self.verifyReason end
    self:Print(line)
    if r and r.vstate then
        local outside, empty = 0, 0
        local pool = r.pool
        if pool then
            for _, e in ipairs(pool) do if e.inside then outside = outside + 1 end end
        end
        for j = r.index, #r.points do
            local st = r.vstate[j]
            if st and st.final and not r.removed[j] then
                local g = geometry(r, j)
                if g and g.inside then empty = empty + 1 end
            end
        end
        self:Print(("  Watch: %d point(s) outside the route and %d empty point(s) ahead are inside the minimap, each probed again every %d yd travelled; %d gathering wave(s), %d gathered point(s)"):format(
            outside, empty, rescanDist(), r.vstats and r.vstats.waves or 0, r.harvestedCount or 0))
    end
    if r and r.vstats and r.vstats.amb then
        local a = r.vstats.amb
        local half, source = zoneHalf()
        self:Print(("  Ambiguity: %s, zone half-width %s; %d ambiguous positive(s): %d distinct, %d rejected (treated as absent), %d unresolved; %d offset probe(s)"):format(
            self.db.ambiguity == false and "off" or "on", half and ("%.1f units (%s)"):format(half, source) or "unknown",
            a.marked, a.distinct, a.rejected, a.unresolved, a.probes))
    end
    if r and r.vstats then
        for cause, n in pairs(r.vstats.causes) do self:Print(("  inconclusive x%d: %s"):format(n, cause)) end
    end
end

-- /hr verify calibrate: the player points at a yellow dot (phase A), then rests
-- the mouse in the world (phase B); every method probes that dot and a control
-- position, and the first method that sees the dot and not the control is kept.
-- Phase A of the calibration tests: the mouse is on a yellow dot; returns its
-- offset from the minimap center (units, y up), or nil after saying why.
local function captureDot(name)
    if probing then return end
    if MM.combatBlocked() then return HR:Say(name .. ": not in combat (or tick \"Probe the minimap during combat\").") end
    local has = MM.reading()
    if MM.cursorInside() ~= true or not has then
        return HR:Say(name .. ": no tooltip line under the cursor. Rest the mouse on a yellow dot and retry.")
    end
    local sx, sy = GetCursorPosition()
    local es = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    return sx / es - cx, sy / es - cy
end

local function categoryOf(arg)
    arg = (arg or ""):lower()
    if arg == "ores" or arg == "ore" or arg == "minerals" then return "ores" end
    return "herbs"
end

function HR:VerifyCalibrate(arg)
    self.verifyCategory = categoryOf(arg)
    self:Say(("Calibration, phase A in 3 s: put the mouse ON a yellow %s dot of the minimap and keep it still."):format(self.verifyCategory == "ores" and "ore" or "herb"))
    C_Timer.After(3, function()
        local ox, oy = captureDot("Calibration")
        if not ox then return end
        HR:Say(("Calibration: dot captured at (%.1f, %.1f) units. Phase B in 5 s: move the mouse into the world, away from any window, and keep it still."):format(ox, oy))
        C_Timer.After(5, function()
            if probing then return end
            local why = blocked(true, true)
            if why then return HR:Say("Calibration not run: " .. why .. ".") end
            local halfW = Minimap:GetWidth() / 2
            local control
            for _, c in ipairs({{40, 0}, {-40, 0}, {0, 40}, {0, -40}}) do
                local x, y = ox + c[1], oy + c[2]
                if x * x + y * y <= (0.8 * halfW) ^ 2 then control = {x, y} break end
            end
            if not control then
                return HR:Say("Calibration: the dot is too close to the minimap edge for a control; pick a dot nearer the center.")
            end
            local results = {}
            local function conclude()
                local best
                for _, r in ipairs(results) do
                    if r.hit == "line" and r.control ~= "line" then best = best or r end
                end
                for _, r in ipairs(results) do
                    if r.hit == "line" then best = best or r end
                end
                if best then
                    HR.db.recipe, HR.db.recipeBuild = best.v.name, currentBuild()
                    HR:Say(("Calibration done: method '%s' stored for build %s. Automatic verification is enabled."):format(
                        best.v.name, currentBuild()))
                else
                    HR.db.recipe, HR.db.recipeBuild = nil, nil
                    HR:Say("Calibration failed: no method detects the dot. Automatic verification stays off on this build.")
                end
            end
            local function run(k)
                local v = VARIANTS[k]
                if not v then return conclude() end
                probe(ox, oy, function(hit, hitCause)
                    probe(control[1], control[2], function(ctl)
                        results[#results + 1] = {v = v, hit = hit, control = ctl}
                        HR:Say(("  [%s] on the dot: %s%s; control: %s"):format(
                            v.name, hit, hitCause and (" (" .. hitCause .. ")") or "", ctl))
                        run(k + 1)
                    end, nil, v.opts)
                end, nil, v.opts)
            end
            run(1)
        end)
    end)
end

-- /hr verify arming: does the plain method keep working as time passes after
-- the mouse was on a dot? The known dot and a control are probed at fixed
-- delays after phase A while the mouse rests in the world.
local ARMING_TIMES = {6, 10, 15, 20, 30, 45, 60}

function HR:VerifyArming(arg)
    self.verifyCategory = categoryOf(arg)
    self:Say("Arming test, phase A in 3 s: put the mouse ON a yellow " .. (self.verifyCategory == "ores" and "ore" or "herb") .. " dot of the minimap, then move it into the world within 4 s and keep it still for about a minute. The minimap blinks briefly at each check.")
    C_Timer.After(3, function()
        local ox, oy = captureDot("Arming test")
        if not ox then return end
        local t0 = GetTime()
        local halfW = Minimap:GetWidth() / 2
        local control
        for _, c in ipairs({{40, 0}, {-40, 0}, {0, 40}, {0, -40}}) do
            local x, y = ox + c[1], oy + c[2]
            if x * x + y * y <= (0.8 * halfW) ^ 2 then control = {x, y} break end
        end
        if not control then return HR:Say("Arming test: the dot is too close to the minimap edge; pick a dot nearer the center.") end
        HR:Say(("Arming test: dot captured at (%.1f, %.1f) units; checks at %s s."):format(ox, oy, table.concat(ARMING_TIMES, ", ")))
        local function runAt(k)
            local when = ARMING_TIMES[k]
            if not when then return HR:Say("Arming test finished.") end
            C_Timer.After(math.max(0, t0 + when - GetTime()), function()
                local why = blocked(true, true)
                if why then
                    HR:Say(("  t=%ds: skipped (%s)"):format(when, why))
                    return runAt(k + 1)
                end
                probe(ox, oy, function(hit)
                    probe(control[1], control[2], function(ctl)
                        HR:Say(("  t=%ds after the dot: dot %s, control %s"):format(when, hit, ctl))
                        runAt(k + 1)
                    end, nil, {})
                end, nil, {})
            end)
        end
        runAt(1)
    end)
end

-- /hr verify probe: one probe on the current point with the calibrated method
-- (plain when not calibrated), with everything measured.
function HR:VerifyProbeNow()
    local r = self.route
    if not r or r.mode ~= "follow" then return self:Say("Start a route in follow mode first.") end
    self:Say("Verify probe in 3 s: MOVE the mouse a little in the world, then keep it still.")
    local x0, y0 = GetCursorPosition()
    local movedDuring = false
    local function watch(t)
        local x, y = GetCursorPosition()
        if math.abs(x - x0) > 2 or math.abs(y - y0) > 2 then movedDuring = true end
        if t < 2.75 then C_Timer.After(0.25, function() watch(t + 0.25) end) end
    end
    watch(0)
    C_Timer.After(3, function()
        if HR.route ~= r or probing then return end
        local i = r.index
        local g = geometry(r, i)
        if not g then return HR:Say("Verify probe: no position data (HereBeDragons or the route overlay is missing).") end
        HR:Say(("Verify probe: point %d/%d (%s), %.0f yd away, projected offset (%.0f, %.0f) units, %s the probe disc; mouse moved during the countdown: %s; method: %s."):format(
            i, #r.points, r.points[i].herb, g.dist, g.ox, g.oy, g.inside and "inside" or "outside",
            movedDuring and "yes" or "NO", recipeOpts() and HR.db.recipe or "plain (not calibrated)"))
        local why = blocked(true, true)
        if why then return HR:Say("Verify probe: not run: " .. why .. ".") end
        local d = {}
        probe(g.ox, g.oy, function(result, cause)
            HR:Say(("  cursor (%.0f, %.0f) px, minimap center (%.1f, %.1f), shift (%.1f, %.1f)"):format(
                d.sx or 0, d.sy or 0, d.cx or 0, d.cy or 0, d.hx or 0, d.hy or 0))
            for _, rd in ipairs(d.reads or {}) do
                HR:Say(("  +%d: moved=%s onMinimap=%s focus=%s lines=%s data=%s %s"):format(
                    rd.frame, tostring(rd.applied), tostring(rd.inside), tostring(rd.focus), tostring(rd.has), tostring(rd.anyData), tostring(rd.sig)))
            end
            HR:Say(("  result: %s%s; minimap back home: %s"):format(result, cause and (" (" .. cause .. ")") or "", tostring(d.homeOk)))
        end, d, recipeOpts() or {})
    end)
end

-- /hr verify scan: probes a grid over the whole minimap to map the blips, then
-- draws them next to the projected route points of the current herb (ASCII map
-- in the report window) and compares the projection with its mirror images.
-- Dense herbs explain almost any placement, so only a clear gain counts.
local SCAN_STEP = 16
local SCAN_TOL = 14
local MAP_CHAR = 8

local function countNext(cands, hits, fx, fy)
    local n = 0
    for _, c in ipairs(cands) do
        local x, y = fx * c.x, fy * c.y
        for _, h in ipairs(hits) do
            local dx, dy = x - h.x, y - h.y
            if dx * dx + dy * dy <= SCAN_TOL * SCAN_TOL then n = n + 1 break end
        end
    end
    return n
end

local function asciiMap(cells, cands, R)
    local half = math.floor(R / MAP_CHAR + 0.5)
    local grid = {}
    for row = -half, half do
        grid[row] = {}
        for col = -half, half do grid[row][col] = " " end
    end
    local function put(x, y, ch, strong)
        local col, row = math.floor(x / MAP_CHAR + 0.5), math.floor(y / MAP_CHAR + 0.5)
        if grid[row] and grid[row][col] then
            local old = grid[row][col]
            if (old == "X" and ch == "o") or (old == "o" and ch == "X") then ch = "#" end
            if strong or old == " " or old == "." then grid[row][col] = ch end
        end
    end
    for _, c in ipairs(cells) do put(c.x, c.y, c.res == "line" and "X" or ".", c.res == "line") end
    for _, c in ipairs(cands) do put(c.x, c.y, "o", true) end
    grid[0][0] = "+"
    local out = {}
    for row = half, -half, -1 do out[#out + 1] = table.concat(grid[row], "", -half, half) end
    return table.concat(out, "\n")
end

local function finishScan(r, cells, counts, R)
    local hits = {}
    for _, c in ipairs(cells) do if c.res == "line" then hits[#hits + 1] = c end end
    local report = {("HerbRoute verify scan %s, method %s"):format(date("%Y-%m-%d %H:%M:%S"), tostring(HR.db.recipe))}
    local function say(fmt, ...)
        local line = select("#", ...) > 0 and fmt:format(...) or fmt
        report[#report + 1] = line
        HR:Say(line)
    end
    say("Scan: %d cells probed, %d with lines, %d empty, %d inconclusive.", counts.cells, #hits, counts.empty, counts.none)

    local herb = "route"
    local radius = HR.ViewRadius and HR.ViewRadius()
    local cands = {}
    for j, p in ipairs(r.points) do
        if not r.removed[j] then
            local g = geometry(r, j)
            if g and radius and g.dist <= 0.8 * radius then cands[#cands + 1] = {x = g.ox, y = g.oy, d = g.dist} end
        end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)
    while #cands > 40 do cands[#cands] = nil end

    if #hits > 0 and #cands > 0 then
        local blobs = {}
        for _, h in ipairs(hits) do
            local home
            for _, b in ipairs(blobs) do
                for _, m in ipairs(b.cells) do
                    local dx, dy = h.x - m.x, h.y - m.y
                    if dx * dx + dy * dy <= (1.5 * SCAN_STEP) ^ 2 then home = b break end
                end
                if home then break end
            end
            if not home then home = {cells = {}} blobs[#blobs + 1] = home end
            home.cells[#home.cells + 1] = h
        end
        for _, b in ipairs(blobs) do
            local sx, sy = 0, 0
            for _, m in ipairs(b.cells) do sx, sy = sx + m.x, sy + m.y end
            b.x, b.y = sx / #b.cells, sy / #b.cells
        end
        local used, sumx, sumy, sumRatio = 0, 0, 0, 0
        local listed = {}
        local LOCAL = 20
        for _, c in ipairs(cands) do
            local n, cx, cy = 0, 0, 0
            for _, h in ipairs(hits) do
                local dx, dy = h.x - c.x, h.y - c.y
                if dx * dx + dy * dy <= LOCAL * LOCAL then n, cx, cy = n + 1, cx + h.x, cy + h.y end
            end
            if n > 0 then
                cx, cy = cx / n, cy / n
                used = used + 1
                sumx, sumy = sumx + (cx - c.x), sumy + (cy - c.y)
                local rp = math.sqrt(c.x ^ 2 + c.y ^ 2)
                if rp > 0 then sumRatio = sumRatio + math.sqrt(cx ^ 2 + cy ^ 2) / rp end
                if #listed < 8 then listed[#listed + 1] = ("%.0f: (%+.0f,%+.0f)"):format(rp, cx - c.x, cy - c.y) end
            end
        end
        say("Scan: %d blip group(s); %d of %d projected point(s) have blip cells within %d units (offset = centre of those cells minus the projection).", #blobs, used, #cands, LOCAL)
        if used > 0 then
            say("Scan: offsets blip minus projection (distance from the center: dx,dy in units): %s", table.concat(listed, "; "))
            say("Scan: mean offset (%+.1f, %+.1f) units, mean radial ratio blip/projection %.2f (1 = correct scale).", sumx / used, sumy / used, sumRatio / used)
        end
    end

    if #hits == 0 then
        say("Scan: no blip found on the minimap.")
    elseif #cands < 5 then
        say("Scan: only %d %s point(s) inside the minimap, too few to compare.", #cands, herb)
    else
        local id = countNext(cands, hits, 1, 1)
        local fx, fy, both = countNext(cands, hits, -1, 1), countNext(cands, hits, 1, -1), countNext(cands, hits, -1, -1)
        say("Scan: %d %s point(s) projected; next to a blip (within %d units): as projected %d, mirrored in x %d, in y %d, both %d.",
            #cands, herb, SCAN_TOL, id, fx, fy, both)
        if math.max(fx, fy, both) >= id + math.max(3, 0.2 * #cands) then
            say("Scan: a mirrored projection fits clearly better: the projection is probably wrong.")
        else
            say("Scan: no mirror image fits clearly better than the projection (dense herbs explain most placements; read the map).")
        end
    end
    report[#report + 1] = "Map (8 units per character, north up): X blip, o projected point, # both, . empty cell, + you"
    report[#report + 1] = asciiMap(cells, cands, R)
    local text = table.concat(report, "\n")
    HR.db.scan = {time = date("%Y-%m-%d %H:%M:%S"), text = text}
    HR.Probe:ShowReport(text)
end

function HR:VerifyScan()
    local r = self.route
    if not r or r.mode ~= "follow" then return self:Say("Start a route in follow mode first.") end
    self:Say("Verify scan in 3 s: MOVE the mouse a little in the world, keep it still and do not touch it for about 10 s. The minimap will jump around.")
    C_Timer.After(3, function()
        if HR.route ~= r or probing then return end
        local why = blocked(true)
        if why then return HR:Say("Verify scan: not run: " .. why .. ".") end
        local opts = recipeOpts()
        local R = 0.9 * Minimap:GetWidth() / 2
        local cells = {}
        local gx = -R
        while gx <= R do
            local gy = -R
            while gy <= R do
                if gx * gx + gy * gy <= R * R then cells[#cells + 1] = {x = gx, y = gy} end
                gy = gy + SCAN_STEP
            end
            gx = gx + SCAN_STEP
        end
        local counts, idx = {cells = 0, empty = 0, none = 0}, 0
        local function nextCell()
            idx = idx + 1
            local c = cells[idx]
            if not c then return finishScan(r, cells, counts, R) end
            if HR.route ~= r then return end
            local stop = MM.combatBlocked() and "combat" or (MM.buttonDown() and "a mouse button was pressed")
            if stop then return HR:Say("Verify scan stopped: " .. stop .. ".") end
            probe(c.x, c.y, function(result, cause)
                counts.cells = counts.cells + 1
                c.res = result
                if result == "empty" then
                    counts.empty = counts.empty + 1
                elseif result == "none" then
                    counts.none = counts.none + 1
                    if counts.none >= 8 and counts.none * 3 > counts.cells then
                        return HR:Say("Verify scan stopped: too many inconclusive probes (" .. tostring(cause) .. ").")
                    end
                end
                nextCell()
            end, nil, opts)
        end
        nextCell()
    end)
end
