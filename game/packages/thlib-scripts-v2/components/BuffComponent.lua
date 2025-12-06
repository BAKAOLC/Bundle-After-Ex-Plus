---Buff组件
local BuffSystem = require("systems.BuffSystem")

---@class components.BuffComponent : core.Component
---@field buffs systems.BuffSystem

---创建Buff组件
---@param owner any
---@param config table
---@return components.BuffComponent
local function create(owner, config)
    config = config or {}

    ---@type components.BuffComponent
    local component = {
        enabled = true,
        executePriority = 95,
        typeName = "buff",
        owner = owner,
        buffs = BuffSystem.new(owner),
    }

    function component:update()
        self.buffs:update()
    end

    -- 便捷方法：添加buff
    function component:addBuff(buffConfig)
        self.buffs:addBuff(buffConfig)
    end

    -- 便捷方法：移除buff
    function component:removeBuff(buffName)
        self.buffs:removeBuff(buffName)
    end

    -- 便捷方法：检查是否有某个buff
    function component:hasBuff(buffName)
        return self.buffs:hasBuff(buffName)
    end

    -- 便捷方法：获取buff
    function component:getBuff(buffName)
        return self.buffs:getBuff(buffName)
    end

    -- 便捷方法：清空所有buff
    function component:clear()
        self.buffs:clear()
    end

    return component
end

return {
    create = create,
}



