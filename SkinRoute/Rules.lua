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

function R.killTime(diff, base, fixed, slope, factor)
    local d = math.max(-10, math.min(10, diff))
    return fixed + (base - fixed) * slope ^ d * (factor or 1)
end

function R.lootValue(cid, ctx)
    local c = ctx.lootData and ctx.lootData[cid]
    if not c then return 0 end
    local v = c.g or 0
    for item, d in pairs(c.d or {}) do
        local price = ctx.lootPrice(item)
        if price then v = v + d[1] / 100 * (d[2] + d[3]) / 2 * price end
    end
    return v
end

function R.evaluate(entries, creatures, ctx)
    local e = {total = 0, inBand = 0, skinnable = 0, drops = 0, value = 0, skinValue = 0, lootValue = 0, seconds = 0, unpriced = {}}
    local levelSum = 0
    for _, entry in ipairs(entries) do
        local c = creatures[entry.id]
        if c and (not c.e or ctx.elites) and (not ctx.only or ctx.only[entry.id]) then
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
                        e.skinValue = e.skinValue + entry.n * perValue
                        e.value = e.value + entry.n * perValue
                        if ctx.loot then
                            local lv = entry.n * R.lootValue(entry.id, ctx)
                            e.lootValue = e.lootValue + lv
                            e.value = e.value + lv
                        end
                        if ctx.killBase then
                            e.seconds = e.seconds + entry.n * R.killTime((c.l[1] + c.l[2]) / 2 - ctx.level, ctx.killBase, ctx.killFixed, ctx.killSlope, c.e and ctx.eliteFactor or nil)
                        end
                    end
                end
            end
        end
    end
    e.perHour = e.seconds > 0 and e.value / e.seconds * 3600 or 0
    e.skinPerHour = e.seconds > 0 and e.skinValue / e.seconds * 3600 or 0
    e.lootPerHour = e.seconds > 0 and e.lootValue / e.seconds * 3600 or 0
    e.dropsHour = e.seconds > 0 and e.drops / e.seconds * 3600 or 0
    e.avgSeconds = e.skinnable > 0 and e.seconds / e.skinnable or nil
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

local PLAN_SHARE = 0.03

function R.plan(entries, creatures, ctx, anyPrice)
    local cands = {}
    for _, entry in ipairs(entries) do
        local c = creatures[entry.id]
        if c and (not c.e or ctx.elites) and (not ctx.bandOnly or R.inBand(c, ctx.level, ctx.lo, ctx.hi)) then
            local v, items = 0, {}
            for item, d in pairs(c.d) do
                if ctx.items[item] then
                    local avg = d[1] / 100 * (d[2] + d[3]) / 2
                    local w = anyPrice and (ctx.price(item) or 0) or 1
                    items[item] = avg * w
                    v = v + avg * w
                end
            end
            if v > 0 then
                local t = R.killTime((c.l[1] + c.l[2]) / 2 - ctx.level, ctx.killBase, ctx.killFixed, ctx.killSlope, c.e and ctx.eliteFactor or nil)
                local l = (ctx.loot and anyPrice) and R.lootValue(entry.id, ctx) or 0
                cands[#cands + 1] = {
                    id = entry.id, n = entry.n, v = v, l = l, t = t, items = items,
                    skin = ctx.skill == nil or R.canSkin(ctx.skill, c.l[2]),
                }
            end
        end
    end
    local usable = {}
    for _, k in ipairs(cands) do
        if k.skin then usable[#usable + 1] = k end
    end
    table.sort(usable, function(a, b)
        local ra, rb = (a.v + a.l) / a.t, (b.v + b.l) / b.t
        if ra ~= rb then return ra > rb end
        return a.id < b.id
    end)
    local keep = ctx.keep or 0.7
    local bv, bl, bt, bestN = 0, 0, 0, 0
    local chosen = {}
    local mobs = 0
    if #usable > 0 then
        local top = (usable[1].v + usable[1].l) / usable[1].t
        for _, k in ipairs(usable) do
            if (k.v + k.l) / k.t >= top * keep then
                bestN = bestN + 1
                chosen[#chosen + 1] = k
                mobs = mobs + k.n
                bv, bl, bt = bv + k.n * k.v, bl + k.n * k.l, bt + k.n * k.t
            end
        end
    else
        chosen = cands
    end
    local contrib, total = {}, 0
    for _, k in ipairs(chosen) do
        for item, v in pairs(k.items) do
            contrib[item] = (contrib[item] or 0) + k.n * v
            total = total + k.n * v
        end
    end
    local list = {}
    for item, v in pairs(contrib) do
        if v > 0 and v >= total * PLAN_SHARE then list[#list + 1] = {id = item, v = v} end
    end
    table.sort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return a.id < b.id
    end)
    local only = {}
    for _, k in ipairs(chosen) do only[k.id] = true end
    local ids, set = {}, {}
    for _, it in ipairs(list) do
        ids[#ids + 1] = it.id
        set[it.id] = true
    end
    return {
        ids = ids, set = set, creatures = only, perHour = bt > 0 and (bv + bl) / bt * 3600 or 0,
        skinPerHour = bt > 0 and bv / bt * 3600 or 0, lootPerHour = bt > 0 and bl / bt * 3600 or 0,
        value = bv + bl, seconds = bt, mobs = mobs, usable = bestN > 0,
    }
end

function SR:AnyPrice()
    for id in pairs(self.Data.items) do
        if self:ItemPrice(id) then return true end
    end
    return false
end

function SR:AllItemSet()
    local set = {}
    for id in pairs(self.Data.items) do set[id] = true end
    return set
end

function SR:AutoPlan(region, ctx, anyPrice)
    ctx = ctx or self:Context()
    local all = {}
    for k, v in pairs(ctx) do all[k] = v end
    all.items = self:AllItemSet()
    all.only = nil
    if anyPrice == nil then anyPrice = self:AnyPrice() end
    local plan = R.plan(self:RegionEntries(region), self.Data.creatures, all, anyPrice)
    plan.region = region
    plan.eval = R.evaluate(self:RegionEntries(region), self.Data.creatures, all)
    return plan
end

function SR:RankAuto()
    local ctx = self:Context()
    local anyPrice = self:AnyPrice()
    local open, locked = {}, {}
    for _, region in ipairs(self:GetRegions()) do
        local plan = self:AutoPlan(region, ctx, anyPrice)
        local status = plan.eval.status
        local row = {region = region, plan = plan, eval = plan.eval}
        if status == "ok" or status == "partial" then
            open[#open + 1] = row
        elseif status == "locked" then
            locked[#locked + 1] = row
        end
    end
    table.sort(open, function(a, b)
        if a.plan.perHour ~= b.plan.perHour then return a.plan.perHour > b.plan.perHour end
        return a.region < b.region
    end)
    table.sort(locked, function(a, b)
        if a.eval.minNeeded ~= b.eval.minNeeded then return a.eval.minNeeded < b.eval.minNeeded end
        return a.region < b.region
    end)
    for _, row in ipairs(locked) do open[#open + 1] = row end
    return open, anyPrice
end

function SR:EvaluateRegion(region, ctx)
    return R.evaluate(self:RegionEntries(region), self.Data.creatures, ctx)
end

local function sortRows(rows, ctx, hourly)
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
    local key = hourly and (anyPrice and "perHour" or "dropsHour") or (anyPrice and "value" or "drops")
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

function SR:RankRegionsByProfit(ctx)
    local rows = {}
    for _, region in ipairs(self:GetRegions()) do
        rows[#rows + 1] = {region = region, tie = region, eval = self:EvaluateRegion(region, ctx)}
    end
    return sortRows(rows, ctx, true)
end

function SR:ZoneCreatures(entries, ctx, limit)
    local anyPrice = self:AnyPrice()
    local list = {}
    for _, en in ipairs(entries) do
        local c = self.Data.creatures[en.id]
        if c and (not c.e or ctx.elites) and (not ctx.only or ctx.only[en.id]) and (not ctx.bandOnly or R.inBand(c, ctx.level, ctx.lo, ctx.hi))
            and (ctx.skill == nil or R.canSkin(ctx.skill, c.l[2])) then
            local v, relevant = 0, false
            for item, d in pairs(c.d) do
                if ctx.items[item] then
                    relevant = true
                    local w = anyPrice and (ctx.price(item) or 0) or 1
                    v = v + d[1] / 100 * (d[2] + d[3]) / 2 * w
                end
            end
            if relevant then
                local l = (ctx.loot and anyPrice) and R.lootValue(en.id, ctx) or 0
                local t = R.killTime((c.l[1] + c.l[2]) / 2 - ctx.level, ctx.killBase, ctx.killFixed, ctx.killSlope, c.e and ctx.eliteFactor or nil)
                list[#list + 1] = {name = c.n, elite = c.e and true or false, rate = (v + l) / t, n = en.n}
            end
        end
    end
    table.sort(list, function(a, b)
        if a.rate ~= b.rate then return a.rate > b.rate end
        return a.name < b.name
    end)
    while #list > limit do list[#list] = nil end
    return list
end

function SR:PickBest(s)
    local min = self.db.bestMin or 35
    local key = s.anyPrice and "perHour" or "dropsHour"
    local cands = {}
    for _, row in ipairs(s.rows) do
        local e = row.eval
        if (e.status == "ok" or e.status == "partial") and e.skinnable >= min and e[key] > 0 then cands[#cands + 1] = row end
    end
    table.sort(cands, function(a, b)
        if a.eval[key] ~= b.eval[key] then return a.eval[key] > b.eval[key] end
        return a.zone.id < b.zone.id
    end)
    local best = {}
    if cands[1] then
        best[1] = cands[1]
        local gap = 2 * s.set.radius
        local a = cands[1].zone
        for i = 2, #cands do
            local b = cands[i].zone
            local dx, dy = a.wx - b.wx, a.wy - b.wy
            if dx * dx + dy * dy >= gap * gap then
                best[2] = cands[i]
                break
            end
        end
    end
    return best
end

function SR:RankZones(set, ctx)
    local rows = {}
    for _, zone in ipairs(set.zones) do
        rows[#rows + 1] = {zone = zone, tie = zone.id, eval = R.evaluate(zone.entries, self.Data.creatures, ctx)}
    end
    return sortRows(rows, ctx)
end

local STATUS_ORDER = {ok = 1, partial = 1, locked = 2, out = 3}

function SR:ItemTotals()
    if self.itemTotals then return self.itemTotals end
    local totals = {}
    for _, zone in pairs(self.Data.zones) do
        for cid, pts in pairs(zone) do
            local c = self.Data.creatures[cid]
            if c and (not c.e or self.db.elites) then
                local n = math.floor(#pts / 2)
                for item in pairs(c.d) do totals[item] = (totals[item] or 0) + n end
            end
        end
    end
    self.itemTotals = totals
    return totals
end

function SR:RegionItems(region, ctx)
    local entries = self:RegionEntries(region)
    local rows = {}
    for _, it in ipairs(self:AllItems()) do
        local one = {level = ctx.level, skill = ctx.skill, lo = ctx.lo, hi = ctx.hi, bandOnly = ctx.bandOnly, elites = ctx.elites,
            items = {[it.id] = true}, price = ctx.price}
        local e = R.evaluate(entries, self.Data.creatures, one)
        if e.total > 0 then rows[#rows + 1] = {id = it.id, name = it.name, eval = e} end
    end
    table.sort(rows, function(a, b)
        local oa, ob = STATUS_ORDER[a.eval.status], STATUS_ORDER[b.eval.status]
        if oa ~= ob then return oa < ob end
        return a.name < b.name
    end)
    return rows
end

function SR:RankRegionsByMobs(ctx)
    local rows = {}
    for _, region in ipairs(self:GetRegions()) do
        local e = self:EvaluateRegion(region, ctx)
        if e.status ~= "empty" then rows[#rows + 1] = {region = region, eval = e} end
    end
    table.sort(rows, function(a, b)
        local oa, ob = STATUS_ORDER[a.eval.status], STATUS_ORDER[b.eval.status]
        if oa ~= ob then return oa < ob end
        if oa == 1 and a.eval.inBand ~= b.eval.inBand then return a.eval.inBand > b.eval.inBand end
        if oa == 2 and a.eval.minNeeded ~= b.eval.minNeeded then return a.eval.minNeeded < b.eval.minNeeded end
        if oa == 3 and a.eval.total ~= b.eval.total then return a.eval.total > b.eval.total end
        return a.region < b.region
    end)
    return rows
end

function SR:ValueItems()
    local list = self:AllItems()
    for _, it in ipairs(list) do it.price, it.src = self:ItemPrice(it.id) end
    table.sort(list, function(a, b)
        if a.price and b.price and a.price ~= b.price then return a.price > b.price end
        if (a.price ~= nil) ~= (b.price ~= nil) then return a.price ~= nil end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return list
end
