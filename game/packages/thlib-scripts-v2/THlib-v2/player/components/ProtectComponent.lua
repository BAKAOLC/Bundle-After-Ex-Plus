---保护效果组件（无敌时间）

---@class THlib.Player.ProtectComponent : foundation.Component
---@field protectTimer number

---创建保护组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.ProtectComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.ProtectComponent
    local component = {
        enabled = true,
        executePriority = 2,
        typeName = "protect",
        owner = owner,
        protectTimer = 0,
    }

    function component:update()
        if self.protectTimer > 0 then
            self.protectTimer = self.protectTimer - 1
        end
    end

    function component:isProtected()
        return self.protectTimer > 0
    end

    function component:setProtect(duration)
        self.protectTimer = duration
    end

    return component
end

return {
    create = create,
}



