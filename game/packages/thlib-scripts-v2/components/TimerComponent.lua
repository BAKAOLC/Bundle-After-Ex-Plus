local pairs = pairs

---计时器组件
local TimerSystem = require("systems.TimerSystem")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.TimerComponent : core.Component
---@field timers systems.TimerSystem

-- 定义组件类型（引用基础 Component 类型）
local TimerComponentType = TypeDef.create("components.TimerComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 100,
        alias = "timer",
        timers = nil,
    },
    methods = {
        Awake = function(self)
            -- 延迟初始化，此时 owner 已经设置
            if not self.timers then
                self.timers = TimerSystem.new(self.owner)

                -- 初始化时注册计时器
                if self._config and self._config.timers then
                    for name, interval in pairs(self._config.timers) do
                        self.timers:registerTimer(name, interval)
                    end
                end
                self._config = nil
            end
        end,

        Update = function(self)
            if self.timers then
                self.timers:update()
            end
        end,

        -- 便捷方法：注册计时器
        registerTimer = function(self, name, interval)
            if not self.timers then
                self:Awake()
            end
            return self.timers:registerTimer(name, interval)
        end,

        -- 便捷方法：移除计时器
        removeTimer = function(self, name)
            if self.timers then
                self.timers:removeTimer(name)
            end
        end,

        -- 便捷方法：获取计时器
        getTimer = function(self, name)
            if not self.timers then
                self:Awake()
            end
            return self.timers:getTimer(name)
        end,

        -- 便捷方法：检查计时器是否就绪
        isReady = function(self, name)
            if not self.timers then
                self:Awake()
            end
            return self.timers:isReady(name)
        end,

        -- 便捷方法：触发计时器
        trigger = function(self, name)
            if self.timers then
                self.timers:trigger(name)
            end
        end,

        -- 便捷方法：重置计时器
        reset = function(self, name)
            if self.timers then
                self.timers:reset(name)
            end
        end,

        -- 便捷方法：设置计时器剩余时间
        set = function(self, name, remainingTime)
            if self.timers then
                self.timers:set(name, remainingTime)
            end
        end,

        -- 便捷方法：清空所有计时器
        clear = function(self)
            if self.timers then
                self.timers:clear()
            end
        end,
    },
})

---创建计时器组件
---@param config table
---@return components.TimerComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(TimerComponentType, {
        _config = config,
    })
end

return {
    create = create,
    Type = TimerComponentType,
}



