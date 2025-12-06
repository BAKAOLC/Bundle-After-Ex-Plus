---碰撞处理组件

---@class thlib.Player.CollisionComponent : core.Component
---@field onHit function|nil 被击中回调 function(player, other)
---@field deleteOnHit boolean 是否删除碰撞对象
---@field playSoundOnHit boolean 是否播放音效
---@field protectComp thlib.Player.ProtectComponent|nil

---创建碰撞处理组件
---@param owner thlib.Player
---@param config table
---@return thlib.Player.CollisionComponent
local function create(owner, config)
    config = config or {}

    ---@type thlib.Player.CollisionComponent
    local component = {
        enabled = true,
        executePriority = 15,
        typeName = "collision",
        owner = owner,
        onHit = config.onHit,
        deleteOnHit = config.deleteOnHit ~= false,
        playSoundOnHit = config.playSoundOnHit ~= false,
    }

    function component:resolveDependencies(gameObject)
        -- 获取保护组件
        local protectComp = gameObject:getComponent("protect")
        self.protectComp = protectComp
    end

    function component:onAdd()
        local player = self.owner

        -- 注册碰撞事件
        player:registerEvent("onCollision", "collisionHandler", 10, function(p, other)
            return self:handleCollision(p, other)
        end)

        -- 注册Kill事件
        player:registerEvent("onKill", "collisionKillHandler", 10, function(p)
            return self:handleKill(p)
        end)
    end

    function component:onRemove()
        local player = self.owner
        player:unregisterEvent("onCollision", "collisionHandler")
        player:unregisterEvent("onKill", "collisionKillHandler")
    end

    function component:handleCollision(player, other)
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
    end

    function component:triggerHit(player, other)
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
    end

    function component:handleKill(player)
        if player.__currentState == "normal" then
            -- Kill 事件没有明确的击杀者，传 nil
            self:triggerHit(player, nil)
        end
        return true
    end

    return component
end

return {
    create = create,
}

