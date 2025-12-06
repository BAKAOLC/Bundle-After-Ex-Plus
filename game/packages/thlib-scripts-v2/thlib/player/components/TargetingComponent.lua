---目标锁定组件
local Player = require("thlib.player.core.Player")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.TargetingComponent : core.Component
---@field customFunc function|nil
---@field inputComp thlib.Player.InputComponent|nil

-- 定义组件类型
local TargetingComponentType = TypeDef.create("thlib.Player.TargetingComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 8,
        customFunc = nil,
        inputComp = nil,
    },
    methods = {
        Start = function(self)
            local inputComp = self.owner:getComponent("input")
            self.inputComp = inputComp
        end,

        Update = function(self)
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
        end,
    },
})

---创建目标锁定组件
---@param config table
---@return thlib.Player.TargetingComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(TargetingComponentType, {
        customFunc = config.customFunc,
    })
end

return {
    create = create,
    Type = TargetingComponentType,
}

