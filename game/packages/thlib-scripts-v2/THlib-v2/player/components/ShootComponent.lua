---射击组件
---@class THlib.Player.ShootComponent : foundation.Component
---@field shootFunc function|nil
---@field timers foundation.TimerSystem|nil
---@field inputComp THlib.Player.InputComponent|nil
---@field powerComp THlib.Player.PowerComponent|nil
---@field optionComp THlib.Player.OptionComponent|nil

---创建射击组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.ShootComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.ShootComponent
    local component = {
        enabled = true,
        executePriority = 10,
        typeName = "shoot",
        owner = owner,
        shootFunc = config.onShoot or config.shootFunc,
        interval = config.interval or 0,
        powerComp = nil,
        optionComp = nil,
    }

    function component:resolveDependencies(gameObject)
        -- 获取计时器组件
        local timerComp = gameObject:getComponent("timer")
        if timerComp then
            self.timers = timerComp.timers
            -- 设置射击计时器的间隔
            if self.interval > 0 then
                local shootTimer = self.timers:getTimer("shoot")
                if shootTimer then
                    shootTimer:setInterval(self.interval)
                end
            end
        end

        -- 获取输入组件
        local inputComp = gameObject:getComponent("input")
        self.inputComp = inputComp

        -- 获取火力组件
        self.powerComp = gameObject:getComponent("power")

        -- 获取子机组件
        self.optionComp = gameObject:getComponent("option")
    end

    function component:update()
        local player = self.owner

        if not self.inputComp or not self.inputComp.keyState.shoot then
            return
        end

        if not self.timers or not self.timers:isReady("shoot") then
            return
        end

        if self.timers then
            self.timers:trigger("shoot")
        end

        if self.shootFunc then
            self.shootFunc(player)
        end
    end

    return component
end

return {
    create = create,
}

