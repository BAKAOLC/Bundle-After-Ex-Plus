local pairs = pairs

---计时器组件
local TimerSystem = require("foundation.TimerSystem")

---@class foundation.TimerComponent : foundation.Component
---@field timers foundation.TimerSystem

---创建计时器组件
---@param owner any
---@param config table
---@return foundation.TimerComponent
local function create(owner, config)
    config = config or {}

    ---@type foundation.TimerComponent
    local component = {
        enabled = true,
        executePriority = 100,
        typeName = "timer",
        owner = owner,
        timers = TimerSystem.new(owner),
    }

    function component:update()
        self.timers:update()
    end

    -- 便捷方法：注册计时器
    function component:registerTimer(name, interval)
        return self.timers:registerTimer(name, interval)
    end

    -- 便捷方法：移除计时器
    function component:removeTimer(name)
        self.timers:removeTimer(name)
    end

    -- 便捷方法：获取计时器
    function component:getTimer(name)
        return self.timers:getTimer(name)
    end

    -- 便捷方法：检查计时器是否就绪
    function component:isReady(name)
        return self.timers:isReady(name)
    end

    -- 便捷方法：触发计时器
    function component:trigger(name)
        self.timers:trigger(name)
    end

    -- 便捷方法：重置计时器
    function component:reset(name)
        self.timers:reset(name)
    end

    -- 便捷方法：设置计时器剩余时间
    function component:set(name, remainingTime)
        self.timers:set(name, remainingTime)
    end

    -- 便捷方法：清空所有计时器
    function component:clear()
        self.timers:clear()
    end

    -- 初始化时注册计时器
    if config.timers then
        for name, interval in pairs(config.timers) do
            component.timers:registerTimer(name, interval)
        end
    end

    return component
end

return {
    create = create,
}



