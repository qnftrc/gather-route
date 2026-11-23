local addonName, HR = ...

local ui
local dirty = false -- the user typed a start position

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

local function selectedHerbs()
    local list = {}
    for _, row in ipairs(ui.rows) do
        if row:IsShown() and row:GetChecked() then list[#list + 1] = row.herb end
    end
    return list
end

local function updateHerbCount()
    ui.herbTitle:SetText(("%s (%d selected)"):format(HR.categories[ui.category].label, #selectedHerbs()))
end

local function getRow(i)
    local row = ui.rows[i]
    if not row then
        row = CreateFrame("CheckButton", nil, ui.herbChild, "UICheckButtonTemplate")
        row:SetSize(24, 24)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.text:SetPoint("LEFT", row, "RIGHT", 2, 1)
        ui.rows[i] = row
    end
    return row
end

local function fillHerbs(region)
    local herbs = HR:GetHerbs(region, ui.category)
    local saved = (ui.category == "ores" and HR.db.ores or HR.db.herbs)[region] or {}
    for i, herb in ipairs(herbs) do
        local row = getRow(i)
        row:SetScript("OnClick", updateHerbCount)
        row.region = nil
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.herbChild, "TOPLEFT", 0, -(i - 1) * 24)
        row.herb = herb
        row.text:SetText(("%s |cff999999(%d)|r"):format(herb, HR:CountPoints(region, herb, ui.category)))
        row:SetChecked(saved[herb] and true or false)
        row:Show()
    end
    for i = #herbs + 1, #ui.rows do ui.rows[i]:Hide() end
    ui.herbChild:SetSize(270, math.max(1, #herbs * 24))
    updateHerbCount()
end

local function chooseRankedRegion(region)
    ui.region = region
    for _, row in ipairs(ui.rows) do row:SetChecked(row.region ~= nil and row.region == region) end
end

local function setRegion(region)
    if ui.mode == "item" then return chooseRankedRegion(region) end
    ui.region = region
    ui.regionButton:SetText(HR.RegionLabel(region))
    ui.regionPopup:Hide()
    fillHerbs(region)
end

local function fillPosition()
    local m, x, y = HR:GetPlayerPosition()
    if not m then return end
    ui.x:SetText(("%.1f"):format(x))
    ui.y:SetText(("%.1f"):format(y))
    dirty = false
end

-- Letters typed in the search box must all be present in the region name, in any
-- order; a letter typed twice needs two occurrences. Case, spaces and punctuation
-- are ignored.
function HR.MatchRegion(query, name)
    local q = HR.normalize(query or "")
    if q == "" then return true end
    local counts = {}
    for ch in HR.normalize(name):gmatch(".") do counts[ch] = (counts[ch] or 0) + 1 end
    for ch in q:gmatch(".") do
        if (counts[ch] or 0) == 0 then return false end
        counts[ch] = counts[ch] - 1
    end
    return true
end

local function fillRegionPopup()
    local query = ui.regionSearch and ui.regionSearch:GetText() or ""
    local regions = {}
    for _, region in ipairs(HR:GetRegions(ui.category)) do
        if HR.MatchRegion(query, HR.RegionLabel(region)) or HR.MatchRegion(query, region) then regions[#regions + 1] = region end
    end
    ui.regionMatches = regions
    if ui.regionNone then ui.regionNone:SetShown(#regions == 0) end
    local child = ui.regionChild
    child:SetSize(290, #regions * 20)
    for i, region in ipairs(regions) do
        local b = ui.regionRows[i]
        if not b then
            b = CreateFrame("Button", nil, child)
            b:SetSize(290, 20)
            b:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            b:SetNormalFontObject("GameFontHighlight")
            b:SetHighlightFontObject("GameFontNormal")
            b:SetText(HR.RegionLabel(region))
            b:GetFontString():SetPoint("LEFT", 4, 0)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.12)
            ui.regionRows[i] = b
        end
        b:SetText(HR.RegionLabel(region))
        b:SetScript("OnClick", function() ui.setRegion(region) end)
        b:Show()
    end
    for i = #regions + 1, #ui.regionRows do ui.regionRows[i]:Hide() end
end

local function itemSelection()
    HR.db.browseItems = HR.db.browseItems or {}
    HR.db.browseItems[ui.category] = HR.db.browseItems[ui.category] or {}
    return HR.db.browseItems[ui.category]
end

local function selectedItems()
    local list, sel = {}, itemSelection()
    for _, e in ipairs(HR:GetAllItems(ui.category)) do
        if sel[e.item] then list[#list + 1] = e.item end
    end
    return list
end

local function itemButtonText()
    local items = selectedItems()
    local noun = HR.categories[ui.category].item
    if #items == 0 then return "Select " .. noun .. "s" end
    local text = items[1]
    if #items > 1 then text = text .. ", " .. items[2] end
    if #items > 2 then text = text .. (" (+%d)"):format(#items - 2) end
    return text
end

local function refreshRanking(top)
    local items = selectedItems()
    local ranking = HR:RankRegions(ui.category, items)
    ui.ranking = ranking
    for i, e in ipairs(ranking) do
        local row = getRow(i)
        row:SetScript("OnClick", function() chooseRankedRegion(e.region) end)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.herbChild, "TOPLEFT", 0, -(i - 1) * 24)
        row.herb, row.region = nil, e.region
        row.text:SetText(("%s |cff999999(%d)|r"):format(HR.RegionLabel(e.region), e.total))
        row:Show()
    end
    for i = #ranking + 1, #ui.rows do
        ui.rows[i].region = nil
        ui.rows[i]:SetChecked(false)
        ui.rows[i]:Hide()
    end
    ui.herbChild:SetSize(270, math.max(1, #ranking * 24))
    local keep
    if not top then
        for _, e in ipairs(ranking) do if e.region == ui.region then keep = e.region end end
    end
    if ranking[1] then chooseRankedRegion(keep or ranking[1].region) end
    ui.herbTitle:SetText(#items == 0 and "Select items to list the regions"
        or ("Regions, most points first (%d)"):format(#ranking))
    ui.regionButton:SetText(itemButtonText())
end

local function fillItemPopup()
    local query = type(ui.itemQuery) == "string" and ui.itemQuery or ""
    local all, sel = {}, itemSelection()
    for _, e in ipairs(HR:GetAllItems(ui.category)) do
        if HR.MatchRegion(query, e.item) then all[#all + 1] = e end
    end
    ui.itemMatches = #all
    for i, e in ipairs(all) do
        local row = ui.itemRows[i]
        if not row then
            row = CreateFrame("CheckButton", nil, ui.itemChild, "UICheckButtonTemplate")
            row:SetSize(24, 24)
            row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            row.text:SetPoint("LEFT", row, "RIGHT", 2, 1)
            ui.itemRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.itemChild, "TOPLEFT", 4, -(i - 1) * 24)
        row.item = e.item
        row.text:SetText(("%s |cff999999(%d)|r"):format(e.item, e.total))
        row:SetChecked(sel[e.item] and true or false)
        row:SetScript("OnClick", function(self)
            itemSelection()[self.item] = self:GetChecked() and true or nil
            refreshRanking(true)
        end)
        row:Show()
    end
    for i = #all + 1, #ui.itemRows do ui.itemRows[i]:Hide() end
    ui.itemChild:SetSize(290, math.max(1, #all * 24))
    if ui.itemNone then ui.itemNone:SetShown(#all == 0) end
end

local function applyMode()
    local item = ui.mode == "item"
    ui.byItem:SetChecked(item)
    ui.regionLabel:SetText(item and (HR.categories[ui.category].item:gsub("^%l", string.upper)) or "Region")
    ui.regionPopup:Hide()
    ui.itemPopup:Hide()
    ui.noneButton:SetShown(not item)
    ui.allButton:SetShown(not item)
    if item then
        fillItemPopup()
        refreshRanking()
    else
        ui.regionButton:SetText(HR.RegionLabel(ui.region))
        fillHerbs(ui.region)
    end
end

local function buildItemPopup()
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
    local search = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    search:SetSize(286, 20)
    search:SetPoint("TOPLEFT", 14, -6)
    search:SetAutoFocus(false)
    ui.itemSearch = search
    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -30)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    ui.itemNone = popup:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    ui.itemNone:SetPoint("TOPLEFT", 14, -40)
    ui.itemNone:SetText("No match")
    ui.itemNone:Hide()
    search:SetScript("OnTextChanged", function()
        ui.itemQuery = search:GetText()
        fillItemPopup()
        scroll:SetVerticalScroll(0)
    end)
    search:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup:SetScript("OnShow", function()
        search:SetText("")
        search:SetFocus()
    end)
    popup:SetScript("OnHide", function() search:ClearFocus() end)
    ui.itemChild = CreateFrame("Frame", nil, scroll)
    ui.itemChild:SetSize(290, 1)
    scroll:SetScrollChild(ui.itemChild)
    ui.itemRows = {}
    ui.itemPopup = popup
end

local function buildRegionPopup()
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

    local search = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    search:SetSize(286, 20)
    search:SetPoint("TOPLEFT", 14, -6)
    search:SetAutoFocus(false)
    ui.regionSearch = search

    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -30)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    ui.regionScroll = scroll
    ui.regionNone = popup:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    ui.regionNone:SetPoint("TOPLEFT", 14, -40)
    ui.regionNone:SetText("No match")
    ui.regionNone:Hide()
    ui.regionChild = CreateFrame("Frame", nil, scroll)
    ui.regionChild:SetSize(290, 1)
    scroll:SetScrollChild(ui.regionChild)
    ui.regionRows = {}
    ui.setRegion = setRegion
    ui.regionPopup = popup
    search:SetScript("OnTextChanged", function()
        fillRegionPopup()
        scroll:SetVerticalScroll(0)
    end)
    search:SetScript("OnEnterPressed", function()
        local first = ui.regionMatches and ui.regionMatches[1]
        if first then setRegion(first) end
    end)
    search:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup:SetScript("OnShow", function()
        search:SetText("")
        search:SetFocus()
    end)
    popup:SetScript("OnHide", function() search:ClearFocus() end)
    fillRegionPopup()
end

local function hasData(region, category)
    for _, name in ipairs(HR:GetRegions(category)) do
        if name == region then return true end
    end
    return false
end

local function setCategory(category)
    ui.category = category
    HR.db.category = category
    ui.catHerbs:SetChecked(category == "herbs")
    ui.catOres:SetChecked(category == "ores")
    ui.isolate.label:SetText("Keep only " .. HR.categories[category].spellName .. " tracking during a route")
    local region = ui.region
    if not region or not hasData(region, category) then
        local current = HR:GetCurrentRegion()
        region = (current and hasData(current, category) and current) or HR:GetRegions(category)[1]
    end
    fillRegionPopup()
    if ui.mode == "item" then
        ui.region = region
        applyMode()
    else
        setRegion(region)
    end
end

local function build()
    ui = CreateFrame("Frame", "HerbRouteFrame", UIParent, "BasicFrameTemplateWithInset")
    ui:SetSize(360, 672)
    ui:SetPoint("CENTER")
    ui:SetMovable(true)
    ui:EnableMouse(true)
    ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", ui.StartMoving)
    ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
    ui:SetClampedToScreen(true)
    ui:SetFrameStrata("MEDIUM")
    if ui.SetTitle then ui:SetTitle("HerbRoute") elseif ui.TitleText then ui.TitleText:SetText("HerbRoute") end
    tinsert(UISpecialFrames, "HerbRouteFrame")
    ui.rows = {}

    ui.regionLabel = label(ui, "Region", "TOPLEFT", 16, -34)
    ui.catHerbs = check(ui, "Herbs", 96, -30, function() setCategory("herbs") end)
    ui.catOres = check(ui, "Ores", 166, -30, function() setCategory("ores") end)
    ui.byItem = check(ui, "By item", 240, -30, function(self)
        ui.mode = self:GetChecked() and "item" or "region"
        HR.db.browse = ui.mode
        applyMode()
    end)
    ui.regionButton = button(ui, "", 328, "TOPLEFT", 16, -52, function()
        if ui.mode == "item" then
            ui.itemPopup:SetShown(not ui.itemPopup:IsShown())
        else
            ui.regionPopup:SetShown(not ui.regionPopup:IsShown())
        end
    end)
    buildRegionPopup()
    buildItemPopup()

    ui.herbTitle = label(ui, "Herbs", "TOPLEFT", 16, -84)
    ui.noneButton = button(ui, "None", 50, "TOPRIGHT", -16, -80, function()
        for _, row in ipairs(ui.rows) do row:SetChecked(false) end
        updateHerbCount()
    end)
    ui.allButton = button(ui, "All", 50, "TOPRIGHT", -70, -80, function()
        for _, row in ipairs(ui.rows) do if row:IsShown() then row:SetChecked(true) end end
        updateHerbCount()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, ui, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -104)
    scroll:SetSize(300, 180)
    ui.herbChild = CreateFrame("Frame", nil, scroll)
    ui.herbChild:SetSize(270, 1)
    scroll:SetScrollChild(ui.herbChild)

    label(ui, "Start position (%)", "TOPLEFT", 16, -296)
    local function editBox(x)
        local e = CreateFrame("EditBox", nil, ui, "InputBoxTemplate")
        e:SetSize(48, 20)
        e:SetPoint("TOPLEFT", ui, "TOPLEFT", x, -318)
        e:SetAutoFocus(false)
        e:SetScript("OnTextChanged", function(_, userInput) if userInput then dirty = true end end)
        return e
    end
    ui.x = editBox(26)
    ui.y = editBox(86)
    label(ui, "X", "TOPLEFT", 16, -320)
    label(ui, "Y", "TOPLEFT", 76, -320)
    button(ui, "My position", 100, "TOPLEFT", 150, -317, function()
        fillPosition()
        local region = HR:GetCurrentRegion()
        if region and hasData(region, ui.category) then setRegion(region) end
    end)

    ui.showMap = check(ui, "Draw route on the world map", 12, -346, function(self)
        HR.db.showMap = self:GetChecked() and true or false
        HR:UpdateOverlay()
    end)
    ui.showMini = check(ui, "Draw route on the minimap", 12, -370, function(self)
        HR.db.showMinimap = self:GetChecked() and true or false
        HR:UpdateOverlay()
    end)

    ui.isolate = check(ui, "Keep only Find Herbs tracking during a route", 12, -394, function(self)
        HR.db.isolateTracking = self:GetChecked() and true or false
        if not HR.db.isolateTracking then
            HR:RestoreTracking()
        elseif HR.route then
            HR:IsolateTracking()
        end
    end)

    ui.verify = check(ui, "Verify the next point on the minimap", 12, -418, function(self)
        if self:GetChecked() then
            HR.db.verify = HR.db.verifyLast or "report"
        else
            if HR.db.verify ~= "off" then HR.db.verifyLast = HR.db.verify end
            HR.db.verify = "off"
        end
    end)

    ui.reroute = check(ui, "Reorder the points ahead after removals", 12, -442, function(self)
        HR.db.reroute = self:GetChecked() and true or false
    end)

    ui.revive = check(ui, "Put points back in the route when they reappear", 12, -466, function(self)
        HR.db.revive = self:GetChecked() and true or false
    end)

    ui.nearest = check(ui, "Go to the nearest filled point first", 12, -490, function(self)
        HR.db.nearest = self:GetChecked() and true or false
    end)

    ui.combat = check(ui, "Probe the minimap during combat", 12, -514, function(self)
        HR.db.verifyCombat = self:GetChecked() and true or false
    end)

    ui.chat = check(ui, "Show HerbRoute messages in the chat", 12, -538, function(self)
        HR.db.chat = self:GetChecked() and true or false
    end)

    ui.radiusText = label(ui, "", "TOPLEFT", 16, -574)
    local slider = CreateFrame("Slider", nil, ui, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", ui, "TOPLEFT", 150, -576)
    slider:SetSize(190, 16)
    slider:SetMinMaxValues(5, 40)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end
    slider:SetScript("OnValueChanged", function(_, value)
        HR.db.radius = math.floor(value + 0.5)
        ui.radiusText:SetText(("Arrival distance: %d yd"):format(HR.db.radius))
    end)
    ui.slider = slider

    ui.generate = button(ui, "Generate", 100, "BOTTOMLEFT", 16, 40, function() HR.UIGenerate() end)
    function HR.UIGenerate()
        local item = ui.mode == "item"
        local herbs = item and selectedItems() or selectedHerbs()
        if #herbs == 0 then return HR:Print("Select at least one " .. HR.categories[ui.category].item .. ".") end
        if item and not (ui.ranking and #ui.ranking > 0) then
            return HR:Print("No region has the selected " .. HR.categories[ui.category].item .. "s.")
        end
        local start
        if dirty then
            local x, y = tonumber(ui.x:GetText()), tonumber(ui.y:GetText())
            if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
                return HR:Print("X and Y must be numbers between 0 and 100.")
            end
            start = {x = x, y = y}
        end
        HR:GenerateRoute(ui.region, herbs, start, ui.category)
    end
    button(ui, "Stats", 60, "TOPRIGHT", -34, -3, function() HR:ToggleStats() end)
    ui.skip = button(ui, "Skip", 100, "BOTTOM", 0, 40, function() HR:SkipPoint() end)
    ui.stop = button(ui, "Stop", 100, "BOTTOMRIGHT", -16, 40, function() HR:StopRoute() end)

    ui.status = ui:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ui.status:SetPoint("BOTTOM", ui, "BOTTOM", 0, 16)

    ui:SetScript("OnShow", function()
        ui.showMap:SetChecked(HR.db.showMap)
        ui.showMini:SetChecked(HR.db.showMinimap)
        ui.isolate:SetChecked(HR.db.isolateTracking)
        ui.verify:SetChecked(HR.db.verify ~= "off")
        ui.reroute:SetChecked(HR.db.reroute == true)
        ui.revive:SetChecked(HR.db.revive ~= false)
        ui.nearest:SetChecked(HR.db.nearest ~= false)
        ui.combat:SetChecked(HR.db.verifyCombat == true)
        ui.chat:SetChecked(HR.db.chat ~= false)
        ui.byItem:SetChecked(ui.mode == "item")
        ui.slider:SetValue(HR.db.radius)
        if not dirty then fillPosition() end
        HR:UpdateUI()
    end)

    ui.category = HR.categories[HR.db.category] and HR.db.category or "herbs"
    local region = HR:GetCurrentRegion()
    if not (region and hasData(region, ui.category)) then
        region = HR.db.region
        if not (region and hasData(region, ui.category)) then region = HR:GetRegions(ui.category)[1] end
    end
    ui.region = region
    ui.mode = HR.db.browse == "item" and "item" or "region"
    setCategory(ui.category)
end

function HR:UpdateUI()
    if not ui or not ui:IsShown() then return end
    local active = self.route ~= nil
    ui.skip:SetEnabled(active)
    ui.stop:SetEnabled(active)
    ui.generate:SetEnabled(not self.generating)
    if self.generating then
        ui.status:SetText("Computing route...")
    elseif active then
        local i, n = self:GetProgress()
        local removed = self.route.removedCount or 0
        ui.status:SetText(("%s: point %d / %d%s"):format(HR.RegionLabel(self.route.region), i, n,
            removed > 0 and (", " .. removed .. " removed") or ""))
    else
        ui.status:SetText("No active route")
    end
end

local skipButton

local function settings()
    HR.db.skipButton = HR.db.skipButton or {}
    return HR.db.skipButton
end

local function savePosition()
    local point, _, relPoint, x, y = skipButton:GetPoint()
    settings().pos = {point, relPoint, x, y}
end

local function buildSkipButton()
    skipButton = CreateFrame("Button", "HerbRouteSkipButton", UIParent, "UIPanelButtonTemplate")
    skipButton:SetSize(90, 28)
    skipButton:SetText("Skip")
    skipButton:SetFrameStrata("HIGH")
    skipButton:SetClampedToScreen(true)
    skipButton:SetMovable(true)
    skipButton:RegisterForDrag("LeftButton")
    skipButton:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    skipButton:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() end)
    skipButton:SetScript("OnClick", function() HR:SkipPoint() end)
    skipButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("HerbRoute: skip the current point")
        GameTooltip:AddLine("Shift-drag to move. Bind a key in Key Bindings > AddOns.", 1, 1, 1)
        GameTooltip:Show()
    end)
    skipButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local pos = settings().pos
    if pos then
        skipButton:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        skipButton:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end
end

function HR:ToggleSkipButton(show)
    if not skipButton then buildSkipButton() end
    if show == nil then show = not skipButton:IsShown() end
    skipButton:SetShown(show)
    settings().shown = show
end

function HR:InitSkipButton()
    if settings().shown then self:ToggleSkipButton(true) end
end

function HR:ToggleUI()
    if not ui then build() end
    ui:SetShown(not ui:IsShown())
end

function HR:SetBrowseMode(mode)
    if not ui then build() end
    ui.mode = mode == "item" and "item" or "region"
    HR.db.browse = ui.mode
    applyMode()
end

function HR:ToggleBrowseItem(item)
    if not ui then build() end
    local sel = itemSelection()
    sel[item] = not sel[item] or nil
    if ui.mode == "item" then fillItemPopup() refreshRanking(true) end
end

function HR:SelectBrowseRegion(region)
    if ui and ui.mode == "item" then chooseRankedRegion(region) end
end

function HR:BrowseState()
    return ui and ui.mode, ui and ui.ranking, ui and ui.region
end

function HR:BrowseItemSearch(query)
    if not ui then build() end
    ui.itemQuery = query or ""
    fillItemPopup()
    return ui.itemMatches
end
