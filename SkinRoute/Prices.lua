local addonName, SR = ...

local CALLER = "SkinRoute"

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

function SR.ItemInfo(id)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return nil end
    local ok, a, _, _, _, _, _, _, _, _, _, k = pcall(fn, id)
    if not ok then return nil end
    if type(a) == "table" then return a.itemName or a.name, a.sellPrice or a.vendorPrice end
    return a, k
end

local function auctionator()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemID then return api end
end

function SR:ReadPrices()
    local api = auctionator()
    if not api then return 0 end
    local memory = self.db.ahPrices
    local n = 0
    for id in pairs(self.Data.items) do
        local ok, c = pcall(api.GetAuctionPriceByItemID, CALLER, id)
        if ok and type(c) == "number" and not isSecret(c) and c > 0 then
            local old = memory[id]
            if not old or old.c ~= c then memory[id] = {c = c, at = time()} end
            n = n + 1
        end
    end
    return n
end

function SR:ItemPrice(id)
    local manual = self.db.prices[id]
    if manual then return manual, "manual" end
    local m = self.db.ahPrices[id]
    if m and m.c and m.c > 0 then return m.c, "ah", m.at end
    local _, vendor = SR.ItemInfo(id)
    if type(vendor) == "number" and not isSecret(vendor) and vendor > 0 then return vendor, "vendor" end
end

function SR.PriceLine()
    local newest
    for _, m in pairs(SR.db and SR.db.ahPrices or {}) do
        if m.at and (not newest or m.at > newest) then newest = m.at end
    end
    if newest then
        return "Prices: Auctionator scan of " .. date("%Y-%m-%d %H:%M", newest) .. ", else vendor"
    end
    return "Prices: vendor only (no Auctionator scan seen yet)"
end

function SR:InitPrices()
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "AUCTION_HOUSE_CLOSED")
    f:SetScript("OnEvent", function() SR:ReadPrices() SR:RefreshZones() end)
    local api = auctionator()
    if api and api.RegisterForDBUpdate then
        pcall(api.RegisterForDBUpdate, CALLER, function() SR:ReadPrices() SR:RefreshZones() end)
    end
    self:ReadPrices()
end

function SR:PricesProbe()
    local api = auctionator()
    self:Say("Prices: Auctionator " .. (Auctionator and "found" or "not found") .. ", API v1 price function " .. (api and "present" or "missing") .. ".")
    if api then
        local id = 2319
        local ok, c = pcall(api.GetAuctionPriceByItemID, CALLER, id)
        self:Say(("Prices: Medium Leather (%d) from Auctionator: %s."):format(id,
            ok and (type(c) == "number" and not isSecret(c) and SR.MoneyText(c) or "none (no scan yet?)") or ("error " .. tostring(c))))
        self:Say(("Prices: %d of %d item(s) priced and remembered."):format(self:ReadPrices(), self:CountItems()))
    end
    self:Say(SR.PriceLine() .. ".")
    self:RefreshZones()
end

function SR:CountItems()
    local n = 0
    for _ in pairs(self.Data.items) do n = n + 1 end
    return n
end
