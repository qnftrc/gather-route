local addonName, HR = ...

-- Port of the planner HTML: nearest neighbour, then a windowed segment
-- reversal (2-opt style). Points are tables {x=, y=} in percent.
-- `tick` is called regularly so a caller can yield from a coroutine.
local M = {}
HR.Math = M

local sqrt = math.sqrt

local function distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx * dx + dy * dy)
end
M.distance = distance

function M.nearest(points, start, tick)
    local n = #points
    local used, route = {}, {}
    local cur = start
    for k = 1, n do
        local best, d = nil, math.huge
        for i = 1, n do
            if not used[i] then
                local dd = distance(cur, points[i])
                if dd < d then d, best = dd, i end
            end
        end
        used[best] = true
        route[k] = points[best]
        cur = points[best]
        if tick and k % 50 == 0 then tick() end
    end
    return route
end

function M.improve(route, start, tick)
    local n = #route
    if n < 3 then return route end
    local maxPass = n > 1800 and 1 or (n > 700 and 2 or 5)
    local window = n > 700 and 60 or math.min(n, 220)
    for _ = 1, maxPass do
        local changed = false
        for i = 1, n - 1 do
            local before = i == 1 and start or route[i - 1]
            local jmax = math.min(n, i + window - 1)
            for j = i + 1, jmax do
                local after = j < n and route[j + 1] or nil
                local old = distance(before, route[i]) + (after and distance(route[j], after) or 0)
                local new = distance(before, route[j]) + (after and distance(route[i], after) or 0)
                if new + 1e-9 < old then
                    local a, b = i, j
                    while a < b do
                        route[a], route[b] = route[b], route[a]
                        a, b = a + 1, b - 1
                    end
                    changed = true
                end
            end
            if tick and i % 20 == 0 then tick() end
        end
        if not changed then break end
    end
    return route
end

function M.pathLength(route, start)
    local sum, cur = 0, start
    for _, p in ipairs(route) do
        sum = sum + distance(cur, p)
        cur = p
    end
    return sum
end

function M.solve(points, start, tick)
    return M.improve(M.nearest(points, start, tick), start, tick)
end
