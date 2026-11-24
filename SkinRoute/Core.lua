local addonName, SR = ...
_G.SkinRoute = SR

local defaults = {
    browse = "region",
    optionsShown = false,
    items = {},
    bandOnly = true,
    bandLow = -8,
    bandHigh = 2,
    chat = false,
    showMap = true,
    zoneRadius = 233,
    zoneMin = 5,
    zoneMax = 12,
    arrival = 233,
    prices = {},
    overrides = {},
}

function SR:Say(msg)
    print("|cff33ff99SkinRoute|r: " .. tostring(msg))
end

function SR:Print(msg)
    if SR.db and SR.db.chat == false and not SR.replying then return end
    SR:Say(msg)
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local ACCENTS = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c",
    ["À"] = "a", ["Â"] = "a", ["Ä"] = "a", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
    ["Î"] = "i", ["Ï"] = "i", ["Ô"] = "o", ["Ö"] = "o", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u", ["Ç"] = "c",
}

local function normalize(s)
    s = s:gsub("[\195][\128-\191]", function(c) return ACCENTS[c] or "" end)
    return (s:lower():gsub("[^%w]", ""))
end
SR.normalize = normalize

local function splitList(s)
    local out = {}
    for raw in s:gmatch("[^,]+") do
        local token = raw:match("^%s*(.-)%s*$")
        if token ~= "" then out[#out + 1] = token end
    end
    return out
end

function SR.MoneyText(c)
    c = math.floor((c or 0) + 0.5)
    local neg = c < 0
    if neg then c = -c end
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if g > 0 or s > 0 then parts[#parts + 1] = s .. "s" end
    parts[#parts + 1] = cp .. "c"
    return (neg and "-" or "") .. table.concat(parts, " ")
end

local MONEY_ICON = "|TInterface\\MoneyFrame\\UI-%sIcon:14:14:2:0|t"

function SR.Money(c)
    c = math.floor((c or 0) + 0.5)
    local neg = c < 0
    if neg then c = -c end
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. MONEY_ICON:format("Gold") end
    if g > 0 or s > 0 then parts[#parts + 1] = s .. MONEY_ICON:format("Silver") end
    parts[#parts + 1] = cp .. MONEY_ICON:format("Copper")
    return (neg and "-" or "") .. table.concat(parts, " ")
end

function SR:PlayerLevel()
    if self.db.level then return self.db.level, true end
    return (UnitLevel and UnitLevel("player")) or 1, false
end

function SR:PlayerSkill()
    if self.db.skill then return self.db.skill, true end
    return nil, false
end

function SR:SelectedSet()
    local set = {}
    for _, id in ipairs(self.db.items) do set[id] = true end
    return set
end

function SR:Context()
    local level = self:PlayerLevel()
    local skill = self:PlayerSkill()
    return {
        level = level,
        skill = skill,
        lo = self.db.bandLow,
        hi = self.db.bandHigh,
        bandOnly = self.db.bandOnly ~= false,
        items = self:SelectedSet(),
        price = function(id) return self.db.prices[id] end,
    }
end

local COLORS = {red = "ff4040", orange = "ff8040", yellow = "ffd100", green = "40c040", gray = "9d9d9d"}

local function paint(color, text)
    return "|cff" .. COLORS[color] .. text .. "|r"
end

local function levelText(e, level)
    local lmin, lmax = e.lmin, e.lmax
    if not lmin then return "" end
    local text = lmin == lmax and ("Lv " .. lmin) or ("Lv " .. lmin .. "-" .. lmax)
    local color = SR.Rules.difficulty(e.avgLevel or ((lmin + lmax) / 2), level)
    return paint(color, text)
end

SR.Paint = paint
SR.LevelText = levelText

local function itemNames(ids)
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = SR.Data.items[id] or tostring(id) end
    return table.concat(names, ", ")
end

local function describeRow(i, label, row, ctx, anyPrice)
    local e = row.eval
    local parts = {("%d. %s"):format(i, label), levelText(e, ctx.level)}
    if e.status == "locked" then
        parts[#parts + 1] = paint("orange", "needs skinning " .. e.minNeeded)
    else
        if e.status == "partial" then parts[#parts + 1] = ("%d%%"):format(math.floor(e.percent + 0.5)) end
        if anyPrice then
            parts[#parts + 1] = SR.MoneyText(e.value)
        else
            parts[#parts + 1] = ("~%.0f items"):format(e.drops)
        end
        parts[#parts + 1] = ("%d mobs"):format(e.skinnable)
    end
    return table.concat(parts, "  ")
end

local function usage()
    SR:Say("/sr - open the window")
    SR:Say("/sr items <name>[, <name>] | clear - leathers and scales to count (partial names work)")
    SR:Say("/sr regions [n] - regions ranked by value for your level and skinning skill")
    SR:Say("/sr region <name> - one region in detail")
    SR:Say("/sr level [n|auto] - simulate a character level (auto = the real one)")
    SR:Say("/sr skill [n|auto] - simulate a skinning skill (auto = the real one)")
    SR:Say("/sr band [<low> <high>|off] - count only mobs from level+low to level+high (default -8 +2)")
    SR:Say("/sr price <item>: <copper> - price used for the value (Auctionator comes later)")
    SR:Say("/sr need <level> - skinning skill needed for a mob level")
    SR:Say("/sr zones [region] - compute the zones of a region (default: your region) and draw them on the world map")
    SR:Say("/sr go [region] - compute the zones, then guide you to the best one with TomTom; /sr skip - next zone; /sr stop - end the guide")
    SR:Say("/sr clear - remove the zones from the map | /sr radius [yd] - zone radius (default 233) | /sr arrival [yd] - distance at which you count as arrived (default 233)")
    SR:Say("/sr map - status of the map overlay and a test circle around you")
    SR:Say("/sr chat [on|off] | setmap <region>: <mapID> | debug")
end

SR.DescribeRow = describeRow

function SR:ReportZones()
    local s = self.shown
    if not s then return end
    self:Say(("%s: %d zone(s) of %d yd from %d points, %d without a mob in range, %d point(s) left outside any zone."):format(
        s.region, #s.rows, s.set.radius, s.set.points, s.hidden or 0, s.set.leftover or 0))
    for i = 1, math.min(8, #s.rows) do
        local row = s.rows[i]
        self:Say(describeRow(i, ("(%.0f, %.0f)"):format(row.zone.x, row.zone.y), row, s.ctx, s.anyPrice))
    end
    if #s.rows == 0 then self:Say("Nothing to show: select other items or change the level, skill or band.") end
end

local function showItems()
    if #SR.db.items == 0 then
        SR:Say("No item selected. /sr items <name>[, <name>]")
    else
        SR:Say("Items: " .. itemNames(SR.db.items))
    end
end

local function listRegions(limit)
    if #SR.db.items == 0 then return SR:Say("Select items first: /sr items <name>[, <name>]") end
    local ctx = SR:Context()
    local ranked, hidden, anyPrice = SR:RankRegions(ctx)
    local level, simLevel = SR:PlayerLevel()
    local skill, simSkill = SR:PlayerSkill()
    SR:Say(("Level %d%s, skinning %s%s, %s. Items: %s."):format(
        level, simLevel and " (simulated)" or "",
        skill and tostring(skill) or "unknown (no limit applied, /sr skill <n>)", simSkill and " (simulated)" or "",
        ctx.bandOnly and ("mobs from level " .. (level + ctx.lo) .. " to " .. (level + ctx.hi)) or "all mob levels",
        itemNames(SR.db.items)))
    if #ranked == 0 then return SR:Say(("No region (%d without a mob in range)."):format(hidden)) end
    for i = 1, math.min(limit, #ranked) do SR:Say(describeRow(i, ranked[i].region, ranked[i], ctx, anyPrice)) end
    if #ranked > limit then SR:Say(("... %d more (/sr regions <n>)."):format(#ranked - limit)) end
end

local function showRegion(name)
    local region, err = SR:FindRegion(name)
    if not region then
        return SR:Say(err == "ambiguous" and ("Several regions match '" .. name .. "'.") or ("Unknown region '" .. name .. "'."))
    end
    local ctx = SR:Context()
    local e = SR:EvaluateRegion(region, ctx)
    SR:Say(("%s: %s, %d relevant mobs, %d in range, %d skinnable%s."):format(
        region, e.status, e.total, e.inBand, e.skinnable, e.minNeeded and (", needs skinning " .. e.minNeeded .. " at least") or ""))
    local shown = 0
    for _, entry in ipairs(SR:RegionEntries(region)) do
        local c = SR.Data.creatures[entry.id]
        if c and shown < 12 then
            local drops = {}
            for item, d in pairs(c.d) do
                if ctx.items[item] then drops[#drops + 1] = ("%s %.0f%%"):format(SR.Data.items[item] or item, d[1]) end
            end
            if #drops > 0 then
                table.sort(drops)
                shown = shown + 1
                SR:Say(("  %s Lv %d-%d x%d: %s"):format(c.n, c.l[1], c.l[2], entry.n, table.concat(drops, ", ")))
            end
        end
    end
end

local function setNumber(field, arg, label)
    if arg == "auto" or arg == "off" then
        SR.db[field] = nil
    elseif arg ~= "" then
        local n = tonumber(arg)
        if not n or n < 1 then return SR:Say("Usage: /sr " .. label .. " <number>|auto") end
        SR.db[field] = math.floor(n)
    end
    SR:RefreshZones()
    local value, simulated = (field == "level" and SR.PlayerLevel or SR.PlayerSkill)(SR)
    SR:Say(("%s: %s%s."):format(label == "level" and "Level" or "Skinning skill", value and tostring(value) or "unknown",
        simulated and " (simulated, /sr " .. label .. " auto to go back)" or ""))
end

local function handleSlash(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()

    if cmd == "" then
        SR:ToggleUI()
    elseif cmd == "help" or cmd == "?" then
        usage()
    elseif cmd == "items" or cmd == "item" then
        local arg = rest:lower()
        if arg == "clear" then
            SR.db.items = {}
        elseif rest ~= "" then
            local ids, missing = SR:FindItems(splitList(rest))
            if #missing > 0 then SR:Say("Not found: " .. table.concat(missing, ", ")) end
            if #ids > 0 then SR.db.items = ids end
        end
        SR:RefreshZones()
        showItems()
    elseif cmd == "regions" then
        listRegions(tonumber(rest) or 10)
    elseif cmd == "region" then
        showRegion(rest)
    elseif cmd == "level" then
        setNumber("level", rest:lower(), "level")
    elseif cmd == "skill" then
        setNumber("skill", rest:lower(), "skill")
    elseif cmd == "band" then
        local arg = rest:lower()
        if arg == "off" then
            SR.db.bandOnly = false
        elseif arg ~= "" then
            local lo, hi = arg:match("^([%+%-]?%d+)%s+([%+%-]?%d+)$")
            if not lo then return SR:Say("Usage: /sr band <low> <high> (for example -8 +2) or /sr band off") end
            lo, hi = tonumber(lo), tonumber(hi)
            if lo > hi then lo, hi = hi, lo end
            SR.db.bandLow, SR.db.bandHigh, SR.db.bandOnly = lo, hi, true
        end
        SR:RefreshZones()
        SR:Say(SR.db.bandOnly == false and "Level band: off (all mob levels)."
            or ("Level band: from level %+d to %+d."):format(SR.db.bandLow, SR.db.bandHigh))
    elseif cmd == "price" then
        if rest == "" then
            local n = 0
            for id, copper in pairs(SR.db.prices) do
                n = n + 1
                SR:Say(("%s: %s"):format(SR.Data.items[id] or id, SR.MoneyText(copper)))
            end
            if n == 0 then SR:Say("No price set. /sr price <item>: <copper>") end
            return
        end
        local name, copper = rest:match("^(.-)%s*:%s*(%d+)$")
        local ids = name and SR:FindItems({name})
        if not ids or #ids ~= 1 then return SR:Say("Usage: /sr price <one item>: <copper>") end
        SR.db.prices[ids[1]] = tonumber(copper)
        SR:RefreshZones()
        SR:Say(("%s: %s."):format(SR.Data.items[ids[1]], SR.MoneyText(tonumber(copper))))
    elseif cmd == "need" then
        local level = tonumber(rest)
        if not level then return SR:Say("Usage: /sr need <mob level>") end
        SR:Say(("Mob level %d needs skinning %d (rule of the 1.12 server code, to check on Forever)."):format(level, SR.Rules.minSkill(level)))
    elseif cmd == "zones" then
        local region
        if rest ~= "" then
            local err
            region, err = SR:FindRegion(rest)
            if not region then
                return SR:Say(err == "ambiguous" and ("Several regions match '" .. rest .. "'.") or ("Unknown region '" .. rest .. "'."))
            end
        else
            region = SR:GetCurrentRegion()
            if not region then return SR:Say("Your current zone has no data. Use /sr zones <region>.") end
        end
        SR:ShowZones(region)
    elseif cmd == "go" then
        local region
        if rest ~= "" then
            local err
            region, err = SR:FindRegion(rest)
            if not region then
                return SR:Say(err == "ambiguous" and ("Several regions match '" .. rest .. "'.") or ("Unknown region '" .. rest .. "'."))
            end
        else
            region = SR:GetCurrentRegion()
            if not region then return SR:Say("Your current zone has no data. Use /sr go <region>.") end
        end
        SR:ShowZones(region, true)
    elseif cmd == "skip" then
        SR:SkipZone()
    elseif cmd == "stop" then
        SR:StopGuide()
    elseif cmd == "arrival" then
        local n = tonumber(rest)
        if rest ~= "" then
            if not n or n < 10 or n > 1000 then return SR:Say("Usage: /sr arrival <10 to 1000> (yards)") end
            SR.db.arrival = math.floor(n)
        end
        SR:Say("Arrival distance: " .. SR.db.arrival .. " yd (takes effect at the next zone).")
    elseif cmd == "clear" then
        SR:ClearZones()
        SR:Say("Zones removed from the map.")
    elseif cmd == "radius" then
        local n = tonumber(rest)
        if rest ~= "" then
            if not n or n < 50 or n > 1000 then return SR:Say("Usage: /sr radius <50 to 1000> (yards)") end
            SR.db.zoneRadius = math.floor(n)
            if SR.shown then SR:ShowZones(SR.shown.region) end
        end
        SR:Say("Zone radius: " .. SR.db.zoneRadius .. " yd (the minimap at zoom 0 shows about 233 yd around you).")
    elseif cmd == "map" then
        SR:MapTest()
    elseif cmd == "chat" then
        local arg = rest:lower()
        if arg == "on" or arg == "off" then SR.db.chat = arg == "on" end
        SR:Say("SkinRoute messages in the chat: " .. (SR.db.chat == false and "off" or "on") .. " (replies to commands are always shown).")
    elseif cmd == "setmap" then
        local region, id = rest:match("^(.-)%s*:%s*#?(%d+)$")
        local real = region and SR:FindRegion(region)
        if not real then return SR:Say("Usage: /sr setmap <region>: <mapID>") end
        SR.db.overrides[real] = tonumber(id)
        SR:BuildMaps()
        SR:Say(real .. " -> map " .. id)
    elseif cmd == "debug" then
        SR:DebugRegions()
    else
        SR:Say("Unknown command '" .. cmd .. "'. /sr help")
    end
end

SLASH_SKINROUTE1 = "/skinroute"
SLASH_SKINROUTE2 = "/sr"
SlashCmdList["SKINROUTE"] = function(msg)
    SR.replying = true
    local ok, err = pcall(handleSlash, msg)
    SR.replying = false
    if not ok then error(err, 0) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    SkinRouteDB = SkinRouteDB or {}
    for k, v in pairs(defaults) do
        if SkinRouteDB[k] == nil then SkinRouteDB[k] = copy(v) end
    end
    SR.db = SkinRouteDB
    SR:LoadData()
    SR:InitOverlay()
    SR:InitRunner()
    SR:InitUI()
end)
