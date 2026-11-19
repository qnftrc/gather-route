local addonName, HR = ...

-- /hr probe: diagnostics of what the client lets an addon read from the
-- minimap blips. Nothing lasting is changed (the minimap anchors and alpha are
-- always restored) and the herb database is never touched.
local Probe = {}
HR.Probe = Probe

local MM = HR.MM
local isSecret, lineCount, rawRead, reading, present = MM.isSecret, MM.lineCount, MM.rawRead, MM.reading, MM.present
local cursorInside, buttonDown, waitFrames = MM.cursorInside, MM.buttonDown, MM.waitFrames
local savePoints, placeMinimap, mouseOverWorld = MM.savePoints, MM.placeMinimap, MM.mouseOverWorld

local COUNTDOWN = 3
local WORLD_WAIT = 5
local SHIFT = 40 -- control shift of the minimap, in minimap units

local lines

local function add(fmt, ...)
    lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
end

local function viewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, r = pcall(C_Minimap.GetViewRadius)
        if ok and type(r) == "number" then return r end
    end
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

local function fieldTag(v)
    if isSecret(v) then return "secret" end
    if type(v) == "number" then return "number=" .. tostring(v) end
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

local function finish()
    local text = table.concat(lines, "\n")
    HR.db.probe = {time = date("%Y-%m-%d %H:%M:%S"), text = text}
    for _, l in ipairs(lines) do HR:Print(l) end
    Probe:ShowReport(text)
end

-- /hr probe, /hr probe minimap: environment, functions, and the read of the
-- real mouse hover (no probe call).
local function runMain(expected)
    lines = {}
    local version, build, _, toc = GetBuildInfo()
    add("HerbRoute probe %s", date("%Y-%m-%d %H:%M:%S"))
    add("Client %s build %s toc %s, locale %s", tostring(version), tostring(build), tostring(toc), tostring(GetLocale()))
    local radius = viewRadius()
    add("Minimap: %.0fx%.0f units, zoom %s, view radius %s yd, rotate %s",
        Minimap:GetWidth(), Minimap:GetHeight(), tostring(Minimap:GetZoom()),
        radius and ("%.1f"):format(radius) or "n/a", tostring(GetCVar("rotateMinimap")))
    local inside = cursorInside()
    add("Cursor: MouseIsOver(Minimap)=%s, inside the minimap disc=%s",
        tostring(MouseIsOver and MouseIsOver(Minimap) or false), tostring(inside))
    if expected == "minimap" and inside == false then HR:Print("The cursor is not inside the minimap.") end

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
        {"GetCursorPosition", GetCursorPosition},
        {"issecretvalue", issecretvalue},
    }
    local missing = {}
    for _, f in ipairs(fns) do
        if not f[2] then missing[#missing + 1] = f[1] end
    end
    add("Missing functions: %s", #missing > 0 and table.concat(missing, ", ") or "none")

    if not (C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover) then
        add("RESULT: the minimap hover cannot be read (function missing).")
        return finish()
    end

    local data = rawRead()
    local n = lineCount(data)
    add("Baseline read (no probe call): %s",
        data == nil and "no data" or (n > 0 and ("data with %d line(s)"):format(n) or "data without lines"))
    add("  structure: %s", describe(data))
    if describe(data):find("secret", 1, true) then
        add("NOTE: text fields are secret values; only the presence of tooltip lines is readable.")
    end
    if n > 0 then
        add("RESULT: something is under the real mouse hover (cursor %s the minimap disc).", inside and "inside" or "outside")
    elseif data ~= nil then
        add("RESULT: empty hover data, nothing under the cursor (cursor %s the minimap disc).", inside and "inside" or "outside")
    else
        add("RESULT: no data under the cursor (cursor %s the minimap disc).", inside and "inside" or "outside")
    end
    finish()
end

-- /hr probe blink world: the method NodeRadar documents. Phase A: the mouse is
-- on a blip, its offset from the minimap center is captured. Phase B: the
-- mouse rests in the world; the minimap is moved so that the blip lands under
-- the cursor (hit) or away from it (controls), and the reading is compared.
local function runBlinkWorldB(hidden, ox, oy)
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
        local control, hit, misses = nil, nil, {}
        for _, st in ipairs(steps) do
            if st.r6 ~= nil then
                add("  %s (%d,%d): +1 frame %s, +3 frames %s, +6 frames %s, back %s%s", st.kind, st.dx, st.dy,
                    st.r1 and "present" or "absent", st.r3 and "present" or "absent",
                    st.r6 and "present" or "absent", st.back and "present" or "absent",
                    st.sig and (" [" .. st.sig .. "]") or "")
                if st.kind == "control" then control = st
                elseif st.kind == "hit" then hit = st
                else misses[#misses + 1] = st end
            end
        end
        if control and hit and #misses > 0 then
            local function any(st) return st.r1 or st.r3 or st.r6 end
            local missPresent, missEmpty = 0, 0
            for _, m in ipairs(misses) do
                if any(m) then missPresent = missPresent + 1 else missEmpty = missEmpty + 1 end
            end
            local latency = hit.r1 and "1 frame" or (hit.r3 and "3 frames" or "6 frames")
            if any(control) then
                add("RESULT: lines are reported even with the minimap in place and the cursor in the world: the reading is not tied to a blip position.")
            elseif any(hit) and missEmpty > 0 then
                add("RESULT: a blip can be detected by moving the minimap under a resting cursor (lines appear after %s).", latency)
                if missPresent > 0 then
                    add("  %d of %d controls also have lines (neighbouring blips); %d have none: the reading is tied to positions.", missPresent, #misses, missEmpty)
                else
                    add("  Hit has lines, controls have none: positional verification is feasible.")
                end
            elseif any(hit) then
                add("RESULT: lines are reported wherever the minimap lies under the cursor: not tied to the blip.")
            elseif not any(hit) then
                add("RESULT: the blip did not show up under the cursor after the minimap was moved: no positional sampling with this method on this build.")
            else
                add("RESULT: inconclusive.")
            end
        elseif not msg then
            add("RESULT: inconclusive (not enough steps completed).")
        end
        finish()
    end

    if InCombatLockdown and InCombatLockdown() then return conclude("in combat") end
    if buttonDown() then return conclude("a mouse button is held") end
    if not GetCursorPosition or cursorInside() ~= false then return conclude("the cursor must rest in the world, outside the minimap") end
    if not mouseOverWorld() then return conclude("the mouse is over a UI element, not the world") end

    local sx, sy = GetCursorPosition()
    local es = Minimap:GetEffectiveScale()
    local cx0, cy0 = Minimap:GetCenter()
    local halfW = Minimap:GetWidth() / 2
    local hx, hy = (sx / es - ox) - cx0, (sy / es - oy) - cy0
    if math.abs(hx) > 3000 or math.abs(hy) > 3000 then return conclude("the shift needed is too large") end

    steps[1] = {kind = "control", dx = 0, dy = 0}
    steps[2] = {kind = "hit", dx = hx, dy = hy}
    local controls = 0
    for _, c in ipairs({{SHIFT, 0}, {-SHIFT, 0}, {0, SHIFT}, {0, -SHIFT}}) do
        local rx, ry = ox - c[1], oy - c[2]
        if controls < 3 and rx * rx + ry * ry <= (0.8 * halfW) ^ 2 then
            controls = controls + 1
            steps[#steps + 1] = {kind = "miss", dx = hx + c[1], dy = hy + c[2]}
        end
    end
    if controls < 1 then return conclude("no control shift keeps the cursor inside the minimap") end

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
        waitFrames(1, function()
            if finished then return end
            st.r1, st.sig = reading()
            waitFrames(2, function()
                if finished then return end
                st.r3 = present()
                waitFrames(3, function()
                    if finished then return end
                    st.r6 = present()
                    placeMinimap(pts, 0, 0)
                    Minimap:SetAlpha(alpha)
                    waitFrames(3, function()
                        if finished then return end
                        st.back = present()
                        nextStep()
                    end)
                end)
            end)
        end)
    end
    nextStep()
end

local function blinkWorld(hidden)
    lines = {}
    add("HerbRoute probe blink world%s %s", hidden and " (hidden)" or "", date("%Y-%m-%d %H:%M:%S"))
    if not (Minimap.GetNumPoints and Minimap.GetPoint and Minimap.SetPoint and Minimap.ClearAllPoints) then
        add("ABORTED: the minimap anchors cannot be read")
        return finish()
    end
    if InCombatLockdown and InCombatLockdown() then add("ABORTED: in combat") return finish() end
    if buttonDown() then add("ABORTED: a mouse button is held") return finish() end
    if not GetCursorPosition or cursorInside() ~= true then
        add("ABORTED: phase A needs the cursor on a herb blip inside the minimap")
        return finish()
    end
    if not present() then add("ABORTED: phase A found no data under the cursor: rest the mouse on a herb blip") return finish() end
    local sx, sy = GetCursorPosition()
    local cx, cy = Minimap:GetCenter()
    local es = Minimap:GetEffectiveScale()
    local ox, oy = sx / es - cx, sy / es - cy
    add("Phase A: blip under the cursor, offset from the minimap center (%.1f, %.1f) units.", ox, oy)
    HR:Print(("Blip captured. Move the mouse into the world (not over the minimap or a window) and keep it still: test in %d s."):format(WORLD_WAIT))
    C_Timer.After(WORLD_WAIT, function() runBlinkWorldB(hidden, ox, oy) end)
end

-- /hr probe watch: log how the real hover changes while the mouse is moved by
-- hand over empty ground, herb dots and outside the minimap.
local WATCH_SECONDS, WATCH_STEP, WATCH_MAX_EVENTS = 15, 0.2, 80

local function runWatch()
    lines = {}
    add("HerbRoute probe watch %s", date("%Y-%m-%d %H:%M:%S"))
    local tracking, ok = trackingList()
    if ok then
        local active = {}
        for _, t in ipairs(tracking) do if t.active then active[#active + 1] = tostring(t.name) end end
        add("Tracking active: %s", #active > 0 and table.concat(active, ", ") or "none")
    end
    add("Zoom %s, view radius %s yd", tostring(Minimap:GetZoom()), viewRadius() and ("%.1f"):format(viewRadius()) or "n/a")
    HR:Print(("Move the mouse slowly over the minimap for %d s: empty ground, herb dots, then outside."):format(WATCH_SECONDS))
    local elapsed, samples, events, last = 0, 0, 0, nil
    local function tick()
        if elapsed >= WATCH_SECONDS then
            add("%d samples, %d changes%s.", samples, events, events > WATCH_MAX_EVENTS and " (list cut)" or "")
            return finish()
        end
        samples = samples + 1
        local has, sig, anyData = reading()
        local state = has and sig or (anyData and ("empty: " .. sig) or "none")
        local key = anyData and (sig:gsub(" id=%S+", "")) or "none"
        local inside = cursorInside()
        key = key .. "|" .. tostring(inside)
        if key ~= last then
            last = key
            events = events + 1
            if events <= WATCH_MAX_EVENTS then
                local ox, oy = 0, 0
                if GetCursorPosition then
                    local cx, cy = Minimap:GetCenter()
                    local x, y = GetCursorPosition()
                    ox, oy = x / Minimap:GetEffectiveScale() - cx, y / Minimap:GetEffectiveScale() - cy
                end
                add("t=%.1fs cursor (%.0f,%.0f) inside=%s: %s", elapsed, ox, oy, tostring(inside), state)
            end
        end
        elapsed = elapsed + WATCH_STEP
        C_Timer.After(WATCH_STEP, tick)
    end
    tick()
end

local function usage()
    HR:Print("/hr probe - environment, functions, read of the real mouse hover")
    HR:Print("/hr probe minimap - same after 3 s, with the mouse on the minimap")
    HR:Print("/hr probe watch - log how the real hover changes while you move the mouse")
    HR:Print("/hr probe blink world [hidden] - move the minimap under a resting cursor")
    HR:Print("/hr probe copy - reopen the last report")
end

function Probe:Run(arg)
    arg = (arg or ""):lower()
    if arg == "" then
        runMain()
    elseif arg == "minimap" then
        HR:Print(("Probe in %d s: put the mouse over the minimap."):format(COUNTDOWN))
        C_Timer.After(COUNTDOWN, function() runMain("minimap") end)
    elseif arg == "watch" then
        HR:Print(("Watch in %d s: put the mouse over the minimap."):format(COUNTDOWN))
        C_Timer.After(COUNTDOWN, runWatch)
    elseif arg == "blink world" or arg == "blink world hidden" then
        HR:Print(("Phase A in %d s: put the mouse ON a herb blip of the minimap and keep it still."):format(COUNTDOWN))
        C_Timer.After(COUNTDOWN, function() blinkWorld(arg == "blink world hidden") end)
    elseif arg == "copy" then
        local saved = HR.db.probe
        if not saved then return HR:Print("No saved probe report.") end
        self:ShowReport(saved.text)
    else
        usage()
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
