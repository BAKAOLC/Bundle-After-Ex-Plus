---碰撞处理组件
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.CollisionComponent : core.Component
---@field onHit function|nil 被击中回调 function(player, other)
---@field deleteOnHit boolean 是否删除碰撞对象
---@field playSoundOnHit boolean 是否播放音效
---@field protectComp thlib.Player.ProtectComponent|nil

-- 定义组件类型
local CollisionComponentType = TypeDef.create("thlib.Player.CollisionComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 15,
        onHit = nil,
        deleteOnHit = true,
        playSoundOnHit = true,
        protectComp = nil,
    },
    methods = {
        Start = function(self)
            -- 获取保护组件
            local protectComp = self.owner:getComponent("protect")
            self.protectComp = protectComp
        end,

        Awake = function(self)
            local player = self.owner

            -- 注册碰撞事件
            player:registerEvent("onCollision", "collisionHandler", 10, function(p, other)
                return self:handleCollision(p, other)
            end)

            -- 注册Kill事件
            player:registerEvent("onKill", "collisionKillHandler", 10, function(p)
                return self:handleKill(p)
            end)
        end,

        OnDestroy = function(self)
            local player = self.owner
            player:unregisterEvent("onCollision", "collisionHandler")
            player:unregisterEvent("onKill", "collisionKillHandler")
        end,

        handleCollision = function(self, player, other)
            -- 如果在无敌保护期，不处理碰撞
            if self.protectComp and self.protectComp:isProtected() then
                if self.deleteOnHit and other.group == GROUP_ENEMY_BULLET then
                    Del(other)
                end
                return true  -- 阻止默认行为
            end

            -- 如果不在正常状态，不处理碰撞
            if player.__currentState ~= "normal" then
                return true
            end

            -- 处理与敌弹/敌人的碰撞
            if other.group == GROUP_ENEMY_BULLET or other.group == GROUP_ENEMY then
                -- 自定义回调
                if self.onHit then
                    local prevented = self.onHit(player, other)
                    if prevented then
                        return true
                    end
                end

                -- 触发被击中
                self:triggerHit(player, other)

                return true  -- 阻止默认行为
            end

            return false  -- 不阻止其他碰撞
        end,

        triggerHit = function(self, player, other)
            -- 触发决死状态
            player.__shouldEnterDeathSpell = true

            -- 删除子弹（如果 other 存在）
            if other and self.deleteOnHit and other.group == GROUP_ENEMY_BULLET then
                Del(other)
            end

            -- 播放音效
            if self.playSoundOnHit then
                PlaySound("pldead00", 0.5)
            end
        end,

        handleKill = function(self, player)
            if player.__currentState == "normal" then
                -- Kill 事件没有明确的击杀者，传 nil
                self:triggerHit(player, nil)
            end
            return true
        end,
    },
})

---创建碰撞处理组件
---@param config table
---@return thlib.Player.CollisionComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(CollisionComponentType, {
        onHit = config.onHit,
        deleteOnHit = config.deleteOnHit ~= false,
        playSoundOnHit = config.playSoundOnHit ~= false,
    })
end

return {
    create = create,
    Type = CollisionComponentType,
}

