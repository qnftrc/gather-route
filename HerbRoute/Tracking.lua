local addonName, HR = ...

-- While a route runs, only the tracking of its category (Find Herbs or Find Minerals) stays on; the player's own
-- configuration is saved in HerbRouteDB.trackingSnapshot and put back when the
-- route stops (also after a /reload or a crash, at the next login).

local function api()
    return C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo and C_Minimap.SetTracking
end

local function currentCategory(category)
    category = category or (HR.route and HR.route.category) or "herbs"
    return HR.categories[category] or HR.categories.herbs
end

local function wantedName(category)
    local c = currentCategory(category)
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, c.spell)
        if ok then name = n end
    elseif GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, c.spell)
        if ok then name = n end
    end
    return name or c.spellName
end

local function list()
    local out = {}
    local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
    if not ok or type(n) ~= "number" then return out end
    for i = 1, n do
        local ok2, a, b, c = pcall(C_Minimap.GetTrackingInfo, i)
        if ok2 and a ~= nil then
            if type(a) == "table" then
                out[#out + 1] = {index = i, name = a.name, active = a.active and true or false, spellID = a.spellID}
            else
                out[#out + 1] = {index = i, name = a, active = c and true or false}
            end
        end
    end
    return out
end

local function key(t)
    if t.spellID and t.spellID ~= 0 then return "s" .. t.spellID end
    return "n" .. HR.normalize(tostring(t.name))
end

local function isWanted(t, wanted, category)
    if t.spellID == currentCategory(category).spell then return true end
    return HR.normalize(tostring(t.name)) == wanted
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

function HR:IsolateTracking(category)
    if not self.db.isolateTracking then return end
    if self.db.trackingSnapshot then return end
    if not api() then return end
    if inCombat() then
        self.pendingTracking = "isolate"
        return
    end

    local items = list()
    local wanted = HR.normalize(wantedName(category))
    local herbs
    for _, t in ipairs(items) do
        if isWanted(t, wanted, category) then herbs = t end
    end
    if not herbs then
        self:Print(currentCategory(category).spellName .. " tracking is not available: the other trackings are left unchanged.")
        return
    end

    local snapshot = {}
    for _, t in ipairs(items) do
        if t.active then snapshot[#snapshot + 1] = {name = t.name, spellID = t.spellID} end
    end
    self.db.trackingSnapshot = snapshot

    local switched = 0
    for _, t in ipairs(items) do
        if t.active and t ~= herbs then
            pcall(C_Minimap.SetTracking, t.index, false)
            switched = switched + 1
        end
    end
    if not herbs.active then pcall(C_Minimap.SetTracking, herbs.index, true) end
    self:Print(("Tracking: only %s stays on while the route runs (%d other(s) switched off)."):format(tostring(herbs.name), switched))
end

function HR:RestoreTracking()
    local snapshot = self.db.trackingSnapshot
    if not snapshot then return end
    if not api() then
        self.db.trackingSnapshot = nil
        return
    end
    if inCombat() then
        self.pendingTracking = "restore"
        return
    end

    local want = {}
    for _, s in ipairs(snapshot) do want[key(s)] = true end
    local items = list()
    -- Switch off first, then on: only one spell tracking can be active at a time.
    for _, t in ipairs(items) do
        if t.active and not want[key(t)] then pcall(C_Minimap.SetTracking, t.index, false) end
    end
    for _, t in ipairs(items) do
        if not t.active and want[key(t)] then pcall(C_Minimap.SetTracking, t.index, true) end
    end
    self.db.trackingSnapshot = nil
    self.pendingTracking = nil
    self:Print("Tracking restored to your configuration.")
end

function HR:TrackingActive(category)
    if not api() then return nil end
    local wanted = HR.normalize(wantedName(category))
    for _, t in ipairs(list()) do
        if isWanted(t, wanted, category) then return t.active end
    end
    return nil
end

function HR:TrackingName(category)
    return currentCategory(category).spellName
end

HR.IsolateHerbTracking = HR.IsolateTracking
HR.HerbTrackingActive = HR.TrackingActive

function HR:TrackingStatus()
    self:Print("Tracking isolation: " .. (self.db.isolateTracking and "on" or "off")
        .. (self.db.trackingSnapshot and (" (configuration saved: %d tracking(s) to restore)"):format(#self.db.trackingSnapshot) or ""))
end

function HR:OnTrackingEvent(event)
    if not self.db then return end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            if self.db.trackingSnapshot and not self.route then self:RestoreTracking() end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" and self.pendingTracking then
        local pending = self.pendingTracking
        self.pendingTracking = nil
        if pending == "restore" then
            self:RestoreTracking()
        elseif self.route then
            self:IsolateTracking()
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event) HR:OnTrackingEvent(event) end)
