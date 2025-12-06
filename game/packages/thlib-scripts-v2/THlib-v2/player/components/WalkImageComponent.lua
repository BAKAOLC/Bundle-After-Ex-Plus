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

        -- 用于追踪进入/退出动画的帧对应关系
        local leftEnterExitProgress = 0  -- 0-1 之间，表示在进入/退出序列中的位置
        local rightEnterExitProgress = 0

        -- 辅助函数：根据进度设置动画帧
        local function setAnimationProgress(animName, progress)
            local anim = ws.animations[animName]
            if not anim then
                return
            end

            local frameCount = #anim.frames
            if frameCount == 0 then
                return
            end

            -- 将进度转换为帧索引（1-based）
            local frameIndex = math.floor(progress * (frameCount - 1)) + 1
            frameIndex = math.max(1, math.min(frameIndex, frameCount))

            ws.animationIndex = frameIndex
            ws.currentFrame = anim.frames[frameIndex]
            ws.animationTimer = 0
            ws.animationFinished = false
        end

        -- 辅助函数：获取当前动画进度
        local function getAnimationProgress()
            if not ws.currentAnimation then
                return 0
            end
            local frameCount = #ws.currentAnimation.frames
            if frameCount <= 1 then
                return 0
            end
            return (ws.animationIndex - 1) / (frameCount - 1)
        end

        -- 注册状态，使用自定义回调来处理帧对应
        ws:registerAnimationState("idle")

        -- 左移进入状态
        ws:registerAnimationState("move_left_enter", nil, true, {
            onEnter = function(ctx)
                -- 如果从左移退出打断过来，使用对应的进度
                if leftEnterExitProgress > 0 then
                    setAnimationProgress("move_left_enter", leftEnterExitProgress)
                    leftEnterExitProgress = 0
                end
            end,
            onUpdate = function(ctx, dt)
                -- 记录当前进度
                leftEnterExitProgress = getAnimationProgress()
            end
        })

        -- 左移循环状态
        ws:registerAnimationState("move_left_loop", nil, true, {
            onEnter = function(ctx)
                -- 进入循环时，重置进度为满（用于后续可能的退出）
                leftEnterExitProgress = 1
            end
        })

        -- 左移退出状态
        ws:registerAnimationState("move_left_exit", nil, true, {
            onEnter = function(ctx)
                -- 从进入或循环状态过来时，使用反向进度
                setAnimationProgress("move_left_exit", 1 - leftEnterExitProgress)
            end,
            onUpdate = function(ctx, dt)
                -- 记录当前进度（反向，用于可能的重新进入）
                leftEnterExitProgress = 1 - getAnimationProgress()
            end
        })

        -- 右移进入状态
        ws:registerAnimationState("move_right_enter", nil, true, {
            onEnter = function(ctx)
                -- 如果从右移退出打断过来，使用对应的反向进度
                if rightEnterExitProgress > 0 then
                    setAnimationProgress("move_right_enter", rightEnterExitProgress)
                    rightEnterExitProgress = 0
                end
            end,
            onUpdate = function(ctx, dt)
                -- 记录当前进度
                rightEnterExitProgress = getAnimationProgress()
            end
        })

        -- 右移循环状态
        ws:registerAnimationState("move_right_loop", nil, true, {
            onEnter = function(ctx)
                -- 进入循环时，重置进度为满（用于后续可能的退出）
                rightEnterExitProgress = 1
            end
        })

        -- 右移退出状态
        ws:registerAnimationState("move_right_exit", nil, true, {
            onEnter = function(ctx)
                -- 从进入或循环状态过来时，使用反向进度
                setAnimationProgress("move_right_exit", 1 - rightEnterExitProgress)
            end,
            onUpdate = function(ctx, dt)
                -- 记录当前进度（反向，用于可能的重新进入）
                rightEnterExitProgress = 1 - getAnimationProgress()
            end
        })

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

        -- 打断1：进入状态停下来 -> 退出状态（保留帧对应）
        sm:addTransition("move_left_enter", "move_left_exit", isIdle)
        sm:addTransition("move_right_enter", "move_right_exit", isIdle)

        -- 左移循环 -> 左移退出（停止移动）
        sm:addTransition("move_left_loop", "move_left_exit", isIdle)

        -- 右移循环 -> 右移退出（停止移动）
        sm:addTransition("move_right_loop", "move_right_exit", isIdle)

        -- 打断2：退出状态重新移动 -> 进入状态（保留帧对应）
        sm:addTransition("move_left_exit", "move_left_enter", isMovingLeft)
        sm:addTransition("move_right_exit", "move_right_enter", isMovingRight)

        -- 左移退出 -> 静止（动画播完）
        sm:addTransition("move_left_exit", "idle", animationFinished)

        -- 右移退出 -> 静止（动画播完）
        sm:addTransition("move_right_exit", "idle", animationFinished)

        -- 打断3：反向移动（在循环状态）
        sm:addTransition("move_left_loop", "move_right_enter", isMovingRight)
        sm:addTransition("move_right_loop", "move_left_enter", isMovingLeft)

        -- 打断4：反向移动（在进入状态，动画未播完）
        sm:addTransition("move_left_enter", "move_right_enter", isMovingRight)
        sm:addTransition("move_right_enter", "move_left_enter", isMovingLeft)

        -- 打断5：反向移动（在退出状态，动画未播完）
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
