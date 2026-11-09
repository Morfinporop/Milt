-- GRIMOHOD: чистые утилиты без привязки к движку (тестируются отдельно)

GRIM = GRIM or {}
GRIM.Util = GRIM.Util or {}
local U = GRIM.Util

-- Взвешенный случайный выбор. weightOf(item) -> число >= 0
function U.WeightedPick(items, weightOf)
    local count = #items
    if count == 0 then return nil end

    local weights, total = {}, 0
    for i = 1, count do
        local w = weightOf(items[i]) or 0
        if w < 0 then w = 0 end
        weights[i] = w
        total = total + w
    end

    if total <= 0 then return items[math.random(count)] end

    local r = math.random() * total
    for i = 1, count do
        r = r - weights[i]
        if r <= 0 then return items[i] end
    end
    return items[count]
end

-- Значения таблицы, отсортированные по числовому ключу ("1", "2", ...)
function U.OrderedValues(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        return tostring(a) < tostring(b)
    end)
    local out = {}
    for i, k in ipairs(keys) do out[i] = t[k] end
    return out
end

-- Разбор строки "[x y z]" или "{p y r}" в три числа
function U.ParseTriple(s)
    if type(s) ~= "string" then return nil end
    local a, b, c = string.match(s, "([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)")
    if not a then return nil end
    return tonumber(a), tonumber(b), tonumber(c)
end

-- Минимальная двоичная куча (min-heap)
local Heap = {}
Heap.__index = Heap

function U.Heap()
    return setmetatable({n = 0, k = {}, v = {}}, Heap)
end

function Heap:Push(key, val)
    local n = self.n + 1
    self.n = n
    self.k[n], self.v[n] = key, val
    local i = n
    while i > 1 do
        local p = math.floor(i / 2)
        if self.k[p] <= self.k[i] then break end
        self.k[p], self.k[i] = self.k[i], self.k[p]
        self.v[p], self.v[i] = self.v[i], self.v[p]
        i = p
    end
end

function Heap:Pop()
    local n = self.n
    if n == 0 then return nil end
    local top = self.v[1]
    self.k[1], self.v[1] = self.k[n], self.v[n]
    self.k[n], self.v[n] = nil, nil
    n = n - 1
    self.n = n
    local i = 1
    while true do
        local l, r, m = i * 2, i * 2 + 1, i
        if l <= n and self.k[l] < self.k[m] then m = l end
        if r <= n and self.k[r] < self.k[m] then m = r end
        if m == i then break end
        self.k[m], self.k[i] = self.k[i], self.k[m]
        self.v[m], self.v[i] = self.v[i], self.v[m]
        i = m
    end
    return top
end

function Heap:Empty()
    return self.n == 0
end

-- A* поверх абстрактного backend:
--   backend.nearest(pos) -> node | nil
--   backend.neighbors(node) -> массив узлов
--   backend.pos(node) -> Vector
--   backend.key(node) -> уникальный ключ
-- Возвращает массив позиций от старта до цели или nil.
function U.AStar(backend, from, to, maxIter)
    local startN, goalN = backend.nearest(from), backend.nearest(to)
    if not startN or not goalN then return nil end

    local sk, gk = backend.key(startN), backend.key(goalN)
    local goalPos = backend.pos(goalN)
    if sk == gk then return {goalPos} end

    local open = U.Heap()
    local g, came, nodeOf, closed = {[sk] = 0}, {}, {[sk] = startN}, {}
    open:Push(backend.pos(startN):Distance(goalPos), sk)

    maxIter = maxIter or 5000
    local iter = 0
    while not open:Empty() do
        iter = iter + 1
        if iter > maxIter then return nil end

        local ck = open:Pop()
        if not closed[ck] then
            closed[ck] = true
            if ck == gk then
                local path, k = {}, gk
                while k ~= nil do
                    table.insert(path, 1, backend.pos(nodeOf[k]))
                    k = came[k]
                end
                return path
            end

            local cn = nodeOf[ck]
            local cp = backend.pos(cn)
            for _, nb in ipairs(backend.neighbors(cn)) do
                local nk = backend.key(nb)
                if not closed[nk] then
                    local np = backend.pos(nb)
                    local ng = g[ck] + cp:Distance(np)
                    if g[nk] == nil or ng < g[nk] then
                        g[nk] = ng
                        came[nk] = ck
                        nodeOf[nk] = nb
                        open:Push(ng + np:Distance(goalPos), nk)
                    end
                end
            end
        end
    end
    return nil
end
