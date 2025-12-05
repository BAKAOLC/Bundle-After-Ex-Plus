---复活组件
---处理玩家复活相关逻辑

---@class THlib.Player.RespawnComponent : foundation.Component
---@field respawnX number
---@field respawnY number
---@field respawnMode string
---@field protectDuration number
---@field onRespawn function|nil
---@field protectComp THlib.Player.ProtectComponent|nil

---创建复活组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.RespawnComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.RespawnComponent
    local component = {
        enabled = true,
        executePriority = 1,
        typeName = "respawn",
        owner = owner,
        -- 组件自己的配置
        respawnX = config.respawnX or 0,
        respawnY = config.respawnY or -176,
        respawnMode = config.respawnMode or "bottom", -- bottom/instant/fadeIn
        protectDuration = config.protectDuration or 120,
        onRespawn = config.onRespawn,
    }

    function component:onAdd()
        local player = self.owner

        -- 监听重生状态事件
        player:registerEvent("onStateChange_respawning", "respawnHandler", 10, function(p)
            self:handleRespawn(p)
        end)
    end

    function component:onRemove()
        local player = self.owner
        player:unregisterEvent("onStateChange_respawning", "respawnHandler")
    end

    function component:resolveDependencies(gameObject)
        local protectComp = gameObject:getComponent("protect")
        self.protectComp = protectComp
    end

    function component:handleRespawn(player)
        -- 设置重生位置
        player.x = self.respawnX
        player.y = self.respawnY

        -- 设置无敌时间
        if self.protectComp then
            self.protectComp:setProtect(self.protectDuration)
        end

        -- 清除弹幕
        New(bullet_deleter, player.x, player.y)

        -- 回调
        if self.onRespawn then
            self.onRespawn(player)
        end
    end

    function component:update()
        local player = self.owner

        -- 处理从下方飞入的动画
        if player.__currentState == "respawning" and self.respawnMode == "bottom" then
            local targetY = 0
            local progress = math.min((player.__respawnTimer or 0) / 60, 1)
            player.y = self.respawnY + (targetY - self.respawnY) * progress
        end
    end

    return component
end

return {
    create = create,
}

