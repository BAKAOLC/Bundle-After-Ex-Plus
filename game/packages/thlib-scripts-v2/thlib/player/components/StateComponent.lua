---状态机组件
---管理玩家状态转换和相关逻辑
local PlayerState = require("thlib.player.state.PlayerState")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.StateComponent : core.Component
---@field stateMachine core.StateMachine
---@field currentState string
---@field stateTimers table<string, number>
---@field config table
---@field respawnComp thlib.Player.RespawnComponent|nil

-- 定义组件类型
local StateComponentType = TypeDef.create("thlib.Player.StateComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 97,
        alias = "state",
        stateMachine = nil,
        currentState = "normal",
        stateTimers = {},
        respawnComp = nil,
    },
    methods = {
        Start = function(self)
            self.respawnComp = self.owner:getComponent("respawn")
        end,

        Awake = function(self)
            local player = self.owner

            -- 创建状态机
            self.stateMachine = PlayerState.createPlayerStateMachine(player)

            -- 监听状态进入事件
            player:registerEvent("onStateEnter_normal", "state_normal", 10, function(p)
                self.currentState = "normal"
                p.__currentState = "normal"
                self.stateTimers[self.currentState] = 0
                p.hide = false
                p.locked = false
            end)

            player:registerEvent("onStateEnter_deathSpell", "state_deathSpell", 10, function(p)
                self.currentState = "deathSpell"
                p.__currentState = "deathSpell"
                self.stateTimers[self.currentState] = 0
            end)

            player:registerEvent("onStateEnter_dying", "state_dying", 10, function(p)
                self.currentState = "dying"
                p.__currentState = "dying"
                self.stateTimers[self.currentState] = 0
                p.locked = true
            end)

            player:registerEvent("onStateEnter_respawning", "state_respawning", 10, function(p)
                self.currentState = "respawning"
                p.__currentState = "respawning"
                self.stateTimers[self.currentState] = 0
            end)

            -- 监听Kill事件来触发状态转换
            player:registerEvent("onKill", "state_killHandler", 5, function(p)
                self:handleHit()
            end)
        end,

        OnDestroy = function(self)
            local player = self.owner
            player:unregisterEvent("onStateEnter_normal", "state_normal")
            player:unregisterEvent("onStateEnter_deathSpell", "state_deathSpell")
            player:unregisterEvent("onStateEnter_dying", "state_dying")
            player:unregisterEvent("onStateEnter_respawning", "state_respawning")
            player:unregisterEvent("onKill", "state_killHandler")
        end,

        Update = function(self)
            -- 更新当前状态timer
            if self.currentState then
                self.stateTimers[self.currentState] = (self.stateTimers[self.currentState] or 0) + 1
            end

            -- 根据当前状态处理状态转换逻辑
            self:handleStateTransitions()

            -- 更新状态机
            if self.stateMachine then
                self.stateMachine:update()
                self.stateMachine:clearRequest()
            end
        end,

        handleHit = function(self)
            if self.currentState == "normal" then
                if self.config.enableDeathSpell then
                    self:requestTransition("deathSpell")
                else
                    self:requestTransition("dying")
                end
            end
        end,

        handleStateTransitions = function(self)
            local timer = self.stateTimers[self.currentState] or 0

            if self.currentState == "deathSpell" then
                -- 决死时间结束
                if timer >= self.config.deathSpellDuration then
                    self:requestTransition("dying")
                end
            elseif self.currentState == "dying" then
                -- 死亡动画结束
                if timer >= self.config.deathAnimationDuration then
                    self:requestTransition("respawning")
                end
            elseif self.currentState == "respawning" then
                -- 重生完成，使用 RespawnComponent 的配置
                local duration = 60 -- 默认值
                if self.respawnComp then
                    duration = self.respawnComp.respawnDuration
                    if self.respawnComp.respawnMode == "instant" then
                        duration = 1
                    end
                end
                if timer >= duration then
                    self:requestTransition("normal")
                end
            end
        end,

        requestTransition = function(self, state)
            if self.stateMachine then
                self.stateMachine:requestState(state)
            end
        end,

        getStateTimer = function(self)
            return self.stateTimers[self.currentState] or 0
        end,

        -- 决死成功（放雷救命）
        saveFromDeathSpell = function(self)
            if self.currentState == "deathSpell" then
                self:requestTransition("normal")
            end
        end,
    },
})

---创建状态机组件
---@param config table
---@return thlib.Player.StateComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(StateComponentType, {
        config = {
            -- 决死相关
            enableDeathSpell = config.enableDeathSpell ~= false,
            deathSpellDuration = config.deathSpellDuration or 10,

            -- 死亡动画相关
            deathAnimationDuration = config.deathAnimationDuration or 90,
        },
    })
end

return {
    create = create,
    Type = StateComponentType,
}

