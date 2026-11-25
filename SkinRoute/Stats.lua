local addonName, SR = ...

local GRACE = 8
local GATHER_MAX = 30
local LINE_H = 13
local VISIBLE = 18
local NAME_W = 150
local ROW_W = 228
local LOOT_GRACE = 2
local SKIN_COLOR, KILL_COLOR = "|cffd9a066", "|cff7fcf7f"

local SKINNING_SPELLS = {[8613] = true, [8617] = true, [8618] = true, [10768] = true, [32678] = true, [50305] = true}
local START = {UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true}
local EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
}

local s
local gather
local lootWin
local ticking
local win

local function newSession(stoppedAt)
    return {startedAt = GetTime(), items = {}, skins = 0, stoppedAt = stoppedAt,
        loot = {items = {}, copper = 0}, kills = 0, guids = {}}
end

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok then
            if type(n) == "table" then return n.name end
            if type(n) == "string" then return n end
        end
    end
end

local function isSkinningSpell(id)
    if type(id) ~= "number" or isSecret(id) then return false end
    if SKINNING_SPELLS[id] then return true end
    return SR.IsSkinning(spellName(id)) and true or false
end

local function clock(sec)
    sec = math.max(0, math.floor(sec))
    return ("%d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

local function settings()
    SR.db.statsWindow = SR.db.statsWindow or {}
    return SR.db.statsWindow
end

function SR.StatsElapsed()
    if not s then return 0 end
    return (s.stoppedAt or GetTime()) - s.startedAt
end

local function countLoot()
    return settings().countLoot ~= false
end

local function skinTotal()
    local total, unpriced = 0, 0
    if not s then return 0, 0 end
    for id, e in pairs(s.items) do
        local p = SR:ItemPrice(id)
        if p and p > 0 then total = total + p * e.count else unpriced = unpriced + e.count end
    end
    return total, unpriced
end

local function lootTotal()
    local total, unpriced = 0, 0
    if not s then return 0, 0 end
    total = s.loot.copper
    for id, e in pairs(s.loot.items) do
        local p = SR:LootPrice(id, e.ah, e.q)
        if p and p > 0 then total = total + p * e.count else unpriced = unpriced + e.count end
    end
    return total, unpriced
end

function SR.StatsTotal()
    local total, unpriced = skinTotal()
    if countLoot() then
        local lt, lu = lootTotal()
        total, unpriced = total + lt, unpriced + lu
    end
    return total, unpriced
end

function SR:StatsStart()
    s = newSession()
    gather, lootWin = nil, nil
    self:ReadPrices()
    self:UpdateStats()
end

function SR:StatsStop()
    if s and not s.stoppedAt then s.stoppedAt = GetTime() end
    gather, lootWin = nil, nil
    self:UpdateStats()
end

function SR.StatsReset()
    if not s then return end
    local live = not s.stoppedAt
    s = newSession((not live) and GetTime() or nil)
    gather, lootWin = nil, nil
    SR:UpdateStats()
end

local function add(id, link, n)
    if not s or s.stoppedAt then return end
    local e = s.items[id]
    if not e then
        local name = type(link) == "string" and link:match("|h%[(.-)%]|h") or SR:ItemLabel(id)
        e = {count = 0, name = name}
        s.items[id] = e
    end
    e.count = e.count + n
end

local function bagCount(id)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then return nil end
    local ok, c = pcall(fn, id)
    if ok and type(c) == "number" and not isSecret(c) then return c end
end

local function snapshot()
    local snap = {}
    for id in pairs(SR.Data.items) do snap[id] = bagCount(id) end
    return snap
end

local function windowOpen()
    return gather and (gather.open or GetTime() < gather.closeAt)
end

local function settle(g)
    if not g.snap or (g.seen and not g.unreadable) then return end
    for id, before in pairs(g.snap) do
        local now = bagCount(id)
        local gain = now and (now - before - (g.counted[id] or 0)) or 0
        if gain > 0 then add(id, nil, gain) end
    end
end

local function closeWindow(g)
    if gather ~= g then return end
    gather = nil
    settle(g)
    SR:UpdateStats()
end

function SR.StatsGatherStart()
    if not s or s.stoppedAt then return end
    if gather then
        local prev = gather
        gather = nil
        settle(prev)
    end
    gather = {open = true, closeAt = GetTime() + GATHER_MAX, snap = snapshot(), counted = {}}
    local g = gather
    C_Timer.After(GATHER_MAX, function()
        if gather == g and g.open then
            g.open = false
            g.closeAt = GetTime() + GRACE
            C_Timer.After(GRACE, function() closeWindow(g) end)
        end
    end)
end

function SR.StatsGatherEnd()
    local g = gather
    if not g or not g.open then return end
    g.open, g.closeAt = false, GetTime() + GRACE
    C_Timer.After(GRACE, function() closeWindow(g) end)
end

local function lootWindowOpen()
    return lootWin and lootWin.creature and (lootWin.open or GetTime() < lootWin.closeAt)
end

local function creatureSource()
    if not GetLootSourceInfo then return true, nil end
    local ok, guid = pcall(GetLootSourceInfo, 1)
    if not ok or type(guid) ~= "string" or isSecret(guid) then return true, nil end
    return guid:find("^Creature%-") ~= nil, guid
end

function SR.LootEvent(event)
    if not s or s.stoppedAt then return end
    if event == "LOOT_OPENED" then
        local creature, guid = creatureSource()
        lootWin = {open = true, creature = creature, closeAt = 0}
        if creature and guid and not s.guids[guid] then
            s.guids[guid] = true
            s.kills = s.kills + 1
        end
        SR:UpdateStats()
    elseif event == "LOOT_CLOSED" then
        if lootWin then lootWin.open, lootWin.closeAt = false, GetTime() + LOOT_GRACE end
        local g = gather
        if g and g.seen and not g.open then closeWindow(g) end
    end
end

local QUALITY_COLORS = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
}

local function linkQuality(link, id)
    local color = type(link) == "string" and link:match("|cff(%x%x%x%x%x%x)")
    if color and QUALITY_COLORS[color:lower()] ~= nil then return QUALITY_COLORS[color:lower()] end
    if color then return 9 end
    local token = type(link) == "string" and link:match("|cnIQ(%d+):")
    if token then return tonumber(token) end
    local byId = C_Item and C_Item.GetItemQualityByID
    if byId then
        local ok, q = pcall(byId, id)
        if ok and type(q) == "number" and not isSecret(q) then return q end
    end
    if GetItemInfo then
        local ok, _, _, q = pcall(GetItemInfo, id)
        if ok and type(q) == "number" and not isSecret(q) then return q end
    end
    local info = SR.Loot and SR.Loot.items[id]
    return info and info[2] or nil
end

local debugLog = {}

local function record(entry)
    debugLog[#debugLog + 1] = entry
    if #debugLog > 30 then table.remove(debugLog, 1) end
end

function SR.StatsDebug()
    local out = {}
    for i = math.max(1, #debugLog - 14), #debugLog do
        local e = debugLog[i]
        out[#out + 1] = ("%s -> id %s, quality %s, %s (%s)"):format(tostring(e.text), tostring(e.id), tostring(e.q), e.target, e.why)
    end
    if #out == 0 then out[1] = "No loot message seen yet in this session." end
    return out
end

local function addKillItem(id, link, n, q)
    if q == nil or q > 2 or not s or s.stoppedAt or not countLoot() then return false end
    local e = s.loot.items[id]
    if not e then
        local name = type(link) == "string" and link:match("|h%[(.-)%]|h") or ("item " .. id)
        e = {count = 0, name = name, q = q}
        s.loot.items[id] = e
    end
    e.count = e.count + n
    local ah = SR.AuctionByLink(link)
    if ah then e.ah = ah end
    return true
end

local function amountPattern(global, fallback)
    local g = _G[global]
    if type(g) ~= "string" then return fallback end
    return (g:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%d", "(%%d+)"))
end

function SR.StatsMoney(message)
    if not s or s.stoppedAt or not countLoot() or not lootWindowOpen() then return end
    if type(message) ~= "string" or isSecret(message) then return end
    local you = _G.YOU_LOOT_MONEY
    local mine
    if type(you) == "string" then
        mine = message:match("^" .. you:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", "(.+)") .. "$") ~= nil
    else
        mine = message:find("^You loot") ~= nil
    end
    if not mine then return end
    local gold = tonumber(message:match(amountPattern("GOLD_AMOUNT", "(%d+) Gold"))) or 0
    local silver = tonumber(message:match(amountPattern("SILVER_AMOUNT", "(%d+) Silver"))) or 0
    local copper = tonumber(message:match(amountPattern("COPPER_AMOUNT", "(%d+) Copper"))) or 0
    s.loot.copper = s.loot.copper + gold * 10000 + silver * 100 + copper
    SR:UpdateStats()
end

function SR.CastEvent(event, unit, castGUID, spellId)
    if unit ~= "player" or not isSkinningSpell(spellId) then return end
    if START[event] then
        SR.StatsGatherStart()
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and s and not s.stoppedAt then
        s.skins = s.skins + 1
        SR:UpdateStats()
    end
    SR.StatsGatherEnd()
end

local function selfPatterns()
    local list = {}
    for _, name in ipairs({"LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF"}) do
        local g = _G[name]
        if type(g) == "string" then
            local p = g:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
            list[#list + 1] = p
        end
    end
    return list
end

function SR.StatsLoot(message)
    local skinWindow = windowOpen()
    local lootOpen = lootWindowOpen()
    if not skinWindow and not lootOpen then return end
    if type(message) ~= "string" or isSecret(message) then
        if skinWindow then gather.unreadable = true end
        return
    end
    local mine
    local patterns = selfPatterns()
    if #patterns == 0 then
        mine = message:find("^You ") ~= nil
    else
        for _, pat in ipairs(patterns) do
            if message:match("^" .. pat .. "$") then mine = true break end
        end
    end
    if not mine then return end
    local link = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)") or message:match("(|cn[%w_]+:|Hitem:.-|h%[.-%]|h|r)") or message:match("(|Hitem:.-|h%[.-%]|h)")
    local id = link and tonumber(link:match("|Hitem:(%d+)"))
    if not id then
        if skinWindow then gather.unreadable = true end
        return
    end
    local n = tonumber(message:match("|h|rx(%d+)") or message:match("|hx(%d+)")) or 1
    local q = linkQuality(link, id)
    local skinItem = SR.Data.items[id] ~= nil
    local lootItem = SR.Loot and SR.Loot.items[id] ~= nil
    local target, why
    if skinItem and not lootItem then
        target, why = "skin", "skinning item"
    elseif not skinItem then
        target, why = "kill", "not a skinning item"
    elseif skinWindow then
        target, why = "skin", "in both tables, during a skinning cast"
    else
        target, why = "kill", "in both tables, outside a skinning cast"
    end
    if target == "skin" then
        add(id, link, n)
        if gather then
            gather.seen = true
            gather.counted[id] = (gather.counted[id] or 0) + n
        end
    elseif not (lootOpen and countLoot() and addKillItem(id, link, n, q)) then
        why = why .. (lootOpen and (countLoot() and ", quality " .. tostring(q) .. " not counted" or ", loot counting off") or ", no creature loot window")
        target = "ignored"
    end
    record({text = message:gsub("|c%x+", ""):gsub("|cn[%w_]+:", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""), id = id, q = q, target = target, why = why})
    SR:UpdateStats()
end

local function priced(value, src)
    return value .. (src == "vendor" and "*" or "")
end

local function lines()
    local names, values = {}, {}
    if not s then return {"No guide yet."}, 0, {"No guide yet."}, {""} end
    local function row(name, value)
        names[#names + 1] = name
        values[#values + 1] = value or ""
    end

    local skinSum = skinTotal()
    row(SKIN_COLOR .. "Skinning|r", SKIN_COLOR .. SR.Money(skinSum) .. "|r")
    local list = {}
    for id, e in pairs(s.items) do
        local p, src = SR:ItemPrice(id)
        p = p or 0
        list[#list + 1] = {id = id, e = e, p = p, src = src, v = p * e.count}
    end
    table.sort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.e.name < b.e.name
    end)
    local body = {}
    for _, it in ipairs(list) do
        local value = it.src and SR.Money(it.v) or "no price"
        body[#body + 1] = ("%s x%d  %s%s"):format(it.e.name, it.e.count, value, it.src == "vendor" and " (vendor)" or "")
        row(("%s x%d"):format(it.e.name, it.e.count), priced(value, it.src))
    end
    if #list == 0 then
        body[1] = "Nothing skinned yet."
        row(body[1])
    end

    if countLoot() then
        row("")
        row(KILL_COLOR .. "Kills (mob loot)|r", KILL_COLOR .. SR.Money(lootTotal()) .. "|r")
        local shown = 0
        if s.loot.copper > 0 then
            row("Gold coins", SR.Money(s.loot.copper))
            shown = shown + 1
        end
        local rows, gray = {}, {count = 0, value = 0, unpriced = 0}
        for id, e in pairs(s.loot.items) do
            local p = SR:LootPrice(id, e.ah, e.q)
            if e.q == 0 then
                gray.count = gray.count + e.count
                if p then gray.value = gray.value + p * e.count else gray.unpriced = gray.unpriced + e.count end
            else
                rows[#rows + 1] = {e = e, p = p, v = (p or 0) * e.count}
            end
        end
        table.sort(rows, function(a, b)
            if a.v ~= b.v then return a.v > b.v end
            return a.e.name < b.e.name
        end)
        for _, r in ipairs(rows) do
            row(("%s x%d"):format(r.e.name, r.e.count), r.p and SR.Money(r.v) or "no price")
            shown = shown + 1
        end
        if gray.count > 0 then
            row(("Gray items x%d (vendor)"):format(gray.count), gray.value > 0 and (SR.Money(gray.value) .. "*") or "no price")
            shown = shown + 1
        end
        if shown == 0 then row("Nothing looted yet.") end
    end
    return body, #list, names, values
end

function SR.StatsText()
    local body, _, names, values = lines()
    local total, unpriced = SR.StatsTotal()
    local el = SR.StatsElapsed()
    local perHour = el >= 60 and SR.Money(total / el * 3600) .. "/h" or "..."
    local duration = ("Guide time: %s%s, %d skinned"):format(clock(el), s and s.stoppedAt and " (stopped)" or "", s and s.skins or 0)
    if countLoot() then duration = duration .. (", %d kills"):format(s and s.kills or 0) end
    return {
        duration = duration,
        body = table.concat(body, "\n"),
        names = table.concat(names, "\n"),
        values = table.concat(values, "\n"),
        total = "Total: " .. SR.Money(total) .. (unpriced > 0 and (" (" .. unpriced .. " unpriced)") or ""),
        perHour = "Per hour: " .. perHour,
        count = math.max(1, #names),
    }
end

local function build()
    win = CreateFrame("Frame", "SkinRouteStatsFrame", UIParent, "BasicFrameTemplateWithInset")
    win:SetSize(262, 50 + LINE_H * VISIBLE + 70)
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
    win:SetScript("OnHide", function()
        ticking = nil
        settings().shown = false
    end)
    if win.SetTitle then win:SetTitle("SkinRoute Stats") elseif win.TitleText then win.TitleText:SetText("SkinRoute Stats") end
    local pos = settings().pos
    if pos then win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else win:SetPoint("CENTER", UIParent, "CENTER", 320, 0) end

    win.duration = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    win.duration:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -31)
    local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    b:SetSize(44, 17)
    b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10)
    b:SetText("Reset")
    b:SetScript("OnClick", function() SR.StatsReset() end)
    win.resetButton = b
    win.scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -50)
    win.scroll:SetSize(ROW_W, LINE_H * VISIBLE)
    win.child = CreateFrame("Frame", nil, win.scroll)
    win.child:SetSize(ROW_W, LINE_H * VISIBLE)
    win.scroll:SetScrollChild(win.child)
    win.rows = {}
    win.total = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    win.lootCheck = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    win.lootCheck:SetSize(20, 20)
    win.lootCheck:SetPoint("TOPLEFT", win, "TOPLEFT", 6, -50 - LINE_H * VISIBLE - 4)
    win.lootCheck.text = win.lootCheck:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    win.lootCheck.text:SetPoint("LEFT", win.lootCheck, "RIGHT", 2, 1)
    win.lootCheck.text:SetText("Count mob loot (gray, white, green)")
    win.lootCheck:SetScript("OnClick", function(self)
        settings().countLoot = self:GetChecked() and true or false
        SR:UpdateStats()
    end)
    win.total:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -50 - LINE_H * VISIBLE - 28)
    win.perHour = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    win.perHour:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -50 - LINE_H * VISIBLE - 44)
end

local function tick()
    if not win or not settings().shown or ticking then return end
    ticking = true
    local function loop()
        if not ticking or not settings().shown then
            ticking = nil
            return
        end
        SR:UpdateStats()
        C_Timer.After(1, loop)
    end
    C_Timer.After(1, loop)
end

function SR:UpdateStats()
    if not win or not settings().shown then return end
    local t = SR.StatsText()
    win.lootCheck:SetChecked(countLoot())
    win.duration:SetText(t.duration)
    win.total:SetText(t.total)
    win.perHour:SetText(t.perHour)
    win.child:SetHeight(math.max(LINE_H * VISIBLE, LINE_H * t.count))
    local names, values = {}, {}
    for n in (t.names .. "\n"):gmatch("(.-)\n") do names[#names + 1] = n end
    for v in (t.values .. "\n"):gmatch("(.-)\n") do values[#values + 1] = v end
    for i = 1, math.max(#names, #win.rows) do
        local row = win.rows[i]
        if names[i] and not row then
            row = {
                name = win.child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"),
                value = win.child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"),
            }
            row.name:SetPoint("TOPLEFT", win.child, "TOPLEFT", 2, -(i - 1) * LINE_H)
            row.name:SetWidth(NAME_W)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)
            row.value:SetPoint("TOPRIGHT", win.child, "TOPRIGHT", -2, -(i - 1) * LINE_H)
            row.value:SetJustifyH("RIGHT")
            row.value:SetWordWrap(false)
            win.rows[i] = row
        end
        if row then
            if names[i] then
                row.name:SetText(names[i])
                row.value:SetText(values[i] or "")
                row.name:Show()
                row.value:Show()
            else
                row.name:Hide()
                row.value:Hide()
            end
        end
    end
end

function SR:ToggleStats(show)
    if not win then build() end
    if show == nil then show = not settings().shown end
    win:SetShown(show)
    settings().shown = show
    if show then
        self:UpdateStats()
        tick()
    end
end

function SR:InitStats()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_LOOT")
    pcall(f.RegisterEvent, f, "CHAT_MSG_MONEY")
    pcall(f.RegisterEvent, f, "LOOT_OPENED")
    pcall(f.RegisterEvent, f, "LOOT_CLOSED")
    f:SetScript("OnEvent", function(_, event, message)
        if event == "CHAT_MSG_LOOT" then SR.StatsLoot(message)
        elseif event == "CHAT_MSG_MONEY" then SR.StatsMoney(message)
        else SR.LootEvent(event) end
    end)
    local casts = CreateFrame("Frame")
    SR.castEvents = {}
    for _, ev in ipairs(EVENTS) do
        if pcall(casts.RegisterUnitEvent, casts, ev, "player") then SR.castEvents[#SR.castEvents + 1] = ev end
    end
    casts:SetScript("OnEvent", function(_, event, ...) SR.CastEvent(event, ...) end)
    if settings().shown then self:ToggleStats(true) end
end

function SR.StatsWin()
    return win
end
