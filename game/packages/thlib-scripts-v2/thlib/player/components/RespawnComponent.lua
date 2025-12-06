---复活组件
---处理玩家复活相关逻辑
local math = math
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

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

-- 定义组件类型
local RespawnComponentType = TypeDef.create("thlib.Player.RespawnComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 25, -- 在 MovementComponent 之后执行，确保位置不被覆盖
        alias = "respawn",
        respawnX = 0,
        respawnY = -236, -- 参考旧代码：从 -236 开始
        targetX = 0, -- 重生动画结束后的目标X坐标
        targetY = -192, -- 参考旧代码：飞到 -192
        respawnMode = "fadeIn", -- fadeIn/instant
        respawnDuration = 60, -- 重生动画时长
        protectDuration = 120,
        onRespawn = nil,
        protectComp = nil,
        stateComp = nil,
    },
    methods = {
        Awake = function(self)
            local player = self.owner

            -- 监听重生状态事件
            player:registerEvent("onStateEnter_respawning", "respawnHandler", 10, function(p)
                self:handleRespawn(p)
            end)
        end,

        OnDestroy = function(self)
            local player = self.owner
            player:unregisterEvent("onStateEnter_respawning", "respawnHandler")
        end,

        Start = function(self)
            self.protectComp = self.owner:getComponent("protect")
            self.stateComp = self.owner:getComponent("state")
        end,

        handleRespawn = function(self, player)
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
        end,

        Update = function(self)
            local player = self.owner

            -- 处理渐入动画
            if self.stateComp and self.stateComp.currentState == "respawning" and self.respawnMode == "fadeIn" then
                local timer = self.stateComp:getStateTimer()
                local progress = math.min(timer / self.respawnDuration, 1)
                player.x = self.respawnX + (self.targetX - self.respawnX) * progress
                player.y = self.respawnY + (self.targetY - self.respawnY) * progress
            end
        end,
    },
})

---创建复活组件
---@param config table
---@return thlib.Player.RespawnComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(RespawnComponentType, {
        respawnX = config.respawnX or 0,
        respawnY = config.respawnY or -236,
        targetX = config.targetX or 0,
        targetY = config.targetY or -192,
        respawnMode = config.respawnMode or "fadeIn",
        respawnDuration = config.respawnDuration or 60,
        protectDuration = config.protectDuration or 120,
        onRespawn = config.onRespawn,
    })
end

return {
    create = create,
    Type = RespawnComponentType,
}

