local addonName, HR = ...
_G.HerbRoute = HR

local defaults = {
    region = nil,
    herbs = {},
    ores = {},
    category = "herbs",
    radius = 15,
    showMap = true,
    showMinimap = true,
    isolateTracking = true,
    verify = "report",
    verifyAhead = true,
    mergeDuplicates = true,
    reroute = false,
    revive = true,
    nearest = true,
    ambiguity = true,
    verifyCombat = false,
    skipButton = {shown = false},
    overrides = {},
}

BINDING_HEADER_HERBROUTE = "HerbRoute"
BINDING_NAME_HERBROUTE_SKIP = "Skip the current point"
BINDING_NAME_HERBROUTE_STOP = "Stop the route"
BINDING_NAME_HERBROUTE_WINDOW = "Open or close the window"

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
    HR:Print("/hr ambiguity [on|off] - tell apart a positive read that comes from a neighbouring point (on by default)")
    HR:Print("/hr nearest [on|off] - the filled point nearest to you becomes the target, the route is recomputed on arrival (on by default)")
    HR:Print("/hr revive [on|off] - put points of the database that are no longer ahead in the route (reached, skipped, removed) back when they reappear on the minimap (on by default)")
    HR:Print("/hr reroute [on|off|now] - reorder the points ahead after points are removed (off by default)")
    HR:Print("/hr merge [on|off] - merge points closer than 1% of the map (the data files stay untouched)")
    HR:Print("/hr button - show or hide a movable Skip button (keys: Game Menu > Options > Key Bindings > AddOns > HerbRoute)")
    HR:Print("/hr stop | skip | debug | map (test of the world map overlay)")
    HR:Print("/hr tracking [on|off|status|restore] - keep only Find Herbs during a route")
    HR:Print("/hr verify [off|report|remove|status|ahead [on|off]|combat [on|off]|probe|scan|calibrate [ores]|arming [ores]] - check the next point on the minimap")
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
    elseif cmd == "reroute" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then HR.db.reroute = arg == "on" end
        if arg == "now" then return HR:Reroute() end
        HR:Print("Reroute after removals: " .. (HR.db.reroute == true and "on" or "off") .. " (/hr reroute on|off|now): reorders the points ahead from the current one; the database is never changed.")
    elseif cmd == "ambiguity" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then HR.db.ambiguity = arg == "on" end
        local half, source = HR.ZoneHalf and HR.ZoneHalf()
        HR:Print(("Ambiguous positives: %s (/hr ambiguity on|off), zone half-width %s, margin %.1f units; the route's own category only, the database is never changed. /hr probe zone measures the zone."):format(
            HR.db.ambiguity == false and "off" or "on", half and ("%.1f units (%s)"):format(half, source) or "unknown",
            HR.AMB_MARGIN or 0))
    elseif cmd == "nearest" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then HR.db.nearest = arg == "on" end
        HR:Print("Nearest filled point as target: " .. (HR.db.nearest == false and "off" or "on") .. " (/hr nearest on|off): the route is recomputed from your position once that waypoint is reached; the database is never changed.")
    elseif cmd == "revive" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then HR.db.revive = arg == "on" end
        local r = HR.route
        HR:Print(("Revive points outside the route: %s (/hr revive on|off), %d candidate(s) from the database, %d put back this route; the database is never changed."):format(
            HR.db.revive == false and "off" or "on", r and HR.ReviveCount(r) or 0, r and r.revivedCount or 0))
    elseif cmd == "merge" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then HR.db.mergeDuplicates = arg == "on" end
        local function total(cat)
            local n = 0
            for _, region in ipairs(HR:GetRegions(cat)) do
                for _, item in ipairs(HR:GetHerbs(region, cat)) do n = n + HR:CountPoints(region, item, cat) end
            end
            return n
        end
        HR:Print(("Merge of neighbouring points (within %.1f%% of the map): %s. Points now: %d herbs, %d ores. The data files are never changed."):format(
            HR.MERGE_TOL, HR.db.mergeDuplicates == true and "on" or "off", total("herbs"), total("ores")))
    elseif cmd == "button" then
        HR:ToggleSkipButton()
    elseif cmd == "map" then
        HR:OverlayTest()
    elseif cmd == "debug" then
        HR:DebugRegions()
        HR:OverlayStatus()
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
        local word, cat = arg:match("^(%a+)%s*(%a*)$")
        if word == "calibrate" then return HR:VerifyCalibrate(cat) end
        if word == "arming" then return HR:VerifyArming(cat) end
        if arg == "ahead" or arg:match("^ahead%s+%a+$") then return HR:VerifyAhead(arg:match("^ahead%s+(%a+)$")) end
        local opt, val = arg:match("^(%a+)%s*(%a*)$")
        if opt == "combat" then return HR:VerifyOption(opt, val) end
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
    self:InitSkipButton()
end
