local math = math

---行走图组件
local WalkImageSystem = require("foundation.WalkImageSystem")

---@class THlib.Player.WalkImageComponent : foundation.Component
---@field walkSystem foundation.WalkImageSystem
---@field moveThreshold number 触发移动动画的阈值
---@field protectComp THlib.Player.ProtectComponent|nil

---创建行走图组件
---@param owner THlib.Player
---@param config table
---@return THlib.Player.WalkImageComponent
local function create(owner, config)
    config = config or {}

    ---@type THlib.Player.WalkImageComponent
    local component = {
        enabled = true,
        executePriority = 5, -- 渲染相关，优先级较低
        typeName = "walkImage",
        owner = owner,
        walkSystem = nil,
        moveThreshold = config.moveThreshold or 0.5,
        protectComp = nil,
    }

    function component:resolveDependencies(gameObject)
        -- 获取保护组件引用
        self.protectComp = gameObject:getComponent("protect")
    end

    function component:onAdd()
        local player = self.owner

        -- 创建行走图系统
        self.walkSystem = WalkImageSystem.new(player, config.texture)

        local view = require("lib.debug.StateMachineView")
        view:addWatch(self.walkSystem.stateMachine)

        -- 注册图像帧（由具体玩家实现自定义）
        if config.registerFrames then
            config.registerFrames(self.walkSystem)
        end

        -- 注册动画（由具体玩家实现自定义）
        if config.registerAnimations then
            config.registerAnimations(self.walkSystem)
        end

        -- 设置默认状态
        self:setupDefaultStates()

        -- 初始状态
        self.walkSystem:setState("idle")
    end

    function component:setupDefaultStates()
        local ws = self.walkSystem
        local thisComponent = self

        -- 使用简化方法注册状态（自动处理动画播放和更新）
        ws:registerAnimationState("idle")
        ws:registerAnimationState("move_left_enter")
        ws:registerAnimationState("move_left_loop")
        ws:registerAnimationState("move_left_exit")
        ws:registerAnimationState("move_right_enter")
        ws:registerAnimationState("move_right_loop")
        ws:registerAnimationState("move_right_exit")

        -- 获取状态机引用（用于添加转换）
        local sm = ws.stateMachine

        -- 状态转换条件
        local function isMovingLeft(ctx)
            local player = ctx.owner.obj
            local dx = player.__move_dx or 0
            return dx < -thisComponent.moveThreshold
        end

        local function isMovingRight(ctx)
            local player = ctx.owner.obj
            local dx = player.__move_dx or 0
            return dx > thisComponent.moveThreshold
        end

        local function isIdle(ctx)
            local player = ctx.owner.obj
            local dx = player.__move_dx or 0
            return math.abs(dx) <= thisComponent.moveThreshold
        end

        local function animationFinished(ctx)
            return ctx.owner.animationFinished
        end

        -- 从静止到移动
        sm:addTransition("idle", "move_left_enter", isMovingLeft)
        sm:addTransition("idle", "move_right_enter", isMovingRight)

        -- 左移进入 -> 左移循环（动画播完）
        sm:addTransition("move_left_enter", "move_left_loop", animationFinished)

        -- 右移进入 -> 右移循环（动画播完）
        sm:addTransition("move_right_enter", "move_right_loop", animationFinished)

        -- 左移循环 -> 左移退出（停止移动）
        sm:addTransition("move_left_loop", "move_left_exit", isIdle)

        -- 右移循环 -> 右移退出（停止移动）
        sm:addTransition("move_right_loop", "move_right_exit", isIdle)

        -- 左移退出 -> 静止（动画播完）
        sm:addTransition("move_left_exit", "idle", animationFinished)

        -- 右移退出 -> 静止（动画播完）
        sm:addTransition("move_right_exit", "idle", animationFinished)

        -- 左右切换（在循环状态）
        sm:addTransition("move_left_loop", "move_right_enter", isMovingRight)
        sm:addTransition("move_right_loop", "move_left_enter", isMovingLeft)

        -- 左右切换（在进入状态，动画未播完）
        sm:addTransition("move_left_enter", "move_right_enter", isMovingRight)
        sm:addTransition("move_right_enter", "move_left_enter", isMovingLeft)

        -- 左右切换（在退出状态，动画未播完）
        sm:addTransition("move_left_exit", "move_right_enter", isMovingRight)
        sm:addTransition("move_right_exit", "move_left_enter", isMovingLeft)
    end

    function component:update()
        -- 更新状态机
        self.walkSystem:update(1)
    end

    function component:render()
        -- 检查 protect 状态并应用闪烁效果
        if self.protectComp and self.protectComp.protectTimer > 0 then
            if self.protectComp.protectTimer % 3 == 1 then
                -- 红绿通道设为0，实现闪烁效果
                self.walkSystem:addColorScale("protect", 0, 0, 1, 1)
            else
                self.walkSystem:removeColorScale("protect")
            end
        else
            self.walkSystem:removeColorScale("protect")
        end

        -- 渲染行走图
        self.walkSystem:render()
    end

    return component
end

return {
    create = create,
}
