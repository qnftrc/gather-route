local addonName, HR = ...
_G.HerbRoute = HR

local defaults = {
    region = nil,
    herbs = {},
    ores = {},
    category = "herbs",
    mode = "follow",
    radius = 15,
    showMap = true,
    showMinimap = true,
    isolateTracking = true,
    verify = "report",
    overrides = {},
}

function HR:Print(msg)
    print("|cff33ff99HerbRoute|r: " .. tostring(msg))
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function normalize(s)
    return (s:lower():gsub("[^%w]", ""))
end
HR.normalize = normalize

-- Splits "a, b ,c" into a list of trimmed names.
local function splitList(s)
    local out = {}
    for raw in s:gmatch("[^,]+") do
        local token = raw:match("^%s*(.-)%s*$")
        if token ~= "" then out[#out + 1] = token end
    end
    return out
end

local function findRegion(name, category)
    local n = normalize(name)
    local regions = category and HR:GetRegions(category) or HR.regionNames
    for _, region in ipairs(regions) do
        if normalize(region) == n then return region end
    end
    local hit
    for _, region in ipairs(regions) do
        if normalize(region):find(n, 1, true) then
            if hit then return nil, "ambiguous" end
            hit = region
        end
    end
    return hit
end

local function findHerbs(region, names, category)
    local available = HR:GetHerbs(region, category)
    local picked, missing = {}, {}
    for _, wanted in ipairs(names) do
        local w = normalize(wanted)
        local hit
        for _, herb in ipairs(available) do
            if normalize(herb) == w then hit = herb break end
        end
        if not hit then
            for _, herb in ipairs(available) do
                if normalize(herb):find(w, 1, true) then hit = herb break end
            end
        end
        if hit then picked[#picked + 1] = hit else missing[#missing + 1] = wanted end
    end
    return picked, missing
end

local function usage()
    HR:Print("/hr - open the window")
    HR:Print("/hr <herb>[, <herb>] - route in the current region (or 'all')")
    HR:Print("/hr <region>: <herb>[, <herb>] - route in another region")
    HR:Print("/hr ores <ore>[, <ore>] or /hr ores <region>: <ore>[, <ore>] - same for ores (or 'all')")
    HR:Print("/hr stop | skip | debug")
    HR:Print("/hr tracking [on|off|status|restore] - keep only Find Herbs during a route")
    HR:Print("/hr verify [off|report|remove|status|probe|scan|calibrate|arming] - check the next point on the minimap")
    HR:Print("/hr probe [minimap|watch|blink world [hidden]|copy] - test minimap reading")
    HR:Print("/hr setmap <region>: <mapID> - force the map ID of a region")
end

local function handleSlash(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()

    if cmd == "" then
        HR:ToggleUI()
    elseif cmd == "help" or cmd == "?" then
        usage()
    elseif cmd == "stop" then
        HR:StopRoute()
    elseif cmd == "skip" then
        HR:SkipPoint()
    elseif cmd == "debug" then
        HR:DebugRegions()
    elseif cmd == "tracking" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then
            HR.db.isolateTracking = arg == "on"
            if arg == "off" then HR:RestoreTracking() elseif HR.route then HR:IsolateTracking() end
            HR:TrackingStatus()
        elseif arg == "restore" then
            HR:RestoreTracking()
        else
            HR:TrackingStatus()
        end
    elseif cmd == "verify" then
        local arg = rest:lower()
        if arg == "probe" then return HR:VerifyProbeNow() end
        if arg == "scan" then return HR:VerifyScan() end
        if arg == "calibrate" then return HR:VerifyCalibrate() end
        if arg == "arming" then return HR:VerifyArming() end
        if arg == "off" or arg == "report" or arg == "remove" then HR.db.verify = arg end
        HR:VerifyStatus()
    elseif cmd == "probe" then
        HR.Probe:Run(rest)
    elseif cmd == "setmap" then
        local region, id = rest:match("^(.-)%s*:%s*#?(%d+)$")
        local real = region and findRegion(region)
        if not real then
            HR:Print("Usage: /hr setmap <region>: <mapID>")
            return
        end
        HR.db.overrides[real] = tonumber(id)
        HR:BuildMaps()
        HR:Print(real .. " -> map " .. id)
    else
        local category = "herbs"
        local word, tail = msg:match("^%s*(%a+)%s+(.-)%s*$")
        if not word then word, tail = msg:match("^%s*(%a+)%s*$"), "" end
        word = word and word:lower()
        if word == "ores" or word == "ore" or word == "minerals" then
            category, msg = "ores", tail
        elseif word == "herbs" or word == "herb" then
            msg = tail
        end
        local what = category == "ores" and "ore" or "herb"
        local regionPart, herbPart = msg:match("^%s*(.-)%s*:%s*(.-)%s*$")
        if not regionPart then herbPart = msg end
        local region
        if regionPart and regionPart ~= "" and regionPart:lower() ~= "here" then
            local err
            region, err = findRegion(regionPart, category)
            if not region then
                HR:Print(err == "ambiguous" and ("Several regions match '" .. regionPart .. "'.") or ("Unknown region '" .. regionPart .. "'."))
                return
            end
        else
            region = HR:GetCurrentRegion()
            if not region then
                HR:Print(("Your current zone has no %s data. Use /hr %s<region>: <%ss>."):format(what, category == "ores" and "ores " or "", what))
                return
            end
        end
        local herbs, missing
        if herbPart:lower() == "all" then
            herbs, missing = HR:GetHerbs(region, category), {}
        else
            herbs, missing = findHerbs(region, splitList(herbPart), category)
        end
        if #missing > 0 then
            HR:Print("Not found in " .. region .. ": " .. table.concat(missing, ", "))
        end
        if #herbs == 0 then return end
        HR:GenerateRoute(region, herbs, nil, category)
    end
end

SLASH_HERBROUTE1 = "/herbroute"
SLASH_HERBROUTE2 = "/hr"
SlashCmdList["HERBROUTE"] = handleSlash

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    HerbRouteDB = HerbRouteDB or {}
    for k, v in pairs(defaults) do
        if HerbRouteDB[k] == nil then HerbRouteDB[k] = copy(v) end
    end
    HR.db = HerbRouteDB
    HR:OnLoaded()
end)

function HR:OnLoaded()
    self:InitRunner()
    self:InitOverlay()
end
