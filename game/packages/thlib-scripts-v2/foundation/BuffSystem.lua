local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local table = table

---Buff系统

---@class foundation.Buff
---@field name string
---@field duration number 持续时间（帧数），-1表示永久
---@field remainingTime number 剩余时间
---@field stackable boolean 是否可叠加
---@field maxStacks number 最大叠加层数
---@field currentStacks number 当前叠加层数
---@field data table 自定义数据
---@field onApply function|nil
---@field onRemove function|nil
---@field onUpdate function|nil
---@field onStack function|nil
local Buff = {}

---@param config table
function Buff:init(config)
    self.name = config.name or "UnnamedBuff"
    self.duration = config.duration or -1
    self.remainingTime = self.duration
    self.stackable = config.stackable or false
    self.maxStacks = config.maxStacks or 1
    self.currentStacks = 1
    self.data = config.data or {}

    self.onApply = config.onApply
    self.onRemove = config.onRemove
    self.onUpdate = config.onUpdate
    self.onStack = config.onStack
end

---添加层数
function Buff:addStack()
    if not self.stackable then
        self.remainingTime = self.duration
        return
    end

    if self.currentStacks < self.maxStacks then
        self.currentStacks = self.currentStacks + 1
        if self.onStack then
            self.onStack(self)
        end
    end
    self.remainingTime = self.duration
end

---更新buff
---@return boolean 是否应该移除
function Buff:update()
    if self.duration > 0 then
        self.remainingTime = self.remainingTime - 1
        if self.remainingTime <= 0 then
            return true
        end
    end

    if self.onUpdate then
        self.onUpdate(self)
    end

    return false
end

---@class foundation.BuffSystem
---@field owner any
---@field buffs table<string, foundation.Buff>
local BuffSystem = {}

---@param owner any
function BuffSystem:init(owner)
    self.owner = owner
    self.buffs = {}
end

---添加buff
---@param buffConfig table
function BuffSystem:addBuff(buffConfig)
    local buffName = buffConfig.name

    if self.buffs[buffName] then
        local existingBuff = self.buffs[buffName]
        if existingBuff.stackable then
            existingBuff:addStack()
        else
            existingBuff.remainingTime = existingBuff.duration
        end
        return
    end

    local buff = setmetatable({}, { __index = Buff })
    buff:init(buffConfig)
    self.buffs[buffName] = buff

    if buff.onApply then
        buff.onApply(buff, self.owner)
    end
end

---移除buff
---@param buffName string
function BuffSystem:removeBuff(buffName)
    local buff = self.buffs[buffName]
    if buff then
        if buff.onRemove then
            buff.onRemove(buff, self.owner)
        end
        self.buffs[buffName] = nil
    end
end

---检查是否有某个buff
---@param buffName string
---@return boolean
function BuffSystem:hasBuff(buffName)
    return self.buffs[buffName] ~= nil
end

---获取buff
---@param buffName string
---@return foundation.Buff|nil
function BuffSystem:getBuff(buffName)
    return self.buffs[buffName]
end

---清空所有buff
function BuffSystem:clear()
    for _, buff in pairs(self.buffs) do
        if buff.onRemove then
            buff.onRemove(buff, self.owner)
        end
    end
    self.buffs = {}
end

---更新所有buff
function BuffSystem:update()
    local toRemove = {}

    for name, buff in pairs(self.buffs) do
        if buff:update() then
            table.insert(toRemove, name)
        end
    end

    for _, name in ipairs(toRemove) do
        self:removeBuff(name)
    end
end

---创建新的BuffSystem实例
---@param owner any
---@return foundation.BuffSystem
function BuffSystem.new(owner)
    local instance = setmetatable({}, { __index = BuffSystem })
    instance:init(owner)
    return instance
end

return BuffSystem

