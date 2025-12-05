---输入组件
local input_rep = require("foundation.input.replay")

---@class THlib.Player.InputComponent : foundation.Component
---@field keyState table
---@field moveVector table {dx, dy}
---@field inputFunc function|nil 自定义输入函数

---创建输入组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.InputComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.InputComponent
    local component = {
        enabled = true,
        executePriority = 98,
        typeName = "input",
        owner = owner,
        keyState = {
            slow = false,
            shoot = false,
            spell = false,
            special = false,
        },
        moveVector = { dx = 0, dy = 0 },
        inputFunc = config.inputFunc,
    }

    function component:update()
        local player = self.owner

        -- 如果有自定义输入函数，使用它
        if self.inputFunc then
            self.inputFunc(player, self)
            return
        end

        -- 默认玩家输入
        self:defaultInput()

        -- 更新玩家的slow状态
        player.slow = self.keyState.slow and 1 or 0
    end

    function component:defaultInput()
        -- 使用向量获取移动输入
        local dx, dy = input_rep.getVector2ActionValue("move")
        self.moveVector.dx = dx
        self.moveVector.dy = dy

        -- 按键状态
        self.keyState.slow = KeyIsDown("slow")
        self.keyState.shoot = KeyIsDown("shoot")
        self.keyState.spell = KeyIsDown("spell")
        self.keyState.special = KeyIsDown("special")
    end

    return component
end

return {
    create = create,
}

