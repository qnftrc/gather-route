local addonName, HR = ...

local GRACE = 8       -- seconds after the end of a gathering during which loot still counts
local GATHER_MAX = 30 -- safety: a gathering window never stays open longer than this
local LINES = 12

local ITEMS = {
    [2447] = "Peacebloom", [765] = "Silverleaf", [2449] = "Earthroot", [785] = "Mageroyal",
    [2450] = "Briarthorn", [3820] = "Stranglekelp", [2453] = "Bruiseweed", [3355] = "Wild Steelbloom",
    [3369] = "Grave Moss", [3356] = "Kingsblood", [3357] = "Liferoot", [3818] = "Fadeleaf",
    [3821] = "Goldthorn", [3358] = "Khadgar's Whisker", [3819] = "Wintersbite", [4625] = "Firebloom",
    [8831] = "Purple Lotus", [8836] = "Arthas' Tears", [8838] = "Sungrass", [8839] = "Blindweed",
    [8845] = "Ghost Mushroom", [8846] = "Gromsblood", [13464] = "Golden Sansam", [13463] = "Dreamfoil",
    [13465] = "Mountain Silversage", [13466] = "Plaguebloom", [13467] = "Icecap", [13468] = "Black Lotus",
    [2770] = "Copper Ore", [2771] = "Tin Ore", [2772] = "Iron Ore", [2775] = "Silver Ore",
    [2776] = "Gold Ore", [3858] = "Mithril Ore", [7911] = "Truesilver Ore", [10620] = "Thorium Ore",
    [11370] = "Dark Iron Ore", [3340] = "Incendicite Ore", [4278] = "Lesser Bloodstone Ore",
}

local NODE_ITEM = {
    ["Copper Vein"] = 2770, ["Tin Vein"] = 2771, ["Iron Deposit"] = 2772, ["Silver Vein"] = 2775,
    ["Gold Vein"] = 2776, ["Mithril Deposit"] = 3858, ["Truesilver Deposit"] = 7911,
    ["Thorium Vein"] = 10620, ["Small Thorium Vein"] = 10620, ["Rich Thorium Vein"] = 10620, ["Dark Iron Deposit"] = 11370,
    ["Incendicite Mineral Vein"] = 3340, ["Lesser Bloodstone Deposit"] = 4278,
}
local OOZE = "Ooze Covered "

local CALLER = "HerbRoute"
local s          -- current statistics, nil before the first route
local gather     -- window of the gathering in progress: {open = bool, until = time, snap = {id = count}}
local ticking
local win

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function itemInfo(id)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, id)
    if not ok then return nil end
    if type(a) == "table" then return a.itemName or a.name, a.sellPrice or a.vendorPrice end
    return a, k
end

local function learned()
    HR.db.itemIds = HR.db.itemIds or {}
    return HR.db.itemIds
end

-- Names of the database (herbs and ore nodes) -> item ID; false when the ID is not known yet.
function HR.NodeItems()
    local out = {}
    local byName = {}
    for id, name in pairs(ITEMS) do byName[name] = id end
    for _, region in pairs(HerbRoute_Data or {}) do
        for herb in pairs(region) do out[herb] = byName[herb] or learned()[herb] or false end
    end
    for _, region in pairs(HerbRoute_OreData or {}) do
        for node in pairs(region) do
            local base = node:gsub("^" .. OOZE, "")
            out[node] = NODE_ITEM[base] or false
        end
    end
    return out
end

local function allItems()
    local all = {}
    for id, name in pairs(ITEMS) do all[id] = name end
    for name, id in pairs(learned()) do all[id] = name end
    for name, id in pairs(HR.NodeItems()) do
        if id then all[id] = all[id] or name end
        if id == false then
            local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo or function() end)(name)
            local got = type(link) == "string" and tonumber(link:match("|Hitem:(%d+)"))
            if got then learned()[name] = got; all[got] = name end
        end
    end
    return all
end

local function auctionator()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemID then return api end
end

function HR:PriceMemory()
    self.db.prices = self.db.prices or {}
    return self.db.prices
end

-- Reads the Auctionator price of every herb and ore and keeps it. Returns the number read.
function HR:RefreshPrices()
    local api = auctionator()
    if not api then return 0 end
    local mem, n = self:PriceMemory(), 0
    for id in pairs(allItems()) do
        local ok, c = pcall(api.GetAuctionPriceByItemID, CALLER, id)
        if ok and type(c) == "number" and c > 0 then
            n = n + 1
            local old = mem[id]
            if not old or old.c ~= c then mem[id] = {c = c, at = time()} end
        end
    end
    return n
end

-- copper, "ah" | "vendor" | nil
function HR.ItemPrice(id)
    local m = HR.db and HR.db.prices and HR.db.prices[id]
    if m and m.c and m.c > 0 then return m.c, "ah", m.at end
    local _, vendor = itemInfo(id)
    if type(vendor) == "number" and vendor > 0 then return vendor, "vendor" end
    return 0, nil
end

function HR.Money(c)
    c = math.floor((c or 0) + 0.5)
    local neg = c < 0
    if neg then c = -c end
    local g, sv, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local t
    if g > 0 then t = ("%dg %02ds"):format(g, sv)
    elseif sv > 0 then t = ("%ds %02dc"):format(sv, cp)
    else t = ("%dc"):format(cp) end
    return (neg and "-" or "") .. t
end

local function clock(sec)
    sec = math.max(0, math.floor(sec))
    return ("%d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

function HR.StatsElapsed()
    if not s then return 0 end
    return (s.stoppedAt or GetTime()) - s.startedAt
end

function HR.StatsTotal()
    local total, unpriced = 0, 0
    if not s then return 0, 0 end
    for id, e in pairs(s.items) do
        local p = HR.ItemPrice(id)
        if p > 0 then total = total + p * e.count else unpriced = unpriced + e.count end
    end
    return total, unpriced
end

function HR:StatsStart()
    s = {startedAt = GetTime(), items = {}}
    gather = nil
    self:RefreshPrices()
    self:UpdateStats()
end

function HR:StatsStop()
    if s and not s.stoppedAt then s.stoppedAt = GetTime() end
    gather = nil
    self:UpdateStats()
end

function HR.StatsReset()
    if not s then return end
    local live = not s.stoppedAt
    s = {startedAt = GetTime(), items = {}, stoppedAt = (not live) and GetTime() or nil}
    gather = nil
    HR:UpdateStats()
end

local function add(id, link, n)
    if not s or s.stoppedAt then return end
    local e = s.items[id]
    if not e then
        local name = type(link) == "string" and link:match("|h%[(.-)%]|h") or ITEMS[id] or itemInfo(id) or ("item " .. id)
        e = {count = 0, name = name}
        if HR.db and not ITEMS[id] then
            for n, known in pairs(HR.NodeItems()) do if known == false and n == name then learned()[name] = id end end
        end
        s.items[id] = e
    end
    e.count = e.count + n
end

local function snapshot()
    local snap = {}
    if GetItemCount then
        for id in pairs(allItems()) do
            local ok, c = pcall(GetItemCount, id)
            if ok and type(c) == "number" then snap[id] = c end
        end
    end
    return snap
end

local function windowOpen()
    return gather and (gather.open or GetTime() < gather.closeAt)
end

local function closeWindow(g)
    if gather ~= g then return end
    gather = nil
    if g.unreadable and g.snap and GetItemCount then
        for id, before in pairs(g.snap) do
            local ok, now = pcall(GetItemCount, id)
            if ok and type(now) == "number" and now > before then add(id, nil, now - before) end
        end
    end
    HR:UpdateStats()
end

function HR.StatsGatherStart()
    if not s or s.stoppedAt then return end
    gather = {open = true, closeAt = GetTime() + GATHER_MAX, snap = snapshot()}
    local g = gather
    C_Timer.After(GATHER_MAX, function()
        if gather == g and g.open then g.open = false; g.closeAt = GetTime() + GRACE; C_Timer.After(GRACE, function() closeWindow(g) end) end
    end)
end

function HR.StatsGatherEnd()
    local g = gather
    if not g or not g.open then return end
    g.open, g.closeAt = false, GetTime() + GRACE
    C_Timer.After(GRACE, function() closeWindow(g) end)
end

local function selfPatterns()
    local list = {}
    for _, name in ipairs({"LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF"}) do
        local g = _G[name]
        if type(g) == "string" then
            local p = g:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
            list[#list + 1] = {p, name:find("MULTIPLE", 1, true) ~= nil}
        end
    end
    return list
end

function HR.StatsLoot(message)
    if not windowOpen() then return end
    if type(message) ~= "string" or isSecret(message) then
        gather.unreadable = true
        return
    end
    local mine
    local patterns = selfPatterns()
    if #patterns == 0 then
        mine = message:find("^You ") ~= nil
    else
        for _, pat in ipairs(patterns) do
            if message:match("^" .. pat[1] .. "$") then mine = true break end
        end
    end
    if not mine then return end
    local link = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)") or message:match("(|Hitem:.-|h%[.-%]|h)")
    local id = link and tonumber(link:match("|Hitem:(%d+)"))
    if not id then
        gather.unreadable = true
        return
    end
    local n = tonumber(message:match("|h|rx(%d+)") or message:match("|hx(%d+)")) or 1
    add(id, link, n)
    HR:UpdateStats()
end

local function lines()
    local out = {}
    if not s then
        out[1] = "No route yet."
        return out, 0
    end
    local list = {}
    for id, e in pairs(s.items) do
        local p, src = HR.ItemPrice(id)
        list[#list + 1] = {id = id, e = e, p = p, src = src, v = p * e.count}
    end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.e.name < b.e.name end)
    for i, it in ipairs(list) do
        if i > LINES then
            out[#out + 1] = ("... and %d more"):format(#list - LINES)
            break
        end
        out[#out + 1] = ("%s x%d  %s%s"):format(it.e.name, it.e.count,
            it.src and HR.Money(it.v) or "no price", it.src == "vendor" and " (vendor)" or "")
    end
    if #list == 0 then out[1] = "Nothing gathered yet." end
    return out, #list
end

function HR.StatsText()
    local body = lines()
    local total, unpriced = HR.StatsTotal()
    local el = HR.StatsElapsed()
    local perHour = el >= 60 and HR.Money(total / el * 3600) .. "/h" or "..."
    local mem = HR.db and HR.db.prices
    local newest
    if mem then for _, m in pairs(mem) do if m.at and (not newest or m.at > newest) then newest = m.at end end end
    local src = newest and ("AH prices (Auctionator) of " .. date("%Y-%m-%d %H:%M", newest) .. ", else vendor") or "Vendor prices only"
    return {
        duration = "Route time: " .. clock(el) .. (s and s.stoppedAt and " (stopped)" or ""),
        body = table.concat(body, "\n"),
        total = "Total: " .. HR.Money(total) .. "   Per hour: " .. perHour .. (unpriced > 0 and (" (" .. unpriced .. " unpriced)") or ""),
        source = src,
    }
end

local function settings()
    HR.db.statsWindow = HR.db.statsWindow or {}
    return HR.db.statsWindow
end

local function build()
    win = CreateFrame("Frame", "HerbRouteStatsFrame", UIParent, "BasicFrameTemplateWithInset")
    win:SetSize(270, 330)
    win:SetFrameStrata("MEDIUM")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        settings().pos = {point, relPoint, x, y}
    end)
    win:SetScript("OnHide", function() ticking = nil settings().shown = false end)
    if win.SetTitle then win:SetTitle("HerbRoute Stats") elseif win.TitleText then win.TitleText:SetText("HerbRoute Stats") end
    local pos = settings().pos
    if pos then win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else win:SetPoint("CENTER", UIParent, "CENTER", 320, 0) end

    win.duration = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    win.duration:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -32)
    win.body = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    win.body:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -54)
    win.body:SetJustifyH("LEFT")
    win.total = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    win.total:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 52)
    win.source = win:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    win.source:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 36)
    local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    b:SetSize(80, 22)
    b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 10)
    b:SetText("Reset")
    b:SetScript("OnClick", function() HR.StatsReset() end)
end

local function tick()
    if not win or not settings().shown or ticking then return end
    ticking = true
    local function loop()
        if not ticking or not settings().shown then ticking = nil return end
        HR:UpdateStats()
        C_Timer.After(1, loop)
    end
    C_Timer.After(1, loop)
end

function HR:UpdateStats()
    if not win or not settings().shown then return end
    local t = HR.StatsText()
    win.duration:SetText(t.duration)
    win.body:SetText(t.body)
    win.total:SetText(t.total)
    win.source:SetText(t.source)
end

function HR:ToggleStats(show)
    if not win then build() end
    if show == nil then show = not settings().shown end
    win:SetShown(show)
    settings().shown = show
    if show then self:UpdateStats() tick() end
end

function HR:StatsProbe()
    local api = auctionator()
    self:Say("Stats: Auctionator " .. (Auctionator and "found" or "not found") .. ", API v1 price function " .. (api and "present" or "missing") .. ".")
    if api then
        local ok, c = pcall(api.GetAuctionPriceByItemID, CALLER, 8839)
        self:Say(("Stats: Blindweed (8839) price from Auctionator: %s."):format(ok and (c and HR.Money(c) or "none (no scan yet?)") or ("error " .. tostring(c))))
        self:Say(("Stats: %d herbs and ores priced and remembered."):format(self:RefreshPrices()))
    end
    local n, bad, unknown, total = 0, 0, {}, 0
    local all = allItems()
    for id, name in pairs(all) do
        total = total + 1
        local got = itemInfo(id)
        if got then n = n + 1 if got ~= name and ITEMS[id] and ITEMS[id] ~= got then bad = bad + 1 self:Say(("Stats: item %d is '%s', expected '%s'."):format(id, got, name)) end end
    end
    local nodes, missing, k = HR.NodeItems(), {}, 0
    for node, id in pairs(nodes) do
        k = k + 1
        if not id then missing[#missing + 1] = node end
    end
    table.sort(missing)
    self:Say(("Stats: %d herbs and ore nodes of the database, %d with a known item%s."):format(k, k - #missing,
        #missing > 0 and (" (missing: " .. table.concat(missing, ", ") .. "; learned from the first loot)") or ""))
    self:Say(("Stats: %d item IDs checked, %d read by the client, %d with another name."):format(total, n, bad))
    local mem = self:PriceMemory()
    local c = 0
    for _ in pairs(mem) do c = c + 1 end
    self:Say(("Stats: %d prices in memory. Loot messages: %s."):format(c, LOOT_ITEM_SELF and "pattern known" or "pattern missing (fallback: text starting with 'You ')"))
end

function HR:InitStats()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_LOOT")
    f:RegisterEvent("AUCTION_HOUSE_CLOSED")
    f:SetScript("OnEvent", function(_, event, message)
        if event == "CHAT_MSG_LOOT" then HR.StatsLoot(message) else HR:RefreshPrices() end
    end)
    local api = auctionator()
    if api and api.RegisterForDBUpdate then
        pcall(api.RegisterForDBUpdate, CALLER, function() HR:RefreshPrices() end)
    end
    if settings().shown then self:ToggleStats(true) end
end
