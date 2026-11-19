local addonName, HR = ...

-- Draws the route on the world map and on the minimap. TomTom only draws
-- pins, so the lines are ours. Minimap projection follows
-- HereBeDragons-Pins-2.0 (view radius, rotation, round shape).

local DONE   = {0.6, 0.6, 0.6, 0.25}
local NEXT   = {0.2, 1.0, 0.3, 1.0}
local TODO   = {1.0, 0.82, 0.2, 0.8}
local DOT    = "Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDotYellow"

local MAP_MAX_SEGMENTS = 800
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

local refreshMap
local boostUntil = 0

-- The world map frame may not exist when the addon loads (Blizzard_WorldMap is
-- load-on-demand on some clients), so the overlay frame is created on first need.
local function ensureMapFrame()
    if mapFrame then return true end
    -- Frames added to the world map taint Blizzard's gamepad code (see
    -- TomTom/core/position.lua), so the map overlay is skipped in that mode.
    if TomTom:IsGamepadUI() or not WorldMapFrame or not WorldMapFrame.GetCanvas then return false end
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return false end
    mapFrame = CreateFrame("Frame", nil, canvas)
    mapFrame:SetAllPoints()
    mapFrame:SetFrameStrata("HIGH")
    mapFrame:SetFrameLevel(9000)
    mapFrame:Hide()
    WorldMapFrame:HookScript("OnShow", function()
        refreshMap()
        C_Timer.After(0, refreshMap)
    end)
    WorldMapFrame:HookScript("OnHide", refreshMap)
    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", refreshMap)
    end
    return true
end

function HR:OverlayStatus()
    local r = self.route
    local shown = WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
    local canvas = mapFrame and WorldMapFrame:GetCanvas()
    self:Print(("Map overlay: frame %s, map shown %s, map ID %s, route map %s, canvas %sx%s, %d line(s), showMap %s"):format(
        mapFrame and "created" or "NOT created", tostring(shown),
        tostring(WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()), tostring(r and r.mapID),
        canvas and tostring(canvas:GetWidth()) or "?", canvas and tostring(canvas:GetHeight()) or "?",
        #mapLines, tostring(self.db.showMap)))
end

local testTex, testLine

-- Draws a red square and a red diagonal on the map for 20 s and reports what the
-- client says about the overlay frame, to tell an invisible frame from invisible lines.
function HR:OverlayTest()
    self:Print("Map overlay test: open the world map within 5 s (the route does not need to run).")
    C_Timer.After(5, function()
        if not ensureMapFrame() then return HR:Print("Map overlay test: no overlay frame (gamepad mode or no map canvas).") end
        local canvas = WorldMapFrame:GetCanvas()
        if not WorldMapFrame:IsShown() then return HR:Print("Map overlay test: the world map was not open.") end
        local w, h = canvas:GetWidth(), canvas:GetHeight()
        mapFrame:Show()
        testTex = testTex or mapFrame:CreateTexture(nil, "OVERLAY")
        testTex:SetColorTexture(1, 0, 0, 1)
        testTex:SetSize(40, 40)
        testTex:ClearAllPoints()
        testTex:SetPoint("CENTER", canvas, "TOPLEFT", w / 2, -h / 2)
        testTex:Show()
        testLine = testLine or mapFrame:CreateLine(nil, "OVERLAY")
        testLine:SetColorTexture(1, 0, 0, 1)
        testLine:SetThickness(4)
        testLine:SetStartPoint("TOPLEFT", canvas, w * 0.2, -h * 0.2)
        testLine:SetEndPoint("TOPLEFT", canvas, w * 0.8, -h * 0.8)
        testLine:Show()
        HR:Print(("Map overlay test: frame visible %s, effective alpha %s, strata %s level %s (canvas %s / %s), scale %s, size %sx%s; square %s, line %s."):format(
            tostring(mapFrame:IsVisible()), tostring(mapFrame:GetEffectiveAlpha()), tostring(mapFrame:GetFrameStrata()),
            tostring(mapFrame:GetFrameLevel()), tostring(canvas:GetFrameStrata()), tostring(canvas:GetFrameLevel()),
            tostring(mapFrame:GetEffectiveScale()), tostring(mapFrame:GetWidth()), tostring(mapFrame:GetHeight()),
            tostring(testTex:IsVisible()), tostring(testLine:IsVisible())))
        HR:Print("Map overlay test: do you see a red square at the centre and a red diagonal? (they disappear in 20 s)")
        local r = HR.route
        if r then
            boostUntil = GetTime() + 20
            refreshMap()
            local l1, d1 = mapLines[1], mapDots[1]
            local function pt(o)
                if not o or not o.GetPoint then return "none" end
                local ok, p, rel, rp, x, y = pcall(o.GetPoint, o)
                return ok and ("%s %.0f,%.0f"):format(tostring(p), tonumber(x) or 0, tonumber(y) or 0) or "?"
            end
            local a, b = "?", "?"
            if l1 and l1.GetStartPoint then
                local ok1, p1, _, _, x1, y1 = pcall(l1.GetStartPoint, l1)
                local ok2, p2, _, _, x2, y2 = pcall(l1.GetEndPoint, l1)
                if ok1 then a = ("%.0f,%.0f"):format(tonumber(x1) or 0, tonumber(y1) or 0) end
                if ok2 then b = ("%.0f,%.0f"):format(tonumber(x2) or 0, tonumber(y2) or 0) end
            end
            local visible = 0
            for _, l in ipairs(mapLines) do if l:IsVisible() then visible = visible + 1 end end
            HR:Print(("Map overlay test: route has %d point(s), %d line(s) visible of %d, first line %s -> %s (canvas %.0fx%.0f), route point 1 = %.1f,%.1f, start %.1f,%.1f, first dot %s. The route is drawn in thick magenta for 20 s."):format(
                #r.points, visible, #mapLines, a, b, w, h, r.points[1].x, r.points[1].y, r.start.x, r.start.y, pt(d1)))
        else
            HR:Print("Map overlay test: no active route (start one with /hr, then run /hr map again to test the route itself).")
        end
        C_Timer.After(20, function() testTex:Hide() testLine:Hide() refreshMap() end)
    end)
end

function refreshMap()
    local r = HR.route
    if not r or not HR.db.showMap or not WorldMapFrame or not WorldMapFrame:IsShown() then
        if mapFrame then mapFrame:Hide() end
        return
    end
    if not ensureMapFrame() then return end
    local canvas = WorldMapFrame:GetCanvas()
    local shownMap = WorldMapFrame:GetMapID()
    if shownMap ~= r.mapID then
        -- the same zone can exist under several map IDs: accept the one shown if it carries the region's name
        local info = C_Map and C_Map.GetMapInfo and shownMap and C_Map.GetMapInfo(shownMap)
        if not (info and type(info.name) == "string" and HR.normalize(info.name) == HR.normalize(r.region)) then
            mapFrame:Hide()
            return
        end
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
        if not (r.removed and r.removed[i]) then
            used = used + 1
            local line = getLine(mapLines, mapFrame, used)
            local c = color(i, r.index)
            local boost = GetTime() < boostUntil
            if boost then c = {1, 0, 1, 1} end
            line:SetColorTexture(c[1], c[2], c[3], c[4])
            line:SetThickness(boost and 6 or (i == r.index and 3 or 2))
            line:SetStartPoint("TOPLEFT", canvas, prev.x / 100 * w, -prev.y / 100 * h)
            line:SetEndPoint("TOPLEFT", canvas, p.x / 100 * w, -p.y / 100 * h)
            line:Show()
            prev = p
        end
    end
    hideFrom(mapLines, used + 1)

    local dots = 0
    for i = r.index, r.mode == "follow" and last or 0 do
        if not (r.removed and r.removed[i]) then
            dots = dots + 1
            local d = getDot(mapDots, mapFrame, dots, GetTime() < boostUntil and 24 or 10)
            d:ClearAllPoints()
            d:SetPoint("CENTER", canvas, "TOPLEFT", pts[i].x / 100 * w, -pts[i].y / 100 * h)
            d:Show()
        end
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
    local last = n
    local used, dots = 0, 0
    local pfx, pfy = 0, 0 -- the player is at the center
    for i = r.index, last do
      if not (r.removed and r.removed[i]) then
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

HR.ComputeRouteWorld = computeWorld
HR.ViewRadius = viewRadius

function HR:UpdateOverlay()
    local r = self.route
    if r and not r.world and hbd then computeWorld(r) end
    refreshMap()
    if not hbd then return end
    if miniFrame then
        miniFrame:SetShown(r ~= nil)
        if r then refreshMinimap() end
    end
end

function HR:InitOverlay()
    hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    mapLines, mapDots, miniLines, miniDots = {}, {}, {}, {}
    ensureMapFrame()
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, name)
        if name == "Blizzard_WorldMap" then ensureMapFrame() end
    end)
    if not hbd then
        HR:Print("HereBeDragons-2.0 not found: the minimap overlay is disabled.")
        return
    end

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
end
