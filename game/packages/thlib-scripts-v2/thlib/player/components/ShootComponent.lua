local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---射击组件
---@class thlib.Player.ShootComponent : core.Component
---@field shootFunc function|nil
---@field timerComp components.TimerComponent|nil
---@field inputComp thlib.Player.InputComponent|nil
---@field powerComp thlib.Player.PowerComponent|nil
---@field optionComp thlib.Player.OptionComponent|nil
---@field stateComp thlib.Player.StateComponent|nil

-- 定义组件类型
local ShootComponentType = TypeDef.create("thlib.Player.ShootComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 10,
        shootFunc = nil,
        interval = 0,
        powerComp = nil,
        optionComp = nil,
    },
    methods = {
        Start = function(self)
            -- 获取计时器组件
            self.timerComp = self.owner:getComponent("timer")
            -- 设置射击计时器的间隔
            if self.timerComp and self.interval > 0 then
                local shootTimer = self.timerComp:getTimer("shoot")
                if shootTimer then
                    shootTimer:setInterval(self.interval)
                end
            end

            -- 获取输入组件
            local inputComp = self.owner:getComponent("input")
            self.inputComp = inputComp

            -- 获取火力组件
            self.powerComp = self.owner:getComponent("power")

            -- 获取子机组件
            self.optionComp = self.owner:getComponent("option")

            -- 获取状态组件
            self.stateComp = self.owner:getComponent("state")
        end,

        Update = function(self)
            local player = self.owner

            -- 只在 normal 状态允许射击
            if self.stateComp and self.stateComp.currentState ~= "normal" then
                return
            end

            if not self.inputComp or not self.inputComp.keyState.shoot then
                return
            end

            if not self.timerComp or not self.timerComp:isReady("shoot") then
                return
            end

            if self.timerComp then
                self.timerComp:trigger("shoot")
            end

            if self.shootFunc then
                self.shootFunc(player)
            end
        end,
    },
})

---创建射击组件
---@param config table
---@return thlib.Player.ShootComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(ShootComponentType, {
        shootFunc = config.onShoot or config.shootFunc,
        interval = config.interval or 0,
    })
end

return {
    create = create,
    Type = ShootComponentType,
}

