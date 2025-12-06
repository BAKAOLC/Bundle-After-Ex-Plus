---保护效果组件（无敌时间）
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.ProtectComponent : core.Component
---@field protectTimer number

-- 定义组件类型
local ProtectComponentType = TypeDef.create("thlib.Player.ProtectComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 2,
        alias = "protect",
        protectTimer = 0,
    },
    methods = {
        Update = function(self)
            if self.protectTimer > 0 then
                self.protectTimer = self.protectTimer - 1
            end
        end,

        isProtected = function(self)
            return self.protectTimer > 0
        end,

        setProtect = function(self, duration)
            self.protectTimer = duration
        end,
    },
})

---创建保护组件
---@param config table
---@return thlib.Player.ProtectComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(ProtectComponentType, config)
end

return {
    create = create,
    Type = ProtectComponentType,
}



