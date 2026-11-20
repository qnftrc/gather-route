local addonName, HR = ...

-- Helpers shared by the probes and the minimap verification: reading the
-- minimap hover, the cursor, and moving the minimap.
local MM = {}
HR.MM = MM

-- True when a probe must not run because of combat: the player is in combat and
-- the "probe during combat" option (one switch for every probe) is off.
function MM.combatBlocked()
    return (InCombatLockdown and InCombatLockdown() and HR.db.verifyCombat ~= true) and true or false
end

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


-- The frame under the cursor (first of the mouse foci), if any.
local function mouseFocus()
    if GetMouseFoci then
        local foci = GetMouseFoci()
        return foci and foci[1]
    end
    if GetMouseFocus then return GetMouseFocus() end
end

-- Height of one text line in the tooltip font, measured on an invisible
-- FontString with the same font (it follows the UI scale and the font).
local unitFS
local function lineUnit(src)
    if not (UIParent and UIParent.CreateFontString and src.GetFont) then return nil end
    if not unitFS then
        unitFS = UIParent:CreateFontString(nil, "ARTWORK")
        unitFS:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 0)
        unitFS:SetAlpha(0)
    end
    local ok, path, size, flags = pcall(src.GetFont, src)
    if not ok or not path or isSecret(size) then return nil end
    pcall(unitFS.SetFont, unitFS, path, size, flags)
    unitFS:SetText("X")
    local ok2, h = pcall(unitFS.GetStringHeight, unitFS)
    if ok2 and type(h) == "number" and not isSecret(h) then return h end
end

-- What the standard tooltip shows: whether it is up, who owns it, the height
-- of its first text (the object names are joined by line breaks in one text,
-- its text is secret but its height is not) and how many lines that makes.
local function tooltipInfo()
    local info = {}
    if not GameTooltip or not GameTooltip.IsShown then return info end
    info.shown = GameTooltip:IsShown() and true or false
    if GameTooltip.GetOwner then
        local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
        if ok and owner then
            local ok2, name = pcall(owner.GetName, owner)
            info.owner = ok2 and name or "?"
        end
    end
    if not info.shown then return info end
    local f = GameTooltipTextLeft1
    if not f or not f.GetStringHeight then return info end
    local ok, h = pcall(f.GetStringHeight, f)
    if not ok then return info end
    if isSecret(h) then info.secret = true return info end
    if type(h) ~= "number" then return info end
    info.h = h
    info.unit = lineUnit(f)
    if info.unit and info.unit > 0 then info.n = math.floor(h / info.unit + 0.5) end
    return info
end

MM.tooltipInfo = tooltipInfo
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
MM.mouseFocus = mouseFocus
