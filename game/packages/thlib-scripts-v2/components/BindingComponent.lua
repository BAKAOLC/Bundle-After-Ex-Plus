---绑定关系组件
local pairs = pairs
local next = next
local error = error
local ipairs = ipairs
local math = math
local table = table

local lstg = lstg

local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---辅助函数：计算带旋转偏移的位置
---@param targetX number
---@param targetY number
---@param offsetX number
---@param offsetY number
---@param targetRot number|nil
---@return number, number
local function calculatePositionWithRotation(targetX, targetY, offsetX, offsetY, targetRot)
    if targetRot then
        local angle = math.rad(targetRot)
        local cos = math.cos(angle)
        local sin = math.sin(angle)
        return targetX + offsetX * cos - offsetY * sin, targetY + offsetX * sin + offsetY * cos
    else
        return targetX + offsetX, targetY + offsetY
    end
end

---更新位置 - 跟随第一个
---@param bindings components.BindingInfo[]
---@param owner any
local function updatePositionFirst(bindings, owner)
    local bindingInfo = bindings[1]
    local target = bindingInfo.target
    local targetX = target.x or 0
    local targetY = target.y or 0
    local targetRot = bindingInfo.followRotation and target.rot or nil
    owner.x, owner.y = calculatePositionWithRotation(targetX, targetY, bindingInfo.offsetX, bindingInfo.offsetY, targetRot)
end

---更新位置 - 跟随最后一个
---@param bindings components.BindingInfo[]
---@param owner any
local function updatePositionLast(bindings, owner)
    local bindingInfo = bindings[#bindings]
    local target = bindingInfo.target
    local targetX = target.x or 0
    local targetY = target.y or 0
    local targetRot = bindingInfo.followRotation and target.rot or nil
    owner.x, owner.y = calculatePositionWithRotation(targetX, targetY, bindingInfo.offsetX, bindingInfo.offsetY, targetRot)
end

---更新位置 - 平均
---@param bindings components.BindingInfo[]
---@param owner any
local function updatePositionAverage(bindings, owner)
    local sumX = 0
    local sumY = 0
    local count = 0

    for _, bindingInfo in ipairs(bindings) do
        local target = bindingInfo.target
        local targetX = target.x or 0
        local targetY = target.y or 0
        local targetRot = bindingInfo.followRotation and target.rot or nil
        local posX, posY = calculatePositionWithRotation(targetX, targetY, bindingInfo.offsetX, bindingInfo.offsetY, targetRot)
        sumX = sumX + posX
        sumY = sumY + posY
        count = count + 1
    end

    if count > 0 then
        owner.x = sumX / count
        owner.y = sumY / count
    end
end

---更新位置 - 加权平均
---@param bindings components.BindingInfo[]
---@param owner any
local function updatePositionWeighted(bindings, owner)
    local sumX = 0
    local sumY = 0
    local totalWeight = 0

    for _, bindingInfo in ipairs(bindings) do
        local target = bindingInfo.target
        local targetX = target.x or 0
        local targetY = target.y or 0
        local weight = bindingInfo.weight or 1
        local targetRot = bindingInfo.followRotation and target.rot or nil
        local posX, posY = calculatePositionWithRotation(targetX, targetY, bindingInfo.offsetX, bindingInfo.offsetY, targetRot)
        sumX = sumX + posX * weight
        sumY = sumY + posY * weight
        totalWeight = totalWeight + weight
    end

    if totalWeight > 0 then
        owner.x = sumX / totalWeight
        owner.y = sumY / totalWeight
    end
end

---更新旋转 - 跟随第一个
---@param bindings components.BindingInfo[]
---@param owner any
local function updateRotationFirst(bindings, owner)
    local bindingInfo = bindings[1]
    local target = bindingInfo.target
    if target.rot then
        owner.rot = target.rot + bindingInfo.offsetAngle
    end
end

---更新旋转 - 跟随最后一个
---@param bindings components.BindingInfo[]
---@param owner any
local function updateRotationLast(bindings, owner)
    local bindingInfo = bindings[#bindings]
    local target = bindingInfo.target
    if target.rot then
        owner.rot = target.rot + bindingInfo.offsetAngle
    end
end

---更新旋转 - 平均
---@param bindings components.BindingInfo[]
---@param owner any
local function updateRotationAverage(bindings, owner)
    local sumRot = 0
    local count = 0

    for _, bindingInfo in ipairs(bindings) do
        local target = bindingInfo.target
        if target.rot then
            sumRot = sumRot + target.rot + bindingInfo.offsetAngle
            count = count + 1
        end
    end

    if count > 0 then
        owner.rot = sumRot / count
    end
end

---更新旋转 - 加权平均
---@param bindings components.BindingInfo[]
---@param owner any
local function updateRotationWeighted(bindings, owner)
    local sumRot = 0
    local totalWeight = 0

    for _, bindingInfo in ipairs(bindings) do
        local target = bindingInfo.target
        if target.rot then
            local weight = bindingInfo.weight or 1
            sumRot = sumRot + (target.rot + bindingInfo.offsetAngle) * weight
            totalWeight = totalWeight + weight
        end
    end

    if totalWeight > 0 then
        owner.rot = sumRot / totalWeight
    end
end

---更新缩放 - 跟随第一个
---@param bindings components.BindingInfo[]
---@param owner any
local function updateScaleFirst(bindings, owner)
    local bindingInfo = bindings[1]
    local target = bindingInfo.target
    if target.hscale then
        owner.hscale = target.hscale * bindingInfo.scaleX
    end
    if target.vscale then
        owner.vscale = target.vscale * bindingInfo.scaleY
    end
end

---更新缩放 - 跟随最后一个
---@param bindings components.BindingInfo[]
---@param owner any
local function updateScaleLast(bindings, owner)
    local bindingInfo = bindings[#bindings]
    local target = bindingInfo.target
    if target.hscale then
        owner.hscale = target.hscale * bindingInfo.scaleX
    end
    if target.vscale then
        owner.vscale = target.vscale * bindingInfo.scaleY
    end
end

---更新缩放 - 平均
---@param bindings components.BindingInfo[]
---@param owner any
local function updateScaleAverage(bindings, owner)
    local sumHScale = 0
    local sumVScale = 0
    local count = 0

    for _, bindingInfo in ipairs(bindings) do
        local target = bindingInfo.target
        if target.hscale then
            sumHScale = sumHScale + target.hscale * bindingInfo.scaleX
        end
        if target.vscale then
            sumVScale = sumVScale + target.vscale * bindingInfo.scaleY
        end
        count = count + 1
    end

    if count > 0 then
        if sumHScale > 0 then
            owner.hscale = sumHScale / count
        end
        if sumVScale > 0 then
            owner.vscale = sumVScale / count
        end
    end
end

---更新缩放 - 加权平均
---@param bindings components.BindingInfo[]
---@param owner any
local function updateScaleWeighted(bindings, owner)
    local sumHScale = 0
    local sumVScale = 0
    local totalWeight = 0

    for _, bindingInfo in ipairs(bindings) do
        local target = bindingInfo.target
        local weight = bindingInfo.weight or 1

        if target.hscale then
            sumHScale = sumHScale + target.hscale * bindingInfo.scaleX * weight
        end
        if target.vscale then
            sumVScale = sumVScale + target.vscale * bindingInfo.scaleY * weight
        end
        totalWeight = totalWeight + weight
    end

    if totalWeight > 0 then
        if sumHScale > 0 then
            owner.hscale = sumHScale / totalWeight
        end
        if sumVScale > 0 then
            owner.vscale = sumVScale / totalWeight
        end
    end
end

---创建默认事件回调
---@param owner any
---@param targetEventName string
---@return fun(...)
local function createDefaultEventCallback(owner, targetEventName)
    return function(...)
        if owner and owner._dispatchEvent then
            owner:_dispatchEvent(targetEventName, ...)
        end
    end
end

---处理字符串类型的事件订阅配置
---@param owner any
---@param targetEventName string
---@param listenerConfig string
---@param defaultListenerName string
---@return string, number, fun(...)
local function handleStringEventConfig(owner, targetEventName, listenerConfig, defaultListenerName)
    local callback = createDefaultEventCallback(owner, targetEventName)
    return listenerConfig, 0, callback
end

---处理表格类型的事件订阅配置
---@param owner any
---@param targetEventName string
---@param listenerConfig table
---@param defaultListenerName string
---@return string, number, fun(...)
local function handleTableEventConfig(owner, targetEventName, listenerConfig, defaultListenerName)
    local listenerName = listenerConfig.name or defaultListenerName
    local priority = listenerConfig.priority or 0
    local callback = listenerConfig.callback or createDefaultEventCallback(owner, targetEventName)
    return listenerName, priority, callback
end

---处理默认事件订阅配置
---@param owner any
---@param targetEventName string
---@param defaultListenerName string
---@return string, number, fun(...)
local function handleDefaultEventConfig(owner, targetEventName, defaultListenerName)
    local callback = createDefaultEventCallback(owner, targetEventName)
    return defaultListenerName, 0, callback
end

---位置计算模式
---@alias BindingPositionMode "average"|"weighted"|"first"|"last"
local BindingPositionMode = {
    AVERAGE = "average", -- 平均
    WEIGHTED_AVERAGE = "weighted", -- 加权平均
    FIRST = "first", -- 跟随第一个
    LAST = "last", -- 跟随最后一个
}

---旋转计算模式
---@alias BindingRotationMode "average"|"weighted"|"first"|"last"
local BindingRotationMode = {
    AVERAGE = "average", -- 平均
    WEIGHTED_AVERAGE = "weighted", -- 加权平均
    FIRST = "first", -- 跟随第一个
    LAST = "last", -- 跟随最后一个
}

---缩放计算模式
---@alias BindingScaleMode "average"|"weighted"|"first"|"last"
local BindingScaleMode = {
    AVERAGE = "average", -- 平均
    WEIGHTED_AVERAGE = "weighted", -- 加权平均
    FIRST = "first", -- 跟随第一个
    LAST = "last", -- 跟随最后一个
}

---@class components.BindingInfo
---@field target any 绑定目标
---@field bindPosition boolean 是否绑定位置
---@field bindRotation boolean 是否绑定旋转
---@field bindScale boolean 是否绑定缩放
---@field offsetX number 位置偏移X
---@field offsetY number 位置偏移Y
---@field offsetAngle number 旋转偏移角度
---@field scaleX number 缩放X
---@field scaleY number 缩放Y
---@field followRotation boolean 是否跟随旋转
---@field weight number 权重（用于加权平均）
---@field data table|nil 自定义数据
---@field eventSubscriptions table<string, string> 事件订阅映射（目标事件名 -> 监听器名称）

---@class components.BindingComponent : core.Component
---@field bindings table<number, components.BindingInfo> 绑定列表（使用ID作为key）
---@field nextBindingId number 下一个绑定ID
---@field positionMode BindingPositionMode 位置计算模式
---@field rotationMode BindingRotationMode 旋转计算模式
---@field scaleMode BindingScaleMode 缩放计算模式
---@field onBindingAdded fun(bindingComponent: components.BindingComponent, bindingId: number, bindingInfo: components.BindingInfo)|nil 绑定添加回调
---@field onBindingRemoved fun(bindingComponent: components.BindingComponent, bindingId: number, bindingInfo: components.BindingInfo)|nil 绑定移除回调

-- 定义组件类型
local BindingComponentType = TypeDef.create("components.BindingComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 50,
        alias = "binding",
        bindings = nil,
        nextBindingId = nil,
        positionMode = BindingPositionMode.AVERAGE,
        rotationMode = BindingRotationMode.AVERAGE,
        scaleMode = BindingScaleMode.AVERAGE,
        onBindingAdded = nil,
        onBindingRemoved = nil,
    },
    methods = {
        Awake = function(self)
            -- 初始化绑定列表
            if not self.bindings then
                self.bindings = {}
            end
            if not self.nextBindingId then
                self.nextBindingId = 1
            end

            -- 初始化位置更新器函数表
            if not self._positionUpdaters then
                self._positionUpdaters = {
                    [BindingPositionMode.FIRST] = updatePositionFirst,
                    [BindingPositionMode.LAST] = updatePositionLast,
                    [BindingPositionMode.AVERAGE] = updatePositionAverage,
                    [BindingPositionMode.WEIGHTED_AVERAGE] = updatePositionWeighted,
                }
            end

            -- 初始化旋转更新器函数表
            if not self._rotationUpdaters then
                self._rotationUpdaters = {
                    [BindingRotationMode.FIRST] = updateRotationFirst,
                    [BindingRotationMode.LAST] = updateRotationLast,
                    [BindingRotationMode.AVERAGE] = updateRotationAverage,
                    [BindingRotationMode.WEIGHTED_AVERAGE] = updateRotationWeighted,
                }
            end

            -- 初始化缩放更新器函数表
            if not self._scaleUpdaters then
                self._scaleUpdaters = {
                    [BindingScaleMode.FIRST] = updateScaleFirst,
                    [BindingScaleMode.LAST] = updateScaleLast,
                    [BindingScaleMode.AVERAGE] = updateScaleAverage,
                    [BindingScaleMode.WEIGHTED_AVERAGE] = updateScaleWeighted,
                }
            end
        end,

        Update = function(self)
            if not self.owner or not self.bindings then
                return
            end

            -- 收集有效的绑定信息
            local validBindings = {}
            for bindingId, bindingInfo in pairs(self.bindings) do
                local target = bindingInfo.target
                if target and (not lstg.IsValid or lstg.IsValid(target)) then
                    table.insert(validBindings, bindingInfo)
                end
            end

            if #validBindings == 0 then
                return
            end

            -- 计算位置
            local positionBindings = {}
            for _, bindingInfo in ipairs(validBindings) do
                if bindingInfo.bindPosition then
                    table.insert(positionBindings, bindingInfo)
                end
            end
            if #positionBindings > 0 then
                self:_updatePosition(positionBindings)
            end

            -- 计算旋转
            local rotationBindings = {}
            for _, bindingInfo in ipairs(validBindings) do
                if bindingInfo.bindRotation then
                    table.insert(rotationBindings, bindingInfo)
                end
            end
            if #rotationBindings > 0 then
                self:_updateRotation(rotationBindings)
            end

            -- 计算缩放
            local scaleBindings = {}
            for _, bindingInfo in ipairs(validBindings) do
                if bindingInfo.bindScale then
                    table.insert(scaleBindings, bindingInfo)
                end
            end
            if #scaleBindings > 0 then
                self:_updateScale(scaleBindings)
            end
        end,

        ---更新位置
        ---@private
        ---@param bindings components.BindingInfo[]
        _updatePosition = function(self, bindings)
            local mode = self.positionMode or BindingPositionMode.AVERAGE
            local owner = self.owner
            local updater = self._positionUpdaters[mode]
            if updater then
                updater(bindings, owner)
            end
        end,

        ---更新旋转
        ---@private
        ---@param bindings components.BindingInfo[]
        _updateRotation = function(self, bindings)
            local mode = self.rotationMode or BindingRotationMode.AVERAGE
            local owner = self.owner
            local updater = self._rotationUpdaters[mode]
            if updater then
                updater(bindings, owner)
            end
        end,

        ---更新缩放
        ---@private
        ---@param bindings components.BindingInfo[]
        _updateScale = function(self, bindings)
            local mode = self.scaleMode or BindingScaleMode.AVERAGE
            local owner = self.owner
            local updater = self._scaleUpdaters[mode]
            if updater then
                updater(bindings, owner)
            end
        end,

        ---添加绑定
        ---@param target any 绑定目标
        ---@param config table|nil 配置选项
        ---@param config.bindPosition boolean|nil 是否绑定位置（默认true）
        ---@param config.bindRotation boolean|nil 是否绑定旋转（默认false）
        ---@param config.bindScale boolean|nil 是否绑定缩放（默认false）
        ---@param config.offsetX number|nil 位置偏移X（默认0）
        ---@param config.offsetY number|nil 位置偏移Y（默认0）
        ---@param config.offsetAngle number|nil 旋转偏移角度（默认0）
        ---@param config.scaleX number|nil 缩放X（默认1）
        ---@param config.scaleY number|nil 缩放Y（默认1）
        ---@param config.followRotation boolean|nil 是否跟随旋转（默认false）
        ---@param config.weight number|nil 权重（用于加权平均，默认1）
        ---@param config.data table|nil 自定义数据
        ---@param config.subscribeEvents table<string, string|table>|nil 事件订阅映射
        ---@return number bindingId 绑定ID
        addBinding = function(self, target, config)
            if not target then
                error("Binding target cannot be nil", 2)
            end

            if not self.bindings then
                self:Awake()
            end

            config = config or {}
            local bindingId = self.nextBindingId
            self.nextBindingId = self.nextBindingId + 1

            local bindingInfo = {
                target = target,
                bindPosition = config.bindPosition ~= false, -- 默认绑定位置
                bindRotation = config.bindRotation or false,
                bindScale = config.bindScale or false,
                offsetX = config.offsetX or 0,
                offsetY = config.offsetY or 0,
                offsetAngle = config.offsetAngle or 0,
                scaleX = config.scaleX or 1,
                scaleY = config.scaleY or 1,
                followRotation = config.followRotation or false,
                weight = config.weight or 1,
                data = config.data or {},
                eventSubscriptions = {},
            }

            self.bindings[bindingId] = bindingInfo

            if config.subscribeEvents then
                self:subscribeBindingEvents(bindingId, config.subscribeEvents)
            end

            if self.onBindingAdded then
                self.onBindingAdded(self, bindingId, bindingInfo)
            end

            return bindingId
        end,

        ---移除绑定
        ---@param bindingId number 绑定ID
        removeBinding = function(self, bindingId)
            if not self.bindings then
                return
            end

            local bindingInfo = self.bindings[bindingId]
            if bindingInfo then
                self:unsubscribeBindingEvents(bindingId)

                if self.onBindingRemoved then
                    self.onBindingRemoved(self, bindingId, bindingInfo)
                end
                self.bindings[bindingId] = nil
            end
        end,

        ---移除所有绑定
        clearBindings = function(self)
            if not self.bindings then
                return
            end

            for bindingId, bindingInfo in pairs(self.bindings) do
                self:unsubscribeBindingEvents(bindingId)

                if self.onBindingRemoved then
                    self.onBindingRemoved(self, bindingId, bindingInfo)
                end
            end
            self.bindings = {}
        end,

        ---获取绑定信息
        ---@param bindingId number 绑定ID
        ---@return components.BindingInfo|nil
        getBinding = function(self, bindingId)
            if not self.bindings then
                self:Awake()
            end
            return self.bindings[bindingId]
        end,

        ---获取所有绑定
        ---@return table<number, components.BindingInfo>
        getAllBindings = function(self)
            if not self.bindings then
                self:Awake()
            end
            return self.bindings
        end,

        ---检查是否有绑定
        ---@param target any|nil 目标对象，如果为nil则检查是否有任何绑定
        ---@return boolean
        hasBinding = function(self, target)
            if not self.bindings then
                self:Awake()
            end

            if target then
                for _, bindingInfo in pairs(self.bindings) do
                    if bindingInfo.target == target then
                        return true
                    end
                end
                return false
            else
                return next(self.bindings) ~= nil
            end
        end,


        ---订阅绑定目标的事件
        ---@param bindingId number 绑定ID
        ---@param eventMap table<string, string|table> 事件映射表 {目标事件名 = 监听器名称} 或 {目标事件名 = {name = 监听器名称, priority = 优先级, callback = 回调函数}}
        subscribeBindingEvents = function(self, bindingId, eventMap)
            if not self.bindings then
                self:Awake()
            end

            local bindingInfo = self.bindings[bindingId]
            if not bindingInfo or not bindingInfo.target then
                return
            end

            local target = bindingInfo.target
            if not target.registerEvent then
                return
            end

            local owner = self.owner
            for targetEventName, listenerConfig in pairs(eventMap) do
                local defaultListenerName = "binding_" .. bindingId .. "_" .. targetEventName
                local listenerName, priority, callback

                local configType = type(listenerConfig)
                if configType == "string" then
                    listenerName, priority, callback = handleStringEventConfig(owner, targetEventName, listenerConfig, defaultListenerName)
                elseif configType == "table" then
                    listenerName, priority, callback = handleTableEventConfig(owner, targetEventName, listenerConfig, defaultListenerName)
                else
                    listenerName, priority, callback = handleDefaultEventConfig(owner, targetEventName, defaultListenerName)
                end

                target:registerEvent(targetEventName, listenerName, priority, callback)
                bindingInfo.eventSubscriptions[targetEventName] = listenerName
            end
        end,

        ---取消订阅绑定目标的事件
        ---@param bindingId number 绑定ID
        ---@param eventNames string[]|nil 要取消的事件名列表，如果为nil则取消所有
        unsubscribeBindingEvents = function(self, bindingId, eventNames)
            if not self.bindings then
                return
            end

            local bindingInfo = self.bindings[bindingId]
            if not bindingInfo or not bindingInfo.target then
                return
            end

            local target = bindingInfo.target
            if not target.unregisterEvent then
                return
            end

            if eventNames then
                -- 取消指定事件
                for _, eventName in ipairs(eventNames) do
                    local listenerName = bindingInfo.eventSubscriptions[eventName]
                    if listenerName then
                        target:unregisterEvent(eventName, listenerName)
                        bindingInfo.eventSubscriptions[eventName] = nil
                    end
                end
            else
                -- 取消所有事件
                for eventName, listenerName in pairs(bindingInfo.eventSubscriptions) do
                    target:unregisterEvent(eventName, listenerName)
                end
                bindingInfo.eventSubscriptions = {}
            end
        end,

        ---广播事件到所有绑定目标
        ---@param eventName string 事件名称
        ---@vararg any 事件参数
        broadcastToBindings = function(self, eventName, ...)
            if not self.bindings then
                return
            end

            for _, bindingInfo in pairs(self.bindings) do
                local target = bindingInfo.target
                if target and (not lstg.IsValid or lstg.IsValid(target)) then
                    if target._dispatchEvent then
                        target:_dispatchEvent(eventName, ...)
                    end
                end
            end
        end,

        ---广播事件到指定的绑定目标
        ---@param bindingId number|number[] 绑定ID或绑定ID列表
        ---@param eventName string 事件名称
        ---@vararg any 事件参数
        broadcastToBinding = function(self, bindingId, eventName, ...)
            if not self.bindings then
                return
            end

            local ids = {}
            if type(bindingId) == "table" then
                ids = bindingId
            else
                table.insert(ids, bindingId)
            end

            for _, id in ipairs(ids) do
                local bindingInfo = self.bindings[id]
                if bindingInfo then
                    local target = bindingInfo.target
                    if target and (not lstg.IsValid or lstg.IsValid(target)) then
                        if target._dispatchEvent then
                            target:_dispatchEvent(eventName, ...)
                        end
                    end
                end
            end
        end,
    },
})

---创建Binding组件
---@param config table
---@return components.BindingComponent
local function create(config)
    config = config or {}
    return TypeDef.instantiate(BindingComponentType, config)
end

return {
    create = create,
    Type = BindingComponentType,
    PositionMode = BindingPositionMode,
    RotationMode = BindingRotationMode,
    ScaleMode = BindingScaleMode,
}
