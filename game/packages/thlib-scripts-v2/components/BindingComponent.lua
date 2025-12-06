---绑定关系组件
local pairs = pairs
local math = math
local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

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
---@field data table|nil 自定义数据

---@class components.BindingComponent : core.Component
---@field bindings table<number, components.BindingInfo> 绑定列表（使用ID作为key）
---@field nextBindingId number 下一个绑定ID
---@field onBindingAdded function|nil 绑定添加回调 function(bindingComponent, bindingId, bindingInfo)
---@field onBindingRemoved function|nil 绑定移除回调 function(bindingComponent, bindingId, bindingInfo)

-- 定义组件类型
local BindingComponentType = TypeDef.create("components.BindingComponent", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 50,
        alias = "binding",
        bindings = nil,
        nextBindingId = nil,
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
        end,

        Update = function(self)
            if not self.owner or not self.bindings then
                return
            end

            for _, bindingInfo in pairs(self.bindings) do
                local target = bindingInfo.target

                -- 检查目标是否有效
                if not target or (lstg.IsValid and not lstg.IsValid(target)) then
                    -- 目标无效，跳过
                    goto continue
                end

                -- 绑定位置
                if bindingInfo.bindPosition then
                    local targetX = target.x or 0
                    local targetY = target.y or 0

                    -- 如果有旋转偏移
                    if bindingInfo.followRotation and target.rot then
                        local angle = math.rad(target.rot)
                        local cos = math.cos(angle)
                        local sin = math.sin(angle)
                        local offsetX = bindingInfo.offsetX
                        local offsetY = bindingInfo.offsetY
                        self.owner.x = targetX + offsetX * cos - offsetY * sin
                        self.owner.y = targetY + offsetX * sin + offsetY * cos
                    else
                        self.owner.x = targetX + bindingInfo.offsetX
                        self.owner.y = targetY + bindingInfo.offsetY
                    end
                end

                -- 绑定旋转
                if bindingInfo.bindRotation and target.rot then
                    self.owner.rot = target.rot + bindingInfo.offsetAngle
                end

                -- 绑定缩放
                if bindingInfo.bindScale then
                    if target.hscale then
                        self.owner.hscale = target.hscale * bindingInfo.scaleX
                    end
                    if target.vscale then
                        self.owner.vscale = target.vscale * bindingInfo.scaleY
                    end
                end

                :: continue ::
            end
        end,

        -- 添加绑定
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
                data = config.data or {},
            }

            self.bindings[bindingId] = bindingInfo

            if self.onBindingAdded then
                self.onBindingAdded(self, bindingId, bindingInfo)
            end

            return bindingId
        end,

        -- 移除绑定
        removeBinding = function(self, bindingId)
            if not self.bindings then
                return
            end

            local bindingInfo = self.bindings[bindingId]
            if bindingInfo then
                if self.onBindingRemoved then
                    self.onBindingRemoved(self, bindingId, bindingInfo)
                end
                self.bindings[bindingId] = nil
            end
        end,

        -- 移除所有绑定
        clearBindings = function(self)
            if not self.bindings then
                return
            end

            for bindingId, bindingInfo in pairs(self.bindings) do
                if self.onBindingRemoved then
                    self.onBindingRemoved(self, bindingId, bindingInfo)
                end
            end
            self.bindings = {}
        end,

        -- 获取绑定信息
        getBinding = function(self, bindingId)
            if not self.bindings then
                self:Awake()
            end
            return self.bindings[bindingId]
        end,

        -- 获取所有绑定
        getAllBindings = function(self)
            if not self.bindings then
                self:Awake()
            end
            return self.bindings
        end,

        -- 检查是否有绑定
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
}
