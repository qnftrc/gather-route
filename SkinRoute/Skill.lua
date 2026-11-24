local addonName, SR = ...

local SKINNING_LINE = 393
local NAMES = {skinning = true, depecage = true, kurschnerei = true}

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function plain(v, kind)
    return type(v) == kind and not isSecret(v)
end

function SR.IsSkinning(name, line)
    if plain(line, "number") and line == SKINNING_LINE then return true end
    return plain(name, "string") and NAMES[SR.normalize(name)] == true
end

function SR:ReadSkill()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return {status = "unavailable"}
    end
    local list = {pcall(GetProfessions)}
    if not list[1] then return {status = "unavailable"} end
    local sawSecret, calls, failures = false, 0, 0
    for i = 2, 8 do
        local idx = list[i]
        if plain(idx, "number") then
            local ok, name, _, rank, max, _, _, line, modifier = pcall(GetProfessionInfo, idx)
            calls = calls + 1
            if not ok then failures = failures + 1 end
            if ok and SR.IsSkinning(name, line) then
                if not (plain(rank, "number") and plain(max, "number")) then return {status = "secret"} end
                modifier = plain(modifier, "number") and modifier or 0
                return {
                    status = "ok", rank = rank, max = max, modifier = modifier, value = rank + modifier,
                    line = plain(line, "number") and line or nil,
                }
            end
        elseif idx ~= nil and isSecret(idx) then
            sawSecret = true
        end
    end
    if calls > 0 and failures == calls then return {status = "unavailable"} end
    return {status = sawSecret and "secret" or "not learned"}
end

function SR.SkillText(info)
    if info.status == "ok" then
        return ("your skill (Skinning %d%s/%d)"):format(info.rank, info.modifier ~= 0 and ("%+d"):format(info.modifier) or "", info.max)
    end
    if info.status == "not learned" then return "Skinning not learned: no limit applied (/sr skill <n> to simulate)" end
    if info.status == "secret" then return "skill is a secret value: no limit applied (/sr skill <n> to simulate)" end
    return "skill not readable: no limit applied (/sr skill <n> to simulate)"
end

function SR.SkillShort(info)
    if info.status == "ok" then
        return ("Skinning %d%s/%d"):format(info.rank, info.modifier ~= 0 and ("%+d"):format(info.modifier) or "", info.max)
    end
    if info.status == "not learned" then return "not learned: no limit" end
    if info.status == "secret" then return "secret: no limit" end
    return "not readable: no limit"
end

function SR.SkillHave(info)
    if info.status == "ok" then return "you have " .. info.value end
    if info.status == "not learned" then return "not learned" end
    return info.status == "secret" and "secret" or "not readable"
end
