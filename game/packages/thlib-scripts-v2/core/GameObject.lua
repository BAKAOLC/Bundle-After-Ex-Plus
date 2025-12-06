local pairs = pairs
local error = error

local GameObjectMixin = require("core.GameObjectMixin")
local TypeDef = require("core.TypeDef")
local createEventDispatcher = require("foundation.EventDispatcher")

---@type lstg.GlobalEventDispatcher
local gameEventDispatcher = lstg.globalEventDispatcher

-- 定义基础 GameObject 类型
local GameObjectType = TypeDef.create("core.GameObject")

---@class core.GameObject : lstg.GameObject
---@field typeDef core.TypeDef 类型定义
---@field componentSystem core.ComponentSystem 组件系统
---@field _lifecycleStarted boolean 生命周期是否已开始（Start 是否已调用）
---@field listener foundation.EventDispatcher|nil 事件监听器（延迟初始化）
---@field addComponent fun(self: core.GameObject, component: core.Component, componentType: string): number
---@field removeComponent fun(self: core.GameObject, componentId: number)
---@field getComponent fun(self: core.GameObject, componentType: string): core.Component|nil
---@field getComponents fun(self: core.GameObject, componentType: string): table|nil
---@field startComponents fun(self: core.GameObject) 处理组件 Start 生命周期
---@field updateComponents fun(self: core.GameObject) 更新组件 Update 生命周期
---@field lateUpdateComponents fun(self: core.GameObject) 更新组件 LateUpdate 生命周期
---@field renderComponents fun(self: core.GameObject) 渲染组件
---@field isTypeOf fun(self: core.GameObject, typeName: string): boolean 检查是否为指定类型或其子类型
---@field _dispatchEvent fun(self: core.GameObject, eventName: string, ...): boolean 分发事件
---@field registerEvent fun(self: core.GameObject, eventName: string, name: string, priority: number, callback: function) 注册事件监听
---@field unregisterEvent fun(self: core.GameObject, eventName: string, name: string) 取消注册事件监听
---@field Awake fun(self: core.GameObject)|nil 对象创建后立即调用（在 init 中）
---@field Start fun(self: core.GameObject)|nil 第一次 frame 之前调用
---@field Update fun(self: core.GameObject)|nil 每帧更新（在组件更新之前）
---@field LateUpdate fun(self: core.GameObject)|nil 每帧更新后（在组件更新之后）
---@field OnRender fun(self: core.GameObject)|nil 渲染时调用
---@field OnCollision fun(self: core.GameObject, other: lstg.GameObject)|nil 碰撞时调用
---@field OnDelete fun(self: core.GameObject)|nil 删除时调用（简单销毁回调）
---@field OnDestroy fun(self: core.GameObject)|nil 销毁时调用（执行特定事件）

---基础 GameObject 类
local GameObject = lstg.CreateGameObjectClass()

---初始化对象
function GameObject:init()
    -- 混入组件系统
    GameObjectMixin.mixin(self)

    -- 初始化生命周期状态
    self._lifecycleStarted = false

    -- 事件系统延迟初始化（只在需要时创建）
    self.listener = nil
end

---获取或创建事件监听器（延迟初始化）
---@return foundation.EventDispatcher
function GameObject:_getListener()
    if not self.listener then
        self.listener = createEventDispatcher()
    end
    return self.listener
end

---分发事件
---@param eventName string 事件名称
---@vararg any 事件参数
---@return boolean
function GameObject:_dispatchEvent(eventName, ...)
    local listener = self:_getListener()
    return listener:DispatchEvent(eventName, self, ...)
end

---注册事件监听
---@param eventName string 事件名称
---@param name string 监听器名称
---@param priority number 优先级
---@param callback function 回调函数
function GameObject:registerEvent(eventName, name, priority, callback)
    local listener = self:_getListener()
    listener:RegisterEvent(eventName, name, priority, callback)
end

---取消注册事件监听
---@param eventName string 事件名称
---@param name string 监听器名称
function GameObject:unregisterEvent(eventName, name)
    if self.listener then
        self.listener:UnregisterEvent(eventName, name)
    end
end

---帧更新
function GameObject:frame()
    -- 第一次调用时触发 Start
    if not self._lifecycleStarted then
        self._lifecycleStarted = true
        local start = self.Start
        if start then
            start(self)
        end

        -- 处理组件 Start 生命周期（第一次调用时，在 GameObject Update 之前）
        self:startComponents()
    end

    -- 调用 Update 生命周期（在组件更新之前）
    local update = self.Update
    if update then
        update(self)
    end

    -- 更新组件 Update 生命周期
    self:updateComponents()
end

---渲染
function GameObject:render()
    -- 调用 OnRender 生命周期
    local onRender = self.OnRender
    if onRender then
        onRender(self)
    end

    -- 渲染组件系统
    self:renderComponents()
end

---碰撞回调
---@param other lstg.GameObject
function GameObject:colli(other)
    -- 调用 OnCollision 生命周期
    local onCollision = self.OnCollision
    if onCollision then
        onCollision(self, other)
    end
end

---删除回调（简单销毁对象，不执行特定事件）
function GameObject:del()
    -- 调用 OnDelete 生命周期
    local onDelete = self.OnDelete
    if onDelete then
        onDelete(self)
    end
end

---销毁回调（执行特定事件）
function GameObject:kill()
    -- 调用 OnDestroy 生命周期
    local onDestroy = self.OnDestroy
    if onDestroy then
        onDestroy(self)
    end
end

---创建 GameObject 实例
---@param typeDef core.TypeDef 类型定义（必需）
---@param config table|nil 可选的配置，包含生命周期方法等
---@return core.GameObject
function GameObject.create(typeDef, config)
    if not typeDef then
        error("TypeDef is required for GameObject.create", 2)
    end

    -- 创建 GameObject 实例
    local self = lstg.New(GameObject)

    -- 从 TypeDef 创建实例并合并属性
    local typeDefInstance = TypeDef.instantiate(typeDef, config)

    -- 将 TypeDef 实例的属性复制到 GameObject 实例
    for k, v in pairs(typeDefInstance) do
        self[k] = v
    end

    -- 在赋值完 config 后调用 Awake
    local awake = self.Awake
    if awake then
        awake(self)
    end

    return self
end

---检查对象是否为指定类型或其子类型
---@param targetType core.TypeDef|string 要检查的类型，可以是 TypeDef 对象或类型名称字符串
---@return boolean
function GameObject:isTypeOf(targetType)
    if not self.typeDef then
        return false
    end
    return TypeDef.isTypeOf(self.typeDef, targetType)
end

--region LateUpdate System
---LateUpdate 系统
---在 GameState.AfterObjFrame 事件中执行所有 GameObject 的 LateUpdate
local lateUpdateSystem = {
    initialized = false,
}

---初始化 LateUpdate 系统
function lateUpdateSystem:init()
    if self.initialized then
        return
    end
    self.initialized = true

    gameEventDispatcher:RegisterEvent("GameState.AfterObjFrame",
            "core.GameObject.LateUpdateSystem.on_GameState_AfterObjFrame", 0,
            function()
                self:on_GameState_AfterObjFrame()
            end)
end

---在 GameState.AfterObjFrame 事件中执行所有 GameObject 的 LateUpdate
function lateUpdateSystem:on_GameState_AfterObjFrame()
    -- 遍历所有对象
    for obj in lstg.ObjList(-1) do
        -- 检查对象是否有效
        if lstg.IsValid(obj) then
            -- 检查是否为 GameObject 类型（通过检查是否有 typeDef 和 isTypeOf 方法）
            if obj.typeDef and obj.isTypeOf and obj:isTypeOf(GameObjectType) then
                -- 调用 GameObject 的 LateUpdate 生命周期
                local lateUpdate = obj.LateUpdate
                if lateUpdate then
                    lateUpdate(obj)
                end

                -- 更新组件 LateUpdate 生命周期
                if obj.lateUpdateComponents then
                    obj:lateUpdateComponents()
                end
            end
        end
    end
end

-- 自动初始化 LateUpdate 系统
lateUpdateSystem:init()
--endregion

return {
    _class = GameObject,
    Type = GameObjectType,
    create = GameObject.create,
    isTypeOf = GameObject.isTypeOf,
}

