---缩放约束组件
local pairs = pairs
local ipairs = ipairs
local error = error
local table = table

local lstg = lstg

local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---计算缩放 - 跟随第一个
---@param sources components.ScaleSource[]
---@param owner any
---@return number|nil, number|nil 计算后的hscale, vscale
local function calculateScaleFirst(sources, owner)
    local source = sources[1]
    local target = source.target
    local hscale = target.hscale and (target.hscale * source.scaleX) or owner.hscale
    local vscale = target.vscale and (target.vscale * source.scaleY) or owner.vscale
    return hscale, vscale
end

---计算缩放 - 跟随最后一个
---@param sources components.ScaleSource[]
---@param owner any
---@return number|nil, number|nil 计算后的hscale, vscale
local function calculateScaleLast(sources, owner)
    local source = sources[#sources]
    local target = source.target
    local hscale = target.hscale and (target.hscale * source.scaleX) or owner.hscale
    local vscale = target.vscale and (target.vscale * source.scaleY) or owner.vscale
    return hscale, vscale
end

---计算缩放 - 平均
---@param sources components.ScaleSource[]
---@param owner any
---@return number|nil, number|nil 计算后的hscale, vscale
local function calculateScaleAverage(sources, owner)
    local sumHScale = 0
    local sumVScale = 0
    local count = 0

    for _, source in ipairs(sources) do
        local target = source.target
        if target.hscale then
            sumHScale = sumHScale + target.hscale * source.scaleX
        end
        if target.vscale then
            sumVScale = sumVScale + target.vscale * source.scaleY
        end
        count = count + 1
    end

    if count > 0 then
        local hscale = sumHScale > 0 and (sumHScale / count) or owner.hscale
        local vscale = sumVScale > 0 and (sumVScale / count) or owner.vscale
        return hscale, vscale
    else
        return owner.hscale, owner.vscale
    end
end

---计算缩放 - 加权平均
---@param sources components.ScaleSource[]
---@param owner any
---@return number|nil, number|nil 计算后的hscale, vscale
local function calculateScaleWeighted(sources, owner)
    local sumHScale = 0
    local sumVScale = 0
    local totalWeight = 0

    for _, source in ipairs(sources) do
        local target = source.target
        local weight = source.weight or 1

        if target.hscale then
            sumHScale = sumHScale + target.hscale * source.scaleX * weight
        end
        if target.vscale then
            sumVScale = sumVScale + target.vscale * source.scaleY * weight
        end
        totalWeight = totalWeight + weight
    end

    if totalWeight > 0 then
        local hscale = sumHScale > 0 and (sumHScale / totalWeight) or owner.hscale
        local vscale = sumVScale > 0 and (sumVScale / totalWeight) or owner.vscale
        return hscale, vscale
    else
        return owner.hscale, owner.vscale
    end
end

---缩放计算模式
---@alias ScaleConstraintMode "average"|"weighted"|"first"|"last"
local ScaleConstraintMode = {
    AVERAGE = "average", -- 平均
    WEIGHTED_AVERAGE = "weighted", -- 加权平均
    FIRST = "first", -- 跟随第一个
    LAST = "last", -- 跟随最后一个
}

---@class components.ScaleSourceConfig
---@field scaleX number|nil 缩放X（默认1）
---@field scaleY number|nil 缩放Y（默认1）
---@field weight number|nil 权重（用于加权平均，默认1）

---@class components.ScaleSource
---@field target any 约束目标
---@field scaleX number 缩放X
---@field scaleY number 缩放Y
---@field weight number 权重（用于加权平均）

---@class components.ScaleConstraint : core.Component
---@field sources table<number, components.ScaleSource> 源列表（使用ID作为key）
---@field nextSourceId number 下一个源ID
---@field mode ScaleConstraintMode 缩放计算模式
---@field weight number 约束权重（0-1，用于控制跟随速度，默认1）
---@field onSourceAdded fun(constraint: components.ScaleConstraint, sourceId: number, source: components.ScaleSource)|nil 源添加回调
---@field onSourceRemoved fun(constraint: components.ScaleConstraint, sourceId: number, source: components.ScaleSource)|nil 源移除回调

-- 定义组件类型
local ScaleConstraintType = TypeDef.create("components.ScaleConstraint", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 50,
        alias = "scaleConstraint",
        sources = nil,
        nextSourceId = nil,
        mode = ScaleConstraintMode.AVERAGE,
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

            -- 初始化缩放计算器函数表
            if not self._calculators then
                self._calculators = {
                    [ScaleConstraintMode.FIRST] = calculateScaleFirst,
                    [ScaleConstraintMode.LAST] = calculateScaleLast,
                    [ScaleConstraintMode.AVERAGE] = calculateScaleAverage,
                    [ScaleConstraintMode.WEIGHTED_AVERAGE] = calculateScaleWeighted,
                }
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

            -- 计算目标缩放
            local mode = self.mode or ScaleConstraintMode.AVERAGE
            local calculator = self._calculators[mode]
            if calculator then
                local targetHScale, targetVScale = calculator(validSources, self.owner)
                local weight = self.weight or 1

                -- 应用权重插值
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
        end,

        ---添加约束源
        ---@param target any 约束目标
        ---@param config components.ScaleSourceConfig|nil 配置选项
        ---@return number sourceId 源ID
        addSource = function(self, target, config)
            if not target then
                error("Scale constraint source target cannot be nil", 2)
            end

            if not self.sources then
                self:Awake()
            end

            config = config or {}
            local sourceId = self.nextSourceId
            self.nextSourceId = self.nextSourceId + 1

            local source = {
                target = target,
                scaleX = config.scaleX or 1,
                scaleY = config.scaleY or 1,
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
        ---@return components.ScaleSource|nil
        getSource = function(self, sourceId)
            if not self.sources then
                self:Awake()
            end
            return self.sources[sourceId]
        end,

        ---获取所有约束源
        ---@return table<number, components.ScaleSource>
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

---创建缩放约束组件
---@param config table
---@return components.ScaleConstraint
local function create(config)
    config = config or {}
    return TypeDef.instantiate(ScaleConstraintType, config)
end

return {
    create = create,
    Type = ScaleConstraintType,
    Mode = ScaleConstraintMode,
    -- 导出计算函数供其他组件复用
    calculateScaleFirst = calculateScaleFirst,
    calculateScaleLast = calculateScaleLast,
    calculateScaleAverage = calculateScaleAverage,
    calculateScaleWeighted = calculateScaleWeighted,
}

