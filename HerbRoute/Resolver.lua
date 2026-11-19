local addonName, HR = ...
local normalize = HR.normalize

HR.categories = {
    herbs = {data = HerbRoute_Data, label = "Herbs", item = "herb", spell = 2383, spellName = "Find Herbs"},
    ores = {data = HerbRoute_OreData or {}, label = "Ores", item = "ore", spell = 2580, spellName = "Find Minerals"},
}

local function sortedRegions(data)
    local list = {}
    for name in pairs(data) do list[#list + 1] = name end
    table.sort(list)
    return list
end

HR.categoryRegions = {herbs = sortedRegions(HR.categories.herbs.data), ores = sortedRegions(HR.categories.ores.data)}

HR.regionNames = {}
do
    local all = {}
    for _, c in pairs(HR.categoryRegions) do
        for _, name in ipairs(c) do all[name] = true end
    end
    for name in pairs(all) do HR.regionNames[#HR.regionNames + 1] = name end
    table.sort(HR.regionNames)
end

HR.regionToMap = {}
HR.mapToRegion = {}
HR.unresolved = {}

function HR:GetRegions(category)
    return self.categoryRegions[category or "herbs"] or {}
end

function HR:GetHerbs(region, category)
    local list = {}
    local data = self.categories[category or "herbs"].data[region]
    if data then
        for herb in pairs(data) do list[#list + 1] = herb end
        table.sort(list)
    end
    return list
end

function HR:CountPoints(region, herb, category)
    local data = self.categories[category or "herbs"].data
    local pts = data[region] and data[region][herb]
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

-- The player's map, or the closest parent map, that has data.
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
