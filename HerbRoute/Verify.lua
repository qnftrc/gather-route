local addonName, HR = ...

-- Verification of the next waypoint on the minimap (follow mode). When the
-- cursor rests in the world, the minimap is moved for a few frames so that the
-- projected position of the point lies under the cursor; at least one tooltip
-- line there means a node is present. A point with no line twice in a row is
-- removed from the route (the herb database is never touched).
--
-- How to make the client refresh the minimap hover after the minimap moved
-- differs between builds, so /hr verify calibrate tries several methods on a
-- yellow dot the player points at, and stores the one that detects it.
HR.verifyHits = 0

local ENTER = 0.85  -- fraction of the view radius inside which a point is probed
local NEAR = 35     -- yards: last check of a confirmed point before arrival
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
    if HR:HerbTrackingActive() ~= true then return "Find Herbs tracking is not active" end
    if not noRecipe and not recipeOpts() then
        return "run /hr verify calibrate once (the probe method is not calibrated for this build)"
    end
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
        if opts.alpha then pcall(Minimap.SetAlpha, Minimap, alpha0) end
        if soft then pcall(Minimap.SetUsingSoftCursor, Minimap, false) end
        if hiddenUID and TomTom.ShowWaypoint then pcall(TomTom.ShowWaypoint, TomTom, hiddenUID) end
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
    C_Timer.After(3, function() finish("none", "timeout") end)

    local function read(n)
        if finished then return end
        local x, y = GetCursorPosition()
        if math.abs(x - sx) > 3 or math.abs(y - sy) > 3 then return finish("none", "the mouse moved") end
        if InCombatLockdown and InCombatLockdown() then return finish("none", "combat") end
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
    end, nil, recipeOpts())
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
    local line = ("Verify: %s (%d blip(s) confirmed this session), method: %s"):format(
        self.db.verify, self.verifyHits, recipeOpts() and self.db.recipe or "not calibrated (/hr verify calibrate)")
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

-- /hr verify calibrate: the player points at a yellow dot (phase A), then rests
-- the mouse in the world (phase B); every method probes that dot and a control
-- position, and the first method that sees the dot and not the control is kept.
-- Phase A of the calibration tests: the mouse is on a yellow dot; returns its
-- offset from the minimap center (units, y up), or nil after saying why.
local function captureDot(name)
    if probing then return end
    if InCombatLockdown and InCombatLockdown() then return HR:Print(name .. ": not in combat.") end
    local has = MM.reading()
    if MM.cursorInside() ~= true or not has then
        return HR:Print(name .. ": no tooltip line under the cursor. Rest the mouse on a yellow dot and retry.")
    end
    local sx, sy = GetCursorPosition()
    local es = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    return sx / es - cx, sy / es - cy
end

function HR:VerifyCalibrate()
    self:Print("Calibration, phase A in 3 s: put the mouse ON a yellow herb dot of the minimap and keep it still.")
    C_Timer.After(3, function()
        local ox, oy = captureDot("Calibration")
        if not ox then return end
        HR:Print(("Calibration: dot captured at (%.1f, %.1f) units. Phase B in 5 s: move the mouse into the world, away from any window, and keep it still."):format(ox, oy))
        C_Timer.After(5, function()
            if probing then return end
            local why = blocked(true, true)
            if why then return HR:Print("Calibration not run: " .. why .. ".") end
            local halfW = Minimap:GetWidth() / 2
            local control
            for _, c in ipairs({{40, 0}, {-40, 0}, {0, 40}, {0, -40}}) do
                local x, y = ox + c[1], oy + c[2]
                if x * x + y * y <= (0.8 * halfW) ^ 2 then control = {x, y} break end
            end
            if not control then
                return HR:Print("Calibration: the dot is too close to the minimap edge for a control; pick a dot nearer the center.")
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
                    HR:Print(("Calibration done: method '%s' stored for build %s. Automatic verification is enabled."):format(
                        best.v.name, currentBuild()))
                else
                    HR.db.recipe, HR.db.recipeBuild = nil, nil
                    HR:Print("Calibration failed: no method detects the dot. Automatic verification stays off on this build.")
                end
            end
            local function run(k)
                local v = VARIANTS[k]
                if not v then return conclude() end
                probe(ox, oy, function(hit, hitCause)
                    probe(control[1], control[2], function(ctl)
                        results[#results + 1] = {v = v, hit = hit, control = ctl}
                        HR:Print(("  [%s] on the dot: %s%s; control: %s"):format(
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

function HR:VerifyArming()
    self:Print("Arming test, phase A in 3 s: put the mouse ON a yellow herb dot of the minimap, then move it into the world within 4 s and keep it still for about a minute. The minimap blinks briefly at each check.")
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
        if not control then return HR:Print("Arming test: the dot is too close to the minimap edge; pick a dot nearer the center.") end
        HR:Print(("Arming test: dot captured at (%.1f, %.1f) units; checks at %s s."):format(ox, oy, table.concat(ARMING_TIMES, ", ")))
        local function runAt(k)
            local when = ARMING_TIMES[k]
            if not when then return HR:Print("Arming test finished.") end
            C_Timer.After(math.max(0, t0 + when - GetTime()), function()
                local why = blocked(true, true)
                if why then
                    HR:Print(("  t=%ds: skipped (%s)"):format(when, why))
                    return runAt(k + 1)
                end
                probe(ox, oy, function(hit)
                    probe(control[1], control[2], function(ctl)
                        HR:Print(("  t=%ds after the dot: dot %s, control %s"):format(when, hit, ctl))
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
    if not r or r.mode ~= "follow" then return self:Print("Start a route in follow mode first.") end
    self:Print("Verify probe in 3 s: MOVE the mouse a little in the world, then keep it still.")
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
        if not g then return HR:Print("Verify probe: no position data (HereBeDragons or the route overlay is missing).") end
        HR:Print(("Verify probe: point %d/%d (%s), %.0f yd away, projected offset (%.0f, %.0f) units, %s the probe disc; mouse moved during the countdown: %s; method: %s."):format(
            i, #r.points, r.points[i].herb, g.dist, g.ox, g.oy, g.inside and "inside" or "outside",
            movedDuring and "yes" or "NO", recipeOpts() and HR.db.recipe or "plain (not calibrated)"))
        local why = blocked(true, true)
        if why then return HR:Print("Verify probe: not run: " .. why .. ".") end
        local d = {}
        probe(g.ox, g.oy, function(result, cause)
            HR:Print(("  cursor (%.0f, %.0f) px, minimap center (%.1f, %.1f), shift (%.1f, %.1f)"):format(
                d.sx or 0, d.sy or 0, d.cx or 0, d.cy or 0, d.hx or 0, d.hy or 0))
            for _, rd in ipairs(d.reads or {}) do
                HR:Print(("  +%d: moved=%s onMinimap=%s focus=%s lines=%s data=%s %s"):format(
                    rd.frame, tostring(rd.applied), tostring(rd.inside), tostring(rd.focus), tostring(rd.has), tostring(rd.anyData), tostring(rd.sig)))
            end
            HR:Print(("  result: %s%s; minimap back home: %s"):format(result, cause and (" (" .. cause .. ")") or "", tostring(d.homeOk)))
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
        HR:Print(line)
    end
    say("Scan: %d cells probed, %d with lines, %d empty, %d inconclusive.", counts.cells, #hits, counts.empty, counts.none)

    local herb = r.points[r.index].herb
    local radius = HR.ViewRadius and HR.ViewRadius()
    local cands = {}
    for j, p in ipairs(r.points) do
        if p.herb == herb and not r.removed[j] then
            local g = geometry(r, j)
            if g and radius and g.dist <= 0.8 * radius then cands[#cands + 1] = {x = g.ox, y = g.oy, d = g.dist} end
        end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)
    while #cands > 40 do cands[#cands] = nil end

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
    if not r or r.mode ~= "follow" then return self:Print("Start a route in follow mode first.") end
    self:Print("Verify scan in 3 s: MOVE the mouse a little in the world, keep it still and do not touch it for about 10 s. The minimap will jump around.")
    C_Timer.After(3, function()
        if HR.route ~= r or probing then return end
        local why = blocked(true)
        if why then return HR:Print("Verify scan: not run: " .. why .. ".") end
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
            local stop = (InCombatLockdown and InCombatLockdown()) and "combat" or (MM.buttonDown() and "a mouse button was pressed")
            if stop then return HR:Print("Verify scan stopped: " .. stop .. ".") end
            probe(c.x, c.y, function(result, cause)
                counts.cells = counts.cells + 1
                c.res = result
                if result == "empty" then
                    counts.empty = counts.empty + 1
                elseif result == "none" then
                    counts.none = counts.none + 1
                    if counts.none >= 8 and counts.none * 3 > counts.cells then
                        return HR:Print("Verify scan stopped: too many inconclusive probes (" .. tostring(cause) .. ").")
                    end
                end
                nextCell()
            end, nil, opts)
        end
        nextCell()
    end)
end
