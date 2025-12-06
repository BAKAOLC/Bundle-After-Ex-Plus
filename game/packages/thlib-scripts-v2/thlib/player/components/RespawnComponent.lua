---复活组件
---处理玩家复活相关逻辑

---@class thlib.Player.RespawnComponent : core.Component
---@field respawnX number
---@field respawnY number
---@field targetX number
---@field targetY number
---@field respawnMode string
---@field respawnDuration number
---@field protectDuration number
---@field onRespawn function|nil
---@field protectComp thlib.Player.ProtectComponent|nil
---@field stateComp thlib.Player.StateComponent|nil

---创建复活组件
---@param owner thlib.Player
---@param config table
---@return thlib.Player.RespawnComponent
local function create(owner, config)
    config = config or {}

    ---@type thlib.Player.RespawnComponent
    local component = {
        enabled = true,
        executePriority = 1,
        typeName = "respawn",
        owner = owner,
        -- 组件自己的配置
        respawnX = config.respawnX or 0,
        respawnY = config.respawnY or -236, -- 参考旧代码：从 -236 开始
        targetX = config.targetX or 0, -- 重生动画结束后的目标X坐标
        targetY = config.targetY or -192, -- 参考旧代码：飞到 -192
        respawnMode = config.respawnMode or "fadeIn", -- fadeIn/instant
        respawnDuration = config.respawnDuration or 60, -- 重生动画时长
        protectDuration = config.protectDuration or 120,
        onRespawn = config.onRespawn,
        stateComp = nil,
    }

    function component:onAdd()
        local player = self.owner

        -- 监听重生状态事件
        player:registerEvent("onStateEnter_respawning", "respawnHandler", 10, function(p)
            self:handleRespawn(p)
        end)
    end

    function component:onRemove()
        local player = self.owner
        player:unregisterEvent("onStateEnter_respawning", "respawnHandler")
    end

    function component:resolveDependencies(gameObject)
        self.protectComp = gameObject:getComponent("protect")
        self.stateComp = gameObject:getComponent("state")
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

        -- 显示玩家
        player.hide = false

        -- 回调
        if self.onRespawn then
            self.onRespawn(player)
        end
    end

    function component:update()
        local player = self.owner

        -- 处理渐入动画
        if self.stateComp and self.stateComp.currentState == "respawning" and self.respawnMode == "fadeIn" then
            local timer = self.stateComp:getStateTimer()
            local progress = math.min(timer / self.respawnDuration, 1)
            player.x = self.respawnX + (self.targetX - self.respawnX) * progress
            player.y = self.respawnY + (self.targetY - self.respawnY) * progress
        end
    end

    return component
end

return {
    create = create,
}

