local pairs = pairs

---计时器组件
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.Timer
---@field name string
---@field interval number 间隔时间（帧数）
---@field remainingTime number 剩余冷却时间
---@field active boolean 是否激活

---创建新的 Timer 实例
---@param name string
---@param interval number
---@return components.Timer
local function newTimer(name, interval)
    local timer = {
        name = name,
        interval = interval or 0,
        remainingTime = 0,
        active = true,
    }

    ---更新计时器
    function timer:update()
        if not self.active then
            return
        end

        if self.remainingTime > 0 then
            self.remainingTime = self.remainingTime - 1
        end
    end

    ---检查是否就绪
    ---@return boolean
    function timer:isReady()
        return self.active and self.remainingTime <= 0
    end

    ---触发计时器（开始冷却）
    function timer:trigger()
        self.remainingTime = self.interval
    end

    ---重置计时器
    function timer:reset()
        self.remainingTime = 0
    end

    ---设置间隔
    ---@param interval number
    function timer:setInterval(interval)
        self.interval = interval
    end

    return timer
end

---@class components.TimerComponent : core.Component
---@field timers table<string, components.Timer>

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
            -- 初始化 timers 表
            if not self.timers then
                self.timers = {}
            end

            -- 初始化时注册计时器
            if self._config and self._config.timers then
                for name, interval in pairs(self._config.timers) do
                    self:registerTimer(name, interval)
                end
            end
            self._config = nil
        end,

        Update = function(self)
            if not self.timers then
                return
            end

            for _, timer in pairs(self.timers) do
                timer:update()
            end
        end,

        -- 注册计时器
        registerTimer = function(self, name, interval)
            if not self.timers then
                self:Awake()
            end

            local timer = newTimer(name, interval)
            self.timers[name] = timer
            return timer
        end,

        -- 移除计时器
        removeTimer = function(self, name)
            if self.timers then
                self.timers[name] = nil
            end
        end,

        -- 获取计时器
        getTimer = function(self, name)
            if not self.timers then
                self:Awake()
            end
            return self.timers[name]
        end,

        -- 检查计时器是否就绪
        isReady = function(self, name)
            if not self.timers then
                self:Awake()
            end

            local timer = self.timers[name]
            return timer and timer:isReady() or false
        end,

        -- 触发计时器
        trigger = function(self, name)
            if self.timers then
                local timer = self.timers[name]
                if timer then
                    timer:trigger()
                end
            end
        end,

        -- 重置计时器
        reset = function(self, name)
            if self.timers then
                local timer = self.timers[name]
                if timer then
                    timer:reset()
                end
            end
        end,

        -- 设置计时器剩余时间
        set = function(self, name, remainingTime)
            if self.timers then
                local timer = self.timers[name]
                if timer then
                    timer.remainingTime = remainingTime
                end
            end
        end,

        -- 清空所有计时器
        clear = function(self)
            if self.timers then
                self.timers = {}
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
