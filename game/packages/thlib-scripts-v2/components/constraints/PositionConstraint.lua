---位置约束组件
local pairs = pairs
local ipairs = ipairs
local error = error
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

---计算位置 - 跟随第一个
---@param sources components.PositionSource[]
---@param owner any
---@return number, number 计算后的x, y
local function calculatePositionFirst(sources, owner)
    local source = sources[1]
    local target = source.target
    local targetX = target.x or 0
    local targetY = target.y or 0
    local targetRot = source.followRotation and target.rot or nil
    return calculatePositionWithRotation(targetX, targetY, source.offsetX, source.offsetY, targetRot)
end

---计算位置 - 跟随最后一个
---@param sources components.PositionSource[]
---@param owner any
---@return number, number 计算后的x, y
local function calculatePositionLast(sources, owner)
    local source = sources[#sources]
    local target = source.target
    local targetX = target.x or 0
    local targetY = target.y or 0
    local targetRot = source.followRotation and target.rot or nil
    return calculatePositionWithRotation(targetX, targetY, source.offsetX, source.offsetY, targetRot)
end

---计算位置 - 平均
---@param sources components.PositionSource[]
---@param owner any
---@return number, number 计算后的x, y
local function calculatePositionAverage(sources, owner)
    local sumX = 0
    local sumY = 0
    local count = 0

    for _, source in ipairs(sources) do
        local target = source.target
        local targetX = target.x or 0
        local targetY = target.y or 0
        local targetRot = source.followRotation and target.rot or nil
        local posX, posY = calculatePositionWithRotation(targetX, targetY, source.offsetX, source.offsetY, targetRot)
        sumX = sumX + posX
        sumY = sumY + posY
        count = count + 1
    end

    if count > 0 then
        return sumX / count, sumY / count
    else
        return owner.x or 0, owner.y or 0
    end
end

---计算位置 - 加权平均
---@param sources components.PositionSource[]
---@param owner any
---@return number, number 计算后的x, y
local function calculatePositionWeighted(sources, owner)
    local sumX = 0
    local sumY = 0
    local totalWeight = 0

    for _, source in ipairs(sources) do
        local target = source.target
        local targetX = target.x or 0
        local targetY = target.y or 0
        local weight = source.weight or 1
        local targetRot = source.followRotation and target.rot or nil
        local posX, posY = calculatePositionWithRotation(targetX, targetY, source.offsetX, source.offsetY, targetRot)
        sumX = sumX + posX * weight
        sumY = sumY + posY * weight
        totalWeight = totalWeight + weight
    end

    if totalWeight > 0 then
        return sumX / totalWeight, sumY / totalWeight
    else
        return owner.x or 0, owner.y or 0
    end
end

---位置计算模式
---@alias PositionConstraintMode "average"|"weighted"|"first"|"last"
local PositionConstraintMode = {
    AVERAGE = "average", -- 平均
    WEIGHTED_AVERAGE = "weighted", -- 加权平均
    FIRST = "first", -- 跟随第一个
    LAST = "last", -- 跟随最后一个
}

---@class components.PositionSourceConfig
---@field offsetX number|nil 位置偏移X（默认0）
---@field offsetY number|nil 位置偏移Y（默认0）
---@field followRotation boolean|nil 是否跟随旋转（默认false）
---@field weight number|nil 权重（用于加权平均，默认1）

---@class components.PositionSource
---@field target any 约束目标
---@field offsetX number 位置偏移X
---@field offsetY number 位置偏移Y
---@field followRotation boolean 是否跟随旋转
---@field weight number 权重（用于加权平均）

---@class components.PositionConstraint : core.Component
---@field sources table<number, components.PositionSource> 源列表（使用ID作为key）
---@field nextSourceId number 下一个源ID
---@field mode PositionConstraintMode 位置计算模式
---@field weight number 约束权重（0-1，用于控制跟随速度，默认1）
---@field onSourceAdded fun(constraint: components.PositionConstraint, sourceId: number, source: components.PositionSource)|nil 源添加回调
---@field onSourceRemoved fun(constraint: components.PositionConstraint, sourceId: number, source: components.PositionSource)|nil 源移除回调

-- 定义组件类型
local PositionConstraintType = TypeDef.create("components.PositionConstraint", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 50,
        alias = "positionConstraint",
        sources = nil,
        nextSourceId = nil,
        mode = PositionConstraintMode.AVERAGE,
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

            -- 初始化位置计算器函数表
            if not self._calculators then
                self._calculators = {
                    [PositionConstraintMode.FIRST] = calculatePositionFirst,
                    [PositionConstraintMode.LAST] = calculatePositionLast,
                    [PositionConstraintMode.AVERAGE] = calculatePositionAverage,
                    [PositionConstraintMode.WEIGHTED_AVERAGE] = calculatePositionWeighted,
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

            -- 计算目标位置
            local mode = self.mode or PositionConstraintMode.AVERAGE
            local calculator = self._calculators[mode]
            if calculator then
                local targetX, targetY = calculator(validSources, self.owner)
                local weight = self.weight or 1

                -- 应用权重插值
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
        end,

        ---添加约束源
        ---@param target any 约束目标
        ---@param config components.PositionSourceConfig|nil 配置选项
        ---@return number sourceId 源ID
        addSource = function(self, target, config)
            if not target then
                error("Position constraint source target cannot be nil", 2)
            end

            if not self.sources then
                self:Awake()
            end

            config = config or {}
            local sourceId = self.nextSourceId
            self.nextSourceId = self.nextSourceId + 1

            local source = {
                target = target,
                offsetX = config.offsetX or 0,
                offsetY = config.offsetY or 0,
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
        ---@return components.PositionSource|nil
        getSource = function(self, sourceId)
            if not self.sources then
                self:Awake()
            end
            return self.sources[sourceId]
        end,

        ---获取所有约束源
        ---@return table<number, components.PositionSource>
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

---创建位置约束组件
---@param config table
---@return components.PositionConstraint
local function create(config)
    config = config or {}
    return TypeDef.instantiate(PositionConstraintType, config)
end

return {
    create = create,
    Type = PositionConstraintType,
    Mode = PositionConstraintMode,
    -- 导出计算函数供其他组件复用
    calculatePositionFirst = calculatePositionFirst,
    calculatePositionLast = calculatePositionLast,
    calculatePositionAverage = calculatePositionAverage,
    calculatePositionWeighted = calculatePositionWeighted,
    calculatePositionWithRotation = calculatePositionWithRotation,
}

