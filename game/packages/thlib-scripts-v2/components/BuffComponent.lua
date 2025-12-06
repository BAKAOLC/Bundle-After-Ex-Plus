---Buff组件
local BuffSystem = require("systems.BuffSystem")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class components.BuffComponent : core.Component
---@field buffs systems.BuffSystem

-- 定义组件类型
local BuffComponentType = TypeDef.create("components.BuffComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 95,
        buffs = nil,
    },
    methods = {
        Awake = function(self)
            -- 延迟初始化，此时 owner 已经设置
            if not self.buffs then
                self.buffs = BuffSystem.new(self.owner)
            end
        end,

        Update = function(self)
            if self.buffs then
                self.buffs:update()
            end
        end,

        -- 便捷方法：添加buff
        addBuff = function(self, buffConfig)
            if not self.buffs then
                self:Awake()
            end
            self.buffs:addBuff(buffConfig)
        end,

        -- 便捷方法：移除buff
        removeBuff = function(self, buffName)
            if self.buffs then
                self.buffs:removeBuff(buffName)
            end
        end,

        -- 便捷方法：检查是否有某个buff
        hasBuff = function(self, buffName)
            if not self.buffs then
                self:Awake()
            end
            return self.buffs:hasBuff(buffName)
        end,

        -- 便捷方法：获取buff
        getBuff = function(self, buffName)
            if not self.buffs then
                self:Awake()
            end
            return self.buffs:getBuff(buffName)
        end,

        -- 便捷方法：清空所有buff
        clear = function(self)
            if self.buffs then
                self.buffs:clear()
            end
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



