local addonName, HR = ...

-- Helpers shared by the probes and the minimap verification: reading the
-- minimap hover, the cursor, and moving the minimap.
local MM = {}
HR.MM = MM

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- Number of tooltip lines. An empty hover returns data without lines, so "a
-- blip is under the hover" means at least one line, not merely non-nil data.
local function lineCount(data)
    if type(data) ~= "table" or isSecret(data) then return 0 end
    local ls = data.lines
    if type(ls) ~= "table" or isSecret(ls) then return 0 end
    return #ls
end

-- The readable numbers of the tooltip data (the text and color are secret).
local function signature(data)
    if type(data) ~= "table" or isSecret(data) then return "n/a" end
    local line = type(data.lines) == "table" and data.lines[1]
    local function n(v)
        if type(v) == "number" and not isSecret(v) then return tostring(v) end
        return "?"
    end
    return ("type=%s id=%s lines=%d line1type=%s"):format(n(data.type), n(data.dataInstanceID), lineCount(data),
        type(line) == "table" and n(line.type) or "?")
end

local function rawRead()
    local ok, data = pcall(C_TooltipInfo.GetMinimapMouseover)
    if not ok then return nil end
    return data
end

-- Returns: something under the hover (lines), the signature, any data at all.
local function reading()
    local data = rawRead()
    return lineCount(data) > 0, signature(data), data ~= nil
end

local function present()
    return (reading())
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

local function buttonDown()
    if not IsMouseButtonDown then return false end
    return (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        or IsMouseButtonDown("MiddleButton")) and true or false
end

local function waitFrames(n, fn)
    if n <= 0 then return fn() end
    C_Timer.After(0, function() waitFrames(n - 1, fn) end)
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

local function mouseOverWorld()
    local focus
    if GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci and foci[1]
    elseif GetMouseFocus then
        focus = GetMouseFocus()
    else
        return true
    end
    return focus == nil or focus == WorldFrame
end


MM.isSecret = isSecret
MM.lineCount = lineCount
MM.signature = signature
MM.rawRead = rawRead
MM.reading = reading
MM.present = present
MM.cursorInside = cursorInside
MM.buttonDown = buttonDown
MM.waitFrames = waitFrames
MM.savePoints = savePoints
MM.placeMinimap = placeMinimap
MM.mouseOverWorld = mouseOverWorld
