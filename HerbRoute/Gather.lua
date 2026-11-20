local addonName, HR = ...

-- Gathering. The character stands still during the channel, so the position read
-- when it starts names the node: the nearest point of the database (route's
-- types) within RANGE yards. When a gathering starts, every point that may have
-- respawned is probed again at once (HR.StartWave), during the channel: the minimap
-- can be read and moved while it lasts, so the "casting" guard of the probes is
-- lifted until the gathering ends (HR.gatheringUntil). The end only settles the
-- gathered point.
local RANGE = 12
local SAFETY = 30   -- seconds after which the guard lifted for a gathering is dropped anyway

local EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
}
local START = {UNIT_SPELLCAST_START = "cast", UNIT_SPELLCAST_CHANNEL_START = "channel"}

local GATHER_IDS = {
    [2366] = true, [2368] = true, [3570] = true, [11993] = true, [28695] = true, [50300] = true,
    [2575] = true, [2576] = true, [3564] = true, [10248] = true, [29354] = true, [50310] = true,
}

local active

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function safe(v)
    if v == nil then return "nil" end
    if isSecret(v) then return "<secret>" end
    return tostring(v)
end

local function trace(fmt, ...)
    if HR.db and HR.db.gatherDebug == true then HR:Say("Gather: " .. fmt:format(...)) end
end

local function spellName(id)
    if type(id) ~= "number" or isSecret(id) then return nil end
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

-- true / false, or nil when the spell cannot be read.
local function isGatherSpell(id)
    if type(id) ~= "number" or isSecret(id) then return nil end
    if GATHER_IDS[id] then return true end
    local n = spellName(id)
    if not n then return nil end
    n = n:lower()
    return (n:find("gathering", 1, true) or n:find("herbalism", 1, true) or n:find("mining", 1, true)) and true or false
end

local function nodeAtPlayer(r)
    local hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    local pool = HR.RevivePool and HR.RevivePool(r)
    if not hbd or not pool then return nil end
    local px, py, inst = hbd:GetPlayerWorldPosition()
    if not px then return nil end
    local best, bestD
    for _, e in ipairs(pool) do
        if e.inst == inst then
            local d = math.sqrt((e.wx - px) ^ 2 + (e.wy - py) ^ 2)
            if d <= RANGE and (not bestD or d < bestD) then best, bestD = e, d end
        end
    end
    return best, bestD
end

local function endTime(kind)
    local fn = kind == "channel" and UnitChannelInfo or UnitCastingInfo
    if not fn then return nil end
    local ok, _, _, _, _, stop = pcall(fn, "player")
    if ok and type(stop) == "number" and not isSecret(stop) then return stop / 1000 end
end

local function harvest(r, e)
    for j = r.index, #r.points do
        if not r.removed[j] and HR.PointKey(r.points[j]) == e.key then
            HR:HarvestPoint(j)
            return "removed from the route (point " .. j .. ")"
        end
    end
    HR:MarkReached(e.p)
    return "marked reached (it was not ahead in the route)"
end

function HR.GatherEvent(event, unit, castGUID, spellId)
    if unit ~= "player" then return end
    local r = HR.route
    local known = isGatherSpell(spellId)
    trace("%s spell=%s (%s) gathering=%s", event, safe(spellId), safe(spellName(spellId)),
        known == nil and "unknown" or tostring(known))

    if START[event] then
        local node, d
        if r and r.mode == "follow" then node, d = nodeAtPlayer(r) end
        local gather = known
        if gather == nil then gather = node ~= nil end
        if not gather then active = nil return end
        active = {kind = START[event], at = GetTime(), endsAt = endTime(START[event]), node = node}
        HR.gatheringUntil = GetTime() + SAFETY
        trace("gathering started, node in range: %s", node and ("%s %.1f yd"):format(node.p.herb, d) or "none")
        if r and r.mode == "follow" then
            HR.StartWave(r)
            if node then node.nextAt, node.nextOdo = GetTime() + SAFETY, (r.odo or 0) + 1e9 end
            trace("every point that may have respawned is probed again now, during the gathering")
        end
        return
    end

    local a = active
    if not a then return end
    if a.kind == "channel" and (event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_STOP") then return end
    if a.kind == "cast" and event == "UNIT_SPELLCAST_CHANNEL_STOP" then return end
    active = nil
    HR.gatheringUntil = nil
    local failed = event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED"
        or (a.kind == "cast" and event == "UNIT_SPELLCAST_STOP")
    if not failed and a.kind == "channel" and a.endsAt and GetTime() < a.endsAt - 0.4 then failed = true end
    local note = "no node in range"
    if r and r.mode == "follow" and not failed and a.node then
        a.node.nextAt, a.node.nextOdo = 0, 0
        note = harvest(r, a.node)
    end
    trace("gathering %s: %s", failed and "failed" or "succeeded", note)
end

function HR:InitGather()
    local f = CreateFrame("Frame")
    HR.gatherEvents = {}
    for _, ev in ipairs(EVENTS) do
        if pcall(f.RegisterUnitEvent, f, ev, "player") then HR.gatherEvents[#HR.gatherEvents + 1] = ev end
    end
    f:SetScript("OnEvent", function(_, event, ...) HR.GatherEvent(event, ...) end)
end
