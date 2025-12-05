local StateMachine = require("foundation.StateMachine")

---创建玩家状态机
---@param player THlib.Player
---@return foundation.StateMachine
local function createPlayerStateMachine(player)
    local sm = StateMachine.new()

    sm:setContext("player", player)

    -- 注册状态
    local STATE_NORMAL = sm:registerState("normal", {
        onEnter = function(ctx)
            ctx.player:_dispatchEvent("onStateEnter_normal")
        end,
        onExit = function(ctx)
            ctx.player:_dispatchEvent("onStateExit_normal")
        end,
    })

    -- 决死状态
    local STATE_DEATH_SPELL = sm:registerState("deathSpell", {
        onEnter = function(ctx)
            ctx.player:_dispatchEvent("onStateEnter_deathSpell")
        end,
        onExit = function(ctx)
            ctx.player:_dispatchEvent("onStateExit_deathSpell")
        end,
    })

    -- 死亡动画状态
    local STATE_DYING = sm:registerState("dying", {
        onEnter = function(ctx)
            local p = ctx.player
            p:_dispatchEvent("onStateEnter_dying")
            p:_dispatchEvent("onMiss")
        end,
        onExit = function(ctx)
            ctx.player:_dispatchEvent("onStateExit_dying")
        end,
    })

    -- 重生状态
    local STATE_RESPAWNING = sm:registerState("respawning", {
        onEnter = function(ctx)
            local p = ctx.player
            p:_dispatchEvent("onStateEnter_respawning")
            p:_dispatchEvent("onRespawn")
        end,
        onExit = function(ctx)
            ctx.player:_dispatchEvent("onStateExit_respawning")
        end,
    })

    -- 无敌保护状态
    local STATE_PROTECTED = sm:registerState("protected", {
        onEnter = function(ctx)
            ctx.player:_dispatchEvent("onStateEnter_protected")
        end,
        onExit = function(ctx)
            ctx.player:_dispatchEvent("onStateExit_protected")
        end,
    })

    -- 添加状态转换（由组件通过设置标志来触发）

    -- 正常 -> 决死
    sm:addTransition(STATE_NORMAL, STATE_DEATH_SPELL, function(ctx)
        return ctx.player.__requestState == "deathSpell"
    end)

    -- 正常 -> 死亡
    sm:addTransition(STATE_NORMAL, STATE_DYING, function(ctx)
        return ctx.player.__requestState == "dying"
    end)

    -- 决死 -> 正常
    sm:addTransition(STATE_DEATH_SPELL, STATE_NORMAL, function(ctx)
        return ctx.player.__requestState == "normal"
    end)

    -- 决死 -> 死亡
    sm:addTransition(STATE_DEATH_SPELL, STATE_DYING, function(ctx)
        return ctx.player.__requestState == "dying"
    end)

    -- 死亡 -> 重生
    sm:addTransition(STATE_DYING, STATE_RESPAWNING, function(ctx)
        return ctx.player.__requestState == "respawning"
    end)

    -- 重生 -> 保护
    sm:addTransition(STATE_RESPAWNING, STATE_PROTECTED, function(ctx)
        return ctx.player.__requestState == "protected"
    end)

    -- 保护 -> 正常
    sm:addTransition(STATE_PROTECTED, STATE_NORMAL, function(ctx)
        return ctx.player.__requestState == "normal"
    end)

    -- 设置初始状态
    sm:setState(STATE_NORMAL)

    -- 添加便捷方法
    function sm:requestState(stateName)
        self.context.player.__requestState = stateName
    end

    function sm:clearRequest()
        self.context.player.__requestState = nil
    end

    return sm
end

return {
    createPlayerStateMachine = createPlayerStateMachine,
}

