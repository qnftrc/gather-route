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
local function query(x, y)
    local ok, err = pcall(Minimap.UpdateMouseoverAtPoint, Minimap, x, y)
    if not ok then return nil, tostring(err) end
    local ok2, data = pcall(C_TooltipInfo.GetMinimapMouseover)
    if not ok2 then return nil, tostring(data) end
    local line = data and data.lines and data.lines[1]
    local text = line and line.leftText
    if text == nil then return nil end
    if isSecret(text) then return "<secret>" end
    return text
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

    if toggled then pcall(Minimap.SetUsingSoftCursor, Minimap, false) end
    return res
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

local function summarize(runs, radius)
    local working, bestRun = {}, nil
    for _, r in ipairs(runs) do
        if r.hits > 0 then
            working[#working + 1] = configLabel(r)
            if not bestRun or r.hits > bestRun.hits then bestRun = r end
        end
    end
    if #working == 0 then
        add("RESULT: no blip read in any configuration.")
        add("  Stand near a herb with Find Herbs active and the blip visible, then retry.")
    else
        add("RESULT: blips read with %s.", table.concat(working, ", "))
    end
    return bestRun
end

local function finish()
    local text = table.concat(lines, "\n")
    HR.db.probe = {time = date("%Y-%m-%d %H:%M:%S"), text = text}
    for _, l in ipairs(lines) do HR:Print(l) end
    Probe:ShowReport(text)
end

local function environment(cursorOver)
    local version, build, _, toc = GetBuildInfo()
    add("HerbRoute probe %s", date("%Y-%m-%d %H:%M:%S"))
    add("Client %s build %s toc %s, locale %s", tostring(version), tostring(build), tostring(toc), tostring(GetLocale()))
    local radius = viewRadius()
    add("Minimap: %.0fx%.0f units, zoom %s, view radius %s yd, rotate %s",
        Minimap:GetWidth(), Minimap:GetHeight(), tostring(Minimap:GetZoom()),
        radius and ("%.1f"):format(radius) or "n/a", tostring(GetCVar("rotateMinimap")))
    add("Cursor over minimap: %s", tostring(cursorOver))

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

local function runMain(cursorExpected)
    lines = {}
    local cursorOver = MouseIsOver and MouseIsOver(Minimap) or false
    if cursorExpected == "minimap" and not cursorOver then
        HR:Print("The cursor is not over the minimap.")
    elseif cursorExpected == "world" and cursorOver then
        HR:Print("The cursor is over the minimap, not in the world.")
    end
    local radius, usable = environment(cursorOver)
    if not usable then
        add("RESULT: the minimap cannot be read (missing functions).")
        return finish()
    end

    local region, mapID = HR:GetCurrentRegion()
    local runs = {}
    for _, conv in ipairs({"cursor", "ui"}) do
        for _, soft in ipairs({false, true}) do
            local r = sweep(conv, soft, STEP)
            runs[#runs + 1] = r
            add("Sweep %s: %d probes, %d answers in %.1f ms%s%s", configLabel(r), r.probes, r.hits, r.ms,
                r.truncated and " (cut by time guard)" or "", r.err and (" ERROR: " .. r.err) or "")
            if r.hits > 0 then add("  names: %s", namesText(r.names)) end
        end
    end

    for _, r in ipairs(runs) do
        for name in pairs(r.names) do
            if name == "<secret>" then add("WARNING: tooltip text is a secret value, not readable.") break end
        end
    end

    local best = summarize(runs, radius)
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
        if GetCVar("rotateMinimap") == "1" then
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

function Probe:Run(arg)
    arg = (arg or ""):lower()
    if arg == "copy" then
        local saved = HR.db.probe
        if not saved then return HR:Print("No saved probe report.") end
        return self:ShowReport(saved.text)
    elseif arg == "zoom" then
        return runZoom()
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
