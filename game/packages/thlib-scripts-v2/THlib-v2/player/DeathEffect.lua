local table = table
local math = math
local ipairs = ipairs

local deathEffect = lstg.CreateGameObjectClass()

local EXPAND_DURATION = 50
local EXPAND_RANGE = 600
local EDGE_COUNT = 50

local easeIn3 = function(t)
    return math.pow(t, 3)
end

function deathEffect:frame()
    task.Do(self)
    local finished = true
    for _, v in ipairs(self.renders) do
        v.timer = v.timer + 1
        local t = v.timer / EXPAND_DURATION
        local easedT = easeIn3(t)
        v.r = easedT * EXPAND_RANGE
        if v.timer > EXPAND_DURATION then
            v.finished = true
        end
        if not v.finished then
            finished = false
        end
    end
    if finished then
        Del(self)
        self.hide = true
    end
end

function deathEffect:render()
    for _, v in ipairs(self.renders) do
        local x = self.x + v.x
        local y = self.y + v.y
        rendercircle(x, y, v.r, EDGE_COUNT)
    end
end

function deathEffect.create(x, y)
    local self = lstg.New(deathEffect)
    self.x = x
    self.y = y
    self.layer = LAYER_TOP - 1
    self.renders = {}
    task.New(self, function()
        table.insert(self.renders, { timer = 0, x = 0, y = 0, r = 0 })
        task.Wait(5)
        table.insert(self.renders, { timer = 0, x = 0, y = 32, r = 0 })
        table.insert(self.renders, { timer = 0, x = 32, y = 0, r = 0 })
        table.insert(self.renders, { timer = 0, x = 0, y = -32, r = 0 })
        table.insert(self.renders, { timer = 0, x = -32, y = 0, r = 0 })
        task.Wait(20)
        table.insert(self.renders, { timer = 0, x = 0, y = 0, r = 0 })
    end)
end

lstg.RegisterGameObjectClass(deathEffect)

return deathEffect