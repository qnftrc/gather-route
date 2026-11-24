local addonName, SR = ...

local normalize = SR.normalize

SR.regionToMap, SR.mapToRegion, SR.unresolved, SR.regionNames, SR.entries = {}, {}, {}, {}, {}

function SR:LoadData()
    local data = _G.SkinRoute_Data
    self.dataMissing = data == nil
    self.Data = {items = {}, creatures = {}, zones = {}}
    if data then
        self.Data.items = data.items or {}
        self.Data.creatures = data.creatures or {}
        self.Data.zones = data.zones or {}
    else
        self:Say("Data\\SkinData.lua is missing: no region to show.")
    end
    wipe(self.entries)
    wipe(self.regionNames)
    for region in pairs(self.Data.zones) do self.regionNames[#self.regionNames + 1] = region end
    table.sort(self.regionNames)
    self.mapsBuilt = false
end

function SR:GetRegions()
    return self.regionNames
end

function SR:AllItems()
    local list = {}
    for id, name in pairs(self.Data.items) do list[#list + 1] = {id = id, name = name} end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return list
end

function SR:FindItems(names)
    local all = self:AllItems()
    local picked, missing, seen = {}, {}, {}
    for _, wanted in ipairs(names) do
        local w = normalize(wanted)
        local hits = {}
        for _, it in ipairs(all) do
            if normalize(it.name) == w then hits = {it} break end
        end
        if #hits == 0 and w ~= "" then
            for _, it in ipairs(all) do
                if normalize(it.name):find(w, 1, true) then hits[#hits + 1] = it end
            end
        end
        if #hits == 0 then
            missing[#missing + 1] = wanted
        else
            for _, it in ipairs(hits) do
                if not seen[it.id] then
                    seen[it.id] = true
                    picked[#picked + 1] = it.id
                end
            end
        end
    end
    return picked, missing
end

function SR:FindRegion(name)
    local n = normalize(name)
    if n == "" then return nil end
    for _, region in ipairs(self.regionNames) do
        if normalize(region) == n then return region end
    end
    local hit
    for _, region in ipairs(self.regionNames) do
        if normalize(region):find(n, 1, true) then
            if hit then return nil, "ambiguous" end
            hit = region
        end
    end
    return hit
end

function SR:RegionEntries(region)
    local cached = self.entries[region]
    if cached then return cached end
    local list = {}
    for id, pts in pairs(self.Data.zones[region] or {}) do
        list[#list + 1] = {id = id, n = math.floor(#pts / 2)}
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    self.entries[region] = list
    return list
end

function SR:BuildMaps()
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

function SR:EnsureMaps()
    if not self.mapsBuilt then self:BuildMaps() end
end

function SR:GetRegionMapID(region)
    self:EnsureMaps()
    return self.regionToMap[region]
end

function SR:GetPlayerPosition()
    local m, x, y = TomTom:GetCurrentPlayerPosition()
    if not m or not x then return end
    return m, x * 100, y * 100
end

function SR:GetCurrentRegion()
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

function SR:DebugRegions()
    self:BuildMaps()
    local m, x, y = self:GetPlayerPosition()
    self:Say(("Player: map %s, %.1f, %.1f -> region %s"):format(tostring(m), x or 0, y or 0, tostring((self:GetCurrentRegion()))))
    self:Say(("%d/%d regions resolved."):format(#self.regionNames - #self.unresolved, #self.regionNames))
    for _, region in ipairs(self.unresolved) do
        self:Say("Unresolved: " .. region .. "  (use /sr setmap " .. region .. ": <mapID>)")
    end
end
