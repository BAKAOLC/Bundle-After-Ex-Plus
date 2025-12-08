---输入组件
local input_rep = require("foundation.input.replay")
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---@class thlib.Player.InputComponent : core.Component
---@field keyState {slow: boolean, shoot: boolean, spell: boolean, special: boolean}
---@field moveVector {dx: number, dy: number}
---@field inputFunc function|nil 自定义输入函数
---@field stateComp thlib.Player.StateComponent|nil

-- 定义组件类型
local InputComponentType = TypeDef.create("thlib.Player.InputComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 98,
        alias = "input",
        keyState = {
            slow = false,
            shoot = false,
            spell = false,
            special = false,
        },
        moveVector = { dx = 0, dy = 0 },
        inputFunc = nil,
        stateComp = nil,
    },
    methods = {
        Start = function(self)
            -- 获取状态组件
            self.stateComp = self.owner:getComponent("state")
        end,

        Update = function(self)
            local player = self.owner

            -- 如果有自定义输入函数，使用它
            if self.inputFunc then
                self.inputFunc(player, self)
                return
            end

            -- 默认玩家输入
            self:defaultInput()

            -- 只在普通状态时更新玩家的slow状态
            if self.stateComp and self.stateComp.currentState == "normal" then
                if player.slowlock then
                    player.slow = 1
                else
                    player.slow = self.keyState.slow and 1 or 0
                end
            end
        end,

        defaultInput = function(self)
            -- 使用向量获取移动输入
            local dx, dy = input_rep.getVector2ActionValue("move")
            self.moveVector.dx = dx
            self.moveVector.dy = dy

            -- 按键状态
            self.keyState.slow = KeyIsDown("slow")
            self.keyState.shoot = KeyIsDown("shoot")
            self.keyState.spell = KeyIsDown("spell")
            self.keyState.special = KeyIsDown("special")
        end,
    },
})

---创建输入组件
---@param config {inputFunc: function|nil}|nil
---@return thlib.Player.InputComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(InputComponentType, {
        inputFunc = config.inputFunc,
    })
end

return {
    create = create,
    Type = InputComponentType,
}

