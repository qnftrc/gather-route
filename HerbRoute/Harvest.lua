local addonName, HR = ...

-- A harvest is validated by two things: the player just finished a gathering cast, and the
-- chat then says "You receive loot: [item]" for the matching herb or ore. Only then is the
-- point remembered as visited (HerbRouteDB.visited), the matching point leaves the route, and a
-- harvest where no point is known is stored as a new node (HerbRouteDB.discovered).

local WINDOW = 10   -- seconds between the gathering cast and the loot message
local TOL = 2.0     -- percent of the map between the player and the node

local GATHER = {
    herbs = {[2366] = true, [2368] = true, [3570] = true, [11993] = true, [28695] = true, [50300] = true},
    ores = {[2575] = true, [2576] = true, [3564] = true, [10248] = true, [29354] = true, [50310] = true},
}

local ORE_LOOT = {
    ["Copper Vein"] = "Copper Ore", ["Tin Vein"] = "Tin Ore", ["Silver Vein"] = "Silver Ore",
    ["Gold Vein"] = "Gold Ore", ["Iron Deposit"] = "Iron Ore", ["Mithril Deposit"] = "Mithril Ore",
    ["Truesilver Deposit"] = "Truesilver Ore", ["Small Thorium Vein"] = "Thorium Ore",
    ["Rich Thorium Vein"] = "Thorium Ore", ["Dark Iron Deposit"] = "Dark Iron Ore",
    ["Lesser Bloodstone Deposit"] = "Lesser Bloodstone Ore", ["Incendicite Mineral Vein"] = "Incendicite Ore",
    ["Indurium Mineral Vein"] = "Indurium Ore",
    ["Ooze Covered Silver Vein"] = "Silver Ore", ["Ooze Covered Gold Vein"] = "Gold Ore",
    ["Ooze Covered Mithril Deposit"] = "Mithril Ore", ["Ooze Covered Truesilver Deposit"] = "Truesilver Ore",
    ["Ooze Covered Thorium Vein"] = "Thorium Ore", ["Ooze Covered Rich Thorium Vein"] = "Thorium Ore",
}

local lastGather

local function selfPrefix()
    local fmt = LOOT_ITEM_SELF or "You receive loot: %s."
    return fmt:match("^(.-)%%s") or "You receive loot: "
end

-- The item name of the player's own loot message, or nil.
function HR.ParseSelfLoot(msg)
    if type(msg) ~= "string" then return end
    local prefix = selfPrefix()
    if msg:sub(1, #prefix) ~= prefix then return end
    return msg:match("%[(.-)%]")
end

-- Node names (as in the data) that give this loot item.
local function nodeNames(category, loot)
    local names = {}
    if category == "ores" then
        for node, item in pairs(ORE_LOOT) do
            if item == loot then names[node] = true end
        end
    else
        names[loot] = true
    end
    return names
end

local function visitedNear(region, x, y)
    local list = HR.db.visited and HR.db.visited[region]
    for _, v in ipairs(list or {}) do
        if (v.x - x) ^ 2 + (v.y - y) ^ 2 <= 0.5 ^ 2 then return true end
    end
    return false
end

function HR:OnHarvest(category, loot)
    local r = self.route
    local m, px, py = self:GetPlayerPosition()
    if not m then return end
    local region = r and r.region
    if not region then region = self:GetCurrentRegion() end
    if not region then return end
    local names = nodeNames(category, loot)
    if next(names) == nil then return end
    local function d2(x, y) return (x - px) ^ 2 + (y - py) ^ 2 end

    local best, bestIdx, bestD
    if r and r.category == category and r.mapID == m then
        for i, p in ipairs(r.points) do
            if not r.removed[i] and names[p.herb] and d2(p.x, p.y) <= TOL * TOL then
                local d = d2(p.x, p.y)
                if not bestD or d < bestD then best, bestIdx, bestD = p, i, d end
            end
        end
    end
    if not best then
        local items = (self:DataFor(category)[region]) or {}
        for name in pairs(names) do
            for _, p in ipairs(items[name] or {}) do
                if d2(p[1], p[2]) <= TOL * TOL and not visitedNear(region, p[1], p[2]) then
                    local d = d2(p[1], p[2])
                    if not bestD or d < bestD then best, bestIdx, bestD = {x = p[1], y = p[2]}, nil, d end
                end
            end
        end
    end

    if best then
        self:RememberVisited(region, best.x, best.y)
        if bestIdx then self:DropPoint(bestIdx) end
        self:Print(("Harvest: %s at %.1f, %.1f remembered as visited%s."):format(loot, best.x, best.y, bestIdx and " and removed from the route" or ""))
    else
        local x, y = math.floor(px * 10 + 0.5) / 10, math.floor(py * 10 + 0.5) / 10
        local item = loot
        if category == "ores" then
            item = nil
            for node in pairs(names) do item = item and "Seen on minimap" or node end
            item = item or HR.SEEN_ITEM
        end
        self:StoreNode(category, region, x, y, item)
        self:RememberVisited(region, x, y)
        self:Print(("Harvest: %s at %.1f, %.1f, no known point: stored as a new node and remembered as visited."):format(loot, x, y))
    end
end

function HR:OnHarvestEvent(event, ...)
    if not self.db then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        for category, ids in pairs(GATHER) do
            if ids[spellID] then lastGather = {category = category, time = GetTime()} end
        end
    elseif event == "CHAT_MSG_LOOT" then
        local loot = HR.ParseSelfLoot((...))
        if not loot or not lastGather or GetTime() - lastGather.time > WINDOW then return end
        self:OnHarvest(lastGather.category, loot)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:SetScript("OnEvent", function(_, event, ...) HR:OnHarvestEvent(event, ...) end)
