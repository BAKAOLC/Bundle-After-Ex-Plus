---朝向约束组件（LookAt Constraint）
local pairs = pairs
local ipairs = ipairs
local error = error
local math = math
local table = table

local lstg = lstg

local TypeDef = require("core.TypeDef")
local ComponentSystem = require("core.ComponentSystem")

---计算两点之间的角度（度）
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
local function calculateAngle(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.deg(math.atan2(dy, dx))
end

---计算旋转 - 朝向第一个目标
---@param sources components.LookAtSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateLookAtFirst(sources, owner)
    local source = sources[1]
    local target = source.target
    local targetX = target.x or 0
    local targetY = target.y or 0
    local ownerX = owner.x or 0
    local ownerY = owner.y or 0
    local angle = calculateAngle(ownerX, ownerY, targetX, targetY)
    return angle + source.offsetAngle
end

---计算旋转 - 朝向最后一个目标
---@param sources components.LookAtSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateLookAtLast(sources, owner)
    local source = sources[#sources]
    local target = source.target
    local targetX = target.x or 0
    local targetY = target.y or 0
    local ownerX = owner.x or 0
    local ownerY = owner.y or 0
    local angle = calculateAngle(ownerX, ownerY, targetX, targetY)
    return angle + source.offsetAngle
end

---计算旋转 - 朝向平均位置
---@param sources components.LookAtSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateLookAtAverage(sources, owner)
    local sumX = 0
    local sumY = 0
    local count = 0

    for _, source in ipairs(sources) do
        local target = source.target
        local targetX = target.x or 0
        local targetY = target.y or 0
        sumX = sumX + targetX
        sumY = sumY + targetY
        count = count + 1
    end

    if count > 0 then
        local avgX = sumX / count
        local avgY = sumY / count
        local ownerX = owner.x or 0
        local ownerY = owner.y or 0
        local angle = calculateAngle(ownerX, ownerY, avgX, avgY)
        return angle + (sources[1].offsetAngle or 0)
    else
        return owner.rot
    end
end

---计算旋转 - 朝向加权平均位置
---@param sources components.LookAtSource[]
---@param owner any
---@return number|nil 计算后的旋转角度
local function calculateLookAtWeighted(sources, owner)
    local sumX = 0
    local sumY = 0
    local totalWeight = 0

    for _, source in ipairs(sources) do
        local target = source.target
        local targetX = target.x or 0
        local targetY = target.y or 0
        local weight = source.weight or 1
        sumX = sumX + targetX * weight
        sumY = sumY + targetY * weight
        totalWeight = totalWeight + weight
    end

    if totalWeight > 0 then
        local avgX = sumX / totalWeight
        local avgY = sumY / totalWeight
        local ownerX = owner.x or 0
        local ownerY = owner.y or 0
        local angle = calculateAngle(ownerX, ownerY, avgX, avgY)
        return angle + (sources[1].offsetAngle or 0)
    else
        return owner.rot
    end
end

---朝向计算模式
---@alias LookAtConstraintMode "average"|"weighted"|"first"|"last"
local LookAtConstraintMode = {
    AVERAGE = "average", -- 平均
    WEIGHTED_AVERAGE = "weighted", -- 加权平均
    FIRST = "first", -- 朝向第一个
    LAST = "last", -- 朝向最后一个
}

---@class components.LookAtSourceConfig
---@field offsetAngle number|nil 旋转偏移角度（默认0）
---@field weight number|nil 权重（用于加权平均，默认1）

---@class components.LookAtSource
---@field target any 约束目标
---@field offsetAngle number 旋转偏移角度
---@field weight number 权重（用于加权平均）

---@class components.LookAtConstraint : core.Component
---@field sources table<number, components.LookAtSource> 源列表（使用ID作为key）
---@field nextSourceId number 下一个源ID
---@field mode LookAtConstraintMode 朝向计算模式
---@field weight number 约束权重（0-1，用于控制跟随速度，默认1）
---@field onSourceAdded fun(constraint: components.LookAtConstraint, sourceId: number, source: components.LookAtSource)|nil 源添加回调
---@field onSourceRemoved fun(constraint: components.LookAtConstraint, sourceId: number, source: components.LookAtSource)|nil 源移除回调

-- 定义组件类型
local LookAtConstraintType = TypeDef.create("components.LookAtConstraint", ComponentSystem.ComponentType, {
    defaults = {
        enabled = true,
        executePriority = 50,
        alias = "lookAtConstraint",
        sources = nil,
        nextSourceId = nil,
        mode = LookAtConstraintMode.FIRST,
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

            -- 初始化朝向计算器函数表
            if not self._calculators then
                self._calculators = {
                    [LookAtConstraintMode.FIRST] = calculateLookAtFirst,
                    [LookAtConstraintMode.LAST] = calculateLookAtLast,
                    [LookAtConstraintMode.AVERAGE] = calculateLookAtAverage,
                    [LookAtConstraintMode.WEIGHTED_AVERAGE] = calculateLookAtWeighted,
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
            local mode = self.mode or LookAtConstraintMode.FIRST
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
        ---@param config components.LookAtSourceConfig|nil 配置选项
        ---@return number sourceId 源ID
        addSource = function(self, target, config)
            if not target then
                error("LookAt constraint source target cannot be nil", 2)
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
        ---@return components.LookAtSource|nil
        getSource = function(self, sourceId)
            if not self.sources then
                self:Awake()
            end
            return self.sources[sourceId]
        end,

        ---获取所有约束源
        ---@return table<number, components.LookAtSource>
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

---创建朝向约束组件
---@param config table
---@return components.LookAtConstraint
local function create(config)
    config = config or {}
    return TypeDef.instantiate(LookAtConstraintType, config)
end

return {
    create = create,
    Type = LookAtConstraintType,
    Mode = LookAtConstraintMode,
}

