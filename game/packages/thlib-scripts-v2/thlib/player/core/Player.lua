local require = require
local math = math
local table = table

local GameObjectMixin = require("core.GameObjectMixin")
local PlayerConfig = require("thlib.player.config.PlayerConfig")
local createEventDispatcher = require("foundation.EventDispatcher")

---@class thlib.Player : lstg.GameObject
---@field config thlib.Player.Config
---@field listener foundation.EventDispatcher 事件监听器
---@field componentSystem core.ComponentSystem
---@field slot number
---@field locked boolean
---@field slow number
---@field lh number 低速光环强度
---@field target lstg.GameObject|nil
---@field __move_dx number 本帧移动X
---@field __move_dy number 本帧移动Y
---@field addComponent fun(self: thlib.Player, component: core.Component, componentType: string): number
---@field removeComponent fun(self: thlib.Player, componentId: number)
---@field getComponent fun(self: thlib.Player, componentType: string): core.Component|nil
---@field getComponents fun(self: thlib.Player, componentType: string): table|nil
---@field resolveComponents fun(self: thlib.Player)
---@field updateComponents fun(self: thlib.Player)
---@field renderComponents fun(self: thlib.Player)
---@field _dispatchEvent fun(self: thlib.Player, eventName: string, ...)
---@field registerEvent fun(self: thlib.Player, eventName: string, listenerId: string, priority: number, callback: function)
---@field unregisterEvent fun(self: thlib.Player, eventName: string, listenerId: string)
local Player = lstg.CreateGameObjectClass()

function Player.create(slot, config)
    local self = lstg.New(Player)
    Player.initialize(self, slot, config)
    return self
end

---将类方法复制到对象上（使C++对象可以用冒号调用）
---@param self thlib.Player
local function mixinMethods(self)
    self._dispatchEvent = Player._dispatchEvent
    self.registerEvent = Player.registerEvent
    self.unregisterEvent = Player.unregisterEvent
end

---初始化玩家
---@param slot number 玩家槽位
---@param config table|nil 配置覆盖
function Player:initialize(slot, config)
    -- 混入组件系统
    GameObjectMixin.mixin(self)

    -- 基础设置
    self.group = GROUP_PLAYER
    self.layer = LAYER_PLAYER
    self.bound = false  -- 不会因为出屏而消失
    self.colli = true
    self.hide = false

    -- 加载配置
    self.config = PlayerConfig.merge(PlayerConfig.createDefault(), config or {})

    -- 初始化位置
    self.x = self.config.initialX
    self.y = self.config.initialY

    -- 碰撞盒设置
    self.a = self.config.a
    self.b = self.config.b
    self.rect = self.config.rect

    -- 初始化事件系统
    self.listener = createEventDispatcher()

    -- 复制方法到对象上
    mixinMethods(self)

    -- 基础状态变量
    self.slot = slot
    self.locked = false
    self.slow = 0
    self.target = nil

    -- 内部变量（由组件使用）
    self.__move_dx = 0
    self.__move_dy = 0
    self.__currentState = "normal"  -- 初始状态

    -- 触发初始化事件
    self:_dispatchEvent("onInit")
end

---添加默认组件
---@param componentConfigs table|nil 组件配置
function Player:setupComponents(componentConfigs)
    componentConfigs = componentConfigs or {}

    -- 基础系统组件
    local TimerComp = require("components.TimerComponent")
    local BuffComp = require("components.BuffComponent")
    local MultiplierComp = require("components.MultiplierComponent")

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
                StateComp.create(self, componentConfigs.state or {}),
                "state"
        )
    end

    -- 添加输入组件（默认启用）
    if componentConfigs.input ~= false then
        self:addComponent(
                InputComp.create(self, componentConfigs.input or {}),
                "input"
        )
    end

    -- 添加保护组件（默认启用）
    if componentConfigs.protect ~= false then
        self:addComponent(
                ProtectComp.create(self, componentConfigs.protect or {}),
                "protect"
        )
    end

    -- 添加火力组件（默认启用）
    if componentConfigs.power ~= false then
        self:addComponent(
                PowerComp.create(self, componentConfigs.power or {}),
                "power"
        )
    end

    -- 添加计时器组件（默认启用）
    if componentConfigs.timer ~= false then
        self:addComponent(
                TimerComp.create(self, componentConfigs.timer or {
                    timers = {
                        shoot = 0,
                        spell = 0,
                        special = 0,
                    }
                }),
                "timer"
        )
    end

    -- 添加Buff组件（默认启用）
    if componentConfigs.buff ~= false then
        self:addComponent(
                BuffComp.create(self, componentConfigs.buff or {}),
                "buff"
        )
    end

    -- 添加倍率组件（默认启用）
    if componentConfigs.multiplier ~= false then
        self:addComponent(
                MultiplierComp.create(self, componentConfigs.multiplier or {
                    multipliers = {
                        damage = 1.0,
                        speed = 1.0,
                    }
                }),
                "multiplier"
        )
    end

    -- 添加移动组件（默认启用，支持8向移动）
    if componentConfigs.movement ~= false then
        self:addComponent(
                MovementComp.create(self, componentConfigs.movement or {
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
                "movement"
        )
    end

    -- 添加碰撞处理组件（默认启用）
    if componentConfigs.collision ~= false then
        self:addComponent(
                CollisionComp.create(self, componentConfigs.collision or {}),
                "collision"
        )
    end

    -- 添加擦弹组件（默认启用）
    if componentConfigs.graze ~= false then
        self:addComponent(
                GrazeComp.create(self, componentConfigs.graze or {}),
                "graze"
        )
    end

    -- 添加子机组件
    if componentConfigs.option then
        self:addComponent(
                OptionComp.create(self, componentConfigs.option),
                "option"
        )
    end

    -- 添加射击组件
    if componentConfigs.shoot then
        self:addComponent(
                ShootComp.create(self, componentConfigs.shoot),
                "shoot"
        )
    end

    -- 添加符卡组件
    if componentConfigs.spell then
        self:addComponent(
                SpellComp.create(self, componentConfigs.spell),
                "spell"
        )
    end

    -- 添加复活组件（默认启用）
    if componentConfigs.respawn ~= false then
        self:addComponent(
                RespawnComp.create(self, componentConfigs.respawn or {}),
                "respawn"
        )
    end

    -- 添加死亡动画组件（默认启用）
    if componentConfigs.deathAnimation ~= false then
        self:addComponent(
                DeathAnimComp.create(self, componentConfigs.deathAnimation or {
                    style = "classic",
                }),
                "deathAnimation"
        )
    end

    -- 添加道具收集组件（默认启用）
    if componentConfigs.itemCollection ~= false then
        self:addComponent(
                ItemCollectComp.create(self, componentConfigs.itemCollection or {}),
                "itemCollection"
        )
    end

    -- 添加目标锁定组件（默认启用）
    if componentConfigs.targeting ~= false then
        self:addComponent(
                TargetingComp.create(self, componentConfigs.targeting or {}),
                "targeting"
        )
    end

    -- 添加行走图组件（默认启用）
    if componentConfigs.walkImage ~= false then
        self:addComponent(
                WalkImageComp.create(self, componentConfigs.walkImage or {}),
                "walkImage"
        )
    end

    -- 解析组件依赖
    self:resolveComponents()
end

---帧更新
function Player:frame()
    self:_dispatchEvent("onFrameBegin")
    self:updateComponents()
    self:_dispatchEvent("onFrameEnd")
end

---渲染
function Player:render()
    self:_dispatchEvent("onRenderBegin")
    self:renderComponents()
    self:_dispatchEvent("onRenderEnd")
end

---碰撞回调
---@param other lstg.GameObject
function Player:colli(other)
    -- 触发碰撞事件，由组件处理
    self:_dispatchEvent("onCollision", other)
end

---Kill回调
function Player:kill()
    PreserveObject(self)
    self:_dispatchEvent("onKill")
end

---触发事件
---@param eventName string
---@vararg any
---@return boolean 是否被阻止
function Player:_dispatchEvent(eventName, ...)
    self.listener:DispatchEvent(eventName, self, ...)
    return false
end

---注册事件
---@param eventName string
---@param name string
---@param priority number
---@param callback function
function Player:registerEvent(eventName, name, priority, callback)
    self.listener:RegisterEvent(eventName, name, priority, callback)
end

---取消注册事件
---@param eventName string
---@param name string
function Player:unregisterEvent(eventName, name)
    self.listener:UnregisterEvent(eventName, name)
end

---寻找目标敌人（优先纵向距离近的）
---@param count number|nil 目标数量，默认为1
---@return lstg.GameObject[] 目标数组，按优先级排序
function Player:findTargets(count)
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
end

return Player

