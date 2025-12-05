---符卡组件
---@class THlib.Player.SpellComponent : foundation.Component
---@field spellFunc function|nil
---@field costBomb boolean
---@field timers foundation.TimerSystem|nil
---@field inputComp THlib.Player.InputComponent|nil

---创建符卡组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.SpellComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.SpellComponent
    local component = {
        enabled = true,
        executePriority = 9,
        typeName = "spell",
        owner = owner,
        spellFunc = config.onSpell or config.spellFunc,
        costBomb = config.costBomb ~= false,
        interval = config.interval or 0,
    }

    function component:resolveDependencies(gameObject)
        -- 获取计时器组件
        local timerComp = gameObject:getComponent("timer")
        if timerComp then
            self.timers = timerComp.timers
            -- 设置符卡计时器的间隔
            if self.interval > 0 then
                local spellTimer = self.timers:getTimer("spell")
                if spellTimer then
                    spellTimer:setInterval(self.interval)
                end
            end
        end

        -- 获取输入组件
        local inputComp = gameObject:getComponent("input")
        self.inputComp = inputComp
    end

    function component:update()
        local player = self.owner

        if not self.inputComp or not self.inputComp.keyState.spell then
            return
        end

        if not self.timers or not self.timers:isReady("spell") then
            return
        end

        if player.__currentState == "deathSpell" then
            self:_useDeathSpell()
            return
        end

        if self.costBomb then
            if lstg.var.bomb <= 0 then
                return
            end
            lstg.var.bomb = lstg.var.bomb - 1
            item.PlayerSpell()
        end

        if self.timers then
            self.timers:trigger("spell")
        end

        if self.spellFunc then
            self.spellFunc(player)
        end
    end

    function component:_useDeathSpell()
        local player = self.owner

        if lstg.var.bomb <= 0 then
            return
        end

        lstg.var.bomb = lstg.var.bomb - 1
        item.PlayerSpell()

        player.__deathSpellSaved = true
        player.__shouldEnterDeathSpell = false

        -- 设置保护时间
        local protectComp = player:getComponent("protect")
        if protectComp then
            protectComp:setProtect(60)
        end

        New(bullet_deleter, player.x, player.y)

        player:_dispatchEvent("onDeathSpellUsed")

        if self.timers then
            self.timers:trigger("spell")
        end

        if self.spellFunc then
            self.spellFunc(player)
        end
    end

    return component
end

return {
    create = create,
}

