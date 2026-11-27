local addonName, SR = ...

local TEMPLATES = {
    {"Frame", "BasicFrameTemplateWithInset"},
    {"Button", "UIPanelButtonTemplate"},
    {"CheckButton", "UICheckButtonTemplate"},
    {"EditBox", "InputBoxTemplate"},
    {"Slider", "OptionsSliderTemplate"},
    {"ScrollFrame", "UIPanelScrollFrameTemplate"},
    {"Frame", "BackdropTemplate"},
}

local lines

local function add(fmt, ...)
    lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
end

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function show(v)
    if v == nil then return "nil" end
    if isSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then return '"' .. v:sub(1, 40) .. '"' end
    if t == "table" then return "table" end
    return tostring(v)
end

local function pack(...)
    return {n = select("#", ...), ...}
end

local function try(label, fn, ...)
    local r = pack(pcall(fn, ...))
    if not r[1] then
        add("%s: ERROR %s", label, tostring(r[2]):sub(1, 90))
        return nil
    end
    local parts = {}
    for i = 2, math.min(r.n, 9) do parts[#parts + 1] = show(r[i]) end
    add("%s -> %s", label, #parts > 0 and table.concat(parts, ", ") or "(no value)")
    return r
end

local function addList(prefix, items)
    if #items == 0 then return add("%s (none)", prefix) end
    local cur, len = {}, #prefix
    for _, item in ipairs(items) do
        if len + #item + 2 > 190 and #cur > 0 then
            add("%s %s", prefix, table.concat(cur, ", "))
            prefix, cur, len = "  ...", {}, 6
        end
        cur[#cur + 1] = item
        len = len + #item + 2
    end
    add("%s %s", prefix, table.concat(cur, ", "))
end

local function sectionHeader()
    local r = pack(pcall(GetBuildInfo or function() end))
    add("client %s build %s toc %s, locale %s", show(r[2]), show(r[3]), show(r[5]), show(GetLocale and GetLocale()))
    try('UnitLevel("player")', UnitLevel or function() end, "player")
    local creatures = 0
    for _ in pairs(SR.Data.creatures) do creatures = creatures + 1 end
    add("SkinRoute data: %d regions, %d creatures, %d items%s", #SR.regionNames, creatures, SR:AllItems() and #SR:AllItems() or 0,
        SR.dataMissing and " (DATA FILE MISSING)" or "")
end

local function sectionEnvironment()
    local hbd = LibStub and LibStub("HereBeDragons-2.0", true)
    add("HereBeDragons-2.0: %s", hbd and "present" or "MISSING (zones cannot be computed)")
    local m, x, y = TomTom:GetCurrentPlayerPosition()
    local info = m and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    add("player map %s (%s) at %s, %s", show(m), info and show(info.name) or "?", show(x and x * 100), show(y and y * 100))
    if hbd and m then
        local x0, y0 = hbd:GetWorldCoordinatesFromZone(0, 0, m)
        local x1, y1 = hbd:GetWorldCoordinatesFromZone(1, 1, m)
        if x0 and x1 then
            add("map %s: %.0f x %.0f yd (corners %.0f,%.0f and %.0f,%.0f)", show(m), math.abs(x1 - x0), math.abs(y1 - y0), x0, y0, x1, y1)
            if x and y then
                local xp, yp = hbd:GetWorldCoordinatesFromZone(x, y, m)
                add("your position in world coordinates: %s, %s", show(xp), show(yp))
            end
        else
            add("map %s: HereBeDragons returned no world coordinates", show(m))
        end
    end
    local count = 0
    for _ in pairs(TomTom.NameToMapId or {}) do count = count + 1 end
    SR:BuildMaps()
    add("TomTom.NameToMapId: %d entries; regions resolved %d/%d; current region: %s", count,
        #SR.regionNames - #SR.unresolved, #SR.regionNames, show((SR:GetCurrentRegion())))
    if #SR.unresolved > 0 then
        local names = {}
        for i = 1, math.min(#SR.unresolved, 12) do names[#names + 1] = SR.unresolved[i] end
        addList("unresolved:", names)
    end
    add("world map frame: %s, canvas %s, gamepad UI %s", show(WorldMapFrame and "present"),
        show(WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() and "present"),
        show(TomTom.IsGamepadUI and TomTom:IsGamepadUI()))
    add("frame methods: CreateLine %s, CreateMaskTexture %s", type(UIParent.CreateLine), type(UIParent.CreateMaskTexture))
end

local function sectionTemplates()
    local ok, bad = {}, {}
    for _, t in ipairs(TEMPLATES) do
        local good, frame = pcall(CreateFrame, t[1], nil, UIParent, t[2])
        if good and frame then
            ok[#ok + 1] = t[2]
            if frame.Hide then frame:Hide() end
        else
            bad[#bad + 1] = t[2] .. " (" .. tostring(frame):sub(1, 60) .. ")"
        end
    end
    addList("templates created:", ok)
    if #bad > 0 then addList("templates FAILED:", bad) end
end

local function scanApis()
    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "function" and k:find("Skill") then names[#names + 1] = k end
    end
    table.sort(names)
    local total = #names
    while #names > 60 do table.remove(names) end
    addList(("global functions with Skill in the name (%d):"):format(total), names)
    for _, ns in ipairs({"C_SkillLine", "C_TradeSkillUI", "C_Professions"}) do
        local t = _G[ns]
        if type(t) == "table" then
            local keys = {}
            for k, v in pairs(t) do
                if type(k) == "string" and type(v) == "function" and (k:find("Skill") or k:find("Profession")) then keys[#keys + 1] = k end
            end
            table.sort(keys)
            while #keys > 40 do table.remove(keys) end
            addList(ns .. ":", keys)
        else
            add("%s: %s", ns, type(t))
        end
    end
end

local function skillFromLines()
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        add("GetNumSkillLines / GetSkillLineInfo: not available")
        return
    end
    local okn, n = pcall(GetNumSkillLines)
    if not okn then
        add("GetNumSkillLines: ERROR %s", tostring(n):sub(1, 90))
        return
    end
    add("GetNumSkillLines -> %s", show(n))
    if type(n) ~= "number" or isSecret(n) then return end
    local headers, skills, found, foundIndex, collapsed, errors = {}, {}, nil, nil, 0, 0
    for i = 1, math.min(n, 80) do
        local r = pack(pcall(GetSkillLineInfo, i))
        if not r[1] then
            errors = errors + 1
            if errors == 1 then add("GetSkillLineInfo(%d): ERROR %s", i, tostring(r[2]):sub(1, 90)) end
        else
            local name, header, expanded = r[2], r[3], r[4]
            if header then
                if not expanded then collapsed = collapsed + 1 end
                headers[#headers + 1] = show(name) .. (expanded and "" or " [collapsed]")
            else
                skills[#skills + 1] = ("%s %s/%s"):format(show(name), show(r[5]), show(r[8]))
            end
            if not header and not found and SR.IsSkinning(name) then
                found, foundIndex = r, i
            end
        end
    end
    addList("headers:", headers)
    addList("skills:", skills)
    if collapsed > 0 then add("%d header(s) collapsed: their skills are not listed by the client until expanded", collapsed) end
    if found then
        local raw = {}
        for i = 2, math.min(found.n, 9) do raw[#raw + 1] = show(found[i]) end
        add("Skinning line %d raw: %s", foundIndex, table.concat(raw, ", "))
        return {rank = found[5], max = found[8]}
    end
end

local function skillFromProfessions()
    if type(GetProfessions) ~= "function" then
        add("GetProfessions: not available")
        return
    end
    local r = try("GetProfessions()", GetProfessions)
    if not r or type(GetProfessionInfo) ~= "function" then return end
    for i = 2, math.min(r.n, 7) do
        local idx = r[i]
        if type(idx) == "number" and not isSecret(idx) then
            try(("GetProfessionInfo(%d)"):format(idx), GetProfessionInfo, idx)
        end
    end
end

local function sectionSkills()
    scanApis()
    local classic = skillFromLines()
    skillFromProfessions()
    local info = SR:ReadSkill()
    if info.status == "ok" then
        add("RESULT: Skinning %d (rank %d%s) of %d via GetProfessionInfo, skill line %s", info.value, info.rank,
            info.modifier ~= 0 and (" %+d"):format(info.modifier) or "", info.max, show(info.line))
    elseif info.status == "secret" then
        add("RESULT: Skinning found but its value is a SECRET value (not readable by an addon): no skill limit applied")
    elseif info.status == "not learned" then
        add("RESULT: Skinning is not among your professions (not learned): no skill limit applied")
    else
        add("RESULT: GetProfessions / GetProfessionInfo not usable: no skill limit applied")
    end
    if classic then add("the classic API would give %s/%s (not used by the addon)", show(classic.rank), show(classic.max)) end
end

local SECTIONS = {env = sectionEnvironment, ui = sectionTemplates, skill = sectionSkills}
local ORDER = {"env", "ui", "skill"}

function SR:Probe(arg)
    arg = (arg or ""):lower()
    if arg ~= "" and arg ~= "all" and not SECTIONS[arg] then
        return self:Say("Usage: /sr probe [env|ui|skill] (nothing = everything). Read-only: nothing is changed in the game.")
    end
    lines = {}
    add("probe %s", date and date("%Y-%m-%d %H:%M") or "")
    local function run(name, fn)
        local ok, err = pcall(fn)
        if not ok then add("%s: SECTION ERROR %s", name, tostring(err):sub(1, 100)) end
    end
    run("header", sectionHeader)
    for _, name in ipairs(ORDER) do
        if arg == "" or arg == "all" or arg == name then run(name, SECTIONS[name]) end
    end
    self.db.probe = {date = date and date("%Y-%m-%d %H:%M") or "", lines = lines}
    for _, l in ipairs(lines) do self:Say(l) end
    self:Say(("Probe done: %d line(s), also saved in SkinRouteDB.probe (SavedVariables, written at logout or /reload)."):format(#lines))
end

function SR:HpProbe()
    local out = {}
    local function put(fmt, ...) out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
    if type(UnitExists) ~= "function" or not UnitExists("target") then
        return self:Say("hp probe: no target. Target a creature and run /sr hp probe again.")
    end
    local function read(label, fn, ...)
        if type(fn) ~= "function" then put("%s: not available", label) return nil end
        local ok, v = pcall(fn, ...)
        if not ok then put("%s: ERROR %s", label, tostring(v):sub(1, 90)) return nil end
        put("%s -> %s", label, show(v))
        return v
    end
    local name = read('UnitName("target")', UnitName, "target")
    local level = read('UnitLevel("target")', UnitLevel, "target")
    read('UnitClassification("target")', UnitClassification, "target")
    read('UnitCreatureType("target")', UnitCreatureType, "target")
    read('UnitIsDead("target")', UnitIsDead, "target")
    read('UnitCanAttack("player", "target")', UnitCanAttack, "player", "target")
    read('UnitIsPlayer("target")', UnitIsPlayer, "target")
    read('UnitGUID("target")', UnitGUID, "target")
    local hp = read('UnitHealth("target")', UnitHealth, "target")
    local max = read('UnitHealthMax("target")', UnitHealthMax, "target")
    if type(max) == "number" and not isSecret(max) then
        if max <= 100 and max > 0 then
            put("RESULT: UnitHealthMax is %d: this looks like a percentage, not a real health value", max)
        else
            put("RESULT: real health value readable (max %d%s)", max, type(hp) == "number" and not isSecret(hp) and (", current %d"):format(hp) or "")
        end
    elseif max ~= nil then
        put("RESULT: UnitHealthMax is a SECRET value: health cannot be measured by an addon")
    else
        put("RESULT: UnitHealthMax not usable")
    end
    if type(name) == "string" and not isSecret(name) then
        local found = {}
        for id, c in pairs(self.Data.creatures) do
            if c.n == name then found[#found + 1] = ("id %s level %s-%s%s"):format(tostring(id), tostring(c.l[1]), tostring(c.l[2]), c.e and " elite" or "") end
        end
        table.sort(found)
        if #found == 0 then put("database: no creature named %s", show(name))
        else put("database: %d match(es): %s", #found, table.concat(found, "; ")) end
    end
    self.db.hpProbe = {date = date and date("%Y-%m-%d %H:%M") or "", lines = out}
    for _, l in ipairs(out) do self:Say(l) end
end
