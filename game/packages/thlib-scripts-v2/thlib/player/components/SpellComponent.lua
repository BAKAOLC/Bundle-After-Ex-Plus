---符卡组件
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.SpellComponent : core.Component
---@field spellFunc function|nil
---@field costBomb boolean
---@field timerComp components.TimerComponent|nil
---@field inputComp thlib.Player.InputComponent|nil
---@field protectComp thlib.Player.ProtectComponent|nil
---@field stateComp thlib.Player.StateComponent|nil

-- 定义组件类型
local SpellComponentType = TypeDef.create("thlib.Player.SpellComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 9,
        spellFunc = nil,
        costBomb = true,
        interval = 0,
        timerComp = nil,
        inputComp = nil,
        protectComp = nil,
        stateComp = nil,
    },
    methods = {
        Start = function(self)
            -- 获取计时器组件
            self.timerComp = self.owner:getComponent("timer")
            -- 设置符卡计时器的间隔
            if self.timerComp and self.interval > 0 then
                local spellTimer = self.timerComp:getTimer("spell")
                if spellTimer then
                    spellTimer:setInterval(self.interval)
                end
            end

            -- 获取输入组件
            local inputComp = self.owner:getComponent("input")
            self.inputComp = inputComp

            -- 获取保护组件
            self.protectComp = self.owner:getComponent("protect")

            -- 获取状态组件
            self.stateComp = self.owner:getComponent("state")
        end,

        Update = function(self)
            local player = self.owner

            if not self.inputComp or not self.inputComp.keyState.spell then
                return
            end

            if not self.timerComp or not self.timerComp:isReady("spell") then
                return
            end

            -- 禁止在死亡动画和重生状态下放雷
            if player.__currentState == "dying" or player.__currentState == "respawning" then
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

            if self.timerComp then
                self.timerComp:trigger("spell")
            end

            if self.spellFunc then
                self.spellFunc(player)
            end
        end,

        _useDeathSpell = function(self)
            local player = self.owner

            if lstg.var.bomb <= 0 then
                return
            end

            lstg.var.bomb = lstg.var.bomb - 1
            item.PlayerSpell()

            player.__deathSpellSaved = true
            player.__shouldEnterDeathSpell = false

            -- 设置保护时间
            if self.protectComp then
                self.protectComp:setProtect(60)
            end

            New(bullet_deleter, player.x, player.y)

            player:_dispatchEvent("SpellComponent:onDeathSpellUsed")

            -- 切换回normal状态
            if self.stateComp then
                self.stateComp:saveFromDeathSpell()
            end

            if self.timerComp then
                self.timerComp:trigger("spell")
            end

            if self.spellFunc then
                self.spellFunc(player)
            end
        end,
    },
})

---创建符卡组件
---@param config table
---@return thlib.Player.SpellComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(SpellComponentType, {
        spellFunc = config.onSpell or config.spellFunc,
        costBomb = config.costBomb ~= false,
        interval = config.interval or 0,
    })
end

return {
    create = create,
    Type = SpellComponentType,
}

