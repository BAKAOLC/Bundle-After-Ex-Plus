local require = require

local GameObject = require("core.GameObject")
local TypeDef = require("core.TypeDef")

---玩家子弹基础类型定义
local PlayerBulletType = TypeDef.create("thlib.player.bullets.PlayerBullet", GameObject.Type, {
    defaults = {
        group = GROUP_PLAYER_BULLET,
        layer = LAYER_PLAYER_BULLET,
        colli = true,
    },
    methods = {
        OnCollision = function(self, other)
            -- 如果子弹有伤害组件，尝试对目标造成伤害
            local damageComp = self:getComponent("damage")
            if damageComp and other.getComponent then
                local receiverComp = other:getComponent("damageReceiver")
                if receiverComp then
                    damageComp:dealDamage(other)
                end
            end
        end,
    },
})

---创建玩家子弹实例
---@param config table 配置表
---@return core.GameObject 子弹实例
local function create(config)
    config = config or {}

    -- 提取伤害值（如果提供）
    local damage = config.damage
    local bulletConfig = {
        group = config.group or GROUP_PLAYER_BULLET,
        layer = config.layer or LAYER_PLAYER_BULLET,
        img = config.img,
        x = config.x or 0,
        y = config.y or 0,
        rot = config.angle or 90,
        colli = config.colli ~= false,
    }

    -- 创建 GameObject 实例
    local bullet = GameObject.create(PlayerBulletType, bulletConfig)

    -- 如果提供了伤害值，添加伤害组件
    if damage then
        local DamageComp = require("components.DamageComponent")
        local damageComp = DamageComp.create({
            baseDamage = damage,
        })
        bullet:addComponent(damageComp, "damage")
    end

    return bullet
end

return {
    Type = PlayerBulletType,
    create = create,
}

