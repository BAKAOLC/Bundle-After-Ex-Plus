---旋转约束组件
local pairs = pairs
local ipairs = ipairs
local error = error
local table = table

local lstg = lstg

local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---计算旋转 - 跟随第一个
---@param sources components.RotationSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateRotationFirst(sources, owner)
    local source = sources[1]
    local target = source.target
    if target.rot then
        return target.rot + source.offsetAngle
    end
    return owner.rot
end

---计算旋转 - 跟随最后一个
---@param sources components.RotationSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateRotationLast(sources, owner)
    local source = sources[#sources]
    local target = source.target
    if target.rot then
        return target.rot + source.offsetAngle
    end
    return owner.rot
end

---计算旋转 - 平均
---@param sources components.RotationSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateRotationAverage(sources, owner)
    local sumRot = 0
    local count = 0

    for _, source in ipairs(sources) do
        local target = source.target
        if target.rot then
            sumRot = sumRot + target.rot + source.offsetAngle
            count = count + 1
        end
    end

    if count > 0 then
        return sumRot / count
    else
        return owner.rot
    end
end

---计算旋转 - 加权平均
---@param sources components.RotationSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateRotationWeighted(sources, owner)
    local sumRot = 0
    local totalWeight = 0

    for _, source in ipairs(sources) do
        local target = source.target
        if target.rot then
            local weight = source.weight or 1
            sumRot = sumRot + (target.rot + source.offsetAngle) * weight
            totalWeight = totalWeight + weight
        end
    end

    if totalWeight > 0 then
        return sumRot / totalWeight
    else
        return owner.rot
    end
end

---旋转计算模式
---@alias RotationConstraintMode "average"|"weighted"|"first"|"last"
local RotationConstraintMode = {
    AVERAGE = "average", -- 平均
    WEIGHTED_AVERAGE = "weighted", -- 加权平均
    FIRST = "first", -- 跟随第一个
    LAST = "last", -- 跟随最后一个
}

---@class components.RotationSourceConfig
---@field offsetAngle number|nil 旋转偏移角度（默认0）
---@field weight number|nil 权重（用于加权平均，默认1）

---@class components.RotationSource
---@field target any 约束目标
---@field offsetAngle number 旋转偏移角度
---@field weight number 权重（用于加权平均）

---@class components.RotationConstraint : core.Component
---@field sources table<number, components.RotationSource> 源列表（使用ID作为key）
---@field nextSourceId number 下一个源ID
---@field mode RotationConstraintMode 旋转计算模式
---@field weight number 约束权重（0-1，用于控制跟随速度，默认1）
---@field onSourceAdded fun(constraint: components.RotationConstraint, sourceId: number, source: components.RotationSource)|nil 源添加回调
---@field onSourceRemoved fun(constraint: components.RotationConstraint, sourceId: number, source: components.RotationSource)|nil 源移除回调

-- 定义组件类型
local RotationConstraintType = TypeDef.create("components.RotationConstraint", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 50,
        alias = "rotationConstraint",
        sources = nil,
        nextSourceId = nil,
        mode = RotationConstraintMode.AVERAGE,
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

            -- 初始化旋转计算器函数表
            if not self._calculators then
                self._calculators = {
                    [RotationConstraintMode.FIRST] = calculateRotationFirst,
                    [RotationConstraintMode.LAST] = calculateRotationLast,
                    [RotationConstraintMode.AVERAGE] = calculateRotationAverage,
                    [RotationConstraintMode.WEIGHTED_AVERAGE] = calculateRotationWeighted,
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

            -- 计算目标旋转
            local mode = self.mode or RotationConstraintMode.AVERAGE
            local calculator = self._calculators[mode]
            if calculator then
                local targetRot = calculator(validSources, self.owner)
                if targetRot then
                    local weight = self.weight or 1

                    -- 应用权重插值
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
        end,

        ---添加约束源
        ---@param target any 约束目标
        ---@param config components.RotationSourceConfig|nil 配置选项
        ---@return number sourceId 源ID
        addSource = function(self, target, config)
            if not target then
                error("Rotation constraint source target cannot be nil", 2)
            end

            if not self.sources then
                self:Awake()
            end

            config = config or {}
            local sourceId = self.nextSourceId
            self.nextSourceId = self.nextSourceId + 1

            local source = {
                target = target,
                offsetAngle = config.offsetAngle or 0,
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
        ---@return components.RotationSource|nil
        getSource = function(self, sourceId)
            if not self.sources then
                self:Awake()
            end
            return self.sources[sourceId]
        end,

        ---获取所有约束源
        ---@return table<number, components.RotationSource>
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

---创建旋转约束组件
---@param config table
---@return components.RotationConstraint
local function create(config)
    config = config or {}
    return TypeDef.instantiate(RotationConstraintType, config)
end

return {
    create = create,
    Type = RotationConstraintType,
    Mode = RotationConstraintMode,
    -- 导出计算函数供其他组件复用
    calculateRotationFirst = calculateRotationFirst,
    calculateRotationLast = calculateRotationLast,
    calculateRotationAverage = calculateRotationAverage,
    calculateRotationWeighted = calculateRotationWeighted,
}

