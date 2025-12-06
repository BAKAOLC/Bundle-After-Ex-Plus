local require = require
local math = math
local table = table

local GameObject = require("core.GameObject")
local TypeDef = require("core.TypeDef")
local PlayerConfig = require("thlib.player.config.PlayerConfig")
local createEventDispatcher = require("foundation.EventDispatcher")

---@class thlib.Player : core.GameObject
---@field config thlib.Player.Config
---@field listener foundation.EventDispatcher 事件监听器
---@field slot number
---@field locked boolean
---@field slow number
---@field lh number 低速光环强度
---@field target lstg.GameObject|nil
---@field __move_dx number 本帧移动X
---@field __move_dy number 本帧移动Y

-- 定义 Player 类型（继承自 GameObject）
local PlayerType = TypeDef.create("thlib.Player", GameObject.Type, {
    defaults = {
        group = GROUP_PLAYER,
        layer = LAYER_PLAYER,
        bound = false, -- 不会因为出屏而消失
        colli = true,
        hide = false,
        slot = 0,
        locked = false,
        slow = 0,
        target = nil,
        __move_dx = 0,
        __move_dy = 0,
        __currentState = "normal", -- 初始状态
    },
    methods = {
        Awake = function(self)
            -- 初始化事件系统
            self.listener = createEventDispatcher()

            -- 触发初始化事件
            self:_dispatchEvent("onInit")
        end,

        Update = function(self)
            self:_dispatchEvent("onFrameBegin")
        end,

        LateUpdate = function(self)
            self:_dispatchEvent("onFrameEnd")
        end,

        OnRender = function(self)
            self:_dispatchEvent("onRenderBegin")
        end,

        OnCollision = function(self, other)
            -- 触发碰撞事件，由组件处理
            self:_dispatchEvent("onCollision", other)
        end,

        OnDelete = function(self)
            -- 触发删除事件
            self:_dispatchEvent("onDelete")
        end,

        OnDestroy = function(self)
            PreserveObject(self)
            self:_dispatchEvent("onKill")
        end,

        _dispatchEvent = function(self, eventName, ...)
            self.listener:DispatchEvent(eventName, self, ...)
            return false
        end,

        registerEvent = function(self, eventName, name, priority, callback)
            self.listener:RegisterEvent(eventName, name, priority, callback)
        end,

        unregisterEvent = function(self, eventName, name)
            self.listener:UnregisterEvent(eventName, name)
        end,

        setupComponents = function(self, componentConfigs)
            componentConfigs = componentConfigs or {}

            -- 基础系统组件
            local TimerComp = require("components.TimerComponent")
            local BuffComp = require("components.BuffComponent")
            local ModifierComp = require("components.ModifierComponent")

            -- 玩家组件
            local StateComp = require("thlib.player.components.StateComponent")
            local InputComp = require("thlib.player.components.InputComponent")
            local ProtectComp = require("thlib.player.components.ProtectComponent")
            local PowerComp = require("thlib.player.components.PowerComponent")
            local MovementComp = require("thlib.player.components.MovementComponent")
            local ShootComp = require("thlib.player.components.ShootComponent")
            local SpellComp = require("thlib.player.components.SpellComponent")
            local DeathAnimComp = require("thlib.player.components.DeathAnimationComponent")
            local ItemCollectComp = require("thlib.player.components.ItemCollectionComponent")
            local TargetingComp = require("thlib.player.components.TargetingComponent")
            local GrazeComp = require("thlib.player.components.GrazeComponent")
            local CollisionComp = require("thlib.player.components.CollisionComponent")
            local OptionComp = require("thlib.player.components.OptionComponent")
            local RespawnComp = require("thlib.player.components.RespawnComponent")
            local WalkImageComp = require("thlib.player.components.WalkImageComponent")

            -- 添加状态机组件（默认启用）
            if componentConfigs.state ~= false then
                self:addComponent(
                        StateComp.create(componentConfigs.state or {}),
                        StateComp.Type.typeName
                )
            end

            -- 添加输入组件（默认启用）
            if componentConfigs.input ~= false then
                self:addComponent(
                        InputComp.create(componentConfigs.input or {}),
                        InputComp.Type.typeName
                )
            end

            -- 添加保护组件（默认启用）
            if componentConfigs.protect ~= false then
                self:addComponent(
                        ProtectComp.create(componentConfigs.protect or {}),
                        ProtectComp.Type.typeName
                )
            end

            -- 添加火力组件（默认启用）
            if componentConfigs.power ~= false then
                self:addComponent(
                        PowerComp.create(componentConfigs.power or {}),
                        PowerComp.Type.typeName
                )
            end

            -- 添加计时器组件（默认启用）
            if componentConfigs.timer ~= false then
                self:addComponent(
                        TimerComp.create(componentConfigs.timer or {
                            timers = {
                                shoot = 0,
                                spell = 0,
                                special = 0,
                            }
                        }),
                        TimerComp.Type.typeName
                )
            end

            -- 添加Buff组件（默认启用）
            if componentConfigs.buff ~= false then
                self:addComponent(
                        BuffComp.create(componentConfigs.buff or {}),
                        BuffComp.Type.typeName
                )
            end

            -- 添加修饰器组件（默认启用）
            if componentConfigs.modifier ~= false then
                self:addComponent(
                        ModifierComp.create(componentConfigs.modifier or {}),
                        ModifierComp.Type.typeName
                )
            end

            -- 添加移动组件（默认启用，支持8向移动）
            if componentConfigs.movement ~= false then
                self:addComponent(
                        MovementComp.create(componentConfigs.movement or {
                            highSpeed = 4.5,
                            lowSpeed = 2.0,
                            use8Directions = true,
                            bounds = {
                                left = 8,
                                right = 8,
                                bottom = 16,
                                top = 32,
                            }
                        }),
                        MovementComp.Type.typeName
                )
            end

            -- 添加碰撞处理组件（默认启用）
            if componentConfigs.collision ~= false then
                self:addComponent(
                        CollisionComp.create(componentConfigs.collision or {}),
                        CollisionComp.Type.typeName
                )
            end

            -- 添加擦弹组件（默认启用）
            if componentConfigs.graze ~= false then
                self:addComponent(
                        GrazeComp.create(componentConfigs.graze or {}),
                        GrazeComp.Type.typeName
                )
            end

            -- 添加子机组件
            if componentConfigs.option then
                self:addComponent(
                        OptionComp.create(componentConfigs.option),
                        OptionComp.Type.typeName
                )
            end

            -- 添加射击组件
            if componentConfigs.shoot then
                self:addComponent(
                        ShootComp.create(componentConfigs.shoot),
                        ShootComp.Type.typeName
                )
            end

            -- 添加符卡组件
            if componentConfigs.spell then
                self:addComponent(
                        SpellComp.create(componentConfigs.spell),
                        SpellComp.Type.typeName
                )
            end

            -- 添加复活组件（默认启用）
            if componentConfigs.respawn ~= false then
                self:addComponent(
                        RespawnComp.create(componentConfigs.respawn or {}),
                        RespawnComp.Type.typeName
                )
            end

            -- 添加死亡动画组件（默认启用）
            if componentConfigs.deathAnimation ~= false then
                self:addComponent(
                        DeathAnimComp.create(componentConfigs.deathAnimation or {
                            style = "classic",
                        }),
                        DeathAnimComp.Type.typeName
                )
            end

            -- 添加道具收集组件（默认启用）
            if componentConfigs.itemCollection ~= false then
                self:addComponent(
                        ItemCollectComp.create(componentConfigs.itemCollection or {}),
                        ItemCollectComp.Type.typeName
                )
            end

            -- 添加目标锁定组件（默认启用）
            if componentConfigs.targeting ~= false then
                self:addComponent(
                        TargetingComp.create(componentConfigs.targeting or {}),
                        TargetingComp.Type.typeName
                )
            end

            -- 添加行走图组件（默认启用）
            if componentConfigs.walkImage ~= false then
                self:addComponent(
                        WalkImageComp.create(componentConfigs.walkImage or {}),
                        WalkImageComp.Type.typeName
                )
            end
        end,

        findTargets = function(self, count)
            count = count or 1
            local candidates = {}

            -- 收集所有可碰撞的敌人
            for _, o in ObjList(GROUP_ENEMY) do
                if o.colli then
                    local dx = self.x - o.x
                    local dy = self.y - o.y
                    local pri = math.abs(dy) / (math.abs(dx) + 0.01)
                    table.insert(candidates, { obj = o, priority = pri })
                end
            end

            for _, o in ObjList(GROUP_NONTJT) do
                if o.colli then
                    local dx = self.x - o.x
                    local dy = self.y - o.y
                    local pri = math.abs(dy) / (math.abs(dx) + 0.01)
                    table.insert(candidates, { obj = o, priority = pri })
                end
            end

            -- 按优先级排序（从高到低）
            table.sort(candidates, function(a, b)
                return a.priority > b.priority
            end)

            -- 提取前 count 个目标
            local targets = {}
            for i = 1, math.min(count, #candidates) do
                targets[i] = candidates[i].obj
            end

            return targets
        end,
    },
})

---创建玩家对象
---@param slot number 玩家槽位
---@param config table|nil 配置覆盖
---@return thlib.Player
local function create(slot, config)
    config = config or {}

    -- 加载配置
    local playerConfig = PlayerConfig.merge(PlayerConfig.createDefault(), config)

    -- 创建玩家实例
    local player = GameObject.create(PlayerType, {
        slot = slot,
        locked = false,
        slow = 0,
        target = nil,
        __move_dx = 0,
        __move_dy = 0,
        __currentState = "normal",
        -- 基础设置
        group = GROUP_PLAYER,
        layer = LAYER_PLAYER,
        bound = false,
        colli = true,
        hide = false,
        -- 初始化位置
        x = playerConfig.initialX,
        y = playerConfig.initialY,
        -- 碰撞盒设置
        a = playerConfig.a,
        b = playerConfig.b,
        rect = playerConfig.rect,
        -- 保存配置
        config = playerConfig,
    })

    return player
end

---静态方法：寻找目标敌人（优先纵向距离近的）
---@param selfObj lstg.GameObject 调用对象（可以是玩家或子弹等）
---@param count number|nil 目标数量，默认为1
---@return lstg.GameObject[] 目标数组，按优先级排序
local function findTargets(selfObj, count)
    count = count or 1
    local candidates = {}

    -- 收集所有可碰撞的敌人
    for _, o in ObjList(GROUP_ENEMY) do
        if o.colli then
            local dx = selfObj.x - o.x
            local dy = selfObj.y - o.y
            local pri = math.abs(dy) / (math.abs(dx) + 0.01)
            table.insert(candidates, { obj = o, priority = pri })
        end
    end

    for _, o in ObjList(GROUP_NONTJT) do
        if o.colli then
            local dx = selfObj.x - o.x
            local dy = selfObj.y - o.y
            local pri = math.abs(dy) / (math.abs(dx) + 0.01)
            table.insert(candidates, { obj = o, priority = pri })
        end
    end

    -- 按优先级排序（从高到低）
    table.sort(candidates, function(a, b)
        return a.priority > b.priority
    end)

    -- 提取前 count 个目标
    local targets = {}
    for i = 1, math.min(count, #candidates) do
        targets[i] = candidates[i].obj
    end

    return targets
end

return {
    create = create,
    Type = PlayerType,
    findTargets = findTargets,
}
