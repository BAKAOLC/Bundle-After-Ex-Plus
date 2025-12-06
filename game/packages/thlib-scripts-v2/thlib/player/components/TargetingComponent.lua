---目标锁定组件
---@class thlib.Player.TargetingComponent : core.Component
---@field customFunc function|nil
---@field inputComp thlib.Player.InputComponent|nil

---创建目标锁定组件
---@param owner thlib.Player
---@param config table
---@return thlib.Player.TargetingComponent
local function create(owner, config)
    config = config or {}

    local Player = require("thlib.player.core.Player")

    ---@type thlib.Player.TargetingComponent
    local component = {
        enabled = true,
        executePriority = 8,
        typeName = "targeting",
        owner = owner,
        customFunc = config.customFunc,
    }

    function component:resolveDependencies(gameObject)
        local inputComp = gameObject:getComponent("input")
        self.inputComp = inputComp
    end

    function component:update()
        local player = self.owner

        if not self.inputComp or not self.inputComp.keyState.shoot then
            player.target = nil
            return
        end

        if IsValid(player.target) and player.target.colli then
            return
        end

        if self.customFunc then
            self.customFunc(player)
            return
        end

        -- 使用 Player 的 findTargets 方法来查找目标
        local targets = Player.findTargets(player, 1)
        player.target = targets[1] or nil
    end

    return component
end

return {
    create = create,
}

