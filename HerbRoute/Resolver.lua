local addonName, HR = ...
local normalize = HR.normalize

HR.regionNames = {}
for name in pairs(HerbRoute_Data) do HR.regionNames[#HR.regionNames + 1] = name end
table.sort(HR.regionNames)

HR.regionToMap = {}
HR.mapToRegion = {}
HR.unresolved = {}

function HR:GetHerbs(region)
    local list = {}
    local data = HerbRoute_Data[region]
    if data then
        for herb in pairs(data) do list[#list + 1] = herb end
        table.sort(list)
    end
    return list
end

function HR:CountPoints(region, herb)
    local pts = HerbRoute_Data[region] and HerbRoute_Data[region][herb]
    return pts and #pts or 0
end

-- Matches each region name against TomTom's zone table (TomTom.NameToMapId).
-- Duplicate zone names are stored by TomTom as "Name:Parent", hence the
-- prefix fallback, where the lowest map ID wins as in TomTom itself.
function HR:BuildMaps()
    wipe(self.regionToMap)
    wipe(self.mapToRegion)
    wipe(self.unresolved)

    local byName = {}
    for name, id in pairs(TomTom.NameToMapId or {}) do
        if type(id) == "number" then byName[normalize(name)] = id end
    end

    for _, region in ipairs(self.regionNames) do
        local id = self.db.overrides[region]
        local n = normalize(region)
        if not id then id = byName[n] end
        if not id then
            for key, candidate in pairs(byName) do
                if key:sub(1, #n) == n and (not id or candidate < id) then id = candidate end
            end
        end
        if id then
            self.regionToMap[region] = id
            self.mapToRegion[id] = region
        else
            self.unresolved[#self.unresolved + 1] = region
        end
    end
    self.mapsBuilt = true
end

function HR:EnsureMaps()
    if not self.mapsBuilt then self:BuildMaps() end
end

function HR:GetRegionMapID(region)
    self:EnsureMaps()
    return self.regionToMap[region]
end

-- Returns mapID, x, y with x and y in percent (0-100), or nil.
function HR:GetPlayerPosition()
    local m, x, y = TomTom:GetCurrentPlayerPosition()
    if not m or not x then return end
    return m, x * 100, y * 100
end

-- The player's map, or the closest parent map, that has herb data.
function HR:GetCurrentRegion()
    self:EnsureMaps()
    local m = TomTom:GetCurrentPlayerPosition()
    local guard = 0
    while m and m ~= 0 and guard < 10 do
        if self.mapToRegion[m] then return self.mapToRegion[m], m end
        local info = C_Map.GetMapInfo(m)
        m = info and info.parentMapID
        guard = guard + 1
    end
end

function HR:DebugRegions()
    self:BuildMaps()
    local m, x, y = self:GetPlayerPosition()
    self:Print(("Player: map %s, %.1f, %.1f -> region %s"):format(tostring(m), x or 0, y or 0, tostring(self:GetCurrentRegion())))
    self:Print(("%d/%d regions resolved."):format(#self.regionNames - #self.unresolved, #self.regionNames))
    for _, region in ipairs(self.unresolved) do
        self:Print("Unresolved: " .. region .. "  (use /hr setmap " .. region .. ": <mapID>)")
    end
end
