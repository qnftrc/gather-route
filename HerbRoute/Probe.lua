local addonName, HR = ...

-- /hr probe: diagnostic of what the client lets an addon read from the
-- minimap blips. It changes nothing lasting (soft cursor and zoom are
-- restored) and never touches the herb database.
local Probe = {}
HR.Probe = Probe

local STEP = 6          -- sweep step, in minimap units
local FINE_RANGE = 12   -- calibration window around a hit, in minimap units
local CLUSTER = 10      -- hits closer than this belong to the same blip
local TIME_GUARD = 400  -- ms allowed for one sweep
local COUNTDOWN = 3

local lines

local function add(fmt, ...)
    lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
end

local function hbdLib()
    return LibStub and LibStub("HereBeDragons-2.0", true)
end

local function viewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, r = pcall(C_Minimap.GetViewRadius)
        if ok and type(r) == "number" then return r end
    end
end

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function trackingList()
    local out = {}
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return out, false end
    local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
    if not ok or type(n) ~= "number" then return out, false end
    for i = 1, n do
        local ok2, a, _, c = pcall(C_Minimap.GetTrackingInfo, i)
        if ok2 then
            if type(a) == "table" then
                out[#out + 1] = {name = a.name, active = a.active}
            else
                out[#out + 1] = {name = a, active = c}
            end
        end
    end
    return out, true
end

-- Moves the minimap mouseover to (x, y) and reads the tooltip title back.
-- Returns "<secret>" when the text is unreadable and "<present>" when data
-- exists without a title, so that the presence of a blip is still counted.
local function query(x, y)
    local ok, err = pcall(Minimap.UpdateMouseoverAtPoint, Minimap, x, y)
    if not ok then return nil, tostring(err) end
    local ok2, data = pcall(C_TooltipInfo.GetMinimapMouseover)
    if not ok2 then return nil, tostring(data) end
    if data == nil then return nil end
    if isSecret(data) then return "<secret>" end
    local line = data.lines and data.lines[1]
    local text = line and line.leftText
    if text == nil then return "<present>" end
    if isSecret(text) then return "<secret>" end
    return text
end

local function fieldTag(v)
    if isSecret(v) then return "secret" end
    return type(v)
end

-- Shape of the tooltip data: keys with their types, and the keys of line 1.
local function describe(data)
    if data == nil then return "nil" end
    if isSecret(data) then return "<secret value>" end
    if type(data) ~= "table" then return type(data) end
    local keys = {}
    for k, v in pairs(data) do keys[#keys + 1] = ("%s:%s"):format(tostring(k), fieldTag(v)) end
    table.sort(keys)
    local out = table.concat(keys, ", ")
    local line = type(data.lines) == "table" and data.lines[1]
    if type(line) == "table" then
        local lk = {}
        for k, v in pairs(line) do lk[#lk + 1] = ("%s:%s"):format(tostring(k), fieldTag(v)) end
        table.sort(lk)
        out = out .. " | lines[1]: " .. table.concat(lk, ", ")
    end
    return out
end

-- Read without moving the mouseover: what the real mouse hover gives.
local function baseline()
    local ok, data = pcall(C_TooltipInfo.GetMinimapMouseover)
    if not ok then return false, "error: " .. tostring(data) end
    return data ~= nil, describe(data)
end

-- Cursor position against the minimap disc (MouseIsOver is not reliable here).
local function cursorInside()
    if not GetCursorPosition then return nil end
    local cx, cy = Minimap:GetCenter()
    if not cx then return nil end
    local es = Minimap:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local dx, dy = x / es - cx, y / es - cy
    local r = Minimap:GetWidth() / 2
    return dx * dx + dy * dy <= r * r
end

-- Two coordinate conventions for the point given to UpdateMouseoverAtPoint:
-- "cursor" = screen pixels as GetCursorPosition returns them, "ui" = UI units.
local function toPoint(conv, cx, cy, es, dx, dy)
    if conv == "cursor" then return (cx + dx) * es, (cy + dy) * es end
    return cx + dx, cy + dy
end

local function sweep(conv, soft, step, region)
    local cx, cy = Minimap:GetCenter()
    local es = Minimap:GetEffectiveScale()
    local R = Minimap:GetWidth() / 2 * 0.9
    local res = {conv = conv, soft = soft, probes = 0, hits = 0, names = {}, list = {}}
    if not cx then res.err = "minimap has no position" return res end

    local toggled = soft ~= nil and Minimap.SetUsingSoftCursor
    if toggled then pcall(Minimap.SetUsingSoftCursor, Minimap, soft) end

    local t0 = debugprofilestop()
    local gx = -R
    while gx <= R and not res.err and not res.truncated do
        local gy = -R
        while gy <= R do
            if gx * gx + gy * gy <= R * R then
                local x, y = toPoint(conv, cx, cy, es, gx, gy)
                local name, err = query(x, y)
                res.probes = res.probes + 1
                if err then res.err = err break end
                if name then
                    res.hits = res.hits + 1
                    res.names[name] = (res.names[name] or 0) + 1
                    res.list[#res.list + 1] = {dx = gx, dy = gy, name = name}
                end
            end
            gy = gy + step
        end
        if debugprofilestop() - t0 > TIME_GUARD then res.truncated = true end
        gx = gx + step
    end
    res.ms = debugprofilestop() - t0
    res.echo = res.probes > 20 and res.hits >= res.probes * 0.95

    if toggled then pcall(Minimap.SetUsingSoftCursor, Minimap, false) end
    return res
end

-- Same as sweep on a coarse grid, but reads one frame after moving the
-- mouseover, in case the engine updates it asynchronously.
local function sweepDelayed(conv, soft, step, onDone)
    local cx, cy = Minimap:GetCenter()
    local es = Minimap:GetEffectiveScale()
    local R = Minimap:GetWidth() / 2 * 0.9
    local res = {conv = conv, soft = soft, probes = 0, hits = 0, names = {}, list = {}, delayed = true}
    local pts = {}
    local gx = -R
    while gx <= R do
        local gy = -R
        while gy <= R do
            if gx * gx + gy * gy <= R * R then pts[#pts + 1] = {gx, gy} end
            gy = gy + step
        end
        gx = gx + step
    end
    local toggled = soft ~= nil and Minimap.SetUsingSoftCursor
    if toggled then pcall(Minimap.SetUsingSoftCursor, Minimap, soft) end
    local t0 = debugprofilestop()
    local i = 0
    local function finishRun()
        if toggled then pcall(Minimap.SetUsingSoftCursor, Minimap, false) end
        res.ms = debugprofilestop() - t0
        res.echo = res.probes > 20 and res.hits >= res.probes * 0.95
        onDone(res)
    end
    local function nextPoint()
        i = i + 1
        local p = pts[i]
        if not p then return finishRun() end
        local x, y = toPoint(conv, cx, cy, es, p[1], p[2])
        local ok, err = pcall(Minimap.UpdateMouseoverAtPoint, Minimap, x, y)
        if not ok then res.err = tostring(err) return finishRun() end
        C_Timer.After(0, function()
            local ok2, data = pcall(C_TooltipInfo.GetMinimapMouseover)
            res.probes = res.probes + 1
            if ok2 and data ~= nil then res.hits = res.hits + 1 end
            nextPoint()
        end)
    end
    nextPoint()
end

local function cluster(list)
    local out = {}
    for _, h in ipairs(list) do
        local placed
        for _, c in ipairs(out) do
            local ddx, ddy = c.dx - h.dx, c.dy - h.dy
            if c.name == h.name and ddx * ddx + ddy * ddy <= CLUSTER * CLUSTER then
                c.n, c.sx, c.sy = c.n + 1, c.sx + h.dx, c.sy + h.dy
                placed = true
                break
            end
        end
        if not placed then out[#out + 1] = {name = h.name, n = 1, sx = h.dx, sy = h.dy, dx = h.dx, dy = h.dy} end
    end
    for _, c in ipairs(out) do c.dx, c.dy = c.sx / c.n, c.sy / c.n end
    return out
end

local function namesText(names)
    local parts = {}
    for name, n in pairs(names) do parts[#parts + 1] = ("%s x%d"):format(name, n) end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "-"
end

local function configLabel(r)
    return ("%s/%s"):format(r.conv, r.soft and "soft" or "hard")
end

-- Size of the area that answers around a blip, from a 1-unit grid.
local function calibrate(conv, soft, c)
    local cx, cy = Minimap:GetCenter()
    local es = Minimap:GetEffectiveScale()
    if soft ~= nil and Minimap.SetUsingSoftCursor then pcall(Minimap.SetUsingSoftCursor, Minimap, soft) end
    local minx, maxx, miny, maxy
    for dx = c.dx - FINE_RANGE, c.dx + FINE_RANGE do
        for dy = c.dy - FINE_RANGE, c.dy + FINE_RANGE do
            local x, y = toPoint(conv, cx, cy, es, dx, dy)
            if query(x, y) == c.name then
                minx = math.min(minx or dx, dx); maxx = math.max(maxx or dx, dx)
                miny = math.min(miny or dy, dy); maxy = math.max(maxy or dy, dy)
            end
        end
    end
    if soft ~= nil and Minimap.SetUsingSoftCursor then pcall(Minimap.SetUsingSoftCursor, Minimap, false) end
    if minx then return maxx - minx + 1, maxy - miny + 1 end
end

local function matchHerb(region, name)
    local herbs = region and HerbRoute_Data[region]
    if not herbs then return end
    local n = HR.normalize(name)
    for herb in pairs(herbs) do
        if HR.normalize(herb) == n then return herb end
    end
end

-- Distance in yards between a blip and the closest database point of that herb
-- (rotation off only). It also checks the projection used by Overlay.lua.
local function databaseError(c, region, mapID, radius)
    local hbd = hbdLib()
    local herb = matchHerb(region, c.name)
    if not (hbd and herb and mapID and radius) then return end
    local px, py, instance = hbd:GetPlayerWorldPosition()
    if not px then return end
    local halfW, halfH = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    local bx = px - (c.dx / halfW) * radius
    local by = py + (c.dy / halfH) * radius
    local best
    for _, p in ipairs(HerbRoute_Data[region][herb]) do
        local wx, wy, inst = hbd:GetWorldCoordinatesFromZone(p[1] / 100, p[2] / 100, mapID)
        if wx and inst == instance then
            local d = math.sqrt((wx - bx) ^ 2 + (wy - by) ^ 2)
            if not best or d < best then best = d end
        end
    end
    return best, herb
end

local function summarize(runs)
    local positional, echo, best = {}, {}, nil
    for _, r in ipairs(runs) do
        if r.hits > 0 then
            if r.echo then
                echo[#echo + 1] = configLabel(r) .. (r.delayed and " (+1 frame)" or "")
            else
                positional[#positional + 1] = configLabel(r) .. (r.delayed and " (+1 frame)" or "")
                if not r.delayed and (not best or r.hits > best.hits) then best = r end
            end
        end
    end
    if #positional > 0 then
        add("RESULT: answers that depend on the probed point with %s.", table.concat(positional, ", "))
    elseif #echo > 0 then
        add("RESULT: every probe answered (%s), wherever it pointed.", table.concat(echo, ", "))
        add("  The data does not depend on the probed point: it is the real mouse hover.")
        add("  UpdateMouseoverAtPoint has no effect in these configurations.")
    else
        add("RESULT: no answer in any configuration.")
        add("  Put the mouse on a herb blip of the minimap (use /hr probe minimap) and retry.")
    end
    return best
end

local function finish()
    local text = table.concat(lines, "\n")
    HR.db.probe = {time = date("%Y-%m-%d %H:%M:%S"), text = text}
    for _, l in ipairs(lines) do HR:Print(l) end
    Probe:ShowReport(text)
end

local function environment(over, inside)
    local version, build, _, toc = GetBuildInfo()
    add("HerbRoute probe %s", date("%Y-%m-%d %H:%M:%S"))
    add("Client %s build %s toc %s, locale %s", tostring(version), tostring(build), tostring(toc), tostring(GetLocale()))
    local radius = viewRadius()
    add("Minimap: %.0fx%.0f units, zoom %s, view radius %s yd, rotate %s",
        Minimap:GetWidth(), Minimap:GetHeight(), tostring(Minimap:GetZoom()),
        radius and ("%.1f"):format(radius) or "n/a", tostring(GetCVar("rotateMinimap")))
    add("Cursor: MouseIsOver(Minimap)=%s, inside the minimap disc=%s", tostring(over), tostring(inside))

    local tracking, ok = trackingList()
    if not ok then
        add("Tracking: C_Minimap tracking API not available")
    else
        local active = {}
        for _, t in ipairs(tracking) do if t.active then active[#active + 1] = tostring(t.name) end end
        add("Tracking active: %s", #active > 0 and table.concat(active, ", ") or "none")
    end

    local fns = {
        {"Minimap.UpdateMouseoverAtPoint", Minimap.UpdateMouseoverAtPoint},
        {"C_TooltipInfo.GetMinimapMouseover", C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover},
        {"Minimap.SetUsingSoftCursor", Minimap.SetUsingSoftCursor},
        {"GetCursorPosition", GetCursorPosition},
        {"issecretvalue", issecretvalue},
    }
    local missing = {}
    for _, f in ipairs(fns) do
        if not f[2] then missing[#missing + 1] = f[1] end
    end
    add("Missing functions: %s", #missing > 0 and table.concat(missing, ", ") or "none")
    return radius, (Minimap.UpdateMouseoverAtPoint and C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover) and true or false
end

local function conclude(runs, radius)
    local secret = false
    for _, r in ipairs(runs) do
        if r.names["<secret>"] then secret = true end
    end
    if secret then
        add("WARNING: tooltip text is a secret value, not readable (the presence of a blip is still readable).")
    end

    local region, mapID = HR:GetCurrentRegion()
    local best = summarize(runs)
    Probe.best = best and {conv = best.conv, soft = best.soft} or nil
    if best then
        local clusters = cluster(best.list)
        add("Blips found (%s): %d", configLabel(best), #clusters)
        local c = clusters[1]
        local w, h = calibrate(best.conv, best.soft, c)
        if w and radius then
            local halfW = Minimap:GetWidth() / 2
            add("Answer area around '%s': %.0fx%.0f units, about %.1f x %.1f yd", c.name, w, h,
                w * radius / halfW, h * radius / halfW)
        end
        if secret then
            add("Database error: skipped (names are secret).")
        elseif GetCVar("rotateMinimap") == "1" then
            add("Database error: skipped (rotating minimap is on).")
        else
            local errs = {}
            for _, cl in ipairs(clusters) do
                local d = databaseError(cl, region, mapID, radius)
                if d then errs[#errs + 1] = d end
            end
            if #errs > 0 then
                table.sort(errs)
                add("Distance blip -> closest database point (%d herb blips): min %.1f, median %.1f, max %.1f yd",
                    #errs, errs[1], errs[math.ceil(#errs / 2)], errs[#errs])
            else
                add("Database error: no blip matched a herb of the current region (%s).", tostring(region))
            end
        end
    end
    add("Soft cursor restored to false.")
    finish()
end

local function runMain(cursorExpected)
    lines = {}
    local over = MouseIsOver and MouseIsOver(Minimap) or false
    local inside = cursorInside()
    if cursorExpected == "minimap" and inside == false then
        HR:Print("The cursor is not inside the minimap.")
    elseif cursorExpected == "world" and inside then
        HR:Print("The cursor is inside the minimap, not in the world.")
    end
    local radius, usable = environment(over, inside)
    if not usable then
        add("RESULT: the minimap cannot be read (missing functions).")
        return finish()
    end

    local present, shape = baseline()
    add("Baseline read (no probe call): %s", present and "data present" or "no data")
    add("  structure: %s", shape)

    local runs = {}
    for _, conv in ipairs({"cursor", "ui"}) do
        for _, soft in ipairs({false, true}) do
            local r = sweep(conv, soft, STEP)
            runs[#runs + 1] = r
            add("Sweep %s: %d probes, %d answers (%.0f%%) in %.1f ms%s%s", configLabel(r), r.probes, r.hits,
                r.probes > 0 and r.hits * 100 / r.probes or 0, r.ms,
                r.truncated and " (cut by time guard)" or "", r.err and (" ERROR: " .. r.err) or "")
            if r.hits > 0 then add("  names: %s", namesText(r.names)) end
        end
    end

    -- One frame between moving the mouseover and reading it.
    sweepDelayed("cursor", false, 20, function(r1)
        runs[#runs + 1] = r1
        add("Sweep %s +1 frame: %d probes, %d answers (%.0f%%)%s", configLabel(r1), r1.probes, r1.hits,
            r1.probes > 0 and r1.hits * 100 / r1.probes or 0, r1.err and (" ERROR: " .. r1.err) or "")
        sweepDelayed("cursor", true, 20, function(r2)
            runs[#runs + 1] = r2
            add("Sweep %s +1 frame: %d probes, %d answers (%.0f%%)%s", configLabel(r2), r2.probes, r2.hits,
                r2.probes > 0 and r2.hits * 100 / r2.probes or 0, r2.err and (" ERROR: " .. r2.err) or "")
            conclude(runs, radius)
        end)
    end)
end

local function runZoom()
    if not Probe.best then
        return HR:Print("Run /hr probe first, near a herb blip, so a working configuration is known.")
    end
    lines = {}
    local best = Probe.best
    local levels = (Minimap.GetZoomLevels and Minimap:GetZoomLevels()) or 6
    local original = Minimap:GetZoom()
    add("Zoom probe with %s/%s, original zoom %s", best.conv, best.soft and "soft" or "hard", tostring(original))

    local i = 0
    local function step()
        if i >= levels then
            pcall(Minimap.SetZoom, Minimap, original)
            add("Zoom restored to %s.", tostring(original))
            return finish()
        end
        pcall(Minimap.SetZoom, Minimap, i)
        C_Timer.After(0.3, function()
            local radius = viewRadius()
            local r = sweep(best.conv, best.soft, STEP)
            add("Zoom %d: view radius %s yd, %d answers (%s)", i,
                radius and ("%.1f"):format(radius) or "n/a", r.hits, namesText(r.names))

            local cx, cy = Minimap:GetCenter()
            local es = Minimap:GetEffectiveScale()
            local halfW = Minimap:GetWidth() / 2
            local outside = 0
            if best.soft ~= nil and Minimap.SetUsingSoftCursor then pcall(Minimap.SetUsingSoftCursor, Minimap, best.soft) end
            for _, f in ipairs({1.05, 1.2, 1.4}) do
                for a = 0, 15 do
                    local x, y = toPoint(best.conv, cx, cy, es, math.cos(a * math.pi / 8) * halfW * f, math.sin(a * math.pi / 8) * halfW * f)
                    if query(x, y) then outside = outside + 1 end
                end
            end
            if best.soft ~= nil and Minimap.SetUsingSoftCursor then pcall(Minimap.SetUsingSoftCursor, Minimap, false) end
            add("  answers beyond the disc edge (48 probes): %d", outside)
            i = i + 1
            step()
        end)
    end
    step()
end

-- /hr probe blink: with the real mouse resting on a blip, move the minimap
-- under it and see whether the reading follows. Opt-in; the minimap anchors
-- and alpha are always restored.
local function waitFrames(n, fn)
    if n <= 0 then return fn() end
    C_Timer.After(0, function() waitFrames(n - 1, fn) end)
end

local function present()
    local ok, data = pcall(C_TooltipInfo.GetMinimapMouseover)
    return ok and data ~= nil
end

local function buttonDown()
    if not IsMouseButtonDown then return false end
    return (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        or IsMouseButtonDown("MiddleButton")) and true or false
end

local function savePoints()
    local pts = {}
    for i = 1, Minimap:GetNumPoints() do
        local point, rel, relPoint, x, y = Minimap:GetPoint(i)
        pts[#pts + 1] = {point, rel, relPoint, x or 0, y or 0}
    end
    return pts
end

local function placeMinimap(pts, dx, dy)
    Minimap:ClearAllPoints()
    for _, p in ipairs(pts) do
        Minimap:SetPoint(p[1], p[2], p[3], p[4] + dx, p[5] + dy)
    end
end

local SHIFT = 40
local CANDIDATES = {{SHIFT, 0}, {-SHIFT, 0}, {0, SHIFT}, {0, -SHIFT}, {28, 28}, {-28, 28}, {28, -28}, {-28, -28}}

local function runBlink(hidden)
    lines = {}
    add("HerbRoute probe blink%s %s", hidden and " (hidden)" or "", date("%Y-%m-%d %H:%M:%S"))
    local steps, finished = {}, false
    local pts, alpha

    local function conclude(msg)
        if finished then return end
        finished = true
        if pts then
            pcall(placeMinimap, pts, 0, 0)
            pcall(Minimap.SetAlpha, Minimap, alpha)
            add("Minimap anchors and alpha restored.")
        end
        if msg then add("ABORTED: %s", msg) end

        local control = steps[1] and steps[1].control and steps[1] or nil
        if control and control.r1 ~= nil then add("Control (no shift): %s", control.r1 and "data present" or "no data") end
        local followed, unchanged = {}, 0
        for _, variant in ipairs({false, true}) do
            local total, abs1, abs3, back = 0, 0, 0, true
            for _, st in ipairs(steps) do
                if not st.control and st.update == variant and st.r3 ~= nil then
                    total = total + 1
                    if not st.r1 then abs1 = abs1 + 1 end
                    if not st.r3 then abs3 = abs3 + 1 end
                    if not st.back then back = false end
                    add("  %s shift (%d,%d): +1 frame %s, +3 frames %s, back %s", variant and "update" or "plain",
                        st.dx, st.dy, st.r1 and "present" or "absent", st.r3 and "present" or "absent",
                        st.back and "present" or "absent")
                end
            end
            local label = variant and "update" or "plain"
            if total > 0 then
                if back and abs1 == total then
                    followed[#followed + 1] = label .. " (1 frame)"
                elseif back and abs3 == total then
                    followed[#followed + 1] = label .. " (3 frames)"
                elseif abs1 == 0 and abs3 == 0 then
                    unchanged = unchanged + 1
                end
            end
        end
        if #followed > 0 then
            add("RESULT: the reading follows the moved minimap with %s.", table.concat(followed, ", "))
            add("  Moving the minimap under a resting cursor can sample positions.")
        elseif unchanged > 0 then
            add("RESULT: the reading did not change when the minimap moved.")
            add("  The hover is not refreshed without real mouse motion in these variants.")
        else
            add("RESULT: inconclusive (another blip under the cursor, or the reading was not stable).")
        end
        finish()
    end

    if InCombatLockdown and InCombatLockdown() then return conclude("in combat") end
    if buttonDown() then return conclude("a mouse button is held") end
    if not (Minimap.GetNumPoints and Minimap.GetPoint and Minimap.SetPoint and Minimap.ClearAllPoints) then
        return conclude("the minimap anchors cannot be read")
    end
    if not GetCursorPosition or cursorInside() ~= true then return conclude("the cursor is not inside the minimap") end
    if not present() then return conclude("no data under the cursor: rest the mouse on a herb blip") end

    local sx, sy = GetCursorPosition()
    local cx, cy = Minimap:GetCenter()
    local es = Minimap:GetEffectiveScale()
    local halfW = Minimap:GetWidth() / 2
    local ox, oy = sx / es - cx, sy / es - cy

    -- Only shifts that keep the cursor inside the minimap disc are meaningful.
    local valid = {}
    for _, c in ipairs(CANDIDATES) do
        local rx, ry = ox - c[1], oy - c[2]
        if #valid < 4 and rx * rx + ry * ry <= (0.8 * halfW) ^ 2 then valid[#valid + 1] = c end
    end
    if #valid < 2 then return conclude("move the mouse closer to the minimap center") end

    steps[1] = {control = true, dx = 0, dy = 0, update = false}
    for _, variant in ipairs({false, true}) do
        for _, c in ipairs(valid) do steps[#steps + 1] = {dx = c[1], dy = c[2], update = variant} end
    end

    pts, alpha = savePoints(), Minimap:GetAlpha()
    C_Timer.After(30, function() conclude("timeout") end)

    local function stillOk()
        if InCombatLockdown and InCombatLockdown() then conclude("combat started") return false end
        if buttonDown() then conclude("a mouse button was pressed") return false end
        local x, y = GetCursorPosition()
        if math.abs(x - sx) > 3 or math.abs(y - sy) > 3 then conclude("the mouse moved") return false end
        return true
    end

    local i = 0
    local function nextStep()
        if finished then return end
        i = i + 1
        local st = steps[i]
        if not st then return conclude() end
        if not stillOk() then return end
        placeMinimap(pts, st.dx, st.dy)
        if hidden then Minimap:SetAlpha(0) end
        if st.update then pcall(Minimap.UpdateMouseoverAtPoint, Minimap, sx, sy) end
        waitFrames(1, function()
            if finished then return end
            st.r1 = present()
            waitFrames(2, function()
                if finished then return end
                st.r3 = present()
                placeMinimap(pts, 0, 0)
                Minimap:SetAlpha(alpha)
                if st.update then pcall(Minimap.UpdateMouseoverAtPoint, Minimap, sx, sy) end
                waitFrames(3, function()
                    if finished then return end
                    st.back = present()
                    nextStep()
                end)
            end)
        end)
    end
    nextStep()
end

function Probe:Run(arg)
    arg = (arg or ""):lower()
    if arg == "copy" then
        local saved = HR.db.probe
        if not saved then return HR:Print("No saved probe report.") end
        return self:ShowReport(saved.text)
    elseif arg == "zoom" then
        return runZoom()
    elseif arg == "blink" or arg == "blink hidden" then
        HR:Print(("Blink test in %d s: put the mouse ON a herb blip of the minimap, near its center, and keep it still."):format(COUNTDOWN))
        C_Timer.After(COUNTDOWN, function() runBlink(arg == "blink hidden") end)
        return
    elseif arg == "world" or arg == "minimap" then
        HR:Print(("Probe in %d s: put the mouse %s."):format(COUNTDOWN, arg == "world" and "in the world" or "over the minimap"))
        C_Timer.After(COUNTDOWN, function() runMain(arg) end)
    else
        runMain()
    end
end

function Probe:ShowReport(text)
    if not self.frame then
        local f = CreateFrame("Frame", "HerbRouteProbeFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(560, 360)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")
        if f.SetTitle then f:SetTitle("HerbRoute probe (Ctrl+A, Ctrl+C)") elseif f.TitleText then f.TitleText:SetText("HerbRoute probe (Ctrl+A, Ctrl+C)") end
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -32)
        scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(500)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.edit = edit
        tinsert(UISpecialFrames, "HerbRouteProbeFrame")
        self.frame = f
    end
    self.frame.edit:SetText(text)
    self.frame:Show()
end
