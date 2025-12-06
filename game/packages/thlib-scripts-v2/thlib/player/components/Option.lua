local type = type
local math = math
local setmetatable = setmetatable

---单个子机对象
---每个子机是独立的对象，能够响应火力变化等事件

---@class thlib.Player.OptionConfig
---@field requiredPower number|nil 需要的火力等级（默认为 index-1）
---@field lerpSpeed number|nil 位置插值速度（默认 0.3）
---@field alphaLerpSpeed number|nil 透明度插值速度（默认 0.1）
---@field image string|nil 子机图像
---@field color table|userdata|function|nil 颜色（table: {a,r,g,b}, Color对象, 或返回颜色的函数）
---@field scaleX number|nil 水平缩放（默认 1.0）
---@field scaleY number|nil 垂直缩放（默认 1.0）
---@field blendMode string|nil 混合模式（默认 ""）
---@field rot number|nil 初始旋转角度（默认 0）
---@field omega number|nil 每帧旋转角度（默认 0）
---@field angle number|function|nil 发射角度（供射击使用，数值或返回角度的函数）
---@field getTargetOffset fun(option: thlib.Player.Option): number, number|nil 获取目标偏移量函数，返回 offsetX, offsetY
---@field customRender fun(option: thlib.Player.Option)|nil 自定义渲染函数
---@field onInit fun(option: thlib.Player.Option)|nil 初始化回调
---@field onUpdate fun(option: thlib.Player.Option)|nil 每帧更新回调
---@field onActivate fun(option: thlib.Player.Option)|nil 激活时回调
---@field onDeactivate fun(option: thlib.Player.Option)|nil 停用时回调

---@class thlib.Player.Option
---@field index number 子机索引
---@field owner thlib.Player 玩家对象
---@field x number 当前X坐标
---@field y number 当前Y坐标
---@field timer number 计时器（每帧+1）
---@field rot number 当前旋转角度（用于图像渲染）
---@field omega number 每帧旋转角度（用于图像渲染）
---@field alpha number 当前透明度
---@field visible boolean 是否可见
---@field active boolean 是否激活（达到所需火力等级）
---@field config thlib.Player.OptionConfig 配置
---@field powerComp thlib.Player.PowerComponent|nil 火力组件引用
---@field customData table 自定义数据（供位置函数使用）
---@field lerpSpeed number 位置插值速度
---@field alphaLerpSpeed number 透明度插值速度
---@field requiredPower number 需要的火力等级
---@field image string|nil 子机图像
---@field color table|userdata|function|nil 颜色
---@field scaleX number 水平缩放
---@field scaleY number 垂直缩放
---@field blendMode string 混合模式
---@field getTargetOffset fun(option: thlib.Player.Option): number, number|nil 获取目标偏移量函数
---@field customRender fun(option: thlib.Player.Option)|nil 自定义渲染函数
local Option = {}
Option.__index = Option

---创建子机对象
---@param owner thlib.Player
---@param index number 子机索引（从1开始）
---@param config thlib.Player.OptionConfig 配置
---@return thlib.Player.Option
function Option.new(owner, index, config)
    local self = setmetatable({}, Option)

    self.index = index
    self.owner = owner
    self.x = owner.x
    self.y = owner.y
    self.timer = 0
    self.rot = config.rot or 0
    self.omega = config.omega or 0
    self.alpha = 0
    self.visible = false
    self.active = false
    self.config = config or {}
    self.powerComp = nil
    self.customData = {}

    -- 配置参数
    self.lerpSpeed = config.lerpSpeed or 0.3
    self.alphaLerpSpeed = config.alphaLerpSpeed or 0.1
    self.requiredPower = config.requiredPower or (index - 1)  -- 需要的火力等级，默认为 index-1

    -- 视觉配置
    self.image = config.image  -- 子机自己的图像
    self.color = config.color or Color(255, 255, 255, 255)  -- 子机颜色
    self.scaleX = config.scaleX or 1.0  -- 水平缩放
    self.scaleY = config.scaleY or 1.0  -- 垂直缩放
    self.blendMode = config.blendMode or ""  -- 混合模式

    -- 获取目标偏移量函数：function(option) -> offsetX, offsetY
    self.getTargetOffset = config.getTargetOffset

    -- 渲染函数（可选）：function(option, defaultImage, baseRotation)
    self.customRender = config.customRender

    -- 初始化函数（可选）：function(option)
    if config.onInit then
        config.onInit(self)
    end

    return self
end

---设置火力组件引用
---@param powerComp thlib.Player.PowerComponent
function Option:setPowerComponent(powerComp)
    self.powerComp = powerComp
end

---更新子机状态
function Option:update()
    if not self.powerComp then
        return
    end

    -- 获取当前火力等级
    local support = self.powerComp:getSupport()

    -- 判断是否激活
    local wasActive = self.active
    self.active = (support >= self.requiredPower)

    -- 触发激活/停用事件
    if self.active and not wasActive and self.config.onActivate then
        self.config.onActivate(self)
    elseif not self.active and wasActive and self.config.onDeactivate then
        self.config.onDeactivate(self)
    end

    -- 更新计时器
    self.timer = self.timer + 1

    -- 直接设置透明度和可见性
    if self.active then
        self.alpha = 1.0
        self.visible = true
    else
        self.alpha = 0
        self.visible = false
    end

    -- 更新图像旋转角度
    self.rot = self.rot + self.omega

    -- 更新位置
    if self.getTargetOffset then
        local baseX, baseY = self.powerComp:getSupportPosition()
        local offsetX, offsetY = self.getTargetOffset(self)

        local targetX = baseX + (offsetX or 0)
        local targetY = baseY + (offsetY or 0)

        self.x = self.x + (targetX - self.x) * self.lerpSpeed
        self.y = self.y + (targetY - self.y) * self.lerpSpeed
    end

    -- 调用自定义更新函数
    if self.config.onUpdate then
        self.config.onUpdate(self)
    end
end

---渲染子机
function Option:render()
    if not self.visible then
        return
    end

    -- 使用自定义渲染函数
    if self.customRender then
        self.customRender(self)
        return
    end

    -- 确定使用的图像
    if not self.image then
        return
    end

    -- 使用子机自己的旋转角度
    local rotation = self.rot

    -- 应用颜色和透明度
    local color = self.color
    local colorType = type(color)
    local colorA, colorR, colorG, colorB
    if colorType == "function" then
        color = color(self)
        colorType = type(color)
    end

    if colorType == "table" then
        colorA = color.a or 255
        colorR = color.r or 255
        colorG = color.g or 255
        colorB = color.b or 255
    elseif colorType == "userdata" then
        colorA, colorR, colorG, colorB = color:ARGB()
    else
        colorA = 255
        colorR = 255
        colorG = 255
        colorB = 255
    end

    local finalColor = Color(
            math.floor(colorA * self.alpha),
            colorR,
            colorG,
            colorB
    )

    -- 渲染
    SetImageState(self.image, self.blendMode, finalColor)
    Render(self.image, self.x, self.y, rotation, self.scaleX, self.scaleY)
end

---获取子机的角度（供外部使用，如射击）
---@return number|nil
function Option:getAngle()
    if self.config.angle then
        if type(self.config.angle) == "function" then
            return self.config.angle(self)
        else
            return self.config.angle
        end
    end
    return nil
end

---辅助方法：创建定点式子机配置
---@param image string 子机图像
---@param angle number 发射角度
---@param positions table<number, {highSpeed: {x: number, y: number}, lowSpeed: {x: number, y: number}}> 各火力等级的位置配置
---@param extraConfig table|nil 额外配置
---@return thlib.Player.OptionConfig
function Option.createFixedOption(image, angle, positions, extraConfig)
    extraConfig = extraConfig or {}
    return {
        image = image,
        angle = angle,
        requiredPower = extraConfig.requiredPower,
        lerpSpeed = extraConfig.lerpSpeed,
        color = extraConfig.color,
        scaleX = extraConfig.scaleX,
        scaleY = extraConfig.scaleY,
        blendMode = extraConfig.blendMode,
        rot = extraConfig.rot,
        omega = extraConfig.omega,
        getTargetOffset = function(opt)
            local isSlowMode = (opt.owner.slow == 1)
            local support = opt.powerComp:getSupport()

            -- 找到当前火力等级对应的位置
            local powerLevel = math.floor(support)
            if powerLevel < opt.requiredPower then
                powerLevel = opt.requiredPower
            end

            -- 查找最接近的配置
            local pos = positions[powerLevel]
            if not pos then
                -- 如果没有找到，使用最高的可用配置
                for i = powerLevel, opt.requiredPower, -1 do
                    if positions[i] then
                        pos = positions[i]
                        break
                    end
                end
            end

            if pos then
                if isSlowMode and pos.lowSpeed then
                    return pos.lowSpeed.x, pos.lowSpeed.y
                elseif pos.highSpeed then
                    return pos.highSpeed.x, pos.highSpeed.y
                end
            end

            return 0, 0
        end,
        onInit = extraConfig.onInit,
        onUpdate = extraConfig.onUpdate,
        onActivate = extraConfig.onActivate,
        onDeactivate = extraConfig.onDeactivate,
    }
end

---辅助方法：创建环绕式子机配置
---@param image string 子机图像
---@param radius number|function 环绕半径（数值或函数）
---@param initialAngle number 初始角度（度）
---@param angularSpeed number 角速度（度/帧）
---@param extraConfig table|nil 额外配置 {requiredPower, lerpSpeed, color, scaleX, scaleY, blendMode, rot, omega, angle, ...}
---@return thlib.Player.OptionConfig
function Option.createOrbitOption(image, radius, initialAngle, angularSpeed, extraConfig)
    extraConfig = extraConfig or {}
    return {
        image = image,
        angle = extraConfig.angle or function(opt)
            -- 默认发射角度为环绕角度
            return initialAngle + opt.timer * angularSpeed
        end,
        requiredPower = extraConfig.requiredPower,
        lerpSpeed = extraConfig.lerpSpeed or 0.2,
        color = extraConfig.color,
        scaleX = extraConfig.scaleX,
        scaleY = extraConfig.scaleY,
        blendMode = extraConfig.blendMode,
        rot = extraConfig.rot or 0,
        omega = extraConfig.omega or 0,
        getTargetOffset = function(opt)
            local r = radius
            if type(radius) == "function" then
                r = radius(opt)
            end
            -- 使用 timer 计算环绕角度
            local angle = initialAngle + opt.timer * angularSpeed
            return r * math.cos(math.rad(angle)), r * math.sin(math.rad(angle))
        end,
        onInit = extraConfig.onInit,
        onUpdate = extraConfig.onUpdate,
        onActivate = extraConfig.onActivate,
        onDeactivate = extraConfig.onDeactivate,
    }
end

return Option
