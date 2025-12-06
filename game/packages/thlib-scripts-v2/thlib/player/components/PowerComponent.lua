local math = math

---火力组件
---管理玩家的火力相关属性，包括子机数量等
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.PowerComponent : core.Component
---@field support number 子机数量（浮点数，平滑过渡）
---@field supportx number 子机跟随X坐标
---@field supporty number 子机跟随Y坐标
---@field supportLerpSpeed number 子机数量变化速度
---@field supportPosLerpSpeed number 子机位置跟随速度
---@field getSupport fun(self: thlib.Player.PowerComponent): number 获取当前子机数量
---@field getSupportPosition fun(self: thlib.Player.PowerComponent): number, number 获取子机跟随位置

-- 定义组件类型
local PowerComponentType = TypeDef.create("thlib.Player.PowerComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 85, -- 在大多数组件之后，但在子机组件之前
        alias = "power",
        support = 0,
        supportx = 0,
        supporty = 0,
        supportLerpSpeed = 0.0625, -- 每帧变化速度
        supportPosLerpSpeed = 0.6875, -- 位置跟随速度
    },
    methods = {
        Awake = function(self)
            -- 初始化 support 值
            if lstg and lstg.var and lstg.var.power then
                self.support = math.floor(lstg.var.power / 100)
            end
            -- 初始化位置
            self.supportx = self.owner.x
            self.supporty = self.owner.y
        end,

        Update = function(self)
            local player = self.owner

            -- 更新 support 值，平滑过渡到目标值
            if lstg and lstg.var and lstg.var.power then
                local targetSupport = math.floor(lstg.var.power / 100)

                if self.support > targetSupport then
                    self.support = self.support - self.supportLerpSpeed
                elseif self.support < targetSupport then
                    self.support = self.support + self.supportLerpSpeed
                end

                -- 如果差值小于变化速度，直接设置为目标值
                if math.abs(self.support - targetSupport) < self.supportLerpSpeed then
                    self.support = targetSupport
                end
            end

            -- 更新 support 位置，平滑跟随玩家
            self.supportx = player.x + (self.supportx - player.x) * self.supportPosLerpSpeed
            self.supporty = player.y + (self.supporty - player.y) * self.supportPosLerpSpeed
        end,

        --- 获取当前子机数量
        ---@return number
        getSupport = function(self)
            return self.support
        end,

        --- 获取子机跟随位置
        ---@return number, number
        getSupportPosition = function(self)
            return self.supportx, self.supporty
        end,
    },
})

---创建火力组件
---@param config table
---@return thlib.Player.PowerComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(PowerComponentType, {
        supportLerpSpeed = config.supportLerpSpeed or 0.0625,
        supportPosLerpSpeed = config.supportPosLerpSpeed or 0.6875,
    })
end

return {
    create = create,
    Type = PowerComponentType,
}

