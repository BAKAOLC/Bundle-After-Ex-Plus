---状态机蓝图查看器
---用户可以创建实例来可视化状态机
local BlueprintUI = require("ui.BlueprintUI")

---@class ui.StateMachineBlueprintViewer
local StateMachineBlueprintViewer = {}

---创建新的蓝图查看器
---@return ui.StateMachineBlueprintViewer
function StateMachineBlueprintViewer.new()
    local obj = {
        -- UI 组件
        input = nil,
        canvas = nil,

        -- 节点和连线
        nodes = {},
        connections = {},

        -- 状态机引用
        machine = nil,

        -- 选中状态
        selected_node = nil,
        selected_connection = nil,

        -- 拖拽状态
        dragging_node = nil,
        drag_offset_x = 0,
        drag_offset_y = 0,

        -- 布局状态
        need_layout = true,

        -- 渲染区域
        render_x = 0,
        render_y = 0,
        render_width = 640,
        render_height = 480,

        -- 自动布局参数
        node_spacing_x = 200,
        node_spacing_y = 120,

        -- 启用状态
        enabled = true,
    }

    setmetatable(obj, { __index = StateMachineBlueprintViewer })

    -- 初始化 UI 组件
    obj.input = {}
    for k, v in pairs(BlueprintUI.Input) do
        obj.input[k] = v
    end
    obj.input:init()

    obj.canvas = {}
    for k, v in pairs(BlueprintUI.Canvas) do
        obj.canvas[k] = v
    end
    obj.canvas:init()

    return obj
end

---设置状态机
---@param machine core.StateMachine
function StateMachineBlueprintViewer:setMachine(machine)
    self.machine = machine
    self.need_layout = true
    self:rebuildNodes()
end

---设置渲染区域
---@param x number
---@param y number
---@param width number
---@param height number
function StateMachineBlueprintViewer:setRenderArea(x, y, width, height)
    self.render_x = x
    self.render_y = y
    self.render_width = width
    self.render_height = height
end

---重建节点和连线
function StateMachineBlueprintViewer:rebuildNodes()
    if not self.machine then
        return
    end

    self.nodes = {}
    self.connections = {}

    -- 创建节点
    for i = 1, self.machine.stateCount do
        local state = self.machine.states[i]
        if state then
            local node = BlueprintUI.Node:new(state.id, state.name, 0, 0)
            node.data = state
            self.nodes[state.id] = node
        end
    end

    -- 创建连线
    for i = 1, self.machine.transitionCount do
        local trans = self.machine.transitions[i]
        if trans then
            local from_node = self.nodes[trans.from]
            local to_node = self.nodes[trans.to]
            if from_node and to_node then
                local conn = BlueprintUI.Connection:new(from_node, to_node, trans.condition ~= nil)
                conn.data = trans
                table.insert(self.connections, conn)
            end
        end
    end
end

---层次布局算法
function StateMachineBlueprintViewer:layoutHierarchical()
    if not self.machine or self.machine.stateCount == 0 then
        return
    end

    -- 1. 计算每个节点的层级（BFS）
    local levels = {}
    local visited = {}
    local max_level = 0

    local start_state = self.machine.currentStateId > 0 and self.machine.currentStateId or 1

    local function bfs(start_id)
        local queue = { { id = start_id, level = 0 } }
        visited[start_id] = true
        levels[start_id] = 0

        while #queue > 0 do
            local current = table.remove(queue, 1)
            local transitions = self.machine.transitionsByState[current.id]

            if transitions then
                for _, trans in ipairs(transitions) do
                    if not visited[trans.to] then
                        visited[trans.to] = true
                        local level = current.level + 1
                        levels[trans.to] = level
                        max_level = math.max(max_level, level)
                        table.insert(queue, { id = trans.to, level = level })
                    end
                end
            end
        end
    end

    bfs(start_state)

    -- 处理未访问的节点
    for i = 1, self.machine.stateCount do
        if not visited[i] and self.machine.states[i] then
            bfs(i)
        end
    end

    -- 2. 为每个层级分组节点
    local level_groups = {}
    for i = 0, max_level do
        level_groups[i] = {}
    end

    for state_id, level in pairs(levels) do
        table.insert(level_groups[level], state_id)
    end

    -- 3. 计算位置
    for level = 0, max_level do
        local nodes_in_level = level_groups[level]
        local count = #nodes_in_level

        if count > 0 then
            local total_width = (count - 1) * self.node_spacing_x
            local start_x = -total_width / 2
            local y = level * self.node_spacing_y

            for i, state_id in ipairs(nodes_in_level) do
                local node = self.nodes[state_id]
                if node then
                    node.x = start_x + (i - 1) * self.node_spacing_x
                    node.y = y
                end
            end
        end
    end
end

---更新节点状态
function StateMachineBlueprintViewer:updateNodeStates()
    if not self.machine then
        return
    end

    for id, node in pairs(self.nodes) do
        node.is_current = (id == self.machine.currentStateId)
        node.is_selected = (node == self.selected_node)
    end

    for _, conn in ipairs(self.connections) do
        conn.is_selected = (conn == self.selected_connection)
    end
end

---处理输入
function StateMachineBlueprintViewer:handleInput()
    self.input:update()

    -- 处理缩放
    self.canvas:handleZoom(self.input)

    -- 处理画布拖拽
    self.canvas:handleDrag(self.input)

    -- 获取鼠标世界坐标
    local mouse_world_x, mouse_world_y = self.canvas:screenToWorld(self.input.mouse.x, self.input.mouse.y)

    -- 检查悬停
    local hovered_node
    local hovered_connection

    -- 检查节点悬停
    for _, node in pairs(self.nodes) do
        if node:containsPoint(mouse_world_x, mouse_world_y) then
            hovered_node = node
            break
        end
    end

    -- 如果没有悬停节点，检查连线
    if not hovered_node then
        local threshold = 10 / self.canvas.scale
        for _, conn in ipairs(self.connections) do
            if conn:isNearPoint(mouse_world_x, mouse_world_y, threshold) then
                hovered_connection = conn
                break
            end
        end
    end

    -- 更新悬停状态
    for _, node in pairs(self.nodes) do
        node.is_hovered = (node == hovered_node)
    end
    for _, conn in ipairs(self.connections) do
        conn.is_hovered = (conn == hovered_connection)
    end

    -- 处理点击
    if self.input.mouse.left_pressed then
        if hovered_node then
            -- 选中节点并开始拖拽
            self.selected_node = hovered_node
            self.selected_connection = nil
            self.dragging_node = hovered_node
            self.drag_offset_x = mouse_world_x - hovered_node.x
            self.drag_offset_y = mouse_world_y - hovered_node.y
        elseif hovered_connection then
            -- 选中连线
            self.selected_connection = hovered_connection
            self.selected_node = nil
        else
            -- 取消选中
            self.selected_node = nil
            self.selected_connection = nil
        end
    end

    -- 处理拖拽
    if self.dragging_node and self.input.mouse.left_down then
        self.dragging_node.x = mouse_world_x - self.drag_offset_x
        self.dragging_node.y = mouse_world_y - self.drag_offset_y
    end

    if self.input.mouse.left_released then
        self.dragging_node = nil
    end
end

---更新（在游戏帧循环中调用）
function StateMachineBlueprintViewer:update()
    if not self.enabled then
        return
    end

    -- 重建节点（如果需要）
    if self.machine and next(self.nodes) == nil then
        self:rebuildNodes()
    end

    -- 自动布局（如果需要）
    if self.need_layout then
        self:layoutHierarchical()
        self.canvas:reset()
        self.need_layout = false
    end

    -- 更新节点状态
    self:updateNodeStates()

    -- 处理输入
    self:handleInput()
end

---渲染（在游戏渲染循环中调用）
function StateMachineBlueprintViewer:render()
    if not self.enabled then
        return
    end

    -- 确保资源已加载
    BlueprintUI.ensureResources()

    SetViewMode("ui")

    -- 设置画布区域
    self.canvas:setRect(self.render_x, self.render_y, self.render_width, self.render_height)

    -- 绘制背景
    local bg_color = lstg.Color(255 * 0.8, 20, 20, 30)
    BlueprintUI.Renderer.drawRect(self.render_x, self.render_y, self.render_width, self.render_height, bg_color, true)

    -- 绘制网格
    self.canvas:drawGrid()

    -- 绘制连线
    for _, conn in ipairs(self.connections) do
        conn:draw(self.canvas)
    end

    -- 绘制节点
    for _, node in pairs(self.nodes) do
        node:draw(self.canvas)
    end

    -- 绘制信息面板
    self:drawInfoPanel()

    SetViewMode("world")
end

---绘制信息面板
function StateMachineBlueprintViewer:drawInfoPanel()
    local panel_x = self.render_x + 10
    local panel_y = self.render_y + 10
    local panel_width = 220
    local panel_height = 120

    local panel_bg = lstg.Color(255 * 0.7, 0, 0, 0)
    BlueprintUI.Renderer.drawRect(panel_x, panel_y, panel_width, panel_height, panel_bg, true)

    local text_color = lstg.Color(255, 255, 255, 255)
    local y_offset = panel_y + panel_height - 10

    BlueprintUI.Renderer.drawText(
            string.format("缩放: %.0f%%", self.canvas.scale * 100),
            panel_x + 5, y_offset, text_color, "left", "top")

    y_offset = y_offset - 18
    BlueprintUI.Renderer.drawText(
            string.format("偏移: (%.0f, %.0f)", self.canvas.offset_x, self.canvas.offset_y),
            panel_x + 5, y_offset, text_color, "left", "top")

    if self.selected_node then
        y_offset = y_offset - 18
        local select_color = lstg.Color(255, 100, 255, 100)
        BlueprintUI.Renderer.drawText(
                string.format("选中节点: %s", self.selected_node.name),
                panel_x + 5, y_offset, select_color, "left", "top")
    elseif self.selected_connection then
        y_offset = y_offset - 18
        local select_color = lstg.Color(255, 255, 200, 100)
        BlueprintUI.Renderer.drawText(
                "选中: 连线",
                panel_x + 5, y_offset, select_color, "left", "top")
    end

    y_offset = y_offset - 22
    local hint_color = lstg.Color(255 * 0.7, 180, 180, 180)
    BlueprintUI.Renderer.drawText("左键: 选择/拖拽", panel_x + 5, y_offset, hint_color, "left", "top")
    y_offset = y_offset - 16
    BlueprintUI.Renderer.drawText("右键: 拖拽画布", panel_x + 5, y_offset, hint_color, "left", "top")
    y_offset = y_offset - 16
    BlueprintUI.Renderer.drawText("滚轮: 缩放", panel_x + 5, y_offset, hint_color, "left", "top")
end

---重置布局
function StateMachineBlueprintViewer:resetLayout()
    self.need_layout = true
    self.selected_node = nil
    self.selected_connection = nil
end

---获取选中的节点数据
---@return table|nil
function StateMachineBlueprintViewer:getSelectedNodeData()
    return self.selected_node and self.selected_node.data or nil
end

---获取选中的连线数据
---@return table|nil
function StateMachineBlueprintViewer:getSelectedConnectionData()
    return self.selected_connection and self.selected_connection.data or nil
end

---启用/禁用查看器
---@param enabled boolean
function StateMachineBlueprintViewer:setEnabled(enabled)
    self.enabled = enabled
end

return StateMachineBlueprintViewer

