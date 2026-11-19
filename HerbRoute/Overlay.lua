local addonName, HR = ...

-- Draws the route on the world map and on the minimap. TomTom only draws
-- pins, so the lines are ours. Minimap projection follows
-- HereBeDragons-Pins-2.0 (view radius, rotation, round shape).

local DONE   = {0.6, 0.6, 0.6, 0.25}
local NEXT   = {0.2, 1.0, 0.3, 1.0}
local TODO   = {1.0, 0.82, 0.2, 0.8}
local DOT    = "Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDotYellow"

local MAP_MAX_SEGMENTS = 800
local MINIMAP_AHEAD = 40
local MINIMAP_INTERVAL = 0.1

local hbd
local mapFrame, mapLines, mapDots
local miniFrame, miniLines, miniDots
local miniElapsed = 0

local MINIMAP_SIZE = {
    indoor = {[0] = 300, 240, 180, 120, 80, 50},
    outdoor = {[0] = 466 + 2/3, 400, 333 + 1/3, 266 + 2/6, 200, 133 + 1/3},
}

local function getLine(pool, parent, i)
    local l = pool[i]
    if not l then
        l = parent:CreateLine(nil, "OVERLAY")
        pool[i] = l
    end
    return l
end

local function getDot(pool, parent, i, size)
    local t = pool[i]
    if not t then
        t = parent:CreateTexture(nil, "OVERLAY")
        t:SetTexture(DOT)
        pool[i] = t
    end
    t:SetSize(size, size)
    return t
end

local function hideFrom(pool, n)
    for i = n, #pool do pool[i]:Hide() end
end

local function color(i, index)
    if i < index then return DONE end
    if i == index then return NEXT end
    return TODO
end

-- World map ----------------------------------------------------------------

local function refreshMap()
    if not mapFrame then return end
    local r = HR.route
    local canvas = WorldMapFrame:GetCanvas()
    if not r or not HR.db.showMap or not WorldMapFrame:IsShown()
        or WorldMapFrame:GetMapID() ~= r.mapID then
        mapFrame:Hide()
        return
    end
    mapFrame:Show()

    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local pts = r.points
    local n = #pts
    local first = math.max(1, r.index - 1)
    local last = math.min(n, first + MAP_MAX_SEGMENTS - 1)
    local used = 0

    local prev = first == 1 and r.start or pts[first - 1]
    for i = first, last do
        local p = pts[i]
        used = used + 1
        local line = getLine(mapLines, mapFrame, used)
        local c = color(i, r.index)
        line:SetColorTexture(c[1], c[2], c[3], c[4])
        line:SetThickness(i == r.index and 3 or 2)
        line:SetStartPoint("TOPLEFT", canvas, prev.x / 100 * w, -prev.y / 100 * h)
        line:SetEndPoint("TOPLEFT", canvas, p.x / 100 * w, -p.y / 100 * h)
        line:Show()
        prev = p
    end
    hideFrom(mapLines, used + 1)

    local dots = 0
    for i = r.index, r.mode == "follow" and last or 0 do
        dots = dots + 1
        local d = getDot(mapDots, mapFrame, dots, 10)
        d:ClearAllPoints()
        d:SetPoint("CENTER", canvas, "TOPLEFT", pts[i].x / 100 * w, -pts[i].y / 100 * h)
        d:Show()
    end
    hideFrom(mapDots, dots + 1)
end

-- Minimap ------------------------------------------------------------------

local function viewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then return C_Minimap.GetViewRadius() end
    local indoors = tonumber(GetCVar("minimapZoom")) == Minimap:GetZoom() and "outdoor" or "indoor"
    return MINIMAP_SIZE[indoors][Minimap:GetZoom()] / 2
end

local CIRCLE = 0.9

-- Clips segment a-b to the minimap disc; nil when it cannot be drawn.
local function clip(ax, ay, bx, by)
    local ain = ax * ax + ay * ay <= CIRCLE * CIRCLE
    local bin = bx * bx + by * by <= CIRCLE * CIRCLE
    if ain and bin then return ax, ay, bx, by end
    if not ain and not bin then return end
    local flip = not ain
    if flip then ax, ay, bx, by = bx, by, ax, ay end
    local dx, dy = bx - ax, by - ay
    local A = dx * dx + dy * dy
    local B = 2 * (ax * dx + ay * dy)
    local C = ax * ax + ay * ay - CIRCLE * CIRCLE
    local t = (-B + math.sqrt(B * B - 4 * A * C)) / (2 * A)
    bx, by = ax + t * dx, ay + t * dy
    if flip then return bx, by, ax, ay end
    return ax, ay, bx, by
end

local function refreshMinimap()
    local r = HR.route
    if not r or not HR.db.showMinimap or not Minimap:IsVisible() then
        miniFrame:Hide()
        return
    end
    local px, py, instance = hbd:GetPlayerWorldPosition()
    if not px or instance ~= r.world.instance then
        miniFrame:Hide()
        return
    end
    miniFrame:Show()

    local rotate = GetCVar("rotateMinimap") == "1"
    local sinF, cosF = 0, 1
    if rotate then
        local facing = GetPlayerFacing()
        if facing then sinF, cosF = math.sin(facing), math.cos(facing) end
    end

    local radius = viewRadius()
    local halfW, halfH = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    local wx, wy = r.world.x, r.world.y
    local showDots = r.mode == "follow"

    local n = #r.points
    local last = math.min(n, r.index + MINIMAP_AHEAD)
    local used, dots = 0, 0
    local pfx, pfy = 0, 0 -- the player is at the center
    for i = r.index, last do
        local dx, dy = px - wx[i], py - wy[i]
        if rotate then dx, dy = dx * cosF - dy * sinF, dx * sinF + dy * cosF end
        local fx, fy = dx / radius, dy / radius

        local ax, ay, bx, by = clip(pfx, pfy, fx, fy)
        if ax then
            used = used + 1
            local line = getLine(miniLines, miniFrame, used)
            local c = color(i, r.index)
            line:SetColorTexture(c[1], c[2], c[3], c[4])
            line:SetThickness(2)
            line:SetStartPoint("CENTER", Minimap, ax * halfW, -ay * halfH)
            line:SetEndPoint("CENTER", Minimap, bx * halfW, -by * halfH)
            line:Show()
        end
        if showDots and fx * fx + fy * fy <= CIRCLE * CIRCLE then
            dots = dots + 1
            local d = getDot(miniDots, miniFrame, dots, 8)
            d:ClearAllPoints()
            d:SetPoint("CENTER", Minimap, "CENTER", fx * halfW, -fy * halfH)
            d:Show()
        end
        pfx, pfy = fx, fy
    end
    hideFrom(miniLines, used + 1)
    hideFrom(miniDots, dots + 1)
end

-- Setup --------------------------------------------------------------------

local function computeWorld(r)
    local x, y, instance = {}, {}, nil
    for i, p in ipairs(r.points) do
        local wx, wy, inst = hbd:GetWorldCoordinatesFromZone(p.x / 100, p.y / 100, r.mapID)
        x[i], y[i], instance = wx, wy, inst
    end
    r.world = {x = x, y = y, instance = instance}
end

function HR:UpdateOverlay()
    if not hbd then return end
    local r = self.route
    if r and not r.world then computeWorld(r) end
    refreshMap()
    if miniFrame then
        miniFrame:SetShown(r ~= nil)
        if r then refreshMinimap() end
    end
end

function HR:InitOverlay()
    hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    if not hbd then return end

    mapLines, mapDots, miniLines, miniDots = {}, {}, {}, {}

    miniFrame = CreateFrame("Frame", nil, Minimap)
    miniFrame:SetAllPoints(Minimap)
    miniFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    miniFrame:Hide()
    miniFrame:SetScript("OnUpdate", function(_, elapsed)
        miniElapsed = miniElapsed + elapsed
        if miniElapsed < MINIMAP_INTERVAL then return end
        miniElapsed = 0
        if HR.route and not HR.route.world then computeWorld(HR.route) end
        refreshMinimap()
    end)

    -- Frames added to the world map taint Blizzard's gamepad code (see
    -- TomTom/core/position.lua), so the map overlay is skipped in that mode.
    if not TomTom:IsGamepadUI() and WorldMapFrame and WorldMapFrame.GetCanvas then
        mapFrame = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
        mapFrame:SetAllPoints()
        mapFrame:SetFrameLevel(WorldMapFrame:GetCanvas():GetFrameLevel() + 50)
        mapFrame:Hide()
        WorldMapFrame:HookScript("OnShow", refreshMap)
        WorldMapFrame:HookScript("OnHide", refreshMap)
        if WorldMapFrame.OnMapChanged then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", refreshMap)
        end
    end
end
