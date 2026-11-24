local addonName, SR = ...

local SEGMENTS = 48
local THICKNESS = 3
local TEST_SECONDS = 20
local COLORS = {
    red = {1, 0.25, 0.25},
    orange = {1, 0.5, 0.25},
    yellow = {1, 0.82, 0},
    green = {0.25, 0.75, 0.25},
    gray = {0.62, 0.62, 0.62},
}

local mapFrame, mapLines, mapLabels
local refreshMap

local function getLine(i)
    local l = mapLines[i]
    if not l then
        l = mapFrame:CreateLine(nil, "OVERLAY")
        mapLines[i] = l
    end
    return l
end

local function getLabel(i)
    local f = mapLabels[i]
    if not f then
        f = mapFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f:SetShadowOffset(1, -1)
        mapLabels[i] = f
    end
    return f
end

local function hideFrom(pool, n)
    for i = n, #pool do pool[i]:Hide() end
end

local function ensureMapFrame()
    if mapFrame then return true end
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

local function drawCircle(used, canvas, cx, cy, rx, ry, c, dashed)
    local step = 2 * math.pi / SEGMENTS
    for k = 0, SEGMENTS - 1 do
        if not dashed or k % 3 ~= 2 then
            used = used + 1
            local line = getLine(used)
            local a1, a2 = k * step, (k + 1) * step
            line:SetColorTexture(c[1], c[2], c[3], 0.9)
            line:SetThickness(THICKNESS)
            line:SetStartPoint("TOPLEFT", canvas, cx + rx * math.cos(a1), -(cy + ry * math.sin(a1)))
            line:SetEndPoint("TOPLEFT", canvas, cx + rx * math.cos(a2), -(cy + ry * math.sin(a2)))
            line:Show()
        end
    end
    return used
end

local function zoneLabels(row, s)
    local e = row.eval
    local lines = {}
    local level = ""
    if e.lmin then
        level = e.lmin == e.lmax and ("Lv " .. e.lmin) or ("Lv " .. e.lmin .. "-" .. e.lmax)
    end
    local color = COLORS[SR.Rules.difficulty(e.avgLevel or ((e.lmin + e.lmax) / 2), s.ctx.level)]
    if e.status == "locked" then
        lines[1] = {level, color}
        lines[2] = {"needs skinning " .. e.minNeeded, COLORS.orange}
    else
        lines[1] = {s.anyPrice and SR.MoneyText(e.value) or ("~%.0f items"):format(e.drops), {1, 1, 1}}
        lines[2] = {level, color}
        if e.status == "partial" then
            lines[3] = {("%d%% skinnable"):format(math.floor(e.percent + 0.5)), COLORS.orange}
        end
    end
    return lines
end

function refreshMap()
    local s = SR.shown
    local test = SR.mapTest and GetTime() < SR.mapTest.untilT and SR.mapTest
    if not (s or test) or SR.db.showMap == false or not WorldMapFrame or not WorldMapFrame:IsShown() then
        if mapFrame then mapFrame:Hide() end
        return
    end
    if not ensureMapFrame() then return end
    local canvas = WorldMapFrame:GetCanvas()
    local wantedMap = s and s.mapID or test.mapID
    local wantedName = s and s.region or test.region
    local shownMap = WorldMapFrame:GetMapID()
    if shownMap ~= wantedMap then
        local info = C_Map and C_Map.GetMapInfo and shownMap and C_Map.GetMapInfo(shownMap)
        if not (info and type(info.name) == "string" and SR.normalize(info.name) == SR.normalize(wantedName)) then
            mapFrame:Hide()
            return
        end
    end
    mapFrame:Show()

    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local used, labels = 0, 0
    if s then
        local size = s.set.size
        local rx, ry = s.set.radius / size.w * w, s.set.radius / size.h * h
        for _, row in ipairs(s.rows) do
            local cx, cy = row.zone.x / 100 * w, row.zone.y / 100 * h
            local e = row.eval
            local mid = e.avgLevel or ((e.lmin + e.lmax) / 2)
            used = drawCircle(used, canvas, cx, cy, rx, ry, COLORS[SR.Rules.difficulty(mid, s.ctx.level)], e.status == "locked")
            local lines = zoneLabels(row, s)
            for k, entry in ipairs(lines) do
                labels = labels + 1
                local f = getLabel(labels)
                f:ClearAllPoints()
                f:SetPoint("CENTER", canvas, "TOPLEFT", cx, -(cy + (k - (#lines + 1) / 2) * 14))
                f:SetText(entry[1])
                f:SetTextColor(entry[2][1], entry[2][2], entry[2][3])
                f:Show()
            end
        end
    end
    if test then
        local size = test.size
        used = drawCircle(used, canvas, test.x / 100 * w, test.y / 100 * h, test.radius / size.w * w, test.radius / size.h * h, {1, 0, 1}, false)
    end
    hideFrom(mapLines, used + 1)
    hideFrom(mapLabels, labels + 1)
end

function SR:UpdateOverlay()
    refreshMap()
end

function SR:OverlayStatus()
    local s = self.shown
    local canvas = mapFrame and WorldMapFrame:GetCanvas()
    self:Say(("Map overlay: frame %s, map shown %s, map ID %s, zones for %s (map %s), canvas %sx%s, %d line(s), %d label(s), showMap %s"):format(
        mapFrame and "created" or "NOT created", tostring(WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()),
        tostring(WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()),
        s and s.region or "none", s and tostring(s.mapID) or "-",
        canvas and tostring(canvas:GetWidth()) or "?", canvas and tostring(canvas:GetHeight()) or "?",
        mapLines and #mapLines or 0, mapLabels and #mapLabels or 0, tostring(self.db.showMap)))
end

function SR:MapTest()
    local hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    if not hbd then return self:Say("HereBeDragons-2.0 not found: no test circle.") end
    local m, x, y = self:GetPlayerPosition()
    if not m then return self:Say("No player position (TomTom returned nothing).") end
    local x0, y0 = hbd:GetWorldCoordinatesFromZone(0, 0, m)
    local x1, y1 = hbd:GetWorldCoordinatesFromZone(1, 1, m)
    if not (x0 and x1) then return self:Say("The world position of your map " .. tostring(m) .. " is unknown.") end
    local info = C_Map.GetMapInfo(m)
    self.mapTest = {
        mapID = m, region = info and info.name or "", x = x, y = y, radius = self.db.zoneRadius,
        size = {w = math.abs(x1 - x0), h = math.abs(y1 - y0)}, untilT = GetTime() + TEST_SECONDS,
    }
    self:Say(("Map test: a magenta circle of %d yd around you for %d s. Open the world map, then compare with the minimap at zoom 0 (about 233 yd around you)."):format(self.db.zoneRadius, TEST_SECONDS))
    self:OverlayStatus()
    refreshMap()
    C_Timer.After(TEST_SECONDS, function() refreshMap() end)
end

function SR:InitOverlay()
    mapLines, mapLabels = {}, {}
    ensureMapFrame()
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, name)
        if name == "Blizzard_WorldMap" then ensureMapFrame() end
    end)
end
