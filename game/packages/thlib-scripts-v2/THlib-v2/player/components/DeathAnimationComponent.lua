local deathEffect = require("THlib-v2.player.DeathEffect")

---死亡动画组件
---@class THlib.Player.DeathAnimationComponent : foundation.Component
---@field style string
---@field customFunc function|nil

---创建死亡动画组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.DeathAnimationComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.DeathAnimationComponent
    local component = {
        enabled = true,
        executePriority = 1,
        typeName = "deathAnimation",
        owner = owner,
        style = config.style or "classic",
        customFunc = config.customFunc,
    }

    function component:onAdd()
        local player = self.owner
        player:registerEvent("onStateEnter_dying", "deathAnimation", 10, function(p)
            self:playAnimation(p)
        end)
    end

    function component:onRemove()
        local player = self.owner
        player:unregisterEvent("onStateEnter_dying", "deathAnimation")
    end

    function component:playAnimation(player)
        if self.customFunc then
            self.customFunc(player)
            return
        end

        if self.style == "classic" then
            New(death_weapon, player.x, player.y)
            deathEffect.create(player.x, player.y)
            New(player_death_ef, player.x, player.y)
            player.hide = true
        elseif self.style == "simple" then
            New(player_death_ef, player.x, player.y)
            player.hide = true
        end
    end

    return component
end

return {
    create = create,
}

