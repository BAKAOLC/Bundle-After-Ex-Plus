local deathEffect = require("thlib.player.effects.DeathEffect")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---死亡动画组件
---@class thlib.Player.DeathAnimationComponent : core.Component
---@field style string
---@field customFunc function|nil

-- 定义组件类型
local DeathAnimationComponentType = TypeDef.create("thlib.Player.DeathAnimationComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 1,
        style = "classic",
        customFunc = nil,
    },
    methods = {
        Awake = function(self)
            local player = self.owner
            player:registerEvent("PlayerState:onStateEnter_dying", "deathAnimation", 10, function(p)
                self:playAnimation(p)
            end)
        end,

        OnDestroy = function(self)
            local player = self.owner
            player:unregisterEvent("PlayerState:onStateEnter_dying", "deathAnimation")
        end,

        playAnimation = function(self, player)
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
        end,
    },
})

---创建死亡动画组件
---@param config table
---@return thlib.Player.DeathAnimationComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(DeathAnimationComponentType, {
        style = config.style or "classic",
        customFunc = config.customFunc,
    })
end

return {
    create = create,
    Type = DeathAnimationComponentType,
}

