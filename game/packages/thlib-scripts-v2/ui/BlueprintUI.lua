---@class ui.BlueprintUI
--- 蓝图 UI 框架，用于自定义渲染的可视化界面
local BlueprintUI = {}

local math = math
local string = string

--------------------------------------------------------------------------------
--- 资源初始化
--------------------------------------------------------------------------------

---确保资源已加载
function BlueprintUI.ensureResources()
    -- 检查并加载渲染目标
    if not lstg.CheckRes(2, "rt:blueprint-white") then
        lstg.CreateRenderTarget("rt:blueprint-white", 64, 64)

        -- 填充白色
        lstg.PushRenderTarget("rt:blueprint-white")
        lstg.RenderClear(lstg.Color(255, 255, 255, 255))
        lstg.PopRenderTarget()
    end

    -- 检查并加载白色图像
    if not lstg.CheckRes(8, "img:blueprint-white") then
        lstg.LoadImage("img:blueprint-white", "rt:blueprint-white", 16, 16, 16, 16)
    end

    -- 检查并加载字体
    if not lstg.CheckRes(8, "ttf:blueprint") then
        lstg.LoadTTF("ttf:blueprint", "assets/font/SourceHanSansCN-Bold.otf", 0, 18)
    end
end

--------------------------------------------------------------------------------
--- 输入处理
--------------------------------------------------------------------------------

---@class ui.BlueprintUI.Input
local Input = {}

function Input:init()
    self.mouse = {
        x = 0,
        y = 0,
        left_down = false,
        left_pressed = false,
        left_released = false,
        right_down = false,
        right_pressed = false,
        right_released = false,
        wheel = 0,
        is_move = false,
    }

    self.last_mouse_x = 0
    self.last_mouse_y = 0
    self.last_left = false
    self.last_right = false
end

---更新输入状态
function Input:update()
    local mx, my = lstg.GetMousePosition()

    if screen and screen.scale then
        mx = (mx - screen.dx) / screen.scale
        my = (my - screen.dy) / screen.scale
    end

    self.mouse.x = mx
    self.mouse.y = my

    self.mouse.is_move = (mx ~= self.last_mouse_x or my ~= self.last_mouse_y)
    self.last_mouse_x = mx
    self.last_mouse_y = my

    -- 获取鼠标按钮状态
    local left = lstg.GetMouseState(0)
    local right = lstg.GetMouseState(1)

    self.mouse.left_pressed = left and not self.last_left
    self.mouse.left_released = not left and self.last_left
    self.mouse.left_down = left

    self.mouse.right_pressed = right and not self.last_right
    self.mouse.right_released = not right and self.last_right
    self.mouse.right_down = right

    self.last_left = left
    self.last_right = right

    -- 获取滚轮
    self.mouse.wheel = lstg.GetMouseWheelDelta()
end

---检查鼠标是否在矩形内
---@param x number
---@param y number
---@param width number
---@param height number
---@return boolean
function Input:isMouseInRect(x, y, width, height)
    return self.mouse.x >= x and self.mouse.x <= x + width and
            self.mouse.y >= y and self.mouse.y <= y + height
end

BlueprintUI.Input = Input

--------------------------------------------------------------------------------
--- 画布系统
--------------------------------------------------------------------------------

---@class ui.BlueprintUI.Canvas
local Canvas = {}

function Canvas:init()
    self.offset_x = 0
    self.offset_y = 0
    self.scale = 1.0
    self.min_scale = 0.2
    self.max_scale = 3.0

    -- 画布区域
    self.x = 0
    self.y = 0
    self.width = 0
    self.height = 0

    -- 拖拽状态
    self.dragging = false
    self.drag_start_x = 0
    self.drag_start_y = 0
    self.drag_offset_x = 0
    self.drag_offset_y = 0
end

---设置画布区域
---@param x number
---@param y number
---@param width number
---@param height number
function Canvas:setRect(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
end

---世界坐标转屏幕坐标
---@param wx number
---@param wy number
---@return number, number
function Canvas:worldToScreen(wx, wy)
    local sx = wx * self.scale + self.offset_x + self.x
    local sy = wy * self.scale + self.offset_y + self.y
    return sx, sy
end

---屏幕坐标转世界坐标
---@param sx number
---@param sy number
---@return number, number
function Canvas:screenToWorld(sx, sy)
    local wx = (sx - self.x - self.offset_x) / self.scale
    local wy = (sy - self.y - self.offset_y) / self.scale
    return wx, wy
end

---处理缩放
---@param input ui.BlueprintUI.Input
function Canvas:handleZoom(input)
    if input.mouse.wheel ~= 0 and input:isMouseInRect(self.x, self.y, self.width, self.height) then
        local mouse_world_x, mouse_world_y = self:screenToWorld(input.mouse.x, input.mouse.y)

        self.scale = math.max(self.min_scale, math.min(self.max_scale, self.scale + input.mouse.wheel * 0.001))

        local new_mouse_x, new_mouse_y = self:worldToScreen(mouse_world_x, mouse_world_y)
        self.offset_x = self.offset_x + (input.mouse.x - new_mouse_x)
        self.offset_y = self.offset_y + (input.mouse.y - new_mouse_y)
    end
end

---处理拖拽
---@param input ui.BlueprintUI.Input
function Canvas:handleDrag(input)
    if input.mouse.right_pressed and input:isMouseInRect(self.x, self.y, self.width, self.height) then
        self.dragging = true
        self.drag_start_x = input.mouse.x
        self.drag_start_y = input.mouse.y
        self.drag_offset_x = self.offset_x
        self.drag_offset_y = self.offset_y
    end

    if self.dragging and input.mouse.right_down then
        local dx = input.mouse.x - self.drag_start_x
        local dy = input.mouse.y - self.drag_start_y
        self.offset_x = self.drag_offset_x + dx
        self.offset_y = self.drag_offset_y + dy
    end

    if input.mouse.right_released then
        self.dragging = false
    end
end

---绘制网格背景
function Canvas:drawGrid()
    BlueprintUI.ensureResources()

    local grid_size = 50 * self.scale
    local grid_color = lstg.Color(255 * 0.3, 128, 128, 128)

    -- 计算网格起始位置
    local start_x = (self.offset_x % grid_size) + self.x
    local start_y = (self.offset_y % grid_size) + self.y

    lstg.SetImageState("img:blueprint-white", "", grid_color)

    -- 绘制垂直线
    local x = start_x
    while x < self.x + self.width do
        lstg.RenderRect("img:blueprint-white", x, x + 1, self.y, self.y + self.height)
        x = x + grid_size
    end

    -- 绘制水平线
    local y = start_y
    while y < self.y + self.height do
        lstg.RenderRect("img:blueprint-white", self.x, self.x + self.width, y, y + 1)
        y = y + grid_size
    end
end

---重置视图
function Canvas:reset()
    self.offset_x = 0
    self.offset_y = 0
    self.scale = 1.0
end

BlueprintUI.Canvas = Canvas

--------------------------------------------------------------------------------
--- 渲染工具
--------------------------------------------------------------------------------

---@class ui.BlueprintUI.Renderer
local Renderer = {}

---绘制矩形
---@param x number
---@param y number
---@param width number
---@param height number
---@param color lstg.Color
---@param filled boolean
function Renderer.drawRect(x, y, width, height, color, filled)
    BlueprintUI.ensureResources()

    lstg.SetImageState("img:blueprint-white", "", color)
    if filled then
        lstg.RenderRect("img:blueprint-white", x, x + width, y, y + height)
    else
        local thickness = 2
        lstg.RenderRect("img:blueprint-white", x, x + width, y + height - thickness, y + height)
        lstg.RenderRect("img:blueprint-white", x, x + width, y, y + thickness)
        lstg.RenderRect("img:blueprint-white", x, x + thickness, y, y + height)
        lstg.RenderRect("img:blueprint-white", x + width - thickness, x + width, y, y + height)
    end
end

---绘制线段
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color lstg.Color
---@param thickness number
function Renderer.drawLine(x1, y1, x2, y2, color, thickness)
    BlueprintUI.ensureResources()

    thickness = thickness or 2

    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)

    if length < 0.1 then
        return
    end

    local angle = math.atan2(dy, dx) * 180 / math.pi
    local cx = (x1 + x2) / 2
    local cy = (y1 + y2) / 2

    local img_size = 16
    local hscale = length / img_size
    local vscale = thickness / img_size

    lstg.SetImageState("img:blueprint-white", "", color)
    lstg.Render("img:blueprint-white", cx, cy, angle, hscale, vscale)
end

---绘制箭头
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color lstg.Color
---@param thickness number
---@param arrow_size number
---@param node_radius number
function Renderer.drawArrow(x1, y1, x2, y2, color, thickness, arrow_size, node_radius)
    local dx = x2 - x1
    local dy = y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)

    if length < 0.1 then
        return
    end

    local ux = dx / length
    local uy = dy / length

    local arrow_end_x = x2 - ux * node_radius
    local arrow_end_y = y2 - uy * node_radius

    Renderer.drawLine(x1, y1, arrow_end_x, arrow_end_y, color, thickness)

    local angle = math.atan2(dy, dx)
    local arrow_angle = math.pi / 6

    local p1_x = arrow_end_x
    local p1_y = arrow_end_y
    local p2_x = arrow_end_x - arrow_size * math.cos(angle - arrow_angle)
    local p2_y = arrow_end_y - arrow_size * math.sin(angle - arrow_angle)
    local p3_x = arrow_end_x - arrow_size * math.cos(angle + arrow_angle)
    local p3_y = arrow_end_y - arrow_size * math.sin(angle + arrow_angle)

    Renderer.drawLine(p1_x, p1_y, p2_x, p2_y, color, thickness * 1.5)
    Renderer.drawLine(p1_x, p1_y, p3_x, p3_y, color, thickness * 1.5)
    Renderer.drawLine(p2_x, p2_y, p3_x, p3_y, color, thickness * 1.5)
end

---格式标志枚举
local TTF_FMT = {
    left = 0x00000000,
    center = 0x00000001,
    right = 0x00000002,
    top = 0x00000000,
    vcenter = 0x00000004,
    bottom = 0x00000008,
    noclip = 0x00000100,
}

---绘制文本
---@param text string
---@param x number
---@param y number
---@param color lstg.Color
---@param halign string
---@param valign string
function Renderer.drawText(text, x, y, color, halign, valign)
    BlueprintUI.ensureResources()

    halign = halign or "left"
    valign = valign or "top"

    -- 计算格式标志
    local fmt = (TTF_FMT[halign] or 0) + (TTF_FMT[valign] or 0)

    lstg.RenderTTF("ttf:blueprint", text, x, x, y, y, fmt, color)
end

BlueprintUI.Renderer = Renderer

--------------------------------------------------------------------------------
--- 节点系统
--------------------------------------------------------------------------------

---@class ui.BlueprintUI.Node
local Node = {}

function Node:new(id, name, x, y)
    local obj = {
        id = id,
        name = name,
        x = x or 0,
        y = y or 0,
        width = 150,
        height = 60,

        -- 状态
        is_current = false,
        is_selected = false,
        is_hovered = false,

        -- 用户数据
        data = nil,
    }
    setmetatable(obj, { __index = self })
    return obj
end

---检查点是否在节点内
---@param wx number
---@param wy number
---@return boolean
function Node:containsPoint(wx, wy)
    return wx >= self.x and wx <= self.x + self.width and
            wy >= self.y and wy <= self.y + self.height
end

---绘制节点
---@param canvas ui.BlueprintUI.Canvas
function Node:draw(canvas)
    local sx, sy = canvas:worldToScreen(self.x, self.y)
    local sw = self.width * canvas.scale
    local sh = self.height * canvas.scale

    -- 确定颜色
    local bg_color
    local border_color

    if self.is_current then
        bg_color = lstg.Color(255 * 0.9, 50, 150, 50)
        border_color = lstg.Color(255, 50, 255, 50)
    elseif self.is_selected then
        bg_color = lstg.Color(255 * 0.9, 100, 100, 150)
        border_color = lstg.Color(255, 200, 200, 255)
    elseif self.is_hovered then
        bg_color = lstg.Color(255 * 0.9, 75, 75, 100)
        border_color = lstg.Color(255, 150, 150, 150)
    else
        bg_color = lstg.Color(255 * 0.9, 50, 50, 65)
        border_color = lstg.Color(255, 150, 150, 150)
    end

    -- 绘制背景
    BlueprintUI.Renderer.drawRect(sx, sy, sw, sh, bg_color, true)

    -- 绘制边框
    BlueprintUI.Renderer.drawRect(sx, sy, sw, sh, border_color, false)

    -- 绘制文本
    local text_color = lstg.Color(255, 255, 255, 255)
    local text_y = sy + sh / 2

    -- 缩放太小时不绘制文本
    if canvas.scale > 0.5 then
        BlueprintUI.Renderer.drawText(self.name, sx + sw / 2, text_y + 5, text_color, "center", "vcenter")

        -- 绘制 ID
        if canvas.scale > 0.7 then
            local id_text = string.format("ID:%d", self.id)
            local id_color = lstg.Color(255 * 0.7, 200, 200, 200)
            BlueprintUI.Renderer.drawText(id_text, sx + sw / 2, text_y - 10, id_color, "center", "vcenter")
        end
    end
end

BlueprintUI.Node = Node

--------------------------------------------------------------------------------
--- 连线系统
--------------------------------------------------------------------------------

---@class ui.BlueprintUI.Connection
local Connection = {}

function Connection:new(from_node, to_node, has_condition)
    local obj = {
        from_node = from_node,
        to_node = to_node,
        has_condition = has_condition or false,

        -- 状态
        is_selected = false,
        is_hovered = false,

        -- 用户数据
        data = nil,
    }
    setmetatable(obj, { __index = self })
    return obj
end

---检查点是否接近连线
---@param wx number
---@param wy number
---@param threshold number
---@return boolean
function Connection:isNearPoint(wx, wy, threshold)
    local x1 = self.from_node.x + self.from_node.width / 2
    local y1 = self.from_node.y + self.from_node.height / 2
    local x2 = self.to_node.x + self.to_node.width / 2
    local y2 = self.to_node.y + self.to_node.height / 2

    local dx = x2 - x1
    local dy = y2 - y1
    local length_sq = dx * dx + dy * dy

    if length_sq == 0 then
        return false
    end

    local t = math.max(0, math.min(1, ((wx - x1) * dx + (wy - y1) * dy) / length_sq))
    local proj_x = x1 + t * dx
    local proj_y = y1 + t * dy
    local dist_sq = (wx - proj_x) * (wx - proj_x) + (wy - proj_y) * (wy - proj_y)

    return dist_sq < (threshold * threshold)
end

---绘制连线
---@param canvas ui.BlueprintUI.Canvas
function Connection:draw(canvas)
    -- 计算起点和终点（节点中心）
    local from_x = self.from_node.x + self.from_node.width / 2
    local from_y = self.from_node.y + self.from_node.height / 2
    local to_x = self.to_node.x + self.to_node.width / 2
    local to_y = self.to_node.y + self.to_node.height / 2

    -- 转换到屏幕坐标
    local sx1, sy1 = canvas:worldToScreen(from_x, from_y)
    local sx2, sy2 = canvas:worldToScreen(to_x, to_y)

    -- 确定颜色
    local color
    if self.is_selected then
        color = lstg.Color(255, 255, 128, 50)
    elseif self.is_hovered then
        color = lstg.Color(255, 255, 200, 100)
    elseif self.has_condition then
        color = lstg.Color(255 * 0.8, 200, 200, 50)
    else
        color = lstg.Color(255 * 0.8, 150, 150, 150)
    end

    local thickness = 1.5 * canvas.scale
    local arrow_size = 12 * canvas.scale
    local node_radius = (self.to_node.height / 2) * canvas.scale
    BlueprintUI.Renderer.drawArrow(sx1, sy1, sx2, sy2, color, thickness, arrow_size, node_radius)
end

BlueprintUI.Connection = Connection

--------------------------------------------------------------------------------

return BlueprintUI

