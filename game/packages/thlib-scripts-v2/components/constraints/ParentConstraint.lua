---父约束组件（Parent Constraint）
---可以同时约束位置、旋转和缩放，参考 Unity 的 Parent Constraint
local pairs = pairs
local ipairs = ipairs
local error = error
local table = table

local lstg = lstg

local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

-- 复用其他约束组件的计算函数
local PositionConstraint = require("components.constraints.PositionConstraint")
local RotationConstraint = require("components.constraints.RotationConstraint")
local ScaleConstraint = require("components.constraints.ScaleConstraint")

---位置计算模式
---@alias ParentPositionMode "average"|"weighted"|"first"|"last"
local ParentPositionMode = {
    AVERAGE = "average",
    WEIGHTED_AVERAGE = "weighted",
    FIRST = "first",
    LAST = "last",
}

---旋转计算模式
---@alias ParentRotationMode "average"|"weighted"|"first"|"last"
local ParentRotationMode = {
    AVERAGE = "average",
    WEIGHTED_AVERAGE = "weighted",
    FIRST = "first",
    LAST = "last",
}

---缩放计算模式
---@alias ParentScaleMode "average"|"weighted"|"first"|"last"
local ParentScaleMode = {
    AVERAGE = "average",
    WEIGHTED_AVERAGE = "weighted",
    FIRST = "first",
    LAST = "last",
}

---@class components.ParentSourceConfig
---@field constrainPosition boolean|nil 是否约束位置（默认true）
---@field constrainRotation boolean|nil 是否约束旋转（默认false）
---@field constrainScale boolean|nil 是否约束缩放（默认false）
---@field offsetX number|nil 位置偏移X（默认0）
---@field offsetY number|nil 位置偏移Y（默认0）
---@field offsetAngle number|nil 旋转偏移角度（默认0）
---@field scaleX number|nil 缩放X（默认1）
---@field scaleY number|nil 缩放Y（默认1）
---@field followRotation boolean|nil 是否跟随旋转（默认false）
---@field weight number|nil 权重（用于加权平均，默认1）

---@class components.ParentSource
---@field target any 约束目标
---@field constrainPosition boolean 是否约束位置
---@field constrainRotation boolean 是否约束旋转
---@field constrainScale boolean 是否约束缩放
---@field offsetX number 位置偏移X
---@field offsetY number 位置偏移Y
---@field offsetAngle number 旋转偏移角度
---@field scaleX number 缩放X
---@field scaleY number 缩放Y
---@field followRotation boolean 是否跟随旋转
---@field weight number 权重（用于加权平均）

---@class components.ParentConstraint : core.Component
---@field sources table<number, components.ParentSource> 源列表（使用ID作为key）
---@field nextSourceId number 下一个源ID
---@field positionMode ParentPositionMode 位置计算模式
---@field rotationMode ParentRotationMode 旋转计算模式
---@field scaleMode ParentScaleMode 缩放计算模式
---@field weight number 约束权重（0-1，用于控制跟随速度，默认1）
---@field onSourceAdded fun(constraint: components.ParentConstraint, sourceId: number, source: components.ParentSource)|nil 源添加回调
---@field onSourceRemoved fun(constraint: components.ParentConstraint, sourceId: number, source: components.ParentSource)|nil 源移除回调

-- 定义组件类型
local ParentConstraintType = TypeDef.create("components.ParentConstraint", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 50,
        alias = "parentConstraint",
        sources = nil,
        nextSourceId = nil,
        positionMode = ParentPositionMode.AVERAGE,
        rotationMode = ParentRotationMode.AVERAGE,
        scaleMode = ParentScaleMode.AVERAGE,
        weight = 1,
        onSourceAdded = nil,
        onSourceRemoved = nil,
    },
    methods = {
        Awake = function(self)
            -- 初始化源列表
            if not self.sources then
                self.sources = {}
            end
            if not self.nextSourceId then
                self.nextSourceId = 1
            end
        end,

        Update = function(self)
            if not self.owner or not self.sources then
                return
            end

            -- 收集有效的源
            local validSources = {}
            for sourceId, source in pairs(self.sources) do
                local target = source.target
                if target and (not lstg.IsValid or lstg.IsValid(target)) then
                    table.insert(validSources, source)
                end
            end

            if #validSources == 0 then
                return
            end

            local weight = self.weight or 1

            -- 计算位置
            local positionSources = {}
            for _, source in ipairs(validSources) do
                if source.constrainPosition then
                    table.insert(positionSources, {
                        target = source.target,
                        offsetX = source.offsetX,
                        offsetY = source.offsetY,
                        followRotation = source.followRotation,
                        weight = source.weight,
                    })
                end
            end
            if #positionSources > 0 then
                local mode = self.positionMode or ParentPositionMode.AVERAGE
                local calculator = PositionConstraint._calculators and PositionConstraint._calculators[mode]
                if not calculator then
                    -- 直接调用导出的函数
                    if mode == ParentPositionMode.FIRST then
                        calculator = PositionConstraint.calculatePositionFirst
                    elseif mode == ParentPositionMode.LAST then
                        calculator = PositionConstraint.calculatePositionLast
                    elseif mode == ParentPositionMode.AVERAGE then
                        calculator = PositionConstraint.calculatePositionAverage
                    elseif mode == ParentPositionMode.WEIGHTED_AVERAGE then
                        calculator = PositionConstraint.calculatePositionWeighted
                    end
                end
                if calculator then
                    local targetX, targetY = calculator(positionSources, self.owner)
                    if weight >= 1 then
                        self.owner.x = targetX
                        self.owner.y = targetY
                    else
                        local currentX = self.owner.x or 0
                        local currentY = self.owner.y or 0
                        self.owner.x = currentX + (targetX - currentX) * weight
                        self.owner.y = currentY + (targetY - currentY) * weight
                    end
                end
            end

            -- 计算旋转
            local rotationSources = {}
            for _, source in ipairs(validSources) do
                if source.constrainRotation then
                    table.insert(rotationSources, {
                        target = source.target,
                        offsetAngle = source.offsetAngle,
                        weight = source.weight,
                    })
                end
            end
            if #rotationSources > 0 then
                local mode = self.rotationMode or ParentRotationMode.AVERAGE
                local calculator
                if mode == ParentRotationMode.FIRST then
                    calculator = RotationConstraint.calculateRotationFirst
                elseif mode == ParentRotationMode.LAST then
                    calculator = RotationConstraint.calculateRotationLast
                elseif mode == ParentRotationMode.AVERAGE then
                    calculator = RotationConstraint.calculateRotationAverage
                elseif mode == ParentRotationMode.WEIGHTED_AVERAGE then
                    calculator = RotationConstraint.calculateRotationWeighted
                end
                if calculator then
                    local targetRot = calculator(rotationSources, self.owner)
                    if targetRot then
                        if weight >= 1 then
                            self.owner.rot = targetRot
                        else
                            local currentRot = self.owner.rot or 0
                            -- 处理角度环绕（-180 到 180）
                            local diff = ((targetRot - currentRot + 180) % 360) - 180
                            self.owner.rot = currentRot + diff * weight
                        end
                    end
                end
            end

            -- 计算缩放
            local scaleSources = {}
            for _, source in ipairs(validSources) do
                if source.constrainScale then
                    table.insert(scaleSources, {
                        target = source.target,
                        scaleX = source.scaleX,
                        scaleY = source.scaleY,
                        weight = source.weight,
                    })
                end
            end
            if #scaleSources > 0 then
                local mode = self.scaleMode or ParentScaleMode.AVERAGE
                local calculator
                if mode == ParentScaleMode.FIRST then
                    calculator = ScaleConstraint.calculateScaleFirst
                elseif mode == ParentScaleMode.LAST then
                    calculator = ScaleConstraint.calculateScaleLast
                elseif mode == ParentScaleMode.AVERAGE then
                    calculator = ScaleConstraint.calculateScaleAverage
                elseif mode == ParentScaleMode.WEIGHTED_AVERAGE then
                    calculator = ScaleConstraint.calculateScaleWeighted
                end
                if calculator then
                    local targetHScale, targetVScale = calculator(scaleSources, self.owner)
                    if weight >= 1 then
                        if targetHScale then
                            self.owner.hscale = targetHScale
                        end
                        if targetVScale then
                            self.owner.vscale = targetVScale
                        end
                    else
                        local currentHScale = self.owner.hscale or 1
                        local currentVScale = self.owner.vscale or 1
                        if targetHScale then
                            self.owner.hscale = currentHScale + (targetHScale - currentHScale) * weight
                        end
                        if targetVScale then
                            self.owner.vscale = currentVScale + (targetVScale - currentVScale) * weight
                        end
                    end
                end
            end
        end,

        ---添加约束源
        ---@param target any 约束目标
        ---@param config components.ParentSourceConfig|nil 配置选项
        ---@return number sourceId 源ID
        addSource = function(self, target, config)
            if not target then
                error("Parent constraint source target cannot be nil", 2)
            end

            if not self.sources then
                self:Awake()
            end

            config = config or {}
            local sourceId = self.nextSourceId
            self.nextSourceId = self.nextSourceId + 1

            local source = {
                target = target,
                constrainPosition = config.constrainPosition ~= false, -- 默认约束位置
                constrainRotation = config.constrainRotation or false,
                constrainScale = config.constrainScale or false,
                offsetX = config.offsetX or 0,
                offsetY = config.offsetY or 0,
                offsetAngle = config.offsetAngle or 0,
                scaleX = config.scaleX or 1,
                scaleY = config.scaleY or 1,
                followRotation = config.followRotation or false,
                weight = config.weight or 1,
            }

            self.sources[sourceId] = source

            if self.onSourceAdded then
                self.onSourceAdded(self, sourceId, source)
            end

            return sourceId
        end,

        ---移除约束源
        ---@param sourceId number 源ID
        removeSource = function(self, sourceId)
            if not self.sources then
                return
            end

            local source = self.sources[sourceId]
            if source then
                if self.onSourceRemoved then
                    self.onSourceRemoved(self, sourceId, source)
                end
                self.sources[sourceId] = nil
            end
        end,

        ---移除所有约束源
        clearSources = function(self)
            if not self.sources then
                return
            end

            for sourceId, source in pairs(self.sources) do
                if self.onSourceRemoved then
                    self.onSourceRemoved(self, sourceId, source)
                end
            end
            self.sources = {}
        end,

        ---获取约束源
        ---@param sourceId number 源ID
        ---@return components.ParentSource|nil
        getSource = function(self, sourceId)
            if not self.sources then
                self:Awake()
            end
            return self.sources[sourceId]
        end,

        ---获取所有约束源
        ---@return table<number, components.ParentSource>
        getAllSources = function(self)
            if not self.sources then
                self:Awake()
            end
            return self.sources
        end,

        ---检查是否有约束源
        ---@param target any|nil 目标对象，如果为nil则检查是否有任何源
        ---@return boolean
        hasSource = function(self, target)
            if not self.sources then
                self:Awake()
            end

            if target then
                for _, source in pairs(self.sources) do
                    if source.target == target then
                        return true
                    end
                end
                return false
            else
                return next(self.sources) ~= nil
            end
        end,
    },
})

---创建父约束组件
---@param config table
---@return components.ParentConstraint
local function create(config)
    config = config or {}
    return TypeDef.instantiate(ParentConstraintType, config)
end

return {
    create = create,
    Type = ParentConstraintType,
    PositionMode = ParentPositionMode,
    RotationMode = ParentRotationMode,
    ScaleMode = ParentScaleMode,
}

