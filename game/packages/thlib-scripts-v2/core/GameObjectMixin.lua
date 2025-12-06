---通用游戏对象工具函数
---为对象添加组件系统支持和事件系统支持

local ComponentSystem = require("core.ComponentSystem")
local createEventDispatcher = require("foundation.EventDispatcher")

---为对象初始化组件系统
---@param obj table
local function initComponentSystem(obj)
    obj._componentSystem = ComponentSystem.new(obj)
end

---添加组件
---@param obj table
---@param component core.Component
---@param componentType string
---@return number componentId
local function addComponent(obj, component, componentType)
    return obj._componentSystem:addComponent(component, componentType)
end

---移除组件
---@param obj table
---@param componentId number
local function removeComponent(obj, componentId)
    obj._componentSystem:removeComponent(componentId)
end

---根据类型获取组件
---@param obj table
---@param componentType string
---@return core.Component|nil
local function getComponent(obj, componentType)
    return obj._componentSystem:getComponent(componentType)
end

---根据类型获取所有组件
---@param obj table
---@param componentType string
---@return table|nil
local function getComponents(obj, componentType)
    return obj._componentSystem:getComponents(componentType)
end

---处理组件 Start 生命周期
---@param obj table
local function startComponents(obj)
    obj._componentSystem:Start()
end

---更新组件 Update 生命周期
---@param obj table
local function updateComponents(obj)
    obj._componentSystem:Update()
end

---更新组件 LateUpdate 生命周期
---@param obj table
local function lateUpdateComponents(obj)
    obj._componentSystem:LateUpdate()
end

---渲染组件
---@param obj table
local function renderComponents(obj)
    obj._componentSystem:OnRender()
end

---获取或创建事件监听器（延迟初始化）
---@param obj table
---@return foundation.EventDispatcher
local function _getListener(obj)
    if not obj._listener then
        obj._listener = createEventDispatcher()
    end
    return obj._listener
end

---分发事件
---@param obj table
---@param eventName string 事件名称
---@vararg any 事件参数
---@return boolean
local function _dispatchEvent(obj, eventName, ...)
    local listener = _getListener(obj)
    return listener:DispatchEvent(eventName, obj, ...)
end

---注册事件监听
---@param obj table
---@param eventName string 事件名称
---@param name string 监听器名称
---@param priority number 优先级
---@param callback function 回调函数
local function registerEvent(obj, eventName, name, priority, callback)
    local listener = _getListener(obj)
    listener:RegisterEvent(eventName, name, priority, callback)
end

---取消注册事件监听
---@param obj table
---@param eventName string 事件名称
---@param name string 监听器名称
local function unregisterEvent(obj, eventName, name)
    if obj._listener then
        obj._listener:UnregisterEvent(eventName, name)
    end
end

---为对象混入组件系统方法和事件系统方法
---@param obj table
local function mixin(obj)
    obj.addComponent = addComponent
    obj.removeComponent = removeComponent
    obj.getComponent = getComponent
    obj.getComponents = getComponents
    obj.startComponents = startComponents
    obj.updateComponents = updateComponents
    obj.lateUpdateComponents = lateUpdateComponents
    obj.renderComponents = renderComponents
    obj._getListener = _getListener
    obj._dispatchEvent = _dispatchEvent
    obj.registerEvent = registerEvent
    obj.unregisterEvent = unregisterEvent

    initComponentSystem(obj)
end

return {
    initComponentSystem = initComponentSystem,
    addComponent = addComponent,
    removeComponent = removeComponent,
    getComponent = getComponent,
    getComponents = getComponents,
    startComponents = startComponents,
    updateComponents = updateComponents,
    lateUpdateComponents = lateUpdateComponents,
    renderComponents = renderComponents,
    _getListener = _getListener,
    _dispatchEvent = _dispatchEvent,
    registerEvent = registerEvent,
    unregisterEvent = unregisterEvent,
    mixin = mixin,
}

