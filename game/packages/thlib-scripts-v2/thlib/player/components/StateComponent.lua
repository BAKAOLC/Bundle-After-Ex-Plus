---状态机组件
---管理玩家状态转换和相关逻辑
local PlayerState = require("thlib.player.state.PlayerState")

---@class thlib.Player.StateComponent : core.Component
---@field stateMachine core.StateMachine
---@field currentState string
---@field stateTimers table<string, number>
---@field config table
---@field respawnComp thlib.Player.RespawnComponent|nil

---创建状态机组件
---@param owner thlib.Player
---@param config table
---@return thlib.Player.StateComponent
local function create(owner, config)
    config = config or {}

    ---@type thlib.Player.StateComponent
    local component = {
        enabled = true,
        executePriority = 97,
        typeName = "state",
        owner = owner,
        stateMachine = nil,
        currentState = "normal",
        stateTimers = {},
        respawnComp = nil,
        config = {
            -- 决死相关
            enableDeathSpell = config.enableDeathSpell ~= false,
            deathSpellDuration = config.deathSpellDuration or 10,

            -- 死亡动画相关
            deathAnimationDuration = config.deathAnimationDuration or 90,
        },
    }

    function component:resolveDependencies(gameObject)
        self.respawnComp = gameObject:getComponent("respawn")
    end

    function component:onAdd()
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
            component.handleHit(component)
        end)
    end

    function component:onRemove()
        local player = self.owner
        player:unregisterEvent("onStateEnter_normal", "state_normal")
        player:unregisterEvent("onStateEnter_deathSpell", "state_deathSpell")
        player:unregisterEvent("onStateEnter_dying", "state_dying")
        player:unregisterEvent("onStateEnter_respawning", "state_respawning")
        player:unregisterEvent("onKill", "state_killHandler")
    end

    function component:update()
        -- 更新当前状态timer
        if self.currentState then
            self.stateTimers[self.currentState] = (self.stateTimers[self.currentState] or 0) + 1
        end

        -- 根据当前状态处理状态转换逻辑
        component.handleStateTransitions(component)

        -- 更新状态机
        if self.stateMachine then
            self.stateMachine:update()
            self.stateMachine:clearRequest()
        end
    end

    function component:handleHit()
        if self.currentState == "normal" then
            if self.config.enableDeathSpell then
                component.requestTransition(component, "deathSpell")
            else
                component.requestTransition(component, "dying")
            end
        end
    end

    function component:handleStateTransitions()
        local timer = self.stateTimers[self.currentState] or 0

        if self.currentState == "deathSpell" then
            -- 决死时间结束
            if timer >= self.config.deathSpellDuration then
                component.requestTransition(component, "dying")
            end
        elseif self.currentState == "dying" then
            -- 死亡动画结束
            if timer >= self.config.deathAnimationDuration then
                component.requestTransition(component, "respawning")
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
                component.requestTransition(component, "normal")
            end
        end
    end

    function component:requestTransition(state)
        if self.stateMachine then
            self.stateMachine:requestState(state)
        end
    end

    function component:getStateTimer()
        return self.stateTimers[self.currentState] or 0
    end

    -- 决死成功（放雷救命）
    function component:saveFromDeathSpell()
        if self.currentState == "deathSpell" then
            component.requestTransition(component, "normal")
        end
    end

    return component
end

return {
    create = create,
}

