local addonName, SR = ...

local R = {}
SR.Rules = R

function R.minSkill(level)
    if level <= 10 then return 0 end
    if level < 20 then return (level - 10) * 10 end
    return level * 5
end

function R.canSkin(skill, level)
    local required = skill < 100 and (level - 10) * 10 or level * 5
    return required <= skill
end

function R.inBand(creature, level, lo, hi)
    return creature.l[2] >= level + lo and creature.l[1] <= level + hi
end

function R.difficulty(mid, level)
    local diff = mid - level
    if diff >= 5 then return "red" end
    if diff >= 3 then return "orange" end
    if diff >= -2 then return "yellow" end
    if diff >= -7 then return "green" end
    return "gray"
end

function R.evaluate(entries, creatures, ctx)
    local e = {total = 0, inBand = 0, skinnable = 0, drops = 0, value = 0, unpriced = {}}
    local levelSum = 0
    for _, entry in ipairs(entries) do
        local c = creatures[entry.id]
        if c then
            local per, perValue, relevant = 0, 0, false
            for item, d in pairs(c.d) do
                if ctx.items[item] then
                    relevant = true
                    local avg = d[1] / 100 * (d[2] + d[3]) / 2
                    per = per + avg
                    local price = ctx.price and ctx.price(item)
                    if price then perValue = perValue + avg * price else e.unpriced[item] = true end
                end
            end
            if relevant then
                e.total = e.total + entry.n
                e.allMin = math.min(e.allMin or c.l[1], c.l[1])
                e.allMax = math.max(e.allMax or c.l[2], c.l[2])
                if not ctx.bandOnly or R.inBand(c, ctx.level, ctx.lo, ctx.hi) then
                    e.inBand = e.inBand + entry.n
                    e.lmin = math.min(e.lmin or c.l[1], c.l[1])
                    e.lmax = math.max(e.lmax or c.l[2], c.l[2])
                    levelSum = levelSum + entry.n * (c.l[1] + c.l[2]) / 2
                    local need = R.minSkill(c.l[2])
                    if not e.minNeeded or need < e.minNeeded then e.minNeeded = need end
                    if ctx.skill == nil or R.canSkin(ctx.skill, c.l[2]) then
                        e.skinnable = e.skinnable + entry.n
                        e.drops = e.drops + entry.n * per
                        e.value = e.value + entry.n * perValue
                    end
                end
            end
        end
    end
    e.percent = e.inBand > 0 and e.skinnable / e.inBand * 100 or 0
    e.avgLevel = e.inBand > 0 and levelSum / e.inBand or nil
    if e.total == 0 then
        e.status = "empty"
    elseif e.inBand == 0 then
        e.status = "out"
        e.lmin, e.lmax = e.allMin, e.allMax
    elseif e.skinnable == 0 then
        e.status = "locked"
    elseif e.skinnable < e.inBand then
        e.status = "partial"
    else
        e.status = "ok"
    end
    return e
end

function SR:EvaluateRegion(region, ctx)
    return R.evaluate(self:RegionEntries(region), self.Data.creatures, ctx)
end

local function sortRows(rows, ctx)
    local anyPrice = false
    for item in pairs(ctx.items) do
        if ctx.price and ctx.price(item) then anyPrice = true end
    end
    local open, locked, hidden = {}, {}, 0
    for _, row in ipairs(rows) do
        local status = row.eval.status
        if status == "ok" or status == "partial" then
            open[#open + 1] = row
        elseif status == "locked" then
            locked[#locked + 1] = row
        else
            hidden = hidden + 1
        end
    end
    local key = anyPrice and "value" or "drops"
    table.sort(open, function(a, b)
        if a.eval[key] ~= b.eval[key] then return a.eval[key] > b.eval[key] end
        return a.tie < b.tie
    end)
    table.sort(locked, function(a, b)
        if a.eval.minNeeded ~= b.eval.minNeeded then return a.eval.minNeeded < b.eval.minNeeded end
        return a.tie < b.tie
    end)
    for _, row in ipairs(locked) do open[#open + 1] = row end
    return open, hidden, anyPrice
end

function SR:RankRegions(ctx)
    local rows = {}
    for _, region in ipairs(self:GetRegions()) do
        rows[#rows + 1] = {region = region, tie = region, eval = self:EvaluateRegion(region, ctx)}
    end
    return sortRows(rows, ctx)
end

function SR:RankZones(set, ctx)
    local rows = {}
    for _, zone in ipairs(set.zones) do
        rows[#rows + 1] = {zone = zone, tie = zone.id, eval = R.evaluate(zone.entries, self.Data.creatures, ctx)}
    end
    return sortRows(rows, ctx)
end
