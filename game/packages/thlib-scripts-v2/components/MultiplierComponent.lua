---倍率组件
local MultiplierSystem = require("systems.MultiplierSystem")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.MultiplierComponent : core.Component
---@field multipliers systems.MultiplierSystem

-- 定义组件类型
local MultiplierComponentType = TypeDef.create("components.MultiplierComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 99,
        alias = "multiplier",
        multipliers = nil,
    },
    methods = {
        Awake = function(self)
            -- 延迟初始化，此时 owner 已经设置
            if not self.multipliers then
                self.multipliers = MultiplierSystem.new(self.owner, self._config and self._config.multipliers or {})
                self._config = nil
            end
        end,

        -- 便捷方法：注册倍率类型
        register = function(self, type, defaultValue)
            if not self.multipliers then
                self:Awake()
            end
            self.multipliers:register(type, defaultValue)
        end,

        -- 便捷方法：设置倍率
        set = function(self, type, value)
            if not self.multipliers then
                self:Awake()
            end
            self.multipliers:set(type, value)
        end,

        -- 便捷方法：获取倍率
        get = function(self, type)
            if not self.multipliers then
                self:Awake()
            end
            return self.multipliers:get(type)
        end,

        -- 便捷方法：乘以倍率
        multiply = function(self, type, value)
            if not self.multipliers then
                self:Awake()
            end
            self.multipliers:multiply(type, value)
        end,

        -- 便捷方法：重置指定倍率
        reset = function(self, type, defaultValue)
            if not self.multipliers then
                self:Awake()
            end
            self.multipliers:reset(type, defaultValue)
        end,

        -- 便捷方法：重置所有倍率
        resetAll = function(self, defaultValue)
            if not self.multipliers then
                self:Awake()
            end
            self.multipliers:resetAll(defaultValue)
        end,
    },
})

---创建倍率组件
---@param config table
---@return components.MultiplierComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(MultiplierComponentType, {
        _config = config,
    })
end

return {
    create = create,
    Type = MultiplierComponentType,
}



