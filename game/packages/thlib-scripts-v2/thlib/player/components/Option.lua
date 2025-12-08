local type = type
local math = math
local TypeDef = require("core.TypeDef")

---单个子机对象
---每个子机是独立的对象，能够响应火力变化等事件

---@class thlib.Player.OptionConfig
---@field requiredPower number|nil 需要的火力等级（默认为 index-1）
---@field lerpSpeed number|nil 位置插值速度（默认 0.3）
---@field alphaLerpSpeed number|nil 透明度插值速度（默认 1）
---@field image string|nil 子机图像
---@field color {a: number, r: number, g: number, b: number}|userdata|function|nil 颜色（table: {a,r,g,b}, Color对象, 或返回颜色的函数）
---@field scaleX number|nil 水平缩放（默认 1.0）
---@field scaleY number|nil 垂直缩放（默认 1.0）
---@field blendMode string|nil 混合模式（默认 ""）
---@field rot number|nil 初始旋转角度（默认 0）
---@field omega number|nil 每帧旋转角度（默认 0）
---@field angle number|function|nil 发射角度（供射击使用，数值或返回角度的函数）
---@field getTargetOffset fun(option: thlib.Player.Option): number, number|nil 获取目标偏移量函数，返回 offsetX, offsetY
---@field onAwake fun(option: thlib.Player.Option)|nil Awake 生命周期回调
---@field onStart fun(option: thlib.Player.Option)|nil Start 生命周期回调
---@field onUpdate fun(option: thlib.Player.Option)|nil Update 生命周期回调
---@field onLateUpdate fun(option: thlib.Player.Option)|nil LateUpdate 生命周期回调
---@field onRender fun(option: thlib.Player.Option)|nil OnRender 生命周期回调
---@field onDestroy fun(option: thlib.Player.Option)|nil OnDestroy 生命周期回调
---@field onActivate fun(option: thlib.Player.Option)|nil 激活时回调
---@field onDeactivate fun(option: thlib.Player.Option)|nil 停用时回调
---@field onShoot fun(option: thlib.Player.Option, player: thlib.Player)|nil 射击时回调
---@field shootInterval number|nil 射击间隔（帧数，0表示与主体同步，nil表示不射击）

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
---@field color {a: number, r: number, g: number, b: number}|userdata|function|nil 颜色
---@field scaleX number 水平缩放
---@field scaleY number 垂直缩放
---@field blendMode string 混合模式
---@field getTargetOffset fun(option: thlib.Player.Option): number, number|nil 获取目标偏移量函数

-- 定义 Option 类型
local OptionType = TypeDef.create("thlib.Player.Option", nil, {
    defaults = {
        index = 0,
        owner = nil,
        x = 0,
        y = 0,
        timer = 0,
        rot = 0,
        omega = 0,
        alpha = 0,
        visible = false,
        active = false,
        config = {},
        powerComp = nil,
        customData = {},
        lerpSpeed = 0.3,
        alphaLerpSpeed = 1,
        requiredPower = 0,
        image = nil,
        color = nil,
        scaleX = 1.0,
        scaleY = 1.0,
        blendMode = "",
        getTargetOffset = nil,
        shootInterval = nil,
        shootTimer = 0,
    },
    methods = {
        setPowerComponent = function(self, powerComp)
            self.powerComp = powerComp
        end,

        Awake = function(self)
            if self.config.onAwake then
                self.config.onAwake(self)
            end
        end,

        Start = function(self)
            -- Start 生命周期，在第一次 Update 之前调用
            -- 此时 powerComp 应该已经设置
            -- 初始化时，直接设置 alpha 为目标值，不进行过渡
            if self.powerComp then
                local support = self.powerComp:getSupport()
                self.active = (support >= self.requiredPower)
                self.alpha = self.active and 1.0 or 0.0
                self.visible = self.alpha > 0
            end
            
            if self.config.onStart then
                self.config.onStart(self)
            end
        end,

        Update = function(self)
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

            -- 更新射击计时器
            if self.shootInterval ~= nil and self.shootTimer > 0 then
                self.shootTimer = self.shootTimer - 1
            end

            -- 使用插值过渡透明度
            local targetAlpha = self.active and 1.0 or 0.0
            self.alpha = self.alpha + (targetAlpha - self.alpha) * self.alphaLerpSpeed
            -- 根据透明度判断可见性
            self.visible = self.alpha > 0

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
        end,

        LateUpdate = function(self)
            -- LateUpdate 生命周期，在 Update 之后调用
            if self.config.onLateUpdate then
                self.config.onLateUpdate(self)
            end
        end,

        OnRender = function(self)
            if not self.visible then
                return
            end

            -- 调用配置中的 OnRender 回调
            if self.config.onRender then
                self.config.onRender(self)
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
        end,

        OnDestroy = function(self)
            -- OnDestroy 生命周期，在销毁时调用
            if self.config.onDestroy then
                self.config.onDestroy(self)
            end

            -- 清理资源
            self.powerComp = nil
            self.config = nil
            self.getTargetOffset = nil
        end,

        getAngle = function(self)
            if self.config.angle then
                if type(self.config.angle) == "function" then
                    return self.config.angle(self)
                else
                    return self.config.angle
                end
            end
            return nil
        end,

        ---检查是否可以射击
        ---@return boolean
        canShoot = function(self)
            if not self.active or not self.visible then
                return false
            end
            if self.shootInterval == nil then
                return false
            end
            if self.shootInterval == 0 then
                return true
            end
            return self.shootTimer <= 0
        end,

        ---触发射击（重置射击计时器）
        triggerShoot = function(self)
            if self.shootInterval and self.shootInterval > 0 then
                self.shootTimer = self.shootInterval
            end
        end,
    },
})

---创建子机对象
---@param owner thlib.Player
---@param index number 子机索引（从1开始）
---@param config thlib.Player.OptionConfig 配置
---@return thlib.Player.Option
local function new(owner, index, config)
    config = config or {}

    local option = TypeDef.instantiate(OptionType, {
        index = index,
        owner = owner,
        x = owner.x,
        y = owner.y,
        timer = 0,
        rot = config.rot or 0,
        omega = config.omega or 0,
        alpha = 0,
        visible = false,
        active = false,
        config = config,
        powerComp = nil,
        customData = {},
        lerpSpeed = config.lerpSpeed or 0.3,
        alphaLerpSpeed = config.alphaLerpSpeed or 1,
        requiredPower = config.requiredPower or (index - 1),
        image = config.image,
        color = config.color or Color(255, 255, 255, 255),
        scaleX = config.scaleX or 1.0,
        scaleY = config.scaleY or 1.0,
        blendMode = config.blendMode or "",
        getTargetOffset = config.getTargetOffset,
        shootInterval = config.shootInterval,
        shootTimer = 0,
        _lifecycleStarted = false, -- 标记 Start 是否已调用
    })

    -- 立即调用 Awake 生命周期
    local awake = option.Awake
    if awake then
        awake(option)
    end

    return option
end

---辅助方法：创建定点式子机配置
---@param image string 子机图像
---@param angle number 发射角度
---@param positions table<number, {highSpeed: {x: number, y: number}, lowSpeed: {x: number, y: number}}> 各火力等级的位置配置
---@param extraConfig thlib.Player.OptionConfig|nil 额外配置（image、angle、getTargetOffset 字段会被忽略，因为这些已在函数参数中提供）
---@return thlib.Player.OptionConfig
local function createFixedOption(image, angle, positions, extraConfig)
    extraConfig = extraConfig or {}
    return {
        image = image,
        angle = angle,
        requiredPower = extraConfig.requiredPower,
        lerpSpeed = extraConfig.lerpSpeed,
        alphaLerpSpeed = extraConfig.alphaLerpSpeed,
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
        onAwake = extraConfig.onAwake,
        onStart = extraConfig.onStart,
        onUpdate = extraConfig.onUpdate,
        onLateUpdate = extraConfig.onLateUpdate,
        onRender = extraConfig.onRender,
        onDestroy = extraConfig.onDestroy,
        onActivate = extraConfig.onActivate,
        onDeactivate = extraConfig.onDeactivate,
        onShoot = extraConfig.onShoot,
        shootInterval = extraConfig.shootInterval,
    }
end

---辅助方法：创建环绕式子机配置
---@param image string 子机图像
---@param radius number|function 环绕半径（数值或函数）
---@param initialAngle number 初始角度（度）
---@param angularSpeed number 角速度（度/帧）
---@param extraConfig thlib.Player.OptionConfig|nil 额外配置（image、getTargetOffset 字段会被忽略，因为这些已在函数中自动生成；angle 字段可选，默认使用环绕角度）
---@return thlib.Player.OptionConfig
local function createOrbitOption(image, radius, initialAngle, angularSpeed, extraConfig)
    extraConfig = extraConfig or {}
    return {
        image = image,
        angle = extraConfig.angle or function(opt)
            -- 默认发射角度为环绕角度
            return initialAngle + opt.timer * angularSpeed
        end,
        requiredPower = extraConfig.requiredPower,
        lerpSpeed = extraConfig.lerpSpeed or 0.2,
        alphaLerpSpeed = extraConfig.alphaLerpSpeed,
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
        onAwake = extraConfig.onAwake,
        onStart = extraConfig.onStart,
        onUpdate = extraConfig.onUpdate,
        onLateUpdate = extraConfig.onLateUpdate,
        onRender = extraConfig.onRender,
        onDestroy = extraConfig.onDestroy,
        onActivate = extraConfig.onActivate,
        onDeactivate = extraConfig.onDeactivate,
        onShoot = extraConfig.onShoot,
        shootInterval = extraConfig.shootInterval,
    }
end

return {
    new = new,
    Type = OptionType,
    createFixedOption = createFixedOption,
    createOrbitOption = createOrbitOption,
}
