---倍率组件
local MultiplierSystem = require("systems.MultiplierSystem")

---@class components.MultiplierComponent : core.Component
---@field multipliers systems.MultiplierSystem

---创建倍率组件
---@param owner any
---@param config table
---@return components.MultiplierComponent
local function create(owner, config)
    config = config or {}

    ---@type components.MultiplierComponent
    local component = {
        enabled = true,
        executePriority = 99,
        typeName = "multiplier",
        owner = owner,
        multipliers = MultiplierSystem.new(owner, config.multipliers or {}),
    }

    -- 这个组件不需要update，只是提供数据访问

    -- 便捷方法：注册倍率类型
    function component:register(type, defaultValue)
        self.multipliers:register(type, defaultValue)
    end

    -- 便捷方法：设置倍率
    function component:set(type, value)
        self.multipliers:set(type, value)
    end

    -- 便捷方法：获取倍率
    function component:get(type)
        return self.multipliers:get(type)
    end

    -- 便捷方法：乘以倍率
    function component:multiply(type, value)
        self.multipliers:multiply(type, value)
    end

    -- 便捷方法：重置指定倍率
    function component:reset(type, defaultValue)
        self.multipliers:reset(type, defaultValue)
    end

    -- 便捷方法：重置所有倍率
    function component:resetAll(defaultValue)
        self.multipliers:resetAll(defaultValue)
    end

    return component
end

return {
    create = create,
}



