local table = table
local math = math
local ipairs = ipairs

local GameObject = require("core.GameObject")
local TypeDef = require("core.TypeDef")

local EXPAND_DURATION = 50
local EXPAND_RANGE = 600
local EDGE_COUNT = 50

local easeIn3 = function(t)
    return math.pow(t, 3)
end

-- 定义类型（引用基础 GameObject 类型）
local DeathEffectType = TypeDef.create("thlib.player.effects.DeathEffect", GameObject.Type, {
    methods = {
        Awake = function(self)
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
        end,
        Update = function(self)
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
        end,
        OnRender = function(self)
            for _, v in ipairs(self.renders) do
                local x = self.x + v.x
                local y = self.y + v.y
                rendercircle(x, y, v.r, EDGE_COUNT)
            end
        end,
    },
})

---创建死亡特效
---@param x number
---@param y number
---@return core.GameObject
local function create(x, y)
    return GameObject.create(DeathEffectType, {
        x = x,
        y = y,
    })
end

return {
    create = create,
    Type = DeathEffectType,
}