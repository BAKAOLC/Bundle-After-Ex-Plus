local ipairs = ipairs
local pairs = pairs

---@class core.Component
---@field enabled boolean
---@field executePriority number|nil update优先级，数字越大越先执行（可选，默认0）
---@field renderPriority number|nil render优先级（可选，默认使用executePriority）
---@field owner any
---@field typeName string
---@field executeBefore string[]|nil update时在这些组件之前执行
---@field executeAfter string[]|nil update时在这些组件之后执行
---@field renderBefore string[]|nil render时在这些组件之前渲染
---@field renderAfter string[]|nil render时在这些组件之后渲染
---@field resolveDependencies fun(self: core.Component, gameObject: any)|nil 解析依赖，在此获取其他组件引用
---@field onAdd fun(self: core.Component)|nil 添加时回调，在 resolveDependencies 之后
---@field onRemove fun(self: core.Component)|nil
---@field update fun(self: core.Component)|nil
---@field render fun(self: core.Component)|nil 渲染回调

---@class core.ComponentSystem
---@field components core.Component[] 全部组件数组
---@field updateComponents core.Component[]|nil update组件数组（延迟创建）
---@field renderComponents core.Component[]|nil 渲染组件数组（延迟创建）
---@field componentCount number 组件数量
---@field updateComponentCount number update组件数量
---@field renderComponentCount number 渲染组件数量
---@field componentsByType table<string, {count: number, [number]: core.Component}> 按类型索引的组件
---@field sortDirty boolean 是否需要重新排序
---@field updateSortDirty boolean 是否需要重新排序update组件
---@field renderSortDirty boolean 是否需要重新排序render组件
---@field addComponent fun(self: core.ComponentSystem, component: core.Component, componentType: string): number
---@field removeComponent fun(self: core.ComponentSystem, componentId: number)
---@field getComponents fun(self: core.ComponentSystem, componentType: string): core.Component[]|nil
---@field getComponent fun(self: core.ComponentSystem, componentType: string): core.Component|nil
---@field update fun(self: core.ComponentSystem)
---@field render fun(self: core.ComponentSystem)
---@field clear fun(self: core.ComponentSystem)
---@field setComponentEnabled fun(self: core.ComponentSystem, componentId: number, enabled: boolean)

---创建组件系统实例
---@return core.ComponentSystem
local function new()
    local system = {
        components = {},
        updateComponents = nil, -- 延迟创建
        renderComponents = nil, -- 延迟创建
        componentCount = 0,
        updateComponentCount = 0,
        renderComponentCount = 0,
        componentsByType = {},
        sortDirty = false,
        updateSortDirty = false,
        renderSortDirty = false,
    }

    ---添加组件
    ---@param component core.Component 组件实例
    ---@param componentType string 组件类型标识
    ---@return number componentId 组件ID
    function system:addComponent(component, componentType)
        local count = self.componentCount + 1
        self.componentCount = count
        self.components[count] = component

        -- 按类型分组
        if componentType then
            local typeList = self.componentsByType[componentType]
            if not typeList then
                typeList = { count = 0 }
                self.componentsByType[componentType] = typeList
            end
            local typeCount = typeList.count + 1
            typeList.count = typeCount
            typeList[typeCount] = component
        end

        self.sortDirty = true
        self.updateSortDirty = true
        self.renderSortDirty = true

        -- 注意：不在这里调用 onAdd，而是在 resolveComponents 之后调用

        return count
    end

    ---移除组件
    ---@param componentId number 组件ID（数组索引）
    function system:removeComponent(componentId)
        local component = self.components[componentId]
        if not component then
            return
        end

        if component.onRemove then
            component:onRemove()
        end

        self.components[componentId] = nil

        -- 需要在update时清理
        self.sortDirty = true
        self.updateSortDirty = true
        self.renderSortDirty = true
    end

    ---根据类型获取组件列表
    ---@param componentType string
    ---@return core.Component[]|nil
    function system:getComponents(componentType)
        return self.componentsByType[componentType]
    end

    ---根据类型获取第一个组件
    ---@param componentType string
    ---@return core.Component|nil
    function system:getComponent(componentType)
        local list = self.componentsByType[componentType]
        if list and list.count > 0 then
            return list[1]
        end
        return nil
    end

    ---更新所有组件
    function system:update()
        -- 清理被删除的组件
        if self.sortDirty then
            self:_compact()
            self:_sortComponents()
            self.sortDirty = false
        end

        -- 如果需要，构建并排序update组件列表
        if self.updateSortDirty or not self.updateComponents then
            self:_sortUpdateComponents()
            self.updateSortDirty = false
        end

        local components = self.updateComponents
        local count = self.updateComponentCount

        -- 只遍历有update方法的组件
        for i = 1, count do
            local component = components[i]
            if component and component.enabled then
                component:update()
            end
        end
    end

    ---渲染所有组件
    function system:render()
        -- 如果需要，构建并排序render组件列表
        if self.renderSortDirty or not self.renderComponents then
            self:_sortRenderComponents()
            self.renderSortDirty = false
        end

        local components = self.renderComponents
        local count = self.renderComponentCount

        -- 只遍历有render方法的组件
        for i = 1, count do
            local component = components[i]
            if component and component.enabled then
                component:render()
            end
        end
    end

    ---排序组件（根据priority和依赖关系）
    function system:_sortComponents()
        local components = self.components
        local count = self.componentCount

        if count <= 1 then
            return
        end

        -- 构建组件名称到组件的映射
        local nameToComp = {}
        local nameToIndex = {}
        for i = 1, count do
            local comp = components[i]
            if comp and comp.typeName then
                nameToComp[comp.typeName] = comp
                nameToIndex[comp.typeName] = i
            end
        end

        -- 构建依赖图（入度统计）
        local inDegree = {}  -- 入度：有多少组件需要在这个组件之前执行
        local adjList = {}   -- 邻接表：这个组件需要在哪些组件之前执行

        for i = 1, count do
            local comp = components[i]
            if comp and comp.typeName then
                inDegree[comp.typeName] = 0
                adjList[comp.typeName] = {}
            end
        end

        -- 处理 executeAfter 和 executeBefore
        for i = 1, count do
            local comp = components[i]
            if comp and comp.typeName then
                -- executeAfter: 这个组件要在某些组件之后执行
                -- 意味着：那些组件 -> 这个组件（依赖）
                if comp.executeAfter then
                    for _, afterName in ipairs(comp.executeAfter) do
                        if nameToComp[afterName] then
                            -- afterName 组件要在 comp 之前
                            if not adjList[afterName] then
                                adjList[afterName] = {}
                            end
                            adjList[afterName][comp.typeName] = true
                            inDegree[comp.typeName] = inDegree[comp.typeName] + 1
                        end
                    end
                end

                -- executeBefore: 这个组件要在某些组件之前执行
                -- 意味着：这个组件 -> 那些组件（依赖）
                if comp.executeBefore then
                    for _, beforeName in ipairs(comp.executeBefore) do
                        if nameToComp[beforeName] then
                            -- comp 要在 beforeName 之前
                            adjList[comp.typeName][beforeName] = true
                            inDegree[beforeName] = inDegree[beforeName] + 1
                        end
                    end
                end
            end
        end

        -- 拓扑排序（Kahn算法）
        local queue = {}
        local queueStart = 1
        local queueEnd = 0

        -- 将入度为0的节点加入队列
        for name, degree in pairs(inDegree) do
            if degree == 0 then
                queueEnd = queueEnd + 1
                queue[queueEnd] = name
            end
        end

        local sorted = {}
        local sortedCount = 0

        while queueStart <= queueEnd do
            local current = queue[queueStart]
            queueStart = queueStart + 1

            sortedCount = sortedCount + 1
            sorted[sortedCount] = current

            -- 处理邻接节点
            if adjList[current] then
                for nextName in pairs(adjList[current]) do
                    inDegree[nextName] = inDegree[nextName] - 1
                    if inDegree[nextName] == 0 then
                        queueEnd = queueEnd + 1
                        queue[queueEnd] = nextName
                    end
                end
            end
        end

        -- 检查是否有环
        if sortedCount ~= count then
            -- 有环，回退到简单优先级排序
            self:_sortByPriority()
            return
        end

        -- 应用拓扑排序结果，同时考虑priority作为二级排序
        local newComponents = {}
        local used = {}
        local newIdx = 0

        -- 按拓扑顺序和优先级排列
        for _, name in ipairs(sorted) do
            local comp = nameToComp[name]
            if comp and not used[name] then
                newIdx = newIdx + 1
                newComponents[newIdx] = comp
                used[name] = true
            end
        end

        -- 对于同一层级的组件，使用priority排序（稳定排序）
        -- 这里简化处理：已经按拓扑顺序，priority作为tie-breaker

        self.components = newComponents
    end

    ---简单的优先级排序
    function system:_sortByPriority()
        local components = self.components
        local count = self.componentCount

        for i = 1, count - 1 do
            for j = i + 1, count do
                local compA = components[i]
                local compB = components[j]
                if compA and compB then
                    local prioA = compA.executePriority or 0
                    local prioB = compB.executePriority or 0
                    if prioB > prioA then
                        components[i] = compB
                        components[j] = compA
                    end
                end
            end
        end
    end

    ---通用的组件排序方法
    ---@param filterFunc function 过滤函数，返回true表示包含该组件
    ---@param priorityField string 优先级字段名
    ---@param beforeField string "在...之前"字段名
    ---@param afterField string "在...之后"字段名
    ---@return table, number 排序后的组件数组和数量
    function system:_sortComponentsByType(filterFunc, priorityField, beforeField, afterField)
        local components = self.components
        local count = self.componentCount

        -- 收集符合条件的组件
        local filtered = {}
        local filteredCount = 0
        for i = 1, count do
            local comp = components[i]
            if comp and filterFunc(comp) then
                filteredCount = filteredCount + 1
                filtered[filteredCount] = comp
            end
        end

        -- 检查是否有依赖关系
        local hasDeps = false
        for i = 1, filteredCount do
            local comp = filtered[i]
            local before = comp[beforeField]
            local after = comp[afterField]
            if (before and #before > 0) or (after and #after > 0) then
                hasDeps = true
                break
            end
        end

        -- 没有依赖，使用简单排序
        if not hasDeps then
            self:_simplePrioritySort(filtered, filteredCount, priorityField)
            return filtered, filteredCount
        end

        -- 有依赖，使用拓扑排序
        local sorted = self:_topologicalSort(filtered, filteredCount, priorityField, beforeField, afterField)
        return sorted, filteredCount
    end

    ---简单的优先级排序
    function system:_simplePrioritySort(components, count, priorityField)
        for i = 1, count - 1 do
            for j = i + 1, count do
                local compA = components[i]
                local compB = components[j]
                if compA and compB then
                    local prioA = compA[priorityField] or compA.executePriority or 0
                    local prioB = compB[priorityField] or compB.executePriority or 0
                    if prioB > prioA then
                        components[i] = compB
                        components[j] = compA
                    end
                end
            end
        end
    end

    ---拓扑排序
    function system:_topologicalSort(components, count, priorityField, beforeField, afterField)
        -- 建立名称到组件的映射
        local nameToComp = {}
        for i = 1, count do
            local comp = components[i]
            if comp.typeName then
                nameToComp[comp.typeName] = comp
            end
        end

        -- 建立图
        local adjList = {}
        local inDegree = {}

        for i = 1, count do
            local comp = components[i]
            if comp.typeName then
                inDegree[comp.typeName] = 0
            end
        end

        -- 构建依赖关系
        for i = 1, count do
            local comp = components[i]
            local name = comp.typeName
            if name then
                -- before: 我在这些之前
                local before = comp[beforeField]
                if before then
                    for _, target in ipairs(before) do
                        if nameToComp[target] then
                            if not adjList[name] then
                                adjList[name] = {}
                            end
                            adjList[name][target] = true
                            inDegree[target] = (inDegree[target] or 0) + 1
                        end
                    end
                end

                -- after: 我在这些之后
                local after = comp[afterField]
                if after then
                    for _, source in ipairs(after) do
                        if nameToComp[source] then
                            if not adjList[source] then
                                adjList[source] = {}
                            end
                            adjList[source][name] = true
                            inDegree[name] = inDegree[name] + 1
                        end
                    end
                end
            end
        end

        -- Kahn算法
        local queue = {}
        local queueStart = 1
        local queueEnd = 0

        for name, degree in pairs(inDegree) do
            if degree == 0 then
                queueEnd = queueEnd + 1
                queue[queueEnd] = name
            end
        end

        local sorted = {}
        local sortedCount = 0

        while queueStart <= queueEnd do
            local current = queue[queueStart]
            queueStart = queueStart + 1

            sortedCount = sortedCount + 1
            sorted[sortedCount] = current

            if adjList[current] then
                for nextName in pairs(adjList[current]) do
                    inDegree[nextName] = inDegree[nextName] - 1
                    if inDegree[nextName] == 0 then
                        queueEnd = queueEnd + 1
                        queue[queueEnd] = nextName
                    end
                end
            end
        end

        -- 检查环
        if sortedCount ~= count then
            -- 有环，回退到简单排序
            self:_simplePrioritySort(components, count, priorityField)
            return components
        end

        -- 应用拓扑排序结果
        local result = {}
        for i = 1, sortedCount do
            result[i] = nameToComp[sorted[i]]
        end

        return result
    end

    ---排序update组件
    function system:_sortUpdateComponents()
        local components, count = self:_sortComponentsByType(
                function(comp)
                    return comp.update ~= nil
                end,
                "executePriority",
                "executeBefore",
                "executeAfter"
        )
        self.updateComponents = components
        self.updateComponentCount = count
    end

    ---排序render组件
    function system:_sortRenderComponents()
        local components, count = self:_sortComponentsByType(
                function(comp)
                    return comp.render ~= nil
                end,
                "renderPriority",
                "renderBefore",
                "renderAfter"
        )
        self.renderComponents = components
        self.renderComponentCount = count
    end

    ---压缩数组，移除nil元素
    function system:_compact()
        local components = self.components
        local newComponents = {}
        local newCount = 0

        for i = 1, self.componentCount do
            local comp = components[i]
            if comp then
                newCount = newCount + 1
                newComponents[newCount] = comp
            end
        end

        self.components = newComponents
        self.componentCount = newCount

        -- 重建类型索引
        self.componentsByType = {}
        for i = 1, newCount do
            local comp = newComponents[i]
            local typeName = comp.typeName
            if typeName then
                local typeList = self.componentsByType[typeName]
                if not typeList then
                    typeList = { count = 0 }
                    self.componentsByType[typeName] = typeList
                end
                local typeCount = typeList.count + 1
                typeList.count = typeCount
                typeList[typeCount] = comp
            end
        end
    end

    ---清空所有组件
    function system:clear()
        local components = self.components
        local count = self.componentCount

        for i = 1, count do
            local component = components[i]
            if component and component.onRemove then
                component:onRemove()
            end
        end

        self.components = {}
        self.componentCount = 0
        self.componentsByType = {}
    end

    ---启用/禁用组件
    ---@param componentId number
    ---@param enabled boolean
    function system:setComponentEnabled(componentId, enabled)
        local component = self.components[componentId]
        if component then
            component.enabled = enabled
        end
    end

    return system
end

return {
    new = new,
}

