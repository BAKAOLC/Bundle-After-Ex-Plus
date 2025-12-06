local math = math
---移动组件

---@class thlib.Player.MovementComponent : core.Component
---@field moveFunc function|nil 自定义移动函数 function(player, component)
---@field multipliers systems.MultiplierSystem|nil
---@field inputComp thlib.Player.InputComponent|nil
---@field stateComp thlib.Player.StateComponent|nil

---创建移动组件
---@param owner thlib.Player
---@param config table
---@return thlib.Player.MovementComponent
local function create(owner, config)
    config = config or {}

    ---@type thlib.Player.MovementComponent
    local component = {
        enabled = true,
        executePriority = 20,
        typeName = "movement",
        executeAfter = { "input" }, -- 必须在输入组件之后执行
        owner = owner,
        -- 组件自己存储配置
        highSpeed = config.highSpeed or 4.5,
        lowSpeed = config.lowSpeed or 2.0,
        use8Directions = config.use8Directions == nil and true or config.use8Directions,
        boundsLeft = (config.bounds and config.bounds.left) or 8,
        boundsRight = (config.bounds and config.bounds.right) or 8,
        boundsBottom = (config.bounds and config.bounds.bottom) or 16,
        boundsTop = (config.bounds and config.bounds.top) or 32,
        moveFunc = config.moveFunc,
        -- 依赖的组件引用
        multipliers = nil,
    }

    function component:resolveDependencies(gameObject)
        -- 获取倍率组件引用
        local multiplierComp = gameObject:getComponent("multiplier")
        if multiplierComp then
            self.multipliers = multiplierComp.multipliers
        end

        -- 获取输入组件
        local inputComp = gameObject:getComponent("input")
        self.inputComp = inputComp

        -- 获取状态组件
        local stateComp = gameObject:getComponent("state")
        self.stateComp = stateComp
    end

    function component:update()
        local player = self.owner

        if player.locked then
            player.__move_dx = 0
            player.__move_dy = 0
            return
        end

        -- 检查状态是否允许移动
        if self.stateComp then
            local state = self.stateComp.currentState
            if state ~= "normal" and state ~= "protected" then
                player.__move_dx = 0
                player.__move_dy = 0
                return
            end
        end

        -- 如果有自定义移动函数，使用它
        if self.moveFunc then
            self.moveFunc(player, self)
            return
        end

        -- 默认玩家输入移动
        self:defaultPlayerMovement()
    end

    function component:defaultPlayerMovement()
        local player = self.owner

        -- 从 InputComponent 获取移动向量
        local dx, dy = 0, 0
        if self.inputComp and self.inputComp.moveVector then
            dx = self.inputComp.moveVector.dx
            dy = self.inputComp.moveVector.dy
        end

        local magnitude = math.sqrt(dx * dx + dy * dy)

        if magnitude < 0.1 then
            player.__move_dx = 0
            player.__move_dy = 0
            return
        end

        -- 计算速度
        local speed = player.slow == 1 and self.lowSpeed or self.highSpeed
        if self.multipliers then
            speed = speed * self.multipliers:get("speed")
        end

        -- 计算角度
        local angle = math.atan2(dy, dx) * 180 / math.pi

        if self.use8Directions then
            angle = math.floor((angle + 360 + 22.5) / 45) * 45
        end

        -- 计算移动
        local rad = math.rad(angle)
        local moveX = speed * math.cos(rad)
        local moveY = speed * math.sin(rad)

        local newX = player.x + moveX
        local newY = player.y + moveY

        -- 限制边界
        local world = lstg.world
        newX = math.max(math.min(newX, world.pr - self.boundsRight), world.pl + self.boundsLeft)
        newY = math.max(math.min(newY, world.pt - self.boundsTop), world.pb + self.boundsBottom)

        player.__move_dx = newX - player.x
        player.__move_dy = newY - player.y

        player.x = newX
        player.y = newY
    end

    return component
end

return {
    create = create,
}

