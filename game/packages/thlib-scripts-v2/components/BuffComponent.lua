local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local table = table

---Buff组件
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.Buff
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

---创建新的 Buff 实例
---@param config table
---@return components.Buff
local function newBuff(config)
    local buff = {
        name = config.name or "UnnamedBuff",
        duration = config.duration or -1,
        remainingTime = config.duration or -1,
        stackable = config.stackable or false,
        maxStacks = config.maxStacks or 1,
        currentStacks = 1,
        data = config.data or {},
        onApply = config.onApply,
        onRemove = config.onRemove,
        onUpdate = config.onUpdate,
        onStack = config.onStack,
    }

    ---添加层数
    function buff:addStack()
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
    function buff:update()
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

    return buff
end

---@class components.BuffComponent : core.Component
---@field buffs table<string, components.Buff>

-- 定义组件类型
local BuffComponentType = TypeDef.create("components.BuffComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 95,
        alias = "buff",
        buffs = nil,
    },
    methods = {
        Awake = function(self)
            -- 初始化 buffs 表
            if not self.buffs then
                self.buffs = {}
            end
        end,

        Update = function(self)
            if not self.buffs then
                return
            end

            local toRemove = {}

            for name, buff in pairs(self.buffs) do
                if buff:update() then
                    table.insert(toRemove, name)
                end
            end

            for _, name in ipairs(toRemove) do
                self:removeBuff(name)
            end
        end,

        -- 添加buff
        addBuff = function(self, buffConfig)
            if not self.buffs then
                self:Awake()
            end

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

            local buff = newBuff(buffConfig)
            self.buffs[buffName] = buff

            if buff.onApply then
                buff.onApply(buff, self.owner)
            end
        end,

        -- 移除buff
        removeBuff = function(self, buffName)
            if not self.buffs then
                return
            end

            local buff = self.buffs[buffName]
            if buff then
                if buff.onRemove then
                    buff.onRemove(buff, self.owner)
                end
                self.buffs[buffName] = nil
            end
        end,

        -- 检查是否有某个buff
        hasBuff = function(self, buffName)
            if not self.buffs then
                self:Awake()
            end
            return self.buffs[buffName] ~= nil
        end,

        -- 获取buff
        getBuff = function(self, buffName)
            if not self.buffs then
                self:Awake()
            end
            return self.buffs[buffName]
        end,

        -- 清空所有buff
        clear = function(self)
            if not self.buffs then
                return
            end

            for _, buff in pairs(self.buffs) do
                if buff.onRemove then
                    buff.onRemove(buff, self.owner)
                end
            end
            self.buffs = {}
        end,
    },
})

---创建Buff组件
---@param config table
---@return components.BuffComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(BuffComponentType, config)
end

return {
    create = create,
    Type = BuffComponentType,
}
