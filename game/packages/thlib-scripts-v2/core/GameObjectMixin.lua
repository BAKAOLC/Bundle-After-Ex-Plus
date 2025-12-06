---通用游戏对象工具函数
---为对象添加组件系统支持

local ComponentSystem = require("core.ComponentSystem")

---@class core.GameObjectMixin
---@field componentSystem core.ComponentSystem
---@field _componentsResolved boolean

---为对象初始化组件系统
---@param obj table
local function initComponentSystem(obj)
    obj.componentSystem = ComponentSystem.new()
    obj._componentsResolved = false
end

---添加组件
---@param obj table
---@param component core.Component
---@param componentType string
---@return number componentId
local function addComponent(obj, component, componentType)
    obj._componentsResolved = false
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

---解析组件依赖
---在所有组件添加完成后调用，让组件互相获取引用
---@param obj table
local function resolveComponents(obj)
    if obj._componentsResolved then
        return
    end

    local components = obj.componentSystem.components
    local count = obj.componentSystem.componentCount

    -- 让每个组件解析依赖
    for i = 1, count do
        local component = components[i]
        if component and component.resolveDependencies then
            component:resolveDependencies(obj)
        end
    end

    -- 然后调用 onAdd
    for i = 1, count do
        local component = components[i]
        if component and component.onAdd then
            component:onAdd()
        end
    end

    obj._componentsResolved = true
end

---更新组件
---@param obj table
local function updateComponents(obj)
    obj.componentSystem:update()
end

---渲染组件
---@param obj table
local function renderComponents(obj)
    obj.componentSystem:render()
end

---为对象混入组件系统方法
---@param obj table
local function mixin(obj)
    obj.addComponent = addComponent
    obj.removeComponent = removeComponent
    obj.getComponent = getComponent
    obj.getComponents = getComponents
    obj.resolveComponents = resolveComponents
    obj.updateComponents = updateComponents
    obj.renderComponents = renderComponents

    initComponentSystem(obj)
end

return {
    initComponentSystem = initComponentSystem,
    addComponent = addComponent,
    removeComponent = removeComponent,
    getComponent = getComponent,
    getComponents = getComponents,
    resolveComponents = resolveComponents,
    updateComponents = updateComponents,
    renderComponents = renderComponents,
    mixin = mixin,
}

