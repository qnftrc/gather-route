local addonName, SR = ...

local skipButton

local function settings()
    SR.db.skipButton = SR.db.skipButton or {}
    return SR.db.skipButton
end

local function savePosition()
    local point, _, relPoint, x, y = skipButton:GetPoint()
    settings().pos = {point, relPoint, x, y}
end

local function build()
    skipButton = CreateFrame("Button", "SkinRouteSkipButton", UIParent, "UIPanelButtonTemplate")
    skipButton:SetSize(90, 28)
    skipButton:SetText("Skip")
    skipButton:SetFrameStrata("HIGH")
    skipButton:SetClampedToScreen(true)
    skipButton:SetMovable(true)
    skipButton:RegisterForDrag("LeftButton")
    skipButton:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
    skipButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    skipButton:SetScript("OnClick", function() SR:SkipZone() end)
    skipButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("SkinRoute: go to the next zone")
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

function SR:ToggleSkipButton(show)
    if not skipButton then build() end
    if show == nil then show = not skipButton:IsShown() end
    skipButton:SetShown(show)
    settings().shown = show
end

function SR:InitSkipButton()
    if settings().shown then self:ToggleSkipButton(true) end
end
