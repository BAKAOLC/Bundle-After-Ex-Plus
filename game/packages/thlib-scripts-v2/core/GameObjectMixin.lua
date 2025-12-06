---通用游戏对象工具函数
---为对象添加组件系统支持

local ComponentSystem = require("core.ComponentSystem")

---@class core.GameObjectMixin
---@field componentSystem core.ComponentSystem

---为对象初始化组件系统
---@param obj table
local function initComponentSystem(obj)
    obj.componentSystem = ComponentSystem.new(obj)
end

---添加组件
---@param obj table
---@param component core.Component
---@param componentType string
---@return number componentId
local function addComponent(obj, component, componentType)
    return obj.componentSystem:addComponent(component, componentType)
end

---移除组件
---@param obj table
---@param componentId number
local function removeComponent(obj, componentId)
    obj.componentSystem:removeComponent(componentId)
end

---根据类型获取组件
---@param obj table
---@param componentType string
---@return core.Component|nil
local function getComponent(obj, componentType)
    return obj.componentSystem:getComponent(componentType)
end

---根据类型获取所有组件
---@param obj table
---@param componentType string
---@return table|nil
local function getComponents(obj, componentType)
    return obj.componentSystem:getComponents(componentType)
end

---处理组件 Start 生命周期
---@param obj table
local function startComponents(obj)
    obj.componentSystem:Start()
end

---更新组件 Update 生命周期
---@param obj table
local function updateComponents(obj)
    obj.componentSystem:Update()
end

---更新组件 LateUpdate 生命周期
---@param obj table
local function lateUpdateComponents(obj)
    obj.componentSystem:LateUpdate()
end

---渲染组件
---@param obj table
local function renderComponents(obj)
    obj.componentSystem:OnRender()
end

---为对象混入组件系统方法
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
    mixin = mixin,
}

