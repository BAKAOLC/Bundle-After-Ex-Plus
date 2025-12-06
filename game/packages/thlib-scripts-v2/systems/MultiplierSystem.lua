local pairs = pairs

---倍率系统

---@class systems.MultiplierSystem
---@field owner any
---@field multipliers table<string, number>
local MultiplierSystem = {}

---@param owner any
---@param initialMultipliers table<string, number>|nil 初始倍率定义
function MultiplierSystem:init(owner, initialMultipliers)
    self.owner = owner
    self.multipliers = initialMultipliers or {}
end

---注册一个倍率类型
---@param type string
---@param defaultValue number|nil 默认值，默认为1.0
function MultiplierSystem:register(type, defaultValue)
    if self.multipliers[type] == nil then
        self.multipliers[type] = defaultValue or 1.0
    end
end

---设置倍率
---@param type string
---@param value number
function MultiplierSystem:set(type, value)
    self.multipliers[type] = value
end

---获取倍率
---@param type string
---@return number
function MultiplierSystem:get(type)
    return self.multipliers[type] or 1.0
end

---乘以倍率
---@param type string
---@param value number
function MultiplierSystem:multiply(type, value)
    local current = self.multipliers[type] or 1.0
    self.multipliers[type] = current * value
end

---重置指定倍率
---@param type string
---@param defaultValue number|nil 默认值，默认为1.0
function MultiplierSystem:reset(type, defaultValue)
    self.multipliers[type] = defaultValue or 1.0
end

---重置所有倍率
---@param defaultValue number|nil 默认值，默认为1.0
function MultiplierSystem:resetAll(defaultValue)
    defaultValue = defaultValue or 1.0
    for k in pairs(self.multipliers) do
        self.multipliers[k] = defaultValue
    end
end

---创建新的MultiplierSystem实例
---@param owner any
---@param initialMultipliers table|nil
---@return systems.MultiplierSystem
function MultiplierSystem.new(owner, initialMultipliers)
    local instance = setmetatable({}, { __index = MultiplierSystem })
    instance:init(owner, initialMultipliers)
    return instance
end

return MultiplierSystem

