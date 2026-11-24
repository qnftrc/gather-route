local addonName, SR = ...

local GRACE = 8
local GATHER_MAX = 30
local LINE_H = 13
local VISIBLE = 8
local NAME_W = 84

local SKINNING_SPELLS = {[8613] = true, [8617] = true, [8618] = true, [10768] = true, [32678] = true, [50305] = true}
local START = {UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true}
local EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
}

local s
local gather
local ticking
local win

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

function SR.StatsTotal()
    local total, unpriced = 0, 0
    if not s then return 0, 0 end
    for id, e in pairs(s.items) do
        local p = SR:ItemPrice(id)
        if p and p > 0 then total = total + p * e.count else unpriced = unpriced + e.count end
    end
    return total, unpriced
end

function SR:StatsStart()
    s = {startedAt = GetTime(), items = {}, skins = 0}
    gather = nil
    self:ReadPrices()
    self:UpdateStats()
end

function SR:StatsStop()
    if s and not s.stoppedAt then s.stoppedAt = GetTime() end
    gather = nil
    self:UpdateStats()
end

function SR.StatsReset()
    if not s then return end
    local live = not s.stoppedAt
    s = {startedAt = GetTime(), items = {}, skins = 0, stoppedAt = (not live) and GetTime() or nil}
    gather = nil
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
            if message:match("^" .. pat .. "$") then mine = true break end
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
    gather.seen = true
    gather.counted[id] = (gather.counted[id] or 0) + n
    SR:UpdateStats()
end

local function lines()
    local names, values = {}, {}
    if not s then return {"No guide yet."}, 0, {"No guide yet."}, {""} end
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
        names[#names + 1] = ("%s x%d"):format(it.e.name, it.e.count)
        values[#values + 1] = value .. (it.src == "vendor" and "*" or "")
    end
    if #list == 0 then
        body[1] = "Nothing skinned yet."
        names[1], values[1] = body[1], ""
    end
    return body, #list, names, values
end

function SR.StatsText()
    local body, _, names, values = lines()
    local total, unpriced = SR.StatsTotal()
    local el = SR.StatsElapsed()
    local perHour = el >= 60 and SR.Money(total / el * 3600) .. "/h" or "..."
    return {
        duration = ("Guide time: %s%s, %d skinned"):format(clock(el), s and s.stoppedAt and " (stopped)" or "", s and s.skins or 0),
        body = table.concat(body, "\n"),
        names = table.concat(names, "\n"),
        values = table.concat(values, "\n"),
        total = "Total: " .. SR.Money(total) .. (unpriced > 0 and (" (" .. unpriced .. " unpriced)") or ""),
        perHour = "Per hour: " .. perHour,
        count = math.max(1, #body),
    }
end

local function build()
    win = CreateFrame("Frame", "SkinRouteStatsFrame", UIParent, "BasicFrameTemplateWithInset")
    win:SetSize(210, 210)
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
    b:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -28)
    b:SetText("Reset")
    b:SetScript("OnClick", function() SR.StatsReset() end)
    win.resetButton = b
    win.scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    win.scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -50)
    win.scroll:SetSize(166, LINE_H * VISIBLE)
    win.child = CreateFrame("Frame", nil, win.scroll)
    win.child:SetSize(166, LINE_H * VISIBLE)
    win.scroll:SetScrollChild(win.child)
    win.rows = {}
    win.total = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    win.total:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -50 - LINE_H * VISIBLE - 8)
    win.perHour = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    win.perHour:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -50 - LINE_H * VISIBLE - 26)
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
    f:SetScript("OnEvent", function(_, _, message) SR.StatsLoot(message) end)
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
