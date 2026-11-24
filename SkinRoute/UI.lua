local addonName, SR = ...

local ui

local ROW, VROW = 24, 20
local VIEW_NAMES = {region = "Region", item = "Item", value = "Value"}
local VIEWS = {
    {"region", "Region", "Choose a region, then the leathers inside it"},
    {"item", "Item", "Choose leathers, regions ranked by mobs"},
    {"value", "Value", "Choose leathers, zones ranked by value (prices set with /sr price)"},
}

local function label(parent, text, point, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint(point, parent, point, x, y)
    fs:SetText(text)
    return fs
end

local function button(parent, text, w, point, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint(point, parent, point, x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function check(parent, text, x, y, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    c:SetSize(24, 24)
    local fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", c, "RIGHT", 2, 1)
    fs:SetText(text)
    c.label = fs
    c:SetScript("OnClick", onClick)
    return c
end

local function editBox(parent, w, x, y, onCommit)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    e:SetAutoFocus(false)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusLost", function(self) onCommit(self:GetText()) end)
    return e
end

local function getCheckRow(pool, parent, i, size, font)
    local row = pool[i]
    if not row then
        row = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        row:SetSize(size, size)
        row.text = row:CreateFontString(nil, "ARTWORK", font)
        row.text:SetPoint("LEFT", row, "RIGHT", 2, 1)
        pool[i] = row
    end
    return row
end

function SR.MatchLetters(query, name)
    local q = SR.normalize(query or "")
    if q == "" then return true end
    local counts = {}
    for ch in SR.normalize(name):gmatch(".") do counts[ch] = (counts[ch] or 0) + 1 end
    for ch in q:gmatch(".") do
        if (counts[ch] or 0) == 0 then return false end
        counts[ch] = counts[ch] - 1
    end
    return true
end

function SR.UIHeight(mode, optionsShown)
    return (optionsShown and 610 or 472) + (mode == "value" and 10 or 0)
end

local function isSelected(id)
    for _, v in ipairs(SR.db.items) do
        if v == id then return true end
    end
    return false
end

local function setSelected(id, on)
    local list = {}
    for _, v in ipairs(SR.db.items) do
        if v ~= id then list[#list + 1] = v end
    end
    if on then list[#list + 1] = id end
    SR.db.items = list
end

local PRICE_TAG = {
    ah = " |cff999999AH|r", vendor = " |cffcc7777vendor|r", manual = " |cff999999manual|r",
}

local function grey(text)
    return "|cff808080" .. text .. "|r"
end

local function rowText(name, count, e, level)
    local usable = e.status == "ok" or e.status == "partial"
    local parts = {usable and name or grey(name), "|cff999999(" .. count .. ")|r"}
    local lv = SR.LevelText(e, level)
    if lv ~= "" then parts[#parts + 1] = lv end
    if e.status == "locked" then
        parts[#parts + 1] = SR.Paint("orange", "needs skinning " .. e.minNeeded)
    elseif e.status == "out" then
        parts[#parts + 1] = grey("out of level range")
    elseif e.status == "partial" then
        parts[#parts + 1] = SR.Paint("orange", ("%d%%"):format(math.floor(e.percent + 0.5)))
    end
    return table.concat(parts, " ")
end

local function valueText(e, anyPrice)
    if anyPrice then return SR.Money(e.value) end
    return ("~%.0f items"):format(e.drops)
end

local function hasRegion(region)
    for _, name in ipairs(SR:GetRegions()) do
        if name == region then return true end
    end
    return false
end

local refreshView, applyMode, applyLayout, refreshFields

local function chooseRegion(region)
    ui.region = region
    SR.db.region = region
    for _, row in ipairs(ui.rows) do row:SetChecked(row.region ~= nil and row.region == region) end
    for _, row in ipairs(ui.valZoneRows) do row:SetChecked(row.region ~= nil and row.region == region) end
    if ui.mode == "region" then
        ui.regionButton:SetText(region)
        ui.regionPopup:Hide()
        refreshView()
    end
end

local function selectedCount()
    return #SR.db.items
end

local function itemButtonText()
    local ids = SR.db.items
    if #ids == 0 then return "Select leathers" end
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = SR.Data.items[id] or tostring(id) end
    table.sort(names)
    local text = names[1]
    if #names > 1 then text = text .. ", " .. names[2] end
    if #names > 2 then text = text .. (" (+%d)"):format(#names - 2) end
    return text
end

local function hideRowsFrom(pool, n)
    for i = n, #pool do
        pool[i].region = nil
        pool[i].itemId = nil
        pool[i]:SetChecked(false)
        pool[i]:Hide()
    end
end

local function fillRegionItems()
    local c = SR:Context()
    local rows = ui.region and SR:RegionItems(ui.region, c) or {}
    for i, row in ipairs(rows) do
        local cb = getCheckRow(ui.rows, ui.listChild, i, ROW, "GameFontHighlight")
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", ui.listChild, "TOPLEFT", 0, -(i - 1) * ROW)
        cb.itemId, cb.region = row.id, nil
        cb:SetScript("OnClick", function(self)
            setSelected(self.itemId, self:GetChecked())
            SR:RefreshZones()
        end)
        local count = row.eval.status == "out" and row.eval.total or row.eval.inBand
        cb.text:SetText(rowText(row.name, count, row.eval, c.level))
        cb:SetChecked(isSelected(row.id))
        cb:Show()
    end
    hideRowsFrom(ui.rows, #rows + 1)
    ui.listChild:SetSize(270, math.max(1, #rows * ROW))
    ui.listTitle:SetText(("Leathers (%d selected)"):format(selectedCount()))
    ui.regionButton:SetText(ui.region or "No region")
end

local function fillRanking()
    local c = SR:Context()
    local rows = SR:RankRegionsByMobs(c)
    local keep
    for i, row in ipairs(rows) do
        local cb = getCheckRow(ui.rows, ui.listChild, i, ROW, "GameFontHighlight")
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", ui.listChild, "TOPLEFT", 0, -(i - 1) * ROW)
        cb.itemId, cb.region = nil, row.region
        cb:SetScript("OnClick", function() chooseRegion(row.region) end)
        local count = row.eval.status == "out" and row.eval.total or row.eval.inBand
        cb.text:SetText(rowText(row.region, count, row.eval, c.level))
        cb:Show()
        if row.region == ui.region then keep = row.region end
    end
    hideRowsFrom(ui.rows, #rows + 1)
    ui.listChild:SetSize(270, math.max(1, #rows * ROW))
    if rows[1] then chooseRegion(keep or rows[1].region) end
    ui.listTitle:SetText(#SR.db.items == 0 and "Select leathers to list the regions"
        or ("Regions, most mobs first (%d)"):format(#rows))
    ui.regionButton:SetText(itemButtonText())
end

local function fillValueItems()
    local query = type(ui.valQuery) == "string" and ui.valQuery or ""
    local all = {}
    for _, it in ipairs(SR:ValueItems()) do
        if SR.MatchLetters(query, it.name) then all[#all + 1] = it end
    end
    for i, it in ipairs(all) do
        local row = getCheckRow(ui.valItemRows, ui.valChild1, i, VROW, "GameFontHighlightSmall")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.valChild1, "TOPLEFT", 0, -(i - 1) * VROW)
        row.itemId = it.id
        row.text:SetText(("%s  %s"):format(it.name, it.price and (SR.Money(it.price) .. (PRICE_TAG[it.src] or "")) or "|cff999999no price|r"))
        row:SetChecked(isSelected(it.id))
        row:SetScript("OnClick", function(self)
            setSelected(self.itemId, self:GetChecked())
            SR:RefreshZones()
        end)
        row:Show()
    end
    hideRowsFrom(ui.valItemRows, #all + 1)
    ui.valChild1:SetSize(300, math.max(1, #all * VROW))
    ui.valTitle1:SetText(("Leathers by value (%d)"):format(#all))
end

local function fillZones()
    local c = SR:Context()
    local rows, _, anyPrice = SR:RankRegions(c)
    local keep
    for i, row in ipairs(rows) do
        local cb = getCheckRow(ui.valZoneRows, ui.valChild2, i, VROW, "GameFontHighlightSmall")
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", ui.valChild2, "TOPLEFT", 0, -(i - 1) * VROW)
        cb.region = row.region
        cb:SetScript("OnClick", function() chooseRegion(row.region) end)
        local e = row.eval
        local parts = {e.status == "locked" and grey(row.region) or row.region}
        local lv = SR.LevelText(e, c.level)
        if lv ~= "" then parts[#parts + 1] = lv end
        if e.status == "locked" then
            parts[#parts + 1] = SR.Paint("orange", "needs skinning " .. e.minNeeded)
        else
            if e.status == "partial" then parts[#parts + 1] = SR.Paint("orange", ("%d%%"):format(math.floor(e.percent + 0.5))) end
            parts[#parts + 1] = valueText(e, anyPrice)
        end
        cb.text:SetText(table.concat(parts, "  "))
        cb:Show()
        if row.region == ui.region then keep = row.region end
    end
    hideRowsFrom(ui.valZoneRows, #rows + 1)
    ui.valChild2:SetSize(300, math.max(1, #rows * VROW))
    if rows[1] then chooseRegion(keep or rows[1].region) end
    ui.valTitle2:SetText(#SR.db.items == 0 and "Select leathers to list the zones"
        or ("Most valuable zones (%d)"):format(#rows))
end

function refreshView()
    if not ui then return end
    if ui.mode == "region" then
        fillRegionItems()
    elseif ui.mode == "item" then
        fillRanking()
    else
        fillValueItems()
        fillZones()
        ui.valInfo:SetText(SR.PriceLine())
    end
end

local function fillRegionPopup()
    local query = ui.regionSearch and ui.regionSearch:GetText() or ""
    local regions = {}
    for _, region in ipairs(SR:GetRegions()) do
        if SR.MatchLetters(query, region) then regions[#regions + 1] = region end
    end
    ui.regionMatches = regions
    ui.regionNone:SetShown(#regions == 0)
    ui.regionChild:SetSize(290, math.max(1, #regions * 20))
    for i, region in ipairs(regions) do
        local b = ui.regionPopupRows[i]
        if not b then
            b = CreateFrame("Button", nil, ui.regionChild)
            b:SetSize(290, 20)
            b:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            b:SetNormalFontObject("GameFontHighlight")
            b:SetHighlightFontObject("GameFontNormal")
            b:SetText(region)
            b:GetFontString():SetPoint("LEFT", 4, 0)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.12)
            ui.regionPopupRows[i] = b
        end
        b:SetText(region)
        b:SetScript("OnClick", function() chooseRegion(region) end)
        b:Show()
    end
    for i = #regions + 1, #ui.regionPopupRows do ui.regionPopupRows[i]:Hide() end
end

local function fillItemPopup()
    local query = type(ui.itemQuery) == "string" and ui.itemQuery or ""
    local totals = SR:ItemTotals()
    local all = {}
    for _, it in ipairs(SR:AllItems()) do
        if SR.MatchLetters(query, it.name) then all[#all + 1] = it end
    end
    ui.itemMatches = #all
    for i, it in ipairs(all) do
        local row = getCheckRow(ui.itemPopupRows, ui.itemChild, i, ROW, "GameFontHighlight")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.itemChild, "TOPLEFT", 4, -(i - 1) * ROW)
        row.itemId = it.id
        row.text:SetText(("%s |cff999999(%d)|r"):format(it.name, totals[it.id] or 0))
        row:SetChecked(isSelected(it.id))
        row:SetScript("OnClick", function(self)
            setSelected(self.itemId, self:GetChecked())
            SR:RefreshZones()
        end)
        row:Show()
    end
    for i = #all + 1, #ui.itemPopupRows do ui.itemPopupRows[i]:Hide() end
    ui.itemChild:SetSize(290, math.max(1, #all * ROW))
    ui.itemNone:SetShown(#all == 0)
end

local function popupFrame()
    local popup = CreateFrame("Frame", nil, ui, "BackdropTemplate")
    popup:SetFrameStrata("DIALOG")
    popup:SetSize(328, 256)
    popup:SetPoint("TOPLEFT", ui.regionButton, "BOTTOMLEFT", 0, -2)
    popup:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    popup:Hide()
    return popup
end

local function buildPopups()
    local rp = popupFrame()
    local rsearch = CreateFrame("EditBox", nil, rp, "InputBoxTemplate")
    rsearch:SetSize(286, 20)
    rsearch:SetPoint("TOPLEFT", 14, -6)
    rsearch:SetAutoFocus(false)
    ui.regionSearch = rsearch
    local rscroll = CreateFrame("ScrollFrame", nil, rp, "UIPanelScrollFrameTemplate")
    rscroll:SetPoint("TOPLEFT", 6, -30)
    rscroll:SetPoint("BOTTOMRIGHT", -26, 6)
    ui.regionNone = rp:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    ui.regionNone:SetPoint("TOPLEFT", 14, -40)
    ui.regionNone:SetText("No match")
    ui.regionNone:Hide()
    ui.regionChild = CreateFrame("Frame", nil, rscroll)
    ui.regionChild:SetSize(290, 1)
    rscroll:SetScrollChild(ui.regionChild)
    ui.regionPopupRows = {}
    ui.regionPopup = rp
    rsearch:SetScript("OnTextChanged", function()
        fillRegionPopup()
        rscroll:SetVerticalScroll(0)
    end)
    rsearch:SetScript("OnEnterPressed", function()
        local first = ui.regionMatches and ui.regionMatches[1]
        if first then chooseRegion(first) end
    end)
    rsearch:SetScript("OnEscapePressed", function() rp:Hide() end)
    rp:SetScript("OnShow", function()
        rsearch:SetText("")
        rsearch:SetFocus()
    end)
    rp:SetScript("OnHide", function() rsearch:ClearFocus() end)

    local ip = popupFrame()
    local isearch = CreateFrame("EditBox", nil, ip, "InputBoxTemplate")
    isearch:SetSize(286, 20)
    isearch:SetPoint("TOPLEFT", 14, -6)
    isearch:SetAutoFocus(false)
    ui.itemSearch = isearch
    local iscroll = CreateFrame("ScrollFrame", nil, ip, "UIPanelScrollFrameTemplate")
    iscroll:SetPoint("TOPLEFT", 6, -30)
    iscroll:SetPoint("BOTTOMRIGHT", -26, 6)
    ui.itemNone = ip:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    ui.itemNone:SetPoint("TOPLEFT", 14, -40)
    ui.itemNone:SetText("No match")
    ui.itemNone:Hide()
    ui.itemChild = CreateFrame("Frame", nil, iscroll)
    ui.itemChild:SetSize(290, 1)
    iscroll:SetScrollChild(ui.itemChild)
    ui.itemPopupRows = {}
    ui.itemPopup = ip
    isearch:SetScript("OnTextChanged", function()
        ui.itemQuery = isearch:GetText()
        fillItemPopup()
        iscroll:SetVerticalScroll(0)
    end)
    isearch:SetScript("OnEscapePressed", function() ip:Hide() end)
    ip:SetScript("OnShow", function()
        isearch:SetText("")
        isearch:SetFocus()
    end)
    ip:SetScript("OnHide", function() isearch:ClearFocus() end)
end

local function buildViewMenu()
    local menu = CreateFrame("Frame", nil, ui, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetSize(300, 128)
    menu:SetPoint("TOPRIGHT", ui.viewButton, "BOTTOMRIGHT", 0, -2)
    menu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    menu:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    menu:Hide()
    for i, d in ipairs(VIEWS) do
        local b = CreateFrame("Button", nil, menu)
        b:SetSize(288, 38)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - (i - 1) * 40)
        local title = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetPoint("TOPLEFT", 6, -4)
        title:SetText(d[2])
        local sub = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        sub:SetPoint("TOPLEFT", 6, -20)
        sub:SetText(d[3])
        b:SetScript("OnClick", function() SR:SetBrowseMode(d[1]) end)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.1)
    end
    ui.viewMenu = menu
end

local function buildValueView()
    ui.valueWidgets = {}
    ui.valItemRows, ui.valZoneRows = {}, {}
    local function add(w)
        ui.valueWidgets[#ui.valueWidgets + 1] = w
        return w
    end
    ui.valTitle1 = add(label(ui, "", "TOPLEFT", 16, -62))
    local search = add(CreateFrame("EditBox", nil, ui, "InputBoxTemplate"))
    search:SetSize(150, 18)
    search:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -20, -58)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function()
        ui.valQuery = search:GetText()
        fillValueItems()
        ui.valScroll1:SetVerticalScroll(0)
    end)
    search:SetScript("OnEscapePressed", function() search:ClearFocus() end)
    ui.valSearch = search
    ui.valScroll1 = add(CreateFrame("ScrollFrame", nil, ui, "UIPanelScrollFrameTemplate"))
    ui.valScroll1:SetPoint("TOPLEFT", ui, "TOPLEFT", 16, -82)
    ui.valScroll1:SetSize(322, VROW * 4)
    ui.valChild1 = CreateFrame("Frame", nil, ui.valScroll1)
    ui.valChild1:SetSize(300, 1)
    ui.valScroll1:SetScrollChild(ui.valChild1)
    ui.valTitle2 = add(label(ui, "", "TOPLEFT", 16, -172))
    ui.valScroll2 = add(CreateFrame("ScrollFrame", nil, ui, "UIPanelScrollFrameTemplate"))
    ui.valScroll2:SetPoint("TOPLEFT", ui, "TOPLEFT", 16, -192)
    ui.valScroll2:SetSize(322, VROW * 4)
    ui.valChild2 = CreateFrame("Frame", nil, ui.valScroll2)
    ui.valChild2:SetSize(300, 1)
    ui.valScroll2:SetScrollChild(ui.valChild2)
    ui.valInfo = add(ui:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"))
    ui.valInfo:SetPoint("TOPLEFT", ui, "TOPLEFT", 16, -276)
end

function applyLayout()
    local value = ui.mode == "value"
    ui.lower:ClearAllPoints()
    ui.lower:SetPoint("TOPLEFT", ui, "TOPLEFT", 0, -(296 + (value and 10 or 0)))
    local shown = SR.db.optionsShown == true
    for _, w in ipairs(ui.optionWidgets) do w:SetShown(shown) end
    ui.optionsButton:SetText(shown and "Options -" or "Options +")
    ui:SetHeight(SR.UIHeight(ui.mode, shown))
end

function applyMode()
    local mode = ui.mode
    local value = mode == "value"
    ui.viewButton:SetText("View: " .. VIEW_NAMES[mode])
    ui.regionLabel:SetText(mode == "region" and "Region" or "Leather")
    ui.regionPopup:Hide()
    ui.itemPopup:Hide()
    ui.viewMenu:Hide()
    ui.regionButton:SetShown(not value)
    ui.listTitle:SetShown(not value)
    ui.listScroll:SetShown(not value)
    ui.noneButton:SetShown(mode == "region")
    ui.allButton:SetShown(mode == "region")
    for _, w in ipairs(ui.valueWidgets) do w:SetShown(value) end
    refreshView()
    applyLayout()
end

local function commitNumber(text, lo, hi)
    local n = tonumber(text)
    if not n then return nil end
    return math.max(lo, math.min(hi, math.floor(n)))
end

function refreshFields()
    local level, simLevel = SR:PlayerLevel()
    local real = (UnitLevel and UnitLevel("player")) or level
    ui.levelEdit:SetText(tostring(level))
    ui.levelNote:SetText(simLevel and ("simulated (you are " .. real .. ")") or "your level")
    local skill, simSkill = SR:PlayerSkill()
    local info = SR:ReadSkill()
    ui.skillEdit:SetText(skill and tostring(skill) or "")
    ui.skillNote:SetText(simSkill and ("simulated (" .. SR.SkillHave(info) .. ")") or SR.SkillShort(info))
    ui.lowEdit:SetText(("%+d"):format(SR.db.bandLow))
    ui.highEdit:SetText(("%+d"):format(SR.db.bandHigh))
    ui.radiusEdit:SetText(tostring(SR.db.zoneRadius))
end

local function refreshAll()
    SR:RefreshZones()
end

local function commitLevel(text)
    local n = commitNumber(text, 1, 80)
    local real = UnitLevel and UnitLevel("player")
    SR.db.level = (n and n ~= real) and n or nil
    refreshAll()
end

local function commitSkill(text)
    local n = commitNumber(text, 1, 300)
    SR.db.skill = (n and n ~= SR:ReadSkill().value) and n or nil
    refreshAll()
end

local function commitBand()
    local lo, hi = commitNumber(ui.lowEdit:GetText(), -80, 80), commitNumber(ui.highEdit:GetText(), -80, 80)
    if lo and hi then
        if lo > hi then lo, hi = hi, lo end
        SR.db.bandLow, SR.db.bandHigh = lo, hi
    end
    refreshAll()
end

local function commitRadius(text)
    local n = commitNumber(text, 50, 1000)
    if n and n ~= SR.db.zoneRadius then
        SR.db.zoneRadius = n
        if SR.shown then SR:ShowZones(SR.shown.region) end
    end
    refreshFields()
end

function SR.UIGenerate()
    if #SR.db.items == 0 then return SR:Say("Select at least one leather.") end
    local region = ui.region
    if not region then return SR:Say("Select a region.") end
    SR:ShowZones(region, true)
end

local function build()
    ui = CreateFrame("Frame", "SkinRouteFrame", UIParent, "BasicFrameTemplateWithInset")
    ui:SetSize(380, SR.UIHeight("region", false))
    ui:SetPoint("CENTER")
    ui:SetMovable(true)
    ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", ui.StartMoving)
    ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
    ui:SetClampedToScreen(true)
    ui:SetFrameStrata("MEDIUM")
    if ui.SetTitle then ui:SetTitle("SkinRoute") elseif ui.TitleText then ui.TitleText:SetText("SkinRoute") end
    tinsert(UISpecialFrames, "SkinRouteFrame")
    ui.rows = {}

    ui.statsButton = button(ui, "Stats", 60, "TOPRIGHT", -34, -3, function() SR:ToggleStats() end)
    ui.regionLabel = label(ui, "Region", "TOPLEFT", 16, -34)
    ui.viewButton = button(ui, "View: Region", 116, "TOPRIGHT", -16, -29, function()
        ui.viewMenu:SetShown(not ui.viewMenu:IsShown())
    end)
    ui.regionButton = button(ui, "", 348, "TOPLEFT", 16, -52, function()
        if ui.mode == "item" then
            ui.itemPopup:SetShown(not ui.itemPopup:IsShown())
        else
            ui.regionPopup:SetShown(not ui.regionPopup:IsShown())
        end
    end)
    buildPopups()
    buildValueView()
    buildViewMenu()

    ui.listTitle = label(ui, "Leathers", "TOPLEFT", 16, -84)
    ui.noneButton = button(ui, "None", 50, "TOPRIGHT", -16, -80, function()
        SR.db.items = {}
        refreshAll()
    end)
    ui.allButton = button(ui, "All", 50, "TOPRIGHT", -70, -80, function()
        local ids = {}
        for _, row in ipairs(ui.region and SR:RegionItems(ui.region, SR:Context()) or {}) do ids[#ids + 1] = row.id end
        SR.db.items = ids
        refreshAll()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, ui, "UIPanelScrollFrameTemplate")
    ui.listScroll = scroll
    scroll:SetPoint("TOPLEFT", 16, -104)
    scroll:SetSize(320, 180)
    ui.listChild = CreateFrame("Frame", nil, scroll)
    ui.listChild:SetSize(270, 1)
    scroll:SetScrollChild(ui.listChild)

    ui.lower = CreateFrame("Frame", nil, ui)
    ui.lower:SetPoint("TOPLEFT", ui, "TOPLEFT", 0, -296)
    ui.lower:SetSize(380, 260)
    ui.optionWidgets = {}
    local function option(w)
        ui.optionWidgets[#ui.optionWidgets + 1] = w
        return w
    end

    label(ui.lower, "Level", "TOPLEFT", 16, -4)
    ui.levelEdit = editBox(ui.lower, 40, 74, 0, commitLevel)
    button(ui.lower, "My level", 90, "TOPLEFT", 122, -1, function()
        SR.db.level = nil
        refreshAll()
    end)
    ui.levelNote = ui.lower:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ui.levelNote:SetPoint("TOPLEFT", ui.lower, "TOPLEFT", 222, -4)
    ui.levelNote:SetTextColor(1, 0.6, 0.24)

    label(ui.lower, "Skinning", "TOPLEFT", 16, -32)
    ui.skillEdit = editBox(ui.lower, 40, 74, -28, commitSkill)
    ui.skillButton = button(ui.lower, "My skill", 90, "TOPLEFT", 122, -29, function()
        SR.db.skill = nil
        refreshAll()
    end)
    ui.skillNote = ui.lower:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ui.skillNote:SetPoint("TOPLEFT", ui.lower, "TOPLEFT", 222, -32)
    ui.skillNote:SetTextColor(1, 0.6, 0.24)

    ui.optionsButton = button(ui.lower, "Options +", 100, "TOPLEFT", 16, -58, function()
        SR.db.optionsShown = not (SR.db.optionsShown == true)
        applyLayout()
    end)

    ui.showMap = option(check(ui.lower, "Draw zones on the world map", 12, -86, function(self)
        SR.db.showMap = self:GetChecked() and true or false
        SR:UpdateOverlay()
    end))
    ui.chat = option(check(ui.lower, "Show SkinRoute messages in the chat", 12, -110, function(self)
        SR.db.chat = self:GetChecked() and true or false
    end))
    ui.band = option(check(ui.lower, "Only mobs from level", 12, -134, function(self)
        SR.db.bandOnly = self:GetChecked() and true or false
        refreshAll()
    end))
    ui.lowEdit = option(editBox(ui.lower, 40, 176, -136, commitBand))
    option(label(ui.lower, "to", "TOPLEFT", 224, -140))
    ui.highEdit = option(editBox(ui.lower, 40, 246, -136, commitBand))
    option(label(ui.lower, "Zone radius", "TOPLEFT", 16, -170))
    ui.radiusEdit = option(editBox(ui.lower, 48, 96, -166, commitRadius))
    option(label(ui.lower, "yd", "TOPLEFT", 150, -170))

    ui.arrivalText = option(label(ui.lower, "", "TOPLEFT", 16, -200))
    local slider = option(CreateFrame("Slider", nil, ui.lower, "OptionsSliderTemplate"))
    slider:SetPoint("TOPLEFT", ui.lower, "TOPLEFT", 150, -202)
    slider:SetSize(210, 16)
    slider:SetMinMaxValues(10, 500)
    slider:SetValueStep(10)
    slider:SetObeyStepOnDrag(true)
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end
    slider:SetScript("OnValueChanged", function(_, value)
        SR.db.arrival = math.floor(value + 0.5)
        ui.arrivalText:SetText(("Arrival distance: %d yd"):format(SR.db.arrival))
    end)
    ui.slider = slider

    ui.generate = button(ui, "Generate", 100, "BOTTOMLEFT", 16, 40, function() SR.UIGenerate() end)
    ui.skip = button(ui, "Skip", 100, "BOTTOM", 0, 40, function() SR:SkipZone() end)
    ui.stop = button(ui, "Stop", 100, "BOTTOMRIGHT", -16, 40, function() SR:StopGuide() end)
    ui.status = ui:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ui.status:SetPoint("BOTTOM", ui, "BOTTOM", 0, 16)

    ui:SetScript("OnShow", function()
        ui.showMap:SetChecked(SR.db.showMap ~= false)
        ui.chat:SetChecked(SR.db.chat == true)
        ui.band:SetChecked(SR.db.bandOnly ~= false)
        ui.slider:SetValue(SR.db.arrival)
        refreshFields()
        refreshView()
        SR:UpdateUI()
    end)

    ui.mode = (SR.db.browse == "item" or SR.db.browse == "value") and SR.db.browse or "region"
    local region = SR:GetCurrentRegion()
    if not (region and hasRegion(region)) then
        region = SR.db.region
        if not (region and hasRegion(region)) then region = SR:GetRegions()[1] end
    end
    ui.region = region or false
    applyMode()
    fillRegionPopup()
    fillItemPopup()
    ui:Hide()
end

function SR:UpdateUI()
    if not ui or not ui:IsShown() then return end
    local g = self.guide
    ui.skip:SetEnabled(g ~= nil)
    ui.stop:SetEnabled(g ~= nil)
    ui.generate:SetEnabled(not self.computing)
    if self.computing then
        ui.status:SetText("Computing zones...")
    elseif g and self.shown and self.shown.region == g.region then
        local index = 0
        for i, row in ipairs(self.shown.rows) do
            if row == g.row then index = i end
        end
        ui.status:SetText(("%s: zone %d / %d%s"):format(g.region, index, #self.shown.rows, g.arrived and " (arrived)" or ""))
    elseif g then
        ui.status:SetText(g.region .. ": guiding")
    else
        ui.status:SetText("No active guide")
    end
end

function SR:RefreshUI()
    if not ui or not ui:IsShown() then return end
    refreshFields()
    refreshView()
end

function SR:ToggleUI()
    if not ui then build() end
    ui:SetShown(not ui:IsShown())
end

function SR:SetBrowseMode(mode)
    if not ui then build() end
    ui.mode = (mode == "item" or mode == "value") and mode or "region"
    SR.db.browse = ui.mode
    applyMode()
end

function SR:InitUI()
    local f = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL"}) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", function()
        SR:RefreshZones()
    end)
end
