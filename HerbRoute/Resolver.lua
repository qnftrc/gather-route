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

HR.MERGE_TOL = 1.0 -- percent of the map

-- Keeps the first point of every neighbourhood: a point within `tol` of one already
-- kept (same region, same type) is dropped. The raw tables are never changed.
local function mergeNeighbours(data, tol)
    local out = {}
    local r2 = (tol + 1e-9) ^ 2
    for region, items in pairs(data) do
        local o = {}
        for item, pts in pairs(items) do
            local kept, grid = {}, {}
            for _, p in ipairs(pts) do
                local kx, ky = math.floor(p[1] / tol), math.floor(p[2] / tol)
                local dup = false
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local cell = grid[(kx + dx) * 1000 + (ky + dy)]
                        if cell then
                            for _, q in ipairs(cell) do
                                local ex, ey = p[1] - q[1], p[2] - q[2]
                                if ex * ex + ey * ey <= r2 then dup = true break end
                            end
                        end
                        if dup then break end
                    end
                    if dup then break end
                end
                if not dup then
                    kept[#kept + 1] = p
                    local key = kx * 1000 + ky
                    grid[key] = grid[key] or {}
                    grid[key][#grid[key] + 1] = p
                end
            end
            o[item] = kept
        end
        out[region] = o
    end
    return out
end
HR.MergeNeighbours = mergeNeighbours

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

function HR:DataFor(category)
    local c = self.categories[category or "herbs"]
    if self.db and self.db.mergeDuplicates == true then
        if not c.merged then c.merged = mergeNeighbours(c.data, HR.MERGE_TOL) end
        return c.merged
    end
    return c.data
end

function HR:GetRegions(category)
    return self.categoryRegions[category or "herbs"] or {}
end

function HR:GetHerbs(region, category)
    local list = {}
    local data = self:DataFor(category)[region]
    if data then
        for herb in pairs(data) do list[#list + 1] = herb end
        table.sort(list)
    end
    return list
end

-- Every herb or ore of the category with its points over all regions, sorted by name.
function HR:GetAllItems(category)
    category = category or "herbs"
    local data, totals = self:DataFor(category), {}
    for _, region in ipairs(self:GetRegions(category)) do
        for item, pts in pairs(data[region] or {}) do totals[item] = (totals[item] or 0) + #pts end
    end
    local list = {}
    for item, n in pairs(totals) do list[#list + 1] = {item = item, total = n} end
    table.sort(list, function(a, b) return a.item < b.item end)
    return list
end

-- Regions holding at least one of the items, most points first (ties by name).
function HR:RankRegions(category, items)
    category = category or "herbs"
    local data, list = self:DataFor(category), {}
    for _, region in ipairs(self:GetRegions(category)) do
        local total = 0
        for _, item in ipairs(items) do
            local pts = data[region] and data[region][item]
            if pts then total = total + #pts end
        end
        if total > 0 then list[#list + 1] = {region = region, total = total} end
    end
    table.sort(list, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.region < b.region
    end)
    return list
end

function HR:CountPoints(region, herb, category)
    local data = self:DataFor(category)
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
        local names = HR.RegionNames(region)
        for _, name in ipairs(names) do
            if not id then id = byName[normalize(name)] end
        end
        for _, name in ipairs(names) do
            local n = normalize(name)
            if not id then
                for key, candidate in pairs(byName) do
                    if key:sub(1, #n) == n and (not id or candidate < id) then id = candidate end
                end
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
