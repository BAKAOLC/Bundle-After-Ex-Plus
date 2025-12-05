local pairs = pairs

local Class = plus.Class

---@class foundation.Timer
---@field name string
---@field interval number 间隔时间（帧数）
---@field remainingTime number 剩余冷却时间
---@field active boolean 是否激活
local Timer = Class()

---@param name string
---@param interval number
function Timer:init(name, interval)
    self.name = name
    self.interval = interval or 0
    self.remainingTime = 0
    self.active = true
end

---更新计时器
function Timer:update()
    if not self.active then
        return
    end

    if self.remainingTime > 0 then
        self.remainingTime = self.remainingTime - 1
    end
end

---检查是否就绪
---@return boolean
function Timer:isReady()
    return self.active and self.remainingTime <= 0
end

---触发计时器（开始冷却）
function Timer:trigger()
    self.remainingTime = self.interval
end

---重置计时器
function Timer:reset()
    self.remainingTime = 0
end

---设置间隔
---@param interval number
function Timer:setInterval(interval)
    self.interval = interval
end

---@class foundation.TimerSystem
---@field owner any
---@field timers table<string, foundation.Timer>
local TimerSystem = Class()

---@param owner any
function TimerSystem:init(owner)
    self.owner = owner
    self.timers = {}
end

---注册计时器
---@param name string
---@param interval number
---@return foundation.Timer
function TimerSystem:registerTimer(name, interval)
    local timer = Timer(name, interval)
    self.timers[name] = timer
    return timer
end

---移除计时器
---@param name string
function TimerSystem:removeTimer(name)
    self.timers[name] = nil
end

---获取计时器
---@param name string
---@return foundation.Timer|nil
function TimerSystem:getTimer(name)
    return self.timers[name]
end

---检查计时器是否就绪
---@param name string
---@return boolean
function TimerSystem:isReady(name)
    local timer = self.timers[name]
    return timer and timer:isReady() or false
end

---触发计时器
---@param name string
function TimerSystem:trigger(name)
    local timer = self.timers[name]
    if timer then
        timer:trigger()
    end
end

---重置计时器
---@param name string
function TimerSystem:reset(name)
    local timer = self.timers[name]
    if timer then
        timer:reset()
    end
end

---设置计时器的剩余时间
---@param name string
---@param remainingTime number
function TimerSystem:set(name, remainingTime)
    local timer = self.timers[name]
    if timer then
        timer.remainingTime = remainingTime
    end
end

---更新所有计时器
function TimerSystem:update()
    for _, timer in pairs(self.timers) do
        timer:update()
    end
end

---清空所有计时器
function TimerSystem:clear()
    self.timers = {}
end

---创建新的TimerSystem实例
---@param owner any
---@return foundation.TimerSystem
function TimerSystem.new(owner)
    local instance = setmetatable({}, { __index = TimerSystem })
    instance:init(owner)
    return instance
end

return TimerSystem

