local pairs = pairs
local ipairs = ipairs
local table = table
local math = math

---修饰器组件
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.Modifier
---@field source string 来源标识
---@field operation string 操作类型（"add", "multiply", "power"）
---@field value number 操作值
---@field order number 执行顺序（越小越先执行）

---@class components.ModifierComponent : core.Component
---@field modifiers table<string, components.Modifier[]> 修饰器表，key为类型名，value为修饰器数组

-- 定义组件类型
local ModifierComponentType = TypeDef.create("components.ModifierComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 99,
        alias = "modifier",
        modifiers = nil,
    },
    methods = {
        Awake = function(self)
            if not self.modifiers then
                self.modifiers = {}
            end

            if self._config and self._config.modifiers then
                for type, modifierList in pairs(self._config.modifiers) do
                    for _, mod in ipairs(modifierList) do
                        self:addModifier(
                                type,
                                mod.source,
                                mod.operation,
                                mod.value,
                                mod.order
                        )
                    end
                end
            end
            self._config = nil
        end,

        -- 添加修饰器
        ---@param type string 类型名
        ---@param source string 来源标识
        ---@param operation string 操作类型（"add", "multiply", "power"）
        ---@param value number 操作值
        ---@param order number|nil 执行顺序（可选，默认0）
        addModifier = function(self, type, source, operation, value, order)
            if not self.modifiers then
                self:Awake()
            end

            if not self.modifiers[type] then
                self.modifiers[type] = {}
            end

            order = order or 0
            value = value or 0

            -- 创建修饰器
            local modifier = {
                source = source,
                operation = operation,
                value = value,
                order = order,
            }

            -- 添加到数组
            table.insert(self.modifiers[type], modifier)

            -- 按 order 排序
            table.sort(self.modifiers[type], function(a, b)
                return a.order < b.order
            end)
        end,

        -- 移除指定来源的修饰器
        ---@param type string 类型名
        ---@param source string 来源标识
        removeModifier = function(self, type, source)
            if not self.modifiers then
                return
            end

            local modifierList = self.modifiers[type]
            if not modifierList then
                return
            end

            -- 移除匹配的修饰器
            for i = #modifierList, 1, -1 do
                if modifierList[i].source == source then
                    table.remove(modifierList, i)
                end
            end

            -- 如果列表为空，删除类型
            if #modifierList == 0 then
                self.modifiers[type] = nil
            end
        end,

        -- 清空指定类型的所有修饰器
        ---@param type string 类型名
        clearModifiers = function(self, type)
            if not self.modifiers then
                return
            end

            self.modifiers[type] = nil
        end,

        -- 清空所有修饰器
        clearAll = function(self)
            if not self.modifiers then
                return
            end

            self.modifiers = {}
        end,

        -- 应用修饰器，返回结果
        ---@param type string 类型名
        ---@param baseValue number 基础值
        ---@return number 应用修饰后的值
        apply = function(self, type, baseValue)
            if not self.modifiers then
                self:Awake()
            end

            local modifierList = self.modifiers[type]
            if not modifierList or #modifierList == 0 then
                return baseValue
            end

            local result = baseValue

            -- 按顺序应用所有修饰器
            for _, modifier in ipairs(modifierList) do
                local operation = modifier.operation
                local value = modifier.value

                if operation == "add" then
                    -- 加法操作（value 为正数时加，为负数时减）
                    result = result + value
                elseif operation == "multiply" then
                    -- 乘法操作（value > 1 时乘，value < 1 时除）
                    result = result * value
                elseif operation == "power" then
                    -- 次方操作（value > 1 时次方，value < 1 时开方）
                    if result > 0 then
                        result = math.pow(result, value)
                    elseif result < 0 then
                        -- 对于负数，如果 value 是整数，可以计算
                        if value == math.floor(value) then
                            result = math.pow(result, value)
                        else
                            -- 非整数次方对负数无意义，保持原值
                        end
                    end
                end
            end

            return result
        end,
    },
})

---创建修饰器组件
---@param config table
---@return components.ModifierComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(ModifierComponentType, {
        _config = config,
    })
end

return {
    create = create,
    Type = ModifierComponentType,
}

